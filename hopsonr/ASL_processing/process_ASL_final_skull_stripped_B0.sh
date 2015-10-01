[ $# != 1 ] && echo "script requires a logfile output by process_perfusion.sh" && exit 9

if [ "`basename $1`" == "temp.txt" ];then
input_config=`cat $1|sed -n "${SGE_TASK_ID}p"` #for use with grid
else
basename $1
input_config=$1
fi

source $input_config
current_dir=`pwd`

logrun(){
run="$*"
lrn=$(($lrn+1))
printf ">> `date`: $lrn: ${run}\n" >> $subject_log
$run
ec=$?
printf "exit code: $ec\n" #|tee -a $logfile
[ ! $ec -eq 0 ] && printf "\nError running $exe; exit code: $ec; aborting.\n" |tee -a $subject_log && exit 1
}


echo "**** Processing "$dir" *****"

###first apply distortion correction if desired and possible
if [ $dico == 1 ];then #check if user wants to use distortion correction
	test_dico_exists=`ls $subject_folder/$b0_folder/$b0_filename 2> /dev/null`
	dico_out=`ls $dir/dico_bet/$unique_id"_dc_dico.nii" 2> /dev/null`
	if [ "X$test_dico_exists" != "X" ];then
		if [ "X$dico_out" == "X" ];then
			###This script applies distortion correction to the raw dicoms. It requires that B0_maps already have been processed.
			echo "Applying distortion correction"
			mkdir -p $dir/dico_bet
			cd $dir/dico_bet/
			pwd
			echo /import/speedy/scripts/melliott/dico_correct_v2.sh -nx -e $single_dicom $unique_id"_dc" $rps $b0_mask $nifti
			logrun /import/speedy/scripts/melliott/dico_correct_v2.sh -nx -e $single_dicom $unique_id"_dc" $rps $b0_mask $nifti
			cd $current_dir
			###test if dico ran
			dico_out=`ls $dir/dico_bet/$unique_id"_dc_dico.nii" 2> /dev/null`
			if [ "X$dico_out" == "X" ];then
			"ERROR: could not apply distortion correction"
			exit 1
			fi
		fi # [ "X$dico_out" == "X" ];then
		echo "Distortion correction will be used"
		#set variables for using dico output
		dico=1
		data_to_use_in_prestats=$dico_out
	elif [ "X$test_dico_exists" == "X" ];then 
		echo "No B0 map for participant $scanid. Raw image will be used"
		dico=-1
		data_to_use_in_prestats=$nifti
	fi # if [ "X$test_dico_exists" != "X" ];then
elif [ $dico == 0 ];then 
echo "Not using distortion correction"
dico=-1
data_to_use_in_prestats=$nifti
fi # if [ $dico == 1 ] 

##This script processes the prestats. It requires an appropriately edited template.fsf file.
test_feat=`ls $feat_outpath.feat/absbrainthresh.txt 2> /dev/null`
if [ "X$test_feat" == "X" ];then
echo "Running prestats"

#check if volumes need removed
[ $remove_volumes == 1 ] && volumes=8 || volumes=0

cp $scriptdir/template_bet.fsf $scriptdir/"$unique_id"_design.fsf

sed -i s@WWWWWW_t1brain@$t1brain@g $scriptdir/"$unique_id"_design.fsf
sed -i s@VVVVVV_4D_data_to_use@$data_to_use_in_prestats@g $scriptdir/"$unique_id"_design.fsf
sed -i s@YYYYYY_feat_outpath@$feat_outpath@g $scriptdir/"$unique_id"_design.fsf
sed -i s@ZZZZZZ_smoothing@$smoothing@g $scriptdir/"$unique_id"_design.fsf
sed -i s@XXXXXX_volumes@$volumes@g $scriptdir/"$unique_id"_design.fsf

logrun feat $scriptdir/"$unique_id"_design.fsf

k=0
while [ "X$test_feat" == "X" ] && [ $k -lt 31 ]
do
echo "***** feat still running"
k=$((k+1))
sleep 120
test_feat=`ls $feat_outpath.feat/absbrainthresh.txt 2> /dev/null`
done

echo "***** feat is finished running"

if [ $k == 31 ];then
echo $dir >> feat_timeout.txt
exit
fi # if [ $k == 31 ];then
elif [ "X$test_feat" == "X" ];then
echo "Prestats already run"
fi # if [ "X$test_feat" == "X" ];then

##This script extracts information from a dicom that will be used in the quantification step. It requires that a single dicom have been downloaded.
if [ ! -e $dir/pcasl_info.xml ];then
echo "Creating pcasl_info.xml"
logrun /import/speedy/scripts/melliott/dicom_dump.sh $single_dicom $dir/pcasl_info.xml
fi

if [ ! -e $dir/mask_for_quant.nii* ];then
##This script makes the mask needed for the quantification
echo "Creating mask for quantification"
ref=`ls $feat_outpath.feat/example_func.nii.gz`
mat=`ls $feat_outpath.feat/reg/highres2example_func.mat`

logrun flirt -in $t1brain -ref $ref -applyxfm -init $mat -out $dir/mprage2func_dico_bet.nii.gz
logrun fslmaths $dir/mprage2func_dico_bet.nii.gz -bin $dir/mask_for_quant.nii.gz
fi

##This script makes the actual quantified image. It is a wrapper for Mark Elliot's quantification script
quant_out=`ls $quant_outpath/$quant_outname.nii 2> /dev/null`
filtered_func=$feat_outpath.feat/filtered_func_data.nii.gz
xml=$dir/pcasl_info.xml
if [ "X$quant_out" == "X" ];then
echo "Quantifying mean perfusion"
mkdir -p $quant_outpath
quant_mask=$dir/mask_for_quant.nii.gz

###unzipping files was necessary for old versions of pcasl_quant
#gunzip $quant_mask
#gunzip $filtered_func
#quant_mask=$dir/mask_for_quant.nii
#filtered_func=$feat_outpath.feat/filtered_func_data.nii

###T1 adjusted for age and gender
logrun /import/speedy/scripts/melliott/pcasl_quant_v7.sh $filtered_func $xml $quant_mask $quant_outpath/$quant_outname $t1corr
quant_out=`ls $quant_outpath/$quant_outname.nii*`
fi

###This script applies the transformation to template space
 ###ants does not work yet. this needs updated
if [ $registration == "ants" ];then
	regpath=$quant_outpath/reg_std_ants
	template=/import/speedy/eons/templates/mni_152_skull.nii.gz
	copename=`basename $c | cut -d "." -f1`
	normpath=$(ls -d $subject_folder/*[Mm][Pp][Rr][Aa][Gg][Ee]*/s-normsegmod/)
	rigid=$(ls -d $normpath/mni152_f_*_mprage_r_m_0DerivedInitialMovingTranslation.mat)
	affine=$(ls -d $normpath/mni152_f_*_mprage_r_m_1Affine.mat)
	warp=$( ls -d $normpath/mni152_f_*_mprage_r_m_2Warp.nii.gz)
	coregpath=`ls -d $coreg_outpath`
	#coregwarp=$(ls -d $coreg_outpath/ep2struct_warp.nii.gz) ###re-applies distortion correction if used instead of coreg

	logrun c3d_affine_tool -ref $coregpath/ep2struct.nii.gz -src $feat_outpath.feat/example_func.nii.gz $coregpath/ep2struct.mat -fsl2ras -oitk $coregpath/fsl2ants.txt

	coreg=$(ls -d $coreg_outpath/fsl2ants.txt)

	if [ ! -e $regpath/$quant_outname.nii.gz ];then
	echo "Transforming to template space"
	mkdir -p $regpath

	echo "Applying transform"
	echo "antsApplyTransforms -d 3 -i $c -o $regpath/$quant_outname.nii.gz -r $template -t $affine -t $rigid -t $warp -t $coreg"
	logrun antsApplyTransforms -d 3 -i $quant_out -o $regpath/$quant_outname.nii.gz -r $template -t $affine -t $rigid -t $warp -t $coreg
	else
	echo "Already transformed"
	fi

	if [ ! -e $regpath/"$quant_outname"_2mm.nii.gz ];then
	echo "Downsampling"
	logrun fslmaths $regpath/$quant_outname.nii.gz -subsamp2 $regpath/"$quant_outname"_2mm
	else
	echo "Already downsampled"
	fi


elif [ $registration == "dramms" ];then
	example_func=`ls $feat_outpath.feat/example_func.nii.gz 2> /dev/null`
	example_func_brain=`ls $feat_outpath.feat/$unique_id"_example_func_brain"* 2> /dev/null`
	if [ "X$example_func_brain" == "X" ];then
	logrun bet $example_func $feat_outpath.feat/$unique_id"_example_func_brain" -f 0.3
	example_func_brain=`ls $feat_outpath.feat/$unique_id"_example_func_brain"*`
	fi
	coregmat=$feat_outpath.feat/reg/example_func2highres.mat
	coregnifti=$feat_outpath.feat/reg/example_func2highres.nii.gz
	echo "combining warps"
	logrun $DRAMMSDIR/dramms-combine -c -f $example_func_brain -t $t1brain $coregmat $dramms_warp $coregnifti
	echo "applying warps"
	logrun $DRAMMSDIR/dramms-warp $quant_outpath/$quant_outname.nii $coregnifti $quant_outpath/"$quant_outname"_std_dramms

fi
