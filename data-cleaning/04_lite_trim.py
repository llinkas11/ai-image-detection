"""Step 04: trim to the 49 key variables analysis actually uses.

Input:  AI_DetectionV3.csv (482 columns)
Output: AI_DetectionV3_lite.csv (49 columns)

The trim drops the raw chunk (image-block) columns and the per-block
timing columns. Their information is summarised in Q1..Q10 and AvgAnswTime
respectively.
"""

from pathlib import Path
import sys

try:
    import pandas as pd
except ImportError:
    sys.exit("requires pandas (pip install pandas)")

HERE = Path(__file__).resolve().parent
INPUT_CSV = HERE / "AI_DetectionV3.csv"
OUTPUT_CSV = HERE / "AI_DetectionV3_lite.csv"

KEEP = [
    # response metadata
    "StartDate", "EndDate", "Duration", "RecordedDate",
    # behavioural predictors
    "DetectEasy", "AILiteracy", "AIUseTime", "SocialMediaUseTime",
    "AIFamiliarity", "AICourseYN", "AIClassesTaken",
    # demographics
    "Affiliation", "InternationalStudent", "InternationalFaculty",
    "Age", "Gender", "Race", "Disability", "ADHD",
    # device + identity
    "DeviceType", "DeviceOther", "ImgCount",
    # outcomes (10 questions x 2 fields)
    "Q1", "Q1Conf", "Q2", "Q2Conf", "Q3", "Q3Conf", "Q4", "Q4Conf",
    "Q5", "Q5Conf", "Q6", "Q6Conf", "Q7", "Q7Conf", "Q8", "Q8Conf",
    "Q9", "Q9Conf", "Q10", "Q10Conf",
    # attention checks
    "AttnCheck1", "AttnConf1", "AttnCheck2", "AttnConf2",
    # derived scores
    "CalculatedScore", "Score", "AvgAnswTime",
]


def main() -> None:
    if not INPUT_CSV.exists():
        sys.exit(f"missing input: {INPUT_CSV}")

    df = pd.read_csv(INPUT_CSV, low_memory=False)
    keep_existing = [c for c in KEEP if c in df.columns]
    missing = [c for c in KEEP if c not in df.columns]
    if missing:
        print(f"WARNING: expected columns missing: {missing}")

    df = df[keep_existing]
    df.to_csv(OUTPUT_CSV, index=False)
    print(f"wrote {OUTPUT_CSV}: {len(df)} rows x {len(df.columns)} columns")


if __name__ == "__main__":
    main()
