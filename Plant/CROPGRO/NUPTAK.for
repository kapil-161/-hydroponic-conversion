C=======================================================================
C  NUPTAK, Subroutine
C  Determines N uptake (adapted from CERES)
C-----------------------------------------------------------------------
C  Revision history
C  09/01/1989 JWJ,GH Written
C  03/01/1993 WTB Modified.
C  01/20/1997 GH  Modified.
C  07/10/1998 CHP modified for modular format.
C  05/11/1998 GH  Incorporated in CROPGRO
C  12/22/2025 Added hydroponic K demand estimation from N demand
C              (CROPGRO doesn't calculate K demand, so we estimate it
C               using typical N:K ratio ~1:1.2 for leafy vegetables)
C-----------------------------------------------------------------------
C  Called from:  PLANT
C  Calls:        ERROR, FIND, IGNORE, HYDRO_NUTRIENT
C=======================================================================

      SUBROUTINE NUPTAK(DYNAMIC, ISWITCH,
     &  DLAYR, DUL, FILECC, KG2PPM, LL, NDMSDR, NDMTOT,   !Input
     &  NH4, NO3, NLAYR, RLV, SAT, SW, PLTPOP, RTDEP,     !Input
     &  TRLV, VSTAGE,                                     !Input
     &  TRNH4U, TRNO3U, TRNU, UNH4, UNO3)                 !Output

!-----------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, FIND, ERROR, IGNORE, HYDRO_NUTRIENT
      EXTERNAL SOLPi, SOLKI
      SAVE

      TYPE (SwitchType) ISWITCH

      CHARACTER*6 ERRKEY
      PARAMETER (ERRKEY = 'NUPTAK')
      CHARACTER*6 SECTION
      CHARACTER*80 CHAR
      CHARACTER*92 FILECC

      INTEGER I, LUNCRP, ERR, LNUM, ISECT, FOUND
      INTEGER L, NLAYR, DYNAMIC

      REAL NUF, XMIN
      CHARACTER*1 ISWHYDRO
C     PLTPOP and RTDEP are input parameters - declared for clarity
C     NDMTOT and NDMSDR are input parameters - declared for clarity  
      REAL PLTPOP, RTDEP, NDMTOT, NDMSDR

C     Hydroponic solution variables (SAVE to persist across calls)
      REAL NO3_SOL, NH4_SOL, P_SOL, K_SOL
      REAL UPO4_HYDRO, UK_HYDRO, UNO3_TOT, UNH4_TOT
      REAL UNO3_DUMMY, UNH4_DUMMY  ! Dummy variables for HYDRO_NUTRIENT call
      REAL PDEMAND  ! Estimated P demand (kg/ha/day) - from N demand
      REAL KDEMAND  ! Estimated K demand (kg/ha/day) - from N demand
      REAL N_TO_P_RATIO  ! N:P ratio for demand estimation (typically 1:0.15)
      REAL N_TO_K_RATIO  ! N:K ratio for demand estimation (typically 1:1.2)
      TYPE (ControlType) :: CONTROL_DUMMY
      SAVE
      REAL DLAYR(NL), LL(NL), DUL(NL), SAT(NL), SW(NL), RLV(NL)
      REAL SNO3(NL), SNH4(NL), KG2PPM(NL), NO3(NL), NH4(NL)
      REAL RNO3U(NL), RNH4U(NL), UNO3(NL), UNH4(NL)
      REAL TRNO3U, TRNH4U, TRNU
      REAL ANDEM, FNH4, FNO3, SMDFR, RFAC
      REAL RTNO3, RTNH4, MXNH4U, MXNO3U
      REAL TRLV    ! Total root length per unit area (cm/cm2) from ROOTS
      REAL VSTAGE  ! Vegetative stage (main stage variable)

!***********************************************************************
!***********************************************************************
!     Run Initialization - Called once per simulation
!***********************************************************************
      IF (DYNAMIC .EQ. RUNINIT) THEN
!-----------------------------------------------------------------------
!     ***** READ ROOT GROWTH PARAMETERS *****************
!-----------------------------------------------------------------------
!     Read in values from input file, which were previously input
!       in Subroutine IPCROP.
!-----------------------------------------------------------------------
      CALL GETLUN('FILEC', LUNCRP)
      OPEN (LUNCRP,FILE = FILECC, STATUS = 'OLD',IOSTAT=ERR)
      IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,0)

