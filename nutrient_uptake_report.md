---
title: "Nutrient Uptake Kinetics in Hydroponic Lettuce: Michaelis-Menten Framework with Minimum Concentration, Stress Modifications, and Implementation in the DSSAT Hydroponic Model"
author: "Kapil Bhattarai"
date: "April 2026"
---

# Abstract

Active nutrient uptake by plant roots is the central process determining nutrient use efficiency and solution depletion rates in hydroponic systems. For lettuce (*Lactuca sativa* L.), uptake of nitrogen (as NO₃⁻ and NH₄⁺), phosphorus (as H₂PO₄⁻), and potassium (K⁺) follows Michaelis–Menten saturation kinetics characterized by a maximum uptake rate (J_max), a half-saturation concentration (K_m), and a minimum concentration below which net uptake ceases (C_min). This framework, established by Epstein (1966) and parameterized for soilless lettuce culture by Silberbush et al. (2005), is the foundation of the nutrient uptake modules in the DSSAT-based hydroponic crop simulation model. Uptake kinetics are modified by three environmental stress factors computed by independent modules: electrical conductivity (EC) stress, which suppresses J_max via ion-specific exponential or hyperbolic functions; pH stress, which reduces effective J_max through a Gaussian availability factor and increases effective K_m through an exponential modifier; and dissolved oxygen (O₂) stress, which scales overall uptake rate. Uptake proceeds in two phases per daily timestep (RATE and INTEGR) to maintain mass balance after solution volume concentration from transpiration. Separate Fortran subroutines implement nitrogen (HYDRO_NUTRIENT), potassium (SOLKi), and phosphorus (SOLPi) uptake, sharing state variables through the DSSAT ModuleData shared memory structure.

**Keywords:** nutrient uptake, Michaelis-Menten kinetics, hydroponics, lettuce, nitrogen, phosphorus, potassium, Cmin, EC stress, pH stress, DSSAT, crop simulation

---

# 1. Introduction

Nutrient uptake by plant roots is an active, energy-requiring process mediated by membrane-bound ion transporter proteins. Unlike passive diffusion, active uptake can accumulate ions against concentration gradients, is saturable at high external concentrations, and exhibits a characteristic minimum external concentration (C_min) below which net uptake ceases (Epstein, 1966; Marschner, 2012). The saturation kinetics of these transporters are well described by the Michaelis–Menten equation, originally derived for enzyme kinetics but applied to root ion uptake by Epstein (1966) in one of the landmark papers of plant mineral nutrition.

In hydroponic systems, where roots are immersed in a well-mixed nutrient solution of known composition, the Michaelis–Menten framework provides an especially tractable description of nutrient dynamics. The absence of soil diffusion limitations, ion exchange reactions, and spatial heterogeneity that complicate soil nutrient modeling means that solution concentration is the primary determinant of uptake rate, and changes in concentration are directly attributable to plant uptake and management inputs (Silberbush et al., 2005; Sonneveld & Voogt, 2009).

Silberbush et al. (2005) calibrated Michaelis–Menten uptake parameters (J_max, K_m, C_min) for NO₃⁻, NH₄⁺, K⁺, PO₄-P, SO₄²⁻, Ca²⁺, and Mg²⁺ specifically for lettuce (*Lactuca sativa* L. var. 'Nogah 936') grown in volcanic ash and rock wool soilless substrates, providing a literature basis for the uptake module parameterization used in the DSSAT hydroponic model. This report describes the theoretical basis, parameter values, stress modification framework, mass balance implementation, and module structure for the three nutrient uptake modules: HYDRO_NUTRIENT (N), SOLKi (K), and SOLPi (P).

---

# 2. Michaelis–Menten Kinetics with Minimum Concentration

## 2.1 Classic Michaelis–Menten Uptake

The Michaelis–Menten equation for root ion uptake describes the relationship between external solution concentration and uptake rate per unit root length:

$$J_i = \frac{J_{max,i} \times C_i}{K_{m,i} + C_i}$$

where J_i is the uptake flux (mg ion per cm root per day), J_max,i is the maximum uptake rate (mg cm⁻¹ day⁻¹), C_i is the external solution concentration (mg L⁻¹), and K_m,i is the half-saturation concentration (mg L⁻¹) — the concentration at which J = J_max/2. At C >> K_m, uptake approaches J_max (zero-order with respect to concentration). At C << K_m, uptake is approximately linear in concentration (first-order). This behavior reflects the saturation kinetics of membrane transporter proteins: at low concentrations, transporters are substrate-limited; at high concentrations, they are saturated (Epstein, 1966).

## 2.2 Extension with C_min

Epstein & Bloom (2005) and Silberbush et al. (2005) noted that at very low external concentrations, root cells maintain a cytoplasmic ion activity that creates a chemical potential barrier to further uptake. Below a minimum concentration C_min (also called the threshold or compensation concentration), the net uptake flux is zero or negative (efflux). This is incorporated by replacing C in the Michaelis–Menten equation with the effective driving concentration (C - C_min):

$$J_i = \frac{J_{max,i} \times (C_i - C_{min,i})}{K_{m,i} + (C_i - C_{min,i})}, \quad C_i > C_{min,i}$$

$$J_i = 0, \quad C_i \leq C_{min,i}$$

The C_min values from Silberbush et al. (2005) for lettuce are 0.002 mol m⁻³ (= 0.002 mmol L⁻¹) for NO₃⁻, NH₄⁺, K⁺, and SO₄²⁻, and 0.0002 mol m⁻³ for PO₄-P. Converted to mg L⁻¹ of the element:

- C_min,NO₃ = 0.002 × 14.0067 = **0.028 mg N L⁻¹**
- C_min,NH₄ = 0.002 × 14.0067 = **0.028 mg N L⁻¹**
- C_min,K = 0.002 × 39.0983 = **0.078 mg K L⁻¹**
- C_min,P = 0.0002 × 30.9738 = **0.0062 mg P L⁻¹**

These values are very small relative to typical nutrient solution concentrations (NO₃-N ~150–200 mg L⁻¹, K ~150–250 mg L⁻¹) and become relevant only in late-season drift scenarios when solution depletion is substantial.

## 2.3 Scaling by Root Length

Total crop uptake (kg ha⁻¹ day⁻¹) is obtained by integrating J_i over the total root length per unit area:

$$U_i = J_i \times RL_{total}$$

where RL_total is the total root length per unit area (cm cm⁻²), converted to cm ha⁻¹ for the final uptake calculation. Root length (TRLV) is provided by the CROPGRO plant module and represents the cumulative root development as a function of thermal time, plant population, and growth stage.

---

# 3. Nutrient-Specific Parameters and Uptake Modules

## 3.1 Nitrogen Uptake (HYDRO_NUTRIENT)

Nitrogen is the macronutrient required in the largest quantity by lettuce, with typical total N contents of 3–5% of dry weight (Marschner, 2012). Hydroponic nutrient solutions supply N predominantly as NO₃⁻ (typically 70–90% of total N) with a minor NH₄⁺ fraction (Bugbee, 2004; Sonneveld & Voogt, 2009). Both forms are taken up by distinct high-affinity transporter families: NRT1/NRT2 for NO₃⁻ and AMT1/AMT2 for NH₄⁺.

The HYDRO_NUTRIENT module implements separate Michaelis–Menten kinetics for each N form:

$$U_{NO_3} = \frac{J_{max,NO_3} \times (C_{NO_3} - C_{min,NO_3})}{K_{m,NO_3} + (C_{NO_3} - C_{min,NO_3})} \times TRLV \times 100$$

$$U_{NH_4} = \frac{J_{max,NH_4} \times (C_{NH_4} - C_{min,NH_4})}{K_{m,NH_4} + (C_{NH_4} - C_{min,NH_4})} \times TRLV \times 100$$

The factor 100 converts root length from cm cm⁻² to cm m⁻². J_max and K_m values are read from the crop coefficient file (FILECC), allowing cultivar-specific parameterization. The baseline values for lettuce from Silberbush et al. (2005) are:

**Table 1**

*Michaelis–Menten Parameters for Nitrogen Uptake in Lettuce*

| Parameter | NO₃⁻ | NH₄⁺ | Source |
|---|---|---|---|
| J_max (mg N cm⁻¹ root d⁻¹) | 0.0139 | 0.0184 | Silberbush et al. (2005), calibrated to DSSAT TRLV |
| K_m (mg N L⁻¹) | 0.210 | 0.755 | Silberbush et al. (2005): 0.015 and 0.0539 mol m⁻³ |
| C_min (mg N L⁻¹) | 0.028 | 0.028 | Silberbush et al. (2005): 0.002 mol m⁻³ |

Note: J_max values in the species file (LUGRO048.SPE) are in mg N per cm root length per day, calibrated for use with DSSAT's root length density variable (TRLV, cm root cm⁻² ground). The original Silberbush et al. (2005) Table 1 reports J_max in mol m⁻² s⁻¹ per unit root surface area; conversion to per-length units requires the mean root radius r₀. J_max for NO₃⁻ is further concentration-dependent due to NO₃⁻-inducible NRT expression. This induction is implemented in HYDRO_NUTRIENT as a multiplicative factor applied before the Michaelis–Menten equation: INDUCT_NO3 = 1 + 0.21 × (NO3_SOL / 14.0067), where NO3_SOL is in mg N L⁻¹ and 14.0067 converts to mol m⁻³. At a typical solution concentration of 82 mg N L⁻¹ (≈5.9 mol m⁻³, Heinen 1994 experiment), INDUCT_NO3 ≈ 2.23, making the effective J_max approximately 2.2 times the base value (0.0139 × 2.23 ≈ 0.031 mg cm⁻¹ d⁻¹). At high concentrations (150 mg N L⁻¹), INDUCT_NO3 ≈ 3.25 and effective J_max ≈ 0.045 mg cm⁻¹ d⁻¹.

A demand cap is applied to prevent uptake from exceeding plant nitrogen demand (ANDEM, kg N ha⁻¹ day⁻¹) as computed by the plant growth module:

$$\text{If } (U_{NO_3} + U_{NH_4}) > ANDEM: \quad U_i = U_i \times \frac{ANDEM}{U_{NO_3} + U_{NH_4}}$$

## 3.2 Potassium Uptake (SOLKi)

Potassium is the dominant cation in plant tissue and in hydroponic nutrient solutions (typically 150–300 mg K L⁻¹). K⁺ uptake by high-affinity K transporters (HKT family) follows Michaelis–Menten kinetics (Epstein, 1966):

$$U_K = \frac{J_{max,K} \times (C_K - C_{min,K})}{K_{m,K} + (C_K - C_{min,K})} \times TRLV \times 100$$

The Na⁺-dependent J_max suppression described in Silberbush et al. (2005) for K uptake:

$$J_{max,K} = J_{max,K,0} \times e^{-0.023 \times C_{Na}}$$

is implemented through the EC stress module (SOLEC) as the ECSTRESS_JMAX_K factor (see Section 5.1), where C_Na (mmol L⁻¹) is derived from the solution EC. The parameter k = 0.023 is the Silberbush et al. (2005) Table 1 value for lettuce — a critical species-specific value that differs from values reported for other crops (e.g., k = 0.0136 for rose; Silberbush et al., 2005).

## 3.3 Phosphorus Uptake (SOLPi)

Phosphorus is taken up predominantly as H₂PO₄⁻ at typical hydroponic pH (5.5–6.5). Uptake follows:

$$U_P = \frac{J_{max,P} \times (C_P - C_{min,P})}{K_{m,P} + (C_P - C_{min,P})} \times TRLV \times 100$$

The C_min,P = 0.0002 mol m⁻³ = 0.0062 mg P L⁻¹ (Silberbush et al., 2005) is one order of magnitude lower than for N and K, reflecting the very high affinity of H₂PO₄⁻ transporters. The Silberbush et al. (2005) J_max for P is approximately two orders of magnitude lower than for NO₃⁻ on a molar basis, consistent with the much lower P requirement of plants relative to N.

---

# 4. Effective Uptake with Stress Modification

## 4.1 Combined Stress Factor Framework

All three stress factors (EC, pH, O₂) modify the kinetic parameters before the Michaelis–Menten equation is evaluated. The effective J_max and K_m for each nutrient are:

