# Train Model

# # Clear environment before library loading
# if('RETICULATE_PYTHON' %in% names(Sys.getenv())){
#   print('Removing RETICULATE_PYTHON from environment')
#   Sys.unsetenv('RETICULATE_PYTHON')
# }
# 
# # Setup conda
# conda_installations = reticulate::conda_list()
# conda_dir = gsub('\\', '/',
#                  conda_installations$python[conda_installations$name == neptune_envname], 
#                  fixed =T)
# Sys.setenv(RETICULATE_PYTHON = conda_dir)
# Install & load libraries  

libs = c('forecast', 'yaml', 'dplyr', 'timetk', 'lubridate',
         'tidymodels', 'modeltime', 'reticulate','neptune')

sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load Variables
train_data_info =  read_yaml('config/parameters.yaml')[['train']]
resampling = train_data_info$resampling
input = train_data_info$input
output_path = train_data_info$output_path
output_filename = train_data_info$output_filename
allow_parallel = train_data_info$allow_parallel
parallel_cores = train_data_info$parallel_cores
neptune_envname = train_data_info$neptune$envname
neptune_project = train_data_info$neptune$project
model_output = train_data_info$model_output
best_model_output = train_data_info$best_model_output

# Read Data
data = readRDS(input)
neptune_api_key = Sys.getenv('api_key')

# Fix timestamp
data$datetime = ymd_hms(data$datetime)
data$date = as.Date(data$datetime)
data$percentage = NULL
data$datetime = NULL

# Make splits
splits = data %>%
  time_series_split(assess = resampling, cumulative = TRUE)

# Create recipe for preprocessing
recipe_spec_final <- recipe(value ~ ., data = training(splits)) %>%
  step_timeseries_signature(date) %>%
  step_fourier(date, period = 365, K = 5) %>%
  step_rm(date) %>%
  step_rm(all_nominal_predictors()) %>%
  step_rm(date_index.num) %>%
  step_rm(contains("iso"), contains("minute"), contains("hour"),
          contains("am.pm"), contains("xts")) %>%
  step_zv(all_predictors())


bake(prep(recipe_spec_final), new_data =  training(splits)) %>% glimpse(.)

# Create models --> Accepted boost_tree 
if("boost_tree" %in% names(train_data_info$models)){
  
  model_parameters = train_data_info$models$boost_tree$parameters %>% 
    unlist(.) %>% strsplit(., ',')
  
  model_parameters = data.frame(model_parameters) %>% tibble()
  
  
  model_grid = model_parameters %>%
    create_model_grid(
      f_model_spec = boost_tree,
      engine_name  = train_data_info$models$boost_tree$engine,
      mode         = train_data_info$prediction_mode
  )
  
}

# Create the workflow set
workflow <- workflow_set(
  preproc = list(recipe_spec_final),
  models = model_grid$.models, 
  cross = T
  )


control_fit_workflowset(
  verbose   = TRUE,
  allow_par = TRUE
)

if(allow_parallel){
  parallel_start(parallel_cores)
}

# Train in parallel
model_parallel_tbl <- workflow %>%
  modeltime_fit_workflowset(
    data    = training(splits),
    control = control_fit_workflowset(
      verbose   = TRUE,
      allow_par = allow_parallel
    )
  )

if(allow_parallel){
  parallel_stop()
}

calibrated_table = model_parallel_tbl %>%
  modeltime_calibrate(testing(splits)) 
  
accuracy_table = calibrated_table %>% modeltime_accuracy()

# Extract parameters for each model
for(i in 1:nrow(accuracy_table)){
  
  run <- neptune_init(
    project= neptune_project,
    api_token= neptune_api_key,
    python = 'conda',
    python_path = conda_dir
  )
  
  # Extract & log parameters
  model_specs = extract_spec_parsnip(workflow$info[[i]]$workflow[[1]])
  parameters = list()
  parameters[['engine']] = model_specs$engine
  parameters[['mode']] = model_specs$mode
  
  for(arg in names(model_specs$args)){
    parameters[[arg]] = as.character(model_specs$args[[arg]])[2]  
  }
  
  run["parameters"] = parameters
  
  # Add each metric in the accuracy table
  for(col in 4:ncol(accuracy_table) ){
    print(col)
    metric = colnames(accuracy_table)[col]
    run[paste0("evaluation/",metric)] = accuracy_table[[i, col]]
  }
  
  saveRDS(workflow$info[[i]]$workflow, model_output)
  neptune_upload(run["model"], model_output)
  
}

# Get best model
best_model = accuracy_table$.model_id[accuracy_table$mae == min(accuracy_table$mae)] 

# Save best model
saveRDS(calibrated_table[best_model,], best_model_output)