C=======================================================================
C  HYDRO_WATER, Subroutine
C
C  Simple hydroponic water module - provides unlimited water from solution
C-----------------------------------------------------------------------
C  Revision history
C
C  12/22/2025 Created for hydroponic water supply
C-----------------------------------------------------------------------
C  Called from: SPAM
C
C-----------------------------------------------------------------------

      SUBROUTINE HYDRO_WATER(
     &    CONTROL, ISWITCH,                    !Input
     &    TRWUP, TRWU, EP, ES)                 !Output

      USE ModuleDefs
      IMPLICIT NONE
      SAVE

      TYPE (ControlType) CONTROL
      TYPE (SwitchType)  ISWITCH

C     Output variables
      REAL TRWUP      ! Total potential root water uptake (cm/d)
      REAL TRWU       ! Total actual root water uptake (cm/d)
      REAL EP         ! Potential plant transpiration (mm/d)
      REAL ES         ! Actual soil evaporation (mm/d)

C     Local variables
      REAL SOLVOL, NO3_CONC

C-----------------------------------------------------------------------
C     In hydroponic systems:
C     - Water is always available (no water stress)
C     - No soil evaporation (solution is contained)
C     - Roots take up water as needed (potential = actual)
C-----------------------------------------------------------------------

      SELECT CASE (CONTROL % DYNAMIC)

      CASE (RUNINIT, SEASINIT)
C       Initialize
        TRWUP = 0.0
        TRWU  = 0.0
        EP    = 0.0
        ES    = 0.0

        WRITE(*,100)
 100    FORMAT(/,' Hydroponic water module initialized',
     &         /,' Water supply: UNLIMITED from nutrient solution',/)

      CASE (RATE)
C       During growth: water is always available
C       In a real hydroponic system, water uptake equals demand
C       We provide unlimited water - no stress

        TRWUP = 999.0   ! Effectively unlimited
        TRWU  = 999.0   ! Actual = potential (no water stress)
        ES    = 0.0     ! No soil evaporation in hydroponics

        WRITE(*,*) 'HYDRO_WATER: Providing unlimited water from solution'

      CASE (INTEGR)
C       Integration - nothing to integrate for simple model
        CONTINUE

      CASE (OUTPUT)
C       Output - handled by main model
        CONTINUE

      END SELECT

      RETURN
      END SUBROUTINE HYDRO_WATER
