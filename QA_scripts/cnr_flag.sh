#! /bin/bash
export SUBJECTS_DIR=$2
slist=$1
outdir=$SUBJECTS_DIR/../stats/cnr
if [ ! -e $outdir ]; then mkdir $outdir; fi
file=$outdir/cnr_buckner.csv
if [ ! -e $file ]; then
	echo bblid,scanid,cnr > $file
fi
for i in $(cat $slist);do
	bblid=$(echo $i | cut -d"_" -f1)
	scanid=$(echo $i | cut -d"_" -f2)
	echo working on subject $bblid $scanid
	surf=`ls -d $SUBJECTS_DIR/$i/surf`
	mri=`ls -d $SUBJECTS_DIR/$i/mri`
	# checks if subject is in the file already. not sure if this will work
	if ! grep -q "$bblid,$scanid" $file; then
		mri_cnr $surf $mri/orig.mgz > val.txt
		val=`grep "total CNR" val.txt`
		value=`echo $val |cut -f 4 -d " "`
		subj=`echo $i |cut -f 6 -d /`
		echo $bblid,$scanid,$value >> $file
	fi
done
rm -f val.txt
