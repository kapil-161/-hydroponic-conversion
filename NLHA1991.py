"""
Script to create DSSAT Experiment File for Heinen (1994) NFT Lettuce Experiment 6705
Wageningen, The Netherlands — DLO-Instituut voor Agrobiologisch en Bodemvruchtbaarheidsonderzoek

Reference:
  Heinen, M. (1994). Growth and nutrient uptake by lettuce grown on NFT.
  Rapport 1, DLO-Instituut voor Agrobiologisch en Bodemvruchtbaarheidsonderzoek,
  Haren, The Netherlands.

Generates DSSAT experiment (.LUX) and weather (.WTH) files for NFT hydroponic
lettuce simulation matching Experiment 6705, Project 402.
Cultivar: Lactuca sativa cv Sitonia (butterhead lettuce)
Growth period: 7 weeks (49 days), June 3 – July 22, 1991
"""
import os
import sys
import math


def create_weather_file(experiment_code, planting_date, harvest_date):
    """Create a greenhouse weather file (.WTH) for Experiment 6705.

    Climate from Heinen (1994):
      - Day temperature set point: 15 °C (ventilation at 17 °C)
      - Night temperature set point: 10 °C
      - Weeks 1–4 actual: ~15 °C
      - Weeks 5–7 actual: 20–25 °C (unusually warm summer)
      - Natural sunlight only (no supplemental lighting)
      - Season: summer (June–July 1991), Wageningen, Netherlands
      - Latitude 51.97°N, Longitude 5.67°E

    Because weeks 5–7 experienced elevated temperatures (20–25 °C),
    we use two temperature regimes:
      Weeks 1–4 (days 0–28): TMAX=17, TMIN=10
      Weeks 5–7 (days 29–49): TMAX=25, TMIN=18
    SRAD estimated from Netherlands summer daily global radiation
    inside greenhouse (~50% transmission): 8.0–12.0 MJ/m²/d outside,
    ~4.0–6.0 MJ/m²/d inside greenhouse. Heinen reports cumulative
    radiation of ~70 kJ·cm⁻² over 49 days ≈ 14.3 MJ/m²/d outside.
    At ~50% greenhouse transmission → ~7.1 MJ/m²/d inside.
    We use 7.0 MJ/m²/d as representative.
    """
    # Wageningen, The Netherlands coordinates
    lat = 51.97
    lon = 5.67
    elev = 12

    # Two-phase temperature regime from Heinen (1994)
    # Phase 1 (weeks 1–4): ~15 °C average
    tmax_phase1 = 17.0
    tmin_phase1 = 10.0
    # Phase 2 (weeks 5–7): 20–25 °C actual
    tmax_phase2 = 25.0
    tmin_phase2 = 18.0

    tav = 16.3    # weighted average: (28*13.5 + 21*21.5)/49
    amp = 4.0     # approximate seasonal amplitude

    srad = 7.0    # MJ/m²/d inside greenhouse (see docstring)
    rain = 0.0    # greenhouse, no rain on crop
    dewp_phase1 = 10.0   # estimated dewpoint for greenhouse humidity at ~15 °C
    dewp_phase2 = 16.0   # estimated dewpoint for greenhouse humidity at ~22 °C

    # Generate daily records
    year = 1900 + int(planting_date[:2])
    start_doy = int(planting_date[2:]) - 7  # start 7 days before planting (ensures ICDAT is within weather file)
    end_doy = int(harvest_date[2:]) + 5    # buffer

    # Phase transition at day 28 after planting (start of week 5)
    phase_transition_doy = start_doy + 28

    content = "$WEATHER DATA : Greenhouse, Wageningen University, The Netherlands\n"
    content += "\n"
    content += "@ INSI      LAT     LONG  ELEV   TAV   AMP REFHT WNDHT\n"
    content += f"  WAGA  {lat:6.3f}    {lon:5.3f}    {elev:2d}  {tav:4.1f}   {amp:3.1f}   2.0 -99.0\n"
    content += "@  DATE  SRAD  TMAX  TMIN  RAIN  DEWP  WIND\n"

    for doy in range(start_doy, end_doy + 1):
        if doy < phase_transition_doy:
            tmax = tmax_phase1
            tmin = tmin_phase1
            dewp = dewp_phase1
        else:
            tmax = tmax_phase2
            tmin = tmin_phase2
            dewp = dewp_phase2
        content += f"{year}{doy:03d}   {srad:3.1f}  {tmax:4.1f}  {tmin:4.1f}   {rain:3.1f}  {dewp:4.1f}   0.0\n"

    output_path = os.path.join('C:\\DSSAT48\\Weather', f'{experiment_code}.WTH')
    # For cross-platform compatibility, use local output if Windows path fails
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
    except (OSError, FileNotFoundError):
        output_path = os.path.join(os.getcwd(), f'{experiment_code}.WTH')
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    days = end_doy - start_doy + 1
    print(f"Created weather file: {output_path} ({days} days)")
    return output_path


def create_hydroponic_lettuce_experiment(
    experiment_code="WAGA9101",
    planting_date="91154",       # June 3, 1991 (DOY 154)
    harvest_date="91203",        # July 22, 1991 (DOY 203, 49 days)
    plant_density=20.0,          # NOT reported in Heinen (1994); estimated 20 plants/m² (typical Netherlands NFT butterhead commercial density)
    total_plants=144,            # 144 plants total at start
    solution_volume_liters=168.0,# measured initial volume (168.0 L, cv 1.3%)
    transplant_age=21,           # 3 weeks after sowing per Heinen (1994)
    transplant_wt=12,            # week 0: shoot dry 0.007g + root dry 0.005g = 0.012g = 12 mg
    planting_depth=2,            # foam blocks, shallow placement
    seedling_leaf=4,             # estimated for 3-week-old butterhead seedling
):
    """Create a DSSAT experiment file for Heinen (1994) Experiment 6705.

    Single treatment: Lactuca sativa cv Sitonia on NFT with manual nutrient
    dosing and automatic pH + water level control.

    Key parameters from Heinen (1994):
      - Cultivar: Sitonia (butterhead lettuce)
      - Growth period: 49 days (7 weeks)
      - Initial plants: 144
      - System volume: 168 L (measured)
      - pH control: automatic, set point 6.0, range 5.5–6.5
      - pH acid: 0.1 M HNO₃; pH base: 0.1 M KOH
      - Water level: automatic (constant level in supply tank)
      - Nutrient dosing: manual daily at 16:00h based on NO₃ analysis
      - Set point concentrations: half of experiment 5132
      - Average EC: 0.84 mS/cm (cv 8.9%)
    """

    # Cultivar: single cultivar experiment
    cultivars = [
        {"code": "LU0004", "name": "SITONIA"},
    ]

    # Nutrient solution set point concentrations from Heinen (1994) Table 2.1
    # Macronutrients in mmol/L, converted to mg/L for DSSAT
    # NO3: 5.000 mmol/L × 14.007 g/mol (as N) = 70.04 mg-N/L
    # P:   0.333 mmol/L × 30.974 g/mol = 10.31 mg-P/L
    # K:   2.624 mmol/L × 39.098 g/mol = 102.59 mg-K/L
    # Ca:  1.172 mmol/L × 40.078 g/mol = 46.97 mg-Ca/L
    # Mg:  0.392 mmol/L × 24.305 g/mol = 9.53 mg-Mg/L
    # SO4: 0.168 mmol/L × 32.065 g/mol (as S) = 5.39 mg-S/L
    #
    # NH4 not specified as separate set point; pH control uses 0.1M HNO3/KOH
    # so NH4 is assumed negligible (~0 mg/L)
    ec_treatments = [
        {
            "ec": 0.84,      # actual average EC (mS/cm), cv 8.9%
            "no3": 70.0,     # NO3-N mg/L (from 5.000 mmol/L NO3)
            "nh4": 0.0,      # NH4-N mg/L (not supplied separately)
            "p": 10.3,       # P mg/L (from 0.333 mmol/L)
            "k": 102.6,      # K mg/L (from 2.624 mmol/L)
        },
    ]

    # pH control parameters from Heinen (1994)
    ph = 6.0              # set point (actual average 6.27, cv 3.9%)
    do2 = 8.0             # dissolved O2 estimated for NFT with flowing film
    solution_temp = 15.0  # weeks 1–4 greenhouse temp; solution assumed near air temp

    # Solution depth: volume_L / area_m² converted to mm
    # area_m² = total_plants / plant_density = 144 / 20 = 7.2 m²
    # SOLVOL (mm) = 168 L / 7.2 m² = 168,000 cm³ / 72,000 cm² = 2.333 cm = 23.3 mm
    growing_area_m2 = total_plants / plant_density          # 7.2 m²
    solution_depth = (solution_volume_liters * 1000.0       # L → cm³
                      / (growing_area_m2 * 10000.0)        # m² → cm²; result in cm
                      * 10.0)                              # cm → mm
    solution_depth = round(solution_depth, 1)              # 23.3 mm

    # NFT channel geometry: NOT reported in Heinen (1994)
    # Estimated: typical Dutch greenhouse NFT butterhead system
    # CHLEN=1000 cm (10 m channels), CHSPC=25 cm (spacing for butterhead)
    channel_length = 1000.0   # cm — ESTIMATED, not reported
    channel_spacing = 25.0    # cm — ESTIMATED, not reported

    # Control flags
    auto_ph = 'Y'     # automatic acid/base dosing (0.1M HNO3 / 0.1M KOH)
    auto_vol = 'Y'    # automatic water level control
    auto_conc = 'Y'   # Heinen manually dosed daily to maintain ~5 mmol/L NO3 — effectively AUTO_CONC=Y
    auto_o2 = 'N'     # no O2 supplementation (NFT with flowing film provides passive aeration)

    # Row spacing: NOT reported — use -99
    row_spacing = -99

    # Calculate initial conditions date (1 day before planting)
    icdate = str(int(planting_date) - 1)

    # Single treatment for experiment 6705
    treatments = [
        {"num": 1, "name": "SITONIA EC0.84", "cu": 1, "hs": 1},
    ]

    # --- Build experiment file content ---
    content = f"""*EXP.DETAILS: {experiment_code}LU LETTUCE HYDROPONIC NFT - HEINEN 1994 EXP 6705

*GENERAL
@PEOPLE
M. Heinen
@ADDRESS
DLO-Instituut voor Agrobiologisch en Bodemvruchtbaarheidsonderzoek, Haren, NL
@SITE
Greenhouse, Wageningen University, The Netherlands

*TREATMENTS                        -------------FACTOR LEVELS------------
@N R O C TNAME.................... CU FL SA IC MP MI MF MR MC MT ME MH SM HS HC
"""
    for t in treatments:
        content += f"{t['num']:3d}1 0 0 {t['name']:<25s}{t['cu']:3d}{1:3d}{0:3d}{1:3d}{1:3d}{1:3d}{0:3d}{0:3d}{0:3d}{0:3d}{0:3d}{1:3d}{1:3d}{t['hs']:3d}{1:3d}\n"

    content += f"""
*CULTIVARS
@C CR INGENO CNAME
"""
    for ci, cv in enumerate(cultivars, 1):
        content += f" {ci} LU {cv['code']} {cv['name']}\n"

    content += f"""
*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 WAGA0001 {experiment_code}   -99   -99   -99   -99   -99   -99 -99    -99  -99        Hydroponic_NFT_Wageningen
@L ...........XCRD ...........YCRD .....ELEV .............AREA .SLEN .FLWR .SLAS FLHST FHDUR
 1             -99             -99       -99               -99   -99   -99   -99   -99   -99

*INITIAL CONDITIONS
@C   PCR ICDAT  ICRT  ICND  ICRN  ICRE  ICWD ICRES ICREN ICREP ICRIP ICRID ICNAME
 1    LU {icdate}   -99   -99     1     1   -99   -99   -99   -99   -99   -99 Hydroponic - No Soil

*PLANTING DETAILS
@P PDATE EDATE  PPOP  PPOE  PLME  PLDS  PLRS  PLRD  PLDP  PLWT  PAGE  PENV  PLPH  SPRL                        PLNAME
 1 {planting_date}   -99{plant_density:6.1f}{plant_density:6.1f}     T     R   {row_spacing:3d}     0     {planting_depth}    {transplant_wt}    {transplant_age}    15   -99     {seedling_leaf}                        NFT Transplants 3wk

*IRRIGATION (AUTOMATIC)
@I  IEFF  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1   -99   -99   -99   -99   -99   -99   -99 Not used in hydroponics

*FERTILIZERS (AUTOMATIC)
@F  FMCD  FAMP  FAMK  FAMD  FAMLC FMOC  FNOP
 1   -99   -99   -99   -99   -99   -99   -99 Manual daily dosage based on NO3 analysis

*RESIDUES
@R  RDATE  RCOD  RAMT  RESN  RESP  RESK  RINP  RDEP  RMET RENAME
 1    -99   -99   -99   -99   -99   -99   -99   -99   -99 Not used in hydroponics

*CHEMICAL APPLICATIONS
@C  CDATE CHCOD CHAMT  CHME CHDEP   CHT..CHNAME
 1    -99   -99   -99   -99   -99   -99 Not used in hydroponics

*TILLAGE
@T  TDATE TIMPL  TDEP TNAME
 1    -99   -99   -99 Not used in hydroponics

*ENVIRONMENT MODIFICATIONS
@E  ODATE EDAY  ERAD  EMAX  EMIN  ERAIN ECO2  EDEW  EWIND ENVNAME
 1 {planting_date}   -99   -99   -99   -99   -99   -99   -99   -99 Natural greenhouse conditions

*HARVEST DETAILS
@H HDATE  HSTG  HCOM HSIZE   HPC  HBPC HNAME
 1 {harvest_date} GS000     C     A   -99   -99 Final harvest week 7

*HYDROPONIC SOLUTION
@  L    SOLVOL(mm)    EC        PH       DO2      TEMP   NO3_CONC  NH4_CONC    P_CONC    K_CONC    CHLEN    CHSPC
"""
    for ei, ec in enumerate(ec_treatments, 1):
        content += (
            f"   {ei}   {solution_depth:7.1f}      {ec['ec']:5.2f}    {ph:5.2f}    {do2:5.1f}   {solution_temp:6.1f}"
            f"     {ec['no3']:7.1f}     {ec['nh4']:7.1f}    {ec['p']:7.1f}    {ec['k']:7.1f}"
            f"  {channel_length:7.1f}   {channel_spacing:6.1f}\n"
        )

    content += f"""
! NOTE: System volume = {solution_volume_liters} L (measured, cv=1.3%)
! NOTE: Final system volume = 176.4 L (5% increase due to root mat water retention)
! NOTE: Plant density, gully dimensions, flow rate, greenhouse area NOT reported
! NOTE: PPOP set to -99 because planting density (plants/m2) is not reported;
!       only total plant count ({total_plants} plants) was stated.

*HYDROPONIC CONTROL
@  L  AUTO_PH  AUTO_VOL  AUTO_CONC  AUTO_O2
   1     {auto_ph}        {auto_vol}         {auto_conc}          {auto_o2}
! pH acid: 0.1 M HNO3; pH base: 0.1 M KOH
! Water level: automatic constant level in supply tank
! Nutrient dosing: MANUAL daily at 16:00h based on measured NO3 and uptake ratios

*SIMULATION CONTROLS
@N GENERAL     NYERS NREPS START SDATE RSEED SNAME.................... SMODEL
 1 GE              1     1     S {planting_date}  2150 Heinen1994 Exp6705 NFT
@N OPTIONS     WATER NITRO SYMBI PHOSP POTAS DISES  CHEM  TILL   CO2
 1 OP              Y     Y     N     Y     Y     N     N     N     M
@N METHODS     WTHER INCON LIGHT EVAPO INFIL PHOTO HYDRO NSWIT MESOM MESEV MESOL
 1 ME              M     M     E     R     S     L     Y     1     G     S     2
@N MANAGEMENT  PLANT IRRIG FERTI RESID HARVS
 1 MA              R     N     N     N     R
@N OUTPUTS     FNAME OVVEW SUMRY FROPT GROUT CAOUT WAOUT NIOUT MIOUT DIOUT VBOSE CHOUT OPOUT FMOPT
 1 OU              N     Y     Y     1     Y     Y     Y     Y     N     N     Y     N     N     A

@  AUTOMATIC MANAGEMENT
@N PLANTING    PFRST PLAST PH2OL PH2OU PH2OD PSTMX PSTMN
 1 PL          {planting_date} {planting_date}    40   100    30    40    10
@N IRRIGATION  IMDEP ITHRL ITHRU IROFF IMETH IRAMT IREFF
 1 IR             30    50   100 GS000 IR001    10   -99
@N NITROGEN    NMDEP NMTHR NAMNT NCODE NAOFF
 1 NI             30    50    25 FE001 GS000
@N RESIDUES    RIPCN RTIME RIDEP
 1 RE            100     1    20
@N HARVEST     HFRST HLAST HPCNP HPCNR
 1 HA              0 91365   100     0

"""

    output_path = os.path.join('C:\\DSSAT48\\Lettuce', f'{experiment_code}.LUX')
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
    except (OSError, FileNotFoundError):
        output_path = os.path.join(os.getcwd(), f'{experiment_code}.LUX')
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Created hydroponic lettuce experiment: {output_path}")
    print(f"\nExperiment: {experiment_code} — Heinen (1994) Experiment 6705")
    print(f"Treatments: {len(treatments)}")
    for t in treatments:
        ec_val = ec_treatments[t['hs'] - 1]['ec']
        cv_name = cultivars[t['cu'] - 1]['name']
        print(f"  Trt {t['num']}: {cv_name} at EC {ec_val:.2f} mS/cm")
    print(f"\nPlanting: {planting_date} (June 3, 1991)")
    print(f"Harvest:  {harvest_date} (July 22, 1991, 49 DAT)")
    print(f"Total Plants: {total_plants}")
    print(f"Plant Density: {plant_density} plants/m² (ESTIMATED — not reported in Heinen 1994)")
    print(f"\nNutrient Solution Set Points (Heinen 1994, Table 2.1):")
    print(f"  NO3  = 5.000 mmol/L  ({ec_treatments[0]['no3']:.1f} mg-N/L)")
    print(f"  P    = 0.333 mmol/L  ({ec_treatments[0]['p']:.1f} mg-P/L)")
    print(f"  K    = 2.624 mmol/L  ({ec_treatments[0]['k']:.1f} mg-K/L)")
    print(f"  Ca   = 1.172 mmol/L")
    print(f"  Mg   = 0.392 mmol/L")
    print(f"  SO4  = 0.168 mmol/L")
    print(f"\nSolution: pH set point={ph}, actual avg=6.27 (cv 3.9%)")
    print(f"  EC actual avg={ec_treatments[0]['ec']:.2f} mS/cm (cv 8.9%)")
    print(f"  System volume={solution_volume_liters} L (measured)")
    print(f"Control: AUTO_PH={auto_ph} AUTO_VOL={auto_vol} AUTO_CONC={auto_conc}")
    print(f"\nKnown complications:")
    print(f"  - Electrical failure day 23: lost solution, replaced 32.5 L")
    print(f"  - Electrical failure day 34: lost solution, replaced 28.5 L")
    print(f"  - Missing transpiration data days 34–35")
    print(f"  - ~15 L residual demin. water at start (actual vol 168 L, not 150 L)")
    print(f"\nValidation targets (Week 7 per plant):")
    print(f"  Shoot fresh mass:  332.58 g")
    print(f"  Shoot dry mass:     18.300 g")
    print(f"  Root fresh mass:    39.728 g")
    print(f"  Root dry mass:       2.467 g")
    print(f"  Shoot dry matter:    5.50%")
    print(f"  Shoot/root dry:      7.42")
    print(f"  Cumul. N uptake:    54.224 mmol/plant")
    print(f"  Cumul. P uptake:     5.323 mmol/plant")
    print(f"  Cumul. K uptake:    44.140 mmol/plant")
    print(f"\nTo run: dscsm048.exe A {experiment_code}.LUX")

    return output_path


if __name__ == '__main__':
    # Heinen (1994) Experiment 6705
    # Growth period: June 3 – July 22, 1991
    # June 3, 1991 = DOY 154; July 22, 1991 = DOY 203
    create_weather_file("WAGA9101", "91154", "91203")
    create_hydroponic_lettuce_experiment(
        experiment_code="WAGA9101",
        planting_date="91154",    # June 3, 1991 (DOY 154)
        harvest_date="91203",     # July 22, 1991 (DOY 203, 49 days)
    )