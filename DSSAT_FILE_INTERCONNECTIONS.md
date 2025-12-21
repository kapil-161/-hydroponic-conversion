# DSSAT File Interconnections

This document explains how different DSSAT file types are interconnected and reference each other within the DSSAT system.

## Overview

DSSAT uses a modular file structure where experiment files (FileX) act as the central hub, referencing various data files for weather, soil, cultivars, and other inputs. Understanding these connections is crucial for creating valid experiment files and running successful simulations.

## File Type Overview

| File Type | Extension | Purpose | Location |
|-----------|-----------|---------|----------|
| **Experiment File** | `.MZX`, `.SBX`, `.CBX`, `.WHX`, etc. | Defines the experiment setup | Crop directories (e.g., `C:\DSSAT48\Maize\`) |
| **Weather File** | `.WTH` | Daily weather data | `C:\DSSAT48\Weather\` |
| **Soil File** | `.SOL` | Soil profile data | `C:\DSSAT48\Soil\` |
| **Cultivar File** | `.CUL` | Crop cultivar coefficients | `C:\DSSAT48\Genotype\` |
| **Ecotype File** | `.ECO` | Crop ecotype parameters | `C:\DSSAT48\Genotype\` |
| **Species File** | `.SPE` | Crop species parameters | `C:\DSSAT48\Genotype\` |
| **Pest File** | `.PST` | Pest and disease parameters | `C:\DSSAT48\Pest\` |

## File Naming Conventions

### Experiment Files (FileX)

Format: `SSSSNNNN.CXX`
- `SSSS` = Site code (4 characters)
- `NNNN` = Experiment number (4 digits)
- `CXX` = Crop code + version (e.g., `.MZX` for Maize, `.SBX` for Soybean, `.CBX` for Cabbage)

**Examples:**
- `EBPL8501.MZX` - Maize experiment at EBPL site, experiment 8501
- `UHIH1201.CBX` - Cabbage experiment at UHIH site, experiment 1201
- `IBPF8601.SBX` - Soybean experiment at IBPF site, experiment 8601

### Weather Files

Format: `SSSSNNNN.WTH`
- `SSSS` = Weather station code (4 characters)
- `NNNN` = Year or identifier (4 digits)

**Examples:**
- `ACNM1301.WTH` - Weather station ACNM, year 2013
- `EBCH8401.WTH` - Weather station EBCH, year 1984

### Soil Files

Format: `SSSSNNNN.SOL` or descriptive names
- Contains multiple soil profiles
- Each profile has a unique ID within the file

**Examples:**
- `AG.SOL` - Contains multiple soil profiles (AGSP209115, AGSP209113, etc.)
- `EBMZ850001.SOL` - Specific soil profile

### Cultivar Files

Format: `CCCCCCCC.CUL`
- `CCCCCCCC` = Crop model code (8 characters, e.g., `CBGRO048` for Cabbage CROPGRO v4.8)

**Examples:**
- `CBGRO048.CUL` - Cabbage CROPGRO cultivars
- `MZCER048.CUL` - Maize CERES cultivars
- `WHAPS048.CUL` - Wheat APSIM cultivars

## Interconnections

### 1. Experiment File → Weather File

**Connection Point:** `*FIELDS` section, `WSTA` field

```fortran
*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 UHIH0001 ACNM1301   -99     0 DR000     0     0 00000 -99    120  UHIH150004 IHO1
```

**How it works:**
- The `WSTA` field (e.g., `ACNM1301`) references a weather file
- DSSAT looks for `ACNM1301.WTH` in the `C:\DSSAT48\Weather\` directory
- The weather file must exist and contain data for the simulation period

**Example:**
```
Experiment File: UHIH1201.CBX
  └─> WSTA: ACNM1301
      └─> Weather File: C:\DSSAT48\Weather\ACNM1301.WTH
```

### 2. Experiment File → Soil File

**Connection Point:** `*FIELDS` section, `ID_SOIL` field

```fortran
*FIELDS
@L ID_FIELD WSTA....  FLSA  FLOB  FLDT  FLDD  FLDS  FLST SLTX  SLDP  ID_SOIL    FLNAME
 1 UHIH0001 ACNM1301   -99     0 DR000     0     0 00000 -99    120  UHIH150004 IHO1
```

**How it works:**
- The `ID_SOIL` field (e.g., `UHIH150004`) references a soil profile
- DSSAT searches all `.SOL` files in `C:\DSSAT48\Soil\` for a profile with this ID
- The soil profile ID is defined in the `*SOILS:` header line within the `.SOL` file

**Example:**
```
Experiment File: UHIH1201.CBX
  └─> ID_SOIL: UHIH150004
      └─> Soil File: C:\DSSAT48\Soil\*.SOL
          └─> Profile: *UHIH150004 (found within any .SOL file)
```

**Soil File Structure:**
```fortran
*SOILS: SOIL DATA DESCRIPTION
*UHIH150004  SOIL PROFILE NAME
@SITE        COUNTRY          LAT     LONG SCS FAMILY
 Ihinger Hof  GERMANY          48.73   8.92 -99
@  SLB  SLMH  SLLL  SDUL  SSAT  SRGF  SSKS  SBDM  SLOC  SLCL  SLSI  SLCF  SLNI  SLHW  SLHB  SCEC  SADC
    30   -99  .117  .433  .497     1   .09   1.5   1.8  42.9    51   -99   -99     8   -99    16   -99
    60   -99   .22  .449  .553  .407   .68   1.5    .5   6.4    70   -99   -99     8   -99    13   -99
    ...
```

### 3. Experiment File → Cultivar File

**Connection Point:** `*CULTIVARS` section, `CR` and `INGENO` fields

```fortran
*CULTIVARS
@C CR INGENO CNAME
 1 CB 990003 Kalorama  4
```

**How it works:**
- The `CR` field (e.g., `CB` for Cabbage) determines which cultivar file to use
- The `INGENO` field (e.g., `990003`) is the cultivar identifier within that file
- DSSAT maps crop codes to cultivar files:
  - `CB` → `CBGRO048.CUL` (Cabbage CROPGRO)
  - `MZ` → `MZCER048.CUL` (Maize CERES) or `MZIXM048.CUL` (Maize IXIM)
  - `SB` → `SBGRO048.CUL` (Soybean CROPGRO)
  - `WH` → `WHAPS048.CUL` (Wheat APSIM) or `CSCER048.CUL` (Wheat CERES)

**Example:**
```
Experiment File: UHIH1201.CBX
  └─> CR: CB
      └─> Cultivar File: C:\DSSAT48\Genotype\CBGRO048.CUL
          └─> INGENO: 990003
              └─> Cultivar Entry: 990003 Kalorama (found in CBGRO048.CUL)
```

**Cultivar File Structure:**
```fortran
*CABBAGE CLTIVAR COEFFICIENTS: CRGRO048 MODEL
@VAR#  VRNAME.......... EXPNO   ECO#  CSDL PPSEN EM-FL FL-SH FL-SD SD-PM ...
 990001 Tastie    4          . CB0401 13.09 0.000  26.0   5.0  11.0 55.00 ...
 990003 Kalorama  4          . CB0403 13.09 0.000  26.0   6.0  16.0 82.00 ...
```

### 4. Cultivar File → Ecotype File

**Connection Point:** `ECO#` field in cultivar file

**How it works:**
- Each cultivar entry has an `ECO#` field (e.g., `CB0403`)
- This references an ecotype file with the same crop prefix
- For Cabbage: `CB0403` → `CBGRO048.ECO`

**Example:**
```
Cultivar File: CBGRO048.CUL
  └─> Cultivar: 990003 Kalorama
      └─> ECO#: CB0403
          └─> Ecotype File: C:\DSSAT48\Genotype\CBGRO048.ECO
              └─> Ecotype Entry: CB0403
```

### 5. Cultivar File → Species File

**Connection Point:** Implicit based on crop code

**How it works:**
- Species files are automatically loaded based on the crop code
- Format: `CCCCCCCC.SPE` (e.g., `CBGRO048.SPE` for Cabbage)

**Example:**
```
Cultivar File: CBGRO048.CUL
  └─> Crop Code: CB
      └─> Species File: C:\DSSAT48\Genotype\CBGRO048.SPE
```

### 6. Experiment File → Pest File (Optional)

**Connection Point:** `*TREATMENTS` section, `DISEASES` factor level

**How it works:**
- If pest/disease simulation is enabled (`DISEASES` = Y in options)
- DSSAT looks for pest files matching the crop model
- Format: `CCCCCCCC.PST` (e.g., `CBGRO048.PST`)

**Example:**
```
Experiment File: UHIH1201.CBX
  └─> Options: DISES = Y
      └─> Crop: CB
          └─> Pest File: C:\DSSAT48\Pest\CBGRO048.PST
```

## Complete Connection Diagram

```
Experiment File (UHIH1201.CBX)
│
├─> *FIELDS Section
│   ├─> WSTA: ACNM1301
│   │   └─> Weather File: C:\DSSAT48\Weather\ACNM1301.WTH
│   │
│   └─> ID_SOIL: UHIH150004
│       └─> Soil File: C:\DSSAT48\Soil\*.SOL
│           └─> Profile: *UHIH150004
│
├─> *CULTIVARS Section
│   ├─> CR: CB
│   │   └─> Cultivar File: C:\DSSAT48\Genotype\CBGRO048.CUL
│   │       ├─> INGENO: 990003
│   │       │   └─> Cultivar Entry: 990003 Kalorama
│   │       │       └─> ECO#: CB0403
│   │       │           └─> Ecotype File: C:\DSSAT48\Genotype\CBGRO048.ECO
│   │       │               └─> Ecotype: CB0403
│   │       │
│   │       └─> Species File: C:\DSSAT48\Genotype\CBGRO048.SPE
│   │
│   └─> Model: CRGRO048 (from SMODEL in Simulation Controls)
│
└─> *SIMULATION CONTROLS Section
    └─> OPTIONS: DISES = Y (if enabled)
        └─> Pest File: C:\DSSAT48\Pest\CBGRO048.PST
```

## File Reference Resolution

### Resolution Order

1. **Weather Files:**
   - DSSAT searches: `C:\DSSAT48\Weather\WSTA.WTH`
   - Must match exactly (case-sensitive on some systems)

2. **Soil Files:**
   - DSSAT searches all `.SOL` files in `C:\DSSAT48\Soil\`
   - Looks for profile ID in any `.SOL` file
   - Multiple profiles can be in one `.SOL` file

3. **Cultivar Files:**
   - Mapping based on crop code and model:
     - Crop code `CB` + Model `CRGRO048` → `CBGRO048.CUL`
     - Crop code `MZ` + Model `MZCER048` → `MZCER048.CUL`
   - Searches: `C:\DSSAT48\Genotype\`

4. **Ecotype Files:**
   - Same naming as cultivar file but with `.ECO` extension
   - Searches: `C:\DSSAT48\Genotype\`

5. **Species Files:**
   - Same naming as cultivar file but with `.SPE` extension
   - Searches: `C:\DSSAT48\Genotype\`

## Common Issues and Solutions

### Issue 1: Weather File Not Found

**Error:** `Weather file not found: ACNM1301`

**Solution:**
- Verify the `WSTA` code in the experiment file matches the weather file name
- Ensure the weather file exists in `C:\DSSAT48\Weather\`
- Check file extension is `.WTH`
- Verify the weather file contains data for the simulation period

### Issue 2: Soil Profile Not Found

**Error:** `Soil profile not found: UHIH150004`

**Solution:**
- Verify the `ID_SOIL` in the experiment file
- Check that a soil profile with this ID exists in any `.SOL` file
- The profile ID must match exactly (case-sensitive)
- Format: `*PROFILE_ID` at the start of the profile definition

### Issue 3: Cultivar Not Found

**Error:** `Cultivar not found: 990003`

**Solution:**
- Verify the `CR` code matches the crop model
- Check that `INGENO` exists in the appropriate cultivar file
- Ensure the cultivar file exists (e.g., `CBGRO048.CUL` for Cabbage)
- Verify the model code in simulation controls matches the cultivar file

### Issue 4: Ecotype Not Found

**Error:** `Ecotype not found: CB0403`

**Solution:**
- Verify the `ECO#` in the cultivar entry
- Ensure the ecotype file exists (e.g., `CBGRO048.ECO`)
- Check that the ecotype ID exists in the ecotype file

## Example: Creating a Valid Experiment File

To create a valid experiment file, ensure all references are correct:

```python
# 1. Weather file must exist
# C:\DSSAT48\Weather\ACNM1301.WTH

# 2. Soil profile must exist in a .SOL file
# C:\DSSAT48\Soil\AG.SOL contains:
# *UHIH150004  SOIL PROFILE NAME
# ...

# 3. Cultivar must exist in cultivar file
# C:\DSSAT48\Genotype\CBGRO048.CUL contains:
# 990003 Kalorama  4          . CB0403 13.09 ...

# 4. Ecotype must exist
# C:\DSSAT48\Genotype\CBGRO048.ECO contains:
# CB0403 ...

# 5. Species file must exist
# C:\DSSAT48\Genotype\CBGRO048.SPE
```

## File Dependency Checklist

When creating or modifying an experiment file, verify:

- [ ] Weather file exists and matches `WSTA` code
- [ ] Weather file contains data for simulation period
- [ ] Soil profile ID exists in a `.SOL` file
- [ ] Cultivar file exists for the crop code
- [ ] Cultivar ID (`INGENO`) exists in cultivar file
- [ ] Ecotype file exists for the crop code
- [ ] Ecotype ID exists in ecotype file
- [ ] Species file exists for the crop code
- [ ] Model code in simulation controls matches cultivar file naming
- [ ] If pests enabled, pest file exists

## Directory Structure Summary

```
C:\DSSAT48\
├── Weather\
│   └── *.WTH (referenced by WSTA in *FIELDS)
├── Soil\
│   └── *.SOL (contains profiles referenced by ID_SOIL in *FIELDS)
├── Genotype\
│   ├── *.CUL (referenced by CR code, contains cultivars by INGENO)
│   ├── *.ECO (referenced by ECO# in cultivar entries)
│   └── *.SPE (automatically loaded based on crop code)
├── Pest\
│   └── *.PST (optional, referenced if DISES = Y)
└── [Crop]\
    └── *.CXX (experiment files - the central hub)
```

## DSSATPRO.v48 - The Configuration File

### Overview

`DSSATPRO.v48` (or `DSSATPRO.L48` on Linux) is the central configuration file that defines:
- **Directory paths** where DSSAT looks for different file types
- **Crop model mappings** that link crop codes to executable models
- **Crop directory mappings** that specify where experiment files are stored for each crop

This file acts as a "roadmap" that tells DSSAT where to find everything it needs.

### Location

- **Windows:** `C:\DSSAT48\DSSATPRO.v48`
- **Linux:** `{install_prefix}/DSSATPRO.L48`
- DSSAT reads this file at startup to configure all directory paths

### File Structure

The file contains three main types of entries:

#### 1. Directory Path Definitions (D-prefix codes)

These define where DSSAT looks for different types of files:

| Code | Description | Example Value |
|------|-------------|---------------|
| `DDB` | Database directory | `C: \DSSAT48` |
| `DTB` | Table directory | `C: \DSSAT48` |
| `DTE` | Template directory | `C: \DSSAT48` |
| `DTO` | Tools directory | `C: \DSSAT48` |
| `DAT` | Data directory | `C: \DSSAT48` |
| `DPT` | Pest directory | `C: \DSSAT48` |
| `DIM` | Image directory | `C: \DSSAT48` |
| `DTP` | Template directory | `C: \DSSAT48` |
| `DPF` | Profile directory | `C: \DSSAT48` |
| `DFO` | Output directory | `C: \DSSAT48` |
| `DIS` | Input directory | `C: \DSSAT48` |
| `DDW` | Weather directory | `C: \DSSAT48` |
| `DWG` | Weather generator directory | `C: \DSSAT48` |
| `DWC` | Weather climate directory | `C: \DSSAT48` |
| `DDS` | Soil directory | `C: \DSSAT48` |
| `DTS` | Soil template directory | `C: \DSSAT48` |
| `DDG` | Genotype directory | `C: \DSSAT48` |
| `STD` | Standard data directory | `C: \DSSAT48\StandardData` |
| `WED` | Weather data directory | `C: \DSSAT48\Weather` |
| `SLD` | Soil data directory | `C: \DSSAT48\SOIL` |
| `CRD` | Genotype (cultivar) directory | `C: \DSSAT48\GENOTYPE` |

**Example:**
```
DDB C: \DSSAT48
WED C: \DSSAT48\Weather
SLD C: \DSSAT48\SOIL
CRD C: \DSSAT48\GENOTYPE
```

#### 2. Crop Model Mappings (M-prefix codes)

These map crop codes to executable models. Format: `MXX Path Executable ModelCode`

| Code | Crop | Executable | Model |
|------|------|------------|-------|
| `MAL` | Alfalfa | `DSCSM048.EXE` | `PRFRM048` |
| `MBA` | Barley | `DSCSM048.EXE` | `CSCER048` |
| `MCB` | Cabbage | `DSCSM048.EXE` | `CRGRO048` |
| `MMZ` | Maize | `DSCSM048.EXE` | `MZCER048` |
| `MSB` | Soybean | `DSCSM048.EXE` | `CRGRO048` |
| `MWH` | Wheat | `DSCSM048.EXE` | `CSCER048` |
| `MRI` | Rice | `DSCSM048.EXE` | `RICER048` |
| `MPT` | Potato | `DSCSM048.EXE` | `PTSUB048` |
| `MCS` | Cassava | `DSCSM048.EXE` | `CSYCA048` |

**Example:**
```
MCB C: \DSSAT48 DSCSM048.EXE CRGRO048
```
This means: Crop code `CB` (Cabbage) uses executable `DSCSM048.EXE` with model `CRGRO048`.

#### 3. Crop Directory Mappings (XXD codes)

These specify where experiment files are stored for each crop:

| Code | Crop | Directory |
|------|------|-----------|
| `ALD` | Alfalfa | `C: \DSSAT48\ALFALFA` |
| `BAD` | Barley | `C: \DSSAT48\BARLEY` |
| `CBD` | Cabbage | `C: \DSSAT48\CABBAGE` |
| `MZD` | Maize | `C: \DSSAT48\Maize` |
| `SBD` | Soybean | `C: \DSSAT48\Soybean` |
| `WHD` | Wheat | `C: \DSSAT48\Wheat` |
| `RID` | Rice | `C: \DSSAT48\Rice` |
| `PTD` | Potato | `C: \DSSAT48\POTATO` |
| `CSD` | Cassava | `C: \DSSAT48\CASSAVA` |

**Example:**
```
CBD C: \DSSAT48\CABBAGE
```
This means: Cabbage experiment files (`.CBX`) are stored in `C:\DSSAT48\CABBAGE\`.

### How DSSATPRO.v48 Works

#### 1. Directory Resolution

When DSSAT needs to find a file, it uses the directory paths from `DSSATPRO.v48`:

```
Experiment File needs weather file "ACNM1301"
  └─> Reads DSSATPRO.v48
      └─> Finds WED (Weather directory): C: \DSSAT48\Weather
          └─> Looks for: C:\DSSAT48\Weather\ACNM1301.WTH
```

#### 2. Crop Model Resolution

When an experiment file specifies a crop code, DSSAT uses the model mapping:

```
Experiment File: UHIH1201.CBX
  └─> Crop Code: CB (from *CULTIVARS section)
      └─> Reads DSSATPRO.v48
          └─> Finds MCB: DSCSM048.EXE CRGRO048
              └─> Uses model CRGRO048
                  └─> Loads: CBGRO048.CUL, CBGRO048.ECO, CBGRO048.SPE
```

#### 3. Experiment File Location

DSSAT knows where to look for experiment files based on crop directory mappings:

```
User runs: dscsm048.exe A UHIH1201.CBX
  └─> Determines crop from file extension (.CBX = Cabbage)
      └─> Reads DSSATPRO.v48
          └─> Finds CBD: C: \DSSAT48\CABBAGE
              └─> Looks for: C:\DSSAT48\CABBAGE\UHIH1201.CBX
```

### Complete Flow Example

Here's how all the pieces work together:

```
1. User Command:
   cd C:\DSSAT48\Cabbage
   dscsm048.exe A UHIH1201.CBX

2. DSSAT reads DSSATPRO.v48:
   - Finds CBD: C:\DSSAT48\CABBAGE (experiment file location)
   - Finds MCB: DSCSM048.EXE CRGRO048 (model mapping)
   - Finds WED: C:\DSSAT48\Weather (weather directory)
   - Finds SLD: C:\DSSAT48\SOIL (soil directory)
   - Finds CRD: C:\DSSAT48\GENOTYPE (cultivar directory)

3. DSSAT loads experiment file:
   C:\DSSAT48\CABBAGE\UHIH1201.CBX

4. From experiment file, DSSAT reads:
   - WSTA: ACNM1301 → Looks in WED → C:\DSSAT48\Weather\ACNM1301.WTH
   - ID_SOIL: UHIH150004 → Looks in SLD → C:\DSSAT48\SOIL\*.SOL
   - CR: CB, INGENO: 990003 → Uses MCB model → Looks in CRD → C:\DSSAT48\GENOTYPE\CBGRO048.CUL

5. All files loaded, simulation runs
```

### Modifying DSSATPRO.v48

#### Changing Directory Paths

If you install DSSAT in a different location, update the paths:

```
# Original
DDB C: \DSSAT48
WED C: \DSSAT48\Weather

# Modified (if installed to D:\MyDSSAT)
DDB D: \MyDSSAT
WED D: \MyDSSAT\Weather
```

#### Adding New Crops

To add a new crop, add entries for:
1. Model mapping (MXX)
2. Directory mapping (XXD)

```
# Example: Adding a new crop "XY" with model "XYMODEL048"
MXY D: \DSSAT48 DSCSM048.EXE XYMODEL048
XYD D: \DSSAT48\XYCROP
```

#### Changing Crop Directories

To change where experiment files are stored:

```
# Original
CBD C: \DSSAT48\CABBAGE

# Modified
CBD D: \MyData\CabbageExperiments
```

### Platform-Specific Files

- **Windows:** `DSSATPRO.v48` - Uses Windows paths (`C: \DSSAT48`)
- **Linux/Unix:** `DSSATPRO.L48` - Uses Unix paths (`/usr/local/dssat`)

The Linux version is generated from `DSSATPRO.L48.in` during CMake configuration.

### Important Notes

1. **Path Format:** Windows paths use format `C: \DSSAT48` (note the space after the colon). This is the DSSAT convention.

2. **Case Sensitivity:** On Linux, paths are case-sensitive. On Windows, they're typically not, but DSSAT may be case-sensitive in some contexts.

3. **Default Path:** If `DSSATPRO.v48` is missing, DSSAT uses hardcoded defaults (typically `C:\DSSAT48\` on Windows).

4. **Model Codes:** The model code in `DSSATPRO.v48` must match:
   - The model code in experiment file simulation controls (`SMODEL`)
   - The cultivar file naming (e.g., `CRGRO048` → `CBGRO048.CUL`)

5. **File Location:** `DSSATPRO.v48` must be in the DSSAT root directory (same location as the executable or as specified in the code).

### Troubleshooting DSSATPRO.v48 Issues

#### Issue: "DSSATPRO.v48 not found"

**Solution:**
- Ensure `DSSATPRO.v48` exists in the DSSAT root directory
- Check that the file is not corrupted
- Verify file permissions allow reading

#### Issue: "Directory not found" errors

**Solution:**
- Check all directory paths in `DSSATPRO.v48` exist
- Verify paths use correct format (space after colon on Windows)
- Ensure directories are accessible

#### Issue: "Model not found" errors

**Solution:**
- Verify crop model mapping exists in `DSSATPRO.v48`
- Check that model code matches cultivar file naming
- Ensure executable path is correct

#### Issue: "Experiment file not found"

**Solution:**
- Verify crop directory mapping (XXD) exists in `DSSATPRO.v48`
- Check that the directory path is correct
- Ensure experiment file is in the specified directory

## Additional Notes

1. **File Extensions:** DSSAT is case-sensitive on some systems. Always use uppercase extensions (`.WTH`, `.SOL`, `.CUL`, etc.)

2. **Profile IDs:** Soil profile IDs can be in any `.SOL` file. DSSAT searches all `.SOL` files to find the matching profile.

3. **Model Codes:** The model code in simulation controls (`SMODEL`) determines which cultivar/ecotype/species files to use. Common codes:
   - `CRGRO048` - CROPGRO model v4.8
   - `MZCER048` - CERES Maize v4.8
   - `MZIXM048` - IXIM Maize v4.8
   - `WHAPS048` - APSIM Wheat v4.8
   - `CSCER048` - CERES Wheat/Barley v4.8

4. **Date Formats:** DSSAT uses YYDDD format (2-digit year + 3-digit day of year):
   - `13015` = Day 15 of year 2013 (January 15, 2013)
   - `12135` = Day 135 of year 2012 (May 14, 2012)

5. **Missing Files:** If a referenced file is missing, DSSAT will generate an error. Always verify all referenced files exist before running simulations.

6. **DSSATPRO.v48 Priority:** DSSATPRO.v48 takes precedence over hardcoded paths. Always check this file first when troubleshooting path-related issues.

