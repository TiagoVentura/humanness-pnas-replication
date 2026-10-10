## Replication Materials: _Humans show limited ability to distinguish human-authored and AI-generated political content on social media_

Replication materials for *Humans show limited ability to distinguish human-authored and AI-generated political content on social media*, authored by Sejin Paik, Tiago Ventura, Rebecca Ansell, Leticia Bode, Autumn Toney-Wails, and Lisa Singh, published in the *Proceedings of the National Academy of Sciences*.

> __Abstract:__
This study employs a set of behavioral experiments to examine how individuals perceive the humanness of social media posts about the 2024 U.S. presidential debate between Kamala Harris and Donald Trump. Posts presented in the experiment were authored either by humans or chatbots, varying the large language model (LLM), the model architecture, the social media platform, and the political personas. Participants judged randomly-paired posts on which they perceived to be AI-generated. We find that human-authored posts were on average perceived as more human-like than AI outputs generated from five of the six LLMs in this study. However, participants' ability to detect AI-generated content is limited. They do so only slightly above chance in human-AI pairs, and this ability weakens for newer LLMs, varies by platform, and reflects partisan bias. Only posts generated with Llama 3.3 scored, on average, higher on perceived humanness than human-authored posts. The social media platform also mattered, with participants distinguishing human from AI on most platforms (YouTube, TikTok, Truth Social), but not on X/Twitter. Incivility and negative emotions are associated with high humanness perceptions, and partisan identity also shaped evaluations, with Republican respondents more likely to view ideologically mis-aligned AI posts as AI-generated.
>

## Tutorial

This README file provides an overview of the replication materials for the article and its SI Appendix.

The R code used in the article and the SI Appendix can be found in the folder `**code**`. The Python notebooks and scripts that produce the upstream inputs (Bradley-Terry scores, attention checks, survey descriptives, text-feature labels) and the original data-collection and generation code are in `**code/python**`.

The datasets for the full replication of the article and the SI Appendix can be found in the folder `**data**`.

All figures and tables produced by the code are written to the folder `**output**`.

We also provide a [codebook](codebook.md) describing the variables in the analysis datasets.

Data, outputs and documentation are released under CC0 1.0; code under the MIT License. See [LICENSE](LICENSE), which also notes that the human-authored posts remain the property of their original authors.

To reproduce every figure and table from the raw survey exports, open the project in R (the `.Rproj` file sets the working directory) and run

```r
source("code/run_all.R")
```

or, from a terminal at the package root,

```bash
Rscript code/run_all.R
```

The script runs the 16 R scripts listed below in order, regenerating the derived datasets (`survey_cleaned.csv`, `pairs_data_*.csv`, `pairs_survey_clean.csv`, `all_pairs_wide_format.csv`, `followup_ai_clean.csv`) and then every figure and table. A full run takes about three minutes on a laptop. Packages are loaded with `pacman::p_load()`, which installs anything missing; an `renv.lock` file records the exact package versions used for the published results (`renv::restore()` recreates that library).

Two steps are not part of `run_all.R`: `11_gpt_ai_detector.R` calls the OpenAI API (about 21,000 calls) and its output ships in `data/`; the Python Bradley-Terry notebooks produce `data/bt_scores/`, which ships ready to use. Both can be re-run as described below.

## Code

### R scripts (`code/`)

- `00_utils.R`: user-defined ggplot theme, color palettes, a confidence-interval helper, and `save_function()`, which writes figures to `output/`. Sourced by the analysis scripts.

- `01_clean_text_pairs.R`: reshapes the raw Qualtrics exports into one row per respondent, pair, and post, attaches the post text and source, and codes the attention checks. Produces `pairs_data_yt_x.csv` and `pairs_data_tt_ts.csv`.

- `02_clean_survey_data.R`: builds the respondent-level file from the raw survey exports and the CloudResearch Connect demographics (party, news trust and consumption, conspiracy and cynicism scales, social media use, education, income). Produces `survey_cleaned.csv`.

