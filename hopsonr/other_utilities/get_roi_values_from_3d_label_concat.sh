for i in `ls /import/monstrum/eons_xnat/subjects/*/*_bbl1_idemo2_210/stats/*_bbl1_idemo2_210_SEQ*_idemo_behav_incorr_*.feat/stats/sig_maps_sbia/eons_std/get_rois_temp.txt`
do
	bblid=`cat $i | sed -n 2p | cut -d "," -f 1`
	echo $bblid
	grep -q ^$bblid /import/monstrum/eons_xnat/redcap/imaging_variables/n1601_idemo_behav_incorr_sbia_rois_all_copes.csv && echo "already calculated" && continue
	cat $i | sed -n 2,'$'p >> /import/monstrum/eons_xnat/redcap/imaging_variables/n1601_idemo_behav_incorr_sbia_rois_all_copes.csv

done
