# Install & load libraries  
libs = c('forecast', 'yaml', 'dplyr', 'timetk', 'lubridate',
         'tidymodels', 'modeltime', 'reticulate','neptune')

sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load Variables
predict_data_info =  read_yaml('config/parameters.yaml')[['predict']]
predict_horizon = predict_data_info$horizon
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

# Make predictions
predictions = model %>%
  modeltime_forecast(h = predict_horizon, actual_data = data) %>%
  filter(.model_desc != 'ACTUAL') %>%
  select(.index, .value, .conf_lo, .conf_hi)

predictions$prediction_date = Sys.Date()

# Append to predictions
if(file.exists(predictions_path)){
  
  # Load past predictionsa & append
  past_predictions = readRDS(predictions_path)
  predictions = bind_rows(past_predictions, predictions)
  
}

# Save predictions
saveRDS(predictions, predictions_path)

predictions %>% ggplot(aes(.index, .value, col = .model_desc)) + geom_line()
