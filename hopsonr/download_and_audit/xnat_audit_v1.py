#!/import/monstrum/Applications/epd-7.1/bin/python
import sys
import socket
from pyxnat import Interface
#import sys, getopt
import argparse, getpass

parser = argparse.ArgumentParser(description='Performs xnat audit: xnat_audit_v1.py -configfile ~/.xnat.cfg -project EONS_810366  -scan mprage -scan idemo -scan frac2back');

group = parser.add_argument_group('Required')
group.add_argument('-configfile', action="store", dest='configfile', required=True, help='Path to .xnat.cfg')
group.add_argument('-project', action="store", dest='project', required=True, help='Project name as in xnat')
group.add_argument('-scan', action="append", dest='scan', required=True, help='Single scan to be evaluated')

parser.add_argument('-version', action='version', version='%(prog)s 3.0')

inputArguments = parser.parse_args()
configfile = inputArguments.configfile
project = inputArguments.project
scans = inputArguments.scan

central = Interface(config=configfile)

#define function to perform final quality check#
################################################
def checkquality(scanid,scantype,array):
	quality = 0
	matching = []
	matching = [a for a in array if scantype in str(a.get('qlux_qluxname')) and scanid == str(a.get('session_id'))]
	for i in matching:
		if qual_dict[str(i.get('session_id')),str(i.get('imagescan_id'))] == 'usable' : quality = 1
	return quality

#define function for checking if log file uploaded#
###################################################
def checklog(scanid,dictionary):
	taskname=0
	if scanid in dictionary:
		taskname=dictionary[scanid]
	return taskname

#get all participants in a study#
#################################
constraints = [('bbl:Sequence/PROJECT','=',project),'AND',('bbl:Sequence/QLUX_MATCHED','=','1')]
seqs = central.select('bbl:Sequence',['bbl:Sequence/QLUX_QLUXNAME','bbl:Sequence/IMAGESCAN_ID','bbl:Sequence/SUBJECT_ID','bbl:Sequence/imageSession_ID','bbl:Sequence/PROJECT','bbl:Sequence/MR_SERIESDESCRIPTION']).where(constraints);

#create a dictionary of scanids and bblids#
###########################################
subject_dict = {} 
for i in seqs:
	subject_dict[str(i.get('session_id'))]=i.get('subject_id')

#get all quality data for subjects in the dictionary#
#####################################################
count = 1
for i in subject_dict.keys():
	if count == 1:
		quality_constraints="[('xnat:mrScanData/IMAGE_SESSION_ID','=','"+i+"')"
		count = 2
	quality_constraints = str(quality_constraints)+",'OR',('xnat:mrScanData/IMAGE_SESSION_ID','=','"+i+"')"
quality_constraints = str(quality_constraints)+"]"

quality_data = central.select('xnat:mrScanData',['xnat:mrScanData/IMAGE_SESSION_ID', 'xnat:mrScanData/QUALITY', 'xnat:mrScanData/ID']).where(eval(quality_constraints))

#create a dictionary of quality. key is tuple of scanid and sequence number#
############################################################################
qual_dict={}
for i in quality_data:
	qual_dict[str(i.get('image_session_id')),str(i.get('id'))]=i.get('quality')

#get all presentation files to check for logs#
##############################################
#constraints = [('bbl:presentation/PROJECT','=','MEALS_810792'),'AND',[('bbl:presentation/FORM','=','session_test'),'OR',('bbl:presentation/FORM','=','food_bk-v2.00')]]
#tasks=central.select('bbl:presentation',['bbl:presentation/SESSION_ID','bbl:presentation/SUBJECT_ID','bbl:presentation/EXPT_ID','bbl:presentation/FORM']).where(constraints)
#task_dict={}
#for i in tasks:
#	task_dict[str(i.get('session_id'))]=i.get('form')

#check scans for each participant#
##################################
header="subject"
for pair in scans:
	split=pair.split(',')
	scan=split[0]
	header+=","+str(scan)
header+=",bblid"
print header
#print "subject,mprage,B0,ep2d,idemo,frac2back,restbold,DTI,T2_sagittal,bblid"
for p in subject_dict.keys():
	subject=str(p)
	for pair in scans:
		split=pair.split(',')
		scan=split[0]
		matched=split[1]
		subject+=","+str(checkquality(p,scan,seqs))
	subject+=","+str(subject_dict[p])
	print subject
#	print str(p)+","+str(checkquality(p,'MPRAGE_TI1110_ipat2_moco3',seqs))+","+str(checkquality(p,'B0',seqs))+","+str(checkquality(p,'ep2d',seqs))+","+str(checkquality(p,'idemo',seqs))+","+str(checkquality(p,'frac2back',seqs))+","+str(checkquality(p,'restbold',seqs))+","+str(checkquality(p,'DTI',seqs))+","+str(checkquality(p,'T2_sagittal',seqs))+","+str(subject_dict[p])
#+","+str(task_dict.get(p))
