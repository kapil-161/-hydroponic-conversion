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
      EXTERNAL GETLUN, ERROR, IGNORE, CURV, TABEX
      SAVE

      CHARACTER*92 FILECC
      CHARACTER*80 CHAR
      CHARACTER*3  TYPNUT
      CHARACTER*6  ERRKEY
      PARAMETER (ERRKEY = 'HYDNUT')

      INTEGER LUNCRP, ERR, LNUM, ISECT, II

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
      REAL SOLTEMP       ! Solution temperature (C)
      REAL NO3_CONC_INIT ! Initial NO3 concentration (mg/L)
      REAL NH4_CONC_INIT ! Initial NH4 concentration (mg/L)

C     Water-nutrient coupling variables
      REAL WATER_FACTOR  ! Water availability factor (0-1)
      REAL FLOW_FACTOR   ! Solution circulation/flow factor (0-1)
      REAL MASS_FLOW_NO3 ! Passive NO3 uptake via mass flow (kg/ha/day)
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

C     Conversion factors and intermediate variables
      REAL ROOT_AREA     ! Root surface area per plant (m2/plant)
      REAL ROOT_RADIUS   ! Root radius (m) - species parameter
      REAL ROOT_LENGTH   ! Root length per plant (m/plant) - from TRLV
      
C     Uptake calculations
      REAL UNO3_plant    ! NO3 uptake per plant (mg/plant/day)
      REAL UNH4_plant    ! NH4 uptake per plant (mg/plant/day)

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
      REAL TEMP_FACTOR   ! Temperature correction factor (0-1)
      REAL DEPL_NO3, DEPL_NH4  ! Depletion rates
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)
      REAL GROWING_AREA  ! Growing area (m2) - for area conversions
      REAL VOL_AREA_RATIO ! Solution volume per unit area (L/m2)

C     Concentration conversion (mg/L to mol/m3)
      REAL NO3_CONC_MOL  ! NO3 concentration (mol/m3)
      REAL NH4_CONC_MOL  ! NH4 concentration (mol/m3)
      
C     Molecular weights (g/mol)
      REAL MW_N          ! Nitrogen molecular weight
      
C     Temperature parameters for nutrient uptake (from species file)
      REAL FNNUT(4)      ! Temperature effect function values (Tmin, Topt1, Topt2, Tmax)
      REAL CURV, TABEX   ! Functions for curve interpolation and table lookup

C     Growth stage effect on nutrient uptake (from species file)
      REAL XNUSTG(10)    ! VSTAGE values for nutrient uptake scaling
      REAL YNUSTG(10)    ! Relative nutrient uptake at each VSTAGE
      SAVE XNUSTG, YNUSTG, FNNUT, TYPNUT  ! Preserve between calls

      INTEGER DYNAMIC
      SAVE SOLVOL_INIT

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
C-----------------------------------------------------------------------
C       Read hydroponic nutrient uptake parameters from species file
C-----------------------------------------------------------------------
        LNUM = 0
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP,FILE = FILECC, STATUS = 'OLD',IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,0)

C       Skip to HYDROPONIC NUTRIENT section
   10   CONTINUE
        CALL IGNORE(LUNCRP,LNUM,ISECT,CHAR)
        IF (ISECT .EQ. 0) THEN
C         Section not found - use default values
          FNNUT(1) = 5.0   ! Minimum temperature (C)
          FNNUT(2) = 18.0  ! Lower optimal temperature (C)
          FNNUT(3) = 22.0  ! Upper optimal temperature (C)
          FNNUT(4) = 35.0  ! Maximum temperature (C)
          TYPNUT = 'LIN'   ! Linear interpolation
          WRITE(*,*) 'HYDRO_NUTRIENT: Using default temperature params'
          GOTO 20
        ENDIF
        IF (INDEX(CHAR,'!*HYDROPONIC NUTRIENT') .EQ. 0) GO TO 10

C       Read temperature effect on nutrient uptake
        CALL IGNORE(LUNCRP,LNUM,ISECT,CHAR)
        READ(CHAR,'(4F6.0,3X,A3)',IOSTAT=ERR)
     &    (FNNUT(II),II=1,4), TYPNUT
        IF (ERR .NE. 0) THEN
C         Error reading - use defaults
          FNNUT(1) = 5.0
          FNNUT(2) = 18.0
          FNNUT(3) = 22.0
          FNNUT(4) = 35.0
          TYPNUT = 'LIN'
          WRITE(*,*) 'HYDRO_NUTRIENT: Error reading temp params, ',
     &               'using defaults'
        ENDIF

C       Read growth stage effect on nutrient uptake
        CALL IGNORE(LUNCRP,LNUM,ISECT,CHAR)
        READ(CHAR,'(10F6.0)',IOSTAT=ERR) (XNUSTG(II),II=1,10)
        IF (ERR .NE. 0) THEN
