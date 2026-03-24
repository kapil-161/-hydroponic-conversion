C=======================================================================
C  MODULE HydroFertData_mod
C
C  Shared data for hydroponic fertilizer addition events.
C  Populated by IPSOL at input time; consumed by HYDRO_FERT at runtime.
C-----------------------------------------------------------------------
C  Written for DSSAT hydroponic module support.
C=======================================================================

      MODULE HydroFertData_mod
        USE ModuleDefs
        IMPLICIT NONE

C       Number of scheduled hydroponic fertilizer events
        INTEGER :: NHFERT = 0

C       Event dates (YYYYDDD calendar format)
        INTEGER :: HFER_DAY(NAPPL)

C       Fertilizer material code (e.g. 'FE017'), for N-split lookup
        CHARACTER*5 :: HFER_FMCD(NAPPL)

C       Amounts to add (mg/L = concentration increase in solution)
C         HFER_FAMN : total N to add (split into NO3/NH4 via FMCD)
C         HFER_FAMP : P to add
C         HFER_FAMK : K to add
        REAL :: HFER_FAMN(NAPPL)
        REAL :: HFER_FAMP(NAPPL)
        REAL :: HFER_FAMK(NAPPL)

      END MODULE HydroFertData_mod
