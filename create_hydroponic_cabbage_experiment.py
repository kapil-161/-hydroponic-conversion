"""
Script to create a Hydroponic Cabbage experiment file with *HYDROPONIC SOLUTION section
Based on the original UHIH1201.CBX but modified for hydroponic NFT system
"""
import os

def create_hydroponic_cabbage_experiment():
    """Create a hydroponic cabbage experiment file with *HYDROPONIC SOLUTION section"""

    content = """*EXP.DETAILS: HYDRO001CB Hydroponic NFT Cabbage System

*GENERAL
@PEOPLE
DSSAT Hydroponic System Test
@ADDRESS
Controlled Environment Greenhouse
@SITE
Hydroponic NFT System (Nutrient Film Technique)
@ PAREA  PRNO  PLEN  PLDR  PLSP  PLAY HAREA  HRNO  HLEN  HARM.........
    -99   -99   -99   -99   -99   -99   -99   -99   -99   -99
@NOTES
Hydroponic cabbage production in NFT system with controlled nutrient solution
Testing DSSAT-CSM hydroponic module implementation


*TREATMENTS                        -------------FACTOR LEVELS------------
@N R O C TNAME.................... CU FL SA IC MP MI MF MR MC MT ME MH SM
 1 0 0 0 Hydroponic NFT Cabbage     1  1  0  1  1  1  1  0  0  0  0  1  1

*CULTIVARS
@C CR INGENO CNAME
 1 CB 990003 Kalorama  4

*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 UHIH0001 UHIH       -99   -99   -99   -99   -99   -99 -99    -99  UHIH150004 Hydroponic NFT
@L ...........XCRD ...........YCRD .....ELEV .............AREA .SLEN .FLWR .SLAS FLHST FHDUR
 1             -99             -99       -99               -99   -99   -99   -99   -99   -99

*HYDROPONIC SOLUTION
@  L    SOLVOL        EC        PH       DO2      TEMP   NO3_CONC  NH4_CONC    P_CONC    K_CONC
   1    1000.0       2.2       6.0       8.0      20.0      180.0      15.0      60.0     240.0

*INITIAL CONDITIONS
@C   PCR ICDAT  ICRT  ICND  ICRN  ICRE  ICWD ICRES ICREN ICREP ICRIP ICRID ICNAME
 1    CB 12099   -99   -99     1     1   -99   -99   -99   -99   -99   -99 -99
@C  ICBL  SH2O  SNH4  SNO3
 1     5  0.30   0.5   5.0
 1    15  0.30   0.5   5.0
 1    30  0.30   0.5   5.0

*PLANTING DETAILS
@P PDATE EDATE  PPOP  PPOE  PLME  PLDS  PLRS  PLRD  PLDP  PLWT  PAGE  PENV  PLPH  SPRL                        PLNAME
 1 12135   -99     4     4     T     R    50     0     3    22    10    15   -99     5                        Hydroponic Transplant

*IRRIGATION AND WATER MANAGEMENT
@I  EFIR  IDEP  ITHR  IEPT  IOFF  IAME  IAMT IRNAME
 1     1    30    50   100   GS000 IR001    10 Nutrient Solution
@I IDATE  IROP IRVAL
 1 12135 IR001    20
 1 12140 IR001    20
 1 12145 IR001    20
 1 12150 IR001    20
 1 12155 IR001    20
 1 12160 IR001    20

*FERTILIZERS (INORGANIC)
@F FDATE  FMCD  FACD  FDEP  FAMN  FAMP  FAMK  FAMC  FAMO  FOCD FERNAME
 1 12134 FE005 AP001     1    50    15    60   -99   -99   -99 Hydroponic Nutrient A
 1 12145 FE005 AP001     1    50    15    60   -99   -99   -99 Hydroponic Nutrient B
 1 12155 FE005 AP001     1    50    15    60   -99   -99   -99 Hydroponic Nutrient C
 1 12165 FE005 AP001     1    50    15    60   -99   -99   -99 Hydroponic Nutrient D

*RESIDUES AND ORGANIC FERTILIZER
@R RDATE  RCOD  RAMT  RESN  RESP  RESK  RINP  RDEP  RMET RENAME
 1 13001   -99   -99   -99   -99   -99   -99   -99   -99 -99

*CHEMICAL APPLICATIONS
@C CDATE CHCOD CHAMT  CHME CHDEP   CHT..CHNAME
 1 12135   -99   -99   -99   -99   -99  -99

*TILLAGE AND ROTATIONS
@T TDATE TIMPL  TDEP TNAME
 1 12134   -99   -99 -99

*HARVEST DETAILS
@H HDATE  HSTG  HCOM HSIZE   HPC  HBPC HNAME
 1 12240 GS016     C     A   -99   -99 Hydroponic Cabbage Harvest

*SIMULATION CONTROLS
@N GENERAL     NYERS NREPS START SDATE RSEED SNAME.................... SMODEL
 1 GE              1     1     S 12001  2150 Hydroponic NFT Cabbage    CRGRO
@N OPTIONS     WATER NITRO SYMBI PHOSP POTAS DISES  CHEM  TILL   CO2
 1 OP              Y     Y     N     N     N     N     N     N     D
@N METHODS     WTHER INCON LIGHT EVAPO INFIL PHOTO HYDRO NSWIT MESOM MESEV MESOL
 1 ME              M     M     E     F     S     L     R     1     G     R     2
@N MANAGEMENT  PLANT IRRIG FERTI RESID HARVS
 1 MA              R     R     R     N     R
@N OUTPUTS     FNAME OVVEW SUMRY FROPT GROUT CAOUT WAOUT NIOUT MIOUT DIOUT VBOSE CHOUT OPOUT FMOPT
 1 OU              N     Y     Y     1     Y     Y     Y     Y     Y     N     Y     N     Y     A

@  AUTOMATIC MANAGEMENT
@N PLANTING    PFRST PLAST PH2OL PH2OU PH2OD PSTMX PSTMN
 1 PL          12001 12140    40   100    30    40    10
@N IRRIGATION  IMDEP ITHRL ITHRU IROFF IMETH IRAMT IREFF
 1 IR             30    50   100 GS000 IR001    10     1
@N NITROGEN    NMDEP NMTHR NAMNT NCODE NAOFF
 1 NI             30    50    25 FE001 GS000
@N RESIDUES    RIPCN RTIME RIDEP
 1 RE            100     1    20
@N HARVEST     HFRST HLAST HPCNP HPCNR
 1 HA              0 12365   100     0
@N SIMDATES    ENDAT    SDUR   FODAT  FSTRYR  FENDYR FWFILE           FONAME
 1
"""

    output_path = r'C:\DSSAT48\Cabbage\UHIH1202.CBX'
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Successfully created hydroponic experiment file: {output_path}")
    print("\nFile contains *HYDROPONIC SOLUTION section:")
    print("  - Solution Volume: 1000.0 L")
    print("  - EC: 2.2 dS/m")
    print("  - pH: 6.0")
    print("  - DO2: 8.0 mg/L")
    print("  - Temperature: 20.0 °C")
    print("  - NO3-N: 180.0 mg/L")
    print("  - NH4-N: 15.0 mg/L")
    print("  - P: 60.0 mg/L")
    print("  - K: 240.0 mg/L")
    print("\nThis file will activate HYDROPONIC mode (ISWHYDRO='Y')")
    print(f"\nTo run: dscsm048.exe A UHIH1202.CBX")

    return output_path

if __name__ == '__main__':
    create_hydroponic_cabbage_experiment()
