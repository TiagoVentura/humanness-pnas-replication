##############################################################################
# File-Name: 04_pairs_to_wide.r
# Date: 2022
# author: Tiago Ventura
# Purpose: convert pairs to wide formats
# Data in:  processed survey + processed pairs
# Data out: merged datasers
# status:
# Machine: MacOS High Sierra
##############################################################################

# Set working directory ---------
setwd(here::here())
getwd()


# Packages ----------------------------------------------------------------
pacman::p_load(tidyverse, scales, lubridate, here, janitor, 
               rebus, RColorBrewer, wesanderson, lubridate, qualtRics, tidylog)

# Open datasets -------------------------

## pairs responses
responses_1  <- read_csv("data/pairs_data_tt_ts.csv")
responses_2  <- read_csv("data/pairs_data_yt_x.csv")
responses <- bind_rows(responses_1, responses_2)


responses %>% tabyl(source)

## pairs to wide
responses %>% select(response_id, text_id, order, response, platform, post, source, ) %>%
  pivot_wider(names_from=response, 
              values_from=c(post, text_id, source)) %>% 
  janitor::clean_names() %>%
  write_csv("data/all_pairs_wide_format.csv")

