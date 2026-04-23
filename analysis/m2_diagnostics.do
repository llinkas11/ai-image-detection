* One-off: diagnostics computed on m2's specification only.
* m2 = oprobit score i.over_25 i.device_type i.gender i.race
* We need:
*   - oparallel results (5 tests) on the 3-level bucketed score with m2's predictors
*   - VIF from parallel OLS with m2's predictors
clear all
set more off
* cd "set your working directory here"

use "data/AI_DetectionV3_lite.dta", clear
rename score_total score

* --- Same filter pipeline as the main do-file ---
keep if attn_both == 1
decode device_type, gen(_dev_str)
drop if _dev_str == "Other"
drop _dev_str
gen ln_resp_time = ln(avg_resp_time)
summarize ln_resp_time
local lnm = r(mean)
local lns = r(sd)
keep if inrange(ln_resp_time, `lnm' - 3*`lns', `lnm' + 3*`lns')

* --- Variable recoding (identical to main) ---
decode affiliation, gen(_affil_str)
gen over_25 = (_affil_str == "Faculty/Staff")
drop _affil_str
recode gender (4 = 3)
label define gender_lbl 1 "Man" 2 "Woman" 3 "Other", replace
label values gender gender_lbl
recode race (6 = 8) (7 = 8)
label define race_lbl 1 "White" 2 "Asian" 3 "Black or African American" ///
    4 "Hispanic or Latino" 5 "Two or more races" 8 "Other", replace
label values race race_lbl

* --- Parallel regression test on m2's predictors ---
cap log close m2_parallel
log using "figs/m2_parallel.txt", text replace name(m2_parallel)
display _newline(2) " m2 parallel regression test "
recode score (0/5 = 1 "Low (<=5)") (6/7 = 2 "Moderate (6-7)") (8/10 = 3 "Strong (>=8)"), gen(score_cat)
ologit score_cat i.over_25 i.device_type i.gender i.race
capture noisily oparallel
log close m2_parallel
drop score_cat

* --- VIF on m2's predictors ---
cap log close m2_vif
log using "figs/m2_vif.txt", text replace name(m2_vif)
display _newline(2) " m2 VIF "
quietly reg score i.over_25 i.device_type i.gender i.race
estat vif
log close m2_vif
