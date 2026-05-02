## Materials and Methods

## Conceptual Architecture of the Hydroponic Extension

### Overview

Figure 1 presents the conceptual architecture and daily process flow of the hydroponic extension within DSSAT-CSM v4.8. The extension operates through two parallel pathways that are activated conditionally on the ISWHYDRO flag: a **solution state pathway** (left column) that tracks the physical and chemical state of the nutrient reservoir, and an **existing CROPGRO plant growth pathway** (right column) that is modified only at the nutrient uptake and photosynthesis linkage points. The two pathways communicate exclusively through the DSSAT ModuleData shared memory structure (GET/PUT calls with the 'HYDRO' identifier).

**Figure 1.** Conceptual architecture and daily process flow of the DSSAT-CSM v4.8 hydroponic extension. Inputs include the experiment file (.LUX) with the *HYDROPONIC SOLUTION section, genotype files (LUGRO048.CUL, LUGRO048.ECO, LUGRO048.SPE), and hourly weather data (WTHER=H). The left pathway shows the solution state subroutines (HYDRO_FERT, HYDRO_WATER, SOLEC, SOLPH, SOLO2, HYDRO_NUTRIENT, SOLKi, SOLPi); the right pathway shows the existing CROPGRO plant growth engine with the points of modification (photosynthesis stress linkage and nutrient uptake redirection). All inter-module communication passes through the DSSAT ModuleData shared memory structure (GET/PUT calls with the 'HYDRO' identifier).

### Subroutine Summary

**Table 2.** Subroutines comprising the hydroponic extension, their role, and calling context within DSSAT-CSM.

| Subroutine | Type | Called from | Role |
|---|---|---|---|
| ipexp.for | Modified existing | DSSAT input parser | Detects and parses `*HYDROPONIC SOLUTION` section; sets ISWHYDRO |
| SPAM.for | Modified existing | Main DSSAT loop | Calls HYDRO_WATER, SOLEC, SOLPH, SOLO2 when ISWHYDRO='Y' |
| HYDRO_FERT | New | SPAM.for | Applies scheduled fertiliser additions to solution pools |
| HYDRO_WATER | New | SPAM.for | Daily water balance; transpiration-driven concentration factor; AUTO_VOL |
| SOLEC | New | SPAM.for | EC computation from ionic concentrations; EC stress functions; AUTO_CONC |
| SOLPH | New | SPAM.for | Prognostic pH integration; pH-dependent nutrient availability factors; AUTO_PH |
| SOLO2 | New | SPAM.for | Dissolved oxygen balance (Benson & Krause, 1984); O2_STRESS; AUTO_O2 |
| HYDRO_NUTRIENT | New | NUPTAK.for | MM N uptake with C_min, induction, stress multipliers, demand cap, depletion |
| SOLKi | New | K_Uptake.for | MM K⁺ uptake with C_min, stress multipliers, demand cap, depletion |
| SOLPi | New | P_Uptake.for | MM PO₄-P uptake with C_min, stress multipliers, demand cap, depletion |

---

## Integration of the Hydroponic Extension into DSSAT-CSM

The hydroponic extension was designed to operate as a set of conditionally activated Fortran subroutines within the existing DSSAT Cropping System Model (DSSAT-CSM) v4.8 (Hoogenboom et al., [2019](https://doi.org/10.7303/CY6H-8083.2019); the present work extends the v4.8 source branched from the v4.7 public release), compiled into the single standard executable (dscsm048). Activation is controlled by the logical flag ISWHYDRO within the ISWITCH control structure, which is set to 'Y' when the input experiment file (.LUX) contains a `*HYDROPONIC SOLUTION` section specifying initial solution parameters. In the absence of this section, ISWHYDRO defaults to 'N' and all soil-based subroutines execute without modification, preserving full backward compatibility with the complete existing DSSAT simulation library (Jones et al., [2003](https://doi.org/10.1016/S1161-0301(02)00107-7); Hoogenboom et al., [2019](https://doi.org/10.7303/CY6H-8083.2019)).

### Experiment File Inputs

Hydroponic simulations are configured through a `*HYDROPONIC SOLUTION` section added to the standard DSSAT experiment file (.LUX). The parser (ipexp.for) reads the following inputs at simulation initialisation:

**Initial solution state variables** (all read once at sowing date):

| Variable | Description | Unit |
|---|---|---|
| SOLVOL | Solution depth (volume per unit area) | mm |
| EC_INIT | Initial electrical conductivity | dS m⁻¹ |
| PH_INIT | Initial solution pH | dimensionless |
| DO_INIT | Initial dissolved oxygen concentration | mg L⁻¹ |
| TEMP_INIT | Initial solution temperature | °C |
| CNO3_INIT | Initial NO₃-N concentration | mg L⁻¹ |
| CNH4_INIT | Initial NH₄-N concentration | mg L⁻¹ |
| CP_INIT | Initial phosphorus (P) concentration | mg L⁻¹ |
| CK_INIT | Initial potassium (K) concentration | mg L⁻¹ |
| CNA_INIT | Initial sodium (Na) concentration | mg L⁻¹ |

**Management control flags** (single character, read from experiment file):

| Flag | Options | Description |
|---|---|---|
| AUTO_PH | Y / N | Y: pH held constant at PH_INIT each timestep (managed system); N: pH integrates freely |
| AUTO_VOL | Y / N | Y: solution volume replenished to SOLVOL daily to replace transpiration losses; N: volume drifts |
| AUTO_CONC | O / I / N | O: replenish to optimal EC range; I: replenish to initial EC; N: no replenishment (depletion mode) |
| AUTO_O2 | Y / N | Y: dissolved oxygen (DO₂) pinned to DO_INIT each timestep (aerated system); N: DO₂ integrates dynamically from root respiration and aeration (Benson & Krause, 1984) |

These parameters are stored in the ModuleData shared memory structure using the 'HYDRO' module identifier. Because CROPGRO's root temperature and development subroutines require a soil profile object regardless of growing system, a minimal single-layer soil structure is programmatically initialised with generic properties; this object is never accessed by any hydroponic subroutine and exists solely for numerical compatibility.

### Source Code Modifications

Source code modifications were confined to five existing DSSAT-CSM subroutines. The experiment file parser (ipexp.for) was extended by approximately 120 lines to detect and parse the `*HYDROPONIC SOLUTION` section. The SPAM subroutine (SPAM.for) was modified with a conditional block to call HYDRO_WATER when ISWHYDRO = 'Y', replacing the standard soil water balance. The nitrogen uptake subroutine (NUPTAK.for), the potassium uptake subroutine (K_Uptake.for), and the phosphorus uptake subroutine (P_Uptake.for) were each modified with analogous conditional blocks to redirect nutrient uptake calculation through HYDRO_NUTRIENT, SOLKi, and SOLPi, respectively.

Inter-module communication employs exclusively the DSSAT ModuleData shared memory architecture, using GET and PUT calls with the 'HYDRO' identifier. No global Fortran common blocks or module-level shared variables are introduced, consistent with the loose-coupling design principle of DSSAT-CSM (Jones et al., [2003](https://doi.org/10.1016/S1161-0301(02)00107-7)).

### Daily Execution Sequence

The complete daily simulation execution sequence within the INTEGR phase is: HYDRO_FERT applies any scheduled nutrient additions; HYDRO_WATER executes the water balance and applies the transpiration-driven concentration factor to all ion pools; SOLEC recomputes solution electrical conductivity and EC stress factors on the updated concentrations; SOLPH integrates solution pH and computes pH-dependent nutrient availability factors; and finally, within the CROPGRO–NUPTAK pathway, HYDRO_NUTRIENT calculates and integrates nitrogen uptake, SOLKi calculates and integrates potassium uptake, and SOLPi calculates and integrates phosphorus uptake. This ordering ensures that EC and pH stress factors are recomputed from post-transpiration concentrations before nutrient uptake kinetics are finalised. SOLEC and SOLPH are also called in the RATE phase (before HYDRO_WATER) to provide preliminary stress factors for plant growth calculations that occur earlier in the daily timestep.

---

## Nutrient Uptake: Induction, Demand Caps, and Mass Depletion (HYDRO_NUTRIENT, SOLKi, SOLPi)

### Michaelis–Menten Kinetic Framework

Nutrient uptake for NO₃⁻, NH₄⁺, K⁺, and PO₄-P is computed using Michaelis–Menten kinetics with a minimum concentration threshold (C_min), with ion-specific maximum uptake rate (J_max, mol m⁻² root s⁻¹), half-saturation constant (K_m, mol m⁻³), and minimum concentration (C_min, mol m⁻³) read from the species parameter file (LUGRO048.SPE). Base values for J_max, K_m, and C_min for each ion are taken from Silberbush et al. ([2005](https://doi.org/10.1007/s11104-004-3093-z), Table 1), which extended and updated the kinetic parameter set of Silberbush & Ben-Asher ([2001](https://doi.org/10.1023/A:1010382321883)) to include C_min = 0.002 mol m⁻³ for all major ions. The base uptake rate for each ion *i* is:

U_i = J_max,i × (C_i − C_min,i) / (K_m,i + (C_i − C_min,i))   **(Eq. 1)**

(Silberbush & Ben-Asher, [2001](https://doi.org/10.1023/A:1010382321883); Silberbush et al., [2005](https://doi.org/10.1007/s11104-004-3093-z))

where C_i is the current solution concentration of ion *i* (mol m⁻³) and C_min,i is the minimum concentration below which net uptake is zero (mol m⁻³; C_min = 0.002 mol m⁻³ for NO₃⁻, NH₄⁺, K⁺, PO₄-P; Silberbush et al., [2005](https://doi.org/10.1007/s11104-004-3093-z)). Stress multipliers for EC and pH (described below) are applied to J_max,i before evaluation.

### Nitrate Transporter Induction

Nitrate uptake by plant roots is regulated not only by external solution concentration but also by the transcriptional induction of high-affinity NRT2-family transporter genes in response to external NO₃⁻ availability (Forde & Clarkson, [1999](https://doi.org/10.1016/S0065-2113(08)60887-5); Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2)). To capture this concentration-dependent induction, a multiplicative enhancement factor is applied to J_max for NO₃⁻ before evaluation of the Michaelis–Menten equation:

INDUCT_NO3 = 1 + β_ind × (C_NO3 / MW_N)   **(Eq. 2)**

(Silberbush & Ben-Asher, [2001](https://doi.org/10.1023/A:1010382321883), Table 1; Silberbush et al., [2005](https://doi.org/10.1007/s11104-004-3093-z), Table 1)

where C_NO3 is the current solution concentration of NO₃-N (mg L⁻¹), MW_N = 14.0067 g mol⁻¹ converts C_NO3 to mol m⁻³, and β_ind (mol m⁻³ per mol m⁻³) is the induction slope coefficient read from LUGRO048.SPE. The coefficient β_ind = 0.21 is taken directly from the NO₃⁻ J_max induction term (1 + 0.21·C_NO3) reported in Silberbush & Ben-Asher ([2001](https://doi.org/10.1023/A:1010382321883), Table 1) and retained in Silberbush et al. ([2005](https://doi.org/10.1007/s11104-004-3093-z), Table 1), based on measured uptake kinetics across plant species in soilless culture. As solution NO₃-N is progressively depleted across the growing cycle, INDUCT_NO3 declines toward unity, representing down-regulation of high-affinity transport at low external nitrate concentrations.

### Plant Demand Caps

To maintain physical consistency between solution chemistry and plant growth modules, kinetically computed daily uptake of each nutrient is capped at the plant's physiological demand. For nitrogen, the cap is the daily plant nitrogen demand (ANDEM, kg N ha⁻¹ d⁻¹) computed within the CROPGRO growth framework. If the sum of kinetically computed NO₃⁻ and NH₄⁺ uptake exceeds ANDEM, both values are scaled proportionally downward while preserving their ratio, ensuring that the model does not simulate luxury nitrogen uptake beyond what the plant can assimilate (Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2)):

If (U_NO3 + U_NH4) > ANDEM:  U_i = U_i × [ANDEM / (U_NO3 + U_NH4)]   **(Eq. 3)**

(Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2))

For potassium and phosphorus, daily demand values (KTOTDEM and PTOTDEM, kg ha⁻¹ d⁻¹) are retrieved from ModuleData, where they are stored each day by the K_Plant.for and P_Plant.for subroutines, respectively. The one-day lag inherent to this explicit-Euler integration is accepted as negligible given the slowly varying nature of daily plant demand.

### Mass Depletion and Solution Concentration Update

Following determination of final realised uptake rates, the daily mass removed from solution for each nutrient is subtracted from the reservoir. The depletion of solution concentration (ΔC_i, mg L⁻¹ d⁻¹) is calculated from the uptake flux (U_i, kg ha⁻¹ d⁻¹) and current solution volume per unit area:

ΔC_i = (U_i × 10⁶) / (SOLVOL_mm × 10,000)   **(Eq. 4)**

(Silberbush et al., [2005](https://doi.org/10.1007/s11104-004-3093-z))

where U_i × 10⁶ converts kg to mg, and SOLVOL_mm × 10,000 converts solution depth (mm) to liters per hectare (1 mm over 10,000 m² ha⁻¹ = 10,000 L ha⁻¹). Updated concentration is bounded below at zero. A minimum solution volume of 10 L ha⁻¹ is enforced in the denominator to prevent division by zero under extreme drift scenarios.

### Two-Phase RATE/INTEGR Execution

Nutrient uptake computations are structured across DSSAT-CSM's standard RATE and INTEGR simulation phases. During the RATE phase, preliminary kinetic uptake estimates are computed using current-day solution concentrations and made available to the CROPGRO plant growth engine for carbon–nitrogen balance calculations. During the subsequent INTEGR phase, uptake rates are recomputed using post-transpiration solution concentrations — after HYDRO_WATER has applied the daily concentration factor — and the resulting masses are subtracted from the solution reservoir (Silberbush et al., [2005](https://doi.org/10.1007/s11104-004-3093-z)).

---

## EC Stress Functions and Automated Concentration Management (SOLEC)

### Sub-Optimal EC: Linear Deficiency Stress Function

When solution EC falls below the lower boundary of the optimal range (EC_OPT_LOW, dS m⁻¹, read from LUGRO048.SPE), nutrient supply becomes limiting because at concentrations well below the Michaelis–Menten half-saturation constant, uptake rate is approximately proportional to concentration (Bugbee, [2004](https://doi.org/10.17660/ActaHortic.2004.648.39)). A linear stress factor is applied:

f_EC,LOW = f_min + (1 − f_min) × (EC_CALC / EC_OPT_LOW),   constrained to [f_min, 1.0]   **(Eq. 5)**

(Bugbee, [2004](https://doi.org/10.17660/ActaHortic.2004.648.39); Hosseini et al., [2021](https://doi.org/10.3390/horticulturae7090283))

where f_min is a species-level floor parameter (dimensionless, read from LUGRO048.SPE) representing residual metabolic activity when nutrient supply is severely limiting. The floor parameter is not empirically derived at EC = 0 — no experiment with true zero-EC nutrient solution was available for lettuce — and its value is informed by the minimum relative yield observed in low-EC experiments (Hosseini et al., [2021](https://doi.org/10.3390/horticulturae7090283)). Its uncertainty at EC values below experimentally tested ranges is acknowledged as a model limitation.

### Supra-Optimal EC: Exponential Decay Stress Function

When EC exceeds the upper boundary of the optimal range (EC_OPT_HIGH, dS m⁻¹, read from LUGRO048.SPE), osmotic stress and ion-specific toxicity impose a progressively increasing growth and uptake penalty (Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911)). An exponential decay function is applied:

f_EC,HIGH = exp(−k × (EC_CALC − EC_OPT_HIGH)),   constrained to [f_floor, 1.0]   **(Eq. 6)**

(Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911); Shannon & Grieve, [1999](https://doi.org/10.1016/S0304-4238(98)00189-7))

where k (dS⁻¹ m) is the decay constant read from LUGRO048.SPE and f_floor is a minimum stress floor. The value of k is derived from published EC₅₀ estimates for lettuce salinity tolerance: Shannon and Grieve ([1999](https://doi.org/10.1016/S0304-4238(98)00189-7)) reported the yield-reducing EC threshold in saturated-paste extract (ECₑ), which is converted to nutrient solution EC using the standard ECₑ-to-solution ratio (Sonneveld & Voogt, [2009](https://doi.org/10.1007/978-90-481-2532-6)). This conversion factor is recipe- and cultivar-dependent (range approximately 0.35–0.6), introducing uncertainty in the derived k that is acknowledged as a model limitation.

The combined EC stress factor applied at each timestep is the minimum of the two component functions:

f_EC = min(f_EC,LOW, f_EC,HIGH)   **(Eq. 7)**

Within the optimal range (EC_OPT_LOW ≤ EC ≤ EC_OPT_HIGH), both components equal 1.0 and no EC stress is imposed.

### Na⁺ Ion-Specific Inhibition

When Na⁺ concentration exceeds a threshold specified in LUGRO048.SPE (mg L⁻¹), ion-specific inhibition functions replace the aggregate EC stress: J_max for NH₄⁺ is suppressed linearly by Na⁺ concentration, and J_max for K⁺ and PO₄-P is suppressed exponentially. These inhibition forms follow Silberbush & Ben-Asher ([2001](https://doi.org/10.1023/A:1010382321883), Table 1), where NH₄⁺ J_max carries a −0.02·C_Na factor and K⁺ J_max carries an e^(−0.0136Na) factor. The Na⁺ threshold of 0.1 mM (the critical concentration for Na⁺ passive influx; Silberbush & Ben-Asher, [2001](https://doi.org/10.1023/A:1010382321883), Eq. 7) is the concentration below which Na⁺ contributes negligibly to transporter inhibition. Inhibition coefficients (K_INHIB, mol m⁻³) for each ion are read from LUGRO048.SPE.

### Photosynthesis Stress Linkage

In addition to its effect on nutrient transporter kinetics, the sub-optimal EC stress factor (f_EC,LOW) is applied as a direct multiplier to the hourly canopy gross photosynthesis (PG) when ISWHYDRO = 'Y'. This linkage reflects the physiological basis that nutrient deficiency at low EC reduces nitrogen supply to leaf mesophyll cells, lowering photosynthetic electron transport capacity (Jmax) and thus carbon assimilation rate (Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2); Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911)). The stress is applied in CROPGRO.for immediately after the call to ETPHOT (which executes the leaf-level hourly photosynthesis calculation when MEPHO = 'L'):

PG_stressed = PG_unlimited × f_EC,LOW   **(Eq. 8)**

(Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2); Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911))

The supra-optimal EC stress factor (f_EC,HIGH) is deliberately excluded from the photosynthesis multiplier, because the primary mechanism of high EC on gas exchange operates through osmotic-driven stomatal closure rather than through direct impairment of mesophyll biochemistry (Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911)). Applying both f_EC,LOW and f_EC,HIGH to PG would double-penalise the plant through parallel pathways that represent the same underlying stress event.

### Transpiration Stress Linkage

When solution EC exceeds EC_OPT_HIGH, osmotic potential of the nutrient solution decreases, reducing the leaf-to-solution water potential gradient and inducing stomatal closure (Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911)). To represent this mechanism, the supra-optimal EC stress factor (f_EC,HIGH, ECSTRESS_TRANSP) is retrieved from ModuleData in SPAM.for and applied as a multiplier to potential canopy transpiration (EOP) to obtain actual transpiration (EP) in hydroponic mode:

EP = EOP × f_EC,HIGH   **(Eq. 9)**

(Munns & Tester, [2008](https://doi.org/10.1146/annurev.arplant.59.032607.092911); Silberbush & Ben-Asher, [2001](https://doi.org/10.1023/A:1010382321883))

When EC is within or below the optimal range, f_EC,HIGH = 1.0 and transpiration is unrestricted by osmotic stress. This formulation ensures that low EC (nutrient deficiency) penalises photosynthetic capacity and growth directly, while high EC (osmotic stress) penalises transpiration — distinct mechanisms applied through separate pathways without double-penalisation.

### Automated Concentration Management (AUTO_CONC)

Three automated replenishment modes are implemented within the SOLEC INTEGR phase, controlled by the AUTO_CONC flag in the experiment file. Under AUTO_CONC = O (optimum mode), nutrient concentrations are rescaled upward whenever EC_CALC falls below EC_OPT_LOW, restoring EC to EC_OPT_HIGH. This mode simulates standard commercial feed-and-drift management (Bugbee, [2004](https://doi.org/10.17660/ActaHortic.2004.648.39); Sonneveld & Voogt, [2009](https://doi.org/10.1007/978-90-481-2532-6)). Under AUTO_CONC = I (initial EC mode), concentrations are rescaled whenever EC_CALC falls below 99% of the formula-derived initial EC (EC_CALC_INIT), restoring EC to EC_CALC_INIT; this mode maintains a specific user-defined recipe throughout the crop cycle. Under AUTO_CONC = N (no replenishment), the solution operates in pure depletion mode, consistent with the approach of Silberbush et al. ([2005](https://doi.org/10.1007/s11104-004-3093-z)).

---

## Solution pH Dynamics and pH-Dependent Nutrient Availability (SOLPH)

The pH of the nutrient solution is a primary determinant of nutrient availability and root transporter kinetics in hydroponic systems (Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1); Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2)). Outside the optimal pH range, nutrient precipitation — particularly of iron, manganese, and phosphorus at alkaline pH (Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108); Sonneveld & Voogt, [2009](https://doi.org/10.1007/978-90-481-2532-6)) — and direct transporter inhibition reduce both nutrient uptake and plant growth. The SOLPH module implements a prognostic (forward-integration) approach to pH simulation, advancing solution pH one day at a time from the net H⁺ exchange associated with differential nitrogen form uptake.

### Stoichiometric H⁺ Production from N-Form Uptake

The principal driver of pH change in recirculating hydroponic solutions is the differential absorption of NH₄⁺ and NO₃⁻ (Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1)). Each mole of NH₄-N assimilated releases one mole of H⁺ to the external solution through charge compensation at the root plasma membrane, whereas each mole of NO₃-N assimilated consumes one mole of H⁺ (Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2)). The net daily molar H⁺ production rate (Ḣ⁺, mol ha⁻¹ d⁻¹) is:

Ḣ⁺ = [(U_NH4 − U_NO3) × 1000] / MW_N   **(Eq. 10)**

(Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1); Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2))

where U_NH4 and U_NO3 are daily NH₄-N and NO₃-N uptake rates (kg ha⁻¹ d⁻¹), the factor 1000 converts kg to g, and MW_N = 14.0067 g mol⁻¹. In the typical case of predominantly NO₃⁻-based nutrition recommended for lettuce (Bugbee, [2004](https://doi.org/10.17660/ActaHortic.2004.648.39)), Ḣ⁺ is negative, driving monotonic alkaline pH drift over the growing cycle.

### Prognostic pH Integration

The daily pH increment (ΔpH) is obtained by dividing net H⁺ production by the total buffer capacity of the solution (β_total, mol H⁺ per pH unit):

ΔpH = −(Ḣ⁺ × A / 10,000) / β_total   **(Eq. 11)**

(Heinen, [1994](#ref-heinen1994); Silberbush et al., [2005](https://doi.org/10.1007/s11104-004-3093-z))

where A is the growing area (m²) and division by 10,000 converts ha to m². The result is clamped to a maximum absolute daily increment to prevent numerical instability on days with extreme N-form uptake imbalances; this clamp is set wider than the maximum daily pH excursion observed in unmanaged recirculating systems (Heinen, [1994](#ref-heinen1994)) and is not reached under normal simulation conditions. The updated pH is stored in ModuleData for retrieval by all nutrient uptake modules in the same timestep.

A diagnostic charge-balance approach — solving pH algebraically from ionic charge neutrality, following Silberbush et al. ([2005](https://doi.org/10.1007/s11104-004-3093-z)) — was evaluated as an alternative. However, this approach requires all major ions to be tracked dynamically. In the present model, only N, P, and K are prognostic state variables; Ca²⁺, Mg²⁺, and SO₄²⁻ are held at their initial values. This causes the residual charge term to change sign on alternate days, driving unrealistic pH oscillations. The prognostic approach avoids this instability by integrating only the computable component of H⁺ exchange.

The fixed Ca²⁺ and Mg²⁺ assumption also affects EC calculation: since these ions typically contribute 25–40% of total EC in standard lettuce nutrient recipes (Sonneveld & Voogt, [2009](https://doi.org/10.1007/978-90-481-2532-6)), holding them constant causes EC_CALC to progressively overestimate true EC as the crop depletes these ions. This bias is estimated to remain within the optimal EC range for the crop durations used here, but represents a limitation for long-duration simulations. Tracking Ca²⁺ and Mg²⁺ as dynamic state variables is identified as the primary avenue for future model improvement.

### Buffer Capacity Components

The total buffer capacity β_total (mol H⁺ per pH unit) is the sum of three components evaluated at the current pH and solution volume V (liters):

**CO₂-equilibrium bicarbonate.** The equilibrium bicarbonate concentration at the current pH is (Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108)):

[HCO₃⁻] = K₁ × [CO₂(aq)] / [H⁺]   **(Eq. 12)**

(Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108))

where K₁ = 4.47 × 10⁻⁷ is the first dissociation constant of carbonic acid at 25°C (Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108)) and [CO₂(aq)] is computed from Henry's law using the ambient CO₂ concentration specified in the experiment file (pCO₂, ppm):

[CO₂(aq)] = K_H × pCO₂   **(Eq. 13)**

(Sander, [2015](https://doi.org/10.5194/acp-15-4399-2015))

where K_H = 3.4 × 10⁻² mol L⁻¹ atm⁻¹ at 25°C (Sander, [2015](https://doi.org/10.5194/acp-15-4399-2015)). The model reads the experiment-specific CO₂ concentration so that [CO₂(aq)] — and therefore bicarbonate buffer capacity — correctly reflects each experimental condition. Its buffer capacity contribution is:

β_CO2 = 2.303 × [HCO₃⁻] × V   **(Eq. 14)**

(Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108))

**Background alkalinity.** A fixed background alkalinity (BGALKAL, mol L⁻¹, read from LUGRO048.SPE) is included to represent dissolved bicarbonate from irrigation water (Sonneveld & Voogt, [2009](https://doi.org/10.1007/978-90-481-2532-6)):

β_BG = 2.303 × BGALKAL × V   **(Eq. 15)**

(Sonneveld & Voogt, [2009](https://doi.org/10.1007/978-90-481-2532-6))

This term provides a physically realistic minimum buffer capacity at low pH values where CO₂-equilibrium bicarbonate approaches zero.

**Phosphate buffering.** The dihydrogen phosphate–monohydrogen phosphate equilibrium (pKa₂ = 7.21 at 25°C, ionic strength → 0; Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108)) contributes additional buffering capacity:

β_P = 2.303 × (C_P / MW_P) × V × f × (1 − f)   **(Eq. 16)**

(Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108))

where C_P is the current solution phosphorus concentration (mg L⁻¹), MW_P = 30.97 g mol⁻¹, and f = 10^(pH − 7.21) / [1 + 10^(pH − 7.21)] is the fraction of total P as HPO₄²⁻. The total buffer capacity is:

β_total = β_CO2 + β_BG + β_P   **(Eq. 17)**

(Stumm & Morgan, [1996](https://doi.org/10.1002/iroh.19970820108))

### pH-Dependent Nutrient Availability Factors

Following the daily pH update, SOLPH computes two pH-dependent modification factors for each tracked nutrient (NO₃⁻, NH₄⁺, PO₄-P, K⁺). The first is a Gaussian availability factor that scales J_max downward as pH deviates from the species optimum (PH_OPT, read from LUGRO048.SPE) in either direction (Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1)):

f_pH,i = exp[−(pH − PH_OPT)² / (2σ_i²)]   **(Eq. 18)**

(Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1); Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2))

where σ_i (dimensionless, read from LUGRO048.SPE) controls the width of the pH tolerance window for ion *i*. The second is an exponential K_m modifier that increases the apparent Michaelis–Menten affinity constant as pH departs from the optimum, reflecting reduced substrate affinity of the transporter protein (Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2)):

f_Km,pH,i = exp(α_i × |pH − PH_OPT|)   **(Eq. 19)**

(Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2); Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1))

where α_i (dimensionless, read from LUGRO048.SPE) controls the K_m sensitivity to pH for ion *i*. Phosphorus receives the narrowest availability window and the largest K_m sensitivity, reflecting the well-documented sharp decline in H₂PO₄⁻ availability above pH 6.5 (Marschner, [2012](https://doi.org/10.1016/C2009-0-02533-2); Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1)). Potassium receives the broadest availability window and the smallest K_m sensitivity, consistent with the relative pH insensitivity of HKT-family K⁺ transporters (Haynes, [1990](https://doi.org/10.1016/S0065-2113(08)60484-1); Schachtman & Schroeder, [1994](https://doi.org/10.1038/370655a0)). Species-level values for σ_i and α_i are listed in the species file (LUGRO048.SPE) and are reported in the Results section alongside the calibrated parameter set.

The SOLPH module supports two operational modes. Under AUTO_PH = Y, pH is held constant at the user-specified target at each timestep, simulating daily acid or base addition in managed commercial systems. Under AUTO_PH = N, pH integrates freely under the prognostic framework, enabling research simulations of unmanaged pH drift.

---

## Temperature Response Parameterisation (LUGRO048.SPE)

### CROPGRO Photosynthetic Temperature Response Structure

CROPGRO models leaf-level photosynthetic temperature response through the XLMAXT/YLMAXT lookup table, a six-point piecewise-linear interpolation function applied hourly to the light-saturated leaf photosynthesis rate (LMXREF) when MEPHO = 'L'. The function yields a dimensionless temperature multiplier TEMPMX, normalised to 1.0 at 30°C. XLMAXT specifies six cardinal temperatures (°C) and YLMAXT specifies the corresponding multiplier values (dimensionless, 0–1). A separate chilling function (FNPGL) applies a quadratic reduction in daily leaf Pmax as a function of minimum daily temperature (TMIN, °C), parameterised by a lower threshold temperature X1 (°C) below which chilling effects begin.

Default DSSAT-CSM parameters for these functions were derived from soybean (Boote et al., [1998](https://doi.org/10.2134/agronmonogr40.c3)) and are inappropriate for lettuce, which has a substantially lower base temperature and a higher Jmax optimum. Recalibration of XLMAXT, YLMAXT, and FNPGL for lettuce was therefore required.

### Scientific Basis for Cardinal Temperature Selection

The XLMAXT/YLMAXT cardinal temperatures for lettuce were grounded in the published physiology of C3 leaf electron transport. The relevant temperature boundaries and their literature support are: (1) base temperature for leaf photosynthesis, informed by lettuce growth studies (Wheeler et al., [1993](https://doi.org/10.1016/s1161-0301(14)80178-0); Wurr et al., [1996](https://doi.org/10.1016/s0304-4238(96)00925-9)); (2) Jmax optimum temperature at elevated CO₂, informed by Rubisco activase thermal stability and the elevated-CO₂ shift in electron transport optima (Crafts-Brandner & Salvucci, [2000](https://doi.org/10.1126/science.287.5452.1477); Sage & Kubien, [2007](https://doi.org/10.1111/j.1365-3040.2007.01682.x)); (3) the rate of Jmax decline above the optimum (Sage & Kubien, [2007](https://doi.org/10.1111/j.1365-3040.2007.01682.x)); and (4) the temperature of irreversible Photosystem II denaturation (Berry & Björkman, [1980](https://doi.org/10.1146/annurev.pp.31.060180.002423)). The FNPGL chilling threshold X1 was informed by documented chilling-induced reductions in photosynthetic capacity at sub-optimal temperatures (Ensminger et al., [2006](https://doi.org/10.1111/j.1399-3054.2006.00627.x)). Calibrated values of XLMAXT, YLMAXT, and FNPGL X1 are reported in the Results section.

### Iterative Calibration Procedure

Calibration of the XLMAXT/YLMAXT array and FNPGL X1 proceeded by iterative manual adjustment guided by the scientific constraints above. The objective function was root mean square error (RMSE, kg ha⁻¹) computed across a nine-treatment batch comprising three representative datasets: Skyphos at four temperatures (UFGA2201), Waldmanns Green at four temperatures (UFGA2402), and Sitonia in the Wageningen greenhouse (WAGA9101). Calibration history and final parameter values are reported in the Results section.

---

## Cultivar Parameter Calibration (LUGRO048.CUL)

### Calibration Framework: GLUE with Monte Carlo Sampling

Cultivar-level parameters were calibrated using the Generalized Likelihood Uncertainty Estimation (GLUE) framework as implemented in DSSAT-CSM (Beven & Binley, [1992](https://doi.org/10.1002/hyp.3360060305); Ferreira et al., [2024](https://doi.org/10.1016/j.compag.2024.109513)). GLUE operates by sampling a large ensemble of parameter sets from prior distributions, evaluating each set by running the full model simulation, and computing an informal likelihood measure from agreement between simulated and observed values. Rather than producing a formal posterior distribution, GLUE identifies behavioural parameter sets and the parameter set yielding the minimum RMSE is selected as the calibrated estimate. This approach is robust to non-Gaussian likelihood surfaces and is computationally tractable for crop models with expensive forward simulations (Beven & Binley, [1992](https://doi.org/10.1002/hyp.3360060305); Ferreira et al., [2024](https://doi.org/10.1016/j.compag.2024.109513)). In the present application, 10,000 Monte Carlo samples were drawn for each cultivar calibration run from uniform prior distributions bounded by the species-level MINIMA and MAXIMA specified in LUGRO048.SPE. GLUE was configured with GLUEFlag = 3, restricting calibration to growth-rate parameters and leaving phenological parameters unchanged. EcotypeCalibration was set to N to prevent ecotype-level parameters from being modified during cultivar-specific runs.

### Parameters Optimised

Two primary parameters were optimised. SLAVR (specific leaf area of newly formed leaves, cm² g⁻¹) determines the relationship between leaf dry mass and leaf area, governing the rate of canopy development and light interception during vegetative growth. LFMAX (maximum leaf photosynthesis rate at 30°C and optimum CO₂, mg CO₂ m⁻² s⁻¹) scales the absolute rate of carbon assimilation and is multiplied by the temperature modifier TEMPMX and the CO₂ response function at each hourly timestep. Together, these two parameters jointly determine simulated shoot dry weight at harvest under given environmental conditions.

### Cultivar-Specific Calibration Targets

For butterhead cultivars Rex, Muir, and Skyphos, GLUE was run against all harvest-date CWAM observations from UFGA2201 (three cultivars × four temperature treatments), using minimisation of RMSE as the likelihood measure. For Sitonia, GLUE was run against the seven WAGA9101 time-course CWAD measurements with harvest CWAD as the primary target. For Bibb, a simultaneous species- and cultivar-level GLUE run (SpeciesCalibration = Y) was conducted against all six harvest-date CWAM observations from GTGA2401. This configuration simultaneously optimised SLAVR, LFMAX, and two species-level photosynthesis parameters governing the leaf-nitrogen effect on canopy photosynthesis: FNPGN1 (the leaf N% below which gross photosynthesis PG = 0) and FNPGN2 (the leaf N% at which the age–nitrogen factor AGEFAC rises to 1.0, marking the onset of the photosynthesis plateau). Because FNPGN1 and FNPGN2 are species-level parameters shared across all cultivars, their recalibration from a single Bibb dataset is acknowledged as a limitation; verification against cultivars with measured leaf-N × photosynthesis response data is identified as a priority for future validation. BG23-1251 and Waldmanns Green were assigned initial parameter estimates in the absence of cultivar-specific calibration data. Calibrated values for all parameters are reported in the Results section.

---

### Case studies

The application and calibration of the hydroponic extension are illustrated through four case studies. Each case study exemplifies the calibration of the model for lettuce (*Lactuca sativa* L.) using data collected from independent controlled-environment NFT or soilless systems. The case studies span a range of cultivar types, air temperature regimes, and nutrient supply levels, encompassing five cultivars and a total of fifteen treatment combinations. All simulations used hourly weather data (WTHER = H in the experiment file METHODS section), which is required for the leaf-level hourly photosynthesis module (MEPHO = 'L') to resolve the sub-daily variation in radiation and temperature that drives canopy carbon assimilation in controlled-environment systems. The primary comparison variable for all case studies is shoot dry weight at harvest (CWAM or CWAD, kg ha⁻¹). A summary of all four case studies is provided in Table 1.

**Table 1.** Summary of experimental case studies used for model calibration and evaluation.

| Case Study | Location | Cultivar(s) | Temperature (°C) | Photoperiod | CO₂ (ppm) | Population (plants m⁻²) | Harvest | Primary Use |
|---|---|---|---|---|---|---|---|---|
| WAGA9101 | Wageningen, NL | Sitonia | 15/10 day/night | Ambient | 709 | 15.6 | 7 time points (weeks 0–7) | Mass-balance validation; Sitonia calibration |
| UFGA2201 | Gainesville, FL | Rex, Muir, Skyphos | 24, 26, 28, 30 (day/19°C night) | 16.5 h LED | 705–770 | 12.3 | DAS 35 | Temperature response; cultivar calibration |
| UFGA2402 | Gainesville, FL | BG23-1251, Waldmanns Green | 21.25, 24.75, 30.75, 33.75 (mean) | 16.5 h LED | 405–635 | 16 | DAS 35 | Extended temperature range; transferability evaluation |
| GTGA2401 | Atlanta, GA | Bibb | 21.5 (constant) | 12 h LED | ~400 | 16 | DAT32 (DAS45) | N-level response; species and Bibb calibration |

#### Case study 1: Wageningen NFT time-series — Sitonia butterhead calibration

Data for butterhead lettuce (*Lactuca sativa* L. cv. Sitonia) were obtained from a recirculating NFT experiment (experiment 6705) conducted at Wageningen University, The Netherlands, and reported by Heinen ([1994](#ref-heinen1994)). Plants were grown in a greenhouse with a controlled daytime temperature setpoint of 15°C and nighttime setpoint of 10°C during June–July 1991. Seeds were sown three weeks before transfer to the NFT gullies, and the total growth period was seven weeks (June 3 to July 22, 1991). The greenhouse CO₂ concentration was 709 ppm. Plants were placed at a population density of 15.6 plants m⁻² (144 plants in 12 gullies of 326.5 × 23.5 cm, corresponding to a greenhouse area of 9.21 m²). The nutrient solution volume was approximately 168 L (72.8 mm equivalent depth over the greenhouse area), with an initial NO₃-N concentration of 82.2 mg L⁻¹, EC of 0.86 dS m⁻¹, and pH setpoint of 6.0 (range 5.5–6.5).

Shoot dry weight per unit area (CWAD, kg ha⁻¹) was measured at seven harvest times — at transplanting (t = 0) and at weeks 1, 2, 4, 5, 6, and 7 after transplanting — providing a full time-course growth trajectory. Daily nutrient solution concentrations of NO₃-N, phosphorus (P), and potassium (K) were also recorded throughout the experiment. This dataset was used for both Sitonia cultivar-level parameter calibration and as the primary mass-balance validation target for the nutrient depletion modules, as it directly underpins the soilless culture model of Silberbush & Ben-Asher ([2001](https://doi.org/10.1023/A:1010382321883)) and Silberbush et al. ([2005](https://doi.org/10.1007/s11104-004-3093-z)) from which the Michaelis–Menten kinetic parameters and flow model structure were derived. Nutrient solution concentration was managed manually by daily dosing (AUTO_CONC = O), with GLUE calibration conducted using N = 10,000 Monte Carlo samples.

#### Case study 2: Temperature × cultivar response — Rex, Muir, and Skyphos calibration

Data for three lettuce cultivars — two butterhead (*Lactuca sativa* L. cv. Rex and cv. Skyphos) and one Batavia (*Lactuca sativa* L. cv. Muir) — were obtained from a controlled-environment growth chamber experiment conducted at the University of Florida, Gainesville, FL (Pompeo et al., [2025](https://doi.org/10.13031/ja.16172)). Plants were grown in a recirculating NFT system at four day/night air temperature setpoints: 24/19, 26/19, 28/19, and 30/19°C. A photoperiod of 16.5 hours was maintained using LED lighting at a daily light integral of 13 mol m⁻² d⁻¹. CO₂ was enriched to a target of 800 mg L⁻¹; measured concentrations averaged 709, 743, 705, and 770 ppm for the 24, 26, 28, and 30°C trials, respectively. Nutrient solution was maintained at EC 1.2 dS m⁻¹ and pH 5.8, with a plant population of 12.3 plants m⁻².

All treatments were harvested at 35 days after sowing (DAS). Shoot dry weight at harvest (CWAM, kg ha⁻¹) was the primary comparison variable. Nutrient solution was not automatically replenished (AUTO_CONC = N), so the experiment operated in depletion mode throughout each grow cycle. This case study was used for calibration of cultivar-level parameters (SLAVR, LFMAX) for Rex, Muir, and Skyphos simultaneously across all four temperature treatments, with GLUE calibration conducted using N = 10,000 Monte Carlo samples per cultivar.

#### Case study 3: Extended temperature range — BG23-1251 and Waldmanns Green evaluation

A second University of Florida growth chamber dataset extended the air temperature range to heat-stress and sub-optimal cool conditions, using two additional cultivars — BG23-1251 and Waldmanns Green (*Lactuca sativa* L.) — grown at four mean air temperatures: 21.25, 24.75, 30.75, and 33.75°C (Donald et al., 2025). These mean temperatures were achieved by a 5°C day–night differential (day/night setpoints: 23.75/18.75, 27.25/22.25, 33.25/28.25, and 36.25/31.25°C, respectively). The experiment was conducted in the same NFT facility as case study 2, with a plant population of 16 plants m⁻² and a 16.5-hour LED photoperiod. CO₂ concentrations were measured per temperature group: 405, 635, 545, and 494 ppm for the 21.25, 24.75, 30.75, and 33.75°C treatments, respectively, introducing a CO₂ × temperature confound that is identified as a structural limitation during evaluation. Nutrient solution was replenished to the optimal EC range (AUTO_CONC = O). All treatments were harvested at 35 DAS, and CWAM (kg ha⁻¹) was the comparison variable.

Because BG23-1251 and Waldmanns Green lacked cultivar-specific calibration data, initial parameter estimates were assigned from the nearest calibrated cultivar type. Performance for these cultivars in this case study should therefore be interpreted as a test of species-level parameter transferability across the extended temperature range, rather than a test of the full calibration framework.

#### Case study 4: Nitrogen-level response — Bibb species and cultivar calibration

Data for Bibb lettuce (*Lactuca sativa* L.) were obtained from a vertical ZipGrow NFT system experiment conducted at the Georgia Institute of Technology, Atlanta, GA (Sharkey et al., [2024](https://doi.org/10.3390/agriculture14081358)). Plants were grown at six total nitrogen supply levels corresponding to 8, 19, 25, 50, 100, and 200% of the Modified Sonneveld's Solution (MSS) baseline: 10.58, 25.30, 33.06, 66.12, 132.24, and 264.47 mg total-N L⁻¹, spanning a range from severe N deficiency to mild osmotic excess. The NO₃-N fractions at these levels were 10.6, 25.3, 33.1, 64.9, 125.6, and 191.7 mg L⁻¹; at the two highest N levels, NH₄-N contributed an additional 6.6 and 72.8 mg L⁻¹, respectively. Phosphorus concentration varied inversely with nitrogen level (154.1, 93.9, 109.9, 31.0, 31.0, and 31.0 mg P L⁻¹) because H₃PO₄ was used for pH balancing at low-N treatments. Corresponding initial EC values were 1.13, 1.14, 1.19, 1.28, 1.62, and 2.32 dS m⁻¹. All treatments operated in initial-EC replenishment mode (AUTO_CONC = I), maintaining each treatment's initial EC rather than a common target.

Seedlings were germinated for 13 days before transplanting. Environmental conditions were held constant at 21.5°C air temperature, a 12-hour LED photoperiod, a daily light integral of 14.69 mol m⁻² d⁻¹, and ambient CO₂ (uncontrolled, approximately 400 ppm). Plant population was 16 plants m⁻². Harvest occurred at 32 days after transplanting (DAT32, equivalent to DAS45), and CWAM (kg ha⁻¹) was the comparison variable. A simultaneous species- and cultivar-level GLUE calibration (SpeciesCalibration = Y; Ferreira et al., [2024](https://doi.org/10.1016/j.compag.2024.109513)) was conducted across all six nitrogen treatments with N = 10,000 Monte Carlo samples, optimising SLAVR, LFMAX, and two species-level leaf-nitrogen photosynthesis parameters (FNPGN1, FNPGN2).

---

## Performance Evaluation Metrics

Simulated and observed shoot dry weight at harvest (CWAM, kg ha⁻¹) were compared using two complementary statistics. The root mean square error (RMSE) quantifies the average magnitude of the discrepancy between simulated and observed values (Jones et al., [2003](https://doi.org/10.1016/S1161-0301(02)00107-7)):

RMSE = √[(1/n) × Σ(y_i − ŷ_i)²]   **(Eq. 20)**

(Jones et al., [2003](https://doi.org/10.1016/S1161-0301(02)00107-7))

where y_i is the i-th observed value, ŷ_i is the corresponding simulated value, and n is the number of treatment-level comparisons.

The index of agreement (d-statistic) of Willmott ([1981](https://doi.org/10.1080/02723646.1981.10642213)) measures the degree to which simulated values match both the mean and the pattern of observed variation:

d = 1 − [Σ(y_i − ŷ_i)²] / [Σ(|ŷ_i − ȳ| + |y_i − ȳ|)²],   0 ≤ d ≤ 1   **(Eq. 21)**

(Willmott, [1981](https://doi.org/10.1080/02723646.1981.10642213))

where ȳ is the mean of observed values. A d-statistic of 1.0 indicates perfect agreement; 0 indicates no agreement. The d-statistic is preferred over the coefficient of determination (R²) for model evaluation because it is sensitive to both systematic bias and proportional differences between simulated and observed values, not merely to the linear correlation structure (Willmott, [1981](https://doi.org/10.1080/02723646.1981.10642213)).

Where relevant, two model versions were compared: a pre-calibration baseline using the original DSSAT-CSM soybean-derived species parameters, and the fully calibrated hydroponic extension.

---

## References

Benson, B. B., & Krause, D. (1984). The concentration and isotopic fractionation of oxygen dissolved in freshwater and seawater in equilibrium with the atmosphere. *Limnology and Oceanography*, 29(3), 620–632. https://doi.org/10.4319/lo.1984.29.3.0620

Beven, K., & Binley, A. (1992). The future of distributed models: Model calibration and uncertainty prediction. *Hydrological Processes*, 6(3), 279–298. https://doi.org/10.1002/hyp.3360060305

Berry, J., & Björkman, O. (1980). Photosynthetic response and adaptation to temperature in higher plants. *Annual Review of Plant Physiology*, 31, 491–543. https://doi.org/10.1146/annurev.pp.31.060180.002423

Ensminger, I., Busch, F., & Huner, N. P. A. (2006). Photostasis and cold acclimation: sensing low temperature through photosynthesis. *Physiologia Plantarum*, 126(1), 28–44. https://doi.org/10.1111/j.1399-3054.2006.00627.x

Boote, K. J., Jones, J. W., & Pickering, N. B. (1998). Potential uses and limitations of crop models. In G. Y. Tsuji, G. Hoogenboom, & P. K. Thornton (Eds.), *Understanding Options for Agricultural Production* (pp. 53–76). Springer/Kluwer Academic. https://doi.org/10.2134/agronmonogr40.c3

Bugbee, B. (2004). Nutrient management in recirculating hydroponic culture. *Acta Horticulturae*, 648, 299–316. https://doi.org/10.17660/ActaHortic.2004.648.39

Crafts-Brandner, S. J., & Salvucci, M. E. (2000). Rubisco activase constrains the photosynthetic potential of leaves at high temperature and CO₂. *Science*, 287(5452), 1477–1479. https://doi.org/10.1126/science.287.5452.1477

Ferreira, T. B., Shelia, V., Porter, C., Moreno Cadena, P., Salmeron Cortasa, M., Khan, M. S., Pavan, W., & Hoogenboom, G. (2024). Enhancing crop model parameter estimation across computing environments: Utilizing the GLUE method and parallel computing for determining genetic coefficients. *Computers and Electronics in Agriculture*, 227, 109513. https://doi.org/10.1016/j.compag.2024.109513

Forde, B. G., & Clarkson, D. T. (1999). Nitrate and ammonium nutrition of plants: Physiological and molecular perspectives. *Advances in Botanical Research*, 30, 1–90. https://doi.org/10.1016/S0065-2113(08)60887-5

Hosseini, H., Mozafari, V., & Roosta, H. R. (2021). Nutrient use in vertical farming: Optimal electrical conductivity of nutrient solution for growth of lettuce and basil in hydroponic cultivation. *Horticulturae*, 7(9), 283. https://doi.org/10.3390/horticulturae7090283

Haynes, R. J. (1990). Active ion uptake and maintenance of cation-anion balance: A critical examination of their role in regulating rhizosphere pH. *Advances in Agronomy*, 43, 227–264. https://doi.org/10.1016/S0065-2113(08)60484-1

Heinen, M. (1994). *Growth and nutrient uptake by lettuce grown on NFT* (AB-DLO Rapport 1). DLO-Instituut voor Agrobiologisch en Bodemvruchtbaarheidsonderzoek, Haren, The Netherlands.

Heinen, M., de Jager, A., & Niers, H. (1991). Uptake of nutrients by lettuce on NFT with controlled composition of the nutrient solution. *Netherlands Journal of Agricultural Science*, 39(3), 197–212. https://doi.org/10.18174/njas.v39i3.16542

Hoogenboom, G., Porter, C. H., Boote, K. J., Shelia, V., Wilkens, P. W., Singh, U., White, J. W., Asseng, S., Lizaso, J. I., Moreno, L. P., Pavan, W., Ogoshi, R., Hunt, L. A., Tsuji, G. Y., & Jones, J. W. (2019). *The DSSAT Cropping System Model* (v4.7) [Software]. Open Science Framework. https://doi.org/10.7303/CY6H-8083.2019

Jones, J. W., Hoogenboom, G., Porter, C. H., Boote, K. J., Batchelor, W. D., Hunt, L. A., Wilkens, P. W., Singh, U., Gijsman, A. J., & Ritchie, J. T. (2003). The DSSAT cropping system model. *European Journal of Agronomy*, 18(3–4), 235–265. https://doi.org/10.1016/S1161-0301(02)00107-7

Sharkey, A., Altman, A., Cohen, A. R., Groh, T., Igou, T. K. S., Ferrarezi, R. S., & Chen, Y. (2024). Modeling Bibb lettuce nitrogen uptake and biomass productivity in vertical hydroponic agriculture. *Agriculture*, 14(8), 1358. https://doi.org/10.3390/agriculture14081358

Silberbush, M., & Ben-Asher, J. (2001). Simulation study of nutrient uptake by plants from soilless cultures as affected by salinity buildup and transpiration. *Plant and Soil*, 233(1), 59–69. https://doi.org/10.1023/A:1010382321883

Silberbush, M., Ben-Asher, J., & Ephrath, J. E. (2005). A model for nutrient and water flow and their uptake by plants grown in a soilless culture. *Plant and Soil*, 271(1–2), 309–319. https://doi.org/10.1007/s11104-004-3093-z

Marschner, H. (2012). *Marschner's Mineral Nutrition of Higher Plants* (3rd ed.). Academic Press. https://doi.org/10.1016/C2009-0-02533-2

Munns, R., & Tester, M. (2008). Mechanisms of salinity tolerance. *Annual Review of Plant Biology*, 59, 651–681. https://doi.org/10.1146/annurev.arplant.59.032607.092911

Pompeo, J. P., Zhang, Y., Yu, Z., Gomez, C., Correll, M., & Bliznyuk, N. (2025). Impact of air temperature and root-zone cooling on heat-tolerant lettuce production in indoor farming under low-speed air flow conditions. *Journal of ASABE*, 68(1), 113–124. https://doi.org/10.13031/ja.16172

Sage, R. F., & Kubien, D. S. (2007). The temperature response of C3 and C4 photosynthesis. *Plant, Cell & Environment*, 30(9), 1086–1106. https://doi.org/10.1111/j.1365-3040.2007.01682.x

Sander, R. (2015). Compilation of Henry's law constants (version 4.0) for water as solvent. *Atmospheric Chemistry and Physics*, 15(8), 4399–4981. https://doi.org/10.5194/acp-15-4399-2015

Schachtman, D. P., & Schroeder, J. I. (1994). Structure and transport mechanism of a high-affinity potassium uptake transporter from higher plants. *Nature*, 370(6490), 655–658. https://doi.org/10.1038/370655a0

Shannon, M. C., & Grieve, C. M. (1999). Tolerance of vegetable crops to salinity. *Scientia Horticulturae*, 78(1–4), 5–38. https://doi.org/10.1016/S0304-4238(98)00189-7

Wheeler, T. R., Hadley, P., & Morison, J. I. L. (1993). Effects of temperature on the growth of lettuce (*Lactuca sativa* L.) and the implications for assessing the impacts of potential climate change. *European Journal of Agronomy*, 2(4), 305–311. https://doi.org/10.1016/s1161-0301(14)80178-0

Sonneveld, C., & Voogt, W. (2009). *Plant Nutrition of Greenhouse Crops*. Springer. https://doi.org/10.1007/978-90-481-2532-6

Stumm, W., & Morgan, J. J. (1996). *Aquatic Chemistry: Chemical Equilibria and Rates in Natural Waters* (3rd ed.). Wiley-Interscience. https://doi.org/10.1002/iroh.19970820108

Willmott, C. J. (1981). On the validation of models. *Physical Geography*, 2(2), 184–194. https://doi.org/10.1080/02723646.1981.10642213

Wurr, D. C. E., Fellows, J. R., & Phelps, K. (1996). Investigating trends in vegetable crop response to increasing temperature associated with climate change. *Scientia Horticulturae*, 66(3–4), 255–263. https://doi.org/10.1016/s0304-4238(96)00925-9
