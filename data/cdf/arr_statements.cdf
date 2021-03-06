[[ARR_STATEMENTS.ADIS]]
rem --- enable/disable
rem --- (this callpoint is fired if clicking one of the saved selection options)

	seq$=callpoint!.getColumnData("ARR_STATEMENTS.REPORT_SEQUENCE")
	option$=callpoint!.getColumnData("ARR_STATEMENTS.REPORT_OPTION")

	gosub enable_disable_fields

[[ARR_STATEMENTS.ARAR]]
rem --- Set default value
	dim sysinfo$:stbl("+SYSINFO_TPL")
	sysinfo$=stbl("+SYSINFO")
	callpoint!.setColumnData("ARR_STATEMENTS.CURSTM_DATE",sysinfo.system_date$,1)
	callpoint!.setColumnEnabled("ARR_STATEMENTS.CUSTOMER_ID",0)
	callpoint!.setColumnEnabled("ARR_STATEMENTS.ALT_SEQUENCE",0)
	callpoint!.setColumnEnabled("ARR_STATEMENTS.REPORT_SEQUENCE",1)

[[ARR_STATEMENTS.ARER]]
rem --- Init
use ::ado_func.src::func

rem --- Open/Lock files
num_files=1
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="ARS_PARAMS",open_opts$[1]="OTA"
gosub open_tables
ars_params=num(open_chans$[1])
dim ars_params$:open_tpls$[1]

rem --- Retrieve parameter data
readrecord(ars_params,key=firm_id$+"AR00",dom=std_missing_params)ars_params$

rem --- Update Aging Period ListButton
codeVect!=BBjAPI().makeVector()
descVect!=BBjAPI().makeVector()

days$=" "+Translate!.getTranslation("AON_DAYS","Days",1)
codeVect!.add("A")
descVect!.add(Translate!.getTranslation("AON_ALL"))
codeVect!.add("1")
descVect!.add(str(ars_params.age_per_days_1)+days$)
codeVect!.add("2")
descVect!.add(str(ars_params.age_per_days_2)+days$)
codeVect!.add("3")
descVect!.add(str(ars_params.age_per_days_3)+days$)
codeVect!.add("4")
descVect!.add(str(ars_params.age_per_days_4)+"+"+days$)

ldat$=func.buildListButtonList(descVect!,codeVect!)
callpoint!.setTableColumnAttribute("ARR_STATEMENTS.PICK_PER","LDAT",ldat$)
periodList!=callpoint!.getControl("ARR_STATEMENTS.PICK_PER")
periodList!.removeAllItems()
periodList!.insertItems(0,descVect!)
periodList!.selectIndex(0)

rem --- default age_by (report_type) based on AR params
callpoint!.setColumnData("ARR_STATEMENTS.REPORT_TYPE",iff(cvs(ars_params.dflt_age_by$,2)="","I",ars_params.dflt_age_by$),1)

[[ARR_STATEMENTS.REPORT_OPTION.AVAL]]
rem --- enable/disable

	seq$=callpoint!.getColumnData("ARR_STATEMENTS.REPORT_SEQUENCE")
	option$=callpoint!.getUserInput()

	gosub enable_disable_fields

[[ARR_STATEMENTS.REPORT_SEQUENCE.AVAL]]
rem --- enable/disable

	option$=callpoint!.getColumnData("ARR_STATEMENTS.REPORT_OPTION")
	seq$=callpoint!.getUserInput()

	gosub enable_disable_fields

[[ARR_STATEMENTS.<CUSTOM>]]
rem ====================================================
enable_disable_fields:
rem --- enable/disable fields based on selected option (All, Restart, Single)
rem --- and selected sequence (Customer, Alt seq)
rem --- incoming: seq$ and option$
rem ====================================================
	if option$="R"
		if seq$="C"
			callpoint!.setColumnEnabled("ARR_STATEMENTS.CUSTOMER_ID",1)
			callpoint!.setColumnEnabled("ARR_STATEMENTS.ALT_SEQUENCE",0)	
		else
			callpoint!.setColumnEnabled("ARR_STATEMENTS.CUSTOMER_ID",0)
			callpoint!.setColumnEnabled("ARR_STATEMENTS.ALT_SEQUENCE",1)	
		endif
		callpoint!.setColumnEnabled("ARR_STATEMENTS.REPORT_SEQUENCE",1)	
	endif
	if cvs(option$,2)=""
		callpoint!.setColumnEnabled("ARR_STATEMENTS.CUSTOMER_ID",0)
		callpoint!.setColumnEnabled("ARR_STATEMENTS.ALT_SEQUENCE",0)	
		callpoint!.setColumnEnabled("ARR_STATEMENTS.REPORT_SEQUENCE",1)
	endif
	if option$="S"
		callpoint!.setColumnEnabled("ARR_STATEMENTS.CUSTOMER_ID",1)
		callpoint!.setColumnEnabled("ARR_STATEMENTS.ALT_SEQUENCE",0)	
		callpoint!.setColumnEnabled("ARR_STATEMENTS.REPORT_SEQUENCE",0)
		callpoint!.setColumnData("ARR_STATEMENTS.REPORT_SEQUENCE","C",1)
	endif

	return

#include [+ADDON_LIB]std_missing_params.aon



