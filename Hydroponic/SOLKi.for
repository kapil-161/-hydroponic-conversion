C=======================================================================
C  SOLKi, Subroutine
C
C  Hydroponic potassium uptake and solution management
C  Implements full Michaelis-Menten kinetics with dual-affinity systems
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic K management
C  01/30/2026 Enhanced with full M-M kinetics (HATS + LATS)
C-----------------------------------------------------------------------
C  Called from: CROPGRO nutrient uptake modules
C
C-----------------------------------------------------------------------

      SUBROUTINE SOLKi(
     &    CONTROL, ISWITCH,                    !Input
     &    FILECC, PLTPOP, RTDEP, KDEMAND,      !Input
     &    UK,                                  !Output - kg/ha/day
     &    K_SOL)                               !I/O - Solution conc. mg/L

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, ERROR, IGNORE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables
      CHARACTER*92 FILECC  ! Species file (for future use)
      REAL PLTPOP        ! Plant population (plants/m2)
      REAL RTDEP         ! Root depth (cm)
      REAL KDEMAND       ! K demand (kg/ha/day)
      REAL TEMP_SOL      ! Solution temperature (C) - from ModuleData

C     Output variables
      REAL UK            ! Potassium uptake (kg/ha/day)

C     Solution concentrations (mg/L)
      REAL K_SOL         ! Potassium in solution

C     Local variables
      REAL SOLVOL        ! Solution volume (mm) = (L/m2) - saved between calls
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL TRANSP_MM     ! Transpiration rate (mm/day)
      SAVE SOLVOL, SOLVOL_INIT

C-----------------------------------------------------------------------
C     FULL MICHAELIS-MENTEN KINETICS WITH DUAL-AFFINITY SYSTEMS
C     Reference: Epstein & Bloom (2005), Marschner (2012)
C
C     Potassium uptake via two distinct transporter systems:
C     1. HATS (High-Affinity Transport System) - K+ channels (AKT1)
C        - Active at low K concentrations (< 0.5 mM ~ 20 mg/L)
C        - Km ~ 20-50 μM (0.8-2.0 mg/L)
C        - Vmax ~ 10-30 μmol/g root DW/h
C
C     2. LATS (Low-Affinity Transport System) - K+ transporters (HAK/KUP)
C        - Active at high K concentrations (> 0.5 mM ~ 20 mg/L)
C        - Km ~ 5-10 mM (200-400 mg/L)
C        - Linear (non-saturable) at typical hydroponic concentrations
C-----------------------------------------------------------------------

C     HATS (High-Affinity Transport System) parameters
      REAL Vmax_HATS     ! Max uptake rate HATS (mg K/plant/day)
      REAL Km_HATS       ! Half-saturation constant HATS (mg/L)
      REAL Cmin_HATS     ! Min concentration for net uptake (mg/L)
      REAL UK_HATS       ! K uptake via HATS (mg/plant/day)

C     LATS (Low-Affinity Transport System) parameters
      REAL Vmax_LATS     ! Max uptake rate LATS (mg K/plant/day)
      REAL Km_LATS       ! Half-saturation constant LATS (mg/L)
      REAL UK_LATS       ! K uptake via LATS (mg/plant/day)

C     Temperature-dependent kinetics (Q10 model)
      REAL Q10_K         ! Q10 for K uptake (typically 1.5-2.5)
      REAL TEMP_REF      ! Reference temperature (C)
      REAL TEMP_FACTOR   ! Temperature effect on uptake rate
      REAL TEMP_MIN      ! Minimum temperature for uptake (C)
      REAL TEMP_OPT      ! Optimum temperature (C)
      REAL TEMP_MAX      ! Maximum temperature (C)

C     Initialize M-M parameters with DATA statements (Literature values)
      DATA Vmax_HATS /15.0/, Km_HATS /1.5/, Cmin_HATS /0.12/
      DATA Vmax_LATS /80.0/, Km_LATS /250.0/
      DATA Q10_K /2.0/, TEMP_REF /25.0/
      DATA TEMP_MIN /5.0/, TEMP_OPT /25.0/, TEMP_MAX /40.0/

C     Environmental stress factors
      REAL ECSTRESS_K    ! EC stress factor for K uptake
      REAL PH_AVAIL_K    ! pH-dependent K availability factor
      REAL PH_KM_FACTOR  ! pH effect on transporter affinity
      REAL K_SOL_EFF     ! Effective K concentration after pH adjustment

C     Root surface area and uptake capacity
      REAL ROOT_FACTOR   ! Root length/density effect on uptake capacity
      REAL ROOT_MASS     ! Estimated root mass (g/plant)
      REAL SPEC_UPTAKE   ! Specific uptake rate (mg/g root/day)

C     Uptake calculations
      REAL UK_plant      ! Total K uptake per plant (mg/plant/day)
      REAL UK_active     ! Active K uptake (kg/ha/day)
      REAL UK_passive    ! Passive K uptake via mass flow (kg/ha/day)
      REAL UK_potential  ! Potential K uptake (kg/ha/day)
      REAL UPTAKE_FACTOR ! Scaling factor for growth stage
      REAL DEPL_K        ! Depletion rate (mg/L)
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)

C     Plant demand from K_PLANT module (tissue-based, like N demand)
      REAL KDEMAND_USE   ! K demand from KTotDem or KDEMAND fallback

C     Water-nutrient coupling
      REAL WATER_FACTOR  ! Water availability factor (0-1)
      REAL FLOW_FACTOR   ! Solution circulation/flow factor (0-1)
      REAL MIN_SOLVOL    ! Minimum solution volume for uptake (mm)
      REAL CRITICAL_SOLVOL ! Critical solution volume threshold (mm)

C     Mass flow coefficient for K
      REAL MASS_FLOW_COEF ! Mass flow efficiency (fraction of transpiration)
      DATA MASS_FLOW_COEF /0.10/

C     SAVE all M-M parameters set in RUNINIT
      SAVE Vmax_HATS, Km_HATS, Cmin_HATS, Vmax_LATS, Km_LATS
      SAVE Q10_K, TEMP_REF, TEMP_MIN, TEMP_OPT, TEMP_MAX, MASS_FLOW_COEF

C     Species file reading variables (unused but kept for compatibility)
      INTEGER LUNCRP, ERR, LINC, ISECT, FOUND
      CHARACTER*6 SECTION
      CHARACTER*80 CHAR

      INTEGER DYNAMIC

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
C-----------------------------------------------------------------------
C       Initialize dual-affinity M-M parameters for K
C       Literature values from Epstein & Bloom (2005), Marschner (2012)
C-----------------------------------------------------------------------
C       HATS defaults (high-affinity transport system)
        Vmax_HATS = 15.0   ! mg K/plant/day (typical for lettuce)
        Km_HATS   = 1.5    ! mg/L (~40 μM)
C       LATS defaults (low-affinity transport system)
        Vmax_LATS = 80.0   ! mg K/plant/day
        Km_LATS   = 250.0  ! mg/L (~6.4 mM)

C       Set C_min for K (minimum concentration for net uptake)
C       Below C_min: efflux = influx, so net uptake = 0
C       Literature: 2-5 μM K (Barber 1984, Seiffert et al. 1995)
C       3 μM K = 0.117 mg/L (MW K = 39 g/mol)
        Cmin_HATS = 0.12     ! mg/L (~3 μM)

C       Temperature parameters
        Q10_K     = 2.0      ! Q10 for K uptake
        TEMP_REF  = 25.0     ! Reference temperature (C)
        TEMP_MIN  = 5.0      ! Minimum temperature (C)
        TEMP_OPT  = 25.0     ! Optimum temperature (C)
        TEMP_MAX  = 40.0     ! Maximum temperature (C)

C       Mass flow coefficient
C       K+ is highly mobile, similar to NO3-
C       Reflection coefficient ~ 0.10 (90% of K in solution enters roots)
        MASS_FLOW_COEF = 0.10

        UK = 0.0

        WRITE(*,100) Vmax_HATS, Km_HATS, Vmax_LATS, Km_LATS, Cmin_HATS
 100    FORMAT(/,' Hydroponic Potassium Module (Full M-M Kinetics)',
     &         /,'   HATS: Vmax=',F6.1,' mg/plant/d, Km=',F5.2,' mg/L',
     &         /,'   LATS: Vmax=',F6.1,' mg/plant/d, Km=',F6.1,' mg/L',
     &         /,'   Cmin: ',F6.3,' mg/L',/)

      CASE (SEASINIT)
C-----------------------------------------------------------------------
C       Initialize K concentration from ModuleData
C-----------------------------------------------------------------------
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

C       Store initial solution volume for water-nutrient coupling
        SOLVOL_INIT = SOLVOL

        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default 1000 mm (= L/m2)
          SOLVOL_INIT = SOLVOL
          WRITE(*,*) 'SOLKi: Using default SOLVOL=',SOLVOL,'mm'
        ENDIF

        IF (K_SOL .LT. 0.0) THEN
          K_SOL = 240.0  ! Default K concentration (mg/L)
          WRITE(*,*) 'SOLKi: Using default K_CONC=',K_SOL,'mg/L'
        ENDIF

        WRITE(*,150) K_SOL
 150    FORMAT(' SOLKi SEASINIT: Initial [K]=',F8.2,' mg/L')

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily K uptake using full M-M kinetics
C       K_SOL is passed as argument from calling routine (not retrieved here)
C-----------------------------------------------------------------------
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','EP',TRANSP_MM)
        CALL GET('HYDRO','TEMP_SOL',TEMP_SOL)
        IF (TRANSP_MM .LT. 0.0) TRANSP_MM = 0.0
        IF (K_SOL .LT. 0.0) K_SOL = 0.0
        IF (TEMP_SOL .LT. 1.0) TEMP_SOL = 25.0  ! Default 25C if not set

