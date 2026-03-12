#!/usr/bin/env python3
"""Small utility for dialogue authoring import/export between JSON and CSV.

Usage:
  # Export localization keys to CSV
  python scripts/tools/dialogue_import_export.py export-localization \
      --input resources/dialogue/localization/en.json \
      --output /tmp/dialogue_en.csv

  # Import localization CSV back to JSON
  python scripts/tools/dialogue_import_export.py import-localization \
      --input /tmp/dialogue_en.csv \
      --output resources/dialogue/localization/en.json
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def export_localization(input_path: Path, output_path: Path) -> None:
    data = json.loads(input_path.read_text(encoding="utf-8"))
    entries = data.get("entries", {})
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["text_key", "text"])
        for key in sorted(entries.keys()):
            writer.writerow([key, entries[key]])


def import_localization(input_path: Path, output_path: Path, locale: str) -> None:
    entries: dict[str, str] = {}
    with input_path.open("r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if "text_key" not in reader.fieldnames or "text" not in reader.fieldnames:
            raise SystemExit("CSV must include text_key,text columns")
        for row in reader:
            key = (row.get("text_key") or "").strip()
            if not key:
                continue
            entries[key] = row.get("text") or ""

    payload = {"locale": locale, "entries": dict(sorted(entries.items()))}
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    exp = sub.add_parser("export-localization")
    exp.add_argument("--input", required=True, type=Path)
    exp.add_argument("--output", required=True, type=Path)

    imp = sub.add_parser("import-localization")
    imp.add_argument("--input", required=True, type=Path)
    imp.add_argument("--output", required=True, type=Path)
    imp.add_argument("--locale", default="en")

    args = parser.parse_args()
    if args.cmd == "export-localization":
        export_localization(args.input, args.output)
    else:
        import_localization(args.input, args.output, args.locale)


if __name__ == "__main__":
    main()
