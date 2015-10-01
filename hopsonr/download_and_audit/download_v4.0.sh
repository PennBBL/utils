#this version has been recomplicated. The decision was made (Ted and Kosha) to preserve the legacy processing, using old dicoms2nifti where possible (all but T2_space), as well as the old bet and biascorrection. Also added scoring before download.

. /import/monstrum/Users/hopsonr/.bashrc
#. /import/monstrum/Users/hopsonr/test_env

#test_mode="echo"
dir=/import/monstrum/eons3_xnat/scripts/download

if [ "$#" == 0 ];then
	singlesub=0
	#slist=`cat $dir/eons3_xnat_audit_*.csv | grep 009216`
elif [ "$#" == 1 ];then
	singlesub=1
else
	echo "Illegal number of arguments"
	exit
fi

####remove old subject list and get new one, if the subject list was run the day before####
###########################################################################################
check_last_run () {
	day=`date +%m_%d_%y`
	lastrun=`basename /import/monstrum/eons3_xnat/scripts/download/eons3_xnat_audit_*.csv 2> /dev/null | cut -d "." -f 1 | cut -d "_" -f 4,5,6`
	echo $day
	echo $lastrun

	[ "X$lastrun" == "X" ] && lastrun="none"
	if [ $lastrun != $day ];then
		[ -e $dir/eons3_xnat_audit_*.csv ] && mv $dir/eons3_xnat_audit_*.csv $dir/audit_archive/
		$dir/eons3_xnat_audit_01_07_15.py > "$dir/eons3_xnat_audit_"$day".csv"
	fi
}

[ $singlesub == 0 ] && check_last_run
[ $singlesub == 0 ] && slist=`cat $dir/eons3_xnat_audit_*.csv | sed -n 2,'$'p`
[ $singlesub == 1 ] && slist=`cat $dir/eons3_xnat_audit_*.csv | grep $1`

####make a unique tmp dir for scores####
########################################
temp_name=`uuidgen`
mkdir /tmp/$temp_name

####define functions####
########################
check_niftis () {
	echo "running check_niftis."
	#set vars to 0
	t2_nifti=0;mprage_nifti=0;biascorrbet_nifti=0;frac2back_nifti=0;idemo_nifti=0;restbold_nifti=0;dti_nifti=0;pcasl_nifti=0;process=0;process_epi=0;errors=$scanid,$bblid;pcasl_dicom=0
	
	t2=`ls $subdir/*T2_sagittal_SPACE*/nifti/*.nii 2> /dev/null`
	if [ "X$t2" == "X" ] && [ $has_t2 == 1 ];then 
		echo "***missing t2"
		process=1
		errors=$errors,"missing_t2_nifti"
	elif [ "X$t2" != "X" ] && [ $has_t2 == 1 ];then
		t2_nifti=1
	fi
	
	mprage=`ls $subdir/*MPRAGE*moco3/nifti/*.nii.gz 2> /dev/null`
	if [ "X$mprage" == "X" ] && [ $has_mprage == 1 ];then 
		echo "***missing mprage"
		process=1
		errors=$errors,"missing_mprage_nifti"
	elif [ "X$mprage" != "X" ] && [ $has_mprage == 1 ];then
		mprage_nifti=1
	fi
	
	biascorrbettest=`ls $subdir/*MPRAGE*moco3/biascorrection/*brain.nii.gz 2> /dev/null`
	if [ "X$biascorrbettest" == "X" ] && [ $has_mprage == 1 ];then 
		echo "***missing biascor bet"
		process=1
		errors=$errors,"missing_biascorrbet_nifti"
	elif [ "X$biascorrbettest" != "X" ] && [ $has_mprage == 1 ];then
		biascorrbet_nifti=1
	fi
	
	frac2back=`ls $subdir/*frac2back*/nifti/*.nii.gz 2> /dev/null`
	if [ "X$frac2back" == "X" ] && [ $has_frac2back == 1 ];then 
		echo "***missing frac2back"
		process=1
		process_epi=1
		errors=$errors,"missing_frac_nifti"
	elif [ "X$frac2back" != "X" ] && [ $has_frac2back == 1 ];then
		frac2back_nifti=1
	fi
	
	idemo=`ls $subdir/*idemo*/nifti/*.nii.gz 2> /dev/null`
	if [ "X$idemo" == "X" ] && [ $has_idemo == 1 ];then
		echo "***missing idemo"
		process=1
		process_epi=1
		errors=$errors,"missing_idemo_nifti"
	elif [ "X$idemo" != "X" ] && [ $has_idemo == 1 ];then
		idemo_nifti=1
	fi
	
	restbold=`ls $subdir/*restbold*/nifti/*.nii.gz 2> /dev/null`
	if [ "X$restbold" == "X" ] && [ $has_restbold == 1 ];then
		echo "***missing restbold"
		process=1
		process_epi=1
		errors=$errors,"missing_restbold_nifti"
	elif [ "X$restbold" != "X" ] && [ $has_restbold == 1 ];then
		restbold_nifti=1
	fi
	
	dti=`ls $subdir/*DTI*/nifti/*.nii.gz 2> /dev/null`
	if [ "X$dti" == "X" ] && [ $has_dti == 1 ];then
		echo "***missing dti"
		process=1
		errors=$errors,"missing_dti_nifti"
	elif [ "X$dti" != "X" ] && [ $has_dti == 1 ];then
		dti_nifti=1
	fi
	
	pcasl=`ls $subdir/*pcasl*/nifti/*.nii.gz 2> /dev/null`
	if [ "X$pcasl" == "X" ] && [ $has_pcasl == 1 ];then
		echo "***missing pcasl"
		process=1
		errors=$errors,"missing_pcasl_nifti"
	elif [ "X$pcasl" != "X" ] && [ $has_pcasl == 1 ];then
		pcasl_nifti=1
	fi

        pcasl_dcm=`ls $subdir/*pcasl*/dicoms/*.dcm 2> /dev/null`
        if [ "X$pcasl_dcm" == "X" ] && [ $has_pcasl == 1 ];then
                echo "***missing pcasl_dcm"
                process=1
                errors=$errors,"missing_pcasl_dicom"
        elif [ "X$pcasl_dcm" != "X" ] && [ $has_pcasl == 1 ];then
                pcasl_dicom=1
        fi
}

check_scores () {
	echo "Running check_scores."
	#set vars to 0
	missing_frac_score=0;frac_score=0;missing_idemo_score=0;idemo_score=0
	#check for scores
	frac_test=`ls $subdir/scores/frac2B_1.00/*test_output_scores.csv 2> /dev/null`
	if [ "X$frac_test" == "X" ] && [ $has_frac2back == 1 ];then
		missing_frac_score=1
		process=1
		errors=$errors,"missing_frac_scores"
	elif [ "X$frac_score" != "X" ] && [ $has_frac2back == 1 ];then
		frac_score=1
	fi
	idemo_test=`ls $subdir/scores/iDemo2.10/*test_output_scores.csv 2> /dev/null`
	if [ "X$idemo_test" == "X" ] && [ $has_idemo == 1 ];then
		missing_idemo_score=1
		process=1
		errors=$errors,"missing_idemo_scores"
	elif [ "X$idemo_score" != "X" ] && [ $has_idemo == 1 ];then
		idemo_score=1
	fi
}

#####make csv for nifti audit#####
##################################
[ $singlesub == 0 ] && echo bblid,scanid,has_mprage,has_b0,has_pcasl,has_idemo,has_frac2back,has_restbold,has_dti,has_t2,mprage_nifti,biascorrbet_nifti,pcasl_nifti,idemo_nifti,frac2back_nifti,restbold_nifti,dti_nifti,t2_nifti,frac_score,idemo_score,error > $dir/eons3_nifti_audit.csv

####remove old error log####
############################
[ $singlesub == 0 ] && rm -f $dir/eons3_nifti_errors.csv

#####loop over subjects#####
############################
for i in $slist

#get scanid, shortened scanid (- 00), bblid, make id, and has_scantype variables
#had to make two bblids because some start with 0 in the file (and I don't want them too, they are only 5 characters long) while some don't start with 0 and are 6 characters long (and we want to keep the whole thing). 
do
scanid=`echo $i | cut -d "," -f 1`
scanid_short=`echo $scanid | sed 's/^0*//'`
bblid=`echo $i | cut -d "," -f 10 | sed 's/^0*//'`

#subject,mprage,B0,ep2d,idemo,frac2back,restbold,DTI,T2_sagittal,bblid

id=`echo $bblid"_"$scanid_short`
has_mprage=`echo $i | cut -d "," -f 2`
has_B0=`echo $i | cut -d "," -f 3`
has_pcasl=`echo $i | cut -d "," -f 4`
has_idemo=`echo $i | cut -d "," -f 5`
has_frac2back=`echo $i | cut -d "," -f 6`
has_restbold=`echo $i | cut -d "," -f 7`
has_dti=`echo $i | cut -d "," -f 8`
has_t2=`echo $i | cut -d "," -f 9`
downloaddir=/import/monstrum/eons3_xnat/subjects/
#downloaddir=~/eons3_test/
subdir=$downloaddir/$id


#for each subject, check if their scan folders are empty and if they should have data based on the eons3 file, if they should have data, set process=1. If they do have data, just skip to the next scan type (this way we aren't constantly re-downloading data). 
echo "******************"$id"******************************"

check_niftis
check_scores

###run scoring if needed
[ $missing_frac_score == 1 ] && $test_mode /import/monstrum/BBL_scripts/download_sessions_by_date_and_process_scores_v4.py -configfile ~/.xnat.cfg -project EONS3_810336 -matched 1 -session $scanid -process 1 -out /tmp/$temp_name -thetask frac2B_1.00 -thespec frac2B_1.00.xml
[ $missing_idemo_score == 1 ] && $test_mode /import/monstrum/BBL_scripts/download_sessions_by_date_and_process_scores_v4.py -configfile ~/.xnat.cfg -project EONS3_810336 -matched 1 -session $scanid -process 1 -out /tmp/$temp_name -thetask iDemo2.10 -thespec iDemo2.10.xml
###may need to add the next line to deal with possible version 2.11's
#[ $missing_idemo_score == 1 ] && /import/monstrum/BBL_scripts/download_sessions_by_date_and_process_scores_v4.py -configfile ~/.xnat.cfg -project EONS3_810336 -matched 1 -session $scanid -process 1 -out /tmp/$temp_name -thetask iDemo2.11 -thespec iDemo2.10.xml

if [ $process == 1 ];then
	echo "Data missing. Processing."
	#scantype == 'DTI' or scantype == 'DWI'  or scantype == 'MPRAGE' or scantype == 'T2' or scantype == 'EPI' or scantype == 'ASL':
	[ $dti_nifti == 0 ] && [ $has_dti == 1 ] && $test_mode dicoms2nifti.py -scanid $scanid -download 0 -upload 1 -force_unmatched 0 -scantype DTI #convert dicoms to niftis
	[ $mprage_nifti == 0 ] && [ $has_mprage == 1 ] && $test_mode dicoms2nifti.py -scanid $scanid -download 0 -upload 1 -force_unmatched 0 -scantype MPRAGE #convert dicoms to niftis
	[ $process_epi == 1 ] && $test_mode dicoms2nifti.py -scanid $scanid -download 0 -upload 1 -force_unmatched 0 -scantype EPI #convert dicoms to niftis
	([ $pcasl_nifti == 0 ] || [ $pcasl_dicom == 0 ]) && [ $has_pcasl == 1 ] && $test_mode dicoms2nifti.py -scanid $scanid -download 1 -upload 1 -download_dicoms 1 -force_unmatched 0 -scantype ASL -outdir $downloaddir #convert dicoms to niftis
	[ $t2_nifti == 0 ] && [ $has_t2 == 1 ] && $test_mode /import/speedy/scripts/bin/dicoms2nifti_v4.2.py -scanid $scanid -upload 1 -outdir $downloaddir -auto 1 -autotype T2_sagittal 

	[ $biascorrbet_nifti == 0 ] && echo "Processing mprage"
	[ $biascorrbet_nifti == 0 ] && $test_mode /import/monstrum/BBL_scripts/xnat_bet.py -scanid $scanid -download 0 -upload 1 -seqname mprage #bet mprage
	[ $biascorrbet_nifti == 0 ] && $test_mode /import/monstrum/BBL_scripts/xnat_biascorr.py -scanid $scanid -download 0 -upload 1 -seqname mprage #biascorrect mprage

	$test_mode /import/monstrum/BBL_scripts/xnat_downloaders/xnatdownloader_v2.py -scanid $scanid -outdir $downloaddir #to get log files

	###unzip logs###
	################
	[ $missing_frac_score == 1 ] && $test_mode unzip $subdir/scores/frac2B_1.00/STICK.zip -d $subdir/scores/frac2B_1.00
	[ $missing_idemo_score == 1 ] && $test_mode unzip $subdir/scores/iDemo2.10/STICK.zip -d $subdir/scores/iDemo2.10
	

else
	echo "All processing completed, skipping subject"
fi

####check that niftis and scores are actually present
check_niftis
check_scores
[ $singlesub == 0 ] && echo $bblid,$scanid_short,$has_mprage,$has_B0,$has_pcasl,$has_idemo,$has_frac2back,$has_restbold,$has_dti,$has_t2,$mprage_nifti,$biascorrbet_nifti,$pcasl_nifti,$idemo_nifti,$frac2back_nifti,$restbold_nifti,$dti_nifti,$t2_nifti,$frac_score,$idemo_score,$process >> $dir/eons3_nifti_audit.csv
[ $singlesub == 0 ] && [ "$errors" != "$scanid,$bblid" ] && echo $errors >> $dir/eons3_nifti_errors.csv

done # for i in $slist


[ $singlesub == 0 ] && $test_mode /import/monstrum/Applications/R3.0.2/bin/R --file=/import/monstrum/Users/hopsonr/upload_to_redcap.R --slave --args "PNC-LG_Timepoint3_Imaging" "/import/monstrum/eons3_xnat/scripts/download/eons3_nifti_audit.csv"

echo ""
echo "Complete. Removing temp dir."
rm -rf /tmp/$temp_name

error_log_test=`ls $dir/eons3_nifti_errors.csv 2> /dev/null`
if [ "X$error_log_test" != "X" ] && [ $singlesub == 0 ];then
echo ""
echo "Emailing error log"
mail -s "GO3 download error log for $day" hopsonr@bbl.med.upenn.edu < $dir/eons3_nifti_errors.csv
fi







