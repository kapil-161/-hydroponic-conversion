---
title: "pH Dynamics and pH-Dependent Nutrient Uptake in Hydroponic Lettuce: Mechanisms, Buffering Chemistry, and Implementation in the DSSAT Hydroponic Model"
author: "Kapil Bhattarai"
date: "April 2026"
---

# Abstract

Solution pH is a primary determinant of nutrient availability and uptake kinetics in hydroponic systems. For lettuce (*Lactuca sativa* L.), the optimal pH range is 5.5–6.5, with a functional optimum near 5.75. Outside this range, nutrient precipitation, transporter inhibition, and ion toxicity progressively reduce growth and yield. This report reviews the chemical mechanisms driving pH change in recirculating nutrient solutions, with emphasis on the stoichiometric H⁺ exchange associated with NH₄⁺ and NO₃⁻ uptake, bicarbonate and phosphate buffering, and phosphate speciation. A pH-dependent nutrient availability model is described using Gaussian scaling functions and Michaelis–Menten affinity modifiers, both implemented in the SOLPH module of a DSSAT-based hydroponic crop simulation model. pH is prognostically integrated each day from the net H⁺ production of nutrient uptake divided by the total buffer capacity of the solution. Buffer capacity includes three components: CO₂-equilibrium bicarbonate at the current pH (Silberbush et al., 2005), a background alkalinity term representing irrigation water bicarbonate (0.5 mmol L⁻¹), and pH-dependent phosphate buffering (pKa = 7.21). The SOLPH implementation supports free-drift mode (pH integrates from the current ionic state each day) and managed mode (pH held at user-specified target). The diagnostic charge-balance approach (Silberbush et al., 2005) was evaluated but found to require a complete ion inventory; with only N, P, K tracked dynamically, the residual charge A ≈ 5 × 10⁻⁶ mol L⁻¹ is smaller than one day's depletion shift, causing unrealistic pH oscillations. The prognostic buffer-integration approach is retained as physically consistent and numerically stable.

**Keywords:** pH, hydroponics, lettuce, nutrient availability, bicarbonate buffering, phosphate speciation, Michaelis–Menten kinetics, DSSAT, crop simulation, CO₂ equilibrium

---

# 1. Introduction

The pH of the root-zone solution is among the most consequential variables in hydroponic crop production. Unlike soil systems where pH is buffered by mineral weathering, cation exchange, and organic matter decomposition, hydroponic nutrient solutions have relatively low buffering capacity and are subject to rapid pH shifts driven by differential ion uptake and water loss (Sonneveld & Voogt, 2009). Growers routinely monitor and adjust pH daily, recognizing that deviations from the optimal range compromise nutrient availability even when total ion concentrations remain adequate (Resh, 2013).

The mechanisms driving pH change in nutrient solutions are well established. When plants absorb NH₄⁺, a proton is released to the solution for each mole of nitrogen assimilated, lowering pH. Conversely, NO₃⁻ uptake consumes a proton, raising pH (Marschner, 2012). The relative proportions of NH₄⁺ and NO₃⁻ in the nutrient solution therefore determine the direction and rate of pH drift, and the buffering capacity of the solution determines the magnitude of that drift per unit of uptake (Haynes, 1990).

At the crop physiology level, pH affects nutrient availability through two distinct pathways. First, pH directly controls the solubility of mineral nutrients: iron, manganese, and zinc precipitate at high pH, while phosphate availability peaks in the slightly acidic range (Marschner, 2012). Second, pH affects the kinetics of membrane-bound ion transporters, altering both the maximum uptake rate (J_max) and the Michaelis–Menten affinity constant (K_m) for specific nutrients (Haynes, 1990).

Accurate simulation of pH dynamics is therefore a prerequisite for reliable prediction of nutrient uptake and plant growth in hydroponic models. The DSSAT-based hydroponic crop simulation model described here includes a dedicated pH module (SOLPH) that forward-integrates pH each day from the net H⁺ production of nutrient uptake relative to the solution's total buffer capacity, following the buffer chemistry framework of Silberbush et al. (2005).

---

# 2. Optimal pH Range for Hydroponic Lettuce

## 2.1 Empirically Established Optimum

