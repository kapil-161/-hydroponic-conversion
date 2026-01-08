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
     &    UNO3, UNH4, UPO4, UK,                !Output
     &    NO3_SOL, NH4_SOL, P_SOL, K_SOL)      !I/O - Solution conc.

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
      REAL UPO4          ! Phosphate uptake
      REAL UK            ! Potassium uptake

C     Solution concentrations (mg/L) - updated by depletion
      REAL NO3_SOL       ! Nitrate in solution
      REAL NH4_SOL       ! Ammonium in solution
      REAL P_SOL         ! Phosphorus in solution
      REAL K_SOL         ! Potassium in solution

C     Local variables
      REAL SOLVOL        ! Solution volume (mm) - saved between calls
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL SOLTEMP       ! Solution temperature (C)
      REAL NO3_CONC_INIT ! Initial NO3 concentration (mg/L)
      REAL NH4_CONC_INIT ! Initial NH4 concentration (mg/L)
      REAL P_CONC_INIT   ! Initial P concentration (mg/L)
      REAL K_CONC_INIT   ! Initial K concentration (mg/L)

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
      REAL Jmax_P        ! Max uptake rate P (mol/m2/s)
      REAL Jmax_K        ! Max uptake rate K (mol/m2/s)

      REAL Km_NO3        ! Half-saturation constant NO3 (mol/m3)
      REAL Km_NH4        ! Half-saturation constant NH4 (mol/m3)
      REAL Km_P          ! Half-saturation constant P (mol/m3)
      REAL Km_K          ! Half-saturation constant K (mol/m3)

C     Conversion factors and intermediate variables
      REAL ROOT_AREA     ! Root surface area per plant (m2/plant)
      REAL ROOT_RADIUS   ! Root radius (m) - species parameter
      REAL ROOT_LENGTH   ! Root length per plant (m/plant) - from TRLV
      
C     Uptake calculations
      REAL UNO3_plant    ! NO3 uptake per plant (mg/plant/day)
      REAL UNH4_plant    ! NH4 uptake per plant (mg/plant/day)
      REAL UP_plant      ! P uptake per plant (mg/plant/day)
      REAL UK_plant      ! K uptake per plant (mg/plant/day)

C     Uptake in mol/m2/s (from M-M equation)
      REAL J_NO3         ! NO3 influx (mol/m2/s)
      REAL J_NH4         ! NH4 influx (mol/m2/s)
      REAL J_P           ! P influx (mol/m2/s)
      REAL J_K           ! K influx (mol/m2/s)

      REAL UPTAKE_FACTOR ! Scaling factor for crop growth stage
      REAL TEMP_FACTOR   ! Temperature correction factor (0-1)
      REAL DEPL_NO3, DEPL_NH4, DEPL_P, DEPL_K  ! Depletion rates
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)
      REAL GROWING_AREA  ! Growing area (m2) - for area conversions
      REAL VOL_AREA_RATIO ! Solution volume per unit area (L/m2)
      
C     Concentration conversion (mg/L to mol/m3)
      REAL NO3_CONC_MOL  ! NO3 concentration (mol/m3)
      REAL NH4_CONC_MOL  ! NH4 concentration (mol/m3)
      REAL P_CONC_MOL    ! P concentration (mol/m3)
      REAL K_CONC_MOL    ! K concentration (mol/m3)
      
C     Molecular weights (g/mol)
      REAL MW_N          ! Nitrogen molecular weight
      REAL MW_P          ! Phosphorus molecular weight
      REAL MW_K          ! Potassium molecular weight
      
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
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

C       Store initial solution volume for water-nutrient coupling
        SOLVOL_INIT = SOLVOL

        WRITE(*,*) 'HYDRO_NUTRIENT INIT: Concentrations:'
        WRITE(*,*) '  NO3=',NO3_SOL,' NH4=',NH4_SOL,
     &             ' P=',P_SOL,' K=',K_SOL,' SOLVOL=',SOLVOL,' mm'

C-----------------------------------------------------------------------
C       Michaelis-Menten parameters for LETTUCE
C       From general multi-ion model (lettuce/sorghum calibration)
C-----------------------------------------------------------------------
C       Jmax values (mol/m2/s) - from literature
        Jmax_NO3 = 3.23E-8   ! mol/m2/s
        Jmax_NH4 = 4.20E-8   ! mol/m2/s
        Jmax_P   = 1.06E-8   ! mol/m2/s
        Jmax_K   = 4.82E-8   ! mol/m2/s