!-----------------------------------------------------------------------
!    Find and Read Photosynthesis Section
!-----------------------------------------------------------------------
!     Subroutine FIND finds appropriate SECTION in a file by
!     searching for the specified 6-character string at beginning
!     of each line.
!-----------------------------------------------------------------------
      SECTION = '!*ROOT'
      CALL FIND(LUNCRP, SECTION, LNUM, FOUND)
      IF (FOUND .EQ. 0) THEN
        CALL ERROR(SECTION, 42, FILECC, LNUM)
      ELSE
        DO I = 1, 3
          CALL IGNORE(LUNCRP,LNUM,ISECT,CHAR)
          IF (ISECT .EQ. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)
        ENDDO
        READ(CHAR,'(2F6.0)',IOSTAT=ERR) RTNO3, RTNH4
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)
      ENDIF

      CLOSE (LUNCRP)

!***********************************************************************
!***********************************************************************
!     Seasonal initialization - run once per season
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. SEASINIT) THEN
!-----------------------------------------------------------------------
      ISWHYDRO = ISWITCH % ISWHYDRO

      TRNO3U = 0.0
      TRNH4U = 0.0
      TRNU   = 0.0
      UNH4   = 0.0
      UNO3   = 0.0

C     Initialize hydroponic solution concentrations from ModuleData
      IF (ISWHYDRO .EQ. 'Y') THEN
C       Get values from ModuleData (should be set by IPEXP)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

C       Check if values were retrieved successfully (should be > 0 if set)
C       If values are missing (still 0 or negative), use defaults from experiment file
        IF (NO3_SOL .LT. 0.1 .OR. NH4_SOL .LT. 0.0) THEN
          WRITE(*,*) 'NUPTAK WARNING: ModuleData values not found, using defaults'
          IF (NO3_SOL .LT. 0.1) NO3_SOL = 180.0   ! Default NO3-N (mg/L)
          IF (NH4_SOL .LT. 0.0) NH4_SOL = 15.0    ! Default NH4-N (mg/L)
          IF (P_SOL .LT. 0.0) P_SOL = 60.0        ! Default P (mg/L)
          IF (K_SOL .LT. 0.0) K_SOL = 240.0       ! Default K (mg/L)
C         Store defaults back to ModuleData
          CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
          CALL PUT('HYDRO','NH4_CONC',NH4_SOL)
          CALL PUT('HYDRO','P_CONC',P_SOL)
          CALL PUT('HYDRO','K_CONC',K_SOL)
        ENDIF

        WRITE(*,*) 'NUPTAK SEASINIT: Solution concentrations initialized:'
        WRITE(*,*) '  NO3=',NO3_SOL,' NH4=',NH4_SOL,
     &             ' P=',P_SOL,' K=',K_SOL

C       Initialize HYDRO_NUTRIENT module for N uptake only
C       HYDRO_NUTRIENT will also read from ModuleData, but we pass current values
        CONTROL_DUMMY % DYNAMIC = SEASINIT
        CALL HYDRO_NUTRIENT(
     &    CONTROL_DUMMY, ISWITCH,
     &    FILECC, PLTPOP, RTDEP, 999.0, TRLV, VSTAGE,
     &    UNO3_TOT, UNH4_TOT,
     &    NO3_SOL, NH4_SOL)

C       Initialize SOLPi module for P uptake
        PDEMAND = 0.0
        CONTROL_DUMMY % DYNAMIC = SEASINIT
        CALL SOLPi(
     &    CONTROL_DUMMY, ISWITCH,
     &    FILECC, PLTPOP, RTDEP, PDEMAND,
     &    UPO4_HYDRO,
     &    P_SOL)

C       Initialize SOLKI module for K uptake
        KDEMAND = 0.0
        CONTROL_DUMMY % DYNAMIC = SEASINIT
        CALL SOLKI(
     &    CONTROL_DUMMY, ISWITCH,
     &    FILECC, PLTPOP, RTDEP, KDEMAND,
     &    UK_HYDRO,
     &    K_SOL)

        WRITE(*,*) 'NUPTAK: Hydroponic mode initialized (N,P,K)'
      ENDIF

