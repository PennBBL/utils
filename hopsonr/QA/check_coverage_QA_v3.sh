#useage
function Usage {
    cat <<USAGE
Usage:
  -f:  Full path to processed data. Required.
  -m:  Group level mask to check coverage (MNI brain can be substituted). Required.
USAGE
    exit 1
}

# reading command line arguments
while getopts ":f:m:h" OPT
	do
	case $OPT in
		h) #help
		Usage >&2
		exit 0
		;;
		f) #path to file
		data=$OPTARG
		;;
		m) #path to group mask
		mask=$OPTARG
		;;
		\?) # getopts issues an error message
		Usage >&2
		exit 1
		;;
	esac
done

### arguments 1 = protocol, 2 = nifti , 3 = maskaudit_file
source /etc/bashrc

##count number of voxels in mask
voxels_in_mask=`fslstats $mask -V | cut -d " " -f 1`

###initialize variable
zeros=""

###make sure nifti exists
reg_test=`ls $data 2>/dev/null`
[ "X$reg_test" == "X" ] && echo "nifti not found for coverage check" && exit

###count nonzeros, subtract from voxels in mask, for zeros in mask
nonzeros=`fslstats $reg_test -k $mask -V | cut -d " " -f 1`
zeros=`echo $voxels_in_mask - $nonzeros | bc`

###look for voxels above 1/3 of max outside of mask
max=`fslstats $reg_test -r | cut -d " " -f 2`
threshold=`echo 'scale=0;'$max'/3' | bc` #calculate threshold
inbrainvoxels=`fslstats $reg_test -k $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz -l $threshold -V | cut -d " " -f 1` #count voxels above threshold in brain
allvoxels=`fslstats $reg_test -l $threshold -V | cut -d " " -f 1` #count all voxels above threshold
outofbrainvoxels=`echo $allvoxels - $inbrainvoxels | bc` #subtract for voxels out of mask. done so mask doesn't need to be inverted

echo $zeros,$outofbrainvoxels | sed s/" "//g
