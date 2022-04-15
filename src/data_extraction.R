# Extract data from Coinmarketcap and Save it

# 1. Load libraries
libs = c('crypto2', 'curl', 'yaml', 'dplyr')
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load Variables
variables_data =  read_yaml('parameters.yaml')[['data_extraction']]
interval = variables_data$interval
coins = variables_data$coins
output_file_name = variables_data$output_file_name
output_file_path = variables_data$output_path
output_file = paste0(output_file_path, '/', output_file_name)

# Transform coins to vector
coins = gsub(' ','', coins) %>%  strsplit(., ',') %>% unlist(.)

# Extract coins data
input_list = crypto_list() %>% filter(symbol %in% coins)

# Read last date
if(output_file_name %in% list.files(output_file_path)){
  previous_data = readRDS(output_file)
  last_updated_date = max(previous_data$timestamp) %>%
      format(., '%Y%m%d')
  
  message(
    paste0('Previous data found. Data will be extracted from ', last_updated_date)
    )
  
} else{
  last_updated_date = NULL
  message('No previous file found. Extracting all historical data.')
}


# Extract data
new_data = crypto_history(
  coin_list = input_list, 
  interval = 
    , 
  start_date = last_updated_date, 
  end_date = Sys.Date() %>% format(., '%Y%m%d'),
  finalWait = F
  )

# Get intersting variables
keep_cols = c('timestamp', 'symbol', 'close')

if(output_file_name %in% list.files(output_file_path)){
  
  bind_rows(previous_data, new_data[keep_cols]) %>%
    saveRDS(., output_file)
  message('Previous file found. File joined & saved.')
  
  }else{
    saveRDS(new_data[keep_cols], output_file)  
    message('No previous file found. File saved directly.')
  }

