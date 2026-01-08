C=======================================================================
C  COPYRIGHT 1998-2025
C                      DSSAT Foundation
C                      University of Florida, Gainesville, Florida
C                      International Fertilizer Development Center
C
C  ALL RIGHTS RESERVED
C=======================================================================
C=======================================================================
C  SPAM, Subroutine
C  Calculates soil-plant-atmosphere interface energy balance components.
C-----------------------------------------------------------------------
C  REVISION       HISTORY
C  11/09/2001 WMB/CHP Split WATBAL into WATBAL and SPAM.
C  02/06/2003 KJB/CHP Added KEP, EORATIO inputs from plant routines.
C  06/19/2003 CHP Added KTRANS - used instead of KEP in TRANS.
C  04/01/2004 CHP/US Added Penman - Meyer routine for potential ET
!  10/24/2005 CHP Put weather variables in constructed variable.
!  07/24/2006 CHP Use MSALB instead of SALB (includes mulch and soil
!                 water effects on albedo)
!  08/25/2006 CHP Add SALUS soil evaporation routine, triggered by new
!                 FILEX parameter MESEV
!  12/09/2008 CHP Remove METMP
!  10/16/2020 CHP Cumulative "soil" evaporation includes mulch and flood evap
!  01/26/2023 CHP Reduce compile warnings: add EXTERNAL stmts, remove 
!                 unused variables, shorten lines. 
C-----------------------------------------------------------------------
C  Called by: Main
C  Calls:     XTRACT, OPSPAM    (File SPSUBS.for)
C             PET     (File PET.for)
C             PSE     (File PET.for)
C             ROOTWU  (File ROOTWU.for)
C             SOILEV  (File SOILEV.for)
C             TRANS   (File TRANS.for)
C=======================================================================

      SUBROUTINE SPAM(CONTROL, ISWITCH,
     &    CANHT, EORATIO, KSEVAP, KTRANS, MULCH,          !Input
     &    PSTRES1, PORMIN, RLV, RWUMX, SOILPROP, SW,      !Input
     &    SWDELTS, UH2O, WEATHER, WINF, XHLAI, XLAI,      !Input
     &    FLOODWAT, SWDELTU,                              !I/O
     &    EO, EOP, EOS, EP, ES, RWU, SRFTEMP, ST,         !Output
     &    SWDELTX, TRWU, TRWUP, UPFLOW)                   !Output

!-----------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      USE FloodModule

      IMPLICIT NONE
      EXTERNAL ETPHOT, STEMP_EPIC, STEMP, ROOTWU, SOILEV, TRANS
      EXTERNAL MULCH_EVAP, OPSPAM, PET, PSE, FLOOD_EVAP, ESR_SOILEVAP
      EXTERNAL XTRACT
      EXTERNAL SOLEC, SOLPH, SOLO2, OPSOL, HYDRO_WATER
      SAVE

      CHARACTER*1  IDETW, ISWWAT, ISWHYDRO
      CHARACTER*1  MEEVP, MEINF, MEPHO, MESEV, METMP
      CHARACTER*2  CROP
      CHARACTER*6, PARAMETER :: ERRKEY = "SPAM  "
!      CHARACTER*78 MSG(2)

      INTEGER DYNAMIC, L, NLAYR

      REAL CANHT, CO2, SRAD, TAVG,
     &    TMAX, TMIN, WINDSP, XHLAI, XLAI
      REAL CEF, CEM, CEO, CEP, CES, CET, CEVAP
      REAL EF, EM, EO, EP, ES, ET, EVAP
      REAL TRWU, TRWUP, U
      REAL EOS, EOP, WINF, MSALB, ET_ALB
      REAL XLAT, TAV, TAMP, SRFTEMP
      REAL EORATIO, KSEVAP, KTRANS

      REAL DLAYR(NL), DUL(NL), LL(NL), RLV(NL), RWU(NL),
     &    SAT(NL), ST(NL), SW(NL), SW_AVAIL(NL), !SWAD(NL),
     &    SWDELTS(NL), SWDELTU(NL), SWDELTX(NL), UPFLOW(NL)
      REAL ES_LYR(NL)

!     Root water uptake computed by some plant routines (optional)
      REAL UH2O(NL)

!     Species-dependant variables imported from PLANT module:
      REAL PORMIN, RWUMX

!     Flood management variables:
      REAL FLOOD, EOS_SOIL

!     P Stress on photosynthesis
      REAL PSTRES1
!     Hourly transpiration for MEEVP=H
      REAL, DIMENSION(TS)    :: ET0

!     Hydroponic solution management variables
      REAL NO3_CONC, NH4_CONC, P_CONC, K_CONC  ! Solution concentrations (mg/L)
      REAL EC_CALC, EC_TARGET                  ! Electrical conductivity (dS/m)
      REAL PH_CALC, PH_TARGET                  ! pH
      REAL DO2_CALC, DO2_SAT                   ! Dissolved oxygen (mg/L)
      REAL UNO3_HYDRO, UNH4_HYDRO              ! N uptake for pH calculation (kg/ha/d)
      REAL UPO4_HYDRO, UK_HYDRO                ! P and K uptake (kg/ha/d)
      REAL ROOT_RESP                           ! Root respiration for O2 consumption
      REAL PLTPOP                              ! Plant population (plants/m2)

!-----------------------------------------------------------------------
!     Define constructed variable types based on definitions in
!     ModuleDefs.for.
      TYPE (ControlType) CONTROL
      TYPE (SoilType)    SOILPROP
      TYPE (SwitchType)  ISWITCH
      TYPE (FloodWatType)FLOODWAT
      TYPE (MulchType)   MULCH
      TYPE (WeatherType) WEATHER