!***********************************************************************
!***********************************************************************
!     DAILY RATE/INTEGRATION
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. INTEGR) THEN
!-----------------------------------------------------------------------
C   Initialize variables
C-----------------------------------------------------------------------
      TRNU   = 0.0
      TRNO3U = 0.0
      TRNH4U = 0.0
      NUF    = 0.0
      XMIN   = 0.0
      DO L=1,NLAYR
        RNO3U(L) = 0.0
        RNH4U(L) = 0.0
        UNH4(L)  = 0.0
        UNO3(L)  = 0.0
        !KG2PPM(L) = 10. / (BD(L) * DLAYR(L))
        SNO3(L) = NO3(L) / KG2PPM(L)
        SNH4(L) = NH4(L) / KG2PPM(L)
      ENDDO
C-----------------------------------------------------------------------
C   HYDROPONIC MODE: Use solution-based nutrient uptake
C   Make it demand-driven like soil mode - match exact soil behavior
C-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
C       Calculate N demand (EXACT same as soil mode)
        ANDEM = (NDMTOT - NDMSDR) * 10.0  ! kg N/ha

C       Estimate P and K demands from N demand using typical ratios for lettuce
C       Literature values for lettuce: N:P:K approximately 1.0:0.15:1.2
C       This makes P and K uptake demand-driven like N uptake
        N_TO_P_RATIO = 0.15  ! P demand = N demand * 0.15
        N_TO_K_RATIO = 1.2   ! K demand = N demand * 1.2
        PDEMAND = ANDEM * N_TO_P_RATIO  ! kg P/ha/day
        KDEMAND = ANDEM * N_TO_K_RATIO  ! kg K/ha/day

        IF (ANDEM .GT. 1.E-9) THEN
C         In hydroponic systems with adequate concentrations, uptake should meet demand
C         Check if solution concentrations are adequate (similar to soil availability check)
C         In hydroponic systems, when concentrations are adequate, uptake should meet demand
C         This matches soil mode behavior when soil N is abundant
          IF (NO3_SOL + NH4_SOL .GT. 10.0) THEN
C           Concentrations are adequate (>= 10 mg/L total N) - uptake can meet full demand
C           Distribute demand between NO3 and NH4 based on relative concentrations
            IF ((NO3_SOL + NH4_SOL) .GT. 0.0) THEN
              UNO3_TOT = ANDEM * (NO3_SOL / (NO3_SOL + NH4_SOL))
              UNH4_TOT = ANDEM * (NH4_SOL / (NO3_SOL + NH4_SOL))
            ELSE
              UNO3_TOT = ANDEM * 0.9  ! Default: mostly NO3
              UNH4_TOT = ANDEM * 0.1
            ENDIF
C           Calculate P uptake using SOLPi module (demand-based)
            CONTROL_DUMMY % DYNAMIC = RATE
            CALL SOLPi(
     &        CONTROL_DUMMY, ISWITCH,                !Input
     &        FILECC, PLTPOP, RTDEP, PDEMAND,        !Input
     &        UPO4_HYDRO,                            !Output (kg/ha/d)
     &        P_SOL)                                 !I/O

C           Calculate K uptake using SOLKI module (demand-based)
            CONTROL_DUMMY % DYNAMIC = RATE
            CALL SOLKI(
     &        CONTROL_DUMMY, ISWITCH,                !Input
     &        FILECC, PLTPOP, RTDEP, KDEMAND,        !Input
     &        UK_HYDRO,                              !Output (kg/ha/d)
     &        K_SOL)                                 !I/O
          ELSE
C           Low concentrations - use Michaelis-Menten for N
            CONTROL_DUMMY % DYNAMIC = RATE
            CALL HYDRO_NUTRIENT(
     &        CONTROL_DUMMY, ISWITCH,                !Input
     &        FILECC, PLTPOP, RTDEP, 999.0, TRLV, VSTAGE,  !Input
     &        UNO3_TOT, UNH4_TOT,                    !Output (kg/ha/d)
     &        NO3_SOL, NH4_SOL)                      !I/O

C           Limit N by demand (like soil mode)
            IF ((UNO3_TOT + UNH4_TOT) .GT. ANDEM) THEN
              IF ((UNO3_TOT + UNH4_TOT) .GT. 0.0) THEN
                NUF = ANDEM / (UNO3_TOT + UNH4_TOT)
                UNO3_TOT = UNO3_TOT * NUF
                UNH4_TOT = UNH4_TOT * NUF
              ENDIF
            ENDIF

