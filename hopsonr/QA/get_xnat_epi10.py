#!/import/monstrum/Applications/epd-7.1/bin/python
import sys
from pyxnat import Interface
import argparse, getpass

parser = argparse.ArgumentParser(description='Returns project specific qa_epi10 module data: get_xnat_epi10.py -configfile ~/.xnat.cfg -project EONS_810366');

group = parser.add_argument_group('Required')
group.add_argument('-configfile', action="store", dest='configfile', required=True, help='Path to .xnat.cfg')
group.add_argument('-project', action="store", dest='project', required=True, help='Project name as in xnat')
parser.add_argument('-version', action='version', version='%(prog)s 3.0')

inputArguments = parser.parse_args()
configfile = inputArguments.configfile
project = inputArguments.project

central = Interface(config=configfile)

X = central.select('bbl:epi10').where([('bbl:epi10/PROJECT','=',project),'AND'])
epi10_fields=['subject_id','scan_date','tr','func_seqname','imagescan_id','session_id','project','meanrelrms','maxrelrms','tsnr2','spikerate2','spikepts2','gsnr3','gmean2','drift2','nclip','bbl_epi10_externalid']

Y = central.select('bbl:Sequence').where([('bbl:Sequence/PROJECT','=',project),'AND'])

scan_info={}
for i in Y:
	scan_info[str(i.get('session_id')+'_'+i.get('imagescan_id'))]=i.get('qlux_qluxname')

D=""
for j in epi10_fields:  
                D=D+str(j)+','
D=D+str('qlux_qluxname')
print D
for line in X:
	D=""
	for j in epi10_fields:	
		D = D+str(line.get(j))+','
	D=D+str(scan_info[str(line.get('session_id'))+'_'+str(line.get('imagescan_id'))])
	print D


#subject_dict = {} 
#for i in seqs:
#	subject_dict[str(i.get('session_id'))]=i.get('subject_id')
