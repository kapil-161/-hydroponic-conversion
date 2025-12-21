# Hydroponic vs Soil: Key Differences and Removal Guide

## Quick Reference: What to Remove vs What to Replace

### ❌ REMOVE (Not Needed in Hydroponic)

| Component | Location | Reason |
|-----------|----------|--------|
| **Infiltration** | `Soil/SoilWater/INFIL.for` | No soil to infiltrate into |
| **Drainage** | `Soil/SoilWater/WATBAL.for` | Replaced by solution replacement |
| **Runoff** | `Soil/SoilWater/RNOFF.for` | No surface runoff in hydroponic |
| **Soil Evaporation (ES)** | `SPAM/SPAM.for` | No soil surface to evaporate |
| **Capillary Rise** | `Soil/SoilWater/WBSUBS.for` | No soil water movement |
| **Water Table** | `Soil/SoilWater/WaterTable.f90` | Not applicable |
| **Tiledrain** | `Soil/SoilWater/TILEDRAIN.for` | Not applicable |
| **Soil Organic Matter** | `Soil/CENTURY_OrganicMatter/` | No organic matter in solution |
| **Soil Organic Matter** | `Soil/CERES_OrganicMatter/` | No organic matter in solution |
| **Tillage** | `Management/Tillage/` | No soil to till |
| **Mulch** | `Soil/Mulch/` | Optional - may keep for some systems |
| **Soil Texture** | `Soil/SoilUtilities/SOILDYN.for` | No texture in solution |
| **Bulk Density** | `Soil/SoilUtilities/SOILDYN.for` | Not applicable |
| **Porosity** | `Soil/SoilUtilities/SOILDYN.for` | Not applicable |
| **Soil Adsorption** | `Soil/Inorganic_P/SoilPi.for` | Direct availability in solution |
| **P Fixation** | `Soil/Inorganic_P/SoilPi.for` | Not applicable |
| **K Fixation** | `Soil/Inorganic_K/SoilKi.for` | Not applicable |
| **Nitrification** | `Soil/Inorganic_N/SoilNi.for` | Minimal or simplified |
| **Denitrification** | `Soil/Inorganic_N/SoilNi.for` | Minimal |
| **N Leaching** | `Soil/Inorganic_N/SoilNi.for` | Replaced by solution replacement |
| **Snow** | `Soil/SoilWater/WATBAL.for` | Not applicable |
| **Flood Water** | `Soil/FloodN/` | Not applicable (unless flood-and-drain) |

### ✅ REPLACE (Need Hydroponic Equivalent)

| Soil Component | Location | Hydroponic Replacement | New Location |
|----------------|----------|------------------------|--------------|
| **SOIL.for** | `Soil/SOIL.for` | **HYDRO.for** | `Hydroponic/HYDRO.for` |
| **WATBAL** | `Soil/SoilWater/WATBAL.for` | **SOLBAL** | `Hydroponic/SolutionManagement/SOLBAL.for` |
| **SoilNi** | `Soil/Inorganic_N/SoilNi.for` | **SOLNi** | `Hydroponic/SolutionNutrients/SOLNi.for` |
| **SoilPi** | `Soil/Inorganic_P/SoilPi.for` | **SOLPi** | `Hydroponic/SolutionNutrients/SOLPi.for` |
| **SoilKi** | `Soil/Inorganic_K/SoilKi.for` | **SOLKi** | `Hydroponic/SolutionNutrients/SOLKi.for` |
| **SOILDYN** | `Soil/SoilUtilities/SOILDYN.for` | **SOLPROP** | `Hydroponic/SolutionUtilities/SOLPROP.for` |
| **IPSOIL** | `Soil/SoilUtilities/IPSOIL.for` | **IPSOL** | `Hydroponic/SolutionUtilities/IPSOL.for` |
| **SoilType** | `Utilities/ModuleDefs.for` | **SolutionType** | `Utilities/ModuleDefs.for` |

### ➕ ADD (New for Hydroponic)

| New Component | Purpose | Location |
|---------------|---------|----------|
| **SOLEC** | EC management | `Hydroponic/SolutionChemistry/SOLEC.for` |
| **SOLPH** | pH management | `Hydroponic/SolutionChemistry/SOLPH.for` |
| **SOLO2** | Dissolved oxygen | `Hydroponic/SolutionChemistry/SOLO2.for` |
| **SOLRECIRC** | Solution recirculation | `Hydroponic/SolutionManagement/SOLRECIRC.for` |
| **SOLREFRESH** | Solution refresh/replacement | `Hydroponic/SolutionManagement/SOLREFRESH.for` |
| **SOLTEMP** | Solution temperature | `Hydroponic/SolutionManagement/SOLTEMP.for` |
| **SOLMICRO** | Micronutrients | `Hydroponic/SolutionNutrients/SOLMICRO.for` |

## Detailed Comparison

### Water Balance

#### Soil System (Current)
```
Water Balance:
  Input:  RAIN + IRRIGATION
  Output: DRAINAGE + RUNOFF + EVAPORATION (ES) + TRANSPIRATION (EP)
  Storage: SOIL WATER (SW) in layers
  Processes: Infiltration, percolation, capillary rise
```

#### Hydroponic System (Proposed)
```
Solution Balance:
  Input:  WATER ADDITION + FERTILIZER WATER
  Output: PLANT UPTAKE + EVAPORATION + SOLUTION REPLACEMENT
  Storage: SOLUTION VOLUME (SOLVOL)
  Processes: Recirculation, refresh, direct uptake
```

### Nutrient Availability

#### Soil System (Current)
```
Nutrients:
  - Stored in soil layers (NH4, NO3, P, K per layer)
  - Subject to adsorption/desorption
  - Subject to fixation (P, K)
  - Subject to transformation (nitrification, denitrification)
  - Subject to leaching
  - Available based on soil properties and root distribution
```

#### Hydroponic System (Proposed)
```
Nutrients:
  - Stored in solution (concentrations in mg/L)
  - Directly available (no adsorption)
  - No fixation
  - Minimal transformation (simplified nitrification)
  - Lost through solution replacement (not leaching)
  - Available based on solution concentration and volume
```

### Key Process Differences

| Process | Soil | Hydroponic |
|---------|------|------------|
| **Water Movement** | Infiltration, percolation, capillary rise | Recirculation, direct uptake |
| **Nutrient Availability** | Adsorption, desorption, fixation | Direct availability |
| **Nutrient Loss** | Leaching, denitrification | Solution replacement |
| **Water Stress** | Based on soil water content | Based on solution availability |
| **Nutrient Stress** | Based on soil concentration + root access | Based on solution concentration |
| **Temperature** | Soil temperature (layered) | Solution temperature (single or zoned) |
| **pH Effects** | pH affects nutrient availability via soil chemistry | pH affects nutrient availability directly |
| **EC/Salinity** | Soil EC affects plant growth | Solution EC directly controls growth |

## Code Removal Checklist

### Files to Remove/Disable for Hydroponic Mode

#### Soil Water Processes
- [ ] `Soil/SoilWater/INFIL.for` - Infiltration
- [ ] `Soil/SoilWater/RNOFF.for` - Runoff
- [ ] `Soil/SoilWater/TILEDRAIN.for` - Tile drainage
- [ ] `Soil/SoilWater/WaterTable.f90` - Water table
- [ ] `Soil/SoilWater/WBSUBS.for` - Capillary rise
- [ ] `Soil/SoilWater/SATFLO.for` - Saturated flow (if not needed)

#### Soil Organic Matter
- [ ] `Soil/CENTURY_OrganicMatter/` - Entire directory
- [ ] `Soil/CERES_OrganicMatter/` - Entire directory

#### Soil Properties
- [ ] Texture calculations in `Soil/SoilUtilities/SOILDYN.for`
- [ ] Bulk density effects
- [ ] Porosity calculations (keep concept for solution volume)

#### Soil-Specific Nutrient Processes
- [ ] P adsorption in `Soil/Inorganic_P/SoilPi.for`
- [ ] K fixation in `Soil/Inorganic_K/SoilKi.for`
- [ ] Complex nitrification (simplify in hydroponic)
- [ ] Denitrification (minimal in hydroponic)

#### Management
- [ ] `Management/Tillage/` - Tillage operations
- [ ] `Soil/Mulch/` - Mulch (optional - may keep)

### Code Sections to Modify

#### In LAND.for
```fortran
! REMOVE or CONDITIONAL:
CALL SOIL(...)  ! Replace with conditional HYDRO/SOIL

! REMOVE for hydroponic:
- SNOW
- MULCH
- FLOODWAT
- FLOODN
- TILLVALS
- ES (soil evaporation)
```

#### In SPAM.for
```fortran
! REMOVE for hydroponic:
- ES (soil evaporation) calculation
- Soil water stress (always non-limiting in solution)
- Root water uptake from soil layers (replace with solution uptake)
```

#### In ModuleDefs.for
```fortran
! ADD:
TYPE SolutionType
  ! ... (see plan document)
END TYPE

! MODIFY SwitchType:
CHARACTER*1 ISWHYDRO
CHARACTER*10 HYDROTYPE
```

## Migration Strategy

### Option 1: Conditional Compilation
- Use preprocessor directives to include/exclude code
- Pros: Clean separation, smaller executable
- Cons: More complex build system

### Option 2: Runtime Selection
- Use ISWHYDRO switch to select at runtime
- Pros: Single executable, easier testing
- Cons: Larger executable, some unused code

### Option 3: Separate Modules
- Create completely separate hydroponic branch
- Pros: Clean separation, no conflicts
- Cons: Code duplication, maintenance overhead

**Recommendation:** Option 2 (Runtime Selection) - Most flexible and maintainable

## Interface Compatibility

### Maintaining Plant Module Compatibility

**Challenge:** Plant modules expect:
- `SW(NL)` - Soil water by layer
- `NH4_plant(NL)`, `NO3_plant(NL)` - Nutrients by layer
- `SOILPROP` - Soil properties structure

**Solution Options:**

1. **Adapter Layer** - Convert solution to layer format
   ```fortran
   ! In HYDRO.for
   DO L = 1, NLAYR
     SW(L) = SOLVOL / (NLAYR * LAYER_VOLUME)  ! Distribute evenly
     NH4_plant(L) = NH4_CONC * CONVERSION
     NO3_plant(L) = NO3_CONC * CONVERSION
   ENDDO
   ```

2. **Modify Plant Interface** - Add solution-aware interface
   ```fortran
   ! New interface
   IF (ISWHYDRO == 'Y') THEN
     CALL PLANT_HYDRO(..., SOLUTION, ...)
   ELSE
     CALL PLANT_SOIL(..., SOILPROP, SW, ...)
   ENDIF
   ```

3. **Virtual Layers** - Create solution zones as "layers"
   ```fortran
   ! Solution zones as virtual layers
   SW(1) = RESERVOIR_VOL
   SW(2) = ROOT_ZONE_VOL
   SW(3) = DRAIN_ZONE_VOL
   ```

**Recommendation:** Start with Option 1 (Adapter), migrate to Option 2 if needed

## Testing Strategy

### Unit Tests
1. Solution balance (volume in = volume out + storage change)
2. Nutrient balance (nutrients in = nutrients out + storage change)
3. EC calculation from concentrations
4. pH calculation from nutrient uptake

### Integration Tests
1. Full hydroponic simulation with simple crop
2. Solution refresh cycle
3. EC/pH management
4. Nutrient management

### Validation Tests
1. Compare to published hydroponic data
2. Compare to soil-based results (where applicable)
3. Mass balance checks
4. Nutrient balance checks

## Summary

**Key Takeaway:** 
- Remove ~40% of soil-specific code
- Replace ~30% with hydroponic equivalents
- Add ~30% new hydroponic-specific code
- Maintain ~90% of plant code (minimal changes)

**Complexity:** Medium-High
- Significant architectural changes
- But clear separation of concerns
- Well-defined interfaces

**Timeline:** 20-24 weeks (5-6 months) for full implementation

