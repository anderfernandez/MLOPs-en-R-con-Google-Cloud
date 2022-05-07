libs = c('httr', 'jsonlite', 'lubridate', 'dplyr', 'yaml', 'glue')
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Read parameters file
parameters = read_yaml('config/parameters.yaml')[['data_extraction']]

time_trunc = parameters$time_trunc
category = parameters$category
subcategory = parameters$subcategory
first_date = parameters$first_date
output_path = parameters$output_path
output_filename_data = parameters$output_filename_data
output_filename_date = parameters$output_filename_date
max_time_call = parameters$max_time_call


# Create full paths
output_data = glue("{output_path}/{output_filename_data}")
output_date = glue("{output_path}/{output_filename_date}")

# Read last date
if(output_filename_date %in% list.files(output_path)){
  first_date =readRDS(output_date)
}


get_real_demand = function(url){
  resp = GET(url)
  tmp = content(resp, type = 'text', encoding = 'UTF-8') %>% fromJSON(.)
  return(tmp$included$attributes$values[[1]])
}

# I calculate the extraction dates as dates as a substract from today
if(time_trunc == 'hour'){
  now = floor_date(Sys.time(), unit = time_trunc) 
  hours_extract = difftime(now, ymd_hms(first_date), units = 'days') %>% as.numeric(.)
  hours_extract = hours_extract * 24  
} else{
  now = floor_date(Sys.Date()-1, unit = time_trunc)
  hours_extract = difftime(now, ymd(first_date), units = 'days') %>% as.numeric(.)
}


if(hours_extract > max_time_call){
  n_extractions = ceiling(hours_extract/max_time_call)
  diff_times = as.difftime( max_time_call * 1:n_extractions, units = paste0(time_trunc,'s'))
  date_extractions = now - diff_times
  
} else{
  date_extractions = c(first_date)
  
}

# I add today as last day
date_extractions = c(now, date_extractions)


# Change Format
date_extractions = format(date_extractions, '%Y-%m-%dT%H:%M')

if(time_trunc == 'hour'){
  date_extractions[length(date_extractions)] = ymd_hms(first_date) %>% format(., '%Y-%m-%dT%H:%M')  
} else{
  date_extractions[length(date_extractions)] = ymd(first_date) %>% format(., '%Y-%m-%dT%H:%M')
}


# I create the URLs
urls = c()

for(i in 1:(length(date_extractions)-1)){
  url = paste0(
    'https://apidatos.ree.es/en/datos/',
    category,'/', subcategory,
    '?start_date=', date_extractions[i+1],
    '&end_date=', date_extractions[i],
    '&time_trunc=', time_trunc
  )
  urls = c(urls, url)
}

# Get URLs Asynchronously
# resps = getURLAsynchronous(urls)
resps = lapply(urls, get_real_demand)

resps =list()
for(i in 1:length(urls)){
  resps[[i]] =  get_real_demand(urls[i])
  print(i)
  Sys.sleep(1)
}


# From list to df
data = bind_rows(resps)

# Check if data exists
if(output_filename_data %in% list.files(output_path)){
  
  # Read previous data & merge
  prev_data = readRDS(output_data)
  data = bind_rows(data, prev_data)
  
}



# Save the file
saveRDS(data, output_data)
saveRDS(now, output_date)
