##############################################################################
# File-Name: 09_logit.R
# author: Tiago Ventura
# Purpose: Logit models of correct AI identification on respondent
#          characteristics, and the persona-by-party model. Produces Figures
#          3 and 4.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Set working directory ------------------------------------------------------
setwd(here::here())
getwd()

# Packages -------------------------------------------------------------------
pacman::p_load(tidyverse, scales, lubridate, here, janitor,
               rebus, RColorBrewer, wesanderson, qualtRics, tidylog,
               estimatr, patchwork, lme4, marginaleffects, kableExtra, broom)

source("code/00_utils.R")

# glmer control used by the persona x party logit (Figure 4)
glm_ctrl <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))

# Data + preprocessing ------------------------------------------------------
d <- read_csv("data/pairs_survey_clean.csv")
d <- d %>% filter(att_check_sum == 0)

d <- d %>%
  mutate(source_num = ifelse(source == "Human", 1, 0)) %>%
  group_by(response_id, order, platform) %>%
  mutate(sum_source = sum(source_num)) %>%
  ungroup()

d_h_ai <- d %>%
  filter(sum_source == 1) %>%
  select(sum_source, everything()) %>%
  arrange(response_id, order, platform) %>%
  filter(binary_response == 1) %>%
  mutate(correct = case_when(source == "Human" ~ 0, TRUE ~ 1))

d_h_ai$education_cat <- fct_relevel(d_h_ai$education_cat, "No College Degree")

# News online/offline composites --------------------------------------------
d_h_ai <- d_h_ai %>%
  rowwise() %>%
  mutate(trust_news_online  = mean(c(news_trust_social_media,
                                     news_trust_news_websites)),
         trust_news_offline = mean(c(news_trust_newspapers,
                                     news_trust_radio,
                                     news_trust_local)),
         news_consumption_online = mean(c(news_websites, news_fb,
                                          news_tt, news_yt, news_x)),
         news_consumption_off    = mean(c(news_radio, news_newspapers,
                                          news_friends))) %>%
  ungroup() %>%
  mutate(trust_news_online_rescaled  = scale(trust_news_online)[, 1],
         trust_news_offline_rescaled = scale(trust_news_offline)[, 1],
         news_online_rescaled        = scale(news_consumption_online)[, 1],
         news_offline_rescaled       = scale(news_consumption_off)[, 1])

# AI-vs-AI subset for fig4 --------------------------------------------------
d_ai_ai <- d %>%
  filter(sum_source == 0) %>%
  arrange(response_id, order, platform) %>%
  mutate(persona = str_to_lower(persona))

# =============================================================================
# A) Demographics — logit ------------------------------------------------------
# =============================================================================
mod_demo_logit <- glmer(
  correct ~ age_group + sex + education_cat +
            party_id_imputation + white + hispanic +
            (1 | order) + (1 | response_id),
  data    = d_h_ai,
  family  = binomial
)


res_demo_logit <- avg_slopes(mod_demo_logit) %>%
  tidy() %>%
  mutate_at(vars(estimate, std.error, conf.low, conf.high), as.numeric) %>%
  conf_int(estimate, std.error) %>%
  mutate(yaxis = case_when(
           term == "party_id_imputation" ~ contrast,
           term == "sex" ~ contrast,
           term == "white" ~ contrast,
           term == "age_group"     ~ paste0("Age: ", contrast),
           term == "education_cat" ~ contrast,
           TRUE ~ str_to_title(term)),
         yaxis = str_remove_all(yaxis, "Degree"),
         yaxis = fct_rev(fct_inorder(yaxis)))

# =============================================================================
# B) News online/offline (Attitudinal panel) — logit --------------------------
# =============================================================================
mod_news_on_off_logit <- glmer(
  correct ~ politics +
            conspiratory_beliefs_reescaled +
            cyn_beliefs_reescaled +
            trust_news_online_rescaled +
            trust_news_offline_rescaled +
            news_online_rescaled +
            news_offline_rescaled +
            (1 | order) + (1 | response_id),
  data    = d_h_ai,
  family  = binomial
)

res_news_on_off_logit <- avg_slopes(mod_news_on_off_logit) %>%
  tidy() %>%
  mutate_at(vars(estimate, std.error, conf.low, conf.high), as.numeric) %>%
  conf_int(estimate, std.error) %>%
  mutate(yaxis = c("Conspiracy Beliefs", "News Cynicism",
                   "Offline News Consumption", "Online News Consumption",
                   "Interest in Politics", "Trust News Offline",
                   "Trust News Online"))

# =============================================================================
# C) News x platform (Platform-Specific News panel) — logit -------------------
# =============================================================================
mod_news_platform_logit <- glmer(
  correct ~ news_fb * platform +
            news_tt * platform +
            news_x  * platform +
            news_yt * platform +
            (1 | order) + (1 | response_id),
  data    = d_h_ai,
  family  = binomial)

extract_news_var <- function(mod, var, facet_label) {
  avg_slopes(mod, variables = var, by = "platform") %>%
    tidy() %>%
    mutate_at(vars(estimate, std.error, conf.low, conf.high), as.numeric) %>%
    conf_int(estimate, std.error) %>%
    mutate(facet = facet_label)
}

res_news_tt_logit <- extract_news_var(mod_news_platform_logit, "news_tt",
                                      "Consume News on TikTok")
res_news_x_logit  <- extract_news_var(mod_news_platform_logit, "news_x",
                                      "Consume News on X/Twitter")
res_news_yt_logit <- extract_news_var(mod_news_platform_logit, "news_yt",
                                      "Consume News on YouTube")
res_news_logit <- bind_rows(res_news_tt_logit, res_news_x_logit, res_news_yt_logit)

# =============================================================================
# Combined ABC figure (logit version) — matches 02 lines 443-528 -------------
# =============================================================================

panel_A <- ggplot(res_demo_logit,
                  aes(y = yaxis, x = estimate)) +
  geom_errorbar(aes(xmin = lb95, xmax = up95),
                size = 1, width = 0,
                position = position_dodge(width = .3)) +
  geom_point(size = 4, shape = 21, fill = "white",
             position = position_dodge(width = .3)) +
  geom_vline(aes(xintercept = 0), linetype = "dashed", color = "gray50") +
  ylab("") + xlab("") +
  labs(title = "A) Demographics") +
  theme(axis.text.x  = element_text(size = 10, family = my_font, hjust = .5),
        axis.text.y  = element_text(size = 12),
        plot.margin  = margin(0, 0, 0, 0, "cm"),
        plot.title   = element_markdown(size = 16, face = "bold",
                                        family = my_font))

panel_B <- ggplot(res_news_on_off_logit,
                  aes(y = yaxis, x = estimate)) +
  geom_errorbar(aes(xmin = lb95, xmax = up95),
                size = 1, width = 0,
                position = position_dodge(width = .3)) +
  geom_point(size = 4, shape = 21, fill = "white",
             position = position_dodge(width = .3)) +
  geom_vline(aes(xintercept = 0), linetype = "dashed", color = "gray50") +
  ylab("") + xlab("") +
  labs(title = "B) Attitudinal") +
  theme(axis.text.x  = element_text(size = 10, family = my_font, hjust = 0),
        axis.text.y  = element_text(size = 12),
        plot.margin  = margin(0, 0, 0, 0, "cm"),
        plot.title   = element_markdown(size = 16, face = "bold",
                                        family = my_font))

panel_C <- ggplot(res_news_logit,
                  aes(y = platform, x = estimate)) +
  geom_errorbar(aes(xmin = lb95, xmax = up95),
                size = 1, width = 0,
                position = position_dodge(width = .3)) +
  geom_point(size = 4, shape = 21, fill = "white",
             position = position_dodge(width = .3)) +
  geom_vline(aes(xintercept = 0), linetype = "dashed", color = "gray50") +
  xlab("") + ylab("") +
  coord_flip() +
  labs(title = "C) Platform-Specific News Habits") +
  theme(axis.text.x      = element_text(size = 10, family = my_font, hjust = .5),
        axis.text.y      = element_text(size = 10),
        plot.margin      = margin(0, 0, 0, 0, "cm"),
        strip.background = element_rect(fill = "gray85", color = "black"),
        strip.text       = element_text(size = 12, family = my_font,
                                        face = "bold", color = "#22211d"),
        plot.title       = element_markdown(size = 16, face = "bold",
                                            family = my_font)) +
  facet_wrap(~ facet, nrow = 1)

(panel_A + panel_B) / panel_C +
  plot_annotation(caption = "Note: Marginal Effects on Probability of Identifying AI-Generated Posts") &
  theme(axis.title.x = element_text(size = 12, hjust = 0.5),
        axis.title.y = element_text(size = 12),
        plot.caption = element_text(size = 14, hjust = 0.5,
                                    face   = "bold",
                                    family = my_font,
                                    margin = margin(t = 8)))

save_function("fig3.pdf", 14, 12)
save_function("fig3.png", 14, 12)

# =============================================================================
# D) Persona x Party — logit (Figure 4) -----------------------------
# =============================================================================
mod_persona_logit <- glmer(
  binary_response ~ persona * party_id_imputation +
                    (1 | order) + (1 | response_id),
  data    = d_ai_ai %>% filter(!is.na(party_id_imputation),
                                !is.na(persona),
                                !is.na(binary_response),
                                party_id_imputation %in% c("Democrat", "Republican")),
  family  = binomial,
  control = glm_ctrl
)

res_fig4_logit <- avg_predictions(
  mod_persona_logit,
  by = c("party_id_imputation", "persona")
) %>%
  as_tibble() %>%
  mutate(across(c(estimate, std.error), as.numeric))

persona_map_fig4 <- c(
  "conservativecommentator"        = "Conservative",
  "liberalcommentator"             = "Liberal",
  "libertarianpopulistcommentator" = "Libertarian Populist",
  "moderatecommentator"            = "Moderate",
  "progressivecommentator"         = "Progressive"
)
persona_order_fig4 <- c("Progressive", "Liberal", "Moderate",
                        "Conservative", "Libertarian Populist")

cell_fig4_logit <- res_fig4_logit %>%
  rename(party  = party_id_imputation,
         mean_p = estimate,
         se_p   = std.error) %>%
  mutate(persona_clean = persona_map_fig4[persona],
         persona_clean = factor(persona_clean, levels = persona_order_fig4),
         mean_flipped  = 1 - mean_p,
         pct_diff      = (mean_flipped - 0.5) * 100,
         ci_pct        = 1.96 * se_p * 100,
         lb95          = pct_diff - ci_pct,
         up95          = pct_diff + ci_pct)

n_dem_fig4 <- d_ai_ai %>% filter(party_id_imputation == "Democrat")   %>% pull(response_id) %>% n_distinct()
n_rep_fig4 <- d_ai_ai %>% filter(party_id_imputation == "Republican") %>% pull(response_id) %>% n_distinct()

DEM_COLOR_FIG4 <- "#2b83ba"
REP_COLOR_FIG4 <- "#c0392b"

make_persona_panel_logit <- function(d_panel, color, title_txt, show_y_title) {
  ggplot(d_panel, aes(x = persona_clean, y = pct_diff)) +
    geom_col(width = 0.55, fill = color, color = NA) +
    geom_errorbar(aes(ymin = lb95, ymax = up95),
                  width = 0.15, color = "gray55", linewidth = 0.7) +
    geom_text(aes(
        label = paste0(abs(round(pct_diff)), "%"),
        y     = ifelse(pct_diff >= 0, up95 + 0.9, lb95 - 0.9),
        vjust = ifelse(pct_diff >= 0, 0, 1)),
      color = color, fontface = "bold", size = 4.2,
      family = my_font) +
    geom_hline(yintercept = 0, linetype = "dashed",
               color = "black", linewidth = 0.4) +
    annotate("text", x = 0.55, y = 19, label = "More Human-like",
             hjust = 0, color = "gray50", size = 4, family = my_font) +
    annotate("text", x = 0.55, y = -19, label = "More AI-like",
             hjust = 0, color = "gray50", size = 4, family = my_font) +
    scale_y_continuous(
      breaks = seq(-20, 20, 10),
      labels = function(x) paste0("+", abs(x), "%"),
      limits = c(-20, 20),
      expand = c(0, 0)
    ) +
    scale_x_discrete(
      labels = c("Progressive", "Liberal", "Moderate",
                 "Conservative", "Libertarian\nPopulist")
    ) +
    labs(title = title_txt,
         x = "Persona",
         y = if (show_y_title) "% deviation from random" else NULL) +
    theme(
      plot.title         = element_markdown(face = "bold", size = 16,
                                            hjust = 0.5, family = my_font),
      axis.title.x       = element_text(face = "bold", size = 12,
                                        family = my_font, hjust = 0.5),
      axis.title.y       = element_text(face = "bold", size = 12,
                                        family = my_font),
      axis.text.x        = element_text(size = 11, family = my_font),
      axis.text.y        = element_text(size = 11, family = my_font),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_blank(),
      plot.margin        = margin(8, 8, 8, 8)
    )
}

p_dem_logit <- make_persona_panel_logit(
  cell_fig4_logit %>% filter(party == "Democrat"),
  DEM_COLOR_FIG4,
  paste0("Democrat (n=", n_dem_fig4, ")"),
  show_y_title = TRUE
)
p_rep_logit <- make_persona_panel_logit(
  cell_fig4_logit %>% filter(party == "Republican"),
  REP_COLOR_FIG4,
  paste0("Republican (n=", n_rep_fig4, ")"),
  show_y_title = FALSE
)

p_dem_logit + p_rep_logit + plot_layout(ncol = 2, widths = c(1, 1))

save_function("fig4.pdf", 14, 5)
save_function("fig4.png", 14, 5)
