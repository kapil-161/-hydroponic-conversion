"""
Script to create a Hydroponic Lettuce experiment file with *HYDROPONIC SOLUTION section
Generates DSSAT experiment (.LUX) files for NFT hydroponic lettuce simulations
Supports multiple treatments with factorial cultivar x EC combinations
"""
import os
import sys
import math


def create_weather_file(experiment_code, planting_date, harvest_date):
    """Create a controlled-environment weather file (.WTH).

    Constant daily conditions for indoor growth chamber:
      TMAX=24, TMIN=19, SRAD=6.5 MJ/m²/d (PPF 250 µmol/m²/s, 16.5h),
      RAIN=0, DEWP=16 (RH~60% at 24/19 C)
    """
    # Gainesville, FL coordinates
    lat = 29.65
    lon = -82.32
    elev = 24
    tav = 21.5    # average of 24 and 19
    amp = 2.5     # half of (24-19)

    # Controlled environment constants
    srad = 6.5    # MJ/m²/d from PPF=250 µmol/m²/s over 16.5h photoperiod
    tmax = 24.0   # day temperature
    tmin = 19.0   # night temperature
    rain = 0.0
    dewp = 16.0   # dewpoint for ~60% RH at these temperatures

    # Generate daily records covering planting through harvest (+5 day buffer)
    # Use 7-digit YYYYDDD format matching UFGB weather files used by lettuce
    year = 2000 + int(planting_date[:2])
    start_doy = int(planting_date[2:]) - 1
    end_doy = int(harvest_date[2:]) + 5

    content = f"$WEATHER DATA : Controlled Environment Growth Chamber, UF Gainesville FL\n"
    content += f"\n"
    content += f"@ INSI      LAT     LONG  ELEV   TAV   AMP REFHT WNDHT\n"
    content += f"  VKGA   {lat:5.3f}   {lon:6.3f}    {elev:2d}  {tav:4.1f}   {amp:3.1f}   2.0 -99.0\n"
    content += f"@  DATE  SRAD  TMAX  TMIN  RAIN  DEWP  WIND\n"

    for doy in range(start_doy, end_doy + 1):
        content += f"{year}{doy:03d}   {srad:3.1f}  {tmax:4.1f}  {tmin:4.1f}   {rain:3.1f}  {dewp:4.1f}   0.0\n"

    output_path = rf'C:\DSSAT48\Weather\{experiment_code}.WTH'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    days = end_doy - start_doy + 1
    print(f"Created weather file: {output_path} ({days} days)")
    return output_path


def create_hydroponic_lettuce_experiment(
    experiment_code="VKGA2201",
    planting_date="22213",      # Aug 1, 2022 (Period 1)
    harvest_date="22248",       # 35 DAP
    plant_density=12.3,         # plants per m²
    solution_depth=20.0,        # solution depth in mm (1 mm = 1 L/m²)
    channel_length=183.0,       # NFT channel length (cm)
    channel_spacing=15.0,       # NFT channel spacing (cm)
    transplant_wt=24,           # transplant weight (mg/plant)
    transplant_age=14,          # transplant age (days)
    planting_depth=5,           # planting depth (cm)
    seedling_leaf=3,            # number of leaves at transplant
):
    """Create a multi-treatment hydroponic lettuce experiment file.

    4 treatments matching actual experiment design:
      Trt 1: REX     at EC 1.2
      Trt 2: MUIR    at EC 1.2
      Trt 3: SKYPHOS at EC 1.2
      Trt 4: REX     at EC 1.6
    Based on Experiment 1 (Chapter 2) - NFT zero-discharge, 35-day cycle.
    """

    # Cultivar definitions
    cultivars = [
        {"code": "LU0001", "name": "REX"},
        {"code": "LU0002", "name": "MUIR"},
        {"code": "LU0003", "name": "SKYPHOS"},
    ]

    # EC treatment definitions with measured initial nutrient concentrations
    ec_treatments = [
        {
            "ec": 1.2,
            "no3": 110.0,   # NO3-N mg/L
            "nh4": 6.9,     # NH4-N mg/L
            "p": 30.0,      # P mg/L
            "k": 190.0,     # K mg/L
        },
        {
            "ec": 1.6,
            "no3": 130.0,
            "nh4": 8.7,
            "p": 51.0,
            "k": 260.0,
        },
    ]

    # Common solution parameters
    ph = 5.9
    do2 = 6.0
    solution_temp = 22.7

    # Control flags
    auto_ph = 'Y'    # automatic acid dosing (1M HNO3)
    auto_vol = 'Y'   # float switch + peristaltic pump (deionized water)
    auto_conc = 'Y'  # automatic EC dosing (1:50 concentrate)

    # Calculate initial conditions date (1 day before planting)
    icdate = str(int(planting_date) - 1)

    # Calculate row spacing as square equivalent of plant density
    row_spacing = int(round(math.sqrt(1.0 / plant_density) * 100.0))

    # Build treatment list: 4 treatments matching actual experiment
    # Low EC (1.2): Rex, Muir, Skyphos | High EC (1.6): Rex only
    # CU=cultivar index (1-3), HS=hydroponic solution index (1-2), HC=1 for all
    treatments = [
        {"num": 1, "name": "REX EC1.2",     "cu": 1, "hs": 1},  # Rex at low EC
        {"num": 2, "name": "MUIR EC1.2",    "cu": 2, "hs": 1},  # Muir at low EC
        {"num": 3, "name": "SKYPHOS EC1.2", "cu": 3, "hs": 1},  # Skyphos at low EC
        {"num": 4, "name": "REX EC1.6",     "cu": 1, "hs": 2},  # Rex at high EC
    ]

    # --- Build experiment file content ---
    content = f"""*EXP.DETAILS: {experiment_code}LU LETTUCE HYDROPONIC NFT - 3CV LOW EC + REX HIGH EC

*GENERAL
@PEOPLE
Kapil Bhattarai
@ADDRESS
University of Florida, Gainesville, FL
@SITE
Controlled Environment Growth Chamber

*TREATMENTS                        -------------FACTOR LEVELS------------
@N R O C TNAME.................... CU FL SA IC MP MI MF MR MC MT ME MH SM HS HC
"""
    for t in treatments:
        # Format 55: I3,I1,2(1X,I1),1X,A25,15I3
        # TNAME=25 chars, each factor level=3 chars (I3)
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
 1 VKGA0001 {experiment_code}   -99   -99   -99   -99   -99   -99 -99    -99  -99        Hydroponic_NFT
@L ...........XCRD ...........YCRD .....ELEV .............AREA .SLEN .FLWR .SLAS FLHST FHDUR
 1             -99             -99       -99                50   -99   -99   -99   -99   -99

*INITIAL CONDITIONS
@C   PCR ICDAT  ICRT  ICND  ICRN  ICRE  ICWD ICRES ICREN ICREP ICRIP ICRID ICNAME
 1    LU {icdate}   -99   -99     1     1   -99   -99   -99   -99   -99   -99 Hydroponic - No Soil

*PLANTING DETAILS
@P PDATE EDATE  PPOP  PPOE  PLME  PLDS  PLRS  PLRD  PLDP  PLWT  PAGE  PENV  PLPH  SPRL                        PLNAME
 1 {planting_date}   -99  {plant_density:4.1f}  {plant_density:4.1f}     T     R    {row_spacing:2d}     0     {planting_depth}    {transplant_wt}    {transplant_age}    20   -99     {seedling_leaf}                        NFT Transplants

*IRRIGATION (AUTOMATIC)
@I  IEFF  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1   -99   -99   -99   -99   -99   -99   -99 Not used in hydroponics

*FERTILIZERS (AUTOMATIC)
@F  FMCD  FAMP  FAMK  FAMD  FAMLC FMOC  FNOP
 1   -99   -99   -99   -99   -99   -99   -99 Not used in hydroponics

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
 1 {planting_date}   -99   -99   -99   -99   -99 R 600   -99   -99 CO2 supplemented >600ppm

*HARVEST DETAILS
@H HDATE  HSTG  HCOM HSIZE   HPC  HBPC HNAME
 1 {harvest_date} GS000     C     A   -99   -99 Harvest

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
*HYDROPONIC CONTROL
@  L  AUTO_PH  AUTO_VOL  AUTO_CONC
   1     {auto_ph}        {auto_vol}         {auto_conc}

*SIMULATION CONTROLS
@N GENERAL     NYERS NREPS START SDATE RSEED SNAME.................... SMODEL
 1 GE              1     1     S {planting_date}  2150 NFT Lettuce 3cv+RexHiEC
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
 1 HA              0 02001   100     0

"""

    output_path = rf'C:\DSSAT48\Lettuce\{experiment_code}.LUX'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Created hydroponic lettuce experiment: {output_path}")
    print(f"\nExperiment: {experiment_code}")
    print(f"Treatments: {len(treatments)}")
    for t in treatments:
        ec_val = ec_treatments[t['hs'] - 1]['ec']
        cv_name = cultivars[t['cu'] - 1]['name']
        print(f"  Trt {t['num']}: {cv_name} at EC {ec_val:.1f}")
    print(f"\nPlanting: {planting_date}, Harvest: {harvest_date} (35 DAP)")
    print(f"Plant Density: {plant_density} plants/m²")
    print(f"Row Spacing (PLRS): {row_spacing} cm (square equivalent)")
    print(f"\nSolution: pH={ph}, DO2={do2} mg/L, Temp={solution_temp} C")
    print(f"Control: AUTO_PH={auto_ph} AUTO_VOL={auto_vol} AUTO_CONC={auto_conc}")
    print(f"\nTo run: dscsm048.exe A {experiment_code}.LUX")

    return output_path


if __name__ == '__main__':
    # Period 1: Aug-Sep 2022
    create_weather_file("VKGA2201", "22213", "22248")
    create_hydroponic_lettuce_experiment(
        experiment_code="VKGA2201",
        planting_date="22213",   # Aug 1, 2022
        harvest_date="22248",    # 35 DAP
    )

    # Period 2: Apr-May 2023
    create_weather_file("VKGA2301", "23091", "23126")
    create_hydroponic_lettuce_experiment(
        experiment_code="VKGA2301",
        planting_date="23091",   # Apr 1, 2023
        harvest_date="23126",    # 35 DAP
    )
