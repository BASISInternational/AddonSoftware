[[POC_LINECODE.BDEL]]
rem --- When deleting the PO Line Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("POC_LINECODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[POC_LINECODE.BSHO]]
rem --- Open/Lock files

files=8,begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="POS_PARAMS";rem --- ads-01
files$[2]="IVT_ITEMTRAN"
files$[3]="IVT_LSTRANS"
files$[4]="POE_INVDET"
files$[5]="POE_QADET"
files$[6]="POE_ROGDET"
files$[7]="POT_INVDET"
files$[8]="POT_ROGDET"

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

ads01_dev=num(chans$[1])

rem --- Retrieve miscellaneous templates

files=1,begfile=1,endfile=files
dim ids$[files],templates$[files]
ids$[1]="pos-01A:POS_PARAMS"

call stbl("+DIR_PGM")+"adc_template.aon",begfile,endfile,ids$[all],templates$[all],status
if status goto std_exit

rem --- Dimension miscellaneous string templates

dim pos01a$:templates$[1]

rem --- init/parameters

pos01a_key$=firm_id$+"PO00"
find record (ads01_dev,key=pos01a_key$,err=std_missing_params) pos01a$

dim info$[20]

call stbl("+DIR_PGM")+"adc_application.aon","GL",info$[all]
gl$=info$[20]
callpoint!.setDevObject("gl_installed",gl$)

[[POC_LINECODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the PO Line Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("POC_LINECODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[POC_LINECODE.GL_EXP_ACCT.AVAL]]
gosub gl_active

[[POC_LINECODE.GL_PPV_ACCT.AVAL]]
gosub gl_active

[[POC_LINECODE.LINE_TYPE.AVAL]]
rem - don't use gl accounts if GL not installed

if callpoint!.getDevObject("gl_installed")<>"Y"  then
	callpoint!.setColumnData("POC_LINECODE.GL_EXP_ACCT","")
	callpoint!.setColumnData("POC_LINECODE.GL_PPV_ACCT","")
	ctl_name$="POC_LINECODE.GL_EXP_ACCT"
	ctl_stat$="D"
	gosub disable_fields
	ctl_name$="POC_LINECODE.GL_PPV_ACCT"
	gosub disable_fields
endif

rem --- Unset Lead Time Flag if not S type

if callpoint!.getUserInput() <> "S"
	callpoint!.setColumnData("POC_LINECODE.LEAD_TIM_FLG","N")
	callpoint!.setStatus("MODIFIED-REFRESH")
else
	if callpoint!.getRecordMode() = "A"
		callpoint!.setColumnData("POC_LINECODE.LEAD_TIM_FLG","Y")
		callpoint!.setStatus("REFRESH")
	endif
endif

[[POC_LINECODE.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon
#include [+ADDON_LIB]std_functions.aon

gl_active:
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*return) glm01a$
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
 callpoint!.setStatus("ABLEMAP-REFRESH")
 
return

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	po_line_code$=callpoint!.getColumnData("POC_LINECODE.PO_LINE_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVT_ITEMTRAN")
	checkTables!.addItem("IVT_LSTRANS")
	checkTables!.addItem("POE_INVDET")
	checkTables!.addItem("POE_QADET")
	checkTables!.addItem("POE_ROGDET")
	checkTables!.addItem("POS_PARAMS")
	checkTables!.addItem("POT_INVDET")
	checkTables!.addItem("POT_ROGDET")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if (thisTable$<>"POE_ROGDET" and thisTable$<>"POT_ROGDET" and table_tpl.po_line_code$=po_line_code$) or
: 			((thisTable$="POE_ROGDET" or thisTable$="POT_ROGDET") and table_tpl.line_code$=po_line_code$)then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="PO "+Translate!.getTranslation("AON_LINE_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVT_ITEMTRAN"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVT_ITEMTRAN-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVT_LSTRANS"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVT_LSTRANS-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_INVDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_INVDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_QADET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QADET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_ROGDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ROGDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POS_PARAMS"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POS_PARAMS-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_INVDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_INVDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_ROGDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_ROGDET-DD_ATTR_WINT")
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
		callpoint!.setColumnData("POC_LINECODE.CODE_INACTIVE","N",1)
	endif

return



