C=======================================================================
C  HYDRO_NUTRIENT, Subroutine
C
C  Hydroponic nutrient uptake using Michaelis-Menten kinetics
C  V = Vmax * [S] / (Km + [S])
C  CALIBRATED FOR LETTUCE (Lactuca sativa)
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic nutrient uptake
C  01/08/2026 Calibrated for lettuce using literature values
C-----------------------------------------------------------------------
C  Called from: Nitrogen/nutrient uptake modules
C
C-----------------------------------------------------------------------

      SUBROUTINE HYDRO_NUTRIENT(
     &    CONTROL, ISWITCH,                    !Input
     &    FILECC, PLTPOP, RTDEP, RWU_HYDRO, TRLV, VSTAGE,  !Input
     &    UNO3, UNH4,                          !Output
     &    NO3_SOL, NH4_SOL)                    !I/O - Solution conc.

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL TABEX
      SAVE

      CHARACTER*92 FILECC
      CHARACTER*6  ERRKEY
      PARAMETER (ERRKEY = 'HYDNUT')

      INTEGER II

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables
      REAL PLTPOP        ! Plant population (plants/m2)
      REAL RTDEP         ! Root depth (cm)
      REAL RWU_HYDRO     ! Water uptake (cm3/plant/day)
      REAL TRLV          ! Total root length per unit area (cm/cm2) from ROOTS
      REAL VSTAGE        ! Vegetative stage (main stage variable)

C     Output variables - uptake rates (kg/ha/day)
      REAL UNO3          ! Nitrate uptake
      REAL UNH4          ! Ammonium uptake

C     Solution concentrations (mg/L) - updated by depletion
      REAL NO3_SOL       ! Nitrate in solution
      REAL NH4_SOL       ! Ammonium in solution

C     Local variables
      REAL SOLVOL        ! Solution volume (mm) - saved between calls
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL NO3_CONC_INIT ! Initial NO3 concentration (mg/L)
      REAL NH4_CONC_INIT ! Initial NH4 concentration (mg/L)

C     Water-nutrient coupling variables
      REAL WATER_FACTOR  ! Water availability factor (0-1)
      REAL FLOW_FACTOR   ! Solution circulation/flow factor (0-1)
      REAL MASS_FLOW_NO3 ! Passive NO3 uptake via mass flow (kg/ha/day)
      REAL MASS_FLOW_NH4 ! Passive NH4 uptake via mass flow (kg/ha/day)
      REAL MASS_FLOW_K   ! Passive K uptake via mass flow (kg/ha/day)
      REAL TRANSP_MM     ! Transpiration rate (mm/day)
      REAL MIN_SOLVOL    ! Minimum solution volume for uptake (mm)
      REAL CRITICAL_SOLVOL ! Critical solution volume threshold (mm)

C     Michaelis-Menten parameters for LETTUCE (from literature)
C     Values from general multi-ion model (lettuce/sorghum calibration)
      REAL Jmax_NO3      ! Max uptake rate NO3 (mol/m2/s)
      REAL Jmax_NH4      ! Max uptake rate NH4 (mol/m2/s)

      REAL Km_NO3        ! Half-saturation constant NO3 (mol/m3)
      REAL Km_NH4        ! Half-saturation constant NH4 (mol/m3)

C     C_min: Minimum concentration for net uptake (mol/m3)
C     Below C_min, efflux = influx, so net uptake = 0
C     Values from literature (Barber 1984, Claassen & Barber 1974)
      REAL Cmin_NO3      ! Min concentration NO3 (mol/m3) ~5 μM
      REAL Cmin_NH4      ! Min concentration NH4 (mol/m3) ~5 μM

C     Conversion factors and intermediate variables
      REAL ROOT_AREA     ! Root surface area per plant (m2/plant)
      REAL ROOT_RADIUS   ! Root radius (m) - species parameter
      REAL ROOT_LENGTH   ! Root length per plant (m/plant) - from TRLV
      
