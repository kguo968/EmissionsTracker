source("library.R")
source("helper.R")

# Import all emissions data and store as single data frame
if (!file.exists("emissions.rda")) {
  getSheet()
}

load(file = "emissions.rda")
load(file = "time_series.rda")

# Manually replace NA Layer in hierarchy value with correct value (checked in excel sheet)
emissions$`Layer in hierarchy` <-
  replace_na(emissions$`Layer in hierarchy`, 6)

# Get initial year (2018)
emission_year <- emissions %>%
  filter(Year == 2018)

# Extract summary information
summary_emission <- emission_year %>%
  filter(`Layer in hierarchy` == 1) %>%
  getSummary() %>%
  StartEnd()

# Reformat and clean time series data
time_series_summary <-
  timeSummary(time_series_data)    # Summary of total emissions
time_series_clean <-
  cleanSheet(time_series_data)   # Time series breakdown of individual components

# Get GHG data frame
total_ghg <- getGHG(summary_emission)

# Define global variable to track current year
currentYear <<- 2018

# Define UI for application that draws a histogram
ui <- fluidPage(
  # Adjust style of the shiny app
  tags$head(tags$style(
    HTML("
        body{
            font-family: 'Lato';
            color: #1b556b;
        }
    ")
  )),
  
  # Adjusting the style of the hover output
  # Below javascript code found from https://stackoverflow.com/questions/38917101/how-do-i-show-the-y-value-on-tooltip-while-hover-in-ggplot2
  tags$head(tags$style(
    '#toolTip {
        position: absolute;
        width: 125px;
         }'
  )),
  
  # CSS for the hover output
  tags$script(
    '
    $(document).ready(function() {
      // id of the plot
      $("#Emissions").mousemove(function(e) {

        // ID of uiOutput
        $("#toolTip").show();
        $("#toolTip").css({
          top: (e.pageY + 5) + "px",
          left: (e.pageX + 5) + "px"
        });
      });
    });
    '
  ),
  
  # Application title
  titlePanel("New Zealand's Interactive Emissions Tracker"),
  
  # Main panel with the emissions graph
  fluidRow(
    column(
      width = 8,
      # Choose the view for the main plot (Graph or table)
      radioButtons(
        "plotType",
        "Choose Plot Type",
        c("Graph View", "Table View"),
        selected = "Graph View",
        inline = TRUE
      ),
      # Switch to Table View when selected
      conditionalPanel(
        'input.plotType == "Table View"',
        selectInput(
          'YearComp',
          label = "Year to Compare",
          choices = time_series_summary$Year,
          selected = time_series_summary$Year[1]
        )
      ),
      # Switch to Graph view when selected (also default)
      conditionalPanel(
        'input.plotType == "Graph View"',
        plotOutput(
          'Emissions',
          height = "800px",
          click = "Emissions_click",
          hover = "Emissions_hover"
          )
      ),
      # Table View output
      conditionalPanel('input.plotType == "Table View"',
                       DTOutput('DataFrame')),
      fluidRow(
        column(width = 1,
               # Action button to go up a layer
               actionButton("LevelUp",
                            "Go up")),
        column(width = 1,
               # Action button to reset to base layer
               actionButton("Reset_Sector",
                            "Reset")),
        column(width = 10,
               # Output for Sector trace
               uiOutput("Sector_trace")),
        # Output for hover tooltip
        uiOutput("toolTip")
      )
    ),
    
    # Side panel with the year and GHG graphs
    column(
      width = 4,
      fluidRow(
        # Output for current year we're one
        uiOutput("Year_value"),
        # Year graph output
        plotOutput('Year',
                   click = "Year_click"),
      ),
      fluidRow(
        column(width = 8,
               # Output for currently filtered GHG
               uiOutput("GHG_selected")),
        column(width = 4,
               # Action button to reset filter to nothing
               actionButton("Reset_GHG",
                            "Reset")),
        # Output plot for GHG values
        plotOutput('GHG',
                   click = "GHG_click"),
      )
    )
  )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
  # reactiveValues and reactiveVal ------------------------------------------
  
  # Provide all required reactiveValues
  Emission_year <- reactiveValues(data = emission_year)
  
  Sector_Frame <- reactiveValues(data = NULL)
  
  Category_Selector <- reactiveValues(selected = NULL,
                   previous = vector(),
                   sector = NULL,
                   tracker = "[Sectors/Totals]",
                   GUID = vector())
  
  Year_Selector <- reactiveValues(selected = NULL,
                                  toHighlight = c(rep(FALSE, dim(
                                    time_series_summary
                                  )[1] - 1), TRUE))
  
  GHG_Selector <- reactiveValues(selected = vector(),
                                 toHighlight = rep(TRUE, length(total_ghg$Gas)))
  
  Current_Summary <- reactiveValues(summary = summary_emission)
  
  gross <- reactiveValues(value = sum(summary_emission[summary_emission$Totals > 0,]$Totals))
  
  Comparison_Frame <- reactiveValues(data = NULL)
  
  # reactiveVal for tracking levels
  level <- reactiveVal(0)
  
  # observeEvent ------------------------------------------------------------
  
  # Assign name based on selected bar input
  observeEvent(input$Emissions_click, {
    if (level() == 0) {
      # Obtain and assign selected bar
      Category_Selector$selected <-
        summary_emission$Sector[round(input$Emissions_click$x)]
      
      # Update dataframe based on selected sector
      Sector_Frame$data <- Emission_year$data %>%
        filter(Sector == as.character(Category_Selector$selected))
      
      # Update sector indicator 
      Category_Selector$sector <- as.character(Category_Selector$selected)
      
      # Temporary string to append onto tracker for base level
      temp_NoT <- Sector_Frame$data %>% 
        filter(`Layer in hierarchy` == 1) %>% 
        select(`Name on tab`, `GUID of node`)
       
      # Update GUID tracker
      Category_Selector$GUID <-
        c(Category_Selector$GUID, 
          temp_NoT$`GUID of node`)
      
      # Update tracker with temp_NoT
      Category_Selector$tracker <-
        paste0(Category_Selector$tracker, temp_NoT$`Name on tab`)
      
      # Increment level
      level(level() + 1)
    } else {
      
      # Determine sub-section by filtering via Location of Node in hierarchy
      sector_level <- Sector_Frame$data %>% 
        filter(`Location of Node in hierarchy` == Category_Selector$tracker) %>% 
        dplyr::arrange(match(.$`Name on tab`, Current_Summary$summary$`Name on tab`))
      
      # Update Category_Selector value only if not on lowest level
      if (sector_level[sector_level$`Name on tab` == sector_level$`Name on tab`[round(input$Emissions_click$x)],]$`Lowest level?` != "lowest") {
        # Update previous sector
        Category_Selector$previous <- c(Category_Selector$previous,
                                        as.character(Category_Selector$selected))
        
        # Update currently selected sector
        Category_Selector$selected <- sector_level$`Name on tab`[round(input$Emissions_click$x)]
        
        # Update GUID vector
        Category_Selector$GUID <- 
          c(Category_Selector$GUID, 
            sector_level %>% 
              filter(`Name on tab` == Category_Selector$selected) %>% 
              select(`GUID of node`) %>% 
              as.character())
        
        # Update tracker
        Category_Selector$tracker <- paste0(Category_Selector$tracker, Category_Selector$selected)
        
        # Increment level
        level(level() + 1)
      }
    }
    
  }, priority = 1)
  
  # Observe event for changing year
  observeEvent(input$Year_click, {
    # Update Year_Selector values
    Year_Selector$selected <- round(input$Year_click$x)
    Year_Selector$toHighlight <-
      time_series_summary$Year %in% Year_Selector$selected
  })
  
  # Go back up a level
  observeEvent(input$LevelUp, {
    # Only able to go up a level if we're not at the base level
    if (level() > 0) {
      # browser()
      Category_Selector$tracker <-
        str_remove(Category_Selector$tracker, "\\[[^\\[]+\\]$")
      Category_Selector$GUID <-
        Category_Selector$GUID[-level()]
      
      # Decrease level by 1
      newValue <- level() - 1
      
      # Update value
      level(newValue)
      
      if (level() == 0) {
        # Reset selected category once returned to 'base' level
        Category_Selector$selected <- NULL
      } else {
        Category_Selector$selected <-
          Category_Selector$previous[level()]
        Category_Selector$previous <-
          Category_Selector$previous[-level()]
      }
    }
  }, ignoreInit = TRUE)
  
  # Observe event for choosing GHG
  observeEvent(input$GHG_click, {
    ghg <- as.character(total_ghg$Gas[round(input$GHG_click$x)])
    
    if (!ghg %in% GHG_Selector$selected) {
      # Add GHG type if not already present
      GHG_Selector$selected <- c(GHG_Selector$selected, ghg)
    } else {
      # Remove GHG type if already present
      GHG_Selector$selected <-
        c(GHG_Selector$selected[-match(ghg, GHG_Selector$selected)])
    }
    
    # Update values to be highlighted
    if (is_empty(GHG_Selector$selected)) {
      # If none of the GHG are filtered for, all GHG should be highlighted
      GHG_Selector$toHighlight <- rep(TRUE, length(total_ghg$Gas))
    } else {
      GHG_Selector$toHighlight <-
        total_ghg$Gas %in% GHG_Selector$selected
    }
    
  }, priority = 1)
  
  # Reset GHG
  observeEvent(input$Reset_GHG,{
    
    GHG_Selector$selected <- vector()
    GHG_Selector$toHighlight <- rep(TRUE, length(total_ghg$Gas))
    
    }, ignoreInit = TRUE, priority = 0)
  
  # Reset Sector filters
  observeEvent(input$Reset_Sector, {
    # Reset level back to 0
    level(0)
    
    # Update Category_Selector values with default values
    Category_Selector$selected <- NULL
    Category_Selector$previous <- vector()
    Category_Selector$tracker <- "[Sectors/Totals]"
    Category_Selector$GUID <- vector()
  })
  
  # Observe event for TableOutput row clicked (only triggers in Table view)
  observeEvent(input$DataFrame_cell_clicked,{
    # Obtain information on clicked cell
    info = input$DataFrame_cell_clicked
                 
    # Don't do anything (return nothing) when no info, or clicked cell doesn't match requirements
    if (is.null(info$value) ||
        info$col != 0 ||
        info$row == (dim(Current_Summary$summary)[1] + 1))
      return()
   
    # If valid cell clicked:
    if (level() == 0) {
      Category_Selector$selected <- info$value
     
      # Update dataframe based on selected sector
      Sector_Frame$data <- Emission_year$data %>%
        filter(Sector == as.character(Category_Selector$selected))
     
      # Update sector indicator
      Category_Selector$sector <- as.character(Category_Selector$selected)
     
      # Create temporary string to store tracker update for base level
      temp_NoT <- Sector_Frame$data %>% 
        filter(`Layer in hierarchy` == 1) %>%
        select(`Name on tab`, `GUID of node`)
     
      # Update GUID
      Category_Selector$GUID <- c(Category_Selector$GUID, 
                                  temp_NoT$`GUID of node`)
     
      # Update tracker using temp_NoT
      Category_Selector$tracker <- paste0(Category_Selector$tracker, 
                                          temp_NoT$`Name on tab`)
     
      # Increment level
      level(level() + 1)
      
      } else {
        # Determine sector breakdown by filtering via Location of Node in hierarchy column
        sector_level <- Sector_Frame$data %>% 
          filter(`Location of Node in hierarchy` == Category_Selector$tracker)
     
        # Reorder sector_level such that it's sorted alphabetically (consistent with ggplot ordering)
        if (!all(sector_level$Totals >= 0) & !all(sector_level$Totals <= 0)) {
          sector_level <- sector_level %>%
            changeOrder()
        } else {
          sector_level <- sector_level %>%
            dplyr::arrange(`Name on tab`)
        }
        # Update Category_Selector values only if we're not on the lowest level
        if (sector_level[sector_level$`Name on tab` == info$value,]$`Lowest level?` != "lowest") {
       
          # Update previous value
          Category_Selector$previous <- c(Category_Selector$previous,
                                          as.character(Category_Selector$selected))
       
          # Update currently selected value
          Category_Selector$selected <- info$value
       
          # Update GUID
          Category_Selector$GUID <- c(Category_Selector$GUID, 
                                      sector_level %>% 
                                        filter(`Name on tab` == Category_Selector$selected) %>% 
                                        select(`GUID of node`) %>% 
                                        as.character())
       
          # Update tracker vector
          Category_Selector$tracker <- paste0(Category_Selector$tracker, 
                                           Category_Selector$selected)
       
          # Increment level
          level(level() + 1)
     }
   }
 }, ignoreInit = TRUE, priority = 1)
  
  # Reactives ------------------------
  # Reactive for when we change the category
  category_change <- reactive({
    # Determine new displayed sectors by filtering through Location of Node in hierarchy 
    emission_sector <- Sector_Frame$data %>% 
      filter(`Location of Node in hierarchy` == Category_Selector$tracker)
    
    # Change ordering such that it's appropriate for ggplot
    if (!all(sign(emission_sector$Totals) == sign(emission_sector$Totals[1]))) {
      emission_sector <- emission_sector %>% 
        changeOrder()
    } else {
      emission_sector <- emission_sector %>% 
        # dplyr::arrange(`Link to CRF import file`)
        dplyr::arrange(`Name on tab`)
    }
    
    # Reformat dataframe such that it's workable with plotting function
    emission_sector <- emission_sector %>%
      getSummarySectorBreakdown() %>%
      StartEnd()
    
    emission_sector
  })
  
  # Reactive for when we change the time sector (used for year graph)
  time_sector_change <- reactive({
    # Due to Road transportation being grouped all together prior to 2001, introduce switch case to capture this
    switch(as.character(Category_Selector$selected),
           # Case for All vehicle types
           `[1.A.3.b.i  All vehicle types]` = {
             time_sector <- time_series_clean %>%
               filter(`Link to CRF import file` == "1.A.3.b.i")
               
             # Update time_sector to remove 2000 and before
             time_sector[, as.character(c(2001:2018))] <- 0
             },
           
           # Case for Cars
           `[1.A.3.b.i  Cars]` = {
             time_sector <- time_series_clean %>% 
               filter(`Name on tab` == as.character(Category_Selector$selected))
             
             # Update time_sector to remove 2001 and after  
             time_sector[, as.character(c(1990:2000))] <- 0
             },
           {
             # Case for all other sectors
             time_sector <- time_series_clean %>%
               filter(GUID == Category_Selector$GUID[length(Category_Selector$GUID)])
             })
    
    time_sector
  })
  
  # Reactive for when we change the time sector with GHG filters
  time_sector_GHG <- reactive({
    
    # Obtain time series data after filtering for specified GHG emission types
    time_sector <- emissions %>% 
      filter(`GUID of node` == Category_Selector$GUID[length(Category_Selector$GUID)]) %>% 
      select(all_of(GHG_Selector$selected), Year) %>% 
      dplyr::arrange(-row_number())
    
    # Put 'filler' values (0) for certain sub-sections which don't have data for a given range of year
    if (length(time_sector$Year) != length(time_series_summary$Year)) {
      time_sector <- left_join(time_series_summary, time_sector, by = "Year")
      time_sector[,-c(1,2)] <- ifelse(is.na(time_sector[,-c(1,2)]), 0, time_sector[,-c(1,2)])
      time_sector <- time_sector %>% 
        select(-Emissions)
      time_sector <- time_sector[, c(2:dim(time_sector)[2], 1)]
    }  
    
    time_sector
  })
  
  # Reactive for when we change the year chosen at the base level
  year_change <- reactive({
    # Update Emission_year reactive with new year selected
    Emission_year$data <- emissions %>%
      filter(Year == Year_Selector$selected)
    
    # Update summary emission based on new year
    summary_emission <- Emission_year$data %>%
      filter(`Layer in hierarchy` == 1) %>%
      getSummary() %>%
      StartEnd()
    
    summary_emission
  })
  
  #Reactive for when we change the GHGs chosen
  GHG_change <- reactive({
    # Get list of currently 'active' GHG to filter for
    filter_for <- GHG_Selector$selected
    
    # Apply a different function based on the level in the hierarchy we're currently at
    filtered_GHG <- Emission_year$data %>% 
      filter(`Location of Node in hierarchy` == Category_Selector$tracker) %>% 
      select(1,2, all_of(filter_for), 10:dim(Emission_year$data)[2])

    col_num <- dim(filtered_GHG)[2]
    
    # Reformat dataframe to obtain summary data
    filtered_GHG <- add_column(filtered_GHG,
                               Totals = rowSums(filtered_GHG[,3:(2+length(filter_for)),
                                                             drop = FALSE]),
                               .after = "Name on tab")
    
    if (!all(filtered_GHG$Totals >= 0) & !all(filtered_GHG$Totals <= 0)) {
      filtered_GHG <- filtered_GHG %>%
        changeOrder()
    } else {
      filtered_GHG <- filtered_GHG %>%
        dplyr::arrange(`Name on tab`)
    }
    
    # Use appropriate functions to obtain summary data for plotting
    if (level() == 0) {
      filtered_GHG <- filtered_GHG %>%
        getSummary() %>%
        StartEnd()
    } else {
      filtered_GHG <- filtered_GHG %>%
        getSummaryGHG(length(GHG_Selector$selected)) %>%
        StartEnd()
    }
    
    filtered_GHG
  })
  
  # Reactive to get dataframe required for Table percentage changes
  YearComp_change <- reactive({
    # Determine whether a GHG filter is applied or not
    if (!is_empty(GHG_Selector$selected)) {
      # Has a GHG filter
      # Obtain data frame of year to be compared against
      Comparison <- emissions %>% 
        filter(Year == input$YearComp, `Location of Node in hierarchy` == Category_Selector$tracker) %>% 
        {
          if (isolate(level()) == 0)
            select(., Sector, GHG_Selector$selected)
          else 
            select(., `Name on tab`, GHG_Selector$selected)
        } %>% 
        mutate(Totals = rowSums(.[, -1,
                                  drop = FALSE])) %>%
        select(1, Totals)
      
      # Rearrange ordering of points in base level
      if (level() == 0) {
        Comparison <- Comparison[c(1, 2, 3, 5, 6, 4), ]
      }
      
    } else {
      # No GHG filters, apply other standard filters
      # Obtain data frame of year to be compared against
      Comparison <- emissions %>%
        filter(Year == input$YearComp, `Location of Node in hierarchy` == Category_Selector$tracker) %>% 
        {
          if (isolate(level()) == 0)
            getSummary(.) %>% 
            select(Sector, Totals)
          else
            getSummarySectorBreakdown(.) %>% 
            select(`Name on tab`, Totals)
        }  
    }

    # Append new row detailing totals onto Comparison data frame
    Comparison <- Comparison %>%
      {
        if(isolate(level()) == 0)
          rbind(., data.frame(Sector = "Total", Totals = sum(Comparison$Totals)))
        else
          rbind(., data.frame(Name = "Total", Totals = sum(Comparison$Totals)) %>% 
                  dplyr::rename(`Name on tab` = Name))
      }
    
    Comparison
  })
  
  # Output plots ------------------------------------------------------------
  
  # Output plot for main emissions graph
  output$Emissions <- renderPlot({
    # Apply different plotting command based on level of hierarchy we're currently at
    if (level() <= 0) {
      # Base level
      
      if (!is.null(Year_Selector$selected)) {
        # Check if year has changed from default (2018)
        summary_emission <- year_change()
      }
      
      if (!is_empty(GHG_Selector$selected)) {
        # Check if GHG filter exists
        summary_emission <- GHG_change()
      }
      
      # Begin formatting ggplot
      e <- summary_emission %>%
        ggplot(aes(x = Sector,
                   y = Start,
                   fill = Sector)) +
        geom_crossbar(aes(ymin = Start, ymax = End),
                      fatten = 0,
                      position = position_dodge()) +
        labs(title = "Emissions from Sectors",
             y = "Emissions CO2-e (kilotonnes)") +
        #theme_mfe() +
        #scale_fill_mfe(direction = 1) +
        scale_x_discrete(expand = c(0, 0)) +
        geom_hline(yintercept = max(summary_emission$End),
                   linetype = "dashed") +
        geom_text(aes(x = 1, y = max(End)), label = "Net", vjust = -1) +
        geom_hline(yintercept = summary_emission$End[6], linetype = "dashed") +
        geom_text(aes(x = 1, y = End[6]), label = "Gross", vjust = -1)
      
    } else {
      # Non-base level
      # Check if year is different from previous/default
      if (!is.null(Year_Selector$selected)) {
        if (Year_Selector$selected != currentYear) {
          # Update year for emission data
          Emission_year$data <- emissions %>%
            filter(Year == Year_Selector$selected)
          
          # Update sector data for the new year
          Sector_Frame$data <- Emission_year$data %>%
            filter(Sector == Category_Selector$sector)
          
          # Update the current year
          currentYear <<- Year_Selector$selected
        }
      }
      
      # Get appropriate sub category dataframe for the given year
      # Check if any filters for GHG
      if (!is_empty(GHG_Selector$selected)) {
        # If so, update dataframe
        summary_emission <- GHG_change()
      } else {
        summary_emission <- category_change()
      }
      
      title <-
        getTitle(as.character(Category_Selector$selected),
                 isolate(level()))
      
      # Begin formatting ggplot
      e <- summary_emission %>%
        ggplot(aes(x = `Name on tab`,
                   y = Start,
                   fill = `Name on tab`)) +
        geom_crossbar(aes(ymin = Start,
                          ymax = End),
                      fatten = 0,
                      position = position_dodge()) +
        labs(
          title = paste("Emissions from", title),
          y = "Emissions CO2-e (kilotonnes)",
          x = Category_Selector$sector
        ) +
        #theme_mfe() +
        #scale_fill_mfe(direction = 1) +
        geom_text(
          aes(
            y = End,
            label = paste0(round(Totals / max(End), 3) * 100, '%'),
            fontface = "bold"
          ),
          position = position_dodge(width = 0.9),
          vjust = -0.5,
          size = 8
        ) +
        scale_x_discrete(
          limits = summary_emission$`Name on tab`,
          expand = c(0, 0),
          labels = str_remove(
            str_sub(summary_emission$`Name on tab`, 2, -2),
            "\\d[\\d\\.\\w]+[\\s]+"
          )
        )
    }
    
    # Update Current_Summary reactiveValue with new summary_emission
    Current_Summary$summary <- summary_emission
    
    # Finish ggplot
    e + theme(
      plot.title = element_text(hjust = 0.5, size = 18),
      legend.position = 'none',
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.title.x = element_text(size = 16),
      axis.title.y = element_text(size = 16)
    ) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1)),
                         breaks = pretty(c(
                           min(summary_emission$Start,
                               summary_emission$End),
                           max(summary_emission$End,
                               summary_emission$Start)
                         ),
                         n = 10))
  })
  
  # Output of dataframe corresponding to the current graph
  output$DataFrame <- renderDT({
    if (level() <= 0) {
      # Base level
      
      if (!is.null(Year_Selector$selected)) {
        # Check if year has changed from default (2018)
        summary_emission <- year_change()
        
        # Update gross emissions value based on year
        gross$value <-
          sum(summary_emission[summary_emission$Totals > 0,]$Totals)
      }
      
      if (!is_empty(GHG_Selector$selected)) {
        # Check if GHG filter exists
        summary_emission <- GHG_change()
      }
      
    } else {
      # Non-base level
      if (!is.null(Year_Selector$selected)) {
        if (Year_Selector$selected != currentYear) {
          # Update year for emission data
          Emission_year$data <- emissions %>%
            filter(Year == Year_Selector$selected)
          
          # Update sector data for the new year
          Sector_Frame$data <- Emission_year$data %>%
            filter(Sector == Category_Selector$sector)
          
          # Update the current year
          currentYear <<- Year_Selector$selected
          
          # Update gross emissions value based on new year
          gross$value <- Emission_year$data %>%
            filter(`Layer in hierarchy` == 1) %>%
            {
              sum(.[.$Totals > 0, ]$Totals)
            }
        }
      }
      
      # Compute total sector emission (Used for Percentage (Sector))
      s_Emission <- Sector_Frame$data %>%
        filter(`Layer in hierarchy` == 1) %>%
        select(Totals) %>%
        as.numeric()
      
      # Get appropriate sub category dataframe for the given year
      summary_emission <- category_change()
      
      # Check if any filters for GHG
      if (!is_empty(GHG_Selector$selected)) {
        # If so, update dataframe
        summary_emission <- GHG_change()
      }
    }
    
    # Update Current_Summary reactiveValue with new summary_emission
    Current_Summary$summary <- summary_emission
    
    # Create df_output dataframe to be used for the renderDT output
    df_output <- summary_emission %>%
      # Get required columns based on layer in hierarchy
      {
        if (level() == 0)
          select(., Sector, Totals)
        else
          select(., `Name on tab`, Totals)
      } %>%
      # Compute new required columns
      # mutate(Totals = round(summary_emission$Totals, 2)) %>%
      mutate(`Percentage (gross)` =
               round(.$Totals / isolate(gross$value) * 100, 1)) %>%
      {
        # Append a new row detailing Totals for each column based on layer in hierarchy
        if (level() == 0)
          rbind(
            .,
            data.frame(
              Sector = "Total",
              Totals = round(sum(.$Totals), 2),
              Percent = sum(.[.$Totals > 0,]$`Percentage (gross)`)
            ) %>%
              dplyr::rename(`Percentage (gross)` = Percent)
          )
        else
          rbind(
            .,
            data.frame(
              Name = "Total",
              Totals = round(sum(.$Totals), 2),
              Percent = sum(.$`Percentage (gross)`)
            ) %>%
              dplyr::rename(`Percentage (gross)` = Percent) %>%
              dplyr::rename(`Name on tab` = Name)
          )
      } %>%
      dplyr::rename(`Emissions (kt CO2-e)` = Totals) %>%
      mutate(`Percentage (gross)` = paste0(as.character(`Percentage (gross)`), "%"))
    
    # Make naming/string adjustments based on the level we're at
    if (level() == 0) {
      df_output[df_output$Sector == "LULUCF", ]$`Percentage (gross)` <- ""
    } else {
      # Add colunn for Percentage (Sector) once beyond base level
      df_output <- df_output %>%
        mutate(PSector = paste0(round((`Emissions (kt CO2-e)` / s_Emission) * 100, 2
        ), "%"))
      
      # Rename above column
      names(df_output)[4] <-
        paste0("Percentage (", Category_Selector$sector, ")")
    }
    
    # Get dataframe for comparison percentage change column
    # browser()
    Comparison_Frame <- YearComp_change()
    
    if (level() > 0) {
      # Reorder Comparison_Frame such that the ordering matches df_output
      Comparison_Frame <- Comparison_Frame[match(df_output$`Name on tab`, Comparison_Frame$`Name on tab`), ]
    }

    # Add new column onto df_output
    df_output <- df_output %>%
      mutate(Comparison = as.factor(round(((df_output$`Emissions (kt CO2-e)` - Comparison_Frame$Totals) / abs(Comparison_Frame$Totals)
      ) * 100,
      1))) %>%
      mutate(Comparison = paste0(as.character(Comparison), "%"))
    
    # Rename column
    if (is.null(Year_Selector$selected)) {
      names(df_output)[names(df_output) == "Comparison"] <-
        paste0("Change from ", input$YearComp, " to 2018")
    } else {
      names(df_output)[names(df_output) == "Comparison"] <-
        paste0("Change from ",
               input$YearComp,
               " to ",
               Year_Selector$selected)
      
    }
    
    # Make adjustments to output when Percentage (Sector) and Percentage(gross) is 0 (due to rounding error)
    df_output[, 3] <- df_output[, 3] %>%
      str_replace("^0%$", "< 0.1%")
    
    df_output[, 4] <- df_output[, 4] %>%
      str_replace("^0%$", "< 0.1%")
    # browser()
    
    df_output <- df_output %>% 
      mutate(`Emissions (kt CO2-e)` = round(`Emissions (kt CO2-e)`, 2))
    
    # Return df_output to renderDT as output with few parameters
    df_output %>%
      datatable(selection = 'none', rownames = FALSE) %>%
      formatStyle(1, cursor = 'pointer')
  })
  
  # Output plot for time series of total emissions
  output$Year <- renderPlot({
    # Check if any category is chosen
    if (is.null(Category_Selector$selected)) {
      # No category chosen
      # Check if any filtering required for GHG
      if (!is_empty(GHG_Selector$selected)) {
        # If so, filter for required GHGs
        t <- emissions %>%
          filter(`Layer in hierarchy` == 0) %>%
          select(all_of(GHG_Selector$selected), Year) %>% 
          mutate(Emissions = rowSums(.[,-dim(.)[2], drop = FALSE])) %>% 
          dplyr::arrange(-row_number())
      } else {
        # If not, use imported time series summary dataframe
        t <- time_series_summary
      }
      
    } else {
      # A category is chosen
      # Check for any filtering requirements for GHG
      if (!is_empty(GHG_Selector$selected)) {
        # If so, filter for required GHGs
        time_sector <- time_sector_GHG()
        
        # Create new Emissions columns for plotting purposes
        time_sector <- time_sector %>%
          mutate(Emissions = rowSums(time_sector[, -dim(time_sector)[2], drop = FALSE]))
        
      } else {
        # If not, filter for desired subcategory
        time_sector <- time_sector_change() %>%
          dplyr::arrange(-row_number())
        
        # Restructure dataframe for plotting
        time_sector <-
          as.data.frame(t(as.matrix(time_sector[, 4:32])))
        time_sector$Year <- as.numeric(row.names(time_sector))
        names(time_sector)[1] <- "Emissions"
        
      }
      
      t <- time_sector
    }
    
    # Create ggplot based on required dataframe
    t %>%
      ggplot(aes(
        x = Year,
        y = Emissions,
        fill = ifelse(Year_Selector$toHighlight, yes = "Yes", no = "No")
      )) +
      geom_bar(stat = "identity",
               width = 0.5) +
      labs(title = "Select Year",
           y = "Emissions (kt CO2-e)") +
      scale_fill_manual(values = c("Yes" = "mediumvioletred", "No" = "plum2")) +
      #theme_mfe() +
      theme(
        plot.title = element_text(hjust = 0.5, size = 16),
        legend.position = 'none',
        axis.text.x = element_text(angle = 0),
        axis.title.x = element_text(size = 14),
        axis.title.y = element_text(size = 14)
      ) +
      scale_x_continuous(expand = c(0, 0),
                         breaks = pretty(c(1990, 2018),
                                         n = 5)) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1)))
  })
  
  # Output plot for GHG breakdowns
  output$GHG <- renderPlot({
    # Check if a Sector is chosen
    if (!is.null(Category_Selector$selected)) {
      # If so, update summary with new category/sub category
      summary_emission <- category_change()
      
      # Update ghg dataframe to match new emission summary
      total_ghg <- getGHG(summary_emission)
      
    } else if (!is.null(Year_Selector$selected)) {
      # Check if year has changed from previous
      if (Year_Selector$selected != currentYear) {
        # If so, update summary with new year
        summary_emission <- year_change()
        
        # Update ghg dataframe to match new emission summary
        total_ghg <- getGHG(summary_emission)
      }
    }
    
    # Plotting function
    total_ghg %>% filter(Gas != "Totals") %>%
      ggplot(aes(
        x = Gas,
        y = Emission,
        fill = ifelse(GHG_Selector$toHighlight,
                      yes = "Yes",
                      no = "No")
      )) +
      geom_bar(stat = "identity") +
      labs(title = "Select Greenhouse Gas",
           x = "Gas Type",
           y = "Emissions (kt CO2-e)") +
      scale_fill_manual(values = c("Yes" = "green4",
                                   "No" = "palegreen3")) +
      #theme_mfe() +
      theme(
        plot.title = element_text(hjust = 0.5, size = 16),
        legend.position = 'none',
        axis.text.x = element_text(angle = 0),
        axis.title.x = element_text(size = 14),
        axis.title.y = element_text(size = 14)
      ) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
      scale_x_discrete(expand = c(0, 0))
  })
  
  # Output textInput for showing which Year is currently selected
  output$Year_value <- renderUI({
    textInput(
      inputId = "Year_label",
      label = "Selected Year ",
      value = Year_Selector$selected,
      placeholder = "Default Year - 2018"
    )
  })
  
  # Output selectInput for showing which GHG/s are filtered for
  output$GHG_selected <- renderUI({
    selectInput(
      inputId = "GHG_label",
      label = NULL,
      choices = c("Select GHG to filter for" = "", GHG_Selector$selected),
      selected = GHG_Selector$selected,
      multiple = TRUE,
      width = '100%'
    )
  })
  
  # Output selectInput for tracing the sectors we've gone down
  output$Sector_trace <- renderUI({
    selectInput(
      inputId = "SectorTrace_label",
      label = NULL,
      choices = c(
        "Trace for Sectors" = "" ,
        Category_Selector$previous,
        as.character(Category_Selector$selected)
      ),
      selected = c(
        Category_Selector$previous,
        as.character(Category_Selector$selected)
      ),
      multiple = TRUE,
      width = '100%'
    )
  })
  
  # Output for registering hover over main plot
  output$toolTip <- renderUI({
    hover <- input$Emissions_hover
    req(!is.null(hover))
    if (level() == 0) {
      y <-
        Current_Summary$summary[Current_Summary$summary$Sector == Current_Summary$summary$Sector[round(hover$x)], ]
    } else {
      y <-
        Current_Summary$summary[Current_Summary$summary$`Name on tab` == Current_Summary$summary$`Name on tab`[round(hover$x)], ]
    }
    
    req(nrow(y) != 0)
    verbatimTextOutput("values")
    
  })
  
  # Output the values that correspond to the bar that is hovered over
  output$values <- renderPrint({
    hover <- input$Emissions_hover
    req(!is.null(hover))
    if (level() == 0) {
      y <- Current_Summary$summary[Current_Summary$summary$Sector == Current_Summary$summary$Sector[round(hover$x)], ]
    } else {
      y <- Current_Summary$summary[Current_Summary$summary$`Name on tab` == Current_Summary$summary$`Name on tab`[round(hover$x)], ]
    }
    
    req(nrow(y) != 0)
    round(y$Totals, 2)
  })
}

# Run the application
shinyApp(ui = ui, server = server)