C-----------------------------------------------------------------------
C       WATER-NUTRIENT COUPLING
C-----------------------------------------------------------------------
        MIN_SOLVOL = SOLVOL_INIT * 0.10
        CRITICAL_SOLVOL = SOLVOL_INIT * 0.05

        IF (SOLVOL .LT. CRITICAL_SOLVOL) THEN
          UK = 0.0
          RETURN
        ENDIF

        IF (SOLVOL .GE. SOLVOL_INIT) THEN
          WATER_FACTOR = 1.0
        ELSE IF (SOLVOL .LE. MIN_SOLVOL) THEN
          WATER_FACTOR = 0.3
        ELSE
          WATER_FACTOR = 0.3 + 0.7 * (SOLVOL - MIN_SOLVOL) /
     &                   (SOLVOL_INIT - MIN_SOLVOL)
        ENDIF

C-----------------------------------------------------------------------
C       TEMPERATURE-DEPENDENT KINETICS (Cardinal temperature model)
C-----------------------------------------------------------------------
        IF (TEMP_SOL .LT. TEMP_MIN) THEN
          TEMP_FACTOR = 0.0
        ELSEIF (TEMP_SOL .LT. TEMP_OPT) THEN
C         Increasing phase: Q10 model
          TEMP_FACTOR = Q10_K ** ((TEMP_SOL - TEMP_REF) / 10.0)
        ELSEIF (TEMP_SOL .LT. TEMP_MAX) THEN
C         Decreasing phase: linear decline from peak at TEMP_OPT
C         Peak value from Q10 model at TEMP_OPT for continuity
          TEMP_FACTOR = Q10_K ** ((TEMP_OPT - TEMP_REF) / 10.0)
          TEMP_FACTOR = TEMP_FACTOR * (1.0 - (TEMP_SOL - TEMP_OPT) /
     &                  (TEMP_MAX - TEMP_OPT))
          TEMP_FACTOR = MAX(0.0, TEMP_FACTOR)
        ELSE
          TEMP_FACTOR = 0.0
        ENDIF

C       Root factor based on root depth
        IF (RTDEP .GT. 20.0) THEN
          ROOT_FACTOR = 1.0
        ELSEIF (RTDEP .GT. 5.0) THEN
          ROOT_FACTOR = 0.3 + 0.7 * (RTDEP - 5.0) / 15.0
        ELSE
          ROOT_FACTOR = 0.1 + 0.2 * RTDEP / 5.0
        ENDIF

C       Growth stage factor based on root depth
        IF (RTDEP .LT. 10.0) THEN
          UPTAKE_FACTOR = 0.2    ! Seedling stage
        ELSEIF (RTDEP .LT. 20.0) THEN
          UPTAKE_FACTOR = 0.5    ! Early vegetative
        ELSEIF (RTDEP .LT. 40.0) THEN
          UPTAKE_FACTOR = 0.8    ! Vegetative growth
        ELSE
          UPTAKE_FACTOR = 1.0    ! Peak growth
        ENDIF

