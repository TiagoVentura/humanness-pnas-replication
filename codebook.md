# Codebook

Variable-level documentation for the datasets in `data/`. Question wording and response options follow the survey instruments reproduced in SI section S11. Numeric survey items keep the Qualtrics export coding (1 = first option listed in the instrument unless noted). Value ranges and levels below were read from the shipped files.

Identifiers. `response_id`, `fu_response_id`, `main_response_id` are Qualtrics response tokens (`R_...`). `participant_id` (and `ParticipantId`, `participantId` in the raw files) is a salted hash of the CloudResearch Connect ID, consistent across every file, so all joins work; the original ID cannot be recovered from the package. IP address, geolocation, recipient name/email, external reference and free-text feedback fields were removed from every survey file before packaging.

---

## 1. `pairs_survey_clean.csv`

Primary analysis file. One row per respondent x pair x side (left/right post), so each pairwise comparison contributes two rows. 72,420 rows, 72 columns. Built by `03_merge_response_pairs_surveys.R` from `pairs_data_*.csv` and `survey_cleaned.csv`.

### 1a. Pairwise task (from `01_clean_text_pairs.R`)

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `response_id` | chr | 1,207 unique | Qualtrics response token for the respondent |
| `text_id` | int | 1-600 | Post identifier, platform-local (restarts for each platform) |
| `order` | int | 1-15 | Position of the pair in the platform block (pair 10 is the attention check) |
| `response` | chr | Left, Right | Side of the pair this row describes (Post A = Left, Post B = Right) |
| `platform` | chr | TikTok, Truth Social, X/Twitter, YouTube | Platform pool the pair was drawn from |
| `att_check` | int | 0, 1; NA | Attention-check pair (order 10) only: 1 = failed (chose Left), 0 = passed; NA for other pairs |
| `binary_response` | int | 0, 1 | 1 if the respondent picked this post as the AI-generated one, 0 for the other post of the pair |
| `att_check_sum` | int | 0, 15, 30 | Respondent-level count of failed attention-check rows (0 = passed both blocks; analysis keeps `att_check_sum == 0`) |
| `source` | chr | AI, Human | Whether this post is human-authored or LLM-generated |
| `persona` | chr | conservative, liberal, libertarian-populist, moderate, progressive commentator (two capitalisations in the raw files); NA | Political persona prompt used to generate the post; NA for human posts |
| `post` | chr | 2,383 unique texts | Post text as shown to the respondent (handles masked as `@USER`) |

### 1b. Respondent survey (from `02_clean_survey_data.R`)

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `participant_id` | chr | 32-hex hash | Hashed Connect ID (merge key to Connect demographics and follow-up) |
| `politics` | int | 1-5 | Political attention: 1 = Extremely closely ... 5 = Not at all |
| `news_trust_newspapers` ... `news_trust_national_news_org` | int | 1, 2, 3, 4, 6 | Trust in news from each source: 1 = Not at all, 2 = A little, 3 = Some, 4 = Quite a lot, 6 = All the time (Qualtrics code for the fifth option) |
| `party_id` | chr | Democrat, Independent, Republican, Something else | Party identification |
| `party_id_lean` | chr | Democrat, Neither, Republican; NA | Party lean, asked only of Independents / Something else |
| `ideo_place_self` | int | 1-7 | Ideology: 1 = Very liberal ... 4 = Moderate ... 7 = Very conservative |
| `conspiracies_1` ... `conspiracies_4` | int | 1-5 | Agreement with four conspiracy-belief statements: 1 = Strongly disagree ... 5 = Strongly agree |
| `sm_cynicism_1` ... `sm_cynicism_4` | int | 1-7 | Social media cynicism items, recoded to 1 = Strongly disagree ... 7 = Strongly agree (item 4 is reverse-worded: confidence in finding the truth) |
| `news_tv`, `news_radio`, `news_newspapers`, `news_websites`, `news_friends`, `news_fb`, `news_x`, `news_tt`, `news_yt` | int | 1-5 | Frequency of using each source for news: 1 = Never, 2 = Sometimes, 3 = About half the time, 4 = Most of the time, 5 = Always |
| `oe_multiple_1` ... `oe_multiple_6` | int | 1-5 | Rated importance of cues for judging humanness (length, grammar, emojis/symbols/hashtags, slang, emotional language, ideological stance): 1 = Not important ... 5 = Extremely important |
| `study` | chr | yt-tw, ts-tt | Survey wave: Survey 1 (YouTube + X/Twitter) or Survey 2 (Truth Social + TikTok) |
| `socialmedia_usage_1` ... `socialmedia_usage_7` | int | 1-5; NA | Survey 2 only. Frequency of using YouTube, TikTok, X, Truth Social, Instagram, Facebook, Reddit (order as in the instrument); NA for Survey 1 |

### 1c. Connect demographics (merged by `participant_id`)

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `age` | int | 18-83 | Age in years (Connect profile) |
| `age_group` | chr | <25, 25-44, 45-64, 65+ | Age bracket |
| `education_num` | int | 0-4; NA | 0 = less than high school, 1 = high school, 2 = some college / associate, 3 = bachelor's, 4 = graduate or professional degree |
| `education_cat` | chr | No College Degree, College Degree, Post-Graduate Degree; NA | Collapsed education |
| `sex` | chr | Female, Male; NA | Sex (Connect profile; other responses set to NA) |
| `party_connect` | chr | Democrat, Independent, Other, Republican | Party as recorded in the Connect profile |
| `hispanic` | int | 0, 1 | 1 = Hispanic, Latino or Spanish origin |
| `white` | chr | White, Non-White | Race (Connect profile) collapsed to white vs non-white |
| `household_income` | chr | 17 brackets from "Less than $10,000" to "$250,000 or more", plus "Prefer not to say"; NA | Household income bracket |
| `income_num` | int | 0-16; NA | Income bracket as an ordinal code (0 = lowest); NA for "Prefer not to say" |

### 1d. Derived indices

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `trust_news` | num | 1-6 | Mean of the six news-trust items |
| `trust_news_reescaled` | num | z-score | `trust_news` standardised across respondents |
| `party_id_imputation` | chr | Democrat, Republican; NA | Party with leaners assigned to the party they lean toward; NA for "Neither" |
| `conspiratory_beliefs` | num | 1-5 | Mean of the four conspiracy items |
| `conspiratory_beliefs_reescaled` | num | z-score | Standardised `conspiratory_beliefs` |
| `cyn_beliefs` | num | 1.5-7 | Mean of the four cynicism items |
| `cyn_beliefs_reescaled` | num | z-score | Standardised `cyn_beliefs` |
| `news_cons` | int | 9-45 | Sum of the nine news-consumption items |
| `news_cons_reescaled` | num | z-score | Standardised `news_cons` |

---

## 2. `survey_cleaned.csv`

One row per respondent. 1,207 rows, 62 columns. Output of `02_clean_survey_data.R`. Contains `response_id`, `participant_id`, and every variable in sections 1b-1d above with identical coding.

---

## 3. `followup_ai_clean.csv`

One row per follow-up respondent (May 2026 recontact). 724 rows, 49 columns. Output of `05_prep_followup_data.R`. Demographics are carried over from `survey_cleaned.csv`.

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `participant_id` | chr | 32-hex hash | Hashed Connect ID (merge key to the main study) |
| `fu_response_id` | chr | 724 unique | Qualtrics response token, follow-up survey |
| `main_response_id` | chr | 723 unique; 1 NA | Qualtrics response token of the same person in the main study |
| `white`, `sex`, `age_group`, `education_cat`, `hispanic`, `party_id_imputation` | | as in section 1c-1d | Demographics from the main study |
| `ai_freq` | int | 1-7 | AI chatbot use frequency: 1 = Never, 2 = About once a year, 3 = Several times a year, 4 = About once a month, 5 = Several times a month, 6 = Once or twice a week, 7 = Almost every day |
| `ai_freq_chatgpt`, `ai_freq_gemini`, `ai_freq_copilot`, `ai_freq_grok`, `ai_freq_metaai`, `ai_freq_claude`, `ai_freq_deepseek`, `ai_freq_perplexity` | int | 1-8; NA | Use frequency per chatbot: 1 = Never ... 7 = Almost every day, 8 = Multiple times a day; NA for respondents who answered Never at the gate |
| `tool_breadth` | int | 0-8 | Number of the eight chatbots used at all (frequency above Never); 0 for non-users |
| `ai_timing` | int | 1-5; NA | When the respondent started using AI chatbots: 1 = Never, 2 = This year (2026), 3 = Last year (2025), 4 = Two years ago (2024), 5 = 2023 or earlier |
| `ai_timing_users` | int | 2-5; NA | `ai_timing` with non-users set to NA |
| `ai_never` | lgl | TRUE/FALSE | `ai_freq == 1` |
| `heavy_user` | lgl | TRUE/FALSE | `ai_freq >= 6` (weekly or more) |
| `early_adopter` | lgl | TRUE/FALSE | `ai_timing == 5` (2023 or earlier) |
| `purpose_politics_news`, `purpose_info_qa`, `purpose_work_edu`, `purpose_creative`, `purpose_entertainment`, `purpose_companionship`, `purpose_health`, `purpose_shopping`, `purpose_travel`, `purpose_other` | int | 0, 1 | Select-all purposes of AI use, one flag per option in instrument order |
| `purpose_missing` | int | 0, 1 | 1 if the purpose item was skipped (mostly non-users) |
| `ai_confidence` | int | 1-5 | Confidence in detecting AI content: 1 = Not confident at all ... 5 = Extremely confident |
| `ai_importance` | int | 1-5 | Importance of being able to tell AI from human content: 1 = Not at all ... 5 = Extremely important |
| `ai_sentiment` | int | 1-3 | 1 = More concerned than excited, 2 = Equally, 3 = More excited than concerned |
| `ai_social_awareness` | int | 1-5 | How often the respondent considers whether social media content is AI-made: 1 = Never ... 5 = Always |
| `human_pref` | int | 1-5 | Preference for human-created content: 1 = None at all ... 5 = A great deal |
| `news_aichatbot` | int | 1-5 | Frequency of using AI chatbots as a news source: 1 = Never ... 5 = Always |
| `dlit_recalgo`, `dlit_clickbait`, `dlit_phishing`, `dlit_shadowban`, `dlit_contentmod` | int | 1-5 | Familiarity with each digital-literacy item: 1 = Not familiar at all ... 5 = Extremely familiar |
| `dlit_index` | num | 1-5 | Mean of the five digital-literacy items |
| `att_check` | int | 3, 4, 5; NA | Raw attention-check answer code (3 = President Obama, the correct option) |
| `att_pass` | lgl | TRUE/FALSE | `att_check == 3` |

---

## 4. `bt_scores/bt_{x,yt,tt,ts}_posts_rankings_with_source_persona_inverted.csv`

One row per post, one file per platform (x = X/Twitter 593 rows, yt = YouTube 600, tt = TikTok 600, ts = Truth Social 593). Produced by `code/python/*/2_bradley_terry.ipynb` from the pairwise judgements. Same seven columns in each file.

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `Text` | chr | | Post text |
| `Text_ID` | int | 1-600 | Post identifier, platform-local |
| `Ability` | num | unbounded (e.g. -2.8 to 20.1 for X) | Bradley-Terry log-ability estimate from a binomial GLM, reference post fixed at 0 |
| `Normalized Ability` | num | -1 to 1 | Rank-normalised ability, sign-flipped so higher = more human-like. This is the PHI score used throughout the paper |
| `source` | chr | LLM name; NA | Generating model for AI posts (raw names: `gpt_4`, `gpt_4o_fall`/`gpt_4o`, `gpt4o-mini`/`gpt_4omini`/`gpt_4o_mini`, `llama2_70b`, `llama3_2_3b`, `llama3_3`/`llama_3_3`; naming differs across waves and is harmonised in `06_analysis_bt.R`); NA for human posts |
| `persona` | chr | five commentator personas; NA | Political persona prompt for AI posts; NA for human posts |
| `model` | chr | as `source` plus `human` | Post source with human posts labelled `human` |

---

## 5. `bt_scores_features/post_traits_{x,yt,tt,ts}.csv`

One row per post, same rows and order as the matching BT file above, with text features appended. 37 columns. The generating script is not included in the package (see README); the files are shipped as inputs.

| Variable group | Type | Values / range | Description |
|---|---|---|---|
| `Text`, `Text_ID`, `Ability`, `Normalized Ability`, `source`, `persona`, `model` | | as in section 4 | BT columns, identical to the BT file |
| `n_chars`, `n_words`, `n_sents` | int | e.g. 38-313 chars, 5-64 words, 1-21 sentences | Length counts of the raw text |
| `avg_word_len` | num | 3.5-10.8 | Mean characters per word |
| `n_exclaims` | int | 0-6 | Number of exclamation marks |
| `n_caps`, `pct_caps` | int, num | 0-96; 0-0.78 | Count and share of upper-case characters |
| `punctuation_rate` | num | 0.01-0.20 | Punctuation characters per character |
| `ttr` | num | 0.63-1 | Type-token ratio |
| `flesch_reading_ease`, `smog_index`, `flesch_kincaid_grade`, `vader_compound`, `polarity`, `subjectivity` | | all NA | Readability and lexicon-sentiment columns present in the header but empty in every shipped file; not used by any script |
| `sentiment_p_label_0`, `sentiment_p_label_1`, `sentiment_p_label_2`, `sentiment_label` | num, chr | 0-1; LABEL_0/1/2 | TweetEval sentiment probabilities and argmax label (`cardiffnlp/twitter-roberta-base-sentiment`): LABEL_0 = negative, LABEL_1 = neutral, LABEL_2 = positive |
| `emotion_p_joy`, `emotion_p_optimism`, `emotion_p_anger`, `emotion_p_sadness`, `emotion_label` | num, chr | 0-1; joy/optimism/anger/sadness | TweetEval emotion probabilities and label (`cardiffnlp/twitter-roberta-base-emotion`) |
| `hate_p_hateful`, `hate_label` | num, chr | 0-1; hate/non-hate | TweetEval hate-speech probability and label (`cardiffnlp/twitter-roberta-base-hate`) |
| `irony_p_irony`, `irony_label` | num, chr | 0-1; irony/non_irony | TweetEval irony probability and label (`cardiffnlp/twitter-roberta-base-irony`) |
| `offensive_p_offensive`, `offensive_label` | num, chr | 0-1; offensive/non-offensive | TweetEval offensive-language probability and label (`cardiffnlp/twitter-roberta-base-offensive`) |

---

## 6. Pair-level files

`pairs_data_yt_x.csv` (36,060 rows) and `pairs_data_tt_ts.csv` (36,360 rows): outputs of `01_clean_text_pairs.R`, one row per respondent x pair x side, with the 11 task columns of section 1a (`response_id` through `post`). Merged with the survey in `03_merge_response_pairs_surveys.R`.

`all_pairs_wide_format.csv` (36,210 rows, 9 columns): output of `04_pairs_to_wide.R`, one row per respondent x pair. Input to `11_gpt_ai_detector.R`.

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `response_id`, `order`, `platform` | | as in section 1a | Respondent, pair position, platform |
| `post_left`, `post_right` | chr | | Text of Post A and Post B |
| `text_id_left`, `text_id_right` | int | 1-600 | Post identifiers |
| `source_left`, `source_right` | chr | AI, Human | Source of each post |

---

## 7. `tweeteval_eval/labels_tweeteval.csv` and `labels_bertweet.csv`

One row per post, all four platforms pooled (2,386 rows, 25 columns). Produced by `code/python/tweeteval_eval/build_feature_labels.py`; full model and label-mapping details are in `code/python/tweeteval_eval/datasets.txt`.

| Variable | Type | Values / range | Description |
|---|---|---|---|
| `Text_ID`, `Text`, `Normalized Ability`, `source`, `persona`, `model` | | as in section 4 | Post identifiers, text, PHI score and source (raw model names, not harmonised) |
| `platform` | chr | TikTok, Truth Social, Twitter/X, YouTube | Platform |
| `Sentiment - Negative`, `Sentiment - Positive`, `Joy`, `Optimism`, `Anger`, `Sadness`, `Hateful Speech`, `Irony`, `Offensive` | int | 0, 1 | Binary feature labels (dominant class). Neutral sentiment is 0 on both sentiment columns; exactly one emotion is 1 |
| `prob_<feature>` | num | 0-1 | Classifier probability for the positive class of each feature |

`labels_tweeteval.csv` reformats the TweetEval columns of `post_traits_*.csv` (Cardiff NLP RoBERTa models); `labels_bertweet.csv` re-runs inference with BERTweet-architecture models (`finiteautomata/bertweet-base-sentiment-analysis`, `cardiffnlp/bertweet-base-{emotion,hate,irony,offensive}`).

---

## 8. Raw and auxiliary files

| File | What it is | Consumed by |
|---|---|---|
| `raw_yt_x_survey.csv`, `raw_tt_ts_survey.csv` | Qualtrics exports of Survey 1 and Survey 2 with labelled values (601 and 606 rows). Include the 30 pairwise items per respondent, post texts and IDs for each pair, and the `oe_cues` open-ended answer | `01_clean_text_pairs.R` |
| `raw_yt_x_survey_num.csv`, `raw_tt_ts_survey_num.csv` | Same exports with numeric codes | `02_clean_survey_data.R` |
| `connect_survey_yt_x.csv`, `connect_survey_ts_tt.csv` | CloudResearch Connect participant exports (621 and 613 rows): `ParticipantId`, timing, status, and profile demographics (Age, Education, Sex, Political Party, Ethnicity, Race, Household Income, Employment Status, ...). Payment and completion-code columns removed | `02_clean_survey_data.R`, `09_logit.R`, `13_balance_table_demographics.R` |
| `survey_followup2.csv` | Qualtrics export of the May 2026 follow-up survey (three-row Qualtrics header, 740 data rows, raw item names such as `AI-freq`, `digital-lit_1`, `participantId`) | `05_prep_followup_data.R` |
| `x_selected_150_posts.csv`, `yt_selected_150_posts.csv`, `tt_selected_600_posts.csv`, `ts_selected_600_posts.csv` | Stimulus pools (about 600 posts each): `id`, `rt`, `source`, `persona`, `post`, `nchar` | `01_clean_text_pairs.R` |
| `OE_Humanness.xlsx` | Open-ended cue responses (`ResponseId`, `oe_cues`, six `oe_multiple` ratings, correctness flag) in three sheets: `All` (1,212), `ytx`, `ttts`. Feedback column blanked | `14_qualitative_cues.R` |
| `gpt_detector_sample_gpt-5_all_posts_20260511.csv` | Output of the GPT-5 zero-shot detector run of 2026-05-11 (21,201 pair-level API calls): pair identifiers and texts, model settings, raw and parsed answers, token counts | `12_gpt_direct_classifier_figure.R` |

Inputs for the Python stage (raw Qualtrics `VALUES-*.csv` exports with PII removed, post metadata, winner/loser pair files and BT intermediates) sit next to the notebooks under `code/python/x_yt_analysis/` and `code/python/tt_ts_analysis/`.
