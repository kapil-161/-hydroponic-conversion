#!/usr/bin/env python3
"""Publication-quality calibration figures for hydroponic lettuce DSSAT model."""
import math, re
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np

# ── paths ──────────────────────────────────────────────────────────────────
LETTUCE  = Path("/Applications/DSSAT48/Lettuce")
LUT      = LETTUCE / "UFGA2201.LUT"
PLANTGRO = LETTUCE / "PlantGro.OUT"
OUT_DIR  = Path("/Users/kapilbhattarai/-hydroponic-conversion/figures")
OUT_DIR.mkdir(exist_ok=True)

ALL_TRTS = tuple(range(1, 13))
TRT_NAMES = {
    1:"Rex 24°C",  2:"Rex 26°C",  3:"Rex 28°C",  4:"Rex 30°C",
    5:"Muir 24°C", 6:"Muir 26°C", 7:"Muir 28°C", 8:"Muir 30°C",
    9:"Sky 24°C", 10:"Sky 26°C", 11:"Sky 28°C", 12:"Sky 30°C",
}
CULTIVAR = {t: "Rex" if t<=4 else "Muir" if t<=8 else "Skyphos" for t in ALL_TRTS}
PDATE_DOY = {1:104,2:243,3:195,4:62,
             5:104,6:243,7:195,8:62,
             9:104,10:243,11:195,12:62}

# cultivar colours, temperature markers
CUL_COLOR = {"Rex": "#2166ac", "Muir": "#d6604d", "Skyphos": "#1a9641"}
TEMP_MARKER = {24:"o", 26:"s", 28:"^", 30:"D"}
TEMP_LABEL  = {24:"24°C", 26:"26°C", 28:"28°C", 30:"30°C"}

matplotlib.rcParams.update({
    "font.family":     "serif",
    "font.serif":      ["Times New Roman", "DejaVu Serif"],
    "font.size":       9,
    "axes.titlesize":  9,
    "axes.labelsize":  9,
    "xtick.labelsize": 8,
    "ytick.labelsize": 8,
    "legend.fontsize": 8,
    "figure.dpi":      300,
    "axes.linewidth":  0.8,
    "lines.linewidth": 1.2,
    "lines.markersize":5,
})

# ── parsing ─────────────────────────────────────────────────────────────────
def parse_obs():
    data = {t: [] for t in ALL_TRTS}
    for line in LUT.read_text().splitlines():
        if not line.strip() or line.startswith("*") or line.startswith("@"): continue
        p = line.split()
        trt = int(p[0])
        if trt in data:
            doy = int(p[1]) % 1000
            das = doy - PDATE_DOY[trt]
            if das < 0: das += 365
            cwid = float(p[2]) if p[2] != "-99" else None
            chtd = float(p[3]) if p[3] != "-99" else None
            cwad = float(p[7])
            data[trt].append((das, cwad, chtd, cwid))
    return data

def parse_sim():
    text = PLANTGRO.read_text().splitlines()
    runs = {}; current = None
    for line in text:
        m = re.match(r"\*RUN\s+\d+\s+:.*\sUFGA2201\s+(\d+)", line)
        if m:
            current = int(m.group(1)); runs[current] = {}; continue
        if current in ALL_TRTS and re.match(r"\s*\d{4}\s+\d{3}\s+", line):
            p = line.split()
            doy = int(p[1])
            das = doy - PDATE_DOY[current]
            if das < 0: das += 365
            runs[current][das] = {
                "cwad": float(p[12]),
                "chtd": float(p[31]),
                "cwid": float(p[32]),
            }
    return runs

def nrmse(obs_vals, sim_vals):
    n = len(obs_vals)
    rmse = math.sqrt(sum((s-o)**2 for s,o in zip(sim_vals,obs_vals))/n)
    return 100.0*rmse/(sum(obs_vals)/n)

def d_stat(obs_vals, sim_vals):
    """Willmott's index of agreement (0–1, 1 = perfect)."""
    o_mean = sum(obs_vals) / len(obs_vals)
    num  = sum((s - o)**2 for s, o in zip(sim_vals, obs_vals))
    den  = sum((abs(s - o_mean) + abs(o - o_mean))**2
               for s, o in zip(sim_vals, obs_vals))
    return 1.0 - num / den if den > 0 else 1.0

obs = parse_obs()
sim = parse_sim()

# align sim to obs dates
def get_sim_at_obs(trt, var="cwad"):
    sim_days = sorted(sim[trt])
    sv = []
    for das_o, *_ in obs[trt]:
        if das_o in sim[trt]:
            sv.append(sim[trt][das_o][var])
        else:
            elig = [d for d in sim_days if d <= das_o]
            sd = elig[-1] if elig else min(sim_days, key=lambda d: abs(d-das_o))
            sv.append(sim[trt][sd][var])
    return sv

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 1 — 4×3 time-course panels
# ═══════════════════════════════════════════════════════════════════════════
fig1, axes = plt.subplots(3, 4, figsize=(7.5, 5.5), sharey=False)
fig1.subplots_adjust(left=0.08, right=0.97, top=0.96, bottom=0.13,
                     hspace=0.45, wspace=0.35)

row_labels = ["Rex", "Muir", "Skyphos"]
for idx, trt in enumerate(ALL_TRTS):
    row, col = divmod(idx, 4)
    ax = axes[row][col]

    cul  = CULTIVAR[trt]
    temp = [24,26,28,30][col]
    color = CUL_COLOR[cul]

    # simulated line (full daily curve)
    sim_days_full = sorted(sim[trt])
    sim_vals_full = [sim[trt][d]["cwad"] for d in sim_days_full]
    ax.plot(sim_days_full, sim_vals_full, color=color, lw=1.4,
            label="Simulated", zorder=2)

    # observed points
    das_obs = [d for d, *_ in obs[trt]]
    cwad_obs = [v[0] for _, *v in obs[trt]]
    ax.scatter(das_obs, cwad_obs, color="black", marker=TEMP_MARKER[temp],
               s=22, zorder=4, label="Observed")

    # d-stat + NRMSE annotation
    sv = get_sim_at_obs(trt)
    nr = nrmse(cwad_obs, sv)
    ds = d_stat(cwad_obs, sv)
    ax.text(0.96, 0.05, f"d-stat={ds:.2f}\nNRMSE={nr:.0f}%", transform=ax.transAxes,
            ha="right", va="bottom", fontsize=7,
            bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.8))

    ax.set_title(TRT_NAMES[trt], fontsize=8.5, fontweight="bold", pad=3)
    ax.set_xlim(0, 32)
    ax.set_xticks([7, 14, 21, 28])
    ax.yaxis.set_major_locator(plt.MaxNLocator(4, integer=True))
    ax.tick_params(length=3)

    if col == 0:
        ax.set_ylabel("CWAD (kg/ha)", labelpad=3)
    if row == 2:
        ax.set_xlabel("DAS", labelpad=2)

    # subtle background colour per cultivar
    ax.set_facecolor({"Rex":"#eaf2fb","Muir":"#fdf3f1","Skyphos":"#edfaef"}[cul])
    for sp in ax.spines.values():
        sp.set_linewidth(0.6)

# shared legend (top right)
from matplotlib.lines import Line2D
legend_elements = [
    Line2D([0],[0], color="gray", lw=1.4, label="Simulated"),
    Line2D([0],[0], marker="o", color="w", markerfacecolor="black",
           markersize=5, label="Observed"),
]
fig1.legend(handles=legend_elements, loc="upper center", ncol=2,
            bbox_to_anchor=(0.5, 0.04), frameon=True, edgecolor="gray",
            handlelength=1.5)

# row labels on right
for r, lab in enumerate(row_labels):
    fig1.text(0.99, 0.83 - r*0.295, lab, va="center", ha="right",
              fontsize=9, fontweight="bold",
              color=list(CUL_COLOR.values())[r], rotation=90)


fig1.savefig(OUT_DIR / "Fig1_timecourse.png", dpi=300, bbox_inches="tight")
fig1.savefig(OUT_DIR / "Fig1_timecourse.pdf", bbox_inches="tight")
print("Saved Fig1_timecourse")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 2 — 1:1 scatter (one panel per cultivar + combined)
# ═══════════════════════════════════════════════════════════════════════════
fig2, axes2 = plt.subplots(1, 4, figsize=(7.5, 2.4))
fig2.subplots_adjust(left=0.08, right=0.97, top=0.95, bottom=0.22,
                     wspace=0.38)

cultivar_groups = {
    "Rex":     [1,2,3,4],
    "Muir":    [5,6,7,8],
    "Skyphos": [9,10,11,12],
    "All":     list(range(1,13)),
}

for ax, (cul_lab, trts) in zip(axes2, cultivar_groups.items()):
    all_obs, all_sim = [], []
    for trt in trts:
        sv = get_sim_at_obs(trt, "cwad")
        ov = [v[0] for _, *v in obs[trt]]
        temp = [24,26,28,30][[1,2,3,4,5,6,7,8,9,10,11,12].index(trt) % 4]
        color = CUL_COLOR.get(CULTIVAR[trt], "#555")
        ax.scatter(ov, sv, color=color if cul_lab=="All" else CUL_COLOR.get(cul_lab, "#555"),
                   marker=TEMP_MARKER[temp], s=20, zorder=3,
                   label=TEMP_LABEL[temp], edgecolors="none")
        all_obs.extend(ov); all_sim.extend(sv)

    # 1:1 line
    mx = max(max(all_obs), max(all_sim)) * 1.05
    ax.plot([0, mx], [0, mx], "k--", lw=0.9, label="1:1")

    # regression
    obs_arr = np.array(all_obs); sim_arr = np.array(all_sim)
    m_coef, b = np.polyfit(obs_arr, sim_arr, 1)
    x_fit = np.linspace(0, mx, 100)
    ax.plot(x_fit, m_coef*x_fit+b, color="gray", lw=1.0, ls="-", alpha=0.7)

    # stats
    nr = nrmse(all_obs, all_sim)
    r2 = np.corrcoef(obs_arr, sim_arr)[0,1]**2
    rmse_v = math.sqrt(sum((s-o)**2 for s,o in zip(all_sim,all_obs))/len(all_obs))
    ax.text(0.04, 0.96,
            f"R²={r2:.2f}\nRMSE={rmse_v:.0f} g m⁻²\nNRMSE={nr:.0f}%",
            transform=ax.transAxes, va="top", ha="left", fontsize=7,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="lightgray", lw=0.5))

    ax.set_xlim(0, mx); ax.set_ylim(0, mx)
    ax.set_aspect("equal")
    ax.set_title(cul_lab, fontsize=9, fontweight="bold",
                 color=CUL_COLOR.get(cul_lab, "black") if cul_lab!="All" else "black")
    ax.set_xlabel("Observed CWAD (kg/ha)", labelpad=3)
    if ax == axes2[0]:
        ax.set_ylabel("Simulated CWAD (kg/ha)", labelpad=3)
    ax.tick_params(length=3)
    for sp in ax.spines.values():
        sp.set_linewidth(0.6)

# shared legend for temps
temp_handles = [Line2D([0],[0], marker=TEMP_MARKER[t], color="w",
                        markerfacecolor="dimgray", markersize=5,
                        label=TEMP_LABEL[t]) for t in [24,26,28,30]]
temp_handles.append(Line2D([0],[0], ls="--", color="black", lw=0.9, label="1:1 line"))
fig2.legend(handles=temp_handles, loc="upper center", ncol=5,
            bbox_to_anchor=(0.5, 0.04), frameon=True, edgecolor="gray",
            handlelength=1.2, columnspacing=0.8)


fig2.savefig(OUT_DIR / "Fig2_scatter.png", dpi=300, bbox_inches="tight")
fig2.savefig(OUT_DIR / "Fig2_scatter.pdf", bbox_inches="tight")
print("Saved Fig2_scatter")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 3 — bar chart: final harvest obs vs sim per treatment
# ═══════════════════════════════════════════════════════════════════════════
fig3, ax3 = plt.subplots(figsize=(7.5, 3.2))
fig3.subplots_adjust(left=0.09, right=0.97, top=0.88, bottom=0.16)

x = np.arange(12)
w = 0.35
obs_final = [obs[t][-1][1] for t in ALL_TRTS]
sim_final = [sim[t][max(sim[t])]["cwad"] for t in ALL_TRTS]

bar_colors_obs = [CUL_COLOR[CULTIVAR[t]] for t in ALL_TRTS]
bars_obs = ax3.bar(x - w/2, obs_final, w, label="Observed",
                   color=bar_colors_obs, alpha=0.85, edgecolor="white", lw=0.5)
bars_sim = ax3.bar(x + w/2, sim_final, w, label="Simulated",
                   color=bar_colors_obs, alpha=0.45, edgecolor="white", lw=0.5,
                   hatch="///")

# error bars (NRMSE as % of obs)
for trt in ALL_TRTS:
    sv = get_sim_at_obs(trt)
    ov = [v[0] for _, *v in obs[trt]]
    nr = nrmse(ov, sv)

ax3.set_xticks(x)
ax3.set_xticklabels([TRT_NAMES[t] for t in ALL_TRTS], rotation=35, ha="right", fontsize=7.5)
ax3.set_ylabel("Final Harvest CWAD (g m$^{-2}$)")
ax3.set_ylim(0, 2300)
ax3.yaxis.set_major_locator(plt.MultipleLocator(500))
ax3.tick_params(length=3)

# group brackets
for x0, x1, lab, col in [(0,3,"Rex",CUL_COLOR["Rex"]),
                           (4,7,"Muir",CUL_COLOR["Muir"]),
                           (8,11,"Skyphos",CUL_COLOR["Skyphos"])]:
    ax3.annotate("", xy=(x1+0.4, 2200), xytext=(x0-0.4, 2200),
                 arrowprops=dict(arrowstyle="-", color=col, lw=1.5))
    ax3.text((x0+x1)/2, 2230, lab, ha="center", va="bottom",
             fontsize=8.5, color=col, fontweight="bold")

for sp in ["top","right"]:
    ax3.spines[sp].set_visible(False)
ax3.spines["left"].set_linewidth(0.6)
ax3.spines["bottom"].set_linewidth(0.6)

from matplotlib.patches import Patch
legend_elems = [Patch(fc=CUL_COLOR["Rex"], alpha=0.85, label="Observed (solid)"),
                Patch(fc=CUL_COLOR["Rex"], alpha=0.45, hatch="///", label="Simulated (hatched)")]
ax3.legend(handles=legend_elems, frameon=True, edgecolor="gray",
           loc="upper left", fontsize=8)


fig3.savefig(OUT_DIR / "Fig3_harvest_bar.png", dpi=300, bbox_inches="tight")
fig3.savefig(OUT_DIR / "Fig3_harvest_bar.pdf", bbox_inches="tight")
print("Saved Fig3_harvest_bar")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 4 — 1:1 scatter for Canopy Height (CHTD)
# ═══════════════════════════════════════════════════════════════════════════
fig4, axes4 = plt.subplots(1, 4, figsize=(7.5, 2.4))
fig4.subplots_adjust(left=0.08, right=0.97, top=0.95, bottom=0.22, wspace=0.38)

for ax, (cul_lab, trts) in zip(axes4, cultivar_groups.items()):
    all_obs, all_sim = [], []
    for trt in trts:
        sv_all = get_sim_at_obs(trt, "chtd")
        ov_all = [v[1] for _, *v in obs[trt]] # v is (cwad, chtd, cwid)
        valid = [(o, s) for o, s in zip(ov_all, sv_all) if o is not None]
        if not valid: continue
        ov, sv = zip(*valid)
        temp = [24,26,28,30][[1,2,3,4,5,6,7,8,9,10,11,12].index(trt) % 4]
        color = CUL_COLOR.get(CULTIVAR[trt], "#555")
        ax.scatter(ov, sv, color=color if cul_lab=="All" else CUL_COLOR.get(cul_lab, "#555"),
                   marker=TEMP_MARKER[temp], s=20, zorder=3, edgecolors="none")
        all_obs.extend(ov); all_sim.extend(sv)

    if not all_obs: continue
    mx = max(max(all_obs), max(all_sim)) * 1.05
    ax.plot([0, mx], [0, mx], "k--", lw=0.9)
    obs_arr, sim_arr = np.array(all_obs), np.array(all_sim)
    m_coef, b = np.polyfit(obs_arr, sim_arr, 1)
    x_fit = np.linspace(0, mx, 100)
    ax.plot(x_fit, m_coef*x_fit+b, color="gray", lw=1.0, ls="-", alpha=0.7)
    
    nr = nrmse(all_obs, all_sim)
    r2 = np.corrcoef(obs_arr, sim_arr)[0,1]**2
    rmse_v = math.sqrt(sum((s-o)**2 for s,o in zip(all_sim,all_obs))/len(all_obs))
    ax.text(0.04, 0.96, f"R²={r2:.2f}\nRMSE={rmse_v:.2f} m\nNRMSE={nr:.0f}%",
            transform=ax.transAxes, va="top", ha="left", fontsize=7,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="lightgray", lw=0.5))

    ax.set_xlim(0, mx); ax.set_ylim(0, mx); ax.set_aspect("equal")
    ax.set_title(cul_lab, fontsize=9, fontweight="bold", color=CUL_COLOR.get(cul_lab, "black") if cul_lab!="All" else "black")
    ax.set_xlabel("Observed CHTD (m)", labelpad=3)
    if ax == axes4[0]: ax.set_ylabel("Simulated CHTD (m)", labelpad=3)
    ax.tick_params(length=3)

fig4.legend(handles=temp_handles, loc="upper center", ncol=5, bbox_to_anchor=(0.5, 0.04), frameon=True, edgecolor="gray", handlelength=1.2, columnspacing=0.8)
fig4.savefig(OUT_DIR / "Fig4_height_scatter.png", dpi=300, bbox_inches="tight")
fig4.savefig(OUT_DIR / "Fig4_height_scatter.pdf", bbox_inches="tight")
print("Saved Fig4_height_scatter")

# ═══════════════════════════════════════════════════════════════════════════
# FIGURE 5 — 1:1 scatter for Canopy Width (CWID)
# ═══════════════════════════════════════════════════════════════════════════
fig5, axes5 = plt.subplots(1, 4, figsize=(7.5, 2.4))
fig5.subplots_adjust(left=0.08, right=0.97, top=0.95, bottom=0.22, wspace=0.38)

for ax, (cul_lab, trts) in zip(axes5, cultivar_groups.items()):
    all_obs, all_sim = [], []
    for trt in trts:
        sv_all = get_sim_at_obs(trt, "cwid")
        ov_all = [v[2] for _, *v in obs[trt]] # v is (cwad, chtd, cwid)
        valid = [(o, s) for o, s in zip(ov_all, sv_all) if o is not None]
        if not valid: continue
        ov, sv = zip(*valid)
        temp = [24,26,28,30][[1,2,3,4,5,6,7,8,9,10,11,12].index(trt) % 4]
        color = CUL_COLOR.get(CULTIVAR[trt], "#555")
        ax.scatter(ov, sv, color=color if cul_lab=="All" else CUL_COLOR.get(cul_lab, "#555"),
                   marker=TEMP_MARKER[temp], s=20, zorder=3, edgecolors="none")
        all_obs.extend(ov); all_sim.extend(sv)

    if not all_obs: continue
    mx = max(max(all_obs), max(all_sim)) * 1.05
    ax.plot([0, mx], [0, mx], "k--", lw=0.9)
    obs_arr, sim_arr = np.array(all_obs), np.array(all_sim)
    m_coef, b = np.polyfit(obs_arr, sim_arr, 1)
    x_fit = np.linspace(0, mx, 100)
    ax.plot(x_fit, m_coef*x_fit+b, color="gray", lw=1.0, ls="-", alpha=0.7)
    
    nr = nrmse(all_obs, all_sim)
    r2 = np.corrcoef(obs_arr, sim_arr)[0,1]**2
    rmse_v = math.sqrt(sum((s-o)**2 for s,o in zip(all_sim,all_obs))/len(all_obs))
    ax.text(0.04, 0.96, f"R²={r2:.2f}\nRMSE={rmse_v:.2f} m\nNRMSE={nr:.0f}%",
            transform=ax.transAxes, va="top", ha="left", fontsize=7,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="lightgray", lw=0.5))

    ax.set_xlim(0, mx); ax.set_ylim(0, mx); ax.set_aspect("equal")
    ax.set_title(cul_lab, fontsize=9, fontweight="bold", color=CUL_COLOR.get(cul_lab, "black") if cul_lab!="All" else "black")
    ax.set_xlabel("Observed CWID (m)", labelpad=3)
    if ax == axes5[0]: ax.set_ylabel("Simulated CWID (m)", labelpad=3)
    ax.tick_params(length=3)

fig5.legend(handles=temp_handles, loc="upper center", ncol=5, bbox_to_anchor=(0.5, 0.04), frameon=True, edgecolor="gray", handlelength=1.2, columnspacing=0.8)
fig5.savefig(OUT_DIR / "Fig5_width_scatter.png", dpi=300, bbox_inches="tight")
fig5.savefig(OUT_DIR / "Fig5_width_scatter.pdf", bbox_inches="tight")
print("Saved Fig5_width_scatter")

print(f"\nAll figures saved to: {OUT_DIR}")
