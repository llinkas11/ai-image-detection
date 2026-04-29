# Methodology

## Research question

Can people reliably distinguish AI-generated images from real photographs, and which respondent characteristics (device, age, AI familiarity, AI usage, demographics) predict detection ability?

## Study design

### Stimulus pool

80 images total:

- 40 AI-generated images drawn from publicly available datasets
- 40 real photographs drawn from matched categories (landscapes, portraits, scenes)

### Stratified stimulus sampling

The 80-image pool is split into 3 roughly balanced strata of 27 / 27 / 26 images, each approximately 50 percent AI and 50 percent real. Every respondent sees a random draw of 3 + 3 + 4 images across the three strata, for a total of 10 images per respondent. This guarantees a roughly balanced stimulus regardless of which 10 images the respondent happens to draw.

### Attention checks

Two attention-check images are inserted at positions 4 and 8 in the respondent sequence. These are obvious AI-generated images (Gemini diffusion output with visible artifacts) that any attentive respondent should classify correctly. Failing either check flags the respondent for exclusion.

### Per-image questions

For each of the 10 study images plus 2 attention checks, respondents answer:

1. **Real vs AI-generated** (forced-choice, 2 options)
2. **Confidence** (optional slider, 0 to 10)

Per-block response time is also recorded.

### After the image block

All respondents also answer:

- AI familiarity (5-point Likert)
- Weekly AI usage time (ordinal bins)
- Social media usage time (ordinal bins)
- Demographics: class year or faculty/staff, age, gender, race, international student or faculty status, disability, device type (mobile phone or laptop)

## Sampling

Non-probability convenience sample, recruited through:

- Class-year-specific email distribution (freshmen and juniors via mobile, sophomores and seniors via laptop)
- Faculty and staff via Student Digest post
- Word of mouth
- QR code on flyers

Target n = 300. Actual responses collected: 437 (352 fully recorded, 85 in-progress with near-complete data).

## Data filtering

Three-stage filter applied:

1. **Attention check**: drop respondents who failed either of the two attention checks.
2. **Device filter**: drop respondents on "Other" devices (n = 9, all iPads). The sample is too small to identify an iPad effect, and keeping only Mobile vs Laptop clarifies the core device contrast.
3. **Response-time filter**: drop respondents outside +/- 3 SD on log-transformed average response time per image. Log scale is used because raw response times are heavily right-skewed (skew approximately 6), so a raw-scale filter barely cuts anyone while a log-scale filter produces the intended ~0.1 percent tail trim.

Sample size at each step:

- Starting: N = 508
- After attention check: N = 434
- After "Other" device drop: N = 424
- After log response-time trim (+/- 3 SD): **N = 419**

Models that include all predictors (m4, m5, m6) drop additional respondents who are missing on at least one covariate and run on N = 401.

## Dependent variable

**Detection score**: integer count of correct classifications out of 10 images, range 0 to 10. Distribution is approximately symmetric around the mode (mean = 6.95, SD = 1.60, median = 7), consistent with a normal latent variable.

## Model

Ordered probit with robust standard errors. The score has 11 ordered integer levels, so an ordinal model is appropriate. The choice of probit over logit reflects the observed score distribution being approximately normal, consistent with a normal latent error.

Predictor blocks:

- **Primary hypotheses**: device type (Mobile vs Laptop), age or affiliation (Student vs Faculty/Staff, proxied by over_25)
- **AI-exposure controls** (potential confounders): AI familiarity, AI weekly usage, familiarity x usage interaction, social media time
- **Demographic controls**: gender, race, disability
- **Sensitivity**: log-transformed response time

Eight specifications were estimated, from a minimal baseline through a full model with all controls plus response time. The preferred specification (m5) includes the primary predictors and all hypothesized confounders.

## Assumption checks

- **Parallel regression (proportional odds)**: tested via `oparallel` on a bucketed score (3 levels). Passes in both the faculty subsample (all p > 0.33) and the student subsample (all p > 0.97) after excluding race from the test (sparse cells caused perfect prediction).
- **Multicollinearity**: variance inflation factors computed on a parallel OLS. Mean VIF = 1.26, max = 1.63, all well below the conventional threshold of 5.

## Privacy

Raw individual-level responses are not published. The demographic combinations in this sample can uniquely identify individuals at a small institution, so we publish only aggregated summary statistics, regression coefficient tables, and figures. Researchers interested in the raw data may contact the authors.

## Limitations

1. Convenience sample at one small institution. Not generalizable to the broader public.
2. Self-reported AI familiarity may not capture actual AI literacy (an objective quiz would be cleaner).
3. Device effect confounds screen size with who-uses-what. A randomized controlled trial assigning device would separate these.
4. Only 10 images per respondent. Floor and ceiling effects are possible at the tails.
