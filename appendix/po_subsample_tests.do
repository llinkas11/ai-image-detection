* Parallel-regression assumption tests for the preferred subsample
* specifications (faculty mf3b, student ms4) plus VIF on each subsample.
*
* The full predictor set causes perfect prediction in oparallel because
* sparse race cells (Black or African American n=11; Other n=3) yield zero
* observations in at least one bucketed-score x race cell. We follow a
* fall-back ladder per subsample: full spec; drop race; drop race + gender.
* The first variant that runs is the reported test.

capture program drop run_po
program define run_po
    args label spec subsample_cond
    display _newline "--- `label' ---"
    capture noisily ologit score_cat `spec' `subsample_cond'
    if _rc == 0 capture noisily oparallel
    if _rc != 0 display "ologit failed: rc=" _rc
end

recode score (0/5=1) (6/7=2) (8/10=3), gen(score_cat)


* F.2 faculty subsample (mf3b: i.device_type c.ai_familiarity i.gender i.race
*                        if over_25 == 1)
display _newline(2) "F.2 Faculty/Staff subsample"
run_po "mf3b: full spec (with race + gender)" ///
    "i.device_type c.ai_familiarity i.gender i.race" "if over_25 == 1"
run_po "mf3b: drop race" ///
    "i.device_type c.ai_familiarity i.gender" "if over_25 == 1"
run_po "mf3b: drop race + gender (final reported test)" ///
    "i.device_type c.ai_familiarity" "if over_25 == 1"


* F.3 student subsample (ms4: i.affiliation i.device_type i.gender i.race
*                        c.ai_familiarity##c.ai_use_time c.social_media_time
*                        if over_25 == 0)
display _newline(2) "F.3 Student subsample"
run_po "ms4: full spec (with race)" ///
    "i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time" "if over_25 == 0"
run_po "ms4: drop race (final reported test)" ///
    "i.affiliation i.device_type i.gender c.ai_familiarity##c.ai_use_time c.social_media_time" "if over_25 == 0"

drop score_cat


* F.4 subsample VIFs (parallel OLS, since estat vif requires OLS)
display _newline(2) "F.4 Subsample VIF (parallel OLS)"

display _newline "--- Faculty/Staff VIF ---"
quietly reg score i.device_type c.ai_familiarity i.gender i.race if over_25 == 1
estat vif

display _newline "--- Student VIF ---"
quietly reg score i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time if over_25 == 0
estat vif
