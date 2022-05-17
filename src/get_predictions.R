# Load libraries
libs = c('yaml', 'httr', 'jsonlite')
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load variables
predict_info =  read_yaml('config/parameters.yaml')[['predict']]
horizon = predict_info[['horizon']]
service_url = predict_info[['service_url']]
service_endpoint = predict_info[['service_endpoint']]
predictions_path = predict_info[['predictions_path']]

# Construct the API call
url = paste0(service_url,'/',service_endpoint)

resp = POST(url)
predictions = fromJSON(content(resp, type = "text")) 

# Read the predictions
past_predictions = readRDS(predictions_path)

# Merge files
predictions$.index = as.Date(predictions$.index)
predictions$prediction_date = as.Date(predictions$prediction_date)
all_predictions = bind_rows(past_predictions, predictions)

# Save predictions
saveRDS(all_predictions, predictions_path)