Lettuce production in hydroponic systems requires pH maintenance within a relatively narrow window. The consensus optimal range is 5.5–6.5, with the functional optimum centered near pH 5.75 (Bugbee, 2004; Resh, 2013; Sonneveld & Voogt, 2009). Within this range, all macronutrients and most micronutrients remain soluble and accessible to roots, transporter proteins function at near-maximal efficiency, and root cell membrane integrity is maintained.

Tyson et al. (2007) investigated pH management in recirculating hydroponic systems and confirmed that lettuce growth was optimal at pH 5.8–6.2, with measurable growth reductions at pH below 5.0 and above 7.0. Resh (2013) reported that pH 6.0 is the practical management target for most leafy vegetable crops in NFT and deep water culture, with acceptable performance between pH 5.5 and 6.5. Sonneveld and Voogt (2009) noted that in substrate culture, the optimal pH range is slightly higher (6.0–6.5) due to the buffering interaction of the substrate matrix, but in true liquid hydroponics the lower end of the range (5.5–6.0) is generally preferred to maximize iron and phosphorus availability.

## 2.2 Consequences of pH Deviation

Both acidic and alkaline deviations from the optimum impose distinct nutritional constraints. At pH above 6.5, iron (Fe²⁺/Fe³⁺), manganese (Mn²⁺), and zinc (Zn²⁺) precipitate as hydroxides and carbonates, becoming unavailable to roots despite adequate total concentrations in solution (Marschner, 2012). Phosphorus availability also declines above pH 7.0 as HPO₄²⁻ replaces H₂PO₄⁻ and calcium phosphate precipitation becomes thermodynamically favorable. At pH below 5.0, NH₄⁺ toxicity becomes significant: the protonated form NH₄⁺ predominates and its accumulation in the cytoplasm disrupts nitrogen metabolism and membrane potential (Marschner, 2012). Manganese and aluminum toxicity may also emerge at very low pH, though these are less relevant in well-formulated hydroponic solutions.

---

# 3. Mechanisms of pH Change in Hydroponic Systems

## 3.1 Stoichiometric H⁺ Exchange During Nutrient Uptake

The primary driver of pH change in recirculating hydroponic solutions is the differential uptake of cations and anions by plant roots. To maintain electro-neutrality across the root plasma membrane, plants exchange H⁺ or OH⁻ ions with the external solution in proportion to the net charge imbalance created by nutrient uptake (Haynes, 1990; Marschner, 2012).

For NH₄⁺ uptake, the relevant stoichiometry is:

$$NH_4^+ + \text{plant} \rightarrow N_{plant} + H^+$$

One mole of H⁺ is released to the external solution per mole of NH₄-N assimilated. This is a consequence of both the charge balance requirement (uptake of a cation must be balanced by H⁺ efflux) and the biochemistry of NH₄⁺ assimilation, in which the glutamine synthetase pathway consumes NH₄⁺ and releases a proton (Marschner, 2012).

For NO₃⁻ uptake, the stoichiometry is reversed:

$$NO_3^- + H^+ + \text{plant} \rightarrow N_{plant}$$

One mole of H⁺ is consumed from the external solution per mole of NO₃-N assimilated, as the net uptake of an anion must be balanced by H⁺ influx or OH⁻ efflux (Haynes, 1990). The net daily H⁺ production rate is therefore:

$$\dot{H}^+ = \frac{U_{NH_4} \times 1000}{MW_N} - \frac{U_{NO_3} \times 1000}{MW_N} \quad \text{(mol ha}^{-1} \text{day}^{-1}\text{)}$$

where *U*_NH4 and *U*_NO3 are the daily NH₄-N and NO₃-N uptake rates (kg ha⁻¹ day⁻¹) and MW_N = 14.0067 g mol⁻¹. In practice, most hydroponic nutrient solutions supply predominantly NO₃⁻ with a small proportion of NH₄⁺ (typically NO₃:NH₄ ratios of 3:1 to 9:1), so the net H⁺ balance tends to be negative (pH-raising) over the crop cycle (Bugbee, 2004; Sonneveld & Voogt, 2009).

## 3.2 Secondary pH Drivers

