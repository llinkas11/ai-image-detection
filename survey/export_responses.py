#!/usr/bin/env python3
"""
Export Qualtrics survey responses (recorded and in-progress) to CSV.

Merges the two exports into one file. For in-progress responses, keeps only
rows where the score field is populated (near-complete responses).

Requires QUALTRICS_API_TOKEN environment variable.

Usage:
  export QUALTRICS_API_TOKEN=...
  python3 export_responses.py
"""

Export survey responses  -  recorded + in-progress (only if score is non-empty)

Qualtrics API v3 exports recorded and in-progress separately, so we:
  1. Export recorded responses
  2. Export in-progress responses
  3. Merge them, keeping only in-progress rows where 'score' is non-empty
  4. Write combined CSV
"""

import os
import csv, json, os, sys, time, zipfile, io

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

API_TOKEN  = os.environ["QUALTRICS_API_TOKEN"]
BASE_URL   = "https://bowdoincollege.qualtrics.com/API/v3"
SURVEY_ID  = "SV_bQ8cVhMLAvco9bE"
HEADERS    = {"X-API-TOKEN": API_TOKEN, "Content-Type": "application/json"}
OUT_DIR    = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
OUT_FILE   = os.path.join(OUT_DIR, "survey-responses-latest.csv")

def start_export(label, extra_params=None):
    """Start a response export and return the progressId."""
    params = {"format": "csv"}
    if extra_params:
        params.update(extra_params)
    print(f" Starting {label} export...")
    r = requests.post(f"{BASE_URL}/surveys/{SURVEY_ID}/export-responses",
                      headers=HEADERS, json=params, timeout=60)
    if r.status_code != 200:
        print(f" {r.status_code}: {r.text[:300]}")
        sys.exit(1)
    pid = r.json().get("result", {}).get("progressId", "")
    print(f"   Progress ID: {pid}")
    return pid

def poll_and_download(pid, label):
    """Poll until export is complete, then download and return CSV rows."""
    print(f" Polling {label}...")
    file_id = None
    for attempt in range(60):
        time.sleep(2)
        r = requests.get(f"{BASE_URL}/surveys/{SURVEY_ID}/export-responses/{pid}",
                         headers=HEADERS, timeout=60)
        result = r.json().get("result", {})
        status = result.get("status", "")
        pct = result.get("percentComplete", 0)
        if status == "complete":
            file_id = result.get("fileId", "")
            print(f"   Complete!")
            break
        if (attempt + 1) % 5 == 0:
            print(f"   [{attempt+1}] {status} ({pct}%)")
    else:
        sys.exit(f" {label} export timed out")

    # Download
    r = requests.get(f"{BASE_URL}/surveys/{SURVEY_ID}/export-responses/{file_id}/file",
                     headers={"X-API-TOKEN": API_TOKEN}, timeout=120)
    print(f"   Downloaded {len(r.content):,} bytes")

    # Extract CSV
    z = zipfile.ZipFile(io.BytesIO(r.content))
    csv_name = [n for n in z.namelist() if n.endswith(".csv")][0]
    raw = z.read(csv_name).decode("utf-8-sig")
    rows = list(csv.reader(raw.splitlines()))
    return rows

def main():
    #  Export both
    rec_pid = start_export("recorded")
    inp_pid = start_export("in-progress", {"exportResponsesInProgress": True})

    rec_rows = poll_and_download(rec_pid, "recorded")
    inp_rows = poll_and_download(inp_pid, "in-progress")

    # Parse CSVs  -  row 0 = headers, row 1 = import IDs, row 2 = labels, row 3+ = data
    rec_headers = rec_rows[0]
    rec_meta = rec_rows[1:3]
    rec_data = rec_rows[3:]

    inp_headers = inp_rows[0]
    inp_data = inp_rows[3:]

    print(f"\n Results:")
    print(f"   Recorded responses: {len(rec_data)}")
    print(f"   In-progress responses: {len(inp_data)}")

    # Verify headers match
    if rec_headers != inp_headers:
        print(f"  Header mismatch! Recorded has {len(rec_headers)} cols, in-progress has {len(inp_headers)} cols")
        # Use the longer header set
        if len(inp_headers) > len(rec_headers):
            rec_headers = inp_headers

    # Find 'score' column
    score_idx = None
    for i, h in enumerate(rec_headers):
        if h == "score":
            score_idx = i
            break

    # Filter in-progress: only keep rows where score is non-empty
    if score_idx is not None:
        print(f"   'score' column index: {score_idx}")
        filtered_inp = []
        dropped = 0
        for row in inp_data:
            if score_idx < len(row) and row[score_idx].strip() != "":
                filtered_inp.append(row)
            else:
                dropped += 1
        print(f"   In-progress with score (kept): {len(filtered_inp)}")
        print(f"   In-progress without score (dropped): {dropped}")
    else:
        print("  No 'score' column found  -  keeping all in-progress rows")
        filtered_inp = inp_data

    # Combine
    all_data = rec_data + filtered_inp
    print(f"\n   Total rows to export: {len(all_data)}")

    #  Write CSV
    print(f"\n Writing to {OUT_FILE}")
    with open(OUT_FILE, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(rec_headers)
        for mr in rec_meta:
            writer.writerow(mr)
        for row in all_data:
            writer.writerow(row)

    print(f"\n Exported: {OUT_FILE}")
    print(f"   {len(rec_data)} recorded + {len(filtered_inp)} in-progress (with score) = {len(all_data)} total")

if __name__ == "__main__":
    main()
