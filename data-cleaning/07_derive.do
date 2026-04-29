* Step 07: derive 12 analysis-ready variables on top of the 49 cleaned base
* variables. Final dataset: 61 variables, 508 observations.

clear all
set more off
use "AI_DetectionV3_lite.dta", clear


* ---------------------------------------------------------------------------
* Outcome counts: how many TP / TN / FP / FN per respondent across q1..q10
* ---------------------------------------------------------------------------
gen byte tp_count = 0
gen byte tn_count = 0
gen byte fp_count = 0
gen byte fn_count = 0
forvalues i = 1/10 {
    replace tp_count = tp_count + (q`i' == 1) if !missing(q`i')
    replace tn_count = tn_count + (q`i' == 2) if !missing(q`i')
    replace fp_count = fp_count + (q`i' == 3) if !missing(q`i')
    replace fn_count = fn_count + (q`i' == 4) if !missing(q`i')
}

label variable tp_count "True positives (correctly identified AI)"
label variable tn_count "True negatives (correctly identified real)"
label variable fp_count "False positives (real called AI)"
label variable fn_count "False negatives (AI called real)"


* ---------------------------------------------------------------------------
* Outcome rates: TP rate among AI images seen, TN rate among real seen, etc.
* Stata's standard formula avoids division by zero by leaving the rate
* missing when the denominator is zero (rare but possible if a respondent
* was shown only fakes or only reals).
* ---------------------------------------------------------------------------
gen float tp_rate = tp_count / (tp_count + fn_count) if (tp_count + fn_count) > 0
gen float tn_rate = tn_count / (tn_count + fp_count) if (tn_count + fp_count) > 0
gen float fp_rate = fp_count / (tn_count + fp_count) if (tn_count + fp_count) > 0
gen float fn_rate = fn_count / (tp_count + fn_count) if (tp_count + fn_count) > 0

label variable tp_rate "TP rate (TP / AI images seen)"
label variable tn_rate "TN rate (TN / real images seen)"
label variable fp_rate "FP rate (FP / real images seen)"
label variable fn_rate "FN rate (FN / AI images seen)"


* ---------------------------------------------------------------------------
* Average per-image confidence
* ---------------------------------------------------------------------------
egen float avg_conf = rowmean(q1_conf q2_conf q3_conf q4_conf q5_conf ///
                              q6_conf q7_conf q8_conf q9_conf q10_conf)
label variable avg_conf "Mean per-image confidence (0-10)"


* ---------------------------------------------------------------------------
* Both attention checks passed
* ---------------------------------------------------------------------------
gen byte attn_both = (attn_check1 == 1 & attn_check2 == 1)
label variable attn_both "Passed both attention checks"
label define attn_lbl 0 "Failed at least one" 1 "Passed both", replace
label values attn_both attn_lbl


* ---------------------------------------------------------------------------
* Verify CalculatedScore matches our derivation
* ---------------------------------------------------------------------------
capture confirm variable calc_score
if !_rc {
    quietly count if calc_score != tp_count + tn_count & !missing(calc_score)
    if r(N) > 0 {
        display "WARNING: " r(N) " rows where calc_score differs from tp_count+tn_count"
    }
    else {
        display "calc_score matches tp_count + tn_count for all rows"
    }
}


save "AI_DetectionV3_lite.dta", replace
display _newline "final dataset: `c(k)' variables, `c(N)' observations"
display "ready for analysis/ scripts"