!     Transfer values from constructed data types into local variables.
      CROP    = CONTROL % CROP
      DYNAMIC = CONTROL % DYNAMIC

      DLAYR  = SOILPROP % DLAYR
      DUL    = SOILPROP % DUL
      LL     = SOILPROP % LL
      MSALB  = SOILPROP % MSALB
      NLAYR  = SOILPROP % NLAYR
      SAT    = SOILPROP % SAT
      U      = SOILPROP % U

      ISWWAT   = ISWITCH % ISWWAT
      ISWHYDRO = ISWITCH % ISWHYDRO
      IDETW    = ISWITCH % IDETW
      MEEVP    = ISWITCH % MEEVP
      MEINF    = ISWITCH % MEINF
      MEPHO    = ISWITCH % MEPHO
      METMP    = ISWITCH % METMP
      MESEV    = ISWITCH % MESEV

      FLOOD  = FLOODWAT % FLOOD

      CO2    = WEATHER % CO2
      SRAD   = WEATHER % SRAD
      TAMP   = WEATHER % TAMP
      TAV    = WEATHER % TAV
      TAVG   = WEATHER % TAVG
      TMAX   = WEATHER % TMAX
      TMIN   = WEATHER % TMIN
      WINDSP = WEATHER % WINDSP
      XLAT   = WEATHER % XLAT

!***********************************************************************
!***********************************************************************
!     Run Initialization - Called once per simulation
!***********************************************************************
      IF (DYNAMIC .EQ. RUNINIT) THEN
!-----------------------------------------------------------------------
      IF (MEPHO .EQ. 'L' .OR. MEEVP .EQ. 'Z') THEN
        CALL ETPHOT(CONTROL, ISWITCH,
     &    PORMIN, PSTRES1, RLV, RWUMX, SOILPROP, ST, SW,  !Input
     &    WEATHER, XLAI,                                  !Input
     &    EOP, EP, ES, RWU, TRWUP)                        !Output
      ENDIF

      !Initialize ASCE dual KC ET variables (KRT)
      CALL PUT('SPAM', 'REFET', -99.0)
      CALL PUT('SPAM', 'KCB', -99.0)
      CALL PUT('SPAM', 'KE', -99.0)
      CALL PUT('SPAM', 'KC', -99.0)

!-----------------------------------------------------------------------
!     Initialize hydroponic solution output file (delete old file)
!-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
        CALL OPSOL(CONTROL, ISWITCH,
     &    0.0, 0.0, 0.0, 0.0,                      !Concentrations
     &    0.0, 0.0, 0.0, 0.0,                      !EC, pH
     &    0.0, 0.0, 0.0, 0.0, 0.0, 0.0)            !DO2, Uptakes
      ENDIF

!***********************************************************************
!***********************************************************************
!     Seasonal initialization - run once per season
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. SEASINIT) THEN
!-----------------------------------------------------------------------
      EF   = 0.0; CEF  = 0.0
      EM   = 0.0; CEM  = 0.0
      EO   = 0.0; CEO  = 0.0
      EP   = 0.0; EOP  = 0.0; CEP  = 0.0
      ES   = 0.0; EOS  = 0.0; CES  = 0.0
      ET   = 0.0; CET  = 0.0
      EVAP = 0.0; CEVAP =0.0
      ES_LYR = 0.0
      SWDELTX = 0.0
      TRWU = 0.0
      XHLAI = 0.0
      ET0 = 0.0

!     ---------------------------------------------------------
!     SOIL TEMPERATURE CALCULATIONS (SEASINIT phase)
!     ---------------------------------------------------------
      IF (MEEVP .NE.'Z') THEN   !LPM 02dec14 use values from ETPHOT
        IF (ISWHYDRO .EQ. 'Y') THEN
!         HYDROPONIC MODE: Use solution temperature instead of soil temperature
!         Solution temperature is stored in ModuleData, use air temp as proxy if not available
          DO L = 1, NLAYR
            ST(L) = TAVG  ! Use average air temperature for root zone
          ENDDO
          SRFTEMP = TAVG  ! Surface temperature = air temperature
        ELSE
!         SOIL MODE: Calculate soil temperature by layer
          SELECT CASE (METMP)
          CASE ('E')    !EPIC soil temperature routine
            CALL STEMP_EPIC(CONTROL, ISWITCH,
     &        SOILPROP, SW, TAVG, TMAX, TMIN, TAV, WEATHER,    !Input
     &        SRFTEMP, ST)                                     !Output
          CASE DEFAULT  !DSSAT soil temperature
            CALL STEMP(CONTROL, ISWITCH,
     &        SOILPROP, SRAD, SW, TAVG, TMAX, XLAT, TAV, TAMP, !Input
     &        SRFTEMP, ST)                                     !Output
          END SELECT
        ENDIF
      ENDIF
!     ---------------------------------------------------------
!     ROOT WATER UPTAKE AND SOIL EVAPORATION INITIALIZATION
!     ---------------------------------------------------------
      IF (MEEVP .NE. 'Z') THEN
        IF (ISWHYDRO .EQ. 'Y') THEN
!         HYDROPONIC MODE: Skip soil-related routines
!         Root water uptake is handled by HYDRO_WATER
!         No soil evaporation in hydroponic systems
          RWU   = 0.0
          TRWUP = 0.0
          ES    = 0.0
!         Initialize hydroponic water module
          CALL HYDRO_WATER(CONTROL, ISWITCH,
     &      0.0,                                !Input - EP not needed in SEASINIT
     &      TRWUP, TRWU, ES)                    !Output
        ELSE
!         SOIL MODE: Initialize root water uptake and soil evaporation
          CALL ROOTWU(SEASINIT,
     &      DLAYR, LL, NLAYR, PORMIN, RLV, RWUMX, SAT, SW,!Input
     &      RWU, TRWUP)                           !Output

!         Initialize soil evaporation variables
          SELECT CASE (MESEV)
