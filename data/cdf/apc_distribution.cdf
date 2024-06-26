[[APC_DISTRIBUTION.BDEL]]
rem --- Do NOT allow deleting this Distribution Code when still in use.
	thisDistCd$=callpoint!.getColumnData("APC_DISTRIBUTION.AP_DIST_CODE")
	usedInTable$=""

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("APC_TYPECODE")
	checkTables!.addItem("APE_INVOICEHDR")
	checkTables!.addItem("APE_MANCHECKDET")
	checkTables!.addItem("APE_RECURRINGHDR")
	checkTables!.addItem("APM_VENDHIST")
	checkTables!.addItem("APS_PARAMS")
	checkTables!.addItem("APT_CHECKHISTORY")
	checkTables!.addItem("APT_INVOICEHDR")
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_INVHDR")
		checkTables!.addItem("POT_INVHDR")
	endif
	for i=0 to checkTables!.size()-1
		table_dev = fnget_dev(checkTables!.getItem(i))
		dim table_tpl$:fnget_tpl$(checkTables!.getItem(i))
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.ap_dist_code$=thisDistCd$ then
				if usedInTable$<>"" then usedInTable$=usedInTable$+", "
				usedInTable$=usedInTable$+checkTables!.getItem(i)
				break
			endif
		wend
	next i

	rem --- Report tables where this Distribution Code is currently being used.
	if usedInTable$<>"" then
		msg_id$="AP_DIST_CD_USED"
		dim msg_tokens$[1]
		msg_tokens$[1]=usedInTable$
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Do they want to deactivate code instead of deleting it?
	msg_id$="AD_DEACTIVATE_CODE"
	gosub disp_message
	if msg_opt$="Y" then
		rem --- Check the CODE_INACTIVE checkbox
		callpoint!.setColumnData("APC_DISTRIBUTION.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[APC_DISTRIBUTION.BSHO]]
rem --- This firm using Purchase Orders?
	call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
	callpoint!.setDevObject("usingPO",info$[20])

rem --- Open/Lock files
files=10
if callpoint!.getDevObject("usingPO")<>"Y" then files=8
begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="APS_PARAMS";rem --- aps-01
files$[2]="APC_TYPECODE"
files$[3]="APE_INVOICEHDR"
files$[4]="APE_MANCHECKDET"
files$[5]="APE_RECURRINGHDR"
files$[6]="APM_VENDHIST"
files$[7]="APT_CHECKHISTORY"
files$[8]="APT_INVOICEHDR"
if callpoint!.getDevObject("usingPO")="Y" then
	files$[9]="POE_INVHDR"
	files$[10]="POT_INVHDR"
endif

for wkx=begfile to endfile
	options$[wkx]="OTA"
next wkx

call stbl("+DIR_SYP")+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:                                 chans$[all],templates$[all],table_chans$[all],batch,status$

if status$<>"" then
	remove_process_bar:
	bbjAPI!=bbjAPI()
	rdFuncSpace!=bbjAPI!.getGroupNamespace()
	rdFuncSpace!.setValue("+build_task","OFF")
	release
endif

aps01_dev=num(chans$[1])

rem --- Retrieve miscellaneous templates

files=1,begfile=1,endfile=files
dim ids$[files],templates$[files]
ids$[1]="aps-01A:APS_PARAMS"

call stbl("+DIR_PGM")+"adc_template.aon",begfile,endfile,ids$[all],templates$[all],status
if status goto std_exit

rem --- Dimension miscellaneous string templates

dim aps01a$:templates$[1]

rem --- init/parameters

aps01a_key$=firm_id$+"AP00"
find record (aps01_dev,key=aps01a_key$,err=std_missing_params) aps01a$

if aps01a.ret_flag$<>"Y" 
    ctl_name$="APC_DISTRIBUTION.GL_RET_ACCT"
    ctl_stat$="I"
    gosub disable_fields
endif

dim info$[20]
call stbl("+DIR_PGM")+"adc_application.aon","AP",info$[all]
gl$=info$[9]
if gl$<>"Y" then
	callpoint!.setColumnEnabled("APC_DISTRIBUTION.GL_AP_ACCT",-1)
	callpoint!.setColumnEnabled("APC_DISTRIBUTION.GL_CASH_ACCT",-1)
	callpoint!.setColumnEnabled("APC_DISTRIBUTION.GL_DISC_ACCT",-1)
endif

[[APC_DISTRIBUTION.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Distribution code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("APC_DISTRIBUTION.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[APC_DISTRIBUTION.GL_AP_ACCT.AVAL]]
gosub gl_active

[[APC_DISTRIBUTION.GL_CASH_ACCT.AVAL]]
gosub gl_active

[[APC_DISTRIBUTION.GL_DISC_ACCT.AVAL]]
gosub gl_active

[[APC_DISTRIBUTION.GL_PURC_ACCT.AVAL]]
gosub gl_active

[[APC_DISTRIBUTION.GL_RET_ACCT.AVAL]]
gosub gl_active

[[APC_DISTRIBUTION.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon
#include [+ADDON_LIB]std_missing_params.aon

gl_active:
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
return

disable_fields:
 rem --- used to disable/enable controls depending on parameter settings
 rem --- send in control to toggle (format "ALIAS.CONTROL_NAME"), and D or space to disable/enable


 wctl$=str(num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI")):"00000")
 wmap$=callpoint!.getAbleMap()
 wpos=pos(wctl$=wmap$,8)
 wmap$(wpos+6,1)=ctl_stat$
 callpoint!.setAbleMap(wmap$)
 callpoint!.setStatus("ABLEMAP-REFRESH-ACTIVATE")
 
return

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	ap_dist_code$=callpoint!.getColumnData("APC_DISTRIBUTION.AP_DIST_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("APC_TYPECODE")
	checkTables!.addItem("APE_INVOICEHDR")
	checkTables!.addItem("APE_MANCHECKDET")
	checkTables!.addItem("APE_RECURRINGHDR")
	checkTables!.addItem("APM_VENDHIST")
	checkTables!.addItem("APS_PARAMS")
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_INVHDR")
	endif
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.ap_dist_code$=ap_dist_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="AP "+Translate!.getTranslation("AON_DISTRIBUTION_CODE")
				switch (BBjAPI().TRUE)
					case thisTable$="APC_TYPECODE"
						msg_tokens$[2]=Translate!.getTranslation("DDM_TABLE_COLS-APC_TYPECODE-AP_TYPE-DD_ATTR_PROM")+" "+Translate!.getTranslation("AON_CODE")
						break
                				case thisTable$="APE_INVOICEHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APE_INVOICEHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="APE_MANCHECKDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APE_MANCHECKHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="APE_RECURRINGHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APE_RECURRINGHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="APM_VENDHIST"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APM_VENDHIST-DD_ATTR_WINT")
                    				break
                				case thisTable$="APS_PARAMS"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APS_PARAMS-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_INVHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_INVHDR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("APC_DISTRIBUTION.CODE_INACTIVE","N",1)
	endif

	return



