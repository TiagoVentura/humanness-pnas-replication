##############################################################################
# File-Name: 05_prep_followup_data.R
# author: Tiago Ventura
# Purpose: Clean the follow-up survey on AI usage and digital literacy and
#          link it to the main-study respondents. Produces
#          data/followup_ai_clean.csv.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Setup -------------------------------------------------------------------
setwd(here::here())

pacman::p_load(tidyverse, tidylog, janitor)

followup_path <- "data/survey_followup2.csv"
main_path     <- "data/survey_cleaned.csv"


# 1. Read raw follow-up, drop the 2 Qualtrics metadata rows ----------------
fu_raw <- read_csv(followup_path, col_types = cols(.default = col_character()))
cat("Raw follow-up rows:", nrow(fu_raw), "\n")

# remove tests
fu <- fu_raw %>%
  filter(str_detect(participantId, "^[A-Fa-f0-9]{32}$"))


# 2. Rename to short variable names (per codebook) -------------------------
fu <- fu %>%
  rename(
    participant_id      = participantId,      # == main `participant_id` (merge key)
    fu_response_id      = ResponseId,
    ai_freq             = `AI-freq`,
    ai_freq_chatgpt     = `AI-freqbytype_1`,
    ai_freq_gemini      = `AI-freqbytype_2`,
    ai_freq_copilot     = `AI-freqbytype_3`,
    ai_freq_grok        = `AI-freqbytype_4`,
    ai_freq_metaai      = `AI-freqbytype_5`,
    ai_freq_claude      = `AI-freqbytype_6`,
    ai_freq_deepseek    = `AI-freqbytype_7`,
    ai_freq_perplexity  = `AI-freqbytype_8`,
    ai_timing           = `AI-retro`,
    ai_purpose_raw      = `AI-purpose`,
    ai_purpose_other    = `AI-purpose_10_TEXT`,
    ai_confidence       = `AI-detection1`,
    ai_importance       = `AI-detection2`,
    ai_sentiment        = `AI-sentiment`,      # 1=more concerned ... 3=more excited
    ai_social_awareness = `AI-awareness`,
    human_pref          = `human-authpref`,
    dlit_recalgo        = `digital-lit_1`,
    dlit_clickbait      = `digital-lit_2`,
    dlit_phishing       = `digital-lit_3`,
    dlit_shadowban      = `digital-lit_4`,
    dlit_contentmod     = `digital-lit_5`,
    pol_attention       = politics,            # 1=extremely closely ... 5=not at all
    news_tv             = news_consumption_1,
    news_radio          = news_consumption_2,
    news_print          = news_consumption_3,
    news_websites       = news_consumption_4,
    news_social_ties    = news_consumption_5,
    news_x              = news_consumption_6,
    news_tiktok         = news_consumption_7,
    news_youtube        = news_consumption_8,
    news_truthsocial    = news_consumption_9,
    news_aichatbot      = news_consumption_10,
    sm_youtube          = socialmedia_usage_1,
    sm_tiktok           = socialmedia_usage_2,
    sm_x                = socialmedia_usage_3,
    sm_truthsocial      = socialmedia_usage_4,
    sm_instagram        = socialmedia_usage_5,
    sm_facebook         = socialmedia_usage_6,
    sm_reddit           = socialmedia_usage_7,
    fu_party_id         = Party_id,
    fu_party_lean       = Party_id_lean,
    fu_ideology         = ideo_place_self,
    ts_ai_choice        = ts_res
  )


# 3. Coerce numeric response columns to integer ----------------------------
int_cols <- c("ai_freq",
              paste0("ai_freq_", c("chatgpt","gemini","copilot","grok",
                                   "metaai","claude","deepseek","perplexity")),
              "ai_timing", "ai_confidence", "ai_importance", "ai_sentiment",
              "ai_social_awareness", "human_pref",
              paste0("dlit_", c("recalgo","clickbait","phishing",
                                "shadowban","contentmod")),
              "att_check", "pol_attention",
              "news_tv","news_radio","news_print","news_websites",
              "news_social_ties","news_x","news_tiktok","news_youtube",
              "news_truthsocial","news_aichatbot",
              "sm_youtube","sm_tiktok","sm_x","sm_truthsocial",
              "sm_instagram","sm_facebook","sm_reddit",
              "fu_party_id","fu_party_lean","fu_ideology","ts_ai_choice")

fu <- fu %>% mutate(across(all_of(int_cols), ~ suppressWarnings(as.integer(.))))
## tidylog returns no new NAs, all good.

# 4. Derived AI-usage variables --------------------------------------------
fu <- fu %>% mutate(att_pass = att_check == 3L)



## tool_breadth -----
# count of the 8 named chatbots used at all (freq > 1 = above "Never"). 
# Respondents who said "Never" at the gate (ai_freq == 1) skipped the matrix -> 
# assign breadth 0. 

tool_cols <- paste0("ai_freq_", c("chatgpt","gemini","copilot","grok",
                                  "metaai","claude","deepseek","perplexity"))
fu <- fu %>%
  rowwise() %>%
  mutate(tool_breadth = case_when(
    is.na(ai_freq)   ~ NA_integer_,
    ai_freq == 1L    ~ 0L,
    TRUE             ~ sum(c_across(all_of(tool_cols)) > 1L, na.rm = TRUE)
  )) %>%
  ungroup()

## quick check a few row



## ai timing --- 

# ai_never: no users based on ai_freq f
# ai_timing: 1=never, 2=2026, 3=2025, 4=2024, 5=2023+ (higher = earlier adopter).
# ai_timing_users = same scale but NA for non-users, so "earlier vs later" is  estimated among adopters only (the keep/drop robustness from the plan).

fu <- fu %>%
  mutate(
    ai_never        = ai_freq == 1L,
    ai_timing_users = if_else(ai_timing == 1L | ai_never, NA_integer_, ai_timing),
    # descriptive binary cutoffs (prose aids only)
    heavy_user      = ai_freq >= 6L,            # weekly or more
    early_adopter   = ai_timing == 5L           # 2023 or earlier
  )

## Digital-literacy index ----
# mean familiarity across the 5 items (higher = more familiar with recommendation algorithms / clickbait / phishing / shadowban /
# content moderation). 
dlit_cols <- paste0("dlit_", c("recalgo","clickbait","phishing",
                               "shadowban","contentmod"))
fu <- fu %>%
  rowwise() %>%
  mutate(dlit_index = mean(c_across(all_of(dlit_cols)), na.rm = TRUE)) %>%
  ungroup()

## Purposes: --- 

# parse the comma-separated select-all into 10 binary flags.
# Anchored regex so "1" does not match inside "10". NA purpose -> 0 on each flag
# (mostly the "Never" skippers); purpose_missing keeps the true-zero/skip split.
purpose_labels <- c("1" = "purpose_politics_news", "2" = "purpose_info_qa",
                    "3" = "purpose_work_edu",      "4" = "purpose_creative",
                    "5" = "purpose_entertainment", "6" = "purpose_companionship",
                    "7" = "purpose_health",        "8" = "purpose_shopping",
                    "9" = "purpose_travel",        "10" = "purpose_other")

for (code in names(purpose_labels)) {
  fu[[purpose_labels[[code]]]] <- as.integer(str_detect(
    replace_na(fu$ai_purpose_raw, ""),
    str_c("(^|,)\\s*", code, "\\s*($|,)")))
}

fu$purpose_missing <- as.integer(is.na(fu$ai_purpose_raw))


# 5. Merge demographics from the main study --------------------------------
demo_vars <- c("white","sex","age_group","education_cat","hispanic",
               "party_id_imputation")

main_demo <- read_csv(main_path, 
                      col_types = cols(.default = col_character())) %>%
  mutate(hispanic = suppressWarnings(as.integer(hispanic))) %>%
  select(participant_id, main_response_id = response_id, all_of(demo_vars)) %>%
  # 5 duplicates
  distinct(participant_id, .keep_all = TRUE)

clean <- fu %>% 
         left_join(main_demo, by = "participant_id")

# 6. Keep analysis columns, write -----------------------------------------
keep_cols <- c("participant_id", "fu_response_id", "main_response_id",
               demo_vars,
               "ai_freq", tool_cols, "tool_breadth",
               "ai_timing", "ai_timing_users", "ai_never",
               "heavy_user", "early_adopter",
               names(purpose_labels) %>% map_chr(~ purpose_labels[[.x]]),
               "purpose_missing",
               "ai_confidence", "ai_importance", "ai_sentiment",
               "ai_social_awareness", "human_pref",
               "news_aichatbot",
               dlit_cols, "dlit_index",
               "att_check", "att_pass")

clean_out <- clean %>% select(any_of(keep_cols))


## Save it
write_csv(clean_out, "data/followup_ai_clean.csv")

