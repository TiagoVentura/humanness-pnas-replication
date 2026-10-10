##############################################################################
# File-Name: 10_si_kde_platforms.R
# author: Tiago Ventura
# Purpose: Kernel densities of normalized PHI scores by model and platform.
#          Produces SI Figure S3.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Set working directory (repo root) ----------------------------------------
setwd(here::here())
getwd()

# Packages + theme ---------------------------------------------------------
source("code/00_utils.R")


# Load BT-score CSVs (platform encoded in filename) ------------------------
files <- str_subset(list.files("data/bt_scores"), "^bt_")

bt <- map_df(files, ~
               read_csv(paste0("./data/bt_scores/", .x)) %>%
               mutate(platform = .x))


# Normalize platform + model labels (mirrors 00_analysis_bt.R) -------------
bt <- bt %>%
  mutate(platform = case_when(
           platform == "bt_ts_posts_rankings_with_source_persona_inverted.csv" ~ "Truth Social",
           platform == "bt_tt_posts_rankings_with_source_persona_inverted.csv" ~ "TikTok",
           platform == "bt_x_posts_rankings_with_source_persona_inverted.csv"  ~ "X/Twitter",
           platform == "bt_yt_posts_rankings_with_source_persona_inverted.csv" ~ "YouTube"
         ),
         model = case_when(
           model == "gpt_4omini"   ~ "gpt_4o_mini",
           model == "llama3_3"     ~ "llama_3.3",
           model == "llama_3_3"    ~ "llama_3.3",
           model == "gpt_4o_fall"  ~ "gpt_4o",
           model == "gpt4o-mini"   ~ "gpt_4o_mini",
           TRUE                    ~ model
         )) %>%
  clean_names()


# Display labels (match manuscript: 2_results_v2.tex) ----------------------
bt <- bt %>%
  mutate(model_label = recode(model,
           "human"        = "Human",
           "gpt_4"        = "GPT-4",
           "gpt_4o"       = "GPT-4o",
           "gpt_4o_mini"  = "GPT-4o mini",
           "llama2_70b"   = "Llama 2",
           "llama3_2_3b"  = "Llama 3.2",
           "llama_3.3"    = "Llama 3.3"
         ),
         model_label = factor(model_label, levels = c(
           "GPT-4", "GPT-4o", "GPT-4o mini",
           "Llama 2", "Llama 3.2", "Llama 3.3", "Human"
         )),
         platform = factor(platform, levels = c(
           "X/Twitter", "YouTube", "Truth Social", "TikTok"
         )))

# Sanity check
bt %>% count(platform, model_label) %>% print(n = 50)


# Color palette ------------------------------------------------------------
# Family base colors match Fig. 1 of the main paper (00_analysis_bt.R):
#   Human  -> steelblue, GPT -> tomato, Llama -> grey.
# Within each family, shade gradient runs light -> dark in chronological
# order (older model = lighter, newer model = darker) to differentiate
# variants while preserving the family signal.

family_pal <- c(
  # Human (single model)
  "Human"       = "#1F4E8C",  # deep saturated blue

  # GPT family (light -> dark = older -> newer)
  "GPT-4"       = "#F5B7B1",  # light tomato
  "GPT-4o"      = "#E74C3C",  # tomato (mid)
  "GPT-4o mini" = "#7B241C",  # dark tomato

  # Llama family (light -> dark = older -> newer)
  "Llama 2"     = "#BDBDBD",  # light grey
  "Llama 3.2"   = "#737373",  # mid grey
  "Llama 3.3"   = "#252525"   # dark grey
)


# Common plot scaffold -----------------------------------------------------

base_plot <- bt %>%
  filter(!is.na(model_label), !is.na(platform)) %>%
  ggplot(aes(x = normalized_ability,
             fill = model_label,
             color = model_label)) +
  facet_wrap(~ platform, nrow = 2) +
  scale_fill_manual(values = family_pal) +
  scale_color_manual(values = family_pal) +
  labs(x = "Normalized PHI", 
       y = "Density",
       fill = "Model", color = "Model")


# OPTION A — Tight axis, unmodified Gaussian KDE (viewport clip) ----------
#
# Kernel density estimates of normalized PHI scores across four social media
# platforms. Each curve is a Gaussian kernel density estimate (Scott's rule,
# bandwidth multiplier = 1.2) independently normalized (area = 1) and
# comparable across panels. The horizontal axis is clipped to the data
# support, $[-1, 1]$; kernel tails extending past these bounds are computed
# but not displayed.
p_kde_A <- base_plot +
  geom_density(alpha = 0.35, linewidth = .6, adjust = 1.2) +
  coord_cartesian(xlim = c(-1, 1)) +
  scale_x_continuous(breaks = seq(-1, 1, 0.5)) +
  theme(axis.text.x = element_text(size = 10),
        axis.text.y = element_text(size = 12),
        axis.title  = element_text(size = 16), 
        strip.text = element_text(size = 12, face="bold"))

p_kde_A
save_function("fig_si_kde_platforms_A_clip.png", width = 12, height = 8)
save_function("fig_si_kde_platforms_A_clip.pdf", width = 12, height = 8)

