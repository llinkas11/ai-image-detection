# AI Detection Study

A Bowdoin College senior project investigating whether people can reliably distinguish AI-generated images from real photographs, and which respondent characteristics predict detection ability.

**Authors:** Maddy Ohta, Lulu Linkas, Seamus Woodruff
**Course:** DCS 3850 Advanced Data Science, Spring 2026
**Live site:** *(link to come)*

## Headline findings

From an ordered probit model on N = 392 respondents:

- **Faculty/Staff scored lower than students** (β = -0.34, p = 0.04)
- **Mobile users scored lower than laptop users** (β = -0.25, p = 0.03)
- **Self-reported AI familiarity and weekly AI usage did not predict detection score**

The significant effects are robust across 8 specifications and after controlling for gender, race, social media time, and response time.

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

## License

MIT. See `LICENSE`.

## Contact

For data access requests or methodological questions: llinkas@bowdoin.edu
