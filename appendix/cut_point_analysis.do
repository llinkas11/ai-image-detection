* Cut-point analysis for the faculty mf3b spec.
*
* Ordered probit estimates k-1 cut points for a k-level outcome. The gap
* between adjacent cut points is the latent-scale distance respondents
* must cover to move from one observed score level to the next. If the
* gaps are equal, the score levels reflect equally-spaced latent ability;
* if one gap is much larger, that score transition is harder.
*
* This script computes all adjacent gaps with nlcom, identifies the
* maximum gap, and Wald-tests it against each other gap. Cut-count is
* detected at runtime because the faculty subsample uses fewer score
* levels than the pooled model (some scores have zero respondents in
* n=73 faculty), and Stata's e(k_cat) reports the nominal level count
* rather than the count of estimable cut points.
*
* Assumes mf3b is in memory from oprobit_regression_by_affiliation.do.

display _newline(2) "=========================================="
display "Cut-point analysis: faculty mf3b"
display "=========================================="

estimates restore mf3b

* Probe each candidate cut-point name; stop at the first one that doesn't
* exist. Handles sparse-category collapse where e(k_cat) over-counts.
local k = 1
while 1 {
    capture display _b[/cut`k']
    if _rc {
        local k = `k' - 1
        continue, break
    }
    local k = `k' + 1
}
local n_cuts = `k'
display _newline "Faculty model has " `n_cuts' " cut points (" `n_cuts' - 1 " adjacent gaps)."


* Compute all adjacent gaps with nlcom in one pass.
local gap_args = ""
forvalues i = 1/`=`n_cuts'-1' {
    local j = `i' + 1
    local gap_args `"`gap_args' (gap`i': _b[/cut`j'] - _b[/cut`i'])"'
}

display _newline "All adjacent cut-point gaps with 95% CIs:"
nlcom `gap_args'

* Identify the largest gap by scanning r(b) directly (no second pass).
matrix gaps = r(b)
local maxgap_idx = 1
local maxgap_val = gaps[1, 1]
forvalues i = 2/`=colsof(gaps)' {
    if gaps[1, `i'] > `maxgap_val' {
        local maxgap_idx = `i'
        local maxgap_val = gaps[1, `i']
    }
}

display _newline "Largest gap: gap" `maxgap_idx' " = " %5.3f `maxgap_val'
display "  (transition between observed scores " `maxgap_idx' - 1 " and " `maxgap_idx' " on the latent scale)"


display _newline "Pairwise Wald tests of largest gap against each other gap:"
display "(H0: gap_i == max_gap; rejection means max_gap is significantly larger)"

local maxj = `maxgap_idx' + 1
forvalues i = 1/`=`n_cuts'-1' {
    if `i' == `maxgap_idx' continue
    local j = `i' + 1
    display _newline "  vs gap" `i' " (cut" `i' " to cut" `j' "):"
    test (_b[/cut`maxj'] - _b[/cut`maxgap_idx']) = (_b[/cut`j'] - _b[/cut`i'])
}


* Bar chart of the gaps (requires coefplot)
cap mkdir "figs/cut_points"
capture which coefplot
if _rc == 0 {
    coefplot, vertical xtitle("Score transition") ///
        ytitle("Latent gap (cut difference)") ///
        title("Faculty cut-point gaps (mf3b)") ///
        ciopts(recast(rcap)) recast(bar)
    graph export "figs/cut_points/faculty_gaps.png", replace width(1200)
}
else {
    display _newline "coefplot not installed; install via: ssc install coefplot"
}
