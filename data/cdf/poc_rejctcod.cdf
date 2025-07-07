[[POC_REJCTCOD.BDEL]]
rem --- When deleting the QA Receipt Rejection Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("POC_REJCTCOD.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[POC_REJCTCOD.BSHO]]
rem --- open files

num_files=3
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="POS_PARAMS",open_opts$[1]="OTA"
open_tables$[2]="POC_REJCTCMT",open_opts$[2]="OTA"
open_tables$[3]="POE_QAREJDET",open_opts$[3]="OTA"

gosub open_tables

pos_params=num(open_chans$[1])
dim pos01a$:open_tpls$[1]

rem --- init/parameters

pos01a_key$=firm_id$+"PO00"
find record (pos_params,key=pos01a_key$,err=std_missing_params) pos01a$

[[POC_REJCTCOD.CODE_INACTIVE.AVAL]]
rem --- When deactivating the QA Receipt Rejection Code , warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("POC_REJCTCOD.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[POC_REJCTCOD.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	reject_code$=callpoint!.getColumnData("POC_REJCTCOD.REJECT_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("POC_REJCTCMT")
	checkTables!.addItem("POE_QAREJDET")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.reject_code$=reject_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="QA "+Translate!.getTranslation("AON_RECEIPT")+" "+Translate!.getTranslation("AON_REJECTED")+
:							    " "+Translate!.getTranslation("AON_RECEIPT")
				switch (BBjAPI().TRUE)
                				case thisTable$="POC_REJCTCMT"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POC_REJCTCMT-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_QAREJDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QAREJDET-DD_ATTR_WINT")
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
		callpoint!.setColumnData("POC_REJCTCOD.CODE_INACTIVE","N",1)
	endif

return



