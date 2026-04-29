* Count-Data Sensitivity Check -- Poisson and Negative Binomial
* DV: score (0-10, integer count of correct AI vs real classifications)
*
* Purpose:
* The primary model for this analysis is ordered probit (see score-regression.do).
* Class notes (Count Data Models section) describe a second valid framing for
* integer outcomes: count-data models. This do-file runs that framing as a
* sensitivity check.
*
* Class-notes decision rule:
*   "Is variance approximately equal to mean?  -> Poisson"
*   "Is variance much greater than mean?       -> Negative Binomial"
*
* Expected result here:
* score has mean ~ 6.95, variance ~ 2.55 -- variance is BELOW the mean
* (under-dispersion), not above it. Per the class rule, neither Poisson
* (equi-dispersion) nor NB (over-dispersion) is the textbook fit, but the
* class-notes "why not OLS for counts" reasoning (non-negative integer,
* right-skew pattern) still makes the Poisson/NB family worth reporting as
* a robustness check. We expect:
*   - Poisson SEs to UNDER-state uncertainty a bit less than usual (because
*     variance < mean means the Poisson assumption is already conservative).
*   - NB's dispersion parameter alpha to be near 0 (NB collapses toward Poisson).
* Signs and significance should line up with the oprobit results; if they do,
* conclusions are robust across model families.
*
* Required packages (install once):
*   ssc install estout      (esttab for exporting regression tables to RTF/CSV)
* (poisson and nbreg are native to Stata.)
*
* Output locations (all in figs/ subfolder):
*   .rtf files -- regression tables (Word)
*   .csv files -- regression tables (spreadsheet / copy-paste)
*   .txt files -- captured log output (dispersion check, margins)

clear all
set more off
* cd "set your working directory here"
cap mkdir "figs"

use "data/AI_DetectionV3_lite.dta", clear

rename score_total score

* 1. Same ideal-dataset filter as the main do-file (keep samples comparable)
summarize avg_resp_time
local m = r(mean)
local s = r(sd)
keep if attn_both == 1 & inrange(avg_resp_time, `m' - 3*`s', `m' + 3*`s')

* 2. Confirm dispersion before choosing Poisson vs NB
* Class rule: variance ~ mean -> Poisson; variance >> mean -> NB.
cap log close disp_check
log using "figs/dispersion_check.txt", text replace name(disp_check)
summarize score, detail
display "mean = "     r(mean)
display "variance = " r(Var)
display "ratio var/mean = " r(Var)/r(mean)
log close disp_check

* 3. Binary age from affiliation (same coding as main do-file)
decode affiliation, gen(_affil_str)
gen over_25 = (_affil_str == "Faculty/Staff")
drop _affil_str

* 4. Poisson regression (class notes: `poisson y X1 X2 X3`)
* Run the same specs as the main analysis so oprobit and Poisson are directly
* comparable.

* Model 1: baseline -- affiliation only
poisson score i.affiliation, vce(robust)
estimates store p1

* Model 2: + device
poisson score i.affiliation i.device_type, vce(robust)
estimates store p2

* Model 3: + AI familiarity x usage interaction
poisson score i.affiliation i.device_type ///
    c.ai_familiarity##c.ai_use_time, vce(robust)
estimates store p3

* Model 4 (full): + social media
poisson score i.affiliation i.device_type ///
    c.ai_familiarity##c.ai_use_time c.social_media_time, vce(robust)
estimates store p4

* Model 5: binary age version
poisson score over_25 i.device_type ///
    c.ai_familiarity##c.ai_use_time c.social_media_time, vce(robust)
estimates store p5

* 5. Negative Binomial regression (class notes: `nbreg y X1 X2 X3`)
* NB extends Poisson by adding a dispersion parameter alpha.
* alpha ~ 0 -> Poisson is adequate.
* alpha significantly > 0 -> NB is preferred (over-dispersion).

nbreg score i.affiliation, vce(robust)
estimates store n1

nbreg score i.affiliation i.device_type, vce(robust)
estimates store n2

nbreg score i.affiliation i.device_type ///
    c.ai_familiarity##c.ai_use_time, vce(robust)
estimates store n3

nbreg score i.affiliation i.device_type ///
    c.ai_familiarity##c.ai_use_time c.social_media_time, vce(robust)
estimates store n4

nbreg score over_25 i.device_type ///
    c.ai_familiarity##c.ai_use_time c.social_media_time, vce(robust)
estimates store n5

* 6. Side-by-side comparison
estimates stats p1 p2 p3 p4 p5 n1 n2 n3 n4 n5

* Export combined Poisson + NB tables
* Columns ordered simplest-to-most-complex by # predictors:
*   p1 (affiliation only) < p2 (+device) < p5 (binary-age version, simpler than p3)
*   < p3 (+ai interaction) < p4 (+social_media, full)
* Significance legend: * p<0.05, ** p<0.01, *** p<0.001 (printed by esttab)
esttab p1 p2 p5 p3 p4 using "figs/poisson_models.rtf", replace ///
    b(3) se(3) star(* 0.05 ** 0.01 *** 0.001) ///
    stats(N ll aic bic, labels("N" "Log-lik" "AIC" "BIC") fmt(0 2 1 1)) ///
    label nogaps ///
    mtitles("p1" "p2" "p5" "p3" "p4") ///
    title("Poisson of detection score on respondent characteristics")

esttab p1 p2 p5 p3 p4 using "figs/poisson_models.csv", replace ///
    b(3) se(3) star(* 0.05 ** 0.01 *** 0.001) ///
    stats(N ll aic bic, labels("N" "Log-lik" "AIC" "BIC") fmt(0 2 1 1)) ///
    label nogaps ///
    mtitles("p1" "p2" "p5" "p3" "p4")

esttab n1 n2 n5 n3 n4 using "figs/nbreg_models.rtf", replace ///
    b(3) se(3) star(* 0.05 ** 0.01 *** 0.001) ///
    stats(N ll aic bic, labels("N" "Log-lik" "AIC" "BIC") fmt(0 2 1 1)) ///
    label nogaps ///
    mtitles("n1" "n2" "n5" "n3" "n4") ///
    title("Negative binomial of detection score on respondent characteristics")

esttab n1 n2 n5 n3 n4 using "figs/nbreg_models.csv", replace ///
    b(3) se(3) star(* 0.05 ** 0.01 *** 0.001) ///
    stats(N ll aic bic, labels("N" "Log-lik" "AIC" "BIC") fmt(0 2 1 1)) ///
    label nogaps ///
    mtitles("n1" "n2" "n5" "n3" "n4")

* 7. Interpretation via margins
* Poisson/NB coefficients are on the log-count scale (exp(beta) = incidence
* rate ratio). Use margins to get effects on the expected count scale, which
* is directly comparable to the oprobit predicted-category probabilities.

cap log close margins_p4
log using "figs/margins_p4.txt", text replace name(margins_p4)
estimates restore p4
margins, dydx(*)
log close margins_p4

cap log close margins_n4
log using "figs/margins_n4.txt", text replace name(margins_n4)
estimates restore n4
margins, dydx(*)
log close margins_n4

* Interpretation notes:
* - Poisson / NB coefficients are log-count effects; exp(beta) gives the
*   incidence rate ratio (a ratio change in expected score).
* - Use margins, dydx(*) for average marginal effects on the expected count.
* - If signs/significance across oprobit (main) and Poisson/NB (here) agree,
*   conclusions are robust to the choice of ordered vs count framing.
* - DV is a count out of 10, not a probability -- do NOT use p.p. language.