C-----------------------------------------------------------------------
C       pH-DEPENDENT AVAILABILITY AND TRANSPORTER AFFINITY
C-----------------------------------------------------------------------
        CALL GET('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
        CALL GET('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR)
        IF (PH_AVAIL_K .LT. 0.01) PH_AVAIL_K = 1.0
        IF (PH_KM_FACTOR .LT. 0.1) PH_KM_FACTOR = 1.0

C       Effective K concentration = actual × pH availability
        K_SOL_EFF = K_SOL * PH_AVAIL_K

C-----------------------------------------------------------------------
C       EC STRESS FACTOR
C-----------------------------------------------------------------------
        CALL GET('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_K)
        IF (ECSTRESS_K .LT. 0.1) ECSTRESS_K = 1.0

C-----------------------------------------------------------------------
C       DUAL-AFFINITY MICHAELIS-MENTEN KINETICS (HATS + LATS)
C-----------------------------------------------------------------------
C       HATS: High-Affinity Transport System
C       Active mainly at low K concentrations (< 20 mg/L)
C       Modified M-M with Cmin threshold
        IF (K_SOL_EFF .GT. Cmin_HATS) THEN
          UK_HATS = (Vmax_HATS * TEMP_FACTOR * ECSTRESS_K *
     &              (K_SOL_EFF - Cmin_HATS)) /
     &              (Km_HATS * PH_KM_FACTOR + K_SOL_EFF - Cmin_HATS)
        ELSE
          UK_HATS = 0.0
        ENDIF

C       LATS: Low-Affinity Transport System
C       Active at high K concentrations (> 20 mg/L)
C       Standard M-M kinetics (no Cmin for LATS)
        IF (K_SOL_EFF .GT. 0.0) THEN
          UK_LATS = (Vmax_LATS * TEMP_FACTOR * ECSTRESS_K * K_SOL_EFF)/
     &              (Km_LATS * PH_KM_FACTOR + K_SOL_EFF)
        ELSE
          UK_LATS = 0.0
        ENDIF

C       Total active uptake per plant (mg/plant/day)
        UK_plant = (UK_HATS + UK_LATS) * ROOT_FACTOR * UPTAKE_FACTOR

C       Convert from mg/plant/day to kg/ha/day
C       kg/ha = mg/plant × plants/m² × 10000 m²/ha × 1e-6 kg/mg
        UK_active = UK_plant * PLTPOP * 0.01

C-----------------------------------------------------------------------
C       MASS FLOW COMPONENT (Passive uptake)
C       K+ is highly mobile in xylem, similar to NO3-
C       Mass flow = Transpiration × Concentration × Coefficient
C-----------------------------------------------------------------------
        IF (TRANSP_MM .GT. 0.0 .AND. K_SOL .GT. 0.0) THEN
C         Transpiration (mm/d) × 10000 m²/ha = L/ha/d
C         Mass flow (kg/ha/d) = L/ha/d × mg/L × 1e-6 kg/mg
          UK_passive = TRANSP_MM * 10000.0 * K_SOL * 1.0E-6 *
     &                 MASS_FLOW_COEF * ECSTRESS_K
        ELSE
          UK_passive = 0.0
        ENDIF

C-----------------------------------------------------------------------
C       TOTAL UPTAKE = Active (M-M) + Passive (Mass flow)
C       Limited by plant demand
C-----------------------------------------------------------------------
        UK_potential = UK_active + UK_passive

C       Get plant K demand from ModuleData (fallback to KDEMAND if not set)
        CALL GET('HYDRO','KTOTDEM',KDEMAND_USE)
        IF (KDEMAND_USE .LT. 1.E-9 .AND. KDEMAND .GT. 1.E-9) THEN
          KDEMAND_USE = KDEMAND
        ENDIF

C       Demand-based limitation (allow 20% luxury uptake)
        IF (KDEMAND_USE .GT. 1.E-9) THEN
          UK = MIN(UK_potential, KDEMAND_USE * 1.2)
        ELSE
C         Low demand: allow passive uptake only
          UK = UK_passive
        ENDIF

C       Ensure non-negative uptake
        UK = MAX(0.0, UK)

        WRITE(*,200) K_SOL, K_SOL_EFF, UK_HATS, UK_LATS,
     &               UK_active, UK_passive, UK, KDEMAND_USE
 200    FORMAT(' SOLKi M-M Kinetics:',
     &         /,'   [K]=',F6.1,' mg/L, [K]eff=',F6.1,' mg/L',
     &         /,'   HATS=',F5.2,' LATS=',F5.2,' mg/plant/d',
     &         /,'   Active=',F8.2,' Passive=',F8.3,' kg/ha/d',
     &         /,'   Total=',F8.2,' Demand=',F8.2,' kg/ha/d')

C       Store K uptake to ModuleData for output (Solution.OUT)
        CALL PUT('HYDRO','UK',UK)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution K concentration after uptake
C-----------------------------------------------------------------------
        CALL GET('HYDRO','K_CONC',K_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)

        IF (SOLVOL .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         SOLVOL is in mm (= L/m²), so L/ha = SOLVOL * 10000 m²/ha
          VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)

C         Calculate depletion (mg/L)
C         Depletion = Uptake (kg/ha) × 1e6 (mg/kg) / Volume (L/ha)
          DEPL_K = (UK * 1.0E6) / VOL_PER_HA

C         Update solution concentration
          K_SOL = MAX(0.0, K_SOL - DEPL_K)

          WRITE(*,300) DEPL_K, K_SOL
 300      FORMAT(' SOLKi depletion: dK=',F6.3,' mg/L',
     &           ' New [K]=',F6.1,' mg/L')
        ENDIF

C       Store updated concentration back to ModuleData
        CALL PUT('HYDRO','K_CONC',K_SOL)

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLKi
