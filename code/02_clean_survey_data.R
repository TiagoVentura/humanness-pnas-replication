##############################################################################
# File-Name: 02_clean_survey_data.R
# author: Tiago Ventura
# Purpose: Build the respondent-level survey file (attitudes, news habits,
#          Connect demographics). Produces data/survey_cleaned.csv.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
# Set working directory ---------
setwd(here::here())
getwd()


# Packages ----------------------------------------------------------------
pacman::p_load(tidyverse, scales, lubridate, here, janitor, 
               rebus, RColorBrewer, wesanderson, lubridate, qualtRics, tidylog)


# Open datasets -------------------------
bs_yt_x  <- read_csv("data/raw_yt_x_survey_num.csv")
bs_tt_ts <- read_csv("data/raw_tt_ts_survey_num.csv")

# Remove all non-survey variables -----------------------------------------
s_yt_x <- bs_yt_x %>%
  select(response_id, participant_id, 19:42, 
         contains("sm_cy"), 
         contains("news_consump"), contains("misinfor_lit"), 
         contains("oe_multiple"), 
         -contains("_do_"))  %>%
  mutate(study="yt-tw")

s_tt_ts <- bs_tt_ts %>%
  select(response_id, participant_id, 20:50, 
         contains("sm_cy"), 
         contains("news_consump"), contains("misinfor_lit"), 
         contains("oe_multiple"), 
         -contains("_do_")) %>%
  mutate(study="ts-tt")

# bind rows
d = bind_rows(s_yt_x, s_tt_ts)

# which variables we do not have on both datasets
na = colSums(is.na(d)) 
names = colnames(d)

# check results
tibble(names, na) %>%
  arrange(desc(na))

## only social media usage. party id lean is standard because we do not have party id for all

# Merging with Connect ----------------------------------------------------

s1 <- read_csv("data/connect_survey_ts_tt.csv")   %>% mutate(study="ts-tt")
s2 <- read_csv("data/connect_survey_yt_x.csv")  %>%
  mutate(study="yt-tw")

# bind rows
cn <- bind_rows(s1, s2) %>% clean_names()

# basic pre-processing
colnames(cn)

cn <- cn %>%
  select(participant_id, age, education, sex, occupation_field, relationship_marital_status, 
         political_party, ethnicity, gender, household_income, race, employment_status, 
         study) 



## Education
names(table(cn$education))
cn <- cn%>%
  mutate(
    education_num = case_when(
      str_detect(education, "Less than a high school|No formal education")  ~ 0,
      str_detect(education, "High school graduate")  ~ 1,
      str_detect(education, "Some college|Associate degree")  ~ 2,
      str_detect(education, "Bachelor") ~ 3,
      str_detect(education, "Doctorate|Master|Professional") ~ 4,
      TRUE  ~ NA), 
    education_cat=case_when(education_num<3 ~  "No College Degree", 
                         education_num==3 ~ "College Degree", 
                         education_num>3 ~ "Post-Graduate Degree"))

# check results    
cn %>% tabyl(education_num, education_cat) 

# Age
table(cn$age)

cn <- cn %>% mutate(
  age_group = case_when(
    age < 25                ~ "<25",
    age >= 25 & age <= 44    ~ "25-44",
    age >= 45 & age <= 64    ~ "45-64",
    age >= 65                ~ "65+",
    TRUE                     ~ NA_character_
  ),
  age_group = factor(age_group, levels = c("<25", "25-44", "45-64", "65+"), ordered = TRUE)
)

table(cn$age_group)

## Sex
table(cn$sex)
cn <- cn %>%
  mutate(sex = case_when(
      sex %in% c("Male", "Female") ~ sex,
      TRUE                         ~ NA))
    
## Party
cn = cn %>%
  mutate(party_connect = case_when(
      political_party %in% c("Democratic", "Democrat")    ~ "Democrat",
      political_party %in% c("Republican")                ~ "Republican",
      political_party %in% c("Independent")               ~ "Independent",
      TRUE                                                ~ "Other"
    ))
    

## ehtnicity
table(cn$ethnicity)
table(cn$race)
cn <- cn %>%
      mutate(hispanic=ifelse(ethnicity=="No, not of Hispanic, Latino, or Spanish origin", 
                             0, 1),
             white=ifelse(race=="White", "White", "Non-White"))

# Income → 4 brackets
cn <- cn %>%
  mutate(income_num = case_when(
    household_income == "Less than $10,000"      ~  0,
    household_income == "$10,000-$19,999"        ~ 1,
    household_income == "$20,000-$29,999"        ~ 2,
    household_income == "$30,000-$39,999"        ~ 3,
    household_income == "$40,000-$49,999"        ~ 4,
    household_income == "$50,000-$59,999"        ~ 5,
    household_income == "$60,000-$69,999"        ~ 6,
    household_income == "$70,000-$79,999"        ~ 7,
    household_income == "$80,000-$89,999"        ~ 8,
    household_income == "$90,000-$99,999"        ~ 9,
    household_income == "$100,000-$124,999"      ~10,
    household_income == "$125,000-$149,999"      ~11,
    household_income == "$150,000-$174,999"      ~12,
    household_income == "$175,000-$199,999"      ~13,
    household_income == "$200,000-$224,999"      ~14,
    household_income == "$225,000-$249,999"      ~15,
    household_income == "$250,000 or more"       ~16,
    household_income == "Prefer not to say"      ~   NA_real_,
    TRUE                                          ~   NA_real_
  ))

### filter
cn <- cn %>%
  select(participant_id, age, age_group, education_num, education_cat, sex, party_connect, hispanic, white, household_income, income_num)

## merge with survey
d = left_join(d, cn)
## 30 participants from CN not matched. probably people we removed for not completing. 


# Pre-Processing ----------------------------------------------------------

colnames(d)

# Trust News
d<-d %>%
  rename("news_trust_newspapers"="newstrust_1", 
         "news_trust_social_media"="newstrust_2", 
         "news_trust_news_websites"="newstrust_3", 
         "news_trust_radio"="newstrust_4", 
         "news_trust_local"="newstrust_5",
         "news_trust_national_news_org"="newstrust_6") %>%
  rowwise() %>%
  mutate(trust_news=mean(c_across(news_trust_newspapers:news_trust_national_news_org))) %>%
  ungroup() %>%
  mutate(trust_news_reescaled=scale(trust_news)[,1]) 

# Party ID 

d <- d %>%
  mutate(party_id=case_when(party_id==1 ~ "Republican", 
                            party_id==2 ~ "Democrat", 
                            party_id==3 ~ "Independent", 
                            party_id==4 ~ "Something else"), 
         party_id_lean=case_when(party_id_lean==1 ~ "Republican", 
                                 party_id_lean==2 ~ "Democrat",
                                 party_id_lean==3 ~ "Neither"), 
         party_id_imputation=case_when(party_id=="Something else" ~ party_id_lean, 
                                       party_id=="Independent" ~ party_id_lean, 
                                       TRUE ~ party_id), 
         party_id_imputation=case_when(str_detect(party_id_imputation, "Republican")~"Republican", 
                                       str_detect(party_id_imputation, "Democrat")~"Democrat",
                                       party_id_lean=="Neither" ~ NA_character_,
                                       TRUE ~ party_id_imputation), 
         party_id_imputation=as_factor(party_id_imputation))

# Conspiratory Beliefs
d<-d %>%
  rowwise() %>%
  mutate(conspiratory_beliefs=mean(c_across(conspiracies_1:conspiracies_4))) %>%
  ungroup() %>%
  mutate(conspiratory_beliefs_reescaled=scale(conspiratory_beliefs)[,1]) 

# sm cynicism ##  recoding is wrong
d <- d %>%
  mutate_at(vars(sm_cynicism_1:sm_cynicism_4), 
            ~ case_when(.x==10~4, 
                      .x==11~5, 
                      .x==12~6,
                      .x==9~7, 
                      TRUE~.x
            ))  %>%
  rowwise() %>%
  mutate(cyn_beliefs=mean(c_across(sm_cynicism_1:sm_cynicism_4))) %>%
  ungroup() %>%
  mutate(cyn_beliefs_reescaled=scale(cyn_beliefs)[,1]) 

## news consumption
d<-d %>%
  rename("news_tv"="news_consumption_1", 
         "news_radio"="news_consumption_2", 
         "news_newspapers"="news_consumption_3", 
         "news_websites"="news_consumption_4", 
         "news_friends"="news_consumption_5",
         "news_fb"="news_consumption_6", 
         "news_x"="news_consumption_7", 
         "news_tt"="news_consumption_8", 
         "news_yt"="news_consumption_9") %>%
  rowwise() %>%
  mutate(news_cons=sum(c_across(news_tv:news_yt))) %>%
  ungroup() %>%
  mutate(news_cons_reescaled=scale(news_cons)[,1])  



# save ---------------------------------------------------------------
write_csv(d, "data/survey_cleaned.csv")
