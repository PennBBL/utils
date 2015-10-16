#!/bin/bash
# The main script for running freesurfer QA. The final output is
# a csv that has flags on whether someone is an outlier (>2sd) in any of
# the following fields:
# 1. mean thickness
# 2. total surface area
# 3. Cortical volume
# 4. Subcortical gray matter
# 5. Cortical White matter
# 6. CNR
# 7. SNR
# 8. ROI-Raw cortical thickness
# 9. ROI- laterality thickness difference
# For the ROI based measures we compute number of roi outliers for each subject
# then compute outliers across subjects for number of ROIs flagged.


# full directory to subject list bblid_scanid
slist=/import/monstrum/.../n_project_bblid_scanid.csv
export SUBJECTS_DIR=/import/monstrum/.../freesurfer/subjects
export QA_TOOLS=/import/monstrum/Applications/freesurfer/QAtools_v1.1

# create subcortical segment volumes
if [ ! -e "$SUBJECTS_DIR/../stats/aseg.stats" ]; then
	mkdir -p $SUBJECTS_DIR/../stats/aseg.stats
fi
asegstats2table --subjectsfile=$slist -t $SUBJECTS_DIR/../stats/aseg.stats/aseg.stats.volume.csv -m volume --skip

# create parcelation tables
if [ ! -e "$SUBJECTS_DIR/../stats/aparc.stats" ]; then
	mkdir -p $SUBJECTS_DIR/../stats/aparc.stats
fi
# code to create mean QA data charts. thickness and surface area charts.
/import/monstrum/.../progs/freesurfer/qa/aparc.stats.meanthickness.totalarea.sh $slist $SUBJECTS_DIR

aparcstats2table --hemi lh --subjectsfile=$slist -t $SUBJECTS_DIR/../stats/aparc.stats/lh.aparc.stats.thickness.csv -m thickness --skip
aparcstats2table --hemi rh --subjectsfile=$slist -t $SUBJECTS_DIR/../stats/aparc.stats/rh.aparc.stats.thickness.csv -m thickness --skip
aparcstats2table --hemi lh --subjectsfile=$slist -t $SUBJECTS_DIR/../stats/aparc.stats/lh.aparc.stats.volume.csv -m volume --skip
aparcstats2table --hemi rh --subjectsfile=$slist -t $SUBJECTS_DIR/../stats/aparc.stats/rh.aparc.stats.volume.csv -m volume --skip

# cnr
# this runs the cnr_flag.sh and within the cnr_flag.R
/import/monstrum/.../progs/freesurfer/qa/cnr_flag.sh $slist $SUBJECTS_DIR

# snr
for i in $(cat $slist); do
	#$QA_TOOLS/recon_checker -s $(cat $slist) -nocheck-aseg -nocheck-status -nocheck-outputFOF -no-snaps > temp.txt
	$QA_TOOLS/recon_checker -s $i -nocheck-aseg -nocheck-status -nocheck-outputFOF -no-snaps 
done > temp.txt
grep "wm-anat-snr results" temp.txt | cut -d"(" -f2 | cut -d")" -f1 >temp2.txt
for i in $(cat -n temp.txt | grep "wm-anat-snr results" | cut -f1); do
	echo $(sed -n "$(echo $i +2 | bc)p" temp.txt | cut -f1)
done > temp3.txt
paste temp2.txt temp3.txt > $SUBJECTS_DIR/../stats/cnr/snr.txt
#rm -f temp*.txt


# r scripts to flag outliers from tables created above.
# These flag all the outliers, but write them all to separate files.
# need to add something to the end of aseg.stats.volumes.R to concatenate them all.
/import/monstrum/Applications/R/bin/R --slave --file=/import/monstrum/.../progs/freesurfer/qa/flag_outliers.R --args $SUBJECTS_DIR
