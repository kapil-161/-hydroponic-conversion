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

C     Hydroponic control flag
      REAL AUTO_PH_R       ! 1.0 = maintain constant pH, 0.0 = allow drift

C     pH-dependent availability and Km variables
      REAL PH_OPT        ! Optimal pH (center of range)
      REAL PH_STRESS_TOTAL ! Combined pH stress (0-1) for backward compatibility
      REAL PH_AVAIL_NO3, PH_AVAIL_NH4, PH_AVAIL_P, PH_AVAIL_K  ! Availability factors
      REAL PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4, PH_KM_FACTOR_P, PH_KM_FACTOR_K
      REAL PH_EXP_NO3, PH_EXP_NH4, PH_EXP_P, PH_EXP_K  ! Intermediate exp arguments
      REAL PH_DEVIATION  ! |pH - pH_opt|
      REAL PH_SCALE_NO3, PH_SCALE_NH4, PH_SCALE_P, PH_SCALE_K  ! Scaling factors
      REAL PH_KM_ALPHA_NO3, PH_KM_ALPHA_NH4, PH_KM_ALPHA_P, PH_KM_ALPHA_K  ! Km sensitivity

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
      REAL H_CONC        ! Current H+ concentration (mol/L) - for diagnostics
      
C     Buffering capacity
C     Based on solution volume, bicarbonate and phosphate
      REAL BUFFER_CAP    ! Total buffering capacity (mol H+/pH unit)
      REAL HCO3_CONC     ! Bicarbonate concentration (mg/L) - calculated from charge balance
      REAL SOLVOL_L      ! Solution volume in liters
      REAL P_FRAC        ! Fraction of P as HPO4^2- (for buffer calc)
      REAL P_BUFFER_CAP  ! Phosphate buffering capacity (mol H+/pH unit)
      
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
      
C     pH-dependent availability scaling factors (s in sigmoidal function)
      PARAMETER (PH_SCALE_NO3 = 0.8)  ! NO3: moderate sensitivity
      PARAMETER (PH_SCALE_NH4 = 0.8)  ! NH4: moderate sensitivity  
      PARAMETER (PH_SCALE_P = 0.5)    ! P: high sensitivity (precipitation)
      PARAMETER (PH_SCALE_K = 1.0)    ! K: low sensitivity
      
C     pH-dependent Km sensitivity factors (α in exponential function)
      PARAMETER (PH_KM_ALPHA_NO3 = 0.15)  ! NO3: moderate sensitivity
      PARAMETER (PH_KM_ALPHA_NH4 = 0.15)  ! NH4: moderate sensitivity
      PARAMETER (PH_KM_ALPHA_P = 0.20)    ! P: higher sensitivity
      PARAMETER (PH_KM_ALPHA_K = 0.10)    ! K: lower sensitivity
      
C     Optimal pH for lettuce
      PARAMETER (PH_OPT = 5.75)  ! Center of 5.5-6.0 range

      INTEGER DYNAMIC
      SAVE PH_INIT, SOLVOL_INIT, AREA, AUTO_PH_R

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
          CALL ERROR('SOLPH ',1,'PH missing or invalid',0)
        ENDIF

        IF (SOLVOL_INIT .LT. 1.0) THEN
          CALL ERROR('SOLPH ',1,'SOLVOL missing',0)
        ENDIF

        IF (AREA .LT. 0.1) THEN
          CALL ERROR('SOLPH ',1,'AREA missing',0)
        ENDIF

C       Get AUTO_PH control flag from ISWITCH structure
C       'Y' = maintain constant pH (grower adds acid/base as needed)
C       'N' = allow natural drift based on nutrient uptake chemistry
        IF (ISWITCH % AUTO_PH .EQ. 'Y') THEN
          AUTO_PH_R = 1.0
        ELSE
          AUTO_PH_R = 0.0
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

