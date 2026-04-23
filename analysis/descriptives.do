* Descriptive Statistics -- Ideal respondent sample
* For each variable: tabulation + appropriate chart
*   - Numerical  -> summarize (detail) + histogram with normal overlay
*   - Categorical -> tabulate + pie chart
*
* "Ideal respondent" filter matches score-regression.do:
*   attn_both == 1 AND avg_resp_time within mean +/- 3 SD (full-sample bounds).
*
* Outputs:
*   - Figures saved to figs/descriptives/ as PNG (one per variable)
*   - Summary table saved to descriptives_summary.csv
*
* Organization follows class convention: numeric measures summarized first,
* then categorical tabulations, then per-question breakdowns.

clear all
set more off
* cd "set your working directory here"

capture mkdir "figs"
capture mkdir "figs/descriptives"

use "data/AI_DetectionV3_lite.dta", clear

rename score_total score

* 1. Dependent variable summary -- confirm approximate normality before oprobit
cap log close sum_prefilter
log using "figs/score_summary_prefilter.txt", text replace name(sum_prefilter)
summarize score, detail
log close sum_prefilter

histogram score, normal xtitle("score (correct out of 10)")
graph export "figs/score_hist.png", replace

* 2. Ideal-dataset filter (identical to score-regression.do)
* Keep: passed both attention checks AND avg_resp_time within mean +/- 3 SD.
* Apply the attention-check filter FIRST, then compute the timing mean/SD on
* attention-passing respondents. Otherwise SD is inflated by the same inattentive
* outliers we're trying to remove, pushing the 3 SD upper bound far too wide.
count
display "n before filter: " r(N)
keep if attn_both == 1
count
display "n after attention-check filter: " r(N)

* ----- Diagnostic: why raw +/-3 SD is unusable here
* avg_resp_time is very right-skewed, so its SD is dominated by a handful of
* tail observations. Raw +3 SD lands at ~450s -- it barely cuts anyone, yet
* the distribution still has multi-minute-per-image responses. Show the raw
* SD bands for the record, then move to log scale for the actual filter.
summarize avg_resp_time
local m  = r(mean)
local s  = r(sd)
local p1 = `m' + `s'
local p2 = `m' + 2*`s'
local p3 = `m' + 3*`s'
display "avg_resp_time raw SD bands (diagnostic only, not used as filter):"
display "  mean        = " %7.2f `m' " s"
display "  mean + 1 SD = " %7.2f `p1' " s"
display "  mean + 2 SD = " %7.2f `p2' " s"
display "  mean + 3 SD = " %7.2f `p3' " s"
count if avg_resp_time > `p3'
display "Raw +3 SD would drop only: " r(N) " respondent(s) -- filter is too loose on skewed data"

histogram avg_resp_time, ///
    xline(`m', lcolor(red)) xline(`p1', lcolor(orange) lpattern(dash)) ///
    xline(`p2', lcolor(orange) lpattern(dash)) xline(`p3', lcolor(red) lpattern(dash)) ///
    xlabel(`m' `p1' `p2' `p3', format(%6.0f)) ///
    title("avg_resp_time raw SD bands (diagnostic)") ///
    xtitle("avg response time (s)") ///
    note("Raw scale. Red dashed = raw +3 SD (NOT the filter we apply).") ///
    name(h_resp_sdbands_raw, replace)
graph export "figs/descriptives/hist_avg_resp_time_sdbands.png", replace width(1200)

* ----- Actual filter: +/-3 SD on ln(avg_resp_time)
* Log-transform pulls the right tail in so the distribution is approximately
* symmetric. +/-3 SD on the log scale then corresponds to the intended ~0.1%
* tails (whereas raw +/-3 SD corresponds to far looser bounds).
gen ln_resp_time = ln(avg_resp_time)
summarize ln_resp_time
local lnm  = r(mean)
local lns  = r(sd)
local lnp1 = `lnm' + `lns'
local lnp2 = `lnm' + 2*`lns'
local lnp3 = `lnm' + 3*`lns'
local lnm1 = `lnm' - `lns'
local lnm2 = `lnm' - 2*`lns'
local lnm3 = `lnm' - 3*`lns'

* Back-transform SD bands to seconds for reporting.
display "ln(avg_resp_time) SD bands (attention-passing sample, pre log +/-3 SD cut):"
display "  mean - 3 SD = " %7.2f exp(`lnm3') " s   <-- lower cutoff"
display "  mean - 1 SD = " %7.2f exp(`lnm1') " s"
display "  mean        = " %7.2f exp(`lnm')  " s"
display "  mean + 1 SD = " %7.2f exp(`lnp1') " s"
display "  mean + 2 SD = " %7.2f exp(`lnp2') " s"
display "  mean + 3 SD = " %7.2f exp(`lnp3') " s   <-- upper cutoff"

histogram ln_resp_time, normal ///
    xline(`lnm3', lcolor(red)    lpattern(dash)) ///
    xline(`lnm1', lcolor(orange) lpattern(dash)) ///
    xline(`lnm',  lcolor(red)) ///
    xline(`lnp1', lcolor(orange) lpattern(dash)) ///
    xline(`lnp2', lcolor(orange) lpattern(dash)) ///
    xline(`lnp3', lcolor(red)    lpattern(dash)) ///
    xlabel(`lnm3' `lnm1' `lnm' `lnp1' `lnp2' `lnp3', format(%5.2f)) ///
    title("ln(avg_resp_time) with SD bands (filter scale)") ///
    xtitle("ln(avg response time)") ///
    note("Red dashed = +/-3 SD cutoff (filter applied here)." ///
         "Normal overlay shown to check approximate log-normality.") ///
    name(h_resp_sdbands_ln, replace)
graph export "figs/descriptives/hist_ln_resp_time_sdbands.png", replace width(1200)

count if !inrange(ln_resp_time, `lnm3', `lnp3')
display "Log +/-3 SD will drop: " r(N) " respondent(s)"
keep if inrange(ln_resp_time, `lnm3', `lnp3')
count
display "n after filter: " r(N)

* Post-filter histograms: the "more normal" distribution for the slide deck.
histogram ln_resp_time, normal ///
    title("ln(avg_resp_time) after +/-3 SD cut (analytic sample)") ///
    xtitle("ln(avg response time)") ///
    note("Post-filter distribution with normal overlay.") ///
    name(h_ln_resp_post, replace)
graph export "figs/descriptives/hist_ln_resp_time_postfilter.png", replace width(1200)

histogram avg_resp_time, ///
    title("avg_resp_time after +/-3 SD log cut (analytic sample)") ///
    xtitle("avg response time (s)") ///
    name(h_resp_post, replace)
graph export "figs/descriptives/hist_avg_resp_time_postfilter.png", replace width(1200)

* Check changes after filtering for ideal respondents
cap log close sum_postfilter
log using "figs/score_summary_postfilter.txt", text replace name(sum_postfilter)
summarize score, detail
log close sum_postfilter

histogram score, normal xtitle("score (correct out of 10)")
graph export "figs/score_hist_filtered.png", replace

* 2. Variable lists
* Numerical -- continuous or count measures -> summarize + histogram
local numvars ///
    duration_min detect_easy ai_literacy ///
    score avg_resp_time avg_conf ///
    tp_count tn_count fp_count fn_count ///
    tp_rate tn_rate ai_img_seen real_img_seen ///
    attn_conf1 attn_conf2

* Categorical -- discrete/labelled -> tabulate + pie
* (ordinal Likert scales are treated as categorical since they have few
* labelled buckets and a pie/bar of counts is more readable than a histogram)
local catvars ///
    affiliation student age_group gender race ///
    disability adhd intl_student intl_faculty ///
    device_type ai_familiarity ai_use_time ai_course ///
    social_media_time attn_check1 attn_check2 attn_both

* Per-question variables -- pooled across all 10 questions (not stratified).
* q1..q10 (TP/TN/FP/FN outcomes) and q1_conf..q10_conf (0-10 confidence).
local qvars q1 q2 q3 q4 q5 q6 q7 q8 q9 q10
local qconf q1_conf q2_conf q3_conf q4_conf q5_conf ///
            q6_conf q7_conf q8_conf q9_conf q10_conf

* 3. One-shot summary table for all numerical variables
* Produces a compact N / mean / SD / min / max block for the report appendix.
estpost summarize `numvars', detail
* If estpost not installed, fall back to plain summarize:
* ssc install estout
capture noisily esttab using "descriptives_summary.csv", ///
    cells("count mean sd min p50 max") ///
    nomtitle nonumber replace
if _rc {
    display as text "esttab unavailable (ssc install estout); using summarize instead"
    summarize `numvars'
}

* 4. Numerical variables -- summarize + histogram
foreach v of local numvars {
    display _newline(2) "{hline 70}"
    display "Variable: `v'"
    display "{hline 70}"
    summarize `v', detail
    histogram `v', normal ///
        title("`v'") ///
        xtitle("`v'") ///
        name(h_`v', replace)
    graph export "figs/descriptives/hist_`v'.png", replace width(1200)
}

* 5. Categorical variables -- tabulate + pie chart
foreach v of local catvars {
    display _newline(2) "{hline 70}"
    display "Variable: `v'"
    display "{hline 70}"
    tabulate `v', missing
    graph pie, over(`v') ///
        plabel(_all percent, format(%4.1f) size(small)) ///
        title("`v'") ///
        name(p_`v', replace)
    graph export "figs/descriptives/pie_`v'.png", replace width(1200)
}

* 6. Pooled per-question outcomes + confidence (not stratified per question)
* Reshape to long (respondent x question) so all 10 questions are pooled into
* a single distribution: one tab + pie for TP/TN/FP/FN, one summary + histogram
* for confidence. Uses preserve/restore so the wide file stays intact for the
* cross-tabs in section 7.
preserve
    gen long _rid = _n
    keep _rid `qvars' `qconf'

    * rename q*_conf -> qconf* so reshape long can handle two stubs in one call
    forvalues i = 1/10 {
        rename q`i'_conf qconf`i'
    }
    reshape long q qconf, i(_rid) j(qnum)

    display _newline(2) "{hline 70}"
    display "Pooled question outcomes (all 10 questions combined)"
    display "{hline 70}"
    tabulate q, missing
    graph pie, over(q) ///
        plabel(_all percent, format(%4.1f) size(small)) ///
        title("Response outcomes -- all 10 questions pooled") ///
        name(p_q_pooled, replace)
    graph export "figs/descriptives/pie_q_pooled.png", replace width(1200)

    display _newline(2) "{hline 70}"
    display "Pooled per-question confidence (all 10 questions combined)"
    display "{hline 70}"
    summarize qconf, detail
    histogram qconf, normal discrete ///
        title("Confidence -- all 10 questions pooled") ///
        xtitle("confidence (0-10)") ///
        name(h_qconf_pooled, replace)
    graph export "figs/descriptives/hist_qconf_pooled.png", replace width(1200)
restore

* 7. Cross-tabs worth having on hand for the presentation
display _newline(2) "Cross-tabulations"

* Score by affiliation (group means)
display "{hline 70}"
display "Mean score by affiliation"
display "{hline 70}"
table affiliation, statistic(mean score) statistic(sd score) ///
    statistic(count score)

* Score by device
display "{hline 70}"
display "Mean score by device type"
display "{hline 70}"
table device_type, statistic(mean score) statistic(sd score) ///
    statistic(count score)

* Affiliation x device
display "{hline 70}"
display "Affiliation x Device"
display "{hline 70}"
tabulate affiliation device_type, row

display _newline(2) "Done. Figures in figs/descriptives/ ; summary table in descriptives_summary.csv"
