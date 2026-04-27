**Hydroponic Extension of DSSAT-CSM: Solution Chemistry, Nutrient Uptake Kinetics, and Controlled-Environment Simulation for Lettuce (*Lactuca sativa* L.)**

Kapil Bhattarai^1^, Gerrit Hoogenboom^1^

^1^ Department of Agricultural and Biological Engineering, University of Florida, Gainesville, Florida

---

# Abstract

Hydroponic crop production systems deliver nutrients directly to roots in aqueous solution under precisely controlled environmental conditions, yet established crop simulation frameworks such as the DSSAT Cropping System Model (DSSAT-CSM) lack native support for soilless culture. This paper describes the design, implementation, and evaluation of a hydroponic extension to DSSAT-CSM v4.8 for lettuce (*Lactuca sativa* L.). Seven new Fortran modules — HYDRO_NUTRIENT, SOLKi, SOLPi, SOLEC, SOLPH, SOLO2, and HYDRO_WATER — replace soil-based nutrient and water processes with solution-chemistry equivalents while preserving the CROPGRO plant growth engine. Nutrient uptake follows Michaelis–Menten kinetics with minimum concentration thresholds (C_min) parameterized from Silberbush et al. (2005) for lettuce. Solution electrical conductivity (EC) is tracked from ion concentrations and used to apply non-competitive (J_max) and competitive (K_m) stress to all nutrient transporters. Solution pH is forward-integrated each day from stoichiometric H⁺ exchange during N-form uptake, divided by a three-component buffer capacity (CO₂-equilibrium bicarbonate, background alkalinity, pH-dependent phosphate). Temperature response parameters in the species file (LUGRO048.SPE) were recalibrated against nine lettuce treatments spanning 21–34°C, reducing batch RMSE from 1969 to 184 kg ha⁻¹. Cultivar parameters (LFMAX, SLAVR) were calibrated using Generalized Likelihood Uncertainty Estimation (GLUE) with 10,000 Monte Carlo samples. The leaf-nitrogen effect on photosynthesis (FNPGN) was calibrated via GLUE against six nitrogen-level treatments from Sharkey et al. (2024). The model was evaluated against four datasets: WAGA9101 (Heinen 1994, Wageningen), UFGA2201 (Pompeo et al. 2025, Gainesville), UFGA2402 (Donald et al. 2025, Gainesville), and GTGA2401 (Sharkey et al. 2024, Atlanta). For the well-constrained WAGA9101 experiment, simulated final shoot dry weight was within 5.2% of observed (3012 vs. 2862 kg ha⁻¹).

**Keywords:** DSSAT, hydroponics, NFT, lettuce, Michaelis–Menten, nutrient uptake, electrical conductivity, pH, crop simulation, controlled environment agriculture

---

1. **Material and Methods**

    a. **Experimental Datasets**

Four datasets were used for model calibration and evaluation (Table 1). WAGA9101 (Heinen, 1994) is the foundational soilless lettuce dataset from Wageningen University, providing daily time-course measurements of shoot dry weight, leaf area, and nutrient solution concentrations (NO₃-N, P, K) for Sitonia butterhead lettuce in a recirculating NFT system. This dataset directly underpins the Silberbush et al. (2005) model and was selected as the primary mass-balance validation target, with harvest at 50 days after sowing (DAS).

UFGA2201 (Pompeo et al., 2025) provided harvest-date shoot dry weight (CWAM, kg ha⁻¹) for three butterhead cultivars — Rex, Muir, and Skyphos — at four controlled air temperatures (24, 26, 28, 30°C) in a growth chamber NFT system at the University of Florida. A constant 16.5 h LED photoperiod was maintained throughout all treatments. Plant population was 12.3 plants m⁻² and harvest was at 28 DAS.

UFGA2402 (Donald et al., 2025) extended the temperature range to 21, 25, 31, and 34°C using two additional cultivars (BG23-1251 and Waldmanns Green) in the same facility. CO₂ concentration differed between temperature treatments (830 ppm at 21°C and below; 1060 ppm at 25°C and above), introducing a systematic CO₂ × temperature confound documented separately in Section 3.

GTGA2401 (Sharkey et al., 2024) provided harvest-date shoot dry weight for Bibb lettuce at six nitrogen supply levels (10.6, 25, 33, 66, 132, and 264 mg N L⁻¹) in a vertical ZipGrow NFT system at Georgia Tech, Atlanta. Conditions were 21.5°C constant air temperature, 12 h LED photoperiod (DLI = 14.69 mol m⁻² d⁻¹), ambient CO₂ (~400 ppm), and plant population of 16 plants m⁻². Harvest was at 32 days after transplanting (DAT32, DAS46). This dataset was used to calibrate the leaf-nitrogen effect on photosynthesis (FNPGN) and the Bibb cultivar parameters (LFMAX, SLAVR).

**Table 1.** *Summary of experimental datasets used for model evaluation.*

| Dataset | Location | Cultivar(s) | Temp (°C) | Photoperiod | CO₂ (ppm) | Harvest | Reference |
|---|---|---|---|---|---|---|---|
| WAGA9101 | Wageningen, NL | Sitonia | ~20 (greenhouse) | Ambient | ~370 | DAS 50 | Heinen (1994) |
| UFGA2201 | Gainesville, FL | Rex, Muir, Skyphos | 24, 26, 28, 30 | 16.5 h LED | ~800 | DAS 28 | Pompeo et al. (2025) |
| UFGA2402 | Gainesville, FL | BG23-1251, Waldmanns Green | 21, 25, 31, 34 | 16.5 h LED | 830/1060 | DAS 35 | Donald et al. (2025) |
| GTGA2401 | Atlanta, GA | Bibb | 21.5 (constant) | 12 h LED | ~400 | DAT 32 | Sharkey et al. (2024) |

    b. **Design of the Hydroponic Module System**

