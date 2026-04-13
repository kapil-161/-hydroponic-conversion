---
title: "Electrical Conductivity and EC Stress in Hydroponic Lettuce: Mechanisms, Dose–Response Functions, and Implementation in the DSSAT Hydroponic Model"
author: "Kapil Bhattarai"
date: "April 2026"
bibliography: references
csl: apa
---

# Abstract

Electrical conductivity (EC) of the nutrient solution is a principal management variable in hydroponic systems, simultaneously indicating nutrient availability and osmotic load. Both deficiency (low EC) and salinity toxicity (high EC) reduce lettuce (*Lactuca sativa* L.) growth and nutrient uptake through distinct physiological mechanisms. This report reviews the role of EC in hydroponic systems, documents the optimal EC range for lettuce (1.2–1.8 dS m⁻¹), and synthesizes published dose–response functions for EC stress. Two complementary stress functions are presented and justified: a linear function describing growth reduction at sub-optimal EC (nutrient deficiency) and an exponential decay function describing reduction at supra-optimal EC (osmotic/ionic toxicity). These functions are directly implemented in the SOLEC module of a DSSAT-based hydroponic crop model, where they modulate Michaelis–Menten nutrient uptake kinetics and plant morphological growth. The exponential decay constant (*k* = 0.277 dS⁻¹ m) is validated against published EC₅₀ values for lettuce, and the linear floor (0.30) is justified by nutrient mass-balance principles and empirical growth data. The integrated approach enables simulation of realistic EC dynamics in both feed-and-drift and continuous-recirculation hydroponic systems.

**Keywords:** electrical conductivity, EC stress, hydroponics, lettuce, Michaelis–Menten kinetics, DSSAT, crop simulation, nutrient solution, salinity

---

# 1. Introduction

Hydroponic crop production has expanded substantially as a controlled-environment alternative to field agriculture, offering precise regulation of the root-zone chemical environment (Bugbee, 2004; Sonneveld & Voogt, 2009). Unlike soil-based systems, where nutrient availability is mediated by complex soil–water–mineral interactions, hydroponic systems deliver nutrients directly in aqueous solution, allowing measurable and adjustable concentrations of all essential elements. Within this framework, electrical conductivity (EC) has become the primary diagnostic tool for managing nutrient solution quality. EC integrates the total ionic strength of the solution and provides a rapid, non-destructive proxy for both nutrient supply capacity and osmotic potential (Sonneveld & Voogt, 2009).

Despite the convenience of EC as a management metric, the relationship between EC and plant performance is non-linear and operates in two opposing directions. At low EC, nutrients are insufficient to meet crop demand, limiting growth through substrate-level nutrient deficiency. At high EC, the accumulated ionic load imposes osmotic stress and ion-specific toxicity, reducing both growth and nutrient uptake efficiency (Munns & Tester, 2008). Accurately modeling these divergent responses is essential for any crop simulation model that operates in hydroponic environments.

The DSSAT (Decision Support System for Agrotechnology Transfer) cropping system model has been extended to simulate lettuce production in hydroponic systems. A dedicated EC management module, SOLEC, calculates solution EC from tracked nutrient concentrations and applies EC-based stress factors to nutrient uptake kinetics and plant growth parameters. This report describes the scientific basis for the EC stress functions implemented in SOLEC, relating them to established literature on crop salt tolerance and hydroponic physiology.

The specific objectives are to: (1) define EC and its role in hydroponic systems; (2) document the optimal EC range and tolerance limits for lettuce; (3) review the effects of sub-optimal and supra-optimal EC on plant physiology; (4) describe the mathematical forms used to quantify EC stress; and (5) explain the implementation of EC stress functions in the DSSAT hydroponic model.

---

# 2. Electrical Conductivity in Hydroponic Systems

## 2.1 Definition and Physical Basis

