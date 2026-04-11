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

C     Feed-and-drift management
      REAL AUTO_CONC_R   ! Auto concentration flag (1.0=Y feed-and-drift, 0.0=N deplete)
      REAL FEED_SCALE    ! Scale factor to replenish concentrations to EC_OPT_HIGH

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

C     EC Stress parameters for Na-based stress (high EC) — read from SPE
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

C     EC threshold fractions and stress curve params — read from SPE
      REAL EC_FRAC_LOW   ! Fraction of EC_INIT for replenish trigger
      REAL EC_FRAC_HIGH  ! Fraction of EC_INIT for replenish target
      REAL EC_STRESS_MIN ! Minimum stress factor at EC=0 (low-EC curve)
      REAL EC_STRESS_SLP ! Slope of low-EC linear stress curve
      REAL EC_DECAY_K    ! Exponential decay constant for high-EC stress

C     Solution volume (for initialization only)
      REAL SOLVOL_INIT   ! Initial solution volume (mm)

C     Conversion factors for EC estimation
C     Approximate relationship: EC (dS/m) ~ TotalIons (ppm) / 640
C     This is a rough empirical relationship for hydroponic solutions
      REAL EC_FACTOR
      PARAMETER (EC_FACTOR = 640.0)

C     File reading for SPE parameters
      CHARACTER*30 FILEIO_LOC
      CHARACTER*12 FILEC_LOC
      CHARACTER*80 PATHCR_LOC, C80_TMP
      CHARACTER*92 FILECC_LOC
      CHARACTER*6  SECTION_LOC
      INTEGER LUNIO_LOC, LUNCRP_LOC, LINC_LOC, FOUND_LOC
      INTEGER PATHL_LOC, ERR_LOC, LNUM_TMP, ISECT_TMP
      CHARACTER*1  BLANK_LOC
      PARAMETER (BLANK_LOC = ' ')
      EXTERNAL GETLUN, ERROR, FIND, IGNORE

      INTEGER DYNAMIC
      SAVE EC_INIT, NO3_INIT, NH4_INIT, P_INIT, K_INIT, SOLVOL_INIT
      SAVE C_NA0_5, K_INHIB_NO3, K_INHIB_K, K_INHIB_P
      SAVE EC_OPT_LOW, EC_OPT_HIGH, AUTO_CONC_R
      SAVE EC_FRAC_LOW, EC_FRAC_HIGH, EC_STRESS_MIN, EC_STRESS_SLP
      SAVE EC_DECAY_K

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Read EC stress parameters from SPE file
C-----------------------------------------------------------------------
        FILEIO_LOC = CONTROL % FILEIO
        LUNIO_LOC  = CONTROL % LUNIO
        OPEN(LUNIO_LOC, FILE=FILEIO_LOC, STATUS='OLD', IOSTAT=ERR_LOC)
        IF (ERR_LOC .NE. 0) CALL ERROR('SOLEC ',ERR_LOC,FILEIO_LOC,0)
        READ(LUNIO_LOC,'(6(/),15X,A12,1X,A80)',IOSTAT=ERR_LOC)
     &       FILEC_LOC, PATHCR_LOC
        CLOSE(LUNIO_LOC)

        PATHL_LOC = INDEX(PATHCR_LOC, BLANK_LOC)
        IF (PATHL_LOC .LE. 1) THEN
          FILECC_LOC = FILEC_LOC
        ELSE
          FILECC_LOC = PATHCR_LOC(1:(PATHL_LOC-1)) // FILEC_LOC
        ENDIF

        CALL GETLUN('FILEC', LUNCRP_LOC)
        OPEN(LUNCRP_LOC, FILE=FILECC_LOC, STATUS='OLD', IOSTAT=ERR_LOC)
        IF (ERR_LOC .NE. 0) CALL ERROR('SOLEC ',42,FILECC_LOC,0)

        SECTION_LOC = '!*ECST'
        CALL FIND(LUNCRP_LOC, SECTION_LOC, LINC_LOC, FOUND_LOC)
        IF (FOUND_LOC .EQ. 0) CALL ERROR('SOLEC ',42,FILECC_LOC,0)
        LNUM_TMP = 0
        CALL IGNORE(LUNCRP_LOC, LNUM_TMP, ISECT_TMP, C80_TMP)
        READ(C80_TMP,*,IOSTAT=ERR_LOC) EC_FRAC_LOW, EC_FRAC_HIGH
        IF (ERR_LOC .NE. 0) CALL ERROR('SOLEC ',ERR_LOC,FILECC_LOC,0)
        CALL IGNORE(LUNCRP_LOC, LNUM_TMP, ISECT_TMP, C80_TMP)
        READ(C80_TMP,*,IOSTAT=ERR_LOC) EC_STRESS_MIN, EC_STRESS_SLP,
     &                                 EC_DECAY_K
        IF (ERR_LOC .NE. 0) CALL ERROR('SOLEC ',ERR_LOC,FILECC_LOC,0)
        CALL IGNORE(LUNCRP_LOC, LNUM_TMP, ISECT_TMP, C80_TMP)
        READ(C80_TMP,*,IOSTAT=ERR_LOC) C_NA0_5, K_INHIB_NO3,
     &                                 K_INHIB_K, K_INHIB_P
        IF (ERR_LOC .NE. 0) CALL ERROR('SOLEC ',ERR_LOC,FILECC_LOC,0)
        CLOSE(LUNCRP_LOC)

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

C       Get AUTO_CONC flag: Y=feed-and-drift, N=pure depletion
        CALL GET('HYDRO','AUTO_CONC',AUTO_CONC_R)
        IF (AUTO_CONC_R .LT. 0.5) AUTO_CONC_R = 0.0

