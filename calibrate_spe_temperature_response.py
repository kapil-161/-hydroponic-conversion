#!/usr/bin/env python3
"""Calibrate LUGRO048.SPE temperature response — run FIRST before CUL calibration.

Key design choices vs previous version:
  1. Shape-based objective: normalises each cultivar's CWAM to its own mean before
     computing NRMSE. This isolates temperature-response SHAPE from absolute level
     (which LFMAX controls). Prevents SPE from compensating for LFMAX errors.
  2. Joint 2-D grid on the two most-interacting parameters (FNPGT plateau end ×
     XLMAXT high-temp decline start) before 1-D sweeps.
  3. SITONIA (run 9) used as validation only — excluded from calibration objective.
     It's a different ecotype (LU0401) at different conditions (Wageningen 1991).
  4. WG 25°C (run 6) excluded — CO2 artifact (1060 vs 830 ppm).
  5. ~60–120 total model runs (was ~300).

Run order: SPE → calibrate_cul_lfmax_slavr.py → (optional) calibrate_eco_parameters.py

Treatments (DSSBatch.v48 run order):
  Run 1: Rex  24°C  obs=1146 kg/ha   ← calibration
  Run 2: Rex  26°C  obs=1177 kg/ha   ← calibration
  Run 3: Rex  28°C  obs=1491 kg/ha   ← calibration
  Run 4: Rex  30°C  obs=1499 kg/ha   ← calibration
  Run 5: WG   21°C  obs=1134 kg/ha   ← calibration
  Run 6: WG   25°C  obs=1826 kg/ha   ← EXCLUDED (CO2 artifact)
  Run 7: WG   31°C  obs=1481 kg/ha   ← calibration
  Run 8: WG   34°C  obs=912  kg/ha   ← calibration
  Run 9: SITONIA    obs=2862 kg/ha   ← validation only
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

SPE     = GENO / "LUGRO048.SPE"
BATCH   = LETTUCE / "DSSBatch.v48"
MODEL   = WORK / "build/bin/dscsm048"
SUMMARY = LETTUCE / "Summary.OUT"

# Observed harvest CWAM (kg/ha) by batch run number
OBS_CWAM: dict[int, float] = {
    1: 1146.0,  2: 1177.0,  3: 1491.0,  4: 1499.0,  # Rex 24/26/28/30°C
    5: 1134.0,                                         # WG 21°C
    7: 1481.0,  8:  912.0,                             # WG 31/34°C
    9: 2862.0,                                         # SITONIA (validation only)
}
REX_RUNS = (1, 2, 3, 4)
WG_RUNS  = (5, 7, 8)
VAL_RUNS = (9,)


# ---------------------------------------------------------------------------
# SPE read/write
# ---------------------------------------------------------------------------

def read_lines(path: Path) -> list[str]:
    return path.read_text().splitlines()

def write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n")

def update_spe(lines: list[str],
               fnpgt: tuple[float, float, float, float],
               xlmaxt: tuple[float, float, float, float, float, float],
               ylmaxt: tuple[float, float, float, float, float, float],
               pheno: tuple) -> list[str]:
    out = []
    for line in lines:
        if "FNPGT(4),TYPPGT-TEMP EFFECT-CANOPY PG" in line:
            out.append(
                f"{fnpgt[0]:6.2f}{fnpgt[1]:6.1f}{fnpgt[2]:6.1f}{fnpgt[3]:6.1f}"
                f"   LIN             FNPGT(4),TYPPGT-TEMP EFFECT-CANOPY PG"
            )
        elif "XLMAXT (6 VALUES)" in line:
            out.append("".join(f"{v:6.1f}" for v in xlmaxt) + "       XLMAXT (6 VALUES)")
        elif "YLMAXT (6 VALUES)" in line:
            out.append("".join(f"{v:6.1f}" for v in ylmaxt) + "       YLMAXT (6 VALUES)")
        elif "1 VEGETATIVE DEVELOPMENT" in line:
            v = pheno[0]
            out.append(f"{v[0]:6.1f}{v[1]:6.1f}{v[2]:6.1f}{v[3]:6.1f}"
                       f"               1 VEGETATIVE DEVELOPMENT")
        elif "2 EARLY REPRODUCTIVE DEVELOPMENT" in line:
            v = pheno[1]
            out.append(f"{v[0]:6.1f}{v[1]:6.1f}{v[2]:6.1f}{v[3]:6.1f}"
                       f"               2 EARLY REPRODUCTIVE DEVELOPMENT")
        elif "3 LATE REPRODUCTIVE DEVELOPMENT" in line:
            v = pheno[2]
            out.append(f"{v[0]:6.1f}{v[1]:6.1f}{v[2]:6.1f}{v[3]:6.1f}"
                       f"               3 LATE REPRODUCTIVE DEVELOPMENT")
        else:
            out.append(line)
    return out


# ---------------------------------------------------------------------------
# Summary.OUT parsing
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


# ---------------------------------------------------------------------------
# Shape-based objective
# Normalise each cultivar's values to their own mean before computing NRMSE.
# This isolates SHAPE (temperature response) from LEVEL (LFMAX).
# ---------------------------------------------------------------------------

def shape_nrmse(obs_vals: list[float], sim_vals: list[float]) -> float:
    """NRMSE of normalised temperature response curves (mean = 1.0)."""
    mean_obs = sum(obs_vals) / len(obs_vals)
    mean_sim = sum(sim_vals) / len(sim_vals)
    if mean_obs < 1.0 or mean_sim < 1.0:
        return 999.0
    obs_norm = [o / mean_obs for o in obs_vals]
    sim_norm = [s / mean_sim for s in sim_vals]
    mse = sum((s - o) ** 2 for s, o in zip(sim_norm, obs_norm)) / len(obs_vals)
    return 100.0 * math.sqrt(mse)


def compute_metrics(sim: dict[int, float]) -> dict:
    rex_obs = [OBS_CWAM[r] for r in REX_RUNS]
    rex_sim = [sim.get(r, -1.0) for r in REX_RUNS]
    wg_obs  = [OBS_CWAM[r] for r in WG_RUNS]
    wg_sim  = [sim.get(r, -1.0) for r in WG_RUNS]

    if any(v < 0 for v in rex_sim + wg_sim):
        return {"rex_shape": 999.0, "wg_shape": 999.0,
                "worst": 999.0, "avg": 999.0,
                "sitonia_bias": 999.0, "sim": sim}

    rex_shape = shape_nrmse(rex_obs, rex_sim)
    wg_shape  = shape_nrmse(wg_obs,  wg_sim)

    # Absolute bias at SITONIA (validation — not in objective)
    sit_sim = sim.get(9, -1.0)
    sit_bias = 100.0 * abs(sit_sim - OBS_CWAM[9]) / OBS_CWAM[9] if sit_sim > 0 else 999.0

    worst = max(rex_shape, wg_shape)
    avg   = (rex_shape + wg_shape) / 2.0
    return {"rex_shape": rex_shape, "wg_shape": wg_shape,
            "worst": worst, "avg": avg,
            "sitonia_bias": sit_bias, "sim": sim}


def run_and_score(name: str, lines: list[str],
                  fnpgt: tuple, xlmaxt: tuple, ylmaxt: tuple, pheno: tuple) -> dict:
    write_lines(SPE, update_spe(lines, fnpgt, xlmaxt, ylmaxt, pheno))
    subprocess.run([str(MODEL), "B", BATCH.name], check=True,
                   cwd=LETTUCE, capture_output=True)
    sim = parse_summary_cwam()
    m = compute_metrics(sim)
    print(f"  [{name:30s}] worst={m['worst']:5.1f}%  "
          f"Rex={m['rex_shape']:5.1f}%  WG={m['wg_shape']:5.1f}%  "
          f"SITONIA_bias={m['sitonia_bias']:5.1f}%  "
          f"fnpgt[2]={fnpgt[2]:.1f}  xlmaxt[3]={xlmaxt[3]:.1f}",
          flush=True)
    return {"name": name, "worst": m["worst"], "avg": m["avg"],
            "metrics": m,
            "params": {"fnpgt": fnpgt, "xlmaxt": xlmaxt,
                       "ylmaxt": ylmaxt, "pheno": pheno}}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    backup = SPE.with_name(SPE.name + ".calib_bak")
    shutil.copy2(SPE, backup)
    print(f"Backup: {backup}\n")

    # Current SPE state — seeded with Phase 1 result (xlmaxt[3]=40.0, fnpgt[2]=18.0)
    # Phase 1 already confirmed: xlmaxt[3]=40 reduces worst 41.4%→28.1%
    fnpgt  = (0.0, 15.0, 18.0, 38.0)
    xlmaxt = (-10.0, 18.0, 24.0, 40.0, 48.0, 55.0)
    ylmaxt = (0.0, 0.0, 1.0, 0.70, 0.0, 0.0)
    pheno  = ((0.0, 20.0, 28.0, 45.0),
              (0.0, 18.0, 28.0, 45.0),
              (-10.0, 15.0, 30.0, 45.0))

    lines = read_lines(SPE)

    # Baseline
    print("=== Baseline ===")
    best = run_and_score("baseline", lines, fnpgt, xlmaxt, ylmaxt, pheno)

    try:
        # ------------------------------------------------------------------
        # Phase 1: Joint 2-D grid — FNPGT[2] × XLMAXT[3]
        # Already run: confirmed fnpgt[2] has no effect on shape NRMSE;
        # xlmaxt[3]=40 is best (worst 41.4%→28.1%). State pre-seeded above.
        # ------------------------------------------------------------------
        print("\n=== Phase 1: Skipped — pre-seeded with known best (xlmaxt[3]=40.0) ===")
        print(f"  fnpgt[2]={fnpgt[2]:.1f}  xlmaxt[3]={xlmaxt[3]:.1f}  worst={best['worst']:.1f}%")

        # ------------------------------------------------------------------
        # Phase 2: 1-D sweeps for remaining parameters
        # ------------------------------------------------------------------
        print("\n=== Phase 2: 1-D sweeps ===")

        param_grids = [
            ("fnpgt[1]",  [12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0]),
            ("fnpgt[3]",  [32.0, 34.0, 36.0, 38.0, 40.0, 42.0, 44.0]),
            ("xlmaxt[2]", [20.0, 22.0, 24.0, 26.0, 28.0]),
            ("ylmaxt[3]", [0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90]),
            ("xlmaxt[4]", [42.0, 44.0, 46.0, 48.0, 50.0]),
        ]

        for step in range(3):   # repeat sweeps until converged
            improved = False
            for param, grid in param_grids:
                for val in grid:
                    if param == "fnpgt[1]":
                        cand_fnpgt  = (fnpgt[0], val, fnpgt[2], fnpgt[3])
                        cand_xlmaxt = xlmaxt
                        cand_ylmaxt = ylmaxt
                    elif param == "fnpgt[3]":
                        cand_fnpgt  = (fnpgt[0], fnpgt[1], fnpgt[2], val)
                        cand_xlmaxt = xlmaxt
                        cand_ylmaxt = ylmaxt
                    elif param == "xlmaxt[2]":
                        cand_fnpgt  = fnpgt
                        cand_xlmaxt = (xlmaxt[0], xlmaxt[1], val, xlmaxt[3], xlmaxt[4], xlmaxt[5])
                        cand_ylmaxt = ylmaxt
                    elif param == "ylmaxt[3]":
                        cand_fnpgt  = fnpgt
                        cand_xlmaxt = xlmaxt
                        cand_ylmaxt = (ylmaxt[0], ylmaxt[1], ylmaxt[2], val, ylmaxt[4], ylmaxt[5])
                    elif param == "xlmaxt[4]":
                        cand_fnpgt  = fnpgt
                        cand_xlmaxt = (xlmaxt[0], xlmaxt[1], xlmaxt[2], xlmaxt[3], val, xlmaxt[5])
                        cand_ylmaxt = ylmaxt
                    else:
                        continue

                    r = run_and_score(f"s{step+1}_{param}={val}",
                                      lines, cand_fnpgt, cand_xlmaxt, cand_ylmaxt, pheno)
                    if (r["worst"], r["avg"]) < (best["worst"], best["avg"]):
                        best = r
                        fnpgt  = cand_fnpgt
                        xlmaxt = cand_xlmaxt
                        ylmaxt = cand_ylmaxt
                        improved = True

            if not improved:
                print(f"  Step {step+1}: no improvement — converged")
                break

    except Exception:
        shutil.copy2(backup, SPE)
        print("ERROR — SPE restored from backup")
        raise

    # Apply best permanently
    if "params" in best and best["worst"] < 999.0:
        p = best["params"]
        write_lines(SPE, update_spe(lines,
                                    tuple(p["fnpgt"]), tuple(p["xlmaxt"]),
                                    tuple(p["ylmaxt"]), tuple(tuple(x) for x in p["pheno"])))
        print(f"\n*** SPE updated ***")
    else:
        shutil.copy2(backup, SPE)
        print("\n*** No improvement — SPE unchanged ***")

    # Report
    m = best["metrics"]
    print(f"\nFinal SPE parameters:")
    p = best["params"]
    print(f"  FNPGT  = {list(p['fnpgt'])}")
    print(f"  XLMAXT = {list(p['xlmaxt'])}")
    print(f"  YLMAXT = {list(p['ylmaxt'])}")
    print(f"\nShape NRMSE (temperature response):")
    print(f"  Rex (4 temps): {m['rex_shape']:.1f}%")
    print(f"  WG  (3 temps): {m['wg_shape']:.1f}%")
    print(f"  SITONIA bias (validation): {m['sitonia_bias']:.1f}%")
    print(f"\nNow run: calibrate_cul_lfmax_slavr.py")


if __name__ == "__main__":
    main()
