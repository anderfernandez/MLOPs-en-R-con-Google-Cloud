# Install & load libraries  
libs = c( 'yaml', 'dplyr', 'lubridate', 'httr', 'glue', 'jsonlite')
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load Variables
GITHUB_TOKEN = Sys.getenv("TOKEN")

retrain_info =  read_yaml('config/parameters.yaml')[['retrain']]
predictions_path = retrain_info$predictions_path
data_path = retrain_info$data_path
max_mae = retrain_info$max_mae
n_days = retrain_info$n_days
github_user = retrain_info$github_user
github_repo = retrain_info$github_repo
github_event_type = retrain_info$github_event_type

# Read Data
data = readRDS(data_path)
predictions = readRDS(predictions_path)


# Unify data
data$datetime = ymd_hms(data$datetime) %>% as.Date(.)
predictions$.index = as.Date(predictions$.index)

# For each date, get latest prediction % join the real data
comparison = predictions %>%
  group_by(.index, prediction_date) %>%
  arrange(desc(prediction_date)) %>%
  slice(1) %>%
  ungroup() %>%
  inner_join(data, by = c('.index' = 'datetime')) %>%
  slice_max(n = n_days, order_by = .index)

mae = mean(abs(comparison$value - comparison$.value))

if(mae > max_mae){
  
  url = glue('https://api.github.com/repos/{github_user}/{github_repo}/dispatches')
    
  body  = list("event_type" = github_event_type) 
  resp = POST(url, 
       add_headers('Authorization' = paste0('token ', GITHUB_TOKEN)),
       body = jsonlite::toJSON(body, pretty = T, auto_unbox = T)
       )
}