C       Calculate buffering capacity from HCO3- and phosphate
C       CRITICAL: Use maximum to prevent very small volumes
        SOLVOL_L = MAX(5.0, SOLVOL_INIT * AREA)            ! L (min 5.0 L)

C       Bicarbonate buffering
C       HCO3_CONC/MW_HCO3 gives mmol/L; divide by 1000 to get mol/L, then * L = mol
        BUFFER_CAP = (HCO3_CONC / MW_HCO3 / 1000.0) * SOLVOL_L / 2.0  ! mol H+/pH unit

C       Phosphate buffering: beta = 2.303 * C_total * f * (1-f)
C       where f = [HPO4^2-] / ([H2PO4^-] + [HPO4^2-])
C       At pH 5.75: f=0.034, f*(1-f)=0.033 (modest but non-zero)
C       At pH 7.0:  f=0.38,  f*(1-f)=0.24  (strong buffering)
        P_FRAC = P_RATIO / (1.0 + P_RATIO)
        P_BUFFER_CAP = 2.303 * (P_CONC/MW_P/1000.0)
     &               * SOLVOL_L * P_FRAC * (1.0 - P_FRAC)
        BUFFER_CAP = BUFFER_CAP + P_BUFFER_CAP

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
C       Calculate pH change due to nutrient uptake using buffer capacity
C       Then update pH BEFORE calculating availability factors
C       This ensures availability factors reflect current pH state
C       Get AUTO_PH control flag from ISWITCH structure
        IF (ISWITCH % AUTO_PH .EQ. 'Y') THEN
          AUTO_PH_R = 1.0
        ELSE
          AUTO_PH_R = 0.0
        ENDIF

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

C-----------------------------------------------------------------------
C       Calculate pH change using buffer capacity method
C       This is chemically accurate for buffered hydroponic solutions
C-----------------------------------------------------------------------
C       Calculate solution volume in liters
        SOLVOL_L = MAX(5.0, SOLVOL_CURRENT * AREA)            ! L (min 5.0 L)

C       Bicarbonate buffering
C       HCO3_CONC/MW_HCO3 gives mmol/L; divide by 1000 to get mol/L, then * L = mol
        BUFFER_CAP = (HCO3_CONC / MW_HCO3 / 1000.0) * SOLVOL_L / 2.0  ! mol H+/pH unit

C       Phosphate buffering (P_RATIO already recalculated above)
        P_FRAC = P_RATIO / (1.0 + P_RATIO)
        P_BUFFER_CAP = 2.303 * (P_CONC/MW_P/1000.0)
     &               * SOLVOL_L * P_FRAC * (1.0 - P_FRAC)
        BUFFER_CAP = BUFFER_CAP + P_BUFFER_CAP

        IF (BUFFER_CAP .LT. 0.01) THEN
          BUFFER_CAP = MAX(0.01, SOLVOL_L * 0.001)  ! Minimum: 0.01 mol H+/pH
        ENDIF

C       Calculate pH change using buffering capacity
C       NET_H_PRODUCTION is in mol/ha/day
C       BUFFER_CAP is in mol H+/pH unit for the entire solution
C       pH_change = -(NET_H_PRODUCTION * AREA / 10000.0) / BUFFER_CAP
C       Negative because: H+ production (positive) lowers pH (negative change)
        IF (BUFFER_CAP .GT. 0.001 .AND. AREA .GT. 0.1) THEN
C         Convert mol/ha/day to mol/day for the solution area
          NET_H_MOL_DAY = NET_H_PRODUCTION * AREA / 10000.0  ! mol/day
          PH_CHANGE = -NET_H_MOL_DAY / BUFFER_CAP  ! pH units
        ELSE
          PH_CHANGE = 0.0
        ENDIF

C       Apply transpiration concentration effect on pH
C       As solution volume decreases, H+ concentrates, lowering pH
        IF (CONCENTRATION_FACTOR .GT. 1.01) THEN
          PH_CHANGE = PH_CHANGE - 0.1 * LOG10(CONCENTRATION_FACTOR)
        ENDIF

