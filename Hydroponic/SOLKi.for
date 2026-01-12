C=======================================================================
C  SOLKi, Subroutine
C
C  Hydroponic potassium uptake and solution management
C  Implements demand-based K uptake with Michaelis-Menten kinetics
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic K management
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

      CHARACTER*92 FILECC

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Input variables
      REAL PLTPOP        ! Plant population (plants/m2)
      REAL RTDEP         ! Root depth (cm)
      REAL KDEMAND       ! K demand (kg/ha/day)

C     Output variables
      REAL UK            ! Potassium uptake (kg/ha/day)

C     Solution concentrations (mg/L)
      REAL K_SOL         ! Potassium in solution

C     Local variables
      REAL SOLVOL        ! Solution volume (mm) = (L/m2) - saved between calls
      REAL SOLVOL_INIT   ! Initial solution volume (mm)
      REAL SOLTEMP       ! Solution temperature (C)
      REAL TRANSP_MM     ! Transpiration rate (mm/day)
      SAVE SOLVOL, SOLVOL_INIT

C     Michaelis-Menten parameters for K
      REAL Vmax_K        ! Max uptake rate K (mg/plant/day)
      REAL Km_K          ! Half-saturation constant K (mg/L)
      REAL Vmax_K_stressed ! Vmax_K after EC stress
      REAL Km_K_stressed   ! Km_K after pH stress
      REAL ECSTRESS_JMAX_K ! EC stress factor for K Jmax
      REAL PH_AVAIL_K      ! pH-dependent K availability factor
      REAL PH_KM_FACTOR_K  ! pH-dependent K Km factor
      REAL K_SOL_EFFECTIVE ! Effective K concentration (× pH availability)

C     Uptake calculations
      REAL UK_plant      ! K uptake per plant (mg/plant/day)
      REAL UK_potential  ! Potential K uptake (kg/ha/day)
      REAL UPTAKE_FACTOR ! Scaling factor for growth stage
      REAL DEPL_K        ! Depletion rate (mg/L)
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)

C     Environmental factors (like HYDRO_NUTRIENT)
      REAL WATER_FACTOR  ! Water availability factor (0-1)
      REAL FLOW_FACTOR   ! Solution circulation/flow factor (0-1)
      REAL TEMP_FACTOR   ! Temperature correction factor (0-1)
      REAL MIN_SOLVOL    ! Minimum solution volume for uptake (mm)
      REAL CRITICAL_SOLVOL ! Critical solution volume threshold (mm)

C     Mass flow component (K is mobile like NO3)
      REAL MASS_FLOW_K   ! Passive K uptake via mass flow (kg/ha/day)

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
C       Read species-specific K uptake parameters from .SPE file
C-----------------------------------------------------------------------
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('SOLKi',42,FILECC,0)

C       Find HYDROPONIC K UPTAKE PARAMETERS section
        SECTION = '!*HYDR'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (LINC .EQ. 0) THEN
          WRITE(*,*) 'SOLKi: !*HYDROPONIC K UPTAKE section not found'
          WRITE(*,*) '       Using default values'
          Vmax_K = 60.0    ! mg K/plant/day (default)
          Km_K   = 1.0     ! mg/L (default)
        ELSE
C         Read first line (skip - this has P parameters)
          READ(LUNCRP,'(A)',IOSTAT=ERR) CHAR
C         Read K uptake parameters: Vmax_K, Km_K
          READ(LUNCRP,'(14X,2F6.2)',IOSTAT=ERR) Vmax_K, Km_K
          IF (ERR .NE. 0) THEN
            WRITE(*,*) 'SOLKi: Error reading K uptake parameters'
            WRITE(*,*) '       Using default values'
            Vmax_K = 60.0
            Km_K   = 1.0
          ENDIF
        ENDIF

        CLOSE (LUNCRP)

        UK = 0.0

        WRITE(*,100) Vmax_K, Km_K
 100    FORMAT(/,' Hydroponic Potassium Module',
     &         /,'   Vmax_K: ',F6.2,' mg K/plant/day',
     &         /,'   Km_K  : ',F6.2,' mg/L',/)

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
C       Calculate daily K uptake with environmental factors
C       Use demand-based approach when concentrations are adequate
C-----------------------------------------------------------------------
        CALL GET('HYDRO','K_CONC',K_SOL)  ! Retrieve current K concentration
        CALL GET('HYDRO','TEMP',SOLTEMP)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','EP',TRANSP_MM)
        IF (TRANSP_MM .LT. 0.0) TRANSP_MM = 0.0

C-----------------------------------------------------------------------
C       WATER-NUTRIENT COUPLING (same as HYDRO_NUTRIENT)
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

C       CRITICAL: Prevent division by zero with very small volumes
        IF (SOLVOL .GT. 0.1 .AND. SOLVOL_INIT .GT. 0.1) THEN
          FLOW_FACTOR = (SOLVOL / SOLVOL_INIT) ** 0.67
        ELSE
          FLOW_FACTOR = 0.2  ! Minimum flow factor for very low volumes
        ENDIF
        FLOW_FACTOR = MIN(1.0, MAX(0.2, FLOW_FACTOR))

