source /etc/bashrc

if [ $# -lt 2 ];then
	echo "ERROR: missing arguments"
	exit
fi

template=/import/monstrum/Applications/fsl5/data/standard/MNI152_T1_2mm_brain.nii.gz

for i in `ls -d /import/monstrum/$1/subjects/*/$2`
do
	scanid=`echo $i | cut -d "/" -f 6 | cut -d "_" -f 2`
	reg_test=`ls $i/stats/*$3*/reg_std_ants/example_func2standard_2mm.nii.gz 2> /dev/null`
	#echo $i
	#echo $reg_test
	[ "X$reg_test" != "X" ] && cc=$(fslcc $reg_test $template | awk '{print $3}' )
	echo $scanid,$cc
done
