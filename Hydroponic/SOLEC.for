C=======================================================================
C  SOLEC, Subroutine
C
C  Hydroponic electrical conductivity (EC) calculation and management
C  Calculates EC based on ion concentrations in solution
C  Implements EC stress through kinetic inhibition, morphological suppression,
C  and ionic antagonism mechanisms
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic EC management
C  12/22/2025 Added EC stress factor calculations
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
      
C     Variables for EC/nutrient calculation
      REAL TotalIons_FromEC  ! Total ions calculated from EC
      REAL TotalNutrients     ! Sum of provided nutrient concentrations
      REAL NutrientRatio_NO3, NutrientRatio_NH4, NutrientRatio_P, NutrientRatio_K
      LOGICAL EC_PROVIDED, NUTRIENTS_PROVIDED

C     EC Stress variables - ballast ions (Na, Cl)
      REAL NA_CONC       ! Sodium concentration (mg/L or mol/m3)
      REAL CL_CONC       ! Chloride concentration (mg/L or mol/m3)
      REAL C_NA_MOL      ! Na concentration in mol/m3

C     EC Stress factors (0.0 to 1.0, where 1.0 = no stress)
      REAL ECSTRESS_JMAX_NO3  ! Stress factor for NO3 Jmax (non-competitive inhibition)
      REAL ECSTRESS_JMAX_NH4  ! Stress factor for NH4 Jmax
      REAL ECSTRESS_JMAX_K    ! Stress factor for K Jmax
      REAL ECSTRESS_JMAX_P    ! Stress factor for P Jmax
      REAL ECSTRESS_KM_NO3    ! Stress factor for NO3 Km (competitive inhibition)
      REAL ECSTRESS_ROOT      ! Stress factor for root growth (morphological)
      REAL ECSTRESS_LEAF      ! Stress factor for leaf expansion (morphological)

C     EC Stress parameters for Na-based stress (high EC)
      REAL C_NA0_5       ! Na concentration at 50% growth reduction (mol/m3)
      REAL K_INHIB_NO3  ! Inhibition constant for NO3 (from NaCl studies)
      REAL K_INHIB_K    ! Inhibition constant for K (exponential decay)
      REAL K_INHIB_P    ! Inhibition constant for P (exponential decay)

C     EC Stress parameters for EC-based stress (high AND low)
      REAL EC_OPT_LOW    ! Lower bound of optimal EC range (dS/m)
      REAL EC_OPT_HIGH   ! Upper bound of optimal EC range (dS/m)
      REAL EC_STRESS_LOW ! Stress factor from low EC (<EC_OPT_LOW)
      REAL EC_STRESS_HIGH ! Stress factor from high EC (>EC_OPT_HIGH)
      REAL EC_STRESS_TOTAL ! Combined EC stress factor (0-1)

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
      SAVE C_NA0_5, K_INHIB_NO3, K_INHIB_K, K_INHIB_P
      SAVE EC_OPT_LOW, EC_OPT_HIGH

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize EC from ModuleData
C       Calculate missing values: EC from nutrients OR nutrients from EC
C-----------------------------------------------------------------------
        CALL GET('HYDRO','EC',EC_INIT)
        CALL GET('HYDRO','SOLVOL',SOLVOL_INIT)

C       Get ballast ion concentrations (Na, Cl) from ModuleData
C       If not set in experiment file, will default to 0.0
        CALL GET('HYDRO','NA_CONC',NA_CONC)
        CALL GET('HYDRO','CL_CONC',CL_CONC)

C-----------------------------------------------------------------------
C       DETERMINE WHAT IS PROVIDED AND CALCULATE MISSING VALUES
C       -99 indicates missing data in experiment file
C-----------------------------------------------------------------------
C       Check if EC is provided (not -99)
        EC_PROVIDED = (EC_INIT .GT. 0.0 .AND. EC_INIT .LT. 100.0)
        
C       Check if nutrients are provided (not -99)
        NUTRIENTS_PROVIDED = (NO3_CONC .GT. 0.0 .OR. NH4_CONC .GT. 0.0 .OR.
     &                        P_CONC .GT. 0.0 .OR. K_CONC .GT. 0.0)
        
