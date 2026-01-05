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

C     Conversion factors for EC estimation
C     Approximate relationship: EC (dS/m) ~ TotalIons (ppm) / 640
C     This is a rough empirical relationship for hydroponic solutions
      REAL EC_FACTOR
      PARAMETER (EC_FACTOR = 640.0)

      INTEGER DYNAMIC
      SAVE EC_INIT, NO3_INIT, NH4_INIT, P_INIT, K_INIT

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize EC from ModuleData or use default
C-----------------------------------------------------------------------
        CALL GET('HYDRO','EC',EC_INIT)

        IF (EC_INIT .LT. 0.1) THEN
          EC_INIT = 2.2  ! Default EC for typical hydroponic solution
          WRITE(*,*) 'SOLEC: Using default EC=',EC_INIT,' dS/m'
        ENDIF

        EC_TARGET = EC_INIT
        EC_CALC = EC_INIT

C       Save initial nutrient concentrations for EC-based management
        NO3_INIT = NO3_CONC
        NH4_INIT = NH4_CONC
        P_INIT = P_CONC
        K_INIT = K_CONC

        WRITE(*,100) EC_INIT, NO3_INIT, NH4_INIT, P_INIT, K_INIT
 100    FORMAT(/,' Hydroponic EC Module Initialized',
     &         /,'   Target EC : ',F6.2,' dS/m',
     &         /,'   Target concentrations (mg/L):',
     &         /,'     NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate current EC based on ion concentrations
C-----------------------------------------------------------------------
C       Convert mg/L to ppm (equivalent for dilute solutions)
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
     &               EC_CALC, EC_TARGET
 200    FORMAT(' SOLEC: NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,
     &         ' => EC=',F5.2,' (Target=',F5.2,' dS/m)')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       EC-BASED NUTRIENT MANAGEMENT
C       Commercial hydroponic systems maintain target EC by adding
C       concentrated nutrient solution when EC drops below target
C-----------------------------------------------------------------------
C       Calculate EC deviation from target
        EC_DEVIATION = EC_TARGET - EC_CALC

C       If EC drops below 90% of target, replenish nutrients to target levels
C       In commercial hydroponics, growers add concentrated nutrient solution
C       or replace solution entirely to maintain target EC
        IF (EC_CALC .LT. EC_TARGET * 0.90) THEN
C         Save old EC to calculate replenishment ratio
          EC_RATIO = EC_CALC / EC_TARGET

C         Restore all concentrations to initial target levels
C         This simulates changing out or replenishing the nutrient solution
          NO3_CONC = NO3_INIT
          NH4_CONC = NH4_INIT
          P_CONC   = P_INIT
          K_CONC   = K_INIT

C         Recalculate EC with adjusted concentrations
          TotalIons = (NO3_CONC + NH4_CONC + P_CONC + K_CONC) * 2.5
          EC_CALC = TotalIons / EC_FACTOR
          IF (EC_CALC .LT. 0.1) EC_CALC = 0.1

C         Update concentrations in ModuleData
          CALL PUT('HYDRO','NO3_CONC',NO3_CONC)
          CALL PUT('HYDRO','NH4_CONC',NH4_CONC)
          CALL PUT('HYDRO','P_CONC',P_CONC)
          CALL PUT('HYDRO','K_CONC',K_CONC)

          WRITE(*,310) EC_RATIO, EC_CALC
 310      FORMAT(' SOLEC: EC replenishment - Ratio=',F6.3,
     &           ' New EC=',F6.2,' dS/m')
        ENDIF

C       Update EC in ModuleData
        CALL PUT('HYDRO','EC',EC_CALC)

        WRITE(*,300) EC_CALC
 300    FORMAT(' SOLEC: Updated EC=',F6.2,' dS/m')

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLEC
