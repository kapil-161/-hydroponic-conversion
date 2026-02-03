!=======================================================================
!  KPlantSubs, Contains subroutines for use by plant potassium model.
!
!  K-SPECIFIC FEATURES:
!  - KValue: Same interpolation function as P
!  - K_Demand: Includes luxury K demand calculation
!  - K_Partition: Different priority (vegetative > reproductive)
!                 K stays preferentially in vegetative tissue
!=======================================================================

!=======================================================================
!  KValue, Linearly interpolates daily optimum and minimum K values
!    based on growth stage fractions.
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on PValue for potassium.
!-----------------------------------------------------------------------
!  Called by: K_PLANT
!=======================================================================
      Function KValue(PhFrac1, PhFrac2, KArray)

!     ------------------------------------------------------------------
      Real KValue                   !Interpolated value returned
      Real, Intent(IN) :: PhFrac1   !Fraction complete growth stage 1
      Real, Intent(IN) :: PhFrac2   !Fraction complete growth stage 2
      Real, Intent(IN) :: KArray(3) !Array of values to be interpolated

!
!                |
! K    KArray(1)>+   x
! V    KArray(2)>+            x
! a              |
! l              |
! u    KArray(3)>+                     x
! e              |___________________________
!                    |        |        |
!                Emergence  Stage1   Stage2
!                        Time  ->
!     ------------------------------------------------------------------
!     Calculate optimum and minimum K concentrations in plant tissue.
!     ------------------------------------------------------------------
      IF (PhFrac1 < 1.E-5) THEN
        !Prior to emergence
        KValue = KArray(1)

      ELSEIF (PhFrac1 < 1.0) THEN
        !First to second critical stage
        KValue = KArray(1) - (KArray(1) - KArray(2)) * PhFrac1

      ELSEIF (PhFrac2 < 1.0) THEN
        !Second to third critical stage
        KValue = KArray(2) - (KArray(2) - KArray(3)) * PhFrac2

      ELSE
        !Subsequent to third critical stage to harvest
        KValue = KArray(3)
      ENDIF

      KValue = MAX(0.0, KValue)

      RETURN
      End Function KValue
!=======================================================================

