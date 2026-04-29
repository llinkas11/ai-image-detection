#!/usr/bin/env python3
"""Resolve {{< include path >}} directives inside appendix.md.

The directive is replaced inline with the contents of the named file,
relative to appendix/. Supports nested directives one level deep so an
included file can also reference figures or sub-includes. Lines that
embed an image with the {{< include >}} pattern are passed through
unchanged so pandoc handles them.

Usage: python3 _expand_includes.py appendix.md > _appendix_expanded.md
"""

import re
import sys
from pathlib import Path

INCLUDE_RE = re.compile(r"\{\{<\s*include\s+([^\s>]+)\s*>\}\}")
HERE = Path(__file__).resolve().parent


def expand(text: str) -> str:
    def replace(match):
        rel = match.group(1).strip()
        path = HERE / rel
        if not path.exists():
            return f"[MISSING INCLUDE: {rel}]"
        return path.read_text(errors="replace").rstrip()
    return INCLUDE_RE.sub(replace, text)


def main():
    if len(sys.argv) != 2:
        sys.exit(f"Usage: {sys.argv[0]} <markdown_file>")
    src = Path(sys.argv[1])
    text = src.read_text()
    sys.stdout.write(expand(text))


if __name__ == "__main__":
    main()