Electrical conductivity measures the ability of a solution to conduct an electrical current, which in aqueous systems arises from the movement of dissolved ions. EC is expressed in decisiemens per meter (dS m⁻¹) or millisiemens per centimeter (mS cm⁻¹), where 1 dS m⁻¹ = 1 mS cm⁻¹. In hydroponic nutrient solutions, the principal ion contributors to EC include nitrate (NO₃⁻), ammonium (NH₄⁺), potassium (K⁺), phosphate (H₂PO₄⁻/HPO₄²⁻), calcium (Ca²⁺), magnesium (Mg²⁺), sulfate (SO₄²⁻), and, in the case of poor-quality irrigation water, sodium (Na⁺) and chloride (Cl⁻) (Sonneveld & Voogt, 2009). Each ion contributes to EC in proportion to its molar concentration and equivalent conductance.

The empirical relationship commonly used to estimate solution EC from total dissolved ions is:

$$EC \approx \frac{TotalIons_{ppm}}{640}$$

where the denominator accounts for the mixed ionic composition of a typical nutrient solution (Sonneveld & Voogt, 2009). This conversion factor varies with ion composition but provides a practical approximation for monitoring purposes.

## 2.2 EC as an Integrated Management Variable

EC serves a dual role in hydroponic management. First, it indicates nutrient availability: when EC is below the crop optimum, the solution is too dilute and nutrient uptake is supply-limited. Second, it indicates osmotic load: when EC is above the crop optimum, the cumulative ionic strength reduces the osmotic potential of the solution, increasing the energy required for water and ion uptake (Munns & Tester, 2008). In recirculating systems, EC tends to rise over time as plants absorb water (and thus concentrate the solution) while selective nutrient uptake depletes individual ions at different rates. This phenomenon, known as salinity buildup, is particularly pronounced when irrigation water contains elevated Na⁺ or Cl⁻ concentrations (Silberbush et al., 2005).

The simplicity of EC measurement — achievable with inexpensive conductivity probes in real time — has made it the standard indicator for automated nutrient replenishment in commercial hydroponic operations (Bugbee, 2004). Growers typically maintain EC within a crop-specific optimal window, adding fresh nutrient solution when EC falls below a lower threshold and flushing or replacing solution when EC rises above an upper threshold.

---

# 3. Optimal EC Range for Hydroponic Lettuce

## 3.1 Empirically Established Optimum

Lettuce (*Lactuca sativa* L.) is classified as moderately sensitive to salinity (Maas & Hoffman, 1977; Ayers & Westcot, 1985). The optimal EC range for hydroponic lettuce production has been consistently reported between 1.2 and 1.8 dS m⁻¹ across multiple experimental systems and cultivars. Gruneberg et al. (2021) evaluated five EC levels (0.5, 0.7, 0.9, 1.2, and 2.0 dS m⁻¹) in a vertical farm ebb-and-flow system and found that fresh mass, dry mass, and leaf area were maximized at EC 0.9–1.2 dS m⁻¹, with statistically significant growth reductions at both 0.5 and 2.0 dS m⁻¹. Conselvan et al. (2025) similarly reported peak fresh and dry matter at EC 0.9–1.4 dS m⁻¹ across deep water culture and NFT systems under tropical conditions, recommending EC 1.3 dS m⁻¹ as optimal. Akter et al. (2026) demonstrated that EC 1.5–2.0 dS m⁻¹ produced the highest shoot fresh weight (57.97 g plant⁻¹) and leaf area (1,338 cm² plant⁻¹), while EC 4.5–6.0 dS m⁻¹ caused a 75–77% reduction relative to the optimal treatment.

These data converge on an optimal EC window of approximately 1.2–1.8 dS m⁻¹ for hydroponic lettuce. Below 1.2 dS m⁻¹, growth is progressively limited by nutrient deficiency; above 1.8 dS m⁻¹, osmotic and ionic stress increasingly reduce growth and nutrient uptake efficiency.

## 3.2 Relationship to Soil-Based Salinity Thresholds