C           Calculate P and K uptake using dedicated modules
C           (SOLPi and SOLKI handle low concentration cases internally)
            CONTROL_DUMMY % DYNAMIC = RATE
            CALL SOLPi(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, PDEMAND,
     &        UPO4_HYDRO,
     &        P_SOL)

            CONTROL_DUMMY % DYNAMIC = RATE
            CALL SOLKI(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, KDEMAND,
     &        UK_HYDRO,
     &        K_SOL)
          ENDIF

C         Integrate to update solution concentrations
C         Update N concentrations using HYDRO_NUTRIENT
          CONTROL_DUMMY % DYNAMIC = INTEGR
          CALL HYDRO_NUTRIENT(
     &      CONTROL_DUMMY, ISWITCH,                !Input
     &      FILECC, PLTPOP, RTDEP, 999.0, TRLV, VSTAGE,  !Input
     &      UNO3_TOT, UNH4_TOT,                    !Output
     &      NO3_SOL, NH4_SOL)                      !I/O

C         Update P concentration using SOLPi
          CONTROL_DUMMY % DYNAMIC = INTEGR
          CALL SOLPi(
     &      CONTROL_DUMMY, ISWITCH,
     &      FILECC, PLTPOP, RTDEP, PDEMAND,
     &      UPO4_HYDRO,
     &      P_SOL)

C         Update K concentration using SOLKI
          CONTROL_DUMMY % DYNAMIC = INTEGR
          CALL SOLKI(
     &      CONTROL_DUMMY, ISWITCH,
     &      FILECC, PLTPOP, RTDEP, KDEMAND,
     &      UK_HYDRO,
     &      K_SOL)

C         Store nutrient uptake rates (needed by SPAM for output/pH calculations)
          CALL PUT('HYDRO','UNO3',UNO3_TOT)
          CALL PUT('HYDRO','UNH4',UNH4_TOT)
          CALL PUT('HYDRO','UPO4',UPO4_HYDRO)
          CALL PUT('HYDRO','UK',UK_HYDRO)

C         Convert from kg/ha/day to g/m2 (divide by 10)
          TRNO3U = UNO3_TOT / 10.0
          TRNH4U = UNH4_TOT / 10.0
          TRNU = TRNO3U + TRNH4U
        ELSE
C         No N demand - set N uptake to zero
          TRNO3U = 0.0
          TRNH4U = 0.0
          TRNU = 0.0
          UNO3_TOT = 0.0
          UNH4_TOT = 0.0

C         Even with no N demand, calculate small P and K demands
C         Early seedlings still need some P and K for structural growth
C         Use minimum basal demands (10% of typical ratio-based demands)
          PDEMAND = 0.01  ! Minimum P demand (kg/ha/day)
          KDEMAND = 0.01  ! Minimum K demand (kg/ha/day)

C         Calculate P and K uptake using dedicated modules
          CONTROL_DUMMY % DYNAMIC = RATE
          CALL SOLPi(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, PDEMAND,
     &        UPO4_HYDRO,
     &        P_SOL)

          CONTROL_DUMMY % DYNAMIC = RATE
          CALL SOLKI(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, KDEMAND,
     &        UK_HYDRO,
     &        K_SOL)

C         Update solution concentrations for N, P and K
C         Update N concentrations using HYDRO_NUTRIENT (even with zero uptake)
          CONTROL_DUMMY % DYNAMIC = INTEGR
          CALL HYDRO_NUTRIENT(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, 999.0, TRLV, VSTAGE,
     &        UNO3_TOT, UNH4_TOT,
     &        NO3_SOL, NH4_SOL)

C         Update P concentration using SOLPi
          CONTROL_DUMMY % DYNAMIC = INTEGR
          CALL SOLPi(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, PDEMAND,
     &        UPO4_HYDRO,
     &        P_SOL)

          CONTROL_DUMMY % DYNAMIC = INTEGR
          CALL SOLKI(
     &        CONTROL_DUMMY, ISWITCH,
     &        FILECC, PLTPOP, RTDEP, KDEMAND,
     &        UK_HYDRO,
     &        K_SOL)

C         Store nutrient uptake rates (N is zero, but P and K may be non-zero)
          CALL PUT('HYDRO','UNO3',UNO3_TOT)
          CALL PUT('HYDRO','UNH4',UNH4_TOT)
          CALL PUT('HYDRO','UPO4',UPO4_HYDRO)
          CALL PUT('HYDRO','UK',UK_HYDRO)
        ENDIF

