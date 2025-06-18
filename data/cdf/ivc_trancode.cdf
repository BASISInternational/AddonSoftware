[[IVC_TRANCODE.ADIS]]
rem --- Check for Commitment type
	if callpoint!.getColumnData("IVC_TRANCODE.TRANS_TYPE") = "C"
		callpoint!.setColumnData("IVC_TRANCODE.POST_GL","N",1)
		callpoint!.setColumnData("IVC_TRANCODE.GL_ADJ_ACCT","",1)
		callpoint!.setColumnEnabled("IVC_TRANCODE.POST_GL",0)
	else
		if user_tpl.gl_installed$="Y" then callpoint!.setColumnEnabled("IVC_TRANCODE.POST_GL",1)
	endif

[[IVC_TRANCODE.AREC]]
	if user_tpl.gl_installed$="Y" then callpoint!.setColumnEnabled("IVC_TRANCODE.POST_GL",1)

[[IVC_TRANCODE.BDEL]]
rem --- When deleting the Product Type code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("IVC_PRODCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_TRANCODE.BSHO]]
rem --- Open/Lock Files
	files=2,begfile=1,endfile=files
	dim files$[files],options$[files],chans$[files],templates$[files]
	files$[1]="IVS_PARAMS",options$[1]="OTA"
	files$[2]="IVE_TRANSHDR",options$[2]="OTA"

	call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:                                 chans$[all],templates$[all],table_chans$[all],batch,status$
	if status$<>"" then
		remove_process_bar:
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif
	ivs01_dev=num(chans$[1])
			
	rem --- Dimension miscellaneous string templates
			
	dim ivs01a$:templates$[1]
			
rem --- init/parameters
			
	ivs01a_key$=firm_id$+"IV00"
	find record (ivs01_dev,key=ivs01a_key$,err=std_missing_params) ivs01a$
rem --- check if GL is installed
	call stbl("+DIR_PGM")+"adc_application.aon","GL",info$[all]
	gl$=info$[20];rem --- gl installed?
	dim user_tpl$:"gl_installed:c(1)"
	user_tpl.gl_installed$=gl$
	if gl$<>"Y" then callpoint!.setColumnEnabled("IVC_TRANCODE.POST_GL",-1)

[[IVC_TRANCODE.BWAR]]
rem --- if post to GL is blank, set it to 'N'
	if callpoint!.getColumnData("IVC_TRANCODE.POST_GL")<>"Y"
		callpoint!.setColumnData("IVC_TRANCODE.POST_GL","N",1)
	endif

[[IVC_TRANCODE.BWRI]]
rem --- Check for blank Trans Type
	if cvs(callpoint!.getColumnData("IVC_TRANCODE.TRANS_TYPE"),2) = "" then
		msg_id$="INVALID_TRANS_TYPE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif
rem --- Check for G/L Number if Post to G/L is up
	if callpoint!.getColumnData("IVC_TRANCODE.POST_GL") = "Y" then
		if cvs(callpoint!.getColumnData("IVC_TRANCODE.GL_ADJ_ACCT"),2) = "" then
			msg_id$ = "IV_NEED_GL_ACCT"
			gosub disp_message
			callpoint!.setStatus("ABORT")
		endif
	endif

[[IVC_TRANCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Transaction Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_TRANCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[IVC_TRANCODE.GL_ADJ_ACCT.AVAL]]
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*break) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE-ABORT")
   endif

[[IVC_TRANCODE.TRANS_TYPE.AVAL]]
rem --- Check for Commitment type
	if callpoint!.getColumnData("IVC_TRANCODE.TRANS_TYPE") = "C"
		callpoint!.setColumnData("IVC_TRANCODE.POST_GL","N",1)
		callpoint!.setColumnData("IVC_TRANCODE.GL_ADJ_ACCT","",1)
		callpoint!.setColumnEnabled("IVC_TRANCODE.POST_GL",0)
		callpoint!.setColumnEnabled("IVC_TRANCODE.GL_ADJ_ACCT",0)
	else
		if user_tpl.gl_installed$="Y" then callpoint!.setColumnEnabled("IVC_TRANCODE.POST_GL",1)
	endif

[[IVC_TRANCODE.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon
#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	trans_code$=callpoint!.getColumnData("IVC_TRANCODE.TRANS_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVE_TRANSHDR")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.trans_code$=trans_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_TRANSACTION")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVE_TRANSHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_TRANSHDR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("IVC_TRANCODE.CODE_INACTIVE","N",1)
	endif

return



