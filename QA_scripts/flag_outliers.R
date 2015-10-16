# this is a subscript of QA.sh that should run at the end of the script.
# The other scripts called by QA.sh create some csvs with thickness, volume,
# surface area, and curvature. This script flags all of these based 2sd outliers.
# The measures that are flagged are based on comments here:
# http://saturn/wiki/index.php/QA
#EDITS: ASEG ROI FLAGS ADDED 2/25/15 BY MQ. NONE OF THE ORIGINAL SCRIPT WAS DELETED OR EDITED, ONLY ASEG ROI SPECIFIC FLAGS
#WERE ADDED. THE NEW ADDS ARE DENOTED BY "2/25/15 MQ" WRITTEN UNDER THE SECTION TITLE. 

### ARGS ###
############
subjects.dir<-commandArgs(TRUE)[1]
if(is.na(subjects.dir)) subjects.dir<-'/import/monstrum/eons_xnat/group_results_n1445/freesurfer/subjects'
sdthresh<-2

### DIRS ###
############
stats.dir<-file.path(subjects.dir, '../stats')
aparc.dir<-file.path(stats.dir, 'aparc.stats')
aseg.dir<-file.path(stats.dir, 'aseg.stats')
area.dir<-file.path(stats.dir, 'aparc.stats/area')
curvature.dir<-file.path(stats.dir, 'aparc.stats/curvature')

### MEAN FILES ###
##################
mean.file<-file.path(aparc.dir, 'bilateral.meanthickness.totalarea.csv')
cnr.file<-file.path(stats.dir, 'cnr/cnr_buckner.csv')
snr.file<-file.path(stats.dir, 'cnr/snr.txt')
aseg.volume.file<-file.path(aseg.dir, 'aseg.stats.volume.csv')
lh.thickness.file<-file.path(aparc.dir, 'lh.aparc.stats.thickness.csv')
rh.thickness.file<-file.path(aparc.dir, 'rh.aparc.stats.thickness.csv')

### READ MEAN DATA ###
######################
mean.data<-read.csv(mean.file, strip.white=TRUE)
mean.data$meanthickness<-rowMeans(mean.data[, c('rh.meanthickness', 'lh.meanthickness')])
mean.data$totalarea<-rowSums(mean.data[, c('rh.totalarea', 'lh.totalarea')])
mean.data<-mean.data[,!(grepl('lh', names(mean.data)) | grepl('rh', names(mean.data)))]
#cnr.data<-read.csv(cnr.file, strip.white=TRUE) 
#full<-merge(mean.data, cnr.data, all=TRUE) ########MQ 2/26/15 THESE LINES IS COMMENTED OUT BECAUSE IT APPEARS THAT THE CNR FILE IS COMING IN LIKE THE SNR FILE AND NEEDS TO BE SPLIT INTO BBLID
#SCANID AND ALSO HEADERS NEED TO BE ADDED
full<- mean.data

# the snr evaluation is not robust
# if it seems to have something wrong with it
# this will ignore it.
snr.data<-try(read.table(snr.file, strip.white=TRUE, header=FALSE, col.names=c('subject', 'snr')))
if(is.data.frame(snr.data)){
	snr.data[,c('bblid', 'scanid')]<-apply(do.call(rbind, strsplit(as.character(snr.data$subject), split="_")), 2, as.numeric)
	snr.data<-snr.data[,-1]
	full<-merge(full, snr.data, all=TRUE)
}

#######MQ 2/26/15 ADDING THIS NEW READ.CSV FOR CNR DATA BASED ON THE SAME ONE FOR SNR DATA
cnr.data<-try(read.table(cnr.file, strip.white=TRUE, header=FALSE, col.names=c('subject', 'cnr')))
cnr.data<-try(read.table(cnr.file, header=FALSE, col.names=c('subject', 'cnr')))
if(is.data.frame(snr.data)){
  cnr.data[,c('bblid', 'scanid')]<-apply(do.call(rbind, strsplit(as.character(cnr.data$subject), split="_")), 2, as.numeric)
  cnr.data<-cnr.data[,-1]
  full<-merge(full, cnr.data, all=TRUE)
}

aseg.volume.data<-read.table(aseg.volume.file, strip.white=TRUE, header=TRUE)
aseg.volume.data[,c('bblid', 'scanid')]<-apply(do.call(rbind, strsplit(as.character(aseg.volume.data$Measure.volume), split="_")), 2, as.numeric)
aseg.volume.data<-aseg.volume.data[,c("bblid", "scanid", "SubCortGrayVol", "CortexVol", "CorticalWhiteMatterVol")]
full<-merge(full, aseg.volume.data, all=TRUE)

### READ IN THICKNESS DATA ###
##############################
thickness.data<-read.table(lh.thickness.file, header=TRUE, strip.white=TRUE)
rh.thickness.data<-read.table(rh.thickness.file, header=TRUE, strip.white=TRUE)
thickness.data[,c('bblid', 'scanid')]<-apply(do.call(rbind, strsplit(as.character(thickness.data$lh.aparc.thickness), split="_")), 2, as.numeric)
rh.thickness.data[,c('bblid', 'scanid')]<-apply(do.call(rbind, strsplit(as.character(rh.thickness.data$rh.aparc.thickness), split="_")), 2, as.numeric)
rh.thickness.data<-rh.thickness.data[,-1]
thickness.data<-thickness.data[,-1]
thickness.data<-merge(thickness.data, rh.thickness.data, all=TRUE)
rm('rh.thickness.data')

### READ IN ASEG VOLUME DATA ###
#2/25/15 MQ: ASEG VOLUME DATA IS READ IN A SECOND TIME SO THAT IT CAN BE SUBSET INTO ROI SPECIFIC AND LATERALITY SPECIFIC DATASHEETS
#WITHOUT ALTERING ANY OF THE PREVIOUS CODE
##############################
volume.data<-read.table(aseg.volume.file, strip.white=TRUE, header=TRUE)
volume.data[,c('bblid', 'scanid')]<-apply(do.call(rbind, strsplit(as.character(volume.data$Measure.volume), split="_")), 2, as.numeric)

### FLAG APARC ROI OUTLIERS ###
#########################
lh.names<-grep('lh', names(thickness.data), value=TRUE)
rh.names<-sub('lh', 'rh', lh.names)
# count number of outlying regions for each subject
thickness.data$noutliers.thickness.rois<-rowSums(abs(scale(thickness.data[,c(lh.names, rh.names)]))> sdthresh)
# number of outliers in laterality for each subject
thickness.data$noutliers.lat.thickness.rois<-rowSums(abs(scale((thickness.data[,lh.names] - thickness.data[,rh.names])/(thickness.data[,lh.names] + thickness.data[,rh.names])))> sdthresh)

### FLAG APARC ROI OUTLIERS ###
#2/25/15 MQ: APARC OUTLIERS ARE CALCULATED FOR SINGLE ROIS. LATERALITY IS ALSO CALCULATED FOR THESE REGIONS.
#########################

# flag outlying regions for each subject and laterality for each subject
flag_names<- names(thickness.data[c(lh.names, rh.names)])
laterality_names<- substring(lh.names,4,nchar(lh.names))
thickness.data[,paste(flag_names, 'outlier', sep="_")]<-as.numeric(abs(scale(thickness.data[,c(lh.names, rh.names)]))> sdthresh)
thickness.data[,paste(laterality_names, 'laterality_outlier', sep="_")]<-as.numeric(abs(scale((thickness.data[,lh.names] - thickness.data[,rh.names])/(thickness.data[,lh.names] + thickness.data[,rh.names])))> sdthresh)

### FLAG ASEG ROI OUTLIERS ###
#2/25/15 MQ: ASEG VOLUME DATA IS SUBSET TO COLUMNS OF INTEREST (AS PER DAVID ROALF AND TED SATTERTHWAITE), AND OUTLIERS FOR THESE
#ROIS ARE CALCULATED THE SAME WAY THEY ARE FOR APARC ROIS. LATERALITY IS ALSO CALCULATED FOR THESE REGIONS.
#LATERALITY IS ALSO THEN CALCULATED FOR THE CORTICAL VOLUME AND WHITE MATTER VOLUME BECAUSE THIS IS NOT DONE IN THE APARC STEP
#########################
volume.data2<- volume.data[,c('bblid','scanid','Left.Lateral.Ventricle','Left.Thalamus.Proper','Left.Caudate','Left.Putamen','Left.Pallidum','X3rd.Ventricle','X4th.Ventricle','Brain.Stem','Left.Hippocampus','Left.Amygdala','Left.Accumbens.area','Right.Lateral.Ventricle','Right.Thalamus.Proper','Right.Caudate','Right.Putamen','Right.Pallidum','Right.Hippocampus','Right.Amygdala','Right.Accumbens.area','X5th.Ventricle','CC_Posterior','CC_Mid_Posterior','CC_Central','CC_Mid_Anterior','CC_Anterior')]
lh.names_aseg<-grep('Left', names(volume.data2), value=TRUE)
rh.names_aseg<-sub('Left', 'Right', lh.names_aseg)