$$J_{max,eff,i} = J_{max,i} \times f_{EC,Jmax,i} \times f_{pH,i}$$

$$K_{m,eff,i} = K_{m,i} \times f_{EC,Km,i} \times f_{pH,Km,i}$$

The full uptake equation with all stress factors is:

$$U_i = \frac{J_{max,eff,i} \times (C_i - C_{min,i})}{K_{m,eff,i} + (C_i - C_{min,i})} \times TRLV \times 100 \times f_{O_2}$$

where f_O2 scales the entire uptake rate (representing root aerobic metabolism suppression at low dissolved oxygen). All stress factors are dimensionless scalars in the range [0, 1].

## 4.2 EC Stress Factors (from SOLEC)

The SOLEC module computes ion-specific EC stress factors based on Na⁺ accumulation (estimated from total EC). For K:
- ECSTRESS_JMAX_K = exp(−0.023 × C_Na), where C_Na is in mmol L⁻¹ (Silberbush et al., 2005)

For NO₃⁻ (hyperbolic Na suppression):
- ECSTRESS_JMAX_NO3 = 1/(1 + C_Na/K_INHIB_NO3), where K_INHIB_NO3 = 50 mol m⁻³

For NH₄⁺: the current implementation sets ECSTRESS_JMAX_NH4 = ECSTRESS_JMAX_NO3 (same hyperbolic form). Silberbush et al. (2005) specifies a distinct linear suppression for NH₄⁺: J_max,NH4 = J_max0 × (1 − 0.02 × C_Na). This difference is a known approximation, consequential only when Na > 10 mg L⁻¹.

A competitive K_m increase factor for NO₃⁻:
- ECSTRESS_KM_NO3 is derived from Na concentration as a proxy. Silberbush et al. (2005) specifies Cl⁻ as the competitive ion (K_m,NO3 = 0.015 + 5.3×10⁻⁴ × C_Cl); the Na-based proxy is an approximation used when Cl⁻ is not independently tracked.

NH₄⁺ K_m Na-dependent increase (K_m,NH4 = 0.0539 + 6.45×10⁻⁴ × C_Na; Silberbush et al., 2005) is not currently implemented. This is only consequential at elevated Na concentrations.

P EC stress factors follow analogous formulations described in the EC stress report.

## 4.3 pH Stress Factors (from SOLPH)

The SOLPH module provides two pH-dependent factors per nutrient (see pH report for full derivation):

**Availability factor** (Gaussian, reduces effective J_max):
$$f_{pH,i} = \exp\left(-\frac{(pH - 5.75)^2}{2\sigma_i^2}\right)$$

**K_m modifier** (exponential, increases effective K_m):
$$f_{pH,Km,i} = \exp\left(\alpha_i \times |pH - 5.75|\right)$$

Parameter values used in the model:

**Table 2**

*pH Stress Parameter Values for Lettuce Nutrient Uptake*

| Nutrient | σ (availability) | α (K_m modifier) |
|---|---|---|
| NO₃⁻ | 0.8 | 0.15 |
| NH₄⁺ | 0.8 | 0.15 |
| PO₄-P | 0.5 | 0.20 |
| K⁺ | 1.0 | 0.10 |

At the optimum pH (5.75), both factors equal 1.0 and impose no modification. At pH 7.0, the availability factors for P drop to 0.08, substantially suppressing phosphorus uptake (Haynes, 1990; Marschner, 2012).

## 4.4 O₂ Stress Factor

The dissolved oxygen stress factor O2_STRESS scales the total uptake rate, reflecting the dependence of active ion transport on root respiration. At adequate dissolved oxygen (>4 mg L⁻¹, as is typical in well-aerated NFT systems), O2_STRESS = 1.0. In submerged or poorly aerated systems, O2_STRESS < 1.0. The current implementation initializes O2_STRESS = 1.0 unless overridden by an aeration module; it is stored in ModuleData for extensibility. If the retrieved value is < 0.01 (indicating it was not set), a default of 1.0 is applied.

---

# 5. Demand Cap

