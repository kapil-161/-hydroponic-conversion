C=======================================================================
C  SOLKi - Hydroponic K uptake: Michaelis-Menten with Cmin
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

      REAL JMAX_K, KM_K
      REAL UK_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_K
C      REAL AUTO_CONC_R  ! removed - depletion now always happens
      REAL PH_AVAIL_K, O2_STRESS, PH_KM_FACTOR_K
      REAL ECSTRESS_JMAX_K, JMAX_EFF_K, KM_EFF_K
      REAL CMIN_K, C_K_EFF

      INTEGER LUNCRP, ERR, LINC, FOUND
      CHARACTER*6 SECTION
      INTEGER DYNAMIC

      SAVE JMAX_K, KM_K

      PARAMETER (CMIN_K = 0.002 * 39.0983)

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('SOLKi',42,FILECC,0)

        SECTION = '!*SOLK'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (FOUND .EQ. 0) CALL ERROR('SOLKi',42,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) JMAX_K, KM_K
        IF (ERR .NE. 0) CALL ERROR('SOLKi',ERR,FILECC,0)

        CLOSE (LUNCRP)
        UK = 0.0

        WRITE(*,100) JMAX_K, KM_K
 100    FORMAT(/,' Hydroponic K Module (M-M with Cmin)',
     &         /,'   Jmax_K: ',F6.3,' mg/cm/d  Km_K: ',F5.1,
     &            ' mg/L',/)

      CASE (SEASINIT)
        CALL GET('HYDRO','K_CONC',K_SOL)
        UK = 0.0

      CASE (RATE)
        CALL GET('HYDRO','K_CONC',K_SOL)
        CALL GET('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
        CALL GET('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR_K)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
        IF (PH_AVAIL_K .LT. 0.01) PH_AVAIL_K = 1.0
        IF (PH_KM_FACTOR_K .LT. 0.01) PH_KM_FACTOR_K = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_K .LT. 0.01) ECSTRESS_JMAX_K = 1.0

C       Apply EC stress: non-competitive inhibition (reduces Jmax)
        JMAX_EFF_K = JMAX_K * ECSTRESS_JMAX_K
        KM_EFF_K   = KM_K   * PH_KM_FACTOR_K

C       Silberbush et al. (2005): K uptake follows Michaelis-Menten
C       kinetics above a minimum concentration Cmin.
        C_K_EFF = MAX(0.0, K_SOL - CMIN_K)
        UK_ACT = JMAX_EFF_K * C_K_EFF / (KM_EFF_K + C_K_EFF)
     &         * TRLV * 100.0 * PH_AVAIL_K * O2_STRESS

        UK = UK_ACT

C       Cap at 1.0x demand
        IF (UK .GT. KDEMAND * 1.0) THEN
          UK = KDEMAND * 1.0
        ENDIF

        UK = MAX(0.0, UK)

        CALL PUT('HYDRO','UK',UK)

      CASE (INTEGR)
C       Recompute kinetic uptake using today's post-concentration solution
C       state after HYDRO_WATER has updated reservoir volume.
        CALL GET('HYDRO','K_CONC',K_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','PH_AVAIL_K',PH_AVAIL_K)
        CALL GET('HYDRO','PH_KM_FACTOR_K',PH_KM_FACTOR_K)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        IF (PH_AVAIL_K .LT. 0.01) PH_AVAIL_K = 1.0
        IF (PH_KM_FACTOR_K .LT. 0.01) PH_KM_FACTOR_K = 1.0
        IF (O2_STRESS  .LT. 0.01) O2_STRESS  = 1.0

        CALL GET('HYDRO','ECSTRESS_JMAX_K',ECSTRESS_JMAX_K)
        IF (ECSTRESS_JMAX_K .LT. 0.01) ECSTRESS_JMAX_K = 1.0
        JMAX_EFF_K = JMAX_K * ECSTRESS_JMAX_K
        KM_EFF_K   = KM_K   * PH_KM_FACTOR_K

        C_K_EFF = MAX(0.0, K_SOL - CMIN_K)
        UK = JMAX_EFF_K * C_K_EFF / (KM_EFF_K + C_K_EFF)
     &     * TRLV * 100.0 * PH_AVAIL_K * O2_STRESS

C       Re-apply demand cap (KDEMAND is current-day value from NUPTAK)
        IF (UK .GT. KDEMAND * 1.0) THEN
          UK = KDEMAND * 1.0
        ENDIF
        UK = MAX(0.0, UK)

C       Update stored uptake with today's kinetic-limited value
        CALL PUT('HYDRO','UK',UK)

        IF (SOLVOL .GT. 0.0) THEN
          VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)
          DEPL_K = (UK * 1.0E6) / VOL_PER_HA
          K_SOL = MAX(0.0, K_SOL - DEPL_K)
        ENDIF
        CALL PUT('HYDRO','K_CONC',K_SOL)

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLKi
