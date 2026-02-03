C=======================================================================
C  SOLPi, Subroutine
C
C  Hydroponic phosphorus uptake and solution management
C  Implements demand-based P uptake with Michaelis-Menten kinetics
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic P management
C-----------------------------------------------------------------------
C  Called from: CROPGRO nutrient uptake modules
C
C-----------------------------------------------------------------------

      SUBROUTINE SOLPi(
     &    CONTROL, ISWITCH,                    !Input
     &    FILECC, PLTPOP, RTDEP, PDEMAND,      !Input
     &    UPO4,                                !Output - kg/ha/day
     &    P_SOL)                               !I/O - Solution conc. mg/L

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, ERROR, IGNORE
      SAVE

      CHARACTER*92 FILECC

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables
      REAL PLTPOP        ! Plant population (plants/m2)
      REAL RTDEP         ! Root depth (cm)
      REAL PDEMAND       ! P demand (kg/ha/day)

C     Output variables
      REAL UPO4          ! Phosphate uptake (kg/ha/day)

C     Solution concentrations (mg/L)
      REAL P_SOL         ! Phosphorus in solution

C     Local variables
      REAL SOLVOL        ! Solution volume (mm) = (L/m2) - saved between calls
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      SAVE SOLVOL, SOLVOL_INIT, Vmax_P, Km_P

C     Michaelis-Menten parameters for P
      REAL Vmax_P        ! Max uptake rate P (mg/plant/day)
      REAL Km_P          ! Half-saturation constant P (mg/L)
      REAL Cmin_P        ! Min concentration for net uptake (mg/L)
      REAL Vmax_P_stressed ! Vmax_P after EC stress
      REAL Km_P_stressed   ! Km_P after pH stress
      REAL ECSTRESS_JMAX_P ! EC stress factor for P Jmax
      REAL PH_AVAIL_P      ! pH-dependent P availability factor
      REAL PH_KM_FACTOR_P  ! pH-dependent P Km factor
      REAL P_SOL_EFFECTIVE ! Effective P concentration (× pH availability)

C     Uptake calculations
      REAL UP_plant      ! P uptake per plant (mg/plant/day)
      REAL UP_potential  ! Potential P uptake (kg/ha/day)
      REAL UPTAKE_FACTOR ! Scaling factor for growth stage
      REAL DEPL_P        ! Depletion rate (mg/L)
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)

C     Plant demand from P_PLANT module (tissue-based, like N demand)
      REAL PDEMAND_USE   ! P demand from P_PLANT PTotDem (kg/ha/day)

C     Environmental factors (like HYDRO_NUTRIENT)
      REAL WATER_FACTOR  ! Water availability factor (0-1)
      REAL FLOW_FACTOR   ! Solution circulation/flow factor (0-1)
      REAL MIN_SOLVOL    ! Minimum solution volume for uptake (mm)
      REAL CRITICAL_SOLVOL ! Critical solution volume threshold (mm)

C     Mass flow variables
      REAL TRANSP_MM     ! Transpiration rate (mm/day)
      REAL MASS_FLOW_P   ! Passive P uptake via mass flow (kg/ha/day)
      REAL MASS_FLOW_COEF_P ! Mass flow coefficient for P (lower than NO3/K)
      DATA MASS_FLOW_COEF_P /0.08/  ! P is less mobile than NO3/NH4/K

C     Species file reading variables
      INTEGER LUNCRP, ERR, LINC, ISECT, FOUND
      CHARACTER*6 SECTION
      CHARACTER*80 CHAR

      INTEGER DYNAMIC

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
C-----------------------------------------------------------------------
C       Read species-specific P uptake parameters from .SPE file
C-----------------------------------------------------------------------
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('SOLPi',42,FILECC,0)

C       Find HYDROPONIC P UPTAKE PARAMETERS section
        SECTION = '!*HYDR'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (LINC .EQ. 0) THEN
          WRITE(*,*) 'SOLPi: !*HYDROPONIC P UPTAKE section not found'
          WRITE(*,*) '       Using default values'
          Vmax_P = 8.0     ! mg P/plant/day (default)
          Km_P   = 0.3     ! mg/L (default)
        ELSE
C         Read P uptake parameters: Vmax_P, Km_P
          READ(LUNCRP,'(14X,2F6.2)',IOSTAT=ERR) Vmax_P, Km_P
          IF (ERR .NE. 0) THEN
            WRITE(*,*) 'SOLPi: Error reading P uptake parameters'
            WRITE(*,*) '       Using default values'
            Vmax_P = 8.0
            Km_P   = 0.3
          ENDIF
        ENDIF

        CLOSE (LUNCRP)

