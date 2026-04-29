"""Step 01: pull Qualtrics responses and merge the recorded + in-progress
batches into a single 508-row CSV.

Wraps survey/export_responses.py, which already handles the Qualtrics REST
API two-phase export (start export, poll for completion, download zip).
This script keeps in-progress responses only when the score embedded-data
field is populated (the 99 percent completion threshold).

Reads QUALTRICS_API_TOKEN from the environment.

Output: survey_responses.csv (508 rows, 639 columns).
"""

from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
SURVEY_SCRIPT = HERE.parent / "survey" / "export_responses.py"


def main() -> None:
    if not SURVEY_SCRIPT.exists():
        sys.exit(f"missing: {SURVEY_SCRIPT}")
    subprocess.run([sys.executable, str(SURVEY_SCRIPT)], check=True, cwd=HERE)
    out = HERE / "survey_responses.csv"
    if out.exists():
        print(f"wrote {out} ({out.stat().st_size:,} bytes)")
    else:
        sys.exit("survey_responses.csv not produced")


if __name__ == "__main__":
    main()
