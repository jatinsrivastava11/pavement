#!/usr/bin/env python3
"""Combine Data/cars/*.tsv into Pavement/Resources/cars.json and report problems."""
import csv, json, re, sys, unicodedata
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIERS = ["legendary", "exotic", "rare", "niche", "occasional", "common"]
ENGINES = "i3 i4 i5 i6 v6 v8 v10 v12 v16 w12 w16 flat4 flat6 rotary electric".split()
BODIES = "sedan hatchback wagon coupe convertible suv pickup van supercar".split()

def slug(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")

def main():
    cars, errors = [], []
    for path in sorted((ROOT / "Data/cars").glob("*.tsv")):
        with path.open(encoding="utf-8") as f:
            for line, row in enumerate(csv.DictReader(f, delimiter="\t"), start=2):
                where = f"{path.name}:{line}"
                if row["tier"] not in TIERS: errors.append(f"{where}: bad tier {row['tier']!r}")
                if row["engine"] not in ENGINES: errors.append(f"{where}: bad engine {row['engine']!r}")
                if row["body"] not in BODIES: errors.append(f"{where}: bad body {row['body']!r}")
                built = row.get("approx_built", "").strip()
                cars.append({
                    "id": slug(f"{row['make']} {row['model']}"),
                    "make": row["make"], "model": row["model"], "tier": row["tier"],
                    "engine": row["engine"], "body": row["body"],
                    **({"approxBuilt": int(built)} if built else {}),
                })
    for car_id, n in Counter(c["id"] for c in cars).items():
        if n > 1: errors.append(f"duplicate id {car_id}")
    if errors:
        print("\n".join(errors)); sys.exit(1)
    cars.sort(key=lambda c: (TIERS.index(c["tier"]), c["make"], c["model"]))
    out = ROOT / "Pavement/Resources/cars.json"
    out.write_text(json.dumps(cars, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    counts = Counter(c["tier"] for c in cars)
    print(f"{len(cars)} cars -> {out.relative_to(ROOT)}")
    print("  ".join(f"{t}: {counts.get(t, 0)}" for t in TIERS))

main()