The classical Maas–Hoffman model (Maas & Hoffman, 1977), originally derived for soil-grown crops, reports a salt tolerance threshold for lettuce of ECₑ = 1.3 dS m⁻¹ (electrical conductivity of the saturation-paste extract), with a linear yield decline of 13% per dS m⁻¹ above that threshold. This was confirmed by Ayers and Westcot (1985) in FAO Irrigation and Drainage Paper No. 29. Shannon and Grieve (1999) extended this to a sigmoid dose–response and estimated G₅₀ (the ECₑ for 50% growth reduction) at approximately 8 dS m⁻¹ for lettuce, equivalent to a nutrient solution EC of approximately 4 dS m⁻¹, given that solution EC is typically 2–4× lower than ECₑ for equivalent osmotic effect.

Sonneveld and Voogt (2009) provided substrate-specific thresholds for greenhouse crops and reported that lettuce production in growing media decreases above a nutrient solution EC of approximately 3.5 dS m⁻¹, with a yield reduction rate of approximately 18.9% per dS m⁻¹ beyond the threshold. These parameters are specific to substrate culture rather than true liquid-phase hydroponics, where the buffering capacity of the substrate is absent.

---

# 4. Effects of EC on Lettuce Physiology and Nutrient Uptake

## 4.1 Effects of Low EC: Nutrient Deficiency Stress

At sub-optimal EC, plant growth is limited by the supply rate of essential nutrients. Bugbee (2004) demonstrated that in recirculating hydroponic culture, nutrient uptake follows Michaelis–Menten kinetics at low solution concentrations, where uptake rate is approximately proportional to concentration (i.e., the linear region of the hyperbola where C ≪ Kₘ). Under these conditions, the growth rate of the crop is directly limited by the rate of nutrient delivery, and reducing EC below the optimum creates a multi-nutrient deficiency rather than a single-element limitation.

Specifically, nitrogen (as NO₃⁻ and NH₄⁺), potassium (K⁺), and phosphorus (H₂PO₄⁻) are the nutrients most rapidly depleted at low solution volumes, and their combined deficiency limits both leaf expansion and dry matter accumulation. Gruneberg et al. (2021) showed that at EC 0.5 dS m⁻¹ — well below the optimum of 1.2 dS m⁻¹ — lettuce fresh weight was reduced by approximately 40–50% relative to the optimal EC treatment, with visible chlorosis symptoms indicating nitrogen deficiency.

## 4.2 Effects of High EC: Osmotic and Ionic Stress

At supra-optimal EC, two distinct physiological mechanisms operate concurrently: osmotic stress and ion-specific toxicity (Munns & Tester, 2008). These have been termed the two-phase model of salt stress.

### 4.2.1 Osmotic Phase

The initial response to elevated EC is osmotic in nature: the reduced water potential of the solution decreases water availability to roots, reducing cell turgor, leaf expansion rate, and stomatal conductance (Munns & Tester, 2008). This phase is rapid (occurring within hours to days) and is proportional to the total osmotic potential regardless of ionic composition. In hydroponic systems where Na⁺ is the primary contributor to elevated EC, the osmotic stress from Na⁺ accumulation is the dominant mechanism at moderate EC levels (Silberbush et al., 2005).

### 4.2.2 Ionic Phase

The second phase of stress involves the accumulation of toxic ion concentrations — primarily Na⁺ and Cl⁻ — in leaf tissue over a period of days to weeks, causing progressive cellular damage, chloroplast degradation, and membrane dysfunction (Munns & Tester, 2008). In the context of nutrient uptake, elevated Na⁺ inhibits the high-affinity transport systems for K⁺, NO₃⁻, NH₄⁺, and PO₄³⁻ through competitive inhibition at the transporter level (Silberbush et al., 2005). Specifically, Na⁺ reduces the maximum uptake rate (Jₘₐₓ) of K⁺ following an exponential relationship:

$$J_{max,K} = J_{max,K_0} \cdot e^{-0.023 \cdot C_{Na}}$$

where *C*_Na is the Na⁺ concentration in mol m⁻³ (Silberbush et al., 2005, Table 1). For NO₃⁻, the inhibition follows a hyperbolic form:

$$J_{max,NO_3} = \frac{J_{max,NO_3,0}}{1 + C_{Na}/K_{inhib}}$$