Beyond N-form uptake, several secondary processes influence solution pH. Respiration by roots releases CO₂, which dissolves to form carbonic acid and lowers pH locally around the rhizosphere. In open recirculating systems, CO₂ exchange with the atmosphere partially equilibrates carbonate chemistry (Silberbush et al., 2005). Phosphate uptake (predominantly as H₂PO₄⁻ at typical hydroponic pH) consumes one negative charge per mole, contributing modestly to cation–anion imbalance. Potassium uptake as K⁺ similarly shifts the charge balance, but its effect on pH is smaller than that of N-form uptake given the lower molar uptake rates relative to N.

---

# 4. Buffering Chemistry of Nutrient Solutions

## 4.1 Bicarbonate Buffering

The principal pH buffer in hydroponic nutrient solutions is the bicarbonate–carbonic acid system. The Henderson-Hasselbalch equation describes the relationship between pH, dissolved CO₂, and bicarbonate:

$$pH = pK_{a1} + \log\frac{[HCO_3^-]}{[CO_2(aq)]}$$

where pK_a1 = 6.35 for carbonic acid at 25°C. The buffer capacity (β, mol H⁺ per pH unit per liter) for the bicarbonate system is:

$$\beta_{HCO_3} = 2.303 \times [HCO_3^-]$$

For a solution of volume *V* (liters), the total bicarbonate buffer capacity is:

$$\beta_{HCO_3,total} = 2.303 \times \frac{C_{HCO_3}}{MW_{HCO_3}} \times V$$

where *C*_HCO3 is the bicarbonate concentration (mg L⁻¹) and MW_HCO3 = 61.02 g mol⁻¹. This expression, derived from the van Slyke buffer equation, quantifies the moles of H⁺ that can be absorbed per pH unit change (Skoog et al., 1994). In hydroponic solutions maintained at pH 5.5–6.5 in equilibrium with atmospheric CO₂ (approximately 370 ppm in ambient air), the equilibrium [HCO₃⁻] is approximately 0.1–0.5 mg L⁻¹ — substantially lower than in alkaline water sources. Irrigation water with high alkalinity (bicarbonate > 2 mM) can substantially increase solution buffering and cause progressive pH rise as bicarbonate accumulates, a common problem in regions with calcareous water supplies (Sonneveld & Voogt, 2009).

## 4.2 Phosphate Buffering

Phosphate provides additional buffering capacity through the equilibrium between dihydrogen phosphate and monohydrogen phosphate:

$$H_2PO_4^- \rightleftharpoons HPO_4^{2-} + H^+ \quad pK_a = 7.21$$

where pKa = 7.21 at 25°C (Lide, 1996). The fraction of total phosphorus present as HPO₄²⁻ is:

$$f = \frac{[HPO_4^{2-}]}{[H_2PO_4^-] + [HPO_4^{2-}]} = \frac{10^{(pH - pK_a)}}{1 + 10^{(pH - pK_a)}}$$

The phosphate buffer capacity is then:

$$\beta_P = 2.303 \times \frac{C_P}{MW_P} \times V \times f \times (1 - f)$$

where *C*_P is the total phosphorus concentration (mg L⁻¹) and MW_P = 30.97 g mol⁻¹. At pH 5.75 — the optimum for lettuce — *f* ≈ 0.034 and *f*(1-*f*) ≈ 0.033, so phosphate buffering is modest. At pH 7.0, *f* ≈ 0.38 and *f*(1-*f*) ≈ 0.24, providing substantially stronger buffering. This pH dependence of phosphate buffering means that at the typical hydroponic operating range (pH 5.5–6.5), bicarbonate buffering dominates even at low bicarbonate concentrations.

## 4.3 Bicarbonate Concentration from CO₂ Equilibrium

The bicarbonate concentration in an open hydroponic system in contact with the atmosphere is governed by the dissolution of atmospheric CO₂ and the first dissociation of carbonic acid. From Henry's law, the dissolved CO₂ concentration at atmospheric partial pressure (approximately 370 ppm at the time of Silberbush et al., 2005) is:

$$[CO_{2(aq)}] = K_H \times p_{CO_2} = 3.4 \times 10^{-2} \times 3.7 \times 10^{-4} = 1.258 \times 10^{-5} \text{ mol L}^{-1}$$

The first dissociation of carbonic acid (H₂CO₃ ⇌ HCO₃⁻ + H⁺) has a first dissociation constant K₁ = 10⁻⁶·³⁵ = 4.47 × 10⁻⁷ at 25°C (Silberbush et al., 2005). Rearranging for [HCO₃⁻]:

$$[HCO_3^-] = \frac{K_1 \times [CO_{2(aq)}]}{[H^+]} = \frac{4.47 \times 10^{-7} \times 1.258 \times 10^{-5}}{10^{-pH}}$$

At the lettuce optimum of pH 5.75, this yields [HCO₃⁻] = 2.50 × 10⁻⁶ mol L⁻¹ = 0.153 mg L⁻¹. At pH 6.0, [HCO₃⁻] = 5.62 × 10⁻⁶ mol L⁻¹ = 0.343 mg L⁻¹. These values are characteristic of a dilute, slightly acidic nutrient solution in equilibrium with atmospheric CO₂ — substantially lower than tap water with high alkalinity, which may contain 1–5 mM HCO₃⁻ (Sonneveld & Voogt, 2009). The CO₂ equilibrium approach is self-contained: it requires only pH and atmospheric CO₂ partial pressure as inputs, avoiding the need for a complete ion inventory.

---

# 5. Effects of pH on Nutrient Availability and Uptake Kinetics

## 5.1 Nutrient Solubility and Availability

The solubility and plant-available form of nutrients are strongly pH-dependent. Marschner (2012) provides a comprehensive treatment of these relationships; the key patterns relevant to hydroponic lettuce are summarized below.

**Phosphorus** is most available between pH 5.5 and 6.5, where H₂PO₄⁻ is the predominant form and calcium phosphate precipitation is minimal. Above pH 7.0, calcium phosphate (Ca₃(PO₄)₂ and CaHPO₄) precipitates rapidly, removing P from solution. Below pH 5.0, iron and aluminum phosphates may form (less relevant in controlled hydroponic solutions).

**Iron** availability decreases sharply above pH 6.5. Ferric iron (Fe³⁺) hydrolyzes to form insoluble Fe(OH)₃ at neutral to alkaline pH, and the solubility product of ferric hydroxide is so low that [Fe³⁺] drops below plant requirements above pH 7.0. Hydroponic nutrient solutions typically supply iron as chelates (Fe-EDTA, Fe-DTPA) to maintain solubility across a wider pH range, but chelate stability itself is pH-dependent (Marschner, 2012).

**Manganese and zinc** show similar patterns: solubility decreases at pH above 6.5–7.0 as hydroxide and carbonate precipitates form. In practice, these micronutrient deficiencies become apparent in hydroponic lettuce at pH > 7.0 within days to weeks (Resh, 2013).

**Calcium and magnesium** are generally available across the normal hydroponic pH range but may become antagonized by elevated NH₄⁺ at low pH, as the high concentration of NH₄⁺ at the root surface competes for cation transporters (Marschner, 2012).

## 5.2 pH Effects on Uptake Kinetics

Beyond solubility effects, pH directly modulates the kinetics of membrane-bound ion transporters. Haynes (1990) reviewed the evidence that pH affects both the maximum uptake capacity (J_max) and the half-saturation constant (K_m) of high-affinity transport systems for NO₃⁻, NH₄⁺, H₂PO₄⁻, and K⁺.

For NO₃⁻ and NH₄⁺ uptake, transport rates peak at slightly acidic pH (5.5–6.5) and decline at both lower and higher pH values, consistent with the pH optima of the corresponding transporter proteins (NRT and AMT families). The pH dependence reflects both the direct effect of H⁺ on transporter conformation and the indirect effect of the transmembrane H⁺ gradient that drives co-transport (Marschner, 2012).

Phosphorus uptake (predominantly via H₂PO₄⁻ transporters) is most efficient at pH 5.0–6.0, where H₂PO₄⁻ is the dominant species. At higher pH, the shift toward HPO₄²⁻ reduces the concentration of the preferred substrate form, effectively increasing the apparent K_m for total phosphorus (Haynes, 1990).

Potassium uptake through high-affinity K⁺ transporters (HKT family) shows relatively low pH sensitivity compared to N and P transporters, consistent with the weaker pH dependence modeled in SOLPH.

---

# 6. pH Stress Modeling: Availability and Kinetic Functions

## 6.1 pH-Dependent Availability Factor

To quantify the reduction in effective nutrient availability as pH deviates from the optimum, the SOLPH module applies a Gaussian scaling function to each nutrient's maximum uptake rate. The Gaussian form is chosen because it produces a smooth, differentiable response that peaks at the optimal pH, declines symmetrically on both sides, and approaches zero at extreme pH values:

$$f_{pH,I} = \exp\left(-\frac{(pH - pH_{opt})^2}{2 \sigma_I^2}\right)$$

where pH_opt = 5.75 (the center of the optimal range for lettuce) and σ_I is the width parameter controlling the steepness of the response for nutrient *I*. The factor f_pH,I = 1.0 at pH = pH_opt and declines toward zero as pH deviates in either direction. Table 1 lists the σ values used for each nutrient.

**Table 1**

*pH-Dependent Availability Factor Parameters (σ) for Lettuce Nutrient Uptake*

| Nutrient | σ (pH units) | Basis |
|---|---|---|
| NO₃⁻ | 0.8 | Moderate sensitivity; NRT transporters functional across 5.0–7.5 (Haynes, 1990) |
| NH₄⁺ | 0.8 | Similar to NO₃⁻; AMT transporters pH-sensitive but broad range (Marschner, 2012) |
| PO₄-P | 0.5 | High sensitivity; H₂PO₄⁻ availability peaks sharply at 5.5–6.5 (Marschner, 2012) |
| K⁺ | 1.0 | Low sensitivity; HKT transporters relatively pH-insensitive (Haynes, 1990) |

At pH 5.75 (optimum), f_pH = 1.0 for all nutrients. At pH 7.0 (1.25 units above optimum), the availability factors are: NO₃⁻ = 0.45, NH₄⁺ = 0.45, P = 0.08, K⁺ = 0.71. At pH 4.5 (1.25 units below optimum), the same values apply by symmetry.

## 6.2 pH-Dependent Km Modifier

In addition to reducing the effective J_max, pH deviation increases the apparent K_m of nutrient transporters, reflecting reduced substrate affinity at sub-optimal pH. The K_m modifier is modeled as an exponential function of the absolute pH deviation from the optimum:

$$f_{Km,I}(pH) = \exp(\alpha_I \times |pH - pH_{opt}|)$$

where α_I is the sensitivity coefficient for nutrient *I*. This function equals 1.0 at optimal pH and increases (i.e., K_m increases, uptake efficiency declines) as pH deviates in either direction. Table 2 lists the α values.

**Table 2**

*pH-Dependent Km Modifier Parameters (α) for Lettuce Nutrient Uptake*

| Nutrient | α (pH units⁻¹) | Basis |
|---|---|---|
| NO₃⁻ | 0.15 | Moderate Km sensitivity (Haynes, 1990) |
| NH₄⁺ | 0.15 | Similar to NO₃⁻ (Haynes, 1990) |
| PO₄-P | 0.20 | Higher sensitivity; speciation shift increases apparent Km (Marschner, 2012) |
| K⁺ | 0.10 | Lower sensitivity (Haynes, 1990) |

At pH 7.0 (1.25 units from optimum), the K_m multipliers are: NO₃⁻ = 1.21, NH₄⁺ = 1.21, P = 1.28, K⁺ = 1.13. The combined effect of the availability factor (reducing J_max) and the K_m modifier (reducing affinity) produces a substantial reduction in uptake rate at high pH, particularly for phosphorus.

## 6.3 Combined Uptake Equation

The effective nutrient uptake rate for each ion *I* integrates pH stress, EC stress (from SOLEC), and O₂ stress:

$$U_I = \frac{J_{max,I} \cdot f_{EC,I} \cdot (C_I - C_{min,I})}{K_{m,I} \cdot f_{Km,pH,I} \cdot f_{Km,EC,I} + (C_I - C_{min,I})} \times RL \times f_{pH,I} \times f_{O_2}$$

where *C*_min is the minimum solution concentration below which uptake ceases (Silberbush et al., 2005), RL is root length (cm cm⁻²), and all stress factors are dimensionless scalars between 0 and 1. This formulation is consistent with the Michaelis–Menten framework described by Silberbush et al. (2005) and extended here with pH and EC stress components.

---

# 7. Implementation in the DSSAT Hydroponic Model: SOLPH Module

## 7.1 Module Structure

