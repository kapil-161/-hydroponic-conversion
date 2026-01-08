C=======================================================================
C  OPSOL, Subroutine
C-----------------------------------------------------------------------
C  Generates output file for daily hydroponic solution data
C  Tracks: EC, pH, DO2, and nutrient concentrations over time
C-----------------------------------------------------------------------
C  REVISION       HISTORY
C  12/22/2025 Created for hydroponic solution output
C-----------------------------------------------------------------------
C  Called by: SPAM
C  Calls:     GETLUN, HEADER, YR_DOY
C=======================================================================
      SUBROUTINE OPSOL(CONTROL, ISWITCH,
     &  NO3_CONC, NH4_CONC, P_CONC, K_CONC,          !Input
     &  EC_CALC, EC_TARGET, PH_CALC, PH_TARGET,       !Input
     &  DO2_CALC, DO2_SAT, UNO3, UNH4, UPO4, UK)      !Input

C-----------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, HEADER, YR_DOY
      SAVE
C-----------------------------------------------------------------------
      CHARACTER*1  IDETW, ISWHYDRO, RNMODE, FMOPT
      CHARACTER*13 OUTSOL

      INTEGER DAS, DAP, DOY, DYNAMIC, ERRNUM, FROP, NOUTSL
      INTEGER RUN, YEAR, YRDOY, YRPLT

      REAL NO3_CONC, NH4_CONC, P_CONC, K_CONC     ! mg/L
      REAL EC_CALC, EC_TARGET                     ! dS/m
      REAL PH_CALC, PH_TARGET                     ! pH units
      REAL DO2_CALC, DO2_SAT                      ! mg/L
      REAL UNO3, UNH4, UPO4, UK                   ! kg/ha/d

      REAL SOLVOL_MM, SOLTEMP                      ! mm (solution depth), C

      LOGICAL FEXIST

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C-----------------------------------------------------------------------
C     Get values from control and switch structures
C-----------------------------------------------------------------------
      DAS      = CONTROL % DAS
      DYNAMIC  = CONTROL % DYNAMIC
      FROP     = CONTROL % FROP
      RUN      = CONTROL % RUN
      RNMODE   = CONTROL % RNMODE
      YRDOY    = CONTROL % YRDOY

      IDETW    = ISWITCH % IDETW
      ISWHYDRO = ISWITCH % ISWHYDRO
      FMOPT    = ISWITCH % FMOPT

C***********************************************************************
C***********************************************************************
C     Run initialization - run once per simulation
C***********************************************************************
      IF (DYNAMIC .EQ. RUNINIT) THEN
C-----------------------------------------------------------------------
C     Get file unit number (call only once per simulation)
      OUTSOL = 'Solution.OUT'
      CALL GETLUN(OUTSOL, NOUTSL)

C***********************************************************************
C***********************************************************************
C     Seasonal initialization - run once per season
C***********************************************************************
      ELSEIF (DYNAMIC .EQ. SEASINIT) THEN
C-----------------------------------------------------------------------
C     Only proceed if hydroponic mode and output detail requested
      IF (ISWHYDRO .NE. 'Y') RETURN
      IF (IDETW .EQ. 'N') RETURN
      IF (FMOPT .NE. 'A' .AND. FMOPT .NE. ' ') RETURN

C     Open file for this season (append mode for multi-season runs)
      INQUIRE (FILE = OUTSOL, EXIST = FEXIST)
      IF (FEXIST) THEN
        OPEN (UNIT = NOUTSL, FILE = OUTSOL, STATUS = 'OLD',
     &    IOSTAT = ERRNUM, POSITION = 'APPEND')
      ELSE
        OPEN (UNIT = NOUTSL, FILE = OUTSOL, STATUS = 'NEW',
     &    IOSTAT = ERRNUM)
        WRITE(NOUTSL,'("*Hydroponic Solution Daily Output")')
      ENDIF

C     Write headers
      CALL HEADER(SEASINIT, NOUTSL, RUN)

      WRITE (NOUTSL,100)
 100  FORMAT('@YEAR DOY   DAP',
C       DAP = Days After Planting (matches soil-based output format)
C       Solution concentrations (mg/L)
     &  '   NO3CL   NH4CL    PCCL    KCCL',
C       Nutrient uptake rates (kg/ha/d)
     &  '   UNO3D   UNH4D   UPO4D     UKD',
C       EC (dS/m)
     &  '   ECCAL',
C       pH
     &  '   PHCAL',
C       DO2 (mg/L)
     &  '   DO2CL   DO2ST',
C       Solution properties
     &  '   SOLVL   SOLTC')
C     Note: SOLVL is solution depth in mm (1 mm = 1 L/m²)

C***********************************************************************
C***********************************************************************
C     DAILY OUTPUT
C***********************************************************************
      ELSEIF (DYNAMIC .EQ. OUTPUT) THEN
