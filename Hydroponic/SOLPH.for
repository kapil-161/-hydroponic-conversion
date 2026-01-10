C=======================================================================
C  SOLPH, Subroutine
C
C  Hydroponic pH calculation and management
C  Tracks pH changes due to nutrient uptake and processes
C  Uses stoichiometric H+ production/consumption and accounts for
C  transpiration concentration effects
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic pH management
C  01/08/2026 Improved: Stoichiometric H+ calculation, transpiration effect
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

C     pH stress variables
      REAL PH_OPT_LOW    ! Optimal pH lower bound
      REAL PH_OPT_HIGH   ! Optimal pH upper bound
      REAL PH_STRESS_LOW ! Stress factor for low pH (0-1)
      REAL PH_STRESS_HIGH ! Stress factor for high pH (0-1)
      REAL PH_STRESS_TOTAL ! Combined pH stress (0-1)

C     Local variables
      REAL PH_INIT       ! Initial pH value
      REAL PH_CHANGE     ! Daily pH change
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL SOLVOL_CURRENT ! Current solution volume (mm)
      REAL CONCENTRATION_FACTOR ! Factor accounting for water loss (≥1.0)
      REAL AREA          ! Growing area (m2)
      
C     Stoichiometric H+ production/consumption
C     NH4+ uptake: NH4+ → N (in plant) + H+ (released) - 1 mol H+ per mol NH4-N
C     NO3- uptake: NO3- + H+ → N (in plant) - consumes 1 mol H+ per mol NO3-N
      REAL MW_N          ! Nitrogen molecular weight (g/mol)
      REAL H_PRODUCTION  ! H+ production from NH4 uptake (mol/ha/day)
      REAL H_CONSUMPTION ! H+ consumption from NO3 uptake (mol/ha/day)
      REAL NET_H_PRODUCTION ! Net H+ production (mol/ha/day)
      REAL NET_H_MOL_DAY    ! Net H+ production (mol/day) for solution area
      REAL H_CONC_CHANGE ! H+ concentration change (mol/L)
      REAL H_CONC        ! Current H+ concentration (mol/L)
      REAL H_CONC_NEW    ! New H+ concentration (mol/L)
      
C     Buffering capacity
C     Based on solution volume and bicarbonate (if available)
      REAL BUFFER_CAP    ! Buffering capacity (mol H+/pH unit)
      REAL HCO3_CONC     ! Bicarbonate concentration (mg/L) - calculated from charge balance
      REAL SOLVOL_L      ! Solution volume in liters
      
C     Ion concentrations for charge balance calculation
      REAL NO3_CONC, NH4_CONC, P_CONC, K_CONC  ! From ModuleData (mg/L)
      REAL Ca_CONC, Mg_CONC, Na_CONC           ! Estimated or from solution (mg/L)
      REAL SO4_CONC, Cl_CONC                   ! Estimated or from solution (mg/L)
      
C     Charge balance variables
      REAL TotalCations   ! Sum of cations in meq/L
      REAL TotalAnions   ! Sum of anions in meq/L
      REAL P_RATIO       ! Phosphate speciation ratio [HPO4^2-]/[H2PO4-]
      REAL P_CHARGE      ! Average charge per P (accounts for speciation)
      
C     Molecular weights (g/mol)
      REAL MW_NO3, MW_NH4, MW_P, MW_K
      REAL MW_Ca, MW_Mg, MW_Na, MW_SO4, MW_Cl, MW_HCO3
      PARAMETER (MW_N = 14.0067)    ! g/mol
      PARAMETER (MW_NO3 = 62.0049)  ! NO3- (g/mol)
      PARAMETER (MW_NH4 = 18.0385) ! NH4+ (g/mol)
      PARAMETER (MW_P = 30.9738)    ! P (g/mol)
      PARAMETER (MW_K = 39.0983)    ! K+ (g/mol)
      PARAMETER (MW_Ca = 40.078)    ! Ca2+ (g/mol)
      PARAMETER (MW_Mg = 24.305)    ! Mg2+ (g/mol)
      PARAMETER (MW_Na = 22.9898)   ! Na+ (g/mol)
      PARAMETER (MW_SO4 = 96.0626)  ! SO4^2- (g/mol)
      PARAMETER (MW_Cl = 35.453)    ! Cl- (g/mol)
      PARAMETER (MW_HCO3 = 61.0168) ! HCO3- (g/mol)
      