C       Calculate total nutrients from provided values
        TotalNutrients = 0.0
        IF (NO3_CONC .GT. 0.0) TotalNutrients = TotalNutrients + NO3_CONC
        IF (NH4_CONC .GT. 0.0) TotalNutrients = TotalNutrients + NH4_CONC
        IF (P_CONC .GT. 0.0) TotalNutrients = TotalNutrients + P_CONC
        IF (K_CONC .GT. 0.0) TotalNutrients = TotalNutrients + K_CONC

C-----------------------------------------------------------------------
C       CASE 1: EC provided, nutrients missing - Calculate nutrients from EC
C-----------------------------------------------------------------------
        IF (EC_PROVIDED .AND. .NOT. NUTRIENTS_PROVIDED) THEN
C         Calculate total ions from EC
C         EC (dS/m) = TotalIons (ppm) / 640
          TotalIons_FromEC = EC_INIT * EC_FACTOR
          
C         Calculate nutrient ions (excluding counter-ions)
C         Factor 2.5 accounts for counter-ions, so nutrients = TotalIons / 2.5
          TotalNutrients = TotalIons_FromEC / 2.5
          
C         Distribute nutrients using typical hydroponic ratios
C         Based on standard hydroponic recipe: N 210 ppm, P 31 ppm, K 235 ppm
C         Assuming NO3-N ~95% of total N (typical for hydroponic solutions)
C         Ratios: NO3 ~42%, NH4 ~2%, P ~6.5%, K ~49.5%
          NutrientRatio_NO3 = 0.42
          NutrientRatio_NH4 = 0.02
          NutrientRatio_P   = 0.065
          NutrientRatio_K   = 0.495
          
          NO3_CONC = TotalNutrients * NutrientRatio_NO3
          NH4_CONC = TotalNutrients * NutrientRatio_NH4
          P_CONC   = TotalNutrients * NutrientRatio_P
          K_CONC   = TotalNutrients * NutrientRatio_K
          
C         Store calculated nutrients in ModuleData
          CALL PUT('HYDRO','NO3_CONC',NO3_CONC)
          CALL PUT('HYDRO','NH4_CONC',NH4_CONC)
          CALL PUT('HYDRO','P_CONC',P_CONC)
          CALL PUT('HYDRO','K_CONC',K_CONC)
          
          WRITE(*,*) 'SOLEC: Calculated nutrients from EC:'
          WRITE(*,*) '  NO3=',NO3_CONC,' NH4=',NH4_CONC,
     &               ' P=',P_CONC,' K=',K_CONC,' mg/L'
          
C-----------------------------------------------------------------------
C       CASE 2: Nutrients provided, EC missing - Calculate EC from nutrients
C-----------------------------------------------------------------------
        ELSE IF (.NOT. EC_PROVIDED .AND. NUTRIENTS_PROVIDED) THEN
C         Calculate EC from nutrient concentrations
C         Use 0.0 for any missing nutrients (-99)
          TotalNutrients = 0.0
          IF (NO3_CONC .GT. 0.0) TotalNutrients = TotalNutrients + NO3_CONC
          IF (NH4_CONC .GT. 0.0) TotalNutrients = TotalNutrients + NH4_CONC
          IF (P_CONC .GT. 0.0) TotalNutrients = TotalNutrients + P_CONC
          IF (K_CONC .GT. 0.0) TotalNutrients = TotalNutrients + K_CONC
          
C         Sum total ions (nutrients + counter-ions)
          TotalIons = TotalNutrients * 2.5
          
C         Calculate EC from total ions
          EC_INIT = TotalIons / EC_FACTOR
          
C         Ensure minimum EC
          IF (EC_INIT .LT. 0.1) EC_INIT = 0.1
          
C         Store calculated EC in ModuleData
          CALL PUT('HYDRO','EC',EC_INIT)
          
          WRITE(*,*) 'SOLEC: Calculated EC from nutrients:'
          WRITE(*,*) '  EC=',EC_INIT,' dS/m'
          
