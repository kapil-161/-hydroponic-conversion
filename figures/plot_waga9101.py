#!/usr/bin/env python3
"""Publication-quality calibration figure for WAGA9101 hydroponic lettuce experiment."""
import math
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

# ── paths ──────────────────────────────────────────────────────────────────
LETTUCE  = Path("/Applications/DSSAT48/Lettuce")
LUT      = LETTUCE / "WAGA9101.LUT"
PLANTGRO = LETTUCE / "PlantGro.OUT"
PLANTN   = LETTUCE / "PlantN.OUT"
PLANTP   = LETTUCE / "PlantP.OUT"
PLANTK   = LETTUCE / "PlantK.OUT"
OUT_DIR  = Path("/Users/kapilbhattarai/-hydroponic-conversion/figures")
OUT_DIR.mkdir(exist_ok=True)

matplotlib.rcParams.update({
    "font.family":     "serif",
    "font.serif":      ["Times New Roman", "DejaVu Serif"],
    "font.size":       10,
    "axes.titlesize":  11,
    "axes.labelsize":  10,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 9,
    "figure.dpi":      300,
    "axes.linewidth":  0.8,
    "lines.linewidth": 1.5,
    "lines.markersize": 6,
})

# ── parsing ─────────────────────────────────────────────────────────────────
def read_lut_obs():
    """Read WAGA9101.LUT observed data. Filters out -99 missing data flags."""
    obs = {
        'DAS': [], 'CWAD': [], 'RWAD': [], 'N%': [], 
        'NUPC': [], 'PUPC': [], 'KUPC': []
    }
    # Map WAGA9101 date to DAS (1991154=DAS1, 1991203=DAS50)
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
                        cwad = float(parts[2])
                        rwad = float(parts[3])
                        ln_pct = float(parts[4])
                        nupc = float(parts[10])
                        pupc = float(parts[11])
                        kupc = float(parts[12])
                        
                        # Skip records with -99 missing values
                        if cwad != -99 and rwad != -99 and ln_pct != -99:
                            obs['DAS'].append(das)
                            obs['CWAD'].append(cwad)
                            obs['RWAD'].append(rwad)
                            obs['N%'].append(ln_pct)
                            obs['NUPC'].append(nupc if nupc != -99 else None)
                            obs['PUPC'].append(pupc if pupc != -99 else None)
                            obs['KUPC'].append(kupc if kupc != -99 else None)
                except (ValueError, IndexError):
                    pass
    return obs

def read_dssat_output(fpath, col_name):
    """Extract daily values from DSSAT output file. Filters out -99 missing data flags."""
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
                    # Skip missing data flag (-99)
                    if val != -99:
                        data[das] = val
                except (ValueError, IndexError):
                    pass
    return data
def d_stat(obs_vals, sim_vals):
    """Calculate Willmott’s d-statistic. Filters out None/-99."""
    # Filter valid pairs
    pairs = [(o, s) for o, s in zip(obs_vals, sim_vals) if o is not None and s is not None and o != -99 and s != -99]
    if not pairs:
        return 0
    obs_filt, sim_filt = zip(*pairs)
    obs_mean = sum(obs_filt) / len(obs_filt)
    numerator = sum((s - o)**2 for s, o in zip(sim_filt, obs_filt))
    denominator = sum((abs(s - obs_mean) + abs(o - obs_mean))**2 for s, o in zip(sim_filt, obs_filt))
    return 1 - numerator / denominator if denominator != 0 else 0

def nrmse(obs_vals, sim_vals):
    """Calculate normalized RMSE. Filters out None and -99 values."""
    # Filter out None values and -99 flags
    pairs = [(o, s) for o, s in zip(obs_vals, sim_vals) if o is not None and s is not None and o != -99 and s != -99]
    if not pairs:
        return 0
    obs_filt, sim_filt = zip(*pairs)
    n = len(obs_filt)
    rmse = math.sqrt(sum((s-o)**2 for s,o in zip(sim_filt, obs_filt)) / n)
    obs_mean = sum(obs_filt) / n
    return 100.0 * rmse / obs_mean if obs_mean > 0 else 0

# Read data
obs = read_lut_obs()
sim_cwad = read_dssat_output(PLANTGRO, 'CWAD')
sim_rwad = read_dssat_output(PLANTGRO, 'RWAD')
sim_nupc = read_dssat_output(PLANTN, 'NUPC')
sim_pupc = read_dssat_output(PLANTP, 'PUPC')
sim_kupc = read_dssat_output(PLANTK, 'KUPC')
sim_ln_pct = read_dssat_output(PLANTN, 'LN%D')

# Get simulated values at observation dates
def get_sim_at_obs(sim_dict, obs_das):
    """Interpolate simulated values at observation dates. Handles missing data."""
    sim_vals = []
    sim_das_sorted = sorted(sim_dict.keys())
    for das_o in obs_das:
        if das_o in sim_dict:
            sim_vals.append(sim_dict[das_o])
        else:
            elig = [d for d in sim_das_sorted if d <= das_o]
            if elig:
                sim_vals.append(sim_dict[elig[-1]])
            else:
                nearest = min(sim_das_sorted, key=lambda d: abs(d-das_o))
                sim_vals.append(sim_dict[nearest])
    return sim_vals

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 1 — 2×3 time-course panels for WAGA9101
# ═══════════════════════════════════════════════════════════════════════════
fig, axes = plt.subplots(2, 3, figsize=(10, 6))
fig.suptitle("", 
             fontsize=12, fontweight="bold", y=0.98)
fig.subplots_adjust(left=0.10, right=0.96, top=0.93, bottom=0.12,
                    hspace=0.35, wspace=0.35)

# Define panels: (axis, variable, obs_col, sim_dict, ylabel, units)
panels = [
    (axes[0,0], "Shoot Biomass", 'CWAD', sim_cwad, "CWAD", "kg ha$^{-1}$"),
    (axes[0,1], "Root Biomass", 'RWAD', sim_rwad, "RWAD", "kg ha$^{-1}$"),
    (axes[0,2], "Leaf N Content", 'N%', sim_ln_pct, "Leaf N%", "%"),
    (axes[1,0], "N Uptake", 'NUPC', sim_nupc, "NUPC", "kg ha$^{-1}$"),
    (axes[1,1], "P Uptake", 'PUPC', sim_pupc, "PUPC", "kg ha$^{-1}$"),
    (axes[1,2], "K Uptake", 'KUPC', sim_kupc, "KUPC", "kg ha$^{-1}$"),
]

colors = {
    'CWAD': '#2166ac', 'RWAD': '#92c5de', 'N%': '#4575b4',
    'NUPC': '#d6604d', 'PUPC': '#f4a582', 'KUPC': '#fee090'
}

for ax, var_name, var_key, sim_dict, y_label, units in panels:

    # --- Simulated line (full daily curve) ---
    sim_das_full = sorted(sim_dict.keys())
    sim_vals_full = [sim_dict[d] for d in sim_das_full]
    ax.plot(sim_das_full, sim_vals_full, "-", color=colors[var_key],
            linewidth=1.5, label="Simulated", zorder=2, alpha=0.8)

    # --- Observed points ---
    das_obs = np.array(obs['DAS'])
    vals_obs_raw = obs[var_key]
    valid_idx = [i for i, v in enumerate(vals_obs_raw) if v is not None]
    das_obs_valid = das_obs[valid_idx]
    vals_obs_valid = np.array([vals_obs_raw[i] for i in valid_idx])
    ax.scatter(das_obs_valid, vals_obs_valid, color="black", marker="o",
               s=32, zorder=4, label="Observed", edgecolors="white", linewidth=0.5)

    # --- NRMSE annotation ---
    sim_at_obs = get_sim_at_obs(sim_dict, das_obs)
    d = d_stat(vals_obs_raw, sim_at_obs)
    nr = nrmse(vals_obs_raw, sim_at_obs)

    # Coordinates in axes fraction (0–1)
    x_pos = 0.42
    y_start = 0.95  # top of panel
    line_spacing = 0.06  # space between lines

    # Place d-stat at top
    ax.annotate(f"d-stat = {d:.3f}", xy=(x_pos, y_start), xycoords='axes fraction',
            ha='right', va='top', fontsize=8,
            bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.8))

    # Place NRMSE below d-stat
    ax.annotate(f"NRMSE = {nr:.1f}%", xy=(x_pos, y_start - line_spacing), xycoords='axes fraction',
            ha='right', va='top', fontsize=8,
            bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.8))

    ax.set_ylabel(f"{y_label} ({units})", fontsize=10)
    ax.set_title(var_name, fontsize=11, fontweight="bold", pad=5)
    ax.set_xlabel("Days After Planting", fontsize=10)
    ax.set_xlim(0, 52)
    ax.tick_params(length=3.5, width=0.7)
    ax.grid(True, alpha=0.2, linestyle=":", linewidth=0.5)
    ax.set_facecolor("#f9f9f9")
    for spine in ax.spines.values():
        spine.set_linewidth(0.7)
    
    # Light background
    ax.set_facecolor("#f9f9f9")

# Add shared legend
from matplotlib.lines import Line2D
legend_elements = [
    Line2D([0], [0], color='#2166ac', lw=1.5, label='Simulated'),
    Line2D([0], [0], marker='o', color='w', markerfacecolor='black',
           markersize=6, label='Observed', markeredgecolor='white', markeredgewidth=0.5),
]
fig.legend(handles=legend_elements, loc="lower center", ncol=2,
           bbox_to_anchor=(0.5, -0.02), frameon=True, edgecolor="gray",
           handlelength=1.8, framealpha=0.95)

fig.savefig(OUT_DIR / "Fig1_WAGA9101_timecourse.png", dpi=300, bbox_inches="tight")
fig.savefig(OUT_DIR / "Fig1_WAGA9101_timecourse.pdf", bbox_inches="tight")
print("✓ Saved Fig1_WAGA9101_timecourse.png")
print("✓ Saved Fig1_WAGA9101_timecourse.pdf")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 2 — 1:1 scatter plots for key variables
# ═══════════════════════════════════════════════════════════════════════════
fig2, axes2 = plt.subplots(1, 3, figsize=(10, 3.2))
fig2.suptitle("", 
              fontsize=12, fontweight="bold", y=0.98)
fig2.subplots_adjust(left=0.10, right=0.96, top=0.90, bottom=0.15,
                     wspace=0.35)

scatter_panels = [
    (axes2[0], "Shoot Biomass (CWAD)", 'CWAD', sim_cwad, "kg ha$^{-1}$"),
    (axes2[1], "N Uptake (NUPC)", 'NUPC', sim_nupc, "kg ha$^{-1}$"),
    (axes2[2], "Root Biomass (RWAD)", 'RWAD', sim_rwad, "kg ha$^{-1}$"),
]

for ax, title, var_key, sim_dict, units in scatter_panels:
    obs_vals_raw = obs[var_key]
    
    # Filter out None values for plotting
    valid_idx = [i for i, v in enumerate(obs_vals_raw) if v is not None]
    obs_vals = np.array([obs_vals_raw[i] for i in valid_idx])
    obs_das_valid = np.array(obs['DAS'])[valid_idx]
    sim_at_obs = np.array(get_sim_at_obs(sim_dict, obs_das_valid))
    
    # Scatter
    ax.scatter(obs_vals, sim_at_obs, color="#2166ac", s=80, 
               marker="o", edgecolors="white", linewidth=1, zorder=3, alpha=0.7)
    
    # 1:1 line
    mx = max(np.max(obs_vals), np.max(sim_at_obs)) * 1.1
    ax.plot([0, mx], [0, mx], "k--", lw=1.0, label="1:1 reference", zorder=1)
    
    # Regression
    z = np.polyfit(obs_vals, sim_at_obs, 1)
    p = np.poly1d(z)
    x_fit = np.linspace(0, mx, 100)
    ax.plot(x_fit, p(x_fit), color="gray", lw=1.2, ls="-", alpha=0.6, 
            label="Linear fit")
    
    # Stats
    nr = nrmse(obs_vals, sim_at_obs)
    r2 = np.corrcoef(obs_vals, sim_at_obs)[0,1]**2
    rmse_val = math.sqrt(np.mean((sim_at_obs - obs_vals)**2))
    
    stats_text = (f"R² = {r2:.3f}\n"
                  f"RMSE = {rmse_val:.1f}\n"
                  f"NRMSE = {nr:.1f}%")
    ax.text(0.05, 0.95, stats_text, transform=ax.transAxes,
            fontsize=9, va="top", ha="left",
            bbox=dict(boxstyle="round,pad=0.4", fc="white", 
                     edgecolor="lightgray", alpha=0.9))
    
    ax.set_xlim(-5, mx)
    ax.set_ylim(-5, mx)
    ax.set_aspect("equal")
    ax.set_xlabel(f"Observed {title.split('(')[0].strip()} ({units})", fontsize=10)
    ax.set_ylabel(f"Simulated {title.split('(')[0].strip()} ({units})", fontsize=10)
    ax.set_title(title, fontsize=11, fontweight="bold", pad=5)
    ax.tick_params(length=3.5, width=0.7)
    ax.grid(True, alpha=0.2, linestyle=":", linewidth=0.5)
    ax.set_facecolor("#f9f9f9")
    
    for spine in ax.spines.values():
        spine.set_linewidth(0.7)
    
    # Add legend only on first subplot
    if ax == axes2[0]:
        ax.legend(loc="lower right", fontsize=9, framealpha=0.95)

fig2.savefig(OUT_DIR / "Fig2_WAGA9101_scatter.png", dpi=300, bbox_inches="tight")
fig2.savefig(OUT_DIR / "Fig2_WAGA9101_scatter.pdf", bbox_inches="tight")
print("✓ Saved Fig2_WAGA9101_scatter.png")
print("✓ Saved Fig2_WAGA9101_scatter.pdf")

print("\n✓ All figures saved to", OUT_DIR)
