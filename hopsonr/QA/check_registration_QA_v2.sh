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
while getopts ":f:h" OPT
	do
	case $OPT in
		h) #help
		Usage >&2
		exit 0
		;;
		f) #path to file
		data=$OPTARG
		;;
		\?) # getopts issues an error message
		Usage >&2
		exit 1
		;;
	esac
done
template=/import/monstrum/Applications/fsl5/data/standard/MNI152_T1_2mm_brain.nii.gz
reg_test=`ls $data 2>/dev/null`
[ "X$reg_test" == "X" ] && echo "nifti not found for registration check" && exit
cc=$(fslcc $reg_test $template | awk '{print $3}' )
echo $cc
