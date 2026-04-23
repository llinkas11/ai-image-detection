# Analysis

Stata do-files for the ordered probit analysis, diagnostics, and subsample comparisons.

## Files

| File | Purpose |
|---|---|
| `descriptives.do` | Summary statistics, histograms, cross-tabs of key variables. |
| `oprobit_regression.do` | Main analysis: ordered probit on detection score with a progressive sequence of specifications (m1 through m5), data cleaning, and diagnostics. |
| `oprobit_regression_by_affiliation.do` | Re-runs the model sequence separately on faculty-only and student-only subsamples (run after `oprobit_regression.do` in the same Stata session). |
| `m2_diagnostics.do` | Parallel regression test (via `oparallel`) and variance inflation factors. |

## Requirements

Stata 18 (older versions may work, not tested). Install the external packages used:

```stata
ssc install oparallel
ssc install estout
```

## Inputs

These scripts expect a raw dataset at `data/AI_DetectionV3_lite.dta` relative to the working directory. The dataset is not included in this repository to protect respondent privacy. See `../data/README.md` for the expected schema.

## Working directory

Each do-file starts with a commented-out `cd` that you will need to un-comment and point at your local clone of this repository.

## Outputs

All scripts write to a `figs/` subdirectory (histograms as PNGs, regression tables as RTF and CSV, diagnostic logs as text). `figs/` is git-ignored.

## Data cleaning sequence

Every analysis script applies the same filter chain:

1. Keep only respondents who passed both attention checks.
2. Drop respondents who used "Other" devices (n = 9, all iPads in the realized sample).
3. Trim log-transformed average response time to +/- 3 SD.
4. Collapse sparse race cells (International, Unknown) into Other.
5. Collapse sparse gender cells (Non-binary, Prefer not to say) into Other.

After filtering, the analytic sample is N = 392 respondents.

## Model sequence in oprobit_regression.do

| Model | Added predictors |
|---|---|
| m1 | baseline (affiliation) |
| m2 | + device |
| m3a | + AI familiarity |
| m3b | + AI usage |
| m3c | + familiarity x usage interaction |
| m4 | + social media |
| m5 | replace affiliation with binary over_25, full controls |
| m6 | m5 + ln(response time) |

m5 is the preferred specification.
