while getopts ":a:" OPT
	do
	case $OPT in
		a) #audit file
		audit_file=`echo $audit_file $OPTARG`
		;;
		\?) # getopts issues an error message
		echo "error" >&2
		exit 1
		;;
	esac
done

echo $audit_file