The demand cap prevents kinetic supply from exceeding plant physiological demand. This is important when solution concentrations are very high and kinetic uptake rates would otherwise exceed what the plant can assimilate. The plant N demand (ANDEM) is computed within NUPTAK on the current day. K demand (KDEMAND) and P demand (PDEMAND) are read from ModuleData, where they are stored each day by K_Plant.for (`CALL PUT('HYDRO','KTOTDEM',KTotDem)`) and P_Plant.for (`CALL PUT('HYDRO','PTOTDEM',PTotDem)`) respectively. This one-day lag (yesterday's demand used as today's cap) is consistent with explicit-Euler time integration and is acceptable because demand changes slowly relative to the daily timestep. The demand cap is applied as a proportional scaling:

$$\text{If } U_i > Demand_i: \quad U_i = Demand_i$$

For nitrogen, the cap scales UNO3 and UNH4 proportionally to maintain their ratio:

$$\text{If } (U_{NO_3} + U_{NH_4}) > ANDEM: \quad U_i = U_i \times \frac{ANDEM}{U_{NO_3} + U_{NH_4}}$$

This formulation preserves the N-form preference ratio while limiting total N uptake to plant demand.

---

# 6. Mass Depletion and Solution Concentration Update

## 6.1 Mass Balance

After uptake rates are determined, the daily mass removed from the solution must be subtracted from the reservoir concentration to update the solution state for the next timestep. The depletion formula converts uptake (kg ha⁻¹ day⁻¹) to a concentration change (mg L⁻¹ day⁻¹):

$$\Delta C_i = \frac{U_i \times 10^6}{V_{per\_ha}}$$

where U_i is in kg ha⁻¹ day⁻¹, the factor 10⁶ converts kg to mg, and V_per_ha is the solution volume per hectare in liters:

$$V_{per\_ha} = SOLVOL_{mm} \times 10000 \; \text{L ha}^{-1}$$

(since 1 mm depth × 10,000 m² ha⁻¹ = 10,000 L ha⁻¹). The updated concentration is:

$$C_{i,new} = \max(0, \; C_{i,old} - \Delta C_i)$$

A minimum of V_per_ha = 10.0 L ha⁻¹ is enforced to prevent division by zero.

## 6.2 Ordering of Concentration and Depletion

The daily sequence within the INTEGR phase is:
1. HYDRO_WATER: updates SOLVOL, applies CONC_FACTOR to all concentrations (passive concentration from transpiration-driven volume loss)
2. HYDRO_NUTRIENT INTEGR: recomputes kinetic uptake using post-concentration concentrations, depletes NO₃ and NH₄
3. SOLPi INTEGR: recomputes kinetic P uptake, depletes P
4. SOLKi INTEGR: recomputes kinetic K uptake, depletes K

The re-computation of kinetic rates in INTEGR (rather than simply using the RATE-phase values) ensures that uptake rates reflect the post-concentration solution state. This two-phase approach maintains numerical stability when daily transpiration causes significant concentration changes.

---

# 7. Module Communication via ModuleData

All four modules (HYDRO_WATER, HYDRO_NUTRIENT, SOLKi, SOLPi) exchange state variables through the DSSAT ModuleData shared memory using GET/PUT calls with the 'HYDRO' module identifier. Key variables:

**Table 3**

*ModuleData Variables for Nutrient Uptake Modules*

