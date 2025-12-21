# DSSAT-CSM Hydroponic Conversion Plan

## Executive Summary

This document outlines a comprehensive plan to modify DSSAT-CSM from soil-based simulations to hydroponic systems. The conversion involves replacing soil modules with hydroponic solution management modules while maintaining compatibility with existing plant growth models.

## Current Architecture Analysis

### Current Soil-Based System

**Main Components:**
1. **SOIL.for** - Main soil module coordinator
   - Calls: SOILDYN, WATBAL, CENTURY/SoilOrg, SoilNi, SoilPi, SoilKi
   
2. **Soil Water Balance (WATBAL)** - Handles:
   - Infiltration, drainage, runoff
   - Soil evaporation (ES)
   - Capillary rise
   - Water table dynamics
   - Snow accumulation
   - Mulch water

3. **Soil Nutrients:**
   - **SoilNi** - Inorganic N (NH4, NO3) with nitrification, denitrification, leaching
   - **SoilPi** - Inorganic P with adsorption/desorption
   - **SoilKi** - Inorganic K
   
4. **Soil Organic Matter:**
   - **CENTURY** or **SoilOrg** - Organic matter decomposition
   - Mineralization/immobilization
   
5. **Soil Properties (SOILDYN):**
   - Texture, bulk density, porosity
   - Hydraulic properties (DUL, LL, SAT)
   - pH, CEC, organic carbon

### Key Interfaces

**From LAND.for:**
```fortran
CALL SOIL(CONTROL, ISWITCH, 
  &    ES, FERTDATA, FracRts, HARVRES, IRRAMT,         !Input
  &    KTRANS, KUptake, OMAData, PUptake, RLV,         !Input
  &    SENESCE, ST, SWDELTX,TILLVALS, UNH4, UNO3,      !Input
  &    WEATHER, XHLAI,                                 !Input
  &    FLOODN, FLOODWAT, MULCH, UPFLOW,                !I/O
  &    NH4_plant, NO3_plant, SKi_AVAIL, SNOW,          !Output
  &    SPi_AVAIL, SOILPROP, SomLitC, SomLitE,          !Output
  &    SW, SWDELTS, SWDELTU, UPPM, WINF, YREND)        !Output
```

**To PLANT:**
- `NH4_plant(NL)`, `NO3_plant(NL)` - Available N by layer
- `SPi_AVAIL(NL)`, `SKi_AVAIL(NL)` - Available P, K by layer
- `SW(NL)` - Soil water content by layer
- `SOILPROP` - Soil properties structure
- `ST(NL)` - Soil temperature by layer

## Hydroponic System Requirements

### What Needs to Change

1. **Remove Soil-Specific Processes:**
   - ❌ Infiltration, drainage, runoff
   - ❌ Soil evaporation (ES)
   - ❌ Capillary rise
   - ❌ Water table dynamics
   - ❌ Soil organic matter decomposition
   - ❌ Soil texture, bulk density, porosity
   - ❌ Soil adsorption/desorption (simplified)
   - ❌ Tillage effects
   - ❌ Mulch (may keep for some systems)

2. **Replace with Hydroponic Processes:**
   - ✅ Solution volume management
   - ✅ Solution recirculation or drain-to-waste
   - ✅ EC (Electrical Conductivity) management
   - ✅ pH management
   - ✅ Direct nutrient availability (no soil buffering)
   - ✅ Solution temperature
   - ✅ Oxygenation/Dissolved O2
   - ✅ Solution replacement/refresh cycles

3. **Keep/Modify:**
   - ✅ Plant water uptake (modified for solution)
   - ✅ Plant nutrient uptake (simplified - direct from solution)
   - ✅ Transpiration (EP) - still needed
   - ✅ Fertilizer applications (modified for solution)
   - ✅ Weather inputs (still needed)

## Proposed Architecture

### New Module Structure

```
Hydroponic/
├── HYDRO.for                    ! Main hydroponic module (replaces SOIL.for)
├── SolutionManagement/
│   ├── SOLBAL.for               ! Solution balance (replaces WATBAL)
│   ├── SOLRECIRC.for             ! Solution recirculation
│   ├── SOLREFRESH.for            ! Solution refresh/replacement
│   └── SOLTEMP.for               ! Solution temperature
├── SolutionNutrients/
│   ├── SOLNi.for                 ! Solution N (replaces SoilNi)
│   ├── SOLPi.for                 ! Solution P (replaces SoilPi)
│   ├── SOLKi.for                 ! Solution K (replaces SoilKi)
│   └── SOLMICRO.for               ! Micronutrients (new)
├── SolutionChemistry/
│   ├── SOLEC.for                 ! EC management
│   ├── SOLPH.for                 ! pH management
│   └── SOLO2.for                 ! Dissolved oxygen
└── SolutionUtilities/
    ├── IPSOL.for                 ! Input solution data (replaces IPSOIL)
    └── OPSOL.for                 ! Output solution data
```

### New Data Structures

**SolutionType (replaces SoilType):**
```fortran
TYPE SolutionType
  ! Solution volume and flow
  REAL SOLVOL              ! Total solution volume (L or m³)
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
  
  ! Nutrient concentrations (mg/L or ppm)
  REAL, DIMENSION(NELEM) :: NUT_CONC
  ! NUT_CONC(1) = NO3-N (mg/L)
  ! NUT_CONC(2) = NH4-N (mg/L)
  ! NUT_CONC(3) = P (mg/L)
  ! NUT_CONC(4) = K (mg/L)
  ! NUT_CONC(5) = Ca (mg/L)
  ! NUT_CONC(6) = Mg (mg/L)
  ! NUT_CONC(7) = S (mg/L)
  ! ... micronutrients
  
  ! Nutrient availability (kg/ha equivalent for plant interface)
  REAL, DIMENSION(NELEM) :: NUT_AVAIL
  
  ! Solution management
  CHARACTER*10 SOLTYPE     ! 'RECIRC', 'DRAIN2WASTE', 'NFT', 'DWC', etc.
  REAL SOLTARGET_EC        ! Target EC (dS/m)
  REAL SOLTARGET_PH        ! Target pH
  REAL SOLREFRESH_RATE     ! Refresh rate (%/day)
  REAL SOLMAX_AGE          ! Maximum solution age (days)
  
  ! System properties
  REAL RESERVOIR_VOL       ! Reservoir volume (L)
  REAL GROWING_AREA        ! Growing area (m²)
  REAL PLANT_DENSITY       ! Plants per m²
END TYPE SolutionType
```

**SolutionNutrientsType:**
```fortran
TYPE SolutionNutrientsType
  ! Current concentrations (mg/L)
  REAL NO3_CONC, NH4_CONC
  REAL P_CONC, K_CONC
  REAL CA_CONC, MG_CONC, S_CONC
  REAL FE_CONC, MN_CONC, ZN_CONC, CU_CONC, B_CONC, MO_CONC
  
  ! Total amounts (kg/ha equivalent)
  REAL NO3_TOT, NH4_TOT
  REAL P_TOT, K_TOT
  
  ! Uptake by plants (kg/ha)
  REAL NO3_UPTAKE, NH4_UPTAKE
  REAL P_UPTAKE, K_UPTAKE
  
  ! Additions from fertilizer (kg/ha)
  REAL FERT_NO3, FERT_NH4
  REAL FERT_P, FERT_K
  
  ! Losses
  REAL NO3_LOSS            ! Loss to drain (kg/ha)
  REAL NH4_VOLAT           ! Volatilization (kg/ha)
END TYPE SolutionNutrientsType
```

## Implementation Plan

### Phase 1: Core Infrastructure (Weeks 1-4)

