C=======================================================================
C  SOLPi - Hydroponic P uptake: mass flow + active (M-M)
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

      REAL SIGMA_P
      REAL JMAX_P, KM_P
      REAL EP, UPO4_MF, UPO4_ACT
      REAL SOLVOL, VOL_PER_HA, DEPL_P
C      REAL AUTO_CONC_R  ! removed - depletion now always happens
      REAL PH_AVAIL_P, O2_STRESS, PH_KM_FACTOR_P
      REAL ECSTRESS_JMAX_P, JMAX_EFF_P, KM_EFF_P
      REAL PDEMAND_ACT

      INTEGER LUNCRP, ERR, LINC, FOUND
      CHARACTER*6 SECTION
      INTEGER DYNAMIC

      SAVE SIGMA_P, JMAX_P, KM_P

      DYNAMIC = CONTROL % DYNAMIC

      SELECT CASE (DYNAMIC)

      CASE (RUNINIT)
        CALL GETLUN('FILEC', LUNCRP)
        OPEN (LUNCRP, FILE = FILECC, STATUS = 'OLD', IOSTAT=ERR)
        IF (ERR .NE. 0) CALL ERROR('SOLPi',42,FILECC,0)

        SECTION = '!*SOLP'
        CALL FIND(LUNCRP, SECTION, LINC, FOUND)
        IF (FOUND .EQ. 0) CALL ERROR('SOLPi',42,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) SIGMA_P
        IF (ERR .NE. 0) CALL ERROR('SOLPi',ERR,FILECC,0)
        READ(LUNCRP,*,IOSTAT=ERR) JMAX_P, KM_P
        IF (ERR .NE. 0) CALL ERROR('SOLPi',ERR,FILECC,0)

        CLOSE (LUNCRP)
        UPO4 = 0.0

        WRITE(*,100) SIGMA_P, JMAX_P, KM_P
 100    FORMAT(/,' Hydroponic P Module (Mass Flow + Active M-M)',
     &         /,'   Sigma_P: ',F5.2,
     &         /,'   Jmax_P: ',F6.4,' mg/cm/d  Km_P: ',F5.2,
     &            ' mg/L',/)

      CASE (SEASINIT)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL PUT('HYDRO','PTOTDEM', 0.0)
        UPO4 = 0.0

      CASE (RATE)
        CALL GET('HYDRO','EP',EP)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
        CALL GET('HYDRO','PH_KM_FACTOR_P',PH_KM_FACTOR_P)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','ECSTRESS_JMAX_P',ECSTRESS_JMAX_P)
        IF (EP .LT. 0.0) EP = 0.0
        IF (PH_AVAIL_P .LT. 0.01) PH_AVAIL_P = 1.0
        IF (PH_KM_FACTOR_P .LT. 0.01) PH_KM_FACTOR_P = 1.0
        IF (O2_STRESS .LT. 0.01) O2_STRESS = 1.0
        IF (ECSTRESS_JMAX_P .LT. 0.01) ECSTRESS_JMAX_P = 1.0

C       Apply EC stress: non-competitive inhibition (reduces Jmax)
        JMAX_EFF_P = JMAX_P * ECSTRESS_JMAX_P
        KM_EFF_P   = KM_P   * PH_KM_FACTOR_P

C       Mass flow
        UPO4_MF = EP * P_SOL * (1.0-SIGMA_P)
     &          * PH_AVAIL_P * O2_STRESS * 0.01

C       Active uptake (Michaelis-Menten with EC stress)
        UPO4_ACT = JMAX_EFF_P * P_SOL / (KM_EFF_P + P_SOL)
     &           * TRLV * 100.0 * PH_AVAIL_P * O2_STRESS

        UPO4 = UPO4_MF + UPO4_ACT

        CALL GET('HYDRO','PTOTDEM',PDEMAND_ACT)

        IF (PDEMAND_ACT .GT. 1.E-9) THEN
          PDEMAND = MAX(PDEMAND, PDEMAND_ACT)
        ENDIF

C       Cap at 1.0x demand
        IF (UPO4 .GT. PDEMAND * 1.0) THEN
          UPO4 = PDEMAND * 1.0
        ENDIF

        UPO4 = MAX(0.0, UPO4)

        CALL PUT('HYDRO','UPO4',UPO4)

C       Store active-only component so INTEGR can recompute passive with today's EP
        CALL PUT('HYDRO','UPO4_ACT',UPO4_ACT)

      CASE (INTEGR)
C       Recompute passive (mass flow) component using today's EP.
C       HYDRO_WATER INTEGR runs before NUPTAK INTEGR, so GET('HYDRO','EP')
C       returns today's actual EP and P_CONC is already post-concentration.
C       Feed-and-drift replenishment is handled by SOLEC INTEGR.
        CALL GET('HYDRO','EP',EP)
        CALL GET('HYDRO','P_CONC',P_SOL)
        CALL GET('HYDRO','SOLVOL',SOLVOL)
        CALL GET('HYDRO','PH_AVAIL_P',PH_AVAIL_P)
        CALL GET('HYDRO','O2_STRESS',O2_STRESS)
        CALL GET('HYDRO','UPO4_ACT',UPO4_ACT)
        IF (EP .LT. 0.0) EP = 0.0
        IF (PH_AVAIL_P .LT. 0.01) PH_AVAIL_P = 1.0
        IF (O2_STRESS  .LT. 0.01) O2_STRESS  = 1.0

C       Passive flow with today's EP and post-concentration C
        UPO4_MF = EP * P_SOL * (1.0-SIGMA_P)
     &          * PH_AVAIL_P * O2_STRESS * 0.01

        UPO4 = UPO4_MF + UPO4_ACT

C       Re-apply demand cap (PDEMAND is current-day value from NUPTAK)
        IF (UPO4 .GT. PDEMAND * 1.0) THEN
          UPO4 = PDEMAND * 1.0
        ENDIF
        UPO4 = MAX(0.0, UPO4)

C       Update stored uptake with today's passive flow
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