C         Use defaults - seedling to mature
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
        ENDIF

        CALL IGNORE(LUNCRP,LNUM,ISECT,CHAR)
        READ(CHAR,'(10F6.0)',IOSTAT=ERR) (YNUSTG(II),II=1,10)
        IF (ERR .NE. 0) THEN
C         Use defaults - gradual increase to peak
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
        ENDIF

   20   CONTINUE
        CLOSE (LUNCRP)

        WRITE(*,*) 'HYDRO_NUTRIENT: Temperature parameters:'
        WRITE(*,*) '  FNNUT=',FNNUT(1),FNNUT(2),FNNUT(3),FNNUT(4)
        WRITE(*,*) '  TYPNUT=',TYPNUT

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

C       Root morphological parameters
C       ROOT_RADIUS is a species-specific parameter (lettuce)
C       Root length (TRLV) comes dynamically from CROPGRO ROOTS module
        ROOT_RADIUS = 1.5E-4  ! m (0.15 mm) - lettuce root radius

C       Molecular weights (g/mol)
        MW_N = 14.007         ! g/mol

        UNO3 = 0.0
        UNH4 = 0.0

        WRITE(*,200) NO3_SOL, NH4_SOL,
     &               FNNUT(1), FNNUT(2), FNNUT(3), FNNUT(4), TYPNUT
 200    FORMAT(/,' Hydroponic Nitrogen Module',
     &         /,'   Initial NO3-N : ',F8.2,' mg/L',
     &         /,'   Initial NH4-N : ',F8.2,' mg/L',
     &         /,'   Temp range    : ',F4.0,' to ',F4.0,' C',
     &         ' (opt: ',F4.0,'-',F4.0,' C) Type: ',A3,/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily N uptake using Michaelis-Menten
C       with water-nutrient coupling for realistic hydroponic behavior
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)

        CALL GET('HYDRO','TEMP',SOLTEMP)
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

C       Calculate temperature correction factor using species file parameters
C       Same approach as photosynthesis (PHOTO.for)
        TEMP_FACTOR = CURV(TYPNUT,FNNUT(1),FNNUT(2),FNNUT(3),
     &                     FNNUT(4),SOLTEMP)

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

