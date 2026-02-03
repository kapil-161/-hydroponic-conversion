C=======================================================================
C  OpPlantK, Subroutine
C-----------------------------------------------------------------------
C  Generates output file for daily plant potassium data
C
C  K-SPECIFIC OUTPUTS:
C  - Luxury K storage tracking
C  - N:K and P:K ratio outputs
C  - Two stress factors (stomatal and photosynthesis)
C-----------------------------------------------------------------------
C  REVISION HISTORY
C  01/30/2026 Written based on OpPlantP for potassium output.
C-----------------------------------------------------------------------
C  Called by: K_PLANT
C  Calls:     None
!=======================================================================
      SUBROUTINE OpPlantK(DYNAMIC, MDATE, YRPLT,
     &  KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt, KConc_Seed_opt,
     &  KConc_Shut_min, KConc_Root_min, KConc_Shel_min, KConc_Seed_min,
     &  KConc_Shut_lux,
     &  KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, KConc_Plant,
     &  KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg, KLuxury_kg,
     &  Shut_kg, Root_kg, Shel_kg, Seed_kg, N2K, P2K, KTotDem,
     &  SenSoilK, SenSurfK, PhFrac1, PhFrac2,
     &  KStres1, KStres2, KSTRESS_RATIO, KUptakeProf,
     &  PestShutK, PestRootK, PestShelK, PestSeedK)

!-----------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, HEADER, TIMDIF, YR_DOY
      SAVE
!-----------------------------------------------------------------------
      CHARACTER*1  IDETL, IDETP, ISWPOT
      CHARACTER*2  CROP
      CHARACTER*12 OUTK
      CHARACTER*13 KPBAL

      INTEGER COUNT, DAP, DAS, DOY, DYNAMIC, ERRNUM, FROP
      INTEGER LUNKPC, NOUTDK, RUN
      INTEGER TIMDIF, YEAR, YRDOY, MDATE, YRPLT

      REAL KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt,KConc_Seed_opt
      REAL KConc_Shut_min, KConc_Root_min, KConc_Shel_min,KConc_Seed_min
      REAL KConc_Shut_lux  !Luxury concentration
      REAL KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, KConc_Plant
      REAL KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg
      REAL KLuxury_kg  !Luxury K storage
      REAL Shut_kg, Root_kg, Shel_kg, Seed_kg
      REAL SenSoilK, SenSurfK, KStres1, KStres2, KUptakeProf
      REAL KSTRESS_RATIO
      REAL CumSenSurfK, CumSenSoilK !cumul. senes. K soil and surface
      REAL DayKBal, CumBal
      REAL InitPlusAdds, FinalPlusSubs
      REAL KPLANTinit, KPlant_Y
      REAL KS1_AV, KS2_AV
      REAL KUptake_Cum
      REAL PhFrac1, PhFrac2
      REAL N2K, P2K, KTotDem
      REAL PestShutK, PestRootK, PestShelK, PestSeedK
      REAL PestShutCumK, PestRootCumK, PestShelCumK, PestSeedCumK
      REAL CumSenTot, CumPestTot, FinalK, KBalance, DayPestK

      LOGICAL FEXIST, FIRST

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

!     Get CONTROL and ISWITCH info
      CALL GET(CONTROL)
      CALL GET(ISWITCH)

!     No output for fallow crop or if K simulation disabled
      CROP    = CONTROL % CROP
      IDETL   = ISWITCH % IDETL
      IDETP   = ISWITCH % IDETP  ! Not used for K, kept for compatibility
      ISWPOT  = ISWITCH % ISWPOT
!     K output controlled by ISWPOT (not IDETP which is P-specific)
      IF (CROP   .EQ. 'FA' .OR.
     &    IDETL  .EQ. 'N'  .OR.
     &    IDETL  .EQ. '0'  .OR.
     &    ISWPOT .EQ. 'N') RETURN

!     Transfer values from constructed data types into local variables.
      DAS     = CONTROL % DAS
      FROP    = CONTROL % FROP
      RUN     = CONTROL % RUN
      YRDOY   = CONTROL % YRDOY

!***********************************************************************
!***********************************************************************
!     Seasonal initialization - run once per season
!***********************************************************************
      IF (DYNAMIC .EQ. SEASINIT) THEN