flags_aseg<-names(volume.data2)[3:ncol(volume.data2)]
flags_aseg_lat<-names(volume.data2[lh.names_aseg])
flags_aseg_lat<- substring(flags_aseg_lat,6,nchar(flags_aseg_lat))

# flag outlying regions for each subject and laterality for each subject
volume.data2[,paste(flags_aseg, 'outlier', sep="_")]<-as.numeric(abs(scale(volume.data2[,flags_aseg]))>sdthresh)
volume.data2[,paste(flags_aseg_lat, 'laterality_outlier', sep="_")]<-as.numeric(abs(scale((volume.data2[,lh.names_aseg] - volume.data2[,rh.names_aseg])/(volume.data2[,lh.names_aseg] + volume.data2[,rh.names_aseg])))> sdthresh)

# count number of outlying regions for each subject
volume.data2$noutliers.aseg_volume.rois<-rowSums(abs(scale(volume.data2[,flags_aseg]))> sdthresh)
# number of outliers in ROI laterality for each subject
volume.data2$noutliers.lat.aseg_volume.rois<-rowSums(abs(scale((volume.data2[,lh.names_aseg] - volume.data2[,rh.names_aseg])/(volume.data2[,lh.names_aseg] + volume.data2[,rh.names_aseg])))> sdthresh)
#number of outliers in mean whole brain laterality for each subject
lh.names_aseg2<-grep('lh', names(volume.data), value=TRUE)
rh.names_aseg2<-sub('lh', 'rh', lh.names_aseg2)
volume.data$noutliers.lat.aseg_volume.cortex<-rowSums(abs(scale((volume.data[,lh.names_aseg2] - volume.data[,rh.names_aseg2])/(volume.data[,lh.names_aseg2] + volume.data[,rh.names_aseg2])))> sdthresh)
#add whole brain laterality column totals to data with roi laterality totals
volume.data2$noutliers.lat.aseg_volume.cortex<- volume.data$noutliers.lat.aseg_volume.cortex[match(volume.data2$scanid,volume.data$scanid)]

### MERGE RESULTS OF ROI FLAGS WITH MEAN DATA ###
#################################################

thickness.data<-thickness.data[,c('bblid', 'scanid', 'noutliers.thickness.rois', 'noutliers.lat.thickness.rois')]
full<-merge(full, thickness.data, all=TRUE)

### FLAG ON MEAN, CNR, SNR, AND NUMBER OF ROI FLAGS ### 
#######################################################
flags<-names(full)[which(!names(full) %in% c('bblid', 'scanid'))]
mean.flags<-c('meanthickness', 'totalarea', "SubCortGrayVol", "CortexVol", "CorticalWhiteMatterVol")
full[,paste(mean.flags, 'outlier', sep="_")]<-as.numeric(abs(scale(full[,mean.flags]))>sdthresh)
full$cnr_outlier<-as.numeric(scale(full$cnr)<(-sdthresh))
if(is.data.frame(snr.data))
	full$snr_outlier<-as.numeric(scale(full$snr)<(-sdthresh))

noutliers.flags<-grep('noutlier', names(full), value=T)
full[,paste(noutliers.flags, 'outlier', sep="_")]<-as.numeric(scale(full[,noutliers.flags])>sdthresh)
write.csv(full, file.path(stats.dir, paste('all.flags.with.aparc.n' , nrow(full),'.csv', sep='')), quote=FALSE, row.names=FALSE)
cat('wrote file to', file.path(stats.dir, paste('all.flags.with.aparc.n' , nrow(full),'.csv', sep='')), '\n')

####2/25/15 MQ: WRITE OUT ASEG DATA TO SAME PLACE AS APARC DATA
write.csv(volume.data2, file.path(stats.dir, paste('aseg_flags.n' , nrow(volume.data2),'.csv', sep='')), quote=FALSE, row.names=FALSE)
cat('wrote file to', file.path(stats.dir, paste('aseg_flags.n' , nrow(volume.data2),'.csv', sep='')), '\n')
