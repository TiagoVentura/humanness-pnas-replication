##############################################################################
# File-Name: 15_combined_mediators_by_demographics.R
# author: Tiago Ventura
# Purpose: Demographic differences in discernment and in the candidate
#          mechanisms measured in the follow-up survey. Produces SI Table
#          S17.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
setwd(here::here())
pacman::p_load(tidyverse, lme4, marginaleffects, broom, modelsummary, kableExtra)
options(modelsummary_factory_latex = "kableExtra",
        modelsummary_format_numeric_latex = "plain")

relev <- function(df) df %>% mutate(
  white               = fct_relevel(white, "Non-White"),
  sex                 = fct_relevel(sex, "Female"),
  age_group           = fct_relevel(age_group, "<25","25-44","45-64","65+"),
  education_cat       = fct_relevel(education_cat, "No College Degree"),
  party_id_imputation = fct_relevel(party_id_imputation, "Democrat"),
  hispanic            = as.integer(hispanic))

covars <- "age_group + sex + education_cat + party_id_imputation + white + hispanic"


# --- DISCERNMENT: trial-level glmer logit exactly as 02b Model A -----------
ps <- read_csv("data/pairs_survey_clean.csv", show_col_types = FALSE)

dha <- ps %>%
  filter(att_check_sum == 0) %>%
  mutate(source_num = ifelse(source == "Human", 1, 0)) %>%
  group_by(response_id, order, platform) %>%
  mutate(sum_source = sum(source_num)) %>% ungroup() %>%
  filter(sum_source == 1, binary_response == 1) %>%
  mutate(correct = case_when(source == "Human" ~ 0, TRUE ~ 1)) %>%
  relev()

mod_disc <- glmer(as.formula(paste("correct ~", covars,
                                   "+ (1|order) + (1|response_id)")),
                  data = dha, family = binomial)


# --- FULL-sample respondent frame: Model-B covariates + news (02b defs) ----
full_d <- ps %>%
  distinct(participant_id, .keep_all = TRUE) %>%
  rowwise() %>%
  mutate(trust_news_online       = mean(c(news_trust_social_media,
                                          news_trust_news_websites)),
         trust_news_offline      = mean(c(news_trust_newspapers,
                                          news_trust_radio, news_trust_local)),
         news_consumption_online = mean(c(news_websites, news_fb,
                                          news_tt, news_yt, news_x)),
         news_consumption_off    = mean(c(news_radio, news_newspapers,
                                          news_friends))) %>%
  ungroup() %>%
  mutate(trust_news_online_rescaled  = scale(trust_news_online)[,1],
         trust_news_offline_rescaled = scale(trust_news_offline)[,1],
         news_online_rescaled        = scale(news_consumption_online)[,1],
         news_offline_rescaled       = scale(news_consumption_off)[,1]) %>%
  relev()


# --- AI usage + digital literacy: follow-up respondents --------------------
fu_d <- read_csv("data/followup_ai_clean.csv", show_col_types = FALSE) %>%
  filter(!is.na(sex)) %>% relev()


# --- Marginal effects for every column; relabel for clean modelsummary rows
ord <- c("White (vs Non-White)","Hispanic","Male (vs Female)",
  "Age 25-44 (vs <25)","Age 45-64 (vs <25)","Age 65+ (vs <25)",
  "College (vs No College)","Post-Grad (vs No College)","Republican (vs Democrat)")

clean_me <- function(m) {
  s <- avg_slopes(m)
  s$contrast <- dplyr::recode(s$contrast,
    "White - Non-White"                        = "White (vs Non-White)",
    "1 - 0"                                     = "Hispanic",
    "dY/dx"                                     = "Hispanic",
    "Male - Female"                             = "Male (vs Female)",
    "25-44 - <25"                               = "Age 25-44 (vs <25)",
    "45-64 - <25"                               = "Age 45-64 (vs <25)",
    "65+ - <25"                                 = "Age 65+ (vs <25)",
    "College Degree - No College Degree"        = "College (vs No College)",
    "Post-Graduate Degree - No College Degree"  = "Post-Grad (vs No College)",
    "Republican - Democrat"                     = "Republican (vs Democrat)")
  s$term <- ""
  s[order(match(s$contrast, ord)), ]   # row order = display order in modelsummary
}
lmf <- function(ov, dat) lm(as.formula(paste(ov, "~", covars)), data = dat)

models <- list(
  "Discernment"      = clean_me(mod_disc),
  "Politics"         = clean_me(lmf("politics", full_d)),
  "Conspiracy"       = clean_me(lmf("conspiratory_beliefs_reescaled", full_d)),
  "Cynicism"         = clean_me(lmf("cyn_beliefs_reescaled", full_d)),
  "Trust online"     = clean_me(lmf("trust_news_online_rescaled", full_d)),
  "Trust offline"    = clean_me(lmf("trust_news_offline_rescaled", full_d)),
  "News online"      = clean_me(lmf("news_online_rescaled", full_d)),
  "News offline"     = clean_me(lmf("news_offline_rescaled", full_d)),
  "AI freq"          = clean_me(lmf("ai_freq", fu_d)),
  "AI tools"         = clean_me(lmf("tool_breadth", fu_d)),
  "Adoption timing"  = clean_me(lmf("ai_timing", fu_d)),
  "Digital literacy" = clean_me(lmf("dlit_index", fu_d)))

# tidy CSV of every estimate
results <- imap_dfr(models, ~ tidy(.x) %>%
  transmute(outcome = .y, term = contrast,
            estimate = as.numeric(estimate), std.error = as.numeric(std.error),
            p.value = as.numeric(p.value)))
write_csv(results, "output/tab_s17.csv")

# write table
note <- c(
  "Cells are marginal effects on each outcome.",
  "Discernment = AME on P(correctly identifying AI) from a binomial GLMER (logit),",
  "trial-level, exactly as 02b_logit.R; N is trials.",
  "Politics / conspiracy / cynicism / trust / news are full-sample respondent-level OLS;",
  "AI usage and digital literacy are follow-up respondents.",
  "Reference: Non-White / Female / under 25 / No College / Democrat.",
  "Outcome scales differ (discernment 0-1; news & trust z-scored;",
  "AI freq 1-7; timing 1-5; tools 0-8; digital literacy 1-5) - compare within columns.")

print(modelsummary(models, shape = contrast ~ model,
                   gof_map = list(list("raw"="nobs","clean"="N","fmt"=0)),
                   stars = c('*'=.05,'**'=.01,'***'=.001), output = "markdown"))

cap <- paste("Demographic differences in discernment and its candidate",
             "mediators (marginal effects; ref = White / Female / <25 /",
             "No College / Democrat).")
out_local <- "output/tab_s17.tex"
modelsummary(models, shape = contrast ~ model,
             gof_map = list(list("raw"="nobs","clean"="N","fmt"=0)),
             stars = c('*'=.05,'**'=.01,'***'=.001), escape = FALSE,
             title = cap, notes = note, output = out_local)

