C=======================================================================
C  SOLO2, Subroutine
C
C  Hydroponic dissolved oxygen (DO2) calculation and management
C  Tracks oxygen concentration changes due to consumption and aeration
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic DO2 management
C-----------------------------------------------------------------------
C  Called from: SPAM or main hydroponic routine
C
C-----------------------------------------------------------------------

      SUBROUTINE SOLO2(
     &    CONTROL, ISWITCH, WEATHER,          !Input
     &    PLTPOP, ROOT_RESP,                  !Input
     &    DO2_CALC, DO2_SAT)                  !Output - mg/L

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH
      TYPE (WeatherType) WEATHER

C     Input variables
      REAL PLTPOP        ! Plant population (plants/m2)
      REAL ROOT_RESP     ! Root respiration rate (g CO2/m2/day)

C     Output variables
      REAL DO2_CALC      ! Calculated dissolved O2 (mg/L)
      REAL DO2_SAT       ! Saturation DO2 at current temp (mg/L)

C     Local variables
      REAL DO2_INIT      ! Initial DO2 value (mg/L)
      REAL SOLVOL        ! Solution volume (L)
      REAL SOLTEMP       ! Solution temperature (C)
      REAL O2_CONSUME    ! O2 consumption (mg/L/day)
      REAL O2_AERATION   ! O2 addition from aeration (mg/L/day)
      REAL AERATION_RATE ! Aeration efficiency (0-1)

C     Constants for DO2 saturation calculation
C     DO2_sat = 14.6 - 0.41*T + 0.008*T^2 - 0.000077*T^3 (mg/L)
C     Valid for 0-40°C
      REAL A0, A1, A2, A3
      PARAMETER (A0 = 14.6, A1 = -0.41, A2 = 0.008, A3 = -0.000077)

      INTEGER DYNAMIC
      SAVE DO2_INIT, SOLVOL, AERATION_RATE, O2_CONSUME, O2_AERATION

C-----------------------------------------------------------------------

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C-----------------------------------------------------------------------
C       Initialize DO2 from ModuleData or use default
C-----------------------------------------------------------------------
        CALL GET('HYDRO','DO2',DO2_INIT)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','TEMP',SOLTEMP)

        IF (DO2_INIT .LT. 0.1) THEN
          DO2_INIT = 8.0  ! Default DO2 for well-aerated solution
          WRITE(*,*) 'SOLO2: Using default DO2=',DO2_INIT,' mg/L'
        ENDIF

        IF (SOLVOL .LT. 1.0) THEN
          SOLVOL = 1000.0
        ENDIF

        IF (SOLTEMP .LT. -50.0) THEN
          SOLTEMP = 20.0  ! Default temperature
        ENDIF

        DO2_CALC = DO2_INIT
        O2_CONSUME = 0.0  ! Initialize O2 consumption
        O2_AERATION = 0.0  ! Initialize O2 aeration

C       Aeration rate - depends on system type
C       NFT/DFT: high (0.8-0.9)
C       Static: low (0.2-0.4)
C       Aeroponics: very high (0.95)
        AERATION_RATE = 0.8  ! Assume NFT-type system

C       Calculate saturation DO2 at current temperature
        DO2_SAT = A0 + A1*SOLTEMP + A2*SOLTEMP**2 + A3*SOLTEMP**3
        IF (DO2_SAT .LT. 5.0) DO2_SAT = 5.0  ! Minimum bound

C       Store initial DO2 value in ModuleData
        CALL PUT('HYDRO','DO2',DO2_CALC)

        WRITE(*,100) DO2_INIT, DO2_SAT, SOLTEMP
 100    FORMAT(/,' Hydroponic Dissolved Oxygen Module Initialized',
     &         /,'   Initial DO2 : ',F6.2,' mg/L',
     &         /,'   DO2 saturation : ',F6.2,' mg/L at ',F5.1,' C',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate DO2 consumption and aeration
C-----------------------------------------------------------------------
C       Get current solution temperature (use air temp as proxy if needed)
        CALL GET('HYDRO','TEMP',SOLTEMP)
        IF (SOLTEMP .LT. -50.0) THEN
          SOLTEMP = WEATHER % TAVG  ! Use air temperature
        ENDIF

C       Update saturation DO2 for current temperature
        DO2_SAT = A0 + A1*SOLTEMP + A2*SOLTEMP**2 + A3*SOLTEMP**3
        IF (DO2_SAT .LT. 5.0) DO2_SAT = 5.0

C-----------------------------------------------------------------------
C       O2 consumption by roots
C       Root respiration rate in g CO2/m2/day
C       O2:CO2 ratio ~ 1:1 (molar basis)
C       Convert: g CO2 -> mol CO2 -> mol O2 -> g O2 -> mg O2
C       Distribute over solution volume
C-----------------------------------------------------------------------
        IF (ROOT_RESP .GT. 0.0 .AND. SOLVOL .GT. 0.0) THEN
C         g CO2/m2/day * (1 mol/44g) * (1 mol O2/mol CO2) * (32g/mol)
C         = g O2/m2/day * 1000 mg/g = mg O2/m2/day
          O2_CONSUME = ROOT_RESP * (32.0/44.0) * 1000.0
C         Convert to mg/L/day using solution volume per m2
C         CRITICAL: Prevent division by zero with very small volumes
          IF (SOLVOL .GT. 0.1) THEN
            O2_CONSUME = O2_CONSUME / SOLVOL
          ELSE
            O2_CONSUME = O2_CONSUME / 0.1  ! Use minimum volume
          ENDIF
        ELSE
C         No root respiration data - use simple estimate
C         Typical: 0.5-2.0 mg/L/day depending on plant size
          IF (PLTPOP .GT. 0.0) THEN
            O2_CONSUME = 1.0  ! mg/L/day default
          ELSE
            O2_CONSUME = 0.0
          ENDIF
        ENDIF

C-----------------------------------------------------------------------
C       O2 addition through aeration
C       Rate depends on deficit from saturation and aeration efficiency
C-----------------------------------------------------------------------
        O2_AERATION = AERATION_RATE * (DO2_SAT - DO2_CALC)
        O2_AERATION = MAX(0.0, O2_AERATION)  ! No negative aeration

        WRITE(*,200) O2_CONSUME, O2_AERATION, DO2_CALC, DO2_SAT
 200    FORMAT(' SOLO2: O2 consumption=',F6.3,' aeration=',F6.3,
     &         ' [DO2]=',F6.2,' (sat=',F6.2,' mg/L)')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update DO2 concentration
C-----------------------------------------------------------------------
        DO2_CALC = DO2_CALC - O2_CONSUME + O2_AERATION

C       Keep DO2 within bounds
        IF (DO2_CALC .LT. 0.0) DO2_CALC = 0.0
        IF (DO2_CALC .GT. DO2_SAT * 1.2) DO2_CALC = DO2_SAT * 1.2
C       Allow slight supersaturation (up to 120%)

C       Store updated DO2
        CALL PUT('HYDRO','DO2',DO2_CALC)

        WRITE(*,300) DO2_CALC
 300    FORMAT(' SOLO2: Updated DO2=',F6.2,' mg/L')

C-----------------------------------------------------------------------
C       Issue warning if DO2 is critically low
C-----------------------------------------------------------------------
        IF (DO2_CALC .LT. 3.0) THEN
          WRITE(*,*) 'SOLO2 WARNING: Low dissolved oxygen (<3 mg/L)'
          WRITE(*,*) '  Root stress may occur - increase aeration'
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLO2
