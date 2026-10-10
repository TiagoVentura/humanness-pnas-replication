# 12_gpt_direct_classifier_figure.R
#
# Builds the Human-vs-AI proportion figure from the PAIRWISE GPT detector
# output produced by 11_gpt_ai_detector.R (file pattern:
# `gpt_detector_sample_*.csv`, one row per API call). Each call evaluates
# a pair (post_left, post_right), one of which is AI and one Human, and the
# model picks "Post A" or "Post B".
#
# We pivot the pairwise output to one row per *post* per call:
#   binary_response = 1 if GPT picked that post as AI, 0 otherwise.
# Then the same `lm(binary_response ~ source [* platform])` + avg_predictions
# pattern as the existing paper figures (see 07_direct_pairs.R).
#
# Input : data/gpt_detector_sample_<model>_*.csv (most recent)
# Output: output/fig_direct_pairs_human_vs_ai_gpt5_all_posts.{png,pdf}

# Set working directory ----------------------------------------------------
setwd(here::here())
getwd()

# ---- Setup ------------------------------------------------------------------

pacman::p_load(tidyverse, here, marginaleffects, glue, ggtext)

my_font  <- "Palatino"
conf_int <- function(data, estimate, std) {
  data |>
    mutate(up90 = {{ estimate }} + 1.64 * {{ std }},
           up95 = {{ estimate }} + 1.96 * {{ std }},
           lb90 = {{ estimate }} - 1.64 * {{ std }},
           lb95 = {{ estimate }} - 1.96 * {{ std }})
}
theme_set(theme_minimal() +
          theme(text = element_text(family = my_font, color = "#22211d"),
                plot.background  = element_rect(fill = "white", color = NA),
                panel.background = element_rect(fill = "white", color = NA),
                plot.title    = element_markdown(size = 22, face = "bold", family = my_font),
                plot.subtitle = element_markdown(size = 14, family = my_font),
                axis.title    = element_text(size = 16),
                axis.text.y   = element_text(size = 13, family = my_font),
                axis.text.x   = element_text(size = 11, family = my_font),
                legend.text   = element_text(size = 12, family = my_font),
                legend.title  = element_text(size = 12),
                plot.margin   = margin(1, 1, 1, 1, "cm")))


source("code/00_utils.R")

# ---- Locate the most recent pairwise-detector output -----------------------

candidates <- list.files(
  here("data"),
  pattern = "^gpt_detector_sample_.*\\.csv$",
  full.names = TRUE
)
stopifnot(length(candidates) > 0)
INPUT <- candidates[which.max(file.mtime(candidates))]
message("Using pairwise-detector output: ", INPUT)

# ---- Load + pivot to one row per post per call -----------------------------

d <- read_csv(INPUT, show_col_types = FALSE)

n_calls_total <- nrow(d)
n_pairs        <- n_distinct(paste(d$text_id_left, d$text_id_right))
detector_model <- unique(d$model)[1]

# Each call produces one Post-A and one Post-B observation. binary_response
# = 1 if GPT picked that side as AI.
d_long <- d |>
  filter(!is.na(parsed_answer)) |>
  transmute(
    text_id_left, text_id_right, platform, call_number,
    parsed_answer,
    `Post A_source` = source_left,
    `Post B_source` = source_right
  ) |>
  pivot_longer(
    cols      = c(`Post A_source`, `Post B_source`),
    names_to  = "side",
    values_to = "source"
  ) |>
  mutate(
    side            = str_remove(side, "_source"),
    binary_response = as.integer(parsed_answer == side),
    platform        = if_else(platform == "X/Twitter", "Twitter/X", platform)
  )

# ---- Pooled + per-platform models ------------------------------------------

m_pool <- lm(binary_response ~ source, data = d_long)
m_plat <- lm(binary_response ~ source * platform, data = d_long)

res_pool <- avg_predictions(m_pool, by = "source") |>
  as_tibble() |>
  conf_int(estimate, std.error) |>
  mutate(comparison = "Pooled")

res_plat <- avg_predictions(m_plat, by = c("source", "platform")) |>
  as_tibble() |>
  conf_int(estimate, std.error) |>
  rename(comparison = platform)

res <- bind_rows(res_pool, res_plat) |>
  mutate(
    comparison = factor(comparison, levels = rev(c(
      "Pooled", "Twitter/X", "YouTube", "TikTok", "Truth Social"))),
    source     = factor(source, levels = c("Human", "AI"))
  )

# ---- Plot ------------------------------------------------------------------

subtitle_txt <- glue(
  "{detector_model} | {n_pairs} unique pairs | {n_calls_total} calls total"
)

ggplot(res, aes(y = comparison, x = estimate, fill = source)) +
  geom_col(width = 0.75, color = "black", linewidth = 0.3,
           position = position_dodge(width = 0.85)) +
  geom_errorbar(aes(xmin = lb95, xmax = up95),
                width = 0.25, linewidth = 0.6, color = "black",
                position = position_dodge(width = 0.85)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "gray40") +
  scale_fill_manual(values = c("Human" = "tomato2", "AI" = "steelblue"),
                    name = "Post Source") +
  scale_x_continuous(breaks = seq(0, 1, by = 0.1)) +
  coord_cartesian(xlim = c(0, 1)) +
  labs(x = "Proportion of Posts Classified as AI \n (Paired with a Human Post)",
       y = "") +
  theme(legend.position = "bottom",
        axis.text.y     = element_text(size = 13, family = my_font),
        axis.text.x     = element_text(size = 11, family = my_font),
        axis.title.x    = element_text(size = 12, hjust = 0.5))

save_function("fig_direct_pairs_human_vs_ai_gpt5_all_posts.png")
save_function("fig_direct_pairs_human_vs_ai_gpt5_all_posts.pdf")