C       C_min for P: minimum concentration for net uptake (mg/L)
C       Below C_min, efflux = influx, so net uptake = 0
C       Literature: ~1 μM for most crops (Barber 1984)
C       1 μM P = 0.031 mg/L (MW P = 31 g/mol)
        Cmin_P = 0.03     ! mg/L (= 1 μM)

        UPO4 = 0.0

        WRITE(*,100) Vmax_P, Km_P, Cmin_P
 100    FORMAT(/,' Hydroponic Phosphorus Module',
     &         /,'   Vmax_P: ',F6.2,' mg P/plant/day',
     &         /,'   Km_P  : ',F6.2,' mg/L',
     &         /,'   Cmin_P: ',F6.3,' mg/L',/)

      CASE (SEASINIT)
C-----------------------------------------------------------------------
C       Initialize P concentration from ModuleData
C       Also ensure Vmax_P and Km_P are initialized if not set in RUNINIT
C-----------------------------------------------------------------------
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','P_CONC',P_SOL)

C       Store initial solution volume for water-nutrient coupling
        SOLVOL_INIT = SOLVOL

        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default 1000 mm (= L/m2)
          SOLVOL_INIT = SOLVOL
          WRITE(*,*) 'SOLPi: Using default SOLVOL=',SOLVOL,'mm'
        ENDIF

        IF (P_SOL .LT. 0.0) THEN
          P_SOL = 60.0  ! Default P concentration (mg/L)
          WRITE(*,*) 'SOLPi: Using default P_CONC=',P_SOL,'mg/L'
        ENDIF

C       Ensure Vmax_P and Km_P are initialized (defaults if not set in RUNINIT)
        IF (Vmax_P .LT. 0.1) THEN
          Vmax_P = 8.0     ! Default: 8 mg P/plant/day
          Km_P = 0.3       ! Default: 0.3 mg/L
          WRITE(*,*) 'SOLPi SEASINIT: Using default Vmax_P=',Vmax_P,
     &               ' Km_P=',Km_P
        ENDIF

        WRITE(*,150) P_SOL
 150    FORMAT(' SOLPi SEASINIT: Initial [P]=',F8.2,' mg/L')

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily P uptake with environmental factors
C       Use demand-based approach when concentrations are adequate
C       P_SOL is passed as argument from calling routine (not retrieved here)
C-----------------------------------------------------------------------
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','EP',TRANSP_MM)
        IF (TRANSP_MM .LT. 0.0) TRANSP_MM = 0.0

C-----------------------------------------------------------------------
C       WATER-NUTRIENT COUPLING (same as HYDRO_NUTRIENT)
C-----------------------------------------------------------------------
        MIN_SOLVOL = SOLVOL_INIT * 0.10
        CRITICAL_SOLVOL = SOLVOL_INIT * 0.05

        IF (SOLVOL .LT. CRITICAL_SOLVOL) THEN
          UPO4 = 0.0
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

C       CRITICAL: Prevent division by zero with very small volumes
        IF (SOLVOL .GT. 0.1 .AND. SOLVOL_INIT .GT. 0.1) THEN
          FLOW_FACTOR = (SOLVOL / SOLVOL_INIT) ** 0.67
        ELSE
          FLOW_FACTOR = 0.2  ! Minimum flow factor for very low volumes
        ENDIF
        FLOW_FACTOR = MIN(1.0, MAX(0.2, FLOW_FACTOR))

C       Growth stage factor (simplified)
        IF (RTDEP .LT. 20.0) THEN
          UPTAKE_FACTOR = 0.3    ! Seedling stage
        ELSEIF (RTDEP .LT. 50.0) THEN
          UPTAKE_FACTOR = 0.7    ! Vegetative growth
        ELSE
          UPTAKE_FACTOR = 1.0    ! Peak growth
        ENDIF

C       Get plant P demand from ModuleData (fallback to PDEMAND if not set)
        CALL GET('HYDRO','PTOTDEM',PDEMAND_USE)
        IF (PDEMAND_USE .LT. 1.E-9 .AND. PDEMAND .GT. 1.E-9) THEN
          PDEMAND_USE = PDEMAND
        ENDIF

C       Supply-based uptake with demand limit (M-M kinetics)
        IF (PDEMAND_USE .GT. 1.E-9) THEN