SOLPH is a Fortran subroutine within the DSSAT hydroponic modeling framework, called at each daily timestep in the RATE and INTEGR phases of the simulation loop. It implements a prognostic (forward-integration) approach: pH is advanced each day by the ratio of net H⁺ production to total buffer capacity. This integrates pH consistently with the current ion uptake rates and buffering chemistry without requiring a complete inventory of all ions in solution.

## 7.2 Prognostic pH Integration

At each daily RATE call, SOLPH computes the net H⁺ production rate from N uptake stoichiometry and divides it by the total buffer capacity to obtain the daily pH increment:

$$\Delta pH = -\frac{\dot{H}^+ \times A / 10000}{\beta_{total}}$$

where $\dot{H}^+$ (mol ha⁻¹ day⁻¹) is the net H⁺ production from NH₄⁺ and NO₃⁻ uptake (Section 3.1), *A* is the growing area (m²), 10000 converts ha to m², and β_total (mol H⁺ per pH unit) is the total buffer capacity of the solution volume. The result is clamped to ±0.5 pH units day⁻¹ to prevent numerical instability when uptake rates are very high:

$$pH_{t+1} = pH_t + \Delta pH, \quad \Delta pH \in [-0.5,\ 0.5]$$

The updated pH is stored in the ModuleData shared memory structure for use by all uptake modules at the same timestep.

## 7.3 Buffer Capacity Components

The total buffer capacity β_total is the sum of three components evaluated at the current pH and solution volume *V* (liters):

**Bicarbonate from CO₂ equilibrium.** For an open system in contact with atmospheric CO₂, [HCO₃⁻] at the current pH is (Silberbush et al., 2005):

$$[HCO_3^-] = \frac{K_1 \times [CO_{2(aq)}]}{[H^+]} \quad \text{(mol L}^{-1}\text{)}$$