C     Phosphate dissociation constant (pKa = 7.21)
      REAL PKA_PHOSPHATE
      PARAMETER (PKA_PHOSPHATE = 7.21)

      INTEGER DYNAMIC
      SAVE PH_INIT, SOLVOL_INIT, AREA

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize pH from ModuleData or use default
C-----------------------------------------------------------------------
        CALL GET('HYDRO','PH',PH_INIT)
        CALL GET('HYDRO','SOLVOL',SOLVOL_INIT)
        CALL GET('HYDRO','AREA',AREA)

        IF (PH_INIT .LT. 1.0 .OR. PH_INIT .GT. 14.0) THEN
          PH_INIT = 6.0  ! Default pH for hydroponic solution
          WRITE(*,*) 'SOLPH: Using default PH=',PH_INIT
        ENDIF

        IF (SOLVOL_INIT .LT. 1.0) THEN
          SOLVOL_INIT = 100.0  ! Default solution depth (mm)
          WRITE(*,*) 'SOLPH: Using default SOLVOL=',SOLVOL_INIT,' mm'
        ENDIF

        IF (AREA .LT. 0.1) THEN
          AREA = 1.0  ! Default area (m2)
        ENDIF

C       Get initial nutrient concentrations for charge balance
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

C       Estimate other ion concentrations from typical hydroponic solution ratios
C       Typical ratios: Ca ≈ 0.6×K, Mg ≈ 0.2×K, SO4 ≈ 0.5×K, Na ≈ 0.1×K, Cl ≈ 0.1×K
C       These are approximations - in real systems, these would come from solution recipe
        Ca_CONC = K_CONC * 0.6   ! Typical Ca:K ratio
        Mg_CONC = K_CONC * 0.2    ! Typical Mg:K ratio
        SO4_CONC = K_CONC * 0.5   ! Typical SO4:K ratio
        Na_CONC = K_CONC * 0.1    ! Typical Na:K ratio (from water source)
        Cl_CONC = K_CONC * 0.1    ! Typical Cl:K ratio (from water source)

C       Calculate phosphate speciation based on initial pH
C       H2PO4- ↔ HPO4^2- + H+ (pKa = 7.21)
C       P_RATIO = [HPO4^2-]/[H2PO4-] = 10^(pH - pKa)
        P_RATIO = 10.0 ** (PH_INIT - PKA_PHOSPHATE)
C       Average charge per P: H2PO4- = -1, HPO4^2- = -2
C       Weighted average: (-1 + -2*P_RATIO) / (1 + P_RATIO)
        P_CHARGE = (-1.0 - 2.0*P_RATIO) / (1.0 + P_RATIO)

C       Calculate charge balance to determine HCO3- concentration
C       C_HCO3 = Σ cations - Σ anions (in meq/L)
C       Convert mg/L to meq/L: mg/L / (MW g/mol) * charge
        TotalCations = (K_CONC/MW_K) +                    ! K+ (1 charge)
     &                 2.0*(Ca_CONC/MW_Ca) +              ! Ca2+ (2 charges)
     &                 2.0*(Mg_CONC/MW_Mg) +              ! Mg2+ (2 charges)
     &                 (Na_CONC/MW_Na) +                  ! Na+ (1 charge)
     &                 (NH4_CONC/MW_NH4)                   ! NH4+ (1 charge)
        
        TotalAnions = (NO3_CONC/MW_NO3) +                 ! NO3- (1 charge)
     &                2.0*(SO4_CONC/MW_SO4) +              ! SO4^2- (2 charges)
     &                (Cl_CONC/MW_Cl) +                    ! Cl- (1 charge)
     &                (P_CONC/MW_P) * ABS(P_CHARGE)        ! P (variable charge)