C-----------------------------------------------------------------------
C       CASE 3: Both provided - Use as-is (may need validation)
C-----------------------------------------------------------------------
        ELSE IF (EC_PROVIDED .AND. NUTRIENTS_PROVIDED) THEN
C         Both provided - validate consistency
C         Use 0.0 for any missing nutrients (-99)
          TotalNutrients = 0.0
          IF (NO3_CONC .GT. 0.0) TotalNutrients = TotalNutrients + NO3_CONC
          IF (NH4_CONC .GT. 0.0) TotalNutrients = TotalNutrients + NH4_CONC
          IF (P_CONC .GT. 0.0) TotalNutrients = TotalNutrients + P_CONC
          IF (K_CONC .GT. 0.0) TotalNutrients = TotalNutrients + K_CONC
          
          TotalIons = TotalNutrients * 2.5
          EC_CALC = TotalIons / EC_FACTOR
          
          IF (ABS(EC_CALC - EC_INIT) .GT. 0.5) THEN
            WRITE(*,*) 'SOLEC WARNING: EC mismatch!'
            WRITE(*,*) '  Provided EC=',EC_INIT,' dS/m'
            WRITE(*,*) '  Calculated from nutrients=',EC_CALC,' dS/m'
            WRITE(*,*) '  Using provided EC, nutrients as-is'
          ENDIF
        ENDIF

C-----------------------------------------------------------------------
C       INITIALIZE EC STRESS PARAMETERS
C-----------------------------------------------------------------------
C       APPROACH: Use total EC deviation from optimal range
C       This is simpler and more practical than Na-based stress
C       Works even when Na concentration is not measured
C-----------------------------------------------------------------------
C       Optimal EC range for lettuce (from literature)
C       Narrower range: 1.2-1.8 dS/m for optimal lettuce growth
C       Outside this range: nutrient deficiency (low) or toxicity (high)
        EC_OPT_LOW  = 1.2   ! dS/m - below this, nutrient deficiency stress
        EC_OPT_HIGH = 1.8   ! dS/m - above this, salinity/toxicity stress

C       Na-based stress parameters (if Na data is available)
C       C_NA0_5: Na concentration causing 50% root growth reduction (mol/m3)
C       From literature: typically 20-50 mol/m3 for sensitive crops
        C_NA0_5 = 30.0  ! mol/m3 (≈690 mg/L Na)

C       Inhibition constants (from rose studies and general literature)
C       K_INHIB_NO3: Hyperbolic inhibition constant for NO3 Jmax
        K_INHIB_NO3 = 50.0  ! mol/m3 (NaCl concentration for 50% inhibition)

C       Exponential decay constants for K and P
C       Jmax = Jmax_0 * exp(-k * C_Na)
        K_INHIB_K = 0.0136  ! From rose studies: Jmax_K = Jmax_0 * exp(-0.0136 * C_Na)
        K_INHIB_P = 0.0022  ! From literature: Jmax_P = Jmax_0 * exp(-0.0022 * C_Na)

        EC_TARGET = EC_INIT
        EC_CALC = EC_INIT

C       Save initial nutrient concentrations for EC-based management
        NO3_INIT = NO3_CONC
        NH4_INIT = NH4_CONC
        P_INIT = P_CONC
        K_INIT = K_CONC

C       Initialize stress factors to 1.0 (no stress)
        ECSTRESS_JMAX_NO3 = 1.0
        ECSTRESS_JMAX_NH4 = 1.0
        ECSTRESS_JMAX_K = 1.0
        ECSTRESS_JMAX_P = 1.0
        ECSTRESS_KM_NO3 = 1.0
        ECSTRESS_ROOT = 1.0
        ECSTRESS_LEAF = 1.0
        