C     Uptake calculations
      REAL UNO3_plant    ! NO3 uptake per plant (mg/plant/day)
      REAL UNH4_plant    ! NH4 uptake per plant (mg/plant/day)
      REAL UNO3_potential ! Potential NO3 uptake (kg/ha/day)
      REAL UNH4_potential ! Potential NH4 uptake (kg/ha/day)
      REAL UN_potential   ! Total potential N uptake (kg/ha/day)

C     N demand from plant module (for demand-based limiting)
      REAL NDMNEW        ! N demand for new growth (g/m2/day) from DEMAND.for
      REAL NDEMAND_KG    ! N demand converted to kg/ha/day

C     Uptake in mol/m2/s (from M-M equation)
      REAL J_NO3         ! NO3 influx (mol/m2/s)
      REAL J_NH4         ! NH4 influx (mol/m2/s)

C     EC and pH stress-modified parameters
      REAL Jmax_NO3_stressed  ! NO3 Jmax after EC stress
      REAL Jmax_NH4_stressed  ! NH4 Jmax after EC stress
      REAL Km_NO3_stressed    ! NO3 Km after EC and pH stress
      REAL Km_NH4_stressed    ! NH4 Km after pH stress
      REAL ECSTRESS_JMAX_NO3  ! EC stress factor for NO3 Jmax
      REAL ECSTRESS_JMAX_NH4  ! EC stress factor for NH4 Jmax
      REAL ECSTRESS_KM_NO3    ! EC stress factor for NO3 Km
      REAL PH_AVAIL_NO3       ! pH-dependent NO3 availability factor
      REAL PH_AVAIL_NH4       ! pH-dependent NH4 availability factor
      REAL PH_KM_FACTOR_NO3   ! pH-dependent NO3 Km factor
      REAL PH_KM_FACTOR_NH4   ! pH-dependent NH4 Km factor
      REAL NO3_CONC_EFFECTIVE ! Effective NO3 concentration (× pH availability)
      REAL NH4_CONC_EFFECTIVE ! Effective NH4 concentration (× pH availability)

      REAL UPTAKE_FACTOR ! Scaling factor for crop growth stage
      REAL DEPL_NO3, DEPL_NH4  ! Depletion rates
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)
      REAL GROWING_AREA  ! Growing area (m2) - for area conversions
      REAL VOL_AREA_RATIO ! Solution volume per unit area (L/m2)
      REAL AUTO_CONC_R   ! AUTO_CONC flag (1.0=maintain conc, 0.0=deplete)

C     Concentration conversion (mg/L to mol/m3)
      REAL NO3_CONC_MOL  ! NO3 concentration (mol/m3)
      REAL NH4_CONC_MOL  ! NH4 concentration (mol/m3)
      
C     Molecular weights (g/mol)
      REAL MW_N          ! Nitrogen molecular weight
      
      REAL TABEX         ! Function for table lookup

C     Growth stage effect on nutrient uptake (from species file)
      REAL XNUSTG(10)    ! VSTAGE values for nutrient uptake scaling
      REAL YNUSTG(10)    ! Relative nutrient uptake at each VSTAGE
      SAVE XNUSTG, YNUSTG  ! Preserve between calls

      INTEGER DYNAMIC
      SAVE SOLVOL_INIT

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
C-----------------------------------------------------------------------
C       Initialize growth stage effect on nutrient uptake
C-----------------------------------------------------------------------
        XNUSTG(1) = 0.0
        XNUSTG(2) = 1.0
        XNUSTG(3) = 2.0
        XNUSTG(4) = 3.0
        XNUSTG(5) = 4.0
        XNUSTG(6) = 5.0
        XNUSTG(7) = 6.0
        XNUSTG(8) = 10.0
        XNUSTG(9) = 20.0
        XNUSTG(10) = 30.0

        YNUSTG(1) = 0.3
        YNUSTG(2) = 0.5
        YNUSTG(3) = 0.7
        YNUSTG(4) = 0.9
        YNUSTG(5) = 1.0
        YNUSTG(6) = 1.0
        YNUSTG(7) = 1.0
        YNUSTG(8) = 0.8
        YNUSTG(9) = 0.6
        YNUSTG(10) = 0.4

        WRITE(*,*) 'HYDRO_NUTRIENT: Initialized (no temp factor)'

C-----------------------------------------------------------------------
C       Initialize solution concentrations from ModuleData
C-----------------------------------------------------------------------
      CASE (SEASINIT)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)

C       Store initial solution volume for water-nutrient coupling
        SOLVOL_INIT = SOLVOL

        WRITE(*,*) 'HYDRO_NUTRIENT INIT: Concentrations:'
        WRITE(*,*) '  NO3=',NO3_SOL,' NH4=',NH4_SOL,
     &             ' SOLVOL=',SOLVOL,' mm'

C-----------------------------------------------------------------------
C       Michaelis-Menten parameters for LETTUCE
C       From general multi-ion model (lettuce/sorghum calibration)
C-----------------------------------------------------------------------
C       Jmax values (mol/m2/s) - from literature
        Jmax_NO3 = 3.23E-8   ! mol/m2/s
        Jmax_NH4 = 4.20E-8   ! mol/m2/s

C       Km values (mol/m3) - from literature
        Km_NO3   = 0.015     ! mol/m3 (= 0.015 mM = 0.21 mg N/L)
        Km_NH4   = 0.0539    ! mol/m3 (= 0.0539 mM = 0.75 mg N/L)

C       C_min values (mol/m3) - minimum concentration for net uptake
C       Below C_min, passive efflux balances active influx (net uptake = 0)
C       Literature: Barber (1984), Claassen & Barber (1974)
C       Values: ~5 μM for NO3, ~5 μM for NH4 (onion, general crops)
        Cmin_NO3 = 0.005     ! mol/m3 (= 5 μM = 0.07 mg N/L)
        Cmin_NH4 = 0.005     ! mol/m3 (= 5 μM = 0.07 mg N/L)

C       Root morphological parameters
C       ROOT_RADIUS is a species-specific parameter (lettuce)
C       Root length (TRLV) comes dynamically from CROPGRO ROOTS module
        ROOT_RADIUS = 1.5E-4  ! m (0.15 mm) - lettuce root radius

C       Molecular weights (g/mol)
        MW_N = 14.007         ! g/mol

        UNO3 = 0.0
        UNH4 = 0.0

        WRITE(*,200) NO3_SOL, NH4_SOL
 200    FORMAT(/,' Hydroponic Nitrogen Module',
     &         /,'   Initial NO3-N : ',F8.2,' mg/L',
     &         /,'   Initial NH4-N : ',F8.2,' mg/L',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily N uptake using Michaelis-Menten
C       with water-nutrient coupling for realistic hydroponic behavior
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)

C-----------------------------------------------------------------------
C       WATER-NUTRIENT COUPLING (Scientifically based)
C       1. Critical water threshold: Below 10% of initial, uptake stops
C       2. Water availability factor: Uptake scales with water volume
C       3. Flow/circulation factor: Adequate water needed for nutrient delivery
C-----------------------------------------------------------------------
        MIN_SOLVOL = SOLVOL_INIT * 0.10      ! 10% of initial
        CRITICAL_SOLVOL = SOLVOL_INIT * 0.05 ! 5% critical threshold

C       Check if solution volume is critically low
        IF (SOLVOL .LT. CRITICAL_SOLVOL) THEN
          WRITE(*,*) '*** CRITICAL WARNING: Solution volume too low! ***'
          WRITE(*,*) '    Current:',SOLVOL,' mm  Critical:',CRITICAL_SOLVOL
          WRITE(*,*) '    Nutrient uptake STOPPED - system failure'
          UNO3 = 0.0
          UNH4 = 0.0
          RETURN
        ENDIF

C       Water availability factor (linear decline as water depletes)
C       Based on solution volume relative to initial
C       Range: 0.3 (at MIN_SOLVOL) to 1.0 (at full volume)
        IF (SOLVOL .GE. SOLVOL_INIT) THEN
          WATER_FACTOR = 1.0
        ELSE IF (SOLVOL .LE. MIN_SOLVOL) THEN
          WATER_FACTOR = 0.3  ! Minimum 30% uptake at low water
        ELSE
          WATER_FACTOR = 0.3 + 0.7 * (SOLVOL - MIN_SOLVOL) /
     &                   (SOLVOL_INIT - MIN_SOLVOL)
        ENDIF

C       Flow/circulation factor (non-linear decline)
C       Accounts for reduced mixing and nutrient delivery at low volume
C       Based on turbulent flow principles: Flow ∝ Volume^0.67
C       CRITICAL: Prevent division by zero with very small volumes
        IF (SOLVOL .GT. 0.1 .AND. SOLVOL_INIT .GT. 0.1) THEN
          FLOW_FACTOR = (SOLVOL / SOLVOL_INIT) ** 0.67
        ELSE
          FLOW_FACTOR = 0.2  ! Minimum flow factor for very low volumes
        ENDIF
        FLOW_FACTOR = MIN(1.0, MAX(0.2, FLOW_FACTOR))

C       Get transpiration for mass flow calculation
C       EP is stored in ModuleData by HYDRO_WATER module (mm/day)
        CALL GET('HYDRO','EP',TRANSP_MM)
        IF (TRANSP_MM .LT. 0.0) TRANSP_MM = 0.0

C       Growth stage factor based on VSTAGE (from species file)
C       Same approach as canopy height (CANOPY.for)
C       Safeguard: If VSTAGE is outside table range, use boundary values
        IF (VSTAGE .LE. XNUSTG(1)) THEN
          UPTAKE_FACTOR = YNUSTG(1)
        ELSE IF (VSTAGE .GE. XNUSTG(10)) THEN
          UPTAKE_FACTOR = YNUSTG(10)
        ELSE
          UPTAKE_FACTOR = TABEX(YNUSTG,XNUSTG,VSTAGE,10)
        ENDIF

