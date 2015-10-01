###as an input, this script takes the path to a group level feat directory
###find the names of contrasts at the group level
for i in `grep ContrastName $1/design.con | sed s/" "/"_"/g | cut -f 2`
do
group_cons=(${group_cons[@]} $i)
done

echo "=========Group Level Contrast Names========="
printf -- '%s\n' "${group_cons[@]}"

###get a single subject feat dir and find the names of contrasts at subject level
single_subject=`grep subjects $1/design.fsf | head -1 | cut -d "\"" -f 2`
for i in `grep ContrastName $single_subject/design.con | sed s/" "/"_"/g | cut -f 2`
do
s_cons=(${s_cons[@]} $i)
done

echo "=========Subject Level Contrast Names========="
printf -- '%s\n' "${s_cons[@]}"


###make directory for new zstats
mkdir -p $1/renamed_zstats

###append group and subject level contrasts to make meaningful names, and copy zstats using new names
echo "=========Meaningful Name/Original Path========="
k=1
for i in ${s_cons[@]}
do
l=1
for j in ${group_cons[@]}
do

name=`echo $i$j`

echo $name
ls $1/cope"$k".feat/stats/zstat"$l".nii.gz

cp $1/cope"$k".feat/stats/zstat"$l".nii.gz $1/renamed_zstats/"$name"zstat.nii.gz

l=$((l+1))
done
k=$((k+1))
done
