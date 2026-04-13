#!/usr/bin/env python3
"""Diagnostic tool for LUGRO048.ECO parameters (LU0405) — run LAST and ONLY IF NEEDED.

ECO parameters (PM09, LNHSH, OPTBI, SLOBI) primarily affect N dynamics and organ
partitioning, not total harvest biomass (CWAM). Do NOT run this to fix CWAM errors —
fix those with SPE (temperature response) and CUL (LFMAX/SLAVR) first.

Run this only if, after SPE+CUL calibration, you observe:
  - N uptake (NUCM) deviating > 15% from WAGA9101 observed (118.8 kg/ha)
  - Tissue N% or K% trajectories are systematically wrong in WAGA9101

This script first diagnoses whether ECO tuning would help, then optionally calibrates.
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

ECO     = GENO / "LUGRO048.ECO"
BATCH   = LETTUCE / "DSSBatch.v48"
MODEL   = WORK / "build/bin/dscsm048"
SUMMARY = LETTUCE / "Summary.OUT"

# Observed harvest CWAM by batch run (for reference only — ECO should not be tuned to CWAM)
OBS_CWAM: dict[int, float] = {
    1: 1146.0,  2: 1177.0,  3: 1491.0,  4: 1499.0,
    5: 1134.0,  7: 1481.0,  8:  912.0,  9: 2862.0,
}
CAL_RUNS = (1, 2, 3, 4, 5, 7, 8, 9)

# WAGA9101 N uptake target (run 9) — primary ECO diagnostic
WAGA_OBS_NUCM = 118.8   # kg N/ha


# ---------------------------------------------------------------------------
# ECO file helpers
# ---------------------------------------------------------------------------

def _patch_eco_line(line: str, pm09: float, lnhsh: float,
                    optbi: float, slobi: float) -> str:
    return (line[:66]
            + f"{pm09:6.2f}"
            + f"{lnhsh:6.1f}"
            + line[78:114]
            + f"{optbi:6.1f}"
            + f"{slobi:6.3f}")


def update_eco(pm09: float, lnhsh: float, optbi: float, slobi: float) -> None:
    lines = ECO.read_text().splitlines()
    out = []
    for line in lines:
        if re.match(r"^LU0405\s", line):
            out.append(_patch_eco_line(line, pm09, lnhsh, optbi, slobi))
        else:
            out.append(line)
    ECO.write_text("\n".join(out) + "\n")


# ---------------------------------------------------------------------------
# Summary.OUT parsing
# ---------------------------------------------------------------------------

def parse_summary(col_name: str) -> dict[int, float]:
    """Extract any named column from Summary.OUT by run number."""
    text = SUMMARY.read_text().splitlines()
    col = None
    result: dict[int, float] = {}
    for line in text:
        if line.startswith("@") and col_name in line:
            col = line.index(col_name)
            continue
        if col is None or not line.strip() or line.startswith(("!", "*", "@")):
            continue
        m = re.match(r"^\s+(\d+)\s+\d+", line)
        if not m:
            continue
        run_no = int(m.group(1))
        try:
            result[run_no] = float(line[col:col + 8].strip())
        except (ValueError, IndexError):
            continue
    return result


def compute_metrics() -> dict:
    cwam = parse_summary("CWAM")
    nucm = parse_summary("NUCM")
    cwam_nrmse = {
        r: 100.0 * abs(cwam.get(r, -1.0) - OBS_CWAM[r]) / OBS_CWAM[r]
        if cwam.get(r, -1.0) > 0 else 999.0
        for r in CAL_RUNS
    }
    waga_nucm_bias = (
        100.0 * (nucm.get(9, -1.0) - WAGA_OBS_NUCM) / WAGA_OBS_NUCM
        if nucm.get(9, -1.0) > 0 else 999.0
    )
    worst_cwam = max(cwam_nrmse[r] for r in CAL_RUNS)
    avg_cwam   = sum(cwam_nrmse[r] for r in CAL_RUNS) / len(CAL_RUNS)
    return {
        "cwam_nrmse": cwam_nrmse,
        "worst_cwam": worst_cwam,
        "avg_cwam": avg_cwam,
        "waga_nucm_sim": nucm.get(9, -1.0),
        "waga_nucm_bias_pct": waga_nucm_bias,
    }


def print_diagnostics(m: dict, label: str) -> None:
    print(f"\n{'='*50}")
    print(f"{label}")
    print(f"  CWAM worst={m['worst_cwam']:.1f}%  avg={m['avg_cwam']:.1f}%")
    print(f"  WAGA9101 N uptake: sim={m['waga_nucm_sim']:.1f}  "
          f"obs={WAGA_OBS_NUCM:.1f}  bias={m['waga_nucm_bias_pct']:+.1f}%")
    print(f"{'='*50}")


def evaluate(label: str, pm09: float, lnhsh: float,
             optbi: float, slobi: float) -> dict:
    update_eco(pm09, lnhsh, optbi, slobi)
    subprocess.run([str(MODEL), "B", BATCH.name], check=True,
                   cwd=LETTUCE, capture_output=True)
    m = compute_metrics()
    print(f"  [{label}] N_bias={m['waga_nucm_bias_pct']:+.1f}%  "
          f"CWAM_worst={m['worst_cwam']:.1f}%  "
          f"PM09={pm09:.2f} LNHSH={lnhsh:.1f} OPTBI={optbi:.1f} SLOBI={slobi:.3f}",
          flush=True)
    return {"label": label, "metrics": m,
            "params": {"pm09": pm09, "lnhsh": lnhsh, "optbi": optbi, "slobi": slobi}}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    lu0405 = next(l for l in ECO.read_text().splitlines() if l.startswith("LU0405"))
    cur = {
        "pm09":  float(lu0405[66:72]),
        "lnhsh": float(lu0405[72:78]),
        "optbi": float(lu0405[114:120]),
        "slobi": float(lu0405[120:126]),
    }
    print(f"Current LU0405: {cur}")

    # Step 1: Diagnose baseline
    print("\n=== Baseline diagnosis ===")
    subprocess.run([str(MODEL), "B", BATCH.name], check=True,
                   cwd=LETTUCE, capture_output=True)
    baseline = compute_metrics()
    print_diagnostics(baseline, "Baseline")

    # Decision gate: only calibrate if N uptake deviates > 15%
    n_bias = abs(baseline["waga_nucm_bias_pct"])
    if n_bias <= 15.0 and baseline["worst_cwam"] <= 25.0:
        print(f"\nECO calibration NOT needed:")
        print(f"  N uptake bias = {baseline['waga_nucm_bias_pct']:+.1f}% (threshold: ±15%)")
        print(f"  CWAM worst    = {baseline['worst_cwam']:.1f}% (threshold: 25%)")
        print("  ECO parameters left unchanged.")
        return

    print(f"\nECO calibration triggered:")
    print(f"  N uptake bias = {baseline['waga_nucm_bias_pct']:+.1f}%  (> 15% threshold)")

    backup = ECO.with_suffix(".ECO.calib_bak")
    shutil.copy2(ECO, backup)
    print(f"  Backup: {backup}\n")

    # Step 2: Coordinate descent on N-uptake objective
    # Objective: minimise |N_uptake_bias|, subject to CWAM not getting worse
    state = dict(cur)
    best = {"metrics": baseline, "params": dict(cur)}

    pm09_vals  = [0.28, 0.30, 0.34, 0.38, 0.42, 0.46, 0.50]
    lnhsh_vals = [10.0, 11.0, 12.0, 13.0, 14.0, 16.0, 18.0]
    optbi_vals = [14.0, 16.0, 18.0, 20.0, 22.0]
    slobi_vals = [0.025, 0.028, 0.032, 0.035, 0.038, 0.042]

    def is_better(res: dict, ref: dict) -> bool:
        """Better = smaller |N_bias|, provided CWAM doesn't worsen by more than 3%."""
        new_n = abs(res["metrics"]["waga_nucm_bias_pct"])
        old_n = abs(ref["metrics"]["waga_nucm_bias_pct"])
        new_cwam = res["metrics"]["worst_cwam"]
        old_cwam = ref["metrics"]["worst_cwam"]
        return new_n < old_n and new_cwam <= old_cwam + 3.0

    try:
        for step in range(4):
            print(f"\n=== Step {step + 1} ===")
            improved = False
            for param, grid in (("pm09",  pm09_vals),
                                 ("lnhsh", lnhsh_vals),
                                 ("optbi", optbi_vals),
                                 ("slobi", slobi_vals)):
                for val in grid:
                    if abs(val - state[param]) < 1e-9:
                        continue
                    cand = dict(state); cand[param] = val
                    res = evaluate(f"s{step+1}_{param}={val:.3f}",
                                   cand["pm09"], cand["lnhsh"],
                                   cand["optbi"], cand["slobi"])
                    if is_better(res, best):
                        best = res
                        state = cand
                        improved = True
            if not improved:
                break

        update_eco(best["params"]["pm09"], best["params"]["lnhsh"],
                   best["params"]["optbi"], best["params"]["slobi"])
        print_diagnostics(best["metrics"], "After ECO calibration")
        print(f"*** ECO updated: {best['params']} ***")
        print("\n" + json.dumps({"baseline_N_bias": baseline["waga_nucm_bias_pct"],
                                  "final_N_bias": best["metrics"]["waga_nucm_bias_pct"],
                                  "best_params": best["params"]}, indent=2))

    except Exception:
        shutil.copy2(backup, ECO)
        print("ERROR — ECO restored from backup")
        raise


if __name__ == "__main__":
    main()
