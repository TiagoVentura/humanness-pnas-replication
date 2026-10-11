# tt\_ts\_analysis/

This folder contains the full analysis workflow for the TikTok (TT) and Truth Social (TS) datasets used in the humanness project.

---

## Folder Contents

```
tt_ts_analysis/
├── data/                                # Input datasets for TikTok (TT) and Truth Social (TS)
│   ├── figures/                         # Per-dataset coefficient plots
│   │   ├── regression_results_tt.csv    # Regression coefficients for TT
│   │   ├── regression_results_ts.csv    # Regression coefficients for TS
│   │   ├── <plots>.png                   # Generated coefficient plots
├── 0_attn_check.ipynb                   # Quality check for attention-check filtering
├── 1_data_loading.ipynb                 # Loads cleaned TT and TS data for analysis
├── 2_bradley_terry.ipynb                 # Applies Bradley-Terry model to compute humanness scores
├── readme.md                            # This file
├── VALUES-humanness_judgements.csv      # Reference data for humanness judgement labels
```

---

## Analysis Workflow

1. **Data Quality Check**

   * `0_attn_check.ipynb` filters and reports on failed attention-check participants.

2. **Data Loading**

   * `1_data_loading.ipynb` imports and structures the TT and TS datasets for analysis.

3. **Humanness Score Computation**

   * `2_bradley_terry.ipynb` fits a Bradley-Terry model to pairwise judgements and produces humanness scores for each post.

---

## Prerequisites

* **Python 3.8+**
* Dependencies:

  ```bash
  pip install pandas numpy statsmodels tabulate
  ```

---

## Usage

Run the analysis end-to-end in the order the notebooks are numbered.

---

## Notes

* CSV filenames use short platform codes (`tt` for TikTok Comments, `ts` for TruthSocial).