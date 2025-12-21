# How to Run DSSAT-CSM Simulations

This guide explains how to run simulations using the compiled DSSAT-CSM executable.

## Prerequisites

- DSSAT-CSM executable: `build\bin\dscsm048.exe`
- Experiment files (`.MZX`, `.SBX`, `.ALX`, etc.) in the appropriate crop directories
- Weather files referenced by experiment files
- Soil files referenced by experiment files
- DSSAT data directory structure (typically `C:\DSSAT48\`)

## Basic Command Syntax

```
dscsm048.exe [model] <runmode> [argA] [argB] [control_file]
```

### Parameters

- **model** (optional): 8-character crop model name (e.g., `MZCER048`, `WHAPS048`)
- **runmode** (required): Single character run mode code
- **argA**: First argument (varies by run mode)
- **argB**: Second argument (varies by run mode)
- **control_file** (optional): Path to simulation control file (e.g., `DSCSM048.CTR`)

## Run Modes

| Mode | argA | argB | Description |
|------|------|------|-------------|
| **A** | FileX | NA | All: Run all treatments in the specified FileX |
| **B** | BatchFile | NA | Batch: Batchfile lists experiments and treatments |
| **C** | FileX | TrtNo | Command line: Run single FileX and treatment # |
| **D** | TempFile | NA | Debug: Skip input module and use existing TempFile |
| **E** | BatchFile | NA | Sensitivity: Batchfile lists FileX and TrtNo |
| **F** | BatchFile | NA | Farm model: Batchfile lists experiments and treatments |
| **G** | FileX | TrtNo | Gencalc: Run single FileX and treatment # |
| **I** | NA | NA | Interactive: Interactively select FileX and TrtNo |
| **L** | BatchFile | NA | Gene-based model (Locus): Batchfile for FileX and TrtNo |
| **N** | BatchFile | NA | Seasonal analysis: Batchfile lists FileX and TrtNo |
| **Q** | BatchFile | NA | Sequence analysis: Batchfile lists FileX & rotation # |
| **S** | BatchFile | NA | Spatial: Batchfile lists experiments and treatments |
| **T** | BatchFile | NA | Gencalc: Batchfile lists experiments and treatments |
| **Y** | BatchFile | NA | Yield forecast mode uses ensemble weather data |

## Running Simulations

### Method 1: Run All Treatments in an Experiment File (Mode A)

**Recommended approach for single experiment files**

1. Navigate to the crop directory containing your experiment file:
   ```powershell
   cd C:\DSSAT48\Maize
   ```

2. Run the simulation using just the filename (not full path):
   ```powershell
   C:\dssat-csm-os\build\bin\dscsm048.exe A EBPL8501.MZX
   ```

**Important Notes:**
- Must run from the crop directory (e.g., `C:\DSSAT48\Maize`)
- Use only the filename, not the full path
- The experiment file must be in the current directory

**Example Output:**
```
RUN    TRT FLO MAT TOPWT HARWT  RAIN  TIRR   CET  PESW  TNUP  TNLF   TSON TSOC
           dap dap kg/ha kg/ha    mm    mm    mm    mm kg/ha kg/ha  kg/ha t/ha
  1 MZ   1  82 159 11231  4461  1089     0   507     4   115    47  11986  120
  2 MZ   2  82 159 16582  6734  1089     0   508     2   225    63  12051  121
```

### Method 2: Run Single Treatment (Mode C)

Run a specific treatment number from an experiment file:

```powershell
cd C:\DSSAT48\Maize
C:\dssat-csm-os\build\bin\dscsm048.exe C EBPL8501.MZX 1
```

This runs treatment #1 from the experiment file.

### Method 3: Batch Mode (Mode B)

Run multiple experiments listed in a batch file:

```powershell
cd C:\DSSAT48
C:\dssat-csm-os\build\bin\dscsm048.exe B BatchFiles\Maize.v48
```

**Note:** Batch files must have correct paths to experiment files. Update paths in batch files if needed.

### Method 4: Interactive Mode (Mode I)

Interactively select experiment files and treatments:

```powershell
cd C:\DSSAT48
C:\dssat-csm-os\build\bin\dscsm048.exe I
```

Follow the on-screen prompts to select files and treatments.

## Common Issues and Solutions

### Issue 1: "File not found" Error

**Problem:** Path is truncated (e.g., shows `C:\DSSAT48\M` instead of full path)

**Solution:**
- Navigate to the crop directory first
- Use only the filename, not the full path
- Example:
  ```powershell
  cd C:\DSSAT48\Maize
  dscsm048.exe A EBPL8501.MZX
  ```

### Issue 2: Missing Experiment Files

**Problem:** No experiment files (`.MZX`, `.SBX`, etc.) in directories

**Solution:**
- Download the DSSAT data repository: https://github.com/DSSAT/dssat-csm-data
- Or create experiment files using the DSSAT GUI
- Ensure files are in the correct crop directories (e.g., `C:\DSSAT48\Maize\`)

### Issue 3: Missing Weather or Soil Files

**Problem:** Simulation fails due to missing weather or soil data

**Solution:**
- Ensure weather files (`.WTH`) are in `C:\DSSAT48\Weather\`
- Ensure soil files (`.SOL`) are in `C:\DSSAT48\Soil\`
- Check that experiment file references are correct

### Issue 4: Wrong Working Directory

**Problem:** DSSAT can't find required data files

**Solution:**
- Always run from the appropriate directory
- For single experiments: run from the crop directory
- For batch files: run from `C:\DSSAT48\` or the directory containing the batch file

## Output Files

After running a simulation, DSSAT generates several output files:

- **Summary.OUT**: Summary of simulation results
- **Overview.OUT**: Overview of all simulations
- **WARNING.OUT**: Warnings and error messages
- **Evaluate.OUT**: Evaluation statistics (if enabled)
- **PlantGro.OUT**: Daily plant growth data (if enabled)
- **Weather.OUT**: Weather data used (if enabled)
- **SoilNi.OUT**: Soil nitrogen data (if enabled)
- **WaterBal.OUT**: Water balance data (if enabled)

Output files are typically created in the same directory where you run the simulation.

## Using Control Files

You can specify simulation controls using a control file:

```powershell
cd C:\DSSAT48\Maize
C:\dssat-csm-os\build\bin\dscsm048.exe A EBPL8501.MZX Data\DSCSM048.CTR
```

The control file (`DSCSM048.CTR`) allows you to:
- Set output options
- Control simulation methods
- Override experiment file settings
- Specify verbosity levels

See `Data\DSCSM048.CTR` for available control options.

## Examples

### Example 1: Run All Treatments in Maize Experiment
```powershell
cd C:\DSSAT48\Maize
C:\dssat-csm-os\build\bin\dscsm048.exe A EBPL8501.MZX
```

### Example 2: Run Single Treatment with Model Specification
```powershell
cd C:\DSSAT48\Maize
C:\dssat-csm-os\build\bin\dscsm048.exe MZCER048 C EBPL8501.MZX 2
```

### Example 3: Run Batch File
```powershell
cd C:\DSSAT48
C:\dssat-csm-os\build\bin\dscsm048.exe B BatchFiles\Maize.v48
```

### Example 4: Run with Control File
```powershell
cd C:\DSSAT48\Maize
C:\dssat-csm-os\build\bin\dscsm048.exe A EBPL8501.MZX C:\dssat-csm-os\Data\DSCSM048.CTR
```

## Tips

1. **Always check WARNING.OUT** after running simulations for any issues
2. **Use relative paths** when possible - run from the appropriate directory
3. **Verify file paths** in batch files match your directory structure
4. **Check output files** to ensure simulations completed successfully
5. **Use Mode I (Interactive)** when unsure about file locations or names

## Directory Structure

Typical DSSAT directory structure:
```
C:\DSSAT48\
├── Maize\
│   └── *.MZX (experiment files)
├── Wheat\
│   └── *.WHX (experiment files)
├── Soybean\
│   └── *.SBX (experiment files)
├── Weather\
│   └── *.WTH (weather files)
├── Soil\
│   └── *.SOL (soil files)
├── Genotype\
│   ├── *.CUL (cultivar files)
│   ├── *.ECO (ecotype files)
│   └── *.SPE (species files)
└── BatchFiles\
    └── *.v48 (batch files)
```

## Additional Resources

- DSSAT Documentation: https://dssat.net/
- DSSAT Data Repository: https://github.com/DSSAT/dssat-csm-data
- DSSAT Forum: https://groups.google.com/g/dssat-model

