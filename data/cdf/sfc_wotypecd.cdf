[[SFC_WOTYPECD.ADIS]]
rem --- Disable variance accounts

	stdact_flag$=callpoint!.getColumnData("SFC_WOTYPECD.STDACT_FLAG")
	gosub disable_accts

[[SFC_WOTYPECD.BDEL]]
rem --- When deleting the Work Order Type Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("SFC_WOTYPECD.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[SFC_WOTYPECD.BSHO]]
rem --- This firm using Materials Planning?
	call stbl("+DIR_PGM")+"adc_application.aon","MP",info$[all]
	callpoint!.setDevObject("usingAP",info$[20])

rem --- Open files

	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SFS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="GLS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="IVS_PARAMS",open_opts$[3]="OTA"
	open_tables$[4]="SFE_WOMASTR",open_opts$[4]="OTA"
	if callpoint!.getDevObject("usingMP")="Y" then
		open_tables$[5]="MPE_PEGGING",open_opts$[5]="OTA"
		open_tables$[6]="MPM_FORCAST",open_opts$[6]="OTA"
	endif

	gosub open_tables

	sfs01_dev=num(open_chans$[1])
	gls01_dev=num(open_chans$[2])
	ivs01_dev=num(open_chans$[3])

	dim sfs01a$:open_tpls$[1]
	dim gls01a$:open_tpls$[2]
	dim ivs01$:open_tpls$[3]

rem --- Get SF parameters

	read record (sfs01_dev,key=firm_id$+"SF00",dom=std_missing_params) sfs01a$
	gl$=sfs01a.post_to_gl$
	callpoint!.setDevObject("gl",gl$)

	if gl$="Y" then
		rem --- Check to see if main GL param rec (firm/GL/00) exists; if not, tell user to set it up first
		gls01a_key$=firm_id$+"GL00"
		find record (gls01_dev,key=gls01a_key$,err=*next) gls01a$  
		if cvs(gls01a.current_per$,2)=""
			msg_id$="GL_PARAM_ERR"
			dim msg_tokens$[1]
			msg_opt$=""
			gosub disp_message
			rem - remove process bar
			bbjAPI!=bbjAPI()
			rdFuncSpace!=bbjAPI!.getGroupNamespace()
			rdFuncSpace!.setValue("+build_task","OFF")
			release
		endif
	else
		rem --- Not using GL, so disable GL acct fields
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_CLOSE_TO",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_DIR_LAB",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_LAB_VAR",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_MAT_VAR",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_OVH_LAB",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_OVH_VAR",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_PUR_ACCT",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_SUB_VAR",-1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_WIP_ACCT",-1)
	endif

rem --- Retrieve IV parameter data

	read record (ivs01_dev,key=firm_id$+"IV00",dom=std_missing_params)ivs01$
	callpoint!.setDevObject("cost_method",ivs01.cost_method$)

[[SFC_WOTYPECD.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Work Order Type Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("SFC_WOTYPECD.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[SFC_WOTYPECD.STDACT_FLAG.AINP]]
rem --- See if we need to set flag

	if callpoint!.getDevObject("cost_method")="S" and callpoint!.getColumnData("SFC_WOTYPECD.WO_CATEGORY")="I"
		callpoint!.setColumnData("SFC_WOTYPECD.STDACT_FLAG","S",1)
	endif

[[SFC_WOTYPECD.STDACT_FLAG.AVAL]]
rem --- Disable variance accounts

	stdact_flag$=callpoint!.getUserInput()
	gosub disable_accts

[[SFC_WOTYPECD.<CUSTOM>]]
rem =====================================================
disable_accts:
rem - stdact_flag$	input
rem =====================================================
rem --- Disable 4 G/L Accounts if posting at Actuals

	if stdact_flag$="A"
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_LAB_VAR",0)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_MAT_VAR",0)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_OVH_VAR",0)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_SUB_VAR",0)
	else
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_LAB_VAR",1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_MAT_VAR",1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_OVH_VAR",1)
		callpoint!.setColumnEnabled("SFC_WOTYPECD.GL_SUB_VAR",1)
	endif

	return

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	wo_type$=callpoint!.getColumnData("SFC_WOTYPECD.WO_TYPE")

	checkTables!=BBjAPI().makeVector()
	if callpoint!.getDevObject("usingMP")="Y" then
		checkTables!.addItem("MPE_PEGGING")
		checkTables!.addItem("MPM_FORCAST")
	endif
	checkTables!.addItem("SFE_WOMASTR")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.wo_type$=wo_type$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_WO_TYPE_")+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="MPE_PEGGING"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPE_PEGGING-DD_ATTR_WINT")
                    				break
                				case thisTable$="MPM_FORCAST"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPM_FORCAST-DD_ATTR_WINT")
                    				break
                				case thisTable$="SFE_WOMASTR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMASTR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("SFC_WOTYPECD.CODE_INACTIVE","N",1)
	endif

return

#include [+ADDON_LIB]std_missing_params.aon



