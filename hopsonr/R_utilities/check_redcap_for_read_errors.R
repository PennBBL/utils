#Load Relevant Packages
library("bitops")
library("RCurl")
library("REDCapR")
source("/import/speedy/scripts/hopsonr/R_utilities//redcap_read_rdh.R")

project<-commandArgs(trailingOnly=TRUE)[1]

if (exists("testing")){
      project<-"WOLF SATTERTHWAITE Project"
}

redcap_uri <- "https://banshee.uphs.upenn.edu/api/"
ALL_Projects<-read.csv("~/.redcap.cfg")

#List of projects needed for full data import 
projects<-ALL_Projects[which(ALL_Projects[,1] == project),]

####Importing selected Banshee Redcap Project and Dictionary####
i<-1
p.token<-projects[i,2]
name<-projects[i,1]
#print(p.token)
#print(name)

project_dictionary<-redcap_metadata_read(redcap_uri=redcap_uri, token=p.token,config_options = list(ssl.verifypeer=FALSE))$data
unique_id<-project_dictionary$field_name[1]
batch=10000
project_ids<-redcap_read_rdh(
      redcap_uri = redcap_uri,
      token = p.token,
      #records = ids,
      config_options = list(ssl.verifypeer=FALSE),
      fields=unique_id,
      batch_size=batch
)$data

project_data<-redcap_read_rdh(
      redcap_uri = redcap_uri,
      token = p.token,
      config_options = list(ssl.verifypeer=FALSE),
      batch_size=batch
)$data

if(nrow(project_data)!=nrow(project_ids)){
      print("Error in reading data. Finding problem records")
      problemids<-project_ids$participant_id[which(! project_ids$participant_id %in% project_data$participant_id)]
      batch<-batch/10
      while(batch >= 1){
            #print(paste("batch: ",batch,sep=""))
            #print(paste("problemids: ",problemids,sep=""))
            project_data_issues<-redcap_read_rdh(
                  redcap_uri = redcap_uri,
                  token = p.token,
                  config_options = list(ssl.verifypeer=FALSE),,
                  records=problemids,
                  batch_size=batch
            )$data
            problemids<-problemids[which(! problemids %in% project_data_issues[[unique_id]])]
            batch<-batch/10
      }
      print("Error detected in: ")
      print(problemids)
} else {
      print(paste("No errors detected in ",project,sep=""))
}