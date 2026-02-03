!=======================================================================
!  K_Ceres, Translates MZ_CERES variables into variables required by
!     the generic plant potassium routine, K_PLANT.
!
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_Ceres for potassium simulation.
!-----------------------------------------------------------------------
!  Called by: MZ_CERES
!  Calls:     K_PLANT
!=======================================================================
      SUBROUTINE K_Ceres (DYNAMIC, ISWPOT,                !Input
     &    CumLeafSenes, DLAYR, DS, FILECC, MDATE, NLAYR,  !Input
     &    PCNVEG, PConc_Veg, PLTPOP, PODWT, RLV, RTDEP,   !Input
     &    RTWTO, SDWT, SWIDOT, SeedFrac, SKi_AVAIL,       !Input
     &    Stem2Ear, STMWTO, VegFrac, WLIDOT, WRIDOT,      !Input
     &    WSIDOT, WTLF, YRPLT,                            !Input
     &    SENESCE,                                        !I/O
     &    KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, !Output
     &    KStres1, KStres2, KUptake, FracRts)             !Output

!     ------------------------------------------------------------------
!     Send DYNAMIC to accomodate emergence calculations
!       (DYNAMIC=EMERG) within the integration section of CERES
!     ------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      IMPLICIT  NONE
      EXTERNAL K_Plant
      SAVE
!     ------------------------------------------------------------------

      CHARACTER*1 ISWPOT
      CHARACTER*2 CROP
      CHARACTER*6, PARAMETER :: ERRKEY = 'KCERES'
      CHARACTER*92 FILECC

      INTEGER DYNAMIC, L, MDATE, NLAYR, YRPLT
      INTEGER, PARAMETER :: SRFC = 0
      INTEGER, PARAMETER :: K = 3   !Element index for potassium

      REAL Shut_kg, Leaf_kg, Stem_kg, Root_kg, Shel_kg, Seed_kg
      REAL PhFrac1, PhFrac2
      REAL PLTPOP, PODWT, MoveK
      REAL KStres1, KStres2
      REAL RTDEP, RTWTO, SDWT, SHELWT
      REAL SeedFrac, VegFrac, STMWTO, WTLF
      REAL CumSenSurfK, CumLeafSenes, CumLeafSenesY
      REAL SenSurf, SenSurfK, SenSoil, SenSoilK
      REAL KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed
      REAL PCNVEG, PConc_Veg
      REAL KShut_kg, KRoot_kg, KShel_kg, KSeed_kg
      REAL Stem2Ear
      REAL SWIDOT, WLIDOT, WRIDOT, WSIDOT
      REAL PestShut, PestRoot, PestShel, PestSeed
      REAL ShutMob, RootMob, ShelMob

      REAL, DIMENSION(NL) :: DLAYR, DS, SKi_AVAIL
      REAL, DIMENSION(NL) :: KUptake, RLV, FracRts

      TYPE (ResidueType) SENESCE
      TYPE (ControlType) CONTROL

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

!***********************************************************************
!***********************************************************************
      IF (DYNAMIC == SEASINIT) THEN

      CALL GET(CONTROL)
      CROP = CONTROL % CROP

!       Soil potassium routine needs volume of soil adjacent to roots.
        CALL RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC,   !Input
     &    FracRts)                                        !Output

        Shut_kg = 0.0
        Leaf_kg = 0.0
        Stem_kg = 0.0
        Root_kg = 0.0
        Shel_kg = 0.0
        Seed_kg = 0.0

        SENESCE % ResE = 0.0
        SenSoilK = 0.0
        SenSurfK = 0.0
        CumSenSurfK = 0.0

        PestShut = 0.
        PestRoot = 0.
        PestShel = 0.
        PestSeed = 0.

!       Mass of mobilized plant tissue -- not used in Ceres, set to zero.
        ShutMob = 0.0
        RootMob = 0.0
        ShelMob = 0.0

!       Yesterdays cumulative leaf senescence
        CumLeafSenesY = 0.0

      ELSE    !Not an initialization
        IF (ISWPOT == 'N') RETURN
      ENDIF

      IF (DYNAMIC < OUTPUT) THEN
!       Convert units for Generic Plant Potassium routine to kg/ha
        SHELWT = PODWT - SDWT               !g/m2

        Leaf_kg = WTLF * 10.
        Stem_kg = STMWTO * 10.
        Shut_kg = Leaf_kg + Stem_kg
        Root_kg = RTWTO * 10.
        Shel_kg = SHELWT * 10.
        Seed_kg = SDWT * 10.

        IF (Stem2Ear > 1.E-6) THEN
!         First growth of ears -- mass was transferred from stem
!         Need to transfer K
          MoveK = Stem2Ear * 10. * KConc_Shut   !kg[K]/ha
          KShut_kg = KShut_kg - MoveK
          KShel_kg = KShel_kg + MoveK * (Shel_kg/(Stem2Ear*10))
          KSeed_kg = KSeed_kg + MoveK * (Seed_kg/(Stem2Ear*10))
          Stem2Ear = 0.0
        ENDIF

      ENDIF

      IF (DYNAMIC == INTEGR) THEN
        CALL RootSoilVol(DYNAMIC, ISWPOT,
     &    DLAYR, DS, NLAYR, PLTPOP, RLV, RTDEP, FILECC,   !Input
     &    FracRts)                                        !Output

!       Add in daily senesced leaf mass, which has not dropped from plant
!       and therefore was not added to SENESCE variable
        SenSurf = CumLeafSenes - CumLeafSenesY       !kg [dry matter]/ha
        SenSurfK = (CumLeafSenes - CumLeafSenesY) * KConc_Shut !kg[K]/ha
        CumSenSurfK = CumSenSurfK + SenSurfK

!       Save cumulative leaf senescence for use tomorrow
        CumLeafSenesY = CumLeafSenes

!       Senesced matter to soil (kg[K]/ha) - already added to SENESCE
        SenSoil = 0.0
        SenSoilK = 0.0
        DO L = 1, NLAYR
          SenSoil = SenSoil + SENESCE % ResWt(L)
          SENESCE % ResE(L,K) = SENESCE % ResWt(L) * KConc_Root
          SenSoilK = SenSoilK + SENESCE % ResE(L,K)   !kg/ha
        ENDDO
        SENESCE % CUMRESE(K) = SENESCE % CUMRESE(K) + SenSoilK

!       Pest damage - convert from g/m2 to kg/ha
        PestShut = (WLIDOT + WSIDOT) * 10.
        PestRoot = WRIDOT * 10.
        PestShel = 0.0
        PestSeed = SWIDOT * 10.
      ENDIF

!     PhFrac1 is the fraction of physiological time which has occurred between
!       emergence and first tassel.
!     PhFrac2 is the fraction of physiological time which has occurred between
!       first tassel and physiological maturity.
      PhFrac1 = VegFrac
      PhFrac2 = SeedFrac

      CALL K_Plant (DYNAMIC, ISWPOT,                      !I Control
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

      IF (DYNAMIC == SEASEND) THEN
        SENESCE % ResE(SRFC,K) = CumSenSurfK
      ENDIF
!***********************************************************************
      RETURN
      END SUBROUTINE K_Ceres
C=======================================================================