C       Limit daily pH change to realistic range (±0.5 pH units/day max)
C       Buffering prevents rapid pH swings
        PH_CHANGE = MAX(-0.5, MIN(0.5, PH_CHANGE))

C-----------------------------------------------------------------------
C       UPDATE pH (AUTO_PH_R: 1.0=constant pH, 0.0=natural drift)
C-----------------------------------------------------------------------
        IF (AUTO_PH_R .GT. 0.5) THEN
C         Maintain pH at target (simulates grower adding acid/base)
          PH_CALC = PH_TARGET
        ELSE
C         Natural drift mode: Apply calculated pH change
          PH_CALC = PH_CALC + PH_CHANGE

C         Keep pH within reasonable bounds
          IF (PH_CALC .LT. 3.0) PH_CALC = 3.0
          IF (PH_CALC .GT. 9.0) PH_CALC = 9.0
        ENDIF

C       Store updated pH immediately
        CALL PUT('HYDRO','PH',PH_CALC)

C-----------------------------------------------------------------------
C       CALCULATE pH-DEPENDENT NUTRIENT AVAILABILITY FACTORS
C       Gaussian: f(pH) = exp(-(pH - pH_opt)^2 / (2 * scale^2))
C       Gives 1.0 at optimal pH, declines symmetrically away
C-----------------------------------------------------------------------
        PH_EXP_NO3 = -((PH_CALC-PH_OPT)**2)/(2.0*PH_SCALE_NO3**2)
        PH_EXP_NH4 = -((PH_CALC-PH_OPT)**2)/(2.0*PH_SCALE_NH4**2)
        PH_EXP_P   = -((PH_CALC-PH_OPT)**2)/(2.0*PH_SCALE_P**2)
        PH_EXP_K   = -((PH_CALC-PH_OPT)**2)/(2.0*PH_SCALE_K**2)

        PH_EXP_NO3 = MAX(-10.0, PH_EXP_NO3)
        PH_EXP_NH4 = MAX(-10.0, PH_EXP_NH4)
        PH_EXP_P   = MAX(-10.0, PH_EXP_P)
        PH_EXP_K   = MAX(-10.0, PH_EXP_K)

        PH_AVAIL_NO3 = EXP(PH_EXP_NO3)
        PH_AVAIL_NH4 = EXP(PH_EXP_NH4)
        PH_AVAIL_P   = EXP(PH_EXP_P)
        PH_AVAIL_K   = EXP(PH_EXP_K)

        PH_AVAIL_NO3 = MAX(0.01, MIN(1.0, PH_AVAIL_NO3))
        PH_AVAIL_NH4 = MAX(0.01, MIN(1.0, PH_AVAIL_NH4))
        PH_AVAIL_P   = MAX(0.01, MIN(1.0, PH_AVAIL_P))
        PH_AVAIL_K   = MAX(0.01, MIN(1.0, PH_AVAIL_K))

C-----------------------------------------------------------------------
C       CALCULATE pH-DEPENDENT Km (transporter affinity)
C       Km(pH) = Km_opt × exp(α × |pH - pH_opt|)
C       Higher pH deviation → higher Km → lower affinity
C-----------------------------------------------------------------------
        PH_DEVIATION = ABS(PH_CALC - PH_OPT)
        
        PH_KM_FACTOR_NO3 = EXP(PH_KM_ALPHA_NO3 * PH_DEVIATION)
        PH_KM_FACTOR_NH4 = EXP(PH_KM_ALPHA_NH4 * PH_DEVIATION)
        PH_KM_FACTOR_P = EXP(PH_KM_ALPHA_P * PH_DEVIATION)
        PH_KM_FACTOR_K = EXP(PH_KM_ALPHA_K * PH_DEVIATION)
        