!     ----------------------------
          CASE ('R')  !Original soil evaporation routine
            CALL SOILEV(SEASINIT,
     &      DLAYR, DUL, EOS, LL, SW, SW_AVAIL(1),         !Input
     &      U, WINF,                                      !Input
     &      ES)                                           !Output
!     ----------------------------
          END SELECT
        ENDIF

!       Initialize plant transpiration variables
        CALL TRANS(DYNAMIC, MEEVP,
     &    CO2, CROP, EO, ET0, EVAP, KTRANS,               !Input
     &    WINDSP, XHLAI, WEATHER,                         !Input
     &    EOP)                                            !Output
      ENDIF

      CALL MULCH_EVAP(DYNAMIC, MULCH, EOS, EM)

!     ---------------------------------------------------------
      IF (CROP .NE. 'FA') THEN
        IF (MEPHO .EQ. 'L' .OR. MEEVP .EQ. 'Z') THEN
          CALL ETPHOT(CONTROL, ISWITCH,
     &    PORMIN, PSTRES1, RLV, RWUMX, SOILPROP, ST, SW,  !Input
     &    WEATHER, XLAI,                                  !Input
     &    EOP, EP, ES, RWU, TRWUP)                        !Output
        ENDIF
      ENDIF

!     Call OPSPAM to open and write headers to output file
      IF (IDETW .EQ. 'Y') THEN
        CALL OPSPAM(CONTROL, ISWITCH, FLOODWAT, TRWU,
     &    CEF, CEM, CEO, CEP, CES, CET, CEVAP, EF, EM,
     &    EO, EOP, EOS, EP, ES, ET, TMAX, TMIN, TRWUP, SRAD,
     &    ES_LYR, SOILPROP)
      ENDIF

!-----------------------------------------------------------------------
!     HYDROPONIC SOLUTION OUTPUT INITIALIZATION
!-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
!       Initialize solution concentrations for output
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

!       Ensure P and K are initialized (default if not set)
        IF (P_CONC .LT. 0.1) THEN
          P_CONC = 60.0  ! Default P concentration (mg/L)
          CALL PUT('HYDRO','P_CONC',P_CONC)
        ENDIF
        IF (K_CONC .LT. 0.1) THEN
          K_CONC = 240.0  ! Default K concentration (mg/L)
          CALL PUT('HYDRO','K_CONC',K_CONC)
        ENDIF

!       Get plant population for initialization
        CALL GET('PLANT','PLTPOP',PLTPOP)
        IF (PLTPOP .LT. 0.1) PLTPOP = 10.0  ! Default

!       Initialize solution management modules to get proper values
!       Call SOLEC to initialize EC
        CALL SOLEC(CONTROL, ISWITCH,
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,      !Input
     &    EC_CALC, EC_TARGET)                       !Output

!       Call SOLPH to initialize pH (with zero uptake for initialization)
        CALL SOLPH(CONTROL, ISWITCH,
     &    0.0, 0.0,                                  !Input - zero uptake for init
     &    PH_CALC, PH_TARGET)                       !Output

!       Call SOLO2 to initialize DO2
        ROOT_RESP = 0.0  ! Zero for initialization
        CALL SOLO2(CONTROL, ISWITCH, WEATHER,
     &    PLTPOP, ROOT_RESP,                        !Input
     &    DO2_CALC, DO2_SAT)                        !Output

!       Initialize uptake rates
        UNO3_HYDRO = 0.0
        UNH4_HYDRO = 0.0
        UPO4_HYDRO = 0.0
        UK_HYDRO = 0.0

!       Call OPSOL to initialize output file (SEASINIT phase)
        CALL OPSOL(CONTROL, ISWITCH,
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,         !Input
     &    EC_CALC, EC_TARGET, PH_CALC, PH_TARGET,     !Input
     &    DO2_CALC, DO2_SAT, UNO3_HYDRO, UNH4_HYDRO,  !Input
     &    UPO4_HYDRO, UK_HYDRO)                        !UPO4, UK
      ENDIF

!     Transfer data to storage routine
      CALL PUT('SPAM', 'CEF', CEF)
      CALL PUT('SPAM', 'CEM', CEM)
      CALL PUT('SPAM', 'CEO', CEO)
      CALL PUT('SPAM', 'CEP', CEP)
      CALL PUT('SPAM', 'CES', CES)
      CALL PUT('SPAM', 'CET', CET)
      CALL PUT('SPAM', 'CEVAP',CEVAP)
      CALL PUT('SPAM', 'EF',  EF)
      CALL PUT('SPAM', 'EM',  EM)
      CALL PUT('SPAM', 'EO',  EO)
      CALL PUT('SPAM', 'EP',  EP)
      CALL PUT('SPAM', 'ES',  ES)
      CALL PUT('SPAM', 'ET',  ET)

!***********************************************************************
!***********************************************************************
!     DAILY RATE CALCULATIONS
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. RATE) THEN
!-----------------------------------------------------------------------
      SWDELTX = 0.0
!     ---------------------------------------------------------
!     SOIL TEMPERATURE CALCULATIONS
!     ---------------------------------------------------------
      IF (MEEVP .NE.'Z') THEN  !LPM 02dec14 use values from ETPHOT
        IF (ISWHYDRO .EQ. 'Y') THEN
!         HYDROPONIC MODE: Use solution temperature instead of soil temperature
!         Solution temperature is stored in ModuleData, use air temp as proxy if not available
          DO L = 1, NLAYR
            ST(L) = TAVG  ! Use average air temperature for root zone
          ENDDO
          SRFTEMP = TAVG  ! Surface temperature = air temperature
        ELSE
!         SOIL MODE: Calculate soil temperature by layer
          SELECT CASE (METMP)
          CASE ('E')    !EPIC soil temperature routine
            CALL STEMP_EPIC(CONTROL, ISWITCH,
     &        SOILPROP, SW, TAVG, TMAX, TMIN, TAV, WEATHER,   !Input
     &        SRFTEMP, ST)                                    !Output
          CASE DEFAULT
