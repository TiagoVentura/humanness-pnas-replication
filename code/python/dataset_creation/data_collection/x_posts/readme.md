# x\_posts/ README

This folder contains scripts and datasets for cleaning, combining, and preparing X (formerly Twitter) data for downstream analysis.

---

## Folder Contents

```
x_posts/
├── raw_x/                           # (not tracked) Place your input CSV exports here
├── x_cleaned/                       # Cleaned outputs from script 01
├── csv_combined_dataset.csv         # Combined dataset from script 02
├── x_combined_dataset_clean.csv     # Final dataset after script 03
├── 01_x_cleaning.py                 # Cleans raw .csv files from raw_x/ into x_cleaned/
├── 02_x_combine.py                  # Samples and merges generated + real data into csv_combined_dataset.csv
├── 03_httpurl_clean.py              # Replaces HTTPURL placeholders with broken links into x_combined_dataset_clean.csv
├── requirements.txt                 # Python dependencies
└── README.md                        # This file
```

---

## Prerequisites

* **Python 3.7+**
* Install dependencies via:

  ```bash
  pip install -r x_posts/requirements.txt
  ```

---

## Scripts Overview

### 1. `01_x_cleaning.py`

**Purpose:**

* Reads all `.csv` files in `raw_x/`.
* Replaces URLs with `HTTPURL` and usernames with `@USER`.
* Drops metadata/PII columns (e.g., `lang`, `author_id`, `user.*`, `geo.*`).
* Saves cleaned files to `x_cleaned/` as `cleaned_<original>.csv`.

**Usage:**

```bash
python x_posts/01_x_cleaning.py
```

---

### 2. `02_x_combine.py`

**Purpose:**

* Samples up to 500 real-world posts from `x_cleaned/`, filtering to English and unique.
* Cleans numbering/quotes and labels source as `X`.
* Combines these real-world posts into `csv_combined_dataset.csv`.

**Usage:**

````bash
python x_posts/02_x_combine.py
```

---

### 3. `03_httpurl_clean.py`

**Purpose:**

* Reads `csv_combined_dataset.csv`.
* Replaces each `HTTPURL` placeholder with a random broken `t.co` link.
* Outputs `x_combined_dataset_clean.csv`.

**Usage:**

```bash
python x_posts/03_httpurl_clean.py
```

---

## Data Files

* **`raw_x/`**: Raw exports from X API.
* **`x_cleaned/`**: Outputs from `01_x_cleaning.py`.
* **`csv_combined_dataset.csv`**: Master dataset from `02_x_combine.py`.
* **`x_combined_dataset_clean.csv`**: Final cleaned dataset from `03_httpurl_clean.py`.

---

## Notes

* Each script auto-creates necessary folders if missing.
* raw_x folder is not currently in this repositary. A download link will be made available.

---