C       Set layer uptake to zero (not layer-based in hydroponics)
        DO L=1,NLAYR
          UNO3(L) = 0.0
          UNH4(L) = 0.0
        ENDDO

        WRITE(*,200) TRNO3U, TRNH4U, TRNU
 200    FORMAT(' Hydroponic N uptake: NO3=',F6.2,
     &         ' NH4=',F6.2,' Total=',F6.2,' g/m2/d')

C       Update stored solution concentrations
        CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
        CALL PUT('HYDRO','NH4_CONC',NH4_SOL)
        CALL PUT('HYDRO','P_CONC',P_SOL)
        CALL PUT('HYDRO','K_CONC',K_SOL)
C       Store uptake rates for output (convert from kg/ha/d to match output format)
        CALL PUT('HYDRO','UNO3',UNO3_TOT)
        CALL PUT('HYDRO','UNH4',UNH4_TOT)
        CALL PUT('HYDRO','UPO4',UPO4_HYDRO)
        CALL PUT('HYDRO','UK',UK_HYDRO)

C       Soil-based uptake will be skipped (handled by ELSE below)
      ELSE
C-----------------------------------------------------------------------
C   SOIL MODE: Determine crop N demand (kg N/ha), after subtracting mobilized N
C-----------------------------------------------------------------------
      ANDEM = (NDMTOT - NDMSDR) * 10.0
      IF (ANDEM .GT. 1.E-9) THEN
C-----------------------------------------------------------------------
C   Calculate potential N uptake in soil layers with roots
C-----------------------------------------------------------------------
        DO L=1,NLAYR
          IF (RLV(L) .GT. 1.E-6) THEN
            FNH4 = 1.0 - EXP(-0.08 * NH4(L))
            FNO3 = 1.0 - EXP(-0.08 * NO3(L))
            IF (FNO3 .LT. 0.04) FNO3 = 0.0  
            IF (FNO3 .GT. 1.0)  FNO3 = 1.0
            IF (FNH4 .LT. 0.04) FNH4 = 0.0  
            IF (FNH4 .GT. 1.0)  FNH4 = 1.0

!           SMDFR = relative drought factor
            SMDFR = (SW(L) - LL(L)) / (DUL(L) - LL(L))

            IF (SW(L) .GT. DUL(L)) THEN
              SMDFR = 1.0 - (SW(L) - DUL(L)) / (SAT(L) - DUL(L))
            ENDIF
            
            IF (SMDFR .LT. 0.1) THEN
              SMDFR = 0.1
            ENDIF
            ! FO/KJB - Change for Cotton
            !RFAC = RLV(L) * SMDFR * SMDFR * DLAYR(L) * 100.0
            RFAC = RLV(L) * SQRT(SMDFR) * DLAYR(L) * 100.0
C-----------------------------------------------------------------------
C  RLV = Rootlength density (cm/cm3);SMDFR = relative drought factor
C  RTNO3 + RTNH4 = Nitrogen uptake / root length (mg N/cm)
C  RNO3U + RNH4  = Nitrogen uptake (kg N/ha)
C-----------------------------------------------------------------------
            RNO3U(L) = RFAC * FNO3 * RTNO3
            RNH4U(L) = RFAC * FNH4 * RTNH4
            RNO3U(L) = MAX(0.0,RNO3U(L))
            RNH4U(L) = MAX(0.0,RNH4U(L))
            TRNU = TRNU + RNO3U(L) + RNH4U(L) !kg[N]/ha
          ENDIF
        ENDDO
C-----------------------------------------------------------------------
C   Calculate N uptake in soil layers with roots based on demand (kg/ha)
C-----------------------------------------------------------------------
        IF (ANDEM .GT. TRNU) THEN
          ANDEM = TRNU
        ENDIF
!        IF (TRNU .EQ. 0.0) GO TO 600
        IF (TRNU .GT. 0.0) THEN
          NUF = ANDEM / TRNU
          DO L=1,NLAYR
            IF (RLV(L) .GT. 0.0) THEN
              UNO3(L) = RNO3U(L) * NUF
              UNH4(L) = RNH4U(L) * NUF
              XMIN    = 0.25 / KG2PPM(L)
              MXNO3U  = MAX(0.0,(SNO3(L) - XMIN))
              IF (UNO3(L) .GT. MXNO3U) THEN
                UNO3(L) = MXNO3U
              ENDIF
              XMIN = 0.5 / KG2PPM(L)
              MXNH4U  = MAX(0.0,(SNH4(L) - XMIN))
              IF (UNH4(L) .GT. MXNH4U) UNH4(L) = MXNH4U
              TRNO3U  = TRNO3U + UNO3(L)
              TRNH4U  = TRNH4U + UNH4(L)
            ENDIF
          ENDDO
