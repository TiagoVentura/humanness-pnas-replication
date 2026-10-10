# YouTube Comments Processing Pipeline

This repository contains a set of Python scripts and configurations for collecting, cleaning, sampling, and preparing YouTube comments data for analysis. The processing pipeline consists of three main stages:

1. **Initial JSON-to-CSV conversion** (`01_yt_cleaning.py`)
2. **Real-world sampling and dataset combination** (`02_more_cleaning.py`)
3. **Final comment-level cleaning** (`03_final_clean.py`)

---

## Repository Structure

```
youtube_comments/
├── csv_yt_comments/            # Directory for intermediate per-video CSV files
├── cleaned_yt_comments/        # (Optional) Directory for cleaned JSON outputs
├── raw_yt_comments/            # Directory containing original JSON comment files
├── 01_yt_cleaning.py           # Stage 1: JSON-to-CSV filtering (>5-word comments)
├── 02_more_cleaning.py         # Stage 2: Sampling, English detection, unique selection, combining
├── 03_final_clean.py           # Stage 3: Token and URL normalization
├── yt_combined_dataset.csv     # Combined dataset output (auto-generated)
├── requirements.txt            # Python dependencies
└── README.md                   # Project documentation (this file)
```

---

## Installation

1. Create and activate a Python environment (recommended):

   ```bash
   python -m venv .venv
   source .venv/bin/activate     # macOS/Linux
   .\.venv\Scripts\activate   # Windows
   ```

2. Install required dependencies:

   ```bash
   pip install -r requirements.txt
   ```

---

## Stage 1: JSON-to-CSV Conversion (`01_yt_cleaning.py`)

This script reads raw YouTube comment JSON files from `./raw_yt_comments`, filters out comments with 5 words or fewer, and saves each video’s remaining comments to a separate CSV in `./csv_yt_comments`.

**Key steps:**

* Define `id_to_name_mapping` to map video IDs to friendly CSV names.
* Parse each JSON line as a separate comment record.
* Extract fields: `etag`, `id`, `videoId`, `textDisplay`.
* Filter by word count (`> 5`).
* Save per-video CSV files:

  ```bash
  python 01_yt_cleaning.py
  ```

---

## Stage 2: Sampling and Combination (`02_more_cleaning.py`)

This script builds a real-world dataset of exactly 50 unique English comments per video by:

1. Sampling up to 1,000 comments per video from `./csv_yt_comments`.
2. Filtering for English comments using `langdetect`.
3. Ensuring exactly 50 unique comments, with resampling if necessary.
4. Normalizing content (strip numbering, quotes).
5. Labeling source as `YouTube` and appending to a combined DataFrame.
6. Saving the aggregated results to `yt_combined_dataset.csv`.

**Usage:**

```bash
python 02_more_cleaning.py
```

---

## Stage 3: Token and URL Normalization (`03_final_clean.py`)

This final cleanup script processes the combined CSV (`yt_combined_dataset.csv`) to:

* Replace any `@username` mentions with `@USER`.
* Substitute URLs (`http://`, `https://`, `www.`) with the placeholder `HTTPURL`.

It then overwrites the combined CSV with the cleaned content.

**Usage:**

```bash
python 03_final_clean.py
```

---

## requirements.txt

```text
pandas
langdetect
```

(Ensure `requirements.txt` is kept in sync with any additional dependencies.)

---

## Notes & Troubleshooting

* Update `raw_yt_comments` and `csv_yt_comments` directory paths in the scripts if your folder structure differs.
* If you encounter `LangDetectException`, comments will be skipped as non-English.

---

##
