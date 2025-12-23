C=======================================================================
C  SOLPH, Subroutine
C
C  Hydroponic pH calculation and management
C  Tracks pH changes due to nutrient uptake and processes
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic pH management
C-----------------------------------------------------------------------
C  Called from: SPAM or main hydroponic routine
C
C-----------------------------------------------------------------------

      SUBROUTINE SOLPH(
     &    CONTROL, ISWITCH,                    !Input
     &    NO3_UPTAKE, NH4_UPTAKE,              !Input - kg/ha/day
     &    PH_CALC, PH_TARGET)                  !Output

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables - nutrient uptake rates (kg/ha/day)
      REAL NO3_UPTAKE    ! Nitrate uptake (tends to raise pH)
      REAL NH4_UPTAKE    ! Ammonium uptake (tends to lower pH)

C     Output variables
      REAL PH_CALC       ! Calculated pH
      REAL PH_TARGET     ! Target pH from initialization

C     Local variables
      REAL PH_INIT       ! Initial pH value
      REAL PH_CHANGE     ! Daily pH change
      REAL SOLVOL        ! Solution volume (L)
      REAL BUFFER_CAP    ! Buffering capacity (arbitrary units)

C     pH change factors
C     NH4 uptake releases H+ (lowers pH)
C     NO3 uptake releases OH- or takes up H+ (raises pH)
      REAL NH4_FACTOR    ! pH change per kg NH4-N uptake
      REAL NO3_FACTOR    ! pH change per kg NO3-N uptake

      INTEGER DYNAMIC
      SAVE PH_INIT, SOLVOL, PH_CHANGE, NH4_FACTOR, NO3_FACTOR, BUFFER_CAP

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize pH from ModuleData or use default
C-----------------------------------------------------------------------
        CALL GET('HYDRO','PH',PH_INIT)
        CALL GET('HYDRO','SOLVOL',SOLVOL)

        IF (PH_INIT .LT. 1.0 .OR. PH_INIT .GT. 14.0) THEN
          PH_INIT = 6.0  ! Default pH for hydroponic solution
          WRITE(*,*) 'SOLPH: Using default PH=',PH_INIT
        ENDIF

        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0
        ENDIF

        PH_TARGET = PH_INIT
        PH_CALC = PH_INIT
        PH_CHANGE = 0.0  ! Initialize pH change

C       Buffering capacity - larger volume = more stable pH
C       Also depends on solution buffering (Ca, Mg carbonates, etc.)
        BUFFER_CAP = SOLVOL / 100.0  ! Simplified buffering

C       pH change factors (simplified empirical values)
C       These would ideally be based on actual buffering chemistry
        NH4_FACTOR = -0.05 / BUFFER_CAP  ! NH4 uptake lowers pH
        NO3_FACTOR =  0.02 / BUFFER_CAP  ! NO3 uptake raises pH

C       Store initial pH values in ModuleData
        CALL PUT('HYDRO','PH',PH_CALC)

        WRITE(*,100) PH_INIT
 100    FORMAT(/,' Hydroponic pH Module Initialized',
     &         /,'   Target pH : ',F5.2,/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate pH change due to nutrient uptake
C-----------------------------------------------------------------------
C       pH changes based on differential uptake of NH4 vs NO3
        PH_CHANGE = (NH4_UPTAKE * NH4_FACTOR) +
     &              (NO3_UPTAKE * NO3_FACTOR)

C       Apply pH change (limited to realistic daily changes)
        PH_CHANGE = MAX(-0.5, MIN(0.5, PH_CHANGE))  ! Max ±0.5 pH units/day

        WRITE(*,200) NH4_UPTAKE, NO3_UPTAKE, PH_CHANGE
 200    FORMAT(' SOLPH: NH4 uptake=',F6.3,' NO3 uptake=',F6.3,
     &         ' => pH change=',F6.3)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update pH based on calculated change
C-----------------------------------------------------------------------
        PH_CALC = PH_CALC + PH_CHANGE

C       Keep pH within reasonable bounds
        IF (PH_CALC .LT. 3.0) PH_CALC = 3.0
        IF (PH_CALC .GT. 9.0) PH_CALC = 9.0

C       Store updated pH
        CALL PUT('HYDRO','PH',PH_CALC)

        WRITE(*,300) PH_CALC, PH_TARGET
 300    FORMAT(' SOLPH: Updated pH=',F5.2,' (Target=',F5.2,')')

C-----------------------------------------------------------------------
C       Optional: Implement pH adjustment/control
C       In real hydroponic systems, pH is actively controlled
C       This could be implemented as automatic adjustment when pH
C       deviates too far from target
C-----------------------------------------------------------------------
        IF (ABS(PH_CALC - PH_TARGET) .GT. 1.0) THEN
          WRITE(*,*) 'SOLPH WARNING: pH deviation >1.0 unit from target'
C         Could implement automatic pH correction here
C         For now, just issue warning
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLPH
