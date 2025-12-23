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
     &    PLTPOP, RTDEP, PDEMAND,              !Input
     &    UPO4,                                !Output - kg/ha/day
     &    P_SOL)                               !I/O - Solution conc. mg/L

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

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
      REAL SOLVOL        ! Solution volume (L)
      SAVE SOLVOL

C     Michaelis-Menten parameters for P
      REAL Vmax_P        ! Max uptake rate P (mg/plant/day)
      REAL Km_P          ! Half-saturation constant P (mg/L)

C     Uptake calculations
      REAL UP_plant      ! P uptake per plant (mg/plant/day)
      REAL UP_potential  ! Potential P uptake (kg/ha/day)
      REAL UPTAKE_FACTOR ! Scaling factor for growth stage
      REAL DEPL_P        ! Depletion rate (mg/L)
      REAL VOL_PER_HA    ! Solution volume per hectare (L/ha)
      INTEGER DYNAMIC

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize P concentration from ModuleData
C-----------------------------------------------------------------------
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','P_CONC',P_SOL)

        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0  ! Default 1000 L
          WRITE(*,*) 'SOLPi: Using default SOLVOL=',SOLVOL,'L'
        ENDIF

        IF (P_SOL .LT. 0.0) THEN
          P_SOL = 60.0  ! Default P concentration (mg/L)
          WRITE(*,*) 'SOLPi: Using default P_CONC=',P_SOL,'mg/L'
        ENDIF

C       Michaelis-Menten parameters for P (from hydroponic literature)
C       These are typical values - can be crop-specific
        Vmax_P = 8.0     ! mg P/plant/day (peak uptake)
        Km_P   = 0.3     ! mg/L (half-saturation)

        UPO4 = 0.0

        WRITE(*,100) P_SOL
 100    FORMAT(/,' Hydroponic Phosphorus Module Initialized',
     &         /,'   Initial P : ',F8.2,' mg/L',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate daily P uptake
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
C       Demand-based uptake strategy (similar to N uptake in NUPTAK)
C-----------------------------------------------------------------------
        IF (PDEMAND .GT. 1.E-9) THEN
          IF (P_SOL .GT. 5.0) THEN
C           Adequate P concentration (>5 mg/L) - uptake meets demand
            UPO4 = PDEMAND
          ELSE
C           Low P concentration - use Michaelis-Menten kinetics
            UP_plant = (Vmax_P * UPTAKE_FACTOR * P_SOL) /
     &                 (Km_P + P_SOL)

C           Convert from mg/plant/day to kg/ha/day
            UP_potential = UP_plant * PLTPOP * 0.01

C           Limit by demand
            UPO4 = MIN(UP_potential, PDEMAND)
          ENDIF
        ELSE
          UPO4 = 0.0
        ENDIF

C       Prevent negative uptake
        UPO4 = MAX(0.0, UPO4)

        WRITE(*,200) P_SOL, UPO4, PDEMAND
 200    FORMAT(' SOLPi: [P]=',F6.1,' mg/L',
     &         ' Uptake=',F6.3,' Demand=',F6.3,' kg/ha/d')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update solution P concentration after uptake
C-----------------------------------------------------------------------
        IF (SOLVOL .LT. 1.0) THEN
          CALL GET('HYDRO','SOLVOL',SOLVOL)
          IF (SOLVOL .LT. 1.0) SOLVOL = 1000.0
        ENDIF

        IF (SOLVOL .GT. 0.0 .AND. PLTPOP .GT. 0.0) THEN
C         Calculate solution volume per hectare
          VOL_PER_HA = SOLVOL * 10000.0  ! L/ha

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
