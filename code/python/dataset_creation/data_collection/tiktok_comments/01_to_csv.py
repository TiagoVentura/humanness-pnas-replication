"""
@author: ransell
"""

import os
import json
import pandas as pd

RAW_DIR = "raw_data"

video_ids = [
    "7413232974096878891",
    "7413218924390632735",
    "7432437724176583968",
    "7413925988951657770",
    "7413199911044517166",
    "7413197374048341294",
    "7413239838541106478",
    "7413405886116318495",
    "7413572606147939630",
    "7414599502465600798"
]

# Build a lookup
vid_to_label = { vid: f"v{idx+1}" for idx, vid in enumerate(video_ids) }

for fname in os.listdir("RAW_DIR"):
    if not fname.endswith(".json"):
        continue

    base = os.path.splitext(fname)[0]

    # Find which video ID appears anywhere in the filename
    match_vid = None
    for vid in video_ids:
        if vid in base:
            match_vid = vid
            break

    if match_vid is None:
        print(f"Skipping {fname}: no matching video ID found.")
        continue

    label  = vid_to_label[match_vid]
    out_csv = f"{label}.csv"

    # Load JSON-lines
    records = []
    with open(fname, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"Skipping invalid JSON in {fname}: {e}")

    if not records:
        print(f"No valid records in {fname}.")
        continue

    # Flatten and write CSV
    df = pd.json_normalize(records)
    df.to_csv(out_csv, index=False)
    print(f"Wrote {len(df)} rows from {fname} to {out_csv}")