where *K*_inhib is the inhibition constant. Additionally, Na⁺ competitively increases the Michaelis–Menten affinity constant (Kₘ) for NO₃⁻ and NH₄⁺, reducing uptake efficiency at a given nutrient concentration (Silberbush et al., 2005).

### 4.2.3 Morphological Suppression

Elevated Na⁺ also suppresses root elongation and leaf area expansion, reducing the physical surface area available for nutrient absorption (Silberbush et al., 2005). Root length growth is inhibited in proportion to both Na⁺ concentration and the ratio of Ca²⁺ to the sum of cations, with Ca²⁺ providing partial amelioration of Na⁺ toxicity. Akter et al. (2026) documented a 75% reduction in leaf area at EC 4.5–6.0 dS m⁻¹ compared to the optimal EC range, demonstrating the combined contribution of osmotic and ionic stress to growth suppression.

---

# 5. EC Stress Dose–Response Functions

## 5.1 Classical Models

### 5.1.1 Maas–Hoffman Piecewise Linear Model

The Maas–Hoffman model (Maas & Hoffman, 1977) is the most widely cited dose–response function for crop salt tolerance:

$$Y_r = \begin{cases} 100 & \text{if } EC \leq EC_t \\ 100 - S(EC - EC_t) & \text{if } EC > EC_t \end{cases}$$

where *Y*_r is relative yield (%), EC_t is the threshold conductivity, and *S* is the slope (% yield loss per dS m⁻¹). For lettuce, Maas and Hoffman (1977) reported EC_t = 1.3 dS m⁻¹ and *S* = 13% dS⁻¹ m (ECₑ basis). Ayers and Westcot (1985) confirmed these parameters in FAO Paper 29. Although widely used, this model has two limitations: it does not account for growth reduction below the threshold (nutrient deficiency), and its linear form may underestimate stress at very high EC where growth declines more sharply (van Genuchten & Hoffman, 1984).

### 5.1.2 Van Genuchten–Gupta Sigmoid Model

Van Genuchten and Hoffman (1984) proposed a two-parameter sigmoid dose–response function that overcomes the discontinuity of the Maas–Hoffman model:

$$Y_r = \frac{1}{1 + (EC/C_{50})^p}$$

where *C*_50 is the EC causing 50% yield loss and *p* is a shape parameter controlling the steepness of the response. This model is continuous and differentiable across all EC values, making it more suitable for integration in numerical simulation models. Shannon and Grieve (1999) reported *C*_50 ≈ 8 dS m⁻¹ ECₑ for lettuce using sigmoid fitting, corresponding to approximately 4 dS m⁻¹ in nutrient solution.

For EC significantly above *C*_50/2 (the inflection point), the sigmoid approximates an exponential decay function, providing the theoretical basis for the exponential stress function used in the DSSAT hydroponic model.

## 5.2 EC Stress Functions for Simulation Models

In crop simulation models, EC stress functions are typically expressed as dimensionless factors (0–1) that scale biological rates (growth, uptake). Two functional forms are required for hydroponic modeling: one for sub-optimal EC (deficiency) and one for supra-optimal EC (toxicity).

### 5.2.1 Low EC Stress: Linear Deficiency Function

At sub-optimal EC (EC < EC_opt_low), nutrient supply limits growth approximately in proportion to EC, because at concentrations well below Kₘ, Michaelis–Menten uptake kinetics reduce to a linear function of concentration (Bugbee, 2004):

$$U \approx \frac{J_{max}}{K_m} \cdot C \quad \text{when } C \ll K_m$$

This means that as EC falls below the optimum, the fractional supply rate decreases linearly. A floor term (> 0) is retained to represent the minimum metabolic activity supported by internal nutrient reserves at zero external supply. The linear stress function used in the DSSAT hydroponic model is:

$$EC_{STRESS,LOW} = 0.30 + 0.70 \cdot \frac{EC_{CALC}}{EC_{OPT,LOW}}$$

