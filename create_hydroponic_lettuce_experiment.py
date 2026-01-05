"""
Script to create a Hydroponic Lettuce experiment file with *HYDROPONIC SOLUTION section
Based on UHIH2501.LUX but with configurable parameters
"""
import os
import sys

def create_hydroponic_lettuce_experiment(
    experiment_code="UHIH2501",
    cultivar_code="990001",
    cultivar_name="Buttercrunch",
    planting_date="25010",
    harvest_date="25045",  # 35 days after planting
    plant_density=16,  # plants per m²
    solution_volume=1000.0,
    ec=2.0,
    ph=6.0,
    do2=8.0,
    solution_temp=20.0,
    no3_conc=160.0,
    nh4_conc=12.0,
    p_conc=50.0,
    k_conc=200.0
):
    """Create a hydroponic lettuce experiment file with *HYDROPONIC SOLUTION section"""

    # Calculate initial conditions date (1 day before planting)
    icdate = str(int(planting_date) - 1)
    
    content = f"""*EXP.DETAILS: {experiment_code}LU LETTUCE HYDROPONIC NFT SIMULATION

*GENERAL
@PEOPLE
Kapil Bhattarai
@ADDRESS
University of Hohenheim, Germany
@SITE
IhingerHof Research Station

*TREATMENTS                        -------------FACTOR LEVELS------------
@N R O C TNAME.................... CU FL SA IC MP MI MF MR MC MT ME MH SM
 1 1 0 0 {cultivar_name} NFT          1  1  0  1  1  1  0  0  0  0  0  1  1

*CULTIVARS
@C CR INGENO CNAME
 1 LU {cultivar_code} {cultivar_name}

*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 UHIH0001 {experiment_code}   -99   -99   -99   -99   -99   -99 -99    -99  -99        Hydroponic NFT System
@L ...........XCRD ...........YCRD .....ELEV .............AREA .SLEN .FLWR .SLAS FLHST FHDUR
 1             -99             -99       -99                50   -99   -99   -99   -99   -99

*INITIAL CONDITIONS
@C   PCR ICDAT  ICRT  ICND  ICRN  ICRE  ICWD ICRES ICREN ICREP ICRIP ICRID ICNAME
 1    LU {icdate}   -99   -99     1     1   -99   -99   -99   -99   -99   -99 Hydroponic - No Soil

*PLANTING DETAILS
@P PDATE EDATE  PPOP  PPOE  PLME  PLDS  PLRS  PLRD  PLDP  PLWT  PAGE  PENV  PLPH  SPRL                        PLNAME
 1 {planting_date}   -99    {plant_density:2d}    {plant_density:2d}     T     R    15     0     2     8     7    10   -99     3                        NFT Transplants

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
 1    -99   -99   -99   -99   -99   -99   -99   -99   -99

*HARVEST DETAILS
@H  HDATE  HSTG  HCOM HSIZE   HPC  HBPC HNAME
 1 {harvest_date} GS000   -99   -99   -99   -99 Harvest at {int(harvest_date[-2:]) - int(planting_date[-2:])} days

*HYDROPONIC SOLUTION
@  L    SOLVOL        EC        PH       DO2      TEMP   NO3_CONC  NH4_CONC    P_CONC    K_CONC
   1   {solution_volume:7.1f}      {ec:4.1f}     {ph:4.1f}     {do2:4.1f}    {solution_temp:5.1f}     {no3_conc:7.1f}     {nh4_conc:7.1f}    {p_conc:7.1f}    {k_conc:7.1f}

*SIMULATION CONTROLS
@N GENERAL     NYERS NREPS START SDATE RSEED SNAME.................... SMODEL
 1 GE              1     1     S {planting_date}  2150 NFT Lettuce Simulation
@N OPTIONS     WATER NITRO SYMBI PHOSP POTAS DISES  CHEM  TILL   CO2
 1 OP              Y     Y     N     N     N     N     N     N     M
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
 1 HA          {harvest_date} {harvest_date}   100     0

"""

    output_path = rf'C:\DSSAT48\Lettuce\{experiment_code}.LUX'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Successfully created hydroponic lettuce experiment file: {output_path}")
    print(f"\nExperiment Code: {experiment_code}")
    print(f"Cultivar: {cultivar_name} ({cultivar_code})")
    print(f"Planting Date: {planting_date} (Day {planting_date[-3:]})")
    print(f"Harvest Date: {harvest_date} (Day {harvest_date[-3:]})")
    print(f"Growing Period: {int(harvest_date[-2:]) - int(planting_date[-2:])} days")
    print(f"Plant Density: {plant_density} plants/m² ({plant_density * 10000} plants/ha)")
    print("\nHydroponic Solution Parameters:")
    print(f"  - Solution Volume: {solution_volume:.1f} L")
    print(f"  - EC: {ec:.1f} dS/m")
    print(f"  - pH: {ph:.1f}")
    print(f"  - DO2: {do2:.1f} mg/L")
    print(f"  - Temperature: {solution_temp:.1f} °C")
    print(f"  - NO3-N: {no3_conc:.1f} mg/L")
    print(f"  - NH4-N: {nh4_conc:.1f} mg/L")
    print(f"  - P: {p_conc:.1f} mg/L")
    print(f"  - K: {k_conc:.1f} mg/L")
    print("\nThis file will activate HYDROPONIC mode (ISWHYDRO='Y')")
    print(f"\nTo run: dscsm048.exe A {experiment_code}.LUX")

    return output_path

if __name__ == '__main__':
    # Default: Create UHIH2501 experiment with 35-day harvest
    if len(sys.argv) > 1:
        experiment_code = sys.argv[1]
    else:
        experiment_code = "UHIH2501"
    
    create_hydroponic_lettuce_experiment(
        experiment_code=experiment_code,
        harvest_date="25045"  # 35 days after planting
    )
# use R for reported date for harvest
