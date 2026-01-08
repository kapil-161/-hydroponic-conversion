C=======================================================================
C  SOLEC, Subroutine
C
C  Hydroponic electrical conductivity (EC) calculation and management
C  Calculates EC based on ion concentrations in solution
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic EC management
C-----------------------------------------------------------------------
C  Called from: SPAM or main hydroponic routine
C
C-----------------------------------------------------------------------

      SUBROUTINE SOLEC(
     &    CONTROL, ISWITCH,                    !Input
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,  !I/O - mg/L (adjusted for EC)
     &    EC_CALC, EC_TARGET)                  !Output - dS/m

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables - nutrient concentrations (mg/L)
      REAL NO3_CONC      ! Nitrate concentration
      REAL NH4_CONC      ! Ammonium concentration
      REAL P_CONC        ! Phosphorus concentration
      REAL K_CONC        ! Potassium concentration

C     Output variables
      REAL EC_CALC       ! Calculated EC (dS/m)
      REAL EC_TARGET     ! Target EC from initialization (dS/m)

C     Local variables
      REAL EC_INIT       ! Initial EC value (dS/m)
      REAL NO3_ppm       ! NO3-N in ppm
      REAL NH4_ppm       ! NH4-N in ppm
      REAL P_ppm         ! P in ppm
      REAL K_ppm         ! K in ppm
      REAL TotalIons     ! Total ion concentration (ppm)
      REAL NO3_INIT, NH4_INIT, P_INIT, K_INIT ! Initial nutrient concentrations
      REAL EC_RATIO, EC_DEVIATION  ! For EC management

C     Transpiration concentration variables
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL SOLVOL_CURRENT ! Current solution volume (mm)
      REAL CONCENTRATION_FACTOR ! Factor accounting for water loss (≥1.0)

C     Conversion factors for EC estimation
C     Approximate relationship: EC (dS/m) ~ TotalIons (ppm) / 640
C     This is a rough empirical relationship for hydroponic solutions
      REAL EC_FACTOR
      PARAMETER (EC_FACTOR = 640.0)

      INTEGER DYNAMIC
      SAVE EC_INIT, NO3_INIT, NH4_INIT, P_INIT, K_INIT, SOLVOL_INIT

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize EC from ModuleData or use default
C-----------------------------------------------------------------------
        CALL GET('HYDRO','EC',EC_INIT)
        CALL GET('HYDRO','SOLVOL',SOLVOL_INIT)

        IF (EC_INIT .LT. 0.1) THEN
          EC_INIT = 2.2  ! Default EC for typical hydroponic solution
          WRITE(*,*) 'SOLEC: Using default EC=',EC_INIT,' dS/m'
        ENDIF

        IF (SOLVOL_INIT .LT. 1.0) THEN
          SOLVOL_INIT = 100.0  ! Default solution depth (mm)
          WRITE(*,*) 'SOLEC: Using default SOLVOL=',SOLVOL_INIT,' mm'
        ENDIF

        EC_TARGET = EC_INIT
        EC_CALC = EC_INIT