!       7/21/2016 - DSSAT method is default, per GH
!       CASE ('D')  !DSSAT soil temperature
            CALL STEMP(CONTROL, ISWITCH,
     &        SOILPROP, SRAD, SW, TAVG, TMAX, XLAT, TAV, TAMP,!Input
     &        SRFTEMP, ST)                                    !Output
          END SELECT
        ENDIF
      ENDIF
!-----------------------------------------------------------------------
!     POTENTIAL ROOT WATER UPTAKE
!-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
!       HYDROPONIC MODE - unlimited water from nutrient solution
        WRITE(*,*) 'SPAM: Hydroponic mode - unlimited water'
!       Still need to calculate PET for plant transpiration demand
!       Skip soil water uptake calculations, but do PET calculation below
        RWU   = 0.0      ! No layer-specific uptake (solution-based)
        ES    = 0.0      ! No soil evaporation

!       Fall through to calculate PET (don't skip to ENDIF)
!       Set flag to bypass soil water limitations later
      ENDIF

      IF (ISWWAT .EQ. 'Y' .OR. ISWHYDRO .EQ. 'Y') THEN
!       Calculate the availability of soil water for use in SOILEV.
!       Skip in hydroponic mode - no soil water to calculate
        IF (ISWHYDRO .NE. 'Y') THEN
          DO L = 1, NLAYR
            SW_AVAIL(L) = MAX(0.0, SW(L) + SWDELTS(L) + SWDELTU(L))
          ENDDO
        ENDIF

!       These processes are done by ETPHOT for hourly (Zonal) energy
!       balance method.
        IF (MEEVP .NE. 'Z') THEN
!         Calculate potential root water uptake rate for each soil layer
!         and total potential water uptake rate.
          IF (ISWHYDRO .NE. 'Y') THEN
!           SOIL MODE: Calculate root water uptake from soil
            IF (XHLAI .GT. 0.0) THEN
              CALL ROOTWU(RATE,
     &            DLAYR, LL, NLAYR, PORMIN, RLV, RWUMX, SAT, SW,!Input
     &            RWU, TRWUP)                                   !Output
            ELSE
              RWU   = 0.0
              TRWUP = 0.0
            ENDIF
          ELSE
!           HYDROPONIC MODE: Calculate potential supply from solution
            RWU   = 0.0       ! No layer uptake
!           Call HYDRO_WATER in RATE phase to calculate TRWUP
            CALL HYDRO_WATER(CONTROL, ISWITCH,
     &        0.0,                            !Input - EP not needed in RATE
     &        TRWUP, TRWU, ES)                !Output - TRWUP calculated here
          ENDIF

!-----------------------------------------------------------------------
!         POTENTIAL EVAPOTRANSPIRATION
!-----------------------------------------------------------------------
          IF (FLOOD .GT. 0.0) THEN
            ! Set albedo to 0.08 under flooded conditions
            ! US - change to 0.05 Feb2004
            ET_ALB = 0.05
          ELSE
            ET_ALB = MSALB
          ENDIF

          CALL PET(CONTROL,
     &       ET_ALB, XHLAI, MEEVP, WEATHER,  !Input for all
     &       EORATIO, !Needed by Penman-Monteith
     &       CANHT,   !Needed by dynamic Penman-Monteith
     &       EO,      !Output
     &       ET0)     !Output hourly Priestly-Taylor with VPD effect

!-----------------------------------------------------------------------
!         POTENTIAL SOIL EVAPORATION
!-----------------------------------------------------------------------
!         05/26/2007 CHP/MJ Use XLAI instead of XHLAI
!         This was important for Canegro and affects CROPGRO crops
!             only very slightly (max 0.5% yield diff for one peanut
!             experiment).  No difference to other crop models.
          CALL PSE(EO, KSEVAP, XLAI, EOS)

!-----------------------------------------------------------------------
!         ACTUAL SOIL, MULCH AND FLOOD EVAPORATION
!-----------------------------------------------------------------------
!         Initialize soil, mulch and flood evaporation
          ES = 0.; EM = 0.; EF = 0.; EVAP = 0.0
          UPFLOW = 0.0; ES_LYR = 0.0

!         Skip soil evaporation calculations in hydroponic mode
          IF (ISWHYDRO .EQ. 'Y') THEN
!           HYDROPONIC MODE: No soil, mulch, or flood evaporation
            ES = 0.0
            EM = 0.0
            EF = 0.0
            EVAP = 0.0
            GOTO 350  ! Skip to after evaporation calculations
          ENDIF

!         First meet evaporative demand from floodwater
          IF (FLOOD .GT. 1.E-4) THEN
            CALL FLOOD_EVAP(XLAI, EO, EF)
            IF (EF > FLOOD) THEN
!             Floodwater not enough to supply EOS demand
              EOS_SOIL = MIN(EF - FLOOD, EOS)
              EF = FLOOD
            ELSE
              EOS_SOIL = 0.0
            ENDIF
          ELSE
            EOS_SOIL = EOS
          ENDIF

!         Next meet evaporative demand from mulch
          IF (EOS_SOIL > 1.E-6 .AND. INDEX('RSM',MEINF) > 0) THEN
            CALL MULCH_EVAP(DYNAMIC, MULCH, EOS_SOIL, EM)
            IF (EOS_SOIL > EM) THEN
!             Some evaporative demand leftover for soil
              EOS_SOIL = EOS_SOIL - EM
            ELSE
              EOS_SOIL = 0.0
            ENDIF
          ENDIF

!         Soil evaporation after flood and mulch evaporation
          IF (EOS_SOIL > 1.E-6) THEN
            SELECT CASE(MESEV)
!           ------------------------
            CASE ('S')  ! Sulieman-Ritchie soil evaporation routine
!             Note that this routine calculates UPFLOW, unlike the SOILEV.
              CALL ESR_SoilEvap(
     &          EOS_SOIL, SOILPROP, SW, SWDELTS,          !Input
     &          ES, ES_LYR, SWDELTU, UPFLOW)              !Output
!           ------------------------
            CASE DEFAULT
!           CASE ('R')  !Ritchie soil evaporation routine
!             Calculate the availability of soil water for use in SOILEV.
              DO L = 1, NLAYR
                SW_AVAIL(L) = MAX(0.0, SW(L) + SWDELTS(L) + SWDELTU(L))
              ENDDO
              CALL SOILEV(RATE,
     &          DLAYR, DUL, EOS_SOIL, LL, SW,             !Input
     &          SW_AVAIL(1), U, WINF,                     !Input
     &          ES)                                       !Output
            END SELECT
!           ------------------------
          ENDIF

!         Total evaporation from soil, mulch, flood
          EVAP = ES + EM + EF

! 350    Continue here after skipping evaporation in hydroponic mode
 350      CONTINUE

!-----------------------------------------------------------------------
!         Potential transpiration - model dependent
!-----------------------------------------------------------------------
          IF (ISWHYDRO .EQ. 'Y') THEN
!           HYDROPONIC MODE: Calculate potential transpiration from LAI
!           Same calculation as soil mode - transpiration should scale with plant size
!           Bypass XHLAI check to allow seedling transpiration (TRANS handles this)
            IF (XHLAI > 1.E-6) THEN
              CALL TRANS(RATE, MEEVP,
     &        CO2, CROP, EO, ET0, EVAP, KTRANS,           !Input
     &        WINDSP, XHLAI,                              !Input
     &        WEATHER,                                    !Input
     &        EOP)                                        !Output
            ELSE
!             For very small LAI, use a small fraction of EO
              EOP = EO * 0.1  ! 10% of reference ET for seedlings
            ENDIF
          ELSEIF (XHLAI > 1.E-6) THEN
!           SOIL MODE: Calculate from LAI
            CALL TRANS(RATE, MEEVP,
     &      CO2, CROP, EO, ET0, EVAP, KTRANS,           !Input
     &      WINDSP, XHLAI,                              !Input
     &      WEATHER,                                    !Input
     &      EOP)                                        !Output
          ELSE
            EOP = 0.0
          ENDIF

!-----------------------------------------------------------------------
!         ACTUAL TRANSPIRATION
!-----------------------------------------------------------------------
          IF (ISWHYDRO .EQ. 'Y') THEN
!           HYDROPONIC MODE: Water is unlimited, so actual = potential
!           EP should equal EOP (demand-based, no water stress)
!           Don't restrict by XHLAI to avoid chicken-egg problem
            IF (EOP .GT. 1.E-6) THEN
              EP = EOP    ! Actual = potential (unlimited water supply)
              WRITE(*,*) 'HYDRO EP: EOP=',EOP,' EP=',EP,' (demand-based)'
            ELSE
              EP = 0.0
              WRITE(*,*) 'HYDRO EP=0: EOP=',EOP
            ENDIF
          ELSEIF (XHLAI .GT. 1.E-4 .AND. EOP .GT. 1.E-4) THEN
!           SOIL MODE: Normal calculation - limited by soil water supply
            !These calcs replace the old SWFACS subroutine
            !Stress factors now calculated as needed in PLANT routines.
            EP = MIN(EOP, TRWUP*10.)  ! Limited by soil water availability
          ELSE
            EP = 0.0
          ENDIF
        ENDIF
      ENDIF

!-----------------------------------------------------------------------
!     ALTERNATE CALL TO ENERGY BALANCE ROUTINES
!-----------------------------------------------------------------------
      IF (CROP .NE. 'FA') THEN
        IF (MEEVP .EQ. 'Z' .OR.
     &        (MEPHO .EQ. 'L' .AND. XHLAI .GT. 0.0)) THEN
          !ETPHOT called for photosynthesis only
          !    (MEPHO = 'L' and MEEVP <> 'Z')
          !or for both photosynthesis and evapotranspiration
          !   (MEPHO = 'L' and MEEVP = 'Z').
          CALL ETPHOT(CONTROL, ISWITCH,
     &    PORMIN, PSTRES1, RLV, RWUMX, SOILPROP, ST, SW,  !Input
     &    WEATHER, XLAI,                                 !Input
     &    EOP, EP, ES, RWU, TRWUP)                        !Output
          EVAP = ES  !CHP / BK 7/13/2017
C         Override EP in hydroponic mode to ensure demand-based transpiration
          IF (ISWHYDRO .EQ. 'Y' .AND. EOP .GT. 1.E-6) THEN
            EP = EOP    ! Actual = potential (unlimited water supply)
          ENDIF
        ENDIF

!-----------------------------------------------------------------------
!       ACTUAL ROOT WATER EXTRACTION
!-----------------------------------------------------------------------
        IF (ISWWAT .EQ. 'Y') THEN
!         Adjust available soil water for evaporation
          SELECT CASE(MESEV)
          CASE ('R') !
            SW_AVAIL(1) = MAX(0.0, SW_AVAIL(1) - 0.1 * ES / DLAYR(1))

          CASE DEFAULT
            DO L = 1, NLAYR
              SW_AVAIL(L) = MAX(0.0,SW_AVAIL(L) -0.1*ES_LYR(L)/DLAYR(L))
            ENDDO
          END SELECT

!         Calculate actual soil water uptake and transpiration rates
          IF (ISWHYDRO .NE. 'Y') THEN
!           SOIL MODE: Calculate water extraction from soil
            CALL XTRACT(
     &        NLAYR, DLAYR, LL, SW, SW_AVAIL, TRWUP, UH2O,  !Input
     &        EP, RWU,                                      !Input/Output
     &        SWDELTX, TRWU)                                !Output
          ELSE
!           HYDROPONIC MODE: No water stress, actual = potential
            TRWU = EP    ! Actual transpiration = potential (no stress)
            SWDELTX = 0.0  ! No soil water extraction
          ENDIF
        ENDIF   !ISWWAT = 'Y'
      ENDIF

!     Transfer computed value of potential floodwater evaporation to
!     flood variable.
      FLOODWAT % EF = EF

!-----------------------------------------------------------------------
!     HYDROPONIC SOLUTION MANAGEMENT (RATE phase)
!-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
!       Get current solution concentrations from ModuleData
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

!       Get plant population from ModuleData (needed for DO2 calculation)
        CALL GET('PLANT','PLTPOP',PLTPOP)

!       Calculate EC based on current nutrient concentrations
        CALL SOLEC(CONTROL, ISWITCH,
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,      !Input
     &    EC_CALC, EC_TARGET)                       !Output

!       Get N uptake from ModuleData for pH calculation
!       (These should be set by NUPTAK in plant module)
        UNO3_HYDRO = 0.0
        UNH4_HYDRO = 0.0
        UPO4_HYDRO = 0.0
        UK_HYDRO = 0.0
!       Try to get from HYDRO module (stored by NUPTAK)
        CALL GET('HYDRO','UNO3',UNO3_HYDRO)
        CALL GET('HYDRO','UNH4',UNH4_HYDRO)
        CALL GET('HYDRO','UPO4',UPO4_HYDRO)
        CALL GET('HYDRO','UK',UK_HYDRO)

!       Calculate pH based on N uptake pattern
        CALL SOLPH(CONTROL, ISWITCH,
     &    UNO3_HYDRO, UNH4_HYDRO,                   !Input
     &    PH_CALC, PH_TARGET)                       !Output

!       Calculate dissolved oxygen
!       Root respiration not directly available - use simple estimate
        ROOT_RESP = 0.0  ! Could be linked to plant respiration later

        CALL SOLO2(CONTROL, ISWITCH, WEATHER,
     &    PLTPOP, ROOT_RESP,                        !Input
     &    DO2_CALC, DO2_SAT)                        !Output
      ENDIF

!     Transfer data to storage routine
      CALL PUT('SPAM', 'EF',  EF)
      CALL PUT('SPAM', 'EM',  EM)
      CALL PUT('SPAM', 'EO',  EO)
      CALL PUT('SPAM', 'EP',  EP)
      CALL PUT('SPAM', 'ES',  ES)
      CALL PUT('SPAM', 'EOP', EOP)
      CALL PUT('SPAM', 'EVAP',EVAP)
      CALL PUT('SPAM', 'UH2O',RWU)

!***********************************************************************
!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. INTEGR) THEN
!-----------------------------------------------------------------------
      IF (ISWWAT .EQ. 'Y') THEN
