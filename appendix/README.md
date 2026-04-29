# Appendix

Reproducible technical appendix for the AI Detection Study.

## What it is

A single Word document (`appendix.docx`, with optional `appendix.pdf`) that walks the reader through every analytical step: filter pipeline, descriptive statistics, exploratory analysis, model specification, subsample analysis, diagnostics, margins, and robustness checks. Every figure, table, and Stata log embedded in the document is regenerated from source by a single command.

## Build it

```
bash appendix/build.sh
```

Run from any directory; the script `cd`s into `appendix/` first. About 3-5 minutes end-to-end on a 2024-era MacBook.

## What the build does

1. Re-syncs the most recent versions of every analysis `.do` file from the authors' OneDrive working copy into `analysis/` (run through `_clean_for_repo.py` to strip em-dashes, hardcoded paths, and any leaked tokens).
2. Re-copies the most recent `.pptx` from OneDrive into `presentation/`.
3. Verifies cleanliness (no `/Users/llinkas/...` paths, no API tokens, no em-dashes left behind). Fails the build if any leak is found.
4. Copies the raw dataset (gitignored) into `_outputs/data/` for Stata to read.
5. Runs Stata in batch mode (`StataBE -e -q do run_all.do`) which executes every analysis script in order, capturing per-section logs to `_outputs/logs/` and figures to `_outputs/figs/`.
6. Expands `{{< include path >}}` directives in `appendix.md` by inlining the named files.
7. Calls pandoc to compile the expanded markdown to `appendix.docx`. If `pdflatex` is available, also produces `appendix.pdf`.

## Requirements

- macOS with Stata 18 BE installed at `/Applications/Stata/StataBE.app/`
- `pandoc` (install with `brew install pandoc`)
- Optional: `pdflatex` (install with `brew install --cask basictex`) for direct PDF output. Without it, the `.docx` is the deliverable; open it in Word and use File -> Save As PDF.
- Read access to the authors' OneDrive working copy at `/Users/llinkas/Library/CloudStorage/OneDrive-BowdoinCollege/Desktop/ADS/final-presentation/`. (The build will fail with a clear message if this is unavailable.)

## Files

| File | Purpose |
|---|---|
| `appendix.md` | Hand-written narrative, references regenerated outputs by path |
| `build.sh` | Single-command build (sync, run, compile) |
| `run_all.do` | Stata master that calls every analysis in order |
| `exploratory.do` | Bivariate exploratory analysis (Section C, new for this appendix) |
| `po_subsample_tests.do` | Parallel-regression tests on faculty (mf3b) and student (ms3c) subsamples + subsample VIFs (Section F.2 - F.4) |
| `_clean_for_repo.py` | Strips em-dashes, paths, tokens from synced source files |
| `_expand_includes.py` | Resolves `{{< include >}}` directives in `appendix.md` |
| `_outputs/` | Build artifacts (logs, figures, tables, data); regenerated each build, gitignored |
| `appendix.docx`, `appendix.pdf` | Output deliverables; regenerated each build, gitignored |