!=======================================================================
!  K_Demand
!     CALCULATE DEMANDS in kg/ha
!     and reduction in demands due to mobilized tissue.
!     K-SPECIFIC: Also calculates luxury demand (above optimum)
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_Demand for potassium.
!-----------------------------------------------------------------------
!  Called by: K_PLANT
!=======================================================================
      Subroutine K_Demand(DYNAMIC,
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

      USE ModuleDefs
      IMPLICIT NONE
      SAVE

      Integer DYNAMIC

      Real Shut_kg, Root_kg, Shel_kg, Seed_kg
      Real KShut_kg, KRoot_kg, KShel_kg, KSeed_kg
      Real ShutMob, RootMob, ShelMob
      REAL KConc_Shut_opt, KConc_Root_opt, KConc_Shel_opt,KConc_Seed_opt
      REAL KConc_Shut_min, KConc_Root_min, KConc_Shel_min
      REAL KConc_Shut_lux, KConc_Root_lux  !Luxury concentrations
      Real DeltKShut, DeltKRoot, DeltKShel, DeltKSeed
      Real KShutDem, KRootDem, KShelDem, KSeedDem, KTotDem
      Real KLuxuryDem  !Demand for luxury K storage
      Real KShutMobPool, KRootMobPool, KShelMobPool
      Real ShutKOpt, RootKOpt, ShelKOpt, SeedKOpt
      Real ShutKMin, RootKMin, ShelKMin
      Real ShutKLux, RootKLux  !Luxury K amounts
      REAL KConc_Shut, KConc_Root, KConc_Shel
      Real KShutMobToday, KRootMobToday, KShelMobToday

!***********************************************************************
!***********************************************************************
!     SEASONAL INITIALIZATION: RUN ONCE PER SEASON.
!***********************************************************************
      IF (DYNAMIC == SEASINIT .OR. DYNAMIC .EQ. RUNINIT) THEN
!     ------------------------------------------------------------------
      KShutMobPool = 0.0
      KRootMobPool = 0.0
      KShelMobPool = 0.0
      KLuxuryDem = 0.0

!***********************************************************************
!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSEIF (DYNAMIC == INTEGR) THEN
!-----------------------------------------------------------------------
!*** Need to take a mass balance approach.
!     Each day, compute max, opt, and min K allowable (in kg/ha).
!     Use these to check K mobilization amounts.
      ShutKMin = Shut_kg * KConc_Shut_min
      RootKMin = Root_kg * KConc_Root_min
      ShelKMin = Shel_kg * KConc_Shel_min

      ShutKOpt = Shut_kg * KConc_Shut_opt
      RootKOpt = Root_kg * KConc_Root_opt
      ShelKOpt = Shel_kg * KConc_Shel_opt
      SeedKOpt = Seed_kg * KConc_Seed_opt

!     Luxury K amounts (K-specific)
      ShutKLux = Shut_kg * KConc_Shut_lux
      RootKLux = Root_kg * KConc_Root_lux

!     ------------------------------------------------------------------
!     Compute K demand to reach OPTIMUM.
!     If demand is negative (due to high K content), K becomes available
!     for mobilization.

      !Shoots - demand to reach optimum
      KShutDem = ShutKOpt - KShut_kg
      IF (KShutDem < 0.0) THEN
        KShutMobPool = KShutMobPool - KShutDem    !(neg. val.)
        KShutDem = 0.0
      ENDIF

      !Roots - demand to reach optimum
      KRootDem = RootKOpt - KRoot_kg
      IF (KRootDem < 0.0) THEN
        KRootMobPool = KRootMobPool - KRootDem    !(neg. val.)
        KRootDem = 0.0
      ENDIF

      !Shell
      KShelDem = ShelKOpt - KShel_kg
      IF (KShelDem < 0.0) THEN
        KShelMobPool = KShelMobPool - KShelDem    !(neg. val.)
        KShelDem = 0.0
      ENDIF

      !Seed - no mobilization pool for seeds
      KSeedDem = SeedKOpt - KSeed_kg
      KSeedDem = MAX(0.0, KSeedDem)

!     ------------------------------------------------------------------
!     K-SPECIFIC: Calculate LUXURY demand (uptake above optimum)
!     K can be stored in vegetative tissue above optimum concentration
      KLuxuryDem = 0.0
      IF (KShutDem < 1.E-6 .AND. ShutKLux > ShutKOpt) THEN
        !Already at optimum, can store more as luxury
        KLuxuryDem = KLuxuryDem + (ShutKLux - KShut_kg)
      ENDIF
      IF (KRootDem < 1.E-6 .AND. RootKLux > RootKOpt) THEN
        KLuxuryDem = KLuxuryDem + (RootKLux - KRoot_kg)
      ENDIF
      KLuxuryDem = MAX(0.0, KLuxuryDem)

!     ------------------------------------------------------------------
!     Mobilized K - reduce demand by amount which is mobilized.
!     K is highly mobile - higher mobilization rates than P
!     ------------------------------------------------------------------
      !Shoots
      KShutMobPool = AMAX1(0.0, ShutMob * KConc_Shut) + KShutMobPool
!     Amount which can be mobilized should not reduce K below minimum
      KShutMobToday = AMIN1(KShutMobPool, KShut_kg - ShutKMin)
      KShutMobToday = MAX(0.0, KShutMobToday)
      IF (KShutDem >= KShutMobToday) THEN
        KShutMobPool = KShutMobPool - KShutMobToday
        KShutDem = KShutDem - KShutMobToday
        KShutMobToday = 0.0
      ELSE
        KShutMobPool = KShutMobPool - KShutDem
        KShutMobToday = KShutMobToday - KShutDem
        KShutDem = 0.0
      ENDIF

      !Roots
      KRootMobPool = AMAX1(0.0, RootMob * KConc_Root) + KRootMobPool
      KRootMobToday = AMIN1(KRootMobPool, KRoot_kg - RootKMin)
      KRootMobToday = MAX(0.0, KRootMobToday)
      IF (KRootDem >= KRootMobToday) THEN
        KRootMobPool = KRootMobPool - KRootMobToday
        KRootDem = KRootDem - KRootMobToday
        KRootMobToday = 0.0
      ELSE
        KRootMobPool = KRootMobPool - KRootDem
        KRootMobToday = KRootMobToday - KRootDem
        KRootDem = 0.0
      ENDIF

      !Shell
      KShelMobPool = AMAX1(0.0, ShelMob * KConc_Shel) + KShelMobPool
      KShelMobToday = AMIN1(KShelMobPool, KShel_kg - ShelKMin)
      KShelMobToday = MAX(0.0, KShelMobToday)
      IF (KShelDem >= KShelMobToday) THEN
        KShelMobPool = KShelMobPool - KShelMobToday
        KShelDem = KShelDem - KShelMobToday
        KShelMobToday = 0.0
      ELSE
        KShelMobPool = KShelMobPool - KShelDem
        KShelMobToday = KShelMobToday - KShelDem
        KShelDem = 0.0
      ENDIF

!     ------------------------------------------------------------------
!     K-SPECIFIC MOBILIZATION PRIORITY:
!     For K, mobilization goes FROM reproductive TO vegetative if needed
!     (opposite of P where seeds have priority)
!     Shells -> Shoots (K moves back to vegetative tissue)
      IF (KShelMobToday > 1.E-5 .AND. KShutDem > 1.E-5) THEN
        IF (KShutDem >= KShelMobToday) THEN
          DeltKShut = DeltKShut + KShelMobToday
          DeltKShel = DeltKShel - KShelMobToday
          KShutDem = KShutDem - KShelMobToday
          KShelMobToday = 0.0
        ELSE
          DeltKShut = DeltKShut + KShutDem
          DeltKShel = DeltKShel - KShutDem
          KShelMobToday = KShelMobToday - KShutDem
          KShutDem = 0.0
        ENDIF
      ENDIF

!     Shells -> Roots
      IF (KShelMobToday > 1.E-5 .AND. KRootDem > 1.E-5) THEN
        IF (KRootDem >= KShelMobToday) THEN
          DeltKRoot = DeltKRoot + KShelMobToday
          DeltKShel = DeltKShel - KShelMobToday
          KRootDem = KRootDem - KShelMobToday
          KShelMobToday = 0.0
        ELSE
          DeltKRoot = DeltKRoot + KRootDem
          DeltKShel = DeltKShel - KRootDem
          KShelMobToday = KShelMobToday - KRootDem
          KRootDem = 0.0
        ENDIF
      ENDIF

!     Shoots -> Seeds (only after vegetative demand is met)
      IF (KShutMobToday > 1.E-5 .AND. KSeedDem > 1.E-5) THEN
        IF (KSeedDem >= KShutMobToday) THEN
          DeltKSeed = DeltKSeed + KShutMobToday
          DeltKShut = DeltKShut - KShutMobToday
          KSeedDem = KSeedDem - KShutMobToday
          KShutMobToday = 0.0
        ELSE
          DeltKSeed = DeltKSeed + KSeedDem
          DeltKShut = DeltKShut - KSeedDem
          KShutMobToday = KShutMobToday - KSeedDem
          KSeedDem = 0.0
        ENDIF
      ENDIF

!     Shoots -> Shells
      IF (KShutMobToday > 1.E-5 .AND. KShelDem > 1.E-5) THEN
        IF (KShelDem >= KShutMobToday) THEN
          DeltKShel = DeltKShel + KShutMobToday
          DeltKShut = DeltKShut - KShutMobToday
          KShelDem = KShelDem - KShutMobToday
          KShutMobToday = 0.0
        ELSE
          DeltKShel = DeltKShel + KShelDem
          DeltKShut = DeltKShut - KShelDem
          KShutMobToday = KShutMobToday - KShelDem
          KShelDem = 0.0
        ENDIF
      ENDIF

!     Roots -> Seeds
      IF (KRootMobToday > 1.E-5 .AND. KSeedDem > 1.E-5) THEN
        IF (KSeedDem >= KRootMobToday) THEN
          DeltKSeed = DeltKSeed + KRootMobToday
          DeltKRoot = DeltKRoot - KRootMobToday
          KSeedDem = KSeedDem - KRootMobToday
          KRootMobToday = 0.0
        ELSE
          DeltKSeed = DeltKSeed + KSeedDem
          DeltKRoot = DeltKRoot - KSeedDem
          KRootMobToday = KRootMobToday - KSeedDem
          KSeedDem = 0.0
        ENDIF
      ENDIF

!     Roots -> Shells
      IF (KRootMobToday > 1.E-5 .AND. KShelDem > 1.E-5) THEN
        IF (KShelDem >= KRootMobToday) THEN
          DeltKShel = DeltKShel + KRootMobToday
          DeltKRoot = DeltKRoot - KRootMobToday
          KShelDem = KShelDem - KRootMobToday
          KRootMobToday = 0.0
        ELSE
          DeltKShel = DeltKShel + KShelDem
          DeltKRoot = DeltKRoot - KShelDem
          KRootMobToday = KRootMobToday - KShelDem
          KShelDem = 0.0
        ENDIF
      ENDIF

!     If leftover mobilizable tissue remains, add back to pool
      KShutMobPool = KShutMobPool + KShutMobToday
      KRootMobPool = KRootMobPool + KRootMobToday
      KShelMobPool = KShelMobPool + KShelMobToday

!     Recalculate demand (does not include luxury demand)
      KTotDem = KShutDem + KRootDem + KShelDem + KSeedDem

!***********************************************************************
!***********************************************************************
!     END OF DYNAMIC IF CONSTRUCT
!***********************************************************************
      ENDIF
!-----------------------------------------------------------------------
      Return
      End Subroutine K_Demand

C=======================================================================


!=======================================================================
!  K_Partition
!     Partition K which has been mobilized and taken up from soil
!     to shoot, root, shell and seed.
!
!     K-SPECIFIC: Different priority than P
!     Priority order: Shoots > Roots > Shells > Seeds
!     (K stays preferentially in vegetative tissue)
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_Partition for potassium.
!-----------------------------------------------------------------------
!  Called by: K_PLANT
!=======================================================================
      Subroutine K_Partition(
     &    FracKMobil, KConc_Root_min, KConc_Shel_min,     !Input
     &    KConc_Shut_min, KRootDem, KRoot_kg, KSeedDem,   !Input
     &    KShelDem, KShel_kg, KShutDem, KShut_kg,         !Input
     &    KLuxuryDem, KUptakeProf, Root_kg, Shel_kg,      !Input
     &    Shut_kg,                                        !Input
     &    DeltKRoot, DeltKSeed, DeltKShel, DeltKShut)     !I/O

!-----------------------------------------------------------------------
      USE ModuleDefs
      IMPLICIT NONE
      SAVE

      REAL ADD, KConc_Shut_min, KConc_Root_min, KConc_Shel_min
      REAL Shut_kg, Root_kg, Shel_kg
      REAL KMine_Avail, FracKMobil, KMined
      REAL ShutMineFrac, RootMineFrac, ShelMineFrac
      REAL KUptakeProf, KSupply
      REAL KShutDem, KRootDem, KShelDem, KSeedDem
      REAL KLuxuryDem  !Demand for luxury storage
      REAL DeltKShut, DeltKRoot, DeltKShel, DeltKSeed
      REAL ShutKMin, KRootMin, KShelMin
      REAL KShut_kg, KRoot_kg, KShel_kg
      REAL K_Mobil_max

!-----------------------------------------------------------------------
!     Calculate minimum vegetative K (kg/ha)
      ShutKMin = KConc_Shut_min * Shut_kg
      KRootMin = KConc_Root_min * Root_kg
      KShelMin = KConc_Shel_min * Shel_kg

!     K available for mining (kg/ha)
!     K is highly mobile - can mobilize more than P
      KMine_Avail = KShut_kg  + KRoot_kg  + KShel_kg      !Actual K
     &            - ShutKMin - KRootMin - KShelMin     !Minimum K

!     Maximum that can be mobilized in one day
!     FracKMobil is typically higher than FracPMobil (0.20 vs 0.10)
      K_Mobil_max = MAX(0.0, FracKMobil * KMine_Avail)

!     Fraction of mined K that will come from roots, shoots, and shells
      IF (KMine_Avail > 0.0) THEN
        ShutMineFrac = (KShut_kg - ShutKMin) / KMine_Avail
        RootMineFrac = (KRoot_kg - KRootMin) / KMine_Avail
        ShelMineFrac = 1.0 - ShutMineFrac - RootMineFrac
        ShelMineFrac = MAX(0.0, ShelMineFrac)
      ELSE
        ShutMineFrac = 0.0
        RootMineFrac = 0.0
        ShelMineFrac = 0.0
      ENDIF

      KMined = 0.0

!------------------------------------------------------------------------
!     K-SPECIFIC PARTITIONING
!     Priority: Shoots > Roots > Shells > Seeds
!     (Opposite of P where seeds have highest priority)
!     K stays preferentially in vegetative tissue
!------------------------------------------------------------------------
      KSupply = KUptakeProf   !K to be partitioned

!     FIRST meet demand for SHOOTS (highest priority for K)
      IF (KShutDem > 0. .AND. KShutDem <= KSupply) THEN
        !Supply for shoots met with some left over
        DeltKShut = DeltKShut + KShutDem
        KSupply = KSupply - KShutDem
      ELSEIF (KShutDem > 0. .AND. KShutDem > KSupply) THEN
        !All supply goes to shoots, still not enough
        DeltKShut = DeltKShut + KSupply
        KSupply = 0.0
      ENDIF

!     SECOND meet demand for ROOTS
      IF (KRootDem > 0. .AND. KSupply > 0.) THEN
        ADD = AMIN1(KRootDem, KSupply)
        DeltKRoot = DeltKRoot + ADD
        KSupply = KSupply - ADD
      ENDIF

!     THIRD meet demand for SHELLS
      IF (KShelDem > 0. .AND. KSupply > 0.) THEN
        ADD = AMIN1(KShelDem, KSupply)
        DeltKShel = DeltKShel + ADD
        KSupply = KSupply - ADD
      ENDIF

!     FOURTH meet demand for SEEDS (lowest priority for K)
      IF (KSeedDem > 0. .AND. KSupply > 0.) THEN
        ADD = AMIN1(KSeedDem, KSupply)
        DeltKSeed = DeltKSeed + ADD
        KSupply = KSupply - ADD
      ELSEIF (KSeedDem > 0. .AND. KSupply <= 0.) THEN
        !K mining from vegetative tissue to meet K demand for seeds
        !Only if there's significant seed demand and no supply left
        KMined = MIN(KSeedDem, K_Mobil_max)
        DeltKSeed = DeltKSeed + KMined
        !Distribute mining proportionally
        DeltKShut = DeltKShut - KMined * ShutMineFrac
        DeltKRoot = DeltKRoot - KMined * RootMineFrac
        DeltKShel = DeltKShel - KMined * ShelMineFrac
      ENDIF

!     FIFTH: If supply remains, store as LUXURY K in vegetative tissue
      IF (KSupply > 0. .AND. KLuxuryDem > 0.) THEN
        !Distribute excess K to vegetative tissue (luxury storage)
        IF (Shut_kg + Root_kg > 0.) THEN
          ADD = AMIN1(KSupply, KLuxuryDem)
          DeltKShut = DeltKShut + ADD * Shut_kg / (Shut_kg + Root_kg)
          DeltKRoot = DeltKRoot + ADD * Root_kg / (Shut_kg + Root_kg)
          KSupply = KSupply - ADD
        ENDIF
      ENDIF

!-----------------------------------------------------------------------
      Return
      End Subroutine K_Partition

C=======================================================================
