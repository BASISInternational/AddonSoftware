[[SFC_OPRTNCOD.BDEL]]
rem --- When deleting the SF Operation Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("SFC_OPRTNCOD.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[SFC_OPRTNCOD.BSHO]]
rem --- Check to make sure BOM isn't being used

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SFS_PARAMS",open_opts$[1]="OTA"
	gosub open_tables

	sfs_params=num(open_chans$[1])
	dim sfs_params$:open_tpls$[1]

	read record(sfs_params,key=firm_id$+"SF00",dom=std_missing_params) sfs_params$

	if sfs_params.bm_interface$="Y"
		msg_id$="SF_BOM_INST"
		gosub disp_message
		rem - remove process bar
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif

rem --- Open/Lock Files
	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SFE_TIMEDATEDET",open_opts$[1]="OTA"
	open_tables$[2]="SFE_TIMEEMPLDET",open_opts$[2]="OTA"
	open_tables$[3]="SFE_TIMEWODET",open_opts$[3]="OTA"
	open_tables$[4]="SFE_WOOPRTN",open_opts$[4]="OTA"
	open_tables$[5]="SFE_WOSCHDL",open_opts$[5]="OTA"
	open_tables$[6]="SFM_OPCALNDR",open_opts$[6]="OTA"

	gosub open_tables

[[SFC_OPRTNCOD.CODE_INACTIVE.AVAL]]
rem --- When deactivating the SF Operation Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("SFC_OPRTNCOD.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[SFC_OPRTNCOD.PCS_PER_HOUR.AVAL]]
rem --- Make sure value is greater than 0

	if num(callpoint!.getUserInput())<=0
		msg_id$="PCS_PER_HR_NOT_ZERO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[SFC_OPRTNCOD.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	op_code$=callpoint!.getColumnData("SFC_OPRTNCOD.OP_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("SFE_TIMEDATEDET")
	checkTables!.addItem("SFE_TIMEEMPLDET")
	checkTables!.addItem("SFE_TIMEWODET")
	checkTables!.addItem("SFE_WOOPRTN")
	checkTables!.addItem("SFE_WOSCHDL")
	checkTables!.addItem("SFM_OPCALNDR")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.op_code$=op_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="SF "+Translate!.getTranslation("AON_OPERATIONS")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="SFE_TIMEDATEDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_TIMEDATEDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="SFE_TIMEEMPLDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_TIMEEMPLDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="SFE_TIMEWODET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_TIMEWODET-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOOPRTN"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOOPRTN-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOSCHDL"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOSCHDL-DD_ATTR_WINT")
						break
                				case thisTable$="SFM_OPCALNDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFM_OPCALNDR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("SFC_OPRTNCOD.CODE_INACTIVE","N",1)
	endif

return



