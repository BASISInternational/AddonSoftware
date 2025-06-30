[[ARC_TERMCODE.BDEL]]
rem --- When deleting the AR Terms Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("ARC_TERMCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[ARC_TERMCODE.BSHO]]
rem --- This firm using Sales Order Processing?
call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
callpoint!.setDevObject("usingOP",info$[20])

rem --- Open/Lock files
num_files=8
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="ARS_CREDIT",open_opts$[1]="OTA"
open_tables$[2]="ARE_CNVINV",open_opts$[2]="OTA"
open_tables$[3]="ARE_DATECHANGE",open_opts$[3]="OTA"
open_tables$[4]="ARE_FINCHG",open_opts$[4]="OTA"
open_tables$[5]="ARE_INVHDR",open_opts$[5]="OTA"
open_tables$[6]="ARM_CUSTDET",open_opts$[6]="OTA"
open_tables$[7]="ARS_CUSTDFLT",open_opts$[7]="OTA"
if callpoint!.getDevObject("usingOP")="Y" then
	open_tables$[8]="OPT_INVHDR",open_opts$[8]="OTA"
endif

gosub open_tables

ars_credit=num(open_chans$[1])
dim ars_credit$:open_tpls$[1]

read record (ars_credit,key=firm_id$+"AR01",dom=*next)ars_credit$
if ars_credit.sys_install$ <> "Y"
 	ctl_name$="ARC_TERMCODE.CRED_HOLD"
 	ctl_stat$="I"
 	gosub disable_fields
endif

[[ARC_TERMCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the AR Terms Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("ARC_TERMCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[ARC_TERMCODE.<CUSTOM>]]
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
	ar_terms_code$=callpoint!.getColumnData("ARC_TERMCODE.AR_TERMS_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("ARE_CNVINV")
	checkTables!.addItem("ARE_DATECHANGE")
	checkTables!.addItem("ARE_FINCHG")
	checkTables!.addItem("ARE_INVHDR")
	checkTables!.addItem("ARM_CUSTDET")
	checkTables!.addItem("ARS_CUSTDFLT")
	if callpoint!.getDevObject("usingOP")="Y" then
		checkTables!.addItem("OPT_INVHDR")
	endif
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
			if table_tpl.ar_terms_code$=ar_terms_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="AR "+Translate!.getTranslation("AON_TERMS_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="ARE_CNVINV"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARE_CNVINV-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARE_DATECHANGE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARE_DATECHANGE-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARE_FINCHG"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARE_FINCHG-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARE_INVHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTSHIP-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARM_CUSTDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARS_CUSTDFLT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARS_CUSTDFLT-DD_ATTR_WINT")
						break
                				case thisTable$="OPT_INVHDR"
						if table_tpl.ordinv_flag$="I" then
                    					msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPE_INVHDR-DD_ATTR_WINT")
						else
                    					msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPE_ORDHDR-DD_ATTR_WINT")
						endif
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
		callpoint!.setColumnData("ARC_TERMCODE.CODE_INACTIVE","N",1)
	endif

return