- `03_merge_response_pairs_surveys.R`: merges the pairwise responses with the respondent-level file. Produces `pairs_survey_clean.csv`, the main analysis dataset.

- `04_pairs_to_wide.R`: converts the pairwise responses to one row per pair (left and right post). Produces `all_pairs_wide_format.csv`, the input to the GPT-5 detector.

- `05_prep_followup_data.R`: cleans the follow-up survey on AI usage and digital literacy and links it to the main study respondents. Produces `followup_ai_clean.csv`.

- `06_analysis_bt.R`: marginal means and regressions of PHI scores on post source. Produces Figure 1 in the main article; Tables S12, S13, and S24 (regression tables and marginal means), Table S3 (post counts), and Table S23 (PHI summary statistics) in the SI Appendix.

- `07_direct_pairs.R`: AI-detection rates in human-AI pairs and the validation of PHI scores against detection. Produces Figures S5, S6, and S7.

- `08_semantic_features.R`: regressions of PHI scores on sentiment, emotion, and civility features, with robustness checks across classifier families and by post source, and the stylistic-marker analysis. Produces Figure 2 in the main article; Figures S2, S8, S9, and S10 and Tables S4 and S5 in the SI Appendix.

- `09_logit.R`: logistic models of correct AI identification on respondent characteristics, and the persona-by-party model. Produces Figures 3 and 4 in the main article.

- `10_si_kde_platforms.R`: kernel densities of normalized PHI scores by platform. Produces Figure S3.

- `11_gpt_ai_detector.R`: runs GPT-5 as a zero-shot detector on every pair (requires `OPENAI_API_KEY`). Not sourced by `run_all.R`; its output is shipped as `data/gpt_detector_sample_gpt-5_all_posts_20260511.csv`.

- `12_gpt_direct_classifier_figure.R`: detection rates of the GPT-5 benchmark on the same pairs as the human labels. Produces Figure S13.

- `13_balance_table_demographics.R`: demographic composition of Survey 1, Survey 2, and the general population. Produces Table S19.

- `14_qualitative_cues.R`: codes the open-ended responses on the cues participants used and cross-tabulates cue by direction. Produces Figure S4 and `summary_A_to_E.csv`, the counts quoted in the SI text.

- `15_combined_mediators_by_demographics.R`: demographic differences in detection and in the candidate mechanisms measured in the follow-up survey. Produces Table S17.

- `16_followup_selection_bias.R`: selection into the follow-up survey. Produces Table S16.

- `17_followup_ai_in_panelB.R`: re-estimates the Figure 3B model adding AI usage and digital literacy. Produces Table S18.

- `run_all.R`: sources the scripts above in order.

### Python (`code/python/`)

- `x_yt_analysis/` and `tt_ts_analysis/`: the Bradley-Terry pipeline for each survey wave. `0_attn_check.ipynb` filters attention-check failures from the Qualtrics export and writes `data/attention_checks_analysis.csv` (Table S7); `1_data_loading.ipynb` reshapes the pairwise judgments into winner/loser pairs; `2_bradley_terry.ipynb` fits the Bradley-Terry model (statsmodels, binomial GLM), merges post metadata, and writes the `bt_*_posts_rankings_with_source_persona_inverted.csv` files that the R scripts read from `data/bt_scores/`. Its summary cells print the per-model counts (Table S3) and PHI statistics (Table S23). Run the notebooks in numerical order from inside each folder; the Qualtrics exports and all intermediate files are included.

- `demographic_analysis/`: `attitudes.ipynb` and `dems.ipynb` compute the survey descriptives in Tables S20, S21, and S22 and the demographic counts used by Table S19. Run from inside the folder; they read from `data/` and write to `output/`.

- `tweeteval_eval/comparing_eval_models.py`: builds `data/tweeteval_eval/labels_tweeteval.csv` and `labels_bertweet.csv` from the post-trait files, running the BERTweet classifiers through HuggingFace. `datasets.txt` documents the columns.

- `dataset_creation/`: the original collection and cleaning scripts for the human posts (`data_collection/`, one folder per platform) and the LLM generation scripts with the debate and video transcripts they used as context (`data_generation/`). Provided for provenance; the raw platform dumps they read are not included.

## Data

See the [codebook](codebook.md) for information about the variables in the datasets below. All respondent-level files are anonymized: IP addresses, geolocation, recipient fields, and free-text feedback were removed, and the CloudResearch Connect participant identifier was replaced by a salted hash (consistent across files, so all merges reproduce).

- `raw_yt_x_survey.csv`, `raw_tt_ts_survey.csv`: Qualtrics exports of Survey 1 (X/Twitter and YouTube) and Survey 2 (Truth Social and TikTok) with labelled responses, one row per respondent. `raw_yt_x_survey_num.csv` and `raw_tt_ts_survey_num.csv` are the same exports with numeric response codes. Inputs to `01` and `02`.

- `connect_survey_yt_x.csv`, `connect_survey_ts_tt.csv`: CloudResearch Connect demographic profiles for the participants of each survey. Input to `02`, `09`, and `13`.

- `x_selected_150_posts.csv`, `yt_selected_150_posts.csv`, `tt_selected_600_posts.csv`, `ts_selected_600_posts.csv`: the stimulus posts shown in the surveys, with source and persona. Input to `01`.

- `survey_followup2.csv`: Qualtrics export of the follow-up survey on AI usage and digital literacy (May 2026). Input to `05`.

- `pairs_data_yt_x.csv`, `pairs_data_tt_ts.csv`: pairwise judgments in long format, one row per respondent, pair, and post. Generated by `01`.

- `survey_cleaned.csv`: respondent-level covariates. Generated by `02`.

- `pairs_survey_clean.csv`: pairwise judgments merged with respondent covariates. The main analysis dataset, used by `07`, `09`, `15`, `16`, and `17`. Generated by `03`.

- `all_pairs_wide_format.csv`: one row per pair with left and right post. Generated by `04`, input to `11`.

- `followup_ai_clean.csv`: cleaned follow-up survey linked to main-study respondents. Generated by `05`, used by `15`, `16`, and `17`.

- `OE_Humanness.xlsx`: open-ended responses on the cues participants used, by survey (sheets `All`, `ytx`, `ttts`). Input to `14`.

### Additional datasets

- `bt_scores/bt_{x,yt,tt,ts}_posts_rankings_with_source_persona_inverted.csv`: Bradley-Terry ability and normalized PHI score for every post, with source, persona, and model. Produced by `code/python/*/2_bradley_terry.ipynb`; input to `06`, `07`, and `10`.

- `bt_scores_features/post_traits_{x,yt,tt,ts}.csv`: the BT scores joined with lexical measures (character, word, sentence, exclamation and capitalization counts, type-token ratio) and Cardiff TweetEval (RoBERTa) sentiment, emotion, hate, irony, and offensiveness labels and probabilities. Six readability and lexicon-sentiment columns in the header (Flesch, SMOG, VADER, TextBlob) are empty and unused. Input to `08`.

- `tweeteval_eval/labels_tweeteval.csv`, `labels_bertweet.csv`: binary labels and probabilities from the TweetEval and BERTweet classifier families for all 2,386 posts. Produced by `code/python/tweeteval_eval/comparing_eval_models.py`; input to `08`.

- `gpt_detector_sample_gpt-5_all_posts_20260511.csv`: GPT-5 zero-shot judgments for every pair, produced by `11` on 2026-05-11. Input to `12`.

## Computational Infrastructure

The Python stage was run with Python 3.11.4, pandas 1.5.3, numpy 1.24.3, and statsmodels 0.14.0.

To ensure reproducibility, here is the output of `sessionInfo()` with every package used by the R scripts loaded, at the time this project was last run:

```r
sessionInfo()
```

```
R version 4.5.1 (2025-06-13)
Platform: aarch64-apple-darwin20
Running under: macOS Sequoia 15.6.1

Matrix products: default
BLAS:   /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libRblas.0.dylib 
LAPACK: /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libRlapack.dylib;  LAPACK version 3.12.1

locale:
[1] en_US.UTF-8/en_US.UTF-8/en_US.UTF-8/C/en_US.UTF-8/en_US.UTF-8

time zone: America/New_York
tzcode source: internal

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
 [1] RColorBrewer_1.1-3        estimatr_1.0.6           
 [3] digest_0.6.37             readxl_1.4.5             
 [5] jsonlite_2.0.0            httr2_1.1.2              
 [7] glue_1.8.0                quanteda.textstats_0.97.2
 [9] quanteda_4.3.0            wesanderson_0.3.7        
[11] kableExtra_1.4.0          modelsummary_2.5.0       
[13] patchwork_1.3.1           clubSandwich_0.6.0       
[15] lmtest_0.9-40             zoo_1.8-14               
[17] sandwich_3.1-1            marginaleffects_1.0.0    
[19] lme4_1.1-37               Matrix_1.7-3             
[21] tidylog_1.1.0             stargazer_5.2.3          
[23] janitor_2.2.1             ggalt_0.4.0              
[25] ggtext_0.1.2              ggdist_3.3.3             
[27] here_1.0.1                broom_1.0.10             
[29] rebus_0.1-3               extrafont_0.19           
[31] srvyr_1.3.0               knitr_1.50               
[33] scales_1.4.0              lubridate_1.9.4          
[35] forcats_1.0.0             stringr_1.5.1            
[37] dplyr_1.1.4               purrr_1.1.0              
[39] readr_2.1.5               tidyr_1.3.1              
[41] tibble_3.3.0              ggplot2_3.5.2            
[43] tidyverse_2.0.0          

loaded via a namespace (and not attached):
 [1] Rdpack_2.6.4          DBI_1.2.3             rlang_1.1.6          
 [4] magrittr_2.0.3        snakecase_0.11.1      rebus.base_0.0-3     
 [7] compiler_4.5.1        systemfonts_1.2.3     vctrs_0.6.5          
[10] maps_3.4.3            pkgconfig_2.0.3       fastmap_1.2.0        
[13] backports_1.5.0       rmarkdown_2.29        tzdb_0.5.0           
[16] nloptr_2.2.1          xfun_0.52             ash_1.0-15           
[19] stopwords_2.3         R6_2.6.1              tables_0.9.31        
[22] stringi_1.8.7         boot_1.3-31           extrafontdb_1.0      
[25] estimability_1.5.1    cellranger_1.1.0      nsyllable_1.0.1      
[28] Rcpp_1.1.0            clisymbols_1.2.0      pacman_0.5.1         
[31] splines_4.5.1         timechange_0.3.0      tidyselect_1.2.1     
[34] rstudioapi_0.18.0     lattice_0.22-7        rebus.datetimes_0.0-2
[37] withr_3.0.2           coda_0.19-4.1         evaluate_1.0.4       
[40] survival_3.8-3        survey_4.4-2          rebus.numbers_0.0-1  
[43] xml2_1.3.8            texreg_1.39.4         pillar_1.11.0        
[46] KernSmooth_2.23-26    reformulas_0.4.1      distributional_0.5.0 
[49] generics_0.1.4        rprojroot_2.0.4       hms_1.1.3            
[52] minqa_1.2.8           xtable_1.8-4          emmeans_1.11.2       
[55] tools_4.5.1           data.table_1.17.8     mvtnorm_1.3-3        
[58] fastmatch_1.1-6       grid_4.5.1            mitools_2.4          
[61] Rttf2pt1_1.3.12       rbibutils_2.3         nlme_3.1-168         
[64] rebus.unicode_0.0-2   Formula_1.2-5         cli_3.6.5            
[67] rappdirs_0.3.3        textshaping_1.0.1     proj4_1.0-15         
[70] viridisLite_0.4.2     svglite_2.2.1         gtable_0.3.6         
[73] farver_2.1.2          htmltools_0.5.8.1     lifecycle_1.0.4      
[76] httr_1.4.7            gridtext_0.1.5        MASS_7.3-65          
```
