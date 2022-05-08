# Install & load libraries  
libs = c('plumber', 'forecast', 'yaml', 'dplyr', 'timetk', 'lubridate',
         'tidymodels', 'modeltime')

print(list.files())
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load Variables
predict_data_info =  read_yaml('config/parameters.yaml')[['predict']]
model_path = predict_data_info$model_path
data_path = predict_data_info$data_path
predictions_path = predict_data_info$predictions_path

# Load model
model = readRDS(model_path)
data = readRDS(data_path)

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
