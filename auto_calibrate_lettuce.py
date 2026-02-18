"""
Automated Lettuce Cultivar Parameter Calibration Script
Calibrates LFMAX, SLAVR, SIZLF for Rex, Muir, Skyphos cultivars
against VKGA2201 hydroponic NFT experiment (Vought Ch2 Period 1)
"""

import os
import re
import subprocess
import shutil
from pathlib import Path
import numpy as np
from scipy.optimize import differential_evolution
import time

# Configuration
DSSAT_EXE = r"C:\dssat-csm-os\build\bin\dscsm048.exe"
CULTIVAR_FILE = r"C:\DSSAT48\Genotype\LUGRO048.CUL"
EXPERIMENT_FILE = "VKGA2201.LUX"
OUTPUT_DIR = r"C:\DSSAT48\Lettuce"
BACKUP_FILE = r"C:\DSSAT48\Genotype\LUGRO048.CUL.backup"

# Observed CWAD time-series (kg/ha) from VKGA2201.LUT
# DAP -> {TRT: CWAD}
OBSERVED_CWAD = {
    1:  {1: 1,   2: 3,    3: 4,    4: 0},
    4:  {1: 2,   2: 7,    3: 8,    4: 0},
    7:  {1: 5,   2: 14,   3: 16,   4: 0},
    8:  {1: 4,   2: 12,   3: 51,   4: 0},
    11: {1: 4,   2: 10,   3: 86,   4: 0},
    13: {1: 9,   2: 11,   3: 50,   4: 9},
    15: {1: 20,  2: 42,   3: 34,   4: 44},
    18: {1: 25,  2: 71,   3: 54,   4: 69},
    20: {1: 64,  2: 84,   3: 62,   4: 55},
    22: {1: 183, 2: 165,  3: 102,  4: 156},
    25: {1: 262, 2: 234,  3: 134,  4: 269},
    27: {1: 358, 2: 365,  3: 157,  4: 234},
    29: {1: 495, 2: 765,  3: 258,  4: 597},
    32: {1: 536, 2: 1033, 3: 337,  4: 995},
    35: {1: 1002,2: 1277, 3: 626,  4: 1066},
}

# Cultivar -> treatment mapping
# Rex = LU0001 (Trt 1 at EC1.2, Trt 4 at EC1.6)
# Muir = LU0002 (Trt 2 at EC1.2)
# Skyphos = LU0003 (Trt 3 at EC1.2)
CULTIVARS = {
    'LU0001': {'name': 'REX',     'treatments': [1, 4]},
    'LU0002': {'name': 'MUIR',    'treatments': [2]},
    'LU0003': {'name': 'SKYPHOS', 'treatments': [3]},
}

# Parameter bounds from CUL MINIMA/MAXIMA
PARAM_BOUNDS = {
    'LFMAX': (0.500, 1.500),
    'SLAVR': (300.0, 400.0),
    'SIZLF': (145.0, 250.0),
}

# CUL file column positions (0-indexed within the line)
# @VAR# VRNAME.......... EXPNO ECO# CSDL PPSEN EM-FL FL-SH FL-SD SD-PM FL-LF LFMAX SLAVR SIZLF ...
# Column indices after splitting on whitespace:
#   0=VAR#, 1=VRNAME, 2=EXPNO, 3=ECO#(.), 4=ECO#, 5=CSDL, 6=PPSEN,
#   7=EM-FL, 8=FL-SH, 9=FL-SD, 10=SD-PM, 11=FL-LF, 12=LFMAX, 13=SLAVR, 14=SIZLF


def backup_cultivar_file():
    if not os.path.exists(BACKUP_FILE):
        shutil.copy2(CULTIVAR_FILE, BACKUP_FILE)
        print(f"Backup created: {BACKUP_FILE}")


def restore_backup():
    if os.path.exists(BACKUP_FILE):
        shutil.copy2(BACKUP_FILE, CULTIVAR_FILE)
        print("Backup restored.")


def read_cul_line(cultivar_id):
    """Read the CUL file line for a given cultivar ID, return (line_index, line_text)"""
    with open(CULTIVAR_FILE, 'r') as f:
        lines = f.readlines()
    for i, line in enumerate(lines):
        if line.strip().startswith(cultivar_id):
            return i, line
    raise ValueError(f"Cultivar {cultivar_id} not found in {CULTIVAR_FILE}")


def update_cultivar_params(cultivar_id, lfmax, slavr, sizlf):
    """Update LFMAX, SLAVR, SIZLF for a cultivar using binary read/write
    to preserve exact file formatting (CRLF, spacing, etc.).

    CUL header columns (0-indexed char positions):
      LFMAX starts at 79, width 6 (79-84)
      SLAVR starts at 85, width 6 (85-90)
      SIZLF starts at 91, width 7 (91-97)
    """
    LFMAX_START = 79
    SIZLF_END = 98

    with open(CULTIVAR_FILE, 'rb') as f:
        raw = f.read()

    lines = raw.split(b'\r\n')

    line_idx = None
    for i, l in enumerate(lines):
        if l.lstrip().startswith(cultivar_id.encode()):
            line_idx = i
            break

    if line_idx is None:
        raise ValueError(f"Cultivar {cultivar_id} not found")

    line = lines[line_idx]

    # Pad if too short
    if len(line) < SIZLF_END:
        line = line + b' ' * (SIZLF_END - len(line))

    # Format: LFMAX(6) + SLAVR(6) + SIZLF(7) = 19 chars total
    # LFMAX: 5.3f (5 chars) + space = 6
    # SLAVR: 5.1f (5 chars) + space = 6
    # SIZLF: 5.1f (5 chars) + 2 spaces = 7
    replacement = f"{lfmax:5.3f} {slavr:5.1f} {sizlf:5.1f}  ".encode()  # 6+6+7=19

    new_line = line[:LFMAX_START] + replacement + line[SIZLF_END:]
    lines[line_idx] = new_line

    with open(CULTIVAR_FILE, 'wb') as f:
        f.write(b'\r\n'.join(lines))


def run_dssat():
    """Run DSSAT simulation, return True on success"""
    result = subprocess.run(
        [DSSAT_EXE, 'A', EXPERIMENT_FILE],
        capture_output=True, text=True, timeout=120,
        cwd=OUTPUT_DIR
    )
    return result.returncode == 0


def parse_plantgro(treatment_nums):
    """Parse PlantGro.OUT and return {trt: {dap: cwad}} for specified treatments."""
    fpath = os.path.join(OUTPUT_DIR, 'PlantGro.OUT')
    if not os.path.exists(fpath):
        return None

    with open(fpath, 'r') as f:
        content = f.read()

    results = {}
    current_trt = None

    for line in content.split('\n'):
        # Detect treatment/run headers
        m = re.match(r'\*RUN\s+(\d+)', line)
        if m:
            current_trt = int(m.group(1))
            if current_trt in treatment_nums:
                results[current_trt] = {}
            continue

        if current_trt not in treatment_nums:
            continue

        parts = line.split()
        if len(parts) < 13:
            continue
        try:
            year = int(parts[0])
            dap = int(parts[3])
            cwad = float(parts[12])  # CWAD column
            if current_trt in results:
                results[current_trt][dap] = cwad
        except (ValueError, IndexError):
            continue

    return results if results else None


def calc_rmse(cultivar_id, simulated):
    """Calculate RMSE between simulated and observed CWAD for a cultivar's treatments."""
    trts = CULTIVARS[cultivar_id]['treatments']
    errors = []

    for dap, obs_by_trt in OBSERVED_CWAD.items():
        for trt in trts:
            if trt not in obs_by_trt or trt not in simulated:
                continue
            obs_val = obs_by_trt[trt]
            if obs_val <= 0:  # skip zero observations
                continue
            if dap not in simulated[trt]:
                continue
            sim_val = simulated[trt][dap]
            errors.append((sim_val - obs_val) ** 2)

    if not errors:
        return float('inf')
    return np.sqrt(np.mean(errors))


def objective(params, cultivar_id):
    """Objective function: update params, run DSSAT, return RMSE."""
    lfmax, slavr, sizlf = params
    update_cultivar_params(cultivar_id, lfmax, slavr, sizlf)

    if not run_dssat():
        return 1e6

    trts = CULTIVARS[cultivar_id]['treatments']
    simulated = parse_plantgro(trts)
    if simulated is None:
        return 1e6

    rmse = calc_rmse(cultivar_id, simulated)
    return rmse


def calibrate_cultivar(cultivar_id):
    """Calibrate one cultivar using differential evolution."""
    info = CULTIVARS[cultivar_id]
    print(f"\n{'='*70}")
    print(f"Calibrating {info['name']} ({cultivar_id}) — Treatments {info['treatments']}")
    print(f"{'='*70}")

    bounds = [
        PARAM_BOUNDS['LFMAX'],
        PARAM_BOUNDS['SLAVR'],
        PARAM_BOUNDS['SIZLF'],
    ]

    iteration_count = [0]
    best_so_far = [float('inf')]

    def callback(xk, convergence=0):
        iteration_count[0] += 1
        rmse = objective(xk, cultivar_id)
        if rmse < best_so_far[0]:
            best_so_far[0] = rmse
            print(f"  Gen {iteration_count[0]:3d}: LFMAX={xk[0]:.3f} SLAVR={xk[1]:.1f} "
                  f"SIZLF={xk[2]:.1f} => RMSE={rmse:.1f} kg/ha *")

    print(f"Running differential evolution (popsize=15, maxiter=50)...")
    t0 = time.time()

    result = differential_evolution(
        lambda p: objective(p, cultivar_id),
        bounds,
        seed=42,
        maxiter=50,
        popsize=15,
        tol=0.01,
        polish=True,
        callback=callback,
    )

    elapsed = time.time() - t0
    lfmax, slavr, sizlf = result.x

    # Apply best params
    update_cultivar_params(cultivar_id, lfmax, slavr, sizlf)
    run_dssat()
    simulated = parse_plantgro(info['treatments'])
    rmse = calc_rmse(cultivar_id, simulated) if simulated else float('inf')

    print(f"\n  RESULT for {info['name']}:")
    print(f"    LFMAX = {lfmax:.3f}")
    print(f"    SLAVR = {slavr:.1f}")
    print(f"    SIZLF = {sizlf:.1f}")
    print(f"    CWAD RMSE = {rmse:.1f} kg/ha")
    print(f"    Time: {elapsed:.0f}s ({result.nfev} evaluations)")

    # Print comparison table
    if simulated:
        print(f"\n  {'DAP':>4} ", end="")
        for trt in info['treatments']:
            print(f"  {'Obs_T'+str(trt):>8} {'Sim_T'+str(trt):>8}", end="")
        print()
        print(f"  {'-'*4} ", end="")
        for trt in info['treatments']:
            print(f"  {'-'*8} {'-'*8}", end="")
        print()

        for dap in sorted(OBSERVED_CWAD.keys()):
            print(f"  {dap:4d} ", end="")
            for trt in info['treatments']:
                obs = OBSERVED_CWAD[dap].get(trt, -99)
                sim = simulated.get(trt, {}).get(dap, -99)
                obs_str = f"{obs:8.0f}" if obs >= 0 else "     -99"
                sim_str = f"{sim:8.0f}" if sim >= 0 else "     -99"
                print(f"  {obs_str} {sim_str}", end="")
            print()

    return cultivar_id, lfmax, slavr, sizlf, rmse


def main():
    print("="*70)
    print("DSSAT Lettuce Cultivar Calibration — VKGA2201 Hydroponic NFT")
    print("Parameters: LFMAX, SLAVR, SIZLF")
    print("Objective: Minimize CWAD RMSE across growth time-series")
    print("="*70)

    backup_cultivar_file()

    results = {}
    for cul_id in ['LU0001', 'LU0002', 'LU0003']:
        cul_id, lfmax, slavr, sizlf, rmse = calibrate_cultivar(cul_id)
        results[cul_id] = (lfmax, slavr, sizlf, rmse)

    # Apply all calibrated params
    print(f"\n{'='*70}")
    print("CALIBRATION SUMMARY")
    print(f"{'='*70}")
    print(f"{'Cultivar':<12} {'LFMAX':>7} {'SLAVR':>7} {'SIZLF':>7} {'RMSE':>10}")
    print(f"{'-'*12} {'-'*7} {'-'*7} {'-'*7} {'-'*10}")

    for cul_id, (lfmax, slavr, sizlf, rmse) in results.items():
        name = CULTIVARS[cul_id]['name']
        print(f"{name:<12} {lfmax:7.3f} {slavr:7.1f} {sizlf:7.1f} {rmse:10.1f}")
        update_cultivar_params(cul_id, lfmax, slavr, sizlf)

    print(f"\nCalibrated file: {CULTIVAR_FILE}")
    print(f"Backup: {BACKUP_FILE}")

    # Final run with all calibrated cultivars
    print("\nRunning final simulation with all calibrated cultivars...")
    run_dssat()
    print("Done!")


if __name__ == '__main__':
    main()