#### 1.1 Create New Module Structure
- [ ] Create `Hydroponic/` directory
- [ ] Create `HYDRO.for` main module (similar structure to SOIL.for)
- [ ] Create `SolutionManagement/SOLBAL.for` (replaces WATBAL)
- [ ] Create basic `SolutionType` in `ModuleDefs.for`

#### 1.2 Modify ModuleDefs.for
- [ ] Add `SolutionType` definition
- [ ] Add `SolutionNutrientsType` definition
- [ ] Add hydroponic switches to `SwitchType`:
  ```fortran
  CHARACTER*1 ISWHYDRO    ! 'Y' = hydroponic, 'N' = soil
  CHARACTER*10 HYDROTYPE  ! 'RECIRC', 'DRAIN2WASTE', 'NFT', 'DWC'
  ```

#### 1.3 Create Solution Balance Module (SOLBAL.for)
**Purpose:** Replace WATBAL.for for hydroponic systems

**Key Functions:**
- Solution volume balance
- Water uptake by plants
- Solution evaporation
- Solution replacement/refresh
- Solution recirculation

**Interface:**
```fortran
SUBROUTINE SOLBAL(CONTROL, ISWITCH,
  &    EP, FERTDATA, IRRAMT, RLV,              !Input
  &    WEATHER, XHLAI,                         !Input
  &    SOLUTION,                               !I/O
  &    SOLVOL, SOLWITHDRAW, SOLEVAP,          !Output
  &    SOLREPLACE, YREND)                      !Output
```

**Key Calculations:**
```fortran
! Solution volume balance
SOLVOL = SOLVOL_YESTERDAY
  + IRRAMT * CONVERSION_FACTOR      ! Irrigation/water addition
  + FERT_WATER                       ! Water from fertilizer solution
  - SOLWITHDRAW                      ! Plant uptake
  - SOLEVAP                          ! Evaporation
  - SOLREPLACE                        ! Replacement/drain

! Plant water withdrawal (simplified - no soil layers)
SOLWITHDRAW = EP * CONVERSION_FACTOR * PLANT_DENSITY

! Solution evaporation (minimal in most systems)
SOLEVAP = ES * EVAP_FACTOR * EXPOSED_SOLUTION_AREA
```

### Phase 2: Nutrient Management (Weeks 5-8)

#### 2.1 Create Solution N Module (SOLNi.for)
**Purpose:** Replace SoilNi.for for hydroponic N management

**Key Differences from SoilNi:**
- ❌ No nitrification (or simplified)
- ❌ No denitrification (or minimal)
- ❌ No leaching (replaced by solution replacement)
- ❌ No soil adsorption
- ✅ Direct availability from solution
- ✅ Simple N balance

**Interface:**
```fortran
SUBROUTINE SOLNi(CONTROL, ISWITCH,
  &    FERTDATA, UNH4, UNO3, WEATHER,          !Input
  &    SOLUTION,                               !I/O
  &    NH4_plant, NO3_plant, UPPM)             !Output
```

**Key Calculations:**
```fortran
! N concentration in solution (mg/L)
NO3_CONC = NO3_TOT / SOLVOL * 1000.0
NH4_CONC = NH4_TOT / SOLVOL * 1000.0

! Plant-available N (kg/ha equivalent)
NO3_plant = NO3_CONC * SOLVOL / GROWING_AREA * CONVERSION
NH4_plant = NH4_CONC * SOLVOL / GROWING_AREA * CONVERSION

! N balance
NO3_TOT = NO3_TOT_YESTERDAY
  + FERT_NO3                    ! From fertilizer
  - UNO3                        ! Plant uptake
  - NO3_LOSS                   ! Solution replacement loss

NH4_TOT = NH4_TOT_YESTERDAY
  + FERT_NH4                   ! From fertilizer
  - UNH4                        ! Plant uptake
  - NH4_VOLAT                  ! Volatilization (if pH high)
  - NH4_LOSS                   ! Solution replacement loss
```

#### 2.2 Create Solution P Module (SOLPi.for)
**Purpose:** Replace SoilPi.for

**Key Differences:**
- ❌ No soil P adsorption/desorption
- ❌ No P fixation
- ✅ Direct availability
- ✅ Simple P balance

#### 2.3 Create Solution K Module (SOLKi.for)
**Purpose:** Replace SoilKi.for

**Key Differences:**
- ❌ No soil K fixation
- ✅ Direct availability
- ✅ Simple K balance

#### 2.4 Create Micronutrient Module (SOLMICRO.for)
**Purpose:** New module for micronutrients (Fe, Mn, Zn, Cu, B, Mo)

### Phase 3: Solution Chemistry (Weeks 9-12)

#### 3.1 EC Management (SOLEC.for)
**Purpose:** Manage electrical conductivity

**Key Functions:**
- Calculate EC from nutrient concentrations
- Monitor EC changes
- EC-based solution refresh triggers

**Calculations:**
```fortran
! EC from nutrient concentrations (simplified)
EC = (NO3_CONC + NH4_CONC + K_CONC + CA_CONC + MG_CONC) 
     * EC_CONVERSION_FACTOR

! Or use measured EC if available
! EC = MEASURED_EC
```

#### 3.2 pH Management (SOLPH.for)
**Purpose:** Manage solution pH

**Key Functions:**
- pH changes from nutrient uptake
- pH adjustment (acid/base addition)
- pH effects on nutrient availability

**Calculations:**
```fortran
! pH changes from plant nutrient uptake
! Cations (NH4+, K+, Ca2+, Mg2+) uptake → pH decreases
! Anions (NO3-, H2PO4-, SO4-) uptake → pH increases

PH_CHANGE = (ANION_UPTAKE - CATION_UPTAKE) * PH_BUFFER_CAPACITY
PH = PH_YESTERDAY + PH_CHANGE + PH_ADJUSTMENT
```

#### 3.3 Dissolved Oxygen (SOLO2.for)
**Purpose:** Manage dissolved oxygen (important for root health)

**Key Functions:**
- DO2 changes from aeration
- DO2 consumption by roots
- DO2 effects on root function

### Phase 4: Integration with Main System (Weeks 13-16)

#### 4.1 Modify LAND.for
**Replace SOIL call with conditional HYDRO/SOIL:**

```fortran
IF (ISWHYDRO == 'Y') THEN
  CALL HYDRO(CONTROL, ISWITCH,
    &    EP, FERTDATA, FracRts, HARVRES, IRRAMT,    !Input
    &    KTRANS, KUptake, PUptake, RLV,            !Input
    &    SENESCE, ST, UNH4, UNO3,                  !Input
    &    WEATHER, XHLAI,                           !Input
    &    SOLUTION,                                 !I/O
    &    NH4_plant, NO3_plant, SKi_AVAIL,          !Output
    &    SPi_AVAIL, SOLPROP, SW, YREND)            !Output
ELSE
  CALL SOIL(...)  ! Existing soil code
ENDIF
```

**Key Changes:**
- Remove ES (soil evaporation) for hydroponic
- Remove SWDELTS, SWDELTU (soil water changes)
- Remove SOILPROP, replace with SOLPROP
- Remove SNOW, MULCH, FLOODWAT, FLOODN
- Simplify SW to single value or remove

#### 4.2 Modify SPAM (Soil-Plant-Atmosphere)
**For Hydroponic:**
- Remove soil evaporation (ES)
- Keep transpiration (EP)
- Modify root water uptake calculation
- Remove soil water stress (always non-limiting in solution)

#### 4.3 Modify Plant Interfaces
**Minimal changes needed if we maintain same output variables:**
- `NH4_plant`, `NO3_plant` - Keep same interface
- `SPi_AVAIL`, `SKi_AVAIL` - Keep same interface
- `SW` - May need to convert to solution availability
- `SOILPROP` → `SOLPROP` - New structure, but similar data

**For plants that use soil layers:**
- Convert layer-based to single solution or simplified zones
- Or create "virtual layers" based on solution zones

### Phase 5: Input/Output (Weeks 17-20)

#### 5.1 Create Input Module (IPSOL.for)
**Purpose:** Read hydroponic solution data from FileX

**New FileX Sections:**
```fortran
*HYDROPONIC SOLUTION
@H HYDROTYPE  SOLVOL  SOLTARGET_EC  SOLTARGET_PH  SOLREFRESH_RATE
 1 RECIRC      1000.0   2.5           6.0           0.10

*SOLUTION INITIAL CONDITIONS
@S SOLVOL  EC   PH   DO2  TEMP  NO3_CONC  NH4_CONC  P_CONC  K_CONC
 1 1000.0  2.0  6.0  8.0  20.0   150.0      20.0     50.0    200.0

*SOLUTION MANAGEMENT
@M MDATE  MOP  MVAL
 1 13015  EC   2.5    ! EC adjustment
 1 13020  PH   6.2    ! pH adjustment
 1 13025  REFR 0.20   ! 20% solution refresh
```

#### 5.2 Modify FileX Reader
- Add hydroponic sections to input parser
- Handle both soil and hydroponic formats
- Add validation for hydroponic data

#### 5.3 Create Output Module (OPSOL.for)
**Purpose:** Output solution data

**Output Variables:**
- Solution volume (L)
- EC, pH, DO2, temperature
- Nutrient concentrations (mg/L)
- Nutrient totals (kg/ha)
- Solution refresh events
- Water additions/withdrawals

### Phase 6: Testing and Validation (Weeks 21-24)

#### 6.1 Unit Testing
- Test each module independently
- Test solution balance calculations
- Test nutrient balance calculations
- Test EC/pH calculations

#### 6.2 Integration Testing
- Test with simple crop (e.g., lettuce)
- Compare with soil-based results (where applicable)
- Validate against published hydroponic data

#### 6.3 System Testing
- Test different hydroponic types (NFT, DWC, recirculating)
- Test solution refresh strategies
- Test EC/pH management
- Test nutrient management

## Key Design Decisions

### 1. Backward Compatibility
**Decision:** Maintain ability to run soil-based simulations
- Use `ISWHYDRO` switch to select mode
- Keep existing SOIL module intact
- Conditional compilation or runtime selection

### 2. Solution Representation
**Decision:** Single solution reservoir or multiple zones
- **Option A:** Single reservoir (simpler, good for most systems)
- **Option B:** Multiple zones (NFT channels, DWC buckets, etc.)
- **Recommendation:** Start with single, add zones later if needed

### 3. Nutrient Availability Interface
**Decision:** How to present nutrients to plant module
- **Option A:** Keep layer-based (create virtual layers)
- **Option B:** Convert to total availability (simpler)
- **Recommendation:** Option B - convert to kg/ha total availability

### 4. Water Stress
**Decision:** How to handle water stress in hydroponic
- **Option A:** Always non-limiting (solution always available)
- **Option B:** Model solution depletion stress
- **Recommendation:** Option B - model depletion for realism

### 5. Root Interface
**Decision:** How roots interact with solution
- **Option A:** Simplified - direct access
- **Option B:** Model root zone in solution
- **Recommendation:** Option A initially, Option B for advanced

## Files to Modify

### New Files to Create
1. `Hydroponic/HYDRO.for`
2. `Hydroponic/SolutionManagement/SOLBAL.for`
3. `Hydroponic/SolutionManagement/SOLRECIRC.for`
4. `Hydroponic/SolutionManagement/SOLREFRESH.for`
5. `Hydroponic/SolutionManagement/SOLTEMP.for`
6. `Hydroponic/SolutionNutrients/SOLNi.for`
7. `Hydroponic/SolutionNutrients/SOLPi.for`
8. `Hydroponic/SolutionNutrients/SOLKi.for`
9. `Hydroponic/SolutionNutrients/SOLMICRO.for`
10. `Hydroponic/SolutionChemistry/SOLEC.for`
11. `Hydroponic/SolutionChemistry/SOLPH.for`
12. `Hydroponic/SolutionChemistry/SOLO2.for`
13. `Hydroponic/SolutionUtilities/IPSOL.for`
14. `Hydroponic/SolutionUtilities/OPSOL.for`

### Files to Modify
1. `Utilities/ModuleDefs.for` - Add new types
2. `CSM_Main/LAND.for` - Add conditional HYDRO/SOIL call
3. `InputModule/INSOIL.for` - Add hydroponic input reading
4. `InputModule/SESOIL.for` - Add hydroponic input reading
5. `SPAM/SPAM.for` - Modify for hydroponic (remove ES)
6. `CMakeLists.txt` - Add new source files

### Files to Keep (No Changes)
- All Plant modules (minimal changes needed)
- Weather module
- Management module (fertilizer applications)
- Most utility modules

## Implementation Checklist

### Phase 1: Infrastructure
- [ ] Create Hydroponic directory structure
- [ ] Add SolutionType to ModuleDefs.for
- [ ] Add ISWHYDRO switch
- [ ] Create HYDRO.for skeleton
- [ ] Create SOLBAL.for skeleton

### Phase 2: Core Functionality
- [ ] Implement solution volume balance
- [ ] Implement plant water withdrawal
- [ ] Implement solution refresh
- [ ] Test solution balance

### Phase 3: Nutrients
- [ ] Implement SOLNi.for
- [ ] Implement SOLPi.for
- [ ] Implement SOLKi.for
- [ ] Test nutrient balances

### Phase 4: Chemistry
- [ ] Implement SOLEC.for
- [ ] Implement SOLPH.for
- [ ] Implement SOLO2.for
- [ ] Test chemistry calculations

### Phase 5: Integration
- [ ] Modify LAND.for
- [ ] Modify SPAM.for
- [ ] Test integration
- [ ] Validate with test crop

### Phase 6: I/O
- [ ] Create IPSOL.for
- [ ] Create OPSOL.for
- [ ] Modify FileX reader
- [ ] Test input/output

### Phase 7: Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] Validation tests
- [ ] Documentation

## Risk Assessment

### High Risk
1. **Plant Module Compatibility** - Plants may expect soil layers
   - **Mitigation:** Create adapter layer or modify plant interfaces
   
2. **Root Water Uptake** - Current models assume soil
   - **Mitigation:** Simplify or create hydroponic-specific root model

3. **Nutrient Uptake** - Current models may use soil-specific equations
   - **Mitigation:** Review and adapt nutrient uptake equations

### Medium Risk
1. **Solution Temperature** - May need greenhouse/environmental model
   - **Mitigation:** Start with simple temperature model

2. **EC/pH Interactions** - Complex chemistry
   - **Mitigation:** Start with simplified models, add complexity later

### Low Risk
1. **Input/Output** - Straightforward file format changes
2. **Documentation** - Standard documentation tasks

## Success Criteria

1. ✅ Can run hydroponic simulation without soil
2. ✅ Solution balance is correct (mass balance closes)
3. ✅ Nutrient balance is correct
4. ✅ Plant growth is reasonable (compare to soil or literature)
5. ✅ EC and pH management works
6. ✅ Solution refresh works correctly
7. ✅ Can handle different hydroponic types
8. ✅ Backward compatible (soil still works)

## Next Steps

1. **Review this plan** with team/stakeholders
2. **Set up development environment** with version control
3. **Create feature branch** for hydroponic development
4. **Start Phase 1** - Infrastructure setup
5. **Regular progress reviews** - Weekly checkpoints

## References

- DSSAT-CSM Source Code
- Hydroponic system literature
- Nutrient solution management guides
- EC/pH management in hydroponics

---

**Document Version:** 1.0  
**Date:** 2025-01-XX  
**Author:** AI Assistant  
**Status:** Draft - Pending Review

