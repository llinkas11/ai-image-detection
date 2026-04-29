# Data cleaning

End-to-end pipeline that turns the raw Qualtrics export (2 CSVs, 639 columns each, merged to 508 responses) into the analytic dataset (`AI_DetectionV3_lite.dta`, 61 variables, 508 observations) used by every script in `analysis/`.

This is a single document. Every step is described in prose, then implemented in a runnable script. To reproduce the cleaning end-to-end, run the seven scripts in numeric order from this directory:

```
python3 01_export.py
python3 02_classify_outcomes.py
python3 03_reorder_rename.py
python3 04_lite_trim.py
stata -e -q do 05_stata_import.do
stata -e -q do 06_recode.do
stata -e -q do 07_derive.do
```

Inputs (not in the public repo, see `../data/README.md`):

- A Qualtrics API token in the environment variable `QUALTRICS_API_TOKEN`.
- The published Qualtrics survey ID (`SV_bQ8cVhMLAvco9bE`).

Outputs (also not in the public repo, to protect respondent privacy):

- Intermediate: `AI_DetectionV2.csv` (after Python processing), `AI_DetectionV3.csv` (after reorder + rename), `AI_DetectionV3_lite.csv` (49-variable trim).
- Final analytic: `AI_DetectionV3_lite.dta` (61 variables, 508 observations).

Authors: Lulu Linkas, Seamus Woodruff, Maddy Ohta. Senior project, DCS 3850 Advanced Data Science, Spring 2026.

---

## Pipeline overview

```
[Qualtrics live survey, 88-92 questions per respondent]
            |
   01 QUALTRICS EXPORTS    pull 2 batch CSVs (recorded + in-progress);
            |              merge to 508 rows; cut 3-row Qualtrics header
            |              block; per-image fields = response + confidence
            |              + timing for 10 images per participant
            |              639 columns per raw export
            |
   02 PYTHON PROCESSING    Python classifier writes per participant x image:
            |              Q1..Q10 = TP / TN / FP / FN strings,
            |              Q1..Q10Conf = confidence sliders,
            |              CalculatedScore = count(TP+TN) (verified vs
            |              Qualtrics native score),
            |              AvgAnswTime = mean of 10 per-image timings,
            |              AttnCheck1/2 = 1 if passed else 0,
            |              DeviceType = 0/1/2 numeric encoding.
            |              File: AI_DetectionV2.csv
            |
   03 PROCESSED CSV V3     Reorder + rename columns for readability.
            |              Chunk (raw image-block) columns moved to follow
            |              the outcome columns. Missing values recoded
            |              as '.'. 482 columns total.
            |              File: AI_DetectionV3.csv
            |
   04 LITE CSV             Drop the raw chunk columns and block-level
            |              timing. Keep 49 key variables: Q1..Q10 outcomes
            |              and confidences, CalculatedScore, AvgAnswTime,
            |              demographics, attention checks, and a small set
            |              of response metadata.
            |              File: AI_DetectionV3_lite.csv
            |
   05 STATA IMPORT + RENAME   import delimited, clear, varnames(1)
            |              encoding(utf-8). Stata auto-shortens column
            |              headers; we then rename all 49 vars to
            |              snake_case via rename + a forvalues loop. A
            |              few names are shortened further by hand
            |              (ai_detection_was_easy -> detect_easy). En-dash
            |              characters in labels are converted to ASCII
            |              hyphens with usubinstr(var, uchar(8211)).
            |              File: AI_DetectionV3_lite.dta
            |
   06 IN-PLACE RECODE      16 string variables converted to numeric with
            |              value labels via the pattern
            |              rename -> gen byte -> replace -> drop.
            |              Binary 0/1: disability, intl_student,
            |              intl_faculty, ai_course.
            |              Ordinal: detect_easy, ai_literacy,
            |              ai_familiarity, ai_use_time, social_media_time.
            |              Nominal: gender, race, affiliation.
            |              "Prefer not to say" maps to missing (.). Q1..Q10
            |              outcomes recoded TP/TN/FP/FN -> 1/2/3/4. Value
            |              and variable labels applied throughout.
            |              File: AI_DetectionV3_lite.dta (overwritten)
            |
   07 FINAL DATASET        Derive 12 analysis-ready variables on top of
            |              the 49 cleaned ones: tp_count, tn_count,
            |              fp_count, fn_count; tp_rate, tn_rate, fp_rate,
            |              fn_rate; avg_conf; attn_both. Total: 61 base
            |              variables, 508 observations, all labelled.
            |
   [AI_DetectionV3_lite.dta]    61 variables, 508 observations
```

---

## Step 01: Qualtrics export and merge

**Inputs.** Two batch CSVs from Qualtrics, both with the standard 3-row Qualtrics header (variable names, internal IDs, ImportId JSON):

- `AI_Detection_Apr12.csv`: 472 fully recorded responses, 639 columns.
- `AI_Detection_Apr12_InProgress.csv`: 36 responses that are 99 percent or more complete, 639 columns.

The 99-percent threshold keeps respondents who reached the score-reveal page (everything important answered) while dropping ones who abandoned mid-survey before any score data was captured. The `score` embedded-data field is populated for the 36 in-progress respondents we keep; the rest are dropped.

**Output.** `survey_responses.csv`: **508 rows = 472 + 36**, 639 columns. The 3-row Qualtrics header is removed (157 rows of metadata cut, including the per-question import-id JSON row that is not part of the data).

**Per-image fields.** Each respondent has, for each of 10 images plus 2 attention checks, three fields: response (Real or AI text), confidence (0 to 10 slider), and timing (seconds spent on that block). The timing fields are dropped at step 04; the response and confidence fields feed the Python classifier in step 02.

Code: [`01_export.py`](01_export.py).

---

## Step 02: Python outcome classifier

**Goal.** Compute the binary-classification outcome for each respondent x image and add several derived columns the analysis needs.

**Outcomes.** For each of the 10 image blocks per respondent:

- TP (true positive): image is AI-generated and respondent answered AI.
- TN (true negative): image is real and respondent answered Real.
- FP (false positive): image is real and respondent answered AI.
- FN (false negative): image is AI-generated and respondent answered Real.

**Logic.** Each image block in the Qualtrics survey has a description like `Img_F_A007` (fake, pool A, position 7) or `Img_R_B015` (real, pool B, position 15). The letter after `Img_` encodes the ground truth. The classifier reads the survey definition through the API to map each multiple-choice question's export tag to its containing block ID, then for each respondent walks the 10 image blocks they were shown and computes the outcome.

**Columns added.**

| Column | Type | Source |
|---|---|---|
| `Q1` ... `Q10` | string (TP, TN, FP, FN) | classifier output per image |
| `Q1Conf` ... `Q10Conf` | int 0-10 | confidence slider per image |
| `CalculatedScore` | int 0-10 | `count(Qi == "TP" or Qi == "TN")` across the 10 questions, verified to match Qualtrics's own `Score` embedded data |
| `AvgAnswTime` | float seconds | mean of the 10 per-image timing fields |
| `AttnCheck1`, `AttnCheck2` | int 0/1 | 1 if attention check answered correctly |
| `DeviceType` | int 0/1/2 | numeric encoding for downstream Stata |

**Output.** `AI_DetectionV2.csv`, 508 rows x roughly 660 columns (639 + the 20+ new ones).

Code: [`02_classify_outcomes.py`](02_classify_outcomes.py).

---

## Step 03: Reorder, rename, and recode missing

**Goal.** Make the CSV human-readable for spot-checking. Reorder columns so each respondent's outcome columns immediately follow the corresponding question columns. Rename Qualtrics's auto-generated names to descriptive names. Recode all blank cells as `.` (the literal Stata-missing string), so the next step's `import delimited` reads them as missing instead of empty strings.

**Output.** `AI_DetectionV3.csv`, 508 rows x **482 columns** (the unused Qualtrics-internal columns are also dropped at this stage).

Code: [`03_reorder_rename.py`](03_reorder_rename.py).

---

## Step 04: Lite trim to analysis-ready columns

**Goal.** Drop everything not used by the analysis. Specifically, the raw chunk (image-block) columns and the block-level timing columns are not needed once `Q1..Q10` and `AvgAnswTime` summarize them. Keep:

- `Q1..Q10` (outcomes) and `Q1Conf..Q10Conf` (confidences): 20 columns.
- `CalculatedScore`, `AvgAnswTime`: 2 columns.
- Demographics: `Affiliation`, `InternationalStudent`, `InternationalFaculty`, `Age`, `Gender`, `Race`, `Disability`, `ADHD`: 8 columns.
- Behavioral predictors: `AILiteracy`, `AIUseTime`, `SocialMediaUseTime`, `AIFamiliarity`, `AICourseYN`, `AIClassesTaken`, `DetectEasy`: 7 columns.
- Attention checks: `AttnCheck1`, `AttnConf1`, `AttnCheck2`, `AttnConf2`: 4 columns.
- Device + identity: `DeviceType`, `DeviceOther`, `ImgCount`, `Score`: 4 columns.
- Response metadata: `StartDate`, `EndDate`, `Duration`, `RecordedDate`: 4 columns.

**Output.** `AI_DetectionV3_lite.csv`, **508 rows x 49 columns**. This file is the input to Stata.

Code: [`04_lite_trim.py`](04_lite_trim.py).

---

## Step 05: Stata import and rename

**Goal.** Move from CSV to a labelled Stata dataset and rename every column to snake_case.

**Import.**

```stata
import delimited "AI_DetectionV3_lite.csv", varnames(1) encoding(utf-8) clear
```

Stata's `import delimited` auto-shortens long column names (Stata variable names are limited to 32 characters). After import, each variable is renamed by hand to a final snake_case form (see `codebook.csv`):

| Imported name | Final name |
|---|---|
| `AIdetectionwaseasy` | `detect_easy` |
| `AIliteracy` | `ai_literacy` |
| `AIusetime` | `ai_use_time` |
| `SocialMediausetime` | `social_media_time` |
| `AIFamiliarity` | `ai_familiarity` |
| `AICourseYN` | `ai_course` |
| `AIClassesTaken` | `ai_classes` |
| `Affiliation` | `affiliation` |
| `InternationalStudent` | `intl_student` |
| `InternationalFaculty` | `intl_faculty` |
| `Disability` | `disability` |
| `DeviceType` | `device_type` |
| `Q1` ... `Q10` | `q1` ... `q10` |
| `Q1Conf` ... `Q10Conf` | `q1_conf` ... `q10_conf` |
| `AttnCheck1`, `AttnCheck2` | `attn_check1`, `attn_check2` |
| `AttnConf1`, `AttnConf2` | `attn_conf1`, `attn_conf2` |
| `Score` | `score_total` |
| `Duration(inseconds)` | `duration_sec` |
| `CalculatedScore` | `calc_score` |
| `AvgAnswTime` | `avg_resp_time` |

The 10 question columns and 10 confidence columns are renamed in a `forvalues` loop:

```stata
forvalues i = 1/10 {
    rename Q`i'      q`i'
    rename Q`i'Conf  q`i'_conf
}
```

**En-dash cleanup.** Some imported labels contain Unicode en-dashes (e.g. `2-4 hours` was originally `2 – 4 hours`). These are converted to ASCII hyphens with:

```stata
foreach v of varlist _all {
    capture replace `v' = usubinstr(`v', uchar(8211), "-", .)
}
```

(`uchar(8211)` is the Unicode codepoint for en-dash; `usubinstr` is Stata's Unicode-aware string replace.)

**Output.** `AI_DetectionV3_lite.dta`, 49 variables.

Code: [`05_stata_import.do`](05_stata_import.do).

---

## Step 06: In-place recode of string variables to numeric with labels

**Goal.** Stata works best with numeric variables paired with value labels. 16 variables come in as strings and need to become numeric.

**The recode pattern** is the same for each string variable: rename the original out of the way, generate a new byte variable from the renamed one with `replace` statements, drop the renamed string. This is `rename -> gen byte -> replace -> drop`:

```stata
* example: gender (4 levels)
rename gender _gender
gen byte gender = .
replace gender = 1 if _gender == "Man"
replace gender = 2 if _gender == "Woman"
replace gender = 3 if _gender == "Non-binary / Third gender"
replace gender = 4 if _gender == "Prefer not to say"
* "Prefer not to say" goes to . in the analysis pipeline
drop _gender
label define gender_lbl 1 "Man" 2 "Woman" 3 "Non-binary" 4 "Prefer not to say"
label values gender gender_lbl
label variable gender "Gender identity (1=Man, 2=Woman, 3=Non-binary, 4=PNS)"
```

**Variables recoded.**

| Variable | Type | Encoding |
|---|---|---|
| `disability` | binary 0/1 | No=0, Yes=1 |
| `intl_student` | binary 0/1 | No=0, Yes=1 |
| `intl_faculty` | binary 0/1 | No=0, Yes=1 |
| `ai_course` | binary 0/1 | No=0, Yes=1 |
| `attn_check1` | binary 0/1 | already numeric from Python step |
| `attn_check2` | binary 0/1 | already numeric from Python step |
| `detect_easy` | ordinal 1-5 | 5-point Likert |
| `ai_literacy` | ordinal 1-5 | self-rated |
| `ai_familiarity` | ordinal 1-5 | "Not at all" .. "Extremely" |
| `ai_use_time` | ordinal bins | hours-per-week buckets |
| `social_media_time` | ordinal bins | hours-per-week buckets |
| `gender` | nominal 1-4 | Man / Woman / Non-binary / PNS |
| `race` | nominal 1-7 | White / Asian / Black / Hispanic / Two+ / International / Unknown |
| `affiliation` | nominal 1-5 | Class of 2026..2029 / Faculty-Staff |
| `device_type` | nominal 1-3 | Laptop / Mobile / Other |
| `q1` ... `q10` | nominal 1-4 | TP=1, TN=2, FP=3, FN=4 |

**Missing.** `Prefer not to say`, the literal string `Other` in free-text fall-throughs, and any blank cell becomes Stata missing (`.`). The downstream regression scripts further collapse race codes 6 and 7 (International, Unknown) into 8 (Other) because of sparse cells.

**Output.** `AI_DetectionV3_lite.dta` (overwritten), still 49 variables but now all numeric where appropriate, with full value-label coverage.

Code: [`06_recode.do`](06_recode.do).

---

## Step 07: Derive analysis-ready variables

**Goal.** Compute 12 derived variables on top of the 49 cleaned ones. These are the variables the regression scripts in `analysis/` actually use.

**Derived variables.**

| Variable | Formula |
|---|---|
| `tp_count` | sum of `q1..q10 == 1` (TP) per respondent |
| `tn_count` | sum of `q1..q10 == 2` (TN) per respondent |
| `fp_count` | sum of `q1..q10 == 3` (FP) per respondent |
| `fn_count` | sum of `q1..q10 == 4` (FN) per respondent |
| `tp_rate` | `tp_count / (tp_count + fn_count)` (rate among AI images seen) |
| `tn_rate` | `tn_count / (tn_count + fp_count)` (rate among real images seen) |
| `fp_rate` | `fp_count / (tn_count + fp_count)` |
| `fn_rate` | `fn_count / (tp_count + fn_count)` |
| `avg_conf` | mean of `q1_conf` .. `q10_conf` per respondent |
| `attn_both` | 1 if `attn_check1 == 1 and attn_check2 == 1`, else 0 |
| `score` | also called `score_total`, equal to `tp_count + tn_count` (verified to match Qualtrics's native `Score`) |

The remaining derived variable is the binary `over_25`, which is created later inside the regression scripts (1 if Faculty/Staff, 0 if student).

All variables are labelled.

**Final.** `AI_DetectionV3_lite.dta`: **61 variables, 508 observations**, all labelled, ready for `analysis/`.

Code: [`07_derive.do`](07_derive.do).

---

## Reproducibility notes

- Steps 01 through 04 are deterministic given the same Qualtrics responses at export time. No `random.seed`.
- Step 02 depends on the live Qualtrics survey definition (block names) at export time. The block-to-truth mapping is cached in `survey/data/graphic_ids.json` and can be regenerated from the live survey.
- Steps 05 through 07 are fully deterministic: same .csv input always produces the same .dta output.
- The pipeline assumes Stata 18 or newer (`usubinstr` and `uchar` are Unicode-aware string functions added in Stata 14).
- The output `.dta` is git-ignored. Researchers requesting access can email llinkas@gmail.com or v.gomezgilyaspik@bowdoin.edu.
