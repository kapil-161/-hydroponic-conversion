C=======================================================================
C  HYDRO_NUTRIENT, Subroutine
C
C  Hydroponic nutrient uptake using Michaelis-Menten kinetics
C  V = Vmax * [S] / (Km + [S])
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic nutrient uptake
C-----------------------------------------------------------------------
C  Called from: Nitrogen/nutrient uptake modules
C
C-----------------------------------------------------------------------

      SUBROUTINE HYDRO_NUTRIENT(
     &    CONTROL, ISWITCH,                    !Input
     &    PLTPOP, RTDEP, RWU_HYDRO,            !Input
     &    UNO3, UNH4, UPO4, UK,                !Output
     &    NO3_SOL, NH4_SOL, P_SOL, K_SOL)      !I/O - Solution conc.

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables
      REAL PLTPOP        ! Plant population (plants/m2)
      REAL RTDEP         ! Root depth (cm)
      REAL RWU_HYDRO     ! Water uptake (cm3/plant/day)

C     Output variables - uptake rates (kg/ha/day)
      REAL UNO3          ! Nitrate uptake
      REAL UNH4          ! Ammonium uptake
      REAL UPO4          ! Phosphate uptake
      REAL UK            ! Potassium uptake

C     Solution concentrations (mg/L) - updated by depletion
      REAL NO3_SOL       ! Nitrate in solution
      REAL NH4_SOL       ! Ammonium in solution
      REAL P_SOL         ! Phosphorus in solution
      REAL K_SOL         ! Potassium in solution

C     Local variables
      REAL SOLVOL        ! Solution volume (L) - saved between calls
      REAL SOLTEMP       ! Solution temperature (C)
      REAL NO3_CONC_INIT ! Initial NO3 concentration (mg/L)
      REAL NH4_CONC_INIT ! Initial NH4 concentration (mg/L)
      REAL P_CONC_INIT   ! Initial P concentration (mg/L)
      REAL K_CONC_INIT   ! Initial K concentration (mg/L)

C     Michaelis-Menten parameters (from hydroponic literature)
      REAL Vmax_NO3      ! Max uptake rate NO3 (mg/plant/day)
      REAL Vmax_NH4      ! Max uptake rate NH4 (mg/plant/day)
      REAL Vmax_P        ! Max uptake rate P (mg/plant/day)
      REAL Vmax_K        ! Max uptake rate K (mg/plant/day)

      REAL Km_NO3        ! Half-saturation constant NO3 (mg/L)
      REAL Km_NH4        ! Half-saturation constant NH4 (mg/L)
      REAL Km_P          ! Half-saturation constant P (mg/L)
      REAL Km_K          ! Half-saturation constant K (mg/L)

C     Uptake calculations
      REAL UNO3_plant    ! NO3 uptake per plant (mg/plant/day)
      REAL UNH4_plant    ! NH4 uptake per plant (mg/plant/day)
      REAL UP_plant      ! P uptake per plant (mg/plant/day)
      REAL UK_plant      ! K uptake per plant (mg/plant/day)

      REAL UPTAKE_FACTOR ! Scaling factor for crop growth stage
      REAL TEMP_FACTOR   ! Temperature correction factor (0-1)
      REAL DEPL_NO3, DEPL_NH4, DEPL_P, DEPL_K  ! Depletion rates
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)
      REAL GROWING_AREA  ! Growing area (m2) - for area conversions
      REAL VOL_AREA_RATIO ! Solution volume per unit area (L/m2)
      
C     Temperature parameters for nutrient uptake
C     Optimal temperature range for most crops: 20-25 C
C     Minimum: 10 C (very low uptake), Maximum: 35 C (uptake declines)
      REAL TEMP_OPT      ! Optimal temperature (C)
      REAL TEMP_MIN      ! Minimum temperature (C)
      REAL TEMP_MAX      ! Maximum temperature (C)
      REAL Q10           ! Q10 factor for temperature response
      
      INTEGER DYNAMIC

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize solution concentrations from ModuleData
C       If ModuleData values are available, use them; otherwise use passed parameters
C-----------------------------------------------------------------------
C       Try to get values from ModuleData first
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

