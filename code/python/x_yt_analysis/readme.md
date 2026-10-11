# x\_yt\_analysis/ README

This folder contains scripts for processing and analyzing perceived humanness data for **X Posts** and **YouTube Comments**.

---

## Folder Contents

```
x_yt_analysis/
├── data/                                # Input data files for X and YouTube
│   ├── figures/                         # Regression plots and visualizations
│   ├── regression_results_x.csv         # Per-feature regression results for X Posts
│   ├── regression_results_yt.csv        # Per-feature regression results for YouTube Comments
│   ├── 0_attn_check.ipynb                # Removes attention check failures
│   ├── 1_data_loading.ipynb        # Loads and formats cleaned datasets
│   ├── 2_bradley_terry.ipynb       # Computes Bradley–Terry humanness scores
└── README.md
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