C       Km values (mol/m3) - from literature
        Km_NO3   = 0.015     ! mol/m3 (= 0.015 mM = 0.21 mg N/L)
        Km_NH4   = 0.0539    ! mol/m3 (= 0.0539 mM = 0.75 mg N/L)
        Km_P     = 0.005     ! mol/m3 (= 0.005 mM = 0.155 mg P/L)
        Km_K     = 0.0127    ! mol/m3 (= 0.0127 mM = 0.497 mg K/L)

C       Root morphological parameters
C       ROOT_RADIUS is a species-specific parameter (lettuce)
C       Root length (TRLV) comes dynamically from CROPGRO ROOTS module
        ROOT_RADIUS = 1.5E-4  ! m (0.15 mm) - lettuce root radius

C       Molecular weights (g/mol)
        MW_N = 14.007         ! g/mol
        MW_P = 30.974         ! g/mol
        MW_K = 39.098         ! g/mol

        UNO3 = 0.0
        UNH4 = 0.0
        UPO4 = 0.0
        UK   = 0.0

        WRITE(*,200) NO3_SOL, NH4_SOL, P_SOL, K_SOL,
     &               FNNUT(1), FNNUT(2), FNNUT(3), FNNUT(4), TYPNUT
 200    FORMAT(/,' Hydroponic Nutrient Module',
     &         /,'   Initial NO3-N : ',F8.2,' mg/L',
     &         /,'   Initial NH4-N : ',F8.2,' mg/L',
     &         /,'   Initial P     : ',F8.2,' mg/L',
     &         /,'   Initial K     : ',F8.2,' mg/L',
     &         /,'   Temp range    : ',F4.0,' to ',F4.0,' C',
     &         ' (opt: ',F4.0,'-',F4.0,' C) Type: ',A3,/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily nutrient uptake using Michaelis-Menten
C       with water-nutrient coupling for realistic hydroponic behavior
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

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
          UPO4 = 0.0
          UK = 0.0
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
        FLOW_FACTOR = (SOLVOL / SOLVOL_INIT) ** 0.67
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
        P_CONC_MOL   = P_SOL / MW_P    ! mol/m3
        K_CONC_MOL   = K_SOL / MW_K    ! mol/m3

C-----------------------------------------------------------------------
C       Michaelis-Menten equation: J = Jmax * [S] / (Km + [S])
C       J is in mol/m2/s (influx per unit root surface area)
C       Apply ALL environmental factors: temperature, growth stage, water, flow
C-----------------------------------------------------------------------
        J_NO3 = (Jmax_NO3 * UPTAKE_FACTOR * TEMP_FACTOR *
     &           WATER_FACTOR * FLOW_FACTOR * NO3_CONC_MOL)/
     &          (Km_NO3 + NO3_CONC_MOL)  ! mol/m2/s

        J_NH4 = (Jmax_NH4 * UPTAKE_FACTOR * TEMP_FACTOR *
     &           WATER_FACTOR * FLOW_FACTOR * NH4_CONC_MOL)/
     &          (Km_NH4 + NH4_CONC_MOL)  ! mol/m2/s

        J_P = (Jmax_P * UPTAKE_FACTOR * TEMP_FACTOR *
     &         WATER_FACTOR * FLOW_FACTOR * P_CONC_MOL) /
     &        (Km_P + P_CONC_MOL)  ! mol/m2/s

        J_K = (Jmax_K * UPTAKE_FACTOR * TEMP_FACTOR *
     &         WATER_FACTOR * FLOW_FACTOR * K_CONC_MOL) /
     &        (Km_K + K_CONC_MOL)  ! mol/m2/s

C-----------------------------------------------------------------------
C       Convert from influx (mol/m2/s) to uptake per plant (mg/plant/day)
C       Uptake = J (mol/m2/s) * ROOT_AREA (m2/plant) * 
C                86400 (s/day) * MW (g/mol) * 1000 (mg/g)
C-----------------------------------------------------------------------
        UNO3_plant = J_NO3 * ROOT_AREA * 86400.0 * MW_N * 1000.0  ! mg N/plant/day
        UNH4_plant = J_NH4 * ROOT_AREA * 86400.0 * MW_N * 1000.0  ! mg N/plant/day
        UP_plant   = J_P   * ROOT_AREA * 86400.0 * MW_P * 1000.0  ! mg P/plant/day
        UK_plant   = J_K   * ROOT_AREA * 86400.0 * MW_K * 1000.0  ! mg K/plant/day

C-----------------------------------------------------------------------
C       Convert from mg/plant/day to kg/ha/day
C       kg/ha/day = mg/plant/day * plants/m2 * 10000 m2/ha * 1e-6 kg/mg
C                 = mg/plant/day * plants/m2 * 0.01
C-----------------------------------------------------------------------
        UNO3 = UNO3_plant * PLTPOP * 0.01  ! kg N/ha/day (active)
        UNH4 = UNH4_plant * PLTPOP * 0.01  ! kg N/ha/day (active)
        UPO4 = UP_plant   * PLTPOP * 0.01  ! kg P/ha/day (active)
        UK   = UK_plant   * PLTPOP * 0.01  ! kg K/ha/day (active)

C-----------------------------------------------------------------------
C       Add MASS FLOW component for passive uptake via transpiration
C       Mass flow uptake = Transpiration (mm/d) × Concentration (mg/L)
C       Applies mainly to NO3- and K+ (highly mobile in xylem)
C       Coefficient b represents fraction of water influx carrying nutrient
C-----------------------------------------------------------------------
        IF (TRANSP_MM .GT. 0.0) THEN
C         Convert transpiration to L/ha: mm × 10000 m²/ha = L/ha
C         Mass flow (kg/ha/d) = Transp (mm/d) × 10000 × Conc (mg/L) × 1e-6
          MASS_FLOW_NO3 = TRANSP_MM * 10000.0 * NO3_SOL * 1.0E-6 * 0.15
          MASS_FLOW_K   = TRANSP_MM * 10000.0 * K_SOL * 1.0E-6 * 0.10
C         Coefficients: NO3 (b=0.15), K (b=0.10) from literature
C         These represent fraction of transpiration stream carrying nutrient
        ELSE
          MASS_FLOW_NO3 = 0.0
          MASS_FLOW_K = 0.0
        ENDIF

C       Total uptake = Active (Michaelis-Menten) + Passive (Mass flow)
        UNO3 = UNO3 + MASS_FLOW_NO3
        UK   = UK + MASS_FLOW_K

        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)
        UPO4 = MAX(0.0, UPO4)
        UK   = MAX(0.0, UK)

        WRITE(*,300) NO3_SOL, NH4_SOL, P_SOL, K_SOL,
     &               UNO3, UNH4, UPO4, UK, SOLTEMP, TEMP_FACTOR,
     &               SOLVOL, WATER_FACTOR, FLOW_FACTOR,
     &               MASS_FLOW_NO3, MASS_FLOW_K
 300    FORMAT(' HYDRO_NUTRIENT (LETTUCE):',
     &         ' [NO3]=',F6.1,' [NH4]=',F6.1,' [P]=',F6.1,' [K]=',F6.1,
     &         ' mg/L',/,
     &         '   Uptake: NO3=',F6.3,' NH4=',F6.3,' P=',F6.3,
     &         ' K=',F6.3,' kg/ha/d',/,
     &         '   Temp=',F5.1,'C Tfac=',F4.2,
     &         ' SolVol=',F6.1,' mm Wfac=',F4.2,' Ffac=',F4.2,/,
     &         '   MassFlow: NO3=',F6.3,' K=',F6.3,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution concentrations after uptake
C-----------------------------------------------------------------------
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','AREA',GROWING_AREA)

C       SOLVOL is in mm (= L/m²), so L/ha = SOLVOL * 10000 m²/ha
        VOL_PER_HA = SOLVOL * 10000.0  ! L/ha

        DEPL_NO3 = (UNO3 * 1.0E6) / VOL_PER_HA  ! mg/L depleted
        DEPL_NH4 = (UNH4 * 1.0E6) / VOL_PER_HA
        DEPL_P   = (UPO4 * 1.0E6) / VOL_PER_HA
        DEPL_K   = (UK * 1.0E6)   / VOL_PER_HA

        NO3_SOL = MAX(0.0, NO3_SOL - DEPL_NO3)
        NH4_SOL = MAX(0.0, NH4_SOL - DEPL_NH4)
        P_SOL   = MAX(0.0, P_SOL - DEPL_P)
        K_SOL   = MAX(0.0, K_SOL - DEPL_K)

        CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
        CALL PUT('HYDRO','NH4_CONC',NH4_SOL)
        CALL PUT('HYDRO','P_CONC',P_SOL)
        CALL PUT('HYDRO','K_CONC',K_SOL)

        WRITE(*,400) DEPL_NO3, DEPL_NH4, DEPL_P, DEPL_K
 400    FORMAT(' Solution depletion (LETTUCE):',
     &         ' dNO3=',F6.3,' dNH4=',F6.3,
     &         ' dP=',F6.3,' dK=',F6.3,' mg/L')

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_NUTRIENT