C       If ModuleData values are missing or invalid, use passed parameters
        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default 1000 L if not set
          WRITE(*,*) 'HYDRO_NUTRIENT: Using default SOLVOL=',SOLVOL,'L'
        ENDIF

        IF (NO3_SOL .LT. 0.0) THEN
          WRITE(*,*) 'HYDRO_NUTRIENT: NO3_CONC not in ModuleData, using passed value'
        ENDIF
        IF (NH4_SOL .LT. 0.0) THEN
          WRITE(*,*) 'HYDRO_NUTRIENT: NH4_CONC not in ModuleData, using passed value'
        ENDIF
        IF (P_SOL .LT. 0.0) THEN
          WRITE(*,*) 'HYDRO_NUTRIENT: P_CONC not in ModuleData, using passed value'
        ENDIF
        IF (K_SOL .LT. 0.0) THEN
          WRITE(*,*) 'HYDRO_NUTRIENT: K_CONC not in ModuleData, using passed value'
        ENDIF

C       Get volume-to-area ratio from ModuleData or use default
C       This ratio depends on hydroponic system type:
C       NFT systems: ~0.5-2 L/m2, DWC: ~5-20 L/m2, Ebb/Flow: ~3-10 L/m2
        CALL GET('HYDRO','VOL_AREA_RATIO',VOL_AREA_RATIO)
        IF (VOL_AREA_RATIO .LT. 0.1) THEN
          VOL_AREA_RATIO = 2.0  ! Default for NFT systems (L/m2)
          WRITE(*,*) 'HYDRO_NUTRIENT: Using default VOL_AREA_RATIO=',
     &               VOL_AREA_RATIO,' L/m2'
        ENDIF

        WRITE(*,*) 'HYDRO_NUTRIENT INIT: Initialized concentrations:'
        WRITE(*,*) '  NO3=',NO3_SOL,' NH4=',NH4_SOL,
     &             ' P=',P_SOL,' K=',K_SOL,' SOLVOL=',SOLVOL
        WRITE(*,*) '  VOL_AREA_RATIO=',VOL_AREA_RATIO,' L/m2'

C       Michaelis-Menten parameters (from literature for NFT systems)
C       These are typical values - should be crop-specific ideally
        Vmax_NO3 = 50.0    ! mg N/plant/day (peak uptake)
        Vmax_NH4 = 30.0    ! mg N/plant/day
        Vmax_P   = 8.0     ! mg P/plant/day
        Vmax_K   = 60.0    ! mg K/plant/day

        Km_NO3   = 2.0     ! mg/L (half-saturation)
        Km_NH4   = 0.5     ! mg/L (higher affinity)
        Km_P     = 0.3     ! mg/L
        Km_K     = 1.0     ! mg/L

