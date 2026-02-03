!=======================================================================
!  K_CASUPRO, Based on K_Ceres.  Translates CSP_CASUPRO variables
!     into variables required by the generic plant potassium routine,
!     K_PLANT.
!
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_CASUPRO for potassium simulation.
!-----------------------------------------------------------------------
!  Called by: CSP_CASUPRO
!  Calls:     K_PLANT
!=======================================================================
      SUBROUTINE K_CASUPRO (CONTROL, DYNAMIC, ISWITCH,    !Input
     &    CROP, FILECC, GrowFrac, LFWTHa, MDATE,          !Input
     &    PCNVEG, PConc_Veg, PLTPOP, RipeFrac, RLV,       !Input
     &    RTDEP, RTWTHa, SOILPROP, SKi_AVAIL, STKWTHa,    !Input
     &    WLIDOT, WRIDOT, WSIDOT, YRPLT,                  !Input
     &    SENESCE,                                        !I/O
     &    KConc_Shut, KConc_Root, KConc_Seed,             !Output
     &    KStres1, KStres2, KUptake, FracRts)             !Output

!     ------------------------------------------------------------------
!     Send DYNAMIC to accomodate emergence calculations
!       (DYNAMIC=EMERG) within the integration section of CROPGRO.
!     ------------------------------------------------------------------
      USE ModuleDefs     !Definitions of constructed variable types,
                         !which contain control information, soil
                         !parameters, hourly weather data.
      IMPLICIT  NONE
      EXTERNAL K_PLANT
      SAVE
!     ------------------------------------------------------------------

      CHARACTER*1 ISWPOT
      CHARACTER*2 CROP
      CHARACTER*9, PARAMETER :: ERRKEY = 'K_CASUPRO'
      CHARACTER*92 FILECC

      INTEGER DAS, DYNAMIC, L, MDATE, NLAYR, YRPLT
      INTEGER, PARAMETER :: K = 3   !Element index for potassium

      REAL Leaf_kg, Stem_kg, Root_kg, Shel_kg, Seed_kg
      REAL PhFrac1, PhFrac2
      REAL PLTPOP
      REAL KStres1, KStres2
      REAL RTDEP
      REAL GrowFrac, RipeFrac
      REAL SenSurf, SenSurfK, SenSoilK
      REAL KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed
      REAL PCNVEG, PConc_Veg
      REAL KShut_kg, KRoot_kg, KShel_kg, KSeed_kg
      REAL WLIDOT, WRIDOT, WSIDOT
      REAL PestShut, PestRoot, PestShel, PestSeed
      REAL ShutMob, RootMob, ShelMob

      REAL, DIMENSION(NL) :: DLAYR, DS, SKi_AVAIL
      REAL, DIMENSION(NL) :: KUptake, RLV, FracRts
      REAL, DIMENSION(0:NumOfDays) :: STKWTHa, LFWTHa, RTWTHa

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH
      TYPE (SoilType)    SOILPROP
      TYPE (ResidueType) SENESCE

!-----------------------------------------------------------------------
!    Need to call RootSoilVol to initialize root volume
!     when fertilizer added in bands or hills prior to planting.
      INTERFACE
        SUBROUTINE RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR,           !Input from all routines
     &    PLTPOP, RLV, RTDEP, FILECC, !Input from plant routine
     &    FracRts,                    !Output
     &    LAYER, AppType)      !Input from soil module (for banded fert)
          USE ModuleDefs
          IMPLICIT NONE
          CHARACTER*1,         INTENT(IN)           :: ISWPOT
          INTEGER,             INTENT(IN)           :: DYNAMIC, NLAYR
          REAL, DIMENSION(NL), INTENT(IN)           :: DS, DLAYR
          REAL, DIMENSION(NL), INTENT(OUT)          :: FracRts
          REAL,                INTENT(IN), OPTIONAL :: PLTPOP, RTDEP
          REAL, DIMENSION(NL), INTENT(IN), OPTIONAL :: RLV
          CHARACTER*92,        INTENT(IN), OPTIONAL :: FILECC
          INTEGER,             INTENT(IN), OPTIONAL :: LAYER
          CHARACTER*7,         INTENT(IN), OPTIONAL :: AppType
        END SUBROUTINE RootSoilVol
      END INTERFACE
