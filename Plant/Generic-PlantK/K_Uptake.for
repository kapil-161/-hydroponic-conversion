!=======================================================================
!  K_Uptake
!  Generic K-uptake routine.
!  Calculates the K uptake and K stress by a crop.
!
!  K-SPECIFIC FEATURES:
!  - Includes luxury K uptake (can exceed optimum demand)
!  - Checks both N:K and P:K ratio constraints
!  - K is readily taken up when available (less limiting than P)
!-----------------------------------------------------------------------
!  Revision History
!  01/30/2026 Written based on P_Uptake for potassium simulation.
!-----------------------------------------------------------------------
!  Called by: K_CGRO, K_CERES, .....
!  Calls:     SOLKi (for hydroponic mode)
!=======================================================================
      SUBROUTINE K_Uptake (DYNAMIC,
     &    N2K_min, P2K_min, PCNVeg, KConc_Veg, PConc_Veg, !Input
     &    KTotDem, KLuxuryDem, RLV, SKi_AVAIL,            !Input
     &    N2K, P2K, KUptake, KUptakeProf)                 !Output

!     ------------------------------------------------------------------
      USE ModuleDefs
      USE ModuleData
      IMPLICIT  NONE
      EXTERNAL WARNING, SOLKi
      SAVE
!     ------------------------------------------------------------------
      CHARACTER*78 MSG(3)
      INTEGER DYNAMIC, L, NLAYR

      REAL KTotDem, KLuxuryDem, K_SUPPLYprof, KUptakeProf
      REAL N2K, N2K_min, P2K, P2K_min
      REAL PCNVeg, KConc_Veg, PConc_Veg
      REAL KUp_reduce
      REAL, DIMENSION(NL) :: DLAYR, DS, DUL, LL, K_SUPPLY, KUptake
      REAL, DIMENSION(NL) :: RLV, SAT, SKi_AVAIL

!     TEMPORARY FOR PRINTOUT
      TYPE (ControlType) CONTROL
      TYPE (SwitchType) ISWITCH
      TYPE (SoilType) SOILPROP
      REAL RLVTOT

!     Hydroponic variables
      CHARACTER*1 ISWHYDRO
      REAL UKi_HYDRO

!***********************************************************************
!***********************************************************************
!     SEASONAL INITIALIZATION: run once per season.
!***********************************************************************
      IF (DYNAMIC .EQ. SEASINIT) THEN
!     ------------------------------------------------------------------
!     Initialize local variables.
      KUptakeProf = 0.0
      KUptake    = 0.0

!***********************************************************************
!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSEIF (DYNAMIC .EQ. INTEGR) THEN
!-----------------------------------------------------------------------
!     K supply.
!     ------------------------------------------------------------------
      KUptake = 0.0
      K_SUPPLYprof = 0.0

!     If there is no demand (including luxury), then return
      IF (KTotDem + KLuxuryDem < 1.E-4) RETURN

!-----------------------------------------------------------------------
!     Check for hydroponic mode
!-----------------------------------------------------------------------
      CALL GET(CONTROL)
      CALL GET(ISWITCH)
      ISWHYDRO = ISWITCH % ISWHYDRO

      IF (ISWHYDRO .EQ. 'Y') THEN
!-----------------------------------------------------------------------
!       HYDROPONIC MODE: K uptake already computed by NUPTAK -> SOLKi.
!       Just read the stored result - do NOT call SOLKi again.
!-----------------------------------------------------------------------
        CALL GET('HYDRO','UK',UKi_HYDRO)
        KUptakeProf = UKi_HYDRO
        KUptake     = 0.0

!       Skip soil-based uptake
        GO TO 500

      ENDIF

!-----------------------------------------------------------------------
!     SOIL MODE: Normal soil-based K uptake
!-----------------------------------------------------------------------
      CALL GET(SOILPROP)
      DS    = SOILPROP % DS
      DUL   = SOILPROP % DUL
      DLAYR = SOILPROP % DLAYR
      NLAYR = SOILPROP % NLAYR
      LL    = SOILPROP % LL
      SAT   = SOILPROP % SAT

!-----------------------------------------------------------------------
!     K uptake -- all of exchangeable K in soil adjacent to roots is
!     available for uptake.
      K_SUPPLY = 0.0
      K_SUPPLYprof = 0.0
      DO L = 1, NLAYR
        IF (RLV(L) > 1.E-6) THEN
          K_SUPPLY(L) = SKi_AVAIL(L)     !kg/ha by layers
          K_SUPPLYprof = K_SUPPLYprof + K_SUPPLY(L)
        ENDIF
      ENDDO

