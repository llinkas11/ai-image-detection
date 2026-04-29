#!/usr/bin/env bash
# Build the appendix.docx (and appendix.pdf if pdflatex is present).
# Run from anywhere, but the script cd's into appendix/ first.
set -euo pipefail

cd "$(dirname "$0")"

ONEDRIVE="/Users/llinkas/Library/CloudStorage/OneDrive-BowdoinCollege/Desktop/ADS/final-presentation"
PPTX_SRC="/Users/llinkas/Library/CloudStorage/OneDrive-BowdoinCollege/Desktop/setup_and_model_justification.pptx"
REPO_ROOT="$(cd .. && pwd)"
STATA="/Applications/Stata/StataBE.app/Contents/MacOS/StataBE"


echo "[0/5] Syncing latest source files from OneDrive..."

# Parallel arrays (bash 3.2 compatible, the macOS default)
SRC_FILES=(
  "descriptives.do"
  "oprobit-regression.do"
  "oprobit-regression-by-affiliation.do"
  "m2_diagnostics.do"
  "score-regression-count.do"
)
DST_FILES=(
  "descriptives.do"
  "oprobit_regression.do"
  "oprobit_regression_by_affiliation.do"
  "m2_diagnostics.do"
  "score_regression_count.do"
)

for i in "${!SRC_FILES[@]}"; do
  src="${SRC_FILES[$i]}"
  dst="${DST_FILES[$i]}"
  if [[ -f "$ONEDRIVE/$src" ]]; then
    python3 _clean_for_repo.py "$ONEDRIVE/$src" "$REPO_ROOT/analysis/$dst"
  else
    echo "  WARN: $src not found in OneDrive, skipping"
  fi
done

if [[ -f "$PPTX_SRC" ]]; then
  cp "$PPTX_SRC" "$REPO_ROOT/presentation/ai-detection.pptx"
  echo "  copied .pptx -> presentation/ai-detection.pptx"
fi


echo "[1/5] Cleanliness gate (no leaks)..."
LEAKS=$(grep -rl --include='*.do' --include='*.py' \
  -e '/Users/llinkas/Library' \
  -e 'UGfXyNEt' \
  "$REPO_ROOT/analysis" "$REPO_ROOT/survey" 2>/dev/null || true)
if [[ -n "$LEAKS" ]]; then
  echo "BUILD FAILED: leaked path/token detected in:" >&2
  echo "$LEAKS" >&2
  exit 1
fi


echo "[2/5] Setting up _outputs/ tree..."
rm -rf _outputs
mkdir -p _outputs/{logs,figs,tables,data}
mkdir -p _outputs/figs/{descriptives,exploratory,tables}

DTA_SRC="$ONEDRIVE/data/AI_DetectionV3_lite.dta"
if [[ ! -f "$DTA_SRC" ]]; then
  echo "BUILD FAILED: raw dataset missing at $DTA_SRC" >&2
  exit 1
fi
cp "$DTA_SRC" _outputs/data/AI_DetectionV3_lite.dta


echo "[3/5] Running Stata batch (this takes a few minutes)..."
if [[ ! -x "$STATA" ]]; then
  echo "BUILD FAILED: Stata BE not found at $STATA" >&2
  exit 1
fi
"$STATA" -e -q do run_all.do
echo "  Stata done. Logs in _outputs/logs/."


echo "[4/5] Expanding {{< include >}} directives..."
python3 _expand_includes.py appendix.md > _appendix_expanded.md


echo "[5/5] Compiling document..."
if ! command -v pandoc >/dev/null 2>&1; then
  echo "BUILD FAILED: pandoc not installed (brew install pandoc)" >&2
  exit 1
fi

pandoc _appendix_expanded.md -o appendix.docx \
  --toc --number-sections \
  --resource-path=. \
  -V geometry:margin=1in
echo "  built appendix.docx"

if command -v pdflatex >/dev/null 2>&1; then
  pandoc _appendix_expanded.md -o appendix.pdf \
    --toc --number-sections \
    --resource-path=. \
    --pdf-engine=pdflatex \
    -V geometry:margin=1in
  echo "  built appendix.pdf"
else
  echo "  pdflatex not installed; skipping PDF (open appendix.docx in Word and Save As PDF)"
fi

rm _appendix_expanded.md
echo
echo "Done. Output: appendix.docx"
[[ -f appendix.pdf ]] && echo "        appendix.pdf"
