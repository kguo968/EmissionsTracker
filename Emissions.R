library(readxl)
library(tidyverse)
library(plyr)

# Define function to allocate different sector names given value 
sectorAllocate <- function(x) {
  sectorName <- switch(as.character(x),
                       "1" = "Energy",
                       "2" = "Industrial Processes and Product Use",
                       "3" = "Agriculture",
                       "4" = "LULUCF",
                       "5" = "Waste",
                       "6" = "Tokelau",
                       "-" = "LULUCF") 
}

# Importing and Restructuring ---------------------------------------------
# Import just the 2018 data to play around wiht initially
emissions <- read_xlsx("Data/emissions data.xlsx",
                       sheet = 2, 
                       range = c("A11:AI1072"))[-c(178:261,300:325,539,1053:1056),
                                                c(1:4,11, 18, 26, 27, 29)]
str(emissions)

# Convert every 'Exclude' to 0 
emissions[emissions=="Exclude"] <- '0'

# Change data entry types from 'character' to 'numeric'
emissions[, -c(1,2)] <- lapply(emissions[,-c(1,2)], function(x) unlist(as.numeric(x)))

str(emissions)
summary(emissions)

# Change the 'N/A' values from NA to 0
emissions[rowSums(is.na(emissions)) > 0, 4:9] <- 0
summary(emissions)

# Remove all rows where total emissions == 0
emissions <- emissions[apply(emissions[,-c(1:2)], 1, function(x) !all(x==0)), ]

# Allocate number which defines the sector (1 = Energy, 2 = Industrial Process and Product Use ...)
emissions[-c(1,2),10] <- apply(emissions[-c(1,2),1], 1, function(x) substr(x,1,1))
names(emissions)[3] <- "Totals"
names(emissions)[10] <- "Sector"

# Loop through data set and set name for 
for (i in 3:dim(emissions)[1]) {
  emissions[i, 10] <- sectorAllocate(emissions[i,10])
}

# Manually name 'sector' for first 2 rows (which are always Net and Gross totals)
emissions[1,10] <- "Net w/LULUCF"
emissions[2,10] <- "Gross w/o LULUCF"


# Main Emissions Tracker Plot ---------------------------------------------
# Filter for just the overall summary of each emission
summary_emission <- emissions %>% filter(`Link to CRF import file` == "1"|
                                         `Link to CRF import file` == "2"|
                                         `Link to CRF import file` == "3"|
                                         `Link to CRF import file` == "4"|
                                         `Link to CRF import file` == "5"|
                                         `Link to CRF import file` == "6")
summary_emission <- summary_emission[,3:10]

# Re-order factors for summary_emission to match interactive tracker
factor_order <- c("Energy", "Industrial Processes and Product Use", "Agriculture","Waste","Tokelau","LULUCF")
summary_emission <- summary_emission %>% mutate(Sector = factor(Sector, levels=factor_order)) %>% arrange(Sector)

# Determine number of rows
row_num <- dim(summary_emission)[1]

# Set the 'Start' values for each of the sectors
summary_emission$Start <- 0 

for (i in 2:row_num) {
  summary_emission[i,9] <- summary_emission[i-1,9] + summary_emission[i-1,1]
}

# Set the 'End' values for each of the sectors
summary_emission$End <- 0

for (j in 1:(row_num-1)) {
  summary_emission[j,10] <- summary_emission[j+1,9]
}
summary_emission[row_num,10] <- summary_emission[row_num-1, 10] + summary_emission[row_num,1] 

# Generate the floating bar graph with lines indicating gross and net emissions
summary_emission %>% ggplot(aes(x=Sector, y=Start, fill=Sector)) + 
  geom_crossbar(aes(ymin=Start, ymax=End), fatten=0,show.legend = FALSE) +
  labs(title="Emissions from sectors", y = "Emissions CO2-e (kilotonnes)") +
  theme(plot.title = element_text(hjust = 0.5)) +
  geom_hline(yintercept = sum(summary_emission[,1]), linetype = "dashed") +
  geom_text(aes(0.7, sum(summary_emission[,1]), label = "Net", vjust = -1)) +
  geom_hline(yintercept = sum(summary_emission[1:5,1]), linetype = "dashed") +
  geom_text(aes(0.7, sum(summary_emission[1:5,1]), label = "Gross", vjust = -1))



# Time series of total emissions w/lulucf ---------------------------------
# Read in the time series data
time_series_data <- read_xlsx("Data/emissions data.xlsx", range = "D11:AF12", col_names = FALSE)

# Transpose data and rename column names
time_series_data <- as.data.frame(t(as.matrix(time_series_data)))
names(time_series_data)[1] <- "Year"
names(time_series_data)[2] <- "Emissions"

# Plot time series data
time_series_data %>% ggplot(aes(x=Year, y=Emissions,)) + geom_bar(stat="identity",fill="#CC79A7") +
  labs(title="Select Year", y="Emissions (kt CO2-e)") + 
  theme(plot.title = element_text(hjust=0.5))

# GHG Emission plot -------------------------------------------------------
# Get total ghg data
total_ghg <- colSums(summary_emission[,2:7]) %>% as.data.frame()
total_ghg$Gas <- row.names(ghg_test)

# Rename column
names(total_ghg)[1] <- "Emission"

# Reorder the factor to match the current tracker
ghg_factor_order <- c("Total CO2", "Total CH4", "Total N2O", "HFCs","PFCs","SF6","Totals")
total_ghg <- total_ghg %>% mutate(Gas = factor(Gas, levels=ghg_factor_order)) %>% arrange(Gas)

# Plot the GHG emissions data
total_ghg %>% filter(Gas != "Totals") %>% ggplot(aes(x=Gas, y=Emission)) + 
  geom_bar(stat="identity", fill="Dark Green") +
  labs(title="Select Greenhouse Gas", x = "Gas Type", y = "Emissions (kt CO2-e)") +
  theme(plot.title = element_text(hjust=0.5))


# Different Levels --------------------------------------------------------
# This is for finding the data corresponding to the specified level
# Define how 'deep' into the specifics we want to go and which sector we want 
level <- 1
sector <- "Tokelau"

Sector_Frame <- emission %>% filter(Sector == sector)
Level_Frame <- Sector_Frame[apply(Sector_Frame[,1], 1, function(x) str_count(x, fixed("."))) == level, ] %>%
  getSummarySectorBreakdown() %>% StartEnd()
Level_Frame %>% ggplot(aes(x=`Name on tab`, y=Start, fill=`Name on tab`)) + 
  geom_crossbar(aes(ymin=Start, ymax=End), fatten=0) + 
  theme(legend.position='none', axis.text.x = element_text(angle=45, hjust =1))


# Read All sheets and store as dataframe ----------------------------------

sheets <- excel_sheets("Data/emissions data.xlsx")[-c(1,31)]
list_emissions <- lapply(sheets, function(x) read_excel("Data/emissions data.xlsx", sheet = x,
                                                        range = c("A11:AI1072"))[-c(178:261,300:325,539,1053:1056),
                                                                                 c(1:4,11, 18, 26, 27, 29)])

for (i in 1:length(sheets)) {
  list_emissions[[i]] <- cleanSheet(list_emissions[[i]])
}

emissions <- rbind.fill(list_emissions)

# Time series total and sectors -------------------------------------------

# Read in all required 
time_series_all <- read_xlsx("Data/emissions data.xlsx", range = "A11:AF1072")[-c(178:261,300:325,539,1053:1056), ]
# Clean using previously defined function
time_clean <- cleanSheet(time_series_all)

level <- 1
sector <- "Tokelau"

Sector_Time <- time_clean %>% filter(Sector == sector)
SectorTimeSummary <- Sector_Time[apply(Sector_Time[,1],
                                       1,
                                       function(x) 
                                         (str_count(x, fixed(".")) == level & 
                                            substr(x, 1, 2) == as.character(x))), ]
SectorTimeSummary <- as.data.frame(t(as.matrix(SectorTimeSummary[,4:32])))
SectorTimeSummary$Year <- row.names(SectorTimeSummary)
names(SectorTimeSummary)[1] <- "Emissions"

# Filter for GHG  ---------------------------------------------------------
filter_for <- colnames(emission_year[,4:9])[c(1,3)] # Change values inside c() between 1 and 6 inclusive to change which GHG values to filter for
filtered_GHG <- emission_year %>% assignSector() %>% select(colnames(emission_year[,c(1,2)]), all_of(filter_for), 10:12)

col_num <- dim(filtered_GHG)[2]

filtered_GHG <- add_column(filtered_GHG, Totals = rowSums(filtered_GHG[,-c(1:2,col_num-2,col_num-1,col_num), drop = FALSE]), .after = "Name on tab")
filtered_GHG <- filtered_GHG %>% getSummary() %>% StartEnd()# %>% ggplot(aes(x = Sector, y = Start, fill = Sector)) + 
 # geom_crossbar(aes(ymin=Start, ymax=End), fatten=0) 
filtered_GHG


# Time series GHG breakdown -----------------------------------------------
# emissions_timeseries <- emissions %>% pivot_longer(!(c(`Link to CRF import file`, `Name on tab`, Year, Sector, `Layer in hierarchy`)), 
#                                                    names_to = "Emission",
#                                                    values_to = "Amount")
# emission_timeseries <- emissions_timeseries[!(emissions_timeseries$Emission == "Totals"), ]

emissions_test <- emissions %>% select(c(4,10,12)) %>% filter(`Layer in hierarchy` == 0)
  