C       Save initial nutrient concentrations for EC-based management
        NO3_INIT = NO3_CONC
        NH4_INIT = NH4_CONC
        P_INIT = P_CONC
        K_INIT = K_CONC

        WRITE(*,100) EC_INIT, SOLVOL_INIT, NO3_INIT, NH4_INIT, P_INIT, K_INIT
 100    FORMAT(/,' Hydroponic EC Module Initialized',
     &         /,'   Target EC : ',F6.2,' dS/m',
     &         /,'   Initial Solution Volume : ',F6.1,' mm',
     &         /,'   Target concentrations (mg/L):',
     &         /,'     NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate current EC based on ion concentrations
C       Account for transpiration concentration effect
C-----------------------------------------------------------------------
C       Get current solution volume to calculate concentration factor
        CALL GET('HYDRO','SOLVOL',SOLVOL_CURRENT)
        
C       Calculate concentration factor due to water loss
C       As plants transpire water, ions become more concentrated
C       CONCENTRATION_FACTOR = Initial_Volume / Current_Volume
C       Example: 100 mm initial → 80 mm current = 1.25× concentration
        IF (SOLVOL_CURRENT .GT. 0.1 .AND. SOLVOL_INIT .GT. 0.1) THEN
          CONCENTRATION_FACTOR = SOLVOL_INIT / SOLVOL_CURRENT
C         Limit to reasonable range (prevent division errors)
          CONCENTRATION_FACTOR = MAX(1.0, MIN(CONCENTRATION_FACTOR, 5.0))
        ELSE
          CONCENTRATION_FACTOR = 1.0  ! No concentration if volumes invalid
        ENDIF

C       Convert mg/L to ppm (equivalent for dilute solutions)
C       IMPORTANT: Nutrient concentrations in ModuleData are ALREADY in mg/L
C       of the CURRENT solution volume. When volume decreases, the depletion
C       calculations naturally account for concentration by calculating mg/L.
C       DO NOT apply CONCENTRATION_FACTOR here - it would double-count the effect.
        NO3_ppm = NO3_CONC
        NH4_ppm = NH4_CONC
        P_ppm   = P_CONC
        K_ppm   = K_CONC

C       Sum total dissolved ions
C       Note: This is simplified - actual EC also depends on Ca, Mg, S, etc.
C       For complete solution, multiply by factor to account for unmeasured ions
        TotalIons = (NO3_ppm + NH4_ppm + P_ppm + K_ppm) * 2.5
C       Factor 2.5 accounts for counter-ions (Ca, Mg, SO4, etc.)

C       Calculate EC from total ions
        EC_CALC = TotalIons / EC_FACTOR

C       Ensure minimum EC
        IF (EC_CALC .LT. 0.1) EC_CALC = 0.1

        WRITE(*,200) NO3_CONC, NH4_CONC, P_CONC, K_CONC,
     &               CONCENTRATION_FACTOR, SOLVOL_CURRENT,
     &               EC_CALC, EC_TARGET
 200    FORMAT(' SOLEC: NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,
     &         ' mg/L',/,
     &         '   ConcFactor=',F5.2,' (Vol=',F6.1,' mm)',
     &         ' => EC=',F5.2,' (Target=',F5.2,' dS/m)')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       EC TRACKING WITHOUT AUTOMATIC REPLENISHMENT
C       EC will drift naturally based on nutrient uptake and evaporation
C       This simulates a research hydroponic system without active EC control
C-----------------------------------------------------------------------
C       Calculate EC deviation from target for monitoring
        EC_DEVIATION = EC_TARGET - EC_CALC

C       AUTOMATIC REPLENISHMENT DISABLED
C       In commercial systems, nutrients would be replenished when EC drops
C       For this simulation, we let EC drift to observe natural dynamics
C       To re-enable automatic management, uncomment the code below:
C
C        IF (EC_CALC .LT. EC_TARGET * 0.90) THEN
C          EC_RATIO = EC_CALC / EC_TARGET
C          NO3_CONC = NO3_INIT
C          NH4_CONC = NH4_INIT
C          P_CONC   = P_INIT
C          K_CONC   = K_INIT
C          TotalIons = (NO3_CONC + NH4_CONC + P_CONC + K_CONC) * 2.5
C          EC_CALC = TotalIons / EC_FACTOR
C          IF (EC_CALC .LT. 0.1) EC_CALC = 0.1
C          CALL PUT('HYDRO','NO3_CONC',NO3_CONC)
C          CALL PUT('HYDRO','NH4_CONC',NH4_CONC)
C          CALL PUT('HYDRO','P_CONC',P_CONC)
C          CALL PUT('HYDRO','K_CONC',K_CONC)
C          WRITE(*,310) EC_RATIO, EC_CALC
C 310      FORMAT(' SOLEC: EC replenishment - Ratio=',F6.3,
C     &           ' New EC=',F6.2,' dS/m')
C        ENDIF

C       Update EC in ModuleData
        CALL PUT('HYDRO','EC',EC_CALC)

        WRITE(*,300) EC_CALC, EC_DEVIATION
 300    FORMAT(' SOLEC: Updated EC=',F6.2,' dS/m (Deviation from target=',
     &         F6.3,' dS/m)')

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLEC
