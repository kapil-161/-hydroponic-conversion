"""
Script to create UHIH1201.CBX experiment file using DSSATTools API
Supports all FileX sections including soil analysis, irrigation, chemicals, tillage, and automatic management
"""
from datetime import date
import sys
import os

# Add the path to DSSATTools if needed
# sys.path.insert(0, '/path/to/dssattools')

# Import the necessary classes
# Note: Adjust imports based on your DSSATTools installation
try:
    from dssattools.filex import (
        Field, Cultivar, Planting, Harvest, InitialConditions,
        Fertilizer, FertilizerEvent, Residue, ResidueEvent,
        Irrigation, IrrigationEvent, Chemical, ChemicalEvent,
        Tillage, TillageEvent, SoilAnalysis, SoilAnalysisLayer,
        SimulationControls, SCGeneral, SCOptions, SCMethods,
        SCManagement, SCOutputs, InitialConditionsLayer,
        AMPlanting, AMIrrigation, AMNitrogen, AMResidues, AMHarvest,
        create_filex
    )
    from dssattools.crop import Cabbage
    from dssattools.weather import WeatherStation
    from dssattools.soil import SoilProfile
    DSSATTOOLS_AVAILABLE = True
except ImportError:
    DSSATTOOLS_AVAILABLE = False
    print("DSSATTools not found. Creating file manually with all sections...")

def create_cabbage_experiment_original_format():
    """Create the UHIH1201.CBX experiment file matching the original format"""
    
    if DSSATTOOLS_AVAILABLE:
        try:
            # Create field
            field = Field(
                id_field='UHIH0001',
                wsta='UHIH',  # Weather station ID
                id_soil='UHIH150004',  # Soil profile ID
                flname='IHO1'
            )
            
            # Create cultivar - Kalorama
            cultivar = Cabbage('990003')  # Kalorama cultivar
            
            # Create soil analysis
            soil_analysis = SoilAnalysis(
                sadat=date(2009, 8, 16),  # 09228
                table=[
                    SoilAnalysisLayer(sabl=30)
                ]
            )
            
            # Create initial conditions
            initial_conditions = InitialConditions(
                pcr='BA',  # Previous crop: Barley
                icdat=date(2012, 4, 8),  # 12099
                icrn=1,
                icre=1,
                table=[
                    InitialConditionsLayer(icbl=30, sno3=21.6),
                    InitialConditionsLayer(icbl=60, sno3=9.1),
                    InitialConditionsLayer(icbl=90, sno3=9.1)
                ]
            )
            
            # Create planting details
            planting = Planting(
                pdate=date(2012, 5, 14),  # 12135
                ppop=4,
                ppoe=4,
                plme='T',  # Transplant
                plds='R',
                plrs=50,
                plrd=0,
                pldp=5,
                plwt=22,
                page=10,
                penv=15,
                sprl=5
            )
            
            # Create irrigation
            irrigation = Irrigation(
                efir=1,
                idep=30,
                ithr=50,
                iept=100,
                ioff='GS000',
                iame='IR001',
                iamt=10,
                table=[
                    IrrigationEvent(idate=date(2012, 5, 14), irval=30, irop='IR003'),  # 12135
                    IrrigationEvent(idate=date(2012, 5, 21), irval=30, irop='IR003'),  # 12142
                    IrrigationEvent(idate=date(2012, 5, 25), irval=30, irop='IR003'),  # 12146
                    IrrigationEvent(idate=date(2012, 5, 29), irval=30, irop='IR003')   # 12150
                ]
            )
            
            # Create fertilizer
            fertilizer = Fertilizer(table=[
                FertilizerEvent(
                    fdate=date(2012, 5, 13),  # 12134
                    fmcd='FE003',
                    facd='AP002',
                    fdep=10,
                    famn=240
                )
            ])
            
            # Create residue (empty)
            residue = Residue(table=[
                ResidueEvent(
                    rdate=date(2013, 1, 1),  # 13001
                    rcod='RE001',
                    ramt=0,
                    resn=0,
                    resp=0,
                    resk=0,
                    rinp=0,
                    rdep=0,
                    rmet='AP001'
                )
            ])
            
            # Create chemical
            chemical = Chemical(table=[
                ChemicalEvent(
                    cdate=date(2009, 8, 16),  # 09228
                    chcod='CH001',
                    chamt=0,
                    chme='AP001',
                    chdep=0
                )
            ])
            
            # Create tillage
            tillage = Tillage(table=[
                TillageEvent(
                    tdate=date(2012, 5, 13),  # 12134
                    timpl='TI011',
                    tdep=10
                )
            ])
            
            # Create harvest
            harvest = Harvest(
                hdate=date(2012, 10, 1),  # 12275
                hstg='GS016',
                hcom='C',
                hsize='A',
                hname='Cabbage'
            )
            
            # Create simulation controls with automatic management
            simulation_controls = SimulationControls(
                general=SCGeneral(
                    sdate=date(2012, 1, 1),  # 12001
                    nyers=1,
                    nreps=1,
                    start='S',
                    rseed=2150,
                    sname='DEFAULT SIMULATION CONTR',
                    smodel='CRGRO'
                ),
                options=SCOptions(
                    water='Y',
                    nitro='Y',
                    symbi='N',
                    phosp='N',
                    potas='N',
                    dises='N',
                    chem='N',
                    till='Y',
                    co2='D'
                ),
                methods=SCMethods(
                    wther='M',
                    incon='M',
                    light='E',
                    evapo='R',
                    infil='S',
                    photo='L',
                    hydro='R',
                    nswit='1',
                    mesom='G',
                    mesev='R',
                    mesol='2'
                ),
                management=SCManagement(
                    plant='R',
                    irrig='R',
                    ferti='R',
                    resid='N',
                    harvs='R'
                ),
                outputs=SCOutputs(
                    fname='N',
                    ovvew='Y',
                    sumry='Y',
                    fropt=1,
                    grout='Y',
                    caout='Y',
                    waout='Y',
                    niout='Y',
                    miout='Y',
                    diout='N',
                    vbose='Y',
                    chout='N',
                    opout='Y',
                    fmopt='A'
                ),
                planting=AMPlanting(
                    pfrst=date(2009, 1, 1),  # 09001
                    plast=date(2009, 1, 1),  # 09001
                    ph2ol=40,
                    ph2ou=100,
                    ph2od=30,
                    pstmx=40,
                    pstmn=10
                ),
                irrigation=AMIrrigation(
                    imdep=30,
                    ithrl=50,
                    ithru=100,
                    iroff='GS000',
                    imeth='IR001',
                    iramt=10,
                    ireff=1
                ),
                nitrogen=AMNitrogen(
                    nmdep=30,
                    nmthr=50,
                    namnt=25,
                    ncode='FE001',
                    naoff='GS000'
                ),
                residues=AMResidues(
                    ripcn=100,
                    rtime=1,
                    ridep=20
                ),
                harvest=AMHarvest(
                    hfrst=date(2012, 1, 1),  # Will be converted to 0
                    hlast=date(2013, 12, 12),  # 13346
                    hpcnp=100,
                    hpcnr=0
                )
            )
            
            # Create the FileX string
            filex_content = create_filex(
                field=field,
                cultivar=cultivar,
                planting=planting,
                simulation_controls=simulation_controls,
                harvest=harvest,
                initial_conditions=initial_conditions,
                fertilizer=fertilizer,
                soil_analysis=soil_analysis,
                irrigation=irrigation,
                residue=residue,
                chemical=chemical,
                tillage=tillage
            )
            
            # Write to file
            output_path = r'C:\DSSAT48\Cabbage\UHIH1201.CBX'
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(filex_content)
            
            print(f"Successfully created experiment file: {output_path}")
            return output_path
            
        except Exception as e:
            print(f"Error using DSSATTools API: {e}")
            print("Falling back to manual creation...")
            return create_file_manually_original()
    else:
        return create_file_manually_original()

def create_file_manually_original():
    """Create the file manually matching the original format exactly"""
    content = """*EXP.DETAILS: UHIH1201CB 2012 IHINGER HOF - EVALUATION

*GENERAL
@PEOPLE
Anne Uebelhoer, Sebastian Munz, Simone Graeff-Hönninger, Wilhelm Claupein
@ADDRESS
University of Hohenheim, Institute of Crop Science
@SITE
Ihinger Hof, Germany (48°44'N,8°55'E, 478 m a.s.l.)
@ PAREA  PRNO  PLEN  PLDR  PLSP  PLAY HAREA  HRNO  HLEN  HARM.........
    -99   -99   -99   -99   -99   -99   -99   -99   -99   -99
@NOTES
Reference: Scientia Horticulturae 182 (2015) 110-118; https://doi.org/10.1016/j.scienta.2014.11.019 


*TREATMENTS                        -------------FACTOR LEVELS------------
@N R O C TNAME.................... CU FL SA IC MP MI MF MR MC MT ME MH SM
 1 0 0 0 IhingerHof 2012            1  1  0  1  1  1  1  0  0  1  0  1  1

*CULTIVARS
@C CR INGENO CNAME
 1 CB 990003 Kalorama  4

*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 UHIH0001 UHIH       -99   -99   -99   -99   -99   -99 -99    -99  UHIH150004 IHO1
@L ...........XCRD ...........YCRD .....ELEV .............AREA .SLEN .FLWR .SLAS FLHST FHDUR
 1             -99             -99       -99               -99   -99   -99   -99   -99   -99

*SOIL ANALYSIS
@A SADAT  SMHB  SMPX  SMKE  SANAME
 1 09228   -99   -99   -99  -99
@A  SABL  SADM  SAOC  SANI SAPHW SAPHB  SAPX  SAKE  SASC
 1    30   -99   -99   -99   -99   -99   -99   -99   -99

*INITIAL CONDITIONS
@C   PCR ICDAT  ICRT  ICND  ICRN  ICRE  ICWD ICRES ICREN ICREP ICRIP ICRID ICNAME
 1    BA 12099   -99   -99     1     1   -99   -99   -99   -99   -99   -99 -99
@C  ICBL  SH2O  SNH4  SNO3
 1    30   -99   -99  21.6
 1    60   -99   -99   9.1
 1    90   -99   -99   9.1

*PLANTING DETAILS
@P PDATE EDATE  PPOP  PPOE  PLME  PLDS  PLRS  PLRD  PLDP  PLWT  PAGE  PENV  PLPH  SPRL                        PLNAME
 1 12135   -99     4     4     T     R    50     0     5    22    10    15   -99     5                        -99

*IRRIGATION AND WATER MANAGEMENT
@I  EFIR  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1     1    30    50   100 GS000 IR001    10 -99
@I IDATE  IROP IRVAL
 1 12135 IR003    30
 1 12142 IR003    30
 1 12146 IR003    30
 1 12150 IR003    30

*FERTILIZERS (INORGANIC)
@F FDATE  FMCD  FACD  FDEP  FAMN  FAMP  FAMK  FAMC  FAMO  FOCD FERNAME
 1 12134 FE003 AP002    10   240   -99   -99   -99   -99   -99 -99

*RESIDUES AND ORGANIC FERTILIZER
@R RDATE  RCOD  RAMT  RESN  RESP  RESK  RINP  RDEP  RMET RENAME
 1 13001   -99   -99   -99   -99   -99   -99   -99   -99 -99

*CHEMICAL APPLICATIONS
@C CDATE CHCOD CHAMT  CHME CHDEP   CHT..CHNAME
 1 09228   -99   -99   -99   -99   -99  -99

*TILLAGE AND ROTATIONS
@T TDATE TIMPL  TDEP TNAME
 1 12134 TI011    10 -99

*HARVEST DETAILS
@H HDATE  HSTG  HCOM HSIZE   HPC  HBPC HNAME
 1 12275 GS016     C     A   -99   -99 Cabbage

*SIMULATION CONTROLS
@N GENERAL     NYERS NREPS START SDATE RSEED SNAME.................... SMODEL
 1 GE              1     1     S 12001  2150 DEFAULT SIMULATION CONTR  CRGRO
@N OPTIONS     WATER NITRO SYMBI PHOSP POTAS DISES  CHEM  TILL   CO2
 1 OP              Y     Y     N     N     N     N     N     Y     D
@N METHODS     WTHER INCON LIGHT EVAPO INFIL PHOTO HYDRO NSWIT MESOM MESEV MESOL
 1 ME              M     M     E     R     S     L     R     1     G     R     2
@N MANAGEMENT  PLANT IRRIG FERTI RESID HARVS
 1 MA              R     R     R     N     R
@N OUTPUTS     FNAME OVVEW SUMRY FROPT GROUT CAOUT WAOUT NIOUT MIOUT DIOUT VBOSE CHOUT OPOUT FMOPT
 1 OU              N     Y     Y     1     Y     Y     Y     Y     Y     N     Y     N     Y     A

@  AUTOMATIC MANAGEMENT
@N PLANTING    PFRST PLAST PH2OL PH2OU PH2OD PSTMX PSTMN
 1 PL          09001 09001    40   100    30    40    10
@N IRRIGATION  IMDEP ITHRL ITHRU IROFF IMETH IRAMT IREFF
 1 IR             30    50   100 GS000 IR001    10     1
@N NITROGEN    NMDEP NMTHR NAMNT NCODE NAOFF
 1 NI             30    50    25 FE001 GS000
@N RESIDUES    RIPCN RTIME RIDEP
 1 RE            100     1    20
@N HARVEST     HFRST HLAST HPCNP HPCNR
 1 HA              0 13346   100     0
@N SIMDATES    ENDAT    SDUR   FODAT  FSTRYR  FENDYR FWFILE           FONAME
 1                                                                    
"""
    
    output_path = r'C:\DSSAT48\Cabbage\UHIH1201.CBX'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Successfully created experiment file: {output_path}")
    return output_path

def create_cabbage_experiment():
    """Main function - creates experiment file in original format"""
    return create_cabbage_experiment_original_format()

if __name__ == '__main__':
    create_cabbage_experiment()
