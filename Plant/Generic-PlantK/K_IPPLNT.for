!=======================================================================
!    Subroutine K_IPPLNT
!    Reads species file for plant potassium data.
!
!    K-SPECIFIC FEATURES:
!    - Reads *POTAS section (not *PHOSP)
!    - K concentrations are ~10x higher than P (1-5% vs 0.1-0.5%)
!    - Includes luxury K concentration parameters
!    - Includes P:K ratio parameters (in addition to N:K)
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  01/30/2026 Written based on P_IPPLNT for potassium.
!-----------------------------------------------------------------------

      SUBROUTINE K_IPPLNT (FILECC,
     & N2Kmax, N2Kmin, P2Kmax, P2Kmin,
     & KCShutMin, KCLeafMin, KCStemMin, KCRootMin, KCShelMin, KCSeedMin,
     & KCShutOpt, KCLeafOpt, KCStemOpt, KCRootOpt, KCShelOpt, KCSeedOpt,
     & KCShutLux, KCRootLux,
     & FracKMobil, FracKUptake, SRATPHOTO_K, SRATSTOM,
     & KMAX_LUXURY, UseShoots)

!     ------------------------------------------------------------------
      USE ModuleDefs     !Definitions of constructed variable types,
                         !which contain control information, soil
                         !parameters, hourly weather data.
      IMPLICIT  NONE
      EXTERNAL GETLUN, FIND, WARNING, ERROR, IGNORE
      SAVE
!     ------------------------------------------------------------------

      CHARACTER*6 SECTION
      CHARACTER*6, PARAMETER :: ERRKEY = 'KPLANT'
      CHARACTER*78 MSG(10)
      CHARACTER*92 FILECC, TEXT

      INTEGER ERR, FOUND, ISECT, I, LNUM
      INTEGER LUNCRP

      REAL FracKMobil, FracKUptake
      REAL SRATPHOTO_K, SRATSTOM
      REAL KMAX_LUXURY  !Maximum luxury factor

      REAL, DIMENSION(3) :: KCShutOpt, KCRootOpt, KCShelOpt, KCSeedOpt
      REAL, DIMENSION(3) :: KCLeafOpt, KCStemOpt
      REAL, DIMENSION(3) :: KCShutMin, KCRootMin, KCShelMin, KCSeedMin
      REAL, DIMENSION(3) :: KCLeafMin, KCStemMin
      REAL, DIMENSION(3) :: KCShutLux, KCRootLux  !Luxury concentrations
      REAL, DIMENSION(3) :: N2Kmin, N2Kmax
      REAL, DIMENSION(3) :: P2Kmin, P2Kmax

      LOGICAL UseShoots

!     ----------------------------------------------------------------
!     Check validity of data
      I = 0
      UseShoots = .TRUE.

!     Initialize luxury arrays with defaults
      KCShutLux = -99.0
      KCRootLux = -99.0
      KMAX_LUXURY = 1.4  !Default: 40% above optimum

!     Read Species file for K parameters
      CALL GETLUN('FILEC', LUNCRP)
      OPEN (LUNCRP,FILE = FILECC, STATUS = 'OLD',IOSTAT=ERR)
      IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,0)

!     ------------------------------------------------------------------
!     Find and Read Potassium Section
      SECTION = '*POTAS'
      CALL FIND(LUNCRP, SECTION, LNUM, FOUND)
      IF (FOUND .EQ. 0) THEN
        MSG(1) = 'Potassium input section not found in species file.'
        MSG(2) = FILECC
        MSG(3) =
     &   'Can not simulate potassium for this crop. Program will stop.'
        CALL WARNING(3,ERRKEY,MSG)
        CALL ERROR(SECTION, 42, FILECC, LNUM)
      ELSE
!       Shoot optimum K concentrations
!       Note: K conc. typically 1-5% (vs 0.1-0.5% for P)
!       If leaf and stem concentrations are used, these should be -99.
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCShutOpt(1), KCShutOpt(2), KCShutOpt(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       If shoot data is present, use that.  Otherwise use leaf and stem data.
        IF (KCShutOpt(1) < 0. .OR. KCShutOpt(2) < 0. .OR.
     &      KCShutOpt(3) < 0.) THEN
          UseShoots = .FALSE.
        ENDIF

!       Leaf optimum K concentrations
!       If shoot concentrations are used, these should be -99.
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCLeafOpt(1), KCLeafOpt(2), KCLeafOpt(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       Stem optimum K concentrations
!       If shoot concentrations are used, these should be -99.
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCStemOpt(1), KCStemOpt(2), KCStemOpt(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       If shoot data was missing, must have leaf and stem data
        IF (.NOT. UseShoots) THEN
          IF (KCLeafOpt(1) < 0. .OR. KCLeafOpt(2) < 0. .OR.
     &        KCLeafOpt(3) < 0. .OR. KCStemOpt(1) < 0. .OR.
     &        KCStemOpt(2) < 0. .OR. KCStemOpt(3) < 0.) THEN
            WRITE(MSG(I+1),*)
     &      'Optimum K data missing for Leaf, Stem or Shoot.'
            I = I + 1
          ENDIF
        ENDIF

!       Root optimum K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCRootOpt(1), KCRootOpt(2), KCRootOpt(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

        IF (KCRootOpt(1) < 0. .OR. KCRootOpt(2) < 0. .OR.
     &      KCRootOpt(3) < 0.) THEN
          WRITE(MSG(I+1),*) 'Optimum K data missing for root.'
          I = I + 1
        ENDIF

!       Shell optimum K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCShelOpt(1), KCShelOpt(2), KCShelOpt(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       Seed optimum K concentrations
!       Note: Seeds have lower K than vegetative tissue
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCSeedOpt(1), KCSeedOpt(2), KCSeedOpt(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!     ------------------------------------------------------------------
!       Shoot minimum K concentrations
!       If leaf and stem concentrations are used, these should be -99.
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCShutMin(1), KCShutMin(2), KCShutMin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       If shoot data is present, use that.  Otherwise use leaf and stem data.
        IF (UseShoots .AND. (KCShutMin(1) < 0. .OR.
     &      KCShutMin(2) < 0. .OR. KCShutMin(3) < 0.)) THEN
          WRITE(MSG(I+1),*)
     &      'Minimum K data missing for Shoots.'
          I = I + 1
        ENDIF

!       Leaf minimum K concentrations
!       If shoot concentrations are used, these should be -99.
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCLeafMin(1), KCLeafMin(2), KCLeafMin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       Stem minimum K concentrations
!       If shoot concentrations are used, these should be -99.
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCStemMin(1), KCStemMin(2), KCStemMin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       If shoot data was missing, must have leaf and stem data
        IF ((.NOT. UseShoots) .AND.
     &       (KCLeafMin(1) < 0. .OR. KCLeafMin(2) < 0. .OR.
     &        KCLeafMin(3) < 0. .OR. KCStemMin(1) < 0. .OR.
     &        KCStemMin(2) < 0. .OR. KCStemMin(3) < 0.)) THEN
          WRITE(MSG(I+1),*)
     &      'Minimum K data missing for Leaf or Stem.'
          I = I + 1
        ENDIF

!       Root minimum K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCRootMin(1), KCRootMin(2), KCRootMin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

        IF (KCRootMin(1) < 0. .OR. KCRootMin(2) < 0. .OR.
     &      KCRootMin(3) < 0.) THEN
          WRITE(MSG(I+1),*) 'Minimum K data missing for root.'
          I = I + 1
        ENDIF

!       Shell minimum K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCShelMin(1), KCShelMin(2), KCShelMin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       Seed minimum K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCSeedMin(1), KCSeedMin(2), KCSeedMin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!     ------------------------------------------------------------------
!     K-SPECIFIC: Luxury K concentrations (above optimum)
!       Shoot luxury K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCShutLux(1), KCShutLux(2), KCShutLux(3)
        IF (ERR .NE. 0) THEN
!         If not present, calculate from optimum * KMAX_LUXURY
          KCShutLux(1) = KCShutOpt(1) * 1.4
          KCShutLux(2) = KCShutOpt(2) * 1.4
          KCShutLux(3) = KCShutOpt(3) * 1.4
        ENDIF

!       Root luxury K concentrations
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    KCRootLux(1), KCRootLux(2), KCRootLux(3)
        IF (ERR .NE. 0) THEN
!         If not present, calculate from optimum * KMAX_LUXURY
          KCRootLux(1) = KCRootOpt(1) * 1.4
          KCRootLux(2) = KCRootOpt(2) * 1.4
          KCRootLux(3) = KCRootOpt(3) * 1.4
        ENDIF

!     ------------------------------------------------------------------
!       Maximum N:K ratios for vegetative tissue
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    N2Kmax(1), N2Kmax(2), N2Kmax(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!       Minimum N:K ratios for vegetative tissue
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    N2Kmin(1), N2Kmin(2), N2Kmin(3)
        IF (ERR .NE. 0) CALL ERROR(ERRKEY,ERR,FILECC,LNUM)

!     ------------------------------------------------------------------
!     K-SPECIFIC: P:K ratio constraints
!       Maximum P:K ratios for vegetative tissue
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    P2Kmax(1), P2Kmax(2), P2Kmax(3)
        IF (ERR .NE. 0) THEN
!         Default P:K ratios if not specified
          P2Kmax(1) = 0.25
          P2Kmax(2) = 0.30
          P2Kmax(3) = 0.35
        ENDIF

!       Minimum P:K ratios for vegetative tissue
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(3F8.0)',IOSTAT=ERR)
     &    P2Kmin(1), P2Kmin(2), P2Kmin(3)
        IF (ERR .NE. 0) THEN
!         Default P:K ratios if not specified
          P2Kmin(1) = 0.05
          P2Kmin(2) = 0.08
          P2Kmin(3) = 0.10
        ENDIF

!     ----------------------------------------------------------------
!     K stress thresholds
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(2F8.0)',IOSTAT=ERR) SRATPHOTO_K, SRATSTOM
        IF (ERR .NE. 0) THEN
!         Default stress thresholds
          SRATPHOTO_K = 0.60
          SRATSTOM = 0.70
        ENDIF

!     K mobilization fraction (higher than P due to K mobility)
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(F8.0)',IOSTAT=ERR) FracKMobil
        IF (ERR .NE. 0) THEN
          FracKMobil = 0.20  !Default: 20% (vs 10% for P)
        ENDIF

!     K uptake fraction
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(F8.0)',IOSTAT=ERR) FracKUptake
        IF (ERR .NE. 0) THEN
          FracKUptake = 1.00
        ENDIF

!     Maximum luxury factor (K-specific)
        CALL IGNORE(LUNCRP,LNUM,ISECT,TEXT)
        READ(TEXT,'(F8.0)',IOSTAT=ERR) KMAX_LUXURY
        IF (ERR .NE. 0) THEN
          KMAX_LUXURY = 1.40  !Default: can store 40% above optimum
        ENDIF

      ENDIF

      CLOSE (LUNCRP)

!     ----------------------------------------------------------------
      IF (I > 0) THEN
        WRITE(MSG(I+1),'(A,A64)') 'Species file: ', FILECC(1:64)
        I = I + 1
        IF (LEN(FILECC) > 64) THEN
          WRITE(MSG(I+1),'(14X,A28)') FILECC(65:92)
          I = I + 1
        ENDIF
        CALL WARNING(I, ERRKEY, MSG)
        CALL ERROR(ERRKEY,10,FILECC,LNUM)
      ENDIF

      RETURN
      END SUBROUTINE K_IPPLNT

!=======================================================================
