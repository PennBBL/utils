####check for config file

configfile<-commandArgs(trailingOnly=TRUE)[1]
if (is.na(configfile)){
  stop("This script requires a config.R file.")
} else if (! file.exists(configfile)){
  stop(paste("config file",configfile,"does not exist.",sep=" "))
} else {
  source(configfile)
}




