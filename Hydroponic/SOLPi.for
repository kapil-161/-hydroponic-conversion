C=======================================================================
C  SOLPi - Hydroponic P uptake: Michaelis-Menten with Cmin
C-----------------------------------------------------------------------
C  Called from: NUPTAK
C=======================================================================

      SUBROUTINE SOLPi(
     &    CONTROL, ISWITCH,
     &    FILECC, PLTPOP, RTDEP, PDEMAND, TRLV,
     &    UPO4,
     &    P_SOL)

      USE ModuleDefs
      USE ModuleData
      IMPLICIT NONE
      EXTERNAL GETLUN, ERROR, FIND, IGNORE
      SAVE

      CHARACTER*92 FILECC
      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

      REAL PLTPOP, RTDEP, PDEMAND, TRLV
      REAL UPO4
      REAL P_SOL

      REAL JMAX_P, KM_P
      REAL UPO4_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_P
C      REAL AUTO_CONC_R  ! removed - depletion now always happens
      REAL PH_AVAIL_P, O2_STRESS, PH_KM_FACTOR_P
      REAL ECSTRESS_JMAX_P, JMAX_EFF_P, KM_EFF_P
      REAL CMIN_P, C_P_EFF

      INTEGER LUNCRP, ERR, LINC, FOUND
      CHARACTER*6 SECTION
      INTEGER DYNAMIC

      SAVE JMAX_P, KM_P

      PARAMETER (CMIN_P = 0.0002 * 30.9738)

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('SOLPi',42,FILECC,0)

        SECTION = '!*SOLP'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (FOUND .EQ. 0) CALL ERROR('SOLPi',42,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) JMAX_P, KM_P
        IF (ERR .NE. 0) CALL ERROR('SOLPi',ERR,FILECC,0)

        CLOSE (LUNCRP)
        UPO4 = 0.0

        WRITE(*,100) JMAX_P, KM_P
 100    FORMAT(/,' Hydroponic P Module (M-M with Cmin)',
     &         /,'   Jmax_P: ',F6.4,' mg/cm/d  Km_P: ',F5.2,
     &            ' mg/L',/)

      CASE (SEASINIT)
        CALL GET('HYDRO','P_CONC',P_SOL)
        UPO4 = 0.0

      CASE (RATE)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
        CALL GET('HYDRO','PH_KM_FACTOR_P',PH_KM_FACTOR_P)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
        IF (PH_AVAIL_P .LT. 0.01) PH_AVAIL_P = 1.0
        IF (PH_KM_FACTOR_P .LT. 0.01) PH_KM_FACTOR_P = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_P .LT. 0.01) ECSTRESS_JMAX_P = 1.0

C       Apply EC stress: non-competitive inhibition (reduces Jmax)
        JMAX_EFF_P = JMAX_P * ECSTRESS_JMAX_P
        KM_EFF_P   = KM_P   * PH_KM_FACTOR_P

C       Silberbush et al. (2005): P uptake follows Michaelis-Menten
C       kinetics above a minimum concentration Cmin.
        C_P_EFF = MAX(0.0, P_SOL - CMIN_P)
        UPO4_ACT = JMAX_EFF_P * C_P_EFF / (KM_EFF_P + C_P_EFF)
     &           * TRLV * 100.0 * PH_AVAIL_P * O2_STRESS

        UPO4 = UPO4_ACT

C       Cap at 1.0x demand
        IF (UPO4 .GT. PDEMAND * 1.0) THEN
          UPO4 = PDEMAND * 1.0
        ENDIF

        UPO4 = MAX(0.0, UPO4)

        CALL PUT('HYDRO','UPO4',UPO4)

      CASE (INTEGR)
C       Recompute kinetic uptake using today's post-concentration solution
C       state after HYDRO_WATER has updated reservoir volume.
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
        CALL GET('HYDRO','PH_KM_FACTOR_P',PH_KM_FACTOR_P)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        IF (PH_AVAIL_P .LT. 0.01) PH_AVAIL_P = 1.0
        IF (PH_KM_FACTOR_P .LT. 0.01) PH_KM_FACTOR_P = 1.0
        IF (O2_STRESS  .LT. 0.01) O2_STRESS  = 1.0

        CALL GET('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
        IF (ECSTRESS_JMAX_P .LT. 0.01) ECSTRESS_JMAX_P = 1.0
        JMAX_EFF_P = JMAX_P * ECSTRESS_JMAX_P
        KM_EFF_P   = KM_P   * PH_KM_FACTOR_P

        C_P_EFF = MAX(0.0, P_SOL - CMIN_P)
        UPO4 = JMAX_EFF_P * C_P_EFF / (KM_EFF_P + C_P_EFF)
     &       * TRLV * 100.0 * PH_AVAIL_P * O2_STRESS

C       Re-apply demand cap (PDEMAND is current-day value from NUPTAK)
        IF (UPO4 .GT. PDEMAND * 1.0) THEN
          UPO4 = PDEMAND * 1.0
        ENDIF
        UPO4 = MAX(0.0, UPO4)

C       Update stored uptake with today's kinetic-limited value
        CALL PUT('HYDRO','UPO4',UPO4)

        IF (SOLVOL .GT. 0.0) THEN
          VOL_PER_HA = MAX(10.0, SOLVOL * 10000.0)
          DEPL_P = (UPO4 * 1.0E6) / VOL_PER_HA
          P_SOL = MAX(0.0, P_SOL - DEPL_P)
        ENDIF
        CALL PUT('HYDRO','P_CONC',P_SOL)

      CASE (OUTPUT)
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE SOLPi
