#!/usr/bin/env python3
"""
Display WAGA9101 simulation results vs observations
"""
import pandas as pd
import numpy as np

# Observed data from WAGA9101.LUT
obs_data = {
    'DAS': [1, 8, 15, 29, 36, 43, 50],
    'CWAD_obs': [1.1, 4.8, 19.7, 344.5, 1045.2, 1893.7, 2862.1],
    'NUPC_obs': [-99, 0.28, 1.36, 21.55, 49.79, 85.30, 118.79],
    'RWAD_obs': [0.78, 1.41, 5.16, 67.25, 203.94, 291.37, 385.83],
}

# Simulated data (from PlantGro.OUT and PlantN.OUT)
sim_cwad = [2, 2, 6, 155, 716, 1791, 3001]     # g/m2
sim_rwad = [0, 0, 1, 21, 92, 224, 370]         # g/m2
sim_nupc = [0.0, 0.0, 0.3, 8.1, 37.5, 94.3, 161.8]  # kg/ha

df = pd.DataFrame(obs_data)
df['CWAD_sim'] = sim_cwad
df['RWAD_sim'] = sim_rwad
df['NUPC_sim'] = sim_nupc

# Calculate errors
df['CWAD_error'] = abs(df['CWAD_sim'] - df['CWAD_obs']) / df['CWAD_obs'] * 100
df['RWAD_error'] = abs(df['RWAD_sim'] - df['RWAD_obs']) / df['RWAD_obs'] * 100
df['NUPC_error'] = abs(df['NUPC_sim'] - df['NUPC_obs']) / (df['NUPC_obs'] + 1e-6) * 100

print('\n' + '='*80)
print('WAGA9101 LETTUCE HYDROPONIC MODEL - SIMULATION RESULTS')
print('='*80)

print('\n📊 SHOOT BIOMASS (CWAD, g/m²):')
print('-' * 80)
print(df[['DAS', 'CWAD_obs', 'CWAD_sim', 'CWAD_error']].to_string(index=False))
cwad_avg = df['CWAD_error'].mean()
print(f'\n  └─ Average error: {cwad_avg:.1f}%')

print('\n📊 ROOT BIOMASS (RWAD, g/m²):')
print('-' * 80)
print(df[['DAS', 'RWAD_obs', 'RWAD_sim', 'RWAD_error']].to_string(index=False))
rwad_avg = df['RWAD_error'].mean()
print(f'\n  └─ Average error: {rwad_avg:.1f}%')

print('\n📊 N UPTAKE (NUPC, kg/ha):')
print('-' * 80)
df_nupc = df[df['NUPC_obs'] > 0].copy()
print(df_nupc[['DAS', 'NUPC_obs', 'NUPC_sim', 'NUPC_error']].to_string(index=False))
nupc_avg = df_nupc['NUPC_error'].mean()
print(f'\n  └─ Average error (excl. DAS 1): {nupc_avg:.1f}%')

# Harvest performance
print('\n' + '='*80)
print('HARVEST PERFORMANCE (DAS 50):')
print('='*80)
print(f'  Shoot biomass: {sim_cwad[-1]:.0f} g/m² (obs: {obs_data["CWAD_obs"][-1]:.1f}, ratio: {sim_cwad[-1]/obs_data["CWAD_obs"][-1]:.3f})')
print(f'  Root biomass:  {sim_rwad[-1]:.0f} g/m² (obs: {obs_data["RWAD_obs"][-1]:.1f}, ratio: {sim_rwad[-1]/obs_data["RWAD_obs"][-1]:.3f})')
print(f'  N uptake:      {sim_nupc[-1]:.1f} kg/ha (obs: {obs_data["NUPC_obs"][-1]:.2f}, ratio: {sim_nupc[-1]/obs_data["NUPC_obs"][-1]:.3f})')

print('\n' + '='*80)
print('CALIBRATION STATUS:')
print('='*80)
if cwad_avg < 50 and nupc_avg < 50:
    print('✓ Model is well-calibrated for WAGA9101 conditions')
elif cwad_avg < 60 and nupc_avg < 60:
    print('⚠ Model shows moderate calibration; early-season undershoot remains')
else:
    print('✗ Model needs further calibration, especially early-season')

print(f'\nKey gaps:\n')
if df['CWAD_error'].iloc[:3].mean() > 50:
    print(f'  • Early-stage biomass (DAS 1-15): {df["CWAD_error"].iloc[:3].mean():.1f}% error')
if df['NUPC_error'].iloc[:3].mean() > 50:
    print(f'  • Early-stage N uptake (DAS 8-15): {df["NUPC_error"].iloc[:3].mean():.1f}% error')
if df['CWAD_error'].iloc[-1] > 10:
    print(f'  • Late-stage biomass (DAS 50): {df["CWAD_error"].iloc[-1]:.1f}% error')
if df['NUPC_error'].iloc[-1] > 20:
    print(f'  • Late-stage N uptake (DAS 50): {df["NUPC_error"].iloc[-1]:.1f}% error')

print('')
