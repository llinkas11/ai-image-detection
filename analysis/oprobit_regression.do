* Regression Analysis -- What factors affect score?
* DV: score (0-10, integer count of correct AI vs real classifications)
* Model: ordered probit (oprobit) with robust SEs
*
* Justification (class notes, Sessions 17 & 18 -- Categorical Outcome Variables):
* score has 11 ordered integer levels (0-10) with natural ordering, so it is
* ordinal (k >= 3). Per the class decision rule:
*   "discrete (k>=3) -> mlogit (nominal) or ologit / oprobit (ordered)."
* Categories are ordered (higher score = better detection), so mlogit is ruled
* out because it would discard the ordering information.
*
* Between ologit and oprobit, the difference is the error distribution:
*   oprobit: e ~ N(0,1)            (standard normal latent)
*   ologit:  e ~ standard logistic (variance pi^2/3)
* The observed score distribution is approximately normal (mean 6.95, SD 1.60,
* symmetric around 7), which is consistent with a normal latent y*, so oprobit
* is the appropriate choice.
*
* Oprobit specifics from the notes:
*   - Latent variable: y* = X*beta + e (unobservable but believed to exist).
*   - Cutpoints c_1, ..., c_{k-1} define boundaries between observed categories.
*   - No intercept -- replaced by cutpoints.
*   - Estimated via MLE.
*   - Parallel regression assumption: each predictor's effect is constant
*     across cutpoints. Checked in section 6a via oparallel on a bucketed score
*     (proxy; see note there on why bucketing is needed).
*   - Raw coefficients are on the latent y* scale; interpret via margins.
*
* Count models (Poisson / Negative Binomial) are tested in a separate do-file
* (score-regression-count.do) for comparison. Per the class decision rule
* (variance ~ mean -> Poisson; variance >> mean -> NB), the observed variance
* (2.55) is far below the mean (6.95), i.e. under-dispersion, so count models
* are not the natural fit here -- but the comparison is run for completeness.
*
* Required packages (install once):
*   ssc install oparallel   (parallel-regression tests: Brant, Wolfe-Gould, Wald, LR)
*   ssc install estout      (esttab for exporting regression tables to RTF/CSV)
* (McFadden's pseudo-R2 is printed in oprobit's own output header.)
*
* Output locations (all in figs/ subfolder):
*   .png files -- histograms
*   .rtf files -- regression tables (Word)
*   .csv files -- regression tables (spreadsheet / copy-paste)
*   .txt files -- captured log output (diagnostics, margins)

clear all
set more off
* cd "set your working directory here"
cap mkdir "figs"

use "data/AI_DetectionV3_lite.dta", clear

rename score_total score

* 1. Dependent variable summary -- confirm approximate normality before oprobit
cap log close sum_prefilter
log using "figs/score_summary_prefilter.txt", text replace name(sum_prefilter)
summarize score, detail
log close sum_prefilter

histogram score, normal xtitle("score (correct out of 10)")
graph export "figs/score_hist.png", replace

* 2. Ideal-dataset filter
* Keep: passed both attention checks AND device is Mobile/Laptop AND
* ln(avg_resp_time) within mean +/- 3 SD.
* Three-step logic:
*   (a) attention-check filter first, so every subsequent SD/sample is
*       computed on people we've already decided to keep.
*   (b) drop "Other" device respondents (n=9, all iPads). Sample is too
*       small to identify a separate iPad effect and it muddies the core
*       Mobile vs Laptop contrast. Keeping only the two main screen classes.
*   (c) filter on ln(avg_resp_time), not raw avg_resp_time. Raw response times
*       are extreme right-skewed (skew ~6 even post-attention-filter), so raw
*       +/-3 SD barely cuts anyone -- the SD is dominated by the very outliers
*       we want to remove. Log-scale ~ normal, so log +/-3 SD corresponds to
*       the intended ~0.1% tails in each direction.
count
display "n before filter: " r(N)

* (a) attention check
keep if attn_both == 1
count
display "n after attention filter: " r(N)

* (b) drop "Other" device respondents
decode device_type, gen(_dev_str)
count if _dev_str == "Other"
display "n 'Other' device dropped: " r(N)
drop if _dev_str == "Other"
drop _dev_str
count
display "n after device filter: " r(N)

