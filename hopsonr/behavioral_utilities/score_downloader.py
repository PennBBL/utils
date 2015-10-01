#!/import/monstrum/Applications/epd-7.1/bin/python
import argparse
import sys
import os
from pyxnat import Interface
import gzip
import fnmatch
import shutil
import getpass
#By Chadtj
#xnat_downloader.py v1.0 - Initial

downloadable_types=[]
downloadable_types.append('bbl:scores')

def get_sequence_ids(scanid):
        constraints = [('bbl:Sequence/imageSession_ID', '=', str(scanid)),'AND',('bbl:Sequence/QLUX_MATCHED','=','1'),'AND']
        seqs = central.select('bbl:Sequence',['bbl:Sequence/QLUX_QLUXNAME','bbl:Sequence/IMAGESCAN_ID']).where(constraints);
        seq_dict = {}
        for line in seqs:
                seqname = line.get('qlux_qluxname')
                seq_id = line.get('imagescan_id')
                seq_dict[seq_id]=seqname
        return seq_dict

def fix_download_dir(outdir, download):
        if download == '1':
                if not str(outdir).endswith('/'):
                        return str(outdir) + '/'        
                else:
                        return str(outdir)

def ensure_dir_exists(dir):
        if not os.path.exists(dir):
                try:
                        os.makedirs(dir)
                        return 1
                except OSError:
                        sys.exit(1)
        else:
                return 1
        
def ensure_write_permissions(dir):
        if os.access(dir, os.W_OK):
                return 1
        else:
                return 0

def check_run_by_pipeline():
        if  os.getenv('HOSTNAME') == 'xnat.uphs.upenn.edu' and getpass.getuser()=='xnat':       
                print "Pipeline mode"
                return 1
        else:
                print "Non-pipeline mode"
                return 0


def check_for_valid_scanid(scanid,central):
        constraints = [('bbl:Sequence/imageSession_ID', '=', str(scanid)),'AND']
        seqs = central.select('bbl:Sequence',['bbl:Sequence/SUBJECT_ID', 'bbl:Sequence/imageSession_ID', 'bbl:Sequence/QLUX_MATCHED', 'bbl:Sequence/date', 'bbl:Sequence/PROTOCOL', 'bbl:Sequence/PROJECT']).where(constraints);
        subj_id = 0
        for line in seqs:
                try:
                        subj_id = line.get('subject_id')
                        if subj_id > 0:
                                print "Found subjectid of: " + subj_id
                                return subj_id
                        else:
                                return 0
                except IndexError, e:
                        pass

def add_zeros_to_scanid(scanid,central):
        if check_for_valid_scanid(scanid,central):
                return scanid
        elif check_for_valid_scanid("0"+scanid,central):
                scanid="0"+scanid
                return scanid
        elif check_for_valid_scanid("00"+scanid,central):
                scanid="00"+scanid
                return scanid
        else:
                print "Couldn't find Session with scanid: " + scanid
                sys.exit(1)

def setup_xnat_connection(configfile, run_by_pipeline):
        if configfile=='X' and run_by_pipeline == 1:
                configfile='/import/monstrum/Users/xnat/.xnat-localhost.cfg'
                central = Interface(config=configfile)
                return central
        elif os.getenv('HOSTNAME') == 'xnat.uphs.upenn.edu' and run_by_pipeline == 0:
                homedir=os.getenv("HOME")
                if os.path.isfile(homedir+'/.xnat-localhost.cfg'):
                        print "Found ~/.xnat-localhost.cfg on xnat"
                        central = Interface(config=homedir+'/.xnat-localhost.cfg')
                        return central
                else:
                        print "Login using your XNAT username and password, this will be saved in a configuration file for next time."
                        try:
                                central = Interface(config=configfile)
                        except AttributeError:
                                central = Interface(server='http://xnat.uphs.upenn.edu:8080/xnat')
                                central.save_config(homedir+'/.xnat-localhost.cfg')
                        return central
        elif configfile=='X' and run_by_pipeline == 0:
                homedir=os.getenv("HOME")
                if os.path.isfile(homedir+'/.xnat.cfg'):
                        print "Found ~/.xnat.cfg"
                        central = Interface(config=homedir+'/.xnat.cfg')
                        return central
                else:
                        print "Login using your XNAT username and password, this will be saved in a configuration file for next time."
                        try:
                                central = Interface(config=configfile)
                        except AttributeError:
                                central = Interface(server='https://xnat.uphs.upenn.edu/xnat')
                                central.save_config(homedir+'/.xnat.cfg')
                        return central
        else:
                try:
                        central = Interface(config=configfile)
                except AttributeError, e:
                        print "Error with the configfile you specified: " + str(e)
                        sys.exit(1)
        return central

def get_session_details(scanid):
       tmp_table = central.select('xnat:mrSessionData',['xnat:mrSessionData/SESSION_ID','xnat:mrSessionData/PROJECT','xnat:mrSessionData/SUBJECT_ID','xnat:mrSessionData/INSERT_USER','xnat:mrSessionData/DATE']).where([('xnat:mrSessionData/SESSION_ID','=',str(scanid)),'AND']) 
       return tmp_table

def return_qluxname(central,scanid,seqnum):
        sequence = central.select('bbl:Sequence',['bbl:Sequence/QLUX_QLUXNAME']).where([('bbl:Sequence/imageSession_ID','=',str(scanid)),'AND',('bbl:Sequence/IMAGESCAN_ID','=',str(seqnum)),'AND'])
        for line in sequence:
                return line.get('qlux_qluxname')

def return_mprageseqnum(central,scanid):
        sequence = central.select('bbl:Sequence',['bbl:Sequence/IMAGESCAN_ID']).where([('bbl:Sequence/imageSession_ID','=',str(scanid)),'AND',('bbl:Sequence/QLUX_QLUXNAME','ILIKE','%mprage%'),'AND',('bbl:Sequence/QLUX_MATCHED','=','1'),'AND',('bbl:Sequence/QLUX_QLUXNAME','NOT LIKE','%nav%'),'AND'])
        for line in sequence:
		return line.get('imagescan_id')

def process_basic_assessor(assessors,type,scanid,outdir,central,subject,project):
	print type + "\n----------"
	if type == 'bbl:nifti':
		for k in assessors:
			print k
			if k.get('expt_id').find('moco') < 0:		
				expt_id = k.get('expt_id')
				seqnum = k.get('bbl_col_niftiimagescan_id')
				seqname =  return_qluxname(central,scanid,seqnum)
				ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
				ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/nifti')
				path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
               		        F = central.select(path)
				for line in F:
                        	      if line._uri.find('.nii.gz')> -1 or line._uri.find('bval')> -1 or line._uri.find('bvec')> -1:
                                	     if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/nifti/'+str(line._urn)):
				     		   line.get(outdir+str(seqnum)+'_'+str(seqname)+'/nifti/'+str(line._urn))
                                     	 	   print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/nifti/'
				    	     else:
						   print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/nifti/ ...Skipping '
				write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/nifti/',str(expt_id))
	elif type == 'bbl:perf':
                for k in assessors:
                        print k
                        expt_id = k.get('expt_id')
                        seqnum = k.get('bbl_col_perfimagescan_id')
                        #if seqnum == None:
                        #        seqnum = return_mprageseqnum(central,scanid)
                        seqname =  return_qluxname(central,scanid,seqnum)
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/quantification')
                        path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                        F = central.select(path)
                        for line in F:
                              if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/quantification/'+str(line._urn)):
                                    line.get(outdir+str(seqnum)+'_'+str(seqname)+'/quantification/'+str(line._urn))
                                    print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/quantification/'
                              else:
                                    print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/quantification/ ...Skipping '
			write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/quantification/',str(expt_id))
	elif type == 'bbl:bet':
		for k in assessors:
			print k
                        expt_id = k.get('expt_id')
                        seqnum = k.get('bbl_col_betimagescan_id')
                        if seqnum == None:
				seqnum = return_mprageseqnum(central,scanid)
			seqname =  return_qluxname(central,scanid,seqnum)
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/bet')
                        path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                        F = central.select(path)
                        for line in F:
			      if line._uri.find('.nii.gz')> -1 or line._uri.find('png')> -1:
                                     if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/bet/'+str(line._urn)):
                                           line.get(outdir+str(seqnum)+'_'+str(seqname)+'/bet/'+str(line._urn))
                                           print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/bet/'
                                     else:
                                           print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/bet/ ...Skipping '
			write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/bet/',str(expt_id))
	elif type == 'bbl:prestats':
                for k in assessors:
                        print k
                        expt_id = k.get('expt_id')
                        seqnum = k.get('bbl_col_prestatsimagescan_id')
                        seqname =  return_qluxname(central,scanid,seqnum)
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/prestats')
                        path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                        F = central.select(path)
                        for line in F:
                               if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/prestats/'+str(line._urn)):
                                      line.get(outdir+str(seqnum)+'_'+str(seqname)+'/prestats/'+str(line._urn))
                                      print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/prestats/'
                               else:
                                      print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/prestats/ ...Skipping '
			write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/prestats/',str(expt_id))
	elif type == 'bbl:first':
                for k in assessors:
                        print k
                        expt_id = k.get('expt_id')
                        seqnum = k.get('bbl_col_firstimagescan_id')
                        seqname =  return_qluxname(central,scanid,seqnum)
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/first')
                        path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                        F = central.select(path)
                        for line in F:
                               if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/first/'+str(line._urn)):
                                      line.get(outdir+str(seqnum)+'_'+str(seqname)+'/first/'+str(line._urn))
                                      print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/first/'
                               else:
                                      print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/first/ ...Skipping '
			write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/first/',str(expt_id))
	elif type == 'bbl:stats':
                for k in assessors:
                        print k
                        expt_id = k.get('expt_id')
                        seqnum = k.get('bbl_col_statsimagescan_id')
                        seqname =  return_qluxname(central,scanid,seqnum)
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/stats')
                        ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat')
			ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/mc')
			ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/custom_timing_files')
			path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                        F = central.select(path)
                        for line in F:
				if line._urn.find("nii.gz") < 0 or line._urn.find("example_func.nii.gz") > -1 or line._urn.find("filtered_func_data.nii.gz") > -1 \
				or line._urn.find("mean_func.nii.gz") > -1 or line._urn.find("dof") > -1 or line._urn.find("cmlogfile") > -1 or line._urn.find("ratios") > -1 or \
				line._urn.find("smoothness") > -1 or line._urn.find("probs") > -1 or line._urn.find("logfile") > -1 or line._urn.find("mask.nii.gz") > -1:
					print str(line) + " belongs in top level dir"  
	                        	if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/'+str(line._urn)):
                                       		line.get(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/'+str(line._urn))
                                       		print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/'
                                	else:
                                       		print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/ ...Skipping '
				else:
					print str(line) + " belongs in stats dir"
					ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/stats/')
					if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/stats/'+str(line._urn)):
                                                line.get(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/stats/'+str(line._urn))
                                                print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/stats/'
                                        else:
                                                print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/stats/ ...Skipping '	
			topleveldir=str(outdir)+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/'
			try:
				process_mc_dir(seqnum,scanid,topleveldir,central,subject,project)			
				process_reg_dir(seqnum,scanid,topleveldir,central,subject,project)
			except IOError, e:
				print str(e) + " couldnt do this. moving on"
			process_evs_dir(topleveldir,topleveldir+'custom_timing_files/')
			process_example_func(seqnum,scanid,topleveldir,central,subject,project)
			try:
				process_highres_and_mni(seqnum,scanid,topleveldir,central,subject,project)
			except IOError, e:
				print str(e) + " Couldnt move that file"
			write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/stats/'+str(expt_id)+'.feat/',str(expt_id))

def process_highres_and_mni(seqnum,scanid,outdir,central,subject,project):
	shutil.copyfile("/import/monstrum/Applications/fsl_4.1.6_64bit/data/standard/MNI152_T1_2mm_brain.nii.gz",outdir+'reg/standard.nii.gz')
	Z = central.select('bbl:biascorrection',['bbl:biascorrection/EXPT_ID']).where([('bbl:biascorrection/SESSION_ID','=',str(scanid)),'AND'])
        expt_id = ""
	for line in Z:
                expt_id = line.get('expt_id')
                print line
	seqnum = return_mprageseqnum(central,scanid)
        seqname =  return_qluxname(central,scanid,seqnum)
        if seqname == None:
                print "No seqname for bias"
                sys.exit(0)
        if seqnum == None:
                print "No seqnum for bias"
                sys.exit(0)
        else:
                print seqnum
        path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
        F = central.select(path)
        for line in F:
		print "Here is the bias correction file: " + str(line)
                if line._urn.find("correctedbrain") >-1:
			print line
                	if not os.path.isfile(outdir+'reg/'+str(line._urn)):
                        	line.get(line.get(outdir+'reg/'+str(line._urn)))
                		print "Downloaded " +line._urn + " to "+ str(outdir)+'reg'
				shutil.copyfile(outdir+'reg/'+str(line._urn),outdir+'reg/highres.nii.gz')
			else:
				print line._urn + " Already exists in : " + str(outdir)+'reg ...Skipping '

def process_example_func(seqnum,scanid,outdir,central,subject,project):
        Z = central.select('bbl:prestats',['bbl:prestats/EXPT_ID']).where([('bbl:prestats/imageScan_ID','=',str(seqnum)),'AND',('bbl:prestats/imageSession_ID','=',str(scanid)),'AND'])
        expt_id = ""
	for line in Z:
                expt_id = line.get('expt_id')
                print line
        if expt_id != "":
		path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
	        F = central.select(path)
	        #ensure_dir_exists(outdir+'stats/reg')
	        for line in F:
        	        if line._urn.find("example_func.nii.gz") >-1:
        	                if not os.path.isfile(outdir+'reg/'+str(line._urn)):
        	                        try:
						line.get(outdir+'reg/'+str(line._urn))
        	                       		print "Downloaded " +line._urn + " to "+ str(outdir)+'reg'
                	        	except IOError, e:
						print str(e) + " Moving on. This wasn't run.!"	
				else:
                        	       print line._urn + " Already exists in : " + str(outdir)+'reg ...Skipping '

def process_evs_dir(topleveldir,dest):
	for filename in os.listdir(topleveldir):	
		if fnmatch.fnmatch(filename, 'ev*txt'):
			shutil.copyfile(topleveldir+filename,dest+filename)

def process_mc_dir(seqnum,scanid,outdir,central,subject,project):
        Z = central.select('bbl:prestats',['bbl:prestats/EXPT_ID']).where([('bbl:prestats/imageScan_ID','=',str(seqnum)),'AND',('bbl:prestats/imageSession_ID','=',str(scanid)),'AND'])
	expt_id = ""
	for line in Z:
		expt_id = line.get('expt_id')
		print line
	if expt_id != "":
		path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
	        F = central.select(path)
		ensure_dir_exists(outdir+'mc/')
	        for line in F:
	                if line._urn.find("prefiltered_func_data_mcf.par") >-1:
		                if not os.path.isfile(outdir+'mc/'+str(line._urn)):
        		               line.get(outdir+'mc/'+str(line._urn))
                		       print "Downloaded " +line._urn + " to "+ str(outdir)+'mc/'
       	        		else:
         		               print line._urn + " Already exists in : " + str(outdir)+'mc/ ...Skipping '
		write_expt_id(outdir+'mc/',str(expt_id))

def process_reg_dir(seqnum,scanid,outdir,central,subject,project):
        Z = central.select('bbl:registration',['bbl:registration/EXPT_ID']).where([('bbl:registration/imageScan_ID','=',str(seqnum)),'AND',('bbl:registration/imageSession_ID','=',str(scanid)),'AND'])
        expt_id = ""
	for line in Z:
                expt_id = line.get('expt_id')
                print line
        if expt_id != "":
		path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
      		F = central.select(path)
	        ensure_dir_exists(outdir+'reg/')
	        for line in F:
       		       if not os.path.isfile(outdir+'reg/'+str(line._urn)):
        	             line.get(outdir+'reg/'+str(line._urn))
                	     print "Downloaded " +line._urn + " to "+ str(outdir)+'reg'
        	       else:
                	     print line._urn + " Already exists in : " + str(outdir)+'reg ...Skipping '
		write_expt_id(outdir+'reg/',str(expt_id))

def process_bias_assessor(assessors,type,scanid,outdir,central,subject,project):
        print type + "\n----------"  
	for k in assessors:
		print k
		expt_id = k.get('expt_id')
                seqnum = return_mprageseqnum(central,scanid)
                seqname =  return_qluxname(central,scanid,seqnum)
                if seqname == None:
			print "No seqname for bias"
			sys.exit(0)
		if seqnum == None:
                        print "No seqnum for bias"
                        sys.exit(0)
		else:
			print seqnum
		ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/biascorrection')
                path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                F = central.select(path)
		for line in F:
			print line	
			if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/biascorrection/'+str(line._urn)):
                              line.get(outdir+str(seqnum)+'_'+str(seqname)+'/biascorrection/'+str(line._urn))
                              print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/biascorrection/'
                        else:
                              print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/biascorrection/ ...Skipping '
		write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/biascorrection/',str(expt_id))

def process_registration_assessor(assessors,type,scanid,outdir,central,subject,project):
        print type + "\n----------" 
	for k in assessors:
                print k
                expt_id = k.get('expt_id')
                seqnum = k.get('bbl_col_registrationimagescan_id')
                seqname =  return_qluxname(central,scanid,seqnum)
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/registration')
                path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                F = central.select(path)
                for line in F:
                        print line
			if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/registration/'+str(line._urn)):
                              line.get(outdir+str(seqnum)+'_'+str(seqname)+'/registration/'+str(line._urn))
                              print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/registration/'
                        else:
                              print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/registration/ ...Skipping '
		write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/registration/',str(expt_id))

def process_registration_assessor2(assessors,type,scanid,outdir,central,subject,project):
        print type + "\n----------"
        for k in assessors:
                print k
                expt_id = k.get('expt_id')
                #seqnum = k.get('bbl_col_registrationimagescan_id')
                seqnum = k.get('expt_id')[(k.get('expt_id').find("SEQ0"))+3:(k.get('expt_id').find("SEQ0"))+6] 
		if seqnum.find("_")>-1:
			seqnum = k.get('expt_id')[(k.get('expt_id').find("SEQ0"))+3:(k.get('expt_id').find("SEQ0"))+5]
		seqnum = int(seqnum)
		#print seqnum
		seqname =  return_qluxname(central,scanid,seqnum)
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/registration')
                path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                F = central.select(path)
                print "Path: " + str(path)
		for line in F:
                        print line
                        if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/registration/'+str(line._urn)):
                              line.get(outdir+str(seqnum)+'_'+str(seqname)+'/registration/'+str(line._urn))
                              print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/registration/'
                        else:
                              print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/registration/ ...Skipping '
		write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/registration/',str(expt_id))

def write_expt_id(indir,exptid):
	if not os.path.isfile(indir+'expt_id.txt'):
		f = open(indir+'expt_id.txt','w')
		f.write(str(exptid)+'\n')
		f.close()
		
def process_presentation_assessor(assessors,type,scanid,outdir,central,subject,project):
#
        print type + "\n----------"  
	for k in assessors:
                print k
                expt_id = k.get('expt_id')
#                seqnum = k.get('bbl_col_presentationimagescan_id')
		seqnum = k.get('imagescan_id')
                seqname =  return_qluxname(central,scanid,seqnum)
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname))
                ensure_dir_exists(outdir+str(seqnum)+'_'+str(seqname)+'/presentation')
           #     path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'

                path='/projects/'+str(project)+'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/scans/'+k.get('imagescan_id')+'/resources/PRESENTATION/files'
	        F = central.select(path)
                for line in F:
                        print line
                        if not os.path.isfile(outdir+str(seqnum)+'_'+str(seqname)+'/presentation/'+str(line._urn)):
                              line.get(outdir+str(seqnum)+'_'+str(seqname)+'/presentation/'+str(line._urn))
                              print "Downloaded " +line._urn + " to " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/presentation/'
                        else:
                              print line._urn + " Already exists in : " + str(outdir)+str(seqnum)+'_'+str(seqname)+'/presentation/ ...Skipping '
		write_expt_id(outdir+str(seqnum)+'_'+str(seqname)+'/presentation/',str(expt_id))

def process_scores_assessor(assessors,type,scanid,outdir,central,subject,project):
        print type + "\n----------"  
	for k in assessors:
                print k
                expt_id = k.get('expt_id')
                seqnum = k.get('module')
		ensure_dir_exists(outdir+'scores/')
                ensure_dir_exists(outdir+'scores/'+str(seqnum)+'/')
                path = '/projects/'+ str(project) +'/subjects/'+str(subject)+'/experiments/'+str(scanid)+'/assessors/'+str(expt_id)+'/out_resources/files'
                F = central.select(path)
                for line in F:
                        print line
                        if not os.path.isfile(outdir+'scores/'+str(seqnum)+'/'+str(line._urn)):
                              line.get(outdir+'scores/'+str(seqnum)+'/'+str(line._urn))
                              print "Downloaded " +line._urn + " to " + str(outdir)+'scores/'+str(seqnum)+'/'
                        else:
                              print line._urn + " Already exists in : " + str(outdir)+'scores/'+str(seqnum)+'/ ...Skipping '
		write_expt_id(outdir+'scores/'+str(seqnum)+'/',str(expt_id))

###Setup input args here

parser = argparse.ArgumentParser(description='Python Pipeline Download Script');
group = parser.add_argument_group('Required')
group.add_argument('-scanid', action="store", dest='scanid', required=True, help='MR Session (scan id) to download')
optgroup = parser.add_argument_group('Optional')
optgroup.add_argument('-outdir',action="store", dest='outdir', required=False, help='Path to the toplevel output directory', default='')
optgroup.add_argument('-configfile',action="store",dest='configfile',required=False, help='Enter path to your XNAT config file if desired.', default='X')
parser.add_argument('-version', action='version', version='%(prog)s 1.0')
version='_downloader_v1_0'
########

###Parse input args here

inputArguments = parser.parse_args()
scanid = inputArguments.scanid
outdir = inputArguments.outdir
configfile = inputArguments.configfile
########

run_by_pipeline = check_run_by_pipeline() ##Find out if run by XNAT

outdir = fix_download_dir(outdir,'1') ##Add a slash to outdir if neccessary

##
#### Check directories are appropriate

if outdir == '':
        print "Must specify output directory with download flag 1"
        sys.exit(1)

if not ensure_dir_exists(outdir): 
	print "Could not create outdir"
        sys.exit(1)
if not ensure_write_permissions(outdir):
	print "No write permissions to your output dir"
        sys.exit(1)

central = setup_xnat_connection(configfile,run_by_pipeline)
scanid = add_zeros_to_scanid(scanid,central)
table = get_session_details(scanid)
print scanid
for j in table:
	project = j.get('project')
	subject = j.get('subject_id')
outdir = outdir + str(subject).lstrip('0') + '_' + str(scanid).lstrip('0') + '/'
if not ensure_dir_exists(outdir): 
        print "Could not create outdir"
        sys.exit(1)
if not ensure_write_permissions(outdir):
        print "No write permissions to your output dir"
        sys.exit(1)
#downloadable_types_tmp=[]
#downloadable_types_tmp.append('bbl:registration')
#downloadable_types_tmp.append('bbl:bet')
#downloadable_types_tmp.append('bbl:registration')
#for i in downloadable_types_tmp:
for i in downloadable_types:
	if i == 'bbl:perf' or i == 'bbl:first' or i == 'bbl:bet' or i == 'bbl:prestats' or i == 'bbl:nifti' or i == 'bbl:stats': 
		try:
			print central.inspect.datatypes(str(i))
			assessors = central.select(str(i),[str(i)+'/EXPT_ID',str(i)+'/imageScan_ID',str(i)+'/SequenceName']).where([(str(i)+'/SESSION_ID','=',str(scanid)),'AND'])
			process_basic_assessor(assessors,i,scanid,outdir,central,subject,project)
		except IndexError:
			print 'Error with perfusion, first, bet, prestats, nifti, or stats'
			sys.exit(0) 
		
	#	process_basic_assessor(assessors,i,scanid,outdir,central,subject,project)
	
	if i == 'bbl:biascorrection':
		try:
			print central.inspect.datatypes('bbl:biascorrection')
         	        assessors = central.select('bbl:biascorrection',['bbl:biascorrection/EXPT_ID']).where([('bbl:biascorrection/SESSION_ID','=',str(scanid)),'AND'])
	        	
			process_bias_assessor(assessors,i,scanid,outdir,central,subject,project)
		except IndexError, e:
                        print 'Error with Bias Correction '+str(e)
		        sys.exit(0) 
		
		#process_bias_assessor(assessors,i,scanid,outdir,central,subject,project)
 
	if i == 'bbl:registration':
                try:  
			print central.inspect.datatypes('bbl:registration')
                        assessors = central.select('bbl:registration',['bbl:registration/EXPT_ID','bbl:registration/BBL_COL_REGISTRATIONIMAGESCAN_ID', \
			 	'bbl:registration/BBL_COL_REGISTRATIONSEQUENCENAME']).where([('bbl:registration/SESSION_ID','=',str(scanid)),'AND'])
                        #assessors = central.select(str(i),[str(i)+'/EXPT_ID',str(i)+'/imageScan_ID',str(i)+'/SequenceName']).where([(str(i)+'/SESSION_ID','=',str(scanid)),'AND'])
		#	assessors = central.select('bbl:registration',['bbl:registration/EXPT_ID', 'bbl:registration/SEQUENCENAME', 'bbl:registration/IMAGESCAN_ID' \
		#		]).where([('bbl:registration/SESSION_ID','=',str(scanid)),'AND'])
                #	print assessors
			process_registration_assessor(assessors,i,scanid,outdir,central,subject,project)
		except IndexError, e:
                        print 'Error with Registration '+str(e)
                        assessors = central.select('bbl:registration',['bbl:registration/EXPT_ID']).where([('bbl:registration/SESSION_ID','=',str(scanid)),'AND'])
			process_registration_assessor2(assessors,i,scanid,outdir,central,subject,project)
			#sys.exit(0)

        	#process_registration_assessor(assessors,i,scanid,outdir,central,subject,project)

	if i == 'bbl:presentation':
                try:
                        assessors = central.select('bbl:presentation',['bbl:presentation/EXPT_ID','bbl:presentation/IMAGESCAN_ID'] \
                                ).where([('bbl:presentation/SESSION_ID','=',str(scanid)),'AND'])
                        process_presentation_assessor(assessors,i,scanid,outdir,central,subject,project)
                except IndexError:
                        print 'Error with Presentation'
                        sys.exit(0)

                #process_presentation_assessor(assessors,i,scanid,outdir,central,subject,project)#process_presentation_assessor(assessors,i,scanid,outdir,central,subject,project)		
        
	if i == 'bbl:scores':
                try:
                        assessors = central.select('bbl:scores',['bbl:scores/EXPT_ID','bbl:scores/IMAGESCAN_ID','bbl:scores/MODULE'] \
				).where([('bbl:scores/SESSION_ID','=',str(scanid)),'AND'])
			process_scores_assessor(assessors,i,scanid,outdir,central,subject,project)
                except IndexError:
                        print 'Error with Scores'
                        sys.exit(0)
		
	#	process_scores_assessor(assessors,i,scanid,outdir,central,subject,project)
