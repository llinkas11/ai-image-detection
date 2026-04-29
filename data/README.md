# Data

## Not included in this repository

Individual-level survey responses are not published here. Even without names, the combination of age, gender, race, class year, international status, and disability flags can uniquely identify individuals at a small institution like Bowdoin. To protect respondent privacy, we publish only:

- Aggregated summary statistics (`../results/descriptives_summary.csv`)
- Regression coefficient tables (`../results/oprobit_models.csv`)
- Aggregate figures (`../results/figures/`)

## Schema

If reproducing the analysis with access to the raw data, the expected Stata dataset (`AI_DetectionV3_lite.dta`) has the following columns:

### Response variables

| Column | Type | Description |
|---|---|---|
| `score` | int (0-10) | count of correctly classified images out of 10 |
| `Question1` ... `Question10` | string | TP / TN / FP / FN per image block |
| `Question1Conf` ... `Question10Conf` | int (0-10) | confidence slider value per block |
| `AttnCheck1`, `AttnCheck2` | binary | 1 = passed the attention check |
| `attn_both` | binary | 1 = passed BOTH attention checks |

### Primary predictors

| Column | Type | Description |
|---|---|---|
| `device_type` | categorical | Mobile phone / Laptop / Other |
| `affiliation` | categorical | Class of 2026 / 2027 / 2028 / 2029 / Faculty/Staff |
| `over_25` | binary | derived: 1 = Faculty/Staff, 0 = student |

### Covariates / controls

| Column | Type | Description |
|---|---|---|
| `ai_familiarity` | ordinal (1-5) | self-reported familiarity with AI |
| `ai_use_time` | ordinal bins | self-reported weekly AI usage |
| `social_media_time` | ordinal bins | self-reported weekly social media usage |
| `gender` | categorical | Man / Woman / Non-binary / Prefer not to say (collapsed to 3 in analysis) |
| `race` | categorical | 7 levels (collapsed to 6 with sparse cells merged) |
| `disability` | binary | self-disclosed disability or ADHD |
| `intl_student`, `intl_faculty` | binary | international flags |
| `avg_resp_time` | numeric | average response time per image, seconds |
| `ln_resp_time` | numeric | log of avg_resp_time, derived |

## Requesting access

Researchers may contact the authors to request access to the raw data for academic replication or extension work: llinkas@gmail.com or v.gomezgilyaspik@bowdoin.edu.
