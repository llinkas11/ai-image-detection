* Section F.2 and F.3: parallel-regression assumption tests on the
* preferred subsample specifications (faculty mf3b and student ms3c)
* plus VIF on each subsample.
*
* The full predictor set causes perfect prediction in oparallel because
* the "Other" race cell (n=3 in the post-filter sample) and "Black or
* African American" (n=11 in the pooled sample, even fewer per subsample)
* yield zero observations in at least one bucketed-score x race cell.
* We follow a fall-back ladder: try the full spec first; if it fails,
* drop race; if still failing, drop gender too. Whichever variant
* successfully runs is the reported test.
*
* Assumes the post-filter dataset is in memory from oprobit_regression.do
* (over_25 derived, gender / race / device collapsed, ln_resp_time present).


* ===========================================================================
* F.2: faculty subsample (mf3b spec)
*   mf3b: oprobit score i.device_type c.ai_familiarity i.gender i.race
*         if over_25 == 1
* ===========================================================================
display _newline(2) "=========================================="
display "F.2 Faculty/Staff subsample - PO test"
display "=========================================="
recode score (0/5=1) (6/7=2) (8/10=3), gen(score_cat)

display _newline "--- mf3b: full spec (with race + gender) ---"
capture noisily ologit score_cat i.device_type c.ai_familiarity i.gender i.race if over_25 == 1
if _rc == 0 capture noisily oparallel
if _rc != 0 display "ologit failed: rc=" _rc

display _newline "--- mf3b fallback: drop race ---"
capture noisily ologit score_cat i.device_type c.ai_familiarity i.gender if over_25 == 1
if _rc == 0 capture noisily oparallel
if _rc != 0 display "ologit failed: rc=" _rc

display _newline "--- mf3b fallback: drop race + gender (final reported test) ---"
capture noisily ologit score_cat i.device_type c.ai_familiarity if over_25 == 1
if _rc == 0 capture noisily oparallel
if _rc != 0 display "ologit failed: rc=" _rc

drop score_cat


* ===========================================================================
* F.3: student subsample (ms3c spec)
*   ms3c: oprobit score i.affiliation i.device_type i.gender i.race
*         c.ai_familiarity##c.ai_use_time if over_25 == 0
* ===========================================================================
display _newline(2) "=========================================="
display "F.3 Student subsample - PO test"
display "=========================================="
recode score (0/5=1) (6/7=2) (8/10=3), gen(score_cat)

display _newline "--- ms3c: full spec (with race) ---"
capture noisily ologit score_cat i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time if over_25 == 0
if _rc == 0 capture noisily oparallel
if _rc != 0 display "ologit failed: rc=" _rc

display _newline "--- ms3c fallback: drop race (final reported test) ---"
capture noisily ologit score_cat i.affiliation i.device_type i.gender c.ai_familiarity##c.ai_use_time if over_25 == 0
if _rc == 0 capture noisily oparallel
if _rc != 0 display "ologit failed: rc=" _rc

drop score_cat


* ===========================================================================
* F.4: VIF on each subsample (parallel OLS, since estat vif requires OLS)
* ===========================================================================
display _newline(2) "=========================================="
display "F.4 Subsample VIF (parallel OLS)"
display "=========================================="

display _newline "--- Faculty/Staff VIF ---"
quietly reg score i.device_type c.ai_familiarity i.gender i.race if over_25 == 1
estat vif

display _newline "--- Student VIF ---"
quietly reg score i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time if over_25 == 0
estat vif
