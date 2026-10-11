# x\_yt\_analysis/ README

This folder contains scripts for processing and analyzing perceived humanness data for **X Posts** and **YouTube Comments**.

---

## Folder Contents

```
x_yt_analysis/
├── 0_attn_check.ipynb        # Scores the attention checks, writes failed_attn_ids.csv
├── 1_data_loading.ipynb      # Reshapes the export into winner/loser pairs per platform
├── 2_bradley_terry.ipynb     # Fits the Bradley-Terry model, merges metadata, inverts scores
├── data/                     # Intermediate files and the bt_*_posts_rankings*.csv outputs
├── VALUES-humanness_march_2025_YT_X_March 13, 2025_11.13.csv   # Qualtrics export (de-identified)
└── readme.md
```

---

## Prerequisites

* **Python 3.8+**
* `pandas`, `numpy`, `statsmodels`, `tabulate`

Install dependencies:

```bash
pip install pandas numpy statsmodels tabulate
```

---

## Scripts Overview

### 0. `0_attn_check.ipynb`

* Filters out participants who fail predefined attention checks.
* Saves filtered datasets for downstream analysis.

### 1. `1_data_loading.ipynb`

* Loads X and YouTube datasets.
* Cleans and standardizes column names and formats for consistency.

### 2. `2_bradley_terry.ipynb`

* Fits a Bradley–Terry model to produce **humanness scores** from ranking data.
* Outputs CSVs with normalized scores per post.


---

## Notes

* CSV filenames use short platform codes (`x` for X Posts, `yt` for YouTube).

---