C       HCO3- balances the charge difference
        HCO3_CONC = (TotalCations - TotalAnions) * MW_HCO3  ! mg/L
        
C       Ensure HCO3- is non-negative (can't have negative concentration)
        HCO3_CONC = MAX(0.0, HCO3_CONC)
        
C       If calculated HCO3- is very small, use minimum (typical in hydroponics)
        IF (HCO3_CONC .LT. 10.0) THEN
          HCO3_CONC = 20.0  ! Minimum typical HCO3- (mg/L)
        ENDIF

        PH_TARGET = PH_INIT
        PH_CALC = PH_INIT
        PH_CHANGE = 0.0  ! Initialize pH change

C-----------------------------------------------------------------------
C       INITIALIZE pH STRESS PARAMETERS
C-----------------------------------------------------------------------
C       Optimal pH range for lettuce: 5.5-6.0
C       Below 5.5: nutrient availability problems (Fe, Mn deficiency)
C       Above 6.0: reduced nutrient availability (Ca, Mg, micronutrients)
        PH_OPT_LOW  = 5.5   ! Below this, low pH stress
        PH_OPT_HIGH = 6.0   ! Above this, high pH stress

C       Calculate buffering capacity from calculated HCO3-
C       Buffer capacity ≈ (HCO3- concentration × volume) / pH range
C       CRITICAL: Use maximum to prevent very small volumes
        SOLVOL_L = MAX(5.0, SOLVOL_INIT * AREA) / 1000.0  ! L (min 5.0 L/m²)
        BUFFER_CAP = (HCO3_CONC / MW_HCO3) * SOLVOL_L / 2.0  ! mol H+/pH unit
C       Factor /2.0 = approximate buffering range (pH 6-8)

C       If buffer capacity too small, use volume-based minimum
        IF (BUFFER_CAP .LT. 0.01) THEN
          BUFFER_CAP = MAX(0.01, SOLVOL_L * 0.001)  ! Minimum: 0.01 mol H+/pH
        ENDIF

C       Store initial pH values in ModuleData
        CALL PUT('HYDRO','PH',PH_CALC)

        WRITE(*,100) PH_INIT, SOLVOL_INIT, AREA, HCO3_CONC, BUFFER_CAP,
     &               TotalCations, TotalAnions
 100    FORMAT(/,' Hydroponic pH Module Initialized',
     &         /,'   Target pH : ',F5.2,
     &         /,'   Initial Solution Volume : ',F6.1,' mm',
     &         /,'   Growing Area : ',F6.2,' m2',
     &         /,'   Bicarbonate (calculated) : ',F6.1,' mg/L',
     &         /,'   Buffer Capacity : ',F6.3,' mol H+/pH unit',
     &         /,'   Charge Balance: Cations=',F6.2,' Anions=',F6.2,' meq/L',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate pH change due to nutrient uptake
C       Uses stoichiometric H+ production/consumption
C       Recalculates HCO3- from charge balance
C-----------------------------------------------------------------------
C       Get current solution volume for transpiration concentration effect
        CALL GET('HYDRO','SOLVOL',SOLVOL_CURRENT)
        
C       Get current nutrient concentrations for charge balance
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)
        
C       Recalculate other ions (may change with nutrient depletion)
C       In a full model, these would be tracked separately
C       Set minimum values to prevent charge balance issues when K depletes
        Ca_CONC = MAX(10.0, K_CONC * 0.6)
        Mg_CONC = MAX(5.0, K_CONC * 0.2)
        SO4_CONC = MAX(20.0, K_CONC * 0.5)
        Na_CONC = MAX(5.0, K_CONC * 0.1)
        Cl_CONC = MAX(5.0, K_CONC * 0.1)
        
C       Recalculate phosphate speciation based on current pH
        P_RATIO = 10.0 ** (PH_CALC - PKA_PHOSPHATE)
        P_CHARGE = (-1.0 - 2.0*P_RATIO) / (1.0 + P_RATIO)
        
C       Recalculate HCO3- from charge balance
        TotalCations = (K_CONC/MW_K) + 2.0*(Ca_CONC/MW_Ca) +
     &                 2.0*(Mg_CONC/MW_Mg) + (Na_CONC/MW_Na) +
     &                 (NH4_CONC/MW_NH4)
        
        TotalAnions = (NO3_CONC/MW_NO3) + 2.0*(SO4_CONC/MW_SO4) +
     &                (Cl_CONC/MW_Cl) + (P_CONC/MW_P) * ABS(P_CHARGE)
        
        HCO3_CONC = (TotalCations - TotalAnions) * MW_HCO3
        HCO3_CONC = MAX(20.0, HCO3_CONC)  ! Minimum 20 mg/L
        
C       Calculate concentration factor due to water loss
C       As plants transpire water, H+ concentration increases
        IF (SOLVOL_CURRENT .GT. 0.1 .AND. SOLVOL_INIT .GT. 0.1) THEN
          CONCENTRATION_FACTOR = SOLVOL_INIT / SOLVOL_CURRENT
          CONCENTRATION_FACTOR = MAX(1.0, MIN(CONCENTRATION_FACTOR, 5.0))
        ELSE
          CONCENTRATION_FACTOR = 1.0
        ENDIF

C       Calculate H+ production/consumption from nutrient uptake
C       Stoichiometry: 1 mol H+ per mol NH4-N, -1 mol H+ per mol NO3-N
C       Convert kg/ha/day to mol/ha/day: kg / (MW g/mol / 1000 g/kg) = mol
        H_PRODUCTION = (NH4_UPTAKE * 1000.0) / MW_N   ! mol H+/ha/day
        H_CONSUMPTION = (NO3_UPTAKE * 1000.0) / MW_N ! mol H+/ha/day (negative effect)
        
        NET_H_PRODUCTION = H_PRODUCTION - H_CONSUMPTION  ! mol H+/ha/day

C       Convert to H+ concentration change (mol/L)
C       Solution volume in L = SOLVOL_CURRENT (mm) * AREA (m2) / 1000.0
C       CRITICAL: Use maximum to prevent division by zero with very small volumes
        SOLVOL_L = MAX(5.0, SOLVOL_CURRENT * AREA) / 1000.0  ! L (min 5.0 L/m²)
        IF (SOLVOL_L .GT. 0.01) THEN
C         Convert mol/ha to mol/L: mol/ha / (ha in m2 / m2 per L)
C         ha = 10000 m2, so: mol/ha / (10000 * AREA / SOLVOL_L)
          H_CONC_CHANGE = NET_H_PRODUCTION / (10000.0 * AREA / SOLVOL_L)
        ELSE
          H_CONC_CHANGE = 0.0
        ENDIF

C       Get current H+ concentration from pH
        H_CONC = 10.0 ** (-PH_CALC)  ! mol/L

C       Calculate new H+ concentration (accounting for transpiration)
C       Transpiration concentrates H+ ions along with other ions
        H_CONC_NEW = (H_CONC * CONCENTRATION_FACTOR) + H_CONC_CHANGE
        
C       Ensure H+ concentration is within reasonable bounds
        H_CONC_NEW = MAX(1.0E-9, MIN(H_CONC_NEW, 1.0))  ! pH range: 0-9

C       Calculate pH change from H+ concentration change
        PH_CHANGE = -LOG10(H_CONC_NEW) - PH_CALC

C       Limit daily pH change to realistic range (±1.0 pH units/day max)
        PH_CHANGE = MAX(-1.0, MIN(1.0, PH_CHANGE))

C-----------------------------------------------------------------------
C       CALCULATE pH STRESS FACTORS
C       Similar to EC stress: Low pH (acidic) and High pH (alkaline)
C-----------------------------------------------------------------------
C       Optimal pH range for lettuce: 5.5-6.0
        PH_OPT_LOW  = 5.5
        PH_OPT_HIGH = 6.0

C       Calculate stress from LOW pH (too acidic)
        IF (PH_CALC .LT. PH_OPT_LOW) THEN
C         Linear decline: pH=4.5 → stress=0.3, pH=5.5 → stress=1.0
C         Below pH 4.5, severe toxicity and membrane damage
          PH_STRESS_LOW = 0.3 + 0.7 * ((PH_CALC - 4.5) / (PH_OPT_LOW - 4.5))
          PH_STRESS_LOW = MAX(0.3, MIN(1.0, PH_STRESS_LOW))
        ELSE
C         No stress from low pH
          PH_STRESS_LOW = 1.0
        ENDIF

C       Calculate stress from HIGH pH (too alkaline)
        IF (PH_CALC .GT. PH_OPT_HIGH) THEN
C         Exponential decline: simulate cumulative nutrient precipitation
C         At pH = 7.0, stress ≈ 0.75; At pH = 8.0, stress ≈ 0.37
C         High pH reduces Fe, Mn, Zn, Cu availability (precipitation)
          PH_STRESS_HIGH = EXP(-0.25 * (PH_CALC - PH_OPT_HIGH))
          PH_STRESS_HIGH = MAX(0.1, MIN(1.0, PH_STRESS_HIGH))
        ELSE
C         No stress from high pH
          PH_STRESS_HIGH = 1.0
        ENDIF

C       Combined pH stress (take minimum = most limiting)
        PH_STRESS_TOTAL = MIN(PH_STRESS_LOW, PH_STRESS_HIGH)

C       Store pH stress factors in ModuleData for use by other modules
        CALL PUT('HYDRO','PHSTRESS_ROOT',PH_STRESS_TOTAL)
        CALL PUT('HYDRO','PHSTRESS_LEAF',PH_STRESS_TOTAL)
        CALL PUT('HYDRO','PHSTRESS_UPTAKE',PH_STRESS_TOTAL)

        WRITE(*,200) NH4_UPTAKE, NO3_UPTAKE, NET_H_PRODUCTION,
     &               CONCENTRATION_FACTOR, SOLVOL_CURRENT, HCO3_CONC,
     &               PH_CHANGE, PH_CALC, PH_OPT_LOW, PH_OPT_HIGH,
     &               PH_STRESS_LOW, PH_STRESS_HIGH, PH_STRESS_TOTAL
 200    FORMAT(' SOLPH: NH4=',F6.3,' NO3=',F6.3,' kg/ha/d',
     &         ' => Net H+=',F8.4,' mol/ha/d',/,
     &         '   ConcFactor=',F5.2,' (Vol=',F6.1,' mm)',
     &         ' HCO3=',F5.1,' mg/L => pH change=',F6.3,/,
     &         '   pH=',F5.2,' (Opt=',F4.2,'-',F4.2,')',
     &         ' pH Stress: Low=',F5.3,' High=',F5.3,' Total=',F5.3)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update pH based on calculated change
C       Recalculate from H+ concentration for accuracy
C       Update HCO3- from charge balance after pH change
C-----------------------------------------------------------------------
C       Get current solution volume
        CALL GET('HYDRO','SOLVOL',SOLVOL_CURRENT)
        
C       Get current nutrient concentrations
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)
        
