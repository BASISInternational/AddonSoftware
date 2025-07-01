[[OPC_MESSAGE.AOPT-PPVW]]
rem --- generate Jasper to show how messages will look on Pick List and Invoice 

	use ::bbjasper.bbj::BBJasperReport
	use ::bbjasper.bbj::BBJasperViewerWindow
	use ::bbjasper.bbj::BBJasperViewerControl

	use ::sys/prog/bao_utilities.bbj::BarUtils
	    
	ScreenSize!   = bbjAPI().getSysGui().getSystemMetrics().getScreenSize()
	screen_width  = ScreenSize!.width - 50; rem -50 keeps it in the MDI w/ no scroll bars
	screen_height = ScreenSize!.height - 50
	    
rem --- Get HashMap of Values in Options Entry Form

	params! = new java.util.HashMap()

	params!.put("FIRM_ID",firm_id$)
	params!.put("MESSAGE_CODE",callpoint!.getColumnData("OPC_MESSAGE.MESSAGE_CODE"))

rem --- Set Report Name & Subreport directory

	reportDir$ = BBjAPI().getFileSystem().resolvePath(util.resolvePathStbls(stbl("+DIR_REPORTS",err=*next)))+"/"
	repTitle!="Standard_Message_Formatting"
	reportBaseName$ = "OPMessageFormat"
	filename$ = reportDir$ + reportBaseName$ + ".jasper"

	declare BBJasperReport report!

rem --- Check for user authentication

	report! = BarUtils.getBBJasperReport(filename$)
	report!.putParams(params!)

	locale$ = stbl("!LOCALE")
	locale$ = stbl("+USER_LOCALE",err=*next)
	report!.setLocale(locale$)

rem --- Fill Report and Show

	rc=report!.fill(1)
	if rc<>BBJasperReport.getSUCCESS() then break

	declare BBJasperViewerWindow viewerWindow!
	viewerWindow! = new BBJasperViewerWindow(report!,0,0,screen_width,screen_height,repTitle$,$00080093$)

	viewerControl! = viewerWindow!.getViewerControl()
	viewerControl!.setFitWidth()

	viewerWindow!.setReleaseOnClose(0)
	viewerWindow!.show(1);rem 1 means let Jasper manage process_events

[[OPC_MESSAGE.AOPT-PRNT]]
rem --- create message listing


call stbl("+DIR_SYP")+"bam_run_prog.bbj","OPR_STDMSGLIST",stbl("+USER_ID"),"","",table_chans$[all]

[[OPC_MESSAGE.BDEL]]
rem --- When deleting the OP Message Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	gosub check_active_code
	if found then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Do they want to deactivate code instead of deleting it?
	msg_id$="AD_DEACTIVATE_CODE"
	gosub disp_message
	if msg_opt$="Y" then
		rem --- Check the CODE_INACTIVE checkbox
		callpoint!.setColumnData("OPC_MESSAGE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[OPC_MESSAGE.BSHO]]
    use ::ado_util.src::util

rem --- Open/Lock files
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARM_CUSTDET",open_opts$[1]="OTA"
	open_tables$[2]="ARS_CUSTDFLT",open_opts$[2]="OTA"
	open_tables$[3]="OPT_INVHDR",open_opts$[3]="OTA"
	gosub open_tables

[[OPC_MESSAGE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the OP Message Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("OPC_MESSAGE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPC_MESSAGE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	message_code$=callpoint!.getColumnData("OPC_MESSAGE.MESSAGE_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("ARM_CUSTDET")
	checkTables!.addItem("ARS_CUSTDFLT")
	checkTables!.addItem("OPT_INVHDR")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		if thisTable$="OPT_INVHDR" then
			read(table_dev,key=firm_id$+"E",knum="AO_STATUS",dom=*next)
		else
			read(table_dev,key=firm_id$,dom=*next)
		endif
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if thisTable$="OPT_INVHDR" and table_tpl.trans_status$<>"E" then break
			if table_tpl.message_code$=message_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="OP "+Translate!.getTranslation("AON_MESSAGE")
				switch (BBjAPI().TRUE)
                				case thisTable$="ARM_CUSTDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARS_CUSTDFLT"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARS_CUSTDFLT-DD_ATTR_WINT")
                    				break
                				case thisTable$="OPT_INVHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPT_INVHDR-DD_ATTR_WINT")
                    				break
                				case default
                    				msg_tokens$[2]="???"
                    				break
            				swend
				gosub disp_message

				found=1
				break
			endif
		wend
		if found then break
	next i

	if found then
		rem --- Uncheck the CODE_INACTIVE checkbox
		callpoint!.setColumnData("OPC_MESSAGE.CODE_INACTIVE","N",1)
	endif

return



