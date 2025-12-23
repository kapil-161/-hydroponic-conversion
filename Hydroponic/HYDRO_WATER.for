C=======================================================================
C  HYDRO_WATER, Subroutine
C
C  Hydroponic water module - tracks solution volume balance
C  Updates SOLVOL based on water additions and plant uptake
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic water supply
C  12/22/2025 Updated to track dynamic solution volume
C-----------------------------------------------------------------------
C  Called from: SPAM
C
C-----------------------------------------------------------------------

      SUBROUTINE HYDRO_WATER(
     &    CONTROL, ISWITCH,                    !Input
     &    EP,                                  !Input - plant transpiration (mm/d)
     &    TRWUP, TRWU, ES)                    !Output

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables
      REAL EP         ! Plant transpiration (mm/d) - from SPAM

C     Output variables
      REAL TRWUP      ! Total potential root water uptake (cm/d)
      REAL TRWU       ! Total actual root water uptake (cm/d)
      REAL ES         ! Actual soil evaporation (mm/d)

C     Local variables
      REAL SOLVOL        ! Solution volume (L)
      REAL SOLVOL_PREV   ! Previous day's solution volume (L)
      REAL WATER_ADD     ! Water addition from irrigation (L/d)
      REAL PLANT_UPTAKE  ! Plant water uptake (L/d) - actual
      REAL PLANT_DEMAND  ! Plant water demand (L/d) - from EP
      REAL AVAILABLE_SUPPLY ! Available water supply (L/d)
      REAL MAX_WITHDRAWAL ! Maximum withdrawal from volume (L)
      REAL MAX_WITHDRAWAL_RATE ! Maximum withdrawal rate (L/d)
      REAL SOL_EVAP      ! Solution evaporation (L/d) - minimal
      REAL GROWING_AREA  ! Growing area (m2) - for conversion
      REAL IRRAMT        ! Irrigation amount (mm) - from irrigation module
      REAL WUF           ! Water uptake factor (demand/supply ratio, 0-1)
      REAL TRWUP_L       ! Potential uptake in L/d (for internal calc)
      REAL TRWU_L        ! Actual uptake in L/d (for internal calc)
      INTEGER DYNAMIC

C-----------------------------------------------------------------------
C     In hydroponic systems:
C     - Water is always available (no water stress)
C     - No soil evaporation (solution is contained)
C     - Roots take up water as needed (potential = actual)
C     - Solution volume changes with water additions and plant uptake
C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize solution volume from ModuleData
C-----------------------------------------------------------------------
        TRWUP = 0.0
        TRWU  = 0.0
        ES    = 0.0

C       Get initial solution volume from ModuleData
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default 1000 L if not set
          CALL PUT('HYDRO','SOLVOL',SOLVOL)
        ENDIF

