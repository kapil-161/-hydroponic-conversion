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

      SUBROUTINE IPSOL (LUNEXP,FILEX,LNSOL,SOLVOL,EC,PH,DO2,TEMP,
     &                  NO3_CONC,NH4_CONC,P_CONC,K_CONC,ISWHYDRO)

      IMPLICIT NONE
      EXTERNAL ERROR, FIND, IGNORE

      CHARACTER*1  ISWHYDRO
      CHARACTER*6  ERRKEY,FINDCH
      CHARACTER*12 FILEX
      CHARACTER*120 CHARTEST

      INTEGER LUNEXP,LNSOL,LN,LINEXP,ISECT,IFIND,ERRNUM
      REAL    SOLVOL,EC,PH,DO2,TEMP
      REAL    NO3_CONC,NH4_CONC,P_CONC,K_CONC

      PARAMETER (ERRKEY='IPSOL ')
                 FINDCH='*HYDRO'

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

C     Default: Hydroponic mode is OFF
      ISWHYDRO = 'N'

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
         READ (CHARTEST,*,IOSTAT=ERRNUM) LN,SOLVOL,EC,PH,DO2,TEMP,
     &        NO3_CONC,NH4_CONC,P_CONC,K_CONC

         IF (ERRNUM .NE. 0) THEN
            CALL ERROR (ERRKEY,ERRNUM,FILEX,LINEXP)
         ENDIF

      ELSE
         CALL ERROR (ERRKEY,2,FILEX,LINEXP)
      ENDIF

      IF (LN .NE. LNSOL) GO TO 50

C     Check if valid hydroponic data (SOLVOL > 0)
      IF (SOLVOL .GT. 0.0) THEN
C       Valid hydroponic parameters - activate HYDROPONIC mode
        ISWHYDRO = 'Y'
C       Print confirmation message to indicate section was read
        WRITE(*,100) SOLVOL,EC,PH,DO2,TEMP,NO3_CONC,NH4_CONC,P_CONC,
     &               K_CONC
      ELSE
C       SOLVOL <= 0 or -99: This treatment is soil-based
C       Keep ISWHYDRO = 'N' and return silently
        WRITE(*,*) ' Soil-based experiment (no hydroponic section found)'
      ENDIF

      REWIND (LUNEXP)

      RETURN

C-----------------------------------------------------------------------
C     FORMAT Strings
C-----------------------------------------------------------------------

 60   FORMAT (I4,9(1X,F9.0))
 100  FORMAT (/,' *** HYDROPONIC MODE ACTIVATED ***',
     &        /,' HYDROPONIC SOLUTION PARAMETERS:',
     &        /,'   Solution Volume  : ',F10.1,' L',
     &        /,'   EC               : ',F10.2,' dS/m',
     &        /,'   pH               : ',F10.2,
     &        /,'   DO2              : ',F10.2,' mg/L',
     &        /,'   Temperature      : ',F10.2,' C',
     &        /,'   NO3-N            : ',F10.2,' mg/L',
     &        /,'   NH4-N            : ',F10.2,' mg/L',
     &        /,'   P                : ',F10.2,' mg/L',
     &        /,'   K                : ',F10.2,' mg/L',/)

      END SUBROUTINE IPSOL
