current_directory=`pwd`

for i in `cat /import/monstrum/ptsd_dm/dm_mprage_list.csv | sed -n 3,'$'p`
do
id=`echo $i | cut -d "," -f 1`
scan1=`echo $i | cut -d "," -f 4`
directory=/import/monstrum/ptsd_dm/subjects/DecisionMaking/$id/T1/
mkdir -p $directory/T1_scan1_BET
mkdir -p $directory/T1_scan1_ANTs_cortical_thickness_OASIS

echo "logdir is "$directory/ants_log.txt

echo $id,$scan1 > $directory/ants_log.txt
echo /import/monstrum/Applications/statapps/ANTs/bin/antsBrainExtraction_rdh2.sh -d 3 -a $directory/$scan1 -e /import/monstrum/Applications/fsl5/data/standard/MNI152_T1_1mm.nii.gz -m /import/monstrum/Applications/fsl5/data/standard/MNI152_T1_1mm_brain_mask.nii.gz -o $directory/T1_scan1_BET/antsBET -k 1 >> $directory/ants_log.txt

qsub -q all.q -S /bin/bash -V -e ~/sge_out/ -o ~/sge_out/ /import/monstrum/Applications/statapps/ANTs/bin/antsBrainExtraction_rdh2.sh -d 3 -a $directory/$scan1 -e /import/monstrum/Applications/fsl5/data/standard/MNI152_T1_1mm.nii.gz -m /import/monstrum/Applications/fsl5/data/standard/MNI152_T1_1mm_brain_mask.nii.gz -o $directory/T1_scan1_BET/antsBET -k 1

echo "" >> $directory/ants_log.txt
echo /import/monstrum/Applications/statapps/ANTs/bin/antsCorticalThickness_rdh.sh -d 3 -a $directory/$scan1 -e /import/monstrum/atlases/OASIS/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0.nii.gz -m /import/monstrum/atlases/OASIS/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumProbabilityMask.nii.gz -p /import/monstrum/atlases/OASIS/MICCAI2012-Multi-Atlas-Challenge-Data/Priors2/priors%d.nii.gz -t /import/monstrum/atlases/OASIS/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellum.nii.gz -f /import/monstrum/atlases/OASIS/MICCAI2012-Multi-Atlas-Challenge-Data/T_template0_BrainCerebellumMask.nii.gz -o $directory/T1_scan1_ANTs_cortical_thickness_OASIS >> $directory/ants_log.txt

#${ANTSPATH}antsCorticalThickness.sh -d 3 -a $t1 -e ${templateDir}/template.nii.gz -m ${templateDir}/masks/templateBrainMaskProbability.nii.gz -f ${templateDir}/masks/templateBrainExtractionRegistrationMask.nii.gz -p ${templateDir}/priors/prior%02d.nii.gz -t ${templateDir}/templateBrain.nii.gz -o ${outputRoot}"

done


