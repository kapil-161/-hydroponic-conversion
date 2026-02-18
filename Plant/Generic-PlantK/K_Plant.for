!=======================================================================
!  K_Plant, Plant potassium model.
!
!  DETERMINES PLANT K TRANSFORMATIONS
!  Computes K concentration and total content for four plant
!    components: shoot (leaf + stem), root, shell and seed.
!  Optimum K concentration for each component is based on 3
!    stages:
!    (1) stage A (e.g., emergence)
!    (2) stage B (e.g., first flower)
!    (3) stage C (e.g., physiological maturity)
!  Optimum, minimum, and luxury K concentrations for each plant
!    component/stage are read from the species file.
!  Fraction of development between stages is sent from each plant
!    routine.  This routine linearly interpolates optimum and
!    minimum K concentrations between stages.
!
!  K-SPECIFIC FEATURES:
!  - K concentrations are ~10x higher than P (1-5% vs 0.1-0.5%)
!  - K is highly mobile in plants (higher remobilization rates)
!  - Luxury K uptake supported (storage above optimum)
!  - K stress affects stomatal conductance (KStres1)
!  - K stress affects photosynthesis (KStres2)
!  - Partitioning priority: Vegetative > Reproductive (K stays in straw)
!
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_Plant.for for potassium simulation.
!-----------------------------------------------------------------------
!  Called by: CROPGRO, MZ_CERES, RI_CERES...
!  Calls:     K_UPTAKE, OPPOTK
!=======================================================================
      SUBROUTINE K_Plant (DYNAMIC, ISWPOT,                !I Control
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

!     ------------------------------------------------------------------
!     Send DYNAMIC to accomodate emergence calculations
!       (DYNAMIC=EMERG) within the integration section of CROPGRO.
!     ------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      IMPLICIT  NONE
      EXTERNAL K_IPPLNT, K_Demand, K_Uptake, OPPlantK, K_Partition,
     &  KValue
      SAVE
!     ------------------------------------------------------------------
!     Interface variables
!     ------------------------------------------------------------------
!     INPUT
      INTEGER      DYNAMIC        !Processing control
      CHARACTER*1  ISWPOT         !K switch (Y or N)
      CHARACTER*2  CROP           !2-character crop code
      CHARACTER*92 FILECC         !Path and name of species file
      INTEGER      MDATE          !Maturity date
      INTEGER      YRPLT          !Planting date

      REAL         SKi_AVAIL(NL)  !K available for uptake (kg/ha)

      !State variables - mass (kg/ha) - includes new growth
      REAL         Leaf_kg        !Leaf mass (kg/ha)
      REAL         Stem_kg        !Stem mass (kg/ha)
      REAL         Root_kg        !Root mass (kg/ha)
      REAL         Shel_kg        !Shell mass (kg/ha)
      REAL         Seed_kg        !Seed mass (kg/ha)

      REAL         PhFrac1      !Fraction phys time betw St 1 & St 2
      REAL         PhFrac2      !Fraction phys time betw St 2 & St 3
      REAL         RLV(NL)        !Root length density
      REAL         SenSoilK       !K senesced from roots
      REAL         SenSurfK       !K senesced from leaf + stem
      REAL         PCNVEG         !N percentage in veg. tissue
      REAL         PConc_Veg      !P concentration in veg. tissue
      !Pest damage variables:
      REAL         PestShut       !Pest damage to leaf and stem
      REAL         PestRoot       !Pest damage to root
      REAL         PestShel       !Pest damage to shell
      REAL         PestSeed       !Pest damage to seed
      !Plant mass lost due to mobilization of N and C
      REAL         ShutMob        !Mobilization loss for leaf and stem
      REAL         RootMob        !Mobilization loss for roots
      REAL         ShelMob        !Mobilization loss for shells

!     OUTPUT
      REAL         KConc_Shut     !K conc in shoots (kg[K]/kg[shoots])
      REAL         KConc_Root     !K conc in roots (kg[K]/kg[roots])
      REAL         KConc_Veg      !K conc in veg tissue (kg[K]/kg[veg])
      REAL         KStres1        !K stress for stomatal conductance
      REAL         KStres2        !K stress for photosynthesis
      REAL         KUptake(NL)    !K uptake by soil layer (kg/ha)

!     ------------------------------------------------------------------
      CHARACTER*6, PARAMETER :: ERRKEY = 'KPLANT'
      LOGICAL UseShoots
      INTEGER I

!     Shoot mass -- leaf + stem (kg/ha)
      REAL Shut_kg

!     Change (increase or decrease) to K variable per day
      REAL DeltKShut, DeltKRoot, DeltKShel, DeltKSeed

!     Daily values of optimum, minimum, luxury and actual K concs.
      REAL KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt,KConc_Seed_opt
      REAL KConc_Shut_min, KConc_Root_min, KConc_Shel_min,KConc_Seed_min
      REAL KConc_Shut_lux, KConc_Root_lux  !Luxury K concentrations
      REAL KConc_Shel, KConc_Seed, KConc_Plant

!     K state variables by weight (kg/ha)
      REAL KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg
      REAL KLuxury_kg  !K stored above optimum (luxury storage)

!     Misc.
      REAL KShutDem, KRootDem, KShelDem, KSeedDem, KTotDem
      REAL KLuxuryDem  !Demand for luxury K storage
      REAL KSTRESS_RATIO, KSTRESS_SUPPLY
      REAL KUptakeProf
      REAL Plant_kg
      REAL N2K, N2K_max, N2K_min
      REAL P2K, P2K_max, P2K_min  !P:K ratio constraints
      REAL PestShutK, PestRootK, PestShelK, PestSeedK
      REAL KSTFAC
      PARAMETER (KSTFAC = 0.70)  ! K stress threshold factor

!     Hydroponic mode variables
      CHARACTER*1 ISWHYDRO
      REAL UKi_HYDRO
      TYPE (SwitchType) ISWITCH

!     From species file:
      REAL, DIMENSION(3) :: KCShutOpt, KCRootOpt, KCShelOpt, KCSeedOpt
      REAL, DIMENSION(3) :: KCLeafOpt, KCStemOpt
      REAL, DIMENSION(3) :: KCShutMin, KCRootMin, KCShelMin, KCSeedMin
      REAL, DIMENSION(3) :: KCLeafMin, KCStemMin
      REAL, DIMENSION(3) :: KCShutLux, KCRootLux  !Luxury concentrations
      REAL, DIMENSION(3) :: N2Kmin, N2Kmax
      REAL, DIMENSION(3) :: P2Kmin, P2Kmax
      REAL SRATSTOM, SRATPHOTO_K
      REAL FracKMobil, FracKUptake
      REAL KMAX_LUXURY  !Maximum luxury factor (e.g., 1.4 = 40% above opt)

      Real KValue !Function

!***********************************************************************
!***********************************************************************
!     SEASONAL INITIALIZATION: RUN ONCE PER SEASON.
!***********************************************************************
      IF (DYNAMIC == SEASINIT .OR. DYNAMIC .EQ. RUNINIT) THEN
!     ------------------------------------------------------------------
      IF (CROP .NE. 'FA' .AND.
     &   (ISWPOT .EQ. 'Y' .OR. ISWPOT .EQ. 'H')) THEN
        CALL K_IPPLNT(FILECC,
     & N2Kmax, N2Kmin, P2Kmax, P2Kmin,
     & KCShutMin, KCLeafMin, KCStemMin, KCRootMin, KCShelMin, KCSeedMin,
     & KCShutOpt, KCLeafOpt, KCStemOpt, KCRootOpt, KCShelOpt, KCSeedOpt,
     & KCShutLux, KCRootLux,
     & FracKMobil, FracKUptake, SRATPHOTO_K, SRATSTOM,
     & KMAX_LUXURY, UseShoots)
      ENDIF

!     ------------------------------------------------------------------
      Call K_Demand(DYNAMIC,
     &    KConc_Root, KConc_Root_min, KConc_Root_opt,     !Input
     &    KConc_Shel, KConc_Shel_min, KConc_Shel_opt,     !Input
     &    KConc_Shut, KConc_Shut_min, KConc_Shut_opt,     !Input
     &    KConc_Shut_lux, KConc_Root_lux,                 !Input (luxury)
     &    KConc_Seed_opt, KRoot_kg, KSeed_kg, KShel_kg,   !Input
     &    KShut_kg, Root_kg, RootMob, Seed_kg, Shel_kg,   !Input
     &    ShelMob, Shut_kg, ShutMob,                      !Input
     &    DeltKRoot, DeltKSeed, DeltKShel, DeltKShut,     !I/O
     &    KRootDem, KSeedDem, KShelDem, KShutDem,         !Output
     &    KTotDem, KLuxuryDem)                            !Output

!     ------------------------------------------------------------------
!     Initialize uptake variables - do this even if K not modelled.
      CALL K_Uptake (DYNAMIC,
     &    N2K_min, P2K_min, PCNVeg, KConc_Veg, PConc_Veg, !Input
     &    KTotDem, KLuxuryDem, RLV, SKi_AVAIL,            !Input
     &    N2K, P2K, KUptake, KUptakeProf)                 !Output

!     Optimum K concentration
      KConc_Shut_opt = 0.0
      KConc_Root_opt = 0.0
      KConc_Shel_opt = 0.0
      KConc_Seed_opt = 0.0

!     Minimum K concentration
      KConc_Shut_min = 0.0
      KConc_Root_min = 0.0
      KConc_Shel_min = 0.0
      KConc_Seed_min = 0.0

!     Luxury K concentration
      KConc_Shut_lux = 0.0
      KConc_Root_lux = 0.0

!     K concentration variables (fraction of plant tissue)
      KConc_Shut  = 0.0
      KConc_Root  = 0.0
      KConc_Shel  = 0.0
      KConc_Seed  = 0.0
      KConc_Plant = 0.0

!     K[kg/ha] variables
      KShut_kg  = 0.0
      KRoot_kg  = 0.0
      KShel_kg  = 0.0
      KSeed_kg  = 0.0
      KPlant_kg = 0.0
      KLuxury_kg = 0.0

!     Demand variables
      KShutDem = 0.0
      KRootDem = 0.0
      KShelDem = 0.0
      KSeedDem = 0.0
      KTotDem  = 0.0
      KLuxuryDem = 0.0

      KStres1 = 1.0
      KStres2 = 1.0
      KSTRESS_RATIO = 1.0

!     K in senesced tissue
      SenSoilK = 0.0
      SenSurfK = 0.0

!     N:K and P:K ratios
      N2K = 0.0
      P2K = 0.0

!     Initial shoot mass
      Shut_kg = 0.0

!     Initial fraction of physiological age for veg and repro
      PhFrac1 = 0.0
      PhFrac2 = 0.0

      IF (ISWPOT == 'N') RETURN

      CALL OPPlantK(DYNAMIC, MDATE, YRPLT,
     &  KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt, KConc_Seed_opt,
     &  KConc_Shut_min, KConc_Root_min, KConc_Shel_min, KConc_Seed_min,
     &  KConc_Shut_lux,
     &  KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, KConc_Plant,
     &  KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg, KLuxury_kg,
     &  Shut_kg, Root_kg, Shel_kg, Seed_kg, N2K, P2K, KTotDem,
     &  SenSoilK, SenSurfK, PhFrac1, PhFrac2,
     &  KStres1, KStres2, KSTRESS_RATIO, KUptakeProf,
     &  PestShutK, PestRootK, PestShelK, PestSeedK)

!***********************************************************************
!***********************************************************************
!     EMERGENCE
!***********************************************************************
      ELSEIF (DYNAMIC == EMERG) THEN
!-----------------------------------------------------------------------
      KTotDem = 0.0
      Shut_kg = Leaf_kg + Stem_kg

!     Optimum K concentration in vegetative matter at emergence (fraction)
      IF (UseShoots) THEN
        KConc_Shut_opt = KCShutOpt(1)
        KConc_Shut_lux = KCShutLux(1)
      ELSE
        KConc_Shut_opt = (KCLeafOpt(1)*Leaf_kg + KCStemOpt(1)*Stem_kg) /
     &                        Shut_kg
        KConc_Shut_lux = KConc_Shut_opt * KMAX_LUXURY
      ENDIF
      KConc_Root_opt = KCRootOpt(1)
      KConc_Root_lux = KCRootLux(1)
      KConc_Shel_opt = KCShelOpt(1)
      KConc_Seed_opt = KCSeedOpt(1)

!     Initial K concentration in vegetative matter at emergence (fraction)
!     Start at optimum concentration
      KConc_Shut = KConc_Shut_opt
      KConc_Root = KConc_Root_opt
      KConc_Shel = KConc_Shel_opt
      KConc_Seed = KConc_Seed_opt

!     Total plant weight
      Plant_kg = Shut_kg + Root_kg + Shel_kg + Seed_kg

!     Plant K (kg/ha)
      KShut_kg = KConc_Shut * Shut_kg
      KRoot_kg = KConc_Root * Root_kg
      KShel_kg = KConc_Shel * Shel_kg
      KSeed_kg = KConc_Seed * Seed_kg
      KPlant_kg = KShut_kg + KRoot_kg + KShel_kg + KSeed_kg
      KLuxury_kg = 0.0  !No luxury storage at emergence

      CALL OPPlantK(DYNAMIC, MDATE, YRPLT,
     &  KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt, KConc_Seed_opt,
     &  KConc_Shut_min, KConc_Root_min, KConc_Shel_min, KConc_Seed_min,
     &  KConc_Shut_lux,
     &  KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, KConc_Plant,
     &  KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg, KLuxury_kg,
     &  Shut_kg, Root_kg, Shel_kg, Seed_kg, N2K, P2K, KTotDem,
     &  SenSoilK, SenSurfK, PhFrac1, PhFrac2,
     &  KStres1, KStres2, KSTRESS_RATIO, KUptakeProf,
     &  PestShutK, PestRootK, PestShelK, PestSeedK)

!***********************************************************************
!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSEIF (DYNAMIC == INTEGR) THEN
!-----------------------------------------------------------------------
!     Get hydroponic mode switch from ISWITCH structure
      CALL GET(ISWITCH)
      ISWHYDRO = ISWITCH % ISWHYDRO

      Shut_kg = Leaf_kg + Stem_kg
      Plant_kg = Shut_kg + Root_kg + Shel_kg + Seed_kg

      IF (.NOT. UseShoots .AND. Shut_kg > 0) THEN
        DO I = 1, 3
          KCShutOpt(I) = (KCLeafOpt(I)*Leaf_kg + KCStemOpt(I)*Stem_kg) /
     &                                    Shut_kg
          KCShutMin(I) = (KCLeafMin(I)*Leaf_kg + KCStemMin(I)*Stem_kg) /
     &                                    Shut_kg
          KCShutLux(I) = KCShutOpt(I) * KMAX_LUXURY
        ENDDO
      ENDIF

!-----------------------------------------------------------------------
!     Initialize delta variables
      DeltKShut = 0.0
      DeltKRoot = 0.0
      DeltKShel = 0.0
      DeltKSeed = 0.0

!-----------------------------------------------------------------------
!     Senesced plant matter - reduce K
      KShut_kg  = KShut_kg - SenSurfK
      KRoot_kg  = KRoot_kg - SenSoilK
      KPlant_kg = KPlant_kg - (SenSoilK + SenSurfK)

!     Pest damage
      PestShutK = PestShut * KConc_Shut
      PestRootK = PestRoot * KConc_Root
      PestShelK = PestShel * KConc_Shel
      PestSeedK = PestSeed * KConc_Seed

      KShut_kg  = KShut_kg - PestShutK
      KRoot_kg  = KRoot_kg - PestRootK
      KShel_kg  = KShel_kg - PestShelK
      KSeed_kg  = KSeed_kg - PestSeedK

      KPlant_kg = KPlant_kg -
     &        (PestShutK + PestRootK + PestShelK + PestSeedK)

!     ------------------------------------------------------------------
!     Calculate optimum, minimum, and luxury K concentrations in plant tissue.
!     ------------------------------------------------------------------
      KConc_Shut_opt =  KValue(PhFrac1, PhFrac2, KCShutOpt)
      KConc_Root_opt =  KValue(PhFrac1, PhFrac2, KCRootOpt)
      KConc_Shel_opt =  KValue(PhFrac1, PhFrac2, KCShelOpt)
      KConc_Seed_opt =  KValue(PhFrac1, PhFrac2, KCSeedOpt)

      KConc_Shut_min =  KValue(PhFrac1, PhFrac2, KCShutMin)
      KConc_Root_min =  KValue(PhFrac1, PhFrac2, KCRootMin)
      KConc_Shel_min =  KValue(PhFrac1, PhFrac2, KCShelMin)
      KConc_Seed_min =  KValue(PhFrac1, PhFrac2, KCSeedMin)

      KConc_Shut_lux =  KValue(PhFrac1, PhFrac2, KCShutLux)
      KConc_Root_lux =  KValue(PhFrac1, PhFrac2, KCRootLux)

      N2K_max =  KValue(PhFrac1, PhFrac2, N2Kmax)
      N2K_min =  KValue(PhFrac1, PhFrac2, N2Kmin)
      P2K_max =  KValue(PhFrac1, PhFrac2, P2Kmax)
      P2K_min =  KValue(PhFrac1, PhFrac2, P2Kmin)

!-----------------------------------------------------------------------
!     CALCULATE DEMANDS in kg/ha (including luxury demand)
      Call K_Demand(DYNAMIC,
     &    KConc_Root, KConc_Root_min, KConc_Root_opt,     !Input
     &    KConc_Shel, KConc_Shel_min, KConc_Shel_opt,     !Input
     &    KConc_Shut, KConc_Shut_min, KConc_Shut_opt,     !Input
     &    KConc_Shut_lux, KConc_Root_lux,                 !Input (luxury)
     &    KConc_Seed_opt, KRoot_kg, KSeed_kg, KShel_kg,   !Input
     &    KShut_kg, Root_kg, RootMob, Seed_kg, Shel_kg,   !Input
     &    ShelMob, Shut_kg, ShutMob,                      !Input
     &    DeltKRoot, DeltKSeed, DeltKShel, DeltKShut,     !I/O
     &    KRootDem, KSeedDem, KShelDem, KShutDem,         !Output
     &    KTotDem, KLuxuryDem)                            !Output

!     Store KTotDem in ModuleData for hydroponic SOLKi module
      CALL PUT('HYDRO','KTOTDEM',KTotDem)

!-----------------------------------------------------------------------
!     K uptake
!     Check if in hydroponic mode - try to get K uptake from ModuleData
!     SOLKi stores as 'UK', K_Uptake stores as 'UKi' - check both
      CALL GET('HYDRO','UK',UKi_HYDRO)
      IF (ISWPOT .NE. 'N' .AND. ISWHYDRO .EQ. 'Y') THEN
!       Hydroponic mode - use K uptake from NUPTAK/SOLKi
        KUptakeProf = UKi_HYDRO
        IF (DYNAMIC .EQ. INTEGR) THEN
          WRITE(*,*) ' K_PLANT: UKi_HYDRO=',UKi_HYDRO,' KUptakeProf=',
     &               KUptakeProf
        ENDIF
!       Set layer-wise uptake to zero (all uptake in solution)
        DO I = 1, NL
          KUptake(I) = 0.0
        ENDDO
!       Calculate N2K and P2K ratios for stress calculation
        IF (KConc_Veg .GT. 0.0) THEN
          IF (PCNVeg .GT. 0.0) N2K = (PCNVeg / 100.0) / KConc_Veg
          IF (PConc_Veg .GT. 0.0) P2K = PConc_Veg / KConc_Veg
        ELSE
          N2K = N2K_min
          P2K = P2K_min
        ENDIF
      ELSE
!       Soil mode - calculate K uptake from soil
        CALL K_Uptake (DYNAMIC,
     &    N2K_min, P2K_min, PCNVeg, KConc_Veg, PConc_Veg, !Input
     &    KTotDem, KLuxuryDem, RLV, SKi_AVAIL,            !Input
     &    N2K, P2K, KUptake, KUptakeProf)                 !Output
      ENDIF

!-----------------------------------------------------------------------
!     K Partitioning (different priority than P: veg > repro)
      CALL K_Partition(
     &    FracKMobil, KConc_Root_min, KConc_Shel_min,     !Input
     &    KConc_Shut_min, KRootDem, KRoot_kg, KSeedDem,   !Input
     &    KShelDem, KShel_kg, KShutDem, KShut_kg,         !Input
     &    KLuxuryDem, KUptakeProf, Root_kg, Shel_kg,      !Input
     &    Shut_kg,                                        !Input
     &    DeltKRoot, DeltKSeed, DeltKShel, DeltKShut)     !I/O

!------------------------------------------------------------------------
!     K mass in plant matter (kg/ha)
      KShut_kg  = KShut_kg + DeltKShut
      KRoot_kg  = KRoot_kg + DeltKRoot
      KShel_kg  = KShel_kg + DeltKShel
      KSeed_kg  = KSeed_kg + DeltKSeed
      KPlant_kg = KPlant_kg + KUptakeProf

!     Calculate luxury K storage (K above optimum in vegetative tissue)
      KLuxury_kg = MAX(0.0, KShut_kg - Shut_kg * KConc_Shut_opt)
     &           + MAX(0.0, KRoot_kg - Root_kg * KConc_Root_opt)

!------------------------------------------------------------------------

C     CALCULATE K CONCENTRATIONS (fractions)
      IF (Seed_kg > 0.) THEN
        KConc_Seed = KSeed_kg / Seed_kg
      ELSE
        KConc_Seed = 0.
      ENDIF

      IF (Shel_kg > 0.) THEN
        KConc_Shel = KShel_kg / Shel_kg
      ELSE
        KConc_Shel = 0.
      ENDIF

      IF (Shut_kg > 0.) THEN
        KConc_Shut = KShut_kg / Shut_kg
      ELSE
        KConc_Shut = 0.
      ENDIF

      IF (Root_kg > 0.) THEN
        KConc_Root = KRoot_kg / Root_kg
      ELSE
        KConc_Root = 0.
      ENDIF

      IF (Plant_kg > 0.) THEN
        KConc_Plant = KPlant_kg / Plant_kg
      ELSE
        KConc_Plant = 0.0
      ENDIF

!     Vegetative K concentration for N:K ratio
      IF (Shut_kg + Root_kg > 1.E-6) THEN
        KConc_Veg = (KConc_Shut * Shut_kg + KConc_Root * Root_kg) /
     &         (Shut_kg + Root_kg)
      ENDIF

!-----------------------------------------------------------------------
!     K STRESS CALCULATIONS
!     K stress affects both stomatal conductance and photosynthesis
!-----------------------------------------------------------------------
!     Calculate KSTRESS_RATIO from tissue concentration
      IF (KConc_Shut_opt - KConc_Shut_Min > 1.E-6) THEN
        KSTRESS_RATIO = MIN(1.0, (KConc_Shut - KConc_Shut_Min) /
     &                       (KConc_Shut_opt - KConc_Shut_Min))
      ELSE
        KSTRESS_RATIO = 1.0
      ENDIF

!     ALSO calculate K stress from supply vs demand
      IF (KTotDem .GT. 1.E-6) THEN
        IF (KUptakeProf .LT. KSTFAC * KTotDem) THEN
!         K supply (uptake) is insufficient
          KSTRESS_SUPPLY = MIN(1.0, KUptakeProf / (KTotDem * KSTFAC))
        ELSE
          KSTRESS_SUPPLY = 1.0
        ENDIF
      ELSE
        KSTRESS_SUPPLY = 1.0  ! No demand = no stress
      ENDIF

C     Use the MINIMUM of tissue-based and supply-based stress ratios
      KSTRESS_RATIO = MIN(KSTRESS_RATIO, KSTRESS_SUPPLY)
      KSTRESS_RATIO = MAX(0.0, KSTRESS_RATIO)

C     Calculate KStres1 (Stomatal conductance) - more sensitive
      IF (KSTRESS_RATIO .GE. SRATSTOM) THEN
        KStres1 = 1.0
      ELSEIF (KSTRESS_RATIO < SRATSTOM .AND. KSTRESS_RATIO > 1.E-6)THEN
        KStres1 = KSTRESS_RATIO / SRATSTOM
      ELSE
        KStres1 = 0.0
      ENDIF

C     Calculate KStres2 (Photosynthesis) - less sensitive
      IF (KSTRESS_RATIO .GE. SRATPHOTO_K) THEN
        KStres2 = 1.0
      ELSEIF (KSTRESS_RATIO < SRATPHOTO_K .AND.
     &        KSTRESS_RATIO > 1.E-6) THEN
        KStres2 = KSTRESS_RATIO / SRATPHOTO_K
      ELSE
        KStres2 = 0.0
      ENDIF

!***********************************************************************
!***********************************************************************
!     DAILY OUTPUT AND SEASONAL SUMMARY
!***********************************************************************
      ELSEIF (DYNAMIC == OUTPUT .OR. DYNAMIC == SEASEND) THEN
!-----------------------------------------------------------------------
      CALL OPPlantK(DYNAMIC, MDATE, YRPLT,
     &  KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt, KConc_Seed_opt,
     &  KConc_Shut_min, KConc_Root_min, KConc_Shel_min, KConc_Seed_min,
     &  KConc_Shut_lux,
     &  KConc_Shut, KConc_Root, KConc_Shel, KConc_Seed, KConc_Plant,
     &  KShut_kg, KRoot_kg, KShel_kg, KSeed_kg, KPlant_kg, KLuxury_kg,
     &  Shut_kg, Root_kg, Shel_kg, Seed_kg, N2K, P2K, KTotDem,
     &  SenSoilK, SenSurfK, PhFrac1, PhFrac2,
     &  KStres1, KStres2, KSTRESS_RATIO, KUptakeProf,
     &  PestShutK, PestRootK, PestShelK, PestSeedK)

      SenSoilK   = 0.0
      SenSurfK   = 0.0
      KUptakeProf = 0.0

!***********************************************************************
!***********************************************************************
!     END OF DYNAMIC IF CONSTRUCT
!***********************************************************************
      ENDIF
!-----------------------------------------------------------------------

      RETURN
      END SUBROUTINE K_Plant
C=======================================================================