!-----------------------------------------------------------------------
!     Initialize daily growth output file
      OUTK  = 'PlantK.OUT'
      CALL GETLUN(OUTK, NOUTDK)
      INQUIRE (FILE = OUTK, EXIST = FEXIST)
      IF (FEXIST) THEN
        OPEN (UNIT = NOUTDK, FILE = OUTK, STATUS = 'OLD',
     &    IOSTAT = ERRNUM, POSITION = 'APPEND')
        FIRST = .FALSE.
      ELSE
        OPEN (UNIT = NOUTDK, FILE = OUTK, STATUS = 'NEW',
     &    IOSTAT = ERRNUM)
        WRITE(NOUTDK,'("*Plant Potassium Daily Output")')
        FIRST = .TRUE.
      ENDIF

      !Write headers
      CALL HEADER(SEASINIT, NOUTDK, RUN)
      WRITE (NOUTDK,50)
   50 FORMAT('@YEAR DOY   DAS   DAP',
!       Optimum K conc. (shoot, root, shell, seed)
     &  '   KSHOD   KRTOD   KSLOD   KSDOD',
!       Minimum K conc. (shoot, root, shell, seed)
     &  '   KSHMD   KRTMD   KSLMD   KSDMD',
!       Luxury K conc. (shoot only - K-specific)
     &  '   KSHLD',
!       K Conc. (shoot, root, shell, seed, plant)
     &  '   SHKPD   RTKPD   SLKPD   SDKPD   PLKPD',
!       K Mass (shoot, root, shell, seed, plant, luxury)
     &  '   SHKAD   RTKAD   SLKAD   SDKAD    KPAD   KLUXD',
!       K stresses, uptake, senescence
     &  '   KST1A   KST2A    KUPD    KUPC   SNK0C   SNK1C',
!       Fraction of vegetative and reproductive phases
     &  '   PHFR1   PHFR2',
!       Plant weights (shoot, root, shell, seed)
     &  '   SHWAD    RWAD    SHAD    GWAD',
!       K stress ratio, N:K, P:K ratios
     &  '   KSTRAT    N2KD    P2KD',
!       Total K demand
     &  '    KTDD')

      CumSenSurfK = 0.0
      CumSenSoilK = 0.0
      KUptake_Cum = 0.0

      PestShutCumK = 0.0
      PestRootCumK = 0.0
      PestShelCumK = 0.0
      PestSeedCumK = 0.0

      KPlantInit = KPlant_kg

!     ------------------------------------------------------------------
!     Seasonal Plant K balance.
      KPBAL = 'PlantKBal.OUT'
      CALL GETLUN(KPBAL, LUNKPC)
      INQUIRE (FILE = KPBAL, EXIST = FEXIST)
      IF (FEXIST) THEN
        OPEN (UNIT = LUNKPC, FILE = KPBAL, STATUS = 'OLD',
     &    IOSTAT = ERRNUM, POSITION = 'APPEND')
      ELSE
        OPEN (UNIT = LUNKPC, FILE = KPBAL, STATUS = 'NEW',
     &    IOSTAT = ERRNUM)
        WRITE(LUNKPC,'("*PLANT K BALANCE")')
      ENDIF

      CALL HEADER(SEASINIT, LUNKPC, RUN)

!     ------------------------------------------------------------------
!     Optional daily K balance (if IDETL = 'D' or 'A')
      IF (INDEX('AD',IDETL) > 0) THEN
        KPLANT_Y = KPLANTinit
        WRITE(LUNKPC, 80)
   80   FORMAT('@YEAR DOY   DAS   DAP',
     &  '   TOTKAD    SHKAD    RTKAD    SLKAD    SDKAD    KLUXD',
     &  '     KUPD    SNK0D    SNK1D    KPest     SKBAL    CUMBAL')
      ENDIF

      KS1_AV = 0.0
      KS2_AV = 0.0
      COUNT = 0

!***********************************************************************
!***********************************************************************
!     EMERGENCE
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. EMERG) THEN
C-----------------------------------------------------------------------
      KPlantInit = KPlant_kg

!***********************************************************************
!***********************************************************************
!     DAILY OUTPUT
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. OUTPUT) THEN
C-----------------------------------------------------------------------
C   CHECK FOR OUTPUT FREQUENCY
C-----------------------------------------------------------------------
!     Don't print prior to planting date
      IF (YRDOY .LT. YRPLT .OR. YRPLT .LT. 0) RETURN

!     Accumulate seasonal K uptake
      KUptake_Cum = KUptake_Cum + KUptakeProf

!     Compute average stress factors since last printout
      KS1_AV = KS1_AV + (1.0 - KSTRES1)
      KS2_AV = KS2_AV + (1.0 - KSTRES2)
      COUNT = COUNT + 1

!     Accumulate K in senesced matter for surface and soil.
      CumSenSurfK = CumSenSurfK + SenSurfK
      CumSenSoilK = CumSenSoilK + SenSoilK

!     Accumulate K lost to pest damage.
      PestShutCumK = PestShutCumK + PestShutK
      PestRootCumK = PestRootCumK + PestRootK
      PestShelCumK = PestShelCumK + PestShelK
      PestSeedCumK = PestSeedCumK + PestSeedK

      IF ((MOD(DAS,FROP) .EQ. 0)          !Daily output every FROP days,
     &  .OR. (YRDOY .EQ. YRPLT)           !on planting date, and
     &  .OR. (YRDOY .EQ. MDATE)) THEN     !at harvest maturity
!       Print
        DAP = MAX(0,TIMDIF(YRPLT,YRDOY))
        CALL YR_DOY(YRDOY, YEAR, DOY)

!       Compute average stress factors since last printout
        IF (COUNT > 0) THEN
          KS1_AV = KS1_AV / COUNT
          KS2_AV = KS2_AV / COUNT
          COUNT = 0
        ENDIF

        WRITE (NOUTDK,100) YEAR, DOY, DAS, DAP,
     &    KConc_Shut_opt*100., KConc_Root_opt*100.,
     &    KConc_Shel_opt*100., KConc_Seed_opt*100.,
     &    KConc_Shut_min*100., KConc_Root_min*100.,
     &    KConc_Shel_min*100., KConc_Seed_min*100.,
     &    KConc_Shut_lux*100.,
     &    KConc_Shut*100., KConc_Root*100.,
     &    KConc_Shel*100., KConc_Seed*100., KConc_Plant*100.,
     &    KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg, KLuxury_kg,
     &    KS1_AV, KS2_AV,
     &    KUptakeProf, KUptake_Cum, CumSenSurfK, CumSenSoilK,
     &    PhFrac1, PhFrac2,
     &    NINT(Shut_kg), NINT(Root_kg), NINT(Shel_kg), NINT(Seed_kg),
     &    KSTRESS_RATIO, N2K, P2K, KTotDem
  100   FORMAT(1X,I4,1X,I3.3,2(1X,I5),
     &       14F8.3,6F8.2,2F8.4,6F8.3,4I8,
     &       F10.3, 3F8.3)

!       Set average stress factors since last printout back to zero
        KS1_AV = 0.0
        KS2_AV = 0.0

      ENDIF

!     -------------------------------------------------------------
!     Daily K balance
      IF (INDEX('AD',IDETL) > 0) THEN

        CumSenTot = CumSenSurfK + CumSenSoilK
        CumPestTot = PestShutCumK + PestRootCumK + PestShelCumK
     &                + PestSeedCumK
        DayPestK = PestShutK + PestRootK + PestShelK + PestSeedK

        DayKBal = KPlant_kg - KPlant_Y        !Change
     &    - KUptakeProf                       !Additions
     &    + SenSurfK + SenSoilK + DayPestK    !Subtractions

        IF ((KPlant_kg - KPLANTinit) .LT. 1.E-6) THEN
          DayKBal = DayKBal - KPLANTinit
        ENDIF

        InitPlusAdds = KPLANTinit + KUptake_Cum
        FinalPlusSubs = KPlant_kg + CumSenTot + CumPestTot
        CumBal = FinalPlusSubs - InitPlusAdds

        WRITE(LUNKPC, 300)  YEAR, DOY, DAS, DAP,
     &    KPlant_kg, KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KLuxury_kg,
     &    KUptakeProf, SenSurfK, SenSoilK, DayPestK, DayKBal, CumBal
  300   FORMAT(1X,I4,1X,I3.3,2(1X,I5),10F9.4, 2F10.5)

        KPlant_Y = KPlant_kg
      ENDIF

!***********************************************************************
!***********************************************************************
!     Seasonal Output
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. SEASEND) THEN
C-----------------------------------------------------------------------
      !Close daily output file.
      CLOSE (NOUTDK)

!     ------------------------------------------------------------------
      CumSenTot = CumSenSurfK + CumSenSoilK
      CumPestTot = PestShutCumK +PestRootCumK +PestShelCumK+PestSeedCumK
      FinalK = KShut_kg + KRoot_kg + KShel_kg + KSeed_kg
      KBalance = FinalK - KPlantInit - KUptake_Cum
     &                    + CumSenTot + CumPestTot

      WRITE (LUNKPC,510) KPlantInit, KUptake_Cum,      !Initial & Uptake
     &    CumSenTot, CumSenSurfK, CumSenSoilK,                !Senesced
     &    CumPestTot, PestShutCumK, PestRootCumK,
     &        PestShelCumK, PestSeedCumK,                     !Pest
     &    FinalK, KShut_kg, KRoot_kg, KShel_kg, KSeed_kg,     !Final
     &    KLuxury_kg,                                         !Luxury K
     &    KBalance                                            !Balance

  510 FORMAT (//,' Seasonal Plant K balance (kg[K]/ha)',/,
     &    T36,'   Total   Shoot    Root   Shell    Seed',/,
     &    ' Initial plant K (at emergence)    ',F8.2,/,       !Initial
     &    ' K uptake from soil               +',F8.2,/,       !Uptake
     &    ' K losses:',/,
     &    '   Senesced / freeze damage       -',3F8.2,/,      !Senesced
     &    '   Pest / disease damage          -',5F8.2,/,      !Pest
     &    ' K in plant tissue at harvest     =',5F8.2,/,      !Final
     &    ' Luxury K stored in veg. tissue    ',F8.2,/,       !Luxury
     &    ' Total K balance                   ',F8.3)         !Balance

      WRITE (LUNKPC,'(/,80("*"))')

!     Close seasonal output file.
      CLOSE (UNIT = LUNKPC)

!***********************************************************************
!***********************************************************************
!     END OF DYNAMIC IF CONSTRUCT
!***********************************************************************
      ENDIF
!-----------------------------------------------------------------------
      RETURN
      END SUBROUTINE OpPlantK
!=======================================================================
