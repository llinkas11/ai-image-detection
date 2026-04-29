"""Step 03: reorder columns for readability, rename Qualtrics-internal
columns, and recode all blank cells as '.' so Stata reads them as missing.

Input:  AI_DetectionV2.csv  (output of step 02)
Output: AI_DetectionV3.csv  (482 columns)
"""

from pathlib import Path
import sys

try:
    import pandas as pd
except ImportError:
    sys.exit("requires pandas (pip install pandas)")

HERE = Path(__file__).resolve().parent
INPUT_CSV = HERE / "AI_DetectionV2.csv"
OUTPUT_CSV = HERE / "AI_DetectionV3.csv"

# Columns to drop (Qualtrics infrastructure not used in analysis)
DROP_PATTERNS = [
    "RecipientLastName", "RecipientFirstName", "RecipientEmail",
    "ExternalReference", "LocationLatitude", "LocationLongitude",
    "DistributionChannel", "UserLanguage",
    "Q_RelevantIDDuplicate", "Q_RelevantIDFraudScore",
    "Q_RelevantIDLastStartDate", "Q_RecaptchaScore", "Q_RecaptchaError",
    "Q_BallotBoxStuffing", "Q_DuplicateRespondent",
    "Status", "Progress", "Finished", "ResponseId",
    "IPAddress",
]


def rename_map() -> dict:
    """Friendly names for the columns we keep."""
    return {
        # demographics
        "InternationalStudent": "InternationalStudent",
        "InternationalFaculty": "InternationalFaculty",
        # behavioural
        "AI literacy": "AILiteracy",
        "AI use time": "AIUseTime",
        "Social Media use time": "SocialMediaUseTime",
        "AI Familiarity": "AIFamiliarity",
        "AI Course YN": "AICourseYN",
        "AI classes taken": "AIClassesTaken",
        "AI detection was easy": "DetectEasy",
        # other
        "Duration (in seconds)": "Duration",
    }


def main() -> None:
    if not INPUT_CSV.exists():
        sys.exit(f"missing input: {INPUT_CSV}")

    df = pd.read_csv(INPUT_CSV, low_memory=False)
    print(f"read {len(df)} rows x {len(df.columns)} columns")

    # Drop Qualtrics-internal columns by exact match or prefix
    drop_cols = [c for c in df.columns
                 if any(c == p or c.startswith(p) for p in DROP_PATTERNS)]
    df = df.drop(columns=drop_cols)
    print(f"dropped {len(drop_cols)} infrastructure columns")

    # Rename to friendlier names
    df = df.rename(columns=rename_map())

    # Reorder so each respondent's outcome columns come right after the
    # corresponding question columns. The user's slide-deck pipeline put
    # raw chunk columns BEHIND the outcome columns; we follow that ordering.
    metadata = ["StartDate", "EndDate", "Duration", "RecordedDate"]
    demographics = [
        "Affiliation", "InternationalStudent", "InternationalFaculty",
        "Age", "Gender", "Race", "Disability", "ADHD",
    ]
    behavioural = [
        "DetectEasy", "AILiteracy", "AIUseTime", "SocialMediaUseTime",
        "AIFamiliarity", "AICourseYN", "AIClassesTaken",
    ]
    outcomes = [c for i in range(1, 11) for c in (f"Q{i}", f"Q{i}Conf")]
    attention = ["AttnCheck1", "AttnConf1", "AttnCheck2", "AttnConf2"]
    embedded = ["ImgCount", "CalculatedScore", "Score", "AvgAnswTime",
                "DeviceType", "DeviceOther"]

    front = [c for c in (metadata + demographics + behavioural + outcomes
                         + attention + embedded) if c in df.columns]
    back = [c for c in df.columns if c not in front]
    df = df[front + back]

    # Replace blank cells with '.' so Stata's import delimited reads as missing.
    df = df.fillna(".")

    df.to_csv(OUTPUT_CSV, index=False)
    print(f"wrote {OUTPUT_CSV} ({len(df.columns)} columns)")


if __name__ == "__main__":
    main()