C       Note: AUTO_EC removed - EC always drifts naturally

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
C       Optimal EC range: derived from EC_TARGET so the model works for any
C       experiment recipe, not just those near 1.5 dS/m.
C       Feed-and-drift: replenish when EC drops to 85% of target; refill to 115%.
C       Stress thresholds: below 70% of target is deficiency; above 200% is toxicity.
        EC_OPT_LOW  = EC_INIT * EC_FRAC_LOW   ! replenish trigger
        EC_OPT_HIGH = EC_INIT * EC_FRAC_HIGH  ! replenish target
        IF (EC_OPT_LOW  .LT. 0.1) EC_OPT_LOW  = 0.1
        IF (EC_OPT_HIGH .LT. 0.2) EC_OPT_HIGH = 0.2

C       Na stress params (C_NA0_5, K_INHIB_NO3, K_INHIB_K, K_INHIB_P) read from SPE

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
C       Calculate current EC based on ion concentrations.
C       GET from ModuleData (not argument list) so that fertilizer
C       additions made by HYDRO_FERT in INTEGR are visible here.
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

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
C         Linear decline: EC=0 → EC_STRESS_MIN, EC=EC_OPT_LOW → 1.0
          EC_STRESS_LOW = EC_STRESS_MIN + EC_STRESS_SLP *
     &                    (EC_CALC / EC_OPT_LOW)
          EC_STRESS_LOW = MAX(EC_STRESS_MIN, MIN(1.0, EC_STRESS_LOW))
        ELSE
C         No stress from low EC
          EC_STRESS_LOW = 1.0
        ENDIF

C       Calculate stress from HIGH EC (salinity/toxicity)
        IF (EC_CALC .GT. EC_OPT_HIGH) THEN
C         Exponential decline: simulate salt toxicity accumulation
          EC_STRESS_HIGH = EXP(-EC_DECAY_K * (EC_CALC - EC_OPT_HIGH))
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
     &               EC_CALC, EC_TARGET, EC_OPT_LOW, EC_OPT_HIGH,
     &               EC_STRESS_LOW, EC_STRESS_HIGH, EC_STRESS_TOTAL,
     &               ECSTRESS_ROOT, ECSTRESS_JMAX_NO3
 200    FORMAT(' SOLEC: NO3=',F6.1,' NH4=',F6.1,' P=',F6.1,' K=',F6.1,
     &         ' mg/L',
     &         ' => EC=',F5.2,' dS/m (Target=',F5.2,', Opt=',F4.2,
     &         '-',F4.2,')',/,
     &         '   EC Stress: Low=',F5.3,' High=',F5.3,' Total=',F5.3,
     &         ' => Root=',F5.3,' Jmax_NO3=',F5.3)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Re-read post-depletion concentrations from ModuleData
C       (HYDRO_NUTRIENT/SOLPi/SOLKi INTEGR have already run and depleted)
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

C       Recalculate EC from post-depletion concentrations
        TotalIons = (NO3_CONC + NH4_CONC + P_CONC + K_CONC) * 2.5
        EC_CALC = TotalIons / EC_FACTOR
        IF (EC_CALC .LT. 0.1) EC_CALC = 0.1

C-----------------------------------------------------------------------
C       FEED-AND-DRIFT MANAGEMENT (AUTO_CONC=Y)
C       When EC drops below lower optimum, replenish to upper optimum.
C       Simulates grower adding fresh nutrient solution to the reservoir.
C-----------------------------------------------------------------------
        IF (AUTO_CONC_R .GT. 0.5 .AND. EC_CALC .LT. EC_OPT_LOW) THEN
C         Scale initial concentrations to reach EC_OPT_HIGH.
C         Base the scale on the EC actually derived from initial nutrients
C         (not EC_INIT from the experiment file, which may differ from
C          the formula-derived EC due to unmeasured counter-ions).
          TotalIons = (NO3_INIT+NH4_INIT+P_INIT+K_INIT) * 2.5
          EC_RATIO = TotalIons / EC_FACTOR   ! EC formula gives for init conc
          IF (EC_RATIO .GT. 0.1) THEN
            FEED_SCALE = EC_OPT_HIGH / EC_RATIO
          ELSE
            FEED_SCALE = 1.0
          ENDIF
          NO3_CONC = NO3_INIT * FEED_SCALE
          NH4_CONC = NH4_INIT * FEED_SCALE
          P_CONC   = P_INIT   * FEED_SCALE
          K_CONC   = K_INIT   * FEED_SCALE
          CALL PUT('HYDRO','NO3_CONC',NO3_CONC)
          CALL PUT('HYDRO','NH4_CONC',NH4_CONC)
          CALL PUT('HYDRO','P_CONC',P_CONC)
          CALL PUT('HYDRO','K_CONC',K_CONC)

C         Recalculate EC after replenishment
          TotalIons = (NO3_CONC + NH4_CONC + P_CONC + K_CONC) * 2.5
          EC_CALC = TotalIons / EC_FACTOR

          WRITE(*,310) EC_OPT_LOW, EC_OPT_HIGH, EC_CALC
 310      FORMAT(' SOLEC: FEED EVENT - EC below',F4.2,' dS/m,',
     &           ' replenished to target',F4.2,' dS/m',
     &           ' => EC=',F5.2,' dS/m')
        ENDIF

C       Calculate EC deviation from target for monitoring
        EC_DEVIATION = EC_TARGET - EC_CALC

C       Update EC in ModuleData
        CALL PUT('HYDRO','EC',EC_CALC)

        WRITE(*,300) EC_CALC, EC_DEVIATION
 300    FORMAT(' SOLEC: Updated EC=',F6.2,' dS/m (Deviation=',
     &         F6.3,' from target)')

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLEC
