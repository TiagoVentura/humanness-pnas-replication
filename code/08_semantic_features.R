##############################################################################
# File-Name: 08_semantic_features.R
# author: Tiago Ventura
# Purpose: Regressions of PHI scores on sentiment, emotion and civility
#          features, robustness across classifier families and by post
#          source, and stylistic markers. Produces Figure 2, SI Figures S2,
#          S8, S9 and S10, and SI Tables S4 and S5.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Set working directory ---------
setwd(here::here())
getwd()

# Call packages -----------------------------------------------------------
pacman::p_load("lme4", "marginaleffects", "sandwich", "lmtest", "clubSandwich", "wesanderson")
source("code/00_utils.R")


# Re-run models -----------------------------------------------------------

# BT Scores Analysis ------------------------------------------------------

## Open data -------------
files <- str_subset(list.files("data/bt_scores_features"),"^post")

## read files
ft3 <- map_df(files, ~ 
               read_csv(paste0("./data/bt_scores_features/",.x)) %>% 
               mutate(platform=.x)) %>% clean_names()
## recode
ft3 = ft3 %>%
  mutate(irony=fct_relevel(irony_label, "non_irony"),
         offensive=fct_relevel(offensive_label, "non-offensive"),
         hateful_speech=fct_relevel(hate_label, "non-hate"), 
         anger=ifelse(emotion_label=="anger", 1, 0), 
         joy=ifelse(emotion_label=="joy", 1, 0),
         optmism=ifelse(emotion_label=="optimism", 1, 0),
         sadness=ifelse(emotion_label=="sadness", 1, 0), 
         sentiment_negative=ifelse(sentiment_label=="LABEL_0", 1, 0),
         sentiment_positive=ifelse(sentiment_label=="LABEL_2", 1, 0))


# model
# Note: n_words dropped (was collinear with n_chars; the joint coefficients
# captured lexical density rather than length and confused interpretation).
mod_p <- lm(normalized_ability~ irony +
              offensive + hateful_speech +
              joy +
              optmism +
              sadness +
              sentiment_negative +
              sentiment_positive + 
              n_chars +
              n_sents + avg_word_len + n_exclaims + pct_caps,
   data=ft3)

summary(mod_p)

## identify platform
ft_res <- mod_p %>% 
       avg_slopes() %>%
       tidy() %>%
        conf_int(estimate, std.error) %>%
       filter(term!="avg_word_len",
              !str_detect(term, "n_|pct")) %>%
        mutate(yaxis=str_to_title(str_replace_all(term, "_", " "))) %>%
  arrange(desc(estimate)) %>%
  mutate(yaxis=fct_rev(fct_inorder(yaxis)), 
         yaxis=fct_rev(fct_relevel(yaxis, c("Hateful Speech", "Sentiment Negative", 
                                    "Optmism", "Sadness", "Joy", "Offensive",
                                    "Irony", "Sentiment Positive")))) %>%
  mutate(category=case_when(yaxis=="Joy"~ "Emotion", 
                            yaxis=="Optmism"~ "Emotion", 
                            yaxis=="Sadness"~ "Emotion", 
                            yaxis=="Hateful Speech"~ "Civility", 
                            yaxis=="Irony"~ "Civility", 
                            yaxis=="Offensive"~ "Civility",
                            str_detect(yaxis, "Sentiment")~ "Sentiment"), 
         category=fct_relevel(category, c("Sentiment","Emotion", "Civility")))


ggplot(ft_res,
       aes(y=yaxis, 
           x=estimate, fill=category)) +
  geom_errorbar(aes(xmin=lb95, xmax = up95),
                size=1.5, width=0) +
  geom_point(size=6, shape=21) +
  xlab("Marginal Effects on PHI Scores (Positive = More Human)") +
  ylab("") +
  labs(title="", 
       subtitle= "", 
       caption="") +
  guides(alpha="none",
         color = guide_legend(reverse = TRUE),
         fill= guide_legend(reverse = TRUE)) +
  scale_fill_manual(values=wes_palette("AsteroidCity2", 3),
                    name="Emotive language features:") +
  theme(legend.position = 'bottom', 
        legend.title = element_text(size = 22),   # increase legend title size
        legend.text = element_text(size = 16)) +
  geom_vline(aes(xintercept=0), linetype="dashed", color="gray50")  +
  xlim(-0.4, 0.4)

save_function("fig_features2.pdf", 14, 12)
save_function("fig_features2.png", 14, 12)
write_csv(ft_res, "output/results_semantic.csv")

# model
mod_p <- lm(normalized_ability~ irony*platform +
              offensive*platform + hateful_speech*platform +
              joy*platform +
              optmism*platform +
              sadness*platform +
              sentiment_negative*platform +
              sentiment_positive*platform + n_chars +
              n_sents + avg_word_len + n_exclaims + pct_caps,
            data=ft3)

## identify platform
fit_res<- map(list("irony", "offensive", "hateful_speech", 
                   "joy", "optmism", "sadness", "sentiment_negative", 
                   "sentiment_positive"), ~ 
                mod_p %>% 
  avg_slopes(variables = .x, 
             by="platform") %>%
  tidy() %>%
  conf_int(estimate, std.error) %>%
  filter(term!="avg_word_len",
         !str_detect(term, "n_|pct")) %>%
  mutate(yaxis=str_to_title(str_replace_all(term, "_", " "))) %>%
  mutate(facet=case_when(platform=="post_traits_ts.csv"~"Truth Social", 
                         platform=="post_traits_tt.csv"~"TikTok", 
                         platform=="post_traits_x.csv"~"X/Twitter", 
                         platform=="post_traits_yt.csv"~"YouTube"))) %>%
  bind_rows() %>%
  mutate(yaxis=fct_rev(fct_inorder(yaxis)), 
         yaxis=fct_rev(fct_relevel(yaxis, c("Hateful Speech", "Sentiment Negative", 
                                            "Optmism", "Sadness", "Joy", "Offensive",
                                            "Irony", "Sentiment Positive"))))


fit_res = fit_res %>% 
  mutate(category=case_when(yaxis=="Joy"~ "Emotion", 
                            yaxis=="Optmism"~ "Emotion", 
                            yaxis=="Sadness"~ "Emotion", 
                            yaxis=="Hateful Speech"~ "Civility", 
                            yaxis=="Irony"~ "Civility", 
                            yaxis=="Offensive"~ "Civility",
                            str_detect(yaxis, "Sentiment")~ "Sentiment"), 
         category=fct_relevel(category, c("Sentiment","Emotion", "Civility")))
# graph
# plot combine
ggplot(fit_res,
       aes(y=yaxis, 
           x=estimate, fill=category)) +
  geom_errorbar(aes(xmin=lb95, xmax = up95),
                size=1.5, width=0) +
  geom_point(size=6, shape=21) +
  geom_vline(aes(xintercept=0), linetype="dashed", color="gray50") +
  xlab("Marginal Effects on PHI Scores (Positive = More Human)") +
  ylab("") +
  labs(title="", 
       subtitle= "", 
       caption="") +
  guides(alpha="none",
         color = guide_legend(reverse = TRUE),
         fill= guide_legend(reverse = TRUE)) +
  scale_fill_manual(values=wes_palette("AsteroidCity2", 3),
                    name="Emotive language features:") +
  theme(plot.subtitle = element_markdown(size=16, face="bold"), 
        strip.text = element_text(family = my_font, 
                                  color = "#22211d",
                                  size = 16, 
                                  hjust=0, face = "bold"), 
        strip.background = element_blank(), 
        axis.text.x = element_text(size=10, family=my_font, hjust=0)) +
  theme(legend.position = 'bottom') +
  facet_wrap(~facet, nrow=1) +
  xlim(-.5, 1)

save_function("sm_fig_features_platform2.pdf", 14, 12)
save_function("sm_fig_features_platform2.png", 14, 12)


# Robustness: TweetEval vs BERTweet ---------------------------------------
#
# Fits Figure 2's multivariate spec (mod_p above) for each classifier family.
# Anger is the omitted emotion baseline — Joy/Optimism/Anger/Sadness are
# mutually exclusive so all four + intercept would be perfectly collinear.
# Matches mod_p by keeping Joy/Optimism/Sadness, dropping Anger.

pacman::p_load(broom, patchwork)
labels_dir <- "data/tweeteval_eval"

labels_all <- bind_rows(
  read_csv(file.path(labels_dir, "labels_tweeteval.csv"), show_col_types = FALSE) %>%
    mutate(model_family = "TweetEval"),
  read_csv(file.path(labels_dir, "labels_bertweet.csv"),  show_col_types = FALSE) %>%
    mutate(model_family = "BERTweet")
) %>%
  mutate(model_family = factor(model_family,
                               levels = c("TweetEval", "BERTweet")))

# Pull controls from ft3. Text_ID is platform-local (restarts at 0 inside
# each post_traits_*.csv), so the join key MUST be (Text_ID, platform).
# Joining on Text_ID alone explodes 2386 rows -> ~9500 by matching every
# post against its same-ID twin in the other three platforms.
ft3_controls <- ft3 %>%
  mutate(platform = recode(platform,
                           post_traits_ts.csv = "Truth Social",
                           post_traits_tt.csv = "TikTok",
                           post_traits_x.csv  = "Twitter/X",
                           post_traits_yt.csv = "YouTube")) %>%
  distinct(text_id, platform, .keep_all = TRUE) %>%
  select(text_id, platform, n_chars, n_sents,
         avg_word_len, n_exclaims, pct_caps)

labels_all <- labels_all %>%
  left_join(ft3_controls,
            by = c("Text_ID" = "text_id", "platform" = "platform"))

# Feature lists. Anger is the omitted emotion baseline (matches mod_p).
feat_binary <- c("Sentiment - Negative", "Sentiment - Positive",
                 "Joy", "Optimism", "Sadness",
                 "Hateful Speech", "Irony", "Offensive")
feat_prob   <- paste0("prob_", feat_binary)
control     <- c("n_chars", "n_sents",
                 "avg_word_len", "n_exclaims", "pct_caps")

rhs_bin  <- paste(c(sprintf("`%s`", feat_binary), control), collapse = " + ")
rhs_prob <- paste(c(sprintf("`%s`", feat_prob),   control), collapse = " + ")

fit_family <- function(family, rhs) {
  lm(as.formula(sprintf("`Normalized Ability` ~ %s", rhs)),
     data = labels_all %>% filter(model_family == family))
}

families    <- c("TweetEval", "BERTweet")
models_bin  <- set_names(map(families, fit_family, rhs = rhs_bin),  families)
models_prob <- set_names(map(families, fit_family, rhs = rhs_prob), families)

# Sanity check: TweetEval/binary should match mod_p almost exactly.
print(tibble(
  feature = c("Joy", "Optimism", "Sadness",
              "Sentiment - Negative", "Sentiment - Positive"),
  paper_mod_p     = c(coef(mod_p)["joy"], coef(mod_p)["optmism"],
                      coef(mod_p)["sadness"],
                      coef(mod_p)["sentiment_negative"],
                      coef(mod_p)["sentiment_positive"]),
  tweeteval_block = c(coef(models_bin$TweetEval)["Joy"],
                      coef(models_bin$TweetEval)["Optimism"],
                      coef(models_bin$TweetEval)["Sadness"],
                      coef(models_bin$TweetEval)["`Sentiment - Negative`"],
                      coef(models_bin$TweetEval)["`Sentiment - Positive`"])
))

# Extract + tidy coefficients
extract_params <- function(model_list) {
  imap_dfr(model_list, ~ broom::tidy(.x, conf.int = TRUE) %>%
                          mutate(model_family = .y)) %>%
    filter(term != "(Intercept)",
           !term %in% control) %>%
    conf_int(estimate, std.error)
}

parameters_bin  <- extract_params(models_bin)
parameters_prob <- extract_params(models_prob)

# Clean labels + ordering. Strip the prob_ prefix so binary/probability
# share the same y-axis ordering.
tidy_params <- function(df) {
  df %>%
    mutate(yaxis = str_remove_all(term, "`"),
           yaxis = str_remove(yaxis, "^prob_"),
           yaxis = recode(yaxis,
                          "Sentiment - Negative" = "Sentiment Negative",
                          "Sentiment - Positive" = "Sentiment Positive",
                          "Optimism"             = "Optmism"),
           category = case_when(
             yaxis %in% c("Joy", "Optmism", "Sadness")            ~ "Emotion",
             yaxis %in% c("Hateful Speech", "Irony", "Offensive") ~ "Civility",
             str_detect(yaxis, "Sentiment")                        ~ "Sentiment"),
           yaxis = fct_rev(fct_relevel(
             yaxis,
             c("Hateful Speech", "Sentiment Negative", "Optmism",
               "Sadness", "Joy", "Offensive", "Irony",
               "Sentiment Positive"))),
           category     = fct_relevel(category, c("Sentiment","Emotion","Civility")),
           model_family = factor(model_family,
                                 levels = c("TweetEval","BERTweet")))
}

