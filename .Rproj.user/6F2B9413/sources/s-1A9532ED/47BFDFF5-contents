library(shiny)
library(ggplot2)

ui <- fluidPage(
  
  tags$head(tags$style('
     #my_tooltip {
      position: absolute;
      width: 300px;
      z-index: 100;
      padding: 0;
     }
  ')),
  
  tags$script('
    $(document).ready(function() {
      // id of the plot
      $("#distPlot").mousemove(function(e) { 

        // ID of uiOutput
        $("#my_tooltip").show();         
        $("#my_tooltip").css({             
          top: (e.pageY + 5) + "px",             
          left: (e.pageX + 5) + "px"         
        });     
      });     
    });
  '),
  
  selectInput("var_y", "Y-Axis", choices = names(iris)),
  plotOutput("distPlot", hover = "plot_hover"),
  uiOutput("my_tooltip")
  
  
)

server <- function(input, output) {
  
  
  output$distPlot <- renderPlot({
    req(input$var_y)
    ggplot(iris, aes_string("Sepal.Width", input$var_y)) + 
      geom_point()
  })
  
  output$my_tooltip <- renderUI({
    hover <- input$plot_hover 
    y <- nearPoints(iris, input$plot_hover)[input$var_y]
    req(nrow(y) != 0)
    verbatimTextOutput("vals")
  })
  
  output$vals <- renderPrint({
    hover <- input$plot_hover 
    y <- nearPoints(iris, input$plot_hover)[input$var_y]
    req(nrow(y) != 0)
    y
  })  
}
shinyApp(ui = ui, server = server)