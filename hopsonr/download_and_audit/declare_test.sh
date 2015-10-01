testing_function () {
	num=1
	for i in `echo a b c`
	do	
		echo $i,$num
		string=`echo $i=$num`
		echo $string
		eval $string
		((num++))
	done

	for i in `echo a b c`
	do	
		echo ${!i}
	done

}

testing_function

for i in `echo a b c`
do	
	echo $i,${!i}
done