* (c) log-scale response-time trim
gen ln_resp_time = ln(avg_resp_time)
summarize ln_resp_time
local lnm = r(mean)
local lns = r(sd)
keep if inrange(ln_resp_time, `lnm' - 3*`lns', `lnm' + 3*`lns')
count
display "n after filter: " r(N)

* Check changes after filtering for ideal respondants
cap log close sum_postfilter
log using "figs/score_summary_postfilter.txt", text replace name(sum_postfilter)
summarize score, detail
log close sum_postfilter

histogram score, normal xtitle("score (correct out of 10)")
graph export "figs/score_hist_filtered.png", replace

* 3. Binary age from affiliation
* over_25 = 1 if Faculty/Staff, 0 if student. All Bowdoin students <25 for
* the purposes of this study; simplification is ok even though some students
* may not fall exactly in that bucket.
decode affiliation, gen(_affil_str)
gen over_25 = (_affil_str == "Faculty/Staff")
drop _affil_str

* 3a. Combined international flag
cap drop international
gen international = (intl_student == 1 | intl_faculty == 1)
tab international, missing

* 3c. Collapse PNS into Non-binary for gender (overwrite gender in place)
* Raw gender has 4 levels: Man (1), Woman (2), Non-binary (3), PNS (4).
* Non-binary (n=10) and PNS (n=15) are both small; merge PNS into Non-binary
* so the residual category has n=25 and can be estimated more reliably.
recode gender (4 = 3)
label define gender_lbl ///
    1 "Man" ///
    2 "Woman" ///
    3 "Other" , replace
label values gender gender_lbl
tab gender, missing

* 3b. Collapse sparse race categories into "Other" (overwrite race in place)
* Raw race has 7 levels, but two of them are too small to identify:
*   International (n=1) and Race/ethnicity unknown (n=2).
* Collapse both (plus anything else sparse) into a single "Other" bucket so
* each race coefficient is estimated on at least a few observations.
recode race (6 = 8) (7 = 8)
label define race_lbl ///
    1 "White" ///
    2 "Asian" ///
    3 "Black or African American" ///
    4 "Hispanic or Latino" ///
    5 "Two or more races" ///
    8 "Other" , replace
label values race race_lbl
tab race, missing

* 3b. Response time -- describe the predictor
* ln_resp_time was generated in section 2 for the filter; now describe it
* (and avg_resp_time) for the model specification. ln_resp_time enters the
* oprobit as a continuous predictor: coefficient = change in y* per unit of
* ln(seconds), i.e. per factor-of-e response-time increase (x 2.718).
summarize avg_resp_time, detail
histogram avg_resp_time, xtitle("avg response time (s)")
graph export "figs/resp_time_hist.png", replace

summarize ln_resp_time, detail
histogram ln_resp_time, normal xtitle("ln(avg response time)")
graph export "figs/ln_resp_time_hist.png", replace

* 4. Model sequence -- ordered probit with robust SEs
* All models use i.over_25 (binary age: 1 if Faculty/Staff, else 0) instead of
* i.affiliation. Rationale: class cohort (Class of 2024/25/26/27) is not the
* construct of interest -- it's age we care about, and over_25 is the intended
* binary proxy. Keeping all specs on a single age variable keeps AIC/BIC
* comparisons apples-to-apples. Demographic controls (gender, race) are carried
* in every model to isolate the marginal contribution of the AI-exposure and
* behavioral predictors. Disability is dropped -- cells are too sparse at
* n~400 to identify a separate effect, and it was the main cause of perfect
* prediction in the parallel-regression diagnostic.

*Model 0: baseline
oprobit score i.gender i.race, vce(robust)
estimates store m0

* Model 1a: age
oprobit score i.over_25 i.gender i.race, vce(robust)
estimates store m1a

* Model 1b: + device
oprobit score i.device_type i.gender i.race, vce(robust)
estimates store m1b

* Model 2: + age + device
oprobit score i.over_25 i.device_type i.gender i.race, vce(robust)
estimates store m2

* Model 3a: + AI usage
oprobit score i.over_25 i.device_type c.ai_use_time i.gender i.race, vce(robust)
estimates store m3a

*Model 3b:  + AI familiarity
oprobit score i.over_25 i.device_type c.ai_familiarity i.gender i.race, vce(robust)
estimates store m3b

* Model 3c: familiarity x usage interaction
oprobit score i.over_25 i.device_type i.gender i.race ///
    c.ai_familiarity##c.ai_use_time, vce(robust)
estimates store m3c

* Model 4: full main effects -- + social media
oprobit score i.over_25 i.device_type i.gender i.race ///
    c.ai_familiarity##c.ai_use_time c.social_media_time, vce(robust)
estimates store m4

* Model 5: m4 + log response time
* Tests whether time-on-task predicts detection accuracy after age/device.
* Also acts as a mediation check: if the mobile or over_25 coefficients shrink
* substantially vs m4, their effects run through response time (mobile = slower,
* older = slower) rather than device/age per se.
oprobit score i.over_25 i.device_type i.gender i.race ///
    c.ai_familiarity##c.ai_use_time c.social_media_time ///
    c.ln_resp_time, vce(robust)
estimates store m5

* 5. Side-by-side comparison -- AIC/BIC/N
estimates stats m0 m1a m1b m2 m3a m3b m3c m4 m5

* Export combined model table (coefficients + SEs + stars + IC stats)
* Columns ordered left-to-right from simplest to most complex.
* Significance legend: * p<0.05, ** p<0.01, *** p<0.001 (printed by esttab)
* RTF opens in Word; CSV opens in Excel / paste into docs.
esttab m0 m1a m1b m2 m3a m3b m3c m4 m5 using "figs/oprobit_models.rtf", replace ///
    b(3) se(3) star(* 0.05 ** 0.01 *** 0.001) ///
    stats(N ll r2_p chi2 p aic bic, ///
          labels("N" "Log-lik" "Pseudo R2" "Wald chi2" "Prob > chi2" "AIC" "BIC") ///
          fmt(0 2 4 2 4 1 1)) ///
    label nogaps ///
    mtitles("m0" "m1a" "m1b" "m2" "m3a" "m3b" "m3c" "m4" "m5") ///
    title("Ordered probit of detection score on respondent characteristics")

esttab m0 m1a m1b m2 m3a m3b m3c m4 m5 using "figs/oprobit_models.csv", replace ///
    b(3) se(3) star(* 0.05 ** 0.01 *** 0.001) ///
    stats(N ll r2_p chi2 p aic bic, ///
          labels("N" "Log-lik" "Pseudo R2" "Wald chi2" "Prob > chi2" "AIC" "BIC") ///
          fmt(0 2 4 2 4 1 1)) ///
    label nogaps ///
    mtitles("m0" "m1a" "m1b" "m2" "m3a" "m3b" "m3c" "m4" "m5")

* 6. Diagnostic checks

* 6a. Parallel regression assumption (via oparallel on bucketed score)
* The 11-level score is too sparse at the tails (very few obs at score=2, 3)
* for oparallel to fit the underlying binary-logit series -- it hits perfect
* prediction (r(198)). Bucket score into 3 ordinal levels for the PO test
* only; this is a PROXY test. The primary oprobit uses the full 11 levels.
* p > 0.05 -> assumption holds, oprobit is valid.
* p < 0.05 -> consider gologit2 or mlogit.
cap log close parallel_test
log using "figs/parallel_regression_test.txt", text replace name(parallel_test)
recode score (0/5 = 1 "Low (<=5)") (6/7 = 2 "Moderate (6-7)") (8/10 = 3 "Strong (>=8)"), gen(score_cat)
ologit score_cat i.over_25 i.device_type i.gender c.social_media_time c.ln_resp_time
capture noisily oparallel
if _rc {
    display as text "oparallel failed (likely perfect prediction in bucketed score with" ///
        " full covariate set). Skipping PO test for this spec."
    display as text "Fallback: try a sparser bucketing or drop demographics to rerun."
}
log close parallel_test
drop score_cat

* 6b. Multicollinearity via parallel OLS (estat vif not available after MLE)
cap log close vif_check
log using "figs/vif.txt", text replace name(vif_check)
quietly reg score i.over_25 i.device_type i.gender i.race c.social_media_time c.ln_resp_time
estat vif
log close vif_check

* 7. Interpretation via margins -- latent-scale AMEs for every model
* No predict() option => margins defaults to the linear predictor (y*), so
* the reported dy/dx is the average marginal effect on the latent detection-
* ability scale (SD units of y*). Gives sign/magnitude comparability across
* predictors without committing to a particular score level.
* Output goes to the main oprobit-regression.log (no separate .txt file).
foreach m in m0 m1a m1b m2 m3a m3b m3c m4 m5 {
    display _newline(2) " Margins for `m' "
    estimates restore `m'
    margins, dydx(*)
}

* Interpretation notes:
* - Oprobit coefficients are on the latent y* scale -- interpret sign/significance
*   only, then use margins for magnitudes (as in the auto.dta worked example
*   in class notes: oprobit rep78 foreign length mpg ; margins, dydx(*)).
* - For a specific outcome level (e.g. score = 7), use predict(outcome(#)) as above.
* - DV is a count out of 10, not a probability -- do NOT use p.p. language
*   when describing effects on the raw score scale.
