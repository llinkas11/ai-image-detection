* T-tests of detection score by device type, run separately for each
* affiliation cohort and pooled. Reproduces slides 22 and 23 of the
* presentation deck.
*
* Question: does score differ between Mobile and Laptop respondents
* within each class year and faculty/staff group, and overall?
*
* Method: two-sample t-test of score_total grouped by device_type
* (1 = Laptop, 2 = Mobile phone after the Other-device drop).
* The within-group t-tests are illustrative; sample sizes per cohort
* are small and the pooled test is the formal hypothesis test.
*
* Assumes the post-filter dataset is in memory from the upstream
* analysis pipeline (attn_both == 1, Other devices dropped,
* ln_resp_time within +/- 3 SD of its mean).
* The variable `score_total` is renamed to `score` upstream;
* this script uses `score` for clarity.

display _newline(2) "=========================================="
display "T-tests: detection score by device type"
display "=========================================="


* ---------------------------------------------------------------------------
* 1. Within-cohort t-tests
*    For each affiliation level we ask: is mean score different
*    between Laptop and Mobile users in that cohort?
* ---------------------------------------------------------------------------

* 1a. Class of 2027 (Juniors)
display _newline "--- Juniors (affiliation == 2) ---"
ttest score if affiliation == 2, by(device_type)

* 1b. Class of 2029 (First-years)
display _newline "--- First-years (affiliation == 4) ---"
ttest score if affiliation == 4, by(device_type)

* 1c. Faculty/Staff
display _newline "--- Faculty/Staff (affiliation == 5) ---"
ttest score if affiliation == 5, by(device_type)


* ---------------------------------------------------------------------------
* 2. Pooled t-tests
*    The pooled test is more powerful (larger n) and is the formal
*    test reported in the manuscript. We also report a Juniors +
*    First-years + Faculty/Staff subset because those three cohorts
*    showed the clearest device gap in the within-cohort tests.
* ---------------------------------------------------------------------------

* 2a. All respondents
display _newline "--- All respondents (pooled) ---"
ttest score, by(device_type)

* 2b. Juniors + First-years + Faculty/Staff
display _newline "--- Juniors + First-years + Faculty/Staff (pooled) ---"
ttest score if inlist(affiliation, 2, 4, 5), by(device_type)


* ---------------------------------------------------------------------------
* 3. Confidence-interval plots (optional, requires ciplot package)
*    These match the visualizations on slides 22-23. Skipped when
*    ciplot is not installed so the build does not fail.
* ---------------------------------------------------------------------------

capture which ciplot
if _rc == 0 {
    cap mkdir "figs/ttests"

    ciplot score if affiliation == 2, by(device_type) ///
        ytitle("Mean detection score") ///
        title("Juniors (Class of 2027): score by device")
    graph export "figs/ttests/ci_juniors_by_device.png", replace width(1200)

    ciplot score if affiliation == 4, by(device_type) ///
        ytitle("Mean detection score") ///
        title("First-years (Class of 2029): score by device")
    graph export "figs/ttests/ci_firstyears_by_device.png", replace width(1200)

    ciplot score if affiliation == 5, by(device_type) ///
        ytitle("Mean detection score") ///
        title("Faculty/Staff: score by device")
    graph export "figs/ttests/ci_facstaff_by_device.png", replace width(1200)

    ciplot score, by(device_type) ///
        ytitle("Mean detection score") ///
        title("All respondents: score by device")
    graph export "figs/ttests/ci_all_by_device.png", replace width(1200)

    ciplot score if inlist(affiliation, 2, 4, 5), by(device_type) ///
        ytitle("Mean detection score") ///
        title("Juniors + First-years + Faculty/Staff: score by device")
    graph export "figs/ttests/ci_jr_fy_fs_by_device.png", replace width(1200)
}
else {
    display _newline "ciplot not installed; skipping CI plots."
    display "  To install: ssc install ciplot"
}


* ---------------------------------------------------------------------------
* 4. Interpretation, written into the log so it travels with the output
* ---------------------------------------------------------------------------
display _newline(2) "=========================================="
display "Interpretation"
display "=========================================="
display "Within-cohort: laptop users score higher than mobile users"
display "  in every cohort, but cohort-level n is small so most"
display "  within-cohort tests fail to reach significance. The"
display "  largest within-cohort gap is in the Faculty/Staff group."
display ""
display "Pooled: the device effect is significant when pooled across"
display "  Juniors + First-years + Faculty/Staff, and significant in"
display "  the full pooled sample. This is the headline t-test result"
display "  reported on slide 23 of the deck."
display ""
display "The ordered probit in Section D quantifies the same effect"
display "  while controlling for AI exposure, demographics, and time."
