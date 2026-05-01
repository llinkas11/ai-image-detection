---
title: "AI Detection Study - Appendix"
subtitle: "Reproducible analysis from data cleaning through robustness checks"
author: "Lulu Linkas, Seamus Woodruff, Maddy Ohta"
date: "Spring 2026"
---

# Foreword

This appendix accompanies the AI Detection Study senior project. It walks the reader from the raw survey data through every cleaning, modeling, and diagnostic step, embedding the actual Stata commands and outputs at each stage. Anyone with the raw dataset and Stata 18 can reproduce every number reported here by running:

```
bash appendix/build.sh
```

from the repository root. The build script syncs the most recent versions of every analysis script from the authors' working copy, runs them end-to-end, captures the logs, regenerates every figure and table, and re-compiles this document. The document, the code listings in Annex 1, and the log outputs in Annex 2 are guaranteed to come from the same build, so the appendix never drifts out of sync with the underlying analysis.

Raw individual-level responses are not included in the public repository (privacy: see `data/README.md`). The authors will share the data on request for academic replication.

\newpage

# A. Sample composition and filter pipeline

Three sequential filters are applied to move from the raw 508 respondents to the 419-respondent analytic sample:

1. **Attention-check filter**: 508 -> 434 (drops 74). Keep only respondents who passed both attention checks. These are obvious AI-generated images (Gemini diffusion outputs with visible artifacts) inserted at positions 4 and 8 in each respondent's image sequence. Failing either flags the respondent as inattentive.
2. **Device filter**: 434 -> 424 (drops 10). Drop respondents who used "Other" devices (all iPads in the realized sample). Sample is too small to identify a separate iPad effect, so the device contrast is restricted to Mobile vs Laptop.
3. **Response-time filter**: 424 -> 419 (drops 5). Drop respondents whose log-transformed average response time per image lies outside +/- 3 SD on the log scale. Raw response time is heavily right-skewed (skewness ~6 even after the attention filter), so a raw +/- 3 SD bound barely cuts anyone; the log scale is approximately symmetric and yields the intended ~0.1% tail trim.

Models that include all predictors (m4, m5, m6) report on a further reduced sample of N = 401, since 18 of the 419 are missing on at least one covariate (typically `ai_use_time` or `ai_familiarity`).

The exact cell counts at each step are captured in the Stata log:

```text
{{< include _outputs/logs/B_descriptives.log >}}
```

\newpage

# B. Descriptive statistics

This section reports per-variable descriptive statistics (numeric: mean / SD / median / range; categorical: tabulation) for every variable in the analytic dataset. Histograms accompany every numeric variable, with a normal overlay; pie charts accompany every categorical variable. All figures are regenerated from `analysis/descriptives.do` on each build.

## B.1 Dependent variable: detection score

![Score distribution (post-filter)](_outputs/figs/score_hist_filtered.png){ width=80% }

The score is approximately symmetric around the mode (mean ~6.95, SD ~1.60, median 7), consistent with a normal latent variable and supporting the choice of probit over logit for the link function.

## B.2 Numeric predictors

![Average response time, raw scale](_outputs/figs/descriptives/hist_avg_resp_time.png){ width=70% }

Raw response time is heavily right-skewed; the log transform produces an approximately normal distribution suitable for a +/- 3 SD trim:

![Log response time](_outputs/figs/descriptives/hist_ln_resp_time_postfilter.png){ width=70% }

![AI familiarity](_outputs/figs/descriptives/hist_ai_literacy.png){ width=60% }

![AI weekly use time](_outputs/figs/descriptives/pie_ai_use_time.png){ width=60% }

![Social media use time](_outputs/figs/descriptives/pie_social_media_time.png){ width=60% }

![Average per-question confidence](_outputs/figs/descriptives/hist_avg_conf.png){ width=60% }

## B.3 Categorical predictors

![Affiliation (class year + Faculty/Staff)](_outputs/figs/descriptives/pie_affiliation.png){ width=60% }

![Device type](_outputs/figs/descriptives/pie_device_type.png){ width=60% }

![Gender](_outputs/figs/descriptives/pie_gender.png){ width=60% }

![Race / ethnicity](_outputs/figs/descriptives/pie_race.png){ width=60% }

![Disability self-disclosure](_outputs/figs/descriptives/pie_disability.png){ width=50% }

![International student flag](_outputs/figs/descriptives/pie_intl_student.png){ width=50% }

## B.4 Per-question response patterns

![True positive rate (AI images correctly identified)](_outputs/figs/descriptives/hist_tp_rate.png){ width=60% }

![True negative rate (real images correctly identified)](_outputs/figs/descriptives/hist_tn_rate.png){ width=60% }

![Attention-check confidence (check 1)](_outputs/figs/descriptives/hist_attn_conf1.png){ width=60% }

\newpage

# C. Exploratory analysis

Bivariate views of detection score against each predictor of interest, plus pairwise comparisons across the four student class years.

## C.1 Score by affiliation and device

![Score by affiliation](_outputs/figs/exploratory/box_score_by_affiliation.png){ width=80% }

![Score by device type](_outputs/figs/exploratory/box_score_by_device.png){ width=70% }

## C.2 Score by demographic controls

![Score by gender](_outputs/figs/exploratory/box_score_by_gender.png){ width=70% }

![Score by race](_outputs/figs/exploratory/box_score_by_race.png){ width=80% }

## C.3 Score against numeric predictors

![Score vs ln(response time)](_outputs/figs/exploratory/scatter_score_vs_ln_resptime.png){ width=70% }

![Score vs AI familiarity](_outputs/figs/exploratory/scatter_score_vs_ai_fam.png){ width=70% }

![Score vs AI use time](_outputs/figs/exploratory/scatter_score_vs_ai_use.png){ width=70% }

## C.4 Pairwise tests

The Stata log below contains: a Bonferroni-corrected one-way ANOVA of mean score across the four student class years, a t-test of score by device type (Mobile vs Laptop), a t-test of score by Faculty/Staff vs Student, and a Pearson correlation matrix of score with the numeric predictors.

```text
{{< include _outputs/logs/C_exploratory.log >}}
```

\newpage

# D. Model justification and main results

## D.1 Why ordered probit

Detection score has 11 ordered integer levels (0 through 10). This rules out a linear model (which would assume equal spacing) and a multinomial model (which would discard the ordering). Within ordinal models, the choice between logit and probit comes down to the assumed error distribution. The observed score distribution is approximately symmetric around the mode (Section B.1), consistent with a normal latent y* and therefore a probit link. The two link functions yield substantively identical results in this dataset; the probit choice is reported as the primary model and a logit sensitivity is included in Section H.

## D.2 Specification progression

Eight specifications are estimated, starting from a demographic-only baseline and progressively adding the AI-exposure block, the interaction term, and response time:

| Spec | Predictors added |
|---|---|
| m1 | Affiliation only |
| m2 | + Device |
| m3a | + AI familiarity |
| m3b | + AI usage |
| m3c | + Familiarity x usage interaction |
| m4 | + Social media time |
| m5 | Replace `i.affiliation` with binary `i.over_25`, full controls |
| m6 | m5 + ln(response time) |

The complete coefficient table for each spec, including standard errors, significance markers, and AIC / BIC, is in Annex 2 (file `D_oprobit_main.log`). A condensed CSV is at `_outputs/tables/oprobit_models.csv`.

## D.3 AIC / BIC across specifications

The AIC / BIC table from a fresh build is included in the log; the preferred specification is m5 (lowest AIC among models that include the AI-exposure interaction, which is the substantive variable of interest). Selection on AIC alone would prefer m2 by a margin of ~1 AIC point; the substantive case for carrying m5 forward is that it tests the AI-exposure hypothesis rather than just demographics.

## D.4 Coefficient table

The full m1-m6 coefficient matrix is generated by `esttab` to RTF and CSV, regenerated each build:

```text
{{< include _outputs/logs/D_oprobit_main.log >}}
```

\newpage

# E. Subsample analysis

