#!/usr/bin/env python3
"""Calibrate LFMAX and SLAVR in LUGRO048.CUL — run AFTER calibrate_spe_temperature_response.py.

Key design choices vs previous version:
  1. SIZLF removed from calibration — harvest-only data cannot constrain 3 params
     simultaneously; SIZLF is fixed at current CUL value.
  2. WG calibrates LFMAX only (SLAVR fixed): with only 3 harvest points,
     LFMAX and SLAVR are collinear at a single time point. Fix SLAVR to current
     value; only LFMAX is identifiable from harvest-CWAM alone.
  3. Rex calibrates LFMAX × SLAVR jointly using PlantGro time-course — the
     growth trajectory constrains both parameters independently.
  4. Grids are smaller and temperature-response-aware (LFMAX grids start low
     since day-length fix causes ~60-80% overprediction at current values).
  5. ~50-70 total model runs (was 500-700).

Run order: SPE first → this script → (optional) calibrate_eco_parameters.py
"""
from __future__ import annotations

import json
import math
import re
import shutil
import subprocess
from pathlib import Path

ROOT    = Path("/Applications/DSSAT48")
GENO    = ROOT / "Genotype"
LETTUCE = ROOT / "Lettuce"
WORK    = Path("/Users/kapilbhattarai/-hydroponic-conversion")

CUL      = GENO / "LUGRO048.CUL"
MODEL    = WORK / "build/bin/dscsm048"
LUT      = LETTUCE / "UFGA2201.LUT"
PLANTGRO = LETTUCE / "PlantGro.OUT"
SUMMARY  = LETTUCE / "Summary.OUT"

REX_BATCH = LETTUCE / "DSSBatch_Rex.v48"    # UFGA2201 TRT 1-4
WG_BATCH  = LETTUCE / "DSSBatch_WG.v48"     # UFGA2402 TRT 2,4,6,8

REX_TRTS    = (1, 2, 3, 4)   # 24/26/28/30°C — all used in objective
WG_CAL_RUNS = (1, 3, 4)      # batch run order: 21°C=1, 25°C=2(skip CO2), 31°C=3, 34°C=4

# Observed harvest CWAM (kg/ha) for WG by WG-batch run number
WG_OBS_CWAM = {1: 1134.0, 3: 1481.0, 4: 912.0}

# Grids — start low since current sims are 60-80% over observed after day-length fix
LFMAX_GRID_REX  = [0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70]
SLAVR_GRID_REX  = [150, 185, 220, 260, 300, 340, 380, 420]
LFMAX_GRID_WG   = [0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75]
LFMAX_FINE_STEP = 0.01
SLAVR_FINE_STEP = 10


# ---------------------------------------------------------------------------
# CUL file helpers
# ---------------------------------------------------------------------------

def _patch_line(line: str, lfmax: float, slavr: int, sizlf: float) -> str:
    return line[:79] + f"{lfmax:5.3f}{slavr:5.0f}.{sizlf:6.1f}" + line[96:]


def read_cul_params(var_ids: tuple[str, ...]) -> dict[str, tuple[float, int, float]]:
    result: dict[str, tuple[float, int, float]] = {}
    for line in CUL.read_text().splitlines():
        for v in var_ids:
            if re.match(rf"^{v}\s", line):
                result[v] = (float(line[79:84]), int(float(line[84:89])), float(line[90:96]))
    return result


def update_cul(params: dict[str, tuple[float, int, float]]) -> None:
    lines = CUL.read_text().splitlines()
    out = []
    for line in lines:
        matched = False
        for var_id, (lfmax, slavr, sizlf) in params.items():
            if re.match(rf"^{var_id}\s", line):
                out.append(_patch_line(line, lfmax, slavr, sizlf))
                matched = True
                break
        if not matched:
            out.append(line)
    CUL.write_text("\n".join(out) + "\n")


# ---------------------------------------------------------------------------
# Rex — PlantGro time-course NRMSE (log-weighted)
# ---------------------------------------------------------------------------

def parse_rex_obs() -> dict[int, list[tuple[int, float]]]:
    data: dict[int, list[tuple[int, float]]] = {t: [] for t in REX_TRTS}
    for line in LUT.read_text().splitlines():
        if not line.strip() or line.startswith(("*", "@")):
            continue
        parts = line.split()
        trt = int(parts[0])
        if trt in data:
            data[trt].append((int(parts[1]), float(parts[7])))
    return data


def parse_rex_sim() -> dict[int, dict[int, float]]:
    text = PLANTGRO.read_text().splitlines()
    runs: dict[int, dict[int, float]] = {}
    current = None
    for line in text:
        m = re.match(r"\*RUN\s+\d+\s+:.*\sUFGA2201\s+(\d+)", line)
        if m:
            current = int(m.group(1))
            runs[current] = {}
            continue
        if current in REX_TRTS and re.match(r"\s*\d{4}\s+\d{3}\s+", line):
            parts = line.split()
            date = int(parts[0]) * 1000 + int(parts[1])
            runs[current][date] = float(parts[12])
    return runs


