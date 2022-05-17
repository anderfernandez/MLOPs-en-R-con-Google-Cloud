
libs = c('shiny', 'yaml', 'dplyr', 'ggplot2', 'lubridate', 'plotly', 'tidyr')
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Get parameters
config = read_yaml('config.yaml')
data_url = config$data_url
predictions_url = config$predictions_url

ui <- fluidPage(
  includeCSS("www/style.css"),
  h1('Spain Electricity Forecast Dashbaord Control'),
  
  fluidRow(class = 'metrics',
    column(3, class = "metric_card",
           p("Mean Square Error", class = "metric"),
           textOutput('mse')),
    column(3,  class = "metric_card",
           p("Root Mean Square Error", class = "metric"),
           textOutput('rmse')),
    column(3, class = "metric_card",
           p("Mean Absolute Error", class = "metric"),
           textOutput('mae')),
    column(3, class = "metric_card",
           p("Mean Percentage Error", class = "metric"),
           textOutput('mape') )
  ),
  
  fluidRow(
    class = 'graphs',
    plotlyOutput('evolution'),
    
  ), 
  
  div(class = "retrain",
    p("Retrain or Refresh Data"),
    actionButton('refresh', 'Refresh Data'),
    actionButton('retrain', 'Retrain Model'),
  )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
  
  
  data_merged = eventReactive(input$refresh, {
    
    # Read Data
    download.file(data_url,"data.RData", mode="wb")
    download.file(predictions_url,"predictions.RData", mode="wb")
    
    data = readRDS("data.RData")
    predictions = readRDS("predictions.RData")
    
    # Parse Date
    predictions$.index = as.Date(predictions$.index) 
    data$datetime = as.Date(data$datetime)
    
    # Join the data
    data_merged = left_join(data, predictions, by = c("datetime" = ".index"))
    data_merged = data_merged %>% filter(!is.na(value) & !is.na(.value))
    
    data_merged
    
  },
  ignoreNULL = FALSE
  )
  
  output$mae = renderText({
    
    data_merged = data_merged()
    
    d = data_merged$value - data_merged$.value 
    mean(abs(d))
    
  })
  
  output$mse = renderText({
    
    data_merged = data_merged()
    d = data_merged$value - data_merged$.value 
    mean((d)^2)
    
  })
  
  output$rmse = renderText({
    
    data_merged = data_merged()
    d = data_merged$value - data_merged$.value 
    sqrt(mean((d)^2))
    
  })
  
  output$mape = renderText({
    
    data_merged = data_merged()
    d =  data_merged$.value - data_merged$value 
    mape = mean(abs(d)/data_merged$value)
    paste0(round(mape*100,2),"%")
    
  })
  
  
    output$evolution <- renderPlotly({
      
      data_merged = data_merged()
      
      gg = data_merged %>% 
        filter(!is.na(.value)) %>%
        rename(prediction = .value) %>%
        select(datetime, value, prediction, .conf_lo, .conf_hi, prediction_date) %>%
        group_by(datetime) %>%
        slice_max(order_by = prediction_date , n = 1) %>%
        ungroup() %>%
        select(-prediction_date) %>%
        pivot_longer(cols = -c("datetime"), names_to = "type", values_to = "value") %>%
        ggplot(aes(datetime, value, col = type)) + geom_line(size = 1) +
        theme_minimal() +
        theme(legend.position = "bottom")
      
      ggplotly(gg)
      
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
