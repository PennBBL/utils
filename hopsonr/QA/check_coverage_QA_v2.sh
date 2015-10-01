source /etc/bashrc
mask=$3
voxels_in_mask=`fslstats $mask -V | cut -d " " -f 1`

for i in `ls -d /import/monstrum/$1/subjects/*/$2`
do
zeros=""
scanid=`echo $i | cut -d "/" -f 6 | cut -d "_" -f 2`


#reg_test=`ls $i/stats/$4/reg_std_ants/example_func2standard_2mm.nii.gz 2> /dev/null`
reg_test=`ls $i/$4/reg_std_ants/cbf_map_*_2mm.nii.gz 2> /dev/null`

[ "X$reg_test" == "X" ] && continue


#zeros=`fslstats $reg_test -a -k $mask -H 2 0 0.00001 | head -1` #find voxels inside mask which are 0
#echo "fslstats $reg_test -a -k $mask -H 2 0 0.00001 | head -1"


nonzeros=`fslstats $reg_test -k $mask -V | cut -d " " -f 1`
zeros=`echo $voxels_in_mask - $nonzeros | bc`

###look for voxels above 1/3 of max outside of mask
max=`fslstats $reg_test -r | cut -d " " -f 2`
threshold=`echo 'scale=0;'$max'/3' | bc`
inbrainvoxels=`fslstats $reg_test -k $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz -l $threshold -V | cut -d " " -f 1`
#echo "fslstats $reg_test -k $FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz -l $threshold -V | cut -d " " -f 1"
allvoxels=`fslstats $reg_test -l $threshold -V | cut -d " " -f 1`
#echo "fslstats $reg_test -l $threshold -V | cut -d " " -f 1"
outofbrainvoxels=`echo $allvoxels - $inbrainvoxels | bc`

#echo $allvoxels
#echo $inbrainvoxels

echo $scanid,$zeros,$outofbrainvoxels | sed s/" "//g

done
