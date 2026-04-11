C=======================================================================
C  HYDRO_NUTRIENT - Hydroponic N uptake: Michaelis-Menten with Cmin
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
      REAL UN_TOTAL, SCALE
      REAL UNO3_ACT, UNH4_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_NO3, DEPL_NH4
C      REAL AUTO_CONC_R  ! removed - depletion now always happens
      REAL PH_AVAIL_NO3, PH_AVAIL_NH4, O2_STRESS
      REAL PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4
      REAL ECSTRESS_JMAX_NO3, ECSTRESS_JMAX_NH4, ECSTRESS_KM_NO3
      REAL JMAX_EFF_NO3, KM_EFF_NO3, JMAX_EFF_NH4, KM_EFF_NH4
      REAL CMIN_NO3, CMIN_NH4, C_NO3_EFF, C_NH4_EFF
      REAL INDUCT_NO3   ! NO3 J_max induction factor: (1 + 0.21*C_NO3_mol_m3)

      INTEGER LUNCRP, ERR, LINC, FOUND
      CHARACTER*6 SECTION
      INTEGER DYNAMIC

      SAVE JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4

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
        READ(LUNCRP,*,IOSTAT=ERR) JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',ERR,FILECC,0)

        CLOSE (LUNCRP)
        UNO3 = 0.0
        UNH4 = 0.0

        WRITE(*,100) JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4
 100    FORMAT(/,' Hydroponic N Module (M-M with Cmin)',
     &         /,'   Jmax_NO3: ',F6.3,' mg/cm/d  Km_NO3: ',F5.1,
     &            ' mg/L',
     &         /,'   Jmax_NH4: ',F6.3,' mg/cm/d  Km_NH4: ',F5.1,
     &            ' mg/L',/)

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

C       Silberbush et al. (2005): direct uptake for N is Michaelis-
C       Menten with a minimum concentration Cmin; transpiration affects
C       reservoir concentration through HYDRO_WATER, not as direct uptake.
        C_NO3_EFF = MAX(0.0, NO3_SOL - CMIN_NO3)
        C_NH4_EFF = MAX(0.0, NH4_SOL - CMIN_NH4)
        UNO3_ACT = JMAX_EFF_NO3 * C_NO3_EFF / (KM_EFF_NO3 + C_NO3_EFF)
     &           * TRLV * 100.0 * PH_AVAIL_NO3 * O2_STRESS
        UNH4_ACT = JMAX_EFF_NH4 * C_NH4_EFF / (KM_EFF_NH4 + C_NH4_EFF)
     &           * TRLV * 100.0 * PH_AVAIL_NH4 * O2_STRESS

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

        CALL PUT('HYDRO','UNO3',UNO3)
        CALL PUT('HYDRO','UNH4',UNH4)

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
        UNO3 = JMAX_EFF_NO3 * C_NO3_EFF / (KM_EFF_NO3 + C_NO3_EFF)
     &       * TRLV * 100.0 * PH_AVAIL_NO3 * O2_STRESS
        UNH4 = JMAX_EFF_NH4 * C_NH4_EFF / (KM_EFF_NH4 + C_NH4_EFF)
     &       * TRLV * 100.0 * PH_AVAIL_NH4 * O2_STRESS

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

C       Update stored uptake with today's kinetic-limited values
        CALL PUT('HYDRO','UNO3',UNO3)
        CALL PUT('HYDRO','UNH4',UNH4)

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
