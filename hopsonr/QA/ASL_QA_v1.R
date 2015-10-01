####check for config file
print(commandArgs(trailingOnly=TRUE))
qa_path<-commandArgs(trailingOnly=TRUE)[1]
out_path<-commandArgs(trailingOnly=TRUE)[2]
visual_qa<-commandArgs(trailingOnly=TRUE)[3]
redcap_project<-commandArgs(trailingOnly=TRUE)[4]

if (exists("testing")){
      qa_path<-"/import/monstrum/eons2_xnat/scripts/ASL/QA/automated_qa.csv"
      #qa_path<-"/import/monstrum/eons_xnat/redcap/imaging_variables/n1601_asl_automated_QA_4_7_15.csv"
      out_path<-"~/ASL_QA_test_data.csv"
      #out_path<-"/import/monstrum/eons_xnat/redcap/imaging_variables/n1601_asl_excludes_4_7_15.csv"
      visual_qa<-"/import/monstrum/eons2_xnat/redcap/imaging/n404_asl_visual_QA.csv"
      #visual_qa<-"/import/monstrum/eons_xnat/redcap/imaging_variables/n1601_asl_visual_QA_4_7_15.csv"
      #redcap_project<-"PNC-LG_Imaging"
}

###test if arguments are valid
if (! file.exists(qa_path)){stop(paste(qa_path," not found.",sep=""))}else{qa_data<-read.csv(qa_path)}

#exclude based on cut offs
#data[,c("meancbf_flag","motion_exclude","tsnr_exclude","clipcount_exclude","zerosinmask_exclude","artifact_exclude")]<-0
#data$motion_exclude[which(data$motion > 0.5)]<-1 #exclude participants with meanrelrms > 0.5
#data$tsnr_exclude[which(data$tsnr < 30)]<-1 #exclude participants with tsnr < 30
#data$clipcount_exclude[which(data$clipcount > 500)]<-1 #exclude participants with > 500 clipped voxels
#data$zerosinmask_exclude[which(data$zerosinmask > 50)]<-1 #exclude participants with > 50 empty voxels inside original eons group mask

###set qa vars to 0
qa_data[,c("no_data_exclude","not_processed_exclude","mean_rel_rms_exclude","max_rel_rms_exclude","tsnr_exclude","coverage_flag","nclips_exclude",
           "mean_intensity_flag","negative_voxels_flag","visual_inspection_exclude","inspected")]<-0

qa_data$no_data_exclude<-qa_data$no_data_collected ###exclude participants w/ no data collected
qa_data$not_processed_exclude<-qa_data$missing_data ###exclude participants w/ no data processed
qa_data$mean_rel_rms_exclude[which(qa_data$meanrel > 0.5)]<-1 ###exclude participants w/ higher than 0.5 mean rel rms
qa_data$max_rel_rms_exclude[which(qa_data$maxrel > 6)]<-1 ###exclude participants w/ higher than 8 max rel rms
qa_data$tsnr_exclude[which(qa_data$tsnr < 30)]<-1 ###exclude participants w/ tsnr < 30
qa_data$nclips_exclude[which(qa_data$nclips > 500)]<-1 ###exclude participants w/ nclips > 500
qa_data$coverage_flag[which(qa_data$zeros_in_mask > 50)]<-1 ###flag participants w/ > 200 empty voxels in group mask
#qa_data$signal_out_of_mask_flag[which(qa_data$voxels_out_of_mask > 60000)]<-1 ###flag participants w/ > 60000 activated voxels out of MNI brain mask #signal out of mask excluded 0 participants
#qa_data$fslcc_flag[which(qa_data$fslcc < 0.6)]<-1 ###flag participants w/ less that 0.6 correlation with MNI brain (not clear that this will be a great measure) #fslcc only excluded 1 participant, and then for neg voxels
qa_data$mean_intensity_flag[which(qa_data$mean_intensity < 40)]<-1 ###flag participants w/ less that 30 mean cbf ##should this also flag > 80??
qa_data$negative_voxels_flag[which(qa_data$negative_voxels > 2000)]<-1 ###flag participants w/ > 35000 negative voxels

apply(qa_data[,which(substring(colnames(qa_data),nchar(colnames(qa_data))-3,100)=="flag")],2,function(x) sum(x,na.rm=T))
qa_data$flagged<-apply(qa_data[,which(substring(colnames(qa_data),nchar(colnames(qa_data))-3,100)=="flag")],1,function(x) sum(x,na.rm=T))

if (file.exists(visual_qa)){
      visual_qa_data<-read.csv(visual_qa)
      qa_data$visual_inspection_exclude[which(qa_data$bblid %in% visual_qa_data$bblid)]<-visual_qa_data$visual_inspection_exclude[
            match(qa_data$bblid[which(qa_data$bblid%in% visual_qa_data$bblid)],visual_qa_data$bblid)]
      qa_data$inspected[which(qa_data$bblid %in% visual_qa_data$bblid)]<-visual_qa_data$inspected[
            match(qa_data$bblid[which(qa_data$bblid%in% visual_qa_data$bblid)],visual_qa_data$bblid)]      
}

apply(qa_data[,which(substring(colnames(qa_data),nchar(colnames(qa_data))-6,100)=="exclude")],2,function(x) sum(x,na.rm=T))
qa_data$excluded<-apply(qa_data[,which(substring(colnames(qa_data),nchar(colnames(qa_data))-6,100)=="exclude")],1,function(x) sum(x,na.rm=T))

write.table(qa_data,out_path,row.names=F,quote=F,sep=",")
write.table(qa_data[which(qa_data$flagged>0),c("bblid","scanid","flagged","inspected","visual_inspection_exclude")],visual_qa,row.names=F,quote=F,sep=",")

#commandArgs

#source()




