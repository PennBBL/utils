###designed by rdh for appending individual items to complete measures from the wolf/satterthwaite projects. 
###difference between this and collapse measures is that this generates one line for each line in the inital measure
##################################################################
#dw_request<-append_items(measure="prt",items=c("newfranksummary","bdisummary","cdsssummary","diagnosis","studyenroll"))

append_items<-function(measure=NULL,items=NULL){
#Load Relevant Packages
library("bitops")
library("RCurl")
library("REDCapR")
source("/import/speedy/scripts/hopsonr/R_utilities//redcap_read_rdh.R")
version<-"append_items_v1"

#Create a redcap.cfg file in Users directory with ALL User-Projects and User-specific Tokens
redcap_uri <- "https://banshee.uphs.upenn.edu/API/"
ALL_Projects<-read.csv("~/.redcap.cfg")

#List of projects needed for full data import 
projects<-ALL_Projects[which(ALL_Projects[,1] == "WOLF SATTERTHWAITE Project"),]

####Importing selected Banshee Redcap Project and Dictionary####
i<-1
p.token<-projects[i,2]
name<-projects[i,1]
#print(p.token)
#print(name)
project_data<-redcap_read_rdh(
      redcap_uri = redcap_uri,
      token = p.token,
      config_options = list(ssl.verifypeer=FALSE),
      batch=1000,
      interbatch_delay=5
)$data
project_dictionary<-redcap_metadata_read(redcap_uri=redcap_uri, token=p.token,config_options = list(ssl.verifypeer=FALSE))$data
#####
###

#####convert dates to usable values####
formatA<-grep("/",project_data$dovisit,invert=T)
formatB<-grep("/",project_data$dovisit,invert=F)
project_data$dovisit2[c(formatA)]<-as.Date(project_data$dovisit[c(formatA)], format="%Y%m%d")
project_data$dovisit2[c(formatB)]<-as.Date(project_data$dovisit[c(formatB)], format="%m/%d/%y")
project_data$dovisit2<-as.Date(project_data$dovisit2,origin="1970-01-01")
project_data$dovisit<-project_data$dovisit2

##remove lines w no dovisit
project_data<-project_data[which(! is.na(project_data$dovisit)),]

measure_data<-project_data[which(project_data$procedure==measure),
                           c(project_dictionary$field_name[which(project_dictionary$form_name %in% c("general",measure))])]
items_measures<-unique(project_dictionary$form_name)
for (item in items){
      columns<-project_dictionary$field_name[which(project_dictionary$form_name %in% c("general",item))]
      item_columns<-project_dictionary$field_name[which(project_dictionary$form_name==item)]
      measure_data[,c(item_columns)]<-NA
      temp<-project_data[which(project_data$procedure==item),c(columns)]
      for (j in seq_along(measure_data$bblid)){
            bblid<-measure_data$bblid[j]
            date<-measure_data$dovisit[j]
            if (! is.na(date)){
                  temp2<-temp[which(temp$bblid==bblid),]
                  temp2$dist<-temp2$dovisit-date
                  if(nrow(temp2) > 0 & length(temp2$participant_id[which(! is.na(temp2$dovisit))]) > 0){
                        row<-temp2[which(abs(temp2$dist) == min(abs(temp2$dist))),]
                        measure_data[j,c(item_columns)]<-
                              row[,item_columns]                  
                  } else if(nrow(temp2) == 1 & length(temp2$participant_id[which(! is.na(temp2$dovisit))]) == 0) {
                        row<-temp2
                        measure_data[j,c(item_columns)]<-
                              row[,item_columns] 
                  } else if(nrow(temp2) == 1 & length(temp2$participant_id[which(! is.na(temp2$dovisit))]) == 1){
                        row<-temp2
                        measure_data[j,c(item_columns)]<-
                              row[,item_columns]                         
                  } else if(nrow(temp2) == 0) {
                        measure_data[j,c(item_columns)]<-NA 
                  }
                  else {
                        print("Error")
                        print(j)
                        print(bblid)
                        print(temp2)
                  }
            }
      }
}
measure_data$version<-version
return(measure_data)
}


