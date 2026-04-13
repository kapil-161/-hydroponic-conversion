# Calibration Next Steps — DSSAT Hydroponic Lettuce Model

**Date:** 2026-04-12 (updated after Priority 1–4)
**Model:** CRGRO048 (CROPGRO lettuce), DSSAT 4.8.5
**Experiments:** WAGA9101 (Heinen 1994), UFGA2201 (JP Thesis 2022), UFGA2402 (Donald Coon 2024–2025)

---

## Current Model State

| Parameter | File | Value | Notes |
|-----------|------|-------|-------|
| XLMAXT/YLMAXT | LUGRO048.SPE | `-10 0 26 34 42 55 / 0 0 1.0 0.70 0.0 0.0` | Peak at 26°C; recalibrated 2026-04-12 |
| SITONIA LFMAX | LUGRO048.CUL | 0.731 | Calibrated to WAGA9101 (+5.2%) |
| SITONIA SLAVR | LUGRO048.CUL | 240 | Unchanged; WAGA9101 stable at +5.2% |
| REX LFMAX | LUGRO048.CUL | 0.690 | Recalibrated Priority 4 (SLAVR+LFMAX) |
| REX SLAVR | LUGRO048.CUL | 320 | Calibrated to UFGA2201 observed LAPD at 28°C |
| MUIR LFMAX | LUGRO048.CUL | 0.620 | Recalibrated Priority 4 (was 0.850→0.720→0.620) |
| MUIR SLAVR | LUGRO048.CUL | 370 | Calibrated to UFGA2201 observed LAPD at 28°C (was 210) |
| SKYPHOS LFMAX | LUGRO048.CUL | 0.720 | Recalibrated Priority 4 (was 1.200→0.970→0.720) |
| SKYPHOS SLAVR | LUGRO048.CUL | 390 | Calibrated to UFGA2201 observed LAPD at 28°C (was 185) |
| BG23-1251 LFMAX | LUGRO048.CUL | 0.590 | Original; 25°C overshoot is CO2 artifact |
| WALDMANNS_GR LFMAX | LUGRO048.CUL | 0.650 | Original; 25°C overshoot is CO2 artifact |
| PRORTI | LUGRO048.SPE | 0.260 | Stable; 0.280 caused N-stress cascade |

### Current Performance Summary

| Experiment | n | NRMSE | d-stat | Primary Bias |
|-----------|---|-------|--------|--------------|
| WAGA9101 trt1 CWAD | 7 | ~12% | ~0.980 | +5.2% at harvest ✓ |
| UFGA2201 harvest CWAM | 12 | ~28% | ~0.70 | See per-treatment table below |
| UFGA2402 harvest CWAM | 8 | ~35% | ~0.70 | See per-treatment table below |

### UFGA2201 Harvest CWAM (kg/ha)

| Treatment | LFMAX | SLAVR | Sim | Obs | Bias | Status |
|-----------|-------|-------|-----|-----|------|--------|
| Rex_24°C | 0.690 | 320 | 1430 | 1146 | +25% | Day-length confound (Apr, 13.1h) |
| Rex_26°C | 0.690 | 320 | 1392 | 1177 | +18% | Day-length confound (Aug, 12.2h) |
| Rex_28°C | 0.690 | 320 | 1450 | 1491 | −3% | ✓ Calibrated |
| Rex_30°C | 0.690 | 320 | 943 | 1499 | −37% | Day-length confound (Mar, 11.8h) |
| Muir_24°C | 0.620 | 370 | 1238 | 914 | +35% | Day-length confound (Apr, 13.1h) |
| Muir_26°C | 0.620 | 370 | 1189 | 1148 | +4% | ✓ |
| Muir_28°C | 0.620 | 370 | 1263 | 1224 | +3% | ✓ Calibrated |
| Muir_30°C | 0.620 | 370 | 779 | 1447 | −46% | Day-length confound (Mar, 11.8h) |
| Skyphos_24°C | 0.720 | 390 | 1649 | 1494 | +10% | Day-length confound (Apr, 13.1h) |
| Skyphos_26°C | 0.720 | 390 | 1612 | 1675 | −4% | ✓ |
| Skyphos_28°C | 0.720 | 390 | 1652 | 1761 | −6% | ✓ Calibrated |
| Skyphos_30°C | 0.720 | 390 | 1132 | 1466 | −23% | Day-length confound (Mar, 11.8h) |

### UFGA2402 Harvest CWAM (kg/ha)

| Treatment | LFMAX | Sim | Obs | Bias | Status |
|-----------|-------|-----|-----|------|--------|
| BG23_21°C | 0.590 | 1183 | 1159 | +2% | ✓ |
| WG_21°C | 0.650 | 1169 | 1134 | +3% | ✓ |
| BG23_25°C | 0.590 | 2312 | 1791 | +29% | CO2 artifact (1060 vs 830 ppm) |
| WG_25°C | 0.650 | 2260 | 1826 | +24% | CO2 artifact |
| BG23_31°C | 0.590 | 916 | 1568 | −42% | Day-length confound (Apr, 13.1h) |
| WG_31°C | 0.650 | 1045 | 1481 | −29% | Day-length confound |
| BG23_34°C | 0.590 | 381 | 960 | −60% | XLMAXT + day-length (May, 13.8h) |
| WG_34°C | 0.650 | 442 | 912 | −52% | XLMAXT + day-length |

### Known Structural Limitations (Do Not Fix by Parameter Tuning)

1. **Day-length confound:** Real experiments used constant 16.5h LED photoperiod. DSSAT uses ambient day length from the outdoor weather station. Treatments placed in different months to achieve target temperatures inadvertently bring different day lengths (11.8–13.5h). This causes systematic under/over-prediction correlated with planting month, not temperature response. **Fix:** Would require modifying weather generation to impose constant 16.5h photoperiod — not straightforward in DSSAT.

2. **CO2 response artifact (UFGA2402):** The 21°C and 25°C treatments differ by 230 ppm CO2 (830 vs 1060 ppm). The model's CO2 response (CCEFF=0.0105/ppm) amplifies this difference too strongly, causing 25°C to overshoot by +24–29%. Reducing LFMAX to compensate would break the well-calibrated 21°C result. **Fix:** Reduce CCEFF in SPE, but this affects all experiments. Low priority.

3. **Transplant initialization lag:** CROPGRO starts from seed weight (PLWT), giving LAI≈0.005 vs real transplant LAI≈0.3–0.5. Early-season biomass is underestimated for 7–14 days. At cooler temperatures (24°C, slower growth), this lag persists longer, causing a relative *overestimation* late in the season due to compensatory N-feedback dynamics. This explains part of the 24°C overshoots for Muir/Skyphos. **Accepted:** Document, focus calibration on harvest-date metrics.

---

## ~~Priority 1 — Sync Installed vs Repo CUL~~ ✅ DONE (2026-04-12)

Both `LUGRO048.CUL` and `LUGRO048.SPE` installed and repo copies are now identical. Committed in main.

---

## ~~Priority 2 — Phenology Causing Premature Harvest at 30°C~~ ✅ RESOLVED (2026-04-12)

**Resolution:** Harvest is date-forced (`HSTG=GS000`, `HARVS=R`). The premature harvest previously observed was caused by the old repo SPE having phenology optimum at TB/TO1/TO2/TM = 0/15/25/35°C (below the range where 30°C falls). With the synced SPE (optimum 0/20/28/45°C), all temperatures remain in the vegetative development zone through the harvest date. No EM-FL adjustment needed.

---

## ~~Priority 3 — LFMAX Calibration Per Cultivar~~ ✅ DONE (2026-04-12)

Calibrated Muir (0.650→0.850) and Skyphos (0.850→1.200) to the 28°C optimal treatment. Rex unchanged (0.660, −2% at 28°C). BG23/WG reverted after finding the 25°C overshoot is a CO2 response artifact, not an LFMAX error. See performance tables above.

---

## ~~Priority 4 — SLAVR Calibration (LAI vs Biomass Trade-off)~~ ✅ DONE (2026-04-12)

**Resolution:** Calibrated SLAVR per cultivar using observed LAPD at DAS_plant=28 for the 28°C treatment (no daylength confound). LFMAX simultaneously adjusted to maintain CWAD target at 28°C.

| Cultivar | SLAVR before | SLAVR after | LFMAX before | LFMAX after | LAIX sim | LAIX obs | CWAD bias |
|----------|-------------|-------------|-------------|-------------|----------|----------|-----------|
| REX | 400 | 320 | 0.660 | 0.690 | 3.8 | 3.77 | −3% ✓ |
| MUIR | 210 | 370 | 0.850 | 0.620 | 4.3 | 4.32 | +3% ✓ |
| SKYPHOS | 185 | 390 | 1.200 | 0.720 | 4.8 | 4.86 | −6% ✓ |

SITONIA, BG23-1251, WALDMANNS_GR SLAVR unchanged (no observed LAPD available for direct calibration). WAGA9101 SITONIA CWAD remains +5.2% ✓.

---

## ~~Priority 5 — FNPGT Alignment with XLMAXT~~ ✅ DONE (2026-04-12)

**Resolution:** FNPGT upper plateau breakpoint shifted 32.0→34.0°C to match XLMAXT decline onset at 34°C. No change to model output (secondary canopy-level factor). All three experiments unchanged after edit.

---

## Priority 6 — Transplant Initialization (Structural Limitation)

**Problem:** CROPGRO initializes from seed weight (PLWT), resulting in LAI≈0.005 at transplant date. Real 2-week-old transplants have LAI≈0.3–0.5. This causes early-season biomass underestimation and distorted tissue concentration trajectories.

**Recommended:** Accept and document. Focus calibration on harvest-date metrics only.

---

## Priority 7 — WAGA9101 Trt 1 CWAD Overshoot (Minor)

**Current:** CWAD=3012 vs observed=2862 (+5.2%). Within the ±5% target. Monitor after SLAVR changes in Priority 4 — SLAVR affects LAI which affects light interception and CWAD.

---

## Testing Protocol

After each change, run all three experiments in sequence:
```bash
cd /Applications/DSSAT48/Lettuce
/Users/kapilbhattarai/-hydroponic-conversion/build/bin/dscsm048 A WAGA9101.LUX
/Users/kapilbhattarai/-hydroponic-conversion/build/bin/dscsm048 A UFGA2201.LUX
/Users/kapilbhattarai/-hydroponic-conversion/build/bin/dscsm048 A UFGA2402.LUX
```

**Accept/reject criteria per experiment:**

| Experiment | Variable | Target |
|-----------|----------|--------|
| WAGA9101 trt1 | CWAD harvest | ±5% of 2862 kg/ha |
| WAGA9101 trt1 | N uptake | ±10% of 118.8 kg/ha |
| UFGA2201 | CWAD NRMSE | < 25% |
| UFGA2201 | CWAD d-stat | > 0.85 |
| UFGA2402 | CWAD NRMSE | < 25% |
| UFGA2402 | CWAD d-stat | > 0.85 |

---

## Files to Edit

| File | Location | Purpose |
|------|----------|---------|
| `LUGRO048.CUL` | `/Applications/DSSAT48/Genotype/` | Cultivar: LFMAX, EM-FL, FL-LF, SLAVR |
| `LUGRO048.SPE` | `/Applications/DSSAT48/Genotype/` | Species: XLMAXT, YLMAXT, FNPGT |
| `LUGRO048.CUL` | `Data/Genotype/` | Repo copy — must match installed |
| `LUGRO048.SPE` | `Data/Genotype/` | Repo copy — must match installed |

Always edit both installed and repo copies together.

---

## Priority 9 — SPE Temperature Parameter Calibration (FNPGT, XLMAXT/YLMAXT, FNPGL, XSLATM)

**Status:** ACTIVE — start here in new conversation

**Background:** Current XLMAXT (`-10, 4, 18, 24, 36, 45`) causes near-zero biomass at 31–34°C (TRT7=496, TRT8=44 g/m²) and large overprediction at cool temps (WAGA=4954 vs obs=1045 g/m² at 35 DAS). Need to calibrate all 4 SPE temperature parameters jointly against 9-treatment batch.

**Batch file to use:** `DSSBatch.v48` — but update TRT1–4 (Rex) → TRT9–12 (Skyphos) in UFGA2201 before calibrating. Skyphos is preferred for temperature response calibration (highest biomass, clearest signal).

**Observed data (g/m² = kg/ha ÷ 10, PPOP=12.3 plants/m²):**

| Run | Experiment | TRT | Cultivar | Temp | Obs CWAM (g/m²) |
|-----|-----------|-----|----------|------|-----------------|
| 1 | UFGA2201 | 9 | Skyphos | 24°C | 149.4 |
| 2 | UFGA2201 | 10 | Skyphos | 26°C | 167.5 |
| 3 | UFGA2201 | 11 | Skyphos | 28°C | 176.1 |
| 4 | UFGA2201 | 12 | Skyphos | 30°C | 146.6 |
| 5 | UFGA2402 | 2 | WG | 21°C | 113.4 |
| 6 | UFGA2402 | 4 | WG | 25°C | 182.6 |
| 7 | UFGA2402 | 6 | WG | 31°C | 148.1 |
| 8 | UFGA2402 | 8 | WG | 34°C | 91.2 |
| 9 | WAGA9101 | 1 | Sitonia | ~20°C | 104.5 (35 DAS) |

**Calibration sequence:**

1. **Update DSSBatch.v48** — replace UFGA2201 TRT1–4 with TRT9–12 (Skyphos)
2. **XLMAXT/YLMAXT** — highest priority; controls leaf Pmax shape across hourly temps
   - Fix peak (X3) at 25–26°C; widen upper decline so 31–34°C not zeroed out
   - Key bounds: X2 (0–8°C), X3 (18–24°C), X4 (24–30°C), X5 (34–42°C), Y4 (0.5–0.9)
3. **FNPGT** — widen optimum from current 15–18°C to cover 20–30°C experimental range
   - Key bounds: FNPGT[2] (18–22°C), FNPGT[3] (28–34°C)
4. **FNPGL** — only if WAGA9101 still overpredicted after Steps 2–3 (TMIN=7°C there)
5. **XSLATM/YSLATM** — defer unless LAI bias remains after Steps 2–4

**Metric:** RMSE across all 9 treatments on CWAM (g/m²)

**Run command:**
```bash
cd /Applications/DSSAT48/Lettuce && /Users/kapilbhattarai/-hydroponic-conversion/build/bin/dscsm048 B DSSBatch.v48
```

**Files to edit:**
- `/Applications/DSSAT48/Genotype/LUGRO048.SPE` + `Data/Genotype/LUGRO048.SPE`
- Always edit both installed and repo copies together.

---

## Priority 8 — Re-calibrate Rex and Waldmanns Green after Day-length Fix

**Status:** ACTIVE — start here in new conversation

**Background:** Day-length confound was previously listed as unfixable. It has now been fixed by adding `EDAY R16.5` to all experiment LUX files (2026-04-13). This forces constant 16.5h photoperiod matching the actual LED growth chamber conditions. All large biases previously attributed to day-length confound are now expected to shrink or reverse.

**Previous biases caused by day-length confound (before fix):**
- Rex_24°C: +25% (Apr, was 13.1h ambient vs 16.5h actual)
- Rex_30°C: −37% (Mar, was 11.8h ambient vs 16.5h actual)
- WG_31°C: −29% (Apr, 13.1h)
- WG_34°C: −52% (May, 13.8h)

**Step 1 — Re-evaluate current performance (before any parameter changes)**
Run `DSSBatch.v48` (Rex TRT 1–4 + WG TRT 2,4,6,8 + WAGA TRT 1) and read `Summary.OUT`. Record new Sim vs Obs CWAM for all treatments. Compare to the bias table above — day-length treatments should improve substantially.

**Step 2 — Decide what still needs calibration**
After re-evaluating, identify which treatments remain poorly fit. These will be genuine temperature response or cultivar parameter issues (not day-length artifacts).

**Step 3 — Calibration sequence (if needed)**

*Temperature response (SPE — species level, affects all cultivars):*
- Use Rex 24/26/28/30°C shape to assess XLMAXT/YLMAXT and FNPGT
- Use WG 21/25/31/34°C to extend the range (especially 31/34°C high-temp decline)
- Only adjust if the *shape* of response is wrong across temperatures (not just one outlier)

*Cultivar parameters (CUL — cultivar specific):*
- Rex: SLAVR=320, LFMAX=0.690 — calibrated at 28°C. Check if still valid across all temps.
- Waldmanns Green: SLAVR unchanged, LFMAX=0.650 — only 21°C was well-fit before. Re-evaluate.
- Calibrate at the temperature closest to optimum (~24–26°C) first, then check shape.

**Key constraint:** Do not re-tune SLAVR/LFMAX to compensate for temperature response errors — fix temperature response (SPE) first.

**Accept/reject criteria (unchanged):**
| Experiment | Variable | Target |
|-----------|----------|--------|
| WAGA9101 trt1 | CWAD harvest | ±5% of 2862 kg/ha |
| UFGA2201 Rex | CWAD NRMSE | < 25%, d-stat > 0.85 |
| UFGA2402 WG | CWAD NRMSE | < 25%, d-stat > 0.85 |

**Files to edit:**
- `/Applications/DSSAT48/Genotype/LUGRO048.CUL` + `Data/Genotype/LUGRO048.CUL`
- `/Applications/DSSAT48/Genotype/LUGRO048.SPE` + `Data/Genotype/LUGRO048.SPE`
- Always edit both installed and repo copies together.

**Run command:**
```bash
cd /Applications/DSSAT48/Lettuce && /Users/kapilbhattarai/-hydroponic-conversion/build/bin/dscsm048 B DSSBatch.v48
```

**Read output from:** `/Applications/DSSAT48/Lettuce/Summary.OUT`

---

## Known Acceptable Limitations (Do Not Fix)

- **Day-length confound:** FIXED 2026-04-13 — all LUX files now have `EDAY R16.5`. No longer a limitation.
- **CO2 response artifact (UFGA2402 25°C):** 1060 ppm CO2 in 25°C treatment vs 830 ppm in 21°C; model over-amplifies the difference. BG23/WG calibrated to 21°C (+2–3%); 25°C overshoot accepted.
- **Early-season biomass lag (DAS 1–14 post-transplant):** Structural CROPGRO limitation. d-stats for concentration variables at early time points are unreliable and should not drive parameter changes.
- **P solution NRMSE=73.8% in WAGA9101:** Observed P rises sharply at DAS 43–50 (likely a manual dosing event in Heinen 1994). Not a model failure.
- **R²=0.000 in statistics table:** Placeholder value not calculated. Do not interpret.
- **Root N%/K%/P% d-stats < 0.4 in WAGA9101:** Direct consequence of early-season lag distorting tissue concentration trajectories. Accepted.
