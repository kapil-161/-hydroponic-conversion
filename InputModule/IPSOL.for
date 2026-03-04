C=======================================================================
C  IPSOL, Subroutine
C
C  Reads hydroponic solution parameters from FILEX
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created to read *HYDROPONIC SOLUTION section
C-----------------------------------------------------------------------
C  Called from: IPEXP
C
C  Calls: ERROR, FIND, IGNORE
C-----------------------------------------------------------------------

      SUBROUTINE IPSOL (LUNEXP,FILEX,LNSOL,LNCTL,
     &                  SOLVOL,EC,PH,DO2,TEMP,
     &                  NO3_CONC,NH4_CONC,P_CONC,K_CONC,ISWHYDRO,
     &                  AUTO_PH,AUTO_VOL,AUTO_CONC,AUTO_O2,
     &                  CHLEN,CHSPC)

      IMPLICIT NONE
      EXTERNAL ERROR, FIND, FIND2, IGNORE

      CHARACTER*1  ISWHYDRO
      CHARACTER*1  AUTO_PH, AUTO_VOL, AUTO_CONC, AUTO_O2  ! Hydroponic control flags
      CHARACTER*6  ERRKEY,FINDCH,FINDCTL
      CHARACTER*12 FILEX
      CHARACTER*120 CHARTEST

      INTEGER LUNEXP,LNSOL,LNCTL,LN,LINEXP,ISECT,IFIND,ERRNUM
      REAL    SOLVOL,EC,PH,DO2,TEMP
      REAL    NO3_CONC,NH4_CONC,P_CONC,K_CONC
      REAL    CHLEN, CHSPC

      PARAMETER (ERRKEY='IPSOL ')
                 FINDCH='*HYDRO'
                 FINDCTL='*HYDRO'

      LINEXP = 0

C     Initialize values to -99 (missing data indicator)
      SOLVOL = -99.0
      EC = -99.0
      PH = -99.0
      DO2 = -99.0
      TEMP = -99.0
      NO3_CONC = -99.0
      NH4_CONC = -99.0
      P_CONC = -99.0
      K_CONC = -99.0
      CHLEN = -99.0
      CHSPC = -99.0

C     Default: Hydroponic mode is OFF
      ISWHYDRO = 'N'

C     Default: Auto-control flags are OFF (allow natural drift)
C     'N' = allow natural drift based on chemistry
C     'Y' = maintain constant value from experiment file
C     Note: AUTO_EC removed - EC always drifts naturally with nutrient uptake
      AUTO_PH = 'N'
      AUTO_VOL = 'N'
      AUTO_CONC = 'N'  ! Concentration: N=deplete, Y=maintain constant
      AUTO_O2 = 'N'    ! O2: N=dynamic DO2, Y=pin DO2 to initial value

      REWIND(LUNEXP)

C     Find *HYDROPONIC SOLUTION section
      CALL FIND (LUNEXP,FINDCH,LINEXP,IFIND)

      IF (IFIND .EQ. 0) THEN
C       Section not found - this is a soil-based experiment
C       Keep ISWHYDRO = 'N' and return
        RETURN
      ENDIF

C     Section found - read the data line
C     Read the data line
 50   CALL IGNORE (LUNEXP,LINEXP,ISECT,CHARTEST)

      IF (ISECT .EQ. 1) THEN
C        Try reading with CHLEN and CHSPC first
         READ (CHARTEST,*,IOSTAT=ERRNUM) LN,SOLVOL,EC,PH,DO2,TEMP,
     &        NO3_CONC,NH4_CONC,P_CONC,K_CONC,CHLEN,CHSPC

         IF (ERRNUM .NE. 0) THEN
C          CHLEN and CHSPC are required for hydroponic experiments
           CALL ERROR (ERRKEY,ERRNUM,FILEX,LINEXP)
         ENDIF

      ELSE
         CALL ERROR (ERRKEY,2,FILEX,LINEXP)
      ENDIF

      IF (LN .NE. LNSOL) GO TO 50

C     Check if valid hydroponic data (SOLVOL > 0)
C     Note: SOLVOL in experiment file is in mm (solution depth)
C     We'll convert to L for ModuleData storage using growing area
      IF (SOLVOL .GT. 0.0) THEN
C       Valid hydroponic parameters - activate HYDROPONIC mode
        ISWHYDRO = 'Y'
C       Print confirmation message to indicate section was read
C       SOLVOL is in mm from experiment file
        WRITE(*,100) SOLVOL,EC,PH,DO2,TEMP,NO3_CONC,NH4_CONC,P_CONC,
     &               K_CONC,CHLEN,CHSPC
      ELSE