C-----------------------------------------------------------------------
C       Get dynamic root length from CROPGRO ROOTS module
C       TRLV = Total root length per unit ground area (cm/cm2)
C       Calculate root surface area per plant from TRLV
C       Root area = 2 * pi * radius * length
C       CRITICAL: NO ROOTS = NO UPTAKE (scientifically correct)
C-----------------------------------------------------------------------
C       TRLV is passed from ROOTS module (cm root / cm2 ground)
        IF (TRLV .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         Convert TRLV to root length per plant
C         TRLV is in cm/cm2, convert to m/plant
C         ROOT_LENGTH (m/plant) = TRLV (cm/cm2) * (10000 cm2/m2) /
C                                 (PLTPOP plants/m2) * (1 m / 100 cm)
          ROOT_LENGTH = TRLV * 100.0 / PLTPOP  ! m/plant
          ROOT_AREA = 2.0 * 3.14159 * ROOT_RADIUS * ROOT_LENGTH  ! m2/plant
        ELSE
C         NO ROOTS = NO UPTAKE (scientifically correct behavior)
          ROOT_AREA = 0.0  ! Zero root area when no roots present
          WRITE(*,*) 'HYDRO_NUTRIENT WARNING: No roots (TRLV=0) - ',
     &               'nutrient uptake set to ZERO'
        ENDIF

C-----------------------------------------------------------------------
C       Convert concentrations from mg/L to mol/m3
C       1 mg/L = 1 g/m3
C       mol/m3 = (g/m3) / (MW g/mol) = mg/L / MW
C-----------------------------------------------------------------------
        NO3_CONC_MOL = NO3_SOL / MW_N  ! mol/m3
        NH4_CONC_MOL = NH4_SOL / MW_N  ! mol/m3

C-----------------------------------------------------------------------
C       Get EC stress factors from SOLEC module
C       Get pH-dependent availability and Km factors from SOLPH module
C       New approach: pH affects both nutrient availability and transporter affinity
C-----------------------------------------------------------------------
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
C       Modified Michaelis-Menten equation with pH-dependent availability:
C       J = Jmax × [S]_effective / (Km_stressed + [S]_effective)
C       where [S]_effective = [S] × f(pH)
C       J is in mol/m2/s (influx per unit root surface area)
C       Apply ALL environmental factors: temperature, growth stage, water, flow, EC stress
C-----------------------------------------------------------------------
        J_NO3 = (Jmax_NO3_stressed * UPTAKE_FACTOR * TEMP_FACTOR *
     &           WATER_FACTOR * FLOW_FACTOR * NO3_CONC_EFFECTIVE)/
     &          (Km_NO3_stressed + NO3_CONC_EFFECTIVE)  ! mol/m2/s

        J_NH4 = (Jmax_NH4_stressed * UPTAKE_FACTOR * TEMP_FACTOR *
     &           WATER_FACTOR * FLOW_FACTOR * NH4_CONC_EFFECTIVE)/
     &          (Km_NH4_stressed + NH4_CONC_EFFECTIVE)  ! mol/m2/s

C-----------------------------------------------------------------------
C       Convert from influx (mol/m2/s) to uptake per plant (mg/plant/day)
C       Uptake = J (mol/m2/s) * ROOT_AREA (m2/plant) *
C                86400 (s/day) * MW (g/mol) * 1000 (mg/g)
C-----------------------------------------------------------------------
        UNO3_plant = J_NO3 * ROOT_AREA * 86400.0 * MW_N * 1000.0  ! mg N/plant/day
        UNH4_plant = J_NH4 * ROOT_AREA * 86400.0 * MW_N * 1000.0  ! mg N/plant/day

C-----------------------------------------------------------------------
C       Convert from mg/plant/day to kg/ha/day
C       kg/ha/day = mg/plant/day * plants/m2 * 10000 m2/ha * 1e-6 kg/mg
C                 = mg/plant/day * plants/m2 * 0.01
C-----------------------------------------------------------------------
        UNO3 = UNO3_plant * PLTPOP * 0.01  ! kg N/ha/day (active)
        UNH4 = UNH4_plant * PLTPOP * 0.01  ! kg N/ha/day (active)

C-----------------------------------------------------------------------
C       Add MASS FLOW component for passive uptake via transpiration
C       Mass flow uptake = Transpiration (mm/d) × Concentration (mg/L)
C       Applies mainly to NO3- (highly mobile in xylem)
C       Coefficient b represents fraction of water influx carrying nutrient
C       EC stress also affects mass flow (reduces transpiration stream efficiency)
C-----------------------------------------------------------------------
        IF (TRANSP_MM .GT. 0.0) THEN
C         Convert transpiration to L/ha: mm × 10000 m²/ha = L/ha
C         Mass flow (kg/ha/d) = Transp (mm/d) × 10000 × Conc (mg/L) × 1e-6
C         Apply EC stress to mass flow (reduces efficiency of transpiration stream)
          MASS_FLOW_NO3 = TRANSP_MM * 10000.0 * NO3_SOL * 1.0E-6 * 0.15 
     &                    * ECSTRESS_JMAX_NO3
C         Coefficient: NO3 (b=0.15) from literature
C         This represents fraction of transpiration stream carrying nutrient
C         EC stress reduces this efficiency
        ELSE
          MASS_FLOW_NO3 = 0.0
        ENDIF

C       Total uptake = Active (Michaelis-Menten) + Passive (Mass flow)
        UNO3 = UNO3 + MASS_FLOW_NO3

        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)

        WRITE(*,300) NO3_SOL, NH4_SOL,
     &               UNO3, UNH4, SOLTEMP, TEMP_FACTOR,
     &               SOLVOL, WATER_FACTOR, FLOW_FACTOR,
     &               MASS_FLOW_NO3
 300    FORMAT(' HYDRO_NUTRIENT (LETTUCE):',
     &         ' [NO3]=',F6.1,' [NH4]=',F6.1,' mg/L',/,
     &         '   Uptake: NO3=',F6.3,' NH4=',F6.3,' kg/ha/d',/,
     &         '   Temp=',F5.1,'C Tfac=',F4.2,
     &         ' SolVol=',F6.1,' mm Wfac=',F4.2,' Ffac=',F4.2,/,
     &         '   MassFlow: NO3=',F6.3,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update N solution concentrations after uptake
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)

        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       SOLVOL is in mm (= L/m²), so L/ha = SOLVOL * 10000 m²/ha
C       CRITICAL: Ensure minimum volume to prevent division overflow
        VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)  ! L/ha (min 10 L/ha = 0.001 mm)

        DEPL_NO3 = (UNO3 * 1.0E6) / VOL_PER_HA  ! mg/L depleted
        DEPL_NH4 = (UNH4 * 1.0E6) / VOL_PER_HA

        NO3_SOL = MAX(0.0, NO3_SOL - DEPL_NO3)
        NH4_SOL = MAX(0.0, NH4_SOL - DEPL_NH4)

        CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
        CALL PUT('HYDRO','NH4_CONC',NH4_SOL)

        WRITE(*,400) DEPL_NO3, DEPL_NH4
 400    FORMAT(' N solution depletion (LETTUCE):',
     &         ' dNO3=',F6.3,' dNH4=',F6.3,' mg/L')

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_NUTRIENT