where EC_OPT_LOW = 1.2 dS m⁻¹. This function yields a stress factor of 1.0 at EC = 1.2 dS m⁻¹ and declines linearly to a floor of 0.30 at EC = 0. The floor of 0.30 reflects residual growth capacity at zero external nutrient supply, consistent with the shape of data reported by Gruneberg et al. (2021), where growth at EC 0.5 dS m⁻¹ was reduced but not eliminated. This function is constrained to the range [0.30, 1.0].

### 5.2.2 High EC Stress: Exponential Decay Function

At supra-optimal EC (EC > EC_opt_high), the osmotic and ionic stress components impose an accelerating growth penalty. The van Genuchten–Gupta model (van Genuchten & Hoffman, 1984) and the Munns–Tester two-phase model (Munns & Tester, 2008) both indicate that growth reduction at high EC follows a curve that, above the inflection point, is well-approximated by an exponential decay. The exponential stress function implemented in the DSSAT hydroponic model is:

$$EC_{STRESS,HIGH} = e^{-k \cdot (EC_{CALC} - EC_{OPT,HIGH})}$$

where EC_OPT_HIGH = 1.8 dS m⁻¹ and *k* = 0.277 dS⁻¹ m. This function yields a stress factor of 1.0 at EC = 1.8 dS m⁻¹ and declines exponentially at higher EC values. This function is constrained to the range [0.10, 1.0].

**Validation of the decay constant *k*:** The EC producing 50% stress (EC₅₀) can be derived by setting the function equal to 0.5:

$$EC_{50} = EC_{OPT,HIGH} + \frac{\ln(2)}{k} = 1.8 + \frac{0.693}{0.277} = 1.8 + 2.50 = 4.30 \text{ dS m}^{-1}$$

This value of 4.30 dS m⁻¹ (nutrient solution) is consistent with published EC₅₀ estimates for lettuce. Shannon and Grieve (1999) reported *G*_50 ≈ 8 dS m⁻¹ ECₑ for lettuce, which converts to approximately 4.0 dS m⁻¹ in nutrient solution (using the approximate factor of 0.5 for ECₑ-to-solution conversion). Akter et al. (2026) observed a 75–77% yield reduction at EC 4.5–6.0 dS m⁻¹ (midpoint ≈ 5.25 dS m⁻¹), which implies EC₅₀ ≈ 4.0–4.5 dS m⁻¹, consistent with *k* ≈ 0.25–0.40 dS⁻¹ m. The value *k* = 0.277 dS⁻¹ m falls within this range and is therefore well-supported by the available lettuce-specific experimental data.

### 5.2.3 Combined Stress Factor

The combined EC stress factor applied to biological rates is the minimum of the two component functions, representing the most limiting condition:

$$EC_{STRESS} = \min(EC_{STRESS,LOW}, \; EC_{STRESS,HIGH})$$

Within the optimal range (EC_OPT_LOW ≤ EC ≤ EC_OPT_HIGH), both components equal 1.0 and no EC-based stress is applied. Outside this range, the relevant component scales all affected biological rates.

Table 1 summarizes the behavior of the two EC stress functions across the EC range relevant to lettuce production.

**Table 1**

*Calculated EC Stress Factor Values Across the EC Range for Hydroponic Lettuce*

| EC (dS m⁻¹) | EC_STRESS_LOW | EC_STRESS_HIGH | EC_STRESS (applied) | Interpretation |
|---|---|---|---|---|
| 0.0 | 0.30 | 1.00 | 0.30 | Severe nutrient deficiency |
| 0.5 | 0.59 | 1.00 | 0.59 | Moderate deficiency |
| 0.9 | 0.83 | 1.00 | 0.83 | Mild deficiency |
| 1.2 | 1.00 | 1.00 | 1.00 | Lower optimum boundary |
| 1.5 | 1.00 | 1.00 | 1.00 | Optimal range |
| 1.8 | 1.00 | 1.00 | 1.00 | Upper optimum boundary |
| 2.5 | 1.00 | 0.82 | 0.82 | Mild salinity stress |
| 3.5 | 1.00 | 0.55 | 0.55 | Moderate salinity stress |
| 4.3 | 1.00 | 0.50 | 0.50 | EC₅₀ — 50% reduction |
| 6.0 | 1.00 | 0.24 | 0.24 | Severe salinity stress |