C       Temperature correction (simplified - similar to HYDRO_NUTRIENT)
        IF (SOLTEMP .LT. 5.0) THEN
          TEMP_FACTOR = 0.0
        ELSE IF (SOLTEMP .GT. 35.0) THEN
          TEMP_FACTOR = 0.0
        ELSE IF (SOLTEMP .GE. 18.0 .AND. SOLTEMP .LE. 22.0) THEN
          TEMP_FACTOR = 1.0
        ELSE IF (SOLTEMP .LT. 18.0) THEN
          TEMP_FACTOR = (SOLTEMP - 5.0) / (18.0 - 5.0)
        ELSE
          TEMP_FACTOR = (35.0 - SOLTEMP) / (35.0 - 22.0)
        ENDIF

C       Growth stage factor (simplified)
        IF (RTDEP .LT. 20.0) THEN
          UPTAKE_FACTOR = 0.3    ! Seedling stage
        ELSEIF (RTDEP .LT. 50.0) THEN
          UPTAKE_FACTOR = 0.7    ! Vegetative growth
        ELSE
          UPTAKE_FACTOR = 1.0    ! Peak growth
        ENDIF

C-----------------------------------------------------------------------
C       Demand-based uptake strategy with environmental factors
C       In hydroponic systems with adequate concentrations, uptake meets demand
C       Only temperature limits uptake (water/flow factors don't apply in recirculating systems)
C-----------------------------------------------------------------------
!       CRITICAL: Ensure K_SOL is valid (>= 0.0) before calculations
        IF (K_SOL .LT. 0.0) K_SOL = 0.0
        
        IF (KDEMAND .GT. 1.E-9) THEN
C         Get pH-dependent availability and Km factors
          CALL GET('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
          CALL GET('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR_K)
          IF (PH_AVAIL_K .LT. 0.01) PH_AVAIL_K = 1.0
          IF (PH_KM_FACTOR_K .LT. 0.1) PH_KM_FACTOR_K = 1.0
          
C         Calculate effective K concentration using pH availability
          K_SOL_EFFECTIVE = K_SOL * PH_AVAIL_K
          
          IF (K_SOL_EFFECTIVE .GT. 10.0) THEN
C           Adequate effective K concentration - uptake meets demand
C           Apply temperature factor and EC stress
            CALL GET('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
            IF (ECSTRESS_JMAX_K .LT. 0.1) ECSTRESS_JMAX_K = 1.0
            UK = KDEMAND * TEMP_FACTOR * ECSTRESS_JMAX_K
          ELSE
C           Low effective K concentration - use Michaelis-Menten kinetics
C           Apply temperature factor and EC stress
            CALL GET('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
            IF (ECSTRESS_JMAX_K .LT. 0.1) ECSTRESS_JMAX_K = 1.0

C           Apply pH-dependent Km (transporter affinity)
            Km_K_stressed = Km_K * PH_KM_FACTOR_K
            
            Vmax_K_stressed = Vmax_K * ECSTRESS_JMAX_K
            UK_plant = (Vmax_K_stressed * UPTAKE_FACTOR * TEMP_FACTOR * K_SOL_EFFECTIVE) /
     &                 (Km_K_stressed + K_SOL_EFFECTIVE)

C           Convert from mg/plant/day to kg/ha/day
            UK_potential = UK_plant * PLTPOP * 0.01

C           Limit by demand
            UK = MIN(UK_potential, KDEMAND)
          ENDIF
        ELSE
          UK = 0.0
        ENDIF

C-----------------------------------------------------------------------
C       Add MASS FLOW component for K (like NO3 in HYDRO_NUTRIENT)
C       K+ is highly mobile in xylem, similar to NO3-
C       EC stress also affects mass flow (reduces transpiration stream efficiency)
C-----------------------------------------------------------------------
        IF (TRANSP_MM .GT. 0.0) THEN
C         Convert transpiration to L/ha: mm × 10000 m²/ha = L/ha
C         Mass flow (kg/ha/d) = Transp (mm/d) × 10000 × Conc (mg/L) × 1e-6
C         Apply EC stress to mass flow (reduces efficiency of transpiration stream)
          MASS_FLOW_K = TRANSP_MM * 10000.0 * K_SOL * 1.0E-6 * 0.10 
     &                  * ECSTRESS_JMAX_K
C         Coefficient: K (b=0.10) from literature
C         This represents fraction of transpiration stream carrying nutrient
C         EC stress reduces this efficiency
        ELSE
          MASS_FLOW_K = 0.0
        ENDIF

C       Total uptake = Active (Michaelis-Menten) + Passive (Mass flow)
        UK = UK + MASS_FLOW_K

C       Prevent negative uptake
        UK = MAX(0.0, UK)

        WRITE(*,200) K_SOL, UK, KDEMAND, SOLTEMP, TEMP_FACTOR, MASS_FLOW_K
 200    FORMAT(' SOLKi: [K]=',F6.1,' mg/L',
     &         ' Uptake=',F6.3,' Demand=',F6.3,' kg/ha/d',/,
     &         '   Temp=',F5.1,'C Tfac=',F4.2,
     &         ' MassFlow: K=',F6.3,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution K concentration after uptake
C-----------------------------------------------------------------------
        CALL GET('HYDRO','K_CONC',K_SOL)  ! Retrieve current K concentration
        CALL GET('HYDRO','SOLVOL',SOLVOL)

        IF (SOLVOL .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         SOLVOL is in mm (= L/m²), so L/ha = SOLVOL * 10000 m²/ha
C         CRITICAL: Ensure minimum volume to prevent division overflow
          VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)  ! L/ha (min 10 L/ha = 0.001 mm)

C         Calculate depletion (mg/L)
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
