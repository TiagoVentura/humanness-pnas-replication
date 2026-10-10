##############################################################################
# File-Name: 03_merge_response_pairs_survey.r
# Date: 2022
# author: Tiago Ventura
# Purpose: merge the datasets with the pairs with the processes survey data
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


## survey
s <- read_csv("data/survey_cleaned.csv")



# Merge -------------------------------------------------------------------
d <- left_join(responses, s)
# perfect. All id merged from both datasets

write_csv(d, "data/pairs_survey_clean.csv")