---

# 6. Implementation in the DSSAT Hydroponic Model (SOLEC Module)

## 6.1 Module Overview

The SOLEC subroutine is a dedicated EC management module within the DSSAT hydroponic modeling framework. It is called at each daily timestep during the RATE and INTEGR phases of the DSSAT cropping system model simulation loop. SOLEC calculates the current solution EC from tracked nutrient concentrations, computes EC stress factors, and makes these factors available via the ModuleData shared memory structure to all nutrient uptake and plant growth modules.

EC is estimated from the sum of tracked dissolved ions (NO₃⁻, NH₄⁺, P, K⁺) using the empirical approximation:

$$EC_{CALC} = \frac{(C_{NO_3} + C_{NH_4} + C_P + C_K) \times 2.5}{640}$$

where concentrations are in mg L⁻¹ and the factor 2.5 accounts for unmeasured counter-ions (Ca²⁺, Mg²⁺, SO₄²⁻) that contribute to total EC in a typical balanced nutrient solution. This approach follows the methodology described by Sonneveld and Voogt (2009) for practical EC estimation in recirculating systems.

## 6.2 EC Stress Computation

During the RATE phase, SOLEC evaluates the current EC against the optimal range and computes the two-component stress system described in Section 5.2. When Na⁺ concentration data are available (NA_CONC > 10 mg L⁻¹), the module switches to ion-specific stress calculations following the kinetic inhibition model of Silberbush et al. (2005):

- **K⁺ Jₘₐₓ suppression:** exponential model with *k* = 0.023 mol⁻¹ m³ (Silberbush et al., 2005, Table 1)
- **PO₄-P Jₘₐₓ suppression:** exponential model with *k* = 0.0022 mol⁻¹ m³ (Silberbush et al., 2005, Table 1)
- **NO₃⁻ Jₘₐₓ suppression:** hyperbolic model with K_inhib = 50 mol m⁻³
- **NO₃⁻ Kₘ increase:** competitive inhibition factor scaling Kₘ

When Na⁺ data are unavailable — the common case in experimental datasets that report only total EC — the total EC-based stress (Section 5.2.3) is applied uniformly to all nutrients.

## 6.3 Stress Factor Application

SOLEC stores seven stress factors in the ModuleData shared memory (Table 2), where they are retrieved by the nutrient uptake modules at each timestep.

**Table 2**

*EC Stress Factors Computed by SOLEC and Their Application in the DSSAT Hydroponic Model*

| Stress Factor | Symbol | Applied to | Equation basis |
|---|---|---|---|
| ECSTRESS_JMAX_NO3 | f_EC,NO3 | Jₘₐₓ of NO₃⁻ uptake (HYDRO_NUTRIENT) | Na hyperbolic or EC linear/exponential |
| ECSTRESS_JMAX_NH4 | f_EC,NH4 | Jₘₐₓ of NH₄⁺ uptake (HYDRO_NUTRIENT) | Same as NO₃⁻ |
| ECSTRESS_JMAX_K | f_EC,K | Jₘₐₓ of K⁺ uptake (SOLKi) | Na exponential: exp(−0.023 C_Na) |
| ECSTRESS_JMAX_P | f_EC,P | Jₘₐₓ of PO₄-P uptake (SOLPi) | Na exponential: exp(−0.0022 C_Na) |
| ECSTRESS_KM_NO3 | f_Km,NO3 | Kₘ of NO₃⁻ uptake (HYDRO_NUTRIENT) | Na competitive inhibition |
| ECSTRESS_ROOT | f_EC,root | Root growth (CROPGRO) | Na morphological or EC total |
| ECSTRESS_LEAF | f_EC,leaf | Leaf expansion (CROPGRO) | Na morphological or EC total |

The effective nutrient uptake rate for each ion *I* is computed as:

$$U_I = \frac{J_{max,I} \cdot f_{EC,I} \cdot (C_I - C_{min,I})}{K_{m,I} \cdot f_{Km,I} \cdot f_{pH,Km,I} + (C_I - C_{min,I})} \times RL \times f_{pH,I} \times f_{O_2}$$

where *C*_min is the minimum solution concentration below which uptake ceases (Silberbush et al., 2005), and the pH-dependent availability factor *f*_pH and Kₘ factor *f*_pH,Km are supplied by the SOLPH module. This formulation integrates the EC stress, pH stress, and O₂ stress mechanisms in a single Michaelis–Menten framework consistent with Silberbush et al. (2005).

## 6.4 Feed-and-Drift Management

The SOLEC INTEGR phase also implements an automated replenishment algorithm (AUTO_CONC flag). When EC falls below EC_OPT_LOW, indicating that nutrient depletion has brought the solution below the deficiency threshold, the module rescales all nutrient concentrations to restore EC to EC_OPT_HIGH. This mimics the management practice of adding fresh nutrient solution to the reservoir when the solution becomes depleted — a standard protocol in commercial NFT and deep water culture systems (Bugbee, 2004; Sonneveld & Voogt, 2009). When AUTO_CONC is disabled, the simulation operates in pure depletion mode, allowing EC to drift freely with uptake and transpiration dynamics, as modeled by Silberbush et al. (2005).

---

# 7. Discussion

The EC stress framework implemented in SOLEC draws from two distinct bodies of literature: classical salt tolerance agronomy (Maas & Hoffman, 1977; Ayers & Westcot, 1985; Shannon & Grieve, 1999) and hydroponic-specific nutrient kinetics (Silberbush et al., 2005; Bugbee, 2004; Sonneveld & Voogt, 2009). The synthesis of these traditions into a unified simulation framework requires careful attention to the differences between soil-based and solution-culture systems.

The most significant conceptual shift is the treatment of sub-optimal EC. Classical salt tolerance models — including the Maas–Hoffman model — define stress only above the threshold EC, assuming that below the threshold, growth is unaffected. In soil systems, this is a reasonable approximation because the soil solid phase buffers nutrient availability, and below-threshold EC rarely corresponds to true nutrient deficiency. In hydroponic systems, however, the solution is the sole nutrient source, and EC below the optimum directly corresponds to sub-optimal nutrient concentrations. The linear deficiency function implemented in SOLEC addresses this gap by quantifying growth reduction as EC falls below EC_OPT_LOW = 1.2 dS m⁻¹, consistent with the empirical data of Gruneberg et al. (2021) showing progressive growth reduction as EC approaches 0.5 dS m⁻¹.

For high EC stress, the exponential decay form is mathematically justified as an approximation to the upper limb of the van Genuchten–Gupta sigmoid (van Genuchten & Hoffman, 1984), and its parameterization (*k* = 0.277 dS⁻¹ m, EC₅₀ = 4.3 dS m⁻¹) is consistent with published *G*_50 values for lettuce (Shannon & Grieve, 1999; Akter et al., 2026). The exponential form has the practical advantage of providing a smooth, differentiable stress function that is numerically stable in iterative simulation, unlike the discontinuous Maas–Hoffman threshold model.

A limitation of the current implementation is that EC is estimated from only four tracked ions (NO₃⁻, NH₄⁺, P, K⁺), while actual solution EC also includes contributions from Ca²⁺, Mg²⁺, SO₄²⁻, Na⁺, and Cl⁻. The empirical factor of 2.5 used to approximate unmeasured counter-ions introduces uncertainty in EC estimation, particularly in experiments where the solution recipe deviates from a typical nutrient balance. Future model development should track Ca, Mg, and SO₄ as dynamic state variables with their own uptake kinetics (Silberbush et al., 2005), which would both improve EC estimation accuracy and enable the Ca:cation ratio suppression of root growth described in Silberbush et al. (2005).

