"""
Script to create a Soil-based Lettuce experiment file (.LUX)
Similar to hydroponic version but with soil parameters instead
"""
import os
import sys

def create_soil_lettuce_experiment(
    experiment_code="UHIH2502",
    cultivar_code="990001",
    cultivar_name="Buttercrunch",
    planting_date="25010",
    harvest_date="25045",  # 35 days after planting
    plant_density=16,  # plants per m²
    weather_station="UHIH2501",
    soil_id="UHIH150004",  # Soil profile ID
    initial_water_content=0.30,  # Initial soil water content (cm³/cm³)
    initial_nh4=0.5,  # Initial NH4-N (kg/ha)
    initial_no3=5.0,  # Initial NO3-N (kg/ha)
    irrigation_method="R",  # R=Rainfed, A=Automatic, M=Manual
    fertilizer_applications=None  # List of (date, N, P, K) tuples
):
    """Create a soil-based lettuce experiment file"""

    # Calculate initial conditions date (1 day before planting)
    icdate = str(int(planting_date) - 1)
    
    # Default fertilizer applications if none provided
    if fertilizer_applications is None:
        # Apply fertilizer at planting
        fertilizer_applications = [
            (planting_date, 50, 15, 60)  # (date, N kg/ha, P kg/ha, K kg/ha)
        ]
    
    # Build fertilizer section
    fertilizer_section = ""
    for i, (fdate, n, p, k) in enumerate(fertilizer_applications, 1):
        fertilizer_section += f" {i} {fdate} FE005 AP001     1   {n:4d}   {p:4d}   {k:4d}   -99   -99   -99 Fertilizer App {i}\n"
    
    # Build irrigation section based on method
    if irrigation_method == "A":  # Automatic
        irrigation_section = """*IRRIGATION (AUTOMATIC)
@I  IEFF  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1     1    30    50   100   GS000 IR001    10 Automatic Irrigation
"""
    elif irrigation_method == "M":  # Manual - add irrigation events
        irrigation_section = """*IRRIGATION AND WATER MANAGEMENT
@I  EFIR  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1     1    30    50   100   GS000 IR001    10 Manual Irrigation
@I IDATE  IROP IRVAL
"""
        # Add weekly irrigation events
        planting_day = int(planting_date[-2:])
        for week in range(1, 6):  # 5 weeks of irrigation
            irr_date = str(int(planting_date[:-2]) * 100 + planting_day + (week * 7))
            irrigation_section += f" 1 {irr_date} IR001    20\n"
    else:  # Rainfed
        irrigation_section = """*IRRIGATION (AUTOMATIC)
@I  IEFF  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1   -99   -99   -99   -99   -99   -99   -99 Rainfed
"""
    
    content = f"""*EXP.DETAILS: {experiment_code}LU LETTUCE SOIL-BASED SIMULATION

*GENERAL
@PEOPLE
Kapil Bhattarai
@ADDRESS
University of Hohenheim, Germany
@SITE
IhingerHof Research Station

*TREATMENTS                        -------------FACTOR LEVELS------------
@N R O C TNAME.................... CU FL SA IC MP MI MF MR MC MT ME MH SM
 1 1 0 0 {cultivar_name} Soil         1  1  0  1  1  1  0  0  0  0  0  1  1

*CULTIVARS
@C CR INGENO CNAME
 1 LU {cultivar_code} {cultivar_name}

*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 UHIH0001 {weather_station}   -99   -99   -99   -99   -99   -99 -99    -99  {soil_id}        IhingerHof Field

*INITIAL CONDITIONS
@C   PCR ICDAT  ICRT  ICND  ICRN  ICRE  ICWD ICRES ICREN ICREP ICRIP ICRID ICNAME
 1    LU {icdate}   -99   -99     1     1   -99   -99   -99   -99   -99   -99 Initial Conditions
@C  ICBL  SH2O  SNH4  SNO3
 1     5  {initial_water_content:.2f}   {initial_nh4:.1f}   {initial_no3:.1f}
 1    15  {initial_water_content:.2f}   {initial_nh4:.1f}   {initial_no3:.1f}
 1    30  {initial_water_content:.2f}   {initial_nh4:.1f}   {initial_no3:.1f}

*PLANTING DETAILS
@P PDATE EDATE  PPOP  PPOE  PLME  PLDS  PLRS  PLRD  PLDP  PLWT  PAGE  PENV  PLPH  SPRL                        PLNAME
 1 {planting_date}   -99    {plant_density:2d}    {plant_density:2d}     T     R    15     0     2     8     7    10   -99     3                        Direct Seeding

{irrigation_section}
*FERTILIZERS (INORGANIC)
@F FDATE  FMCD  FACD  FDEP  FAMN  FAMP  FAMK  FAMC  FAMO  FOCD FERNAME{fertilizer_section}
*RESIDUES AND ORGANIC FERTILIZER
@R RDATE  RCOD  RAMT  RESN  RESP  RESK  RINP  RDEP  RMET RENAME
 1 13001   -99   -99   -99   -99   -99   -99   -99   -99 No residues

*CHEMICAL APPLICATIONS
@C CDATE CHCOD CHAMT  CHME CHDEP   CHT..CHNAME
 1 13001   -99   -99   -99   -99   -99 No chemicals

*TILLAGE AND ROTATIONS
@T TDATE TIMPL  TDEP TNAME
 1 {icdate}   -99   -99 Pre-planting tillage

*ENVIRONMENT MODIFICATIONS
@E  ODATE EDAY  ERAD  EMAX  EMIN  ERAIN ECO2  EDEW  EWIND ENVNAME
 1    -99   -99   -99   -99   -99   -99   -99   -99   -99

*HARVEST DETAILS
@H  HDATE  HSTG  HCOM HSIZE   HPC  HBPC HNAME
 1 {harvest_date} GS000   -99   -99   -99   -99 Harvest at {int(harvest_date[-2:]) - int(planting_date[-2:])} days

*SIMULATION CONTROLS
@N GENERAL     NYERS NREPS START SDATE RSEED SNAME.................... SMODEL
 1 GE              1     1     S {planting_date}  2150 Soil Lettuce Simulation
@N OPTIONS     WATER NITRO SYMBI PHOSP POTAS DISES  CHEM  TILL   CO2
 1 OP              Y     Y     N     N     N     N     N     N     M
@N METHODS     WTHER INCON LIGHT EVAPO INFIL PHOTO HYDRO NSWIT MESOM MESEV MESOL
 1 ME              M     M     E     R     S     L     N     1     G     S     2
@N MANAGEMENT  PLANT IRRIG FERTI RESID HARVS
 1 MA              R     {irrigation_method}     R     N     R
@N OUTPUTS     FNAME OVVEW SUMRY FROPT GROUT CAOUT WAOUT NIOUT MIOUT DIOUT VBOSE CHOUT OPOUT FMOPT
 1 OU              N     Y     Y     1     Y     Y     Y     Y     N     N     Y     N     N     A

@  AUTOMATIC MANAGEMENT
@N PLANTING    PFRST PLAST PH2OL PH2OU PH2OD PSTMX PSTMN
 1 PL          {planting_date} {planting_date}    40   100    30    40    10
@N IRRIGATION  IMDEP ITHRL ITHRU IROFF IMETH IRAMT IREFF
 1 IR             30    50   100 GS000 IR001    10     1
@N NITROGEN    NMDEP NMTHR NAMNT NCODE NAOFF
 1 NI             30    50    25 FE001 GS000
@N RESIDUES    RIPCN RTIME RIDEP
 1 RE            100     1    20
@N HARVEST     HFRST HLAST HPCNP HPCNR
 1 HA          {harvest_date} {harvest_date}   100     0
"""

    output_path = rf'C:\DSSAT48\Lettuce\{experiment_code}.LUX'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Successfully created soil-based lettuce experiment file: {output_path}")
    print(f"\nExperiment Code: {experiment_code}_SOIL")
    print(f"Cultivar: {cultivar_name} ({cultivar_code})")
    print(f"Planting Date: {planting_date} (Day {planting_date[-3:]})")
    print(f"Harvest Date: {harvest_date} (Day {harvest_date[-3:]})")
    print(f"Growing Period: {int(harvest_date[-2:]) - int(planting_date[-2:])} days")
    print(f"Plant Density: {plant_density} plants/m² ({plant_density * 10000} plants/ha)")
    print(f"\nSoil Parameters:")
    print(f"  - Weather Station: {weather_station}")
    print(f"  - Soil Profile ID: {soil_id}")
    print(f"  - Initial Water Content: {initial_water_content:.2f} cm³/cm³")
    print(f"  - Initial NH4-N: {initial_nh4:.1f} kg/ha")
    print(f"  - Initial NO3-N: {initial_no3:.1f} kg/ha")
    print(f"  - Irrigation Method: {irrigation_method} ({'Automatic' if irrigation_method == 'A' else 'Manual' if irrigation_method == 'M' else 'Rainfed'})")
    print(f"\nFertilizer Applications: {len(fertilizer_applications)}")
    for i, (fdate, n, p, k) in enumerate(fertilizer_applications, 1):
        print(f"  {i}. Date {fdate}: N={n} kg/ha, P={p} kg/ha, K={k} kg/ha")
    print(f"\nTo run: dscsm048.exe A {experiment_code}.LUX")
    print(f"\nNote: Ensure soil file with profile '{soil_id}' exists in C:\\DSSAT48\\Soil\\")
    print(f"      Ensure weather file '{weather_station}.WTH' exists in C:\\DSSAT48\\Weather\\")

    return output_path

if __name__ == '__main__':
    # Default: Create UHIH2502_SOIL experiment with 35-day harvest
    if len(sys.argv) > 1:
        experiment_code = sys.argv[1]
    else:
        experiment_code = "UHIH2502"
    
    create_soil_lettuce_experiment(
        experiment_code=experiment_code,
        harvest_date="25045",  # 35 days after planting
        irrigation_method="A"  # Automatic irrigation
    )

