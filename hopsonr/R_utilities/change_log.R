change_log<-function(outfile=NULL,df_original=NULL,df_new=NULL){
      if(missing(outfile)){stop("Must specify an outfile to use change_log")}
      if(missing(df_original)){stop("Must specify an original data frame to use change_log")}
      if(missing(df_new)){stop("Must specify a new data frame to use change_log")}
      
      cat("New lines:","\n",file=outfile)
      added<-df_new[which(! df_new$participant_id %in% df_original$participant_id),c("participant_id","bblid","procedure")]
      for (i in 1:nrow(added)){
            cat(paste(added[i,],sep=",",collapse=","),"\n",sep="",file=outfile,append=TRUE)
      }

      cat("\n","Changed lines:","\n",file=outfile,append=TRUE,sep="")
      #check changed nas
      na_changed_ids<-df_original$participant_id[apply(is.na(df_original)!=is.na(df_new[which(df_new$participant_id %in% df_original$participant_id),]),1,any)]
      for (i in na_changed_ids){
            na_changed_cols<-colnames(df_original)[which(is.na(df_original[which(df_original$participant_id==i),])!=is.na(df_new[which(df_new$participant_id==i),]))]
            line<-i
            for (j in na_changed_cols){
                  line<-paste(line,",",j,":",df_original[ df_original$participant_id==i,j],",",df_new[ df_new$participant_id==i,j],sep="")
            }
            cat(line,"\n",file=outfile,append=TRUE)
      }

      #check change values
      changed_ids<-df_original$participant_id[apply(df_original!=df_new[which(df_new$participant_id %in% df_original$participant_id),],1,any)]
      changed_ids<-changed_ids[which(! is.na(changed_ids))]
      for (i in changed_ids){
            #print(i)
            changed_cols<-colnames(df_original)[which(df_original[which(df_original$participant_id==i),]!=df_new[which(df_new$participant_id==i),])]
            line<-i
            for (j in changed_cols){
                  line<-paste(line,",",j,":",df_original[ df_original$participant_id==i,j],",",df_new[ df_new$participant_id==i,j],sep="")
            }
            cat(line,"\n",file=outfile,append=TRUE)
      }
}