plot_bin  <- tidy_params(parameters_bin)
plot_prob <- tidy_params(parameters_prob)

write_csv(plot_bin,  "output/results_semantic_robustness_binary.csv")
write_csv(plot_prob, "output/results_semantic_robustness_probability.csv")

# Forest plot — three classifier families dodged.
make_forest <- function(df, x_label) {
  ggplot(df, aes(y = yaxis, x = estimate,
                 color = model_family, group = model_family)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = lb95, xmax = up95),
                   height = 0, linewidth = 1,
                   position = position_dodge(width = 0.6)) +
    geom_point(size = 3.5, position = position_dodge(width = 0.6)) +
    scale_color_manual(values = c(TweetEval = "#1f77b4",
                                  BERTweet  = "#ff7f0e"),
                       name = "Classifier:") +
    xlab(x_label) + ylab("") +
    theme(legend.position = "bottom",
          legend.title    = element_text(size = 18),
          legend.text     = element_text(size = 14))
}

p_bin  <- make_forest(plot_bin,
                      "Marginal Effect on PHI (Binary Labels, 95% CI)") +
  xlim(-.5, 1)
p_prob <- make_forest(plot_prob,
                      "Marginal Effect on PHI (Probability Scores, 95% CI)") +
  xlim(-.5, 1)

# Single-panel binary version (direct Figure 2 expansion)
print(p_bin)
save_function("sm_fig_features_model_robustness_binary.pdf", 14, 10)
save_function("sm_fig_features_model_robustness_binary.png", 14, 10)

# Single-panel probability version (additional robustness check)
print(p_prob)
save_function("sm_fig_features_model_robustness_probability.pdf", 14, 10)
save_function("sm_fig_features_model_robustness_probability.png", 14, 10)


# AI vs Human heterogeneity ----------------------------------------------
df_ai_hum <- labels_all %>%
  filter(model_family == "TweetEval") %>%
  mutate(source_type = factor(if_else(model == "human", "Human", "AI"),
                              levels = c("AI", "Human")),
         platform    = factor(platform)) %>%
  rename(NormalizedAbility   = `Normalized Ability`,
         SentimentNegative   = `Sentiment - Negative`,
         SentimentPositive   = `Sentiment - Positive`,
         HatefulSpeech       = `Hateful Speech`)

bind_rows(df_ai_hum, df_ai_hum %>% mutate(platform = "All")) %>%
  mutate(n_chars_text = nchar(Text)) %>%
  group_by(platform, source_type) %>%
  summarise(n = n(), min = min(n_chars_text), max = max(n_chars_text), 
            mean = mean(n_chars_text), median = median(n_chars_text), 
            sd = sd(n_chars_text), .groups = "drop") %>%
  write_csv("output/tab_s4_post_length.csv")

feat_clean <- c("SentimentNegative", "SentimentPositive",
                "Joy", "Optimism", "Sadness",
                "HatefulSpeech", "Irony", "Offensive")

rhs_int <- paste0(c(
  paste0(feat_clean, " * source_type"),
  "platform",
  control
), collapse = " + ")

# model
mod_int <- lm(as.formula(paste("NormalizedAbility ~", rhs_int)),
              data = df_ai_hum)

# Within-group marginal effects (one row per feature × source_type)
slopes_grp <- map_dfr(feat_clean, ~
  avg_slopes(mod_int, variables = .x,
             by = "source_type") %>%
    as_tibble() %>%
    transmute(feature = .x,
              source_type = factor(source_type, c("AI", "Human")),
              estimate, std.error,
              lb95 = conf.low, up95 = conf.high)
)

# Pooled marginal effects from mod_p (additive Figure 2 spec). Term names
# come from ft3 (lowercased / factor-encoded) and need to be mapped to the
# feat_clean labels used in plot_het below.
pooled_term_map <- c(
  hateful_speech     = "HatefulSpeech",
  irony              = "Irony",
  offensive          = "Offensive",
  joy                = "Joy",
  optmism            = "Optimism",
  sadness            = "Sadness",
  sentiment_negative = "SentimentNegative",
  sentiment_positive = "SentimentPositive"
)
slopes_pooled <- avg_slopes(mod_p) %>%
  as_tibble() %>%
  filter(term %in% names(pooled_term_map)) %>%
  transmute(feature     = pooled_term_map[term],
            source_type = factor("Pooled", c("AI", "Human", "Pooled")),
            estimate, std.error,
            lb95 = conf.low, up95 = conf.high)

slopes_grp <- bind_rows(slopes_grp, slopes_pooled) %>%
  mutate(source_type = factor(source_type, levels = c("Pooled", "AI", "Human")))

# Pairwise difference test (Human - AI) per feature
diffs_grp <- map_dfr(feat_clean, function(f) {
  avg_slopes(mod_int, variables = f, by = "source_type",
             hypothesis = ~pairwise) %>%
    as_tibble() %>%
    transmute(feature = f,
              diff_estimate = estimate,
              diff_p        = p.value,
              diff_lb95     = conf.low,
              diff_ub95     = conf.high)
})

# Tidy + plot
plot_het <- slopes_grp %>%
  left_join(diffs_grp, by = "feature") %>%
  mutate(yaxis = recode(feature,
                        "SentimentNegative" = "Sentiment \nNegative",
                        "SentimentPositive" = "Sentiment \nPositive",
                        "HatefulSpeech"     = "Hateful \nSpeech",
                        "Optimism"          = "Optmism"),
         category = case_when(
           yaxis %in% c("Joy", "Optmism", "Sadness")            ~ "Emotion",
           yaxis %in% c("Hateful Speech", "Irony", "Offensive") ~ "Civility",
           str_detect(yaxis, "Sentiment")                        ~ "Sentiment"),
         yaxis = fct_rev(fct_relevel(
           yaxis,
           c("Hateful \nSpeech", "Sentiment \nNegative", "Optmism",
             "Sadness", "Joy", "Offensive", "Irony", "Sentiment \nPositive"))),
         sig_label = case_when(diff_p < 0.001 ~ "***",
                               diff_p < 0.01  ~ "**",
                               diff_p < 0.05  ~ "*",
                               TRUE           ~ ""))

# Per-feature significance labels for the AI-vs-Human gap (one row per
# feature, no source dodge).

# Shared style for the two Figure-3 panels (semantic AI-vs-Human + descriptive
# markers) so they sit side by side with ONE common legend and matching label
# sizes. Identical colour + alpha scales (same name) let patchwork collect a
# single legend.
pal_sample   <- c(Pooled = "black", AI = "steelblue", Human = "tomato2")
alpha_sample <- c(Pooled = 1, AI = .5, Human = .5)
fig3_theme   <- theme(legend.position  = "bottom",
                      legend.title     = element_text(size = 13),
                      legend.text      = element_text(size = 12),
                      axis.title.x     = element_text(size = 12),
                      axis.text.y      = element_text(size = 14), face="bold",
                      axis.text.x      = element_text(size = 10),
                      plot.title       = element_markdown(size = 14, face = "bold"),
                      panel.grid.minor = element_blank())

p_ai <- ggplot(plot_het %>% mutate(source_type=fct_rev(source_type)), 
               aes(y = yaxis, x = estimate,
                             color = source_type, alpha = source_type,
                             group = source_type)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_errorbarh(aes(xmin = lb95, xmax = up95),
                 height = 0, linewidth = 1,
                 position = position_dodge(width = 0.4)) +
  geom_point(size = 4, position = position_dodge(width = 0.4)) +
  scale_color_manual(values = pal_sample, name = "Sample:") +
  scale_alpha_manual(values = alpha_sample, name = "Sample:") +
  labs(title = "Emotive language features") +
  xlab("Marginal Effects Per Binary Feature on PHI Scores  \n (Positive=More Human)") + ylab("") +
  coord_cartesian(xlim = c(-0.5, .5)) 

p_ai

save_function("sm_fig_features_ai_vs_human.pdf", 14, 10)
save_function("sm_fig_features_ai_vs_human.png", 14, 10)


# Heterogeneity test ------------------------------------------------------
#
# Joint F-test of the 8 feature x source interactions (mod_base vs mod_int):
# are the Human-vs-AI differences in the Fig. S10 feature effects jointly
# significant?

rhs_base <- paste0(c(feat_clean, "source_type", "platform", control),
                   collapse = " + ")
mod_base <- lm(as.formula(paste("NormalizedAbility ~", rhs_base)),
               data = df_ai_hum)
het_ftest <- anova(mod_base, mod_int)
print(het_ftest)

# Same test in the marginaleffects idiom: the 8 Human-AI slope differences
# (the gaps plotted in Fig. S10, as in diffs_grp above) are jointly null.
# Reproduces the anova() F exactly: F(8, 2360) = 1.27, p = 0.255.
het_joint_me <- avg_slopes(mod_int, variables = feat_clean, by = "source_type",
                           hypothesis = ~ revpairwise | term) %>%
  hypotheses(joint = TRUE, joint_test = "f")
print(het_joint_me)

# Secondary: any-feature binary x source — does the presence of at least one
# emotive cue predict PHI differently for Human vs AI posts? (~90% of posts
# carry >=1 feature, so this indicator has little variance — interpret with
# caution.)
df_ai_hum <- df_ai_hum %>%
  mutate(any_feature = as.integer(rowSums(across(all_of(feat_clean))) > 0))
mod_any <- lm(as.formula(paste(
  "NormalizedAbility ~ any_feature * source_type + platform +",
  paste(control, collapse = " + "))), data = df_ai_hum)

heterogeneity_results <- bind_rows(
  tibble(estimate = NA_real_, std.error = NA_real_,
         statistic = het_ftest$F[2], p.value = het_ftest$`Pr(>F)`[2],
         lb95 = NA_real_, up95 = NA_real_,
         spec = "Joint F-test of 8 feature x source interactions"),
  broom::tidy(mod_any, conf.int = TRUE) %>%
    filter(str_detect(term, "any_feature:|:any_feature")) %>%
    transmute(estimate, std.error, statistic, p.value,
              lb95 = conf.low, up95 = conf.high,
              spec = "Any-feature binary x source"))
print(heterogeneity_results)
write_csv(heterogeneity_results, "output/results_r13_heterogeneity_test.csv")


# Platform-specific stylistic markers --------------------------------------

# 1. Build markers from the raw text -------------------------------------------

df_mk <- df_ai_hum %>%
  mutate(
    n_hashtags     = str_count(Text, "#\\w+"),
    n_mentions     = str_count(Text, "@\\w+"),
    n_urls         = str_count(Text, "https?://"),
    is_retweet     = as.integer(str_detect(Text, "^RT[ :@]")),
    is_reply       = as.integer(str_detect(Text, "^@\\w+")),
    n_markers      = n_hashtags + n_mentions + n_urls + is_retweet + is_reply,
    text_clean     = Text |>
                       str_replace_all("https?://\\S+", "") |>
                       str_replace_all("#\\w+",         "") |>
                       str_replace_all("@\\w+",         "") |>
                       str_replace_all("^RT[ :@]+",     "") |>
                       str_squish(),
    n_chars_clean       = nchar(text_clean),
    n_chars_markers     = n_chars - n_chars_clean,
    # Per-sentence verbosity: substantive chars / sentence. Adds a separate
    # axis for "sentence variation" — earlier analysis showed that n_sents
    # heterogeneity was masked by correlation with n_chars_clean; teasing
    # apart sentence count from per-sentence length recovers both signals.
    clean_chars_per_sent = n_chars_clean / pmax(n_sents, 1)
  )

# Readability (Flesch Reading Ease), computed on the SUBSTANTIVE text
# (text_clean: ALL platform markers - URLs, #hashtags, @mentions, RT prefixes -
# removed); higher Flesch = easier to read.
# Lexical diversity (raw TTR) was evaluated but EXCLUDED: it was a precise null
# and, being mechanically tied to text length (TTR = unique/total words),
# competed with the substantive-text-length predictor. See
# 01b_semantic_lexical_robustness.R for the TTR specifications.
pacman::p_load(quanteda, quanteda.textstats)
.mk_corp <- corpus(coalesce(df_mk$text_clean, ""))
df_mk$flesch_ease <- textstat_readability(.mk_corp, measure = "Flesch")$Flesch


# Check the mean
df_mk %>% group_by(platform, source_type) %>%
        summarise(across(c(n_hashtags, n_mentions, n_urls, is_retweet),
                         ~ round(mean(.x), 3)),
                  mean_markers = round(mean(n_markers), 2),
                  n = n(), .groups = "drop")

df_mk %>% group_by(platform, source_type) %>%
        summarise(across(c(n_hashtags, is_retweet, n_mentions, n_urls),
                         list(mean = ~ round(mean(.x), 2), 
                              pct = ~ round(100 * mean(.x > 0), 0))),
                  n = n(), .groups = "drop") %>%
  write_csv("output/tab_s5_stylistic_markers.csv")

# 2. Two models: pooled and source-interacted --------------------------------

mod_pool <- lm(NormalizedAbility ~ 
                 n_markers + 
                 n_chars_clean +
                 n_sents +
                 avg_word_len + 
                 n_exclaims + pct_caps, 
               data = df_mk)

mod_src  <- lm(NormalizedAbility ~
                 (n_markers + n_chars_clean + n_sents +
                  avg_word_len + n_exclaims + pct_caps) * source_type,
               data = df_mk)

vars   <- c("n_markers", "n_chars_clean", "n_sents",
            "avg_word_len", "n_exclaims", "pct_caps")

sd_vec <- vapply(vars, function(v) sd(df_mk[[v]], na.rm = TRUE), numeric(1))

scale_per_sd <- function(df) df %>%
  mutate(estimate  = estimate  * sd_vec[term],
         std.error = std.error * sd_vec[term],
         conf.low  = conf.low  * sd_vec[term],
         conf.high = conf.high * sd_vec[term])

res_pooled <- avg_slopes(mod_pool, variables = vars) %>%
                as_tibble() %>% scale_per_sd() %>% mutate(group = "Pooled")

res_src <- avg_slopes(mod_src, variables = vars, by = "source_type") %>%
             as_tibble() %>% scale_per_sd() %>%
             mutate(group = as.character(source_type)) %>%
             select(-source_type)

res_combined <- bind_rows(res_pooled, res_src) %>%
  mutate(predictor = recode(term,
                            "n_markers"            = "Platform's Marker \ncount",
                            "n_chars_clean"        = "Substantive \ntext length",
                            "n_sents"              = "Sentence \ncount",
                            "avg_word_len"         = "Avg word \nlength",
                            "n_exclaims"           = "Exclamation \ncount",
                            "pct_caps"             = "% caps"
                            #"flesch_ease"          = "Readability (Flesch ease)",
                            ),
         predictor = factor(predictor, levels = rev(c(
           "Substantive \ntext length", "Platform's Marker \ncount",
           "Chars per sentence", "Sentence \ncount",
           "Avg word \nlength",
           "Exclamation \ncount", "% caps"))),
         group = fct_rev(factor(group, levels = c("Pooled", "AI", "Human"))))


#write_csv(res_combined, "output/results_markers_pooled_vs_source.csv")

p_mk <- ggplot(res_combined,
               aes(y = predictor, x = estimate, color = group,
                   alpha = group, group = group)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high),
                 height = 0, linewidth = 1,
                 position = position_dodge(width = 0.4)) +
  geom_point(size = 4, position = position_dodge(width = 0.4)) +
  scale_color_manual(values = pal_sample, name = "Sample:") +
  scale_alpha_manual(values = alpha_sample, name = "Sample:") +
  labs(title = "") +
  xlab("Marginal Effects per +1 SD of Textual Features on PHI Scores \n (Positive=More Human)") + ylab("") +
  coord_cartesian(xlim = c(-0.5, 0.5)) +
  fig3_theme

print(p_mk)
save_function("sm_fig_markers_pooled_vs_source.pdf", 12, 7)
save_function("sm_fig_markers_pooled_vs_source.png", 12, 7)
