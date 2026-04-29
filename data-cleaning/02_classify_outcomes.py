"""Step 02: per-respondent x image binary-classification outcomes.

For each of the 10 image blocks each respondent saw, compute the outcome
of the binary classification (TP, TN, FP, FN) and add it as a new column.
Also derive: per-image confidence, total CalculatedScore, AvgAnswTime,
AttnCheck1/2 binary, DeviceType numeric.

Inputs:
  survey_responses.csv          from step 01
  ../survey/data/graphic_ids.json   block-to-image mapping (gives ground truth)
  QUALTRICS_API_TOKEN              for fetching survey definition (block IDs)

Output: AI_DetectionV2.csv

Logic outline:
  1. Read the Qualtrics survey definition from the API to get the
     block-to-question and block-to-graphic-id mappings.
  2. For each block whose description starts with "Img_F_" the ground
     truth is "fake"; "Img_R_" is "real". Attention checks have a separate
     description prefix and use a fixed truth.
  3. Map each MC question's export tag (e.g. Q42) to its parent block's
     ground truth.
  4. For each respondent row in survey_responses.csv:
     - Iterate the 10 image-block MC columns the respondent answered.
     - Pull the respondent's answer (1 = Real, 2 = AI).
     - Compute outcome = TP / TN / FP / FN.
     - Pull the matching confidence column (Q42_Conf).
     - Pull the per-block timing column (Q42_PageTimer).
  5. Compute CalculatedScore (count of TP + TN), AvgAnswTime (mean of
     10 per-image timings), AttnCheck1/2 (binary pass), DeviceType (0/1/2).
  6. Write Q1..Q10 (outcome strings) and Q1Conf..Q10Conf (confidence)
     columns. Verify CalculatedScore matches Qualtrics's native Score
     embedded-data field for each respondent.

This is a logical reconstruction of the classifier the team built in
April 2026. The exact Qualtrics column-name mapping is survey-dependent;
the function map_block_to_truth below is the part that needs to be
adapted if the survey schema changes.
"""

from __future__ import annotations

import json
import os
import sys
from collections import defaultdict
from pathlib import Path

try:
    import pandas as pd
    import requests
except ImportError:
    sys.exit("requires pandas and requests (pip install pandas requests)")


HERE = Path(__file__).resolve().parent
INPUT_CSV = HERE / "survey_responses.csv"
GRAPHICS_JSON = HERE.parent / "survey" / "data" / "graphic_ids.json"
OUTPUT_CSV = HERE / "AI_DetectionV2.csv"
SURVEY_DEF_CACHE = HERE / "survey_def_cache.json"

API_TOKEN = os.environ.get("QUALTRICS_API_TOKEN")
SURVEY_ID = os.environ.get("QUALTRICS_SURVEY_ID", "SV_bQ8cVhMLAvco9bE")
BASE_URL = "https://bowdoincollege.qualtrics.com/API/v3"

N_IMAGES = 10  # image blocks shown per respondent


def fetch_survey_definition() -> dict:
    # Cached locally because the survey schema is static after the survey
    # closes. Set REFRESH_SURVEY=1 to force a fresh API fetch.
    if SURVEY_DEF_CACHE.exists() and not os.environ.get("REFRESH_SURVEY"):
        return json.loads(SURVEY_DEF_CACHE.read_text())
    if not API_TOKEN:
        sys.exit("QUALTRICS_API_TOKEN not set")
    r = requests.get(
        f"{BASE_URL}/survey-definitions/{SURVEY_ID}",
        headers={"X-API-TOKEN": API_TOKEN, "Content-Type": "application/json"},
        timeout=120,
    )
    r.raise_for_status()
    result = r.json().get("result", {})
    SURVEY_DEF_CACHE.write_text(json.dumps(result))
    return result


def block_truth_map(survey_def: dict) -> dict:
    """Map block_id to ground truth ('fake' or 'real') from block description."""
    out = {}
    for bid, blk in survey_def.get("Blocks", {}).items():
        desc = blk.get("Description", "")
        if desc.startswith("Img_F_"):
            out[bid] = "fake"
        elif desc.startswith("Img_R_"):
            out[bid] = "real"
        elif desc.startswith("AttentionCheck"):
            out[bid] = "fake"  # attention checks are obvious AI images
    return out


def question_to_block(survey_def: dict) -> dict:
    """Map QID (e.g. QID42) to its parent block_id."""
    out = {}
    for bid, blk in survey_def.get("Blocks", {}).items():
        for elt in blk.get("BlockElements", []):
            if elt.get("Type") == "Question":
                out[elt["QuestionID"]] = bid
    return out


def export_tag(survey_def: dict, qid: str) -> str:
    """Return the column name Qualtrics uses in the CSV export for this QID."""
    q = survey_def.get("Questions", {}).get(qid, {})
    return q.get("DataExportTag", "")


OUTCOME_MAP = {
    ("2", "fake"): "TP",
    ("1", "real"): "TN",
    ("2", "real"): "FP",
    ("1", "fake"): "FN",
}


def classify(answer: str, truth: str) -> str:
    """answer is "1" (Real) or "2" (AI); truth is 'fake' or 'real'."""
    return OUTCOME_MAP.get((answer, truth), "")


def main() -> None:
    if not INPUT_CSV.exists():
        sys.exit(f"missing input: {INPUT_CSV}")

    survey_def = fetch_survey_definition()
    btruth = block_truth_map(survey_def)
    qblock = question_to_block(survey_def)

    df = pd.read_csv(INPUT_CSV, low_memory=False)
    print(f"read {len(df)} rows x {len(df.columns)} columns")

    # Identify image-block MC questions: those whose parent block has truth in btruth.
    mc_questions = []
    for qid, bid in qblock.items():
        if bid not in btruth:
            continue
        q = survey_def["Questions"].get(qid, {})
        if q.get("QuestionType") == "MC":
            tag = export_tag(survey_def, qid)
            if tag and tag in df.columns:
                mc_questions.append((qid, bid, tag))

    print(f"{len(mc_questions)} image-block MC questions identified")

    # For each row, walk every MC question this respondent answered (skipping NaN);
    # compute outcome string and pull the confidence column.
    outcomes = defaultdict(list)
    confidences = defaultdict(list)
    timings = defaultdict(list)
    attn1 = []
    attn2 = []

    for _, row in df.iterrows():
        seen = []
        for qid, bid, tag in mc_questions:
            ans = row.get(tag, "")
            if pd.isna(ans) or ans == "":
                continue
            truth = btruth[bid]
            outcome = classify(str(int(float(ans))), truth)
            seen.append((bid, outcome, row.get(f"{tag}_Conf", ""),
                         row.get(f"{tag}_PageTimer", "")))

        # Distinguish image blocks (truth from F/R) vs attention check blocks
        img_seen = [s for s in seen if not survey_def["Blocks"][s[0]]["Description"]
                    .startswith("AttentionCheck")]
        attn_seen = [s for s in seen if survey_def["Blocks"][s[0]]["Description"]
                     .startswith("AttentionCheck")]

        # Pad to 10 image entries; later columns will be NaN if respondent saw fewer.
        for i in range(N_IMAGES):
            if i < len(img_seen):
                _, outcome, conf, timer = img_seen[i]
                outcomes[i + 1].append(outcome)
                confidences[i + 1].append(conf)
                timings[i + 1].append(timer)
            else:
                outcomes[i + 1].append("")
                confidences[i + 1].append("")
                timings[i + 1].append("")

        # Attention checks
        if len(attn_seen) >= 1:
            attn1.append(1 if attn_seen[0][1] == "TP" else 0)
        else:
            attn1.append(0)
        if len(attn_seen) >= 2:
            attn2.append(1 if attn_seen[1][1] == "TP" else 0)
        else:
            attn2.append(0)

    # Add derived columns
    for i in range(1, N_IMAGES + 1):
        df[f"Q{i}"] = outcomes[i]
        df[f"Q{i}Conf"] = confidences[i]

    df["AttnCheck1"] = attn1
    df["AttnCheck2"] = attn2

    # CalculatedScore = count(TP + TN) across Q1..Q10
    df["CalculatedScore"] = sum(
        (df[f"Q{i}"] == "TP").astype(int) + (df[f"Q{i}"] == "TN").astype(int)
        for i in range(1, N_IMAGES + 1)
    )

    # AvgAnswTime = mean of the 10 timings (numeric; non-numeric become NaN)
    timing_cols = []
    for i in range(1, N_IMAGES + 1):
        col = f"_t{i}"
        df[col] = pd.to_numeric(pd.Series(timings[i]), errors="coerce")
        timing_cols.append(col)
    df["AvgAnswTime"] = df[timing_cols].mean(axis=1)
    df = df.drop(columns=timing_cols)

    # DeviceType numeric encoding (0 = unknown, 1 = laptop, 2 = mobile)
    if "DeviceType" not in df.columns:
        # Try common Qualtrics column names that captured device
        for candidate in ("Q349", "DeviceType_Selected"):
            if candidate in df.columns:
                df["DeviceType"] = df[candidate]
                break

    # Verify against Qualtrics's native Score embedded-data field
    if "Score" in df.columns:
        score_num = pd.to_numeric(df["Score"], errors="coerce")
        mismatch = (df["CalculatedScore"] != score_num).sum()
        if mismatch:
            print(f"WARNING: {mismatch} rows where CalculatedScore != native Score")

    df.to_csv(OUTPUT_CSV, index=False)
    print(f"wrote {OUTPUT_CSV} ({len(df.columns)} columns)")


if __name__ == "__main__":
    main()
