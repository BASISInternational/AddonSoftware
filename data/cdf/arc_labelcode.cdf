[[ARC_LABELCODE.BDEL]]
rem --- When deleting the AR Label Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("ARC_LABELCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[ARC_LABELCODE.BSHO]]
rem --- Open/Lock files
files=2
begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="ARM_CUSTDET"
files$[2]="ARS_CUSTDFLT"

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

[[ARC_LABELCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the AR Lable Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("ARC_LABELCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[ARC_LABELCODE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	label_code$=callpoint!.getColumnData("ARC_LABELCODE.LABEL_CODE")
                              callpoint!.getColumnData("ARC_LABELCODE.LABEL_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("ARM_CUSTDET")
	checkTables!.addItem("ARS_CUSTDFLT")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		dim msg_tokens$[2]
		switch (BBjAPI().TRUE)
                		case thisTable$="ARM_CUSTDET"
				read(table_dev,key=firm_id$,dom=*next)
				while 1
					readrecord(table_dev,end=*break)table_tpl$
					if table_tpl.firm_id$<>firm_id$ then break
					if table_tpl.label_code$=label_code$ then
						msg_id$="AD_CODE_IN_USE"
						msg_tokens$[1]=Translate!.getTranslation("AON_LABEL_CODE")
		                   		msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARC_LABELCODE-DD_ATTR_WINT")
						gosub disp_message

						found=1
						break
					endif
				wend
                    		break
               		case thisTable$="ARS_CUSTDFLT"
				findrecord(table_dev,key=firm_id$+"D",dom=*next)table_tpl$
				if table_tpl.label_code$=label_code$ then
					callpoint!.setMessage("AR_LABEL_CD_IN_DFLT")

					found=1
					break
				endif
                    		break
           		case default
				msg_id$="AD_CODE_IN_USE"
				msg_tokens$[1]=Translate!.getTranslation("AON_LABEL_CODE")
                    		msg_tokens$[2]="???"
				gosub disp_message

				found=1
                    		break
            	swend
		if found then break
	next i

	if found then
		rem --- Uncheck the CODE_INACTIVE checkbox
		callpoint!.setColumnData("ARC_LABELCODE.CODE_INACTIVE","N",1)
	endif

return



