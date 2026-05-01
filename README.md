# AI Detection Study

A Bowdoin College senior project investigating whether people can reliably distinguish AI-generated images from real photographs, and which respondent characteristics predict detection ability.

**Authors:** Lulu Linkas, Seamus Woodruff, Maddy Ohta
**Course:** DCS 3850 Advanced Data Science, Spring 2026
**Live site:** *https://seamuswoodruff.github.io/ai-detection/*

## Headline findings

Analytic sample after filtering: **N = 419** (508 starting; 74 dropped on attention checks, 10 on "Other" devices, 5 on log response-time trim). Models that include all AI-exposure predictors (m4, m5) drop 18 more on covariate missingness and report on N = 401.

From the preferred ordered probit specification (**m2**: `score = age + device + gender + race`):

- **Age effect.** Being Faculty/Staff (proxied by `over_25`) is a statistically significant predictor of lower detection scores. Margins at specific outcomes show that being over 25 decreases the probability of scoring 8, 9, or 10 by 3 to 5 percentage points, and increases the probability of scoring 4, 5, or 6 by 1 to 2 percentage points.
- **Device effect (pooled t-test).** Pooled across all respondents with both attention checks passed, laptop users scored 0.53 points higher than mobile users (highly significant in the t-test).
- **Device effect (regression with controls).** In the pooled m2 regression, device type is marginally significant overall and the per-outcome margins are not individually significant, indicating the device gap shrinks once age, gender, and race are held constant. In the **student-only** subsample, device type is significant at the top of the score distribution (p < 0.05): using a phone instead of a laptop decreases the probability of scoring 9 or 10 by 3 to 4 percentage points. In the **faculty-only** subsample, device is not statistically significant at any outcome.
- **AI exposure.** Self-reported AI familiarity, weekly AI usage time, and the **`ai_familiarity x ai_use_time` interaction** are all non-significant. Adding them does not improve fit beyond the demographic controls.
- **Cut-point structure (faculty).** In the faculty subsample, the cut-point gap between scores 7 and 8 is significantly larger than the other adjacent gaps. The 9 to 10 jump is the hardest for faculty respondents to make.

Two things predict score in the pooled regression: being a student rather than faculty, and (in the t-test and student subsample) using a laptop. Self-reported AI exposure does not. Full coefficient tables are in `results/oprobit_models.csv` and the technical appendix.

## Repository layout

```
ai-image-detection/
├── README.md                   this file
├── methodology.md              study design, sampling, analysis plan
├── LICENSE                     MIT
├── survey/                     Qualtrics survey builder + response exporter
├── analysis/                   Stata do files (ordered probit + diagnostics)
├── results/                    aggregated summary stats + figures
├── presentation/               final presentation (.pptx)
└── data/                       schema documentation (no raw data)
```

## Reproducing the analysis

Raw individual-level responses are not included in this repository to protect respondent privacy (see `data/README.md`). The analysis code is included for transparency. To run it on equivalent data:

1. **Survey construction** (optional, the survey already ran):
   ```
   export QUALTRICS_API_TOKEN=your_token
   cd survey
   python3 build_survey.py
   ```

2. **Response export**:
   ```
   export QUALTRICS_API_TOKEN=your_token
   cd survey
   python3 export_responses.py
   ```
   Writes `survey_responses.csv`.

3. **Stata analysis**:
   - `analysis/descriptives.do` - summary stats, histograms
   - `analysis/oprobit_regression.do` - main ordered probit models
   - `analysis/oprobit_regression_by_affiliation.do` - faculty vs student subsamples
   - `analysis/m2_diagnostics.do` - parallel regression test, VIF

   Requires Stata 18 and the `oparallel` and `estout` packages:
   ```
   ssc install oparallel
   ssc install estout
   ```

## Ordered probit assumptions and how we checked each

| Assumption | Check applied | Result |
|---|---|---|
| **Ordinal dependent variable.** The outcome must be an ordered categorical variable. | Detection score is an integer count from 0 to 10 with natural ordering (higher = better). | Met by construction. |
| **Parallel slopes / proportional odds.** The relationship between predictors and the outcome is the same across all cut-points (the effect of x on "low vs medium/high" matches "low/medium vs high"). | Brant, Wolfe-Gould, score, likelihood ratio, and Wald tests via `oparallel` on a 3-level bucketed score (0-5, 6-7, 8-10). Pooled m2 and both subsample specs (faculty mf3b, student ms4) tested. | Not rejected for the pooled m2 (all p > 0.05), the faculty subsample (all p > 0.33), or the student subsample (all p > 0.18 (Wald χ²(10) = 12.77, p = 0.237)). If violated, the alternative is `gologit2` or generalized ordered probit. |
| **Independence of observations.** Each respondent's score is independent of every other respondent's. | The survey was an anonymous online instrument with no clustering structure (no within-classroom or within-team groups). Cluster-robust standard errors not required. | Met by design. |
| **Heteroskedasticity-robust standard errors.** Inference should remain valid even if the latent error variance differs across observations. | Every ordered probit call uses `vce(robust)`, including the pooled m1b through m5 specifications and the faculty (mf0..mf5) and student (ms0..ms5) subsample sequences. | Applied throughout the analysis. |
| **No perfect multicollinearity.** Predictors must not be perfectly correlated. | Variance Inflation Factors (VIF) on a parallel OLS of the m2 spec (Stata's `estat vif` is unavailable after MLE). | Mean VIF = 1.26, max = 1.63, all well below the conventional threshold of 5. The structurally inflated VIFs on `c.ai_familiarity##c.ai_use_time` and its components are expected for interaction models and not a concern. |
| **No separation or quasi-separation.** A predictor must not perfectly predict the outcome. | Cross-tabulations of every categorical predictor against the outcome to check for empty or very small cells. | Two race categories (International, n = 1; Race/ethnicity unknown, n = 2) caused perfect prediction in the bucketed-score `oparallel` test and were collapsed into "Other" before re-running. Final analytic categories all have non-zero cells in every score bucket. |

Full diagnostic output, including the `oparallel` log and VIF table, is in the technical appendix (Section F of `appendix/appendix.docx`).

## Presentation

See `presentation/ai-detection.pptx` for the final slide deck. This covers study motivation, design, analytical methods, and results.

## Data cleaning

The `data-cleaning/` folder is a single concise reproducible document covering the seven-step pipeline that turns the raw Qualtrics export (2 batch CSVs, 639 columns each, merged to 508 responses) into the analytic dataset (`AI_DetectionV3_lite.dta`, 61 variables). Each step has prose explanation plus a runnable script. See `data-cleaning/README.md`.

## Reproducible appendix

The `appendix/` folder contains a single-command build (`bash appendix/build.sh`) that regenerates a technical appendix walking through every analytical step: filter pipeline, descriptives, exploratory analysis, model specification and progression, subsample analysis, diagnostics (parallel-regression test, VIF, on the pooled and both subsamples), margins, and count-model robustness. Output is `appendix/appendix.docx` (and `appendix.pdf` if `pdflatex` is installed). See `appendix/README.md` for build requirements.

## License

MIT. See `LICENSE`.

## Contact

For data access requests or methodological questions: llinkas@gmail.com or v.gomezgilyaspik@bowdoin.edu