!       Perform daily summation of water balance variables.
        ET  = EVAP + EP
        CEF = CEF + EF
        CEM = CEM + EM
        CEO = CEO + EO
        CEP = CEP + EP
        CES = CES + ES
        CEVAP=CEVAP + EVAP
        CET = CET + ET
      ENDIF

!-----------------------------------------------------------------------
!     HYDROPONIC SOLUTION MANAGEMENT (INTEGR phase)
!-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
!       Update solution volume based on water balance
!       (water additions, plant uptake, evaporation)
        CALL HYDRO_WATER(CONTROL, ISWITCH,
     &    EP,                                      !Input - transpiration
     &    TRWUP, TRWU, ES)                         !Output

!       Update solution properties after uptake
        CALL SOLEC(CONTROL, ISWITCH,
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,      !Input
     &    EC_CALC, EC_TARGET)                       !Output (INTEGR)

        CALL SOLPH(CONTROL, ISWITCH,
     &    UNO3_HYDRO, UNH4_HYDRO,                   !Input
     &    PH_CALC, PH_TARGET)                       !Output (INTEGR)

        CALL SOLO2(CONTROL, ISWITCH, WEATHER,
     &    PLTPOP, ROOT_RESP,                        !Input
     &    DO2_CALC, DO2_SAT)                        !Output (INTEGR)
      ENDIF

      IF (IDETW .EQ. 'Y') THEN
        CALL OPSPAM(CONTROL, ISWITCH, FLOODWAT, TRWU,
     &    CEF, CEM, CEO, CEP, CES, CET, CEVAP, EF, EM,
     &    EO, EOP, EOS, EP, ES, ET, TMAX, TMIN, TRWUP, SRAD,
     &    ES_LYR, SOILPROP)
      ENDIF

