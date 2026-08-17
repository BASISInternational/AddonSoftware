[[ADX_INSTALLWIZ.AREC]]
rem --- Initialize new record
	callpoint!.setColumnData("ADX_INSTALLWIZ.INSTALL_TYPE","D")
	callpoint!.setColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL","1")
	callpoint!.setColumnEnabled("ADX_INSTALLWIZ.NEW_INSTALL_LOC",0)

[[ADX_INSTALLWIZ.ASHO]]
rem --- Don't allow running the utility if not launched from Addon demo system under Basis download location
	ddm_systems=fnget_dev("DDM_SYSTEMS")
	dim ddm_systems$:fnget_tpl$("DDM_SYSTEMS")
	readrecord(ddm_systems,key=pad("ADDON",16," "),knum="SYSTEM_ID",err=*next)ddm_systems$
	aonDir!=new java.io.File(ddm_systems.mount_dir$)
	aonDir$=aonDir!.getCanonicalPath()

	demoDir!=new java.io.File(System.getProperty("basis.BBjHome")+"/apps/aon")
	demoDir$=demoDir!.getCanonicalPath()
 	
	if aonDir$<>demoDir$ then
		msg_id$="AD_MUST_BE_DEMO_SYS"
		dim msg_tokens$[1]
		msg_tokens$[1]=demoDir$
		gosub disp_message
		callpoint!.setStatus("EXIT")
		break
	endif

rem --- The Install Wizard must be run directly on the server where the Addon demo is installed.
	if num(info(3,6))<>0 and num(info(3,6))<>1 then
		msg_id$="AD_NOT_ON_SERVER"
		dim msg_tokens$[1]
		msg_tokens$[1]=demoDir$
		gosub disp_message
		callpoint!.setStatus("EXIT")
		break
	endif

[[ADX_INSTALLWIZ.ASVA]]
rem --- Update checkboxes (work around for Barista bug 5616)
	help! = callpoint!.getControl("ADX_INSTALLWIZ.APP_HELP")
	callpoint!.setColumnData("ADX_INSTALLWIZ.APP_HELP",str(help!.isSelected()))
	verNeutral! = callpoint!.getControl("ADX_INSTALLWIZ.VERSION_NEUTRAL")
	callpoint!.setColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL",str(verNeutral!.isSelected()))

rem --- Validate Repository
	gitAuthID$=cvs(callpoint!.getColumnData("ADX_INSTALLWIZ.GIT_AUTH_ID"),3)
	gosub validate_git_auth_id

    rem --- Validate this is an officicial (tagged) release, not an RC
	gitAuthID$=cvs(callpoint!.getColumnData("ADX_INSTALLWIZ.GIT_AUTH_ID"),3)
	gosub validate_release_tag

rem --- Validate directory
	if num(callpoint!.getColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL")) then
		rem --- Validate base directory for installation
		new_loc$ = callpoint!.getColumnData("ADX_INSTALLWIZ.BASE_DIR")
		gosub validate_base_dir

		callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR", new_loc$)
		if abort then break
	else
		rem --- Validate directory for aon new install location
		new_loc$ = callpoint!.getColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC")
		gosub validate_aon_dir

		callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC", new_loc$)
		if abort then break
	endif

rem -- Get firm if not using Quick Copy

	firm_id$=callpoint!.getColumnData("ADX_INSTALLWIZ.NEW_FIRM_ID")
	install_type$=callpoint!.getColumnData("ADX_INSTALLWIZ.INSTALL_TYPE")
	if firm_id$="" and install_type$<>"Q" then
		dim dflt_data$[3,1]
		dflt_data$[1,0] = "DATA_LOCATION"
		dflt_data$[1,1] = callpoint!.getColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC")+"/aon/data/"
		dflt_data$[2,0] = "INSTALL_TYPE"
		dflt_data$[2,1] = install_type$
		dflt_data$[3,0] = "NEW_INSTALL"
		dflt_data$[3,1] = "1"; rem --- Yes, it's for a new install

		callpoint!.setDevObject("formData",null())

		call stbl("+DIR_SYP")+"bam_run_prog.bbj","ADX_FIRMSETUP",stbl("+USER_ID"),"MNT","",table_chans$[all],"",dflt_data$[all]

		formData!=callpoint!.getDevObject("formData")
		if formData!=null() then
			rem --- Exited adx_firmsetup form before finishing it
			msg_id$="AD_FIRM_WO_DEMO"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Firm is required for production installs
		firm_id$=formData!.getProperty("NEW_FIRM_ID")
		if firm_id$="" then
			msg_id$="AD_FIRM_WO_DEMO"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Cannot use firm 99 or ZZ
		if pos(firm_id$="99ZZ",2) then
			msg_id$="AD_FIRM_ID_BAD"
			dim msg_tokens$[1]
			msg_tokens$[1]=firm_id$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Display new firm ID
		callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_FIRM_ID",firm_id$,1)
	endif

rem --- Cannot use version-neutral install and Quick Copy together
	if callpoint!.getColumnData("ADX_INSTALLWIZ.INSTALL_TYPE")="Q" and
:	num(callpoint!.getColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL")) then
		msg_id$="AD_VER_NEUT_PLUS_QC"
		gosub disp_message
		callpoint!.setStatus("ABORT")

		callpoint!.setFocus("ADX_INSTALLWIZ.INSTALL_TYPE")
		break
	endif

[[ADX_INSTALLWIZ.BASE_DIR.AVAL]]
rem --- Validate base directory for installation

	new_loc$ = callpoint!.getUserInput()
	gosub validate_base_dir
	if abort then
		callpoint!.setStatus("ABORT")
		break
	endif
	callpoint!.setUserInput(new_loc$)

rem --- Update new install loc
	major_ver$=callpoint!.getDevObject("major_ver")
	minor_ver$=callpoint!.getDevObject("minor_ver")
	callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC",new_loc$+"/"+major_ver$+"/"+minor_ver$,1)
	

[[ADX_INSTALLWIZ.BSHO]]
rem --- Declare Java classes used

	use java.io.File
	use ::ado_file.src::FileObject

rem --- Open/Lock files

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="DDM_SYSTEMS",open_opts$[1]="OTA"

	gosub open_tables

rem --- Get this version of Addon's Admin module
	version_id$="??.??"
	major_ver$="v??"
	minor_ver$="v????"
	call stbl("+DIR_SYP")+"bax_version.bbj",version_id$,lic_id$
	major_ver$="v"+str(num(version_id$,err=*next):"00",err=*next)
	minor_ver$="v"+str(num(version_id$,err=*next)*100:"0000",err=*next)
	callpoint!.setDevObject("major_ver",major_ver$)
	callpoint!.setDevObject("minor_ver",minor_ver$)

[[ADX_INSTALLWIZ.DB_NAME.AVAL]]
rem --- Validate new database name

	db_name$ = callpoint!.getUserInput()
	gosub validate_new_db_name
	callpoint!.setUserInput(db_name$)
	if abort then break

[[ADX_INSTALLWIZ.GIT_AUTH_ID.AVAL]]
gitAuthID$=cvs(callpoint!.getUserInput(),3)
gosub validate_git_auth_id

[[ADX_INSTALLWIZ.INSTALL_TYPE.AVAL]]
rem --- Enable/disable version_neutral
	install_type$=callpoint!.getUserInput()
	if install_type$<>callpoint!.getColumnData("ADX_INSTALLWIZ.INSTALL_TYPE") then
		if install_type$="Q" then
			rem --- Reset base_dir and new_install_loc if currently version neutral
			if num(callpoint!.getColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL")) then
				rem --- Disable and initialize base_dir
				new_install_loc$=callpoint!.getColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC")
				if cvs(new_install_loc$,2)<>"" then
					callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR",new_install_loc$,1)
				else
					callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR","",1)
				endif
				callpoint!.setColumnEnabled("ADX_INSTALLWIZ.BASE_DIR",0)

				rem --- Enable new_install_loc
				callpoint!.setColumnEnabled("ADX_INSTALLWIZ.NEW_INSTALL_LOC",1)
			endif

			rem --- Clear version_neutral
			callpoint!.setColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL","0",1)
			
			rem --- Clear firm_id
			callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_FIRM_ID","",1)
		else
			rem --- Version-neutral install
			callpoint!.setColumnData("ADX_INSTALLWIZ.VERSION_NEUTRAL","1",1)
			callpoint!.setColumnEnabled("ADX_INSTALLWIZ.BASE_DIR",1)
			callpoint!.setColumnEnabled("ADX_INSTALLWIZ.NEW_INSTALL_LOC",0)
			callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC","",1)

			base_dir$=callpoint!.getColumnData("ADX_INSTALLWIZ.BASE_DIR")
			if cvs(base_dir$,2)<>"" then
				major_ver$=callpoint!.getDevObject("major_ver")
				minor_ver$=callpoint!.getDevObject("minor_ver")
				callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC",base_dir$+"/"+major_ver$+"/"+minor_ver$,1)
			endif
		endif
	endif

[[ADX_INSTALLWIZ.NEW_INSTALL_LOC.AVAL]]
rem --- Validate directory for aon new install location

	new_loc$ = callpoint!.getUserInput()
	gosub validate_aon_dir
	if abort then
		callpoint!.setStatus("ABORT")
		break
	endif
	callpoint!.setUserInput(new_loc$)

rem --- Update base dir
	callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR",new_loc$,1)

[[ADX_INSTALLWIZ.<CUSTOM>]]
rem --- validate_git_auth_id
rem --- verifies that the Git repository is a fork or clone of the official Addon repository
rem --- gitAuthID$: the ID of the Git Authentication record in the ADX_GIT_AUTH table.
validate_git_auth_id: 
	use ::ado_GitRepoInterface.aon::GitRepoInterface
	
	git!=new GitRepoInterface(gitAuthID$)
	isOfficial=git!.isDescendantOfOfficialRepo()

	REM If the repo is not official, show a message and cancel validation 
	if !isOfficial then
		msg_id$="ADX_INVALID_GIT_REPO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif 
	return

validate_release_tag:

	git!=new GitRepoInterface(gitAuthID$)

	rem --- if the version being installed/upgraded to isn't tagged (i.e., not an official release), show message and cancel
	tagVersion$=callpoint!.getDevObject("minor_ver")
	tagVersion$=tagVersion$(2)
	isTagged=git!.isTaggedRelease(tagVersion$)
	if !isTagged
		msg_id$="ADX_INVALID_GIT_REL"
		dim msg_tokens$[1]
		msg_tokens$[1]=str(num(tagVersion$)/100:"00.00")
		gosub disp_message
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif
	return 

validate_new_db_name: rem --- Validate new database name

	abort=0

	rem --- Barista uses all upper case db names
	db_name$=cvs(db_name$,4)

	rem --- Also replace any spaces with underscores (ER 10496)
	db_name!=db_name$
	db_name$=db_name!.replace(" ","_")

	rem --- Don't allow database if it's already in Enterprise Manager
	call stbl("+DIR_SYP")+"bac_em_login.bbj",SysGUI!,Form!,rdAdmin!,rd_status$
	if rd_status$="ADMIN" then
		db! = rdAdmin!.getDatabase(db_name$,err=dbNotFound)

		rem --- This db already exists, so don't allow it
		msg_id$="AD_DB_EXISTS"
		gosub disp_message
	endif

	rem --- Abort, need to re-enter database name
	callpoint!.setColumnData("ADX_INSTALLWIZ.DB_NAME", db_name$)
	callpoint!.setFocus("ADX_INSTALLWIZ.DB_NAME")
	callpoint!.setStatus("ABORT")
	abort=1

dbNotFound:
	rem --- Okay to use this db name, it doesn't already exist
	callpoint!.setDevObject("rdAdmin", rdAdmin!)

	return

validate_aon_dir: rem --- Validate directory for aon new install location

	abort=0

	rem --- Flip directory path separators

	filePath$=new_loc$
	gosub fix_path
	new_loc$=filePath$

	rem --- Remove trailing slashes (/ and \) from aon new install location

	while len(new_loc$) and pos(new_loc$(len(new_loc$),1)="/\")
		new_loc$ = new_loc$(1, len(new_loc$)-1)
	wend

	rem --- Remove trailing “/aon”

	if len(new_loc$)>=4 and pos(new_loc$(1+len(new_loc$)-4)="/aon\aon" ,4)
		new_loc$ = new_loc$(1, len(new_loc$)-4)
	endif

	rem --- Fix path for this OS
	current_dir$=dir("")
	current_drive$=dsk("",err=*next)
    	FileObject.makeDirs(new File(new_loc$))
	valid_path=0

	if (new_loc$(2,1)=":") then
		drive$=new_loc$(1,1)
		setdrive drive$
	endif 

	chdir(new_loc$),err=*next; valid_path=1
	if !valid_path then
		msg_id$="AD_BAD_DIR"
		dim msg_tokens$[1]
		msg_tokens$[1]=new_loc$
		gosub disp_message

		callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC", new_loc$)
		callpoint!.setFocus("ADX_INSTALLWIZ.NEW_INSTALL_LOC")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif
	new_loc$=dsk("")+dir("")
	while len(new_loc$) and pos(new_loc$(len(new_loc$),1)="/\")
		new_loc$ = new_loc$(1, len(new_loc$)-1)
	wend
	setdrive current_drive$
	chdir current_dir$

	rem --- Don’t allow current download location

	testLoc$=new_loc$
	gosub verify_not_download_loc
	if !loc_ok
		callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC", new_loc$)
		callpoint!.setFocus("ADX_INSTALLWIZ.NEW_INSTALL_LOC")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif

	rem --- Read-Write-Execute directory permissions are required

	if !FileObject.isDirWritable(new_loc$)
		msg_id$="AD_DIR_NOT_WRITABLE"
		dim msg_tokens$[1]
		msg_tokens$[1]=new_loc$
		gosub disp_message

		callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC", new_loc$)
		callpoint!.setFocus("ADX_INSTALLWIZ.NEW_INSTALL_LOC")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif

	rem --- Cannot be currently used by Addon

	aonDir_exists=0
	testChan=unt
	open(testChan,err=*next)new_loc$ + "/aon"; aonDir_exists=1
	close(testChan,err=*next)
	testChan=unt
	if !aonDir_exists then return

	rem --- Location is used by Addon
	msg_id$="AD_INSTALL_LOC_USED"
	gosub disp_message

	callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC", new_loc$)
	callpoint!.setFocus("ADX_INSTALLWIZ.NEW_INSTALL_LOC")
	callpoint!.setStatus("ABORT")
	abort=1

	return

validate_base_dir: rem --- Validate base directory for installation

	abort=0

	rem --- Flip directory path separators

	filePath$=new_loc$
	gosub fix_path
	new_loc$=filePath$

	rem --- Remove trailing slashes (/ and \) from aon new install location

	while len(new_loc$) and pos(new_loc$(len(new_loc$),1)="/\")
		new_loc$ = new_loc$(1, len(new_loc$)-1)
	wend

	rem --- Fix path for this OS
	current_dir$=dir("")
	current_drive$=dsk("",err=*next)
    	FileObject.makeDirs(new File(new_loc$))
	valid_path=0

	if (new_loc$(2,1)=":") then
		drive$=new_loc$(1,1)
		setdrive drive$
	endif 

	chdir(new_loc$),err=*next; valid_path=1
	if !valid_path then
		msg_id$="AD_BAD_DIR"
		dim msg_tokens$[1]
		msg_tokens$[1]=new_loc$
		gosub disp_message

		callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR", new_loc$)
		callpoint!.setFocus("ADX_INSTALLWIZ.BASE_DIR")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif
	new_loc$=dsk("")+dir("") 
	while len(new_loc$) and pos(new_loc$(len(new_loc$),1)="/\")
		new_loc$ = new_loc$(1, len(new_loc$)-1)
	wend
	setdrive current_drive$
	chdir current_dir$

	rem --- Don’t allow current download location

	testLoc$=new_loc$
	gosub verify_not_download_loc
	if !loc_ok
		callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR", new_loc$)
		callpoint!.setFocus("ADX_INSTALLWIZ.BASE_DIR")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif

	rem --- Read-Write-Execute directory permissions are required

	if !FileObject.isDirWritable(new_loc$)
		msg_id$="AD_DIR_NOT_WRITABLE"
		dim msg_tokens$[1]
		msg_tokens$[1]=new_loc$
		gosub disp_message

		callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR", new_loc$)
		callpoint!.setFocus("ADX_INSTALLWIZ.BASE_DIR")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif

	rem --- Cannot be currently used by Addon

	major_ver$=callpoint!.getDevObject("major_ver")
	minor_ver$=callpoint!.getDevObject("minor_ver")
	aonDir_exists=0
	testChan=unt
	open(testChan,err=*next)new_loc$+"/"+major_ver$+"/"+minor_ver$+"/aon"; aonDir_exists=1
	close(testChan,err=*next)
	testChan=unt
	if !aonDir_exists then return

	rem --- Location is used by Addon
	callpoint!.setColumnData("ADX_INSTALLWIZ.NEW_INSTALL_LOC",new_loc$+"/"+major_ver$+"/"+minor_ver$,1)
	msg_id$="AD_INSTALL_LOC_USED"
	gosub disp_message

	callpoint!.setColumnData("ADX_INSTALLWIZ.BASE_DIR", new_loc$)
	callpoint!.setFocus("ADX_INSTALLWIZ.BASE_DIR")
	callpoint!.setStatus("ABORT")
	abort=1

	return

verify_not_download_loc: rem --- Verify not using current download location

	loc_ok=1
	bbjHome$ = System.getProperty("basis.BBjHome")
	if ((new File(testLoc$)).getAbsolutePath()).toLowerCase().startsWith((new File(bbjHome$)).getAbsolutePath().toLowerCase()+File.separator)
		msg_id$="AD_INSTALL_LOC_BAD"
		dim msg_tokens$[1]
		msg_tokens$[1]=bbjHome$
		gosub disp_message
		loc_ok=0
	endif

	return

fix_path: rem --- Flip directory path separators

	pos=pos("\"=filePath$)
	while pos
		filePath$=filePath$(1, pos-1)+"/"+filePath$(pos+1)
		pos=pos("\"=filePath$)
	wend
	return



