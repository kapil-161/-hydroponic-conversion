C=======================================================================
C  HYDRO_NUTRIENT - Hydroponic N uptake: mass flow + active (M-M)
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

      REAL SIGMA_NO3, SIGMA_NH4
      REAL JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4
      REAL EP, UN_TOTAL, SCALE
      REAL UNO3_MF, UNH4_MF, UNO3_ACT, UNH4_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_NO3, DEPL_NH4
C      REAL AUTO_CONC_R  ! removed - depletion now always happens
      REAL PH_AVAIL_NO3, PH_AVAIL_NH4, O2_STRESS
      REAL PH_KM_FACTOR_NO3, PH_KM_FACTOR_NH4
      REAL ECSTRESS_JMAX_NO3, ECSTRESS_JMAX_NH4, ECSTRESS_KM_NO3
      REAL JMAX_EFF_NO3, KM_EFF_NO3, JMAX_EFF_NH4, KM_EFF_NH4

      INTEGER LUNCRP, ERR, LINC, FOUND
      CHARACTER*6 SECTION
      INTEGER DYNAMIC

      SAVE SIGMA_NO3, SIGMA_NH4
      SAVE JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',42,FILECC,0)

        SECTION = '!*HYDR'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (FOUND .EQ. 0) CALL ERROR('HYDNUT',42,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) SIGMA_NO3, SIGMA_NH4
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',ERR,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4
        IF (ERR .NE. 0) CALL ERROR('HYDNUT',ERR,FILECC,0)

        CLOSE (LUNCRP)
        UNO3 = 0.0
        UNH4 = 0.0

        WRITE(*,100) SIGMA_NO3, SIGMA_NH4,
     &               JMAX_NO3, KM_NO3, JMAX_NH4, KM_NH4
 100    FORMAT(/,' Hydroponic N Module (Mass Flow + Active M-M)',
     &         /,'   Sigma_NO3: ',F5.2,'  Sigma_NH4: ',F5.2,
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
        CALL GET('HYDRO','EP',EP)
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
        IF (EP .LT. 0.0) EP = 0.0
        IF (PH_AVAIL_NO3 .LT. 0.01) PH_AVAIL_NO3 = 1.0
        IF (PH_AVAIL_NH4 .LT. 0.01) PH_AVAIL_NH4 = 1.0
        IF (PH_KM_FACTOR_NO3 .LT. 0.01) PH_KM_FACTOR_NO3 = 1.0
        IF (PH_KM_FACTOR_NH4 .LT. 0.01) PH_KM_FACTOR_NH4 = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_NO3.LT.0.01) ECSTRESS_JMAX_NO3 = 1.0
        IF (ECSTRESS_JMAX_NH4.LT.0.01) ECSTRESS_JMAX_NH4 = 1.0
        IF (ECSTRESS_KM_NO3 .LT. 0.5) ECSTRESS_KM_NO3 = 1.0

C       Apply EC stress: non-competitive (Jmax) and competitive (Km)
        JMAX_EFF_NO3 = JMAX_NO3 * ECSTRESS_JMAX_NO3
        KM_EFF_NO3   = KM_NO3   * ECSTRESS_KM_NO3 * PH_KM_FACTOR_NO3
        JMAX_EFF_NH4 = JMAX_NH4 * ECSTRESS_JMAX_NH4
        KM_EFF_NH4   = KM_NH4   * PH_KM_FACTOR_NH4

C       Mass flow
        UNO3_MF = EP * NO3_SOL * (1.0-SIGMA_NO3)
     &          * PH_AVAIL_NO3 * O2_STRESS * 0.01
        UNH4_MF = EP * NH4_SOL * (1.0-SIGMA_NH4)
     &          * PH_AVAIL_NH4 * O2_STRESS * 0.01

C       Active uptake (Michaelis-Menten with EC stress)
        UNO3_ACT = JMAX_EFF_NO3 * NO3_SOL / (KM_EFF_NO3 + NO3_SOL)
     &           * TRLV * 100.0 * PH_AVAIL_NO3 * O2_STRESS
        UNH4_ACT = JMAX_EFF_NH4 * NH4_SOL / (KM_EFF_NH4 + NH4_SOL)
     &           * TRLV * 100.0 * PH_AVAIL_NH4 * O2_STRESS

        UNO3 = UNO3_MF + UNO3_ACT
        UNH4 = UNH4_MF + UNH4_ACT

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

C       Store active-only components so INTEGR can recompute passive with
C       today's EP (HYDRO_WATER INTEGR stores EP before NUPTAK INTEGR runs)
        CALL PUT('HYDRO','UNO3_ACT',UNO3_ACT)
        CALL PUT('HYDRO','UNH4_ACT',UNH4_ACT)

      CASE (INTEGR)
C       Recompute passive (mass flow) component using today's EP.
C       HYDRO_WATER INTEGR runs before NUPTAK INTEGR (SPAM before PLANT in
C       LAND.for), so GET('HYDRO','EP') now returns today's actual EP and
C       concentrations already include the volume-reduction factor.
C       Feed-and-drift replenishment is handled by SOLEC INTEGR.
        CALL GET('HYDRO','EP',EP)
        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','PH_AVAIL_NO3',PH_AVAIL_NO3)
        CALL GET('HYDRO','PH_AVAIL_NH4',PH_AVAIL_NH4)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','UNO3_ACT',UNO3_ACT)
        CALL GET('HYDRO','UNH4_ACT',UNH4_ACT)
        IF (EP .LT. 0.0) EP = 0.0
        IF (PH_AVAIL_NO3 .LT. 0.01) PH_AVAIL_NO3 = 1.0
        IF (PH_AVAIL_NH4 .LT. 0.01) PH_AVAIL_NH4 = 1.0
        IF (O2_STRESS    .LT. 0.01) O2_STRESS    = 1.0

C       Passive flow with today's EP and post-concentration C
        UNO3_MF = EP * NO3_SOL * (1.0-SIGMA_NO3)
     &          * PH_AVAIL_NO3 * O2_STRESS * 0.01
        UNH4_MF = EP * NH4_SOL * (1.0-SIGMA_NH4)
     &          * PH_AVAIL_NH4 * O2_STRESS * 0.01

        UNO3 = UNO3_MF + UNO3_ACT
        UNH4 = UNH4_MF + UNH4_ACT

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

C       Update stored uptake with today's passive flow
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