!-----------------------------------------------------------------------
!       K uptake.
!-----------------------------------------------------------------------
!     Actual uptake. kg/ha
!     K-SPECIFIC: Can take up more than optimum demand (luxury uptake)
      KUptakeProf = AMIN1(K_SUPPLYprof, KTotDem + KLuxuryDem)

!     Set uptake from each layer to zero every day.
      KUptake = 0.0

      IF (KUptakeProf > 1.E-5) THEN
        IF (ABS(KUptakeProf - K_SUPPLYprof) < 1.E-5) THEN
          KUptake = K_SUPPLY
        ELSE
          DO L = 1, NLAYR
            KUptake(L) = K_SUPPLY(L) * KUptakeProf / K_SUPPLYprof
          END DO
        ENDIF
      ENDIF

!     Temporary print of uptake
      RLVTOT = 0.0
      DO L = 1, NLAYR
        RLVTOT = RLVTOT + RLV(L) * DLAYR(L)
      ENDDO
      RLVTOT = RLVTOT / DS(NLAYR)

 500  CONTINUE   ! Both soil and hydroponic paths converge here

!-----------------------------------------------------------------------
!     Calculate N:K and P:K ratios (applies to both soil and hydroponic)
      IF (KConc_Veg > 1.E-6) THEN
        N2K = (PCNVeg / 100.0) / KConc_Veg    !N:K ratio
        P2K = PConc_Veg / KConc_Veg           !P:K ratio
      ELSE
        N2K = -99.
        P2K = -99.
      ENDIF

!-----------------------------------------------------------------------
!     Ratio guards: skip in hydroponic mode — SOLKi already caps at demand
      IF (ISWHYDRO .NE. 'Y') THEN

!     Reduce uptake if N:K ratio is below minimum
!     (prevents excessive K uptake when N is limiting)
      IF (N2K > 1.E-6 .AND. N2K < N2K_min) THEN
        KUp_Reduce = N2K / N2K_min
        WRITE(MSG(1),100) N2K, N2K_min
        WRITE(MSG(2),110) KUp_Reduce
  100   FORMAT('N:K ratio of ',F5.2,' is below minimum of ',F5.2,'.')
  110   FORMAT
     &    ('Daily K uptake will be reduced by a factor of ',F5.2,'.')
        CALL WARNING(2, 'KUPTAK', MSG)
        KUptake     = KUp_Reduce * KUptake
        KUptakeProf = KUp_Reduce * KUptakeProf
      ENDIF

!     Reduce uptake if P:K ratio is below minimum
!     (K-specific: maintains P:K balance)
      IF (P2K > 1.E-6 .AND. P2K < P2K_min) THEN
        KUp_Reduce = P2K / P2K_min
        WRITE(MSG(1),200) P2K, P2K_min
        WRITE(MSG(2),210) KUp_Reduce
  200   FORMAT('P:K ratio of ',F5.3,' is below minimum of ',F5.3,'.')
  210   FORMAT
     &    ('Daily K uptake will be reduced by a factor of ',F5.2,'.')
        CALL WARNING(2, 'KUPTAK', MSG)
        KUptake     = KUp_Reduce * KUptake
        KUptakeProf = KUp_Reduce * KUptakeProf
      ENDIF

      ENDIF  ! ISWHYDRO .NE. 'Y'

!***********************************************************************
!***********************************************************************
!     END OF DYNAMIC IF CONSTRUCT
!***********************************************************************
      ENDIF
!-----------------------------------------------------------------------

      RETURN
      END SUBROUTINE K_Uptake

!-----------------------------------------------------------------------
! K_Uptake Variables
!-----------------------------------------------------------------------
! DLAYR(L)     Thickness of soil layer L (cm)
! K_SUPPLY(L)  Potential uptake of K in soil layer, L (kg[K]/ha)
! K_SUPPLYprof Total K in soil profile available for uptake by roots
!               (kg[K]/ha)
! KTotDem      Total daily plant demand for K to reach optimum (kg[K]/ha)
! KLuxuryDem   Additional K demand for luxury storage (kg[K]/ha)
! KUptake(L)   Plant uptake of K in soil layer L (kg[K]/ha/d)
! KUptakeProf  Plant uptake of K over whole soil profile (kg[K]/ha/d)
! N2K          N:K ratio in vegetative tissue
! N2K_min      Minimum allowable N:K ratio
! P2K          P:K ratio in vegetative tissue
! P2K_min      Minimum allowable P:K ratio
! RLV(L)       Root length density for soil layer L (cm[root] / cm3[soil])
! SKi_AVAIL(L) Soil K available for plant uptake in layer L (kg[K]/ha)
!-----------------------------------------------------------------------
