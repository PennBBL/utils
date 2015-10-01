first=1
max=0
rm -f /import/monstrum/Users/hopsonr/idemo_temp.txt

#for i in `ls -d /import/monstrum/eons_xnat/subjects/*/*_bbl1_idemo2_210/stats/*_bbl1_idemo2_210_SEQ*_idemo_behav_incorr_*.feat/stats/sig_maps_sbia/eons_std`
for i in `ls -d /import/monstrum/eons_xnat/subjects/*/*_bbl1_idemo2_210/stats/*_bbl1_idemo2_210_SEQ*_idemo_behav_incorr_*.feat/stats/sig_maps_sbia/eons_std`
do
	subdir=`echo $i | cut -d "/" -f 1-6`
	bblid=`echo $i | cut -d "/" -f 6 | cut -d "_" -f 1`
	scanid=`echo $i | cut -d "/" -f 6 | cut -d "_" -f 2`
	echo $bblid,$scanid
	mask=`ls $subdir/*_mprage/sbia/*labeled_SimRank+IC+FS*.nii.gz`
	mask_count=`echo $mask | wc -w`
	[ $mask_count != 1 ] && echo "wrong number of masks - " $mask_count && continue
	grep -q ^$bblid /import/monstrum/eons_xnat/redcap/imaging_variables/n1601_idemo_behav_incorr_sbia_rois_all_copes.csv && echo "already run" && continue
	echo $i >> /import/monstrum/Users/hopsonr/idemo_temp.txt


#	for cope in `ls -v $i/*sig_cope*`
#	#for cope in `ls -v $i/*sig_cope1_rai*`
#	do
#		cope_name=`echo $cope | sed s/'sig_cope'/','/g | cut -d "," -f 2 | cut -d "_" -f 1`
#		rois=`3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 1p`
#		rois=`echo $rois,`
#		values=`3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 2p`
#		line=$bblid,$scanid,$cope_name
#		count=1
#		for item in `echo $all | tr "," " "`
#		do
#			#echo $item
#			if [ "X`echo $rois | grep $item,`" != "X" ];then
#				value=`echo $values | cut -d "," -f $count`
#				line=`echo $line,$value`
#				((count++))
#			else
#				line=`echo $line,NA`
#			fi
#			
#
#		done
#		echo $line >> $outpath		
		#first=2
		
#		if [ $first = 1 ];then
#			#echo "3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 1p"
#			rois=`3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 1p`
#			header=bblid,scanid,cope,$rois
###########
#			length=`echo $header | wc -c`
#			if [ $length -gt $max ];then
#				max=$length
#				echo bblid
#				echo $header	
#			fi

#############
#			echo $header >> $outpath
#		fi
		#values=`3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 2p`
		#line=$bblid,$scanid,$cope_name,$values
		#echo $line >> $outpath		
		#first=2
#	done

done

ntasks=`wc -l /import/monstrum/Users/hopsonr/idemo_temp.txt`
echo qsub -V -q veryshort.q -S /bin/bash -o ~/sge_out/ -e ~/sge_out/ -t 1-${ntasks} /import/speedy/scripts/hopsonr/other_utilities/get_roi_values_from_3d_label_grid.sh /import/monstrum/Users/hopsonr/idemo_temp.txt