| Variable | Units | Written by | Read by |
|---|---|---|---|
| NO3_CONC, NH4_CONC | mg N L⁻¹ | HYDRO_WATER (conc.), HYDRO_NUTRIENT (depletion) | HYDRO_NUTRIENT |
| P_CONC | mg P L⁻¹ | HYDRO_WATER (conc.), SOLPi (depletion) | SOLPi |
| K_CONC | mg K L⁻¹ | HYDRO_WATER (conc.), SOLKi (depletion) | SOLKi |
| SOLVOL | mm | HYDRO_WATER | HYDRO_NUTRIENT, SOLPi, SOLKi |
| PH_AVAIL_{NO3,NH4,P,K} | — | SOLPH | HYDRO_NUTRIENT, SOLPi, SOLKi |
| PH_KM_FACTOR_{NO3,NH4,P,K} | — | SOLPH | HYDRO_NUTRIENT, SOLPi, SOLKi |
| ECSTRESS_JMAX_{NO3,NH4,P,K} | — | SOLEC | HYDRO_NUTRIENT, SOLPi, SOLKi |
| ECSTRESS_KM_NO3 | — | SOLEC | HYDRO_NUTRIENT |
| O2_STRESS | — | (future module) | HYDRO_NUTRIENT, SOLPi, SOLKi |
| PTOTDEM | kg P ha⁻¹ d⁻¹ | P_Plant.for (daily INTEGR) | NUPTAK → SOLPi (as PDEMAND cap) |
| KTOTDEM | kg K ha⁻¹ d⁻¹ | K_Plant.for (daily INTEGR) | NUPTAK → SOLKi (as KDEMAND cap) |
| UNO3, UNH4, UK, UPO4 | kg N (or P, K) ha⁻¹ d⁻¹ | HYDRO_NUTRIENT, SOLKi, SOLPi | NUPTAK; K_Uptake.for; P_Uptake.for |

---

# 8. Discussion

The Michaelis–Menten framework with C_min is well-validated for high-affinity nutrient transporters in the concentration range typical of hydroponic nutrient solutions (Epstein, 1966; Epstein & Bloom, 2005; Silberbush et al., 2005). Its primary limitation in the current implementation is the use of fixed base J_max values, whereas in reality both J_max and K_m are regulated by plant nitrogen status, developmental stage, and external ion interactions. Silberbush et al. (2005) noted that J_max for NO₃⁻ increases with NO₃⁻ concentration (inducible NRT expression: J_max = J_max0 × (1 + 0.21 × C_NO3)), and K_m for NH₄⁺ and K⁺ increases with Na⁺ accumulation. The NO₃⁻ induction factor is now fully implemented in HYDRO_NUTRIENT (INDUCT_NO3 term; see Section 3.1); it concentrates most of its effect in the mid-to-late season when root length is large and solution N concentrations are still substantial. The Na⁺-dependent K_m increase is addressed through EC stress factors in SOLEC (Section 4.2).

**Removal of the mass-flow (passive) uptake component.** Earlier versions of the nutrient modules computed total uptake as the sum of a passive mass-flow term (EP × σ × C, where EP is daily transpiration and σ is a reflection coefficient) and an active Michaelis–Menten term. This two-component scheme follows the Silberbush et al. (2005) formulation for Ca²⁺, where passive uptake via the transpiration stream is physiologically significant (Eq. 13b in the paper). For NO₃⁻, NH₄⁺, K⁺, and PO₄-P, however, Silberbush et al. (2005) use only the active kinetic term (Eq. 13a), noting that high-affinity transporters dominate uptake at the concentrations relevant to hydroponic culture. The transpiration stream does concentrate the solution (reducing SOLVOL and increasing C), which raises the M-M driving force — this indirect effect is correctly captured by the HYDRO_WATER module applying a concentration factor to all solution species before the uptake modules run. Retaining an explicit σ-based mass-flow term on top of this would double-count the transpiration effect. The mass-flow component has therefore been removed from HYDRO_NUTRIENT, SOLKi, and SOLPi; the σ parameters (SIGMA_NO3, SIGMA_NH4, SIGMA_K, SIGMA_P) are no longer read from the species file.

The demand cap is a critical feature for model stability. Without it, at high nutrient concentrations and long root lengths, kinetic uptake rates can substantially exceed plant growth requirements. The demand-supply framework ensures that nutrient uptake does not outpace growth, maintaining consistency between the nutrient cycling and plant growth modules. However, it introduces a coupling between the uptake kinetics and the plant growth submodel: errors in demand estimation propagate into solution depletion rates. For well-parameterized cultivars, this is acceptable; for novel cultivars or growing conditions outside the calibration range, the demand cap may artificially constrain kinetically feasible uptake.

In K_Uptake.for, N:K and P:K tissue ratio guards are bypassed in hydroponic mode. In soil mode these guards prevent excessive K luxury uptake when N or P is limiting; in hydroponic mode, SOLKi already enforces a demand cap, so applying the guards a second time would silently under-deliver K relative to what the kinetics allow.

