[[IVE_ABCWHSE.AREC]]
rem --- Set default Warehouse
	whse$=callpoint!.getDevObject("dflt_whse")
	callpoint!.setColumnData("IVE_ABCWHSE.WAREHOUSE_ID",whse$,1)
	if callpoint!.getDevObject("multi_whse")<>"Y" then callpoint!.setColumnEnabled("IVE_ABCWHSE.WAREHOUSE_ID",0)

[[IVE_ABCWHSE.BSHO]]
rem --- Open needed tables
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"
	gosub open_tables

rem --- Get multiple warehouse flag and default warehouse
	ivs01_dev=num(open_chans$[1])
	dim ivs01a$:open_tpls$[1]
	read record (ivs01_dev,key=firm_id$+"IV00")ivs01a$
	callpoint!.setDevObject("multi_whse",ivs01a.multi_whse$)
	callpoint!.setDevObject("dflt_whse",ivs01a.warehouse_id$)

[[IVE_ABCWHSE.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[IVE_ABCWHSE.WAREHOUSE_ID.AVAL]]
rem --- Don't allow inactive code
	ivcWhseCode_dev=fnget_dev("IVC_WHSECODE")
	dim ivcWhseCode$:fnget_tpl$("IVC_WHSECODE")
	whse_code$=callpoint!.getUserInput()
	read record (ivcWhseCode_dev,key=firm_id$+"C"+whse_code$,dom=*next)ivcWhseCode$
	if ivcWhseCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



