[[APC_TERMSCODE.ADIS]]
rem --- Disable Discount Days when Discount Percent is zero.
	if num(callpoint!.getColumnData("APC_TERMSCODE.DISC_PERCENT"))=0 then
		callpoint!.setColumnEnabled("APC_TERMSCODE.DISC_DAYS",0)
	else
		callpoint!.setColumnEnabled("APC_TERMSCODE.DISC_DAYS",1)
	endif

[[APC_TERMSCODE.BDEL]]
rem --- When deleting the Terms Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("APC_TERMSCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[APC_TERMSCODE.BSHO]]
rem --- This firm using Purchase Orders?
call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
callpoint!.setDevObject("usingPO",info$[20])

rem --- Open/Lock files
files=10
if callpoint!.getDevObject("usingPO")<>"Y" then files=5
begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="APS_PARAMS";rem --- aps-01
files$[2]="APC_TYPECODE"
files$[3]="APE_INVOICEHDR"
files$[4]="APE_RECURRINGHDR"
files$[5]="APM_VENDHIST"
if callpoint!.getDevObject("usingPO")="Y" then
	files$[6]="POE_INVHDR"
	files$[7]="POE_POHDR"
	files$[8]="POE_QAHDR"
	files$[9]="POE_RECHDR"
	files$[10]="POE_REQHDR"
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

ads01_dev=num(chans$[1])

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
find record (ads01_dev,key=aps01a_key$,err=std_missing_params) aps01a$

dim info$[20]

[[APC_TERMSCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Terms Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("APC_TERMSCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[APC_TERMSCODE.DISC_DAYS.AVAL]]
rem --- For Proxy terms, the Discount Days cannot be less than 1, nor greater than the Due Days.
	if callpoint!.getColumnData("APC_TERMSCODE.PROX_OR_DAYS")="P" then
		disc_days=num(callpoint!.getUserInput())
		due_days=num(callpoint!.getColumnData("APC_TERMSCODE.DUE_DAYS"))
		if disc_days<1 or disc_days>due_days then
			msg_id$="AP_PROXY_DISC_DAYS"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- For Days terms, the Discount Days cannot be less than zero, nor greater than the Due Days.
	if callpoint!.getColumnData("APC_TERMSCODE.PROX_OR_DAYS")="D" then
		disc_days=num(callpoint!.getUserInput())
		due_days=num(callpoint!.getColumnData("APC_TERMSCODE.DUE_DAYS"))
		if disc_days<0 or disc_days>due_days then
			msg_id$="AP_DAYS_DISC_DAYS"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[APC_TERMSCODE.DISC_PERCENT.AVAL]]
rem --- Disable Discount Days when Discount Percent is zero, and set Discount Days equal to Due Days.
	if num(callpoint!.getUserInput())=0 then
		callpoint!.setColumnEnabled("APC_TERMSCODE.DISC_DAYS",0)
		callpoint!.setColumnData("APC_TERMSCODE.DISC_DAYS",callpoint!.getColumnData("APC_TERMSCODE.DUE_DAYS"),1)
	else
		callpoint!.setColumnEnabled("APC_TERMSCODE.DISC_DAYS",1)
	endif

[[APC_TERMSCODE.DUE_DAYS.AVAL]]
rem --- For Proxy terms, the Due Days cannot be less than 1, nor greater than 31.
	if callpoint!.getColumnData("APC_TERMSCODE.PROX_OR_DAYS")="P" then
		due_days=num(callpoint!.getUserInput())
		if due_days<1 or due_days>31 then
			msg_id$="AP_PROXY_DUE_DAYS"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- For Days terms, the Due Days cannot be less than zero.
	if callpoint!.getColumnData("APC_TERMSCODE.PROX_OR_DAYS")="D" then
		due_days=num(callpoint!.getUserInput())
		if due_days<0 then
			msg_id$="AP_DAYS_DUE_DAYS"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- When the Discount Percent is zero, set the Discount Days equal to the Due Days
	if num(callpoint!.getColumnData("APC_TERMSCODE.DISC_PERCENT"))=0 then
		callpoint!.setColumnData("APC_TERMSCODE.DISC_DAYS",callpoint!.getUserInput(),1)
	else
		rem --- When there is a Discount and Due Days is changed to less than Discount Days , set Discount Days equal to Due Days.
		due_days=num(callpoint!.getUserInput())
		if due_days<num(callpoint!.getColumnData("APC_TERMSCODE.DUE_DAYS")) then
			disc_days=num(callpoint!.getColumnData("APC_TERMSCODE.DISC_DAYS"))
			if due_days<disc_days then
				callpoint!.setColumnData("APC_TERMSCODE.DISC_DAYS",str(due_days),1)
			endif
		endif
	endif

[[APC_TERMSCODE.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	terms_codeap$=callpoint!.getColumnData("APC_TERMSCODE.TERMS_CODEAP")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("APC_TYPECODE")
	checkTables!.addItem("APE_INVOICEHDR")
	checkTables!.addItem("APE_RECURRINGHDR")
	checkTables!.addItem("APM_VENDHIST")
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_INVHDR")
		checkTables!.addItem("POE_POHDR")
		checkTables!.addItem("POE_QAHDR")
		checkTables!.addItem("POE_RECHDR")
		checkTables!.addItem("POE_REQHDR")
	endif
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.ap_terms_code$=terms_codeap$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_TERMS_CODE")
				switch (BBjAPI().TRUE)
					case thisTable$="APC_TYPECODE"
						msg_tokens$[2]=Translate!.getTranslation("DDM_TABLE_COLS-APC_TYPECODE-AP_TYPE-DD_ATTR_PROM")+" "+Translate!.getTranslation("AON_CODE")
						break
                				case thisTable$="APE_INVOICEHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APE_INVOICEHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="APE_RECURRINGHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APE_RECURRINGHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="APM_VENDHIST"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APM_VENDHIST-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_INVHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_INVHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_POHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_POHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_QAHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QAHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_RECHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_RECHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_REQHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REQHDR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("APC_TERMSCODE.CODE_INACTIVE","N",1)
	endif

return