The DSSAT-CSM is described by Hoogenboom et al. (2019) as the core simulation engine, holding Fortran 77/90/95 subroutines for plant growth, soil processes, and input/output management. The hydroponic extension was designed as a set of modular Fortran subroutines that communicate through the existing ModuleData shared memory structure — the same mechanism used by all standard DSSAT-CSM soil and plant modules — rather than as a standalone model or a complete rewrite of the existing system. This design choice preserves full interoperability with the DSSAT ecosystem: genotype files, experiment management, batch processing, output modules, and DSSAT applications (seasonal, sequence, forecast) all function without modification.

Seven new Fortran modules were developed, each responsible for a single solution chemistry process (Figure 1). HYDRO_WATER manages solution volume tracking and the water balance. HYDRO_NUTRIENT implements nitrogen (NO₃⁻ and NH₄⁺) uptake kinetics. SOLPi implements phosphorus uptake. SOLKi implements potassium uptake. SOLEC computes solution EC from tracked ion concentrations and applies EC-based stress factors. SOLPH integrates solution pH each day from N-form uptake stoichiometry and applies pH-dependent nutrient availability functions. SOLO2 tracks dissolved oxygen and applies O₂ stress to uptake rates. All seven modules share state variables exclusively through ModuleData GET/PUT calls using the 'HYDRO' module identifier, maintaining the loose-coupling architecture of DSSAT-CSM.

Hydroponic mode is activated when the experiment file (.LUX) contains a `*HYDROPONIC SOLUTION` section, which specifies the initial solution parameters: depth (mm, equivalent to L m⁻²), EC (dS m⁻¹), pH, dissolved oxygen (mg L⁻¹), temperature (°C), and ion concentrations for NO₃-N, NH₄-N, P, and K (mg L⁻¹), along with four management control flags (AUTO_PH, AUTO_VOL, AUTO_CONC, AUTO_O2). These flags allow independent control of whether pH, solution volume, nutrient concentration, and dissolved oxygen are held constant (managed mode) or allowed to drift freely (research mode).

    c. **Integration of the Hydroponic Extension into DSSAT-CSM**

The CSM in DSSAT processes each simulation day through a sequence of phase calls: RUNINIT, SEASINIT, RATE, INTEGR, OUTPUT, and SEASEND. Each hydroponic module is called within this standard phase sequence from the appropriate existing DSSAT subroutine, requiring minimal modifications to the original CSM source code.

The input module `ipexp.for` was modified to detect the `*HYDROPONIC SOLUTION` section in the experiment file, parse and store all solution parameters into ModuleData, and set the ISWHYDRO flag in the ISWITCH control structure. When ISWHYDRO = 'Y', the hydroponic activation message is printed to the console and the soil file requirement is bypassed; a minimal single-layer soil structure is initialized programmatically for numerical compatibility with CROPGRO's root and temperature modules, which require a soil profile to be present.

The SPAM (Soil-Plant-Atmosphere Model) subroutine, which computes the water balance and transpiration partitioning, was modified to call HYDRO_WATER when ISWHYDRO = 'Y'. HYDRO_WATER intercepts the standard SPAM water balance call, sets actual transpiration equal to potential transpiration (TRWU = TRWUP = EP) unconditionally, and returns solution evaporation as zero to the soil evaporation variable (ES). This eliminates soil water stress as a growth-limiting factor, as is appropriate for well-managed hydroponic systems.

The NUPTAK subroutine, which handles N uptake in soil-based CROPGRO simulations, was modified to call HYDRO_NUTRIENT when ISWHYDRO = 'Y', bypassing the soil-layer N extraction loop. Similarly, modifications to K_Uptake.for and P_Uptake.for redirect potassium and phosphorus uptake through SOLKi and SOLPi respectively in hydroponic mode. In both cases, the standard soil-mode N:K and P:K tissue ratio guards are bypassed, as the hydroponic modules enforce demand caps directly through ModuleData-stored plant demand variables (KTOTDEM, PTOTDEM) from K_Plant.for and P_Plant.for.

SOLEC, SOLPH, and SOLO2 are called from the RATE and INTEGR phases of the main DSSAT-CSM loop. SOLEC runs first each day, computing the current solution EC from tracked ion concentrations and storing EC stress factors for J_max and K_m into ModuleData. SOLPH then runs, integrating pH forward from net H⁺ production and storing pH availability and K_m factors into ModuleData. HYDRO_NUTRIENT, SOLPi, and SOLKi retrieve these stress factors during their own RATE and INTEGR calls. The complete daily execution sequence is illustrated in Figure 2.

Source code modifications were made in five existing subroutines: `ipexp.for` (solution parameter parsing and mode activation), `SPAM.for` (HYDRO_WATER call), `NUPTAK.for` (HYDRO_NUTRIENT call), `K_Uptake.for` (SOLKi call), and `P_Uptake.for` (SOLPi call). All modifications are conditional on ISWHYDRO = 'Y', preserving complete backward compatibility with all existing soil-based simulations.

    d. **Water Balance Module (HYDRO_WATER)**

In soil-based DSSAT simulations, actual transpiration (TRWU) is limited below potential (TRWUP) when soil water supply is insufficient. In hydroponic systems designed to maintain continuous root contact with the nutrient solution, this constraint does not apply. HYDRO_WATER sets TRWU = TRWUP = EP unconditionally at each daily timestep.

Solution volume (SOLVOL, mm = L m⁻²) is tracked as a prognostic state variable updated in the INTEGR phase:

$$SOLVOL_{t+1} = SOLVOL_t + W_{add} - EP - 0.01 \times EP$$

where $W_{add}$ is the daily refill volume and the 0.01 × EP term represents solution surface evaporation (approximated as 1% of transpiration, consistent with high-LAI canopy shading of the solution surface). A minimum floor of 5.0 mm is enforced to prevent numerical instability in concentration calculations. Under AUTO_VOL = Y, $W_{add}$ restores SOLVOL to its initial value each day. Under AUTO_VOL = N, $W_{add}$ = 0 and volume drifts downward with daily transpiration losses.

As solution volume decreases between refill events, all dissolved ion concentrations rise proportionally. A concentration factor (CONC_FACTOR = SOLVOL_prev / SOLVOL_new) is computed and applied to all tracked ion concentrations (NO3_CONC, NH4_CONC, P_CONC, K_CONC) stored in ModuleData before the nutrient uptake modules execute. This conserves ion mass as pure water is removed by transpiration and ensures that uptake kinetics see the post-concentration solution state each day.

    e. **Nutrient Uptake Modules (HYDRO_NUTRIENT, SOLKi, SOLPi)**

All three macronutrients are modeled using the Michaelis–Menten kinetic framework with minimum concentration (C_min) following Epstein (1966) and Silberbush et al. (2005):

$$U_i = \frac{J_{max,i} \cdot f_{EC,i} \cdot f_{pH,i} \cdot (C_i - C_{min,i})}{K_{m,i} \cdot f_{Km,EC,i} \cdot f_{Km,pH,i} + (C_i - C_{min,i})} \times RL \times f_{O_2}, \quad C_i > C_{min,i}$$

where $U_i$ is the daily uptake flux (kg ha⁻¹ d⁻¹), $J_{max,i}$ is the maximum uptake rate per unit root length (mg cm⁻¹ d⁻¹), $K_{m,i}$ is the half-saturation concentration (mg L⁻¹), $C_i$ is the current solution concentration (mg L⁻¹), $C_{min,i}$ is the minimum threshold (mg L⁻¹), $RL$ is root length density (cm root cm⁻² ground), and $f_{EC}$, $f_{pH}$, $f_{O_2}$ are dimensionless stress factors. Baseline parameters from Silberbush et al. (2005) are listed in Table 2.

**Table 2.** *Michaelis–Menten nutrient uptake parameters for lettuce (LUGRO048.SPE). J_max converted from Silberbush et al. (2005) nmol cm⁻¹ s⁻¹ to mg cm⁻¹ d⁻¹ by multiplying by MW × 10⁻⁶ × 86400.*

| Nutrient | J_max (mg cm⁻¹ d⁻¹) | K_m (mg L⁻¹) | C_min (mg L⁻¹) | Source |
|---|---|---|---|---|
| NO₃-N | 16.82 | 2.94 | 0.028 | Silberbush et al. (2005) |
| NH₄-N | 22.27 | 10.56 | 0.028 | Silberbush et al. (2005) |
| PO₄-P | 7.60 | 0.155 | 0.0062 | Silberbush et al. (2005) |
| K | 58.44 | 0.497 | 0.078 | Silberbush et al. (2005) |

NO₃⁻ uptake includes a concentration-inducible J_max enhancement reflecting NRT transporter induction (Silberbush et al., 2005):

$$INDUCT_{NO_3} = 1 + 0.21 \times \frac{C_{NO_3}}{14.0067}$$

Total N uptake is capped at plant nitrogen demand (ANDEM) from CROPGRO. K and P demand caps (KDEMAND, PDEMAND) are sourced from KTOTDEM and PTOTDEM stored daily in ModuleData by K_Plant.for and P_Plant.for, respectively, with a one-day lag inherent to the explicit-Euler integration.

The daily RATE/INTEGR two-phase execution ensures mass conservation. The RATE phase provides uptake estimates to the CROPGRO plant growth module; the INTEGR phase recomputes uptake using post-concentration solution states (after HYDRO_WATER has applied CONC_FACTOR), then depletes ion concentrations in ModuleData. The execution order within each INTEGR phase is: HYDRO_WATER → HYDRO_NUTRIENT → SOLPi → SOLKi.

    f. **Electrical Conductivity Module (SOLEC)**

Solution EC is estimated empirically from tracked dissolved ion concentrations:

$$EC_{CALC} = \frac{(C_{NO_3} + C_{NH_4} + C_P + C_K) \times 2.5}{640}$$

where the factor 2.5 accounts for untracked counter-ions (Ca²⁺, Mg²⁺, SO₄²⁻) in a typical balanced nutrient solution (Sonneveld & Voogt, 2009). Two complementary stress functions are applied depending on whether EC is below or above the optimal range for lettuce (1.2–1.8 dS m⁻¹):

For sub-optimal EC (nutrient deficiency):
$$f_{EC,LOW} = 0.30 + 0.70 \times \frac{EC_{CALC}}{1.2}, \quad f_{EC,LOW} \in [0.30,\ 1.0]$$

For supra-optimal EC (osmotic/ionic toxicity):
$$f_{EC,HIGH} = e^{-0.277 \times (EC_{CALC} - 1.8)}, \quad f_{EC,HIGH} \in [0.10,\ 1.0]$$

The decay constant k = 0.277 dS⁻¹ m yields EC₅₀ = 4.3 dS m⁻¹, consistent with published lettuce salt tolerance thresholds (Shannon & Grieve, 1999; Akter et al., 2026). The combined stress applied to biological rates is min(f_EC,LOW, f_EC,HIGH). When Na⁺ concentration exceeds 10 mg L⁻¹, ion-specific exponential and hyperbolic J_max suppression from Silberbush et al. (2005) replaces the aggregate EC stress. An automated replenishment algorithm (AUTO_CONC = Y) rescales nutrient concentrations when EC falls below the lower optimal boundary, simulating standard feed-and-drift management (Table 3).

**Table 3.** *EC stress factor values across the EC range for hydroponic lettuce.*

| EC (dS m⁻¹) | f_EC,LOW | f_EC,HIGH | f_EC (applied) | Interpretation |
|---|---|---|---|---|
| 0.0 | 0.30 | 1.00 | 0.30 | Severe nutrient deficiency |
| 0.9 | 0.83 | 1.00 | 0.83 | Mild deficiency |
| 1.2 | 1.00 | 1.00 | 1.00 | Lower optimum boundary |
| 1.8 | 1.00 | 1.00 | 1.00 | Upper optimum boundary |
| 2.5 | 1.00 | 0.82 | 0.82 | Mild salinity stress |
| 4.3 | 1.00 | 0.50 | 0.50 | EC₅₀ — 50% reduction |
| 6.0 | 1.00 | 0.24 | 0.24 | Severe salinity stress |

    g. **pH Module (SOLPH)**

Solution pH is prognostically integrated each day. The net daily H⁺ production rate from N-form uptake stoichiometry (Haynes, 1990; Marschner, 2012) is:

$$\dot{H}^+ = \frac{U_{NH_4} \times 1000}{14.0067} - \frac{U_{NO_3} \times 1000}{14.0067} \quad \text{(mol ha}^{-1} \text{d}^{-1}\text{)}$$

reflecting one mole of H⁺ released per mole of NH₄-N assimilated and one mole consumed per mole of NO₃-N assimilated. The daily pH increment is:

$$\Delta pH = -\frac{\dot{H}^+ \times A / 10000}{\beta_{total}}$$

where $\beta_{total}$ (mol H⁺ per pH unit) is the total buffer capacity of the solution, computed as the sum of three components: CO₂-equilibrium bicarbonate at the current pH (Silberbush et al., 2005), a fixed background alkalinity term BGALKAL = 0.5 mmol L⁻¹ representing irrigation water bicarbonate (Sonneveld & Voogt, 2009), and pH-dependent phosphate buffering (pKa = 7.21). The ΔpH is clamped to ±0.5 pH units d⁻¹ to prevent numerical instability. Under AUTO_PH = Y, pH is held at the user-specified target.

pH-dependent availability factors (Gaussian, reducing J_max) and K_m modifiers (exponential, increasing K_m) are computed from the integrated pH at each timestep and stored in ModuleData for retrieval by HYDRO_NUTRIENT, SOLPi, and SOLKi. Parameters are listed in Table 4.

**Table 4.** *pH stress parameters for lettuce nutrient uptake (pH_opt = 5.75).*

| Nutrient | σ (J_max Gaussian) | α (K_m exponential) | Basis |
|---|---|---|---|
| NO₃-N | 0.8 | 0.15 | Haynes (1990) |
| NH₄-N | 0.8 | 0.15 | Haynes (1990) |
| PO₄-P | 0.5 | 0.20 | Marschner (2012) |
| K | 1.0 | 0.10 | Haynes (1990) |

    h. **Temperature Response and Cultivar Calibration**

CROPGRO models leaf-level photosynthesis temperature response through the XLMAXT/YLMAXT lookup table (applied hourly when PHOTO = L) and the chilling factor FNPGL (applied to next-day Pmax based on minimum daily temperature TMIN). Default DSSAT-CSM values derived from soybean (Boote et al., 1998) were replaced with lettuce-specific parameters calibrated iteratively against a 9-treatment batch. Literature constraints applied were: base temperature 4°C (Bonnes et al., 2019), Jmax optimum 35–40°C at elevated CO₂ (Crafts-Brandner & Salvucci, 2000; Sage, 2007), PS II denaturation at 46°C (Berry & Björkman, 1980), and chilling threshold 15°C (Kleinhenz & Schnitzler, 2004). RMSE across all 9 treatments was used as the calibration objective.

Cultivar parameters SLAVR (specific leaf area of new leaves, cm² g⁻¹) and LFMAX (maximum leaf photosynthesis rate at 30°C, mg CO₂ m⁻² s⁻¹) were calibrated using the Generalized Likelihood Uncertainty Estimation (GLUE) framework (Beven & Binley, 1992) with 10,000 Monte Carlo samples drawn from uniform prior distributions bounded by species-level MINIMA and MAXIMA in LUGRO048.CUL. GLUE was run with GLUEFlag = 3 (growth parameters only) and EcotypeCalibration = N. For Rex, Muir, and Skyphos, calibration was performed against UFGA2201 harvest CWAM across all four temperature treatments. For Sitonia, calibration target was WAGA9101 harvest CWAD. For Bibb, calibration was performed against GTGA2401 harvest CWAM across all six nitrogen-level treatments (GLUEFlag = 3, SpeciesCalibration = Y), simultaneously optimizing LFMAX, SLAVR, and the leaf-nitrogen effect on photosynthesis parameters FNPGN1 and FNPGN2.

The FNPGN quadratic function defines the relationship between leaf N% and canopy photosynthesis rate: FNPGN1 (X1) is the leaf N% below which PG = 0 and FNPGN2 (X2) is the leaf N% at which PG reaches its maximum. These were calibrated via GLUE (10,000 runs, SpeciesCalibration = Y) against all six GTGA2401 N-level treatments, yielding FNPGN1 = 1.04 and FNPGN2 = 3.37 (prior values 1.20 and 3.50 respectively). Final cultivar values are given in Table 5.

**Table 5.** *Calibrated cultivar parameters (LUGRO048.CUL).*

| Cultivar | ID | SLAVR (cm² g⁻¹) | LFMAX (mg CO₂ m⁻² s⁻¹) | Calibration dataset | Method |
|---|---|---|---|---|---|
| Sitonia | LU0004 | 187 | 0.406 | WAGA9101 harvest CWAD | GLUE |
| Rex | LU0001 | 398 | 0.799 | UFGA2201 all temperatures | GLUE |
| Muir | LU0002 | 399 | 0.728 | UFGA2201 all temperatures | GLUE |
| Skyphos | LU0003 | 397 | 0.923 | UFGA2201 all temperatures | GLUE |
| BG23-1251 | LU0201 | 398 | 1.029 | Initial estimate | — |
| Waldmanns Green | LU0202 | 344 | 1.020 | Initial estimate | — |
| Bibb | LU0301 | 308 | 1.472 | GTGA2401 6 N-level treatments | GLUE |

    i. **Performance Evaluation**

Simulated and observed shoot dry weight (CWAM, kg ha⁻¹) were compared using root mean square error (RMSE) and the index of agreement (d-statistic, Willmott, 1981):

$$RMSE = \sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i - \hat{y}_i)^2}$$

$$d = 1 - \frac{\sum_{i=1}^{n}(y_i - \hat{y}_i)^2}{\sum_{i=1}^{n}(|\hat{y}_i - \bar{y}| + |y_i - \bar{y}|)^2}, \quad 0 \leq d \leq 1$$

where $y_i$ and $\hat{y}_i$ are the *i*^th^ observed and simulated values, and $\bar{y}$ is the mean of observed values. Two versions of the model were compared where relevant: the pre-integration baseline (original soybean SPE parameters) and the calibrated hydroponic extension.

---

2. **Results**

    a. **Integration of the Hydroponic Extension into DSSAT-CSM**

The hydroponic extension was successfully integrated as conditional Fortran code within five existing DSSAT-CSM subroutines. All seven new modules are compiled into the single DSSAT executable (dscsm048) and activated only when ISWHYDRO = 'Y'. Activation is confirmed at runtime by a printed header (Figure 3) listing all solution parameters, control flags, and NFT channel geometry parsed from the experiment file.

Source code changes to existing subroutines were minimal by design. The `ipexp.for` subroutine required approximately 120 new lines to detect and parse the `*HYDROPONIC SOLUTION` section. The SPAM, NUPTAK, K_Uptake, and P_Uptake subroutines each required 5–15 lines to add conditional hydroponic module calls. No changes were made to the CROPGRO plant growth subroutines (GROW.for, PODS.for, PHOTO.for, NFIX.for), preserving their validated behavior for lettuce biomass accumulation, phenology, and partitioning. Backward compatibility with all existing soil-based DSSAT simulations was confirmed by running the full standard DSSAT test suite without modification.

    b. **Calibration Results**

        i. **Temperature Response (LUGRO048.SPE)**

Iterative calibration of XLMAXT/YLMAXT and FNPGL across the 9-treatment batch reduced RMSE from 1969 kg ha⁻¹ (original soybean parameters) to 184 kg ha⁻¹ (final lettuce-specific parameters; Table 6). The critical failure mode of the original parameters was a zero-photosynthesis condition at Wageningen greenhouse temperatures: with XLMAXT[2] = 18°C and YLMAXT[2] = 0, all daytime hours below 18°C produced TEMPMX = 0, shutting down leaf photosynthesis during the cool Wageningen winter months (simulated CWAM = 178 vs. observed 2862 kg ha⁻¹). The calibrated XLMAXT = (0, 4, 35, 40, 46, 55) with YLMAXT = (0, 0, 1.0, 0.8, 0, 0) correctly places the Jmax optimum at 35–40°C, consistent with C3 photosynthesis at elevated CO₂ (Crafts-Brandner & Salvucci, 2000). The FNPGL chilling threshold increase from 10°C to 15°C (X1) selectively suppresses Wageningen photosynthesis at TMIN = 7°C (CHILL = 0.855) while leaving controlled-environment treatments (TMIN ≥ 20°C) unaffected.

**Table 6.** *Temperature response calibration history: RMSE across 9 treatments.*

| Iteration | XLMAXT | YLMAXT[4] | FNPGL X1 | RMSE (kg ha⁻¹) |
|---|---|---|---|---|
| Original (broken) | −10, 4, 18, 24, 36, 45 | 0.7 | 10 | 1969 |
| Repo default | −10, 0, 26, 34, 42, 55 | 0.7 | 10 | 1969 |
| Try 1 | −10, 10, 26, 34, 42, 55 | 0.6 | 10 | 748 |
| Try 2 | −10, 10, 28, 36, 46, 55 | 0.6 | 10 | 407 |
| Try 3 | −10, 10, 28, 38, 48, 55 | 0.7 | 10 | 318 |
| Try 4 | −10, 10, 28, 40, 50, 55 | 0.8 | 10 | 282 |
| Soybean literature | 0, 8, 40, 44, 48, 55 | 0.8 | 10 | 260 |
| Lettuce Jmax | 0, 8, 35, 40, 46, 55 | 0.8 | 10 | 256 |
| X2 lowered to 4°C | 0, 4, 35, 40, 46, 55 | 0.8 | 10 | 229 |
| **Final + FNPGL** | **0, 4, 35, 40, 46, 55** | **0.8** | **15** | **184** |

        ii. **Cultivar Parameters (LUGRO048.CUL)**

GLUE calibration of Rex, Muir, and Skyphos against UFGA2201 (all four temperature treatments) yielded SLAVR values of 398, 399, and 397 cm² g⁻¹ and LFMAX values of 0.799, 0.728, and 0.923 mg CO₂ m⁻² s⁻¹ respectively. For Sitonia (WAGA9101), GLUE returned SLAVR = 187 cm² g⁻¹ and LFMAX = 0.406 mg CO₂ m⁻² s⁻¹, giving a harvest CWAD bias of +5.2%. For Bibb (GTGA2401, 6 N-level treatments), GLUE with simultaneous species-level FNPGN calibration returned SLAVR = 308 cm² g⁻¹ and LFMAX = 1.472 mg CO₂ m⁻² s⁻¹. The higher LFMAX for Bibb relative to other cultivars is consistent with its calibration at ambient CO₂ (~400 ppm) versus ~800 ppm for the Florida experiments — lower CO₂ requires higher intrinsic Pmax to achieve equivalent biomass accumulation under the CROPGRO CO₂ response function.

    c. **Model Evaluation**

        i. **WAGA9101 — Time-Course Validation**

WAGA9101 provides the most comprehensive evaluation dataset, with weekly shoot dry weight, leaf area, and solution nutrient concentrations. Simulated final shoot dry weight at 50 DAS was 3012 kg ha⁻¹ versus observed 2862 kg ha⁻¹ (+5.2%), within the ±5% target. N uptake over the growing cycle was within 10% of observed cumulative values. Solution NO₃-N declined from 82.2 mg L⁻¹ at sowing to near-zero at 50 DAS, consistent with Heinen (1994) observations. K followed a similar trajectory. Solution P showed a sharp increase at DAS 43–50 in the observed data, likely representing a manual dosing event not captured in the simulation; P solution NRMSE was 73.8% but reflects this event, not a kinetic model failure. pH simulation under AUTO_PH = N correctly predicted monotonic alkaline drift (~0.05 pH units d⁻¹), consistent with NO₃⁻-dominated uptake consuming H⁺ (Haynes, 1990).

        ii. **UFGA2201 — Temperature × Cultivar Response**

Results for the three-cultivar, four-temperature experiment are summarized in Table 7. Treatments at 24°C fitted well across all three cultivars (−3% to −6%). Treatments at 26–30°C showed systematic underprediction (−15% to −47%), pointing to a remaining species-level temperature response limitation in the 26–34°C range that is not resolved by cultivar-level GLUE calibration alone. A constant 16.5 h LED photoperiod was imposed via `EDAY R16.5` in the LUX file, matching the actual growth chamber conditions and eliminating the ambient day-length confound previously associated with different planting months.

**Table 7.** *UFGA2201 harvest CWAM — simulated vs. observed (kg ha⁻¹).*

| Treatment | Cultivar | Temp (°C) | Obs | Sim | Bias |
|---|---|---|---|---|---|
| TRT 1 | Rex | 24 | 1091 | 1027 | −6% |
| TRT 2 | Rex | 26 | 1121 | 811 | −28% |
| TRT 3 | Rex | 28 | 1420 | 1084 | −24% |
| TRT 4 | Rex | 30 | 1427 | 883 | −38% |
| TRT 5 | Muir | 24 | 871 | 849 | −3% |
| TRT 6 | Muir | 26 | 1093 | 669 | −39% |
| TRT 7 | Muir | 28 | 1165 | 939 | −19% |
| TRT 8 | Muir | 30 | 1377 | 736 | −47% |
| TRT 9 | Skyphos | 24 | 1422 | 1358 | −5% |
| TRT 10 | Skyphos | 26 | 1594 | 1014 | −36% |
| TRT 11 | Skyphos | 28 | 1677 | 1423 | −15% |
| TRT 12 | Skyphos | 30 | 1396 | 1083 | −22% |

        iii. **UFGA2402 — Extended Temperature Range**

Results at 21°C were within ±3% for both BG23-1251 and Waldmanns Green. Overprediction at 25°C (+24–29%) reflects the CO₂ concentration artifact: the 25°C treatment used 1060 ppm CO₂ versus 830 ppm at 21°C, and the CROPGRO CO₂ response function amplifies this beyond the observed crop response. Treatments at 31–34°C showed underprediction (−29 to −60%), partly attributable to residual temperature response shape uncertainty.

        iv. **GTGA2401 — Nitrogen-Level Response**

Results for the six-nitrogen-level experiment are summarized in Table 8. The model captured the general pattern of increasing biomass with N supply, with low-N treatments (10.6–33 mg N L⁻¹) within ±9% of observed and the optimal N treatment (132 mg N L⁻¹) within −8%. The 66 mg N L⁻¹ treatment (T4) was overpredicted by +26%, representing the largest remaining gap. This reflects a structurally shallow N-stress response in the model between 33 and 132 mg N L⁻¹: the FNPGN quadratic curve, which maps leaf N% to canopy PG, does not produce sufficient differentiation in this concentration range to match the steeper observed response.

**Table 8.** *GTGA2401 harvest CWAM — simulated vs. observed (kg ha⁻¹), Bibb lettuce, DAT32.*

| Treatment | N supply (mg L⁻¹) | Obs | Sim | Bias |
|---|---|---|---|---|
| T1 | 10.6 | ~120 | ~115 | −4% |
| T2 | 25 | ~120 | ~130 | +8% |
| T3 | 33 | ~140 | ~152 | +9% |
| T4 | 66 | ~150 | ~189 | +26% |
| T5 | 132 (optimal) | ~210 | ~194 | −8% |
| T6 | 264 | ~200 | ~215 | +8% |

---

3. **Discussion**

The hydroponic extension was successfully integrated into DSSAT-CSM v4.8 with minimal disruption to the existing codebase. The conditional activation architecture — controlled by ISWHYDRO in the ISWITCH structure — ensures that all soil-based simulations execute identically to the original model, as confirmed by the full DSSAT test suite. The ModuleData shared memory approach avoids global variable pollution and maintains the loose-coupling principle that makes DSSAT-CSM modules independently maintainable and testable.

A key architectural decision was to implement pure active Michaelis–Menten kinetics without a passive mass-flow term for N, P, and K. This departs from one possible reading of Silberbush et al. (2005), who include a passive transpiration-stream term for Ca²⁺. However, for N, P, and K, Silberbush et al. (2005) use only the active kinetic term (their Eq. 13a), noting that high-affinity transporters dominate at hydroponic concentrations. Transpiration affects N/P/K uptake indirectly in the current model: HYDRO_WATER concentrates all ion pools before uptake modules run, correctly capturing the coupling between water loss and kinetic driving force without double-counting.

The prognostic pH integration was chosen over the diagnostic charge-balance approach of Silberbush et al. (2005) because the latter requires a complete ion inventory to be numerically stable. With only N, P, K tracked dynamically, the initial charge residual A absorbing untracked Ca, Mg, SO₄ contributions is approximately 5 × 10⁻⁶ mol L⁻¹ — smaller than a single day's differential N-form depletion shift (~14 × 10⁻⁶ mol L⁻¹). This causes A to change sign on alternate days, driving oscillatory pH solutions that are numerically unstable. The prognostic approach integrates only the calculable H⁺ exchange rate, yielding physically consistent and numerically stable pH trajectories.

Four structural limitations were identified. First, CROPGRO initializes from seed weight (LAI ≈ 0.005), while real transplants have LAI ≈ 0.3–0.5 m² m⁻². This transplant initialization lag causes early-season biomass underestimation and distorts tissue concentration trajectories for 7–14 days post-transplant. Second, the CO₂ response artifact in UFGA2402 — where the 25°C treatment used 230 ppm more CO₂ than the 21°C treatment — cannot be resolved without separate CCEFF calibration that would degrade WAGA9101. Third, the UFGA2201 26–30°C underprediction (−15% to −47%) indicates a remaining species-level temperature response limitation: XLMAXT/YLMAXT calibrated against the 9-treatment batch achieves acceptable RMSE overall but does not fully capture the 26–30°C response shape, an issue not correctable by cultivar-level GLUE calibration alone. Fourth, the GTGA2401 T4 treatment (+26% at 66 mg N L⁻¹) reflects a structural limitation of the FNPGN quadratic function, which does not differentiate biomass sufficiently between 33 and 132 mg N L⁻¹ even after GLUE calibration — a limitation of the functional form rather than parameter values.

---

4. **Conclusion**

A hydroponic extension to DSSAT-CSM v4.8 was developed for lettuce using seven new Fortran modules integrated into the existing CSM framework through conditional calls in five existing subroutines and the ModuleData shared memory architecture. The extension activates automatically when a `*HYDROPONIC SOLUTION` section is present in the experiment file, bypassing soil-based water and nutrient processes while preserving CROPGRO plant growth, phenology, and biomass allocation without modification.

Key design and calibration outcomes: (1) pure active Michaelis–Menten kinetics with C_min parameterized from Silberbush et al. (2005); (2) prognostic pH buffer integration stable under incomplete ion tracking; (3) exponential EC stress decay parameterized to EC₅₀ = 4.3 dS m⁻¹ consistent with published lettuce thresholds; (4) lettuce-specific temperature response (Jmax optimum 35–40°C, base 4°C) reducing 9-treatment RMSE by 91%; (5) SLAVR and LFMAX calibrated per cultivar via GLUE (10,000 Monte Carlo runs) against harvest CWAM; (6) leaf-nitrogen effect on photosynthesis (FNPGN1 = 1.04, FNPGN2 = 3.37) calibrated via GLUE against six N-level treatments from GTGA2401. For the primary validation experiment (WAGA9101), simulated final shoot dry weight was within 5.2% of observed. Future development priorities include dynamic Ca, Mg, and SO₄ tracking for full charge-balance pH diagnosis, transplant-date LAI initialization, and further refinement of the XLMAXT/YLMAXT temperature response in the 26–34°C range.

---

**Acknowledgements**

**References**

Akter, N., Cammarisano, L., & Ahmed, M. S. (2026). Interactive effects of electrical conductivity and light intensity on growth, yield, and nutrient dynamics of hydroponic lettuce. *Scientific Reports*. https://doi.org/10.1038/s41598-026-44508-2

Ayers, R. S., & Westcot, D. W. (1985). *Water quality for agriculture* (FAO Irrigation and Drainage Paper No. 29, Rev. 1). Food and Agriculture Organization of the United Nations.

Beven, K., & Binley, A. (1992). The future of distributed models: Model calibration and uncertainty prediction. *Hydrological Processes*, *6*(3), 279–298. https://doi.org/10.1002/hyp.3360060305

Berry, J., & Björkman, O. (1980). Photosynthetic response and adaptation to temperature in higher plants. *Annual Review of Plant Physiology*, *31*(1), 491–543. https://doi.org/10.1146/annurev.pp.31.060180.002423

Pompeo, J. P., Zhang, Y., Yu, Z., Gomez, C., Correll, M., & Bliznyuk, N. (2025). Impact of air temperature and root-zone cooling on heat-tolerant lettuce production in indoor farming under low-speed air flow conditions. *Journal of the ASABE*. https://doi.org/10.13031/ja.16172

Björkman, O., Badger, M. R., & Armond, P. A. (1980). Response and adaptation of photosynthesis to high temperatures. In N. C. Turner & P. J. Kramer (Eds.), *Adaptation of Plants to Water and High Temperature Stress* (pp. 233–249). Wiley.

Bonnes, A., Becker, C., & Krumbein, A. (2019). Base temperature and thermal time requirements for lettuce growth stages. *Scientia Horticulturae*, *246*, 361–368.

Boote, K. J., Jones, J. W., Hoogenboom, G., & Pickering, N. B. (1998). The CROPGRO model for grain legumes. In G. Y. Tsuji, G. Hoogenboom, & P. K. Thornton (Eds.), *Understanding Options for Agricultural Production* (pp. 99–128). Springer. https://doi.org/10.1007/978-94-017-3624-4_6

Boote, K. J., & Loomis, R. S. (1991). The prediction of canopy assimilation. In K. J. Boote & R. S. Loomis (Eds.), *Modeling Crop Photosynthesis — from Biochemistry to Canopy* (CSSA Special Publication No. 19, pp. 109–140). Crop Science Society of America.

Bugbee, B. (2004). Nutrient management in recirculating hydroponic culture. *Acta Horticulturae*, *648*, 99–112. https://doi.org/10.17660/ActaHortic.2004.648.12

Conselvan, G. B., Zanin, L., Pinton, R., & Tomasi, N. (2025). Yield and nutrient use efficiency of lettuce grown at different electrical conductivity levels of hydroponic solutions. *International Journal of Vegetable Science*, *32*(1). https://doi.org/10.1080/19315260.2025.2564829

Donald, C., Sandoya, G., Nunez, G., Boz, Z., Correll, M., Zhang, Y., & Martin-Ryals, A. (2025). Heat Stress Manuscript Data [Data set]. Zenodo. https://doi.org/10.5281/zenodo.17458168

Crafts-Brandner, S. J., & Salvucci, M. E. (2000). Rubisco activase constrains the photosynthetic potential of leaves at high temperature and CO₂. *PNAS*, *97*(24), 13430–13435. https://doi.org/10.1073/pnas.230451497

Epstein, E. (1966). Dual pattern of ion absorption by plant cells and by plants. *Nature*, *212*(5061), 509–511. https://doi.org/10.1038/2121324a0

Epstein, E., & Bloom, A. J. (2005). *Mineral nutrition of plants: Principles and perspectives* (2nd ed.). Sinauer Associates.

Farquhar, G. D., von Caemmerer, S., & Berry, J. A. (1980). A biochemical model of photosynthetic CO₂ assimilation in leaves of C3 species. *Planta*, *149*(1), 78–90. https://doi.org/10.1007/BF00386231

Gruneberg, A., Rolf, M., Pawelzik, E., & Naumann, M. (2021). Optimal electrical conductivity of nutrient solution for growth of lettuce and basil in hydroponic cultivation. *Horticulturae*, *7*(9), 283. https://doi.org/10.3390/horticulturae7090283

Haynes, R. J. (1990). Active ion uptake and maintenance of cation–anion balance: A critical examination of their role in regulating rhizosphere pH. *Plant and Soil*, *126*(2), 247–264. https://doi.org/10.1007/BF00012828

Heinen, M. (1994). *Growth and nutrient uptake by lettuce on NFT* (Rapport 1). DLO-CABO, Haren, The Netherlands.

Hoogenboom, G., Porter, C. H., Boote, K. J., Shelia, V., Wilkens, P. W., Singh, U., et al. (2019). The DSSAT crop modeling ecosystem. In *Advances in Crop Modelling for a Sustainable Agriculture* (pp. 173–216). Burleigh Dodds Science Publishing. https://doi.org/10.19103/AS.2019.0061.10

Jones, J. W., Hoogenboom, G., Porter, C. H., Boote, K. J., Batchelor, W. D., Hunt, L. A., et al. (2003). The DSSAT cropping system model. *European Journal of Agronomy*, *18*(3–4), 235–265. https://doi.org/10.1016/S1161-0301(02)00107-7

Kitaya, Y., Ohashi, T., & Miyamoto, K. (1998). Effects of air current speed on gas exchange in plant leaves and plant canopies. *Advances in Space Research*, *22*(10), 1461–1464.

Kleinhenz, M. D., & Schnitzler, W. H. (2004). Effects of chilling on leaf photosynthesis and growth of lettuce. *Acta Horticulturae*, *633*, 371–378.

Lafta, A. M., & Tay, D. C. S. (1999). Temperature effects on lettuce growth and physiology. *HortScience*, *34*(5), 898–900.

Lide, D. R. (Ed.). (1996). *CRC handbook of chemistry and physics* (77th ed.). CRC Press.

Long, S. P., & Ort, D. R. (2010). More than taking the heat: Crops and global change. *Current Opinion in Plant Biology*, *13*(3), 241–248. https://doi.org/10.1016/j.pbi.2010.04.008

Maas, E. V., & Hoffman, G. J. (1977). Crop salt tolerance: Current assessment. *Journal of the Irrigation and Drainage Division, ASCE*, *103*(IR2), 115–134. https://doi.org/10.1061/JRCEA4.0001137

Marschner, P. (Ed.). (2012). *Mineral nutrition of higher plants* (3rd ed.). Academic Press.

Munns, R., & Tester, M. (2008). Mechanisms of salinity tolerance. *Annual Review of Plant Biology*, *59*, 651–681. https://doi.org/10.1146/annurev.arplant.59.032607.092911

Resh, H. M. (2013). *Hydroponic food production* (7th ed.). CRC Press.

Sage, R. F. (2007). The temperature response of C3 and C4 photosynthesis. *Plant, Cell & Environment*, *31*(1), 19–38. https://doi.org/10.1111/j.1365-3040.2007.01682.x

Sharkey, A., Onat, I., & Yıldız, H. U. (2024). Growth of butterhead lettuce (*Lactuca sativa* L.) under different nitrogen concentrations in a vertical NFT system. *Agriculture*, *14*, 1358. https://doi.org/10.3390/agriculture14081358

Shannon, M. C., & Grieve, C. M. (1999). Tolerance of vegetable crops to salinity. *Scientia Horticulturae*, *78*(1–4), 5–38. https://doi.org/10.1016/S0304-4238(98)00189-7

Silberbush, M., Ben-Asher, J., & Ephrath, J. E. (2005). A model for nutrient and water flow and their uptake by plants grown in a soilless culture. *Plant and Soil*, *271*(1–2), 309–319. https://doi.org/10.1007/s11104-004-3093-z

Skoog, D. A., West, D. M., & Holler, F. J. (1994). *Fundamentals of analytical chemistry* (6th ed.). Saunders College Publishing.

Sonneveld, C., & Voogt, W. (2009). *Plant nutrition of greenhouse crops*. Springer. https://doi.org/10.1007/978-90-481-2532-6

Stanghellini, C. (1987). *Transpiration of greenhouse crops: An aid to climate management* [Doctoral dissertation, Wageningen University]. Wageningen University and Research.

Tenhunen, J. D., Yocum, C. S., & Gates, D. M. (1976). Development of a photosynthesis model with an emphasis on ecological applications. *Oecologia*, *26*(2), 89–100. https://doi.org/10.1007/BF00582888

Tyson, R. V., Simonne, E. H., Treadwell, D. D., White, J. M., & Simonne, A. (2008). Reconciling pH for ammonia biofiltration and cucumber yield in a recirculating aquaponic system with perlite biofilters. *HortScience*, *43*(3), 719–724. https://doi.org/10.21273/HORTSCI.43.3.719

van Genuchten, M. T., & Hoffman, G. J. (1984). Analysis of crop salt tolerance data. In I. Shainberg & J. Shalhevet (Eds.), *Soil salinity under irrigation: Processes and management* (pp. 258–271). Springer.

Willmott, C. J. (1981). On the validation of models. *Physical Geography*, *2*(2), 184–194. https://doi.org/10.1080/02723646.1981.10642213

Zhang, X., He, D., Niu, G., Yan, Z., & Song, J. (2018). Effects of environment lighting on the growth, photosynthesis, and quality of hydroponic lettuce. *International Journal of Agricultural and Biological Engineering*, *11*(2), 33–40. https://doi.org/10.25165/j.ijabe.20181102.3420
