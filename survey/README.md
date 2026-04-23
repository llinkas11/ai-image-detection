# Survey scripts

Three Python scripts that build, export from, and audit the Qualtrics survey.

## Files

| File | Purpose |
|---|---|
| `build_survey.py` | Construct the Qualtrics survey via the REST API: creates blocks, questions, randomizers, embedded data, and flow. |
| `export_responses.py` | Export recorded and in-progress responses from Qualtrics to a single CSV. |
| `audit_survey.py` | Run a full QC pass on a live survey (check block counts, predictor coverage, scoring JavaScript, etc.). |

## Requirements

Python 3.9+ and the `requests` library:

```
pip install requests
```

## Authentication

All scripts read the API token from the `QUALTRICS_API_TOKEN` environment variable. Generate a token in Qualtrics under Account Settings -> Qualtrics IDs, then:

```
export QUALTRICS_API_TOKEN=your_token_here
```

The scripts are configured for the Bowdoin College Qualtrics instance (`bowdoincollege.qualtrics.com`). To target a different instance, edit `BASE_URL` in each script.

## Usage

Build the survey:

```
python3 build_survey.py
```

Export responses:

```
python3 export_responses.py
```

Writes `survey_responses.csv` in the current directory.

Audit a live survey against the expected schema:

```
SURVEY_ID=SV_xxx python3 audit_survey.py
```

## Notes

The build script clones intro, demographics, and AI usage blocks from an existing template survey. The template survey ID is read from the `TEMPLATE_SURVEY_ID` environment variable (defaults to the project's template).