The two-phase RATE/INTEGR implementation is a consequence of the DSSAT simulation framework's execution order. The RATE phase provides preliminary uptake estimates for plant growth calculations; the INTEGR phase finalizes uptake after the water balance (and concentration effect) has been computed. This design ensures that the plant growth module always has uptake rates available (from RATE) and that the solution chemistry is correctly updated (in INTEGR). The re-computation in INTEGR is computationally redundant but numerically important: without it, solution concentrations would be depleted based on pre-concentration uptake rates, slightly underestimating actual depletion in drift mode.

---

# 9. Conclusion

The DSSAT hydroponic model implements nitrogen, phosphorus, and potassium uptake using pure active Michaelis–Menten kinetics with minimum concentration (C_min) as parameterized for lettuce by Silberbush et al. (2005). The earlier passive mass-flow term (EP × σ × C) has been removed; transpiration now affects uptake only indirectly through solution concentration (HYDRO_WATER concentrates all species before the uptake modules run). Three independent modules — HYDRO_NUTRIENT (N), SOLKi (K), SOLPi (P) — calculate kinetic uptake rates per unit root length, apply demand caps to prevent oversupply, and update solution concentrations by daily mass depletion. NO₃⁻ uptake includes a concentration-dependent induction factor (INDUCT_NO3 = 1 + 0.21 × C_NO3_mol_m⁻³) following Silberbush et al. (2005). Uptake kinetics are modified by EC stress factors (exponential or hyperbolic J_max suppression based on Na⁺ accumulation), pH stress factors (Gaussian availability factors reducing J_max; exponential K_m modifiers), and O₂ stress. P and K demand caps are sourced from the previous day's plant demand stored in ModuleData by P_Plant.for and K_Plant.for. All state variables are exchanged through the DSSAT ModuleData shared memory framework. The two-phase RATE/INTEGR computation ensures that kinetic uptake rates are consistent with the post-transpiration solution concentration state, maintaining nutrient mass balance across the daily simulation timestep.

---

# References

Bugbee, B. (2004). Nutrient management in recirculating hydroponic culture. *Acta Horticulturae*, *648*, 99–112. https://doi.org/10.17660/ActaHortic.2004.648.12

Epstein, E. (1966). Dual pattern of ion absorption by plant cells and by plants. *Nature*, *212*(5061), 509–511. https://doi.org/10.1038/212509a0

Epstein, E., & Bloom, A. J. (2005). *Mineral nutrition of plants: Principles and perspectives* (2nd ed.). Sinauer Associates.

Haynes, R. J. (1990). Active ion uptake and maintenance of cation–anion balance: A critical examination of their role in regulating rhizosphere pH. *Advances in Agronomy*, *43*, 227–264. https://doi.org/10.1016/S0065-2113(08)60479-9

Jones, J. W., Hoogenboom, G., Porter, C. H., Boote, K. J., Batchelor, W. D., Hunt, L. A., Wilkens, P. W., Singh, U., Gijsman, A. J., & Ritchie, J. T. (2003). The DSSAT cropping system model. *European Journal of Agronomy*, *18*(3–4), 235–265. https://doi.org/10.1016/S1161-0301(02)00107-7

Marschner, P. (Ed.). (2012). *Mineral nutrition of higher plants* (3rd ed.). Academic Press. https://doi.org/10.1016/B978-0-12-384905-2.00001-4

Munns, R., & Tester, M. (2008). Mechanisms of salinity tolerance. *Annual Review of Plant Biology*, *59*, 651–681. https://doi.org/10.1146/annurev.arplant.59.032607.092911

Resh, H. M. (2013). *Hydroponic food production: A definitive guidebook for the advanced home gardener and the commercial hydroponic grower* (7th ed.). CRC Press.

Silberbush, M., Ben-Asher, J., & Ephrath, J. E. (2005). A model for nutrient and water flow and their uptake by plants grown in a soilless culture. *Plant and Soil*, *271*(1–2), 309–319. https://doi.org/10.1007/s11104-004-3093-z

Sonneveld, C., & Voogt, W. (2009). *Plant nutrition of greenhouse crops*. Springer. https://doi.org/10.1007/978-90-481-2532-6