!-----------------------------------------------------------------------

      DAS    = CONTROL % DAS

      DLAYR  = SOILPROP % DLAYR
      DS     = SOILPROP % DS
      NLAYR  = SOILPROP % NLAYR

      ISWPOT = ISWITCH % ISWPOT
!***********************************************************************
      IF (DYNAMIC == SEASINIT) THEN


!       Soil potassium routine needs volume of soil adjacent to roots.
        CALL RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC,   !Input
     &    FracRts)                                        !Output

        Leaf_kg = 0.0
        Stem_kg = 0.0
        Root_kg = 0.0
        Shel_kg = 0.0
        Seed_kg = 0.0
!       Mass of mobilized plant tissue not used in CASUPRO: set to zero.
        ShutMob = 0.0
        RootMob = 0.0
        ShelMob = 0.0

        SENESCE % ResE = 0.0
        SenSoilK = 0.0
        SenSurfK = 0.0
        SENESCE%CumResE(K) = 0.0

        PestShut = 0.
        PestRoot = 0.
        PestShel = 0.
        PestSeed = 0.



        CALL RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC,   !Input
     &    FracRts)                                        !Output

      ELSE    !Not an initialization
        IF (ISWPOT == 'N') RETURN
      ENDIF

!***********************************************************************
      IF (DYNAMIC < OUTPUT) THEN
!     Convert variables to those needed by Generic Plant Potassium routine
        Leaf_kg = LFWTHa(DAS)
        Stem_kg = STKWTHa(DAS)
        Root_kg = RTWTHa(DAS)
      ENDIF

        IF (DYNAMIC .EQ. INTEGR) THEN
        CALL RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC,   !Input
     &    FracRts)                                        !Output

        SenSurf = SENESCE%ResWt(0)
        SenSurfK = SenSurf * KConc_Shut
        SENESCE % ResE(0,K) = SenSurfK

!         Calculate K senesced in roots
        SenSoilK = 0.0
        DO L = 1, NLAYR
          SENESCE % ResE(L,K) = SENESCE % ResWt(L) * KConc_Root
          SenSoilK = SenSoilK + SENESCE % ResE(L,K)   !(kg[K]/ha)
        ENDDO

          SENESCE%CumResE(K) = SENESCE%CumResE(K) + SenSurfK + SenSoilK

          CALL RootSoilVol(DYNAMIC, ISWPOT,
     &      DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC, !Input
     &      FracRts)                                      !Output
!       Pest damage - convert from g/m2 to kg/ha
!         PestShut includes leaf and stem pest damage
        PestShut = (WLIDOT + WSIDOT) * 10.
        PestRoot = WRIDOT * 10.
        PestShel = 0.0
        PestSeed = 0.0
      ENDIF

!     PhFrac1 is the fraction of physiological time which has occurred between
!       emergence and rapid stalk growth.
!     PhFrac2 is the fraction of physiological time which has occurred between
!       rapid stalk growth and physiological maturity.
      PhFrac1 = GrowFrac
      PhFrac2 = RipeFrac

      CALL K_PLANT(DYNAMIC, ISWPOT,                       !I Control
     &    CROP, FILECC, MDATE, YRPLT,                     !I Crop
     &    SKi_AVAIL,                                      !I Soils
     &    Leaf_kg, Stem_kg, Root_kg, Shel_kg, Seed_kg,    !I Mass
     &    PhFrac1, PhFrac2,                               !I Phase
     &    RLV,                                            !I Roots
     &    SenSoilK, SenSurfK,                             !I Senescence
     &    PCNVEG, PConc_Veg,                              !I N,P conc.
     &    PestShut, PestRoot, PestShel, PestSeed,         !I Pest damage
     &    ShutMob, RootMob, ShelMob,                      !I Mobilized
     &    KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, !O K conc.
     &    KShut_kg, KRoot_kg, KShel_kg, KSeed_kg,         !O K amts.
     &    KStres1, KStres2,                               !O K stress
     &    KUptake)                                        !O K uptake

!***********************************************************************
      RETURN
      END SUBROUTINE K_CASUPRO
!=======================================================================
