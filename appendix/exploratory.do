* Section C exploratory analysis: bivariate views of detection score
* against each predictor of interest, plus pairwise ANOVA across class years.
*
* Assumes the post-filter dataset is in memory from descriptives.do
* (attention check applied, Other devices dropped, ln_resp_time +/-3 SD).
* Derives over_25 inline so this script is self-contained when called
* before oprobit_regression.do (which would otherwise create over_25).

cap mkdir "figs/exploratory"

* Self-contained data prep: if oprobit_regression.do has not run yet, do
* the same recodes here so over_25, collapsed gender/race, and the
* binary device_type are all present. Wrapped in a capture so re-running
* after recodes already exist is a no-op.
capture confirm variable over_25
if _rc {
    decode affiliation, gen(_affil_str)
    gen over_25 = (_affil_str == "Faculty/Staff")
    drop _affil_str
    label define over_25_lbl 0 "Student" 1 "Faculty/Staff", replace
    label values over_25 over_25_lbl

    decode device_type, gen(_dev_str)
    drop if _dev_str == "Other"
    drop _dev_str

    recode gender (4 = 3)
    label define gender_lbl 1 "Man" 2 "Woman" 3 "Other", replace
    label values gender gender_lbl

    recode race (6 = 8) (7 = 8)
    label define race_lbl 1 "White" 2 "Asian" 3 "Black or African American" ///
        4 "Hispanic or Latino" 5 "Two or more races" 8 "Other", replace
    label values race race_lbl
}


* C.1: score by affiliation (5-level: 4 class years + Faculty/Staff)
graph box score, over(affiliation, label(angle(45))) ///
    title("Score by affiliation") ///
    ytitle("Detection score (0-10)") ///
    note("Box: IQR; whiskers: 1.5 x IQR")
graph export "figs/exploratory/box_score_by_affiliation.png", replace width(1200)


* C.2: score by device type
graph box score, over(device_type) ///
    title("Score by device") ///
    ytitle("Detection score (0-10)")
graph export "figs/exploratory/box_score_by_device.png", replace width(1200)


* C.3: score by gender
graph box score, over(gender) ///
    title("Score by gender") ///
    ytitle("Detection score (0-10)")
graph export "figs/exploratory/box_score_by_gender.png", replace width(1200)


* C.4: score by race (collapsed)
graph box score, over(race, label(angle(45))) ///
    title("Score by race") ///
    ytitle("Detection score (0-10)")
graph export "figs/exploratory/box_score_by_race.png", replace width(1200)


* C.5: score vs average response time (log scale)
twoway (scatter score ln_resp_time, mcolor(%30)) ///
       (lfit score ln_resp_time), ///
    title("Score vs ln(response time)") ///
    ytitle("Detection score (0-10)") xtitle("ln(seconds per image)") ///
    legend(order(2 "linear fit"))
graph export "figs/exploratory/scatter_score_vs_ln_resptime.png", replace width(1200)


* C.6: score vs ai_familiarity
twoway (scatter score ai_familiarity, mcolor(%30) jitter(2)) ///
       (lfit score ai_familiarity), ///
    title("Score vs AI familiarity") ///
    ytitle("Detection score (0-10)") xtitle("AI familiarity (1=none, 5=very high)") ///
    legend(order(2 "linear fit"))
graph export "figs/exploratory/scatter_score_vs_ai_fam.png", replace width(1200)


* C.7: score vs ai_use_time
twoway (scatter score ai_use_time, mcolor(%30) jitter(2)) ///
       (lfit score ai_use_time), ///
    title("Score vs AI use time") ///
    ytitle("Detection score (0-10)") xtitle("Weekly AI use bin") ///
    legend(order(2 "linear fit"))
graph export "figs/exploratory/scatter_score_vs_ai_use.png", replace width(1200)


* C.8: pairwise comparisons of mean score by class year (students only)
display _newline "=== Pairwise mean-score comparisons across class years (students) ==="
oneway score affiliation if over_25 == 0, bonferroni


* C.9: t-test of score by device type (overall)
display _newline "=== t-test: score by device type (Mobile vs Laptop) ==="
ttest score, by(device_type)


* C.10: t-test of score by over_25 (Faculty/Staff vs Student)
display _newline "=== t-test: score by Faculty/Staff vs Student ==="
ttest score, by(over_25)


* C.11: correlation matrix of numeric predictors with score
display _newline "=== Pearson correlations: score with numeric predictors ==="
pwcorr score ai_familiarity ai_use_time social_media_time ln_resp_time, sig
