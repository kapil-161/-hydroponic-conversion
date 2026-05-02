C=======================================================================
C  HYDRO_NUTRIENT - Hydroponic N uptake: Haldane kinetics with Cmin
C  plus shared total inorganic N inhibition.
C-----------------------------------------------------------------------
C  Called from: NUPTAK
C=======================================================================

      SUBROUTINE HYDRO_NUTRIENT(
     &    CONTROL, ISWITCH,
     &    FILECC, PLTPOP, RTDEP, ANDEM, TRLV,
     &    UNO3, UNH4,
     &    NO3_SOL, NH4_SOL)

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, ERROR, FIND, IGNORE
      SAVE

      CHARACTER*92 FILECC
      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

      REAL PLTPOP, RTDEP, ANDEM, TRLV
      REAL UNO3, UNH4
      REAL NO3_SOL, NH4_SOL

      REAL JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4
      REAL KI_NO3, KI_NH4, KI_TIN
      REAL NH4_TOX_K, NH4_TOX_N
      REAL UN_TOTAL, SCALE
      REAL UNO3_ACT, UNH4_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_NO3, DEPL_NH4
      REAL PH_AVAIL_NO3, PH_AVAIL_NH4, O2_STRESS
      REAL PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4
      REAL ECSTRESS_JMAX_NO3, ECSTRESS_JMAX_NH4, ECSTRESS_KM_NO3
      REAL JMAX_EFF_NO3, KM_EFF_NO3, JMAX_EFF_NH4, KM_EFF_NH4
      REAL CMIN_NO3, CMIN_NH4, C_NO3_EFF, C_NH4_EFF
      REAL C_TIN_EFF, KM_TIN_EFF, TIN_INHIB
      REAL INDUCT_NO3   ! NO3 J_max induction factor: (1 + 0.21*C_NO3_mol_m3)
      REAL NTOXS        ! NH4 toxicity stress factor (0-1)

      INTEGER LUNCRP, ERR, LINC, FOUND, ISECT
      CHARACTER*6 SECTION
      CHARACTER*80 C80
      INTEGER DYNAMIC

      SAVE JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4, KI_NO3, KI_NH4, KI_TIN
      SAVE NH4_TOX_K, NH4_TOX_N

C     Silberbush et al. (2005) Cmin values converted to mg/L of nutrient.
C     Table units are mol/m3, numerically equal to mmol/L.
      PARAMETER (CMIN_NO3 = 0.002 * 14.0067)
      PARAMETER (CMIN_NH4 = 0.002 * 14.0067)

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',42,FILECC,0)

        SECTION = '!*HYDR'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (FOUND .EQ. 0) CALL ERROR('HYDNUT',42,FILECC,0)
        CALL IGNORE(LUNCRP, LINC, ISECT, C80)
        READ(C80,*,IOSTAT=ERR) JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4,
     &                         KI_NO3, KI_NH4, KI_TIN
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',ERR,FILECC,0)
        CALL IGNORE(LUNCRP, LINC, ISECT, C80)
        READ(C80,*,IOSTAT=ERR) NH4_TOX_K, NH4_TOX_N
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',ERR,FILECC,0)
        IF (KI_NO3    .LE. 1.E-6) KI_NO3    = 1.E6
        IF (KI_NH4    .LE. 1.E-6) KI_NH4    = 1.E6
        IF (KI_TIN    .LE. 1.E-6) KI_TIN    = 1.E6
        IF (NH4_TOX_K .LE. 1.E-6) NH4_TOX_K = 1.E6
        IF (NH4_TOX_N .LE. 1.E-6) NH4_TOX_N = 1.0

        CLOSE (LUNCRP)
        UNO3  = 0.0
        UNH4  = 0.0
        NTOXS = 1.0
        CALL PUT('HYDRO','NTOXS',NTOXS)

        WRITE(*,100) JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4,
     &               KI_NO3, KI_NH4, KI_TIN, NH4_TOX_K, NH4_TOX_N
 100    FORMAT(/,' Hydroponic N Module (Haldane with Cmin + TIN inhibition)',
     &         /,'   Jmax_NO3: ',F6.3,' mg/cm/d  Km_NO3: ',F5.1,
     &            ' mg/L',
     &         /,'   Jmax_NH4: ',F6.3,' mg/cm/d  Km_NH4: ',F5.1,
     &            ' mg/L',
     &         /,'   Ki_NO3  : ',F7.1,' mg/L     Ki_NH4 : ',F7.1,
     &            ' mg/L',
     &         /,'   Ki_TIN  : ',F7.1,' mg/L total inorganic N',
     &         /,'   NH4_TOX_K:',F7.2,' mg/L     NH4_TOX_N:',F5.2,
     &            ' (Hill coeff)',/)

      CASE (SEASINIT)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        UNO3 = 0.0
        UNH4 = 0.0

      CASE (RATE)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','PH_AVAIL_NO3',PH_AVAIL_NO3)
        CALL GET('HYDRO','PH_AVAIL_NH4',PH_AVAIL_NH4)
        CALL GET('HYDRO','PH_KM_FACTOR_NO3',PH_KM_FACTOR_NO3)
        CALL GET('HYDRO','PH_KM_FACTOR_NH4',PH_KM_FACTOR_NH4)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_NO3',ECSTRESS_JMAX_NO3)
        CALL GET('HYDRO','ECSTRESS_JMAX_NH4',ECSTRESS_JMAX_NH4)
        CALL GET('HYDRO','ECSTRESS_KM_NO3',ECSTRESS_KM_NO3)
        IF (PH_AVAIL_NO3 .LT. 0.01) PH_AVAIL_NO3 = 1.0
        IF (PH_AVAIL_NH4 .LT. 0.01) PH_AVAIL_NH4 = 1.0
        IF (PH_KM_FACTOR_NO3 .LT. 0.01) PH_KM_FACTOR_NO3 = 1.0
        IF (PH_KM_FACTOR_NH4 .LT. 0.01) PH_KM_FACTOR_NH4 = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_NO3.LT.0.01) ECSTRESS_JMAX_NO3 = 1.0
        IF (ECSTRESS_JMAX_NH4.LT.0.01) ECSTRESS_JMAX_NH4 = 1.0
        IF (ECSTRESS_KM_NO3 .LT. 0.01) ECSTRESS_KM_NO3 = 1.0

C       NO3 J_max induction by NO3 concentration (Silberbush et al. 2005):
C       Jmax_NO3 = Jmax0 * (1 + 0.21 * C_NO3_mol_m3)
C       C_NO3_mol_m3 = NO3_SOL (mg N/L) / MW_N (14.0067)
        INDUCT_NO3 = 1.0 + 0.21 * (MAX(0.0, NO3_SOL) / 14.0067)

C       Apply EC stress: non-competitive (Jmax) and competitive (Km)
        JMAX_EFF_NO3 = JMAX_NO3 * INDUCT_NO3 * ECSTRESS_JMAX_NO3
        KM_EFF_NO3   = KM_NO3   * ECSTRESS_KM_NO3 * PH_KM_FACTOR_NO3
        JMAX_EFF_NH4 = JMAX_NH4 * ECSTRESS_JMAX_NH4
        KM_EFF_NH4   = KM_NH4   * PH_KM_FACTOR_NH4

C       Direct N uptake follows Haldane kinetics with a minimum
C       concentration Cmin; transpiration affects reservoir concentration
C       through HYDRO_WATER, not as direct uptake.
        C_NO3_EFF = MAX(0.0, NO3_SOL - CMIN_NO3)
        C_NH4_EFF = MAX(0.0, NH4_SOL - CMIN_NH4)
        C_TIN_EFF = C_NO3_EFF + C_NH4_EFF
        KM_TIN_EFF = KM_EFF_NO3 + KM_EFF_NH4
        TIN_INHIB = (KM_TIN_EFF + C_TIN_EFF) /
     &              (KM_TIN_EFF + C_TIN_EFF +
     &               C_TIN_EFF*C_TIN_EFF/KI_TIN)
        UNO3_ACT = JMAX_EFF_NO3 * C_NO3_EFF /
     &           (KM_EFF_NO3 + C_NO3_EFF + C_NO3_EFF*C_NO3_EFF/KI_NO3)
     &           * TRLV * 100.0 * PH_AVAIL_NO3 * O2_STRESS * TIN_INHIB
        UNH4_ACT = JMAX_EFF_NH4 * C_NH4_EFF /
     &           (KM_EFF_NH4 + C_NH4_EFF + C_NH4_EFF*C_NH4_EFF/KI_NH4)
     &           * TRLV * 100.0 * PH_AVAIL_NH4 * O2_STRESS * TIN_INHIB

        UNO3 = UNO3_ACT
        UNH4 = UNH4_ACT

C       Cap at 1.0x demand
        UN_TOTAL = UNO3 + UNH4
        IF (UN_TOTAL .GT. ANDEM * 1.0) THEN
          IF (UN_TOTAL .GT. 1.E-9) THEN
            SCALE = ANDEM * 1.0 / UN_TOTAL
            UNO3 = UNO3 * SCALE
            UNH4 = UNH4 * SCALE
          ELSE
            UNO3 = 0.0
            UNH4 = 0.0
          ENDIF
        ENDIF

        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)

C       NH4 toxicity stress: NTOXS = 1 / (1 + (NH4_SOL/NH4_TOX_K)^NH4_TOX_N)
        NTOXS = 1.0 / (1.0 + (MAX(0.0,NH4_SOL)/NH4_TOX_K)**NH4_TOX_N)
        NTOXS = MAX(0.0, MIN(1.0, NTOXS))

        CALL PUT('HYDRO','UNO3',UNO3)
        CALL PUT('HYDRO','UNH4',UNH4)
        CALL PUT('HYDRO','NTOXS',NTOXS)

      CASE (INTEGR)
C       Recompute kinetic uptake using today's post-concentration solution
C       state after HYDRO_WATER has updated reservoir volume.
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','PH_AVAIL_NO3',PH_AVAIL_NO3)
        CALL GET('HYDRO','PH_AVAIL_NH4',PH_AVAIL_NH4)
        CALL GET('HYDRO','PH_KM_FACTOR_NO3',PH_KM_FACTOR_NO3)
        CALL GET('HYDRO','PH_KM_FACTOR_NH4',PH_KM_FACTOR_NH4)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_NO3',ECSTRESS_JMAX_NO3)
        CALL GET('HYDRO','ECSTRESS_JMAX_NH4',ECSTRESS_JMAX_NH4)
        CALL GET('HYDRO','ECSTRESS_KM_NO3',ECSTRESS_KM_NO3)
        IF (PH_AVAIL_NO3 .LT. 0.01) PH_AVAIL_NO3 = 1.0
        IF (PH_AVAIL_NH4 .LT. 0.01) PH_AVAIL_NH4 = 1.0
        IF (PH_KM_FACTOR_NO3 .LT. 0.01) PH_KM_FACTOR_NO3 = 1.0
        IF (PH_KM_FACTOR_NH4 .LT. 0.01) PH_KM_FACTOR_NH4 = 1.0
        IF (O2_STRESS    .LT. 0.01) O2_STRESS    = 1.0
        IF (ECSTRESS_JMAX_NO3.LT.0.01) ECSTRESS_JMAX_NO3 = 1.0
        IF (ECSTRESS_JMAX_NH4.LT.0.01) ECSTRESS_JMAX_NH4 = 1.0
        IF (ECSTRESS_KM_NO3 .LT. 0.01) ECSTRESS_KM_NO3 = 1.0

        INDUCT_NO3 = 1.0 + 0.21 * (MAX(0.0, NO3_SOL) / 14.0067)
        JMAX_EFF_NO3 = JMAX_NO3 * INDUCT_NO3 * ECSTRESS_JMAX_NO3
        KM_EFF_NO3   = KM_NO3   * ECSTRESS_KM_NO3 * PH_KM_FACTOR_NO3
        JMAX_EFF_NH4 = JMAX_NH4 * ECSTRESS_JMAX_NH4
        KM_EFF_NH4   = KM_NH4   * PH_KM_FACTOR_NH4

        C_NO3_EFF = MAX(0.0, NO3_SOL - CMIN_NO3)
        C_NH4_EFF = MAX(0.0, NH4_SOL - CMIN_NH4)
        C_TIN_EFF = C_NO3_EFF + C_NH4_EFF
        KM_TIN_EFF = KM_EFF_NO3 + KM_EFF_NH4
        TIN_INHIB = (KM_TIN_EFF + C_TIN_EFF) /
     &              (KM_TIN_EFF + C_TIN_EFF +
     &               C_TIN_EFF*C_TIN_EFF/KI_TIN)
        UNO3 = JMAX_EFF_NO3 * C_NO3_EFF /
     &       (KM_EFF_NO3 + C_NO3_EFF + C_NO3_EFF*C_NO3_EFF/KI_NO3)
     &       * TRLV * 100.0 * PH_AVAIL_NO3 * O2_STRESS * TIN_INHIB
        UNH4 = JMAX_EFF_NH4 * C_NH4_EFF /
     &       (KM_EFF_NH4 + C_NH4_EFF + C_NH4_EFF*C_NH4_EFF/KI_NH4)
     &       * TRLV * 100.0 * PH_AVAIL_NH4 * O2_STRESS * TIN_INHIB

C       Re-apply demand cap (ANDEM is the current-day value from NUPTAK)
        UN_TOTAL = UNO3 + UNH4
        IF (UN_TOTAL .GT. ANDEM * 1.0) THEN
          IF (UN_TOTAL .GT. 1.E-9) THEN
            SCALE = ANDEM * 1.0 / UN_TOTAL
            UNO3 = UNO3 * SCALE
            UNH4 = UNH4 * SCALE
          ELSE
            UNO3 = 0.0
            UNH4 = 0.0
          ENDIF
        ENDIF

        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)

C       NH4 toxicity stress: NTOXS = 1 / (1 + (NH4_SOL/NH4_TOX_K)^NH4_TOX_N)
        NTOXS = 1.0 / (1.0 + (MAX(0.0,NH4_SOL)/NH4_TOX_K)**NH4_TOX_N)
        NTOXS = MAX(0.0, MIN(1.0, NTOXS))


C       Update stored uptake with today's kinetic-limited values
        CALL PUT('HYDRO','UNO3',UNO3)
        CALL PUT('HYDRO','UNH4',UNH4)
        CALL PUT('HYDRO','NTOXS',NTOXS)

        IF (SOLVOL .GT. 0.0) THEN
          VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)
          DEPL_NO3 = (UNO3 * 1.0E6) / VOL_PER_HA
          DEPL_NH4 = (UNH4 * 1.0E6) / VOL_PER_HA
          NO3_SOL = MAX(0.0, NO3_SOL - DEPL_NO3)
          NH4_SOL = MAX(0.0, NH4_SOL - DEPL_NH4)
        ENDIF
        CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
        CALL PUT('HYDRO','NH4_CONC',NH4_SOL)

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_NUTRIENT
