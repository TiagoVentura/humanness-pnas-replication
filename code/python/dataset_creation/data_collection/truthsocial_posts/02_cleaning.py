"""
@author: ransell
"""
#!/usr/bin/env python3
import os
import glob
import csv
import re
import random
from pathlib import Path

import pandas as pd
from bs4 import BeautifulSoup

# Paths & constants
BASE_DIR = Path(__file__).resolve().parent
CSV_DIR = BASE_DIR / "csv_updated"
CLEANED_DIR = BASE_DIR / "csv_files_cleaned_updated"
CLEANED_DIR.mkdir(parents=True, exist_ok=True)

# Part 1 constants
DAY_FILTER_OUTPUT = BASE_DIR / "day_of_debate_posts.csv"
DAY_FILTER_DATE = "2024-09-10"

# Part 2 constants
FILES_TO_PROCESS = [
    "debatenight_20240910.csv",
    "debate2024_20240910.csv",
]
COLUMNS_TO_KEEP = ["created_at", "content", "id"]

# Part 3 constants
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
    "https://tinyurl.com/uz1c3h6f",
]
EVENING_OUTPUT = BASE_DIR / "evening_debate_posts_clean.csv"
TARGET_DATE = "2024-09-10"
START_TIME = "19:00:00"
END_TIME = "23:59:59"
TAG_PATTERN = re.compile(r"\b(debate2024|debatenight)\b", re.IGNORECASE)



# Helpers
def censor_text(text: str) -> str:
    """Mask @mentions and replace URLs with random TinyURL."""
    if not isinstance(text, str):
        return ""
    # mask @mentions like "@username" or "@ username"
    text = re.sub(r'@\s*[A-Za-z0-9_]+', '@USER', text)
    # replace any http(s):// link, even if broken by spaces
    text = re.sub(
        r'https?://\s*\S+(?:\s*\S+)*',
        lambda m: random.choice(TINYURLS),
        text,
        flags=re.IGNORECASE
    )
    return text


# Part 1: Combine all CSVs and keep rows on the debate night
def run_day_filter():
    folder = CSV_DIR
    files = glob.glob(str(folder / "*.csv"))
    if not files:
        print(f"No CSV files found in {folder!s}.")
        return

    dfs = []
    for f in files:
        try:
            df = pd.read_csv(f, parse_dates=["created_at"])
            dfs.append(df)
        except Exception as e:
            print(f"Skipping {f!r}: {e}")

    if not dfs:
        print("No valid data loaded (Part 1).")
        return

    combined = pd.concat(dfs, ignore_index=True)
    combined = combined.dropna(subset=["created_at"])

    target_date = pd.to_datetime(DAY_FILTER_DATE).date()
    mask = combined["created_at"].dt.date == target_date
    day10 = combined[mask]

    count = len(day10)
    print(f"[Part 1] Found {count} posts collected on {target_date}.")
    day10.to_csv(DAY_FILTER_OUTPUT, index=False)
    print(f"[Part 1] Saved filtered posts to {DAY_FILTER_OUTPUT.name}")


# Part 2: Clean selected files (strip HTML from `content`) and keep selected columns
def run_clean_selected_files():
    input_folder = CSV_DIR
    output_folder = CLEANED_DIR

    for filename in FILES_TO_PROCESS:
        input_csv_path = input_folder / filename
        output_csv_path = output_folder / f"{Path(filename).stem}_readable.csv"

        if not input_csv_path.exists():
            print(f"[Part 2] File not found: {input_csv_path}")
            continue

        with open(input_csv_path, "r", encoding="utf-8") as infile, \
             open(output_csv_path, "w", newline="", encoding="utf-8") as outfile:

            reader = csv.DictReader(infile)
            writer = csv.DictWriter(outfile, fieldnames=COLUMNS_TO_KEEP)
            writer.writeheader()

            for row in reader:
                filtered_row = {col: row.get(col, "") for col in COLUMNS_TO_KEEP}
                soup = BeautifulSoup(filtered_row["content"], "html.parser")
                plain_text = soup.get_text(separator=" ", strip=True)
                filtered_row["content"] = plain_text
                writer.writerow(filtered_row)

        print(f"[Part 2] Cleaned and readable CSV saved to {output_csv_path.name}")


# Part 3: Compile evening posts with keyword filter, censor text, US/Eastern window
def run_evening_compile():
    folder = CSV_DIR
    files = glob.glob(str(folder / "*.csv"))
    if not files:
        print(f"No CSV files found in '{folder}'.")
        return
    print(f"[Part 3] Found {len(files)} files in '{folder.name}'.")

    parts = []
    for f in files:
        try:
            df = pd.read_csv(f, usecols=["created_at", "text", "id"])
            df["created_at"] = pd.to_datetime(df["created_at"], utc=True)
            parts.append(df)
        except Exception as e:
            print(f"  Skipping {f}: {e}")

    if not parts:
        print("[Part 3] No valid data loaded.")
        return

    combined = pd.concat(parts, ignore_index=True)
    print(f"[Part 3] Loaded {len(combined)} total rows.")
    combined = combined.dropna(subset=["created_at", "text"])

    # Convert to US/Eastern timezone
    combined["created_at"] = combined["created_at"].dt.tz_convert("US/Eastern")

    # Filter to the specified date and time window
    start = pd.Timestamp(f"{TARGET_DATE} {START_TIME}", tz="US/Eastern")
    end = pd.Timestamp(f"{TARGET_DATE} {END_TIME}", tz="US/Eastern")
    print(f"[Part 3] Filtering posts between {start.time()} and {end.time()} on {TARGET_DATE} EDT...")
    window = combined[(combined["created_at"] >= start) & (combined["created_at"] <= end)]
    print(f"[Part 3] Rows after time filter: {len(window)}")

    if window.empty:
        print("[Part 3] No posts in the specified time window.")
        return

    # Filter by keywords in text
    print("[Part 3] Filtering posts by keyword in text...")
    keyword_mask = window["text"].apply(lambda s: bool(TAG_PATTERN.search(s)))
    filtered = window[keyword_mask].copy()
    print(f"[Part 3] Rows after keyword filter: {len(filtered)}")

    if filtered.empty:
        print("[Part 3] No posts match the specified keywords.")
        return

    # Apply text cleaning
    print("[Part 3] Applying text cleaning...")
    filtered["text"] = filtered["text"].apply(censor_text)

    # Save only required columns
    result = filtered[["created_at", "text", "id"]]
    result.to_csv(EVENING_OUTPUT, index=False)
    print(f"[Part 3] Wrote {len(result)} cleaned posts to '{EVENING_OUTPUT.name}'.")



def main():
    run_day_filter()
    run_clean_selected_files()
    run_evening_compile()


if __name__ == "__main__":
    main()
