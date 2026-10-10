##############################################################################
# File-Name: 01_clean_text_pairs.R
# author: Tiago Ventura
# Purpose: Reshape the raw Qualtrics exports into one row per respondent,
#          pair and post; attach post text and source; code the attention
#          checks. Produces data/pairs_data_yt_x.csv and
#          data/pairs_data_tt_ts.csv.
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
bs_yt_x  <- read_csv("data/raw_yt_x_survey.csv")

# Process the survey data YT and Twitter -----------------------------------------------------

# fix two items on youtube
bs_yt_x <- bs_yt_x %>%
  rename("yt_res_15"= "yt_15_res", 
         "yt_res_14"= "yt_14_res")
         
## 1- Get responses ------
responses <- bs_yt_x %>%
  select(response_id, contains("yt_res"), contains("x_res")) %>%
  pivot_longer(cols=-c(1)) %>% 
  drop_na() %>%
  mutate(order=str_remove_all(name, "yt_res_|x_res_"), 
         response=ifelse(value=="Post B", "Right", "Left"),
         platform=ifelse(str_detect(name, "yt"), "YouTube", "X/Twitter"))

# Check responses
responses %>%
  count(response_id) %>%
  count(n) # 604 participants with 30 responses each

## 2 - identify respondents that failed the attention check -----
att_check <- responses %>%
  filter(order==10) %>%
  mutate(att_check=ifelse(response=="Left", 0, 1))  %>%
  select(response_id, platform, att_check)

# join
responses <- left_join(responses, att_check)

# create binary response
responses$binary_response = 1

# select columns
responses <- responses %>% select(response_id, order, platform, response, att_check, binary_response)

# how many failed attention check
responses %>%
  filter(att_check==1) %>%
  distinct(response_id) %>%
  nrow() ## 37 participants 

## 3 - get text id
id <- bs_yt_x %>%
  select(response_id, contains("yt_pairs"), contains("x_pairs_")) %>%
  # keep only id
  select(response_id, contains("_id_")) %>%
  # remove multiple choice
  select(response_id, contains("_left_"), contains("_right_")) %>%
  pivot_longer(cols=-c(1)) %>% 
  drop_na() %>%
  mutate(order=str_extract(name, "\\d+"), 
         response=ifelse(str_detect(name, "left"), "Left", "Right"),
         platform=ifelse(str_detect(name, "yt"), "YouTube", "X/Twitter")) %>%
  select(-name, text_id=value)

# Check responses
id %>%
  count(response_id) %>%
  count(n) # 605 participants with 60 responses each

# merge the datasets
d_x_yt <- left_join(id, responses, by=c("response_id", "order", "platform", "response"))

# it should have half NA for responses
d_x_yt %>%
  count(binary_response) ## perfect


## Recode outcome
d_x_yt <- d_x_yt %>%
           mutate(binary_response=ifelse(is.na(binary_response), 0, 1)) %>%
           # propagate the attention check
           group_by(response_id) %>%
           mutate(att_check_sum=sum(att_check, na.rm = TRUE)) %>%
           ungroup()

## 3 - Merge with id -----
x <- read_csv("data/x_selected_150_posts.csv")
yt <- read_csv("data/yt_selected_150_posts.csv")

# let me do a manual check just to make sure this matching is working

# select some ids and text
temp <- bs_yt_x %>%
  select(x_pairs_10_left_id_0, yt_pairs_10_left_id_0,
         x_pairs_10_left_text_0, yt_pairs_10_left_text_0) %>%
  distinct()


# merge them
left_join(x, temp, by=c("id"="x_pairs_10_left_id_0")) %>% 
  drop_na() %>%
  select(post, x_pairs_10_left_text_0) %>% 
  mutate(t=post==x_pairs_10_left_text_0) 

left_join(yt, temp, by=c("id"="yt_pairs_10_left_id_0")) %>% 
  drop_na() %>%
  select(post, yt_pairs_10_left_text_0) %>% 
  mutate(t=post==yt_pairs_10_left_text_0) 

## working perfectly. 
posts <- bind_rows(x %>% mutate(platform="X/Twitter"), 
          yt %>% mutate(platform="YouTube")) %>%
          select(-rt, -nchar, text_id=id)  

# merge
d_x_yt <- left_join(d_x_yt, posts)

## 4 -  Save -----

write_csv(d_x_yt, "data/pairs_data_yt_x.csv")

# Process the survey data TS and TT -----------------------------------------------------
rm(list=ls(all=TRUE))

bs_tt_ts <- read_csv("data/raw_tt_ts_survey.csv")

# fix two items on youtube
bs_tt_ts <- bs_tt_ts %>%
  rename("tt_res_15"= "tt_15_res", 
         "tt_res_14"= "tt_14_res")

## 1- Get responses ------
responses <- bs_tt_ts %>%
  select(response_id, contains("tt_res"), contains("ts_res")) %>%
  pivot_longer(cols=-c(1)) %>% 
  drop_na() %>%
  mutate(order=str_remove_all(name, "tt_res_|ts_res_"), 
         response=ifelse(value=="Post B", "Right", "Left"),
         platform=ifelse(str_detect(name, "tt"), "TikTok", "Truth Social"))

# Check responses
responses %>%
  count(response_id) %>%
  count(n) 

## 2 - identify respondents that failed the attention check -----
att_check <- responses %>%
  filter(order==10) %>%
  mutate(att_check=ifelse(response=="Left", 0, 1))  %>%
  select(response_id, platform, att_check)

# join
responses <- left_join(responses, att_check)

# create binary response
responses$binary_response = 1

# select columns
responses <- responses %>% select(response_id, order, platform, response, att_check, binary_response)

# how many failed attention check
responses %>%
  filter(att_check==1) %>%
  distinct(response_id) %>%
  nrow() 
## 3 - get text id
id <- bs_tt_ts%>%
  select(response_id, contains("tt_pairs"), contains("ts_pairs_")) %>%
  # keep only id
  select(response_id, contains("_id_")) %>%
  # remove multiple choice
  select(response_id, contains("_left_"), contains("_right_")) %>%
  pivot_longer(cols=-c(1)) %>% 
  drop_na() %>%
  mutate(order=str_extract(name, "\\d+"), 
         response=ifelse(str_detect(name, "left"), "Left", "Right"),
         platform=ifelse(str_detect(name, "tt"), "TikTok", "Truth Social")) %>%
  select(-name, text_id=value)

# merge the datasets
d_tt_ts <- left_join(id, responses, by=c("response_id", "order", "platform", "response"))

## examine a single case

## it should have 2 per order per platform
## 2 becuase I have the left and right text
d_tt_ts %>%
  count(response_id, order, platform) %>%
  count(order, n, platform) %>%
  arrange(as.numeric(order))


## Recode outcome
d_tt_ts<-d_tt_ts%>%
  mutate(binary_response=ifelse(is.na(binary_response), 0, 1)) %>%
  # propagate the attention check
  group_by(response_id) %>%
  mutate(att_check_sum=sum(att_check, na.rm = TRUE)) %>%
  ungroup()

# how many unique users failing att check
d_tt_ts %>%
  filter(att_check_sum>0) %>%
  distinct(response_id) %>%
  nrow()

## check the original att_check dataset
att_check %>%
  filter(att_check==1) %>%
  distinct(response_id) %>%
  nrow()

# perfect

## 3 - Merge with id -----
tt <- read_csv("data/tt_selected_600_posts.csv")
ts <- read_csv("data/ts_selected_600_posts.csv")

# let me do a manual check just to make sure this matching is working

# select some ids and text
temp <- bs_tt_ts %>%
  select(tt_pairs_10_left_id_0, ts_pairs_10_left_id_0,
         tt_pairs_10_left_text_0,ts_pairs_10_left_text_0) %>%
  distinct()


# merge them
left_join(tt, temp, by=c("id"="tt_pairs_10_left_id_0")) %>% 
  drop_na() %>%
  select(post, tt_pairs_10_left_text_0) %>% 
  mutate(t=post==tt_pairs_10_left_text_0) 

left_join(ts, temp, by=c("id"="ts_pairs_10_left_id_0")) %>% 
  drop_na() %>% 
  select(post, ts_pairs_10_left_text_0) %>% 
  mutate(t=post==ts_pairs_10_left_text_0) 

## working perfectly. 
posts <- bind_rows(tt %>% mutate(platform="TikTok"), 
                   ts %>% mutate(platform="Truth Social")) %>%
  select(-rt, -nchar, text_id=id)  

# merge
d_tt_ts<- left_join(d_tt_ts, posts)

## 4 -  Save -----
write_csv(d_tt_ts, "data/pairs_data_tt_ts.csv")
