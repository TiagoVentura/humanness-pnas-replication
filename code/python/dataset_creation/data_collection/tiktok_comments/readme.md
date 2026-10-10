# tiktok\_comments/ README

This folder contains scripts and datasets for cleaning, combining, and preparing TikTok comment data for downstream analysis.

---

## Folder Contents

```
tiktok_comments/
├── raw_data/                       # (not tracked) Place your raw JSON-lines files here
├── v1.csv ... v10.csv               # Per-video CSV outputs from script 01
├── all_tt_cleaned.csv               # Final cleaned combined dataset from script 02
├── 01_to_csv.py                     # Converts raw JSON-lines files into per-video CSVs
├── 02_cleaned_tiktok.py             # Filters to English, censors PII/links, combines into all_tt_cleaned.csv
├── requirements.txt                 # Python dependencies
└── README.md                        # This file
```

---

## Prerequisites

* **Python 3.8+**
* Install dependencies via:

  ```bash
  pip install -r requirements.txt
  ```

---

## Scripts Overview

### 1. `01_to_csv.py`

**Purpose:**

* Reads raw JSON-lines TikTok exports from `raw_data/`.
* Detects video IDs in filenames and maps them to `v1`–`v10`.
* Normalizes JSON into tabular CSV format.
* Outputs `v1.csv` … `v10.csv` in the working directory.

**Usage:**

```bash
python 01_to_csv.py
```

---

### 2. `02_cleaned_tiktok.py`

**Purpose:**

* Reads `v1.csv` … `v10.csv`.
* Filters to English-language comments (`comment_language == "en"`).
* Replaces `@mentions` with `@USER`.
* Replaces URLs/placeholders (`HTTPURL`, `[link]`) with random TinyURL stubs.
* Combines all videos into `all_tt_cleaned.csv` with minimal, cleaned schema.

**Usage:**

```bash
python 02_cleaned_tiktok.py
```

---

## Data Files

* **`raw_data/`**: Raw JSON-lines exports from TikTok.
* **`v1.csv` … `v10.csv`**: Per-video CSVs from `01_to_csv.py`.
* **`all_tt_cleaned.csv`**: Final combined cleaned dataset from `02_cleaned_tiktok.py`.

---

## Notes

* Script 02 will skip any per-video CSV that does not have a `comment_language` column.
* All URLs are replaced with neutral TinyURLs for privacy.
* Video IDs are replaced with generic labels (`v1` … `v10`) 

---
