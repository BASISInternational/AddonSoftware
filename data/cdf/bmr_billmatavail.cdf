[[BMR_BILLMATAVAIL.AREC]]
rem --- Initialize warehouse
	def_wh$=callpoint!.getDevObject("def_wh")
	callpoint!.setColumnData("BMR_BILLMATAVAIL.WAREHOUSE_ID",def_wh$)
	if callpoint!.getDevObject("multi_wh")<>"Y" then callpoint!.setColumnEnabled("BMR_BILLMATAVAIL.WAREHOUSE_ID",0)

[[BMR_BILLMATAVAIL.BFMC]]
rem --- Set Custom Query for BOM Item Number

	callpoint!.setTableColumnAttribute("BMR_BILLMATAVAIL.BILL_NO", "IDEF", "BOM_LOOKUP")

[[BMR_BILLMATAVAIL.BILL_NO.AVAL]]
rem --- Validate against BOM_BILLMAST

	bmm_billmast=fnget_dev("BMM_BILLMAST")
	found=0
	bill$=callpoint!.getUserInput()
	while 1
		find (bmm_billmast,key=firm_id$+bill$,dom=*break)
		found=1
		break
	wend

	if found=0 and cvs(bill$,3)<>""
		msg_id$="INPUT_ERR_DATA"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[BMR_BILLMATAVAIL.BSHO]]
rem --- Open tables

	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="BMM_BILLMAST",open_opts$[1]="OTA"
	open_tables$[2]="IVS_PARAMS",open_opts$[2]="OTA"
	gosub open_tables

rem --- Get multiple warehouse flag and default warehouse
	ivs01_dev=num(open_chans$[2])
	dim ivs01a$:open_tpls$[2]
	read record (ivs01_dev,key=firm_id$+"IV00",dom=std_missing_params)ivs01a$
	callpoint!.setDevObject("multi_wh",ivs01a.multi_whse$)
	callpoint!.setDevObject("def_wh",ivs01a.warehouse_id$)

[[BMR_BILLMATAVAIL.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