C       Limit Km factors to reasonable range (1.0 to 5.0)
        PH_KM_FACTOR_NO3 = MAX(1.0, MIN(5.0, PH_KM_FACTOR_NO3))
        PH_KM_FACTOR_NH4 = MAX(1.0, MIN(5.0, PH_KM_FACTOR_NH4))
        PH_KM_FACTOR_P = MAX(1.0, MIN(5.0, PH_KM_FACTOR_P))
        PH_KM_FACTOR_K = MAX(1.0, MIN(5.0, PH_KM_FACTOR_K))

C       Store pH-dependent factors in ModuleData for use by other modules
        CALL PUT('HYDRO','PH_AVAIL_NO3',PH_AVAIL_NO3)
        CALL PUT('HYDRO','PH_AVAIL_NH4',PH_AVAIL_NH4)
        CALL PUT('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
        CALL PUT('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
        CALL PUT('HYDRO','PH_KM_FACTOR_NO3',PH_KM_FACTOR_NO3)
        CALL PUT('HYDRO','PH_KM_FACTOR_NH4',PH_KM_FACTOR_NH4)
        CALL PUT('HYDRO','PH_KM_FACTOR_P',PH_KM_FACTOR_P)
        CALL PUT('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR_K)
        
C       Also store general pH stress for backward compatibility (membrane effects)
C       Use minimum availability as general stress indicator
        PH_STRESS_TOTAL = MIN(PH_AVAIL_NO3, PH_AVAIL_NH4, PH_AVAIL_P, PH_AVAIL_K)
        CALL PUT('HYDRO','PHSTRESS_ROOT',PH_STRESS_TOTAL)
        CALL PUT('HYDRO','PHSTRESS_LEAF',PH_STRESS_TOTAL)
        CALL PUT('HYDRO','PHSTRESS_UPTAKE',PH_STRESS_TOTAL)

        WRITE(*,200) NH4_UPTAKE, NO3_UPTAKE, NET_H_PRODUCTION,
     &               CONCENTRATION_FACTOR, SOLVOL_CURRENT, HCO3_CONC,
     &               PH_CHANGE, PH_CALC, PH_OPT,
     &               PH_AVAIL_NO3, PH_AVAIL_NH4, PH_AVAIL_P, PH_AVAIL_K,
     &               PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4
 200    FORMAT(' SOLPH: NH4=',F6.3,' NO3=',F6.3,' kg/ha/d',
     &         ' => Net H+=',F10.2,' mol/ha/d',/,
     &         '   ConcFactor=',F5.2,' (Vol=',F6.1,' mm)',
     &         ' HCO3=',F5.1,' mg/L => pH change=',F6.3,/,
     &         '   pH=',F5.2,' (Opt=',F4.2,')',
     &         ' Availability: NO3=',F5.3,' NH4=',F5.3,' P=',F5.3,' K=',F5.3,/,
     &         '   Km factors: NO3=',F5.3,' NH4=',F5.3)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       INTEGR phase - pH was already calculated and stored in RATE phase
C       This block only outputs diagnostic information
C       NOTE: AUTO_PH_R is updated in RATE block which runs before INTEGR,
C             so the SAVEd value is current for this timestep
C-----------------------------------------------------------------------
C       Calculate H+ concentration for diagnostic output
        H_CONC = 10.0 ** (-PH_CALC)

        WRITE(*,300) PH_CALC, PH_TARGET, PH_CHANGE, H_CONC * 1.0E6,
     &               HCO3_CONC, BUFFER_CAP
 300    FORMAT(' SOLPH: pH=',F5.2,' (Target=',F5.2,')',
     &         ' Change=',F6.3,/,
     &         '   [H+]=',F8.2,' µmol/L HCO3=',F5.1,' mg/L',
     &         ' Buffer=',F6.3,' mol H+/pH')

C       Warn if pH deviates significantly from target
        IF (ABS(PH_CALC - PH_TARGET) .GT. 1.0) THEN
          WRITE(*,*) 'SOLPH WARNING: pH deviation >1.0 unit from target'
          WRITE(*,*) '  Consider implementing automatic pH correction'
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLPH
