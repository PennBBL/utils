. /import/monstrum/Users/hopsonr/.bashrc

####this will process the frac2back using the nobehave model as for GO1 and 2

if [ "$#" == 0 ];then
	singlesub=0
	#slist=`cat $dir/eons3_xnat_audit_*.csv | grep 009216`
elif [ "$#" == 1 ];then
	singlesub=1
else
	echo "Illegal number of arguments"
	exit
fi

scriptdir=/import/monstrum/eons3_xnat/scripts/frac2back
downloaddir=/import/monstrum/eons3_xnat/subjects
log=$scriptdir/frac2back_error_log.txt
[ $singlesub == 0 ] && rm -f $scriptdir/frac2back_error_log.txt
[ $singlesub == 0 ] && echo "bblid,scanid,has_frac2back,frac2back_prestats_run,frac2back_stats_run" > $scriptdir/frac2back_processing_audit.csv
audit=`ls /import/monstrum/eons3_xnat/scripts/download/eons3_xnat_audit_*.csv`

check_frac2back () {
	#set vars to 0
	process=0;zstat_check=0;zstat=0;process_prestats=0;process_zstat=0;prestats=0;errors=$scanid,$bblid
	
	prestats_check=`ls $subdir/*bbl1_frac2back1_231/prestats/absbrainthresh.txt 2> /dev/null`
	if [ "X$prestats_check" == "X" ] && [ $has_frac2back == 1 ];then 
		echo "***missing prestats"
		process=1
		process_prestats=1
		errors=$errors,"missing_prestats"
	elif [ "X$prestats_check" != "X" ] && [ $has_frac2back == 1 ];then
		prestats=1
	fi

	zstat_check=`ls $subdir/*_bbl1_frac2back1_231/stats/*frac_nobehave_stats*.feat/stats/zstat1.nii.gz 2> /dev/null`
	if [ "X$zstat_check" == "X" ] && [ $has_frac2back == 1 ];then 
		echo "***missing zstat"
		process=1
		process_zstat=1
		errors=$errors,"missing_zstat"
	elif [ "X$zstat_check" != "X" ] && [ $has_frac2back == 1 ];then
		zstat=1
	fi
}

[ $singlesub == 0 ] && slist=`cat $audit | sed -n 2,'$'p`
[ $singlesub == 1 ] && slist=`cat $audit | grep $1`

for i in $slist
do

scanid=`echo $i | cut -d "," -f 1`
scanid_short=`echo $scanid | sed 's/^0*//'`
bblid=`echo $i | cut -d "," -f 10 | sed 's/^0*//'`
has_frac2back=`echo $i | cut -d "," -f 6`
subdir=`ls -d /import/monstrum/eons3_xnat/subjects/*$scanid_short`
id=`echo $bblid"_"$scanid_short`
echo "******************"$id"******************************"

#qsub -q all.q -S /bin/bash /import/monstrum/Users/chadtj/xnat_frac_stats_sge.sh 00$scanid

check_frac2back

[ $process_prestats == 1 ] && /import/monstrum/BBL_scripts/prestats/prestats_v2.3.py -scanid $scanid -seqname frac2back -output frac_prestats -match 1
[ $process_zstat == 1 ] && /import/monstrum/BBL_scripts/stats_poststats/stats_v2.1.py -output frac_nobehave_stats_$scanid -scanid $scanid -seqname frac2back -duplicate 0 -design $scriptdir/eons_frac2back_nobehave_stats_template.fsf
[ $process == 1 ] && /import/monstrum/BBL_scripts/xnat_downloaders/xnatdownloader_v2.py -scanid $scanid -outdir $downloaddir

check_frac2back
[ $singlesub == 0 ] && echo $bblid,$scanid_short,$has_frac2back,$prestats,$zstat >> $scriptdir/frac2back_processing_audit.csv
[ $singlesub == 0 ] && [ $process == 1 ] && echo $bblid,$scanid_short,$errors >> $scriptdir/frac2back_error_log.txt

#fi
done

error_log_test=`ls $scriptdir/frac2back_error_log.txt 2> /dev/null`
if [ "X$error_log_test" != "X" ] && [ $singlesub == 0 ];then
day=`date +%m_%d_%y`
echo ""
echo "Emailing error log"
mail -s "GO3 frac2back error log for $day" hopsonr@bbl.med.upenn.edu < $scriptdir/frac2back_error_log.txt
fi

[ $singlesub == 0 ] && /import/monstrum/Applications/R3.0.2/bin/R --file=/import/monstrum/Users/hopsonr/upload_to_redcap.R --slave --args "PNC-LG_Timepoint3_Imaging" "/import/monstrum/eons3_xnat/scripts/frac2back/frac2back_processing_audit.csv"

