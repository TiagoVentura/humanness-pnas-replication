##############################################################################
# File-Name: 00_utils.R
# author: Tiago Ventura
# Purpose: Shared ggplot theme, color palettes, confidence-interval helper
#          and save_function() used by the analysis scripts.
# Machine: macOS Sequoia 15.6.1
# R version 4.5.1
##############################################################################
pacman::p_load(tidyverse, scales,  knitr, srvyr, extrafont, 
               rebus, broom, tidyr, lubridate, here, ggdist, ggtext, ggalt,  janitor, 
               broom, tidyr,  stargazer, janitor)

# ggplot theme ------------------------------------------------------------
#my_font <- "Palatino"
my_font <- "sans"
my_bkgd <- "white"
#my_bkgd <- "#f5f5f2"
pal <- RColorBrewer::brewer.pal(9, "Spectral")

my_theme <- theme(text = element_text(family = my_font, color = "#22211d"),
                  rect = element_rect(fill = my_bkgd),
                  plot.background = element_rect(fill = my_bkgd, color = NA),
                  panel.background = element_rect(fill = my_bkgd, color = NA),
                  #panel.border = element_rect(color="transparent"), 
                  strip.background = element_rect(color="black", fill="gray85"), 
                  legend.background = element_rect(fill = my_bkgd, color = NA),
                  legend.key = element_rect(size = 6, fill = "white", colour = NA), 
                  legend.key.size = unit(1, "cm"),
                  legend.text = element_text(size = 14, family = my_font),
                  legend.title = element_text(size=14),
                  plot.title = element_markdown(size = 22, face = "bold", family=my_font),
                  plot.subtitle = element_markdown(size=16, family=my_font),
                  axis.title= element_text(size=22),
                  axis.text.y = element_text(size=18, family=my_font),
                  axis.text.x  = element_text(size=14, family=my_font),
                  
                  axis.title.x = element_text(hjust=1),
                  strip.text = element_text(family = my_font, color = "#22211d",
                                            size = 14, face="bold"), 
                  plot.margin = margin(1, 1, 1, 1, "cm"), 
                  plot.caption = element_text(size=11))

theme_set(theme_minimal() + my_theme)


## confidence intervals
conf_int <- function(data, estimate, std){
  data %>% 
    mutate(up90={{estimate}} + 1.64*{{std}},
           up95={{estimate}} + 1.96*{{std}}, 
           lb90={{estimate}} - 1.64*{{std}}, 
           lb95={{estimate}} - 1.96*{{std}})
}

# Function to save graph outputs ----------------------------------
save_function <- function(name,width = 12, height = 8 ){

  ggsave(filename = paste0("output/", name), 
         width = width, height = height, 
         units = "in", 
         pointsize = 12, bg = "white")
}


# Function to save table outputs ----------------------------------
save_table <- function(table, name){

  save_kable(table, file = here("output", name))
}


# colors ----------------------
royal = wesanderson::wes_palette("Royal1", 3)
mix = c(wesanderson::wes_palette("Royal1", 2), wesanderson::wes_palette("BottleRocket2", 1))
mix_rep <- c(RColorBrewer::brewer.pal(8, "Greys")[3],
             RColorBrewer::brewer.pal(8, "Greys")[5],
             RColorBrewer::brewer.pal(8, "Greys")[8])
