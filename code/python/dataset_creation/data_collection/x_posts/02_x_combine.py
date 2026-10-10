#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
@author: ransell

Samples up to 500 unique, English-language posts from your real-world X data
in x_cleaned/, removes numbering/quotes, and writes the result to csv_combined_dataset.csv.
"""

import os
import pandas as pd
import random
import re
from langdetect import detect, LangDetectException

# Directory where cleaned CSVs live
REAL_WORLD_DIR = 'x_cleaned'

# Output file
OUTPUT_FILE = 'csv_combined_dataset.csv'

# If OUTPUT_FILE exists, load it and avoid re-adding duplicates
if os.path.exists(OUTPUT_FILE):
    master_df = pd.read_csv(OUTPUT_FILE)
    existing = set(master_df['post'].tolist())
    print(f"Loaded existing dataset with {len(existing)} posts.")
else:
    master_df = pd.DataFrame(columns=['post', 'source'])
    existing = set()
    print("Starting new dataset.")

# Helper to strip numbering and edge quotes
def clean_post(text: str) -> str:
    # Remove leading “1. ” style numbering
    text = re.sub(r'^\d+\.\s*', '', text)
    # Strip surrounding quotes if present
    if text.startswith('"') and text.endswith('"'):
        text = text[1:-1]
    return text.strip()

# Language detector with counter
counter = [0]
def is_english(s: str) -> bool:
    try:
        counter[0] += 1
        if counter[0] % 100 == 0:
            print(f"Checked {counter[0]} posts for English.")
        return detect(s) == 'en'
    except LangDetectException:
        return False

# Collect samples
samples = []
for fname in os.listdir(REAL_WORLD_DIR):
    if not fname.lower().endswith('.csv'):
        continue

    path = os.path.join(REAL_WORLD_DIR, fname)
    df = pd.read_csv(path)

    if 'text' not in df.columns:
        print(f"Skipping {fname}, no 'text' column")
        continue

    # Randomly pick 500 rows (or fewer if file smaller)
    tmp = df[['text']].dropna().sample(n=min(500, len(df)), random_state=42)
    tmp['post'] = tmp['text'].apply(clean_post)

    # Filter English
    tmp = tmp[tmp['post'].apply(is_english)]

    # Decide final count per file
    if '#debate2024' in fname.lower():
        keep_n = min(250, len(tmp))
    else:
        keep_n = min(125, len(tmp))
    tmp = tmp.sample(n=keep_n, random_state=42)

    # Remove any posts we’ve already saved
    tmp = tmp[~tmp['post'].isin(existing)]
    existing.update(tmp['post'].tolist())

    # Tag and collect
    tmp = tmp[['post']].copy()
    tmp['source'] = 'X'
    samples.append(tmp)

    print(f"{fname}: selected {len(tmp)} final posts.")

# Combine and write out
if samples:
    new_df = pd.concat([master_df] + samples, ignore_index=True)
else:
    new_df = master_df

new_df.to_csv(OUTPUT_FILE, index=False)
print(f"Wrote {len(new_df)} total posts to {OUTPUT_FILE}.")
