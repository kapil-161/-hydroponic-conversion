"""
Automated Lettuce Cultivar Parameter Calibration Script
Automatically adjusts LFMAX, SLAVR, and SIZLF to minimize RMSE
"""

import os
import re
import subprocess
import shutil
from pathlib import Path
import numpy as np
from scipy.optimize import minimize, differential_evolution
import time

# Configuration
DSSAT_EXE = r"C:\dssat-csm-os\build\bin\dscsm048.exe"
CULTIVAR_FILE = r"C:\DSSAT48\Genotype\LUGRO048.CUL"
EXPERIMENT_FILE = r"C:\DSSAT48\Lettuce\UFGA2401.LUX"
OUTPUT_DIR = r"C:\DSSAT48\Lettuce"
BACKUP_FILE = r"C:\DSSAT48\Genotype\LUGRO048.CUL.backup"

# Observed data (from LUT file)
# DAS 14, 21, 28, 35 from experiment = DAP 0, 7, 14, 21 (days after transplant)
OBSERVED_DATA = {
    0: {'CWAD': 6, 'LAID': None},
    7: {'CWAD': 95, 'LAID': 1.14},
    14: {'CWAD': 502, 'LAID': 1.82},
    21: {'CWAD': 1287, 'LAID': 3.56}
}

# Parameter bounds (min, max) for optimization
PARAM_BOUNDS = {
    'LFMAX': (1.00, 1.50),  # Further expanded - focus on higher photosynthesis rates
    'SLAVR': (350, 550),    # Expanded range for specific leaf area
    'SIZLF': (150, 300)     # Expanded upper bound for larger leaves
}

# Cultivar codes to optimize
CULTIVARS = {
    'LU0201': {'name': 'BUTTERCRUNCH', 'line_num': None},
    'LU0202': {'name': 'BUTTERHEAD', 'line_num': None}
}


def backup_cultivar_file():
    """Create backup of cultivar file"""
    if os.path.exists(CULTIVAR_FILE):
        shutil.copy2(CULTIVAR_FILE, BACKUP_FILE)
        print(f"Backup created: {BACKUP_FILE}")


def read_cultivar_file():
    """Read cultivar file and find line numbers for cultivars"""
    with open(CULTIVAR_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        for cultivar_code in CULTIVARS:
            if line.strip().startswith(cultivar_code):
                CULTIVARS[cultivar_code]['line_num'] = i
                break
    
    return lines


def update_cultivar_parameters(lfmax, slavr, sizlf, cultivar_code='LU0201'):
    """Update cultivar parameters in the file - preserves original formatting"""
    lines = read_cultivar_file()
    
    if CULTIVARS[cultivar_code]['line_num'] is None:
        raise ValueError(f"Cultivar {cultivar_code} not found in file")
    
    line_idx = CULTIVARS[cultivar_code]['line_num']
    line = lines[line_idx].rstrip()
    
    # Parse the line - format: VAR# VRNAME EXPNO ECO# CSDL PPSEN EM-FL FL-SH FL-SD SD-PM FL-LF LFMAX SLAVR SIZLF XFRT ...
    # Example: "LU0201 BUTTERCRUNCH 3       . LU0402 12.50 0.000 59.58 9.562 16.29 29.83 40.00 0.910 385.0 193.0 0.001 ..."
    # Use regex to find and replace the three parameters while preserving format
    import re
    
    # Pattern to match LFMAX, SLAVR, SIZLF (with flexible spacing)
    # Look for pattern: number (LFMAX) number (SLAVR) number (SIZLF)
    # These are after FL-LF (index 11) which is 40.00
    pattern = r'(\d+\.\d+)\s+(\d+\.?\d*)\s+(\d+\.?\d*)(\s+0\.001)'  # Matches LFMAX SLAVR SIZLF followed by 0.001
    
    replacement = f'{lfmax:.3f} {slavr:.1f} {sizlf:.1f}\\4'
    
    new_line = re.sub(pattern, replacement, line) + '\n'
    lines[line_idx] = new_line
    
    # Also update LU0202 with slightly different values
    if cultivar_code == 'LU0201' and CULTIVARS['LU0202']['line_num'] is not None:
        line_idx2 = CULTIVARS['LU0202']['line_num']
        line2 = lines[line_idx2].rstrip()
        new_line2 = re.sub(pattern, f'{lfmax:.3f} {slavr-5:.1f} {sizlf-5:.1f}\\4', line2) + '\n'
        lines[line_idx2] = new_line2
    
    # Write updated file
    with open(CULTIVAR_FILE, 'w', encoding='utf-8') as f:
        f.writelines(lines)


def run_simulation():
    """Run DSSAT simulation"""
    original_dir = os.getcwd()
    try:
        os.chdir(OUTPUT_DIR)
        result = subprocess.run(
            [DSSAT_EXE, 'A', 'UFGA2401.LUX'],
            capture_output=True,
            text=True,
            timeout=60,
            cwd=OUTPUT_DIR
        )
        success = result.returncode == 0
        if not success:
            print(f"  Simulation failed with return code {result.returncode}")
            if result.stderr:
                print(f"  Error: {result.stderr[:200]}")
        return success
    except subprocess.TimeoutExpired:
        print("  Simulation timed out")
        return False
    except Exception as e:
        print(f"  Simulation error: {e}")
        return False
    finally:
        os.chdir(original_dir)


def extract_simulated_values():
    """Extract simulated CWAD and LAID values from PlantGro.OUT"""
    plantgro_file = os.path.join(OUTPUT_DIR, 'PlantGro.OUT')
    
    if not os.path.exists(plantgro_file):
        return None
    
    simulated = {}
    
    with open(plantgro_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract values for DAP 0, 7, 14, 21
    # Format: YEAR DOY DAS DAP L#SD GSTD LAID LWAD SWAD GWAD RWAD VWAD CWAD ...
    lines = content.split('\n')
    for line in lines:
        parts = line.split()
        if len(parts) > 11:
            try:
                # Check if this is a data line (starts with year)
                year = int(parts[0])
                dap = int(parts[3])

                if dap in [0, 7, 14, 21]:
                    laid = float(parts[6])  # LAID is column 6 (0-indexed)
                    cwad = float(parts[11])  # CWAD is column 11

                    # Only keep first occurrence of each DAP (from first treatment)
                    if dap not in simulated:
                        simulated[dap] = {'CWAD': cwad, 'LAID': laid}
            except (ValueError, IndexError):
                continue
    
    return simulated if simulated else None


def calculate_rmse(simulated):
    """Calculate RMSE for CWAD and LAID"""
    if not simulated:
        return float('inf'), float('inf')
    
    cwad_errors = []
    laid_errors = []
    
    for dap, obs_data in OBSERVED_DATA.items():
        if dap not in simulated:
            continue
        
        sim_data = simulated[dap]
        
        # CWAD RMSE
        if obs_data['CWAD'] is not None:
            error = (sim_data['CWAD'] - obs_data['CWAD'])**2
            cwad_errors.append(error)
        
        # LAID RMSE
        if obs_data['LAID'] is not None and sim_data['LAID'] is not None:
            error = (sim_data['LAID'] - obs_data['LAID'])**2
            laid_errors.append(error)
    
    cwad_rmse = np.sqrt(np.mean(cwad_errors)) if cwad_errors else float('inf')
    laid_rmse = np.sqrt(np.mean(laid_errors)) if laid_errors else float('inf')
    
    return cwad_rmse, laid_rmse


def objective_function(params):
    """Objective function to minimize (weighted RMSE)"""
    lfmax, slavr, sizlf = params
    
    # Update cultivar file
    update_cultivar_parameters(lfmax, slavr, sizlf)
    
    # Run simulation
    if not run_simulation():
        return 1e6  # Large penalty for failed simulation
    
    # Extract results
    simulated = extract_simulated_values()
    
    if not simulated:
        return 1e6
    
    # Calculate RMSE
    cwad_rmse, laid_rmse = calculate_rmse(simulated)
    
    # Weighted combination (can adjust weights)
    total_rmse = cwad_rmse * 0.5 + laid_rmse * 50  # Scale LAID RMSE
    
    print(f"  LFMAX={lfmax:.3f}, SLAVR={slavr:.1f}, SIZLF={sizlf:.1f} -> "
          f"CWAD_RMSE={cwad_rmse:.2f}, LAID_RMSE={laid_rmse:.3f}, Total={total_rmse:.2f}")
    
    return total_rmse


def grid_search_optimization():
    """Simple grid search optimization (faster for testing)"""
    print("=" * 70)
    print("Grid Search Optimization (Faster)")
    print("=" * 70)
    
    backup_cultivar_file()
    read_cultivar_file()
    
    # Define grid ranges
    lfmax_range = np.linspace(0.80, 0.95, 8)
    slavr_range = np.linspace(340, 390, 6)
    sizlf_range = np.linspace(170, 195, 6)
    
    best_rmse = float('inf')
    best_params = None
    iteration = 0
    total_iterations = len(lfmax_range) * len(slavr_range) * len(sizlf_range)
    
    print(f"Testing {total_iterations} parameter combinations...")
    print()
    
    for lfmax in lfmax_range:
        for slavr in slavr_range:
            for sizlf in sizlf_range:
                iteration += 1
                rmse = objective_function([lfmax, slavr, sizlf])
                
                if rmse < best_rmse:
                    best_rmse = rmse
                    best_params = [lfmax, slavr, sizlf]
                    print(f"  [{iteration}/{total_iterations}] NEW BEST: "
                          f"LFMAX={lfmax:.3f}, SLAVR={slavr:.1f}, SIZLF={sizlf:.1f}, RMSE={rmse:.2f}")
    
    return best_params, best_rmse


def optimize_parameters(method='differential_evolution'):
    """Main optimization function"""
    print("=" * 70)
    print("Automated Lettuce Cultivar Parameter Calibration")
    print("=" * 70)
    print(f"Target: Minimize RMSE for CWAD and LAID")
    print(f"Observed data points: DAP {list(OBSERVED_DATA.keys())}")
    print()
    
    # Create backup
    backup_cultivar_file()
    
    # Read initial file to find line numbers
    read_cultivar_file()
    
    # Parameter bounds
    bounds = [
        PARAM_BOUNDS['LFMAX'],
        PARAM_BOUNDS['SLAVR'],
        PARAM_BOUNDS['SIZLF']
    ]
    
    # Initial guess (start from previous best parameters)
    initial_guess = [1.20, 460.6, 172.3]
    
    print("Starting optimization...")
    print(f"Initial parameters: LFMAX={initial_guess[0]}, SLAVR={initial_guess[1]}, SIZLF={initial_guess[2]}")
    print(f"Optimization method: {method}")
    print()
    
    if method == 'grid_search':
        # Grid search (simpler, faster for testing)
        best_params, best_rmse = grid_search_optimization()
        result = type('obj', (object,), {'x': best_params, 'fun': best_rmse})()
    elif method == 'differential_evolution':
        # Use differential evolution (global optimization)
        print("Running Differential Evolution optimization...")
        result = differential_evolution(
            objective_function,
            bounds,
            seed=42,
            maxiter=75,      # Increased for more thorough search
            popsize=12,      # Increased population size
            atol=1e-5,       # Increased precision
            polish=True
        )
    elif method == 'minimize':
        # Use local optimization (faster but may get stuck in local minima)
        print("Running local minimization (L-BFGS-B)...")
        result = minimize(
            objective_function,
            initial_guess,
            method='L-BFGS-B',
            bounds=bounds,
            options={'maxiter': 15}
        )
    else:
        raise ValueError(f"Unknown method: {method}. Use 'grid_search', 'differential_evolution', or 'minimize'")
    
    print()
    print("=" * 70)
    print("OPTIMIZATION COMPLETE")
    print("=" * 70)
    print(f"Best parameters found:")
    print(f"  LFMAX = {result.x[0]:.3f}")
    print(f"  SLAVR = {result.x[1]:.1f}")
    print(f"  SIZLF = {result.x[2]:.1f}")
    print(f"  Final RMSE = {result.fun:.2f}")
    print()
    
    # Final simulation with best parameters
    print("Running final simulation with optimized parameters...")
    update_cultivar_parameters(result.x[0], result.x[1], result.x[2])
    run_simulation()
    simulated = extract_simulated_values()
    
    if simulated is None:
        print("ERROR: Could not extract simulated values from output file")
        return result.x, float('inf'), float('inf')
    
    cwad_rmse, laid_rmse = calculate_rmse(simulated)
    
    print()
    print("=" * 70)
    print("FINAL RESULTS")
    print("=" * 70)
    print(f"CWAD RMSE: {cwad_rmse:.2f} kg/ha")
    print(f"LAID RMSE: {laid_rmse:.3f}")
    print()
    print("Comparison:")
    print(f"{'DAP':<6} {'Parameter':<8} {'Observed':<12} {'Simulated':<12} {'Diff':<12} {'% Match':<10}")
    print("-" * 70)
    
    for dap in sorted(OBSERVED_DATA.keys()):
        if simulated and dap in simulated:
            obs = OBSERVED_DATA[dap]
            sim = simulated[dap]
            
            if obs['CWAD'] is not None:
                diff = sim['CWAD'] - obs['CWAD']
                pct = (sim['CWAD'] / obs['CWAD'] * 100) if obs['CWAD'] > 0 else 0
                print(f"{dap:<6} {'CWAD':<8} {obs['CWAD']:<12.1f} {sim['CWAD']:<12.1f} {diff:<12.1f} {pct:<10.1f}%")
            
            if obs['LAID'] is not None and sim['LAID'] is not None:
                diff = sim['LAID'] - obs['LAID']
                pct = (sim['LAID'] / obs['LAID'] * 100) if obs['LAID'] > 0 else 0
                print(f"{dap:<6} {'LAID':<8} {obs['LAID']:<12.3f} {sim['LAID']:<12.3f} {diff:<12.3f} {pct:<10.1f}%")
    
    print()
    print(f"Optimized cultivar file saved: {CULTIVAR_FILE}")
    print(f"Backup available at: {BACKUP_FILE}")
    
    return result.x, cwad_rmse, laid_rmse


if __name__ == '__main__':
    import sys
    
    # Allow method selection via command line argument
    method = 'differential_evolution'
    if len(sys.argv) > 1:
        method = sys.argv[1]
    
    try:
        best_params, cwad_rmse, laid_rmse = optimize_parameters(method=method)
        print()
        print("Calibration completed successfully!")
        print(f"\nTo use these parameters, the cultivar file has been updated.")
        print(f"To restore original: copy {BACKUP_FILE} to {CULTIVAR_FILE}")
    except Exception as e:
        import traceback
        print(f"\nERROR: {e}")
        traceback.print_exc()
        print("\nRestoring backup...")
        if os.path.exists(BACKUP_FILE):
            shutil.copy2(BACKUP_FILE, CULTIVAR_FILE)
            print("Backup restored.")
        raise

