!=======================================================================
!  K_CGRO, Translates CROPGRO variables into variables required by
!     the generic plant potassium routine, K_PLANT.
!
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_CGRO for potassium simulation.
!-----------------------------------------------------------------------
!  Called by: CROPGRO
!  Calls:     K_PLANT
!=======================================================================
      SUBROUTINE K_CGRO (DYNAMIC, ISWITCH,
     &    CROP, FILECC, MDATE, PCNVEG, PConc_Veg, PLTPOP, !Input
     &    RLV, RootMob, RTDEP, RTWT, SDWT, SeedFrac,      !Input
     &    ShelMob, SHELWT, ShutMob, SOILPROP,             !Input
     &    SKi_AVAIL, STMWT, SWIDOT, VegFrac, WLIDOT,      !Input
     &    WRIDOT, WSHIDT, WSIDOT, WTLF, YRPLT,            !Input
     &    SENESCE,                                        !I/O
     &    KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, !Output
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
      CHARACTER*6, PARAMETER :: ERRKEY = 'K_CGRO'
      CHARACTER*92 FILECC

      INTEGER DYNAMIC, L, MDATE, NLAYR, YRPLT
      INTEGER, PARAMETER :: K = 3   !Element index for potassium

      REAL KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed
      REAL KShut_kg, KRoot_kg, KShel_kg, KSeed_kg
      REAL PhFrac1, PhFrac2
      REAL KStres1, KStres2, SeedFrac, VegFrac
      REAL WTLF, STMWT, RTWT, SHELWT, SDWT
      REAL Leaf_kg, Stem_kg, Root_kg, Shel_kg, Seed_kg
      REAL ShutMob, ShelMob, RootMob
      REAL SenSurf, SenSurfK, SenSoilK
      REAL PCNVEG, PConc_Veg
      REAL PestShut, PestRoot, PestShel, PestSeed
      REAL WLIDOT, WSIDOT, WRIDOT, WSHIDT, SWIDOT

!     For RootSoilVol:
      REAL PLTPOP, RTDEP, FracRts(NL)

      REAL, DIMENSION(NL) :: DLAYR, DS, SKi_AVAIL
      REAL, DIMENSION(NL) :: KUptake, RLV

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

      DLAYR  = SOILPROP % DLAYR
      DS     = SOILPROP % DS
      NLAYR  = SOILPROP % NLAYR

      ISWPOT = ISWITCH % ISWPOT

!***********************************************************************
      IF (DYNAMIC == SEASINIT) THEN
        IF (CROP /= 'FA') THEN
!         Soil potassium routine needs volume of soil adjacent to roots.
          CALL RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC,   !Input
     &    FracRts)                                        !Output
        ELSE
          FracRts = 0.0
        ENDIF

        Leaf_kg = 0.0
        Stem_kg = 0.0
        Root_kg = 0.0
        Shel_kg = 0.0
        Seed_kg = 0.0

        SENESCE % ResE = 0.0
        SenSoilK = 0.0
        SenSurfK = 0.0
        SENESCE%CumResE(K) = 0.0

        PestShut = 0.
        PestRoot = 0.
        PestShel = 0.
        PestSeed = 0.

      ELSE    !Not an initialization
        IF (ISWPOT == 'N') RETURN
      ENDIF

!***********************************************************************
      IF (CROP .NE. 'FA') THEN
!       Convert units for Generic Plant Potassium routine
        Leaf_kg = WTLF * 10.
        Stem_kg = STMWT * 10.
        Root_kg = RTWT * 10.
        Shel_kg = SHELWT * 10.
        Seed_kg = SDWT * 10.

        IF (DYNAMIC .EQ. INTEGR) THEN
!         Calculate K senesced in shoots
!         This routine is called prior to senescence calcultion in GROW
!           subroutine.  Need to recompute yesterday's senescence from
!           the cumulative variable.
          SenSurf = SENESCE%ResWt(0)
          SenSurfK = SenSurf * KConc_Shut
          SENESCE % ResE(0,K) = SenSurfK

!         Calculate K senesced in roots
          SenSoilK = 0.0
          DO L = 1, NLAYR
            SENESCE % ResE(L,K) = SENESCE%ResWt(L) * KConc_Root
            SenSoilK = SenSoilK + SENESCE % ResE(L,K)   !kg/ha
          ENDDO
          SENESCE%CumResE(K) = SENESCE%CumResE(K) + SenSurfK + SenSoilK

          CALL RootSoilVol(DYNAMIC, ISWPOT,
     &      DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC, !Input
     &      FracRts)                                      !Output

!         Pest damage - convert from g/m2 to kg/ha
!         PestShut includes leaf and stem pest damage
          PestShut = (WLIDOT + WSIDOT) * 10.
          PestRoot = WRIDOT * 10.
          PestShel = WSHIDT * 10.
          PestSeed = SWIDOT * 10.
         ENDIF

!       PhFrac1 is the fraction of physiological time which has
!         occurred between emergence and first seed.
!       PhFrac2 is the fraction of physiological time which has
!         occurred between first seed and physiological maturity.
        PhFrac1 = VegFrac
        PhFrac2 = SeedFrac
      ENDIF

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
      END SUBROUTINE K_CGRO
C=======================================================================
