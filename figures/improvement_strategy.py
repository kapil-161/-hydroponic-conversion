#!/usr/bin/env python3
"""
Comprehensive analysis of remaining calibration gaps in WAGA9101 lettuce model.
Identifies best next optimization targets.
"""

import pandas as pd
import numpy as np
from pathlib import Path

# Data paths
PLANTGRO = Path("/Applications/DSSAT48/Lettuce/PlantGro.OUT")
PLANTN = Path("/Applications/DSSAT48/Lettuce/PlantN.OUT")
PLANTP = Path("/Applications/DSSAT48/Lettuce/PlantP.OUT")
PLANTK = Path("/Applications/DSSAT48/Lettuce/PlantK.OUT")
LUT = Path("/Applications/DSSAT48/Lettuce/WAGA9101.LUT")

# Observation timepoints (from WAGA9101.LUT)
OBS_DAS = [1, 8, 15, 29, 36, 43, 50]

def read_dssat_output(fpath, col_name):
    """Extract daily values from DSSAT output file."""
    data = {}
    with open(fpath) as f:
        lines = f.readlines()
    in_data = False
    col_idx = None
    for line in lines:
        if "@YEAR" in line:
            cols = line.split()
            try:
                col_idx = cols.index(col_name)
                in_data = True
            except ValueError:
                pass
            continue
        if in_data and line.startswith(" 1991"):
            parts = line.split()
            if len(parts) > col_idx:
                try:
                    das = int(parts[2])  # DAS is always at index 2
                    val = float(parts[col_idx])
                    data[das] = val
                except (ValueError, IndexError):
                    pass
    return data

def read_lut_obs():
    """Read WAGA9101.LUT observed data."""
    obs = {
        'DAS': [], 'CWAD': [], 'RWAD': [], 'N%': [], 'P%': [], 'K%': [],
        'NUPC': [], 'PUPC': [], 'KUPC': []
    }
    # Map WAGA9101 date to DAS
    date_to_das = {
        1991154: 1, 1991161: 8, 1991168: 15, 1991182: 29, 
        1991189: 36, 1991196: 43, 1991203: 50
    }
    with open(LUT) as f:
        for line in f:
            if not line.strip() or line.startswith("*") or line.startswith("@"):
                continue
            parts = line.split()
            if len(parts) >= 13:
                try:
                    date = int(parts[1])
                    das = date_to_das.get(date)
                    if das is not None:
                        obs['DAS'].append(das)
                        obs['CWAD'].append(float(parts[2]))   # CWAD
                        obs['RWAD'].append(float(parts[3]))   # RWAD
                        obs['N%'].append(float(parts[4]))     # LN%D (leaf N%)
                        obs['P%'].append(float(parts[6]))     # SHPPD (shoot P%)
                        obs['K%'].append(float(parts[8]))     # SHKPD (shoot K%)
                        obs['NUPC'].append(float(parts[10]))  # NUPC
                        obs['PUPC'].append(float(parts[11]))  # PUPC
                        obs['KUPC'].append(float(parts[12]))  # KUPC
                except (ValueError, IndexError):
                    pass
    return obs

def analyze_variable(var_name, obs_col, sim_file, sim_col):
    """Analyze single variable across all observation points."""
    print(f"\n{'='*70}")
    print(f"VARIABLE: {var_name}")
    print(f"{'='*70}")
    
    obs = read_lut_obs()
    sim = read_dssat_output(sim_file, sim_col)
    
    obs_data = {obs['DAS'][i]: obs[obs_col][i] for i in range(len(obs['DAS']))}
    
    results = []
    total_error = 0
    for das in OBS_DAS:
        o = obs_data.get(das, None)
        s = sim.get(das, None)
        if o is not None and s is not None:
            error = abs(s - o)
            pct_error = 100 * error / max(abs(o), 1e-6)
            ratio = s / max(o, 1e-6)
            results.append((das, o, s, error, pct_error, ratio))
            total_error += pct_error
    
    # Print table
    print(f"{'DAS':>5} {'Observed':>12} {'Simulated':>12} {'Abs Error':>12} {'Pct Error':>12} {'Ratio':>8}")
    print("-" * 70)
    for das, o, s, err, pct, ratio in results:
        print(f"{das:>5} {o:>12.2f} {s:>12.2f} {err:>12.2f} {pct:>11.1f}% {ratio:>8.3f}")
    
    avg_pct_error = total_error / len(results) if results else 0
    rmse = np.sqrt(sum((r[4]**2 for r in results)) / len(results)) if results else 0
    
    print(f"\nAverage % Error: {avg_pct_error:.1f}%")
    print(f"RMSE (%): {rmse:.1f}%")
    
    # Identify worst timepoints
    sorted_results = sorted(results, key=lambda x: x[4], reverse=True)
    print(f"\nWorst errors (top 3):")
    for das, o, s, err, pct, ratio in sorted_results[:3]:
        print(f"  DAS {das}: {pct:.1f}% error (obs={o:.2f}, sim={s:.2f}, ratio={ratio:.3f})")
    
    return results

# Run analysis on key variables
print("\n" + "="*70)
print("WAGA9101 LETTUCE MODEL - CALIBRATION GAP ANALYSIS")
print("="*70)

cwad_results = analyze_variable("SHOOT BIOMASS (CWAD)", 'CWAD', PLANTGRO, 'CWAD')
rwad_results = analyze_variable("ROOT BIOMASS (RWAD)", 'RWAD', PLANTGRO, 'RWAD')
nupc_results = analyze_variable("N UPTAKE (NUPC)", 'NUPC', PLANTN, 'NUPC')
pupc_results = analyze_variable("P UPTAKE (PUPC)", 'PUPC', PLANTP, 'PUPC')
kupc_results = analyze_variable("K UPTAKE (KUPC)", 'KUPC', PLANTK, 'KUPC')

# Summary and recommendations
print("\n" + "="*70)
print("CALIBRATION STRATEGY RECOMMENDATIONS")
print("="*70)

variables_ranked = [
    ("Shoot Biomass (CWAD)", [r[4] for r in cwad_results]),
    ("Root Biomass (RWAD)", [r[4] for r in rwad_results]),
    ("N Uptake (NUPC)", [r[4] for r in nupc_results]),
    ("P Uptake (PUPC)", [r[4] for r in pupc_results]),
    ("K Uptake (KUPC)", [r[4] for r in kupc_results]),
]

# Calculate priority scores
for var_name, errors in variables_ranked:
    avg_error = np.mean(errors)
    early_error = np.mean(errors[:3]) if len(errors) >= 3 else avg_error
    late_error = np.mean(errors[-2:]) if len(errors) >= 2 else avg_error
    print(f"\n{var_name}:")
    print(f"  Average error: {avg_error:.1f}%")
    print(f"  Early-season (DAS 1-15): {early_error:.1f}%")
    print(f"  Late-season (DAS 36-50): {late_error:.1f}%")
    
    if early_error > late_error:
        print(f"  → Priority: EARLY-SEASON CALIBRATION (Photosynthesis/RUE)")
    else:
        print(f"  → Priority: LATE-SEASON CALIBRATION (N saturation/stress)")

print("\n" + "="*70)
print("RECOMMENDED NEXT STEPS")
print("="*70)
print("""
TIER 1 - High Impact (do first, ~30 min):
  1. Cross-validate N parameters on UFGA2201 batch
     → Run: calibrate_spe.py
     → Check if N calibration (Jmax/Km) generalizes across cultivars/temps
  
TIER 2 - Medium Impact (if CWAD error remains > 15%):
  2. Calibrate RUE (Radiation Use Efficiency) via PGEFF
     → Modify FNPGT temperature response parameters
     → Target: 15-20% increase in early-season growth rate
     → Use: calibrate_spe.py with FNPGT grid search
  
TIER 3 - Advanced (if NUPC still overshoots at harvest):
  3. Implement late-season N limitation saturation
     → Add N-stress multiplier when Leaf N% < 4.0%
     → Modify JMAX_NO3 dynamically in hydroponic module
     → Requires source code modification

Expected Impact:
  • N calibration (Tier 1): +0.005-0.015 d-stat improvement
  • RUE calibration (Tier 2): +0.005-0.010 d-stat improvement  
  • Late N-saturation (Tier 3): +0.005-0.010 d-stat improvement
  → Combined could achieve d-stat > 0.98 on WAGA9101
""")