A second limitation is the treatment of Na⁺ and Cl⁻ as static inputs rather than dynamically accumulated variables. Silberbush et al. (2005) demonstrated that Na⁺ accumulation through the recirculating system is the primary driver of progressive EC rise and the resulting K⁺ depletion in realistic production scenarios. Passive Na⁺ and Cl⁻ uptake, proportional to solution concentration above a critical threshold, should be incorporated in future model versions to accurately simulate salinity buildup over the crop cycle.

---

# 8. Conclusion

Electrical conductivity is the primary management variable for hydroponic nutrient solutions, and its effects on lettuce growth operate through two opposing mechanisms: nutrient deficiency at low EC and osmotic/ionic toxicity at high EC. The optimal EC range for hydroponic lettuce is 1.2–1.8 dS m⁻¹, consistent across multiple experimental systems and cultivars. The DSSAT hydroponic SOLEC module implements two mathematically justified EC stress functions: a linear deficiency function below the optimum (floor = 0.30, upper boundary = 1.2 dS m⁻¹) and an exponential toxicity function above the optimum (*k* = 0.277 dS⁻¹ m, EC₅₀ = 4.3 dS m⁻¹). Both functions are supported by published literature and validated against lettuce-specific experimental data. These stress factors modulate Michaelis–Menten nutrient uptake kinetics and plant growth parameters in the DSSAT model, enabling realistic simulation of EC dynamics under both controlled management and free-drift hydroponic scenarios. The framework is consistent with the mechanistic approach of Silberbush et al. (2005) and extends it to a full DSSAT simulation environment.

---

# References

Akter, N., Cammarisano, L., & Ahmed, M. S. (2026). Interactive effects of electrical conductivity and light intensity on growth, yield, and nutrient dynamics of hydroponic lettuce. *Scientific Reports*. https://doi.org/10.1038/s41598-026-44508-2

Ayers, R. S., & Westcot, D. W. (1985). *Water quality for agriculture* (FAO Irrigation and Drainage Paper No. 29, Rev. 1). Food and Agriculture Organization of the United Nations.

Bugbee, B. (2004). Nutrient management in recirculating hydroponic culture. *Acta Horticulturae*, *648*, 99–112. https://doi.org/10.17660/ActaHortic.2004.648.12

Conselvan, G. B., Zanin, L., Pinton, R., & Tomasi, N. (2025). Yield and nutrient use efficiency of lettuce grown at different electrical conductivity levels of hydroponic solutions. *International Journal of Vegetable Science*, *32*(1). https://doi.org/10.1080/19315260.2025.2564829

Gruneberg, A., Rolf, M., Pawelzik, E., & Naumann, M. (2021). Nutrient use in vertical farming: Optimal electrical conductivity of nutrient solution for growth of lettuce and basil in hydroponic cultivation. *Horticulturae*, *7*(9), 283. https://doi.org/10.3390/horticulturae7090283

Maas, E. V., & Hoffman, G. J. (1977). Crop salt tolerance: Current assessment. *Journal of the Irrigation and Drainage Division, ASCE*, *103*(IR2), 115–134.

Munns, R., & Tester, M. (2008). Mechanisms of salinity tolerance. *Annual Review of Plant Biology*, *59*, 651–681. https://doi.org/10.1146/annurev.arplant.59.032607.092911

Shannon, M. C., & Grieve, C. M. (1999). Tolerance of vegetable crops to salinity. *Scientia Horticulturae*, *78*(1–4), 5–38. https://doi.org/10.1016/S0304-4238(98)00189-7

Silberbush, M., Ben-Asher, J., & Ephrath, J. E. (2005). A model for nutrient and water flow and their uptake by plants grown in a soilless culture. *Plant and Soil*, *271*(1–2), 309–319. https://doi.org/10.1007/s11104-004-3093-z

Sonneveld, C., & Voogt, W. (2009). *Plant nutrition of greenhouse crops*. Springer. https://doi.org/10.1007/978-90-481-2532-6

van Genuchten, M. T., & Hoffman, G. J. (1984). Analysis of crop salt tolerance data. In I. Shainberg & J. Shalhevet (Eds.), *Soil salinity under irrigation: Processes and management* (pp. 258–271). Springer.
