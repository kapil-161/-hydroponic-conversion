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
      REAL AUTO_CONC_R
      REAL PH_AVAIL_NO3, PH_AVAIL_NH4, O2_STRESS
      REAL ECSTRESS_JMAX_NO3, ECSTRESS_JMAX_NH4, ECSTRESS_KM_NO3
      REAL JMAX_EFF_NO3, KM_EFF_NO3, JMAX_EFF_NH4

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
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_NO3',ECSTRESS_JMAX_NO3)
        CALL GET('HYDRO','ECSTRESS_JMAX_NH4',ECSTRESS_JMAX_NH4)
        CALL GET('HYDRO','ECSTRESS_KM_NO3',ECSTRESS_KM_NO3)
        IF (EP .LT. 0.0) EP = 0.0
        IF (PH_AVAIL_NO3 .LT. 0.01) PH_AVAIL_NO3 = 1.0
        IF (PH_AVAIL_NH4 .LT. 0.01) PH_AVAIL_NH4 = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_NO3.LT.0.01) ECSTRESS_JMAX_NO3 = 1.0
        IF (ECSTRESS_JMAX_NH4.LT.0.01) ECSTRESS_JMAX_NH4 = 1.0
        IF (ECSTRESS_KM_NO3 .LT. 0.5) ECSTRESS_KM_NO3 = 1.0

C       Apply EC stress: non-competitive (Jmax) and competitive (Km)
        JMAX_EFF_NO3 = JMAX_NO3 * ECSTRESS_JMAX_NO3
        KM_EFF_NO3   = KM_NO3   * ECSTRESS_KM_NO3
        JMAX_EFF_NH4 = JMAX_NH4 * ECSTRESS_JMAX_NH4

C       Mass flow
        UNO3_MF = EP * NO3_SOL * (1.0-SIGMA_NO3)
     &          * PH_AVAIL_NO3 * O2_STRESS * 0.01
        UNH4_MF = EP * NH4_SOL * (1.0-SIGMA_NH4)
     &          * PH_AVAIL_NH4 * O2_STRESS * 0.01

C       Active uptake (Michaelis-Menten with EC stress)
        UNO3_ACT = JMAX_EFF_NO3 * NO3_SOL / (KM_EFF_NO3 + NO3_SOL)
     &           * TRLV * 100.0 * PH_AVAIL_NO3 * O2_STRESS
        UNH4_ACT = JMAX_EFF_NH4 * NH4_SOL / (KM_NH4 + NH4_SOL)
     &           * TRLV * 100.0 * PH_AVAIL_NH4 * O2_STRESS

        UNO3 = UNO3_MF + UNO3_ACT
        UNH4 = UNH4_MF + UNH4_ACT

C       Cap at 1.2x demand
        UN_TOTAL = UNO3 + UNH4
        IF (ANDEM .GT. 1.E-9 .AND. UN_TOTAL .GT. ANDEM * 1.2) THEN
          SCALE = ANDEM * 1.2 / UN_TOTAL
          UNO3 = UNO3 * SCALE
          UNH4 = UNH4 * SCALE
        ENDIF

        UNO3 = MAX(0.0, UNO3)
        UNH4 = MAX(0.0, UNH4)

        WRITE(*,200) EP, TRLV, UNO3_MF+UNH4_MF,
     &               UNO3_ACT+UNH4_ACT, UNO3+UNH4, ANDEM
 200    FORMAT(' HYDRO_N: EP=',F5.2,' TRLV=',F6.2,
     &         ' MF=',F6.3,' Act=',F6.3,
     &         ' Tot=',F6.3,' Dem=',F6.3,' kg/ha/d')

      CASE (INTEGR)
        CALL GET('HYDRO','AUTO_CONC',AUTO_CONC_R)
        IF (AUTO_CONC_R .LT. 0.5) AUTO_CONC_R = 0.0

        CALL GET('HYDRO','NO3_CONC',NO3_SOL)
        CALL GET('HYDRO','NH4_CONC',NH4_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)

        IF (AUTO_CONC_R .LT. 0.5) THEN
          IF (SOLVOL .GT. 0.0) THEN
            VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)
            DEPL_NO3 = (UNO3 * 1.0E6) / VOL_PER_HA
            DEPL_NH4 = (UNH4 * 1.0E6) / VOL_PER_HA
            NO3_SOL = MAX(0.0, NO3_SOL - DEPL_NO3)
            NH4_SOL = MAX(0.0, NH4_SOL - DEPL_NH4)
          ENDIF
          CALL PUT('HYDRO','NO3_CONC',NO3_SOL)
          CALL PUT('HYDRO','NH4_CONC',NH4_SOL)
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_NUTRIENT