C       Growing area will be calculated from solution volume
C       (calculated in INTEGR phase based on SOLVOL)

        WRITE(*,100) SOLVOL
 100    FORMAT(/,' Hydroponic water module initialized',
     &         /,' Initial solution volume: ',F8.1,' L',
     &         /,' Water supply: UNLIMITED from nutrient solution',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       PHASE 1: Calculate POTENTIAL water supply (like ROOTWU in soil)
C       Potential supply is based on solution volume and flow capacity
C-----------------------------------------------------------------------
        ES = 0.0     ! No soil evaporation in hydroponics
        TRWU = 0.0   ! Actual uptake calculated in INTEGR phase

C       Get current solution volume
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default if not set
        ENDIF

C       Calculate growing area from solution volume
C       In NFT systems, solution volume per m2 is typically 2-5 L/m2
C       Using 2 L/m2: GROWING_AREA (m2) = SOLVOL (L) / 2.0 (L/m2)
        GROWING_AREA = SOLVOL / 2.0  ! m2 (2 L/m2 - solution in channels only)
        IF (GROWING_AREA .LT. 1.0) GROWING_AREA = 1.0  ! Minimum 1 m2

C       Calculate potential water supply from solution
C       In hydroponic systems, potential supply is limited by:
C       1. Solution volume (can't withdraw more than available)
C       2. Maximum withdrawal rate (flow capacity of system)
C       Potential = minimum of available volume and max withdrawal rate
        MAX_WITHDRAWAL = MAX(0.0, SOLVOL - 100.0)  ! L (available, minus reserve)
        MAX_WITHDRAWAL_RATE = SOLVOL * 0.5  ! L/d (50% per day max - flow limit)
        TRWUP_L = MIN(MAX_WITHDRAWAL, MAX_WITHDRAWAL_RATE)  ! L/d (potential supply)

C       Convert to cm/d for compatibility with DSSAT (TRWUP is in cm/d)
C       1 L = 0.1 cm over 1 m2, but we need per-hectare basis
C       TRWUP (cm/d) = TRWUP_L (L/d) * 10 (cm/L) * (10000 m2/ha / GROWING_AREA m2)
C       Simplified: TRWUP = TRWUP_L * 10 * 10000 / GROWING_AREA
        IF (GROWING_AREA .GT. 0.0) THEN
          TRWUP = TRWUP_L * 10.0 * 10000.0 / GROWING_AREA  ! cm/d
        ELSE
          TRWUP = 999.0  ! Unlimited if no area
        ENDIF

C       Store potential supply for INTEGR phase
        CALL PUT('HYDRO','TRWUP_L',TRWUP_L)

        WRITE(*,200) SOLVOL, TRWUP_L, TRWUP
 200    FORMAT(' HYDRO_WATER RATE: SOLVOL=',F8.1,' L',
     &         ' Potential supply=',F6.2,' L/d (',F6.1,' cm/d)')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       PHASE 2: Calculate ACTUAL water uptake (like XTRACT in soil)
C       Actual uptake = MIN(potential supply, demand, available water)
C-----------------------------------------------------------------------
C       Get current solution volume
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default if not set
        ENDIF
        SOLVOL_PREV = SOLVOL

C       Get potential supply from RATE phase
        CALL GET('HYDRO','TRWUP_L',TRWUP_L)
        IF (TRWUP_L .LT. 0.1) THEN
          TRWUP_L = SOLVOL * 0.5  ! Fallback if not set
        ENDIF

C       Calculate growing area (same as RATE phase)
        GROWING_AREA = SOLVOL / 2.0  ! m2
        IF (GROWING_AREA .LT. 1.0) GROWING_AREA = 1.0

C       DEMAND-BASED: Calculate plant water demand from transpiration (EP)
C       EP is in mm/d per hectare (standard DSSAT unit)
C       Convert to L/d: EP (mm/d/ha) * GROWING_AREA (m2) / 10000 (m2/ha) = L/d
        PLANT_DEMAND = EP * GROWING_AREA / 10000.0  ! L/d (demand)

C       Calculate water uptake factor (WUF) - similar to soil systems
C       WUF = demand / supply ratio (0-1)
C       If demand <= supply: WUF = demand/supply (limited by demand)
C       If demand > supply: WUF = 1.0 (limited by supply)
        IF (TRWUP_L .GT. 0.0) THEN
          IF (PLANT_DEMAND .LE. TRWUP_L) THEN
            WUF = PLANT_DEMAND / TRWUP_L  ! Demand-limited
          ELSE
            WUF = 1.0  ! Supply-limited
          ENDIF
        ELSE
          WUF = 0.0  ! No supply available
        ENDIF

C       ACTUAL UPTAKE: Scale potential supply by demand factor
C       Then limit by available volume (safety check)
        TRWU_L = TRWUP_L * WUF  ! L/d (scaled by demand)

C       Final safety check: Can't withdraw more than available volume
        MAX_WITHDRAWAL = MAX(0.0, SOLVOL - 100.0)  ! L (available, minus reserve)
        TRWU_L = MIN(TRWU_L, MAX_WITHDRAWAL)  ! L/d (final actual uptake)

C       Convert to cm/d for output (TRWU is in cm/d)
        IF (GROWING_AREA .GT. 0.0) THEN
          TRWU = TRWU_L * 10.0 * 10000.0 / GROWING_AREA  ! cm/d
        ELSE
          TRWU = 0.0
        ENDIF

C       Plant uptake in L/d (for volume balance)
        PLANT_UPTAKE = TRWU_L  ! L/d

C       Solution evaporation is minimal in closed systems
C       Estimate as 1% of transpiration (typical for NFT systems)
        SOL_EVAP = PLANT_UPTAKE * 0.01  ! L/d
        ES = 0.0  ! No soil evaporation in hydroponics (output variable)

C       Get water addition from irrigation (if any)
C       For now, assume no automatic irrigation
C       Water additions would come from:
C       1. Irrigation schedule (IRRAMT from IRRIG module)
C       2. Fertilizer solution additions
C       3. Manual top-ups
        WATER_ADD = 0.0
C       TODO: Get IRRAMT from irrigation module when available
C       WATER_ADD = IRRAMT * GROWING_AREA  ! Convert mm to L

C       Update solution volume
        SOLVOL = SOLVOL_PREV
     &         + WATER_ADD                    ! Water addition
     &         - PLANT_UPTAKE                 ! Plant uptake
     &         - SOL_EVAP                     ! Evaporation

C       Ensure solution volume doesn't go negative or too low
        IF (SOLVOL .LT. 100.0) THEN
C         Minimum volume: 100 L (10% of initial)
C         In real systems, this would trigger automatic refill
          WRITE(*,*) 'HYDRO_WATER WARNING: SOLVOL low (',SOLVOL,
     &               ' L), should refill solution'
          SOLVOL = MAX(100.0, SOLVOL)
        ENDIF

C       Store updated solution volume back to ModuleData
        CALL PUT('HYDRO','SOLVOL',SOLVOL)

        WRITE(*,300) SOLVOL_PREV, TRWUP_L, PLANT_DEMAND, TRWU_L,
     &               WUF, SOL_EVAP, WATER_ADD, SOLVOL
 300    FORMAT(' HYDRO_WATER INTEGR:',
     &         ' SOLVOL_prev=',F8.1,' L',
     &         ' Supply=',F6.2,' Demand=',F6.2,' L/d',
     &         ' Actual=',F6.2,' L/d (WUF=',F4.2,')',
     &         ' Evap=',F5.2,' Add=',F5.2,
     &         ' => SOLVOL_new=',F8.1,' L')

      CASE (OUTPUT)
C       Output - handled by main model
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_WATER
