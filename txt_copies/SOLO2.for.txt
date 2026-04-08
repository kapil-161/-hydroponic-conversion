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
      EXTERNAL TIMDIF
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
      REAL TA            ! Absolute temperature (K)
      REAL LN_DO2        ! Natural log of DO2 saturation
      REAL O2_STRESS     ! O2 stress on root function (0-1)
      REAL AUTO_O2_R     ! AUTO_O2 flag (1.0=pin to init, 0.0=dynamic)

C     Benson-Krause (1984) coefficients for DO2 saturation calculation
C     ln(DO2_sat) = A0 + A1/Ta + A2/Ta^2 + A3/Ta^3 + A4/Ta^4
C     where Ta = temperature in Kelvin (T_celsius + 273.15)
C     Reference: Benson & Krause, Limnology & Oceanography 29:620-632
C     Valid for 0-40°C freshwater at 1 atm
      REAL A0, A1, A2, A3, A4
      PARAMETER (A0 = -139.34411)
      PARAMETER (A1 = 1.575701E5)
      PARAMETER (A2 = -6.642308E7)
      PARAMETER (A3 = 1.243800E10)
      PARAMETER (A4 = -8.621949E11)

      INTEGER DYNAMIC, YRPLT, YRDOY, DAP, TIMDIF
      SAVE DO2_INIT, SOLVOL, AERATION_RATE, O2_CONSUME, O2_AERATION,
     &     AUTO_O2_R

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
          CALL ERROR('SOLO2 ',1,'DO2 missing',0)
        ENDIF

        IF (SOLVOL .LT. 1.0) THEN
          CALL ERROR('SOLO2 ',1,'SOLVOL missing',0)
        ENDIF

        IF (SOLTEMP .LT. -50.0) THEN
          CALL ERROR('SOLO2 ',1,'TEMP missing',0)
        ENDIF

C       Get AUTO_O2 flag (1.0=pin DO2 to initial, 0.0=dynamic simulation)
        CALL GET('HYDRO','AUTO_O2',AUTO_O2_R)
        IF (AUTO_O2_R .LT. 0.0) AUTO_O2_R = 0.0

C       Save initial DO2 for AUTO_O2 pinning
        CALL PUT('HYDRO','DO2_INIT',DO2_INIT)

        DO2_CALC = DO2_INIT
        O2_CONSUME = 0.0  ! Initialize O2 consumption
        O2_AERATION = 0.0  ! Initialize O2 aeration

C       Aeration rate - depends on system type
C       NFT/DFT: high (0.8-0.9)
C       Static: low (0.2-0.4)
C       Aeroponics: very high (0.95)
        AERATION_RATE = 0.8  ! Assume NFT-type system

C       Calculate saturation DO2 using Benson-Krause (1984) equation
C       Convert temperature to Kelvin
        TA = SOLTEMP + 273.15
        LN_DO2 = A0 + A1/TA + A2/(TA**2) + A3/(TA**3) + A4/(TA**4)
        DO2_SAT = EXP(LN_DO2)
        IF (DO2_SAT .LT. 5.0) DO2_SAT = 5.0  ! Minimum bound

        O2_STRESS = DO2_CALC / (DO2_CALC + 0.5)
        O2_STRESS = MAX(0.0, MIN(1.0, O2_STRESS))

        CALL PUT('HYDRO','DO2',DO2_CALC)
        CALL PUT('HYDRO','DO2_SAT',DO2_SAT)
        CALL PUT('HYDRO','O2_STRESS',O2_STRESS)

        WRITE(*,100) DO2_INIT, DO2_SAT, SOLTEMP, AUTO_O2_R
 100    FORMAT(/,' Hydroponic Dissolved Oxygen Module Initialized',
     &         /,'   Initial DO2 : ',F6.2,' mg/L',
     &         /,'   DO2 saturation : ',F6.2,' mg/L at ',F5.1,' C',
     &         /,'   AUTO_O2 : ',F3.1,' (1=pin, 0=dynamic)',/)

      CASE (RATE)
