# List required packages

packages = c(
  "shiny",
  "readxl",
  "tidyverse",
  "plyr",
  #"mfePubs",
  "stringi",
  "DT"
  # "shinyBS",
  # "shinyWidgets"
  # "crayon"
  # "forcats"
)

# Check if package is installed, if not install it
for(p in packages){
  
  
  if(!require(p,character.only = TRUE)) install.packages(p, dependencies =TRUE)
  library(p,character.only = TRUE)
  # message(!require(p,character.only = TRUE))
}