C-----------------------------------------------------------------------
C     Only proceed if hydroponic mode and output detail requested
      IF (ISWHYDRO .NE. 'Y') RETURN
      IF (IDETW .EQ. 'N') RETURN

C     Initialize DAP
      DAP = 0

C     Get planting date from ModuleData (stored by MGMTOPS)
      CALL GET('MGMT','YRPLT',YRPLT)

C     Only output after planting (same logic as PlantGro.OUT)
C     Don't write if planting date is invalid (<=0) or if current date is before planting
      IF (YRPLT .LE. 0 .OR. YRDOY .LT. YRPLT) RETURN

C     Calculate DAP (Days After Planting) instead of using DAS
C     This matches soil-based simulations where output starts from planting
      DAP = MAX(0, YRDOY - YRPLT)

C     Write on output frequency or on planting day
      IF (MOD(DAS,FROP) .EQ. 0 .OR. YRDOY .EQ. YRPLT) THEN

C       Get solution volume (already in mm) and temperature from ModuleData
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)
        CALL GET('HYDRO','TEMP',SOLTEMP)

C       Default values if not set
        IF (SOLVOL_MM .LT. 0.1) SOLVOL_MM = 100.0  ! Default 100 mm
        IF (SOLTEMP .LT. -50.0) SOLTEMP = 20.0

C       SOLVOL is already stored in mm in ModuleData (from HYDRO_WATER)
C       No conversion needed - use directly

C       Get date
        CALL YR_DOY(YRDOY, YEAR, DOY)

C       Write daily output (using DAP not DAS to match planting-based output)
        WRITE (NOUTSL,200) YEAR, DOY, DAP,
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,          ! mg/L
     &    UNO3, UNH4, UPO4, UK,                        ! kg/ha/d
     &    EC_CALC,                                     ! dS/m
     &    PH_CALC,                                     ! pH
     &    DO2_CALC, DO2_SAT,                           ! mg/L
     &    SOLVOL_MM, SOLTEMP                           ! mm, C

 200    FORMAT(1X,I4,1X,I3.3,1X,I5,
     &    4(1X,F7.1),                                  ! Concentrations
     &    4(1X,F7.2),                                  ! Uptake rates
     &    1X,F7.2,                                     ! EC
     &    1X,F7.2,                                     ! pH
     &    2(1X,F7.2),                                  ! DO2
     &    1X,F7.1,1X,F7.1)                             ! Vol (mm), Temp (C)

      ENDIF

C***********************************************************************
C***********************************************************************
C     SEASONAL OUTPUT - Close file
C***********************************************************************
      ELSEIF (DYNAMIC .EQ. SEASEND) THEN
C-----------------------------------------------------------------------
C     Only proceed if hydroponic mode and output detail requested
      IF (ISWHYDRO .NE. 'Y') RETURN
      IF (IDETW .EQ. 'N') RETURN

C     Write final output if not already written
      IF (MOD(DAS,FROP) .NE. 0) THEN
C       Get planting date from ModuleData
        CALL GET('MGMT','YRPLT',YRPLT)

C       Only output after planting (check if planting date is valid)
        IF (YRPLT .GT. 0 .AND. YRDOY .GE. YRPLT) THEN
C         Get solution volume (already in mm) and temperature from ModuleData
          CALL GET('HYDRO','SOLVOL',SOLVOL_MM)
          CALL GET('HYDRO','TEMP',SOLTEMP)

C         Default values if not set
          IF (SOLVOL_MM .LT. 0.1) SOLVOL_MM = 100.0  ! Default 100 mm
          IF (SOLTEMP .LT. -50.0) SOLTEMP = 20.0

C         SOLVOL is already stored in mm in ModuleData (from HYDRO_WATER)
C         No conversion needed - use directly

C         Get date
          CALL YR_DOY(YRDOY, YEAR, DOY)

C         Calculate DAP for final output
          DAP = MAX(0, YRDOY - YRPLT)

C         Write final day output
          WRITE (NOUTSL,200) YEAR, DOY, DAP,
     &      NO3_CONC, NH4_CONC, P_CONC, K_CONC,
     &      UNO3, UNH4, UPO4, UK,
     &      EC_CALC,
     &      PH_CALC,
     &      DO2_CALC, DO2_SAT,
     &      SOLVOL_MM, SOLTEMP
        ENDIF
      ENDIF

C     Close file
      IF (NOUTSL .GT. 0) THEN
        CLOSE (NOUTSL)
      ENDIF

C***********************************************************************
C***********************************************************************
C     END OF DYNAMIC IF CONSTRUCT
C***********************************************************************
      ENDIF

C-----------------------------------------------------------------------
      RETURN
      END SUBROUTINE OPSOL
C=======================================================================
