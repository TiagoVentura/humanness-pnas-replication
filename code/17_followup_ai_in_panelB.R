##############################################################################
# File-Name: 17_followup_ai_in_panelB.R
# author: Tiago Ventura
# Purpose: Figure 3B attitudinal model with AI usage and digital literacy
#          added. Produces SI Table S18.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
setwd(here::here())
pacman::p_load(tidyverse, lme4, modelsummary, kableExtra)
options(modelsummary_factory_latex     = "kableExtra",
        modelsummary_format_numeric_latex = "plain")
glmer_ctrl <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))


# 1. Build d_h_ai with panel-B composites (rescaled on full d_h_ai, as 02b) -
d <- read_csv("data/pairs_survey_clean.csv", show_col_types = FALSE) %>%
  filter(att_check_sum == 0) %>%
  mutate(source_num = ifelse(source == "Human", 1, 0)) %>%
  group_by(response_id, order, platform) %>%
  mutate(sum_source = sum(source_num)) %>% ungroup() %>%
  filter(sum_source == 1, binary_response == 1) %>%
  mutate(correct = case_when(source == "Human" ~ 0, TRUE ~ 1)) %>%
  rowwise() %>%
  mutate(trust_news_online  = mean(c(news_trust_social_media,
                                     news_trust_news_websites)),
         trust_news_offline = mean(c(news_trust_newspapers, news_trust_radio,
                                     news_trust_local)),
         nco = mean(c(news_websites, news_fb, news_tt, news_yt, news_x)),
         ncf = mean(c(news_radio, news_newspapers, news_friends))) %>%
  ungroup() %>%
  mutate(trust_news_online_rescaled  = scale(trust_news_online)[, 1],
         trust_news_offline_rescaled = scale(trust_news_offline)[, 1],
         news_online_rescaled        = scale(nco)[, 1],
         news_offline_rescaled       = scale(ncf)[, 1])


# 2. z-score AI traces on follow-up respondents present in d_h_ai -----------
z <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)
fu <- read_csv("data/followup_ai_clean.csv", show_col_types = FALSE) %>%
  filter(participant_id %in% d$participant_id) %>%
  transmute(participant_id,
            ai_freq_z      = z(ai_freq),
            tool_breadth_z = z(tool_breadth),
            ai_timing_z    = z(ai_timing),
            dlit_index_z   = z(dlit_index))
dat <- d %>% inner_join(fu, by = "participant_id")

cat("Full sample trials:", nrow(d),
    " | Follow-up subsample trials:", nrow(dat),
    " | respondents:", n_distinct(d$participant_id), "/", n_distinct(dat$participant_id), "\n")


# 3. Two glmer logit models ------------------------------------------------
pb <- paste("politics + conspiratory_beliefs_reescaled + cyn_beliefs_reescaled +",
            "trust_news_online_rescaled + trust_news_offline_rescaled +",
            "news_online_rescaled + news_offline_rescaled")
re <- "(1|order) + (1|response_id)"

m1 <- glmer(as.formula(paste("correct ~", pb, "+", re)),
            data = d, family = binomial, control = glmer_ctrl)
m2 <- glmer(as.formula(paste("correct ~", pb,
              "+ ai_freq_z + tool_breadth_z + ai_timing_z + dlit_index_z +", re)),
            data = dat, family = binomial, control = glmer_ctrl)


# 4. modelsummary table -----------------------------------------------------
cm <- c(
  "news_online_rescaled"           = "Online news consumption",
  "news_offline_rescaled"          = "Offline news consumption",
  "trust_news_online_rescaled"     = "Trust news online",
  "trust_news_offline_rescaled"    = "Trust news offline",
  "politics"                       = "Interest in politics",
  "conspiratory_beliefs_reescaled" = "Conspiracy beliefs",
  "cyn_beliefs_reescaled"          = "News cynicism",
  "ai_freq_z"                      = "AI use frequency",
  "tool_breadth_z"                 = "AI tools (breadth)",
  "ai_timing_z"                    = "AI adoption (earlier)",
  "dlit_index_z"                   = "Digital literacy",
  "(Intercept)"                    = "(Intercept)")

# Vector-of-short-lines pattern so the note doesn't overflow.
fnote <- c(
  "Binomial GLMER (logit) of correctly identifying the AI post in Human-vs-AI pairs.",
  "Continuous predictors z-scored. Random intercepts for participant and trial order.",
  "Model 1 uses the full main-study sample;",
  "Model 2 adds AI usage and digital literacy on the follow-up subsample.")

cap <- paste("Adding AI usage and digital literacy to the attitudinal model of AI",
             "discernment (Figure 2 Panel B). Logit coefficients with standard errors.")

mlist <- list("(1) Attitudinal (full)"             = m1,
              "(2) + AI usage & literacy (follow-up)" = m2)

out_local <- "output/tab_s18.tex"
modelsummary(mlist, output = out_local, coef_map = cm,
             gof_map = c("nobs"), stars = c('*' = .05, '**' = .01, '***' = .001),
             title = cap, notes = fnote)