C-----------------------------------------------------------------------
C   Convert uptake to g/m^2
C-----------------------------------------------------------------------
          TRNO3U = TRNO3U / 10.0
          TRNH4U = TRNH4U / 10.0
          TRNU   = TRNO3U + TRNH4U
C-----------------------------------------------------------------------
        ENDIF
      ENDIF
      ENDIF  ! End of IF (ISWHYDRO .EQ. 'Y') THEN ... ELSE

!***********************************************************************
!***********************************************************************
!     END OF DYNAMIC IF CONSTRUCT
!***********************************************************************
      ENDIF
!***********************************************************************
      RETURN
      END ! SUBROUTINE NUPTAK
C=======================================================================

!-----------------------------------------------------------------------
!       Variable definitions
!-----------------------------------------------------------------------
! ANDEM    Total crop N demand (kg[N]/ha)
! CHAR     Contains the contents of last record read 
! DLAYR(L) Soil thickness in layer L (cm)
! DUL(L)   Volumetric soil water content at Drained Upper Limit in soil 
!            layer L (cm3 [H2O] /cm3 [soil])
! ERR      Error code for file operation 
! ERRKEY   Subroutine name for error file 
! FILECC   Path plus filename for species file (*.spe) 
! FNH4     Potential NH4 availability factor 
! FNO3     Potential NO3 availability factor 
! KG2PPM(L) Conversion factor to switch from kg [N] / ha to ug [N] / g 
!            [soil] for soil layer L 
! LL(L)    Volumetric soil water content in soil layer L at lower limit
!            ( cm3/cm3)
! LUNCRP   Logical unit number for FILEC (*.spe file) 
! MXNH4U   Maximum NH4 uptake from soil (kg N/ha)
! MXNO3U   Maximum NO3 uptake from soil (kg N/ha)
! NDMSDR   Amount of Mobilized N which can be used for seed growth
!            (g[N] / m2 / d)
! NDMTOT   Total N demand (g[N] / m2 / d)
! NH4(L)   Ammonium N in soil layer L (µg[N] / g[soil])
! NL       maximum number of soil layers = 20 
! NLAYR    Number of soil layers 
! NO3(L)   Nitrate in soil layer L (µg[N] / g[soil])
! NUF      N uptake fraction (ratio of demand to N uptake), <= 1.0 
! RFAC     Nitrogen uptake conversion factor ((kg N/ha) / (mg N / cm root))
! RLV(L)   Root length density for soil layer L ((cm root / cm3 soil))
! RNH4U(L) Ammonium uptake (kg N/ha)
! RNO3U(L) Nitrate uptake (kg N/ha)
! RTNH4    Ammonium uptake per unit root length (mg N / cm)
! RTNO3    Nitrate uptake per unit root length (mg N / cm)
! SAT(L)   Volumetric soil water content in layer L at saturation
!            (cm3 [water] / cm3 [soil])
! SMDFR    Relative drought factor 
! SNH4(L)  Total extractable ammonium N in soil layer L (kg [N] / ha)
! SNO3(L)  Total extractable nitrate N in soil layer L (kg [N] / ha)
! SW(L)    Volumetric soil water content in layer L
!            (cm3 [water] / cm3 [soil])
! TRNH4U   Total N uptake in ammonium form in a day (g[N] / m2 / d)
! TRNO3U   Total N uptake in nitrate form in a day (g[N] / m2 / d)
! TRNU     Total N uptake in a day (kg[N] / ha / d)
! UNH4     Uptake of NH4 from soil (interim value) (kg N/ha)
! UNO3     Uptake of NO3 from soil (interim value) (kg N/ha)
! XMIN     Amount of NH4 that cannot be immobilized but stays behind in 
!            soil as NH4; Also, Amount of NO3 that cannot denitrify but 
!            stays behind in the soil as NO3 (kg [N] / ha)
!-----------------------------------------------------------------------
!       END SUBROUTINE NUPTAK
!=======================================================================
