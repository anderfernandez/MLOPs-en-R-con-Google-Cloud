# Install & load libraries  
libs = c('plumber', 'forecast', 'yaml', 'dplyr', 'timetk', 'lubridate',
         'tidymodels', 'modeltime')

print(list.files())
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load Variables
predict_data_info =  read_yaml('config/parameters.yaml')[['predict_api']]
model_url = predict_data_info$model_url
data_url = predict_data_info$data_url


# Load model
download.file(data_url,"data.RData", mode="wb")
download.file(model_url,"model.RData", mode="wb")

model = readRDS("model.RData")
data = readRDS("data.RData")

# Clean data
data$datetime = ymd_hms(data$datetime)
data$date = as.Date(data$datetime)
data$percentage = NULL
data$datetime = NULL


#* @apiTitle Predictions API
#* @apiDescription API to get predictions of Spanish Electricity Demand

#* Get the predictions
#* @param horizon The message to echo
#* @post /get_predictions
function(horizon = "2 months") {
  
  predictions = model %>%
    modeltime_forecast(
      h = horizon,
      actual_data = data
      ) %>%
    filter(.model_desc != 'ACTUAL') %>%
    select(.index, .value, .conf_lo, .conf_hi)
  
  predictions$prediction_date = Sys.Date()
  
  return(predictions)
}
