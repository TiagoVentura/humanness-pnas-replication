##############################################################################
# File-Name: 06_analysis_bt.R
# author: Tiago Ventura
# Purpose: Marginal means and regressions of PHI scores on post source.
#          Produces Figure 1 and SI Tables S3, S12, S13, S23 and S24.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Set working directory ---------
setwd(here::here())
getwd()


# Call packages -----------------------------------------------------------
pacman::p_load("lme4", "marginaleffects", "sandwich", "lmtest", "clubSandwich", "kableExtra")
source("code/00_utils.R")


# BT Scores Analysis ------------------------------------------------------

## Open data -------------
files <- str_subset(list.files("data/bt_scores"),"^bt_")

## read files
bt <- map_df(files, ~ 
            read_csv(paste0("./data/bt_scores/",.x)) %>% 
            mutate(platform=.x))

table(bt$model)

## identify platform
bt <- bt %>% 
      mutate(platform=case_when(platform=="bt_ts_posts_rankings_with_source_persona_inverted.csv" ~ "Truth Social", 
                                platform=="bt_tt_posts_rankings_with_source_persona_inverted.csv" ~ "TikTok", 
                                platform=="bt_x_posts_rankings_with_source_persona_inverted.csv" ~ "Twitter/X", 
                                platform=="bt_yt_posts_rankings_with_source_persona_inverted.csv" ~ "YouTube", 
      ), 
      model=case_when(model=="gpt_4omini" ~ "gpt_4o_mini", 
                      model=="llama3_3" ~ "llama_3.3",
                      model=="llama_3_3" ~ "llama_3.3",
                      model=="gpt_4o_fall" ~ "gpt_4o", 
                      model=="gpt4o-mini" ~ "gpt_4o_mini",

                      TRUE ~ model
      )) %>% 
  clean_names()

## 
table(bt$platform)
table(bt$model)

# stats on table s3
bt %>% count(platform, model) %>% 
  pivot_wider(names_from = platform, values_from = n) %>% 
  kable(format = "latex", booktabs = TRUE, 
        caption = "Final counts of posts by platform and model") %>% 
  save_table("tab_s3.tex")


# stats on table s23
bt %>% group_by(platform, model) %>% 
  summarise(count = n(), mean = mean(normalized_ability), std = sd(normalized_ability), 
            min = min(normalized_ability), max = max(normalized_ability), 
            median = median(normalized_ability), .groups = "drop") %>% 
  kable(format = "latex", booktabs = TRUE, digits = 2, 
        caption = "PHI scores by platform and model") %>% 
  save_table("tab_s23.tex")

# Models ------------------------------------------------------------------

## model
m_human <- lm(normalized_ability ~ model, data=bt)

# marginal means
res_predictions = avg_predictions(m_human,
                                  by = c("model")) %>%
  as_tibble() %>%
  conf_int(estimate, std.error) %>%
  mutate(model = recode(model,
                        "human"       = "Human",
                        "gpt_4"       = "GPT-4",
                        "gpt_4o"      = "GPT-4o",
                        "gpt_4o_mini" = "GPT-4o Mini",
                        "llama2_70b"  = "Llama 2",
                        "llama3_2_3b" = "Llama 3.2",
                        "llama_3.3"   = "Llama 3.3"),
         model = factor(model, levels = rev(c(
           "Human", "GPT-4", "GPT-4o", "GPT-4o Mini",
           "Llama 2", "Llama 3.2", "Llama 3.3"))),
         color = case_when(model == "Human"          ~ "Human",
                           str_detect(model, "GPT")  ~ "GPT",
                           str_detect(model, "Llama") ~ "Llama"),
         color = fct_rev(fct_relevel(color, c("Human", "GPT", "Llama"))))

# produce table s24
res_predictions %>% select(model, estimate, std.error, lb95, up95) %>% 
  kable(format = "latex", booktabs = TRUE, digits = 3, 
        caption = "Marginal means of PHI scores by post source, pooled") %>% 
  save_table("tab_s24_pooled.tex")

# plot combine
pol = ggplot(res_predictions,
       aes(y=model, 
           x=estimate, fill=color)) +
  geom_errorbar(aes(xmin=lb95, xmax = up95),
                size=1, width=0,  
                position=position_dodge(width = .3)) +
  geom_point(size=4, shape=21,
             position=position_dodge(width = .3)) +
  ylab("Post Source \n ") +
  xlab("Marginal Means of PHI Scores (Higher Values = More Human)") +
  labs(title="A) Pooled Estimates",
       subtitle= "",
       caption="") +
  guides(alpha="none",
         color = guide_legend(reverse = TRUE),
         fill= guide_legend(reverse = TRUE)) +
  scale_fill_manual(values=c("steelblue", "gray90", "tomato2"), name="Model Family") +
  theme(plot.subtitle = element_markdown(size=16, face="bold"), 
        strip.text = element_text(family = my_font, 
                                  color = "#22211d",
                                  size = 16, 
                                  hjust=0, face = "bold"), 
        strip.background = element_blank(), 
        plot.margin = margin(0, 0, 0, 0, "cm"), 
        axis.text.x = element_text(size=10, family=my_font, hjust=0), 
        axis.text.y = element_text(size=12, family=my_font, hjust=0)) +
  theme(legend.position = 'none')


# by platform

## model
m_plat <- lm(normalized_ability ~ model*platform, data=bt)

# marginal means
res_predictions = avg_predictions(m_plat,
                                  by = c("model", "platform")) %>%
  as_tibble() %>%
  conf_int(estimate, std.error) %>%
  mutate(model = recode(model,
                        "human"       = "Human",
                        "gpt_4"       = "GPT-4",
                        "gpt_4o"      = "GPT-4o",
                        "gpt_4o_mini" = "GPT-4o Mini",
                        "llama2_70b"  = "Llama 2",
                        "llama3_2_3b" = "Llama 3.2",
                        "llama_3.3"   = "Llama 3.3"),
         model = factor(model, levels = rev(c(
           "Human", "GPT-4", "GPT-4o", "GPT-4o Mini",
           "Llama 2", "Llama 3.2", "Llama 3.3"))),
         platform = recode(platform, "Twitter/X" = "X/Twitter"),
         platform = factor(platform, levels = c(
           "X/Twitter", "YouTube", "TikTok", "Truth Social")),
         color = case_when(model == "Human"          ~ "Human",
                           str_detect(model, "GPT")  ~ "GPT",
                           str_detect(model, "Llama") ~ "Llama"),
         color = fct_rev(fct_relevel(color, c("Human", "GPT", "Llama"))))

# produce table s24 by platform
res_predictions %>% select(platform, model, estimate, std.error, lb95, up95) %>% 
  kable(format = "latex", booktabs = TRUE, digits = 3, 
        caption = "Marginal means of PHI scores by post source and platform") %>% 
  save_table("tab_s24_platform.tex")

# plot combine
platform = ggplot(res_predictions,
       aes(y=model, 
           x=estimate, fill=color)) +
  geom_errorbar(aes(xmin=lb95, xmax = up95),
                size=1, width=0,  
                position=position_dodge(width = .3)) +
  geom_point(size=4, shape=21,
             position=position_dodge(width = .3)) +
  ylab("\nPost Source \n") +
  xlab("Marginal Means of PHI Scores (Higher Values = More Human)") +
  labs(title="B) Platform Estimates",
       subtitle= "",
       caption="") +
  guides(alpha="none",
         color = guide_legend(reverse = TRUE),
         fill= guide_legend(reverse = TRUE)) +
  scale_fill_manual(values=c("steelblue", "gray90", "tomato2"), name="Model Family") +
  theme(plot.subtitle = element_markdown(size=16, face="bold"), 
        strip.text = element_text(family = my_font, 
                                  color = "#22211d",
                                  size = 16, 
                                  hjust=.5, face = "bold"), 
        strip.background = element_blank(), 
        plot.margin = margin(0, 0, 0, 0, "cm"), 
        axis.text.x = element_text(size=10, family=my_font, hjust=0), 
        axis.text.y = element_text(size=12, family=my_font, hjust=0)) +
  theme(legend.position = 'right') +
  facet_wrap(~platform, nrow=2)

platform



# Figure 1
library(patchwork)
pol + platform +
  plot_layout(ncol = 2, widths = c(0.75, 1)) &
  theme(axis.title.x = element_text(size = 12, hjust = 0.5),
        axis.title.y = element_text(size = 12))

save_function("fig1.pdf", 14, 12)
save_function("fig1.png", 14, 12)


# Pairwise comparisons against Human (regression table) -------------------
pacman::p_load("modelsummary", "kableExtra")
options(modelsummary_factory_latex = "kableExtra",
        modelsummary_format_numeric_latex = "plain")

bt_tab <- bt %>%
  mutate(model = recode(model,
                        "human"       = "Human",
                        "gpt_4"       = "GPT-4",
                        "gpt_4o"      = "GPT-4o",
                        "gpt_4o_mini" = "GPT-4o Mini",
                        "llama2_70b"  = "Llama 2",
                        "llama3_2_3b" = "Llama 3.2",
                        "llama_3.3"   = "Llama 3.3"),
         model = factor(model, levels = c(
           "Human", "GPT-4", "GPT-4o", "GPT-4o Mini",
           "Llama 2", "Llama 3.2", "Llama 3.3")))

m_pool <- lm(normalized_ability ~ model, data = bt_tab)
m_x    <- lm(normalized_ability ~ model, data = filter(bt_tab, platform == "Twitter/X"))
m_yt   <- lm(normalized_ability ~ model, data = filter(bt_tab, platform == "YouTube"))
m_tt   <- lm(normalized_ability ~ model, data = filter(bt_tab, platform == "TikTok"))
m_ts   <- lm(normalized_ability ~ model, data = filter(bt_tab, platform == "Truth Social"))

models_list <- list(
  "Pooled"       = m_pool,
  "Twitter/X"    = m_x,
  "YouTube"      = m_yt,
  "TikTok"       = m_tt,
  "Truth Social" = m_ts
)

coef_map <- c(
  "modelGPT-4"        = "GPT-4",
  "modelGPT-4o"       = "GPT-4o",
  "modelGPT-4o Mini"  = "GPT-4o Mini",
  "modelLlama 2"      = "Llama 2",
  "modelLlama 3.2"    = "Llama 3.2",
  "modelLlama 3.3"    = "Llama 3.3",
  "(Intercept)"       = "Human (baseline)"
)

tab_title <- "Pairwise Differences in PHI Scores Against Human Posts"

# Pass `notes` as a character vector so each element renders on its own row
# (modelsummary won't wrap a single long string).
tab_note <- c(
  "Each column reports OLS estimates from a separate regression of PHI scores on post source,",
  "with human posts as the reference category. Coefficients represent the average difference in",
  "perceived humanness between posts from a given model and human posts. Column 1 pools all",
  "platforms; columns 2--5 estimate the model separately for each platform.",
  "Standard errors in parentheses.")

# Save LaTeX table to output/ -----------------------
output_loc <- file.path(getwd(), "output")

options(knitr.table.format = "latex")



modelsummary(models_list,
             output = file.path(output_loc, 
                             "tab_s12.tex"),
             coef_map = coef_map,
             gof_omit = "AIC|BIC|Log.Lik|RMSE|F",
             stars    = c('*' = .05, '**' = .01, '***' = .001),
             title    = tab_title,
             notes    = tab_note,
             escape   = FALSE)



# Pooled Regression Models ------------------------------------------------
bt_tab2 <- bt %>%
  mutate(model = recode(model,
                        "human"       = "Human",
                        "gpt_4"       = "AI-Generated",
                        "gpt_4o"      = "AI-Generated",
                        "gpt_4o_mini" = "AI-Generated",
                        "llama2_70b"  = "AI-Generated",
                        "llama3_2_3b" = "AI-Generated",
                        "llama_3.3"   = "AI-Generated"),
         model = factor(model, levels = c(
           "Human", "AI-Generated")))

m_pool <- lm(normalized_ability ~ model, data = bt_tab2)
m_x    <- lm(normalized_ability ~ model, data = filter(bt_tab2, platform == "Twitter/X"))
m_yt   <- lm(normalized_ability ~ model, data = filter(bt_tab2, platform == "YouTube"))
m_tt   <- lm(normalized_ability ~ model, data = filter(bt_tab2, platform == "TikTok"))
m_ts   <- lm(normalized_ability ~ model, data = filter(bt_tab2, platform == "Truth Social"))

models_list <- list(
  "Pooled"       = m_pool,
  "Twitter/X"    = m_x,
  "YouTube"      = m_yt,
  "TikTok"       = m_tt,
  "Truth Social" = m_ts
)

coef_map <- c(
  "(Intercept)" = "Human (Intercept)",
  "modelAI-Generated"        = "AI-Generated"
  
)

tab_title <- "Regression Models: PHI Scores Differences Between Pooled AI-Generated Posts vs Human Posts"

# Pass `notes` as a character vector so each element renders on its own row
# (modelsummary won't wrap a single long string).
tab_note <- c(
  "Each column reports OLS estimates from a separate regression of PHI scores between pooled AI-Generated post",
  "versus human posts as the reference category. Coefficients represent the average difference in",
  "perceived humanness between AI-Generated posts and human posts. Column 1 pools all",
  "platforms; columns 2-5 estimate the model separately for each platform.",
  "Standard errors in parentheses.")

# Save LaTeX table to output/ -----------------------
output_loc <- file.path(getwd(), "output")

options(knitr.table.format = "latex")

modelsummary(models_list,
             output = file.path(output_loc, 
                             "tab_s13.tex"),
             coef_map = coef_map,
             gof_omit = "AIC|BIC|Log.Lik|RMSE|F",
             stars    = c('*' = .05, '**' = .01, '***' = .001),
             title    = tab_title,
             notes    = tab_note,
             escape   = FALSE)


