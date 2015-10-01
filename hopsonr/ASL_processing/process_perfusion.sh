#!/bin/bash

# Define what happens when user executes Ctrl-C while script is running
# Prints a message and exits with code '3'
trap "printf '\e[31m[interrupted by user]\n'; exit 3" SIGINT SIGTERM

###get list of initial variables set###
#######################################

#initial_vars="`set -o posix ; set`"

###set default values###
########################

dico=1
smoothing=6
remove_volumes=1
registration="flirt"
T1_correction=0
hematocrit=0
c=""
bbl=1
study=""
logdir=""
subject_list=""
pcasl_folder="*se_pcasl*_1200ms"
t1_folder="*MPRAGE*_moco3"
b0_folder="B0_map_new"
b0_filename="rpsmap_t1bet.nii.gz"
b0_maskname="t1bet2b0_mask.nii.gz"
quant_outname="cbf_map"
feat_outdir_name="prestats"
quant_outdir_name="quantification"
coreg_outdir_name="registration/bbr"
scanid_arg=""
t1corr="adult"
usesge=1
queue=all.q
min_images=72
dicom_dir=dicoms
nifti_name="*pcasl*"

###Functions###
###############
# First, define script functions
# [[::Functions start::]]

# Usage: Runs when script is called with no arguments or with '-h' 
# and prints to screen everything between 1st and 2nd "redvelvet"
usage(){
cat << redvelvet
   
 || Description ||  
	This script is intended to distortion correct, preprocess,
	quantify, and register perfusion scans

 || Requirements ||
	- FSL
	- dico_correct
	- dicom_dump
	- pcasl_quant
	- epi_reg_tds

 || Usage ||
	process_asl.sh --option1=X --option2=Y
	Example: ./process_perfusion.sh --study=ONM --pcasl_folder="*pcasl_se_we*" --registration=dramms --remove_volumes=0 --scanid=8522

   Options:
	--h      		help; print this message
	--dico	 		use distortion correction, default = 1
	--smoothing		kernal size, default = 6
	--remove_volumes	for filtering fatsat artifact, default = 1
	--registration		"ants", "dramms", or "flirt". Default = "ants"
	--T1_correction		"age","hematocrit","adult". Default = "adult"
	--hematocrit		if using hematocrit T1 correction, file containing measurements
	--hct_colname		if using hematocrit T1 correction, name of column containing measurements
 	--c      		Use following config file 
	--logdir		path to directory for logs	
   BBL mode and options:
	--bbl			assume bbl standard file structure, default = 1
	--study			if using bbl mode, name of study directory (/import/monstrum/$study)
	--pcasl_folder		common string that distinguishes sequence directory, default = "*se_pcasl*_1200ms" Must be in quotes.
	--t1_folder		common string that distinguishes t1 directory, default = "*MPRAGE*_moco3" Must be in quotes.
	--b0_folder		common string that distinguishes b0 directory, default = B0_map_new
	--b0_filename		common string that distinguishes b0 rpsmap, default = rpsmap_t1bet.nii.gz
	--b0_maskname		common string that distinguishes b0 mask, default = t1bet2b0_mask.nii.gz
	--feat_outdir_name	name of folder created inside asl directory to contain prestats results, default = prestats
	--quant_outdir_name	name of folder created inside asl directory to contain quantification results, default = quantification
	--coreg_outdir_name	name of folder created inside asl directory to contain coregistration results, default = registration/bbr
	--scanid		scanid of participant to run. Leave blank to run all participants
	--usesge		submit jobs to grid, default = 1
	--min_images		minimum number of images in nifti needed for participant to be included. Default = 72
	--dicom_dir		name of directory containing pcasl dicoms. Default = dicoms
	--nifti_name		name of raw nifti file. Default = "*pcasl*"
   Non BBL mode, must specify files:
	--asl			raw asl data
	--t1head		structural scan
	--t1brain		brain extracted structural scan
	--single_dicom		example dicom for setting parameters
	--feat_template		template.fsf to use for prestats
	--unique_id		subject id	
   Ants requirements (if not in BBL mode):
	--wm			white matter segmented map
	--ants_dir		ants directory

   Options can either be specified with the above flags or in a S-template.config file
   using the '-c' option,
   otherwise defaults are used. (Specifying a config file overrides any other arguments passed)

   Example config file S-template.config supplied
 
redvelvet
}

###From Ted's restingbold script, for parsing args###
#####################################################

get_opt1() {
    arg=`echo $1 | sed 's/=.*//'`
    echo $arg
}

get_imarg1() {
    arg=`get_arg1 $1`;
    arg=`$FSLDIR/bin/remove_ext $arg`;
    echo $arg
}

get_arg1() {
    if [ X`echo $1 | grep '='` = X ] ; then ### if echo $1 | grep -q "=";then - rdh
	echo "Option $1 requires an argument" 1>&2
	exit 1
    else
	arg=`echo $1 | sed 's/.*=//'`
	if [ X$arg = X ] ; then
	    echo "Option $1 requires an argument" 1>&2
	    exit 1
	fi
	echo $arg
    fi
}

# Dependencies check: Make sure the required executables are in your path
# This is not strictly required here, since it will be run by s-meta on each processing node
# However, if the submitting node is part of the grid as is often the case, and each node
# is set up identically, as should be the case, it's best to include it right here.
depcheck(){
printf "\n   [Dependencies check..."
depcheckfail=0
for i in fslmaths flirt; do
 [ -z `command -v $i` ] && printf "\n$i not found in path. \n" && depcheckfail=1
done
[ $depcheckfail == 1 ] && printf "\n   Dependencies check failed; aborting\n" && exit 1
printf "\e[32m ok\e[m]\n"
}

# Environment check: Make sure the required environment variables are set
envcheck(){
        #printf "ANTs version: `head -1 /import/monstrum/Applications/ants/ANTS/trunk/README.txt`\n" >> $logfile
        [ -z $ANTSPATH ] && echo "   [ANTSPATH not set, setting now." && ANTSPATH=/import/monstrum/Applications/ANT/bin/
        printf "ANTSPATH is $ANTSPATH\n" >> $1
        [ -z $FSLDIR ] && echo "   [FSLDIR not set, setting now.]" && FSLDIR=/import/monstrum/Applications/fsl
        printf "FSLDIR is $FSLDIR\n" >> $1
        [ -z $DRAMMSDIR ] && echo "   [DRAMMSDIR not set, setting now.]" && DRAMMSDIR=/import/monstrum/Applications/dramms-1.4.0/bin/
        printf "DRAMMSDIR is $DRAMMSDIR\n" >> $1
}

#---[ Get opts ]
# getopts syntax:
# Start with a colon (":"), then
# if an option requires further arguments, it needs a colon (":") after its letter is defined in getopts
# e.g. "t:"
# In the example below, all options require input, e.g. -t /path/to/template.nii.gz,
# except for -h (help)

###parse arguments###
#####################

while [ $# -ge 1 ] ; do
    iarg=`get_opt1 $1`;
    case "$iarg" in
                --h ) usage && exit 8 ;;
		--dico)
			dico=`get_arg1 $1`
			shift;;
		--smoothing)
			smoothing=`get_arg1 $1`
			shift;;
		--remove_volumes)
			remove_volumes=`get_arg1 $1`
			shift;;
		--registration)
			registration=`get_arg1 $1`
			shift;;
		--T1_correction)
			t1corr=`get_arg1 $1`
			shift;;
		--hematocrit)
			hematocrit=`get_arg1 $1`
			shift;;
		--hct_colname)
			hct_colname=`get_arg1 $1`
			shift;;
		--c)
			c=`get_arg1 $1`
			shift;;
		--bbl)
			bbl=`get_arg1 $1`
			shift;;
		--study)
			study=`get_arg1 $1`
			shift;;
		--logdir)
			logdir=`get_arg1 $1`
			shift;;
		--subject_list)
			slist=`get_arg1 $1`
			shift;;
		--pcasl_folder)
			pcasl_folder=`get_arg1 $1`
			shift;;
		--t1_folder)
			t1_folder=`get_arg1 $1`
			shift;;
		--b0_folder)
			b0_folder=`get_arg1 $1`
			shift;;
		--b0_filename)
			b0_b0_filename=`get_arg1 $1`
			shift;;
		--b0_maskname)
			b0_b0_maskname=`get_arg1 $1`
			shift;;
		--scanid)
			scanid_arg=`get_arg1 $1`
			shift;;
		--usesge)
			usesge=`get_arg1 $1`
			shift;;
		--min_images)
			min_images=`get_arg1 $1`
			shift;;
		--quant_outdir_name)
			quant_outdir_name=`get_arg1 $1`
			shift;;
		--coreg_outdir_name)
			coreg_outdir_name=`get_arg1 $1`
			shift;;
		--dicom_dir)
			dicom_dir=`get_arg1 $1`
			shift;;
		--nifti_name)
			nifti_name=`get_arg1 $1`
			shift;;
		*) usage && exit 9;;
    esac
done

#shift $(($OPTIND - 1)) # not needed with new parsing?

###BBL Mode###
##############
#clean up old file list

	if [ $bbl == 1 ];then
	###set group level variables
	###test if a study was provided and if it exists
	[ "X$study" == "X" ] && echo "To use bbl mode, please supply a study." && usage && exit 9
	studydir=`ls -d /import/monstrum/$study 2> /dev/null`
	[ "X$studydir" == "X" ] && echo "Study directory does not exist." && usage && exit 9

	if [ $t1corr == "age" ];then
	t1corr=-1
	elif [ $t1corr == "hematocrit" ];then
	echo "not yet implemented"
	exit
	elif [ $t1corr == "adult" ];then
	t1corr=0
	else
	echo "T1 options are age, hematocrit, or adult." 
	usage
	exit 9
	fi # if [ $t1corr == "age" ];then
	
	###set default logdir if none provided
	if [ "X$logdir" == "X" ];then
	logdir=$studydir/scripts/ASL/logdir
	fi # if [ "X$logdir" == "X" ];then
	mkdir -p $logdir/sge_out
	logfile=$logdir/`basename $0`_`date +%Y%m%d_%H%M%S`_running.log
	
	###get subject list if none provided
	if [ "X$subject_list" == "X" ];then
	subject_list=`ls -d $studydir/subjects/*$scanid_arg`
	fi # if [ "X$subject_list" == "X" ];then
	[ "X$subject_list" == "X" ] && echo "No subject directories provided or found." && usage && exit 9

	###get scriptdir
	scriptdir=`cd "$(dirname "$0")" ; pwd -P`
	
	#---[ Check dependencies and environment]
	depcheck
	envcheck $logfile
	# remove old temp file
	[ -e $logdir/temp.txt ] && rm -f $logdir/temp.txt
	# set run flag to 0, will be set to 1 if anyone actually needs run
###set subject level variables
	for subject_folder in $subject_list
	do
	echo "**********************************"
	echo "Checking participant "$subject_folder
	error=0
	missing_B0=0
	error_msg=""
	dir=`ls -d $subject_folder/$pcasl_folder 2> /dev/null`

	if [ "X$dir" == "X" ];then
	echo "No ASL directory present"
	continue
	fi

	final_image=`ls $dir/$quant_outdir_name/cbf_map_std* 2> /dev/null | wc -l`
	mkdir -p $dir/$quant_outdir_name
	subject_config=$dir/$quant_outdir_name/config.txt
	subject_log=$dir/$quant_outdir_name/quant_log_`date +%Y%m%d_%H%M%S`.log
	scanid=`echo $subject_folder | cut -d "/" -f 6 | cut -d "_" -f 2`
	unique_id=$scanid
	bblid=`echo $subject_folder | cut -d "/" -f 6 | cut -d "_" -f 1`

	if [ $final_image -gt 0 ];then #only look for files if there isn't already a final image
	echo "Already quantified"
	continue
	fi

###names of files and directories to be created
feat_outpath=$dir/$feat_outdir_name
quant_outpath=$dir/$quant_outdir_name
coreg_outpath=$dir/$coreg_outdir_name

###names and counts of files that already should exist
	dir_count=`ls -d $dir 2> /dev/null | wc -l`
	single_count=`ls $dir/$dicom_dir/*.dcm 2> /dev/null | wc -l`
	single_dicom=`ls $dir/$dicom_dir/*.dcm 2> /dev/null | head -1`
	nifti=`ls $dir/nifti/$nifti_name 2> /dev/null`
	nifti_count=`ls $dir/nifti/$nifti_name 2> /dev/null | wc -l`
	rps=`ls $subject_folder/$b0_folder/$b0_filename 2> /dev/null`
	rps_count=`ls $subject_folder/$b0_folder/$b0_filename 2> /dev/null | wc -l`
	b0_mask=`ls $subject_folder/$b0_folder/$b0_maskname 2> /dev/null`
	b0_mask_count=`ls $subject_folder/$b0_folder/$b0_maskname 2> /dev/null | wc -l`
	feat_template=`ls /import/speedy/scripts/hopsonr/ASL_processing/template_bet.fsf 2> /dev/null`
	feat_template_count=`ls /import/speedy/scripts/hopsonr/ASL_processing/template_bet.fsf 2> /dev/null | wc -l`
	t1dir=`ls -d $subject_folder/$t1_folder/biascorrection 2> /dev/null`
	t1dir_count=`ls -d $t1dir 2> /dev/null | wc -l`
	t1head_count=`ls -d $t1dir/*corrected.nii.gz 2> /dev/null | wc -l`
	t1brain=`ls -d $t1dir/*correctedbrain.nii.gz 2> /dev/null`
	t1head=`ls -d $t1dir/*corrected.nii.gz 2> /dev/null`
	t1brain_count=`ls -d $t1dir/*correctedbrain.nii.gz 2> /dev/null | wc -l`

###set variables for registration###
####################################
	
###ants###
	if [ "$registration" == "ants" ];then
	wm=$(ls -d $t1dir/wm_seg_thr99.nii.gz 2> /dev/null | wc -l) 
	fmap=$(ls -d $subject_folder/$b0_folder/*_mag1.nii 2> /dev/null | wc -l)
	fmap_bet=$(ls -d $subject_folder/$b0_folder/*mag1_*.nii* 2> /dev/null | wc -l)
	template=`ls /import/monstrum/eons_xnat/templates/mni_152_skull.nii.gz 2> /dev/null | wc -l`
	normpath=$(ls -d $subject_folder/$t1_folder/s-normsegmod/ 2> /dev/null)
	normpath_count=$(ls -d $subject_folder/$t1_folder/s-normsegmod/ 2> /dev/null | wc -l)
	rigid=$(ls -d $normpath/mni152_f_*_mprage_r_m_0DerivedInitialMovingTranslation.mat 2> /dev/null | wc -l)
	affine=$(ls -d $normpath/mni152_f_*_mprage_r_m_1Affine.mat 2> /dev/null | wc -l)
	warp=$( ls -d $normpath/mni152_f_*_mprage_r_m_2Warp.nii.gz 2> /dev/null | wc -l)
###dramms###
	elif [ "$registration" == "dramms" ];then
	dramms_warp=`ls $t1dir/../dramms/*micobc_to_mni2mm_warp.nii.gz 2> /dev/null`
	dramms_warp_count=`ls $t1dir/../dramms/*micobc_to_mni2mm_warp.nii.gz 2> /dev/null | wc -l`
	#other files are created during prestats, and will need to be found after
	fi # if [ "$registration" == "ants" ];then

###check that subject level variables exist###
##############################################
	if [ $dir_count != 1 ];then
	echo "ERROR: script requires exactly one pcasl directory"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one pcasl directory"`
	ls -d $dir
	fi

	if [ $single_count -lt 1 ];then
	echo "ERROR: script requires at least one example dicom"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one example dicom"`
	ls $dir/$dicom_dir/*.dcm
	fi

	if [ $nifti_count != 1 ];then
	echo "ERROR: script requires exactly one pcasl nifti"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one pcasl nifti"`
	ls $dir/nifti/$nifti_name
	elif [ $nifti_count == 1 ];then
	dim4=`fslinfo $nifti | grep ^dim4 | cut -d " " -f 12`
		if [ $dim4 -lt $min_images ];then
		echo "ERROR: incomplete time series. "$dim4" timepoints found"
		error=1
		error_msg=`echo $error_msg "ERROR: incomplete time series. "$dim4" timepoints found"`
		fi
	fi

	if [ $rps_count != 1 ];then
	echo "ERROR: script requires exactly one rps map"
	missing_B0=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one rps map"`
	ls $subject_folder/$b0_folder/$b0_filename
	fi

	if [ $b0_mask_count != 1 ];then
	echo "ERROR: script requires exactly one B0 mask"
	missing_B0=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one B0 mask"`
	ls $subject_folder/$b0_folder/$b0_maskname
	fi

	if [ $feat_template_count != 1 ];then
	echo "ERROR: script requires exactly one feat template"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one feat template"`
	ls template_bet.fsf
	fi

	if [ $t1dir_count != 1 ];then
	echo "ERROR: script requires exactly one mprage directory"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one mprage directory"`
	ls -d $t1dir
	fi

	if [ $t1head_count != 1 ];then
	echo "ERROR: script requires exactly one corrected T1"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one corrected T1"`
	ls -d $t1dir/*corrected.nii.gz
	fi

	if [ $t1brain_count != 1 ];then
	echo "ERROR: script requires exactly one brain extracted corrected T1"
	error=1
	error_msg=`echo $error_msg "ERROR: script requires exactly one brain extracted corrected T1"`
	ls -d $t1dir/*correctedbrain.nii.gz
	fi

###check variables for registration###
######################################
###ants###
	if [ "$registration" == "ants" ];then
		if [ $wm != 1 ];then
		echo "ERROR: script requires exactly one white matter map"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one white matter map"`
		ls -d $t1dir/wm_seg_thr99.nii.gz
		fi

		if [ $fmap != 1 ];then
		echo "ERROR: script requires exactly one B0 magnitude map"
		missing_B0=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one B0 magnitude map"`
		ls -d $subject_folder/$b0_folder/*_mag1.nii
		fi
		if [ $fmap_bet != 1 ];then
		echo "ERROR: script requires exactly one brain extracted B0 magnitude map"
		missing_B0=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one brain extracted B0 magnitude map"`
		ls -d $subject_folder/$b0_folder/*mag1_*.nii*
		fi
		if [ $template != 1 ];then
		echo "ERROR: script requires exactly one MNI template"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one MNI template"`
		#keep this as eons_xnat for now, no eons2_xnat/templates dir exists
		ls /import/monstrum/eons_xnat/templates/mni_152_skull.nii.gz
		fi
		if [ $normpath_count != 1 ];then
		echo "ERROR: script requires exactly one ANTS directory"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one ANTS directory"`
		ls -d $t1dir/s-normsegmod/
		fi
		if [ $rigid != 1 ];then
		echo "ERROR: script requires exactly one rigid transform"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one rigid transform"`
		ls -d $normpath/mni152_f_*_mprage_r_m_0DerivedInitialMovingTranslation.mat
		fi
		if [ $affine != 1 ];then
		echo "ERROR: script requires exactly one affine transform"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one affine transform"`
		ls -d $normpath/mni152_f_*_mprage_r_m_1Affine.mat
		fi
		if [ $warp != 1 ];then
		echo "ERROR: script requires exactly one warp"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one warp"`
		ls -d $normpath/mni152_f_*_mprage_r_m_2Warp.nii.gz
		fi
###dramms###
	elif [ "$registration" == "dramms" ];then
		if [ $dramms_warp_count != 1 ];then
		echo "ERROR: script requires exactly one warp"
		error=1
		error_msg=`echo $error_msg "ERROR: script requires exactly one warp"`
		ls -d $dramms_warp
		fi
	fi # if [ "$registration" == "ants" ];then	
	
###write out errors, add to list if all files found###
	if [ $error == 1 ];then
	echo "Participant "$subject_folder" will not be run."
	echo $subject_folder,$error_msg >> $logfile
	continue
	elif [ $missing_B0 == 1 ] && [ $error == 0 ];then
	echo "Participant "$subject_folder" will be run without distortion correction."
	echo $subject_folder,$error_msg >> $logdir/perfusion_quant_no_B0_log.txt
	else
	echo "All files found."
	echo $subject_folder >> $logdir/perfusion_quant_all_files_found_log.txt
	fi
	
	###write out config file###
	echo "Writing config file for $unique_id to $subject_config"
	echo "### Config file for `basename $0` run by $USER@$HOSTNAME running on $MACHTYPE" > $subject_config
	echo "### Participant: $subject_folder" >> $subject_config 
	echo "### Date run: `date +%Y%m%d_%H%M%S`" >> $subject_config
	echo "" >> $subject_config
	echo $subject_config >> $logdir/temp.txt

	args=(ANTSPATH DRAMMSDIR FSLDIR T1_correction b0_filename b0_folder b0_mask b0_mask_count b0_maskname bbl bblid c coreg_outdir_name coreg_outpath depcheckfail dico dim4 dir dir_count dramms_warp dramms_warp_count error error_msg feat_outdir_name feat_outpath feat_template feat_template_count final_image hematocrit logdir logfile missing_B0 nifti nifti_count quant_outdir_name quant_outname quant_outpath registration remove_volumes rps rps_count scriptdir single_count single_dicom smoothing study studydir subject_config subject_folder t1brain t1brain_count t1dir t1dir_count t1head t1head_count t1corr unique_id scanid subject_log)
	for i in ${args[@]};do echo $i"="${!i};done >> $subject_config

	done # for subject_dir in $subject_list

ntasks=`cat $logdir/temp.txt|wc -l 2> /dev/null`
if [ $ntasks -gt 0 ];then
	printf "\n\n************All subjects checked. Submitting $ntasks to grid.\n   "
	if [ ! -z $SGE_ROOT ] && [ $usesge == 1 ]; then
		# Array job (qsub -t) replaces one loop
	        qsub -V -q "$queue" -S /bin/bash -o $logdir/sge_out/ -e $logdir/sge_out/ -t 1-${ntasks} $scriptdir/process_ASL_final_skull_stripped_B0_v2.sh $logdir/temp.txt
	#else
	#	for i in $subjects; do
	#               ${EDGPATH}bash/s-meta $i $template $logfile 0 
	#       done
	fi
else
	echo "No subjects found. No jobs to run."
fi	

fi # if [ $bbl == 1 ];then



###for now, only working on bbl mode
exit 0



#---[ Intro ] # want study specific logfiles
#sd=`pwd` #starting directory
#mkdir -p $sd/s-logs/sge_out
#logfile=$sd/s-logs/`basename $0`_`date +%Y%m%d_%H%M%S`_running.log
printf "\n\e[1;36m   `basename $0` at $HOSTNAME running on $MACHTYPE\e[m\n"
printf "   `date +%a\ %b\ %d\ %T\ %Z\ %Y`\n\e[37m   Hello, \e[1;37m$USER\e[0;37m.\e[m\n"
printf "   Your master logfile is $logfile\n"
printf "Log file for `basename $0` started by $USER@$HOSTNAME running on $MACHTYPE\n" >> $logfile
printf "::: `date`: `basename $0` started :::\n" >> $logfile


input=$1

# Check if input is file - this can be either A) a subject.list or B) a single or multiple .nii.gz files
[ ! -f $input ] && usage && exit 1
# 
if [ `file $input|awk '{print $2}'` == 'ASCII' ]; then
	subjects=`cat $input`
	ntasks=`cat $input|wc -l`
	#wd=$(cd `dirname $input`&&pwd)/
else
	# Assume they are niftis
	subjects=$*
	ntasks=$#
	#wd=''
fi

# Better way to count ntasks
nsubjects=`echo $subjects|wc -w|sed -e 's/ //g'`
printf "   Number of subjects: $nsubjects\n"
printf "\nSubjects:\n$subjects\n\n" >> $logfile

#---Template. Defaults to MNI 152 in FSL dims and box
if [ -z $template ]; then
	if [ -f ${EDGPATH}data/mni152.nii.gz ]; then
		template=${EDGPATH}data/mni152.nii.gz
	else
		printf "\e[31m   no template provided and default not found; aborting.\e[m\n" && exit 1
	fi
fi
printf "Template: $template\n" >> $logfile

#---Use SGE
# yes by default, will run if SGE_ROOT is set
[ -z $usesge ] && usesge=1 && printf "SGE cluster: $SGE_CLUSTER_NAME\n" >> $logfile

#---SGE Queue
[ -z $queue ] && queue=all.q

[ ! -z $SGE_ROOT ] && printf "SGE queue: $queue\n" >> $logfile

#---SGE priority
[ -z $priority ] && priority=0 && printf "Priority: $priority\n" >> $logfile

#---Output directory
# no need to set default, will be set by s-fmeta or each subject

###functionality to be added
#---Config file
# If a config file is provided, read its settings
#if [ ! -z $configfile ]; then
#	printf "Using config from $configfile: \n\n`cat $configfile`\n\n" >> $logfile
#	# Look for each variable
#	templateconfig=`cat $configfile|grep PATH_TO_TEMPLATE|sed -e 's/.*=//'`
#	[ ! -z $templateconfig ] && template=$templateconfig && 
#	sgequeueconfig=`cat $configfile|grep SGE_QUEUE|sed -e 's/.*=//'`
#	[ ! -z $sgequeueconfig ] && queue=$sgequeueconfig
#fi	

#---Print options
printf "   Input is $input\n\n   Template set to $template\n\n   SGE queue set to $queue\n\n   SGE priority set to $priority\n\n   ITK number of cores set to $itkcores\n\n   Output directory set to $outdir\n\n"

# [[::Loop::]

####loop through subject list, submit only completed subjects

wd=$(cd `dirname $input`&&pwd)
#ntasks=`cat $input|wc -l`
printf "   I will submit $ntasks tasks\n   "
exit 0
if [ ! -z $SGE_ROOT ] && [ $usesge == 1 ]; then
	# Array job (qsub -t) replaces one loop
        qsub -V -q $queue -S /bin/bash -o $sd/s-logs/sge_out -e $sd/s-logs/sge_out -p $priority -t 1-${ntasks} ${EDGPATH}bash/s-meta ${wd}/`basename $input` $template $logfile 1 $outdir
else
	for i in $subjects; do
                ${EDGPATH}bash/s-meta $i $template $logfile 0 
        done
fi
	
[ ! $? -eq 0 ] && echo -e "\e[31m error, aborting\e[m\n" && exit 1
if [ -z $SGE_ROOT ]; then
	printf "\ncompleted: `date  +%a\ %b\ %d\ %T\ %Z\ %Y`\n" >> $logfile
else
	printf "\n`date`: 1 job with $ntasks tasks submitted to $queue\n\n" >> $logfile
fi
printf "\n   2014 egenn@upenn.edu\n\n\n\e[37;2m   ΣΣΝΝ\n\n\n\e[m"
cd $sd

exit 0

