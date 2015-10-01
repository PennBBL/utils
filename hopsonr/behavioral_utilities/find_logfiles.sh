collab=1
audit_file=/import/monstrum/tripod/scripts/download/tripod_audit_03_31_15.csv #audit file from xnat
oracle_file=/import/monstrum/tripod/scripts/behavioral/migrate_score_download/oracle_4_1_15.csv #oracle file - bblid,scanid,sourceid,doscan
out_dir=/import/monstrum/tripod/logfiles #output directory
scans="4letter3B emo_gonogo emo_ID letter3B_rec" #scan names (as in logfiles)

check_size(){
	biggest=TRUE
	size=`wc -l $1 | cut -d " " -f 1`
	#echo running
	#echo $2
	for log in $2;
	do
		#echo $log
		[ $1 == $log ] && continue
		log_size=`wc -l $log | cut -d " " -f 1`
		#echo $size,$log_size
		[ $log_size -gt $size ] && biggest=FALSE
	done
}

find_dir_by_date(){
	date_match=""
	for possible_folder in /import/monstrum/RTexport/01_logfiles/$prefix* /import/monstrum/RTexport/01_logfiles/older_logs/$prefix*
	do
		possible_log=`ls $possible_folder/*log 2> /dev/null | head -1`
		[ -z $possible_log ] && continue
		possible_date=`grep written $possible_log | cut -d " " -f 4`
		[ "$possible_date" == "$doscan" ] && [ ! -z $date_match ] && date_match=$date_match,$possible_folder
		[ "$possible_date" == "$doscan" ] && [ -z $date_match ] && date_match=$possible_folder
	done
}

for i in `cat $audit_file | sed -n 2,'$'p`
do
	scanid=`echo $i | cut -d "," -f 1 | sed s/^0*//`
	echo $scanid
	if [ $collab == 1 ];then
		oracle=`grep ,$scanid, $oracle_file` 
		sourceid=`echo $oracle | cut -d "," -f 3`
		missing=0

		for j in $scans
		do
			[ -e $out_dir/$scanid/*$j* ] && echo "already found $scanid,$j" && continue
			missing=1

		done

		[ $missing == 0 ] && echo "already found all logs for $scanid" && continue
		[ -z $sourceid ] && echo "$scanid not found in oracle" && continue
		#echo $sourceid
		doscan=`echo $oracle | cut -d "," -f 4`
		dir=`ls -d /import/monstrum/RTexport/01_logfiles/$sourceid 2> /dev/null`
		[ -z $dir ] && dir=`ls -d /import/monstrum/RTexport/01_logfiles/older_logs/$sourceid 2> /dev/null`
		prefix=`echo $sourceid | sed s/[0-9].*//`
		if [ -z $dir ];then
			#echo $prefix
			find_dir_by_date
			echo "no directory found for $scanid. Date match: $date_match"
			continue
		fi

		mkdir -p $out_dir/$scanid
		for j in $scans
		do
			[ -e $out_dir/$scanid/*$j* ] && echo "already found $scanid,$j" && continue
			recent=`ls -tr $dir/*$j* 2> /dev/null | tail -1`
			logs=`ls -tr $dir/*$j* 2> /dev/null`
			[ "X$logs" == "X" ] && echo "no logs found for $scanid, $j" && continue
			#echo $logs
			check_size $recent "$logs"
			#echo $biggest
			[ ! $biggest ] && echo "Most recent logfile not largest for $scanid, $j" && continue
			log_date=`grep written $recent | cut -d " " -f 4`
			[ ! "$doscan" == "$log_date" ] && echo "Date mismatch for $scanid, $j" && continue
			cp -i $recent $out_dir/$scanid
		done
	fi
done



