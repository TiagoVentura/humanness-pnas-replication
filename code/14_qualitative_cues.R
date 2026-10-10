##############################################################################
# File-Name: 14_qualitative_cues.R
# author: Sejin Paik
# Purpose: Code the open-ended responses on the cues used to judge authorship
#          and cross-tabulate cue by direction. Produces SI Figure S4 and
#          output/summary_A_to_E.csv.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
pacman::p_load(readxl, dplyr, stringr, tidyr, tibble, janitor, readr,
               purrr, ggplot2, forcats, rlang, scales)

# ---- paths ----
setwd(here::here())
xlsx_path <- "data/OE_Humanness.xlsx"
out_dir   <- "output"

if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!file.exists(xlsx_path)) stop("File not found: ", xlsx_path)

# ---- read (headers already in row 1) ----
sheets <- readxl::excel_sheets(xlsx_path)
sheet_name <- if ("All" %in% sheets) "All" else sheets[[1]]

raw <- readxl::read_excel(xlsx_path, sheet = sheet_name, guess_max = 5000) %>%
  janitor::clean_names()

if (!"oe_cues" %in% names(raw)) {
  stop("Column 'oe_cues' not found. Columns present are:\n", paste(names(raw), collapse = ", "))
}

# Optional: ID column (used if present)
id_col <- names(raw)[stringr::str_detect(names(raw), "^(response_id|responseid|id)$")]
id_col <- if (length(id_col)) id_col[[1]] else NA_character_

# Source text (character + blanks handled)
df <- raw %>%
  mutate(oe_text = as.character(.data[["oe_cues"]])) %>%
  mutate(oe_text = ifelse(is.na(oe_text), "", oe_text))

# ================================
# Codebooks
# ================================
cue_taxonomy <- tibble::tribble(
  ~code, ~label,
  1L, "Length of post",
  2L, "Grammar",
  3L, "Emojis/hashtags/symbols",
  4L, "Slang/abbreviations",
  5L, "Emotional language",
  6L, "Ideological stance",
  7L, "Content depth/specificity",
  8L, "Logic/coherence",
  9L, "Other"
)
direction_map <- tibble::tribble( ~code, ~label, 1L,"AI", 2L,"Human", 3L,"Unclear" )
subflag_map   <- tibble::tribble( ~code, ~label, 0L,"None", 1L,"Link presence", 2L,"Profanity", 3L,"AI refusal", 4L,"Platform norm comment", 5L,"Gut feeling" )
confidence_map<- tibble::tribble( ~code, ~label, 1L,"Low", 2L,"Medium", 3L,"High" )

# ================================
# Regex patterns & helpers (NA/blank-safe)
# ================================
pat_cues <- list(
  length       = "\\b(long|length|short|brief|concise|wordy)\\b",
  grammar      = "grammar|spelling|punctuation|capitalization|typo|syntax|run[- ]?on",
  symbols      = "emoji|emoticon|#|hashtag|@\\w+|mention|symbol|link|http[s]?://|www\\.|\\.com\\b",
  slang        = "\\b(lol|lmao|fr\\b|idk|imo|irl|btw|smh|stan|copypasta|slang|abbrev|acronym)\\b",
  emotion      = "emotional|emotion|feeling|angr(y|er)|sad|excited|sarcasm|sarcastic|humor|funny|tone|passion|empath",
  ideology     = "politic|liberal|conservative|left|right|democrat|republican|partisan|religio|ideolog|moral",
  specificity  = "specific|detail|example|anecdote|personal|story|concrete|fact|evidence|stat\\b|stats\\b|number|data|source",
  coherence    = "logic|coherent|coherence|flow|reason|contradic|structure|organized|repetit|redundan|template|too tidy",
  other        = ""
)
cue_code_map <- c(length=1L, grammar=2L, symbols=3L, slang=4L, emotion=5L, ideology=6L, specificity=7L, coherence=8L)

pat_dir_ai   <- "\\b(ai|bot|robot(ic)?|chatgpt|llm|generated|automated|too perfect|robotic|machine)\\b"
pat_dir_hum  <- "\\b(human|person|real person|genuine|authentic|sounds like someone)\\b"

pat_link     <- "http[s]?://|www\\.|\\b(link|url)\\b|\\.com\\b"
pat_prof     <- "\\b(fuck|shit|bitch|asshole|dumbass|bastard|cunt|motherfucker|bullshit)\\b"
pat_refusal  <- "as an ai|i cannot|i can't|i can\\s?not|unable to|i am unable|i'm unable|i do not have the ability"
pat_platform <- "\\b(twitter|\\bX\\b|tiktok|youtube|truth\\s?social|platform|subreddit)\\b"
pat_gut      <- "\\bgut|vibe|intuition|just a feeling|felt fake|seemed (ai|human)|i guess|hard to tell\\b"
pat_hedge    <- "\\b(maybe|probably|perhaps|seems|appears|i think|not sure|could be|might be|hard to tell)\\b"

normalize <- function(x) {
  x <- if (is.na(x)) "" else x
  x %>%
    stringr::str_replace_all("[\\r\\n]+", " ") %>%
    stringr::str_squish() %>%
    stringr::str_to_lower()
}

suggest_direction <- function(txt) {
  t <- normalize(txt)
  ai <- stringr::str_detect(t, pat_dir_ai)
  hu <- stringr::str_detect(t, pat_dir_hum)
  if (ai & !hu) return(1L)
  if (hu & !ai) return(2L)
  3L
}

# Always return integers
suggest_cues_top2 <- function(txt) {
  t <- normalize(txt)
  hits <- purrr::map_lgl(pat_cues[names(cue_code_map)], ~ stringr::str_detect(t, .x))
  if (!any(hits)) return(as.integer(c(9, 0)))
  idx <- names(which(hits))
  as.integer(c(cue_code_map[idx[1]], if (length(idx) >= 2) cue_code_map[idx[2]] else 0))
}

suggest_subflag <- function(txt) {
  t <- normalize(txt)
  if (stringr::str_detect(t, pat_link))     return(1L)
  if (stringr::str_detect(t, pat_prof))     return(2L)
  if (stringr::str_detect(t, pat_refusal))  return(3L)
  if (stringr::str_detect(t, pat_platform)) return(4L)
  if (stringr::str_detect(t, pat_gut))      return(5L)
  0L
}

suggest_confidence <- function(txt) {
  t <- normalize(txt)
  has_cue <- any(purrr::map_lgl(pat_cues[names(cue_code_map)], ~ stringr::str_detect(t, .x)))
  has_dir <- stringr::str_detect(t, pat_dir_ai) | stringr::str_detect(t, pat_dir_hum)
  hedged  <- stringr::str_detect(t, pat_hedge)
  if (has_cue & has_dir & !hedged & nchar(t) >= 40) return(3L)
  if ((has_cue | has_dir) & (!hedged | nchar(t) >= 25)) return(2L)
  1L
}

snippet <- function(txt, n = 120) {
  t <- gsub("[\\r\\n]+", " ", paste0(ifelse(is.na(txt), "", txt)))
  t <- stringr::str_squish(t)
  if (nchar(t) <= n) return(t)
  paste0(substr(t, 1, n - 1), "…")
}

# ================================
# Apply to data (oe_text -> A–E)
# ================================
df <- df %>%
  mutate(
    cues_pair    = purrr::map(oe_text, ~ if (!nzchar(.x)) as.integer(c(9, 0)) else suggest_cues_top2(.x)),
    A_direction  = ifelse(!nzchar(oe_text), 3L, vapply(oe_text, suggest_direction, integer(1))),
    B_cue1       = purrr::map_int(cues_pair, ~ as.integer(.x[1])),
    C_cue2       = purrr::map_int(cues_pair, ~ as.integer(.x[2])),
    D_subflag    = ifelse(!nzchar(oe_text), 0L, vapply(oe_text, suggest_subflag, integer(1))),
    E_confidence = ifelse(!nzchar(oe_text), 1L, vapply(oe_text, suggest_confidence, integer(1))),
    evidence_snippet = ifelse(!nzchar(oe_text), "", vapply(oe_text, snippet, character(1)))
  ) %>%
  { if (!is.na(id_col)) select(., any_of(id_col), oe_text, A_direction, B_cue1, C_cue2, D_subflag, E_confidence, evidence_snippet)
    else                 select(., oe_text, A_direction, B_cue1, C_cue2, D_subflag, E_confidence, evidence_snippet) }


# ================================
# Descriptive Statistics (A–E) with % strings
# ================================
freq_table <- function(data, var, codebook) {
  v <- rlang::ensym(var)
  base <- data %>% count(!!v, name="n")
  base <- base %>% mutate(pct = scales::percent(n / sum(n), accuracy = 0.1))
  base %>% left_join(codebook, by = setNames("code", rlang::as_name(v))) %>%
    select(code = !!v, label, n, pct)
}

dir_cb  <- direction_map
cue_cb  <- cue_taxonomy
cue0_cb <- dplyr::bind_rows(tibble::tibble(code = 0L, label = "None (no secondary cue)"), cue_taxonomy)
sub_cb  <- subflag_map
conf_cb <- confidence_map

tab_A <- freq_table(df, A_direction, dir_cb)
tab_B <- freq_table(df, B_cue1, cue_cb)
tab_C <- freq_table(df, C_cue2, cue0_cb)
tab_D <- freq_table(df, D_subflag, sub_cb)
tab_E <- freq_table(df, E_confidence, conf_cb)

dplyr::bind_rows(
  tab_A %>% mutate(variable = "A_direction"),
  tab_B %>% mutate(variable = "B_cue1"),
  tab_C %>% mutate(variable = "C_cue2"),
  tab_D %>% mutate(variable = "D_subflag"),
  tab_E %>% mutate(variable = "E_confidence")
) %>%
  select(variable, code, label, n, pct) %>%
  arrange(variable, desc(n)) %>%
  readr::write_csv(file.path(out_dir, "summary_A_to_E.csv"))

# Heatmap Cue1 x Direction (with counts)
heat_df <- df %>%
  count(B_cue1, A_direction, name = "n") %>%
  left_join(cue_taxonomy,  by = c("B_cue1" = "code")) %>%
  left_join(direction_map, by = c("A_direction" = "code")) %>%
  mutate(label_cue = label.x, label_dir = label.y)

p_heat <- ggplot(heat_df, aes(x = label_dir, y = label_cue, fill = n)) +
  geom_tile(color = "white") +
  geom_text(aes(label = n), size = 3) +
  scale_fill_gradient(low = "#f0f0f0", high = "#084594") +
  labs(x = "Direction (A)", y = "Cue 1 (B)", title = "Counts: Cue 1 × Direction") +
  theme_minimal(base_size = 12)

ggsave(file.path(out_dir, "fig4_qual.png"), p_heat, width = 9, height = 6.5, dpi = 150)
