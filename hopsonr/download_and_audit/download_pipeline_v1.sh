#testing_mode=echo

#useage
function Usage {
	cat <<USAGE
Usage:
  -a:  full path to Audit file, generated by an xnat_audit.py. Required.
  -p:  Protocol name as on monstrum. Required.
  -x:  Protocol name as in xnat. Required.
  -e:  Email address for error reporting.
  -d:  scans that need all Dicoms, if any. As in xnat_audit.
  -r:  Redcap protocol name for automatic uploading.
  -s:  Scanid
  -t:  Testing mode.

USAGE
	exit 1
}

###set defaults
overwrite=0
singlesubject=0
all_dicoms=""
redcap_name=""
email=""
day=`date +%m_%d_%y`

###check for args
[ $# -lt 1 ] && Usage

# reading command line arguments
while getopts ":a:p:s:he:tx:d:r:" OPT
	do
	case $OPT in
		h) #help
		Usage >&2
		exit 0
		;;
		a) #audit file
		audit_file=$OPTARG
		;;
		p) #protocol name as on monstrum
		protocol=$OPTARG
		;;
		x) #path to output
		xnat_name=$OPTARG
		;;
		e) #email address for error reporting
		email=$OPTARG
		;;
		r) #name of redcap project for automated uploading
		redcap_name=$OPTARG
		;;
		d) #name of any scans that require all dicoms
		all_dicoms="$all_dicoms,$OPTARG,"
		;;
		t) #testing mode
		testing=1
		;;
		s) #scanid
		singlesubject=1
		scanid=$OPTARG
		;;
		\?) # getopts issues an error message
		Usage >&2
		exit 1
		;;
	esac
done

#set variables automatically for testing purposes
if [ ! -z $testing ];then
	#audit_file=/import/monstrum/eons2_xnat/scripts/xnat_stats/n404_xnat_audit.csv
	audit_file=/import/monstrum/eons_xnat/redcap/imaging_variables/n1601_eons_xnat_audit_7_1_14.csv
	#protocol=eons2_xnat
	protocol=eons_xnat
	#out_path=/import/monstrum/eons2_xnat/scripts/ASL/QA/automated_qa.csv
	email=hopsonr@bbl.med.upenn.edu
	overwrite=0
fi

###set up error path
mkdir -p /import/monstrum/$protocol/logs
error_path=/import/monstrum/$protocol/logs/download_error_log.txt
[ -e $error_path ] && rm -f $error_path

echo "Audit file is: "$audit_file
echo "Protocol is: "$protocol

###check arguments
errors=""
[ ! -e "$audit_file" ] && errors=`echo $errors "Missing audit file."`
[ ! -d "/import/monstrum/$protocol" ] && errors=`echo $errors "Missing study directory."`

###check dependencies
[ ! -e "/import/speedy/scripts/bin/dicoms2nifti_v4.3.py" ] && errors=`echo $errors "Missing dicoms2nifti script."`

###if any errors, exit
if [ ! -z "$errors" ];then 
	echo $errors 
	[ "$error_path" != "/error_log.txt" ] && echo $errors > $error_path 
	Usage
fi

###get names of scans from audit header, assign field numbers from header
header=`cat $audit_file | sed -n 1p | tr "," " "`
scans=""
field_num=1
for field in $header
do
	[ "$field" != "subject" ] && [ "$field" != "bblid" ] && [ "$field" != "doscan" ] && scans=`echo $scans $field`
	declare $field=$field_num
	echo $field,$field_num
	((field_num++))
done
scans=`echo $scans | sed s/'^ '//`

####define functions####
########################
check_existing () {
	echo "running check_existing."
	process=0
	for check_scan in $scans
	do
		scan_process=$check_scan'_process'
		scan_nifti=$check_scan'_nifti'
		scan_dicom=$check_scan'_dicom'
		command=`echo $scan_process=0`;eval $command
		command=`echo $scan_nifti=0`;eval $command
		command=`echo $scan_dicom=0`;eval $command
		#niftis
		has_nifti=has_"$check_scan"
		test=`ls $subdir/*$check_scan*/nifti/*.nii* 2> /dev/null`
		if [ "X$test" == "X" ] 	&& [ ${!has_nifti} == 1 ];then
			echo "***missing $check_scan"
			process=1
			command=`echo $scan_process=1`;eval $command
			command=`echo $scan_nifti=0`;eval $command
			subject_errors=$subject_errors,"missing_"$check_scan
		elif [ "X$test" != "X" ] && [ ${!has_nifti} == 1 ];then
			command=`echo $scan_process=0`;eval $command
			command=`echo $scan_nifti=1`;eval $command
		fi
	
		#dicoms
    	dcm_test=`ls $subdir/*$check_scan*/[Dd]icoms/*.[Dd][Cc][Mm] 2> /dev/null`
		if [ "X$dcm_test" == "X" ] && [ ${!has_nifti} == 1 ];then
			echo "***missing $check_scan dicom"
			process=1
			command=`echo $scan_process=1`;eval $command
			command=`echo $scan_dicom=0`;eval $command
			subject_errors=$subject_errors,"missing_"$check_scan"_dicom"
		elif [ "X$dcm_test" != "X" ] && [ ${!has_nifti} == 1 ];then
			command=`echo $scan_process=0`;eval $command
			command=`echo $scan_dicom=1`;eval $command
		fi
	done
}

#####make csv for nifti audit#####
##################################
audit_header=bblid,scanid
for scan in $scans
do
	audit_header=$audit_header,$scan"_nifti",$scan'_dicom'
done
audit_header=$audit_header,error

[ $singlesubject == 0 ] && echo $audit_header > /import/monstrum/$protocol/logs/nifti_audit.csv

####remove old error log####
############################
[ $singlesubject == 0 ] && rm -f /import/monstrum/$protocol/logs/nifti_subject_errors.csv

####get subject list####
########################
[ $singlesubject == 0 ] && slist=`cat $audit_file | sed -n 2,'$'p`
[ $singlesubject == 1 ] && slist=`cat $audit_file | grep $scanid`

#####loop over subjects#####
############################
for i in $slist
do
echo $i
#get scanid, shortened scanid (- 00), bblid, make id, and has_scantype variables
scanid=`echo $i | cut -d "," -f $subject`
echo $scanid
scanid_short=`echo $scanid | sed 's/^0*//'`
subjectbblid=`echo $i | cut -d "," -f $bblid | sed 's/^0*//'`

#get values for has_scan
	for scan in $scans
	do
		value=`echo $i | cut -d "," -f ${!scan}`
		declare has_"$scan"=$value	
	done
#subject,mprage,B0,ep2d,idemo,frac2back,restbold,DTI,T2_sagittal,bblid

id=`echo $subjectbblid"_"$scanid_short`
downloaddir=/import/monstrum/$protocol/subjects/
subdir=$downloaddir/$id

#for each subject, check if their scan folders are empty and if they should have data based on the eons3 file, if they should have data, set process=1. If they do have data, just skip to the next scan type (this way we aren't constantly re-downloading data). 
echo "******************"$id"******************************"

####check to see if scans exist####
###################################
check_existing

#####download niftis#####
#########################
if [ $process == 1 ];then
	for scan in $scans
	do
		has_scan_test=has_"$scan"
		process_scan_test=$scan'_process'
		echo scan,has_scan,process_scan
		echo $scan,${!has_scan_test},${!process_scan_test}
		if [ ${!has_scan_test} == 1 ] && [ ${!process_scan_test} == 1 ];then
			[[ $all_dicoms == *",$scan,"* ]] && example_only=0 || example_only=1
			$testing_mode dicoms2nifti_v4.3.py -scanid $scanid -outdir /import/monstrum/$protocol/subjects -auto 1 -upload 0 -autotype $scan -exampledicomonly $example_only
		fi
	done

fi

####now that niftis and dicoms should be downloaded, check to make sure they exist####
######################################################################################
#set up errors variable
subject_errors=$subjectbblid,$scanid
check_existing


###everything from here on needs edited

	if [ $singlesubject == 0 ];then
		line=$subjectbblid,$scanid_short
		for scan in $scans
		do
			scan_nifti=$scan'_nifti'
			scan_dicom=$scan'_dicom'
			echo $scan_nifti,$scan_dicom
			echo ${!scan_nifti},${!scan_dicom}
			line=$line,${!scan_nifti},${!scan_dicom}
		done 
		line=$line,$process
		echo $line >> /import/monstrum/$protocol/logs/nifti_audit.csv
		[ "$subject_errors" != "$scanid,$bblid" ] && echo $subject_errors >> /import/monstrum/$protocol/logs/nifti_subject_errors.csv
	fi
done

[ $singlesubject == 0 ] && [ ! -z $redcap_name ] && $testing_mode /import/monstrum/Applications/R3.0.2/bin/R --file=/import/monstrum/Users/hopsonr/upload_to_redcap.R --slave --args "$redcap_name" "/import/monstrum/$protocol/logs/nifti_audit.csv"
error_log_test=`ls /import/monstrum/$protocol/logs/nifti_subject_errors.csv 2> /dev/null`
if [ "X$error_log_test" != "X" ] && [ $singlesubject == 0 ] && [ ! -z $email ];then
	echo ""
	echo "Emailing error log"
	$testing_mode mail -s "$protocol download error log for $day" $email < /import/monstrum/$protocol/logs/nifti_subject_errors.csv
fi





