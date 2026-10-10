##############################################################################
# File-Name: 13_balance_table_demographics.R
# Date: 2026-05-13
# Purpose: Produce the Table S19 demographic composition table (Survey 1,
#          Survey 2, Total, US general population) with
#          modelsummary::datasummary_balance.
#
# Data in :  data/connect_survey_yt_x.csv, data/connect_survey_ts_tt.csv,
#            data/survey_cleaned.csv, data/pairs_data_yt_x.csv,
#            data/pairs_data_tt_ts.csv
# Data out:  output/tab_s13_demographics_with_genpop.{tex,csv}
#
# General-population reference values are hard-coded in the gen_pop tribble.
##############################################################################

# Set working directory ---------------------------------------------------
setwd(here::here())
getwd()

# Packages ----------------------------------------------------------------
pacman::p_load(tidyverse, here, kableExtra, glue, modelsummary)
options(modelsummary_factory_latex = "kableExtra",
        modelsummary_format_numeric_latex = "plain")

# ---- Read raw inputs (no pre-computed summary CSVs needed) --------------
cs1 <- read_csv("data/connect_survey_yt_x.csv",  show_col_types = FALSE)
cs2 <- read_csv("data/connect_survey_ts_tt.csv", show_col_types = FALSE)
sc  <- read_csv("data/survey_cleaned.csv", show_col_types = FALSE) %>%
  distinct(response_id, .keep_all = TRUE)
pids1 <- read_csv("data/pairs_data_yt_x.csv",  show_col_types = FALSE) %>%
  distinct(response_id) %>% pull(response_id)
pids2 <- read_csv("data/pairs_data_tt_ts.csv", show_col_types = FALSE) %>%
  distinct(response_id) %>% pull(response_id)

# Merge each wave to the pairs-completed sample (this is why n = 601 / 606,
# not the raw 599 / 604 from the Connect files).
merge_wave <- function(cs, pids) {
  cs %>%
    left_join(sc %>% select(participant_id, response_id,
                            party_id, party_id_lean, party_id_imputation),
              by = c("ParticipantId" = "participant_id")) %>%
    filter(response_id %in% pids)
}
w1 <- merge_wave(cs1, pids1)
w2 <- merge_wave(cs2, pids2)

# Bin age into the same 8 ranges Python's dems.ipynb uses.
add_age_range <- function(df) {
  df %>% mutate(
    .age_num = suppressWarnings(as.numeric(Age)),
    `Age Range` = cut(.age_num,
                      breaks = c(17, 24, 34, 44, 54, 64, 74, 84, 100),
                      labels = c("18–24", "25–34", "35–44",
                                 "45–54", "55–64", "65–74",
                                 "75–84", "85+"),
                      right = TRUE, include.lowest = FALSE)
  )
}

w1 <- add_age_range(w1)
w2 <- add_age_range(w2)

# Collapse the 12 detailed Connect race subgroups into the 6 standard
# high-level categories ACS reports (White, Black, Asian, NHPI, AI/AN,
# Other/Two-or-more). Matches the ACS DP05 grouping for direct comparison.
collapse_race <- function(df) {
  df %>% mutate(Race = case_when(
    Race == "White"                              ~ "White",
    Race == "Black or African American"          ~ "Black or African American",
    Race == "American Indian or Alaska Native"   ~ "American Indian or Alaska Native",
    Race %in% c("Chinese", "Vietnamese", "Filipino",
                "Korean", "Asian Indian", "Japanese") ~ "Asian",
    Race %in% c("Hawaiian", "Samoan")            ~ "Native Hawaiian or Pacific Islander",
    Race == "An ethnicity not listed here"       ~ "Other / Not listed",
    TRUE                                          ~ Race
  ))
}
w1 <- collapse_race(w1)
w2 <- collapse_race(w2)

# Collapse the 5 Connect Ethnicity subcategories (one "No" + four Hispanic
# subgroups: Mexican, Puerto Rican, Cuban, other) into a clean
# Hispanic-or-Latino / Non-Hispanic binary, matching the Census convention
# of treating Hispanic origin as a single yes/no dimension separate from race.
collapse_ethnicity <- function(df) {
  df %>% mutate(Ethnicity = case_when(
    Ethnicity == "No, not of Hispanic, Latino, or Spanish origin" ~ "Non-Hispanic",
    startsWith(Ethnicity, "Yes")                                   ~ "Hispanic or Latino",
    TRUE                                                            ~ Ethnicity
  ))
}
w1 <- collapse_ethnicity(w1)
w2 <- collapse_ethnicity(w2)

# For each demographic column, compute count + percent within wave.

demo_blocks <- c("Age Range", "Education", "Sex", "Race", "Ethnicity")

build_wave_summary <- function(df, wave_n) {
  map_dfr(demo_blocks, function(col) {
    df %>%
      count(.data[[col]], name = "Count") %>%
      mutate(Category = col,
             Value = as.character(.data[[col]]),
             Percent = round(100 * Count / wave_n, 1)) %>%
      select(Category, Value, Count, Percent)
  })
}

s1 <- build_wave_summary(w1, nrow(w1))
s2 <- build_wave_summary(w2, nrow(w2))
s1 %>% count(Category, Value)
s1 %>% filter(Category=="Education")
# ---- Label cleanup (Connect long labels -> SI short labels) -------------

label_map <- c(
  "Bachelor's degree (for example: BA, AB, BS)"                                                = "Bachelor's degree",
  "Master's degree (for example: MA, MS, MEng, MEd, MSW, MBA)"                                 = "Master's degree",
  "Doctorate degree (for example: PhD, EdD)"                                                   = "Doctorate degree",
  "Professional degree (for example: MD, DDS, DVM, LLB, JD)"                                   = "Professional degree (MD, JD)",
  "Associate degree (for example: AA, AS)"                                                     = "Associate degree",
  "Some college, but no degree"                                                                = "Some college, no degree",
  "High school graduate - high school diploma or the equivalent (for example: GED)"            = "High school graduate (GED)",
  "Less than a high school diploma"                                                            = "Less than high school",
  "An ethnicity not listed here"                                                               = "Other / Not listed",
  "Not in paid work (e.g., homemaker, disabled)"                                               = "Not in paid work"
)

shorten <- function(x) ifelse(x %in% names(label_map), label_map[x], x)

s1 <- s1 %>% mutate(Value = shorten(Value))
s2 <- s2 %>% mutate(Value = shorten(Value))

# ---- Block + row ordering matching SI S13 (lines 480-531) ---------------

block_order <- c("Age Range", "Education", "Sex", "Political Party",
                 "Race", "Ethnicity")

row_order <- list(
  "Age Range" = c("18–24", "25–34", "35–44", "45–54",
                  "55–64", "65–74", "75–84", "85+"),
  "Education" = c("Doctorate degree", "Professional degree (MD, JD)",
                  "Master's degree", "Bachelor's degree", "Associate degree",
                  "Some college, no degree", "High school graduate (GED)",
                  "Less than high school", "No formal education",
                  "Prefer not to say"),
  "Sex" = c("Male", "Female", "Prefer not to say"),
  # Political Party uses Pew-comparable WITH-LEANER classification (3 rows),
  # not the original 5-row Connect own-ID block. See `party_leaner` below.
  "Political Party" = c("Republican (incl. lean)",
                        "Democrat (incl. lean)",
                        "Pure Independent"),
  # Race uses the 6 standard ACS high-level categories instead of Connect's
  # 12-subgroup breakdown. See collapse_race() above.
  "Race" = c("White", "Black or African American", "Asian",
             "Native Hawaiian or Pacific Islander",
             "American Indian or Alaska Native", "Other / Not listed"),
  # Ethnicity is a separate Census dimension from Race (Hispanic origin).
  # Collapsed from Connect's 5 subcategories — see collapse_ethnicity() above.
  "Ethnicity" = c("Hispanic or Latino", "Non-Hispanic")
)


# ---- Compute the with-leaner Political Party block ---------------------
# Pew reports party ID with a follow-up leaner question. The survey has the
# same construct (party_id_lean), so we collapse the original 5-row own-ID

classify_leaner <- function(df) {
  df %>% mutate(party_lean_inc = case_when(
    party_id_imputation == "Republican" ~ "Republican (incl. lean)",
    party_id_imputation == "Democrat"   ~ "Democrat (incl. lean)",
    is.na(party_id_imputation)          ~ "Pure Independent",
    party_id == "Prefer not to say"     ~ "Prefer not to say",
    TRUE                                ~ "Other"
  ))
}

count_leaner <- function(df, wave_n) {
  df <- classify_leaner(df)
  df %>%
    count(party_lean_inc) %>%
    mutate(pct = round(100 * n / wave_n, 1))
}

p1 <- count_leaner(w1, 601) %>%
  transmute(Value = party_lean_inc, s1_count = n, s1_pct = pct)
p2 <- count_leaner(w2, 606) %>%
  transmute(Value = party_lean_inc, s2_count = n, s2_pct = pct)

party_leaner <- tibble(
  Category = "Political Party",
  Value = c("Republican (incl. lean)", "Democrat (incl. lean)", "Pure Independent")
) %>%
  left_join(p1, by = "Value") %>%
  left_join(p2, by = "Value") %>%
  mutate(
    s1_count = replace_na(s1_count, 0), s1_pct = replace_na(s1_pct, 0),
    s2_count = replace_na(s2_count, 0), s2_pct = replace_na(s2_pct, 0)
  )

# ---- Restrict to the six blocks the SI table uses -----------------------
s1_six <- s1 %>% filter(Category %in% block_order, Category != "Political Party") %>%
  rename(s1_count = Count, s1_pct = Percent) %>%
  bind_rows(party_leaner %>% select(Category, Value, s1_count, s1_pct))
s2_six <- s2 %>% filter(Category %in% block_order, Category != "Political Party") %>%
  rename(s2_count = Count, s2_pct = Percent) %>%
  bind_rows(party_leaner %>% select(Category, Value, s2_count, s2_pct))

# Render NA Employment-Status as "(blank)" so the row matches the SI
s1_six <- s1_six %>% mutate(Value = ifelse(is.na(Value), "(blank)", Value))
s2_six <- s2_six %>% mutate(Value = ifelse(is.na(Value), "(blank)", Value))

# Build the full row inventory in the SI order, then left-join in the counts
full_rows <- imap_dfr(row_order, function(values, cat) {
  tibble(Category = cat, Value = values)
})

tab <- full_rows %>%
  left_join(s1_six %>% select(Category, Value, s1_count, s1_pct),
            by = c("Category", "Value")) %>%
  left_join(s2_six %>% select(Category, Value, s2_count, s2_pct),
            by = c("Category", "Value")) %>%
  mutate(
    s1_count = replace_na(s1_count, 0),
    s2_count = replace_na(s2_count, 0),
    s1_pct   = replace_na(s1_pct, 0),
    s2_pct   = replace_na(s2_pct, 0),
    total_count = s1_count + s2_count,
    total_pct   = round(100 * total_count / (sum(s1_six$s1_count[s1_six$Category == "Sex"])
                                             + sum(s2_six$s2_count[s2_six$Category == "Sex"])), 1)
  )

# Sanity: each Category's total counts should add to the wave Ns (601 / 606).
# Use Sex (no NA) to fix denominators; Age sums match too.
n_s1 <- 601
n_s2 <- 606
n_tot <- n_s1 + n_s2
tab <- tab %>% mutate(total_pct = round(100 * total_count / n_tot, 1))


# ---- General-population reference values (one column, to be added with
# add_columns to datasummary_balance below) -------------------------------
# Sources verified 2026-05-13:
#  - ACS 1-year 2024 (US Census Bureau, released 2025-09-11) for Age, Education,
#    Sex, Employment.
#  - Census Population Estimates Program (Vintage 2024) for Race
#    (race-alone, NOT Hispanic-adjusted; White ≈ 75% incl. Hispanic Whites).
#  - Census 2024 for Ethnicity (Hispanic or Latino origin).
#  - Pew Research NPORS, fielded Feb-Jun 2025, for Political Party (with-leaner).
# "---" = no clean US-population analog (e.g., "Prefer not to say", or rows
# collapsed into a different ACS bucket reported on the topmost row).
gen_pop <- tribble(
  ~Category,           ~Value,                                  ~gen_pop_pct,
  "Age Range",         "18–24",                            11.7,
  "Age Range",         "25–34",                            17.3,
  "Age Range",         "35–44",                            17.2,
  "Age Range",         "45–54",                            15.3,
  "Age Range",         "55–64",                            15.6,
  "Age Range",         "65–74",                            13.3,
  "Age Range",         "75–84",                            7.2,
  "Age Range",         "85+",                                   2.4,
  # ACS combines Doctorate/Professional/Master's into "Graduate or professional
  # degree" (14.7%); reported once on the topmost row.
  "Education",         "Doctorate degree",                      14.7,
  "Education",         "Professional degree (MD, JD)",          NA_real_,
  "Education",         "Master's degree",                       NA_real_,
  "Education",         "Bachelor's degree",                     22.1,
  "Education",         "Associate degree",                      8.8,
  "Education",         "Some college, no degree",               18.5,
  "Education",         "High school graduate (GED)",            25.7,
  "Education",         "Less than high school",                 10.1,
  "Education",         "No formal education",                   NA_real_,
  "Education",         "Prefer not to say",                     NA_real_,
  "Sex",               "Male",                                  49.0,
  "Sex",               "Female",                                51.0,
  "Sex",               "Prefer not to say",                     NA_real_,
  # Pew with-leaner classification: own-ID Republicans/Democrats + leaners.
  "Political Party",   "Republican (incl. lean)",               46.0,
  "Political Party",   "Democrat (incl. lean)",                 45.0,
  "Political Party",   "Pure Independent",                      9.0,
  # Census 2024 PEP, race-alone (includes Hispanic).
  "Race",              "White",                                 75.3,
  "Race",              "Black or African American",             13.7,
  "Race",              "Asian",                                 6.4,
  "Race",              "Native Hawaiian or Pacific Islander",   0.3,
  "Race",              "American Indian or Alaska Native",      1.3,
  "Race",              "Other / Not listed",                    3.0,
  "Ethnicity",         "Hispanic or Latino",                    19.5,
  "Ethnicity",         "Non-Hispanic",                          80.5
)

# Build the Gen-Pop column in the exact factor-level order that
# datasummary_balance(~Wave, data = respondent_df) will produce rows for.
gen_pop_col_values <- character(0)
for (cat in c("Age Range", "Education", "Sex", "Political Party",
              "Race", "Ethnicity", "Employment Status")) {
  for (val in row_order[[cat]]) {
    pct <- gen_pop$gen_pop_pct[gen_pop$Category == cat & gen_pop$Value == val]
    if (length(pct) == 0L || is.na(pct)) {
      gen_pop_col_values <- c(gen_pop_col_values, "---")
    } else {
      gen_pop_col_values <- c(gen_pop_col_values, sprintf("%.1f", pct))
    }
  }
}
gen_pop_addcol <- tibble(`Gen Pop %` = gen_pop_col_values)

# ---- Save CSV -----------------------------------------------------------
tab_ordered <- tab %>%
  mutate(Category = factor(Category, levels = block_order)) %>%
  mutate(.row_idx = map2_int(Category, Value, function(cat, val) {
    rl <- row_order[[as.character(cat)]]
    match(val, rl)
  })) %>%
  arrange(Category, .row_idx) %>%
  select(-.row_idx) %>%
  left_join(gen_pop, by = c("Category", "Value"))

write_csv(tab_ordered %>% select(Category, Value,
                                 s1_count, s1_pct,
                                 s2_count, s2_pct,
                                 total_count, total_pct,
                                 gen_pop_pct),
          here("output", "tab_s13_demographics_with_genpop.csv"))

# ---- Build LaTeX via kableExtra (kbl + pack_rows + threeparttable) ------

pacman::p_load(kableExtra)

# Helpers — convert en-dash Unicode to LaTeX -- so source matches existing SI
latex_endash <- function(s) gsub("–", "--", s, fixed = TRUE)

# Display data frame: Value + 7 numeric/cell columns (Category becomes a
# pack_rows group header rather than a data column).
display <- tab_ordered %>%
  mutate(
    Value     = latex_endash(as.character(Value)),
    s1_pct    = sprintf("%.1f", s1_pct),
    s2_pct    = sprintf("%.1f", s2_pct),
    total_pct = sprintf("%.1f", total_pct),
    gen_cell  = ifelse(is.na(gen_pop_pct), "---", sprintf("%.1f", gen_pop_pct))
  ) %>%
  select(Value, s1_count, s1_pct, s2_count, s2_pct,
         total_count, total_pct, gen_cell)

# pack_rows boundaries — one row range per Category.
# Re-factor Category so group_by respects the block_order (left_join above
# converted Category back to character, so group_by would otherwise sort
# alphabetically, scrambling the pack_rows positions).
cat_sizes <- tab_ordered %>%
  mutate(Category = factor(Category, levels = block_order)) %>%
  group_by(Category) %>%
  summarise(n = n(), .groups = "drop") %>%
  arrange(Category) %>%
  mutate(start = cumsum(c(1L, head(n, -1))),
         end   = cumsum(n))

footnote_text <- paste(
  "Sources: Survey 1 (X/YouTube wave, $n = 601$) and Survey 2 (TikTok/Truth Social wave, $n = 606$).",
  "General population reference values are from US Census Bureau (ACS 1-year 2024, Population Estimates Program 2024) for age, education, sex, race, ethnicity, and employment;",
  "Pew Research NPORS (fielded February--June 2025) for political party (with-leaner classification)."
)

kab <- kbl(
  display,
  format    = "latex",
  booktabs  = TRUE,
  escape    = FALSE,
  caption   = "Demographic characteristics of Survey 1 and Survey 2 compared with the US adult general population.",
  label     = "combined_demo",
  col.names = c("Value", "Count", "\\%", "Count", "\\%", "Count", "\\%", "\\%"),
  align     = c("l", rep("r", 7)),
  linesep   = ""
) %>%
  add_header_above(
    c(" " = 1, "Survey 1" = 2, "Survey 2" = 2, "Total" = 2, "Gen Pop" = 1),
    bold = TRUE, escape = FALSE
  ) %>%
  kable_styling(latex_options = c("hold_position"), font_size = 8)

# Pack_rows for each demographic block
for (i in seq_len(nrow(cat_sizes))) {
  kab <- pack_rows(
    kab,
    group_label = as.character(cat_sizes$Category[i]),
    start_row   = cat_sizes$start[i],
    end_row     = cat_sizes$end[i],
    bold        = TRUE, italic = FALSE, escape = FALSE
  )
}

# Inject threeparttable wrapper + tablenotes manually (kableExtra::footnote
# mangles backslashes, and sub()'s regex-replacement does the same — so we
# splice by position).
kab_str <- as.character(kab)
tablenotes_block <- paste0(
  "\\begin{tablenotes}[para,flushleft]\n",
  "\\footnotesize\n",
  "\\item \\textit{Notes:} ", footnote_text, "\n",
  "\\end{tablenotes}\n"
)

beg_re <- "\\\\begin\\{tabular\\}"
end_re <- "\\\\end\\{tabular\\}"
beg_m <- regexpr(beg_re, kab_str)
end_m <- regexpr(end_re, kab_str)
end_close <- end_m + attr(end_m, "match.length") - 1L

before_tabular <- substr(kab_str, 1L, beg_m - 1L)
tabular_block  <- substr(kab_str, beg_m, end_close)
after_tabular  <- substr(kab_str, end_close + 1L, nchar(kab_str))

kab_str <- paste0(
  before_tabular,
  "\\begin{threeparttable}\n",
  tabular_block, "\n",
  tablenotes_block,
  "\\end{threeparttable}",
  after_tabular
)

writeLines(kab_str, here("output", "tab_s13_demographics_with_genpop.tex"))