C       Recalculate H+ concentration with updated values
        IF (SOLVOL_CURRENT .GT. 0.1 .AND. SOLVOL_INIT .GT. 0.1) THEN
          CONCENTRATION_FACTOR = SOLVOL_INIT / SOLVOL_CURRENT
          CONCENTRATION_FACTOR = MAX(1.0, MIN(CONCENTRATION_FACTOR, 5.0))
        ELSE
          CONCENTRATION_FACTOR = 1.0
        ENDIF

C       Recalculate H+ production for this integration step
C       (Recalculate from uptake values - should match RATE phase)
        H_PRODUCTION = (NH4_UPTAKE * 1000.0) / MW_N   ! mol H+/ha/day
        H_CONSUMPTION = (NO3_UPTAKE * 1000.0) / MW_N ! mol H+/ha/day
        NET_H_PRODUCTION = H_PRODUCTION - H_CONSUMPTION  ! mol H+/ha/day
        
C       Get current buffering capacity (recalculate with current HCO3-)
C       First recalculate HCO3- from charge balance to get current buffer capacity
        P_RATIO = 10.0 ** (PH_CALC - PKA_PHOSPHATE)
        P_CHARGE = (-1.0 - 2.0*P_RATIO) / (1.0 + P_RATIO)

C       Set minimum values to prevent charge balance issues when K depletes
        Ca_CONC = MAX(10.0, K_CONC * 0.6)
        Mg_CONC = MAX(5.0, K_CONC * 0.2)
        SO4_CONC = MAX(20.0, K_CONC * 0.5)
        Na_CONC = MAX(5.0, K_CONC * 0.1)
        Cl_CONC = MAX(5.0, K_CONC * 0.1)

        TotalCations = (K_CONC/MW_K) + 2.0*(Ca_CONC/MW_Ca) +
     &                 2.0*(Mg_CONC/MW_Mg) + (Na_CONC/MW_Na) +
     &                 (NH4_CONC/MW_NH4)

        TotalAnions = (NO3_CONC/MW_NO3) + 2.0*(SO4_CONC/MW_SO4) +
     &                (Cl_CONC/MW_Cl) + (P_CONC/MW_P) * ABS(P_CHARGE)

        HCO3_CONC = (TotalCations - TotalAnions) * MW_HCO3
        HCO3_CONC = MAX(20.0, HCO3_CONC)