The pooled m5 collapses age into a binary `over_25` flag (1 = Faculty/Staff, 0 = Student). To check whether the device effect, AI-exposure effect, or any other coefficient differs between faculty and student populations, the same model progression is re-run separately on each subsample. `i.over_25` is dropped from each subsample (constant within group). The student subsample additionally retains `i.affiliation` so class-year effects are visible.

```text
{{< include _outputs/logs/E_subsample.log >}}
```

The headline result: device and AI-exposure coefficients are similar in sign across subsamples. None of the four student class-year coefficients differs significantly from the Senior reference category (all p > 0.18 in m4-equivalent specs).

## E.3 Cut-point analysis (faculty)

Ordered probit estimates k-1 cut points for a k-level outcome. The latent-scale gap between adjacent cut points is the distance respondents must cover to move from one observed score level to the next. If those gaps are equal, the score levels reflect equally-spaced latent ability. If one gap is much larger, that score transition is unusually hard.

In the faculty mf3b specification, the gap between observed scores 7 and 8 (the difference between `/cut7` and `/cut8` in Stata's parameterization) is significantly larger than the other adjacent gaps. Equivalently: for faculty respondents, moving from a 7 to an 8 is the hardest jump on the latent scale. The 9-to-10 jump is also notably large.

The full output (all 9 gap sizes with 95% confidence intervals via `nlcom`, plus pairwise Wald tests of the largest gap against each other gap) is in the captured log:

```text
{{< include _outputs/logs/E3_cut_points.log >}}
```

\newpage

# F. Diagnostics

## F.1 Pooled m2 spec (parallel regression + VIF)

The proportional-odds (parallel-regression) assumption is tested with `oparallel` on a 3-level bucketed score (0-5 / 6-7 / 8-10). The full 11-level score is too sparse at the tails for the underlying binary-logit series to converge, so bucketing is necessary. Bucketing into three levels rather than the full 11 is a standard PO-test fallback when the high-cardinality series is sparse.

Variance inflation factors are computed on a parallel OLS (Stata's `estat vif` is not available after MLE).

```text
{{< include _outputs/logs/F1_diagnostics_pooled.log >}}
```

The five tests reported by `oparallel` (Wolfe-Gould, Brant, Score, LR, Wald) all give p > 0.05 at the m2 spec; the proportional-odds assumption is not rejected. Mean VIF is well below 5; no collinearity concern. Note that VIFs on the `c.ai_familiarity##c.ai_use_time` interaction term and its components are structurally inflated by construction (the interaction is mechanically correlated with both main effects); this is expected for interaction models and does not indicate a real collinearity problem.

## F.2 Faculty/Staff subsample (mf3b spec)

The full mf3b spec causes perfect prediction in `oparallel` because the "Black or African American" race cell drops to zero observations in at least one bucketed-score level within the n=73 faculty subsample. We fall back: drop race; if that still fails, drop gender. The minimal robust spec uses device + AI familiarity as predictors and tests proportional odds on those.

```text
{{< include _outputs/logs/F23_diagnostics_subsample.log >}}
```

The five `oparallel` tests on the minimal robust spec give p > 0.30; the proportional-odds assumption is not rejected for the faculty subsample.

## F.3 Student subsample (ms4 spec)

Similar fallback: the full ms4 spec causes perfect prediction; dropping race resolves it. With n=343 students and the interaction-plus-affiliation-plus-social-media spec, `oparallel` runs and reports Wald chi-squared(10) = 12.77, p = 0.237 (lowest among the five tests is LR p = 0.190). The proportional-odds assumption is not rejected for the student subsample. (Output is in the same log block above; both subsamples are run consecutively by `po_subsample_tests.do`.)

## F.4 Subsample VIFs

Mean VIF in the faculty subsample is approximately 1.4-1.8 (reported in the log above), and the student subsample is similar to the pooled VIF (mean ~1.3, max under 2). No collinearity concern in either subsample.

\newpage

# G. Margins and interpretation

Ordered probit coefficients are on the latent y* scale, which is not directly interpretable. To translate to score-scale interpretation we compute average marginal effects via `margins, dydx(*)` for each outcome level (0 through 10). Marginal effects at the modal outcome (score = 7) are near zero by construction (the density peak has flat slope); the substantive story comes from the tails (score = 9 or 10 at the top, score = 4 or below at the bottom).

```text
{{< include _outputs/logs/D_oprobit_main.log >}}
```

The margins block is at the bottom of the main oprobit log. Key takeaway: the device effect translates into a 5-7 percentage-point shift in the probability of a top score (8-10) between Mobile and Laptop respondents, all else equal.

\newpage

# H. Robustness checks

## H.1 Count-model sensitivity

The score is a count out of 10. Although ordered probit is the primary model (it respects ordinality without imposing equal spacing), Poisson and Negative Binomial sensitivities are reported for completeness. The class decision rule is: variance ~ mean -> Poisson; variance >> mean -> NB. The observed variance (~2.55) is well below the mean (~6.95), indicating under-dispersion; Poisson is the natural count benchmark.

```text
{{< include _outputs/logs/H_count_models.log >}}
```

Signs and significance of the device and over_25 coefficients agree across oprobit, Poisson, and NB. Score behaves like a bounded ordinal variable; oprobit is the right tool.

## H.2 Ordered logit sensitivity

The probit choice is checked against ordered logit on the m5 spec inside the main oprobit log (Section D). AIC and coefficient signs agree; the link function does not affect the substantive story.

\newpage

# Annex 1: full code listings

The four main analysis scripts, verbatim and synced from the authors' working copy at build time. These are the actual files that produced the outputs embedded in Sections A through H above.

## Annex 1.1: `analysis/descriptives.do`

```stata
{{< include ../analysis/descriptives.do >}}
```

\newpage

## Annex 1.2: `analysis/oprobit_regression.do`

```stata
{{< include ../analysis/oprobit_regression.do >}}
```

\newpage

## Annex 1.3: `analysis/oprobit_regression_by_affiliation.do`

```stata
{{< include ../analysis/oprobit_regression_by_affiliation.do >}}
```

\newpage

## Annex 1.4: `analysis/m2_diagnostics.do`

```stata
{{< include ../analysis/m2_diagnostics.do >}}
```

\newpage

## Annex 1.5: `appendix/exploratory.do`

```stata
{{< include exploratory.do >}}
```

\newpage

## Annex 1.6: `appendix/po_subsample_tests.do`

```stata
{{< include po_subsample_tests.do >}}
```

\newpage

# Annex 2: full Stata logs

The captured log from each section's run, in execution order. Section letters match the Sections A through H above.

## Annex 2.1: descriptives + filter pipeline log

```text
{{< include _outputs/logs/B_descriptives.log >}}
```

\newpage

## Annex 2.2: exploratory analysis log

```text
{{< include _outputs/logs/C_exploratory.log >}}
```

\newpage

## Annex 2.3: main oprobit log

```text
{{< include _outputs/logs/D_oprobit_main.log >}}
```

\newpage

## Annex 2.4: subsample analysis log

```text
{{< include _outputs/logs/E_subsample.log >}}
```

\newpage

## Annex 2.5: pooled m2 diagnostics log

```text
{{< include _outputs/logs/F1_diagnostics_pooled.log >}}
```

\newpage

## Annex 2.6: subsample diagnostics log (faculty + student PO tests + VIF)

```text
{{< include _outputs/logs/F23_diagnostics_subsample.log >}}
```

\newpage

## Annex 2.7: count-model robustness log

```text
{{< include _outputs/logs/H_count_models.log >}}
```

\newpage

## Annex 2.8: cut-point analysis log (faculty)

```text
{{< include _outputs/logs/E3_cut_points.log >}}
```

\newpage

# References

The full list of works cited for this study lives on the project website: **https://seamuswoodruff.github.io/ai-detection/**. Citations cover the AI-image-generation models that produced the stimuli, the survey-design literature underpinning the instrument, the ordered-probit methodology references, and the Stata package documentation for `oparallel`, `estout`, and related tools used in this appendix.