C       SOLVOL <= 0 or -99: This treatment is soil-based
C       Keep ISWHYDRO = 'N' and return silently
        WRITE(*,*) ' Soil-based experiment (no hydroponic section found)'
      ENDIF

C-----------------------------------------------------------------------
C     Read *HYDROPONIC CONTROL section (optional)
C     Format: @  L  AUTO_PH  AUTO_VOL  AUTO_CONC
C             1     Y        Y         N
C     AUTO_CONC: Y = maintain constant nutrient concentration (replenish)
C                N = allow concentration to deplete naturally
C     If section not found, use defaults (all 'N' = allow drift)
C-----------------------------------------------------------------------
      IF (ISWHYDRO .EQ. 'Y') THEN
        REWIND(LUNEXP)
        LINEXP = 0

C       Look for *HYDROPONIC CONTROL section (uses same prefix *HYDRO)
C       Need to find the specific CONTROL section after SOLUTION
        CALL FIND2(LUNEXP,'*HYDROPONIC CONTROL',LINEXP,IFIND)

        IF (IFIND .GT. 0) THEN
C         Section found - read the control flags
 70       CALL IGNORE (LUNEXP,LINEXP,ISECT,CHARTEST)

          IF (ISECT .EQ. 1) THEN
            READ (CHARTEST,*,IOSTAT=ERRNUM) LN,AUTO_PH,AUTO_VOL,
     &            AUTO_CONC,AUTO_O2

            IF (ERRNUM .NE. 0) THEN
C             Error reading - use defaults (AUTO_O2 may be missing in old files)
              AUTO_PH = 'N'
              AUTO_VOL = 'N'
              AUTO_CONC = 'N'
              AUTO_O2 = 'N'
              WRITE(*,*) 'IPSOL: Error reading HYDROPONIC CONTROL,',
     &                   ' using defaults (N)'
            ELSE
C             Validate flags (must be Y or N)
              IF (AUTO_PH .NE. 'Y' .AND. AUTO_PH .NE. 'N') AUTO_PH = 'N'
              IF (AUTO_VOL.NE. 'Y' .AND. AUTO_VOL.NE. 'N') AUTO_VOL= 'N'
              IF (AUTO_CONC.NE.'Y' .AND. AUTO_CONC.NE.'N') AUTO_CONC='N'
              IF (AUTO_O2 .NE. 'Y' .AND. AUTO_O2 .NE. 'N') AUTO_O2 = 'N'
            ENDIF
          ENDIF

          IF (LN .NE. LNCTL) GO TO 70

C         Print control settings
          WRITE(*,110) AUTO_PH, AUTO_VOL, AUTO_CONC, AUTO_O2
        ELSE
C         Section not found - use defaults
          WRITE(*,*) ' HYDROPONIC CONTROL section not found,',
     &               ' using defaults (drift mode)'
        ENDIF
      ENDIF

      REWIND (LUNEXP)

      RETURN

C-----------------------------------------------------------------------
C     FORMAT Strings
C-----------------------------------------------------------------------

 60   FORMAT (I4,9(1X,F9.0))
 100  FORMAT (/,' *** HYDROPONIC MODE ACTIVATED ***',
     &        /,' HYDROPONIC SOLUTION PARAMETERS:',
     &        /,'   Solution Depth   : ',F10.1,' mm (1 mm = 1 L/m²)',
     &        /,'   EC               : ',F10.2,' dS/m',
     &        /,'   pH               : ',F10.2,
     &        /,'   DO2              : ',F10.2,' mg/L',
     &        /,'   Temperature      : ',F10.2,' C',
     &        /,'   NO3-N            : ',F10.2,' mg/L',
     &        /,'   NH4-N            : ',F10.2,' mg/L',
     &        /,'   P                : ',F10.2,' mg/L',
     &        /,'   K                : ',F10.2,' mg/L',
     &        /,'   Channel Length   : ',F10.1,' cm',
     &        /,'   Channel Spacing  : ',F10.1,' cm',/)

 110  FORMAT (' HYDROPONIC CONTROL SETTINGS:',
     &        /,'   AUTO_PH  : ',A1,' (Y=constant, N=drift)',
     &        /,'   AUTO_VOL : ',A1,' (Y=constant, N=drift)',
     &        /,'   AUTO_CONC: ',A1,' (Y=replenish nutrients, N=deplete)',
     &        /,'   AUTO_O2  : ',A1,' (Y=pin DO2 to initial, N=dynamic)',
     &        /,'   (EC always drifts naturally with nutrient uptake)',/)

      END SUBROUTINE IPSOL
