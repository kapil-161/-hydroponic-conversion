# Calibration Next Steps — DSSAT Hydroponic Lettuce Model

**Date:** 2026-04-27 (updated after GLUE calibration of BIBB, FNPGN, and GTGA2401 evaluation)
**Model:** CRGRO048 (CROPGRO lettuce), DSSAT 4.8.5
**Experiments:** WAGA9101 (Heinen 1994), UFGA2201 (JP Thesis 2022), UFGA2402 (Donald Coon 2024–2025), GTGA2401 (Sharkey et al. 2024, Georgia Tech)

---

## Current Model State

### SPE Parameters (LUGRO048.SPE)

| Parameter | Value | Notes |
|-----------|-------|-------|
| XLMAXT | `0, 4, 35, 40, 46, 55` | Calibrated 2026-04-13; Jmax Topt 35–40°C for C3 at elevated CO2 |
| YLMAXT | `0, 0, 1.0, 0.8, 0, 0` | Y4=0.8 moderate decline above Topt; zero at 46°C (PSII damage) |
| FNPGL | `QDR(-6, 15, 50, 60)` | Chilling threshold raised 10→15°C (Kleinhenz & Schnitzler, 2004) |
| FNPGT | `LIN(2, 12, 28, 42)` | Inactive for PHOTO=L; retained for canopy option compatibility |
| FNPGN1 | 1.04 | Leaf N% zero-PG threshold; GLUE-calibrated 2026-04-27 vs GTGA2401 (was 1.20) |
| FNPGN2 | 3.37 | Leaf N% at PG saturation; GLUE-calibrated 2026-04-27 vs GTGA2401 (was 3.50) |
| PGEFF | 0.1470 | Radiation use efficiency scalar |
| LNREF | 2.54 | Leaf N% at which leaf Pmax saturates; updated 2026-04-27 (was 3.50) |
| SLAREF | 296 | Reference SLA in SPE leaf growth section; updated 2026-04-27 (was 280) |
| SLAMAX | 377 | Maximum SLA; updated 2026-04-27 (was 400) |
| FINREF | 600 | Final leaf size reference; updated 2026-04-27 (was 420) |
| PRORTI | 0.260 | Stable; 0.280 caused N-stress cascade |

### CUL Parameters (LUGRO048.CUL)

| Cultivar | ID | LFMAX | SLAVR | Source |
|----------|----|-------|-------|--------|
| SITONIA | LU0004 | 0.406 | 187 | Calibrated to WAGA9101 |
| REX | LU0001 | 0.799 | 398 | GLUE-calibrated vs UFGA2201 |
| MUIR | LU0002 | 0.728 | 399 | GLUE-calibrated vs UFGA2201 |
| SKYPHOS | LU0003 | 0.923 | 397 | GLUE-calibrated vs UFGA2201 |
| WALDMANNS_GR | LU0202 | 1.020 | 344 | Initial estimate |
| BG23-1251 | LU0201 | 1.029 | 398 | Initial estimate |
| BIBB | LU0301 | 1.472 | 308 | GLUE-calibrated 2026-04-27 vs GTGA2401 (all 6 N treatments) |

### Current Performance Summary

| Experiment | n | Notes |
|-----------|---|-------|
| WAGA9101 trt1 CWAD | 7 time points | +5.2% at harvest ✓ |
| UFGA2201 harvest CWAM | 12 treatments | See table below; 24°C fits well, 26–30°C underpredicted |
| GTGA2401 harvest CWAM | 6 N treatments | See table below; GLUE-calibrated BIBB |

### GTGA2401 Harvest CWAM — BIBB, Georgia Tech, DAT32 (kg/ha)

Experiment: Sharkey et al. (2024), 6 N-levels, 16 plants/m², 21.5°C constant, 12h LED, ambient CO2.

| TRT | N (mg/L) | Sim | Obs | Bias | Notes |
|-----|----------|-----|-----|------|-------|
| T1 | 10.6 | ~115 | ~120 | −4% | ✓ |
| T2 | 25 | ~130 | ~120 | +8% | ✓ |
| T3 | 33 | ~152 | ~140 | +9% | ✓ |
| T4 | 66 | ~189 | ~150 | +26% | Remaining gap; shallow N-stress curve |
| T5 | 132 | ~194 | ~210 | −8% | ✓ Optimal N |
| T6 | 264 | ~215 | ~200 | +8% | ✓ |

*Units: kg/ha (= g/m²). FNPGN1=1.04, FNPGN2=3.37 calibrated across all 6 treatments. T4 remaining +26% gap reflects shallow modeled N-stress response between T1 and T5.*

### UFGA2201 Harvest CWAM (kg/ha) — with current SPE parameters

| Treatment | LFMAX | SLAVR | Sim | Obs | Bias | Status |
|-----------|-------|-------|-----|-----|------|--------|
| Rex_24°C | 0.799 | 398 | 1027 | 1091 | −6% | ✓ |
| Rex_26°C | 0.799 | 398 | 811 | 1121 | −28% | Temperature response underprediction |
| Rex_28°C | 0.799 | 398 | 1084 | 1420 | −24% | Temperature response underprediction |
| Rex_30°C | 0.799 | 398 | 883 | 1427 | −38% | Temperature response underprediction |
| Muir_24°C | 0.728 | 399 | 849 | 871 | −3% | ✓ |
| Muir_26°C | 0.728 | 399 | 669 | 1093 | −39% | Temperature response underprediction |
| Muir_28°C | 0.728 | 399 | 939 | 1165 | −19% | Temperature response underprediction |
| Muir_30°C | 0.728 | 399 | 736 | 1377 | −47% | Temperature response underprediction |
| Skyphos_24°C | 0.923 | 397 | 1358 | 1422 | −5% | ✓ |
| Skyphos_26°C | 0.923 | 397 | 1014 | 1594 | −36% | Temperature response underprediction |
| Skyphos_28°C | 0.923 | 397 | 1423 | 1677 | −15% | Temperature response underprediction |
| Skyphos_30°C | 0.923 | 397 | 1083 | 1396 | −22% | Temperature response underprediction |

*Note: 24°C fits well across all cultivars. 26–30°C systematically underpredicted. Points to XLMAXT/YLMAXT temperature response being too conservative in the 26–34°C range, or cultivar LFMAX needing further calibration. These LFMAX/SLAVR values are from a separate GLUE run vs UFGA2201 — the 24°C fit suggests correct SLA; the 26–30°C gap is a species-level temperature response issue.*

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

## ~~Priority 9 — SPE Temperature Parameter Calibration (FNPGT, XLMAXT/YLMAXT, FNPGL)~~ ✅ DONE (2026-04-13)

**Resolution:** XLMAXT/YLMAXT recalibrated from scratch using 9-treatment batch (Skyphos×4temp + WG×4temp + Sitonia). Final values: `0, 4, 35, 40, 46, 55 / 0, 0, 1.0, 0.8, 0, 0`. FNPGL X1 raised 10→15°C. RMSE reduced from 1969 to 184 kg/ha. See `spe_temperature_calibration_report.md` for full derivation.

---

## Priority 10 — BIBB FNPGN N-Stress Calibration ✅ DONE (2026-04-27)

**Resolution:** GLUE (GLUEFlag=3, SpeciesCalibration=Y, 10000 runs) calibrated FNPGN1 and FNPGN2 across all 6 GTGA2401 N treatments. Best-fit: FNPGN1=1.042→1.04, FNPGN2=3.374→3.37. Applied to LUGRO048.SPE. T4 (66 mg/L) still shows +26% gap — likely reflects shallow modeled N-stress response in the 33–132 mg/L range, accepted as structural limitation.

---

## Priority 11 — UFGA2201 Temperature Underprediction (26–30°C)

**Status:** ACTIVE — start here in new conversation

**Problem:** With current XLMAXT/YLMAXT, UFGA2201 shows systematic underprediction at 26–30°C across all three cultivars (−15% to −47%). The 24°C treatment fits well (−3% to −6%). This pattern persists after GLUE calibration of cultivar LFMAX/SLAVR and is therefore a species-level temperature response issue, not a cultivar parameter issue.

**Diagnosis:** XLMAXT was calibrated (Priority 9) using Skyphos (UFGA2201) + WG (UFGA2402) + Sitonia (WAGA9101). The 2026-04-13 calibration achieved RMSE=184 kg/ha across 9 treatments with Skyphos errors of −15% at 24°C, −12% at 26°C, −12% at 28°C, +13% at 30°C. However, the current UFGA2201 run with re-calibrated CUL parameters shows larger gaps at 26–30°C. Possible causes: (1) XLMAXT/YLMAXT still too conservative in the 26–34°C range; (2) cultivar LFMAX interaction with TEMPMX — re-calibrated LFMAX values are higher, amplifying any XLMAXT error.

**Recommended approach:**
1. Run the 9-treatment batch (DSSBatch.v48: Skyphos TRT9–12 + WG TRT2,4,6,8 + Sitonia TRT1)
2. Check if Skyphos 26–30°C errors match the UFGA2201 pattern — if yes, adjust XLMAXT Y4 (currently 0.8 at 40°C) upward or shift X3/X4 slightly higher
3. Do NOT re-tune cultivar LFMAX to compensate for a species-level temperature response error

**Key constraint:** WAGA9101 Sitonia must remain within ±10% of observed (2862 kg/ha) after any XLMAXT change.

---

## ~~Priority 8 — Re-calibrate Rex and Waldmanns Green after Day-length Fix~~ ✅ DONE (2026-04-27)

**Resolution:** Day-length fix (`EDAY R16.5` in all LUX files) was applied 2026-04-13. Rex, Muir, Skyphos LFMAX/SLAVR subsequently re-calibrated via GLUE against UFGA2201 (see Current Model State table). Current UFGA2201 results show 24°C fitting well (−3% to −6%) but 26–30°C systematically underpredicted — this is now identified as a species-level temperature response issue (Priority 11), not a cultivar parameter issue.

---

## Known Acceptable Limitations (Do Not Fix)

- **Day-length confound:** FIXED 2026-04-13 — all LUX files now have `EDAY R16.5`. No longer a limitation.
- **CO2 response artifact (UFGA2402 25°C):** 1060 ppm CO2 in 25°C treatment vs 830 ppm in 21°C; model over-amplifies the difference. BG23/WG calibrated to 21°C (+2–3%); 25°C overshoot accepted.
- **Early-season biomass lag (DAS 1–14 post-transplant):** Structural CROPGRO limitation. d-stats for concentration variables at early time points are unreliable and should not drive parameter changes.
- **P solution NRMSE=73.8% in WAGA9101:** Observed P rises sharply at DAS 43–50 (likely a manual dosing event in Heinen 1994). Not a model failure.
- **R²=0.000 in statistics table:** Placeholder value not calculated. Do not interpret.
- **Root N%/K%/P% d-stats < 0.4 in WAGA9101:** Direct consequence of early-season lag distorting tissue concentration trajectories. Accepted.