C-----------------------------------------------------------------------
C       Calculate DO2 consumption and aeration
C-----------------------------------------------------------------------
C       Get current solution volume and temperature (use air temp as proxy if needed)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','TEMP',SOLTEMP)
        IF (SOLTEMP .LT. -50.0) THEN
          SOLTEMP = WEATHER % TAVG  ! Use air temperature
        ENDIF

C       Update saturation DO2 using Benson-Krause (1984) equation
        TA = SOLTEMP + 273.15
        LN_DO2 = A0 + A1/TA + A2/(TA**2) + A3/(TA**3) + A4/(TA**4)
        DO2_SAT = EXP(LN_DO2)
        IF (DO2_SAT .LT. 5.0) DO2_SAT = 5.0

C       O2 consumption by roots (convert g CO2/m2/day to mg O2/L/day)
        IF (ROOT_RESP .GT. 0.0 .AND. SOLVOL .GT. 0.0) THEN
          O2_CONSUME = ROOT_RESP * (32.0/44.0) * 1000.0
          IF (SOLVOL .GT. 0.1) THEN
            O2_CONSUME = O2_CONSUME / SOLVOL
          ELSE
            O2_CONSUME = O2_CONSUME / 0.1
          ENDIF
        ELSE
C         No root respiration data - no plants yet, no O2 consumption
          O2_CONSUME = 0.0
        ENDIF

C       O2 addition through aeration
        O2_AERATION = AERATION_RATE * (DO2_SAT - DO2_CALC)
        O2_AERATION = MAX(0.0, O2_AERATION)  ! No negative aeration

C       O2 stress on root function: Michaelis-Menten with Km=2 mg/L
C       Full function at DO2>4, half at DO2=2, near-zero at DO2<0.5
C       (Updated in INTEGR after DO2_CALC is refreshed — no PUT here)
        O2_STRESS = DO2_CALC / (DO2_CALC + 0.5)
        O2_STRESS = MAX(0.0, MIN(1.0, O2_STRESS))

!        WRITE(*,200) O2_CONSUME, O2_AERATION, DO2_CALC, DO2_SAT
! 200    FORMAT(' SOLO2: O2 consumption=',F6.3,' aeration=',F6.3,
!     &         ' [DO2]=',F6.2,' (sat=',F6.2,' mg/L)')

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Update DO2 concentration
C-----------------------------------------------------------------------
        CALL GET('MGMT','YRPLT',YRPLT)
        YRDOY = CONTROL % YRDOY

        IF (YRPLT .GT. 0) THEN
          DAP = MAX(0, TIMDIF(YRPLT, YRDOY))
        ELSE
          DAP = 0
        ENDIF

        IF (AUTO_O2_R .GT. 0.5 .OR. DAP .EQ. 0) THEN
C         AUTO_O2=Y or DAP=0: pin DO2 to initial value
          DO2_CALC = DO2_INIT
        ELSE
C         AUTO_O2=N: dynamic O2 balance (consumption vs aeration)
C         Cap consumption to available O2 to maintain mass balance
          IF (O2_CONSUME .GT. DO2_CALC + O2_AERATION) THEN
            O2_CONSUME = DO2_CALC + O2_AERATION
          ENDIF
          DO2_CALC = DO2_CALC - O2_CONSUME + O2_AERATION

C         Keep DO2 within bounds for safety against floating point drift
          IF (DO2_CALC .LT. 0.0) DO2_CALC = 0.0
          IF (DO2_CALC .GT. DO2_SAT * 1.2) DO2_CALC = DO2_SAT * 1.2
C         Allow slight supersaturation (up to 120%)
        ENDIF

C       Recompute O2_STRESS from updated DO2_CALC (fix 1-day lag)
        O2_STRESS = DO2_CALC / (DO2_CALC + 0.5)
        O2_STRESS = MAX(0.0, MIN(1.0, O2_STRESS))

C       Store updated DO2, saturation, and stress
        CALL PUT('HYDRO','DO2',DO2_CALC)
        CALL PUT('HYDRO','DO2_SAT',DO2_SAT)
        CALL PUT('HYDRO','O2_STRESS',O2_STRESS)

!        WRITE(*,300) DO2_CALC, O2_STRESS
! 300    FORMAT(' SOLO2: Updated DO2=',F6.2,' mg/L  O2_STRESS=',F5.3)

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
