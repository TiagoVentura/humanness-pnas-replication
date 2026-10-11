# tt\_ts\_analysis/

This folder contains the full analysis workflow for the TikTok (TT) and Truth Social (TS) datasets used in the humanness project.

---

## Folder Contents

```
tt_ts_analysis/
├── 0_attn_check.ipynb        # Scores the attention checks, writes failed_attn_ids.csv
├── 1_data_loading.ipynb      # Reshapes the export into winner/loser pairs per platform
├── 2_bradley_terry.ipynb     # Fits the Bradley-Terry model, merges metadata, inverts scores
├── data/                     # Intermediate files and the bt_*_posts_rankings*.csv outputs
├── VALUES-humanness_june_2025_TS_TT_July 14, 2025_17.06.csv    # Qualtrics export (de-identified)
└── readme.md
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