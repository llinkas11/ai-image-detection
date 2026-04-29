# AI Detection Study

A Bowdoin College senior project investigating whether people can reliably distinguish AI-generated images from real photographs, and which respondent characteristics predict detection ability.

**Authors:** Lulu Linkas, Seamus Woodruff, Maddy Ohta
**Course:** DCS 3850 Advanced Data Science, Spring 2026
**Live site:** *https://seamuswoodruff.github.io/ai-detection/*

## Headline findings

Analytic sample after filtering: **N = 419** (508 starting; 74 dropped on attention checks, 10 on "Other" devices, 5 on log response-time trim). Models that include all AI-exposure predictors (m4, m5) drop 18 more on covariate missingness and report on N = 401.

From the preferred ordered probit specification (m5):

- **Faculty/Staff scored lower than students** (statistically significant)
- **Mobile users scored lower than laptop users** (negative coefficient, marginal significance)
- **Self-reported AI familiarity and weekly AI usage did not predict detection score**

Direction and magnitude are robust across the eight specifications and after controlling for gender, race, social media time, and log response time. Full coefficient tables are in `results/oprobit_models.csv` and the technical appendix.

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

## Presentation

See `presentation/ai-detection.pptx` for the final slide deck. This covers study motivation, design, analytical methods, and results.

## Reproducible appendix

The `appendix/` folder contains a single-command build (`bash appendix/build.sh`) that regenerates a technical appendix walking through every analytical step: filter pipeline, descriptives, exploratory analysis, model specification and progression, subsample analysis, diagnostics (parallel-regression test, VIF, on the pooled and both subsamples), margins, and count-model robustness. Output is `appendix/appendix.docx` (and `appendix.pdf` if `pdflatex` is installed). See `appendix/README.md` for build requirements.

## License

MIT. See `LICENSE`.

## Contact

For data access requests or methodological questions: llinkas@bowdoin.edu
