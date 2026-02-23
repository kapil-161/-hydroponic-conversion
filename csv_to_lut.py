"""
Convert NPK_summary.csv to DSSAT LUT observed data file (VKGA2201.LUT)

Column mapping:
  NO3 (mg/L)   -> NO3CL  (NO3-N concentration in solution, mg/L)
  NH4 (mg/L)   -> NH4CL  (NH4-N concentration in solution, mg/L)
  P (mg/L)     -> PCCL   (P concentration in solution, mg/L)
  K (mg/L)     -> KCCL   (K concentration in solution, mg/L)
  CWAD (kg/ha) -> CWAD   (shoot dry weight, kg/ha)
  RWAD (kg/ha) -> RWAD   (root dry weight, kg/ha)
  N_%_Shoot    -> LN%D   (shoot N %, fraction*100)
  N_%_Root     -> RN%D   (root N %, fraction*100)
  P_%_Shoot    -> SHPPD  (shoot P %, fraction*100)
  P_%_Root     -> RTPPD  (root P %, fraction*100)
  K_%_Shoot    -> SHKPD  (shoot K %, fraction*100)
  K_%_Root     -> RTKPD  (root K %, fraction*100)
"""

import pandas as pd
import numpy as np

# ── paths ─────────────────────────────────────────────────────────────────────
CSV_IN  = 'C:/dssat-csm-os/NPK_summary.csv'
LUT_OUT = 'C:/DSSAT48/Lettuce/VKGA2201.LUT'

# ── read data (100 rows only, ignore metadata section) ────────────────────────
df = pd.read_csv(CSV_IN, nrows=100)

# ── tissue columns are stored as fractions → convert to % ────────────────────
tissue_cols = ['N_%_Shoot', 'N_%_Root', 'P_%_Shoot', 'P_%_Root',
               'K_%_Shoot', 'K_%_Root']
for col in tissue_cols:
    df[col] = pd.to_numeric(df[col], errors='coerce') * 100.0

# ── ensure all target columns are numeric ─────────────────────────────────────
for col in ['NO3 (mg/L)', 'NH4 (mg/L)', 'P (mg/L)', 'K (mg/L)',
            'CWAD (kg/ha)', 'RWAD (kg/ha)'] + tissue_cols:
    df[col] = pd.to_numeric(df[col], errors='coerce')

# ── formatting helpers ────────────────────────────────────────────────────────
MISSING = -99

def fv(val, width, dec):
    """Format a value; use MISSING if NaN."""
    if pd.isna(val):
        return f'{MISSING:{width}d}'
    return f'{val:{width}.{dec}f}'

# ── column definitions: (csv_col, dssat_code, width, decimals) ───────────────
COLS = [
    ('NO3 (mg/L)',   'NO3CL',  8, 1),
    ('NH4 (mg/L)',   'NH4CL',  8, 2),
    ('P (mg/L)',     'PCCL',   8, 2),
    ('K (mg/L)',     'KCCL',   8, 1),
    ('CWAD (kg/ha)', 'CWAD',   8, 1),
    ('RWAD (kg/ha)', 'RWAD',   8, 1),
    ('N_%_Shoot',    'LN%D',   7, 2),
    ('N_%_Root',     'RN%D',   7, 2),
    ('P_%_Shoot',    'SHPPD',  7, 3),
    ('P_%_Root',     'RTPPD',  7, 3),
    ('K_%_Shoot',    'SHKPD',  7, 3),
    ('K_%_Root',     'RTKPD',  7, 3),
]

# ── build header line ─────────────────────────────────────────────────────────
hdr = f'{"@TRNO":>6}{"DATE":>9}'
for _, code, w, _ in COLS:
    hdr += f'{code:>{w}}'

# ── write LUT file ────────────────────────────────────────────────────────────
rows_written = 0
with open(LUT_OUT, 'w') as f:
    f.write('*EXP. DATA (T): Hydroponic Lettuce - 3 Cultivars x 2 EC Levels\n')
    f.write('\n')
    f.write(hdr + '\n')

    for _, row in df.iterrows():
        # skip rows where every target variable is missing
        vals = [row[c] for c, *_ in COLS]
        if all(pd.isna(v) for v in vals):
            continue

        trno = int(row['TRNO'])
        date = int(row['Date'])
        line = f'{trno:6d}{date:9d}'
        for csv_col, _, w, d in COLS:
            line += fv(row[csv_col], w, d)
        f.write(line + '\n')
        rows_written += 1

print(f"Written {rows_written} data rows to {LUT_OUT}")
print(f"\nHeader:\n{hdr}")
print("\nFirst 5 rows:")
# re-read and show first 5 data lines
with open(LUT_OUT) as f:
    for i, line in enumerate(f):
        if i < 6:
            print(repr(line.rstrip()))
