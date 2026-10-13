# BT_analysis/

Upstream steps that turn the raw pairwise judgments into the inputs the paper's scripts read. Nothing here produces a figure or table directly.

## Bradley-Terry scores

One set of three notebooks per survey wave: `x_yt_*` for Survey 1 (X/Twitter and YouTube) and `tt_ts_*` for Survey 2 (Truth Social and TikTok). Run them in numerical order from inside this folder.

```
BT_analysis/
├── x_yt_0_attn_check.ipynb      # Scores the attention checks, writes data/x_yt_failed_attn_ids.csv
├── x_yt_1_data_loading.ipynb    # Reshapes the export into winner/loser pairs per platform
├── x_yt_2_bradley_terry.ipynb   # Fits the Bradley-Terry model, merges metadata, inverts scores
├── tt_ts_0_attn_check.ipynb     # Same three steps for Survey 2
├── tt_ts_1_data_loading.ipynb
├── tt_ts_2_bradley_terry.ipynb
├── VALUES-humanness_march_2025_YT_X_March 13, 2025_11.13.csv   # Qualtrics export, Survey 1 (de-identified)
├── VALUES-humanness_june_2025_TS_TT_July 14, 2025_17.06.csv    # Qualtrics export, Survey 2 (de-identified)
├── data/                        # Intermediate files and the bt_*_posts_rankings*.csv outputs
├── build_feature_labels.py      # Builds the TweetEval and BERTweet label files
├── labels_columns.txt           # Column documentation for the label files
└── readme.md
```

- `*_0_attn_check.ipynb` filters participants who fail the attention checks and writes `data/<wave>_attention_checks_analysis.csv` (SI Table S7) and `data/<wave>_failed_attn_ids.csv`.
- `*_1_data_loading.ipynb` reshapes the Qualtrics export into one row per judgment with the winning and losing post, and writes `data/{x,yt}_data.csv` or `data/{tt,ts}_data.csv`.
- `*_2_bradley_terry.ipynb` fits a Bradley-Terry model (binomial GLM, statsmodels) to each platform's judgments, rank-normalises the abilities to the -1 to 1 PHI scale, merges the post metadata (source model, persona) and flips the sign so higher means more human-like. The resulting `data/bt_*_posts_rankings_with_source_persona_inverted.csv` files are copied to the package's `data/bt_scores/`, where the R scripts read them.

CSV filenames use short platform codes: `x`, `yt`, `tt`, `ts`.

## Text-feature labels

`build_feature_labels.py` reads the four `data/bt_scores_features/post_traits_*.csv` files and writes `data/tweeteval_eval/labels_tweeteval.csv` (TweetEval labels taken from the post-trait files) and `labels_bertweet.csv` (BERTweet classifiers run through HuggingFace, GPU if available). `labels_columns.txt` documents the columns. Run from inside this folder: `python build_feature_labels.py`.

## Requirements

Python 3.8+, `pandas`, `numpy`, `statsmodels`, `tabulate`; `transformers` and `torch` for the BERTweet step.

```bash
pip install pandas numpy statsmodels tabulate transformers torch
```
