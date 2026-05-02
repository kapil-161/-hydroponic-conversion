C=======================================================================
C  HYDRO_FERT, Subroutine
C
C  Applies scheduled nutrient additions to the hydroponic solution.
C  Reads event data from HydroFertData_mod (populated by IPSOL).
C  Uses FertType_mod to split FAMN into NO3 / NH4 fractions.
C
C  Units: FAMN / FAMP / FAMK are mg/L concentration increase.
C  Urea-N fraction is added to NH4_CONC (rapid hydrolysis assumed).
C
C  Timing: INTEGR phase, before HYDRO_WATER, so added nutrients are
C  subject to the same transpiration concentration step as existing ions.
C-----------------------------------------------------------------------
C  Called from: SPAM
C  Calls  : FertTypeRead (via FertType_mod, only if not yet loaded)
C=======================================================================

      SUBROUTINE HYDRO_FERT(CONTROL, ISWITCH)

      USE ModuleDefs
      USE ModuleData
      USE HydroFertData_mod
      USE FertType_mod

      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

      INTEGER DYNAMIC, YRDOY, I, ERRNUM
      INTEGER FERTYPE

      REAL NO3_CONC, NH4_CONC, P_CONC, K_CONC
      REAL NO3_pct, NH4_pct, UREA_pct
      REAL NO3_ADD, NH4_ADD, P_ADD, K_ADD
      REAL AUTO_CONC_R, SOLVOL, CONV

C-----------------------------------------------------------------------
      DYNAMIC = CONTROL % DYNAMIC
      YRDOY   = CONTROL % YRDOY

      SELECT CASE (DYNAMIC)

      CASE (SEASINIT)
C-----------------------------------------------------------------------
C       Ensure fertilizer type table is loaded (Fert_Place may have
C       already called FertTypeRead; this is a safe no-op if so).
C-----------------------------------------------------------------------
        IF (Number_of_Fertilizers .EQ. 0) THEN
          CALL FertTypeRead(CONTROL)
        ENDIF

        IF (NHFERT .GT. 0) THEN
          WRITE(*,100) NHFERT
 100      FORMAT(' HYDRO_FERT: ',I3,
     &           ' hydroponic fertilizer event(s) scheduled')
        ELSE
          WRITE(*,*) ' HYDRO_FERT: No fertilizer events scheduled'
        ENDIF

      CASE (INTEGR)
C-----------------------------------------------------------------------
C       Fertilizer additions only apply when AUTO_CONC=N (mode 0).
C       Modes O (1) and I (2) let SOLEC manage replenishment automatically.
C-----------------------------------------------------------------------
        CALL GET('HYDRO','AUTO_CONC',AUTO_CONC_R)
        IF (AUTO_CONC_R .GT. 0.5) RETURN

        DO I = 1, NHFERT
          IF (YRDOY .NE. HFER_DAY(I)) CYCLE

C         Get current solution concentrations
          CALL GET('HYDRO','NO3_CONC',NO3_CONC)
          CALL GET('HYDRO','NH4_CONC',NH4_CONC)
          CALL GET('HYDRO','P_CONC',P_CONC)
          CALL GET('HYDRO','K_CONC',K_CONC)

C         Get solution volume for kg/ha → mg/L conversion
C         SOLVOL in mm = L/m²; mg/L = kg/ha * 100 / SOLVOL
          CALL GET('HYDRO','SOLVOL',SOLVOL)
          CONV = 100.0 / MAX(SOLVOL, 0.001)

C         Look up N-form split from fertilizer type code
C         FMCD format: 'FEnn' where nn is the integer index
          READ(HFER_FMCD(I)(3:5),'(I3)',IOSTAT=ERRNUM) FERTYPE
          IF (ERRNUM .NE. 0 .OR. FERTYPE .LT. 1 .OR.
     &        FERTYPE .GT. NFertTypes) THEN
C           Unknown code: default to all NO3
            NO3_pct  = 100.0
            NH4_pct  = 0.0
            UREA_pct = 0.0
          ELSE
            NO3_pct  = FertFile(FERTYPE) % NO3_N_pct
            NH4_pct  = FertFile(FERTYPE) % NH4_N_pct
            UREA_pct = FertFile(FERTYPE) % UREA_N_pct
          ENDIF

C         Convert kg/ha → mg/L and split N into NO3/NH4 fractions
C         Urea treated as NH4 (rapid hydrolysis assumed in solution)
          NO3_ADD = HFER_FAMN(I) * NO3_pct  / 100.0 * CONV
          NH4_ADD = HFER_FAMN(I) * (NH4_pct + UREA_pct) / 100.0 * CONV
          P_ADD   = HFER_FAMP(I) * CONV
          K_ADD   = HFER_FAMK(I) * CONV

          NO3_CONC = NO3_CONC + NO3_ADD
          NH4_CONC = NH4_CONC + NH4_ADD
          P_CONC   = P_CONC   + P_ADD
          K_CONC   = K_CONC   + K_ADD

          CALL PUT('HYDRO','NO3_CONC',NO3_CONC)
          CALL PUT('HYDRO','NH4_CONC',NH4_CONC)
          CALL PUT('HYDRO','P_CONC',P_CONC)
          CALL PUT('HYDRO','K_CONC',K_CONC)

          WRITE(*,200) YRDOY, HFER_FMCD(I),
     &                 NO3_ADD, NH4_ADD, P_ADD, K_ADD,
     &                 NO3_CONC, NH4_CONC, P_CONC, K_CONC
 200      FORMAT(' HYDRO_FERT: Day ',I7,' (',A5,')',
     &           ' Added: NO3=',F6.1,' NH4=',F6.1,
     &           ' P=',F5.1,' K=',F6.1,' mg/L',/,
     &           '   Solution: NO3=',F7.1,' NH4=',F6.1,
     &           ' P=',F6.1,' K=',F7.1,' mg/L')
        ENDDO

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_FERT
