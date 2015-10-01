###workaround for ssl certificate issue with Banshee. needs removed soon###
config_options<-list(cainfo="/import/monstrum/tmp/addtrustexternalcaroot.crt",ssl.verifypeer=FALSE)

################################################
#Import Redcap Projects into R #################
################################################
#Scriptimports user projects from REDCap to R using an Application Programming Interface & User-Specific Tokens
#Tokens for projects provided by REDCap administrator
#Tokens need to be saved in a config file (.redcap.cfg) that is only editable by user 

#Load Relevant Packages
library("bitops")
library("RCurl")
library("REDCapR")

args<-commandArgs()

#Create a redcap.cfg file in Users directory with ALL User-Projects and User-specific Tokens
uri <- "https://banshee.uphs.upenn.edu/api/"
ALL_Projects<-read.csv("~/.redcap.cfg")

#List of projects needed for full data import 
#projects<-ALL_Projects[which(ALL_Projects[,1] %in% c("PNC-LG_Timepoint3_Imaging")),]
projects<-ALL_Projects[which(ALL_Projects[,1]==args[5]),]

csv_to_upload<-read.csv("/import/monstrum/Users/hopsonr/test.txt")
csv_to_upload<-read.csv(file.path(args[6]))

result_write <- REDCapR::redcap_write(ds=csv_to_upload, redcap_uri=uri, token=projects$token,config_options= httr::config(ssl_verifypeer=FALSE,ssl_verifyhost=FALSE))
result_write$raw_text


