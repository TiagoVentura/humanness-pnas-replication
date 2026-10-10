# x\_yt\_analysis/ README

This folder contains scripts for processing and analyzing perceived humanness data for **X Posts** and **YouTube Comments**.

---

## Folder Contents

```
x_yt_analysis/
├── data/                                # Input data files for X and YouTube
├── outputs_analysis1/                   # Outputs from analysis scripts
│   ├── figures/                         # Regression plots and visualizations
│   ├── regression_results_x.csv         # Per-feature regression results for X Posts
│   ├── regression_results_yt.csv        # Per-feature regression results for YouTube Comments
│   ├── 0_attn_check.ipynb                # Removes attention check failures
│   ├── 1_data_loading.ipynb        # Loads and formats cleaned datasets
│   ├── 2_bradley_terry.ipynb       # Computes Bradley–Terry humanness scores
│   └── 3_analysis.ipynb     # Minimal regression + visualization pipeline
└── README.md
```

---

## Prerequisites

* **Python 3.8+**
* `tweetnlp`, `pandas`, `numpy`, `matplotlib`, `seaborn`, `statsmodels`

Install dependencies:

```bash
pip install tweetnlp pandas numpy matplotlib seaborn statsmodels
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

### 3. `3_analysis.ipynb`

* Extracts semantic, stylistic, and sentiment features using **TweetEval via tweetnlp**.
* Runs standardized OLS regressions predicting humanness scores for each platform separately.
* Saves:

  * Per-dataset regression results CSVs (`regression_results_x.csv`, `regression_results_yt.csv`)
  * Corresponding coefficient plots in `figures/`
* **Purpose:** Identify which linguistic and stylistic features are most predictive of perceived humanness for X vs. YouTube.

---

## Notes

* Outputs in `outputs_analysis1/` are overwritten each time the pipeline is run.
* CSV filenames use short platform codes (`x` for X Posts, `yt` for YouTube).
* The regression results and visualizations are designed for direct inclusion in the Results section of the paper.

---
