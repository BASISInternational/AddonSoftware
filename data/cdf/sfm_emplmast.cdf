[[SFM_EMPLMAST.BDEL]]
rem --- When deleting the Work Order Employee, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("SFM_EMPLMAST.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[SFM_EMPLMAST.BSHO]]
rem --- Open files
	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SFS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="SFE_TIMEDATE",open_opts$[2]="OTA"
	open_tables$[3]="SFE_TIMEEMPL",open_opts$[3]="OTA"
	open_tables$[4]="SFE_TIMEWODET",open_opts$[4]="OTA"
	open_tables$[5]="SFT_CLSOPRTR",open_opts$[5]="OTA"
	open_tables$[6]="SFT_OPNOPRTR",open_opts$[6]="OTA"
	gosub open_tables

	sfs_params=num(open_chans$[1])
	dim sfs_params$:open_tpls$[1]

rem --- Check to make sure Payroll isn't installed
	read record(sfs_params,key=firm_id$+"SF00",dom=std_missing_params) sfs_params$

	if sfs_params.pr_interface$="Y"
		msg_id$="SF_PAYROLL_INST"
		gosub disp_message
		rem - remove process bar
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif

[[SFM_EMPLMAST.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Work Order Employee Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("SFM_EMPLMAST.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[SFM_EMPLMAST.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	employee_no$=callpoint!.getColumnData("SFM_EMPLMAST.EMPLOYEE_NO")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("SFE_TIMEDATE")
	checkTables!.addItem("SFE_TIMEEMPL")
	checkTables!.addItem("SFE_TIMEWODET")
	checkTables!.addItem("SFT_CLSOPRTR")
	checkTables!.addItem("SFT_OPNOPRTR")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.employee_no$=employee_no$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_WO")+" "+Translate!.getTranslation("AON_EMPLOYEE")
				switch (BBjAPI().TRUE)
                				case thisTable$="SFE_TIMEDATE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_TIMEDATE-DD_ATTR_WINT")
                    				break
                				case thisTable$="SFE_TIMEEMPL"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_TIMEEMPL-DD_ATTR_WINT")
                    				break
                				case thisTable$="SFE_TIMEWODET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_TIMEWODET-DD_ATTR_WINT")
						break
                				case thisTable$="SFT_CLSOPRTR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFT_CLSOPRTR-DD_ATTR_WINT")
						break
                				case thisTable$="SFT_OPNOPRTR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFT_OPNOPRTR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("SFM_EMPLMAST.CODE_INACTIVE","N",1)
	endif

return



