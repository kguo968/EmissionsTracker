sectorAllocate <- function(x) {
  # Helper function for allocating the Sector name for each observation based on their assigned number
  sectorName <- switch(
    as.character(x),
    "1" = "Energy",
    "2" = "Industrial Processes and Product Use",
    "3" = "Agriculture",
    "4" = "LULUCF",
    "5" = "Waste",
    "6" = "Tokelau",
    "-" = "LULUCF",
    "S" = "Totals"
  )
}

getSheet <- function() {
  # Function which extracts all the useful observations from the provided excel file
  
  # Get list of all years present (assumes first sheet is time series and last sheet is GUIDs)
  sheets <- excel_sheets(
      "Data/Sent to Datacom 25 March 2020 - Emissions data 1990-2018 for Emissions Tracker 2020 submission version T from CRF 13 Feb 2020.xlsx"
    )[-c(1, length(excel_sheets(
      "Data/Sent to Datacom 25 March 2020 - Emissions data 1990-2018 for Emissions Tracker 2020 submission version T from CRF 13 Feb 2020.xlsx")))]
  
  # Read all emissions data into list
  list_emissions <- lapply(sheets, function(x)
      read_excel(
        "Data/emissions data.xlsx",
        sheet = x,
        range = c("A11:AP1072")
      )[,
        c(1:4, 11, 18, 26, 27, 29, 38, 40, 41, 42)])
  
  # Read time series data from first sheet
  time_series_data <- read_xlsx("Data/emissions data.xlsx", range = "A11:AF1072") %>% 
    # Bind GUID values to time series data
    cbind(GUID = list_emissions[[1]]$`GUID of node`)
  
  # Clean data for each year
  for (i in 1:length(sheets)) {
    list_emissions[[i]] <- cleanSheet(list_emissions[[i]])
    list_emissions[[i]]$Year <- as.double(sheets[i])
  }
  
  # Convert list into single dataframe 
  emissions <- rbind.fill(list_emissions)
  
  # Save emissions and time_series as .rda files
  save(emissions, file = "emissions.rda")
  save(time_series_data, file = "time_series.rda")
}

assignSector <- function(x) {
  # Assigns the numeric value for an observations
  summary_emission <- x %>% filter(
    `Link to CRF import file` == "1" |
      `Link to CRF import file` == "2" |
      `Link to CRF import file` == "3" |
      `Link to CRF import file` == "4" |
      `Link to CRF import file` == "5" |
      `Link to CRF import file` == "6"
  )
  summary_emission
}

getSummary <- function(x) {
  # Obtain summary information for rows that are used for plotting
  
  # Extract required columns
  summary <- x[, 3:(dim(x)[2] - 1)]
  
  # Define order of factors
  factor_order <-
    c(
      "Energy",
      "Industrial Processes and Product Use",
      "Agriculture",
      "Waste",
      "Tokelau",
      "LULUCF"
    )
  
  # Reorder factors in data frame
  summary <- summary %>%
    mutate(Sector = factor(Sector, levels = factor_order)) %>%
    arrange(Sector)
  
  summary
}

getSummarySectorBreakdown <- function(x) {
  # Get summary information when we've entered a specific sector
  summary <- x[, 2:9]
  summary <- summary[, c(2:8, 1)]
}

getSummaryGHG <- function(x, num) {
  # Get summary information when we have a filter for GHG
  summary <- x[, 2:(3 + num)]
  summary <- summary[, c(2:(2 + num), 1)]
}

StartEnd <- function(x) {
  # Compute the Starting and Ending values for each sector (x-axis). Required to get desired ggplot
  
  # Obtain number of rows and columns
  row_num <- dim(x)[1]
  col_num <- dim(x)[2]
  
  # Set the 'Start' values for each of the sectors
  x$Start <- 0
  
  # Catch edge case of having only one observation
  if (row_num == 1) {
    # Set end to be equal to the total
    x$End <- x$Totals
    
  } else {
    # Iterate through rows and assign Starting value
    for (i in 2:row_num) {
      x[i, (col_num + 1)] <- x[i - 1, (col_num + 1)] + x[i - 1, 1]
    }
    
    # Set the 'End' values for each of the sectors
    x$End <- 0
    
    # Iterate through rows and assign Ending value
    for (j in 1:(row_num - 1)) {
      x[j, col_num + 2] <- x[j + 1, col_num + 1]
    }
    
    x[row_num, col_num + 2] <-
      x[row_num - 1, col_num + 2] + x[row_num, 1]
  }
  
  x
}

getGHG <- function(x) {
  # Obtain dataframe used for plotting GHG 
  
  # Compute total GHG for each emission type
  total_ghg <- colSums(x[, 2:7]) %>% as.data.frame()
  total_ghg$Gas <- row.names(total_ghg)
  
  # Rename column
  names(total_ghg)[1] <- "Emission"
  
  # Reorder the factor to match the current tracker
  ghg_factor_order <-
    c("Total CO2",
      "Total CH4",
      "Total N2O",
      "HFCs",
      "PFCs",
      "SF6",
      "Totals")
  
  # Update data frame with new factor order
  total_ghg <- total_ghg %>%
    mutate(Gas = factor(Gas, levels = ghg_factor_order)) %>%
    arrange(Gas)
  
  total_ghg
}

cleanSheet <- function(x) {
  # Function which 'cleans' the emissions data for each year such that it removes any unnecessary information
  
  emissions <- x
  col_len <- dim(emissions)[2]
  
  # Remove gross total
  emissions <- emissions[-2,]
  
  # Convert any observations listed as "Exclude" to be equivalent to 0
  emissions[emissions == "Exclude"] <- '0'
  
  # Differentiate between Yearly emissions data (col_len == 13) and time series data
  if (col_len == 13) {
    # For Yearly emissions data:
    
    # Assign "False" to observations that aren't at the lowest level for `Lowest level?` column
    emissions$`Lowest level?`[is.na(emissions$`Lowest level?`)] <- "False"
    
    # Unlist factor values and convert to numeric for applicable columns
    emissions[, -c(1, 2, 10:13)] <- lapply(emissions[,-c(1, 2, 10:13)], function(x)
      unlist(as.numeric(x)))
    
    # Change any N/A values in GHG emission columns from N/A to 0
    emissions[,4:9][is.na(emissions[, 4:9])] <- 0
    
    # Remove any columns where all GHG emission values are 0 (i.e. no emissions, thus not needed)
    emissions <- emissions[apply(emissions[,-c(1:2, 10:13)], 1, function(x)
        ! all(x == 0)), ]
    
    # Assign numeric value to each observation, designating their Sector
    emissions[, col_len + 1] <-
      apply(emissions[, 1], 1, function(x)
        substr(x, 1, 1))
    
    # Rename sector column
    names(emissions)[col_len + 1] <- "Sector"
    
    # Convert numeric value to respective Sector (refer to sectorAllocate function)
    for (i in 1:dim(emissions)[1]) {
      emissions[i, col_len + 1] <-
        (sectorAllocate(emissions[i, col_len + 1]))
    }
    
    } 
  else {
    # For time series data
      
    # Unlist values and convert from factor to numeric
    emissions[, -c(1, 2, 33)] <-
      lapply(emissions[,-c(1, 2, 33)], function(x)
      unlist(as.numeric(x)))
  
    # Remove observations with all their values as 0
    emissions[emissions$...3 != 0, ] 
  }
  
  # Rename Totals column
  names(emissions)[3] <- "Totals"
  
  emissions
}

timeSummary <- function(x) {
  # Obtain useful summary information from time series data sheet
  
  time_series_summary <- as.data.frame(t(as.matrix(x[1, 4:32])))
  time_series_summary$Year <-
    as.double(row.names(time_series_summary))
  names(time_series_summary)[1] <- "Emissions"
  time_series_summary$Emissions <-
    as.numeric(as.character(time_series_summary$Emissions))
  time_series_summary
}

changeOrder <- function(x) {
  # Change ordering of values such that all positive values come first, then negative
  
  # Split data frame to negative and positive values
  x <- x %>%
    split(x$Totals < 0)
  
  # Reorder values within their respective lists
  x[[1]] <- dplyr::arrange(x[[1]], `Name on tab`)
  x[[2]] <- dplyr::arrange(x[[2]], `Name on tab`)
  
  # Combine lists into single dataframe
  x <- rbind.fill(x)
  
  x
}

getTitle <- function(x, level) {
  # Use regex to extract the name of the sub section (used for plotting)
  if (level > 1) {
    x <- str_remove(str_sub(x, 2, -2), "\\d[\\d\\.\\w]+[\\s]+")
  }
  
  x
}