!     Transfer data to storage routine
      CALL PUT('SPAM', 'CEF', CEF)
      CALL PUT('SPAM', 'CEM', CEM)
      CALL PUT('SPAM', 'CEO', CEO)
      CALL PUT('SPAM', 'CEP', CEP)
      CALL PUT('SPAM', 'CES', CES)
      CALL PUT('SPAM', 'CET', CET)
      CALL PUT('SPAM', 'ET',  ET)
      CALL PUT('SPAM', 'CEVAP', CEVAP)

!***********************************************************************
!***********************************************************************
!     OUTPUT - daily output
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. OUTPUT) THEN
C-----------------------------------------------------------------------
!     Flood water evaporation can be modified by Paddy_Mgmt routine.
      EF = FLOODWAT % EF

!     ---------------------------------------------------------
!     SOIL TEMPERATURE CALCULATIONS (OUTPUT phase)
!     ---------------------------------------------------------
      IF (MEEVP .NE.'Z') THEN  !LPM 02dec14 use values from ETPHOT
        IF (ISWHYDRO .EQ. 'Y') THEN
!         HYDROPONIC MODE: Use solution temperature instead of soil temperature
          DO L = 1, NLAYR
            ST(L) = TAVG  ! Use average air temperature for root zone
          ENDDO
          SRFTEMP = TAVG  ! Surface temperature = air temperature
        ELSE
