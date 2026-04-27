**Flexible I/O: An input and storage of internal data to enhance the
capacity of the next generation of crop models**

Fabio A. A. Oliveira^1^, Willingthon Pavan^1^, Felipe de Vargas and
Gerrit Hoogenboom^1,2^

1.  **Material and Methods**

    a.  **Design of Flexible I/O**

A modular flexible data input was designed to process and store data
using a mix of object-oriented programming (OOP) and functional
programming (FP) paradigms visioning modularity, code reusability,
scalability and maintenance of Flexible I/O's source code. OOP
encapsulates the data and functions into objects that ensure data
integrity restricting direct access and modifying data only through
controlled methods usually called 'getters' and 'setters', while FP
builds more reusable and flexible code without hard links between
several different components. The goal was to create a simple,
structured and flexible software design that can evolve across different
crop modeling platforms.

The functionalities of Flexible I/O are described in Figure 1, with
three main individual packages containing individual classes/functions.
It includes data storage, management and input functions to manipulate
information from input files/interfaces and connect between different
programming languages. The Unified Modeling Language (UML) was used to
identify Flexible I/O's requirements, attributes and behaviors and
graphical visualization of the design. Figure 1 (see supplementary
material Figure S1 for full diagram developed for DSSAT-CSM), shows a
simplified conceptual UML diagram where groups of classes are separated
by packages. Classes are represented in boxes compartments, with the
name on top, attributes are defined in the middle, with its respective
visibility of public (+), private (-) or protected (#), followed by
variable name, arguments and return type. Functions that represent the
behavior of the class/function are represented in the bottom, following
the same rules to define attributes. Single functions are represented
with a custom stereotype (\<\<function\>\>). Dashed class boxes
compartments represent future classes/functions that can be implemented
by demand. Relationships are defined with arrows pointing to the purpose
played by that class.

*FlexibleIO* was designed as the main central class, responsible for
managing data storage. Data is stored/retrieved from hash table
functions that can be accessed based on unique key-value pairs. It works
by applying a hashing function to every item enabling fast lookups,
insertions, and deletions. Hash tables remove the needs of iterating
through explicit loops and have an average constant-time complexity. As
shown in *FlexibleIO* class there are three main hash tables to store
and later retrieve the data: *data_map_2D* has only one unique key;
*date_map_3D* has two unique keys; *date_map_4D* has three unique keys;
*FlexibleIO* is instantiated as singleton, which means that only one
instance of this class exists in computer memory. The reason why
singleton is to optimize the resource usage and maintain the data in one
place during the whole runtime of Flexible I/O. Methods in this class
are mainly public access to create/retrieve instances, getters and
setters to get/set data and one method to delete the data stored based
on a key provided.

The input functions, e.g. *ReadFileDataWithFlexibleIO* are defined for
reading and parsing data based on type of file and/or application needs.
Flexible I/O allows unlimited input functions that can be customized and
expanded as the main system grows. Input functions are associated with
*FlexibleIO* for reference to get/set data*.* While Interfaces serve as
intermediaries between Flexible I/O and the main system. Their primary
function is to establish communication with any component/system linked
with Flexible I/O. For example, a crop model written in Fortran with
*FlexibleIO* embedded could implement a *Fortran_Interface*, include the
routine in the system and call its methods. Interfaces were designed to
be flexible and ensure that the choice stays with the core developers to
add attributes and functions as needed (e.g. Fig. 1, *Fortran_Interface*
written in Fortran and *Cpp_Interface* written in C++ implement
*FlexibleIO* methods). Interfaces and data storage classes have a
dependency relationship because the two ends can be temporary or
restricted to a single method.

b.  **Implementation and execution flow of Flexible I/O**

Flexible I/O was developed using C++ (Stroustrup, 2013), which is a
general-purpose programming language that supports multi-paradigm
approaches such as procedural, functional, modular and object-oriented.
C++ is a compiled language, designed for systems that require
performance, efficiency and flexibility. In addition, C++ has
capabilities that allow integration with other programming languages
(e.g. Python, Java, JavaScript and Fortran). Flexible I/O's source code
can be used in two ways, as a standalone application or included as a
library in the main application to be executed. In case of standalone
application, the developer needs to write a C++ main program following
the same design of the input functions. Including as a library the
source code needs to be compiled and linked with the main application.

As illustrated in Figure 2, a UML sequence diagram that defines the
event sequences from a Fortran main program to parse an input file and
retrieve data. *Fortran_Interface, Read_Function and FlexibleIO* are
represented by a box on the top with a dashed vertical line showing the
life of the class/function. They are lifelines that represent the roles
or object instances during the execution of the program. The main
program starts the call to read an input file with data. First, it calls
the *readDataWithFlexibleIO* function, represented by an arrow in the
diagram and solid arrowhead meaning synchronous call. After the call, a
thin rectangle on top of the dashed lifeline shows an execution
occurrence of the *Fortran_Interface*. Then, the interface calls
*readDataFromFile* implemented by the *Read_function*. Next,
*readDataFromFile* gets an instance of *FlexibleIO* with *getInstance*
function, if existing, otherwise creates a new instance of *FlexibleIO,*
and returns to *readDataFromFile* the reference (denoted by dashed
arrow). *readDataFromFile* can parse the input file and use *setData*
methods from *FlexibleIO* to store data. This process continues looping
in *readDataFromFile* until the end of the file or any other event that
could be triggered to stop the data processing. Lastly, when
*readDataFromFile* finishes, it sends a message back to the
*Fortran_Interface* ending the execution and returning to the main
program.

The main program continues its execution normally until it reaches the
point where more data is needed. This can be right after the
*readDataWithFlexibleIO* or any other distinct point of the runtime. The
main program calls *getData* from *Fortran_Interface* sending a unique
key identifier and its arguments. Then, *Fortran_Interface* access
straight to the *FlexibleIO* getters' that searches in the respective
hash table and return the data. Finally, the main application receives
the data and continues its execution flow.

c.  **Integration of Flexible I/O into DSSAT-CSM for weather data
    management**

The CSM is described by Hoogenboom et al. (2019) as the main engine of
DSSAT. It holds the core functions in Fortran 77/90/95 of the models and
input/output modules. Flexible I/O was incorporated using the library
approach compiled into a single CSM executable. Then, a Fortran
interface was built to connect with the CSM. The DSSAT-CSM has several
input files for running a single simulation where the main ones are
experimental (FileX), soil (FileS), weather (FileW) and genetics, other
configuration/utility are present and distributed with the installation.
For this work, the weather input (FileW) was chosen due to the
importance in representing biophysical processes that drive many
components in the crop model such as vegetative, reproductive
development, photosynthesis, respiration and many others.

FileW in DSSAT-CSM is processed through a subroutine called *IPWTH* that
parses ASCII files with the ICASA standard (White et al., 2013) based on
fixed format file adopted by the DSSAT community (e.g. Figure 3). In
another words, this function reads line by line of FileW with a fixed
number of characters for each weather variable based on the header
aligment denoted by @ symbol. Then, data is stored in arrays which are
iterated to retrieve the daily weather measurement. To include Flexible
I/O source code changes were made in *IPWTH* subroutine to parse the
weather file.

In addition to standard FileW and following the same file structure, two
new FileW formats were added with Flexible I/O. First, comma-separated
values (csv) files that represent one of the most widely used formats
for data exchange, particularly for researchers and stakeholders working
with spreadsheet or database systems in the agricultural area. Second,
the hourly FileW for CSM processes, whereas a daily time-step crop model
with some processes such as energy balance require hourly resolution. In
this case, DSSAT-CSM has subroutines (developed about 20 years ago)
responsible for estimate hourly values of daily weather measurements
from FileW.

Additionally, to FileW, DSSAT FileX's define weather methods in its
simulation controls configuration. Weather methods are switches for
configuration and change the type of FileW that the CSM will process.
The standard implemented switches are 'M' for standard measured data and
'G or S' for generated internally weather data. New switches were added
for csv and hourly inputs as they are not supported by the CSM.

d.  **Evaluation of system performance**

To evaluate the performance of Flexible I/O a series of comparative
simulations within different case studies were performed. The goal is to
quantify the impact of Flexible I/O on performance and simulation
accuracy. Two versions of the CSM were built for this analysis. First,
the original-DSSAT-CSM (OCSM) as baseline, which represents the current
CSM version 4.8.5.32[^1]. FlexibleIO-DSSAT-CSM (FIOCSM) which represents
the same version 4.8.5.32 with Flexible I/O[^2] incorporated for weather
data management. Three case studies were built for single season
experimental simulation, applications and hourly weather management.
Experimental, weather, soil and genetics datasets, as well as
configuration files from installation are publicly available through the
DSSAT release[^3] (Hoogenboom et al. 2024) or GitHub repository[^4].
Simulated and observed data for leaf area index (LAI), biomass (kg/ha)
and grain weight (kg/ha) were measured root mean square error (RMSE) and
index of agreement (d-statistic), as shown in Eq. 1 and Eq. 2:

$RMSE\mathbf{=}\ \sqrt{\left( \frac{1}{n} \right)\sum_{i = 1}^{n}\left( y_{i} - {\widehat{y}}_{i} \right)^{2}}$
(1)

$d\mathbf{=}\ 1 - \left\lbrack \frac{\sum_{i = 1}^{n}\left( y_{i} - {\widehat{y}}_{i} \right)^{2}}{\sum_{i = 1}^{n}{|\left( {\widehat{y}}_{i} - z| + |y_{i} - z| \right)}^{2}} \right\rbrack$
, 0 ≤ *d* ≤ 1 (2)

where $y_{i}$ and ${\widehat{y}}_{i}$ represent the *i^th^* observed and
simulated yield, respectively and *z* average from observed values. For
RMSE lower values indicate a better fit to the observed data while
higher values indicate larger amount of error between predictions and
observations. D-statistic were also used to compare the variability
within the simulated time series and observed data for the growing
season. The index varies from 0 to 1, where 0 shows no agreement and 1
perfect agreement between simulated and observed data. Simulations were
performed in a Windows 11 Home operating system with AMD Ryzen 5 3600
6-Core Processor. A bash script was developed to compute elapsed time of
a command line for each experiment of the case studies. The final
runtime was averaged after 30 runs for better accuracy.

2.  **Results**

    a.  **Integration of Flexible I/O into DSSAT-CSM**

The first step was to integrate Flexible I/O as a library within the CSM
source code, which was then compiled to generate a single executable. A
Fortran interface was developed to establish the connection between CSM
and Flexible I/O. All public functions in the *FlexibleIO* class were
implemented in this interface to manage weather data. New input
functions were developed, including *READ_WTH_Y2_4K* to parse measured
data with two- or four-digit year representations, *READ_WTH_CSV* to
parse data in CSV format, and *READ_WTH_HOURLY* to handle hourly
weather. In addition to these functions, new weather methods were
created to switch between daily weather data stored in CSV files
(identified by the letter 'C') and hourly weather data files (identified
by the letter 'H'). Both new file formats follow the same FileW
structure and adhere to ICASA standards for weather data storage. The
CSV files also changed their extension from .WTH to .CSV (Figure 4 and
Figure 5). Figure 6 presents the final simplified structure of OCSM
(A) and FIOCSM (B) with Flexible I/O fully implemented.

Source code modifications to incorporate Flexible I/O into DSSAT-CSM
were made in two subroutines. The first was the *IPWTH* subroutine,
which manages weather input. The implemented changes (Supplementary
material - source code *IPWTH*), start with *USE flexibleio* statement
includes the Fortran interface to establish the connection with Flexible
I/O routines. Based on the selected weather method, the corresponding
input functions describe above are invoked to parse FileW. Once the data
has been parsed and stored in memory, getter functions are invoked to
retrieve the required weather variables for the model. For example,
the *CALL fio % get(\'WTH\', YRDOY, \'SRAD\', SRAD)* retrieves the solar
radiation (SRAD) value for a specific year and day of year (YRDOY).
Here, *fio* refers to the Fortran interface module, and
the *get* function uses an argument list where the first key *'WTH'*
specifies the data group (matches what was stored by Flexible I/O and
can be changed for other groups as needed), the second key *YRDOY*
identifies the date, and the third *'SRAD'* defines the weather variable
to be retrieved. After executing the necessary Flexible I/O calls, the
CSM continues its normal operation until another Flexible I/O routine is
invoked.

The same approach used to integrate Flexible I/O into
the *IPWTH* subroutine was applied to the *HMET* subroutine, which
handles hourly weather data (Supplementary material - source code
*HMET*). In this case, the get call includes an additional key argument
after *YRDOY *to specify the hour for which the weather variable is
retrieved. Unlike *IPWTH*, there is no need for an input function call
within *HMET*, because *IPWTH* calls *READ_WTH_HOURLY* before to store
hourly data in memory. In addition, to this hourly input function, since
the main CSM program operates on a daily time-step, another subroutine
called *HR2DLY* (Supplementary material - source code *HR2DLY*) was
developed to aggregate hourly data back into daily values. This
conversion ensures that the model runs smoothly without triggering
missing weather data errors.

b.  **Case Study**

    i.  **Case 1. Experimental**

Daily ASCII weather files have long been the standard input format in
DSSAT-CSM, making them a fundamental test case for validating the
Flexible I/O system. For this validation, three datasets included in the
default DSSAT installation were used, each representing a single growing
season for different crops. The first dataset corresponds to a maize
experiment (UFGA8201.MZX) conducted in Gainesville, Florida, in 1982,
which included six treatments combining rainfed, irrigated, and
vegetative stress for low and high nitrogen levels. The second dataset
is a soybean experiment (LQPI1602.SBX), conducted in Piracicaba, Brazil,
during the 2016--2017 and 2017--2018 growing seasons, with eight
treatments varying two evapotranspiration models and soil evaporation
methods to assess crop water productivity (da Silva et al., 2022). The
third dataset represents a cotton experiment (AZMC8901.COX) conducted in
Maricopa, Arizona, in 1989, which included two treatments evaluating
cotton growth under different atmospheric CO₂ concentration levels
(Kimball et al., 2022).

Weather inputs in DSSAT-CSM can be organized in three different
ways: single year/single file, single year/multiple files, or multiple
years/single file. In this study, the maize dataset stores weather data
as a single year/single file (UFGA8201.WTH), the soybean dataset as
single year/multiple files (PIR21601.WTH, PIR21701.WTH, PIR21801.WTH),
and the cotton dataset as multiple years/single file (AZMC8932.WTH).

An example of FileW content is shown in Figure 3,
where UFGA8201.WTH contains site-specific information including station
code (INSI), latitude (LAT), longitude (LONG), elevation (ELEV), average
annual temperature (TAV), temperature amplitude (AMP), reference height
for weather measurements (REFHT), and reference height for wind speed
(WNDHT). It also includes daily measured data for solar radiation
(SRAD), maximum temperature (TMAX), minimum temperature (TMIN), rainfall
(RAIN). These are the minimum required weather measurements to run a
simulation (Tsuji et al., 1998). Additional weather measurements are
also provided for UFGA8201.WTH with photosynthetically active radiation
(PAR).

Daily weather data for this site are available for the entire year of
1982. However, the CSM defines the start of the simulation period FileX,
that determines the date from which data and model computations begin to
simulate crop growth and development. For the maize, the simulation
start date is set to February 25, 1982, meaning that weather data
from January 1 to February 24, 1982, are excluded during the input
process. Flexible I/O must therefore handle this data filtering
automatically to ensure consistency with the original model's simulation
setup.

Performance tests confirmed that OCSM, FIOCSM, and FIOCSM_CSV produced
identical results for RMSE and d-statistic for leaf area index (LAI),
biomass (kg ha⁻¹) and grain weight (kg ha⁻¹) as shown in Table 1.
However, runtime performance differed among implementations. For
the maize, the runtime for a single treatment using OCSM with
the CERES-Maize model ranged from approximately 0.202 to 0.208 seconds
(s). The FIOCSM version exhibited an average increase of about 0.110s
relative to OCSM, while FIOCSM_CSV showed an additional increase of
roughly 0.005s compared to FIOCSM. When all treatments were executed,
the total runtimes were 0.854s, 1.014s, and 1.269s for OCSM, FIOCSM, and
FIOCSM_CSV, respectively.

For the soybean experiment, runtime for a single treatment
using OCSM with the CROPGRO-Soybean model (Boote et al., 1998) ranged
from 0.255s to 0.274s. On average, FIOCSM increased runtime by
about 0.145s compared to OCSM, while FIOCSM_CSV added an
additional 0.072s relative to FIOCSM. The average total runtimes for all
treatments were 1.560s, 2.513s and 2.894s for OCSM, FIOCSM, and
FIOCSM_CSV, respectively. Runtime consistency was maintained between
single-treatment and all-treatment executions, with proportional
increases across models.

For the cotton experiment, a single treatment using OCSM with
the CROPGRO-Cotton model required between 0.335s and 0.347s. In this
case, FIOCSM exhibited a substantially higher average runtime,
increasing by 3.918s, while FIOCSM_CSV showed an
additional 0.485s increase compared to FIOCSM. The average total
runtimes for all treatments were 0.554s, 4.581s and 5.373s for OCSM,
FIOCSM, and FIOCSM_CSV, respectively. Despite the larger overhead
observed for cotton, runtime patterns between single and all-treatment
runs remained consistent with those from the previous experiments.

ii. **Case 2. Applications**

Applications embedded within the default DSSAT installation enable users
to explore and construct a wide range of real-world scenario analyses
(Hoogenboom et al., 2019; Boote et al., 2025). For this case study, the
main DSSAT applications were included, such as sequence analysis, which
evaluates crop rotations under varying weather uncertainties and
accounts for long-term carry-over effects on soil properties within the
system. Seasonal analysis was also employed for uncertainty and risk
assessment by simulating long-term historical weather records. In
addition, forecast applications were used to estimate in-season yield
forecasts by incorporating observed weather data to predict the
remaining portion of the growing season.

Table 2 summarizes the application experiments conducted. The first
sequence experiment (CHMC0012.SQX) simulates a winter wheat (cover
crop)-cotton rotation system in Chillicothe, Texas (Adhikari et al.,
2017). The second sequence experiment (MSKB8901.SQX), conducted at the
Kellogg Biological Station Long-Term Ecological Research site,
represents a corn--soybean rotation under conventional tillage with high
input management. The seasonal analysis experiment (UAFD7465.SNX)
evaluates the effects of plant density and nitrogen application rates on
rice growth in Faisalabad, Pakistan, over a 30-year period (1974--2003).
For this case, only one plant density level (13 treatments) was
simulated to prevent repetitive results. Finally, the forecast
experiment (CAPE2002.FCX) simulates in-season yield forecasting for a
hypothetical wheat field in Petropavl, Kazakhstan, during 2020. The
experiment includes three treatments with a common simulation start date
of January 1, 2020, while forecasting begins on June 1, July 1,
and August 1, 2020, for treatments 1, 2, and 3, respectively.

Performance results indicate that for the sequence experiment
CHWC0012.SQX, the average runtimes for OCSM, FIOCSM,
and FIOCSM_CSV were 3.444s, 4.262s, and 4.406s, respectively. Similarly,
for MSKB8901.SQX, the corresponding runtimes were 4.005s, 4.620s,
and 4.803s. These results are consistent with the single experiment case
study where FIOCSM exhibited a moderate increase in runtime relative to
OCSM, FIOCSM_CSV consistently presented the highest average runtime. For
the seasonal application experiment (UAFD7465.SNX), the average runtime
ranged from approximately 4.726s to 5.316s per single treatment. On
average, FIOCSM required an additional 3.372s compared to OCSM,
while FIOCSM_CSV increased runtime by approximately 0.356s relative to
FIOCSM. In the forecast application (CAPE2002.FCX), the runtime
for OCSM ranged from 5.233s to 5.274s for a single forecast
treatment. FIOCSM showed an average increase of 4.784s compared to OCSM,
and FIOCSM_CSV required an additional 0.576s relative to FIOCSM.
Overall, the runtime behavior across all application experiments
followed the same trend observed in the experimental case study,
where OCSM exhibited the fastest performance, followed by FIOCSM,
with FIOCSM_CSV being the slowest.

iii. **Case 3. Hourly weather input**

This case aimed to extend DSSAT-CSM capabilities and evaluate the
performance of both the model and the Flexible I/O using hourly weather
inputs. Following the same approach as Case 1 (single season runs), two
experiments were selected based on the availability of hourly weather
data from external sources, since DSSAT itself does not include hourly
datasets. The first experiment, Carinata (UFJA1803.BCX), was conducted
in Jay, Florida, during the 2018--2019 growing season and included five
treatments evaluating different nitrogen application rates. Weather data
for this site were obtained from the Florida Automated Weather Network
(FAWN), which provides observations at 15-minute intervals (Peeling et
al., 2023). Data corresponding to the FileX growing seasons were
aggregated into hourly values and formatted into a standard
DSSAT-compatible weather file following ICASA conventions (Figgure 5).
This hourly weather dataset was used exclusively as input for Flexible
I/O. The second experiment, Cotton (GACM0401.COX), was conducted in
Camilla, Georgia, in 2004, and included two treatments comparing
irrigated and rainfed conditions. Hourly weather data for this site were
obtained from the University of Georgia Weather Network, which similarly
provides data in 15-minute intervals with complete coverage for the
growing season.

Figure 5 illustrates the FileW structure used for hourly weather inputs
in Flexible I/O. The only difference between daily and hourly files lies
in the *DATE* column, where each line corresponds to an hourly
observation represented by the year and day of year, followed by the
hour separated by a dash (e.g., YYYYDOY--HH).

Performance tests indicated that FIOCSM could not reproduce identical
results to OCSM (Table 3). In the Carinata experiment
(UFJA1803.BCX) using the CROPGRO-Carinata model, FIOCSM produced
slightly higher RMSE values for leaf area index (LAI) and biomass
compared to OCSM. The d-statistic also confirmed a minor decrease in
agreement for FIOCSM relative to OCSM. Runtime performance showed that
OCSM averaged approximately 0.256s, while FIOCSM required 3.117s per
run. When all treatments were executed, the average runtimes were 1.058s
for OCSM and 14.157s for FIOCSM.

The Cotton experiment (GACM0401.COX) using the CROPGRO-Cotton model
produced similar results. FIOCSM yielded slightly higher RMSE values for
LAI, biomass, and grain weight compared with OCSM, and the d-statistic
again indicated a small reduction in model agreement. Runtime results
showed that OCSM averaged 0.218s per run, while FIOCSM averaged 1.890s.
Across all treatments, average runtimes were 0.373s for OCSM and 2.162s
for FIOCSM.

3.  **Discussion**

In Case 1, experimental simulations for single season runs using the
Maize experiment (UFGA8201.MZX) showed that the average increase in
runtime for FIOCSM relative to OCSM is primarily due to the additional
processing layers introduced by Flexible I/O. These layers include
interface management, input functions, and dynamic data storage, all of
which increase computational demand. This overhead results from the
added flexibility in parsing and processing input data, moving away from
DSSAT-CSM's traditional fixed-width format. Another contributing factor
is the difference in programming paradigms. Fortran, which underlies
OCSM, is optimized for high-performance numerical computation and uses
minimal external dependencies, leading to efficient execution. In
contrast, C++, used to implement Flexible I/O, relies more heavily on
external libraries and object-oriented constructors, which introduce
additional execution time.

When comparing FIOCSM to FIOCSM_CSV, results showed a small increase in
average runtime for the CSV version, though the difference was minimal
(\~0.005s across treatments). This minor overhead likely stems from the
CSV input subroutine, which uses regular expressions to handle both
commas and blank spaces, whereas the standard daily subroutines process
only blank spaces. Across all treatments, the same pattern emerged,
where OCSM exhibited the fastest average runtime, followed by FIOCSM,
and then FIOCSM_CSV.

The Soybean experiment (LQPI1602.SBX) followed the same expected
pattern, with OCSM exhibiting the lowest average runtime, followed by
FIOCSM and FIOCSM_CSV, which showed the highest. The average runtime for
soybean was approximately 0.048s longer than that observed for maize.
This difference can be attributed to variations in the source code
implementations of the CERES-Maize and CROPGRO-Soybean models within the
CSM framework. Specifically, the soybean simulations require handling
multiple weather files as input, whereas the Maize experiment relies on
a single weather file, increasing the overall data processing demands
for Soybean.

Moreover, the Cotton experiment (AZMC8901.COX) confirmed the same
runtime pattern observed for Maize and Soybean, with OCSM achieving the
lowest average runtime, followed by FIOCSM and FIOCSM_CSV. Both the
Cotton and Soybean simulations use the CROPGRO model. However, the
higher average runtime for Cotton compared to Soybean is primarily
explained by the weather input structure. The Cotton experiment uses a
single long-term weather file spanning 32 years, whereas the Soybean
experiment relies on multiple shorter files. The longer weather file
increases processing time because the source code must handle a
substantially greater number of records. FIOCSM and FIOCSM_CSV showed
average runtime increases of 3.918s and 4.403s, respectively, compared
with OCSM. This performance difference is mainly attributed to the
Flexible I/O parsing logic. Unlike the standard DSSAT-CSM subroutine,
which stops immediately upon finding the first relevant weather record,
the Flexible I/O implementation continues reading up to 10,000 records
after identifying the start of the simulation, leading to a significant
increase in runtime.

This experimental case study demonstrates that the Flexible I/O
implementation successfully parses and processes both standard ASCII and
CSV formats of weather files, including metadata headers and daily
measurement records. It also maintains backward compatibility with
legacy datasets available in DSSAT, ensuring seamless integration with
existing applications. Furthermore, Flexible I/O removes the constraint
of fixed-width formatting, allowing daily weather measurements to be
flexibly defined if individual values are separated by at least a single
blank space.

The same pattern observed in the experimental case study was also
evident in the applications case study, where OCSM consistently
exhibited the lowest average runtime, followed by FIOCSM and then
FIOCSM_CSV with the highest. Although the sequence experiments
(CHWC0012.SQX and MSKB8901.SQX) cannot be directly compared due to
differences in their rotation scenarios, they follow the same approach
as the all-treatment runs that require multiple weather files as input,
similar to the soybean experiment in Case Study 1. For the CHWC0012.SQX
sequence experiment, the average runtime increased by 0.818s and 0.962s
for FIOCSM and FIOCSM_CSV, respectively, compared to OCSM. For
MSKB8901.SQX, the increase was 0.615s and 0.798s for FIOCSM and
FIOCSM_CSV, respectively. Likewise, the all-treatments soybean
experiment showed runtime increases of 0.953 and 1.334 seconds for
FIOCSM and FIOCSM_CSV, respectively. These results are consistent with
the previous case study and confirm that the primary factor contributing
to longer runtimes is the processing of multiple weather files as input.

The seasonal application (UFAD7465.SNX) followed the same pattern, using
multiple weather files as input while running long-term simulations over
30 years. Results showed an average runtime increase of 3.372s and
3.728s for FIOCSM and FIOCSM_CSV, respectively, compared to OCSM. The
greater runtime difference, relative to the soybean and sequence
experiments, is primarily attributed to the increased processing load
associated with handling thirty distinct weather input files
corresponding to each simulation year.

The forecast application experiment (CAPE2002.FCX) exhibited the same
runtime behavior observed in Case Study 1 for the cotton experiment,
where a long-term weather file was used as input. The average runtime
increases for FIOCSM and FIOCSM_CSV were 4.784s and 5.360s,
respectively, compared to OCSM. In contrast, the single-season cotton
experiment in Case Study 1 showed smaller increases of 3.918s and 4.403s
for FIOCSM and FIOCSM_CSV, respectively. The reduced performance in both
cases is attributed to the Flexible I/O logic used to parse long-term
weather files within the CSM. Additionally, the forecast application
requires backward referencing of weather data from the forecast start
date to simulate future yield, with CAPE2002.FCX running ensemble
simulations across 36 years for each treatment rather than a single
year. The proportional increase in runtime between the forecast and
cotton experiments further confirms that the primary factor affecting
Flexible I/O performance is the processing of long-term weather
datasets.

The hourly case study extended DSSAT-CSM to operate with hourly weather
data across two single-season experiments. In the first experiment,
carinata (UFJA1803.BCX), FIOCSM showed average increases in RMSE of
71.67 and 18.53 kg/ha, and decreases in d-statistic of 0.003 and 0.005
for LAI and biomass, respectively. In the second experiment, cotton
(GACM0401.COX), FIOCSM exhibited average RMSE differences of 3.70,
−23.95, and 3.69 kg/ha, and d-statistic changes of 0.000, 0.002, and
0.002 for LAI, biomass, and grain weight, respectively. These results
suggest that modifications made to the *HMET* subroutine did not
significantly affect model accuracy, indicating that hourly weather data
generated from daily inputs perform comparably. Moreover, FIOCSM
maintained overall model consistency despite structural changes to
accommodate hourly weather processing.

In contrast, runtime performance for FIOCSM was substantially higher
than for OCSM across both single and all-treatment runs. The source of
this increase aligns with the additional computational layers described
in Case Study 1 for the maize experiment. However, the primary factor
driving the performance reduction is the substantially larger data
volume. A daily weather file for a single year contains up to 366
records, while an hourly file may include up to 8,760 records. This case
study highlights both the benefits of supporting higher temporal
resolution and the computational trade-offs involved. It further
demonstrates the robustness of Flexible I/O in managing weather data
across multiple input formats and temporal resolutions within DSSAT-CSM.

4.  **Conclusion**

Overall, Flexible I/O demonstrated slower performance compared to the
original CSM. While this difference has minimal impact on user
experience for single season runs or smaller applications, it becomes
more time consuming in complex experiments involving multiple weather
files or long-term multi-season simulations. In large-scale
applications, such as global analyses requiring parallel execution of
multiple DSSAT instances, the cumulative increase in runtime introduced
by Flexible I/O could extend total computation time by several minutes.
Despite this performance cost, Flexible I/O provides substantial
advantages in data handling and model extensibility. The case studies
confirm its backward compatibility with legacy DSSAT datasets, expanded
support for diverse file formats such as CSV, and extended temporal
resolution to include hourly weather inputs. This can significantly
broaden the system's flexibility and applicability for future modeling
studies.

Further development is needed to improve the performance of Flexible I/O
when handling long-term weather files. Future work should explore
optimization strategies such as "divide and conquer" paradigms to
accelerate data parsing within large files and reduce overall runtime.
In addition, implementing interfaces for other programming languages,
such as Python, R, Rust, and Java and others, would broaden
accessibility and enable a wider range of modeling platforms/communities
and applications to benefit from Flexible I/O. Enhanced documentation
and improved error-checking within core Flexible I/O functions are also
necessary to facilitate debugging and ease integration for developers.
Finally, additional coupling points within DSSAT-CSM should be explored
to demonstrate the broader capabilities of Flexible I/O, further
advancing model interoperability and extending its applicability to
scientific domains not previously addressed.

Moreover, Flexible I/O paves the way for advancements with focus on
input/output challenges in the next generation of crop models (Jones et
al., 2017; Antle et al., 2017), where new coupling points can be
explored to leverage its capabilities. By simplifying data management
and enabling connections between diverse modeling components, Flexible
I/O aims to establish the foundation for more connected and adaptive
agricultural modeling systems. Building on this foundation, the
integration of technologies such as artificial intelligence, remote
sensing, and cloud computing with real-time and big-data streams can
further enhance the applicability and scientific relevance of crop
models. These innovations would allow models to dynamically assimilate
observed data, continuously learn from new information, and operate
efficiently at multiple spatial and temporal scales. Altogether,
Flexible I/O represents a critical step toward modernizing DSSAT-CSM,
bridging traditional modeling with next-generation digital agriculture
tools to support modern simulation platforms for global agricultural
research.

**Acknowledgements**

**References**

Adhikari, P., Omani, N., Ale, S., DeLaune, P.B., Thorp, K.R., Barnes,
E.M., Hoogenboom, G., 2017. Simulated Effects of Winter Wheat Cover Crop
on Cotton Production Systems of the Texas Rolling Plains. Trans ASABE
60, 2083--2096. https://doi.org/https://doi.org/10.13031/trans.12272

Antle, J.M., Basso, B., Conant, R.T., Godfray, H.C.J., Jones, J.W.,
Herrero, M., Howitt, R.E., Keating, B.A., Munoz-Carpena, R., Rosenzweig,
C., Tittonell, P., Wheeler, T.R., 2017. Towards a new generation of
agricultural system data, models and knowledge products: Design and
improvement. Agric Syst 155, 255--268.
https://doi.org/https://doi.org/10.1016/j.agsy.2016.10.002

Ascough, J.C., Green, T.R., McMaster, G.S., David, O., Kipka, H., 2015.
The spatially-distributed AgroEcoSystem-Watershed (AgES-W)
hydrologic/water quality (H/WQ) model for assessment of conservation
effects.

Attia, A., Govind, A., Qureshi, A.S., Feike, T., Rizk, M.S., Shabana,
M.M.A., Kheir, A.M.S., 2022. Coupling Process-Based Models and Machine
Learning Algorithms for Predicting Yield and Evapotranspiration of Maize
in Arid Environments. Water (Basel) 14.
https://doi.org/10.3390/w14223647

Boote, K.J., Jones, J.W., Hoogenboom, G, Pickering, N.B., 1998. The
CROPGRO model for grain legumes, in: Tsuji, G.Y., Hoogenboom, Gerrit,
Thornton, P.K. (Eds.), Understanding Options for Agricultural
Production. Springer Netherlands, Dordrecht, pp. 99--128.
https://doi.org/10.1007/978-94-017-3624-4_6

Boote, K.J., Jones, J.W., White, J.W., Asseng, S., Lizaso, J.I., 2013.
Putting mechanisms into crop production models. Plant Cell Environ 36,
1658--1672. https://doi.org/10.1111/pce.12119

Bouman, B.A.M., van Keulen, H., van Laar, H.H., Rabbinge, R., 1996. The
'School of de Wit' crop growth simulation models: A pedigree and
historical overview. Agric Syst 52, 171--198.
https://doi.org/https://doi.org/10.1016/0308-521X(96)00011-X

Brisson, N., Gary, C., Justes, E., Roche, R., Mary, B., Ripoche, D.,
Zimmer, D., Sierra, J., Bertuzzi, P., Burger, P., Bussière, F.,
Cabidoche, Y.M., Cellier, P., Debaeke, P., Gaudillère, J.P., Hénault,
C., Maraux, F., Seguin, B., Sinoquet, H., 2003. An overview of the crop
model stics. European Journal of Agronomy 18, 309--332.
https://doi.org/https://doi.org/10.1016/S1161-0301(02)00110-7

da Silva, E.H.F.M., Hoogenboom, G., Boote, K.J., Gonçalves, A.O., Marin,
F.R., 2022. Predicting soybean evapotranspiration and crop water
productivity for a tropical environment using the CSM-CROPGRO-Soybean
model. Agric For Meteorol 323, 109075.
https://doi.org/https://doi.org/10.1016/j.agrformet.2022.109075

de Wit, A., Boogaard, H., Fumagalli, D., Janssen, S., Knapen, R., van
Kraalingen, D., Supit, I., van der Wijngaart, R., van Diepen, K., 2019.
25 years of the WOFOST cropping systems model. Agric Syst 168, 154--167.
https://doi.org/https://doi.org/10.1016/j.agsy.2018.06.018

Donatelli, M., Russell, G., Rizzoli, A.E., Acutis, M., Adam, M.,
Athanasiadis, I.N., Balderacchi, M., Bechini, L., Belhouchette, H.,
Bellocchi, G., Bergez, J.-E., Botta, M., Braudeau, E., Bregaglio, S.,
Carlini, L., Casellas, E., Celette, F., Ceotto, E., Charron-Moirez,
M.H., Confalonieri, R., Corbeels, M., Criscuolo, L., Cruz, P., di
Guardo, A., Ditto, D., Dupraz, C., Duru, M., Fiorani, D., Gentile, A.,
Ewert, F., Gary, C., Habyarimana, E., Jouany, C., Kansou, K., Knapen,
R., Filippi, G.L., Leffelaar, P.A., Manici, L., Martin, G., Martin, P.,
Meuter, E., Mugueta, N., Mulia, R., van Noordwijk, M., Oomen, R.,
Rosenmund, A., Rossi, V., Salinari, F., Serrano, A., Sorce, A., Vincent,
G., Theau, J.-P., Thérond, O., Trevisan, M., Trevisiol, P., van Evert,
F.K., Wallach, D., Wery, J., Zerourou, A., 2010. A Component-Based
Framework for Simulating Agricultural Production and Externalities, in:
Brouwer, F.M., Ittersum, M.K. (Eds.), Environmental and Agricultural
Modelling: Integrated Approaches for Policy Impact Assessment. Springer
Netherlands, Dordrecht, pp. 63--108.
https://doi.org/10.1007/978-90-481-3619-3_4

Droutsas, I., Challinor, A.J., Deva, C.R., Wang, E., 2022. Integration
of machine learning into process-based modelling to improve simulation
of complex crop responses. In Silico Plants 4, diac017.
https://doi.org/10.1093/insilicoplants/diac017

Enders, A., Vianna, M., Gaiser, T., Krauss, G., Webber, H., Srivastava,
A.K., Seidel, S.J., Tewes, A., Rezaei, E.E., Ewert, F., 2023.
SIMPLACE---a versatile modelling and simulation framework for
sustainable crops and agroecosystems. In Silico Plants 5, diad006.
https://doi.org/10.1093/insilicoplants/diad006

Fitzgerald, B., Stol, K.-J., 2014. Continuous software engineering and
beyond: trends and challenges, in: Proceedings of the 1st International
Workshop on Rapid Continuous Software Engineering, RCoSE 2014.
Association for Computing Machinery, New York, NY, USA, pp. 1--9.
https://doi.org/10.1145/2593812.2593813

Foster, T., Brozović, N., Butler, A.P., Neale, C.M.U., Raes, D.,
Steduto, P., Fereres, E., Hsiao, T.C., 2017. AquaCrop-OS: An open source
version of FAO's crop water productivity model. Agric Water Manag 181,
18--22. https://doi.org/https://doi.org/10.1016/j.agwat.2016.11.015

Fountas, S., Espejo-García, B., Kasimati, A., Mylonas, N., Darra, N.,
2020. The Future of Digital Agriculture: Technologies and Opportunities.
IT Prof 22, 24--28. https://doi.org/10.1109/MITP.2019.2963412

Holzworth, D.P., Huth, N.I., deVoil, P.G., Zurcher, E.J., Herrmann,
N.I., McLean, G., Chenu, K., van Oosterom, E.J., Snow, V., Murphy, C.,
Moore, A.D., Brown, H., Whish, J.P.M., Verrall, S., Fainges, J., Bell,
L.W., Peake, A.S., Poulton, P.L., Hochman, Z., Thorburn, P.J., Gaydon,
D.S., Dalgliesh, N.P., Rodriguez, D., Cox, H., Chapman, S., Doherty, A.,
Teixeira, E., Sharp, J., Cichota, R., Vogeler, I., Li, F.Y., Wang, E.,
Hammer, G.L., Robertson, M.J., Dimes, J.P., Whitbread, A.M., Hunt, J.,
van Rees, H., McClelland, T., Carberry, P.S., Hargreaves, J.N.G.,
MacLeod, N., McDonald, C., Harsdorf, J., Wedgwood, S., Keating, B.A.,
2014. APSIM -- Evolution towards a new generation of agricultural
systems simulation. Environmental Modelling & Software 62, 327--350.
https://doi.org/https://doi.org/10.1016/j.envsoft.2014.07.009

Hoogenboom, G., Porter, C.H., Boote, K.J., Shelia, V., Wilkens, P.W.,
Singh, U., White, J.W., Asseng, S., Lizaso, J.I., Moreno, L.P., Pavan,
W., Ogoshi, R., Hunt, L.A., Tsuji, G.Y., Jones, J.W., 2019. The DSSAT
crop modeling ecosystem, in: Advances in Crop Modelling for a
Sustainable Agriculture. Burleigh Dodds Science Publishing, pp.
173--216. https://doi.org/10.19103/as.2019.0061.10

Hoogenboom, G., Porter, C.H., Shelia, V., Boote, K.J., Singh, U., Pavan,
W., Oliveira, F.A.A., Moreno-Cadena, L.P., Ferreira, T.B., White, J.W.,
Lizaso, J.I., Pequeno, D.N.L., Kimball, B.A., Alderman, P.D., Thorp,
K.R., Cuadra, S. V., Vianna, M.S., Villalobos, F.J., Batchelor, W.D.,
Asseng, S., Jones, M.R., Hopf, A., Dias, H.B., Hunt, L.A., Jones, J.W.,
2023. Decision Support System for Agrotechnology Transfer (DSSAT)
Version 4.8.2 (www.DSSAT.net).

Hsiao, T.C., Heng, L., Steduto, P., Rojas-Lara, B., Raes, D., Fereres,
E., 2009. AquaCrop---The FAO Crop Model to Simulate Yield Response to
Water: III. Parameterization and Testing for Maize. Agron J 101,
448--459. https://doi.org/https://doi.org/10.2134/agronj2008.0218s

Jägermeyr, J., Müller, C., Ruane, A.C., Elliott, J., Balkovic, J.,
Castillo, O., Faye, B., Foster, I., Folberth, C., Franke, J.A., Fuchs,
K., Guarin, J.R., Heinke, J., Hoogenboom, G., Iizumi, T., Jain, A.K.,
Kelly, D., Khabarov, N., Lange, S., Lin, T.-S., Liu, W., Mialyk, O.,
Minoli, S., Moyer, E.J., Okada, M., Phillips, M., Porter, C., Rabin,
S.S., Scheer, C., Schneider, J.M., Schyns, J.F., Skalsky, R., Smerald,
A., Stella, T., Stephens, H., Webber, H., Zabel, F., Rosenzweig, C.,
2021. Climate impacts on global agriculture emerge earlier in new
generation of climate and crop models. Nat Food 2, 873--885.
https://doi.org/10.1038/s43016-021-00400-y

Jamieson, P.D., Semenov, M.A., Brooking, I.R., Francis, G.S., 1998.
Sirius: a mechanistic model of wheat response to environmental
variation. European Journal of Agronomy 8, 161--179.
https://doi.org/https://doi.org/10.1016/S1161-0301(98)00020-3

Jones, J.W., Antle, J.M., Basso, B., Boote, K.J., Conant, R.T., Foster,
I., Godfray, H.C.J., Herrero, M., Howitt, R.E., Janssen, S., Keating,
B.A., Munoz-Carpena, R., Porter, C.H., Rosenzweig, C., Wheeler, T.R.,
2017. Toward a new generation of agricultural system data, models, and
knowledge products: State of agricultural systems science. Agric Syst
155, 269--288.
https://doi.org/https://doi.org/10.1016/j.agsy.2016.09.021

Jones, J.W., Antle, J.M., Basso, B., Boote, K.J., Conant, R.T., Foster,
I., Godfray, H.C.J., Herrero, M., Howitt, R.E., Janssen, S., Keating,
B.A., Munoz-Carpena, R., Porter, C.H., Rosenzweig, C., Wheeler, T.R.,
2016. Brief history of agricultural systems modeling. Agric Syst 155,
240--254. https://doi.org/https://doi.org/10.1016/j.agsy.2016.05.014

Jones, J.W., Hoogenboom, G., Porter, C.H., Boote, K.J., Batchelor, W.D.,
Hunt, L.A., Wilkens, P.W., Singh, U., Gijsman, A.J., Ritchie, J.T.,
2003. The DSSAT cropping system model. European Journal of Agronomy 18,
235--265. https://doi.org/https://doi.org/10.1016/S1161-0301(02)00107-7

Jones, J.W., Keating, B.A., Porter, C.H., 2001. Approaches to modular
model development. Agric Syst 70, 421--443.
https://doi.org/https://doi.org/10.1016/S0308-521X(01)00054-3

Keating, B.A., Carberry, P.S., Hammer, G.L., Probert, M.E., Robertson,
M.J., Holzworth, D., Huth, N.I., Hargreaves, J.N.G., Meinke, H.,
Hochman, Z., McLean, G., Verburg, K., Snow, V., Dimes, J.P., Silburn,
M., Wang, E., Brown, S., Bristow, K.L., Asseng, S., Chapman, S., McCown,
R.L., Freebairn, D.M., Smith, C.J., 2003. An overview of APSIM, a model
designed for farming systems simulation. European Journal of Agronomy
18, 267--288.
https://doi.org/https://doi.org/10.1016/S1161-0301(02)00108-9

Kimball, B., Thorp, K., Barnes, E., Choi, C., Clarke, T., Colaizzi, P.,
Fitzgerald, G., Haberland, J., Hendrey, G., Hunsaker, D., Kostrzewski,
M., LaMorte, R., Leavitt, S., Lewin, K., Mauney, J., Nagy, J., Pinter,
P., Waller, P., 2022. Cotton response to CO2, water, nitrogen, and plant
density - A repository of FACE, AgIIS and FISE experiment data. Open
Data Journal for Agricultural Research 8, 1--5.
https://doi.org/10.18174/odjar.v8i0.18152

Kralisch, S., Krause, P., David, O., 2005. Using the object modeling
system for hydrological model development and application. Adv. Geosci.
4, 75--81. https://doi.org/10.5194/adgeo-4-75-2005

Langtangen, H.P., 2004. Combining Python with Fortran, C, and C++, in:
Langtangen, H.P. (Ed.), Python Scripting for Computational Science.
Springer Berlin Heidelberg, Berlin, Heidelberg, pp. 169--204.
https://doi.org/10.1007/978-3-662-05450-5_5

Martre, P., Jamieson, P.D., Semenov, M.A., Zyskowski, R.F., Porter,
J.R., Triboi, E., 2006. Modelling protein content and composition in
relation to crop nitrogen dynamics for wheat. European Journal of
Agronomy 25, 138--154.
https://doi.org/https://doi.org/10.1016/j.eja.2006.04.007

Mistrík, I., Grundy, J., van der Hoek, A., Whitehead, J., 2010.
Collaborative Software Engineering: Challenges and Prospects, in:
Mistrík, I., Grundy, J., Hoek, A., Whitehead, J. (Eds.), Collaborative
Software Engineering. Springer Berlin Heidelberg, Berlin, Heidelberg,
pp. 389--403. https://doi.org/10.1007/978-3-642-10294-3_19

Nendel, C., Berg, M., Kersebaum, K.C., Mirschel, W., Specka, X.,
Wegehenkel, M., Wenkel, K.O., Wieland, R., 2011. The MONICA model:
Testing predictability for crop growth, soil moisture and nitrogen
dynamics. Ecol Modell 222, 1614--1625.
https://doi.org/https://doi.org/10.1016/j.ecolmodel.2011.02.018

Peeling, J.A., Judge, J., Misra, V., Jayasankar, C.B., Lusher, W.R.,
2023. Gap-free 16-year (2005--2020) sub-diurnal surface meteorological
observations across Florida. Sci Data 10, 907.
https://doi.org/10.1038/s41597-023-02826-4

Ruparelia, N.B., 2010. Software development lifecycle models. SIGSOFT
Softw. Eng. Notes 35, 8--13. https://doi.org/10.1145/1764810.1764814

Shahhosseini, M., Hu, G., Huber, I., Archontoulis, S. V, 2021. Coupling
machine learning and crop modeling improves crop yield prediction in the
US Corn Belt. Sci Rep 11, 1606.
https://doi.org/10.1038/s41598-020-80820-1

Stroustrup, B., 2013. The C++ Programming Language, 4th ed.
Addison-Wesley Professional.

Tsuji, G.Y., Hoogenboom, G., Thornton, P.K., 1998. Understanding options
for agricultural production. Springer Science & Business Media.

White, J.W., Hoogenboom, G., Kimball, B.A., Wall, G.W., 2011.
Methodologies for simulating impacts of climate change on crop
production. Field Crops Res 124, 357--368.
https://doi.org/https://doi.org/10.1016/j.fcr.2011.07.001

White, J.W., Hunt, L.A., Boote, K.J., Jones, J.W., Koo, J., Kim, S.,
Porter, C.H., Wilkens, P.W., Hoogenboom, G., 2013. Integrated
description of agricultural field experiments and production: The ICASA
Version 2.0 data standards. Comput Electron Agric 96, 1--12.
https://doi.org/https://doi.org/10.1016/j.compag.2013.04.003

Xiong, W., Holman, I., Conway, D., Lin, E., Li, Y., 2008. A crop model
cross calibration for use in regional climate impacts studies. Ecol
Modell 213, 365--380.
https://doi.org/https://doi.org/10.1016/j.ecolmodel.2008.01.005

Zhang, N., Zhou, X., Kang, M., Hu, B.-G., Heuvelink, E., Marcelis,
L.F.M., 2023. Machine learning versus crop growth models: an ally, not a
rival. AoB Plants 15, plac061. https://doi.org/10.1093/aobpla/plac061

 

+--------------+--------+------------------------------+----------------------------+-------------------------------------+
| Experimental | TRT^1^ | Root Mean Square Error       | Index of agreement         | Average runtime (seconds)           |
| file         |        | (RMSE)                       | (d-statistic)              |                                     |
+=============:+=======:+========:+=========:+========:+=======:+========:+========:+========:+==========:+==============:+
|              |        | LAI^3^  | Biomass  | Grain   | LAI    | Biomass | Grain   | OCSM^4^ | FIOCSM^5^ | FIOCSM_CSV^6^ |
|              |        |         | (kg/ha)  | Weight  |        | (kg/ha) | Weight  |         |           |               |
|              |        |         |          | (kg/ha) |        |         | (kg/ha) |         |           |               |
+--------------+--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
| UFGA8201.MZX | 1      | 346.097 | 730.037  | 214.354 | 0.896  | 0.973   | 0.979   | 0.202   | 0.284     | 0.287         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 2      | 448.116 | 565.020  | 163.674 | 0.894  | 0.988   | 0.991   | 0.204   | 0.286     | 0.290         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 3      | 662.678 | 769.125  | 897.34  | 0.879  | 0.995   | 0.969   | 0.204   | 0.286     | 0.292         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 4      | 297.097 | 855.348  | 485.637 | 0.99   | 0.997   | 0.996   | 0.207   | 0.286     | 0.295         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 5      | 611.515 | 815.789  | 607.871 | 0.877  | 0.993   | 0.985   | 0.208   | 0.288     | 0.294         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 6      | 418.669 | 1122.548 | 363.989 | 0.968  | 0.991   | 0.997   | 0.207   | 0.288     | 0.292         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | All^2^ |         |          |         |        |         |         | 0.854   | 1.014     | 1.269         |
+--------------+--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
| LQPI1602.SBX | 1      | 431.711 | 513.382  | 689.871 | 0.979  | 0.995   | 0.948   | 0.255   | 0.416     | 0.462         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 2      | 431.711 | 513.382  | 689.871 | 0.979  | 0.995   | 0.948   | 0.259   | 0.417     | 0.469         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 3      | 431.861 | 513.382  | 689.871 | 0.979  | 0.995   | 0.948   | 0.246   | 0.404     | 0.454         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 4      | 431.861 | 513.382  | 689.871 | 0.979  | 0.995   | 0.948   | 0.243   | 0.399     | 0.501         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 5      | 191.765 | 2227.541 | 407.358 | 0.992  | 0.887   | 0.977   | 0.253   | 0.401     | 0.491         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 6      | 191.765 | 522.45   | 407.358 | 0.992  | 0.991   | 0.977   | 0.274   | 0.415     | 0.461         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 7      | 191.765 | 522.45   | 407.025 | 0.992  | 0.991   | 0.977   | 0.256   | 0.367     | 0.508         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 8      | 191.765 | 522.45   | 407.025 | 0.992  | 0.991   | 0.977   | 0.244   | 0.372     | 0.422         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | All    |         |          |         |        |         |         | 1.560   | 2.513     | 2.894         |
+--------------+--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
| AZMC8901.COX | 1      | 517.975 | 1168.5   |         | 0.921  | 0.968   |         | 0.335   | 4.307     | 4.802         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | 2      | 394.931 | 1963.205 |         | 0.949  | 0.94    |         | 0.347   | 4.211     | 4.686         |
|              +--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+
|              | All    |         |          |         |        |         |         | 0.554   | 4.581     | 5.373         |
+--------------+--------+---------+----------+---------+--------+---------+---------+---------+-----------+---------------+

: **Table 1**. Experimental case study results to validate Flexible I/O
simulations and compare performance against the DSSAT Crop System Model.

^1^Treatment (TRT).

*^2^Treatment = All, means that treatments in the experimental file were
executed with one command line (run mode 'A').*

*^3^Leaf area index (LAI).*

*^4^Original DSSAT-CSM (OCSM).*

*^5^Original DSSAT-CSM with Flexible I/O integration for weather data
management (FIOCSM).*

*^6^FIOCSM with comma-separated values as weather data input
(FIOCSM_CSV).*

+-------------+--------------+--------+-------------------------------------+
| Application | Experiment   | TRT^1^ | Average runtime (seconds)           |
+============:+=============:+=======:+========:+==========:+==============:+
|             |              |        | OCSM^2^ | FIOCSM^3^ | FIOCSM_CSV^4^ |
+-------------+--------------+--------+---------+-----------+---------------+
| Sequence    | CHWC0012.SQX | 1      | 3.444   | 4.262     | 4.406         |
|             +--------------+--------+---------+-----------+---------------+
|             | MSKB8901.SQX | 1      | 4.005   | 4.620     | 4.803         |
+-------------+--------------+--------+---------+-----------+---------------+
| Seasonal    | UAFD7465.SNX | 1      | 5.083   | 8.274     | 8.731         |
|             |              +--------+---------+-----------+---------------+
|             |              | 2      | 5.316   | 8.456     | 8.772         |
|             |              +--------+---------+-----------+---------------+
|             |              | 3      | 5.017   | 8.440     | 8.886         |
|             |              +--------+---------+-----------+---------------+
|             |              | 4      | 4.726   | 8.323     | 8.881         |
|             |              +--------+---------+-----------+---------------+
|             |              | 5      | 4.798   | 8.341     | 8.655         |
|             |              +--------+---------+-----------+---------------+
|             |              | 6      | 5.006   | 8.371     | 8.522         |
|             |              +--------+---------+-----------+---------------+
|             |              | 7      | 4.952   | 8.548     | 8.536         |
|             |              +--------+---------+-----------+---------------+
|             |              | 8      | 5.090   | 8.561     | 8.515         |
|             |              +--------+---------+-----------+---------------+
|             |              | 9      | 5.106   | 8.812     | 8.527         |
|             |              +--------+---------+-----------+---------------+
|             |              | 10     | 5.171   | 8.731     | 8.855         |
|             |              +--------+---------+-----------+---------------+
|             |              | 11     | 5.077   | 8.493     | 9.090         |
|             |              +--------+---------+-----------+---------------+
|             |              | 12     | 5.042   | 8.328     | 8.956         |
|             |              +--------+---------+-----------+---------------+
|             |              | 13     | 4.795   | 8.331     | 8.705         |
+-------------+--------------+--------+---------+-----------+---------------+
| Forecast    | CAPE2002.FCX | 1      | 5.233   | 10.084    | 10.692        |
|             |              +--------+---------+-----------+---------------+
|             |              | 2      | 5.250   | 10.244    | 10.884        |
|             |              +--------+---------+-----------+---------------+
|             |              | 3      | 5.274   | 9.782     | 10.261        |
+-------------+--------------+--------+---------+-----------+---------------+

: **Table 2**. Case study for DSSAT-CSM applications with results of
average runtime performance using Flexible I/O.

^1^Treatment (TRT).

*^2^Original DSSAT-CSM (OCSM).*

*^3^Original DSSAT-CSM with Flexible I/O integration for weather data
management (FIOCSM).*

*^4^FIOCSM with comma-separated values as weather data input
(FIOCSM_CSV).*

+--------------+--------+-----------+--------------------------------+----------------------------+-----------+
| Experimental | TRT^1^ | Model     | Root Mean Square Error (RMSE)  | Index of agreement         | Average   |
| file         |        |           |                                | (d-statistic)              | runtime   |
|              |        |           |                                |                            | (seconds) |
+=============:+=======:+==========:+==========:+=========:+========:+=======:+========:+========:+==========:+
|              |        |           | LAI^3^    | Biomass  | Grain   | LAI    | Biomass | Grain   |           |
|              |        |           |           | (kg/ha)  | Weight  |        | (kg/ha) | Weight  |           |
|              |        |           |           |          | (kg/ha) |        |         | (kg/ha) |           |
+--------------+--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
| UFJA1803.BCX | 1      | OCSM^4^   | 13592.959 | 1014.081 |         | 0.463  | 0.764   |         | 0.256     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM^5^ | 13647.531 | 1041.996 |         | 0.461  | 0.748   |         | 3.117     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | 2      | OCSM      | 5387.787  | 843.262  |         | 0.609  | 0.916   |         | 0.267     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    | 5423.099  | 802.182  |         | 0.606  | 0.922   |         | 3.140     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | 3      | OCSM      | 14355.428 | 1315.775 |         | 0.563  | 0.909   |         | 0.253     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    | 14464.878 | 1339.794 |         | 0.560  | 0.904   |         | 3.092     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | 4      | OCSM      | 5969.397  | 1553.901 |         | 0.599  | 0.898   |         | 0.257     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    | 6004.702  | 1594.210 |         | 0.596  | 0.891   |         | 3.116     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | 5      | OCSM      | 20865.296 | 772.218  |         | 0.565  | 0.965   |         | 0.253     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    | 20989.013 | 811.697  |         | 0.563  | 0.961   |         | 3.241     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | All^2^ | OCSM      |           |          |         |        |         |         | 1.058     |
|              |        +-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    |           |          |         |        |         |         | 14.157    |
+--------------+--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
| GACM0401.COX | 1      | OCSM      | 517.242   | 851.393  | 325.511 | 0.847  | 0.982   | 0.993   | 0.218     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    | 528.835   | 831.294  | 348.776 | 0.844  | 0.983   | 0.991   | 1.890     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | 2      | OCSM      | 395.365   | 1374.938 | 820.903 | 0.718  | 0.900   | 0.861   | 0.214     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    | 391.200   | 1347.133 | 805.026 | 0.721  | 0.904   | 0.867   | 1.963     |
|              +--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              | All    | OCSM      |           |          |         |        |         |         | 0.373     |
|              |        +-----------+-----------+----------+---------+--------+---------+---------+-----------+
|              |        | FIOCSM    |           |          |         |        |         |         | 2.162     |
+--------------+--------+-----------+-----------+----------+---------+--------+---------+---------+-----------+

: **Table 3**. Hourly case study results to validate Flexible I/O
simulations and compare performance against the DSSAT Crop System Model.

^1^Treatment (TRT).

*^2^Treatment = All, means that treatments in the experimental file were
executed with one command line (run mode 'A').*

*^3^Leaf area index (LAI).*

*^4^Original DSSAT-CSM (OCSM) running with daily weather inputs.*

*^5^Original DSSAT-CSM with Flexible I/O integration for weather data
management (FIOCSM) running with hourly weather inputs.*

**List of Figures**

![**Figure 1.** Class diagram with Unified Modeling Language (UML) of
Flexible I/O's design. Packages separate individual classes/functions.
Data storage is the main central class to manage and store data in
memory. 'Input Functions' are defined to parse and process data from an
input file or application needs. They are associated with FlexibleIO
class to store or retrieve data. 'Interfaces', are the primary functions
that establish connection between Flexible I/O and any component/system
linked
with.](media/image1.jpeg){alt="A diagram of a computer AI-generated content may be incorrect."
width="6.48635498687664in" height="4.488774059492563in"}

![**Figure 2.** Sequence diagram using Unified Modeling Language (UML)
with the execution flow of Flexible I/O parsing an input file, stored
data into Flexible I/O and retrieved data during the runtime of the main
program. Fortran_Interface, Read_Function and FlexibleIO are
class/functions showing their respective lifeline (dashed vertical
line). Black dots represent start of a function call from the main
program. Arrows with solid arrowhead show a call triggered to a
respective class/function, while a thin rectangle on top of the dashed
line represents the execution of the function. Dashed arrows represent
the return of a
class/function.](media/image2.jpeg){alt="A diagram of a computer program AI-generated content may be incorrect."
width="6.494645669291339in" height="5.774161198600175in"}

![**Figure 3.** Standard ICASA (White et al. 2013) ASCII DSSAT weather
input file for Gainesville, Florida (UFGA8201.WTH). Top part (\*) shows
the type of file and brief site description, followed by the metadata
header (denoted by @) which are separated by spaces. The same applies to
the second header below showing the daily weather data, where DATE is
characterized by two or four digits to represent the year and three
digits to represent the day of year. Weather measurements are separated
by a fixed number of spaces. RAIN and PAR are an example of
inflexibility of the CSM where they were adjusted in their respective
column leaving a blank space
gap.](media/image3.png){alt="A screenshot of a computer AI-generated content may be incorrect."
width="5.964833770778653in" height="2.6562139107611547in"}

![**Figure 4.** Standard ICASA (White et al. 2013) ASCII Comma-Separated
Values (CSV) weather input file for Gainesville, Florida (UFGA8201.WTH).
Top part (\*) shows the type of file and brief site description,
followed by the metadata header (denoted by @) which is separated by
comma. The same applies to the second header below showing the daily
weather data, where DATE is characterized by two or four digits to
represent the year and three digits to represent the day of year.
Weather measurements are separated by comma and Flexible I/O handles the
blank
spaces.](media/image4.png){alt="A screenshot of a computer screen AI-generated content may be incorrect."
width="5.964833770778653in" height="2.3488451443569556in"}

![**Figure 5.** Standard ICASA (White et al. 2013) ASCII hourly weather
input file for Gainesville, Florida (UFGA8201.WTH). Top part (\$) shows
the type of file and brief site description, followed by the metadata
header (denoted by @) which is separated by spaces. The same applies to
the second header below showing the hourly weather data, where DATE is
characterized by four digits to represent the year, three digits to
represent the day of year, separated by '-' with two digits to represent
the hour from (1-24). Weather measurements are separated by spaces with
no fixed format required and Flexible I/O handles the blank
spaces.](media/image5.png){alt="A screenshot of a computer screen AI-generated content may be incorrect."
width="6.341666666666667in" height="8.203216316710412in"}

![**Figure 6.** (A) Original DSSAT-CSM (OCSM) with original Fortran
routine for input weather data. (B) Flexible I/O-DSSAT-CSM (FIOCSM) with
daily, csv and hourly routines to input weather
data.](media/image6.jpeg){alt="A puzzle pieces with different colors AI-generated content may be incorrect."
width="6.485416666666667in" height="3.723611111111111in"}

**Supplementary Material**

![**Figure S1.** Class diagram with Unified Modeling Language (UML) of
Flexible I/O's design developed for DSSAT-CSM. Packages separate
individual classes/functions. Data storage is the main central class to
manage and store data in memory. 'Input Functions' are defined to parse
and process weather data. They are associated with FlexibleIO class to
store or retrieve data. 'Interfaces', are the primary functions that
establish connection between Flexible I/O and
DSSAT-CSM.](media/image7.jpeg){alt="A close-up of a diagram AI-generated content may be incorrect."
width="6.495867235345582in" height="8.031929133858268in"}

**Source code**

IPWTH subroutine **-**
<https://github.com/DSSAT/dssat-csm-os/blob/FlexibleIO/Weather/IPWTH_alt.for>

HMET subroutine -
<https://github.com/DSSAT/dssat-csm-os/blob/FlexibleIO/Weather/HMET.for>

[^1]: https://github.com/DSSAT/dssat-csm-os/tree/0095184260898f34cb15debe5ea1efc0ea4d5603

[^2]: https://github.com/DSSAT/dssat-csm-os/tree/FlexibleIO

[^3]: https://dssat.net/

[^4]: https://github.com/DSSAT/dssat-csm-data
