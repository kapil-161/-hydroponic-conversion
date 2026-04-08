C=======================================================================
C  HYDRO_WATER, Subroutine
C
C  Hydroponic water module - tracks solution depth in mm
C  Updates solution depth based on water additions and plant uptake
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic water supply
C  12/22/2025 Updated to track dynamic solution volume
C  12/22/2025 Updated to use mm everywhere (removed liters)
C  02/03/2026 Added AUTO_VOL refill logic to maintain constant volume
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

C     Local variables - all in mm
      REAL SOLVOL_MM      ! Solution depth (mm)
      REAL SOLVOL_PREV_MM ! Previous day's solution depth (mm)
      REAL SOLVOL_INIT_MM ! Initial solution depth (mm) - for AUTO_VOL
      REAL WATER_ADD_MM   ! Water addition from irrigation (mm/d)
      REAL AUTO_VOL_R     ! Auto volume control flag (1.0=Y, 0.0=N)
C      REAL AUTO_CONC_R  ! removed - transpiration concentration now always applies
      REAL PLANT_UPTAKE_MM ! Plant water uptake (mm/d) - actual
      REAL PLANT_DEMAND_MM ! Plant water demand (mm/d) - from EP
      REAL SOL_EVAP_MM    ! Solution evaporation (mm/d) - minimal
      REAL GROWING_AREA   ! Growing area (m2) - for conversion
      REAL WUF            ! Water uptake factor (demand/supply ratio, 0-1)
      REAL TRWUP_MM       ! Potential uptake in mm/d
      REAL TRWU_MM        ! Actual uptake in mm/d
C     Concentration correction variables
      REAL CONC_FACTOR    ! Concentration factor from volume reduction (>= 1.0)
      REAL NO3_CONC, NH4_CONC, P_CONC, K_CONC  ! mg/L
      INTEGER DYNAMIC
      CHARACTER*1 IDETL   ! Detail level for output

C-----------------------------------------------------------------------
C     In hydroponic systems:
C     - Water is always available (no water stress)
C     - No soil evaporation (solution is contained)
C     - Roots take up water as needed (potential = actual)
C     - Solution depth changes with water additions and plant uptake
C     - All calculations use mm (1 mm = 1 L/m2)
C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize solution depth from ModuleData
C       ModuleData stores SOLVOL in mm directly from experiment file
C-----------------------------------------------------------------------
        TRWUP = 0.0
        TRWU  = 0.0
        ES    = 0.0

C       Get detail level for output
        IDETL = ISWITCH % IDETL

C       Get initial solution depth in mm from ModuleData
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)
        SOLVOL_INIT_MM = SOLVOL_MM  ! Save for AUTO_VOL refill

C       Store initial volume for AUTO_VOL refill target
        CALL PUT('HYDRO','SOLVOL_INIT',SOLVOL_INIT_MM)

C       Get growing area from experimental file (*FIELDS section)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       Get AUTO_VOL flag (1.0 = Y = constant volume, 0.0 = N = drift)
        CALL GET('HYDRO','AUTO_VOL',AUTO_VOL_R)
        IF (AUTO_VOL_R .LT. 0.0) AUTO_VOL_R = 0.0  ! Default to drift

        IF (IDETL .EQ. 'D') THEN
          WRITE(*,100) SOLVOL_MM, AUTO_VOL_R
 100      FORMAT(/,' Hydroponic water module initialized',
     &           /,' Initial solution depth: ',F8.1,' mm',
     &           /,' AUTO_VOL: ',F3.1,' (1.0=constant, 0.0=drift)',
     &           /,' Water supply: UNLIMITED from nutrient solution',/)
        ENDIF

      CASE (RATE)
C-----------------------------------------------------------------------
C       PHASE 1: Calculate POTENTIAL water supply (like ROOTWU in soil)
C       In hydroponics water is unlimited: TRWUP = previous day EP
C       EC stress propagates through ECSTRESS factors in SOLEC, not WUF
C-----------------------------------------------------------------------
        ES = 0.0     ! No soil evaporation in hydroponics
        TRWU = 0.0   ! Actual uptake calculated in INTEGR phase