def rex_nrmse() -> dict[int, float]:
    obs = parse_rex_obs()
    sim = parse_rex_sim()
    result: dict[int, float] = {}
    for trt in REX_TRTS:
        if trt not in sim or not sim[trt]:
            result[trt] = 999.0
            continue
        obs_pts   = obs[trt]
        sim_dates = sorted(sim[trt])
        obs_vals, sim_vals = [], []
        for d, o in obs_pts:
            obs_vals.append(o)
            if d in sim[trt]:
                sim_vals.append(sim[trt][d])
            else:
                eligible = [sd for sd in sim_dates if sd <= d]
                sim_vals.append(
                    sim[trt][eligible[-1]] if eligible
                    else sim[trt][min(sim_dates, key=lambda sd: abs(sd - d))]
                )
        weights = [1.0 / math.log1p(max(o, 1e-6)) for o in obs_vals]
        w_sum = sum(weights)
        wmse  = sum(w * (s - o) ** 2 for w, s, o in zip(weights, sim_vals, obs_vals)) / w_sum
        result[trt] = 100.0 * math.sqrt(wmse) / max(sum(obs_vals) / len(obs_vals), 1e-6)
    return result


# ---------------------------------------------------------------------------
# WG — harvest CWAM from Summary.OUT
# ---------------------------------------------------------------------------

def parse_summary_cwam() -> dict[int, float]:
    text = SUMMARY.read_text().splitlines()
    cwam_col = None
    result: dict[int, float] = {}
    for line in text:
        if line.startswith("@") and "CWAM" in line:
            cwam_col = line.index("CWAM")
            continue
        if cwam_col is None or not line.strip() or line.startswith(("!", "*", "@")):
            continue
        m = re.match(r"^\s+(\d+)\s+\d+", line)
        if not m:
            continue
        run_no = int(m.group(1))
        try:
            result[run_no] = float(line[cwam_col:cwam_col + 8].strip())
        except (ValueError, IndexError):
            continue
    return result


def wg_nrmse() -> dict[int, float]:
    sim = parse_summary_cwam()
    return {
        r: 100.0 * abs(sim.get(r, -1.0) - WG_OBS_CWAM[r]) / WG_OBS_CWAM[r]
        if sim.get(r, -1.0) > 0 else 999.0
        for r in WG_CAL_RUNS
    }


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def score(nrmse: dict, runs: tuple) -> tuple[float, float]:
    vals = [nrmse[r] for r in runs if r in nrmse]
    return max(vals), sum(vals) / len(vals)


# ---------------------------------------------------------------------------
# Calibration helpers
# ---------------------------------------------------------------------------

def run_batch(batch: Path) -> None:
    subprocess.run([str(MODEL), "B", batch.name],
                   check=True, cwd=LETTUCE, capture_output=True)


# ---------------------------------------------------------------------------
# Rex calibration — LFMAX × SLAVR joint grid, then fine-tune
# ---------------------------------------------------------------------------

def calibrate_rex(params: dict[str, tuple[float, int, float]]) -> dict:
    best: dict | None = None
    cur_lf, cur_sl, cur_sz = params["LU0001"]
    print("\n=== REX: joint LFMAX×SLAVR coarse grid ===")
    for lf in LFMAX_GRID_REX:
        for sl in SLAVR_GRID_REX:
            p = dict(params)
            p["LU0001"] = (lf, sl, cur_sz)
            update_cul(p)
            run_batch(REX_BATCH)
            nrmse = rex_nrmse()
            w, a = score(nrmse, REX_TRTS)
            print(f"  LFMAX={lf:.2f}  SLAVR={sl:3d}  worst={w:.1f}%  avg={a:.1f}%")
            if best is None or (w, a) < (best["worst"], best["avg"]):
                best = {"lfmax": lf, "slavr": sl, "sizlf": cur_sz,
                        "worst": w, "avg": a, "nrmse": nrmse}
                cur_lf, cur_sl = lf, sl

    print(f"\n=== REX: fine-tune neighbourhood (LFMAX≈{cur_lf:.2f} SLAVR≈{cur_sl}) ===")
    for dlf in [-2, -1, 1, 2]:
        lf = round(cur_lf + dlf * LFMAX_FINE_STEP, 3)
        if lf <= 0:
            continue
        p = dict(params); p["LU0001"] = (lf, cur_sl, cur_sz)
        update_cul(p); run_batch(REX_BATCH)
        nrmse = rex_nrmse(); w, a = score(nrmse, REX_TRTS)
        print(f"  LFMAX={lf:.3f}  SLAVR={cur_sl}  worst={w:.1f}%  avg={a:.1f}%")
        if (w, a) < (best["worst"], best["avg"]):
            best = {"lfmax": lf, "slavr": cur_sl, "sizlf": cur_sz,
                    "worst": w, "avg": a, "nrmse": nrmse}
            cur_lf = lf

    for dsl in [-2, -1, 1, 2]:
        sl = cur_sl + dsl * SLAVR_FINE_STEP
        if sl < 100:
            continue
        p = dict(params); p["LU0001"] = (cur_lf, sl, cur_sz)
        update_cul(p); run_batch(REX_BATCH)
        nrmse = rex_nrmse(); w, a = score(nrmse, REX_TRTS)
        print(f"  LFMAX={cur_lf:.3f}  SLAVR={sl}  worst={w:.1f}%  avg={a:.1f}%")
        if (w, a) < (best["worst"], best["avg"]):
            best = {"lfmax": cur_lf, "slavr": sl, "sizlf": cur_sz,
                    "worst": w, "avg": a, "nrmse": nrmse}

    print(f"\n>>> REX best: LFMAX={best['lfmax']:.3f}  SLAVR={best['slavr']}"
          f"  worst={best['worst']:.1f}%  avg={best['avg']:.1f}%")
    return best


# ---------------------------------------------------------------------------
# WG calibration — LFMAX only (SLAVR fixed), harvest CWAM
# ---------------------------------------------------------------------------

def calibrate_wg(params: dict[str, tuple[float, int, float]]) -> dict:
    _, cur_sl, cur_sz = params["LU0202"]
    best: dict | None = None
    print(f"\n=== WG: LFMAX sweep (SLAVR fixed={cur_sl}) ===")

    for lf in LFMAX_GRID_WG:
        p = dict(params); p["LU0202"] = (lf, cur_sl, cur_sz)
        update_cul(p); run_batch(WG_BATCH)
        nrmse = wg_nrmse(); w, a = score(nrmse, WG_CAL_RUNS)
        print(f"  LFMAX={lf:.2f}  worst={w:.1f}%  avg={a:.1f}%  "
              + "  ".join(f"r{r}={nrmse[r]:.0f}%" for r in WG_CAL_RUNS))
        if best is None or (w, a) < (best["worst"], best["avg"]):
            best = {"lfmax": lf, "slavr": cur_sl, "sizlf": cur_sz,
                    "worst": w, "avg": a, "nrmse": nrmse}

    # Fine-tune
    cur_lf = best["lfmax"]
    print(f"\n=== WG: fine-tune (LFMAX≈{cur_lf:.2f}) ===")
    for dlf in [-2, -1, 1, 2]:
        lf = round(cur_lf + dlf * LFMAX_FINE_STEP, 3)
        if lf <= 0:
            continue
        p = dict(params); p["LU0202"] = (lf, cur_sl, cur_sz)
        update_cul(p); run_batch(WG_BATCH)
        nrmse = wg_nrmse(); w, a = score(nrmse, WG_CAL_RUNS)
        print(f"  LFMAX={lf:.3f}  worst={w:.1f}%  avg={a:.1f}%")
        if (w, a) < (best["worst"], best["avg"]):
            best = {"lfmax": lf, "slavr": cur_sl, "sizlf": cur_sz,
                    "worst": w, "avg": a, "nrmse": nrmse}

    print(f"\n>>> WG best: LFMAX={best['lfmax']:.3f}  SLAVR={best['slavr']}"
          f"  worst={best['worst']:.1f}%  avg={best['avg']:.1f}%")
    return best


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    backup = CUL.with_suffix(".CUL.calib_bak")
    shutil.copy2(CUL, backup)
    print(f"Backup: {backup}")

    params = read_cul_params(("LU0001", "LU0202"))
    print(f"Starting params: {params}\n")

    try:
        # --- Rex ---
        rex_result = calibrate_rex(params)
        params["LU0001"] = (rex_result["lfmax"], rex_result["slavr"], rex_result["sizlf"])
        update_cul(params)

        # --- WG ---
        wg_result = calibrate_wg(params)
        params["LU0202"] = (wg_result["lfmax"], wg_result["slavr"], wg_result["sizlf"])
        update_cul(params)

        print("\n*** CUL updated ***")
        print(f"  LU0001 Rex: LFMAX={params['LU0001'][0]:.3f}  SLAVR={params['LU0001'][1]}")
        print(f"  LU0202 WG:  LFMAX={params['LU0202'][0]:.3f}  SLAVR={params['LU0202'][1]} (fixed)")

        # Final verification
        print("\n=== Final verification ===")
        run_batch(REX_BATCH)
        rex_final = rex_nrmse()
        run_batch(WG_BATCH)
        wg_final = wg_nrmse()

        print("Rex NRMSE (time-course):  "
              + "  ".join(f"T{t}={rex_final[t]:.1f}%" for t in REX_TRTS))
        print("WG  NRMSE (harvest):      "
              + "  ".join(f"r{r}={wg_final[r]:.1f}%" for r in WG_CAL_RUNS))
        print(f"\nNow run: calibrate_eco_parameters.py (optional, for N/nutrient diagnostics)")

        print("\n" + json.dumps({
            "LU0001_Rex": {"lfmax": params["LU0001"][0], "slavr": params["LU0001"][1],
                           "nrmse": rex_final},
            "LU0202_WG":  {"lfmax": params["LU0202"][0], "slavr": params["LU0202"][1],
                           "nrmse": wg_final},
        }, indent=2))

    except Exception:
        shutil.copy2(backup, CUL)
        print("ERROR — CUL restored from backup")
        raise


if __name__ == "__main__":
    main()
