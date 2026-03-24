"""csv_to_lut.py
Generates WAGA9101.LUT for one treatment (TRNO=1, ActDose).

Two source CSVs are merged by DOY:

  exp6705_DSSAT_updated.csv       — plant measurements
    CWAD, RWAD        : kg/ha  (scale 1.0)
    LN%D, RN%D        : %      (scale 1.0)
    SHPPD, RTPPD      : %P     (scale 1.0)
    SHKPD, RTKPD      : %K     (scale 1.0)
    NUPC, PUPC, KUPC  : kg/ha  (scale 1.0)

  exp6705_nutrient_balance.csv    — solution measurements
    NO3CL = (N_remain_sol_mmol + N_loss_minus_uptake_mmol) / 168 * 14    mg/L
    PCCL  = (P_remain_sol_mmol + P_loss_minus_uptake_mmol) / 168 * 30.974 mg/L
    KCCL  = (K_remain_sol_mmol + K_loss_minus_uptake_mmol) / 168 * 39.098 mg/L

    loss_col = drainage-only (N_cum_loss_sys - N_cum_uptake).
    Effective model-comparable concentration: what the model would show
    if plant uptake matched observed (model has no drainage).
"""

import csv
import os

BASE     = os.path.dirname(os.path.abspath(__file__))
CSV1_PATH = os.path.join(BASE, "Papers for data", "exp6705_DSSAT_updated.csv")
CSV2_PATH = os.path.join(BASE, "Papers for data", "exp6705_nutrient_balance.csv")
LUT_PATH  = r"C:\DSSAT48\Lettuce\WAGA9101.LUT"

MISSING  = -99
SOLVOL_L = 168.0  # system volume (L), verified from N_remain / N_conc

# (lut_var, field_width, decimals)
COLS = [
    ("CWAD",  8, 1),
    ("RWAD",  8, 2),
    ("LN%D",  7, 3),
    ("RN%D",  7, 3),
    ("SHPPD", 7, 3),
    ("RTPPD", 7, 3),
    ("SHKPD", 7, 3),
    ("RTKPD", 7, 3),
    ("NUPC",  8, 2),
    ("PUPC",  8, 2),
    ("KUPC",  9, 2),
    ("NO3CL", 8, 2),
    ("PCCL",  7, 3),
    ("KCCL",  8, 2),
]

# CSV1: plant measurement columns → (csv_column_name, scale)
PLANT_MAP = {
    "CWAD":  ("CWAD_kg_ha",   1.0),
    "RWAD":  ("RWAD_kg_ha",   1.0),
    "LN%D":  ("LN%D_pct",     1.0),
    "RN%D":  ("RN%D_pct",     1.0),
    "SHPPD": ("SHPPD_pct",    1.0),
    "RTPPD": ("RTPPD_pct",    1.0),
    "SHKPD": ("SHKPD_pct",    1.0),
    "RTKPD": ("RTKPD_pct",    1.0),
    "NUPC":  ("NUPC_kg_N_ha", 1.0),
    "PUPC":  ("PUPC_kg_P_ha", 1.0),
    "KUPC":  ("KUPC_kg_K_ha", 1.0),
}

# CSV2: solution concentration columns
# (lut_var, remain_col, drainage_only_col, atomic_weight_g_mol, width, dec)
CONC_DEF = [
    ("NO3CL", "N_remain_sol_mmol", "N_loss_minus_uptake_mmol", 14.0,    8, 2),
    ("PCCL",  "P_remain_sol_mmol", "P_loss_minus_uptake_mmol", 30.974,  7, 3),
    ("KCCL",  "K_remain_sol_mmol", "K_loss_minus_uptake_mmol", 39.098,  8, 2),
]


def fv(raw, scale, width, dec):
    """Format a numeric value; empty / -99 / nan → MISSING placeholder."""
    s = str(raw).strip()
    if s == "" or s.lower() in ("-99", "nan", "none"):
        return f"{MISSING:{width}d}"
    try:
        return f"{float(s) * scale:{width}.{dec}f}"
    except ValueError:
        return f"{MISSING:{width}d}"


def fmt_missing(width, dec):
    return f"{MISSING:{width}d}"


def calc_eff_conc(row, remain_col, drain_col, atomic_wt, width, dec):
    """Effective model-comparable concentration (mg/L).
    = (remain_mmol + drainage_mmol) / SOLVOL_L * atomic_wt
    """
    s_rem  = row.get(remain_col, "").strip()
    s_loss = row.get(drain_col,  "").strip()
    if not s_rem:
        return fmt_missing(width, dec)
    try:
        remain = float(s_rem)
        drain  = float(s_loss) if s_loss else 0.0
        mg_L   = (remain + drain) / SOLVOL_L * atomic_wt
        return f"{mg_L:{width}.{dec}f}"
    except ValueError:
        return fmt_missing(width, dec)


def build_header():
    hdr = f"{'@TRNO':>6}{'DATE':>9}"
    for lut_var, w, _ in COLS:
        hdr += f"{lut_var:>{w}}"
    return hdr


def read_csv_by_doy(path):
    """Return {doy: row_dict} from a CSV file."""
    result = {}
    with open(path, newline="") as fh:
        for row in csv.DictReader(fh):
            doy = row["DOY"].strip()
            if doy:
                result[int(doy)] = row
    return result


def build_merged_rows():
    """Merge both CSVs by DOY into single TRNO=1 rows."""
    plant_by_doy = read_csv_by_doy(CSV1_PATH)
    conc_by_doy  = read_csv_by_doy(CSV2_PATH)

    # All DOYs present in either file
    all_doys = sorted(set(plant_by_doy) | set(conc_by_doy))

    conc_lookup = {lv: (rc, dc, aw, w, d) for lv, rc, dc, aw, w, d in CONC_DEF}

    rows = []
    for doy in all_doys:
        p_row = plant_by_doy.get(doy, {})
        c_row = conc_by_doy.get(doy, {})

        # Need at least one non-empty value to emit this day
        has_plant = any(p_row.get(col, "").strip() for col, _ in PLANT_MAP.values())
        has_conc  = any(c_row.get(rc, "").strip()
                        for _, rc, _, _, _, _ in CONC_DEF)
        if not has_plant and not has_conc:
            continue

        year = (p_row or c_row).get("YEAR", "").strip()
        date = f"{year}{doy:03d}"
        line = f"{1:6d}{date:>9}"

        for lut_var, w, d in COLS:
            if lut_var in PLANT_MAP:
                csv_col, scale = PLANT_MAP[lut_var]
                line += fv(p_row.get(csv_col, ""), scale, w, d)
            elif lut_var in conc_lookup:
                rc, dc, aw, w2, d2 = conc_lookup[lut_var]
                line += calc_eff_conc(c_row, rc, dc, aw, w2, d2)
            else:
                line += fmt_missing(w, d)

        rows.append(line)
    return rows


def main():
    rows = build_merged_rows()

    lines = [
        "*EXP. DATA (T): Heinen (1999) Exp 6705 NFT Lettuce - Wageningen",
        "",
        build_header(),
    ]
    lines.extend(rows)
    lines.append("")

    with open(LUT_PATH, "w", newline="\n") as fh:
        fh.write("\n".join(lines))

    print(f"Wrote {len(rows)} observations -> {LUT_PATH}")
    print(f"Columns: {', '.join(c[0] for c in COLS)}")
    print()
    with open(LUT_PATH) as fh:
        for line in fh:
            print(line, end="")


if __name__ == "__main__":
    main()