C       Calculate current buffering capacity
C       CRITICAL: Use maximum to prevent division by zero with very small volumes
        SOLVOL_L = MAX(5.0, SOLVOL_CURRENT * AREA) / 1000.0  ! L (min 5.0 L/m²)
        BUFFER_CAP = (HCO3_CONC / MW_HCO3) * SOLVOL_L / 2.0  ! mol H+/pH unit
        IF (BUFFER_CAP .LT. 0.01) THEN
          BUFFER_CAP = MAX(0.01, SOLVOL_L * 0.001)  ! Minimum: 0.01 mol H+/pH
        ENDIF

C       Calculate pH change using buffering capacity
C       NET_H_PRODUCTION is in mol/ha/day
C       BUFFER_CAP is in mol H+/pH unit for the entire solution
C       Need to convert NET_H_PRODUCTION to mol/day for the solution area
C       pH_change = -(NET_H_PRODUCTION * AREA / 10000.0) / BUFFER_CAP
C       Negative because: H+ production (positive) lowers pH (negative change)
C                         H+ consumption (negative) raises pH (positive change)
        IF (BUFFER_CAP .GT. 0.001 .AND. AREA .GT. 0.1) THEN
C         Convert mol/ha/day to mol/day for the solution area
          NET_H_MOL_DAY = NET_H_PRODUCTION * AREA / 10000.0  ! mol/day
          PH_CHANGE = -NET_H_MOL_DAY / BUFFER_CAP  ! pH units
        ELSE
          PH_CHANGE = 0.0
        ENDIF

