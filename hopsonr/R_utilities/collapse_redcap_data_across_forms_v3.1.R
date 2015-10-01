#V3 is an attempt to add the ability to select only certain measures
#V3.1 cleaned up code, fixed bugs leaving out participants with no slected measures, and dropped unnescessary columns

#Load Relevant Packages
library("bitops")
library("RCurl")
library("REDCapR")

######date matching measures from redcap#######
#####parse arguments#####
print(commandArgs(trailingOnly=TRUE))
project<-commandArgs(trailingOnly=TRUE)[1]
range<-commandArgs(trailingOnly=TRUE)[2]
ids_path<-commandArgs(trailingOnly=TRUE)[3]
out_path<-commandArgs(trailingOnly=TRUE)[4]
range<-as.numeric(range)
arguments_count<-length(commandArgs(trailingOnly=TRUE))
if (arguments_count > 4 ){
      selected_measures<-
            commandArgs(trailingOnly=TRUE)[5:arguments_count]
      print(paste("Selected measures are: ",paste(selected_measures,collapse=" "),sep=""))
}
#####

###variables for testing - sets args if in test mode#####
if (exists("testing")){
      project<-"WOLF SATTERTHWAITE Project"
      #ids_path<-"/import/monstrum/Users/hopsonr/test2_bblid_date.csv"
      ids_path<-"/import/monstrum/Users/adaldal/test_bblid_date2.csv"
      range=365
      out_path<-"/import/monstrum/Users/hopsonr/test_collapsed_output_v3f.csv"
      selected_measures<-c("pas","qls")
      arguments_count<-5
}
#####

###read in bblid and date
ids<-read.csv(ids_path,header=F,col.names=c("bblid","date"))

#Scriptimports user projects from REDCap to R using an Application Programming Interface & User-Specific Tokens
#Tokens for projects provided by REDCap administrator
#Tokens need to be saved in a config file (.redcap.cfg) that is only editable by user 

#Create a redcap.cfg file in Users directory with ALL User-Projects and User-specific Tokens
redcap_uri <- "https://banshee.uphs.upenn.edu/redcap/API/"
ALL_Projects<-read.csv("~/.redcap.cfg")

#List of projects needed for full data import 
projects<-ALL_Projects[which(ALL_Projects[,1] == project),]

####Importing selected Banshee Redcap Project and Dictionary####
i<-1
p.token<-projects[i,2]
name<-projects[i,1]
#print(p.token)
#print(name)
project_data<-redcap_read_oneshot(
      redcap_uri = redcap_uri,
      token = p.token,
      config_options = list(ssl.verifypeer=FALSE)
)$data
project_dictionary<-redcap_metadata_read(redcap_uri=redcap_uri, token=p.token,config_options = list(ssl.verifypeer=FALSE))$data
#####

#fill in blank measures - removed starting in V3. procedure is required in redcap now, so can't be blank
#project_data$procedure<-matrix(unlist(strsplit(project_data$participant_id,split="_")), ncol=3, byrow=TRUE)[,2]
#backup<-project_data

###temporary fix to mismatched project_data$procedure/project_dictionary$form_name
if (length(unique(project_data$procedure)[which(! unique(project_data$procedure) %in% unique(project_dictionary$form_name))]) > 0){
      stop("Procedures and forms unmatched. Please check your Redcap data.")
}

###initialize output data frame#####
if (arguments_count > 4){
      project_measures<-unique(project_dictionary$form_name)[which(unique(project_dictionary$form_name) %in% selected_measures)]
      if(length(selected_measures[which(! selected_measures %in% unique(project_dictionary$form_name))]) > 0){
            missing_selected_measures<-selected_measures[which(! selected_measures %in% unique(project_dictionary$form_name))]
            stop(paste("One or more selected measures do not exist: ",paste(missing_selected_measures,collapse=" "),sep=""))
      }
      column_names<-project_dictionary$field_name[which(project_dictionary$form_name %in% c(project_measures,"general"))]
      project_data<-project_data[,c(column_names)]
      project_data<-project_data[which(project_data$procedure %in% project_measures),]
}else{
      project_measures<-unique(project_dictionary$form_name)
}
project_measures<-project_measures[which(! project_measures=="general")]
n_measures<-length(project_measures)
project_data[,paste(project_measures,"distance",sep="_")]<-NA
project_data[,paste(project_measures,"dovisit",sep="_")]<-NA
project_data[,paste(project_measures,"included",sep="_")]<-NA
project_data$dist<-NA
project_data$date_provided<-NA
project_data$dovisit2<-NA
output<-as.data.frame(matrix(nrow=0,ncol=ncol(project_data)),row.names=NULL)
colnames(output)<-colnames(project_data)
bblid_row<-as.data.frame(matrix(nrow=1,ncol=ncol(project_data)),row.names=NULL)
colnames(bblid_row)<-colnames(project_data)

#####

#####convert dates to usable values####
formatA<-grep("/",project_data$dovisit,invert=T)
formatB<-grep("/",project_data$dovisit,invert=F)
project_data$dovisit2[c(formatA)]<-as.Date(project_data$dovisit[c(formatA)], format="%Y%m%d")
project_data$dovisit2[c(formatB)]<-as.Date(project_data$dovisit[c(formatB)], format="%m/%d/%y")
project_data$dovisit2<-as.Date(project_data$dovisit2,origin="1970-01-01")
#####

####loop through participants, collapse across forms####
for (i in 1:nrow(ids)){
      ####check date for participant
      bblid<-ids[i,1]
      date<-ids[i,2]

      ##make first row
      bblid_row$bblid<-bblid
      bblid_row$date_provided<-date
      output<-rbind(output,bblid_row)

      #print(date)
      #date<-ids$date[which(ids$bblid==bblid)]
      #convert input date to usable
      date<-as.Date(as.character(date), format="%Y%m%d")

      #make temp of bblid
      temp<-project_data[which(project_data$bblid == bblid & project_data$dovisit2 > date - range & project_data$dovisit2 < date + range),]

      #get all measures for that participant
      measures=unique(temp$procedure)
      #get distance for rows
      temp$dist<-temp$dovisit2 - date
      if (length(measures) > 0){
            for (measure in measures){
                  ###get the row that contains the version of the measure closest to the date
                  row<-temp[which(temp$procedure==measure & abs(temp$dist) == min(abs(temp$dist[which(temp$procedure==measure)]))),]
                  if ( min(abs(temp$dist[which(temp$procedure==measure)])) == Inf){print(bblid)}
                  if ( min(abs(temp$dist[which(temp$procedure==measure)])) == Inf){print(bblid)}
                  ###if more than one measure is the same distance from the date, take the first one
                  if (nrow(row) > 1){row<-row[which.min(row$dovisit2),]}
                  ###if more than one measure exists on the same day, take the one with fewest NAs
                  if (nrow(row) > 1){
                        na_counts<-apply(row,1,function(x) length(x[which(is.na(x))]))
                        row<-row[which.min(na_counts),]
                  }
                  ###if there are STILL multiple measures, I give up, take the first one
                  if (nrow(row) > 1){row<-row[1,]}
                  ###fill in measures for output
                  output[which(output$bblid==bblid & as.Date(as.character(output$date_provided), format="%Y%m%d")==date),c(project_dictionary$field_name[which(project_dictionary$form_name==measure)])]<-
                        row[,c(project_dictionary$field_name[which(project_dictionary$form_name==measure)])]
                  ###add distance and date for each measure
                  output[which(output$bblid==bblid & as.Date(as.character(output$date_provided), format="%Y%m%d")==date),paste(measure,"distance",sep="_")]<-row$dist
                  output[which(output$bblid==bblid & as.Date(as.character(output$date_provided), format="%Y%m%d")==date),paste(measure,"dovisit",sep="_")]<-row$dovisit
                  output[which(output$bblid==bblid & as.Date(as.character(output$date_provided), format="%Y%m%d")==date),paste(measure,"included",sep="_")]<-1
            }
      }
      ###set missing measures to NA
      for (missing_measure in project_measures[which(! project_measures %in% measures & project_measures != "general")]){
            output[which(output$bblid==bblid & output$date_provided==date),c(project_dictionary$field_name[which(project_dictionary$form_name==missing_measure)])]<-NA
            output[which(output$bblid==bblid & as.Date(as.character(output$date_provided), format="%Y%m%d")==date),paste(missing_measure,"included",sep="_")]<-0
      }

}
#####

###remove unnecessary columns added for collapsing#####
output$dovisit2=NULL
output$dist=NULL
output$dovisit=NULL
output$participant_id<-NULL
output$procedure<-NULL
#####

####write out data####
write.table(output,file=out_path,sep=",",row.names=F)
####