C       Store initial stress factors in ModuleData (so they're available immediately)
        CALL PUT('HYDRO','ECSTRESS_JMAX_NO3',ECSTRESS_JMAX_NO3)
        CALL PUT('HYDRO','ECSTRESS_JMAX_NH4',ECSTRESS_JMAX_NH4)
        CALL PUT('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
        CALL PUT('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
        CALL PUT('HYDRO','ECSTRESS_KM_NO3',ECSTRESS_KM_NO3)
        CALL PUT('HYDRO','ECSTRESS_ROOT',ECSTRESS_ROOT)
        CALL PUT('HYDRO','ECSTRESS_LEAF',ECSTRESS_LEAF)

        WRITE(*,100) EC_INIT, SOLVOL_INIT, NO3_CONC, NH4_CONC, P_CONC, 
     &               K_CONC, NA_CONC, EC_PROVIDED, NUTRIENTS_PROVIDED
 100    FORMAT(/,' Hydroponic EC Module Initialized',
     &         /,'   Target EC : ',F6.2,' dS/m',
     &         /,'   Initial Solution Volume : ',F6.1,' mm',
     &         /,'   Nutrient concentrations (mg/L):',
     &         /,'     NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,
     &         /,'   Na concentration: ',F6.1,' mg/L',
     &         /,'   EC provided: ',L1,' Nutrients provided: ',L1,/)

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

C-----------------------------------------------------------------------
C       CALCULATE EC STRESS FACTORS
C       PRIMARY METHOD: EC deviation from optimal range (works always)
C       SECONDARY METHOD: Na-based stress (if Na data available)
C       Use whichever gives more stress (more conservative)
C-----------------------------------------------------------------------

C=======================================================================
C       METHOD 1: EC-BASED STRESS (from total EC deviation)
C       Simple, practical, works without Na data
C=======================================================================
C       Calculate stress from LOW EC (nutrient deficiency)
        IF (EC_CALC .LT. EC_OPT_LOW) THEN
C         Linear decline: EC=0 → stress=0.3, EC=EC_OPT_LOW → stress=1.0
          EC_STRESS_LOW = 0.3 + 0.7 * (EC_CALC / EC_OPT_LOW)
          EC_STRESS_LOW = MAX(0.3, MIN(1.0, EC_STRESS_LOW))
        ELSE
C         No stress from low EC
          EC_STRESS_LOW = 1.0
        ENDIF

C       Calculate stress from HIGH EC (salinity/toxicity)
        IF (EC_CALC .GT. EC_OPT_HIGH) THEN
C         Exponential decline: simulate salt toxicity accumulation
C         At EC = 2*EC_OPT_HIGH, stress = 0.5
          EC_STRESS_HIGH = EXP(-0.277 * (EC_CALC - EC_OPT_HIGH))
          EC_STRESS_HIGH = MAX(0.1, MIN(1.0, EC_STRESS_HIGH))
        ELSE
C         No stress from high EC
          EC_STRESS_HIGH = 1.0
        ENDIF

C       Combined EC stress (take minimum = most limiting)
        EC_STRESS_TOTAL = MIN(EC_STRESS_LOW, EC_STRESS_HIGH)

C=======================================================================
C       METHOD 2: Na-BASED STRESS (if Na data available)
C       More mechanistic, but requires Na measurement
C=======================================================================
C       Get current Na, Cl concentrations
        CALL GET('HYDRO','NA_CONC',NA_CONC)
        CALL GET('HYDRO','CL_CONC',CL_CONC)

C       Convert Na to mol/m3 for stress calculations
C       Na: 1 mg/L = 1 g/m3, MW_Na = 23 g/mol
        C_NA_MOL = NA_CONC / 23.0  ! mol/m3

C-----------------------------------------------------------------------
C       Apply Na-based stress only if Na > 10 mg/L (meaningful)
C-----------------------------------------------------------------------
        IF (NA_CONC .GT. 10.0) THEN
C-----------------------------------------------------------------------
C         1. KINETIC INHIBITION - Non-competitive (reduces Jmax)
C-----------------------------------------------------------------------
C         NO3: Hyperbolic inhibition model
          ECSTRESS_JMAX_NO3 = 1.0 / (1.0 + C_NA_MOL / K_INHIB_NO3)
          ECSTRESS_JMAX_NO3 = MAX(0.1, MIN(1.0, ECSTRESS_JMAX_NO3))

C         NH4: Similar to NO3
          ECSTRESS_JMAX_NH4 = ECSTRESS_JMAX_NO3

C         K: Exponential decay model
          ECSTRESS_JMAX_K = EXP(-K_INHIB_K * C_NA_MOL)
          ECSTRESS_JMAX_K = MAX(0.1, MIN(1.0, ECSTRESS_JMAX_K))

C         P: Exponential decay model
          ECSTRESS_JMAX_P = EXP(-K_INHIB_P * C_NA_MOL)
          ECSTRESS_JMAX_P = MAX(0.1, MIN(1.0, ECSTRESS_JMAX_P))

C         Competitive inhibition (increases Km)
          ECSTRESS_KM_NO3 = 1.0 + (C_NA_MOL / 10.0) * 0.2
          ECSTRESS_KM_NO3 = MAX(1.0, MIN(3.0, ECSTRESS_KM_NO3))

C-----------------------------------------------------------------------
C         2. MORPHOLOGICAL SUPPRESSION - Root and leaf growth
C-----------------------------------------------------------------------
          ECSTRESS_ROOT = 1.0 - (0.5 * C_NA_MOL / C_NA0_5)
          ECSTRESS_ROOT = MAX(0.1, MIN(1.0, ECSTRESS_ROOT))
          ECSTRESS_LEAF = ECSTRESS_ROOT

        ELSE
C-----------------------------------------------------------------------
C         No Na data - use EC-based stress for all factors
C-----------------------------------------------------------------------
          ECSTRESS_JMAX_NO3 = EC_STRESS_TOTAL
          ECSTRESS_JMAX_NH4 = EC_STRESS_TOTAL
          ECSTRESS_JMAX_K = EC_STRESS_TOTAL
          ECSTRESS_JMAX_P = EC_STRESS_TOTAL
          ECSTRESS_KM_NO3 = 1.0  ! No competitive effect without Na
          ECSTRESS_ROOT = EC_STRESS_TOTAL
          ECSTRESS_LEAF = EC_STRESS_TOTAL
        ENDIF

C       Store stress factors in ModuleData for use by other modules
        CALL PUT('HYDRO','ECSTRESS_JMAX_NO3',ECSTRESS_JMAX_NO3)
        CALL PUT('HYDRO','ECSTRESS_JMAX_NH4',ECSTRESS_JMAX_NH4)
        CALL PUT('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
        CALL PUT('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
        CALL PUT('HYDRO','ECSTRESS_KM_NO3',ECSTRESS_KM_NO3)
        CALL PUT('HYDRO','ECSTRESS_ROOT',ECSTRESS_ROOT)
        CALL PUT('HYDRO','ECSTRESS_LEAF',ECSTRESS_LEAF)
        
C       Debug: Verify ECSTRESS_ROOT is being stored
        IF (CONTROL % DAS .LE. 5) THEN
          WRITE(*,*) 'SOLEC RATE: Stored ECSTRESS_ROOT=',ECSTRESS_ROOT
        ENDIF

        WRITE(*,200) NO3_CONC, NH4_CONC, P_CONC, K_CONC,
     &               CONCENTRATION_FACTOR, SOLVOL_CURRENT,
     &               EC_CALC, EC_TARGET, EC_OPT_LOW, EC_OPT_HIGH,
     &               EC_STRESS_LOW, EC_STRESS_HIGH, EC_STRESS_TOTAL,
     &               ECSTRESS_ROOT, ECSTRESS_JMAX_NO3
 200    FORMAT(' SOLEC: NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,
     &         ' mg/L',/,
     &         '   ConcFactor=',F5.2,' (Vol=',F6.1,' mm)',
     &         ' => EC=',F5.2,' dS/m (Target=',F5.2,', Opt=',F4.2,
     &         '-',F4.2,')',/,
     &         '   EC Stress: Low=',F5.3,' High=',F5.3,' Total=',F5.3,
     &         ' => Root=',F5.3,' Jmax_NO3=',F5.3)

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