!         SOIL MODE: Calculate soil temperature by layer
          SELECT CASE (METMP)
          CASE ('E')    !EPIC soil temperature routine
            CALL STEMP_EPIC(CONTROL, ISWITCH,
     &        SOILPROP, SW, TAVG, TMAX, TMIN, TAV, WEATHER,   !Input
     &        SRFTEMP, ST)                                    !Output
          CASE DEFAULT  !DSSAT soilt temperature
            CALL STEMP(CONTROL, ISWITCH,
     &        SOILPROP, SRAD, SW, TAVG, TMAX, XLAT, TAV, TAMP,!Input
     &        SRFTEMP, ST)                                    !Output
          END SELECT
        ENDIF
      ENDIF

      CALL OPSPAM(CONTROL, ISWITCH, FLOODWAT, TRWU,
     &    CEF, CEM, CEO, CEP, CES, CET, CEVAP, EF, EM,
     &    EO, EOP, EOS, EP, ES, ET, TMAX, TMIN, TRWUP, SRAD,
     &    ES_LYR, SOILPROP)

!-----------------------------------------------------------------------
!     HYDROPONIC SOLUTION OUTPUT
!-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
!       Get current solution concentrations
        CALL GET('HYDRO','NO3_CONC',NO3_CONC)
        CALL GET('HYDRO','NH4_CONC',NH4_CONC)
        CALL GET('HYDRO','P_CONC',P_CONC)
        CALL GET('HYDRO','K_CONC',K_CONC)

!       Get N uptake values for output (should be in ModuleData from NUPTAK)
        UNO3_HYDRO = 0.0
        UNH4_HYDRO = 0.0
        UPO4_HYDRO = 0.0
        UK_HYDRO = 0.0
!       Get from HYDRO module (stored by NUPTAK)
        CALL GET('HYDRO','UNO3',UNO3_HYDRO)
        CALL GET('HYDRO','UNH4',UNH4_HYDRO)
        CALL GET('HYDRO','UPO4',UPO4_HYDRO)
        CALL GET('HYDRO','UK',UK_HYDRO)

!       Call solution output module
        CALL OPSOL(CONTROL, ISWITCH,
     &    NO3_CONC, NH4_CONC, P_CONC, K_CONC,         !Input
     &    EC_CALC, EC_TARGET, PH_CALC, PH_TARGET,     !Input
     &    DO2_CALC, DO2_SAT, UNO3_HYDRO, UNH4_HYDRO,  !Input
     &    UPO4_HYDRO, UK_HYDRO)                       !UPO4, UK
      ENDIF

      IF (CROP .NE. 'FA' .AND. MEPHO .EQ. 'L') THEN
        CALL ETPHOT(CONTROL, ISWITCH,
     &    PORMIN, PSTRES1, RLV, RWUMX, SOILPROP, ST, SW,  !Input
     &    WEATHER, XLAI,                                  !Input
     &    EOP, EP, ES, RWU, TRWUP)                        !Output
      ENDIF

!      CALL OPSTRESS(CONTROL, ET=ET, EP=EP)

!***********************************************************************
!***********************************************************************
!     SEASEND - seasonal output
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. SEASEND) THEN
!-----------------------------------------------------------------------
      CALL OPSPAM(CONTROL, ISWITCH, FLOODWAT, TRWU,
     &    CEF, CEM, CEO, CEP, CES, CET, CEVAP, EF, EM,
     &    EO, EOP, EOS, EP, ES, ET, TMAX, TMIN, TRWUP, SRAD,
     &    ES_LYR, SOILPROP)

!     ---------------------------------------------------------
!     SOIL TEMPERATURE CALCULATIONS (SEASEND phase)
!     ---------------------------------------------------------
      IF (MEEVP .NE.'Z') THEN  !LPM 02dec14 use values from ETPHOT
        IF (ISWHYDRO .EQ. 'Y') THEN
!         HYDROPONIC MODE: Use solution temperature instead of soil temperature
          DO L = 1, NLAYR
            ST(L) = TAVG  ! Use average air temperature for root zone
          ENDDO
          SRFTEMP = TAVG  ! Surface temperature = air temperature
        ELSE
!         SOIL MODE: Calculate soil temperature by layer
          SELECT CASE (METMP)
          CASE ('E')    !EPIC soil temperature routine
            CALL STEMP_EPIC(CONTROL, ISWITCH,
     &        SOILPROP, SW, TAVG, TMAX, TMIN, TAV, WEATHER,   !Input
     &        SRFTEMP, ST)                                    !Output
          CASE DEFAULT  !DSSAT soilt temperature
            CALL STEMP(CONTROL, ISWITCH,
     &        SOILPROP, SRAD, SW, TAVG, TMAX, XLAT, TAV, TAMP,!Input
     &        SRFTEMP, ST)                                    !Output
          END SELECT
        ENDIF
      ENDIF

      IF (MEPHO .EQ. 'L') THEN
        CALL ETPHOT(CONTROL, ISWITCH,
     &    PORMIN, PSTRES1, RLV, RWUMX, SOILPROP, ST, SW,  !Input
     &    WEATHER, XLAI,                                  !Input
     &    EOP, EP, ES, RWU, TRWUP)                        !Output
      ENDIF

!     Transfer data to storage routine
      CALL PUT('SPAM', 'CEF', CEF)
      CALL PUT('SPAM', 'CEM', CEM)
      CALL PUT('SPAM', 'CEO', CEO)
      CALL PUT('SPAM', 'CEP', CEP)
      CALL PUT('SPAM', 'CES', CES)
      CALL PUT('SPAM', 'CET', CET)
      CALL PUT('SPAM', 'ET',  ET)
      CALL PUT('SPAM', 'CEVAP', CEVAP)