C       Apply transpiration concentration effect on pH
C       As solution volume decreases, H+ concentrates, lowering pH
C       This is a small effect compared to nutrient uptake
        IF (CONCENTRATION_FACTOR .GT. 1.01) THEN
C         Transpiration concentrates H+, causing slight pH decrease
C         Approximate: pH_change ≈ -0.1 * log10(concentration_factor)
          PH_CHANGE = PH_CHANGE - 0.1 * LOG10(CONCENTRATION_FACTOR)
        ENDIF

C       Limit daily pH change to realistic range (±0.5 pH units/day max)
C       Buffering prevents rapid pH swings
        PH_CHANGE = MAX(-0.5, MIN(0.5, PH_CHANGE))

C       Update pH
        PH_CALC = PH_CALC + PH_CHANGE

C       Keep pH within reasonable bounds
        IF (PH_CALC .LT. 3.0) PH_CALC = 3.0
        IF (PH_CALC .GT. 9.0) PH_CALC = 9.0

C       Recalculate HCO3- from charge balance with new pH
C       (Phosphate speciation changes with pH)
        P_RATIO = 10.0 ** (PH_CALC - PKA_PHOSPHATE)
        P_CHARGE = (-1.0 - 2.0*P_RATIO) / (1.0 + P_RATIO)
        
        Ca_CONC = K_CONC * 0.6
        Mg_CONC = K_CONC * 0.2
        SO4_CONC = K_CONC * 0.5
        Na_CONC = K_CONC * 0.1
        Cl_CONC = K_CONC * 0.1
        
        TotalCations = (K_CONC/MW_K) + 2.0*(Ca_CONC/MW_Ca) +
     &                 2.0*(Mg_CONC/MW_Mg) + (Na_CONC/MW_Na) +
     &                 (NH4_CONC/MW_NH4)
        
        TotalAnions = (NO3_CONC/MW_NO3) + 2.0*(SO4_CONC/MW_SO4) +
     &                (Cl_CONC/MW_Cl) + (P_CONC/MW_P) * ABS(P_CHARGE)
        
        HCO3_CONC = (TotalCations - TotalAnions) * MW_HCO3
        HCO3_CONC = MAX(20.0, HCO3_CONC)