C       Calculate root surface area from TRLV (cm root/cm2 ground)
        IF (TRLV .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
          ROOT_LENGTH = TRLV * 100.0 / PLTPOP  ! m/plant
          ROOT_AREA = 2.0 * 3.14159 * ROOT_RADIUS * ROOT_LENGTH  ! m2/plant
        ELSE
          ROOT_AREA = 0.0
          WRITE(*,*) 'HYDRO_NUTRIENT WARNING: No roots (TRLV=0)'
        ENDIF

C       Convert concentrations from mg/L to mol/m3
        NO3_CONC_MOL = NO3_SOL / MW_N
        NH4_CONC_MOL = NH4_SOL / MW_N

C       Get EC and pH stress factors
        CALL GET('HYDRO','ECSTRESS_JMAX_NO3',ECSTRESS_JMAX_NO3)
        CALL GET('HYDRO','ECSTRESS_JMAX_NH4',ECSTRESS_JMAX_NH4)
        CALL GET('HYDRO','ECSTRESS_KM_NO3',ECSTRESS_KM_NO3)

C       Get pH-dependent availability factors (sigmoidal function)
        CALL GET('HYDRO','PH_AVAIL_NO3',PH_AVAIL_NO3)
        CALL GET('HYDRO','PH_AVAIL_NH4',PH_AVAIL_NH4)

C       Get pH-dependent Km factors (transporter affinity)
        CALL GET('HYDRO','PH_KM_FACTOR_NO3',PH_KM_FACTOR_NO3)
        CALL GET('HYDRO','PH_KM_FACTOR_NH4',PH_KM_FACTOR_NH4)

C       Default to 1.0 if not set (no stress)
        IF (ECSTRESS_JMAX_NO3 .LT. 0.1) ECSTRESS_JMAX_NO3 = 1.0
        IF (ECSTRESS_JMAX_NH4 .LT. 0.1) ECSTRESS_JMAX_NH4 = 1.0
        IF (ECSTRESS_KM_NO3 .LT. 0.1) ECSTRESS_KM_NO3 = 1.0
        IF (PH_AVAIL_NO3 .LT. 0.01) PH_AVAIL_NO3 = 1.0
        IF (PH_AVAIL_NH4 .LT. 0.01) PH_AVAIL_NH4 = 1.0
        IF (PH_KM_FACTOR_NO3 .LT. 0.1) PH_KM_FACTOR_NO3 = 1.0
        IF (PH_KM_FACTOR_NH4 .LT. 0.1) PH_KM_FACTOR_NH4 = 1.0

C       Apply EC stress to Jmax (non-competitive inhibition)
        Jmax_NO3_stressed = Jmax_NO3 * ECSTRESS_JMAX_NO3
        Jmax_NH4_stressed = Jmax_NH4 * ECSTRESS_JMAX_NH4

C       Apply pH-dependent Km (transporter affinity) and EC stress to Km
C       Combined: Km = Km_opt × ECSTRESS_KM × PH_KM_FACTOR
        Km_NO3_stressed = Km_NO3 * ECSTRESS_KM_NO3 * PH_KM_FACTOR_NO3
        Km_NH4_stressed = Km_NH4 * PH_KM_FACTOR_NH4

C       Calculate effective concentrations using pH-dependent availability
C       Effective [S] = Actual [S] × f(pH)
        NO3_CONC_EFFECTIVE = NO3_CONC_MOL * PH_AVAIL_NO3
        NH4_CONC_EFFECTIVE = NH4_CONC_MOL * PH_AVAIL_NH4

C-----------------------------------------------------------------------
C       Modified M-M with C_min: J = Jmax×([S]-Cmin)/(Km+[S]-Cmin)
C-----------------------------------------------------------------------
C       NO3 uptake
        IF (NO3_CONC_EFFECTIVE .GT. Cmin_NO3) THEN
          J_NO3 = (Jmax_NO3_stressed * UPTAKE_FACTOR *
     &             WATER_FACTOR * FLOW_FACTOR *
     &             (NO3_CONC_EFFECTIVE - Cmin_NO3)) /
     &            (Km_NO3_stressed + NO3_CONC_EFFECTIVE - Cmin_NO3)
        ELSE
C         Below C_min: no net uptake (efflux = influx)
          J_NO3 = 0.0
        ENDIF

C       NH4 uptake
        IF (NH4_CONC_EFFECTIVE .GT. Cmin_NH4) THEN
          J_NH4 = (Jmax_NH4_stressed * UPTAKE_FACTOR *
     &             WATER_FACTOR * FLOW_FACTOR *
     &             (NH4_CONC_EFFECTIVE - Cmin_NH4)) /
     &            (Km_NH4_stressed + NH4_CONC_EFFECTIVE - Cmin_NH4)
        ELSE
C         Below C_min: no net uptake (efflux = influx)
          J_NH4 = 0.0
        ENDIF

C       Convert from mol/m2/s to mg/plant/day
        UNO3_plant = J_NO3 * ROOT_AREA * 86400.0 * MW_N * 1000.0
        UNH4_plant = J_NH4 * ROOT_AREA * 86400.0 * MW_N * 1000.0

C       Convert to kg/ha/day (active uptake)
        UNO3_potential = UNO3_plant * PLTPOP * 0.01
        UNH4_potential = UNH4_plant * PLTPOP * 0.01

C       Mass flow component (passive uptake via transpiration)
        IF (TRANSP_MM .GT. 0.0) THEN
          MASS_FLOW_NO3 = TRANSP_MM * 10000.0 * NO3_SOL * 1.0E-6 * 0.15
     &                    * ECSTRESS_JMAX_NO3
          MASS_FLOW_NH4 = TRANSP_MM * 10000.0 * NH4_SOL * 1.0E-6 * 0.15
     &                    * ECSTRESS_JMAX_NH4
        ELSE
          MASS_FLOW_NO3 = 0.0
          MASS_FLOW_NH4 = 0.0
        ENDIF

C       Total potential uptake = Active (M-M) + Passive (Mass flow)
        UNO3_potential = UNO3_potential + MASS_FLOW_NO3
        UNH4_potential = UNH4_potential + MASS_FLOW_NH4
        UN_potential = UNO3_potential + UNH4_potential

C-----------------------------------------------------------------------
C       DEMAND-BASED LIMITATION (consistent with SOLKi/SOLPi approach)
C       Get N demand from plant module and limit uptake
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NDMNEW',NDMNEW)
        IF (NDMNEW .LT. 1.E-9) NDMNEW = 0.0

C       Convert N demand from g/m2/day to kg/ha/day
        NDEMAND_KG = NDMNEW * 10.0

C       Apply demand-based limitation (allow 20% luxury uptake for N)
        IF (NDEMAND_KG .GT. 1.E-9) THEN
          IF (UN_potential .GT. NDEMAND_KG * 1.2) THEN
C           Scale down both NO3 and NH4 proportionally
            UNO3 = UNO3_potential * (NDEMAND_KG * 1.2) / UN_potential
            UNH4 = UNH4_potential * (NDEMAND_KG * 1.2) / UN_potential
          ELSE
            UNO3 = UNO3_potential
            UNH4 = UNH4_potential
          ENDIF
        ELSE
C         Low demand: allow passive uptake only
          UNO3 = MASS_FLOW_NO3
          UNH4 = MASS_FLOW_NH4
        ENDIF

        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)

        WRITE(*,300) NO3_SOL, NH4_SOL,
     &               UNO3, UNH4,
     &               SOLVOL, WATER_FACTOR, FLOW_FACTOR,
     &               MASS_FLOW_NO3, MASS_FLOW_NH4
 300    FORMAT(' HYDRO_NUTRIENT (LETTUCE):',
     &         ' [NO3]=',F6.1,' [NH4]=',F6.1,' mg/L',/,
     &         '   Uptake: NO3=',F6.3,' NH4=',F6.3,' kg/ha/d',/,
     &         '   SolVol=',F6.1,' mm Wfac=',F4.2,' Ffac=',F4.2,/,
     &         '   MassFlow: NO3=',F6.3,' NH4=',F6.3,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update N solution concentrations after uptake
C       If AUTO_CONC = Y (1.0), skip depletion (maintain constant conc)
C-----------------------------------------------------------------------
        CALL GET('HYDRO','AUTO_CONC',AUTO_CONC_R)
        IF (AUTO_CONC_R .LT. 0.5) AUTO_CONC_R = 0.0  ! Default: deplete

        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)

        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       SOLVOL is in mm (= L/m²), so L/ha = SOLVOL * 10000 m²/ha
C       CRITICAL: Ensure minimum volume to prevent division overflow
        VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)  ! L/ha (min 10 L/ha = 0.001 mm)

C       Only deplete concentration if AUTO_CONC = N (0.0)
C       If AUTO_CONC = Y (1.0), nutrients are replenished to maintain conc
        IF (AUTO_CONC_R .LT. 0.5) THEN
          DEPL_NO3 = (UNO3 * 1.0E6) / VOL_PER_HA  ! mg/L depleted
          DEPL_NH4 = (UNH4 * 1.0E6) / VOL_PER_HA

          NO3_SOL = MAX(0.0, NO3_SOL - DEPL_NO3)
          NH4_SOL = MAX(0.0, NH4_SOL - DEPL_NH4)

          CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
          CALL PUT('HYDRO','NH4_CONC',NH4_SOL)

          WRITE(*,400) DEPL_NO3, DEPL_NH4
 400      FORMAT(' N solution depletion (LETTUCE):',
     &           ' dNO3=',F6.3,' dNH4=',F6.3,' mg/L')
        ELSE
          WRITE(*,*) ' AUTO_CONC=Y: N concentration maintained constant'
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_NUTRIENT