!      CALL OPSTRESS(CONTROL, ET=ET, EP=EP)

!***********************************************************************
!***********************************************************************
!     END OF DYNAMIC IF CONSTRUCT
!***********************************************************************
      ENDIF
!-----------------------------------------------------------------------
      RETURN
      END SUBROUTINE SPAM

!-----------------------------------------------------------------------
!     VARIABLE DEFINITIONS: (updated 12 Feb 2004)
!-----------------------------------------------------------------------
! CANHT       Canopy height (m)
! CEF         Cumulative seasonal evaporation from floodwater surface (mm)
! CEM         Cumulative evaporation from surface mulch layer (mm)
! CEO         Cumulative potential evapotranspiration (mm)
! CEP         Cumulative transpiration (mm)
! CES         Cumulative evaporation (mm)
! CET         Cumulative evapotranspiration (mm)
! CLOUDS      Relative cloudiness factor (0-1)
! CO2         Atmospheric carbon dioxide concentration
!              (�mol[CO2] / mol[air])
! CONTROL     Composite variable containing variables related to control
!               and/or timing of simulation.    See Appendix A.
! CROP        Crop identification code
! DLAYR(L)    Thickness of soil layer L (cm)
! DUL(L)      Volumetric soil water content at Drained Upper Limit in soil
!               layer L (cm3[water]/cm3[soil])
! EF          Evaporation rate from flood surface (mm / d)
! EM          Evaporation rate from surface mulch layer (mm / d)
! EO          Potential evapotranspiration rate (mm/d)
! EOP         Potential plant transpiration rate (mm/d)
! EORATIO     Ratio of increase in potential evapotranspiration with
!               increase in LAI (up to LAI=6.0) for use with FAO-56 Penman
!               reference potential evapotranspiration.
! EOS         Potential rate of soil evaporation (mm/d)
! EP          Actual plant transpiration rate (mm/d)
! ES          Actual soil evaporation rate (mm/d)
! ET          Actual evapotranspiration rate (mm/d)
! FLOOD       Current depth of flooding (mm)
! FLOODWAT    Composite variable containing information related to bund
!               management. Structure of variable is defined in
!               ModuleDefs.for.
! IDETW       Y=detailed water balance output, N=no detailed output
! ISWITCH     Composite variable containing switches which control flow of
!               execution for model.  The structure of the variable
!               (SwitchType) is defined in ModuleDefs.for.
! ISWWAT      Water simulation control switch (Y or N)
! KSEVAP      Light extinction coefficient used for computation of soil
!               evaporation
! KTRANS      Light extinction coefficient used for computation of plant
!               transpiration
! LL(L)       Volumetric soil water content in soil layer L at lower limit
!              (cm3 [water] / cm3 [soil])
! MEEVP       Method of evapotranspiration ('P'=Penman,
!               'R'=Priestly-Taylor, 'Z'=Zonal)
! MEPHO       Method for photosynthesis computation ('C'=Canopy or daily,
!               'L'=hedgerow or hourly)
! NLAYR       Actual number of soil layers
! PORMIN      Minimum pore space required for supplying oxygen to roots for
!               optimal growth and function (cm3/cm3)
! RLV(L)      Root length density for soil layer L (cm[root] / cm3[soil])
! RWU(L)      Root water uptake from soil layer L (cm/d)
! RWUMX       Maximum water uptake per unit root length, constrained by
!               soil water (cm3[water] / cm [root])
! MSALB       Soil albedo with mulch and soil water effects (fraction)
! SAT(L)      Volumetric soil water content in layer L at saturation
!              (cm3 [water] / cm3 [soil])
! SOILPROP    Composite variable containing soil properties including bulk
!               density, drained upper limit, lower limit, pH, saturation
!               water content.  Structure defined in ModuleDefs.
! SRAD        Solar radiation (MJ/m2-d)
! SRFTEMP     Temperature of soil surface litter (�C)
! ST(L)       Soil temperature in soil layer L (�C)
! SUMES1      Cumulative soil evaporation in stage 1 (mm)
! SUMES2      Cumulative soil evaporation in stage 2 (mm)
! SW(L)       Volumetric soil water content in layer L
!              (cm3 [water] / cm3 [soil])
! SW_AVAIL(L) Soil water content in layer L available for evaporation,
!               plant extraction, or movement through soil
!               (cm3 [water] / cm3 [soil])
! SWDELTS(L)  Change in soil water content due to drainage in layer L
!              (cm3 [water] / cm3 [soil])
! SWDELTU(L)  Change in soil water content due to evaporation and/or upward
!               flow in layer L (cm3 [water] / cm3 [soil])
! SWDELTX(L)  Change in soil water content due to root water uptake in
!               layer L (cm3 [water] / cm3 [soil])
! T           Number of days into Stage 2 evaporation (WATBAL); or time
!               factor for hourly temperature calculations
! TA          Daily normal temperature (�C)
! TAMP        Amplitude of temperature function used to calculate soil
!               temperatures (�C)
! TAV         Average annual soil temperature, used with TAMP to calculate
!               soil temperature. (�C)
! TAVG        Average daily temperature (�C)
! TMAX        Maximum daily temperature (�C)
! TMIN        Minimum daily temperature (�C)
! TRWU        Actual daily root water uptake over soil profile (cm/d)
! TRWUP       Potential daily root water uptake over soil profile (cm/d)
! U           Evaporation limit (cm)
! WINDSP      Wind speed at 2m (km/d)
! WINF        Water available for infiltration - rainfall minus runoff plus
!               net irrigation (mm / d)
! XHLAI       Healthy leaf area index (m2[leaf] / m2[ground])
! XLAT        Latitude (deg.)
!-----------------------------------------------------------------------
!     END SUBROUTINE SPAM
!-----------------------------------------------------------------------

