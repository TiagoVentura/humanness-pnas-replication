"""
@author: ransell
"""

import os
import re
import random
import pandas as pd

OUTPUT_FILE = "all_tt_cleaned.csv"

# TinyURL placeholders for link censorship
TINYURLS = [
    "https://tinyurl.com/xf4b2k7a",
    "https://tinyurl.com/yg9m3p5r",
    "https://tinyurl.com/qh8t1u2n",
    "https://tinyurl.com/db6r4w9s",
    "https://tinyurl.com/mj5x8c3e",
    "https://tinyurl.com/kp7n2v4b",
    "https://tinyurl.com/ar3z6l1q",
    "https://tinyurl.com/tw2y5j9k",
    "https://tinyurl.com/np4s8e7d",
    "https://tinyurl.com/uz1c3h6f"
]

def censor_text(text: str) -> str:
    """Mask @mentions and replace any URLs or placeholders with random TinyURL."""
    if not isinstance(text, str):
        return ""
    # mask @mentions
    text = re.sub(r'@[A-Za-z0-9_]+', '@USER', text)
    # replace URLs or placeholders
    text = re.sub(r'\b(?:https?://|ftp://|www\.)\S+\b', 
                  lambda m: random.choice(TINYURLS), text)
    text = re.sub(r'\bHTTPURL\b|\[link\]', 
                  lambda m: random.choice(TINYURLS), text, flags=re.IGNORECASE)
    return text

video_pattern = re.compile(r'^(v[1-9]|v10)\.csv$')

all_rows = []
next_id = 1

for fname in os.listdir("."):
    if not video_pattern.match(fname):
        continue

    video_label = video_pattern.match(fname).group(1)
    df = pd.read_csv(fname)

    # filter English comments
    if "comment_language" in df.columns:
        df = df[df["comment_language"] == "en"]
    else:
        continue

    for _, row in df.iterrows():
        text = row.get("text", "")
        clean = censor_text(text)
        all_rows.append({
            "id":        next_id,
            "video":     video_label,
            "aweme_id":  row.get("aweme_id", ""),
            "cid":       row.get("cid", ""),
            "text":      clean
        })
        next_id += 1

combined_df = pd.DataFrame(all_rows)
combined_df.to_csv(OUTPUT_FILE, index=False)
print(f"Wrote {len(combined_df)} comments to {OUTPUT_FILE}")
