---
title: "Water Uptake Dynamics in Hydroponic Lettuce Systems: Transpiration-Driven Flow, Solution Volume Management, and Implementation in the DSSAT Hydroponic Model"
author: "Kapil Bhattarai"
date: "April 2026"
---

# Abstract

Water uptake in hydroponic systems is fundamentally different from soil-based systems: the nutrient solution provides an essentially unlimited water supply to roots at all times, eliminating classical soil water stress as a limiting factor in crop growth. For lettuce (*Lactuca sativa* L.) grown in recirculating hydroponic systems, actual water uptake equals the potential transpiration demand, and the primary management challenge shifts from water availability to solution volume and nutrient concentration dynamics. This report describes the mechanisms of water uptake in hydroponic systems, with emphasis on the transpiration-driven mass flow of water and nutrients, solution volume tracking using the unit equivalence of millimeters depth and liters per square meter, the distinction between constant-volume (AUTO_VOL) and free-drift management modes, and the concentration effect arising from water loss without nutrient replenishment. The HYDRO_WATER module in the DSSAT hydroponic model implements these principles in a prognostic daily framework that tracks solution depth as a state variable, updates it for plant uptake and evaporation losses, and maintains nutrient concentrations in mass balance. Transpiration is sourced directly from the SPAM module (potential evapotranspiration partitioning), and water supply is set unconditionally equal to demand — reflecting the hydroponic system design assumption that solution volume is always adequate.

**Keywords:** water uptake, hydroponics, lettuce, transpiration, solution volume, nutrient concentration, mass balance, DSSAT, crop simulation, AUTO_VOL

---

# 1. Introduction

Water management in hydroponic systems differs fundamentally from field or greenhouse soil production. In soil, water availability is a primary growth-limiting factor mediated by soil hydraulic properties, root architecture, and atmospheric demand. Crop simulation models for soil systems therefore maintain elaborate water balance modules tracking infiltration, redistribution, evaporation, and root extraction from multiple soil layers (Jones et al., 1998). In hydroponic systems, roots are maintained in continuous contact with a free-flowing nutrient solution, and the rate-limiting step for water uptake is the plant's transpiration demand rather than the supply from the medium (Silberbush et al., 2005).

This architectural difference has profound implications for modeling. In a hydroponic model, the water balance simplifies to: (1) plant uptake equals transpiration demand at all times; (2) the solution volume decreases as water is removed by transpiration and minor evaporative losses; and (3) dissolved nutrients concentrate as solution volume decreases, modifying the chemical environment for root uptake (Sonneveld & Voogt, 2009). Management practices — whether to replenish the solution continuously (constant-volume, or AUTO_VOL mode) or allow concentration to develop until a scheduled solution change (free-drift mode) — determine how rapidly nutrient concentrations evolve over the growing cycle.

The DSSAT hydroponic model (based on the CROPGRO-Lettuce framework) includes a dedicated water module (HYDRO_WATER) that tracks solution depth as a prognostic daily state variable, computing actual water uptake, solution evaporation, and optional volume refill, and maintaining concentration mass balance for dissolved N, P, and K. This report describes the theoretical basis, design decisions, and implementation of this module.

---

# 2. Transpiration as the Driver of Water Uptake

## 2.1 The Transpiration Demand Framework

In hydroponic systems, plant water uptake is driven entirely by the atmospheric evaporative demand and the capacity of the leaf canopy to transpire (Stanghellini, 1987). The potential transpiration rate (EP, mm day⁻¹) is calculated upstream in the DSSAT model by the SPAM (Soil-Plant-Atmosphere Model) module, which partitions reference evapotranspiration (ETo) between canopy transpiration and soil (or solution surface) evaporation based on leaf area index (LAI):

$$EP = ETo \times \left(1 - e^{-k \cdot LAI}\right)$$

where *k* is the light extinction coefficient (typically 0.65 for lettuce). In soil models, actual transpiration (TRWU) may be less than potential (TRWUP) when soil water supply is insufficient. In the hydroponic module, this constraint is removed: actual uptake equals potential demand because the solution always provides adequate water at the root surface.

$$TRWU = TRWUP = EP$$

This assumption is supported by the design principle of recirculating hydroponic systems (NFT, deep water culture, ebb-and-flow), in which root exposure to the nutrient solution is continuous and the solution volume is maintained well above the daily transpiration demand (Resh, 2013). The only exception would be equipment failure or extreme solution depletion, handled by the minimum volume floor of 5.0 mm in the HYDRO_WATER module.

## 2.2 Absence of Water Stress Factor

