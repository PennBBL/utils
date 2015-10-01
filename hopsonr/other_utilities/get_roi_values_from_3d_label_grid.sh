list=$1
first=1
max=0

i=$(cat $list|sed -n "${SGE_TASK_ID}p")
#i=$(cat $list|sed -n "1p")


subdir=`echo $i | cut -d "/" -f 1-6`
bblid=`echo $i | cut -d "/" -f 6 | cut -d "_" -f 1`
scanid=`echo $i | cut -d "/" -f 6 | cut -d "_" -f 2`
echo $bblid,$scanid
mask=`ls $subdir/*_mprage/sbia/*labeled_SimRank+IC+FS*.nii.gz`
mask_count=`echo $mask | wc -w`
[ $mask_count != 1 ] && echo "wrong number of masks - " $mask_count && continue

outpath=$i/get_rois_temp.txt

echo "bblid,scanid,cope,File,Sub-brick,Mean_4,Mean_11,Mean_23,Mean_30,Mean_31,Mean_32,Mean_35,Mean_36,Mean_37,Mean_38,Mean_39,Mean_40,Mean_41,Mean_42,Mean_43,Mean_46,Mean_47,Mean_48,Mean_49,Mean_50,Mean_51,Mean_52,\
Mean_55,Mean_56,Mean_57,Mean_58,Mean_59,Mean_60,Mean_61,Mean_62,Mean_63,Mean_64,Mean_69,Mean_71,Mean_72,Mean_73,Mean_75,Mean_76,Mean_81,Mean_82,Mean_83,Mean_84,Mean_85,Mean_86,Mean_87,Mean_88,Mean_89,Mean_90,Mean_91,\
Mean_92,Mean_93,Mean_94,Mean_95,Mean_100,Mean_101,Mean_102,Mean_103,Mean_104,Mean_105,Mean_106,Mean_107,Mean_108,Mean_109,Mean_112,Mean_113,Mean_114,Mean_115,Mean_116,Mean_117,Mean_118,Mean_119,Mean_120,Mean_121,\
Mean_122,Mean_123,Mean_124,Mean_125,Mean_128,Mean_129,Mean_132,Mean_133,Mean_134,Mean_135,Mean_136,Mean_137,Mean_138,Mean_139,Mean_140,Mean_141,Mean_142,Mean_143,Mean_144,Mean_145,Mean_146,Mean_147,Mean_148,Mean_149,\
Mean_150,Mean_151,Mean_152,Mean_153,Mean_154,Mean_155,Mean_156,Mean_157,Mean_160,Mean_161,Mean_162,Mean_163,Mean_164,Mean_165,Mean_166,Mean_167,Mean_168,Mean_169,Mean_170,Mean_171,Mean_172,Mean_173,Mean_174,Mean_175,\
Mean_176,Mean_177,Mean_178,Mean_179,Mean_180,Mean_181,Mean_182,Mean_183,Mean_184,Mean_185,Mean_186,Mean_187,Mean_190,Mean_191,Mean_192,Mean_193,Mean_194,Mean_195,Mean_196,Mean_197,Mean_198,Mean_199,Mean_200,Mean_201,\
Mean_202,Mean_203,Mean_204,Mean_205,Mean_206,Mean_207" > $outpath

all="File,Sub-brick,Mean_4,Mean_11,Mean_23,Mean_30,Mean_31,Mean_32,Mean_35,Mean_36,Mean_37,Mean_38,Mean_39,Mean_40,Mean_41,Mean_42,Mean_43,Mean_46,Mean_47,Mean_48,Mean_49,Mean_50,Mean_51,Mean_52,\
Mean_55,Mean_56,Mean_57,Mean_58,Mean_59,Mean_60,Mean_61,Mean_62,Mean_63,Mean_64,Mean_69,Mean_71,Mean_72,Mean_73,Mean_75,Mean_76,Mean_81,Mean_82,Mean_83,Mean_84,Mean_85,Mean_86,Mean_87,Mean_88,Mean_89,Mean_90,Mean_91,\
Mean_92,Mean_93,Mean_94,Mean_95,Mean_100,Mean_101,Mean_102,Mean_103,Mean_104,Mean_105,Mean_106,Mean_107,Mean_108,Mean_109,Mean_112,Mean_113,Mean_114,Mean_115,Mean_116,Mean_117,Mean_118,Mean_119,Mean_120,Mean_121,\
Mean_122,Mean_123,Mean_124,Mean_125,Mean_128,Mean_129,Mean_132,Mean_133,Mean_134,Mean_135,Mean_136,Mean_137,Mean_138,Mean_139,Mean_140,Mean_141,Mean_142,Mean_143,Mean_144,Mean_145,Mean_146,Mean_147,Mean_148,Mean_149,\
Mean_150,Mean_151,Mean_152,Mean_153,Mean_154,Mean_155,Mean_156,Mean_157,Mean_160,Mean_161,Mean_162,Mean_163,Mean_164,Mean_165,Mean_166,Mean_167,Mean_168,Mean_169,Mean_170,Mean_171,Mean_172,Mean_173,Mean_174,Mean_175,\
Mean_176,Mean_177,Mean_178,Mean_179,Mean_180,Mean_181,Mean_182,Mean_183,Mean_184,Mean_185,Mean_186,Mean_187,Mean_190,Mean_191,Mean_192,Mean_193,Mean_194,Mean_195,Mean_196,Mean_197,Mean_198,Mean_199,Mean_200,Mean_201,\
Mean_202,Mean_203,Mean_204,Mean_205,Mean_206,Mean_207"


for cope in `ls -v $i/*sig_cope*`
#for cope in `ls -v $i/*sig_cope1_rai*`
do
	cope_name=`echo $cope | sed s/'sig_cope'/','/g | cut -d "," -f 2 | cut -d "_" -f 1`
	rois=`3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 1p`
	rois=`echo $rois,`
	values=`3dROIstats -mask $mask $cope | tr '\t' ',' | sed s/' '//g | sed -n 2p`
	line=$bblid,$scanid,$cope_name
	count=1
	for item in `echo $all | tr "," " "`
	do
		#echo $item
		if [ "X`echo $rois | grep $item,`" != "X" ];then
			value=`echo $values | cut -d "," -f $count`
			line=`echo $line,$value`
			((count++))
		else
			line=`echo $line,NA`
		fi
		
	done
	echo $line >> $outpath		
done