C       Get detail level for output
        IDETL = ISWITCH % IDETL

C       Get current solution depth in mm
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)

C       Get growing area from experimental file (*FIELDS section)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       TRWUP = EP — unlimited supply, potential = demand
C       EP=0 at RATE call time; SPAM RATE overrides TRWU = EP at line 627
        TRWUP_MM = EP   ! mm/d
        TRWUP    = TRWUP_MM * 0.1  ! cm/d

C       Store potential supply for INTEGR phase (in mm/d)
        CALL PUT('HYDRO','TRWUP_MM',TRWUP_MM)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       PHASE 2: Calculate ACTUAL water uptake (like XTRACT in soil)
C       In hydroponics with unlimited water, actual = demand (no stress)
C-----------------------------------------------------------------------
C       Get detail level for output
        IDETL = ISWITCH % IDETL

C       Get current solution depth in mm
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)
        SOLVOL_PREV_MM = SOLVOL_MM

C       Get initial solution depth for AUTO_VOL refill target
        CALL GET('HYDRO','SOLVOL_INIT',SOLVOL_INIT_MM)

C       Get growing area from experimental file (*FIELDS section)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       DEMAND-BASED: Plant water demand from transpiration (EP)
C       EP is already in mm/d (rate per unit area)
        PLANT_DEMAND_MM = EP  ! mm/d

C       Store EP for nutrient uptake module (for mass flow calculations)
        CALL PUT('HYDRO','EP',EP)

C       In hydroponics, water is unlimited: actual uptake = full demand
C       EC stress acts on nutrient kinetics and growth via ECSTRESS factors
C       in SOLEC, not through the water uptake factor (WUF)
        TRWU_MM = PLANT_DEMAND_MM  ! Tank drained by full transpiration
        WUF = 1.0                   ! No water stress

C       Get potential supply from RATE phase for reporting only
        CALL GET('HYDRO','TRWUP_MM',TRWUP_MM)

C       Convert to cm/d for output (TRWU is in cm/d per unit area)
C       EP is already per unit area, so just convert mm to cm
        TRWU = TRWU_MM * 0.1  ! cm/d (per unit area)

C       Plant uptake in mm/d (for depth balance)
        PLANT_UPTAKE_MM = TRWU_MM  ! mm/d

C       Solution evaporation is minimal in closed systems
C       Estimate as 1% of transpiration (typical for NFT systems)
        SOL_EVAP_MM = PLANT_UPTAKE_MM * 0.01  ! mm/d
        ES = 0.0  ! No soil evaporation in hydroponics (output variable)

C       AUTO_VOL: Automatic volume control (1.0=refill to initial, 0.0=drift)
        CALL GET('HYDRO','AUTO_VOL',AUTO_VOL_R)
        IF (AUTO_VOL_R .LT. 0.0) AUTO_VOL_R = 0.0  ! Default to drift

        IF (AUTO_VOL_R .GT. 0.5) THEN
C         Refill to initial volume (not just maintain current)
C         This restores volume to SOLVOL_INIT_MM after losses
          WATER_ADD_MM = SOLVOL_INIT_MM - SOLVOL_PREV_MM
     &                 + PLANT_UPTAKE_MM + SOL_EVAP_MM
C         Ensure we don't remove water (only add)
          IF (WATER_ADD_MM .LT. 0.0) WATER_ADD_MM = 0.0
        ELSE
C         Volume drifts naturally
          WATER_ADD_MM = 0.0
        ENDIF

C       Update solution depth
        SOLVOL_MM = SOLVOL_PREV_MM
     &         + WATER_ADD_MM                    ! Water addition (mm)
     &         - PLANT_UPTAKE_MM                 ! Plant uptake (mm)
     &         - SOL_EVAP_MM                     ! Evaporation (mm)

C       CRITICAL: Enforce minimum solution volume to prevent crashes
C       When volume drops below minimum, plants should experience severe stress
C       but simulation should continue (growth stops, senescence may occur)
C       Minimum of 2.0 mm prevents numerical instability in nutrient calculations
        IF (SOLVOL_MM .LT. 5.0) THEN
          SOLVOL_MM = 5.0  ! Minimum 5.0 mm (5.0 L/m²)
          WRITE(*,'(A)') ' HYDRO_WATER WARNING: Solution volume at '//
     &                   'minimum - severe water/nutrient stress!'
        ENDIF

C       Store updated solution depth back to ModuleData (in mm)
        CALL PUT('HYDRO','SOLVOL',SOLVOL_MM)

C-----------------------------------------------------------------------
C       CONCENTRATION EFFECT FROM WATER LOSS
C       When volume decreases (transpiration in drift mode), dissolved
C       nutrients concentrate. HYDRO_WATER INTEGR runs before NUPTAK INTEGR
C       (SPAM before PLANT in LAND.for), so concentration factor is applied
C       first; NUPTAK then depletes using V_new. Both orderings give the same
C       final result: C_final = (C_old*V_old - uptake_mass) / V_new.
C       Always apply - feed-and-drift replenishment handled by SOLEC INTEGR
C-----------------------------------------------------------------------
        IF (SOLVOL_PREV_MM .GT. SOLVOL_MM .AND.
     &      SOLVOL_MM .GT. 0.0) THEN
          CONC_FACTOR = SOLVOL_PREV_MM / SOLVOL_MM

          CALL GET('HYDRO','NO3_CONC',NO3_CONC)
          CALL GET('HYDRO','NH4_CONC',NH4_CONC)
          CALL GET('HYDRO','P_CONC',P_CONC)
          CALL GET('HYDRO','K_CONC',K_CONC)

          NO3_CONC = NO3_CONC * CONC_FACTOR
          NH4_CONC = NH4_CONC * CONC_FACTOR
          P_CONC   = P_CONC   * CONC_FACTOR
          K_CONC   = K_CONC   * CONC_FACTOR

          CALL PUT('HYDRO','NO3_CONC',NO3_CONC)
          CALL PUT('HYDRO','NH4_CONC',NH4_CONC)
          CALL PUT('HYDRO','P_CONC',P_CONC)
          CALL PUT('HYDRO','K_CONC',K_CONC)
        ENDIF

        IF (IDETL .EQ. 'D') THEN
          WRITE(*,300) SOLVOL_PREV_MM, TRWUP_MM, PLANT_DEMAND_MM,
     &                 TRWU_MM, WUF, SOL_EVAP_MM, WATER_ADD_MM, SOLVOL_MM
 300      FORMAT(' HYDRO_WATER INTEGR:',
     &           ' SOLVOL_prev=',F8.1,' mm',
     &           ' Supply=',F6.2,' Demand=',F6.2,' mm/d',
     &           ' Actual=',F6.2,' mm/d (WUF=',F4.2,')',
     &           ' Evap=',F5.2,' Add=',F5.2,' mm/d',
     &           ' => SOLVOL_new=',F8.1,' mm')
        ENDIF

      CASE (OUTPUT)
C       Output - handled by main model
        CONTINUE

      CASE (SEASEND)
C-----------------------------------------------------------------------
C       End of season cleanup
C-----------------------------------------------------------------------
        IDETL = ISWITCH % IDETL
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)
        CALL GET('HYDRO','SOLVOL_INIT',SOLVOL_INIT_MM)

        IF (IDETL .EQ. 'D') THEN
          WRITE(*,400) SOLVOL_INIT_MM, SOLVOL_MM
 400      FORMAT(/,' HYDRO_WATER: Season ended',
     &           /,'   Initial volume: ',F8.1,' mm',
     &           /,'   Final volume:   ',F8.1,' mm',/)
        ENDIF

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_WATER