# Running Multiple DSSAT Experiments at Once

## Using DSSBatch.v48 File

### Quick Guide

1. **Create/Edit DSSBatch.v48** in your experiment folder (e.g., `C:\DSSAT48\Lettuce\DSSBatch.v48`)

2. **Format:**
```
$BATCH(LETTUCE)
!
! Directory    : C:\DSSAT48\Lettuce
! Crop         : Lettuce
!
@FILEX                                                                                        TRTNO     RP     SQ     OP     CO
C:\DSSAT48\Lettuce\UFGA2401.LUX                                                                   1      1      0      1      0
C:\DSSAT48\Lettuce\UFGA2402.LUX                                                                   1      1      0      0      0
```

3. **Run Command:**
```bash
cd C:\DSSAT48\Lettuce
C:\dssat-csm-os\build\bin\dscsm048.exe B DSSBatch.v48
```

### Column Meanings
- **TRTNO**: Treatment number (1 = all treatments, or specific treatment number)
- **RP**: Number of replications (1 = single run)
- **SQ**: Sequence mode (0 = off)
- **OP**: Output options (0 = summary, 1 = detailed)
- **CO**: Continue on error (0 = stop on error)

### Example Output Location
Output files will be in: `C:\DSSAT48\Lettuce\`
- `UFGA2401.OUT`, `UFGA2402.OUT` (detailed output)
- `PlantGro.OUT`, `Summary.OUT` (summary files)

---
*Both experiments run sequentially in a single command*
