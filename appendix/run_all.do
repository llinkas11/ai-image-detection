* Master Stata runner for the appendix build.
* Strategy: cd into _outputs before running anything. The analysis
* .do files use relative paths for input and output, so running them
* with _outputs as the cwd auto-routes everything into the build tree.
* No edits to the analysis scripts are needed.

clear all
set more off

* Move into the build output tree. data/ already populated by build.sh.
cd "_outputs"

cap mkdir "logs"
cap mkdir "figs"
cap mkdir "figs/descriptives"
cap mkdir "figs/exploratory"
cap mkdir "tables"


* ---------------------------------------------------------------------------
* B: descriptive statistics + filter pipeline
* ---------------------------------------------------------------------------
cap log close section_b
log using "logs/B_descriptives.log", text replace name(section_b)
do "../../analysis/descriptives.do"
log close section_b


* ---------------------------------------------------------------------------
* C: exploratory bivariate analysis (new)
* The dataset is already in memory and post-filter from descriptives.do.
* ---------------------------------------------------------------------------
cap log close section_c
log using "logs/C_exploratory.log", text replace name(section_c)
do "../exploratory.do"
log close section_c


* ---------------------------------------------------------------------------
* C.5: t-tests of score by device type (per cohort + pooled)
* Mirrors slides 22 and 23 of the presentation deck.
* ---------------------------------------------------------------------------
cap log close section_c5
log using "logs/C5_ttests.log", text replace name(section_c5)
do "../ttests.do"
log close section_c5


* ---------------------------------------------------------------------------
* D: main ordered probit, m1 through m6
* ---------------------------------------------------------------------------
cap log close section_d
log using "logs/D_oprobit_main.log", text replace name(section_d)
do "../../analysis/oprobit_regression.do"
log close section_d


* ---------------------------------------------------------------------------
* E: subsample analysis (faculty-only, student-only)
* The by_affiliation script expects oprobit_regression.do to have run.
* ---------------------------------------------------------------------------
cap log close section_e
log using "logs/E_subsample.log", text replace name(section_e)
do "../../analysis/oprobit_regression_by_affiliation.do"
log close section_e


* ---------------------------------------------------------------------------
* F.1: pooled m2 diagnostics
* ---------------------------------------------------------------------------
cap log close section_f1
log using "logs/F1_diagnostics_pooled.log", text replace name(section_f1)
do "../../analysis/m2_diagnostics.do"
log close section_f1


* ---------------------------------------------------------------------------
* F.2 + F.3 + F.4: subsample diagnostics (faculty + student PO tests, VIFs)
* ---------------------------------------------------------------------------
cap log close section_f23
log using "logs/F23_diagnostics_subsample.log", text replace name(section_f23)
do "../po_subsample_tests.do"
log close section_f23


* ---------------------------------------------------------------------------
* H: count-model robustness (Poisson, Negative Binomial)
* ---------------------------------------------------------------------------
capture confirm file "../../analysis/score_regression_count.do"
if !_rc {
    cap log close section_h
    log using "logs/H_count_models.log", text replace name(section_h)
    do "../../analysis/score_regression_count.do"
    log close section_h
}
else {
    di as text "Skipping H: score_regression_count.do not synced yet."
}


* Move generated regression-table CSVs/RTFs from figs/ to tables/
foreach f in oprobit_models.csv oprobit_models.rtf {
    capture confirm file "figs/`f'"
    if !_rc copy "figs/`f'" "tables/`f'", replace
}

display _newline "All sections complete. Outputs in _outputs/"
