# AIS_TRAIL

* Main objective: Generate a unique trip identifier per vessel
* Attempt to label "whacky" points (all points are retained)
* Save each vessel trail profile for each year for downstream processing
  * Further processing is done e.g. in:
    * ~/prj2/fishydata
      * Attempts to match trail and landings statistics by landing date
    * ~/prj2/vms/ices_data_call


Input: Data stored in Oracle
Output: trail/stk-trails_yYYYY_vVVVV.rds
Main script: rscipts/01_stk-trails.R
Logs: see lgs/*_YYYY-MM-DD.log

Critical upstream code: ~/R/Pakkar2/omar/data-raw/00_SETUP_mobileid-vid-match.R

#### TODO:

* Augment stk-data with pame and logbook-trails

