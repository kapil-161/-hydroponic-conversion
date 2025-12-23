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
     &    PLTPOP, RTDEP, KDEMAND,              !Input
     &    UK,                                  !Output - kg/ha/day
     &    K_SOL)                               !I/O - Solution conc. mg/L

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

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
      REAL SOLVOL        ! Solution volume (L)
      SAVE SOLVOL

C     Michaelis-Menten parameters for K
      REAL Vmax_K        ! Max uptake rate K (mg/plant/day)
      REAL Km_K          ! Half-saturation constant K (mg/L)

C     Uptake calculations
      REAL UK_plant      ! K uptake per plant (mg/plant/day)
      REAL UK_potential  ! Potential K uptake (kg/ha/day)
      REAL UPTAKE_FACTOR ! Scaling factor for growth stage
      REAL DEPL_K        ! Depletion rate (mg/L)
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)
      INTEGER DYNAMIC

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize K concentration from ModuleData
C-----------------------------------------------------------------------
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','K_CONC',K_SOL)

        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default 1000 L
          WRITE(*,*) 'SOLKi: Using default SOLVOL=',SOLVOL,'L'
        ENDIF

        IF (K_SOL .LT. 0.0) THEN
          K_SOL = 240.0  ! Default K concentration (mg/L)
          WRITE(*,*) 'SOLKi: Using default K_CONC=',K_SOL,'mg/L'
        ENDIF

C       Michaelis-Menten parameters for K (from hydroponic literature)
C       These are typical values - can be crop-specific
        Vmax_K = 60.0    ! mg K/plant/day (peak uptake)
        Km_K   = 1.0     ! mg/L (half-saturation)

        UK = 0.0

        WRITE(*,100) K_SOL
 100    FORMAT(/,' Hydroponic Potassium Module Initialized',
     &         /,'   Initial K : ',F8.2,' mg/L',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily K uptake
C       Use demand-based approach when concentrations are adequate
C-----------------------------------------------------------------------

C       Growth stage factor (simplified)
        IF (RTDEP .LT. 20.0) THEN
          UPTAKE_FACTOR = 0.3    ! Seedling stage
        ELSEIF (RTDEP .LT. 50.0) THEN
          UPTAKE_FACTOR = 0.7    ! Vegetative growth
        ELSE
          UPTAKE_FACTOR = 1.0    ! Peak growth
        ENDIF

C-----------------------------------------------------------------------
C       Demand-based uptake strategy (similar to N and P uptake)
C-----------------------------------------------------------------------
        IF (KDEMAND .GT. 1.E-9) THEN
          IF (K_SOL .GT. 10.0) THEN
C           Adequate K concentration (>10 mg/L) - uptake meets demand
            UK = KDEMAND
          ELSE
C           Low K concentration - use Michaelis-Menten kinetics
            UK_plant = (Vmax_K * UPTAKE_FACTOR * K_SOL) /
     &                 (Km_K + K_SOL)

C           Convert from mg/plant/day to kg/ha/day
            UK_potential = UK_plant * PLTPOP * 0.01

C           Limit by demand
            UK = MIN(UK_potential, KDEMAND)
          ENDIF
        ELSE
          UK = 0.0
        ENDIF

C       Prevent negative uptake
        UK = MAX(0.0, UK)

        WRITE(*,200) K_SOL, UK, KDEMAND
 200    FORMAT(' SOLKi: [K]=',F6.1,' mg/L',
     &         ' Uptake=',F6.3,' Demand=',F6.3,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution K concentration after uptake
C-----------------------------------------------------------------------
        IF (SOLVOL .LT. 1.0) THEN
          CALL GET('HYDRO','SOLVOL',SOLVOL)
          IF (SOLVOL .LT. 1.0) SOLVOL = 1000.0
        ENDIF

        IF (SOLVOL .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         Calculate solution volume per hectare
          VOL_PER_HA = SOLVOL * 10000.0  ! L/ha

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
