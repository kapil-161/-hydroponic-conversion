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
      REAL WATER_ADD_MM   ! Water addition from irrigation (mm/d)
      REAL PLANT_UPTAKE_MM ! Plant water uptake (mm/d) - actual
      REAL PLANT_DEMAND_MM ! Plant water demand (mm/d) - from EP
      REAL MAX_WITHDRAWAL_MM ! Maximum withdrawal from depth (mm)
      REAL MAX_WITHDRAWAL_RATE_MM ! Maximum withdrawal rate (mm/d)
      REAL SOL_EVAP_MM    ! Solution evaporation (mm/d) - minimal
      REAL GROWING_AREA   ! Growing area (m2) - for conversion
      REAL IRRAMT         ! Irrigation amount (mm) - from irrigation module
      REAL WUF            ! Water uptake factor (demand/supply ratio, 0-1)
      REAL TRWUP_MM       ! Potential uptake in mm/d
      REAL TRWU_MM        ! Actual uptake in mm/d
      REAL SOLVOL_L       ! Temporary: solution volume in L (from ModuleData)
      INTEGER DYNAMIC

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

C       Get initial solution depth in mm from ModuleData
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)

C       Get growing area from experimental file (*FIELDS section)
        CALL GET('HYDRO','AREA',GROWING_AREA)

        WRITE(*,100) SOLVOL_MM
 100    FORMAT(/,' Hydroponic water module initialized',
     &         /,' Initial solution depth: ',F8.1,' mm',
     &         /,' Water supply: UNLIMITED from nutrient solution',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       PHASE 1: Calculate POTENTIAL water supply (like ROOTWU in soil)
C       Potential supply is based on solution depth and flow capacity
C-----------------------------------------------------------------------
        ES = 0.0     ! No soil evaporation in hydroponics
        TRWU = 0.0   ! Actual uptake calculated in INTEGR phase

C       Get current solution depth in mm
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)

C       Get growing area from experimental file (*FIELDS section)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       Calculate potential water supply from solution
C       In hydroponic systems with unlimited water, set TRWUP very high
C       to ensure plants are never water-stressed
C       Set to 100 cm/d which is >> any realistic ET demand
        TRWUP_MM = 100.0  ! mm/d (effectively unlimited)
        TRWUP = TRWUP_MM * 0.1  ! 10.0 cm/d (per unit area)

C       Store potential supply for INTEGR phase (in mm/d)
        CALL PUT('HYDRO','TRWUP_MM',TRWUP_MM)

        WRITE(*,200) SOLVOL_MM, TRWUP_MM, TRWUP
 200    FORMAT(' HYDRO_WATER RATE: SOLVOL=',F8.1,' mm',
     &         ' Potential supply=',F6.2,' mm/d (',F6.1,' cm/d)')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       PHASE 2: Calculate ACTUAL water uptake (like XTRACT in soil)
C       In hydroponics with unlimited water, actual = demand (no stress)
C-----------------------------------------------------------------------
C       Get current solution depth in mm
        CALL GET('HYDRO','SOLVOL',SOLVOL_MM)
        SOLVOL_PREV_MM = SOLVOL_MM

C       Get growing area from experimental file (*FIELDS section)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       DEMAND-BASED: Plant water demand from transpiration (EP)
C       EP is already in mm/d (rate per unit area)
        PLANT_DEMAND_MM = EP  ! mm/d

C       Store EP for nutrient uptake module (for mass flow calculations)
        CALL PUT('HYDRO','EP',EP)

C       In hydroponics with unlimited water: actual uptake = demand
C       No water stress, so WUF = 1.0
        TRWU_MM = PLANT_DEMAND_MM  ! mm/d (actual = demand)
        WUF = 1.0  ! No water stress in hydroponics

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

C       Get water addition from irrigation (if any)
C       IRRAMT is already in mm from irrigation module
        WATER_ADD_MM = 0.0
C       TODO: Get IRRAMT from irrigation module when available
C       WATER_ADD_MM = IRRAMT  ! Already in mm/d

C       Update solution depth
        SOLVOL_MM = SOLVOL_PREV_MM
     &         + WATER_ADD_MM                    ! Water addition (mm)
     &         - PLANT_UPTAKE_MM                 ! Plant uptake (mm)
     &         - SOL_EVAP_MM                     ! Evaporation (mm)

C       Store updated solution depth back to ModuleData (in mm)
        CALL PUT('HYDRO','SOLVOL',SOLVOL_MM)

        WRITE(*,300) SOLVOL_PREV_MM, TRWUP_MM, PLANT_DEMAND_MM, TRWU_MM,
     &               WUF, SOL_EVAP_MM, WATER_ADD_MM, SOLVOL_MM
 300    FORMAT(' HYDRO_WATER INTEGR:',
     &         ' SOLVOL_prev=',F8.1,' mm',
     &         ' Supply=',F6.2,' Demand=',F6.2,' mm/d',
     &         ' Actual=',F6.2,' mm/d (WUF=',F4.2,')',
     &         ' Evap=',F5.2,' Add=',F5.2,' mm/d',
     &         ' => SOLVOL_new=',F8.1,' mm')

      CASE (OUTPUT)
C       Output - handled by main model
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_WATER