C         Get pH-dependent availability and Km factors
          CALL GET('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
          CALL GET('HYDRO','PH_KM_FACTOR_P',PH_KM_FACTOR_P)
          IF (PH_AVAIL_P .LT. 0.01) PH_AVAIL_P = 1.0
          IF (PH_KM_FACTOR_P .LT. 0.1) PH_KM_FACTOR_P = 1.0
          
C         Calculate effective P concentration using pH availability
          P_SOL_EFFECTIVE = P_SOL * PH_AVAIL_P
          
          IF (P_SOL_EFFECTIVE .GT. 5.0) THEN
C           Adequate effective P concentration - uptake meets demand
            CALL GET('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
            IF (ECSTRESS_JMAX_P .LT. 0.1) ECSTRESS_JMAX_P = 1.0
            UPO4 = PDEMAND_USE * ECSTRESS_JMAX_P
          ELSE
C           Low effective P concentration - use Michaelis-Menten kinetics
            IF (Vmax_P .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
              CALL GET('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
              IF (ECSTRESS_JMAX_P .LT. 0.1) ECSTRESS_JMAX_P = 1.0

C             Apply pH-dependent Km (transporter affinity)
              Km_P_stressed = Km_P * PH_KM_FACTOR_P

              Vmax_P_stressed = Vmax_P * ECSTRESS_JMAX_P

C             Modified M-M with C_min threshold (Barber 1984)
C             Below C_min, no net uptake (efflux = influx)
              IF (P_SOL_EFFECTIVE .GT. Cmin_P) THEN
                UP_plant = (Vmax_P_stressed * UPTAKE_FACTOR *
     &                     (P_SOL_EFFECTIVE - Cmin_P)) /
     &                     (Km_P_stressed + P_SOL_EFFECTIVE - Cmin_P)
              ELSE
                UP_plant = 0.0  ! Below C_min: no net uptake
              ENDIF

C             Convert from mg/plant/day to kg/ha/day
              UP_potential = UP_plant * PLTPOP * 0.01

C             Limit by demand (but ensure minimum uptake if demand exists)
              UPO4 = MIN(UP_potential, PDEMAND_USE)

C             Debug: Check if calculation is working
              IF (UPO4 .LT. 1.E-6 .AND. PDEMAND_USE .GT. 0.01) THEN
                WRITE(*,*) ' SOLPi WARNING: Low uptake calculated:',
     &                     ' Vmax=',Vmax_P,' Km=',Km_P,
     &                     ' Ufac=',UPTAKE_FACTOR,
     &                     ' PLTPOP=',PLTPOP,' P_SOL=',P_SOL,
     &                     ' UP_potential=',UP_potential
              ENDIF
            ELSE
              UPO4 = 0.0
            ENDIF
          ENDIF
        ELSE
          UPO4 = 0.0
        ENDIF

C-----------------------------------------------------------------------
C       MASS FLOW COMPONENT (Passive uptake via transpiration)
C       P is less mobile than NO3/NH4/K, so use lower coefficient (0.08)
C-----------------------------------------------------------------------
        IF (TRANSP_MM .GT. 0.0 .AND. P_SOL .GT. 0.0) THEN
          CALL GET('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
          IF (ECSTRESS_JMAX_P .LT. 0.1) ECSTRESS_JMAX_P = 1.0
          MASS_FLOW_P = TRANSP_MM * 10000.0 * P_SOL * 1.0E-6 *
     &                  MASS_FLOW_COEF_P * ECSTRESS_JMAX_P
        ELSE
          MASS_FLOW_P = 0.0
        ENDIF

C       Total uptake = Active (M-M or demand-based) + Passive (Mass flow)
        UPO4 = UPO4 + MASS_FLOW_P

C       Prevent negative uptake
        UPO4 = MAX(0.0, UPO4)

        WRITE(*,200) P_SOL, UPO4, PDEMAND_USE, MASS_FLOW_P
 200    FORMAT(' SOLPi: [P]=',F6.1,' mg/L',
     &         ' Uptake=',F6.3,' PTotDem=',F6.3,' kg/ha/d',
     &         ' MassFlow=',F6.4,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution P concentration after uptake
C-----------------------------------------------------------------------
        CALL GET('HYDRO','P_CONC',P_SOL)  ! Retrieve current P concentration
        CALL GET('HYDRO','SOLVOL',SOLVOL)

        IF (SOLVOL .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         SOLVOL is in mm (= L/m²), so L/ha = SOLVOL * 10000 m²/ha
C         CRITICAL: Ensure minimum volume to prevent division overflow
          VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)  ! L/ha (min 10 L/ha = 0.001 mm)

C         Calculate depletion (mg/L)
          DEPL_P = (UPO4 * 1.0E6) / VOL_PER_HA

C         Update solution concentration
          P_SOL = MAX(0.0, P_SOL - DEPL_P)

          WRITE(*,300) DEPL_P, P_SOL
 300      FORMAT(' SOLPi depletion: dP=',F6.3,' mg/L',
     &           ' New [P]=',F6.1,' mg/L')
        ENDIF

C       Store updated concentration back to ModuleData
        CALL PUT('HYDRO','P_CONC',P_SOL)

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLPi
