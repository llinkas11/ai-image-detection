#!/usr/bin/env python3
"""Strip em-dashes, emojis, ASCII-art separators, and hardcoded paths/tokens
from a source file before embedding in the public repo. Used by build.sh
to keep the analysis/ mirrors in sync with the OneDrive originals."""

import re
import sys
from pathlib import Path

UNICODE_MAP = {
    "—": " - ",   # em-dash
    "–": "-",     # en-dash
    "…": "...",   # ellipsis
    "→": "->",    # right arrow
    "≤": "<=",
    "≥": ">=",
    "±": "+/-",
    "×": "x",
    "≈": "~",
    "²": "2",
    "─": "",      # box-drawing horizontal
    "│": "",
    "└": "",
    "┐": "",
    "┌": "",
    "┘": "",
    "┤": "",
    "├": "",
    "═": "",
}

EMOJI_RE = re.compile(r'[\U0001F300-\U0001FAFF☀-➿]')

ABS_PATH_REPLACE = "/Users/llinkas/Library/CloudStorage/OneDrive-BowdoinCollege/Desktop/ADS/final-presentation/"


def clean(text: str) -> str:
    for u, a in UNICODE_MAP.items():
        text = text.replace(u, a)
    text = EMOJI_RE.sub("", text)
    text = text.replace(ABS_PATH_REPLACE, "")
    text = re.sub(r"^cd\s+\".*?\"\n", '* cd "set your working directory here"\n',
                  text, flags=re.MULTILINE)
    out_lines = []
    for line in text.split("\n"):
        stripped = line.lstrip()
        for char in ("#", "*", "//"):
            if stripped.startswith(char):
                body = stripped.lstrip(char).strip()
                if body and len(body) >= 4 and all(c in "-=_#*" for c in body):
                    line = ""
                break
        out_lines.append(line.rstrip())
    text = "\n".join(out_lines)
    text = re.sub(r"[-=_]{6,}", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text


def main():
    if len(sys.argv) != 3:
        sys.exit(f"Usage: {sys.argv[0]} <input> <output>")
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    text = src.read_text()
    text = clean(text)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text)
    print(f"  cleaned -> {dst.name} ({len(text.splitlines())} lines)")


if __name__ == "__main__":
    main()