C       Temperature parameters for nutrient uptake
C       Based on typical hydroponic crop responses
        TEMP_OPT = 22.5    ! Optimal temperature (C) - midpoint of 20-25 C range
        TEMP_MIN = 10.0    ! Minimum temperature (C) - very low uptake below this
        TEMP_MAX = 32.0    ! Maximum temperature (C) - uptake declines above this
        Q10      = 2.0     ! Q10 factor (uptake doubles per 10 C increase)

        UNO3 = 0.0
        UNH4 = 0.0
        UPO4 = 0.0
        UK   = 0.0

        WRITE(*,200) NO3_SOL, NH4_SOL, P_SOL, K_SOL
 200    FORMAT(/,' Hydroponic Nutrient Module Initialized',
     &         /,'   Initial NO3-N : ',F8.2,' mg/L',
     &         /,'   Initial NH4-N : ',F8.2,' mg/L',
     &         /,'   Initial P     : ',F8.2,' mg/L',
     &         /,'   Initial K     : ',F8.2,' mg/L',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily nutrient uptake using Michaelis-Menten
C-----------------------------------------------------------------------
C       Get current solution concentrations from ModuleData
C       (These should have been updated from previous day's INTEGR phase)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

C       Get solution temperature from ModuleData
        CALL GET('HYDRO','TEMP',SOLTEMP)
        IF (SOLTEMP .LT. -50.0) THEN
C         If temperature not set, use default optimal temperature
          SOLTEMP = TEMP_OPT
        ENDIF

C       Calculate temperature correction factor for nutrient uptake
C       Uses a bell-shaped curve (trapezoidal) centered at optimal temperature
C       Factor = 1.0 at optimal temp, decreases linearly to 0 at min/max temps
C       This approach is similar to temperature_factor() in SAMUCA model
        IF (SOLTEMP .LE. TEMP_MIN .OR. SOLTEMP .GE. TEMP_MAX) THEN
C         Outside viable temperature range - minimal uptake
          TEMP_FACTOR = 0.05  ! 5% of maximum (prevents zero uptake)
        ELSEIF (SOLTEMP .GE. TEMP_OPT) THEN
C         Above optimal - linear decline to maximum temperature
C         Factor decreases from 1.0 at TEMP_OPT to 0.05 at TEMP_MAX
          TEMP_FACTOR = 1.0 - 0.95 * (SOLTEMP - TEMP_OPT) / 
     &                  (TEMP_MAX - TEMP_OPT)
          TEMP_FACTOR = MAX(0.05, TEMP_FACTOR)  ! Minimum 5%
        ELSE
C         Below optimal - linear increase from minimum to optimal
C         Factor increases from 0.05 at TEMP_MIN to 1.0 at TEMP_OPT
          TEMP_FACTOR = 0.05 + 0.95 * (SOLTEMP - TEMP_MIN) / 
     &                  (TEMP_OPT - TEMP_MIN)
          TEMP_FACTOR = MAX(0.05, MIN(1.0, TEMP_FACTOR))  ! Clamp to 0.05-1.0
        ENDIF

C       Growth stage factor (simplified - should link to plant model)
C       Early growth: 0.3, Peak growth: 1.0, Senescence: 0.5
        IF (RTDEP .LT. 20.0) THEN
          UPTAKE_FACTOR = 0.3    ! Seedling stage
        ELSEIF (RTDEP .LT. 50.0) THEN
          UPTAKE_FACTOR = 0.7    ! Vegetative growth
        ELSE
          UPTAKE_FACTOR = 1.0    ! Peak growth
        ENDIF

C       Michaelis-Menten equation: V = Vmax * [S] / (Km + [S])
C       Apply both growth stage factor and temperature factor to Vmax

C       NO3 uptake (mg/plant/day)
C       Vmax is modified by both growth stage and temperature
        UNO3_plant = (Vmax_NO3 * UPTAKE_FACTOR * TEMP_FACTOR * NO3_SOL) /
     &               (Km_NO3 + NO3_SOL)

C       NH4 uptake (mg/plant/day)
        UNH4_plant = (Vmax_NH4 * UPTAKE_FACTOR * TEMP_FACTOR * NH4_SOL) /
     &               (Km_NH4 + NH4_SOL)

C       P uptake (mg/plant/day)
        UP_plant = (Vmax_P * UPTAKE_FACTOR * TEMP_FACTOR * P_SOL) /
     &             (Km_P + P_SOL)

C       K uptake (mg/plant/day)
        UK_plant = (Vmax_K * UPTAKE_FACTOR * TEMP_FACTOR * K_SOL) /
     &             (Km_K + K_SOL)

C       Convert from mg/plant/day to kg/ha/day
C       Formula: mg/plant/day * plants/m2 * 10000 m2/ha * 1e-6 kg/mg
C              = mg/plant/day * plants/m2 * 0.01 kg/ha
        UNO3 = UNO3_plant * PLTPOP * 0.01
        UNH4 = UNH4_plant * PLTPOP * 0.01
        UPO4 = UP_plant   * PLTPOP * 0.01
        UK   = UK_plant   * PLTPOP * 0.01

C       Prevent negative concentrations
        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)
        UPO4 = MAX(0.0, UPO4)
        UK   = MAX(0.0, UK)

        WRITE(*,300) NO3_SOL, NH4_SOL, P_SOL, K_SOL,
     &               UNO3, UNH4, UPO4, UK, SOLTEMP, TEMP_FACTOR
 300    FORMAT(' HYDRO_NUTRIENT:',
     &         ' [NO3]=',F6.1,' [NH4]=',F6.1,' [P]=',F6.1,' [K]=',F6.1,
     &         ' Uptake: N=',F6.2,' P=',F6.2,' K=',F6.2,' kg/ha/d',
     &         ' Temp=',F5.1,'C Tfac=',F4.2)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution concentrations after uptake
C-----------------------------------------------------------------------
C       Get current solution concentrations from ModuleData
C       (These should match the values used in RATE phase)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

C       Ensure SOLVOL is initialized (retrieve from ModuleData if needed)
        IF (SOLVOL .LT. 1.0) THEN
          CALL GET('HYDRO','SOLVOL',SOLVOL)
          IF (SOLVOL .LT. 1.0) THEN
            SOLVOL = 1000.0  ! Default if not set
          ENDIF
        ENDIF

        IF (SOLVOL .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         Calculate depletion (mg/L)
C         Uptake in kg/ha/day -> mg/L/day
C         kg/ha/day * 1e6 mg/kg / (10000 m2/ha * VOL_AREA_RATIO L/m2)

C         Get volume-to-area ratio (should be set in initialization)
          CALL GET('HYDRO','VOL_AREA_RATIO',VOL_AREA_RATIO)
          IF (VOL_AREA_RATIO .LT. 0.1) THEN
            VOL_AREA_RATIO = 2.0  ! Fallback default
          ENDIF

C         Get growing area from experimental file (*FIELDS section)
C         If not set, fallback to calculating from solution volume
          CALL GET('HYDRO','AREA',GROWING_AREA)
          IF (GROWING_AREA .LT. 1.0) THEN
C           Fallback: calculate from solution volume using VOL_AREA_RATIO
            GROWING_AREA = SOLVOL / VOL_AREA_RATIO  ! m2
          ENDIF
          IF (GROWING_AREA .LT. 1.0) GROWING_AREA = 1.0
          
C         Calculate solution volume per hectare
C         VOL_PER_HA (L/ha) = SOLVOL (L) * 10000 (m2/ha) / GROWING_AREA (m2)
          VOL_PER_HA = SOLVOL * 10000.0 / GROWING_AREA  ! L/ha

          DEPL_NO3 = (UNO3 * 1.0E6) / VOL_PER_HA  ! mg/L depleted
          DEPL_NH4 = (UNH4 * 1.0E6) / VOL_PER_HA
          DEPL_P   = (UPO4 * 1.0E6) / VOL_PER_HA
          DEPL_K   = (UK * 1.0E6)   / VOL_PER_HA

C         Update solution concentrations
          NO3_SOL = MAX(0.0, NO3_SOL - DEPL_NO3)
          NH4_SOL = MAX(0.0, NH4_SOL - DEPL_NH4)
          P_SOL   = MAX(0.0, P_SOL - DEPL_P)
          K_SOL   = MAX(0.0, K_SOL - DEPL_K)

C         Store updated concentrations back to ModuleData
          CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
          CALL PUT('HYDRO','NH4_CONC',NH4_SOL)
          CALL PUT('HYDRO','P_CONC',P_SOL)
          CALL PUT('HYDRO','K_CONC',K_SOL)

          WRITE(*,400) DEPL_NO3, DEPL_NH4, DEPL_P, DEPL_K
 400      FORMAT(' Solution depletion:',
     &           ' dNO3=',F6.3,' dNH4=',F6.3,
     &           ' dP=',F6.3,' dK=',F6.3,' mg/L')
        ENDIF

      CASE (OUTPUT)
C       Output handled by main model
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_NUTRIENT
