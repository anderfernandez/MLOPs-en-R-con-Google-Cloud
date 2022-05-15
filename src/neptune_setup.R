# Load libraries
libs = c('yaml', 'reticulate','neptune', 'dplyr')
sapply(libs[!libs %in% installed.packages()], install.packages)
sapply(libs, require, character.only = T)

# Load variables
train_data_info =  read_yaml('config/parameters.yaml')[['train']]
neptune_envname = train_data_info$neptune$envname

# Install Miniconda
install_miniconda()
if(!neptune_envname %in% conda_list()$name){conda_create(envname = neptune_envname)}
conda_installations = conda_list()
conda_dir = conda_installations$python[conda_installations$name == neptune_envname] %>%
  gsub('\\', '/',., fixed =T)

use_condaenv(conda_dir)

# Install Neptune
neptune_install(
  method = 'conda',
  conda = conda_binary(),
  envname = neptune_envname
)
