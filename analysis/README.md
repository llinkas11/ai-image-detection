# Analysis

Stata do-files for the ordered probit analysis, diagnostics, and subsample comparisons.

## Files

| File | Purpose |
|---|---|
| `descriptives.do` | Summary statistics, histograms, cross-tabs of key variables. |
| `oprobit_regression.do` | Main ordered probit on detection score: data cleaning + a progressive sequence of pooled specifications (m1b through m5). |
| `oprobit_regression_by_affiliation.do` | Re-runs the model sequence separately on faculty-only (mf0..mf5) and student-only (ms0..ms5) subsamples. Run after `oprobit_regression.do` in the same Stata session. |
| `m2_diagnostics.do` | Parallel-regression test (`oparallel`) and variance inflation factors (VIF) for the pooled m2 specification. |
| `score_regression_count.do` | Poisson and negative-binomial sensitivity checks against the ordered probit. |

## Requirements

Stata 18 (older versions may work, not tested). Install the external packages used:

```stata
ssc install oparallel
ssc install estout
```

## Inputs

These scripts expect the analytic dataset at `data/AI_DetectionV3_lite.dta` relative to the working directory. The dataset is not included in this repository to protect respondent privacy. See `../data/README.md` for the expected schema and `../data-cleaning/README.md` for how to regenerate it from the raw Qualtrics export.

## Working directory

Each do-file starts with a commented-out `cd` that you will need to un-comment and point at your local clone of this repository.

## Outputs

All scripts write to a `figs/` subdirectory (histograms as PNGs, regression tables as RTF and CSV, diagnostic logs as text). `figs/` is git-ignored.

## Data cleaning sequence

Every analysis script applies the same filter chain at the top:

1. Keep only respondents who passed both attention checks.
2. Drop respondents who used "Other" devices (n = 9, all iPads in the realized sample).
3. Trim log-transformed average response time to plus or minus 3 SD.
4. Collapse sparse race cells (International, Unknown) into Other.
5. Collapse sparse gender cells (Non-binary, Prefer not to say) into Other.

After filtering the analytic sample is **N = 419** respondents (508 starting; minus 74 attention check; minus 10 "Other" device; minus 5 response-time trim). Models including all AI-exposure covariates run on a further reduced N = 401 due to covariate missingness.

## Model sequences

Every regression uses `vce(robust)` for heteroskedasticity-consistent standard errors.

### Pooled sample (in `oprobit_regression.do`)

| Model | Predictors |
|---|---|
| m1b | `i.device_type i.gender i.race` |
| m2 | `i.over_25 i.device_type i.gender i.race` (preferred specification per slide 43) |
| m3a | m2 + `c.ai_use_time` |
| m3b | m2 + `c.ai_familiarity` |
| m3c | m2 + `c.ai_familiarity##c.ai_use_time` |
| m4 | m3c + `c.social_media_time` |
| m5 | m4 + `c.ln_resp_time` |

### Faculty/Staff subsample, `over_25 == 1` (in `oprobit_regression_by_affiliation.do`)

`i.over_25` is dropped from every spec because it is constant within the subsample.

| Model | Predictors |
|---|---|
| mf0 | `i.gender i.race` |
| mf1b | mf0 + `i.device_type` |
| mf3a | mf1b + `c.ai_use_time` |
| mf3b | mf1b + `c.ai_familiarity` |
| mf3c | mf1b + `c.ai_familiarity##c.ai_use_time` |
| mf4 | mf3c + `c.social_media_time` |
| mf5 | mf4 + `c.ln_resp_time` |

### Student subsample, `over_25 == 0` (in `oprobit_regression_by_affiliation.do`)

`i.affiliation` is retained so class-year effects are visible.

| Model | Predictors |
|---|---|
| ms0 | `i.affiliation i.gender i.race` |
| ms1b | ms0 + `i.device_type` |
| ms3a | ms1b + `c.ai_use_time` |
| ms3b | ms1b + `c.ai_familiarity` |
| ms3c | ms1b + `c.ai_familiarity##c.ai_use_time` |
| **ms4** | **ms3c + `c.social_media_time`** (preferred student-only specification) |
| ms5 | ms4 + `c.ln_resp_time` |

## Ordered probit assumptions and how we checked each

Five ordered-probit assumptions need to hold for the inference to be valid. Three are met by design or by the data structure and apply to every scope (pooled, faculty, student); two require empirical checks that we ran separately on each scope. Every regression uses `vce(robust)` so heteroskedasticity does not invalidate the standard errors.

### Assumptions met by design or by construction (apply to all scopes)

| Assumption | Check applied | Result |
|---|---|---|
| Ordinal DV | Score is an integer count from 0 to 10 with natural ordering. | Met by construction. |
| Independence of observations | Anonymous online survey with no clustering structure. Cluster-robust SEs unnecessary. | Met by design. |
| Heteroskedasticity-robust standard errors | Every `oprobit` call uses `vce(robust)`. | Applied throughout. |
| No separation in collapsed categories | Cross-tabs of every categorical predictor against the bucketed score; sparse race cells (International, n = 1; Unknown, n = 2) collapsed into a single "Other" category before any regression. | Resolved before estimation. |

### Pooled sample (m2 spec): parallel regression and VIF

Reported in `m2_diagnostics.do` and captured in `appendix/_outputs/logs/F1_diagnostics_pooled.log`.

| Assumption | Check |
|---|---|
| Parallel slopes / proportional odds | `oparallel` on a 3-level bucketed score (0-5 / 6-7 / 8-10) with predictors `i.over_25 i.device_type i.gender i.race`. All five tests (Brant, Wolfe-Gould, score, LR, Wald) report p > 0.05. Not rejected. |
| No multicollinearity | VIF on parallel OLS of the m2 covariates. Mean VIF approximately 1.26, max approximately 1.63. Well below the conventional threshold of 5. |

### Faculty subsample (mf3b spec): parallel regression and VIF

Reported in the second half of `appendix/po_subsample_tests.do` and captured in `appendix/_outputs/logs/F23_diagnostics_subsample.log`.

| Assumption | Check |
|---|---|
| Parallel slopes / proportional odds | `oparallel` on a 3-level bucketed score with the mf3b predictors. The full spec causes perfect prediction in the faculty n = 73 subsample (sparse race cells), so race and gender are dropped from the test only. With the minimal spec (`i.device_type c.ai_familiarity`), all five tests report p > 0.33. Not rejected. |
| No multicollinearity | VIF on parallel OLS of the mf3b covariates within the faculty subsample. All VIFs comfortably below 5. |

### Student subsample (ms4 spec): parallel regression and VIF

ms4 is the preferred student-only specification: `i.affiliation i.device_type i.gender i.race c.ai_familiarity##c.ai_use_time c.social_media_time`. Same diagnostic block as faculty.

| Assumption | Check |
|---|---|
| Parallel slopes / proportional odds | `oparallel` on a 3-level bucketed score with the ms4 predictors. The full spec causes perfect prediction (sparse race cells), so race is dropped from the test. With `i.affiliation i.device_type i.gender c.ai_familiarity##c.ai_use_time c.social_media_time`, all five tests report p > 0.18 (Wald chi-squared(10) = 12.77, p = 0.237). Not rejected. |
| No multicollinearity | VIF on parallel OLS of the ms4 covariates within the student subsample. The structurally inflated VIFs on the interaction component variables are expected for interaction models and do not indicate a real multicollinearity problem. All other VIFs below 5. |

The full diagnostic output for every scope is in the technical appendix Section F (`appendix/appendix.docx`).
