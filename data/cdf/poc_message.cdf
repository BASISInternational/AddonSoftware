[[POC_MESSAGE.BDEL]]
rem --- When deleting the PO Message Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("POC_MESSAGE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[POC_MESSAGE.BSHO]]
rem --- Open/Lock files

files=15,begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="POE_PODET"
files$[2]="POE_POHDR"
files$[3]="POE_QADET"
files$[4]="POE_QAHDR"
files$[5]="POE_RECDET"
files$[6]="POE_RECHDR"
files$[7]="POE_REQDET"
files$[8]="POE_REQHDR"
files$[9]="POS_PARAMS"
files$[10]="POT_PODET_ARC"
files$[11]="POT_POHDR_ARC"
files$[12]="POT_RECDET"
files$[13]="POT_RECHDR"
files$[14]="POT_REQDET_ARC"
files$[15]="POT_REQHDR_ARC"

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

[[POC_MESSAGE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the PO Message Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("POC_MESSAGE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[POC_MESSAGE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	po_msg_code$=callpoint!.getColumnData("POC_MESSAGE.PO_MSG_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("POE_PODET")
	checkTables!.addItem("POE_POHDR")
	checkTables!.addItem("POE_QADET")
	checkTables!.addItem("POE_QAHDR")
	checkTables!.addItem("POE_RECDET")
	checkTables!.addItem("POE_RECHDR")
	checkTables!.addItem("POE_REQDET")
	checkTables!.addItem("POE_REQHDR")
	checkTables!.addItem("POS_PARAMS")
	checkTables!.addItem("POT_PODET_ARC")
	checkTables!.addItem("POT_POHDR_ARC")
	checkTables!.addItem("POT_RECDET")
	checkTables!.addItem("POT_RECHDR")
	checkTables!.addItem("POT_REQDET_ARC")
	checkTables!.addItem("POT_REQHDR_ARC")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.po_msg_code$=po_msg_code$ or (thisTable$="POS_PARAMS" and table_tpl.po_msg_code$=po_req_msg_code$) then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="PO "+Translate!.getTranslation("AON_MESSAGE")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="POE_PODET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_PODET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_POHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_POHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_QADET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QADET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_QAHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QAHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_RECDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_RECDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_RECHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_RECHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_REQDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REQDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POE_REQHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REQHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="POS_PARAMS"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POS_PARAMS-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_PODET_ARC"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_PODET_ARC-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_POHDR_ARC"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_POHDR_ARC-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_RECDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_RECDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_RECHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_RECHDR-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_REQDET_ARC"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_REQDET_ARC-DD_ATTR_WINT")
                    				break
                				case thisTable$="POT_REQHDR_ARC"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POT_REQHDR_ARC-DD_ATTR_WINT")
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
		callpoint!.setColumnData("POC_MESSAGE.CODE_INACTIVE","N",1)
	endif

return



