##############################################################################
# File-Name: 07_direct_pairs.R
# author: Tiago Ventura
# Purpose: AI-detection rates in human-AI pairs and validation of PHI scores
#          against detection. Produces SI Figures S5, S6 and S7.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Set working directory ----------------------------------------------------
setwd(here::here())
getwd()


# Packages + theme ---------------------------------------------------------
pacman::p_load("lme4", "marginaleffects", "patchwork")
source("code/00_utils.R")


# Load BT scores to get the (platform, text_id) -> model mapping ----------
# Same pattern as 00_analysis_bt.R:25-30.
bt_files <- str_subset(list.files("data/bt_scores"), "^bt_")

bt_models <- map_df(bt_files, ~
                      read_csv(paste0("./data/bt_scores/", .x),
                               show_col_types = FALSE) %>%
                      mutate(platform_file = .x)) %>%
  mutate(platform = case_when(
    platform_file == "bt_ts_posts_rankings_with_source_persona_inverted.csv" ~ "Truth Social",
    platform_file == "bt_tt_posts_rankings_with_source_persona_inverted.csv" ~ "TikTok",
    platform_file == "bt_x_posts_rankings_with_source_persona_inverted.csv"  ~ "Twitter/X",
    platform_file == "bt_yt_posts_rankings_with_source_persona_inverted.csv" ~ "YouTube"
  )) %>%
  select(platform, text_id = Text_ID, model,
         phi = `Normalized Ability`) %>%
  # 3 duplicate (platform, text_id) rows in the BT data; keep first per pair.
  distinct(platform, text_id, .keep_all = TRUE)


# Load + pre-process pairs -------------------------------------------------
# Same pre-processing as 09_logit.R, but stops before the
# binary_response==1 filter so both pair members survive (one Human, one AI).
d <- read_csv("data/pairs_survey_clean.csv")

d_pairs <- d %>%
  filter(att_check_sum == 0) %>%
  # Survey uses "X/Twitter"; BT data uses "Twitter/X". Normalize so the
  # platform key matches the rest of the analysis pipeline.
  mutate(platform = if_else(platform == "X/Twitter", "Twitter/X", platform),
         source_num = ifelse(source == "Human", 1, 0)) %>%
  group_by(response_id, order, platform) %>%
  mutate(sum_source = sum(source_num)) %>%
  ungroup() %>%
  filter(sum_source == 1) %>%
  # Join in the LLM model name per post (Human posts get NA -> "human").
  left_join(bt_models, by = c("platform", "text_id")) %>%
  mutate(model = case_when(
           source == "Human"      ~ "human",
           model == "gpt_4omini"  ~ "gpt_4o_mini",
           model == "llama3_3"    ~ "llama_3.3",
           model == "llama_3_3"   ~ "llama_3.3",
           model == "gpt_4o_fall" ~ "gpt_4o",
           model == "gpt4o-mini"  ~ "gpt_4o_mini",
           TRUE                   ~ model
         ))

# Sanity checks
d_pairs %>% count(model)
d_pairs %>% count(platform)
d_pairs %>% summarise(mean_picked_as_AI = mean(binary_response))


# Pooled estimation --------------------------------------------------------
m_pool <- lm(binary_response ~ model, data = d_pairs)

res_pool <- avg_predictions(m_pool, by = "model") %>%
  as_tibble() %>%
  conf_int(estimate, std.error) %>%
  mutate(model = recode(model,
                        "human"       = "Human (Pooled Across All Models)",
                        "gpt_4"       = "GPT-4",
                        "gpt_4o"      = "GPT-4o",
                        "gpt_4o_mini" = "GPT-4o Mini",
                        "llama2_70b"  = "Llama 2",
                        "llama3_2_3b" = "Llama 3.2",
                        "llama_3.3"   = "Llama 3.3"),
         model = factor(model, levels = rev(c(
           "Human (Pooled Across All Models)",
           "GPT-4", "GPT-4o", "GPT-4o Mini",
           "Llama 2", "Llama 3.2", "Llama 3.3"))),
         color = case_when(str_detect(model, "Human") ~ "Human",
                           str_detect(model, "GPT")   ~ "GPT",
                           str_detect(model, "Llama") ~ "Llama"),
         color = fct_rev(fct_relevel(color, c("Human", "GPT", "Llama"))))


# Per-platform estimation --------------------------------------------------
m_plat <- lm(binary_response ~ model * platform, data = d_pairs)

res_plat <- avg_predictions(m_plat, by = c("model", "platform")) %>%
  as_tibble() %>%
  conf_int(estimate, std.error) %>%
  mutate(model = recode(model,
                        "human"       = "Human (Pooled Across All Models)",
                        "gpt_4"       = "GPT-4",
                        "gpt_4o"      = "GPT-4o",
                        "gpt_4o_mini" = "GPT-4o Mini",
                        "llama2_70b"  = "Llama 2",
                        "llama3_2_3b" = "Llama 3.2",
                        "llama_3.3"   = "Llama 3.3"),
         model = factor(model, levels = rev(c(
           "Human (Pooled Across All Models)",
           "GPT-4", "GPT-4o", "GPT-4o Mini",
           "Llama 2", "Llama 3.2", "Llama 3.3"))),
         platform = recode(platform, "Twitter/X" = "X/Twitter"),
         platform = factor(platform, levels = c(
           "X/Twitter", "YouTube", "TikTok", "Truth Social")),
         color = case_when(str_detect(model, "Human") ~ "Human",
                           str_detect(model, "GPT")   ~ "GPT",
                           str_detect(model, "Llama") ~ "Llama"),
         color = fct_rev(fct_relevel(color, c("Human", "GPT", "Llama"))))


# Graph 1 — Human vs AI (collapsed), Pooled + per-platform in one plot ------
# Models for the AI/Human collapse:
m_pool_src <- lm(binary_response ~ source, data = d_pairs)
m_plat_src <- lm(binary_response ~ source * platform, data = d_pairs)

res_pool_src <- avg_predictions(m_pool_src, by = "source") %>%
  as_tibble() %>%
  conf_int(estimate, std.error) %>%
  mutate(comparison = "Pooled")

res_plat_src <- avg_predictions(m_plat_src, by = c("source", "platform")) %>%
  as_tibble() %>%
  conf_int(estimate, std.error) %>%
  rename(comparison = platform)

res_g1 <- bind_rows(res_pool_src, res_plat_src) %>%
  mutate(comparison = recode(comparison, "Twitter/X" = "X/Twitter"),
         comparison = factor(comparison, levels = rev(c(
           "Pooled", "X/Twitter", "YouTube", "TikTok", "Truth Social"))),
         source = factor(source, levels = c("Human", "AI")))

g1 <- ggplot(res_g1, aes(y = comparison, x = estimate, fill = source)) +
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
       y = "",
       title = "") +
  theme(legend.position = "right",
        axis.text.y = element_text(size = 13, family = my_font),
        axis.text.x = element_text(size = 11, family = my_font),
        axis.title.x = element_text(size = 12, hjust = 0.5))
g1
save_function("fig_s5.png")
save_function("fig_s5.pdf")


# Graph 2 — AI models only: Pooled (A) + Per-platform (B) -------------------
# Mirrors the Figure 1 layout (panel A pooled + panel B per-
# platform), but with bars + 50% reference line, and no Human row.
res_g2_pool <- res_pool %>%
  filter(!str_detect(as.character(model), "Human")) %>%
  mutate(model = fct_drop(model),
         color = fct_drop(color))

res_g2_plat <- res_plat %>%
  filter(!str_detect(as.character(model), "Human")) %>%
  mutate(model = fct_drop(model),
         color = fct_drop(color))

g2a <- ggplot(res_g2_pool, aes(y = model, x = estimate, fill = color)) +
  geom_col(width = 0.7, color = "black", linewidth = 0.3) +
  geom_errorbar(aes(xmin = lb95, xmax = up95),
                width = 0.25, linewidth = 0.6, color = "black") +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "gray40") +
  ylab("Post Source \n ") +
  xlab("Proportion of Posts Classified as AI \n (Paired with a Human Post)") +
  scale_x_continuous(breaks = seq(0, 1, by = 0.1)) +
  coord_cartesian(xlim = c(0, 1)) +
  labs(title = "A) Pooled Estimates") +
  scale_fill_manual(values = c("steelblue", "gray90"),
                    name = "Model Family", drop = FALSE) +
  theme(plot.title = element_markdown(size = 14, face = "bold"),
        strip.text = element_text(family = my_font, color = "#22211d",
                                  size = 12, hjust = 0, face = "bold"),
        strip.background = element_blank(),
        plot.margin = margin(0, 0, 0, 0, "cm"),
        axis.text.x = element_text(size = 10, family = my_font, hjust = 0),
        axis.text.y = element_text(size = 12, family = my_font, hjust = 0),
        legend.position = "none")

g2b <- ggplot(res_g2_plat, aes(y = model, x = estimate, fill = color)) +
  geom_col(width = 0.7, color = "black", linewidth = 0.3) +
  geom_errorbar(aes(xmin = lb95, xmax = up95),
                width = 0.25, linewidth = 0.6, color = "black") +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "gray40") +
  ylab("\nPost Source \n") +
  xlab("Proportion of Posts Classified as AI \n (Paired with a Human Post)") +
  scale_x_continuous(breaks = seq(0, 1, by = 0.1)) +
  coord_cartesian(xlim = c(0, 1)) +
  labs(title = "B) Platform Estimates") +
  scale_fill_manual(values = c("steelblue", "gray90"),
                    name = "Model Family", drop = FALSE) +
  theme(plot.title = element_markdown(size = 14, face = "bold"),
        strip.text = element_text(family = my_font, color = "#22211d",
                                  size = 12, hjust = .5, face = "bold"),
        strip.background = element_blank(),
        plot.margin = margin(0, 0, 0, 0, "cm"),
        axis.text.x = element_text(size = 10, family = my_font, hjust = 0),
        axis.text.y = element_text(size = 12, family = my_font, hjust = 0),
        legend.position = "bottom") +
  facet_wrap(~ platform, nrow = 2)

g2_combined <- g2a + g2b +
  plot_layout(ncol = 2, widths = c(0.75, 1)) &
  theme(axis.title.x = element_text(size = 12, hjust = 0.5),
        axis.title.y = element_text(size = 12))

g2_combined

save_function("fig_s6.png")
save_function("fig_s6.pdf")



# Graph 3 — Proportion classified as AI by PHI bin --------------------------
# For each 0.10-wide bin of PHI, what share of post-judgments picked that
# post as AI? Tests whether BT-derived PHI scores agree with the direct
# AI/Human classification participants gave.
bin_breaks <- seq(-1, 1, by = 0.1)

bin_summary <- d_pairs %>%
  filter(!is.na(phi)) %>%
  mutate(phi_bin = cut(phi, breaks = bin_breaks,
                       include.lowest = TRUE, right = FALSE)) %>%
  group_by(phi_bin) %>%
  summarise(prop_ai = mean(binary_response),
            n       = n(),
            phi_mid = mean(phi),
            .groups = "drop") %>%
  mutate(se  = sqrt(prop_ai * (1 - prop_ai) / n),
         lb95 = pmax(0, prop_ai - 1.96 * se),
         up95 = pmin(1, prop_ai + 1.96 * se))

g3 <- ggplot(bin_summary, aes(x = phi_mid, y = prop_ai)) +
  geom_col(fill = "grey90", color = "black",
           linewidth = 0.3, width = 0.09) +
  geom_errorbar(aes(ymin = lb95, ymax = up95),
                width = 0.025, linewidth = 0.5, color = "black") +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray40") +
  scale_x_continuous(breaks = seq(-1, 1, by = 0.2),
                     limits = c(-1, 1)) +
  scale_y_continuous(breaks = seq(0, 1, by = 0.1),
                     limits = c(0, 1)) +
  labs(x = "PHI Score (binned in 0.1 intervals)",
       y = "Proportion of Posts Classified as AI \n (Paired with a Human Post)")
       #title = "Direct AI Classification by PHI Bin") +
  theme(axis.text.x = element_text(size = 11, family = my_font),
        axis.text.y = element_text(size = 11, family = my_font),
        axis.title.x = element_text(size = 12, hjust = 0.5),
        axis.title.y = element_text(size = 12))
g3

save_function("fig_s7.png")
save_function("fig_s7.pdf")

