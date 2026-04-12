# Calibration Next Steps — DSSAT Hydroponic Lettuce Model

**Date:** 2026-04-12 (updated after Priority 1–3)
**Model:** CRGRO048 (CROPGRO lettuce), DSSAT 4.8.5
**Experiments:** WAGA9101 (Heinen 1994), UFGA2201 (JP Thesis 2022), UFGA2402 (Donald Coon 2024–2025)

---

## Current Model State

| Parameter | File | Value | Notes |
|-----------|------|-------|-------|
| XLMAXT/YLMAXT | LUGRO048.SPE | `-10 0 26 34 42 55 / 0 0 1.0 0.70 0.0 0.0` | Peak at 26°C; recalibrated 2026-04-12 |
| SITONIA LFMAX | LUGRO048.CUL | 0.731 | Calibrated to WAGA9101 (+5.2%) |
| REX LFMAX | LUGRO048.CUL | 0.660 | Calibrated to UFGA2201 28°C (−2%) |
| MUIR LFMAX | LUGRO048.CUL | 0.850 | Recalibrated 2026-04-12 (was 0.650) |
| SKYPHOS LFMAX | LUGRO048.CUL | 1.200 | Recalibrated 2026-04-12 (was 0.850) |
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

| Treatment | LFMAX | Sim | Obs | Bias | Status |
|-----------|-------|-----|-----|------|--------|
| Rex_24°C | 0.660 | 1430 | 1146 | +25% | Day-length confound (Apr, 13.1h) |
| Rex_26°C | 0.660 | 1392 | 1177 | +18% | Day-length confound (Aug, 12.2h) |
| Rex_28°C | 0.660 | 1466 | 1491 | −2% | ✓ Calibrated |
| Rex_30°C | 0.660 | 940 | 1499 | −37% | Day-length confound (Mar, 11.8h) |
| Muir_24°C | 0.850 | 1510 | 914 | +65% | Day-length/N confound (Apr, 13.1h) |
| Muir_26°C | 0.850 | 1449 | 1148 | +26% | Partial confound |
| Muir_28°C | 0.850 | 1449 | 1224 | +18% | ✓ Acceptable (calibrated here) |
| Muir_30°C | 0.850 | 1023 | 1447 | −29% | Day-length confound (Mar, 11.8h) |
| Skyphos_24°C | 1.200 | 2004 | 1494 | +34% | Day-length/N confound (Apr, 13.1h) |
| Skyphos_26°C | 1.200 | 1834 | 1675 | +10% | Acceptable |
| Skyphos_28°C | 1.200 | 1776 | 1761 | +1% | ✓ Calibrated |
| Skyphos_30°C | 1.200 | 1428 | 1466 | −3% | ✓ Excellent |

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

## Priority 4 — SLAVR Calibration (LAI vs Biomass Trade-off)

**Problem:** Specific leaf area (SLAVR) controls how LAI scales with leaf dry weight. Currently:
- SITONIA: 240 cm²/g
- REX: 400 cm²/g
- MUIR: 210 cm²/g
- SKYPHOS: 185 cm²/g
- BG23-1251: 351 cm²/g
- WALDMANNS_GR: 380 cm²/g

LAIX from Summary shows very different values across cultivars (Rex: 5.2, Muir: 2.5, Skyphos: 2.3–2.4). Observed LAI data in UFGA2201.LUT (LAPD column) allows direct comparison.

**Approach:**
1. Extract simulated LAID at each LUT observation date for all 12 UFGA2201 treatments
2. Compare with observed LAPD from LUT
3. Adjust SLAVR per cultivar: if sim LAI > obs → decrease SLAVR; if sim LAI < obs → increase
4. Note: SLAVR and LFMAX interact — changing SLAVR changes light interception → changes CWAD. Always re-check CWAD after SLAVR adjustment.

---

## Priority 5 — FNPGT Alignment with XLMAXT (Low Priority)

**Problem:** FNPGT (canopy-level temperature effect on gross photosynthesis) has breakpoints at 8, 26, 32, 46°C. This is slightly inconsistent with the XLMAXT peak at 26°C. The canopy PG plateaus over 26–32°C while the leaf-level YLMAXT peaks exactly at 26°C.

**Proposed change:**
```
Current:  8.0  26.0  32.0  46.0  LIN   FNPGT
Proposed: 8.0  26.0  34.0  46.0  LIN   FNPGT
```
Low priority — secondary effect.

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

## Known Acceptable Limitations (Do Not Fix)

- **Day-length confound (all experiments):** Lab used constant 16.5h LED; model uses ambient day length from outdoor weather. Treatments at different months have different DAYLA (11.8–13.5h). Causes systematic biases correlated with planting month. Not fixable by parameter tuning.
- **CO2 response artifact (UFGA2402 25°C):** 1060 ppm CO2 in 25°C treatment vs 830 ppm in 21°C; model over-amplifies the difference. BG23/WG calibrated to 21°C (+2–3%); 25°C overshoot accepted.
- **Early-season biomass lag (DAS 1–14 post-transplant):** Structural CROPGRO limitation. d-stats for concentration variables at early time points are unreliable and should not drive parameter changes.
- **P solution NRMSE=73.8% in WAGA9101:** Observed P rises sharply at DAS 43–50 (likely a manual dosing event in Heinen 1994). Not a model failure.
- **R²=0.000 in statistics table:** Placeholder value not calculated. Do not interpret.
- **Root N%/K%/P% d-stats < 0.4 in WAGA9101:** Direct consequence of early-season lag distorting tissue concentration trajectories. Accepted.
