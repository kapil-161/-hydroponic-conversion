C=======================================================================
C  SOLPH, Subroutine
C
C  Hydroponic pH calculation and management
C  Tracks pH changes due to nutrient uptake using prognostic (buffer-
C  capacity) integration with CO2-equilibrium bicarbonate.
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic pH management
C  01/08/2026 Improved: Stoichiometric H+ calculation, transpiration effect
C  04/10/2026 Tested diagnostic charge-balance approach (Silberbush 2005);
C             reverted — approach requires complete ion inventory (Ca, Mg,
C             SO4, Na, Cl) not available in this model.  With only N, P, K
C             tracked, the initial charge residual A ≈ 5e-6 mol/L is smaller
C             than one day's depletion shift, causing the sign of A to flip
C             and pH to swing ±2 units every day.  Prognostic integration
C             with CO2-equilibrium HCO3- is retained instead.
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
      REAL PH_OPT
      REAL PH_STRESS_TOTAL
      REAL PH_AVAIL_NO3, PH_AVAIL_NH4, PH_AVAIL_P, PH_AVAIL_K
      REAL PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4, PH_KM_FACTOR_P, PH_KM_FACTOR_K
      REAL PH_EXP_NO3, PH_EXP_NH4, PH_EXP_P, PH_EXP_K
      REAL PH_DEVIATION
      REAL PH_SCALE_NO3, PH_SCALE_NH4, PH_SCALE_P, PH_SCALE_K
      REAL PH_KM_ALPHA_NO3, PH_KM_ALPHA_NH4, PH_KM_ALPHA_P, PH_KM_ALPHA_K

C     Local variables
      REAL PH_INIT       ! Initial pH value
      REAL PH_CHANGE     ! Daily pH change
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL SOLVOL_PREV   ! Previous day's solution volume (mm)
      REAL SOLVOL_CURRENT ! Current solution volume (mm)
      REAL CONCENTRATION_FACTOR ! Daily volume change ratio
      REAL AREA          ! Growing area (m2)
      LOGICAL FIRST_RATE ! .TRUE. until the first RATE call after SEASINIT

C     Stoichiometric H+ production/consumption
C     NH4+ uptake: NH4+ → N (in plant) + H+ (released) - 1 mol H+ per mol NH4-N
C     NO3- uptake: NO3- + H+ → N (in plant) - consumes 1 mol H+ per mol NO3-N
      REAL MW_N          ! Nitrogen molecular weight (g/mol)
      REAL H_PRODUCTION  ! H+ production from NH4 uptake (mol/ha/day)
      REAL H_CONSUMPTION ! H+ consumption from NO3 uptake (mol/ha/day)
      REAL NET_H_PRODUCTION ! Net H+ production (mol/ha/day)
      REAL NET_H_MOL_DAY    ! Net H+ production (mol/day) for solution area
      REAL H_CONC        ! H+ concentration (mol/L) for diagnostics

C     Buffering capacity
C     Based on solution volume, bicarbonate and phosphate
      REAL BUFFER_CAP    ! Total buffering capacity (mol H+/pH unit)
      REAL HCO3_CONC     ! Bicarbonate concentration (mg/L) from CO2 equilibrium
      REAL SOLVOL_L      ! Solution volume in liters
      REAL P_FRAC        ! Fraction of P as HPO4^2- (for buffer calc)
      REAL P_BUFFER_CAP  ! Phosphate buffering capacity (mol H+/pH unit)

C     Ion concentrations (mg/L) — for buffering calc
      REAL NO3_CONC, NH4_CONC, P_CONC, K_CONC

C     Phosphate speciation variables
      REAL P_RATIO       ! [HPO4^2-]/[H2PO4-] = 10^(pH - pKa)
      REAL P_CHARGE      ! Average charge per P (for reference only)

C     Molecular weights (g/mol)
      REAL MW_P, MW_K, MW_HCO3
      PARAMETER (MW_N    = 14.0067)  ! g/mol
      PARAMETER (MW_P    = 30.9738)  ! P (g/mol)
      PARAMETER (MW_K    = 39.0983)  ! K+ (g/mol)
      PARAMETER (MW_HCO3 = 61.0168)  ! HCO3- (g/mol)

C     Phosphate dissociation constant (pKa = 7.21, Lide 1996)
      REAL PKA_PHOSPHATE
      PARAMETER (PKA_PHOSPHATE = 7.21)

C     CO2 equilibrium constants for HCO3- calculation (Silberbush et al. 2005)
C     K1_CA = first dissociation constant of carbonic acid = 10^-6.35
C     CO2_AQ = KH_CO2 * pCO2 = 3.4e-2 * 370e-6 = 1.258e-5 mol/L
      REAL K1_CA, CO2_AQ
      PARAMETER (K1_CA  = 4.47E-7)   ! 10^-6.35
      PARAMETER (CO2_AQ = 1.258E-5)  ! KH * pCO2 (mol/L)

C     Background alkalinity (HCO3- from irrigation water, meq/L)
C     Provides realistic buffer capacity independent of solution bicarbonate.
C     0.5 meq/L = ~30 mg/L HCO3- corresponds to moderately soft tap water.
      REAL BGALKAL
      PARAMETER (BGALKAL = 0.5E-3)   ! mol/L (0.5 mmol/L = 0.5 meq/L)

C     pH-dependent availability scaling factors
      PARAMETER (PH_SCALE_NO3 = 0.8)
      PARAMETER (PH_SCALE_NH4 = 0.8)
      PARAMETER (PH_SCALE_P   = 0.5)
      PARAMETER (PH_SCALE_K   = 1.0)

C     pH-dependent Km sensitivity factors
      PARAMETER (PH_KM_ALPHA_NO3 = 0.15)
      PARAMETER (PH_KM_ALPHA_NH4 = 0.15)
      PARAMETER (PH_KM_ALPHA_P   = 0.20)
      PARAMETER (PH_KM_ALPHA_K   = 0.10)

C     Optimal pH for lettuce (center of 5.5-6.0 range)
      PARAMETER (PH_OPT = 5.75)

      INTEGER DYNAMIC

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize pH from ModuleData
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

        IF (ISWITCH % AUTO_PH .EQ. 'Y') THEN
          AUTO_PH_R = 1.0
        ELSE
          AUTO_PH_R = 0.0
        ENDIF

        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

C       Phosphate speciation at initial pH
        P_RATIO = 10.0 ** (PH_INIT - PKA_PHOSPHATE)
        P_CHARGE = (-1.0 - 2.0*P_RATIO) / (1.0 + P_RATIO)

C       HCO3- from CO2 equilibrium (Silberbush et al. 2005, Eq. 14a)
C       Valid for open systems in equilibrium with atmospheric CO2.
C       Yields ~0.20 mg/L at pH 5.75, ~0.34 mg/L at pH 6.0.
        HCO3_CONC = K1_CA * CO2_AQ / (10.0**(-PH_INIT))  ! mol/L
        HCO3_CONC = HCO3_CONC * MW_HCO3 * 1000.0          ! mg/L
        HCO3_CONC = MAX(0.1, HCO3_CONC)

        SOLVOL_PREV = SOLVOL_INIT
        FIRST_RATE  = .TRUE.

        PH_TARGET = PH_INIT
        PH_CALC   = PH_INIT
        PH_CHANGE = 0.0

C       Buffer capacity: bicarbonate (CO2 equil.) + background alkalinity + phosphate
        SOLVOL_L = MAX(5.0, SOLVOL_INIT * AREA)

C       Bicarbonate from CO2 equilibrium (open system)
        BUFFER_CAP = 2.303 * (HCO3_CONC / MW_HCO3 / 1000.0) * SOLVOL_L

C       Background alkalinity contribution (irrigation water HCO3-): adds
C       realistic buffer capacity even when solution HCO3- is near zero
        BUFFER_CAP = BUFFER_CAP + 2.303 * BGALKAL * SOLVOL_L

C       Phosphate buffering: beta = 2.303 * C_total * f * (1-f)
        P_FRAC = P_RATIO / (1.0 + P_RATIO)
        P_BUFFER_CAP = 2.303 * (P_CONC/MW_P/1000.0)
     &               * SOLVOL_L * P_FRAC * (1.0 - P_FRAC)
        BUFFER_CAP = BUFFER_CAP + P_BUFFER_CAP

        IF (BUFFER_CAP .LT. 0.01) THEN
          BUFFER_CAP = MAX(0.01, SOLVOL_L * 0.001)
        ENDIF

        CALL PUT('HYDRO','PH',PH_CALC)

        WRITE(*,100) PH_INIT, SOLVOL_INIT, AREA, HCO3_CONC, BUFFER_CAP
 100    FORMAT(/,' Hydroponic pH Module (prognostic, CO2-equil HCO3)',
     &         /,'   Target pH       : ',F5.2,
     &         /,'   Initial Vol.    : ',F6.1,' mm',
     &         /,'   Growing Area    : ',F6.2,' m2',
     &         /,'   HCO3- (CO2 eq.) : ',F6.3,' mg/L',
     &         /,'   Buffer Capacity : ',F6.4,' mol H+/pH',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Prognostic pH: integrate net H+ production through buffer capacity.
C       ΔpH = −(net H+ mol/day) / β_total
C
C       Buffer capacity β = β_CO2_equil + β_background + β_phosphate
C       β_background = 2.303 × BGALKAL × V  (irrigation water alkalinity,
C       0.5 mmol/L, provides ~0.5 mol H+/pH for a 72 L solution)
C-----------------------------------------------------------------------
        IF (ISWITCH % AUTO_PH .EQ. 'Y') THEN
          AUTO_PH_R = 1.0
        ELSE
          AUTO_PH_R = 0.0
        ENDIF

        CALL GET('HYDRO','SOLVOL',SOLVOL_CURRENT)
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

C       Phosphate speciation at current pH
        P_RATIO = 10.0 ** (PH_CALC - PKA_PHOSPHATE)
        P_CHARGE = (-1.0 - 2.0*P_RATIO) / (1.0 + P_RATIO)

C       HCO3- from CO2 equilibrium at current pH
        HCO3_CONC = K1_CA * CO2_AQ / (10.0**(-PH_CALC))  ! mol/L
        HCO3_CONC = HCO3_CONC * MW_HCO3 * 1000.0          ! mg/L
        HCO3_CONC = MAX(0.1, HCO3_CONC)

C       Daily concentration factor from transpiration (yesterday → today)
        IF (SOLVOL_PREV .GT. 0.1 .AND. SOLVOL_CURRENT .GT. 0.1) THEN
          CONCENTRATION_FACTOR = SOLVOL_PREV / SOLVOL_CURRENT
          CONCENTRATION_FACTOR = MAX(1.0, MIN(CONCENTRATION_FACTOR, 2.0))
        ELSE
          CONCENTRATION_FACTOR = 1.0
        ENDIF
        SOLVOL_PREV = SOLVOL_CURRENT

C       Net H+ production from N uptake stoichiometry
C       NH4+ → plant N + H+  (1 mol H+ per mol NH4-N)
C       NO3- + H+ → plant N  (consumes 1 mol H+ per mol NO3-N)
        H_PRODUCTION  = (NH4_UPTAKE * 1000.0) / MW_N  ! mol H+/ha/day
        H_CONSUMPTION = (NO3_UPTAKE * 1000.0) / MW_N  ! mol H+/ha/day
        NET_H_PRODUCTION = H_PRODUCTION - H_CONSUMPTION

C       Buffer capacity: CO2-equil HCO3 + background alkalinity + phosphate
        SOLVOL_L = MAX(5.0, SOLVOL_CURRENT * AREA)
        BUFFER_CAP = 2.303 * (HCO3_CONC / MW_HCO3 / 1000.0) * SOLVOL_L
        BUFFER_CAP = BUFFER_CAP + 2.303 * BGALKAL * SOLVOL_L
        P_FRAC = P_RATIO / (1.0 + P_RATIO)
        P_BUFFER_CAP = 2.303 * (P_CONC/MW_P/1000.0)
     &               * SOLVOL_L * P_FRAC * (1.0 - P_FRAC)
        BUFFER_CAP = BUFFER_CAP + P_BUFFER_CAP
        IF (BUFFER_CAP .LT. 0.01) THEN
          BUFFER_CAP = MAX(0.01, SOLVOL_L * 0.001)
        ENDIF

C       ΔpH = −(H+ mol/day for actual area) / β
C       Skip on first RATE call: uptake arguments may carry stale values
C       from the prior treatment run (SAVE'd state in calling modules).
        IF (FIRST_RATE) THEN
          PH_CHANGE = 0.0
          FIRST_RATE = .FALSE.
        ELSE IF (BUFFER_CAP .GT. 0.001 .AND. AREA .GT. 0.1) THEN
          NET_H_MOL_DAY = NET_H_PRODUCTION * AREA / 10000.0
          PH_CHANGE = -NET_H_MOL_DAY / BUFFER_CAP
        ELSE
          PH_CHANGE = 0.0
        ENDIF

C       No separate transpiration pH correction — as volume drops, SOLVOL_L
C       decreases, BUFFER_CAP decreases proportionally, and the same H+
C       production produces a larger ΔpH.  The effect is implicit.

C       Cap daily pH change at ±0.5 to prevent numerical instability
        PH_CHANGE = MAX(-0.5, MIN(0.5, PH_CHANGE))

C       Update pH
        IF (AUTO_PH_R .GT. 0.5) THEN
          PH_CALC = PH_TARGET
        ELSE
          PH_CALC = PH_CALC + PH_CHANGE
          IF (PH_CALC .LT. 3.0) PH_CALC = 3.0
          IF (PH_CALC .GT. 9.0) PH_CALC = 9.0
        ENDIF

        CALL PUT('HYDRO','PH',PH_CALC)

C-----------------------------------------------------------------------
C       pH-DEPENDENT NUTRIENT AVAILABILITY FACTORS
C       Gaussian: f(pH) = exp(-(pH - pH_opt)^2 / (2 * scale^2))
C-----------------------------------------------------------------------
        PH_EXP_NO3 = MAX(-10.0,-((PH_CALC-PH_OPT)**2)
     &                          /(2.0*PH_SCALE_NO3**2))
        PH_EXP_NH4 = MAX(-10.0,-((PH_CALC-PH_OPT)**2)
     &                          /(2.0*PH_SCALE_NH4**2))
        PH_EXP_P   = MAX(-10.0,-((PH_CALC-PH_OPT)**2)
     &                          /(2.0*PH_SCALE_P**2))
        PH_EXP_K   = MAX(-10.0,-((PH_CALC-PH_OPT)**2)
     &                          /(2.0*PH_SCALE_K**2))

        PH_AVAIL_NO3 = MAX(0.01, MIN(1.0, EXP(PH_EXP_NO3)))
        PH_AVAIL_NH4 = MAX(0.01, MIN(1.0, EXP(PH_EXP_NH4)))
        PH_AVAIL_P   = MAX(0.01, MIN(1.0, EXP(PH_EXP_P)))
        PH_AVAIL_K   = MAX(0.01, MIN(1.0, EXP(PH_EXP_K)))

C-----------------------------------------------------------------------
C       pH-DEPENDENT Km FACTORS
C       Km(pH) = Km_opt × exp(alpha × |pH - pH_opt|)
C-----------------------------------------------------------------------
        PH_DEVIATION = ABS(PH_CALC - PH_OPT)

        PH_KM_FACTOR_NO3 = MAX(1.0, MIN(5.0,
     &                         EXP(PH_KM_ALPHA_NO3 * PH_DEVIATION)))
        PH_KM_FACTOR_NH4 = MAX(1.0, MIN(5.0,
     &                         EXP(PH_KM_ALPHA_NH4 * PH_DEVIATION)))
        PH_KM_FACTOR_P   = MAX(1.0, MIN(5.0,
     &                         EXP(PH_KM_ALPHA_P   * PH_DEVIATION)))
        PH_KM_FACTOR_K   = MAX(1.0, MIN(5.0,
     &                         EXP(PH_KM_ALPHA_K   * PH_DEVIATION)))

        CALL PUT('HYDRO','PH_AVAIL_NO3',PH_AVAIL_NO3)
        CALL PUT('HYDRO','PH_AVAIL_NH4',PH_AVAIL_NH4)
        CALL PUT('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
        CALL PUT('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
        CALL PUT('HYDRO','PH_KM_FACTOR_NO3',PH_KM_FACTOR_NO3)
        CALL PUT('HYDRO','PH_KM_FACTOR_NH4',PH_KM_FACTOR_NH4)
        CALL PUT('HYDRO','PH_KM_FACTOR_P',PH_KM_FACTOR_P)
        CALL PUT('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR_K)

        PH_STRESS_TOTAL = MIN(PH_AVAIL_NO3, PH_AVAIL_NH4,
     &                        PH_AVAIL_P, PH_AVAIL_K)
        CALL PUT('HYDRO','PHSTRESS_ROOT',PH_STRESS_TOTAL)
        CALL PUT('HYDRO','PHSTRESS_LEAF',PH_STRESS_TOTAL)
        CALL PUT('HYDRO','PHSTRESS_UPTAKE',PH_STRESS_TOTAL)

        WRITE(*,200) NH4_UPTAKE, NO3_UPTAKE, NET_H_PRODUCTION,
     &               CONCENTRATION_FACTOR, SOLVOL_CURRENT, HCO3_CONC,
     &               BUFFER_CAP, PH_CHANGE, PH_CALC, PH_OPT,
     &               PH_AVAIL_NO3, PH_AVAIL_NH4, PH_AVAIL_P, PH_AVAIL_K,
     &               PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4
 200    FORMAT(' SOLPH: NH4=',F6.3,' NO3=',F6.3,' kg/ha/d',
     &         ' => Net H+=',F10.2,' mol/ha/d',/,
     &         '   ConcFactor=',F5.2,' (Vol=',F6.1,' mm)',
     &         ' HCO3=',F5.1,' mg/L  Buffer=',F6.4,
     &         ' => pH change=',F6.3,/,
     &         '   pH=',F5.2,' (Opt=',F4.2,')',
     &         ' Avail: NO3=',F5.3,' NH4=',F5.3,' P=',F5.3,' K=',F5.3,/,
     &         '   Km: NO3=',F5.3,' NH4=',F5.3)

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       INTEGR phase — pH calculated in RATE; output diagnostics only
C-----------------------------------------------------------------------
        H_CONC = 10.0 ** (-PH_CALC)

        WRITE(*,300) PH_CALC, PH_TARGET, PH_CHANGE, H_CONC * 1.0E6,
     &               HCO3_CONC, BUFFER_CAP
 300    FORMAT(' SOLPH: pH=',F5.2,' (Target=',F5.2,')',
     &         ' Change=',F6.3,/,
     &         '   [H+]=',F8.2,' umol/L  HCO3=',F5.1,' mg/L',
     &         ' Buffer=',F6.3,' mol H+/pH')

        IF (ABS(PH_CALC - PH_TARGET) .GT. 1.0) THEN
          WRITE(*,*) 'SOLPH WARNING: pH deviation >1.0 unit from target'
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLPH
