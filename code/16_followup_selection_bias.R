##############################################################################
# File-Name: 16_followup_selection_bias.R
# author: Tiago Ventura
# Purpose: Selection into the follow-up survey: full main-study sample vs.
#          follow-up respondents. Produces SI Table S16.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
setwd(here::here())
pacman::p_load(tidyverse, modelsummary, kableExtra)
options(modelsummary_factory_latex     = "kableExtra",
        modelsummary_format_numeric_latex = "plain",
        knitr.table.format             = "latex")


# 1. Respondent-level frame from the discernment data (Fig-3 vars) ----------
d <- read_csv("data/pairs_survey_clean.csv", show_col_types = FALSE) %>%
  filter(att_check_sum == 0) %>%
  mutate(source_num = ifelse(source == "Human", 1, 0)) %>%
  group_by(response_id, order, platform) %>%
  mutate(sum_source = sum(source_num)) %>% ungroup() %>%
  filter(sum_source == 1, binary_response == 1) %>%
  mutate(correct = case_when(source == "Human" ~ 0, TRUE ~ 1)) %>%
  rowwise() %>%
  mutate(trust_online  = mean(c(news_trust_social_media, news_trust_news_websites)),
         trust_offline = mean(c(news_trust_newspapers, news_trust_radio, news_trust_local)),
         news_online   = mean(c(news_websites, news_fb, news_tt, news_yt, news_x)),
         news_offline  = mean(c(news_radio, news_newspapers, news_friends))) %>%
  ungroup()

resp <- d %>%
  group_by(participant_id) %>%
  summarise(discern_prop = mean(correct),                         # aggregate discernment
            across(c(age_group, sex, white, education_cat, party_id_imputation,
                     hispanic, news_online, news_offline, trust_online,
                     trust_offline, politics, conspiratory_beliefs_reescaled,
                     cyn_beliefs_reescaled), first),
            .groups = "drop")

# z-score attitudinal/media measures on the FULL sample
zv <- c("news_online","news_offline","trust_online","trust_offline",
        "politics","conspiratory_beliefs_reescaled","cyn_beliefs_reescaled")
resp <- resp %>% mutate(across(all_of(zv), ~ as.numeric(scale(.)), .names = "{.col}_z"))

# follow-up flag
fu_ids <- read_csv("data/followup_ai_clean.csv", show_col_types = FALSE)$participant_id
resp <- resp %>% mutate(followup = participant_id %in% fu_ids)

cat("Full sample:", nrow(resp), " | Follow-up takers:", sum(resp$followup), "\n")


# 2. Dummy-code categoricals (share of full sample) + labels ----------------
dm <- function(x, lvl) as.integer(coalesce(x == lvl, FALSE))   # NA -> 0 (share of all)

lv <- resp %>% transmute(
  `Age: <25`                      = dm(age_group, "<25"),
  `Age: 25-44`                    = dm(age_group, "25-44"),
  `Age: 45-64`                    = dm(age_group, "45-64"),
  `Age: 65+`                      = dm(age_group, "65+"),
  Male                            = dm(sex, "Male"),
  White                           = dm(white, "White"),
  `College degree`                = dm(education_cat, "College Degree"),
  `No college degree`             = dm(education_cat, "No College Degree"),
  `Post-graduate degree`          = dm(education_cat, "Post-Graduate Degree"),
  Democrat                        = dm(party_id_imputation, "Democrat"),
  Republican                      = dm(party_id_imputation, "Republican"),
  Hispanic                        = as.integer(hispanic %in% 1),
  `Online news consumption (z)`   = news_online_z,
  `Offline news consumption (z)`  = news_offline_z,
  `Trust in online news (z)`      = trust_online_z,
  `Trust in offline news (z)`     = trust_offline_z,
  `Interest in politics (z)`      = politics_z,
  `Conspiracy beliefs (z)`        = conspiratory_beliefs_reescaled_z,
  `News cynicism (z)`             = cyn_beliefs_reescaled_z,
  `AI discernment (prop. correct)`= discern_prop)


# 3. Joint orthogonality F-test: follow-up participation ~ all variables ----
fvars <- c("age_group","sex","white","education_cat","party_id_imputation",
           "hispanic", paste0(zv, "_z"), "discern_prop")
fdat  <- resp %>% mutate(fu = as.integer(followup)) %>%
  select(fu, all_of(fvars)) %>% drop_na()
fst   <- summary(lm(reformulate(fvars, "fu"), data = fdat))$fstatistic
pF    <- pf(fst[["value"]], fst[["numdf"]], fst[["dendf"]], lower.tail = FALSE)

# Hand-broken into short lines so each one stays within the tabular width
# (datasummary_balance writes one multicolumn row per element of `notes`,
# avoiding any single line running off the page).
fnote <- c(
  "Joint orthogonality test of follow-up participation regressed on all listed variables.",
  sprintf("F(%d, %d) = %.2f, p %s (complete cases, N = %d).",
          fst[["numdf"]], fst[["dendf"]], fst[["value"]],
          ifelse(pF < .001, "< 0.001", paste0("= ", sprintf("%.3f", pF))),
          nrow(fdat)),
  "Categorical levels are shares of the full sample;",
  "attitudinal/media measures are z-scored on the full sample.")
cat("\n", paste(fnote, collapse = "\n "), "\n")


# 4. Full-sample vs Follow-up balance table (overlapping) -> LaTeX ----------
bal <- bind_rows(lv %>% mutate(Sample = "Full sample"),
                 lv[resp$followup, ] %>% mutate(Sample = "Follow-up")) %>%
  mutate(Sample = factor(Sample, levels = c("Full sample", "Follow-up")))

caption   <- paste("Selection into the follow-up survey: full main-study sample",
                   "vs. follow-up respondents.")
out_local <- "output/tab_s16.tex"

datasummary_balance(~ Sample, data = bal, fmt = 2,
                    dinm_statistic = "p.value",
                    title  = caption,
                    notes  = fnote,
                    output = out_local)
cat("\nWrote", out_local, "\n")
