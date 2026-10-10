##############################################################################
# File-Name: run_all.R
# author: Tiago Ventura
# Purpose: Run the full R pipeline in order from the package root (Rscript
#          code/run_all.R). 11_gpt_ai_detector.R is not sourced: it calls the
#          OpenAI API and its output ships in data/.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
setwd(here::here())
pdf(NULL)

scripts <- c(
  "01_clean_text_pairs.R",
  "02_clean_survey_data.R",
  "03_merge_response_pairs_surveys.R",
  "04_pairs_to_wide.R",
  "05_prep_followup_data.R",
  "06_analysis_bt.R",
  "07_direct_pairs.R",
  "08_semantic_features.R",
  "09_logit.R",
  "10_si_kde_platforms.R",
  "12_gpt_direct_classifier_figure.R",
  "13_balance_table_demographics.R",
  "14_qualitative_cues.R",
  "15_combined_mediators_by_demographics.R",
  "16_followup_selection_bias.R",
  "17_followup_ai_in_panelB.R"
)

for (s in scripts) {
  cat("\n==== ", s, " ====\n")
  source(file.path("code", s), echo = FALSE)
  setwd(here::here())
}
