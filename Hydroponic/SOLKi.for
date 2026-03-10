C=======================================================================
C  SOLKi - Hydroponic K uptake: mass flow + active (M-M)
C-----------------------------------------------------------------------
C  Called from: NUPTAK
C=======================================================================

      SUBROUTINE SOLKi(
     &    CONTROL, ISWITCH,
     &    FILECC, PLTPOP, RTDEP, KDEMAND, TRLV,
     &    UK,
     &    K_SOL)

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, ERROR, FIND, IGNORE
      SAVE

      CHARACTER*92 FILECC
      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

      REAL PLTPOP, RTDEP, KDEMAND, TRLV
      REAL UK
      REAL K_SOL

      REAL SIGMA_K
      REAL JMAX_K, KM_K
      REAL EP, UK_MF, UK_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_K
      REAL AUTO_CONC_R
      REAL PH_AVAIL_K, O2_STRESS, PH_KM_FACTOR_K
      REAL ECSTRESS_JMAX_K, JMAX_EFF_K, KM_EFF_K
      REAL KDEMAND_ACT

      INTEGER LUNCRP, ERR, LINC, FOUND
      CHARACTER*6 SECTION
      INTEGER DYNAMIC

      SAVE SIGMA_K, JMAX_K, KM_K

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('SOLKi',42,FILECC,0)

        SECTION = '!*SOLK'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (FOUND .EQ. 0) CALL ERROR('SOLKi',42,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) SIGMA_K
        IF (ERR .NE. 0) CALL ERROR('SOLKi',ERR,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) JMAX_K, KM_K
        IF (ERR .NE. 0) CALL ERROR('SOLKi',ERR,FILECC,0)

        CLOSE (LUNCRP)
        UK = 0.0

        WRITE(*,100) SIGMA_K, JMAX_K, KM_K
 100    FORMAT(/,' Hydroponic K Module (Mass Flow + Active M-M)',
     &         /,'   Sigma_K: ',F5.2,
     &         /,'   Jmax_K: ',F6.3,' mg/cm/d  Km_K: ',F5.1,
     &            ' mg/L',/)

      CASE (SEASINIT)
        CALL GET('HYDRO','K_CONC',K_SOL)
        CALL PUT('HYDRO','KTOTDEM', 0.0)
        UK = 0.0

      CASE (RATE)
        CALL GET('HYDRO','EP',EP)
        CALL GET('HYDRO','K_CONC',K_SOL)
        CALL GET('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
        CALL GET('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR_K)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
        IF (EP .LT. 0.0) EP = 0.0
        IF (PH_AVAIL_K .LT. 0.01) PH_AVAIL_K = 1.0
        IF (PH_KM_FACTOR_K .LT. 0.01) PH_KM_FACTOR_K = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_K .LT. 0.01) ECSTRESS_JMAX_K = 1.0

C       Apply EC stress: non-competitive inhibition (reduces Jmax)
        JMAX_EFF_K = JMAX_K * ECSTRESS_JMAX_K
        KM_EFF_K   = KM_K   * PH_KM_FACTOR_K

C       Mass flow
        UK_MF = EP * K_SOL * (1.0-SIGMA_K)
     &        * PH_AVAIL_K * O2_STRESS * 0.01

C       Active uptake (Michaelis-Menten with EC stress)
        UK_ACT = JMAX_EFF_K * K_SOL / (KM_EFF_K + K_SOL)
     &         * TRLV * 100.0 * PH_AVAIL_K * O2_STRESS

        UK = UK_MF + UK_ACT

        CALL GET('HYDRO','KTOTDEM',KDEMAND_ACT)
        IF (KDEMAND_ACT .GT. 1.E-9) THEN
          KDEMAND = MAX(KDEMAND, KDEMAND_ACT)
        ENDIF

C       Cap at 1.0x demand
        IF (UK .GT. KDEMAND * 1.0) THEN
          UK = KDEMAND * 1.0
        ENDIF

        UK = MAX(0.0, UK)

        CALL PUT('HYDRO','UK',UK)

      CASE (INTEGR)
        CALL GET('HYDRO','AUTO_CONC',AUTO_CONC_R)
        IF (AUTO_CONC_R .LT. 0.5) AUTO_CONC_R = 0.0

        CALL GET('HYDRO','K_CONC',K_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)

        IF (AUTO_CONC_R .LT. 0.5) THEN
          IF (SOLVOL .GT. 0.0) THEN
            VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)
            DEPL_K = (UK * 1.0E6) / VOL_PER_HA
            K_SOL = MAX(0.0, K_SOL - DEPL_K)
          ENDIF
          CALL PUT('HYDRO','K_CONC',K_SOL)
        ENDIF

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLKi
