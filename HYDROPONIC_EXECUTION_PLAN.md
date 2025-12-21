# Hydroponic Conversion - Step-by-Step Execution Plan

## Overview

This document provides a detailed, step-by-step execution plan for converting DSSAT-CSM from soil-based to hydroponic systems. Each step includes:
- Specific tasks to complete
- Code changes required
- Test procedures
- Success criteria
- Rollback procedures (if needed)

**Estimated Total Time:** 20-24 weeks  
**Testing Strategy:** Test after each step before proceeding

---

## Phase 1: Foundation Setup (Weeks 1-2)

### Step 1.1: Create Directory Structure

**Tasks:**
1. Create new directory structure for hydroponic modules
2. Set up version control branch (if using Git)

**Commands:**
```bash
mkdir -p Hydroponic/SolutionManagement
mkdir -p Hydroponic/SolutionNutrients
mkdir -p Hydroponic/SolutionChemistry
mkdir -p Hydroponic/SolutionUtilities
```

**Files Created:**
- Directory structure only (no code yet)

**Test:**
```bash
# Verify directories exist
ls -R Hydroponic/
```

**Success Criteria:**
- ✅ All directories created
- ✅ Directory structure matches plan

**Rollback:**
```bash
rm -rf Hydroponic/
```

---

### Step 1.2: Add SolutionType to ModuleDefs.for

**Tasks:**
1. Open `Utilities/ModuleDefs.for`
2. Find `TYPE SoilType` definition (around line 169)
3. Add `TYPE SolutionType` after SoilType
4. Add hydroponic switches to `SwitchType`

**Code Changes:**

**Location:** `Utilities/ModuleDefs.for`

**Add after SoilType (around line 225):**
```fortran
!=======================================================================
!     Data construct for hydroponic solution variables
      TYPE SolutionType
        ! Solution volume and flow
        REAL SOLVOL              ! Total solution volume (L)
        REAL SOLFLOW             ! Solution flow rate (L/day)
        REAL SOLRECIRC           ! Recirculation rate (L/day)
        REAL SOLREPLACE          ! Replacement rate (L/day)
        REAL SOLWITHDRAW         ! Water withdrawn by plants (L/day)
        REAL SOLEVAP             ! Evaporation from solution (L/day)
        
        ! Solution chemistry
        REAL EC                  ! Electrical conductivity (dS/m)
        REAL PH                  ! pH
        REAL DO2                 ! Dissolved oxygen (mg/L)
        REAL TEMP                ! Solution temperature (°C)
        
        ! Nutrient concentrations (mg/L)
        REAL NO3_CONC            ! NO3-N concentration (mg/L)
        REAL NH4_CONC            ! NH4-N concentration (mg/L)
        REAL P_CONC              ! P concentration (mg/L)
        REAL K_CONC              ! K concentration (mg/L)
        REAL CA_CONC             ! Ca concentration (mg/L)
        REAL MG_CONC             ! Mg concentration (mg/L)
        REAL S_CONC              ! S concentration (mg/L)
        
        ! Nutrient totals (kg/ha equivalent for plant interface)
        REAL NO3_TOT             ! Total NO3-N (kg/ha)
        REAL NH4_TOT             ! Total NH4-N (kg/ha)
        REAL P_TOT               ! Total P (kg/ha)
        REAL K_TOT               ! Total K (kg/ha)
        
        ! Solution management
        CHARACTER*10 SOLTYPE     ! 'RECIRC', 'DRAIN2WASTE', 'NFT', 'DWC'
        REAL SOLTARGET_EC        ! Target EC (dS/m)
        REAL SOLTARGET_PH        ! Target pH
        REAL SOLREFRESH_RATE     ! Refresh rate (%/day)
        REAL SOLMAX_AGE          ! Maximum solution age (days)
        
        ! System properties
        REAL RESERVOIR_VOL       ! Reservoir volume (L)
        REAL GROWING_AREA        ! Growing area (m²)
        REAL PLANT_DENSITY       ! Plants per m²
        
        ! Initialization flag
        LOGICAL INITIALIZED
      END TYPE SolutionType
```

**Modify SwitchType (find around line 100-150):**
```fortran
! Add to existing SwitchType:
CHARACTER*1 ISWHYDRO    ! 'Y' = hydroponic, 'N' = soil
CHARACTER*10 HYDROTYPE  ! 'RECIRC', 'DRAIN2WASTE', 'NFT', 'DWC'
```

**Test:**
```bash
# Compile to check for syntax errors
cd build
cmake ..
make 2>&1 | grep -i "error\|warning" | head -20
```

**Success Criteria:**
- ✅ Code compiles without errors
- ✅ No new warnings related to SolutionType
- ✅ SolutionType structure is accessible

**Rollback:**
```bash
git checkout Utilities/ModuleDefs.for
```

---

### Step 1.3: Create HYDRO.for Skeleton

**Tasks:**
1. Create `Hydroponic/HYDRO.for` file
2. Copy structure from `Soil/SOIL.for`
3. Create basic subroutine skeleton

**Code:**

**File:** `Hydroponic/HYDRO.for`
```fortran
!=======================================================================
!  COPYRIGHT 1998-2025
!                      DSSAT Foundation
!                      University of Florida, Gainesville, Florida
!                      International Fertilizer Development Center
!                     
!  ALL RIGHTS RESERVED
!=======================================================================
!  HYDRO, Subroutine
!-----------------------------------------------------------------------
!  Hydroponic Solution Processes subroutine.  Calls the following modules:
!     SOLBAL      - solution balance
!     SOLNi       - solution N
!     SOLPi       - solution P
!     SOLKi       - solution K
!     SOLEC       - EC management
!     SOLPH       - pH management
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  [DATE] [AUTHOR] Written for hydroponic systems
!=======================================================================

      SUBROUTINE HYDRO(CONTROL, ISWITCH, 
     &    EP, FERTDATA, FracRts, HARVRES, IRRAMT,         !Input
     &    KTRANS, KUptake, PUptake, RLV,                   !Input
     &    SENESCE, ST, UNH4, UNO3,                         !Input
     &    WEATHER, XHLAI,                                   !Input
     &    SOLUTION,                                         !I/O
     &    NH4_plant, NO3_plant, SKi_AVAIL,                  !Output
     &    SPi_AVAIL, SOLPROP, SW, YREND)                    !Output

!-----------------------------------------------------------------------
      USE ModuleDefs
      IMPLICIT NONE
      EXTERNAL SOLBAL, SOLNi, SOLPi, SOLKi, SOLEC, SOLPH
      SAVE
!-----------------------------------------------------------------------
!     Interface variables:
!-----------------------------------------------------------------------
!     Input:
      TYPE (ControlType) , INTENT(IN) :: CONTROL
      TYPE (SwitchType)  , INTENT(IN) :: ISWITCH
      REAL               , INTENT(IN) :: EP
      TYPE (FertType)    , INTENT(IN) :: FERTDATA
      REAL, DIMENSION(NL), INTENT(IN) :: FracRts
      Type (ResidueType) , INTENT(IN) :: HARVRES
      REAL               , INTENT(IN) :: IRRAMT
      REAL               , INTENT(IN) :: KTRANS
      REAL, DIMENSION(NL), INTENT(IN) :: PUptake, KUptake
      REAL, DIMENSION(NL), INTENT(IN) :: RLV
      Type (ResidueType) , INTENT(IN) :: SENESCE
      REAL, DIMENSION(NL), INTENT(IN) :: ST
      REAL, DIMENSION(NL), INTENT(IN) :: UNH4, UNO3
      TYPE (WeatherType) , INTENT(IN) :: WEATHER
      REAL               , INTENT(IN) :: XHLAI

!     Input/Output:
      TYPE (SolutionType), INTENT(INOUT) :: SOLUTION

!     Output:
      REAL, DIMENSION(NL), INTENT(OUT) :: NH4_plant
      REAL, DIMENSION(NL), INTENT(OUT) :: NO3_plant
      REAL, DIMENSION(NL), INTENT(OUT) :: SPi_AVAIL, SKi_AVAIL
      TYPE (SolutionType), INTENT(OUT) :: SOLPROP
      REAL, DIMENSION(NL), INTENT(OUT) :: SW
      INTEGER            , INTENT(OUT) :: YREND

!-----------------------------------------------------------------------
!     Local variables
!-----------------------------------------------------------------------
      CHARACTER*1 ISWHYDRO, ISWWAT, ISWNIT
      INTEGER DYNAMIC, RUN, YRDOY
      
!     Transfer values from constructed data types
      DYNAMIC = CONTROL % DYNAMIC
      RUN     = CONTROL % RUN
      YRDOY   = CONTROL % YRDOY
      ISWHYDRO = ISWITCH % ISWHYDRO
      ISWWAT   = ISWITCH % ISWWAT
      ISWNIT   = ISWITCH % ISWNIT

!***********************************************************************
!***********************************************************************
!     SEASONAL INITIALIZATION
!***********************************************************************
      IF (DYNAMIC .EQ. SEASINIT) THEN
!-----------------------------------------------------------------------
!       Initialize solution properties
!-----------------------------------------------------------------------
        SOLUTION % INITIALIZED = .FALSE.
        
!       TODO: Call initialization routines
!       CALL IPSOL(...)  ! Read solution initial conditions
        
        SOLUTION % INITIALIZED = .TRUE.

!***********************************************************************
!***********************************************************************
!     RATE CALCULATIONS
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. RATE) THEN
!-----------------------------------------------------------------------
!       Calculate daily rates
!-----------------------------------------------------------------------
        IF (ISWWAT .EQ. 'Y') THEN
!         Solution balance
          CALL SOLBAL(CONTROL, ISWITCH,
     &      EP, FERTDATA, IRRAMT, RLV, WEATHER, XHLAI,  !Input
     &      SOLUTION)                                    !I/O
        ENDIF

        IF (ISWNIT .EQ. 'Y') THEN
!         Solution N
          CALL SOLNi(CONTROL, ISWITCH,
     &      FERTDATA, UNH4, UNO3, WEATHER,              !Input
     &      SOLUTION,                                    !I/O
     &      NH4_plant, NO3_plant, UPPM)                  !Output
        ENDIF

!       Solution P
        CALL SOLPi(CONTROL, ISWITCH,
     &    FERTDATA, PUptake,                             !Input
     &    SOLUTION,                                      !I/O
     &    SPi_AVAIL)                                     !Output

!       Solution K
        CALL SOLKi(CONTROL, ISWITCH,
     &    FERTDATA, KUptake,                             !Input
     &    SOLUTION,                                      !I/O
     &    SKi_AVAIL)                                     !Output

!       Solution chemistry
        CALL SOLEC(CONTROL, ISWITCH,
     &    SOLUTION)                                      !I/O

        CALL SOLPH(CONTROL, ISWITCH,
     &    SOLUTION)                                      !I/O

!***********************************************************************
!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. INTEGR) THEN
!-----------------------------------------------------------------------
!       Integrate solution state variables
!-----------------------------------------------------------------------
!       TODO: Integration will be done in individual modules

!***********************************************************************
!***********************************************************************
!     OUTPUT
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. OUTPUT) THEN
!-----------------------------------------------------------------------
!       Output solution data
!-----------------------------------------------------------------------
!       TODO: Call output routines
!       CALL OPSOL(...)

!***********************************************************************
!***********************************************************************
!     SEASONAL END
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. SEASEND) THEN
!-----------------------------------------------------------------------
!       End of season cleanup
!-----------------------------------------------------------------------
        SOLUTION % INITIALIZED = .FALSE.

      ENDIF

!-----------------------------------------------------------------------
!     Copy solution to output structure
      SOLPROP = SOLUTION

!***********************************************************************
      RETURN
      END SUBROUTINE HYDRO
!=======================================================================
```

**Test:**
```bash
# Compile to check for syntax errors
cd build
cmake ..
make 2>&1 | grep -i "HYDRO\|error\|warning" | head -20
```

**Success Criteria:**
- ✅ HYDRO.for compiles without errors
- ✅ Subroutine structure matches SOIL.for
- ✅ All interfaces defined (even if stubs)

**Rollback:**
```bash
rm Hydroponic/HYDRO.for
```

---

### Step 1.4: Update CMakeLists.txt

**Tasks:**
1. Find `CMakeLists.txt`
2. Locate where Soil sources are listed
3. Add Hydroponic sources section

**Code Changes:**

**File:** `CMakeLists.txt`

**Find section with Soil sources (around line 200-300), add after it:**
```cmake
# Hydroponic modules
set(HYDROPONIC_SOURCES
  Hydroponic/HYDRO.for
  Hydroponic/SolutionManagement/SOLBAL.for
  Hydroponic/SolutionNutrients/SOLNi.for
  Hydroponic/SolutionNutrients/SOLPi.for
  Hydroponic/SolutionNutrients/SOLKi.for
  Hydroponic/SolutionChemistry/SOLEC.for
  Hydroponic/SolutionChemistry/SOLPH.for
  Hydroponic/SolutionUtilities/IPSOL.for
  Hydroponic/SolutionUtilities/OPSOL.for
)

# Add to main source list (find where SOIL_SOURCES is added)
# Add: ${HYDROPONIC_SOURCES}
```

**Test:**
```bash
# Test CMake configuration
cd build
cmake ..
# Should complete without errors
```

**Success Criteria:**
- ✅ CMake configures successfully
- ✅ Hydroponic sources are recognized

**Rollback:**
```bash
git checkout CMakeLists.txt
```

---

## Phase 2: Solution Balance Module (Weeks 3-4)

### Step 2.1: Create SOLBAL.for Skeleton

**Tasks:**
1. Create `Hydroponic/SolutionManagement/SOLBAL.for`
2. Create basic structure based on WATBAL.for

**Code:**

**File:** `Hydroponic/SolutionManagement/SOLBAL.for`
```fortran
!=======================================================================
!  COPYRIGHT 1998-2025
!                      DSSAT Foundation
!                      University of Florida, Gainesville, Florida
!                      International Fertilizer Development Center
!                     
!  ALL RIGHTS RESERVED
!=======================================================================
!  SOLBAL, Subroutine
!-----------------------------------------------------------------------
!  Solution Balance for hydroponic systems
!-----------------------------------------------------------------------
!  REVISION HISTORY
!  [DATE] [AUTHOR] Written for hydroponic systems
!=======================================================================

      SUBROUTINE SOLBAL(CONTROL, ISWITCH,
     &    EP, FERTDATA, IRRAMT, RLV, WEATHER, XHLAI,  !Input
     &    SOLUTION)                                    !I/O

!-----------------------------------------------------------------------
      USE ModuleDefs
      IMPLICIT NONE
      SAVE
!-----------------------------------------------------------------------
!     Interface variables:
!-----------------------------------------------------------------------
      TYPE (ControlType) , INTENT(IN) :: CONTROL
      TYPE (SwitchType)  , INTENT(IN) :: ISWITCH
      REAL               , INTENT(IN) :: EP
      TYPE (FertType)    , INTENT(IN) :: FERTDATA
      REAL               , INTENT(IN) :: IRRAMT
      REAL, DIMENSION(NL), INTENT(IN) :: RLV
      TYPE (WeatherType) , INTENT(IN) :: WEATHER
      REAL               , INTENT(IN) :: XHLAI

      TYPE (SolutionType), INTENT(INOUT) :: SOLUTION

!-----------------------------------------------------------------------
!     Local variables
!-----------------------------------------------------------------------
      INTEGER DYNAMIC, YRDOY, DAS
      REAL PLANT_WITHDRAW, SOL_EVAP, WATER_ADD
      REAL CONVERSION_FACTOR  ! L/mm conversion

!     Transfer values
      DYNAMIC = CONTROL % DYNAMIC
      YRDOY   = CONTROL % YRDOY
      DAS     = CONTROL % DAS

!     Conversion: 1 mm = 10 L/m² (for 1 m² area)
      CONVERSION_FACTOR = 10.0

!***********************************************************************
!     SEASONAL INITIALIZATION
!***********************************************************************
      IF (DYNAMIC .EQ. SEASINIT) THEN
!-----------------------------------------------------------------------
!       Initialize solution balance variables
!-----------------------------------------------------------------------
        SOLUTION % SOLWITHDRAW = 0.0
        SOLUTION % SOLEVAP = 0.0
        SOLUTION % SOLREPLACE = 0.0

!***********************************************************************
!     RATE CALCULATIONS
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. RATE) THEN
!-----------------------------------------------------------------------
!       Calculate daily rates
!-----------------------------------------------------------------------
!       Plant water withdrawal (L/day)
!       EP is in mm/day, convert to L for solution volume
        PLANT_WITHDRAW = EP * CONVERSION_FACTOR * SOLUTION % GROWING_AREA

!       Solution evaporation (minimal, usually < 1% of transpiration)
        SOL_EVAP = 0.0  ! TODO: Calculate if needed

!       Water addition from irrigation/fertilizer
        WATER_ADD = IRRAMT * CONVERSION_FACTOR * SOLUTION % GROWING_AREA

!       Store rates
        SOLUTION % SOLWITHDRAW = PLANT_WITHDRAW
        SOLUTION % SOLEVAP = SOL_EVAP

!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. INTEGR) THEN
!-----------------------------------------------------------------------
!       Update solution volume
!-----------------------------------------------------------------------
        SOLUTION % SOLVOL = SOLUTION % SOLVOL
     &    + WATER_ADD                    ! Water addition
     &    - SOLUTION % SOLWITHDRAW       ! Plant uptake
     &    - SOLUTION % SOLEVAP           ! Evaporation
     &    - SOLUTION % SOLREPLACE         ! Replacement/drain

!       Ensure solution volume doesn't go negative
        IF (SOLUTION % SOLVOL < 0.0) THEN
          SOLUTION % SOLVOL = 0.0
        ENDIF

      ENDIF

!***********************************************************************
      RETURN
      END SUBROUTINE SOLBAL
!=======================================================================
```

**Test:**
```bash
# Compile
cd build
make 2>&1 | grep -i "SOLBAL\|error" | head -20

# Create simple test program (optional)
# Test that SOLBAL can be called without errors
```

**Success Criteria:**
- ✅ SOLBAL.for compiles
- ✅ No syntax errors
- ✅ Basic structure in place

**Rollback:**
```bash
rm Hydroponic/SolutionManagement/SOLBAL.for
```

---

### Step 2.2: Test SOLBAL with Unit Test

**Tasks:**
1. Create simple test to verify solution balance
2. Test volume calculations
3. Verify mass balance

**Test Code:**

**File:** `Hydroponic/SolutionManagement/test_solbal.f90` (optional, for testing)
```fortran
! Simple test program for SOLBAL
! This is optional - can test manually or with debugger

PROGRAM TEST_SOLBAL
  USE ModuleDefs
  IMPLICIT NONE
  
  TYPE (SolutionType) :: SOLUTION
  TYPE (ControlType) :: CONTROL
  TYPE (SwitchType) :: ISWITCH
  TYPE (FertType) :: FERTDATA
  TYPE (WeatherType) :: WEATHER
  REAL :: EP = 5.0  ! mm/day
  REAL :: IRRAMT = 0.0
  REAL, DIMENSION(NL) :: RLV = 0.0
  REAL :: XHLAI = 2.0
  
  ! Initialize solution
  SOLUTION % SOLVOL = 1000.0  ! 1000 L
  SOLUTION % GROWING_AREA = 10.0  ! 10 m²
  
  ! Test: Add 50 mm irrigation
  IRRAMT = 50.0
  
  ! Call SOLBAL (would need proper initialization first)
  ! CALL SOLBAL(...)
  
  ! Verify: Solution volume should increase
  ! Expected: 1000 + (50 * 10 * 10) = 6000 L
  
  WRITE(*,*) 'Test completed'
END PROGRAM
```

**Manual Test Procedure:**
1. Set initial solution volume = 1000 L
2. Set growing area = 10 m²
3. Add 50 mm irrigation
4. Expected: Volume increases by 5000 L (50 mm × 10 L/mm × 10 m²)
5. Verify calculation is correct

**Success Criteria:**
- ✅ Volume calculations are correct
- ✅ Mass balance closes (in = out + storage change)
- ✅ No negative volumes

---

### Step 2.3: Add Solution Refresh Logic

**Tasks:**
1. Add solution refresh/replacement logic to SOLBAL
2. Implement refresh rate calculation
3. Add solution age tracking

**Code Changes:**

**Add to SOLBAL.for:**
```fortran
! Add to local variables:
REAL SOL_AGE, REFRESH_AMOUNT

! Add to RATE section:
! Calculate solution age (days since last refresh)
SOL_AGE = SOL_AGE + 1.0

! Calculate refresh amount based on refresh rate
IF (SOLUTION % SOLREFRESH_RATE > 0.0) THEN
  REFRESH_AMOUNT = SOLUTION % SOLVOL * SOLUTION % SOLREFRESH_RATE / 100.0
ELSE
  REFRESH_AMOUNT = 0.0
ENDIF

! Or refresh based on maximum age
IF (SOL_AGE >= SOLUTION % SOLMAX_AGE) THEN
  REFRESH_AMOUNT = SOLUTION % SOLVOL * 0.5  ! Replace 50%
  SOL_AGE = 0.0
ENDIF

SOLUTION % SOLREPLACE = REFRESH_AMOUNT
```

**Test:**
1. Set refresh rate = 10% per day
2. Initial volume = 1000 L
3. Expected: 100 L replaced per day
4. Verify refresh amount is correct

**Success Criteria:**
- ✅ Refresh rate calculation works
- ✅ Solution age tracking works
- ✅ Refresh triggers correctly

---

## Phase 3: Solution Nutrients (Weeks 5-8)

### Step 3.1: Create SOLNi.for

**Tasks:**
1. Create `Hydroponic/SolutionNutrients/SOLNi.for`
2. Implement basic N balance
3. Convert concentrations to plant-available amounts

**Code:**

**File:** `Hydroponic/SolutionNutrients/SOLNi.for`
```fortran
!=======================================================================
!  SOLNi, Subroutine
!-----------------------------------------------------------------------
!  Solution Nitrogen management for hydroponic systems
!=======================================================================

      SUBROUTINE SOLNi(CONTROL, ISWITCH,
     &    FERTDATA, UNH4, UNO3, WEATHER,              !Input
     &    SOLUTION,                                    !I/O
     &    NH4_plant, NO3_plant, UPPM)                 !Output

!-----------------------------------------------------------------------
      USE ModuleDefs
      IMPLICIT NONE
      SAVE
!-----------------------------------------------------------------------
      TYPE (ControlType) , INTENT(IN) :: CONTROL
      TYPE (SwitchType)  , INTENT(IN) :: ISWITCH
      TYPE (FertType)    , INTENT(IN) :: FERTDATA
      REAL, DIMENSION(NL), INTENT(IN) :: UNH4, UNO3
      TYPE (WeatherType) , INTENT(IN) :: WEATHER

      TYPE (SolutionType), INTENT(INOUT) :: SOLUTION
      REAL, DIMENSION(NL), INTENT(OUT) :: NH4_plant, NO3_plant
      REAL, DIMENSION(NL), INTENT(OUT) :: UPPM

!-----------------------------------------------------------------------
!     Local variables
!-----------------------------------------------------------------------
      INTEGER DYNAMIC, L
      REAL FERT_NO3, FERT_NH4
      REAL NO3_LOSS, NH4_LOSS, NH4_VOLAT
      REAL CONVERSION  ! mg/L to kg/ha conversion

!     Conversion factor: mg/L * L / m² * conversion = kg/ha
!     1 mg/L = 1 g/m³, for 1 m depth = 1 g/m² = 0.01 kg/ha per mm depth
      CONVERSION = 0.01

!***********************************************************************
!     SEASONAL INITIALIZATION
!***********************************************************************
      IF (DYNAMIC .EQ. SEASINIT) THEN
!-----------------------------------------------------------------------
!       Initialize N variables
!-----------------------------------------------------------------------
        SOLUTION % NO3_TOT = 0.0
        SOLUTION % NH4_TOT = 0.0
        SOLUTION % NO3_CONC = 0.0
        SOLUTION % NH4_CONC = 0.0

!***********************************************************************
!     RATE CALCULATIONS
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. RATE) THEN
!-----------------------------------------------------------------------
!       Calculate N rates
!-----------------------------------------------------------------------
!       Get fertilizer N (simplified - would need proper parsing)
        FERT_NO3 = 0.0  ! TODO: Extract from FERTDATA
        FERT_NH4 = 0.0  ! TODO: Extract from FERTDATA

!       Calculate N losses from solution replacement
        IF (SOLUTION % SOLREPLACE > 0.0 .AND. SOLUTION % SOLVOL > 0.0) THEN
          NO3_LOSS = SOLUTION % NO3_TOT * 
     &      (SOLUTION % SOLREPLACE / SOLUTION % SOLVOL)
          NH4_LOSS = SOLUTION % NH4_TOT * 
     &      (SOLUTION % SOLREPLACE / SOLUTION % SOLVOL)
        ELSE
          NO3_LOSS = 0.0
          NH4_LOSS = 0.0
        ENDIF

!       NH4 volatilization (simplified - depends on pH)
        IF (SOLUTION % PH > 7.5) THEN
          NH4_VOLAT = SOLUTION % NH4_TOT * 0.01  ! 1% per day at high pH
        ELSE
          NH4_VOLAT = 0.0
        ENDIF

!       Calculate plant-available N
!       Convert from solution concentration to kg/ha equivalent
        DO L = 1, NL
          IF (SOLUTION % SOLVOL > 0.0) THEN
            NO3_plant(L) = SOLUTION % NO3_CONC * 
     &        SOLUTION % SOLVOL * CONVERSION / NL
            NH4_plant(L) = SOLUTION % NH4_CONC * 
     &        SOLUTION % SOLVOL * CONVERSION / NL
          ELSE
            NO3_plant(L) = 0.0
            NH4_plant(L) = 0.0
          ENDIF
        ENDDO

!***********************************************************************
!     DAILY INTEGRATION
!***********************************************************************
      ELSE IF (DYNAMIC .EQ. INTEGR) THEN
!-----------------------------------------------------------------------
!       Update N totals
!-----------------------------------------------------------------------
        SOLUTION % NO3_TOT = SOLUTION % NO3_TOT
     &    + FERT_NO3                    ! Fertilizer addition
     &    - SUM(UNO3)                   ! Plant uptake
     &    - NO3_LOSS                    ! Solution replacement loss

        SOLUTION % NH4_TOT = SOLUTION % NH4_TOT
     &    + FERT_NH4                    ! Fertilizer addition
     &    - SUM(UNH4)                   ! Plant uptake
     &    - NH4_LOSS                    ! Solution replacement loss
     &    - NH4_VOLAT                   ! Volatilization

!       Update concentrations
        IF (SOLUTION % SOLVOL > 0.0) THEN
          SOLUTION % NO3_CONC = SOLUTION % NO3_TOT * 1000.0 / 
     &      (SOLUTION % SOLVOL * SOLUTION % GROWING_AREA)
          SOLUTION % NH4_CONC = SOLUTION % NH4_TOT * 1000.0 / 
     &      (SOLUTION % SOLVOL * SOLUTION % GROWING_AREA)
        ELSE
          SOLUTION % NO3_CONC = 0.0
          SOLUTION % NH4_CONC = 0.0
        ENDIF

!       Ensure non-negative
        IF (SOLUTION % NO3_TOT < 0.0) SOLUTION % NO3_TOT = 0.0
        IF (SOLUTION % NH4_TOT < 0.0) SOLUTION % NH4_TOT = 0.0

      ENDIF

!***********************************************************************
      RETURN
      END SUBROUTINE SOLNi
!=======================================================================
```

**Test:**
1. Set initial NO3 = 150 mg/L, volume = 1000 L, area = 10 m²
2. Add 10 kg/ha NO3 fertilizer
3. Plant uptake = 5 kg/ha
4. Verify: Final NO3 should be correct
5. Check mass balance: Initial + Fertilizer - Uptake - Loss = Final

**Success Criteria:**
- ✅ N balance closes
- ✅ Concentrations calculated correctly
- ✅ Plant-available N is reasonable

---

### Step 3.2: Create SOLPi.for and SOLKi.for

**Tasks:**
1. Create SOLPi.for (similar to SOLNi)
2. Create SOLKi.for (similar to SOLNi)
3. Test each independently

**Code Structure:** Similar to SOLNi, but for P and K

**Test:** Similar to SOLNi tests

**Success Criteria:**
- ✅ P and K balances close
- ✅ Concentrations correct
- ✅ Plant-available amounts correct

---

## Phase 4: Solution Chemistry (Weeks 9-12)

### Step 4.1: Create SOLEC.for

**Tasks:**
1. Create EC calculation module
2. Implement EC from nutrient concentrations
3. Add EC monitoring

**Code:**

**File:** `Hydroponic/SolutionChemistry/SOLEC.for`
```fortran
!=======================================================================
!  SOLEC, Subroutine
!-----------------------------------------------------------------------
!  Electrical Conductivity (EC) management for hydroponic systems
!=======================================================================

      SUBROUTINE SOLEC(CONTROL, ISWITCH,
     &    SOLUTION)                                    !I/O

!-----------------------------------------------------------------------
      USE ModuleDefs
      IMPLICIT NONE
      SAVE
!-----------------------------------------------------------------------
      TYPE (ControlType) , INTENT(IN) :: CONTROL
      TYPE (SwitchType)  , INTENT(IN) :: ISWITCH
      TYPE (SolutionType), INTENT(INOUT) :: SOLUTION

!-----------------------------------------------------------------------
!     Local variables
!-----------------------------------------------------------------------
      INTEGER DYNAMIC
      REAL EC_CALC

!     EC conversion factors (dS/m per mg/L)
      REAL, PARAMETER :: EC_NO3 = 0.0015
      REAL, PARAMETER :: EC_NH4 = 0.0018
      REAL, PARAMETER :: EC_K = 0.0025
      REAL, PARAMETER :: EC_CA = 0.0020
      REAL, PARAMETER :: EC_MG = 0.0030
      REAL, PARAMETER :: EC_S = 0.0010

!***********************************************************************
!     RATE CALCULATIONS
!***********************************************************************
      IF (DYNAMIC .EQ. RATE) THEN
!-----------------------------------------------------------------------
!       Calculate EC from nutrient concentrations
!-----------------------------------------------------------------------
        EC_CALC = 
     &    SOLUTION % NO3_CONC * EC_NO3 +
     &    SOLUTION % NH4_CONC * EC_NH4 +
     &    SOLUTION % K_CONC * EC_K +
     &    SOLUTION % CA_CONC * EC_CA +
     &    SOLUTION % MG_CONC * EC_MG +
     &    SOLUTION % S_CONC * EC_S

!       Update solution EC
        SOLUTION % EC = EC_CALC

!       TODO: Compare to target EC and trigger refresh if needed
        IF (SOLUTION % EC > SOLUTION % SOLTARGET_EC * 1.2) THEN
!         EC too high - may need refresh
        ENDIF

      ENDIF

!***********************************************************************
      RETURN
      END SUBROUTINE SOLEC
!=======================================================================
```

**Test:**
1. Set NO3 = 150 mg/L, K = 200 mg/L
2. Calculate EC
3. Expected: EC ≈ 0.225 + 0.5 = 0.725 dS/m
4. Verify calculation

**Success Criteria:**
- ✅ EC calculation is reasonable
- ✅ Matches expected values
- ✅ EC monitoring works

---

### Step 4.2: Create SOLPH.for

**Tasks:**
1. Create pH management module
2. Implement pH changes from nutrient uptake
3. Add pH adjustment logic

**Code:** Similar structure to SOLEC

**Test:** Verify pH calculations

---

## Phase 5: Integration (Weeks 13-16)

### Step 5.1: Modify LAND.for

**Tasks:**
1. Add conditional call to HYDRO or SOIL
2. Handle different output structures
3. Test integration

**Code Changes:**

**File:** `CSM_Main/LAND.for`

**Find SOIL call (around line 311), replace with:**
```fortran
!-----------------------------------------------------------------------
!     Call Soil or Hydroponic processes module
!-----------------------------------------------------------------------
      IF (ISWITCH % ISWHYDRO .EQ. 'Y') THEN
!       Hydroponic system
        CALL HYDRO(CONTROL, ISWITCH, 
     &    EP, FERTDATA, FracRts, HARVRES, IRRAMT,         !Input
     &    KTRANS, KUptake, PUptake, RLV,                  !Input
     &    SENESCE, ST, UNH4, UNO3,                        !Input
     &    WEATHER, XHLAI,                                 !Input
     &    SOLUTION,                                       !I/O
     &    NH4_plant, NO3_plant, SKi_AVAIL,                !Output
     &    SPi_AVAIL, SOLPROP, SW, YREND)                  !Output
        
!       Convert solution to soil-like format for plant interface
        DO L = 1, NL
          SW(L) = SOLUTION % SOLVOL / (NL * 100.0)  ! Distribute evenly
        ENDDO
        
      ELSE
!       Soil system (existing code)
        CALL SOIL(CONTROL, ISWITCH, 
     &    ES, FERTDATA, FracRts, HARVRES, IRRAMT,         !Input
     &    KTRANS, KUptake, OMAData, PUptake, RLV,         !Input
     &    SENESCE, ST, SWDELTX,TILLVALS, UNH4, UNO3,      !Input
     &    WEATHER, XHLAI,                                 !Input
     &    FLOODN, FLOODWAT, MULCH, UPFLOW,                !I/O
     &    NH4_plant, NO3_plant, SKi_AVAIL, SNOW,          !Output
     &    SPi_AVAIL, SOILPROP, SomLitC, SomLitE,          !Output
     &    SW, SWDELTS, SWDELTU, UPPM, WINF, YREND)        !Output
      ENDIF
```

**Test:**
1. Compile with both HYDRO and SOIL
2. Test with ISWHYDRO = 'N' (should use SOIL)
3. Test with ISWHYDRO = 'Y' (should use HYDRO)
4. Verify no compilation errors

**Success Criteria:**
- ✅ Code compiles
- ✅ Both paths work
- ✅ No runtime errors

---

### Step 5.2: Modify SPAM.for

**Tasks:**
1. Remove ES calculation for hydroponic
2. Modify root water uptake
3. Test transpiration

**Code Changes:**

**File:** `SPAM/SPAM.for`

**Add conditional:**
```fortran
IF (ISWITCH % ISWHYDRO .EQ. 'Y') THEN
! Hydroponic - no soil evaporation
  ES = 0.0
! Root water uptake is direct from solution
  ! (Simplified - solution always available)
ELSE
! Soil - existing ES calculation
  ! ... existing code ...
ENDIF
```

**Test:**
1. Run simulation with hydroponic
2. Verify ES = 0
3. Verify EP (transpiration) still works
4. Check water balance

**Success Criteria:**
- ✅ ES = 0 for hydroponic
- ✅ EP works correctly
- ✅ Water balance closes

---

## Phase 6: Input/Output (Weeks 17-20)

### Step 6.1: Create IPSOL.for

**Tasks:**
1. Create input module for solution data
2. Read from FileX
3. Initialize solution

**Code:** Similar to IPSOIL.for

**Test:**
1. Create test FileX with solution data
2. Read and verify initialization
3. Check all values are correct

---

### Step 6.2: Create OPSOL.for

**Tasks:**
1. Create output module
2. Write solution data to output files
3. Test output format

**Test:**
1. Run simulation
2. Check output files
3. Verify data is correct

---

## Phase 7: Testing and Validation (Weeks 21-24)

### Step 7.1: Unit Tests

**Test each module independently:**
- [ ] SOLBAL - solution balance
- [ ] SOLNi - N balance
- [ ] SOLPi - P balance
- [ ] SOLKi - K balance
- [ ] SOLEC - EC calculation
- [ ] SOLPH - pH calculation

### Step 7.2: Integration Tests

**Test full system:**
- [ ] Full simulation runs
- [ ] Mass balances close
- [ ] Nutrient balances close
- [ ] Solution refresh works
- [ ] EC/pH management works

### Step 7.3: Validation Tests

**Compare to:**
- [ ] Published hydroponic data
- [ ] Soil-based results (where applicable)
- [ ] Expected growth patterns

---

## Testing Checklist Template

After each step, use this checklist:

```
Step: [Step Number and Name]
Date: [Date]
Tester: [Name]

Compilation:
[ ] Code compiles without errors
[ ] No new warnings introduced
[ ] All modules link correctly

Functionality:
[ ] Basic functionality works
[ ] Calculations are correct
[ ] Mass balances close (if applicable)
[ ] No runtime errors

Integration:
[ ] Works with existing code
[ ] Doesn't break soil simulations
[ ] Interfaces are correct

Documentation:
[ ] Code is commented
[ ] Changes are documented
[ ] Test results recorded

Issues Found:
[List any issues]

Next Steps:
[What to do next]
```

---

## Rollback Procedures

If a step fails:

1. **Document the failure:**
   - What failed?
   - Error messages
   - What was expected?

2. **Rollback:**
   ```bash
   git checkout [file]
   # or
   rm [new_file]
   ```

3. **Fix issues:**
   - Review error messages
   - Check code logic
   - Consult documentation

4. **Retry:**
   - Fix the issue
   - Re-run tests
   - Verify success

---

## Progress Tracking

Use this table to track progress:

| Step | Status | Date Completed | Tester | Notes |
|------|--------|----------------|--------|-------|
| 1.1 | ⬜ | | | |
| 1.2 | ⬜ | | | |
| 1.3 | ⬜ | | | |
| 1.4 | ⬜ | | | |
| 2.1 | ⬜ | | | |
| 2.2 | ⬜ | | | |
| ... | ⬜ | | | |

**Status Codes:**
- ⬜ Not started
- 🟡 In progress
- ✅ Completed
- ❌ Failed
- ⚠️ Needs review

---

## Notes

- Test after EVERY step before proceeding
- Document all issues and solutions
- Keep code commented
- Maintain backward compatibility
- Regular commits to version control

---

**Last Updated:** [Date]  
**Version:** 1.0

