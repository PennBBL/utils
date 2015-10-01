#!/import/monstrum/Applications/epd-7.1/bin/python
from nipype.interfaces import fsl
import xnatmaster30 as xnatmaster
import argparse
import sys
import array
import subprocess
import os
import fnmatch
import shutil
import uuid
'''
By Chadtj
V1 Initial Version
V2 Uses new bbl:bet datatype and checks for existing nifti - no functional changes
'''
def slice_bet(tmpdir,niftiname):
	slice = fsl.Slicer()
        slice.inputs.in_file = niftiname
        slice.inputs.args = '-s 1 -x 0.4 ' +tmpdir+'/1.png -x 0.5 '+tmpdir+'/2.png -x 0.6 '+tmpdir+'/3.png -y 0.4 '+tmpdir+'/4.png -y 0.5 '+tmpdir+'/5.png -y 0.6 '+tmpdir+'/6.png -z 0.4 '+tmpdir+'/7.png -z 0.5 '+tmpdir+'/8.png -z 0.6'
        slice.inputs.out_file =  tmpdir+'/9.png'
        res = slice.run()
        print "Sliced"

def do_bet(head, fracval, fourD, logpath, tmpdir, prov_list):
        bet = fsl.BET()
        prefile = head.split('/')[-1]
        prefile_wo_ext = prefile[:prefile.find(".nii")]
        if fourD == False:
                bet.inputs.in_file = head
                bet.inputs.out_file = tmpdir + prefile_wo_ext + version + str(fracval) +  'frac_3D.nii.gz'
                bet.inputs.frac = fracval
                bet.inputs.mask = True
		xnatmaster.add_to_log(logpath, bet.cmdline)
                prov_list = xnatmaster.track_provenance(prov_list,'/import/monstrum/Applications/fsl_4.1.7/bin/bet','v2',head+' '+tmpdir + prefile_wo_ext + version + str(fracval) +  'frac_3D.nii.gz -m')
		result = bet.run()
		slice_bet(tmpdir,tmpdir + prefile_wo_ext + version + str(fracval) + 'frac_3D.nii.gz')
                return tmpdir + prefile_wo_ext + version + str(fracval) + 'frac_3D'
        else:
                bet.inputs.in_file = head
		bet.inputs.mask = True
                bet.inputs.out_file = tmpdir + prefile_wo_ext + version + str(fracval) + 'frac_4D.nii.gz'
                bet.inputs.functional=True
                bet.inputs.frac = fracval
                xnatmaster.add_to_log(logpath, bet.cmdline)
		prov_list = xnatmaster.track_provenance(prov_list,'/import/monstrum/Applications/fsl_4.1.7/bin/bet','v2',head+' '+tmpdir + prefile_wo_ext + version + str(fracval) + 'frac_4D.nii.gz -F')
                result = bet.run()
		slice_bet(tmpdir,tmpdir + prefile_wo_ext + version + str(fracval) + 'frac_4D.nii.gz')
                return tmpdir + prefile_wo_ext + version + str(fracval) + 'frac_4D'

###Setup input args here

parser = argparse.ArgumentParser(description='Python Pipeline BET Action Script');
group = parser.add_argument_group('Required')
group.add_argument('-scanid', action="store", dest='scanid', required=True, help='MR Session (scan id) of the Dicoms to convert')
group.add_argument('-download',action="store", dest='download', required=True, help='Should this download the results or just put it back into XNAT? 1 to download or 0 to not download')
optgroup=parser.add_argument_group('Optional')
optgroup.add_argument('-frac', action="store", dest='frac', required=False, help='Fractional intensity value. Default .5 ', default=.5)
optgroup.add_argument('-fourD', action="store", dest='fourD', required=False, help='Is this 4D FMRI Data? Default 0 for MPRAGE', default='0')
optgroup.add_argument('-scantype',action="store", dest='scantype', required=False, help='Enter the type of scan, currently available options are MPRAGE, T2, DTI, DWI, EPI, ASL', default='')
optgroup.add_argument('-upload',action="store", dest='upload', required=False, help='Should this result be uploaded into XNAT? 1 to upload, 0 to keep locally. Default: 0', default='0')
optgroup.add_argument('-outdir',action="store", dest='outdir', required=False, help='Name of the output directory if downloading the result', default='')
optgroup.add_argument('-tmpdir',action="store", dest='tmpdir', required=False, help='Name of the temporary directory to do work', default='/import/monstrum/tmp/bet')
optgroup.add_argument('-configfile',action="store",dest='configfile',required=False, help='Enter path to your XNAT config file if desired.', default='X')
optgroup.add_argument('-seqname',action="store",dest='seqname',required=False, help='Enter a valid sequence name here, eg. DTI, MPRAGE, DWI, T2, RESTBOLD, FRAC2BACK, IDEMO, ASL, or ALL',default='-1')
optgroup.add_argument('-check_existing',action="store",dest='findexisting',required=False,help='Just download Nifti if it already exists. 1 if yes, 0 to force a new nifti to be made.', default='1')
optgroup.add_argument('-sequence_id',action="store", dest='sequence_id', required=False, help='Probably for internal XNAT pipeline use only', default='-1')
parser.add_argument('-version', action='version', version='%(prog)s 2.0')
version='_bet_v2_'
########

###Parse input args here

inputArguments = parser.parse_args()
scanid = inputArguments.scanid
download = inputArguments.download
outdir = inputArguments.outdir
scantype = inputArguments.scantype
tmpdir = inputArguments.tmpdir
upload = inputArguments.upload
configfile = inputArguments.configfile
sn = inputArguments.seqname
fourD = inputArguments.fourD
frac = inputArguments.frac
findexisting = inputArguments.findexisting
sid = inputArguments.sequence_id
########

### Done setting up inputs #####

if scantype != '' and int(sid) != -1:
        print "Got both scantype and sequence_id specified; sequence_id takes priority"

scantype = scantype.upper()

if outdir == '' and download == '1':
	print "Need to specify full path to the output directory with the download flag"
	sys.exit(1)

if download == '0' and upload == '0':
        print "Please specify either -download 1 and/or -upload 1, otherwise this script has no real purpose"
        sys.exit(1)

if outdir == '':
	outdir = tmpdir

scanid_array = xnatmaster.parse_scanids(scanid)

central = xnatmaster.setup_xnat_connection(configfile)

corrected_scanid_array = []

for i in range(0,len(scanid_array)):
	corrected_scanid_array.append(xnatmaster.add_zeros_to_scanid(scanid_array[i],central))
	print str(scanid_array[i]) + ' is valid.'

print corrected_scanid_array

tmpdir = xnatmaster.append_slash(tmpdir)
tmpuuid = uuid.uuid4()
tmpdir = tmpdir + str(tmpuuid) + '/'
if not xnatmaster.ensure_dir_exists(tmpdir) and xnatmaster.ensure_write_permissions(tmpdir):
	print "Could not create tmpdir"
	sys.exit(1)

if str(download) == '1':
	outdir = xnatmaster.append_slash(outdir)
	if not xnatmaster.ensure_dir_exists(outdir) and xnatmaster.ensure_write_permissions(outdir):
        	sys.exit(1)
'''
Done creating neccessary directories
'''

'''
BET specific Validation on input args
'''

if fourD=='0' or fourD.lower()=='no' or fourD.lower()=='false':
	fourD=False
elif fourD=='1' or fourD.lower()=='yes' or fourD.lower()=='true':
	fourD=True
else:
	fourD=False

if float(frac) < 0 or float(frac) > 1:
	print "Invalid frac value. Must be between 0 and 1."
	sys.exit(1)

for i in corrected_scanid_array:
	print "Now dealing with scanid: " + str(i) + '.'
	newtmpdir = tmpdir + str(i) + '/'
#	newoutdir = outdir + str(i) + '/'
	newlogdir = newtmpdir + 'logs/'
#	if not xnatmaster.ensure_dir_exists(newoutdir) and xnatmaster.ensure_write_permissions(newoutdir):
#               sys.exit(1)
	if not xnatmaster.ensure_dir_exists(newtmpdir) and xnatmaster.ensure_write_permissions(newtmpdir):
        	sys.exit(1)
	if not xnatmaster.ensure_dir_exists(newlogdir) and xnatmaster.ensure_write_permissions(newlogdir):
        	sys.exit(1)
	tstamp = xnatmaster.do_tstamp()
	logpath = newlogdir + str(i) + str(version) + str(tstamp) + '.log'
	otherparams = '-upload ' + str(upload) + ' -download ' + str(download) + ' -outdir ' + str(outdir) + ' -tmpdir ' + str(tmpdir) + ' -scantype ' + str(scantype) + ' -sequence_id ' + str(sid) + \
 	' -seqname ' + str(sn) + ' -configfile ' + str(configfile) 
	xnatmaster.print_all_settings('bet.py',version, i, tstamp, otherparams , logpath)
	matched_sequences = xnatmaster.find_matched_sequences(i,scantype,sid,sn,central)
	print matched_sequences
	for line in matched_sequences:
		try:
			subj_id = line.get('subject_id')
                        seqname = line.get('qlux_qluxname')
                        sessid = line.get('session_id')
                        proj_name = line.get('project')
                        scandate = line.get('date')
                        seq_id = line.get('imagescan_id')
                        imgorient = line.get('mr_imageorientationpatient')
                        formname = line.get('mr_seriesdescription')
                        if formname == 'MoCoSeries':
				formname = 'ep2d_se_pcasl_PHC_1200ms_moco'
#NewDir str begin
			formname = formname.replace("(","_")
                        formname = formname.replace(")","_")
                        formname = formname.replace(" ","_")
                        nonzeroi = str(i).lstrip('0')
                        nonzerosubid = str(subj_id).lstrip('0')
                        newoutdir = outdir + str(nonzerosubid) + '_' + str(nonzeroi) + '/' + str(seq_id) + '_' + str(seqname)+'/bet/'
			if not xnatmaster.ensure_dir_exists(newoutdir) and xnatmaster.ensure_write_permissions(newoutdir) and not xnatmaster.ensure_dir_exists(newtmpdir) and xnatmaster.ensure_write_permissions(newtmpdir):
                                sys.exit(1)
##New dir str end
			print "Form: " + str(formname);
			xnatmaster.add_to_log(logpath, "Processing sequence: " + seqname + ":" + str(seq_id))
        		global prov_list
			prov_list = []
        		betfound = 0
			niftifound = 0
			donewithsequence = 0
			niftifound = xnatmaster.existing_nifti(i,seq_id,central)
			if niftifound < 1:
				print "Could not find nifti for this scan. Please run dicoms2nifti before this script."
				sys.exit(1)
        		if findexisting == '1':
               		 	xnatmaster.add_to_log(logpath, "Checking for existing BET: " + seq_id)
               			betfound = xnatmaster.existing_bet(i,seq_id,central)
                		if betfound > 0:
                        		if download == '1':
                                		xnatmaster.get_bet(i, seq_id, newoutdir, central, proj_name, subj_id)
                         	       		xnatmaster.add_to_log(logpath, "Downloaded existing bet to : " + newoutdir + " Done with this sequence.")
						donewithsequence=1
					if upload == '1':
						donewithsequence=1
				else:
					xnatmaster.add_to_log(logpath, "No existing BET: " + seq_id)
					if not xnatmaster.ensure_dir_exists(tmpdir+'NIFTI') and xnatmaster.ensure_write_permissions(tmpdir+'NIFTI'):
                                        	sys.exit(0)
	                                niftidict = xnatmaster.get_nifti(i, seq_id, tmpdir+'NIFTI/', central, proj_name, subj_id)
					print niftidict
        	                        from_seq = niftidict['fromname']
               		                starting_nifti = niftidict['niftipath']
                        	        print "Nifti to work from is in: " + str(starting_nifti)
                        	        result = do_bet(starting_nifti,frac,fourD,logpath,tmpdir,prov_list)
                        	        maskfile = result+'_mask.nii.gz'
                        	        result = result+'.nii.gz'
                            		print prov_list
                          	        print "Resulting Nifti is at: " + result
                    	                if download == '1':
                            	                shutil.copyfile(result,newoutdir+result.split('/')[-1])
                                   	        shutil.copyfile(maskfile,newoutdir+maskfile.split('/')[-1])
                                        	shutil.copyfile(logpath,newoutdir+logpath.split('/')[-1])
        	                                print "Downloaded nifti to: " + newoutdir+result.split('/')[-1]
                	                if upload == '1':
                        	                xnatmaster.add_to_log(logpath,"Now saving into XNAT.")
                	                #Do upload here
                        	                thetype="bbl:bet"
                                	        assname=str(sessid) + '_' + str(formname) + '_BET_SEQ0' + str(seq_id)  + '_RUN01'
                                                assname=assname.replace(".","_")
                        			assname=assname.replace("-","_")
						myproject=central.select('/projects/'+proj_name)
                     	                        assessor=myproject.subject(subj_id).experiment(sessid).assessor(assname)
                             	                if assessor.exists():
                                     	              print "Found original run..."
                                           	      assname=xnatmaster.get_new_assessor(sessid,subj_id,formname,seq_id,proj_name,central)
                                                      myproject=central.select('/projects/'+proj_name)
                                                      assessor=myproject.subject(subj_id).experiment(sessid).assessor(assname)
                                        	assessor.create(**{'assessors':thetype,'xsi:type':thetype,thetype+'/date':str(xnatmaster.get_today()),thetype+'/imageScan_ID':str(seq_id),thetype+'/validationStatus':'unvalidated',thetype+'/status':'completed',thetype+'/source_id':str(from_seq),thetype+'/id':str(assname),thetype+'/SequenceName':formname,thetype+'/PipelineDataTypeVersion':'1.0',thetype+'/PipelineScriptVersion':'2.0'});
                                    	        xnatmaster.extract_provenance(assessor,prov_list)
               	 	                        assessor.out_resource('LOG').file(str(sessid) + '_' + formname + '_SEQ0' + seq_id + '.log').put(logpath)
                         	                assessor.out_resource('BET').file(str(sessid) + '_' + formname + '_BET_SEQ0' + seq_id + '.nii.gz').put(result)
                                 	        assessor.out_resource('BETMASK').file(str(sessid) + '_' + formname + '_BETMASK_SEQ0' + seq_id + '_mask.nii.gz').put(maskfile)
                           	                assessor.out_resource('QAIMAGE').file('1.png').put(tmpdir+'/1.png')
                                   	        assessor.out_resource('QAIMAGE').file('2.png').put(tmpdir+'/2.png')
                              	                assessor.out_resource('QAIMAGE').file('3.png').put(tmpdir+'/3.png')
                                      	 	assessor.out_resource('QAIMAGE').file('4.png').put(tmpdir+'/4.png')
                             	                assessor.out_resource('QAIMAGE').file('5.png').put(tmpdir+'/5.png')
                                     	        assessor.out_resource('QAIMAGE').file('6.png').put(tmpdir+'/6.png')
                                                assessor.out_resource('QAIMAGE').file('7.png').put(tmpdir+'/7.png')
                                        	assessor.out_resource('QAIMAGE').file('8.png').put(tmpdir+'/8.png')
                                        	assessor.out_resource('QAIMAGE').file('9.png').put(tmpdir+'/9.png')
			if findexisting == '0' and donewithsequence == 0 :		
                        	if betfound > 0:
					xnatmaster.add_to_log(logpath, "Forcing the creation of a new BET: " + seq_id)
				else:
					xnatmaster.add_to_log(logpath, "Creating new BET: " + seq_id)
				if not xnatmaster.ensure_dir_exists(tmpdir+'NIFTI') and xnatmaster.ensure_write_permissions(tmpdir+'NIFTI'):
        	                	sys.exit(0)
				niftidict = xnatmaster.get_nifti(i, seq_id, tmpdir+'NIFTI/', central, proj_name, subj_id)
				from_seq = niftidict['fromname']
				starting_nifti = niftidict['niftipath']			
				print "Nifti to work from is in: " + str(starting_nifti)
				result = do_bet(starting_nifti,frac,fourD,logpath,tmpdir,prov_list)	
				maskfile = result+'_mask.nii.gz'
				result = result+'.nii.gz'
				print prov_list
				print "Resulting Nifti is at: " + result
				if download == '1':
					shutil.copyfile(result,newoutdir+result.split('/')[-1])
					shutil.copyfile(maskfile,newoutdir+maskfile.split('/')[-1])
					shutil.copyfile(logpath,newoutdir+logpath.split('/')[-1])
					print "Downloaded nifti to: " + newoutdir+result.split('/')[-1]
				if upload == '1':
					xnatmaster.add_to_log(logpath,"Now saving into XNAT.")  
                                #Do upload here
                                	thetype="bbl:bet"
                                	assname=str(sessid) + '_' + str(formname) + '_BET_SEQ0' + str(seq_id)  + '_RUN01'
					assname=assname.replace(".","_")
                        		assname=assname.replace("-","_")
                                	myproject=central.select('/projects/'+proj_name)
                                	assessor=myproject.subject(subj_id).experiment(sessid).assessor(assname)
                                	if assessor.exists():
                                       		print "Found original run..."
                                        	assname=xnatmaster.get_new_assessor(sessid,subj_id,formname,seq_id,proj_name,central)
                                        	myproject=central.select('/projects/'+proj_name)
                                        	assessor=myproject.subject(subj_id).experiment(sessid).assessor(assname) 
                                	assessor.create(**{'assessors':thetype,'xsi:type':thetype,thetype+'/date':str(xnatmaster.get_today()),thetype+'/imageScan_ID':str(seq_id),thetype+'/validationStatus':'unvalidated',thetype+'/status':'completed',thetype+'/source_id':str(from_seq),thetype+'/id':str(assname),thetype+'/SequenceName':formname,thetype+'/PipelineDataTypeVersion':'1.0',thetype+'/PipelineScriptVersion':'2.0'});
					xnatmaster.extract_provenance(assessor,prov_list)
                                	assessor.out_resource('LOG').file(str(sessid) + '_' + formname + '_SEQ0' + seq_id + '.log').put(logpath)
                                	assessor.out_resource('BET').file(str(sessid) + '_' + formname + '_BET_SEQ0' + seq_id + '.nii.gz').put(result)
					assessor.out_resource('BETMASK').file(str(sessid) + '_' + formname + '_BETMASK_SEQ0' + seq_id + '_mask.nii.gz').put(maskfile)
					assessor.out_resource('QAIMAGE').file('1.png').put(tmpdir+'/1.png')
                                        assessor.out_resource('QAIMAGE').file('2.png').put(tmpdir+'/2.png')
                                        assessor.out_resource('QAIMAGE').file('3.png').put(tmpdir+'/3.png')
                                        assessor.out_resource('QAIMAGE').file('4.png').put(tmpdir+'/4.png')
                                        assessor.out_resource('QAIMAGE').file('5.png').put(tmpdir+'/5.png')
                                        assessor.out_resource('QAIMAGE').file('6.png').put(tmpdir+'/6.png')
                                        assessor.out_resource('QAIMAGE').file('7.png').put(tmpdir+'/7.png')
                                        assessor.out_resource('QAIMAGE').file('8.png').put(tmpdir+'/8.png')
                                        assessor.out_resource('QAIMAGE').file('9.png').put(tmpdir+'/9.png')
		except IndexError, e:
                        xnatmaster.add_to_log(logpath,e)