C       Update buffering capacity with new HCO3-
C       CRITICAL: Use maximum to prevent division by zero with very small volumes
        SOLVOL_L = MAX(5.0, SOLVOL_CURRENT * AREA) / 1000.0  ! L (min 5.0 L/m²)
        BUFFER_CAP = (HCO3_CONC / MW_HCO3) * SOLVOL_L / 2.0
        IF (BUFFER_CAP .LT. 0.01) THEN
          BUFFER_CAP = MAX(0.01, SOLVOL_L * 0.001)  ! Minimum: 0.01 mol H+/pH
        ENDIF

C       Store updated pH
        CALL PUT('HYDRO','PH',PH_CALC)

        H_CONC = 10.0 ** (-PH_CALC)  ! Calculate H+ from final pH
        WRITE(*,300) PH_CALC, PH_TARGET, PH_CHANGE, H_CONC * 1.0E6, 
     &               HCO3_CONC, BUFFER_CAP
 300    FORMAT(' SOLPH: Updated pH=',F5.2,' (Target=',F5.2,')',
     &         ' Change=',F6.3,/,
     &         '   [H+]=',F8.2,' µmol/L HCO3=',F5.1,' mg/L',
     &         ' Buffer=',F6.3,' mol H+/pH')

C-----------------------------------------------------------------------
C       Optional: Implement pH adjustment/control
C       In real hydroponic systems, pH is actively controlled
C       This could be implemented as automatic adjustment when pH
C       deviates too far from target
C-----------------------------------------------------------------------
        IF (ABS(PH_CALC - PH_TARGET) .GT. 1.0) THEN
          WRITE(*,*) 'SOLPH WARNING: pH deviation >1.0 unit from target'
          WRITE(*,*) '  Consider implementing automatic pH correction'
C         Could implement automatic pH correction here
C         For now, just issue warning
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLPH
