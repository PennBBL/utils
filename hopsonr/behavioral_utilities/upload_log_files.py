#!/import/monstrum/Applications/epd-7.1/bin/python
import sys
from pyxnat import Interface
import argparse

###parse arguments###
#####################
parser = argparse.ArgumentParser(description='Upload a logfile to xnat');

group = parser.add_argument_group('Required')
group.add_argument('-scanid', action="store", dest='scanid', required=True, help='scanid of the logfile to upload')
group.add_argument('-bblid', action="store", dest='bblid', required=True, help='bblid of the logfile to upload')
group.add_argument('-dotest', action="store", dest='dotest', required=True, help='date of test, YYYY-MM-DD')
group.add_argument('-logfile', action="store", dest='logfile', required=True, help='full path to logfile')
group.add_argument('-test', action="store", dest='test', required=True, help='name of scoring code')
group.add_argument('-siteid', action="store", dest='siteid', required=True, help='study presentation name, i.e. 22q_pres')
group.add_argument('-study_xnat_name', action="store", dest='study_xnat_name', required=True, help='name of study in xnat')
group.add_argument('-comments', action="store", dest='comments', required=True, help='comments by uploader')
group.add_argument('-configfile', action="store", dest='configfile', required=True, help='configfile of uploader')

inputArguments = parser.parse_args()
scanid = inputArguments.scanid
bblid = inputArguments.bblid
dotest = inputArguments.dotest
logfile = inputArguments.logfile
test = inputArguments.test
siteid = inputArguments.siteid
study_xnat_name = inputArguments.study_xnat_name
comments = inputArguments.comments
configfile = inputArguments.configfile

central = Interface(config=configfile)

#imagescan_id='1234'
#logfile='/import/monstrum/Users/hopsonr/07001-Jolo_1.00.log'

###define functions###
######################

#get shortened lowercase filename from path
def short(filename):
	index=filename.rfind("/")+1
	last=len(filename)
	filename=filename[index:last]
	filename=filename.lower()
	return filename

#upload the actual logfile
def create_presentationScanData(logfile,imagescan_id,mysession):
		
		scan = mysession.scan(imagescan_id);
		filename =logfile;
		shortfilename='.log'
		#shortfilename= short(session['filename'])[:-4];
		#uid,subject_id,session_id=find_subject_id_session(session)
		#imagescan_id=get_unique(unique_keys,session_id)
		
		scan.create(**{'scans':'bbl:presentationScanData','bbl:presentationScanData/type':short(filename)})
		print scan.exists();
		print filename
		try:
			scan.resource('PRESENTATION').file(short(filename)).put(filename,content='PRESENTATION',format='PRESENTATION',tags='PRESENTATION');
			print "uploaded press file for ",short(filename)
		except:
			print "failed for ", scan; 
		print "add pres scan for:",mysession.attrs.get('ID'),imagescan_id
		#uuid=get_uid();

		return True;

#create the associated assesors
def create_presentation(imagescan_id,mysession,test,dotest,logfile,scanid,bblid,siteid,comments):
		id=mysession.attrs.get('ID')+"_PRESENTATION_"+imagescan_id;
		assessor = mysession.assessor(id);
		assessor.create(**{'bbl:presentation/ID':id,'assessors':'bbl:presentation','xsi:type':'bbl:presentation','bbl:presentation/imageScan_ID':imagescan_id,'bbl:presentation/description':'uploaded_via_script','bbl:presentation/form':'session_test'})		
		
		assessor.attrs.set('bbl:presentation/note','test')
		assessor.attrs.set('bbl:presentation/fields/field[name=test]/field',str(test))	
		assessor.attrs.set('bbl:presentation/fields/field[name=tests]/field',str(test))
		assessor.attrs.set('bbl:presentation/fields/field[name=deleted_flag]/field','None');
		assessor.attrs.set('bbl:presentation/fields/field[name=dotest]/field',str(dotest));
		assessor.attrs.set('bbl:presentation/fields/field[name=filename]/field',str(logfile));		
		assessor.attrs.set('bbl:presentation/fields/field[name=localid]/field',str(scanid));
		assessor.attrs.set('bbl:presentation/fields/field[name=subid]/field',str(bblid));
		assessor.attrs.set('bbl:presentation/fields/field[name=bblid]/field',str(bblid));
		assessor.attrs.set('bbl:presentation/fields/field[name=siteid]/field',str(siteid));
		assessor.attrs.set('bbl:presentation/fields/field[name=admin_comments]/field',str(comments));		
		assessor.attrs.set('bbl:presentation/date',mysession.attrs.get('date'));
		assessor.attrs.set('bbl:presentation/comments','Uploaded via upload_log_flies.py');
		print "creating assessor",assessor.exists();
		print id

###get data from xnat###
########################
fullname='/projects/'+str(study_xnat_name)
myproject=central.select(fullname)
mysubject=myproject.subject(bblid)
mysession=mysubject.experiment(scanid)

exists=mysession.exists()

###get the names of all scans already uploaded###
#################################################
types=[]
imagescan_id=0
allscans=mysession.scans()
for scan in allscans:
	types.append(scan.attrs.get('type'))
	x=short(scan.attrs.get('UIR'))
	if int(x) > int(imagescan_id):
		imagescan_id=x
imagescan_id=str(int(imagescan_id)+10)

#check if logfile of that name already exists for that participant, and if not, upload and create assessors
if mysession.exists():
	if short(logfile) in types:
		print 'Logfile of name',short(logfile),'already exists for participant',scanid
	else:
		create_presentationScanData(logfile,imagescan_id,mysession)
		create_presentation(imagescan_id,mysession,test,dotest,logfile,scanid,bblid,siteid,comments)
else:
	print 'Session with bblid',bblid,'and scanid',scanid,'does not exist.'