where K₁ = 4.47 × 10⁻⁷ (first dissociation constant of carbonic acid at 25°C) and [CO₂(aq)] = 1.258 × 10⁻⁵ mol L⁻¹ (from Henry's law at 370 ppm CO₂). This yields [HCO₃⁻] ≈ 0.34 mg L⁻¹ at pH 6.0. Its buffer capacity contribution is:

$$\beta_{CO_2} = 2.303 \times [HCO_3^-] \times V$$

**Background alkalinity.** Real irrigation water contains residual bicarbonate from dissolution of limestone and carbonates in the water supply, typically 0.3–2 mM in temperate regions (Sonneveld & Voogt, 2009). A background alkalinity of BGALKAL = 0.5 mmol L⁻¹ is included as a fixed contribution:

$$\beta_{BGALKAL} = 2.303 \times \text{BGALKAL} \times V$$

This term is independent of pH and provides a realistic minimum buffer capacity even at very low [HCO₃⁻] (e.g., pH < 5.5 where the CO₂-equilibrium bicarbonate approaches zero). For the Heinen NFT experiment (V ≈ 168 L), β_BGALKAL ≈ 0.94 mol H⁺ per pH unit.

**Phosphate buffering.** The H₂PO₄⁻ ↔ HPO₄²⁻ equilibrium (pKa = 7.21) contributes buffering capacity (Section 4.2):

$$\beta_P = 2.303 \times \frac{C_P}{MW_P} \times V \times f \times (1 - f), \quad f = \frac{10^{pH-7.21}}{1 + 10^{pH-7.21}}$$

At pH 5.75, *f* ≈ 0.034 and phosphate buffering is modest. At pH 7.0, *f* ≈ 0.38 and phosphate makes a more substantial contribution. The total buffer capacity is:

$$\beta_{total} = \beta_{CO_2} + \beta_{BGALKAL} + \beta_P$$

## 7.4 Transpiration and Volume Effects

As the crop transpires, the solution volume decreases and all ion concentrations rise. This is handled implicitly: SOLVOL_L (the current solution volume in liters) is retrieved from ModuleData at each RATE call, so β_total scales proportionally with the shrinking volume. The same H⁺ production then divides a smaller buffer capacity, producing a larger ΔpH — correctly representing the effect of concentration without a separate correction term.

## 7.5 pH-Dependent Availability Factors

Following the prognostic pH update, SOLPH computes the Gaussian availability factors and exponential K_m modifiers for all four tracked nutrients (NO₃⁻, NH₄⁺, PO₄-P, K⁺) and stores them in ModuleData. These are retrieved by the uptake modules (HYDRO_NUTRIENT, SOLPi, SOLKi) at each rate calculation. A general pH stress indicator (the minimum availability factor across all nutrients) is also computed for backward compatibility with plant growth stress factors in the CROPGRO module.

## 7.6 AUTO_PH Management Mode

The SOLPH module supports two operational modes controlled by the AUTO_PH flag in the ISWITCH structure. In AUTO_PH = Y mode, pH is held constant at the user-specified target (PH_TARGET) at each timestep, simulating the practice of daily acid or base addition to maintain pH in commercial production. In AUTO_PH = N mode, pH integrates freely under the prognostic framework: net H⁺ production from nutrient uptake accumulates through the buffer capacity each day, producing a realistic representation of unmanaged pH drift for research or sensitivity analysis. For the Heinen NFT experiment with a purely NO₃-based nutrient solution, the unmanaged treatment (phdrift) shows a monotonic alkaline drift of approximately 0.04–0.06 pH units day⁻¹, consistent with the expectation that NO₃⁻-dominated uptake persistently consumes H⁺. The default is AUTO_PH = Y for practical agronomic simulations.

---

# 8. Discussion

The pH simulation framework in SOLPH integrates established buffer chemistry (CO₂ equilibrium, background alkalinity, phosphate speciation) with stoichiometric H⁺ accounting and empirical nutrient uptake kinetics (Gaussian availability factors, exponential K_m modifiers) in a computationally efficient daily timestep framework. Several design choices merit discussion.

**Prognostic vs. diagnostic pH.** The diagnostic charge-balance approach of Silberbush et al. (2005) was evaluated as an alternative to the prognostic framework described here. In the diagnostic approach, pH is re-solved each day from the ionic charge balance, anchoring pH to the current N, P, K concentrations. This is appealing because it eliminates integration error. However, the diagnostic approach requires a complete ion inventory. With only N, P, K tracked dynamically, the initial charge residual A (which absorbs the unknown Ca, Mg, SO₄ contributions) is approximately 5 × 10⁻⁶ mol L⁻¹ — roughly equal to [HCO₃⁻] at pH 6.0. One day's differential depletion of K vs. NO₃ shifts the meq balance by ~14 × 10⁻⁶ mol L⁻¹, which is 3× larger than A, flipping A's sign and driving the quadratic's pH solution from ~4 to ~7 on alternate days. This numerical instability is not a code error but a fundamental incompatibility: the diagnostic approach requires that the tracked-ion charge change be small relative to the total charge residual, a condition violated when only three of ~10 major ions are followed. The prognostic approach avoids this by integrating only what the model can calculate: the rate of H⁺ exchange from N-form uptake.

**Background alkalinity.** The BGALKAL = 0.5 mmol L⁻¹ term represents irrigation water bicarbonate that enters the system with daily top-ups. Without it, the CO₂-equilibrium [HCO₃⁻] at pH 5.5–6.0 is only 0.15–0.34 mg L⁻¹ (2.5–5.6 μmol L⁻¹), providing near-zero buffer capacity and producing unrealistically large daily pH swings. The 0.5 mmol L⁻¹ value is consistent with moderately soft tap water (Sonneveld & Voogt, 2009) and gives a background β_BGALKAL ≈ 0.94 mol H⁺/pH for the Heinen solution volume (168 L), which is physically realistic for an NFT system with daily refilling.

**Gaussian availability function.** The Gaussian form is a mathematical convenience rather than a mechanistically derived shape. The biological reality is more complex: different transporters have different pH optima and response curves, and the effects of pH on nutrient speciation (particularly for phosphorus) are not symmetric around pH 5.75. Marschner (2012) and Haynes (1990) provide the empirical basis for the qualitative patterns (moderate sensitivity for N, high sensitivity for P, low sensitivity for K), but the specific parameter values (σ and α) in Table 1 and Table 2 are approximations derived from the general literature rather than fitted to lettuce-specific data. Calibration against experimental pH × uptake datasets for lettuce would improve model accuracy.

**Micronutrient limitations.** Iron, manganese, and zinc are not tracked as dynamic state variables in the current model, so their precipitation at high pH is not explicitly simulated. The general pH stress indicator (minimum availability factor) provides a partial substitute, but lettuce iron deficiency at pH > 7.0 — a practically important failure mode — is not captured with the current nutrient tracking scope (N, P, K only).

**CO₂ equilibrium assumption.** The CO₂-equilibrium [HCO₃⁻] formula is valid for open systems well-aerated and in exchange with the atmosphere, which is appropriate for NFT and recirculating systems. In closed or anaerobic systems where CO₂ accumulates, a separate CO₂ budget term would be needed. Earlier implementations that attempted to compute [HCO₃⁻] directly from the charge balance (without CO₂ equilibrium anchoring) produced erroneous values (~380 mg L⁻¹ vs. the correct ~0.34 mg L⁻¹ at pH 6.0) because compound molecular weights were mistakenly applied to elemental-basis concentrations. The current approach anchors [HCO₃⁻] to the CO₂ equilibrium at each timestep, which is physically consistent and scale-correct.

---

# 9. Conclusion

Solution pH is a critical determinant of nutrient availability and uptake kinetics in hydroponic lettuce production. The optimal pH range (5.5–6.5, optimum 5.75) reflects the combined requirements of nutrient solubility, transporter function, and root physiology. pH changes in recirculating systems are driven primarily by the differential uptake of NO₃⁻ and NH₄⁺, which consume or release H⁺ stoichiometrically. The DSSAT hydroponic SOLPH module implements a prognostic buffer-integration approach: at each daily timestep, the net H⁺ production from N-form uptake is divided by the total solution buffer capacity (CO₂-equilibrium bicarbonate + background alkalinity + phosphate) to obtain ΔpH. Buffer capacity is computed from the CO₂ equilibrium relation of Silberbush et al. (2005) at the current pH, a fixed background alkalinity term (0.5 mmol L⁻¹, representing irrigation water bicarbonate), and the pH-dependent phosphate buffering. pH-dependent availability factors (Gaussian) and K_m modifiers (exponential) for NO₃⁻, NH₄⁺, PO₄-P, and K⁺ are computed from the integrated pH each day. The diagnostic charge-balance approach was evaluated but found to produce unrealistic pH oscillations when only N, P, K are tracked dynamically, because the initial charge residual is smaller than a single day's depletion shift; the prognostic approach is numerically stable and does not require a complete ion inventory.

---

# References

Bugbee, B. (2004). Nutrient management in recirculating hydroponic culture. *Acta Horticulturae*, *648*, 99–112. https://doi.org/10.17660/ActaHortic.2004.648.12

Haynes, R. J. (1990). Active ion uptake and maintenance of cation–anion balance: A critical examination of their role in regulating rhizosphere pH. *Advances in Agronomy*, *43*, 227–264. https://doi.org/10.1016/S0065-2113(08)60479-9

Lide, D. R. (Ed.). (1996). *CRC handbook of chemistry and physics* (77th ed.). CRC Press.

Marschner, P. (Ed.). (2012). *Mineral nutrition of higher plants* (3rd ed.). Academic Press. https://doi.org/10.1016/B978-0-12-384905-2.00001-4

Munns, R., & Tester, M. (2008). Mechanisms of salinity tolerance. *Annual Review of Plant Biology*, *59*, 651–681. https://doi.org/10.1146/annurev.arplant.59.032607.092911

Resh, H. M. (2013). *Hydroponic food production: A definitive guidebook for the advanced home gardener and the commercial hydroponic grower* (7th ed.). CRC Press.

Silberbush, M., Ben-Asher, J., & Ephrath, J. E. (2005). A model for nutrient and water flow and their uptake by plants grown in a soilless culture. *Plant and Soil*, *271*(1–2), 309–319. https://doi.org/10.1007/s11104-004-3093-z

Skoog, D. A., West, D. M., & Holler, F. J. (1994). *Fundamentals of analytical chemistry* (6th ed.). Saunders College Publishing.

Sonneveld, C., & Voogt, W. (2009). *Plant nutrition of greenhouse crops*. Springer. https://doi.org/10.1007/978-90-481-2532-6

Tyson, R. V., Hochmuth, R. C., Lamb, E. M., Hochmuth, G. J., & Sweat, E. M. (2007). Reconciling pH for ammonia-biofiltration and cucumber yield in a recirculating aquaponic system with perlite biofilters. *HortScience*, *42*(6), 1683–1687. https://doi.org/10.21273/HORTSCI.42.6.1683