In soil-based DSSAT modules, a water uptake factor (WUF) scales actual uptake and associated growth processes:

$$WUF = \frac{TRWU}{TRWUP}$$

In HYDRO_WATER, WUF is set unconditionally to 1.0. Ionic stress from high electrical conductivity (EC) of the nutrient solution — which in soil systems would manifest partly as osmotic stress reducing water uptake — is handled separately in the SOLEC module through kinetic suppression of nutrient transporter activity (J_max and K_m modifications), not through reduction of the water uptake factor. This separation reflects the experimental observation that hydroponic lettuce maintains near-normal water uptake rates at EC values that substantially suppress nutrient uptake, because osmotic adjustment is a slower process than transporter inhibition (Munns & Tester, 2008).

---

# 3. Solution Volume and Units

## 3.1 The mm = L/m² Equivalence

The HYDRO_WATER module represents solution volume as a depth in millimeters (SOLVOL_MM). This follows the agronomic convention that 1 mm of water depth over 1 m² of growing area corresponds to 1 liter of solution:

$$V_L = SOLVOL_{mm} \times A_{m^2}$$

where *V*_L is the solution volume in liters and *A* is the growing area in m². For a 100 m² greenhouse bay holding solution at a depth of 100 mm, V_L = 10,000 L = 10 m³. The mm representation is computationally convenient because it parallels the representation of precipitation and evapotranspiration in standard DSSAT soil modules, enabling consistent unit handling throughout the model framework.

## 3.2 Solution Depth as a State Variable

The solution depth SOLVOL_MM is a prognostic state variable updated at each daily INTEGR timestep:

$$SOLVOL_{t+1} = SOLVOL_t + W_{add} - W_{plant} - W_{evap}$$

where *W*_add is the water added by irrigation or refill (mm day⁻¹), *W*_plant is the plant uptake (= EP, mm day⁻¹), and *W*_evap is the solution surface evaporation (mm day⁻¹). A minimum floor of 5.0 mm (5 L m⁻²) is enforced to prevent numerical instability in nutrient concentration calculations.

---

# 4. Solution Evaporation

Solution surface evaporation from hydroponic systems is substantially smaller than canopy transpiration. In NFT and deep water culture channels, the solution surface is largely shaded by the plant canopy, and in covered substrate systems the solution is not exposed to the atmosphere at all. The HYDRO_WATER module estimates solution evaporation as 1% of the plant transpiration rate:

$$W_{evap} = 0.01 \times EP$$

This approximation is appropriate for mature lettuce canopies (LAI > 2) where canopy shading of the solution surface is high (Bugbee, 2004). At the seedling stage, when LAI is low and solution exposure is greater, the actual evaporation fraction may be higher; however, the overall effect on the solution balance is small relative to transpiration and is not the primary focus of model sensitivity. The output variable ES (soil evaporation, used by DSSAT SPAM) is set to 0.0, as there is no soil in the hydroponic system.

---

# 5. Volume Management Modes

## 5.1 AUTO_VOL = Y: Constant-Volume Refill Mode

When the AUTO_VOL flag is set to Y (AUTO_VOL_R = 1.0), the module adds fresh water (and implicitly nutrients, in the full management model) each day to restore the solution to its initial volume SOLVOL_INIT_MM:

$$W_{add} = SOLVOL_{INIT} - SOLVOL_{prev} + W_{plant} + W_{evap}$$

This represents the management practice of topping up the reservoir daily from a stock solution to maintain constant volume and nutrient concentration. Under this mode, SOLVOL remains approximately constant and nutrient concentrations are determined primarily by the initial recipe and the daily uptake rate, not by progressive concentration from water loss. This is the default mode for standard agronomic simulations and reflects typical commercial practice in lettuce NFT production (Sonneveld & Voogt, 2009).

## 5.2 AUTO_VOL = N: Free-Drift Mode

When AUTO_VOL = N (AUTO_VOL_R = 0.0), no water is added between solution change events (W_add = 0.0), and SOLVOL decreases each day by plant transpiration plus evaporation:

$$SOLVOL_{t+1} = SOLVOL_t - W_{plant} - W_{evap}$$

Volume decreases at the rate of approximately 2–6 mm day⁻¹ for lettuce at typical transpiration rates. Over a 7-day drift period, a 100 mm initial volume might decrease to 75–85 mm, concentrating dissolved nutrients by 18–33%. This mode is used for research simulations investigating the effect of solution management frequency on growth and nutrient use efficiency.

---

# 6. Concentration Effect from Water Loss

## 6.1 Mass Conservation Principle

When plant transpiration removes water from the solution without simultaneously removing dissolved nutrients (since transpiration is essentially pure water), the concentrations of all dissolved ions increase proportionally. This is governed by the law of conservation of mass:

$$C_{new} = C_{old} \times \frac{V_{old}}{V_{new}}$$

The ratio *V*_old/*V*_new is the concentration factor (CONC_FACTOR ≥ 1.0). This applies identically to NO₃⁻, NH₄⁺, P, and K⁺ in the current model.

## 6.2 Implementation

At each INTEGR timestep, after the solution volume is updated, HYDRO_WATER checks whether volume has decreased (SOLVOL_PREV > SOLVOL_CURRENT) and applies the concentration factor:

$$CONC\_FACTOR = \frac{SOLVOL_{prev}}{SOLVOL_{new}}$$

All four tracked nutrient concentrations (NO3_CONC, NH4_CONC, P_CONC, K_CONC) in the ModuleData shared memory are multiplied by CONC_FACTOR. This step occurs before the nutrient uptake modules (HYDRO_NUTRIENT, SOLPi, SOLKi) deplete the concentrations in the same INTEGR phase, ensuring that uptake kinetics see the post-concentration solution state. The mass balance is therefore:

$$C_{final} = \frac{C_{old} \times V_{old} - \Delta U}{V_{new}}$$

where ΔU is the mass removed by uptake (g ha⁻¹ converted to mg L⁻¹). Computing concentration first and depletion second yields the same result as a simultaneous calculation when volume change and uptake occur at the same timestep.

---

# 7. Transpiration and Passive Nutrient Mass Flow

## 7.1 Transpiration Stream Delivery

Beyond its role in water balance, transpiration creates a mass flow of dissolved nutrients from the bulk solution to the root surface. In soil systems, this mass flow contributes to nutrient supply alongside diffusion. In hydroponic systems — where solution mixing ensures near-uniform concentrations — the transpiration stream delivers nutrients at the rate:

$$J_{mass\_flow,i} = EP \times C_i$$

where *C*_i is the concentration of ion *i* in the solution (converted to appropriate units). For calcium (Ca²⁺) in the Silberbush et al. (2005) model, passive uptake via the transpiration stream is the primary uptake mechanism, parameterized as a fraction β of the transpiration-delivered flux reaching the xylem. For N, P, and K in the current DSSAT model, active Michaelis–Menten uptake dominates and mass flow via transpiration is implicitly represented through the concentration effect: as transpiration reduces solution volume, ion concentrations rise, increasing kinetic uptake rates. The transpiration rate EP is stored in ModuleData for potential use by nutrient uptake modules in mass flow calculations.

---

# 8. Implementation in the DSSAT Hydroponic Model: HYDRO_WATER Module

## 8.1 Module Structure

HYDRO_WATER is a Fortran-90 subroutine called from the SPAM module at each daily timestep. It operates through the standard DSSAT simulation phases:

- **RUNINIT/SEASINIT**: Reads initial solution depth (SOLVOL) from the experiment file via ModuleData GET, saves SOLVOL_INIT for AUTO_VOL refill target, reads AUTO_VOL flag.
- **RATE**: Computes potential water uptake (TRWUP = EP × 0.1, in cm day⁻¹) and stores TRWUP_MM for the INTEGR phase. EP is 0.0 at RATE call time in the DSSAT execution sequence; SPAM RATE overrides TRWU = EP before the INTEGR phase begins.
- **INTEGR**: Executes the full water balance: computes actual uptake, applies volume update, enforces minimum floor, applies concentration factor to nutrient pools, stores updated SOLVOL.
- **SEASEND**: Reports initial and final solution volumes.

## 8.2 ModuleData Communication

All inter-module state variables are communicated through the DSSAT ModuleData shared memory structure using GET and PUT calls. The key state variables managed by HYDRO_WATER are:

| Variable | Direction | Units | Description |
|---|---|---|---|
| SOLVOL | GET/PUT | mm | Solution depth (state variable) |
| SOLVOL_INIT | PUT | mm | Initial depth (AUTO_VOL target) |
| AUTO_VOL | GET | — | Volume mode flag (1.0=constant, 0.0=drift) |
| AREA | GET | m² | Growing area |
| EP | PUT | mm/d | Transpiration (for nutrient modules) |
| TRWUP_MM | PUT | mm/d | Potential supply (diagnostic) |
| NO3_CONC, NH4_CONC, P_CONC, K_CONC | GET/PUT | mg/L | Nutrient concentrations updated for concentration effect |

## 8.3 Output Variables

HYDRO_WATER returns three variables to the calling SPAM module:
- **TRWUP** (cm day⁻¹): Potential water uptake — equals EP (unlimited supply)
- **TRWU** (cm day⁻¹): Actual water uptake — equals TRWUP (no water stress)
- **ES** (mm day⁻¹): Solution evaporation returned as 0.0 (no soil in hydroponic system; surface evaporation is handled internally)

---

# 9. Discussion

The HYDRO_WATER design reflects a deliberate simplification: water is not a stress variable in hydroponic systems designed and managed correctly. This contrasts with soil models where elaborate root extraction functions, soil hydraulic conductivity terms, and soil-plant-atmosphere continuum models are required. The simplification is scientifically justified for well-managed hydroponics but introduces an important modeling boundary condition: the minimum volume floor (5.0 mm) is a numerical safeguard, not a physically motivated stress function. Plants approaching solution exhaustion in practice would experience progressive osmotic and nutrient stress well before the tank runs completely dry; capturing this would require a volume-dependent stress function, which is beyond the current model scope.

The 1% solution evaporation factor is a coarse approximation. In practice, evaporation from hydroponic channels depends on solution temperature, air humidity, channel geometry, and canopy cover. Stanghellini (1987) showed that for NFT lettuce at LAI > 3, canopy resistance to solution evaporation is high enough that the 1% approximation is reasonable. At early growth stages (LAI < 1), evaporation could represent 5–10% of ET. The current model does not scale solution evaporation with LAI; for long-duration crops this could introduce systematic volume errors.

The concentration effect calculation (Section 6) is a key mechanistic feature: without it, decreasing solution volume in drift mode would cause nutrient uptake to decrease simply because the volume floor is approached, rather than because concentrations have risen sufficiently to sustain kinetic uptake. The explicit CONC_FACTOR ensures that the mass balance is conserved correctly regardless of volume trajectory.

---

# 10. Conclusion

Water uptake in hydroponic lettuce systems is transpiration-driven and supply-unlimited, reducing the water balance to a solution volume tracking problem. The HYDRO_WATER module implements this by setting actual water uptake equal to potential transpiration demand (TRWU = TRWUP = EP), tracking solution depth in mm (1 mm = 1 L m⁻²) as a prognostic state variable, and applying a daily concentration factor to maintain nutrient mass balance as transpiration reduces solution volume. Two management modes are supported: constant-volume refill (AUTO_VOL = Y) for standard agronomic simulations, and free-drift (AUTO_VOL = N) for research investigations. The absence of a water stress factor (WUF = 1.0) reflects the fundamental hydroponic design principle that root water supply is unlimited, with ion stress handled separately through the EC and pH stress modules.

---

# References

Bugbee, B. (2004). Nutrient management in recirculating hydroponic culture. *Acta Horticulturae*, *648*, 99–112. https://doi.org/10.17660/ActaHortic.2004.648.12

Jones, J. W., Hoogenboom, G., Porter, C. H., Boote, K. J., Batchelor, W. D., Hunt, L. A., Wilkens, P. W., Singh, U., Gijsman, A. J., & Ritchie, J. T. (2003). The DSSAT cropping system model. *European Journal of Agronomy*, *18*(3–4), 235–265. https://doi.org/10.1016/S1161-0301(02)00107-7

Marschner, P. (Ed.). (2012). *Mineral nutrition of higher plants* (3rd ed.). Academic Press. https://doi.org/10.1016/B978-0-12-384905-2.00001-4

Munns, R., & Tester, M. (2008). Mechanisms of salinity tolerance. *Annual Review of Plant Biology*, *59*, 651–681. https://doi.org/10.1146/annurev.arplant.59.032607.092911

Resh, H. M. (2013). *Hydroponic food production: A definitive guidebook for the advanced home gardener and the commercial hydroponic grower* (7th ed.). CRC Press.

Silberbush, M., Ben-Asher, J., & Ephrath, J. E. (2005). A model for nutrient and water flow and their uptake by plants grown in a soilless culture. *Plant and Soil*, *271*(1–2), 309–319. https://doi.org/10.1007/s11104-004-3093-z

Sonneveld, C., & Voogt, W. (2009). *Plant nutrition of greenhouse crops*. Springer. https://doi.org/10.1007/978-90-481-2532-6

Stanghellini, C. (1987). *Transpiration of greenhouse crops: An aid to climate management* [Doctoral dissertation, Wageningen University]. Wageningen University and Research.
