[[BMU_IVCOSTING.AREC]]
rem --- Set default Warehouse
			
	whse$=callpoint!.getDevObject("dflt_whse")
	callpoint!.setColumnData("BMU_IVCOSTING.WAREHOUSE_ID",whse$,1)

[[BMR_COSTING.AREC]]
rem --- Set default Warehouse

	whse$=callpoint!.getDevObject("dflt_whse")
	callpoint!.setColumnData("BMR_COSTING.WAREHOUSE_ID",whse$,1)

[[BMU_IVCOSTING.ASVA]]
rem --- Warning to run IV Valuation Report and the IV Costing Report

	msg_id$="BM_RUN_VALUATION"
	dim msg_tokens$[1]
	msg_opt$=""
	gosub disp_message
	if msg_opt$<>"Y"
		callpoint!.setStatus("EXIT")
	endif

[[BMU_IVCOSTING.BILL_NO.AVAL]]
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

[[BMU_IVCOSTING.BSHO]]
rem --- Open needed tables
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="BMM_BILLMAST",open_opts$[2]="OTA"
	open_tables$[3]="BMM_BILLMAST",open_opts$[3]="OTA"
	gosub open_tables
			
	ivs01_dev=num(open_chans$[1])
	dim ivs01a$:open_tpls$[1]
		
	read record (ivs01_dev,key=firm_id$+"IV00")ivs01a$
	callpoint!.setDevObject("dflt_whse",ivs01a.warehouse_id$)

[[BMR_COSTING.BSHO]]
rem --- Open needed tables
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"
	gosub open_tables

	ivs01_dev=num(open_chans$[1])
	dim ivs01a$:open_tpls$[1]

	read record (ivs01_dev,key=firm_id$+"IV00")ivs01a$
	callpoint!.setDevObject("dflt_whse",ivs01a.warehouse_id$)

[[BMU_IVCOSTING.WAREHOUSE_ID.AVAL]]
rem --- Don't allow inactive code
	ivcWhseCode_dev=fnget_dev("IVC_WHSECODE")
	dim ivcWhseCode$:fnget_tpl$("IVC_WHSECODE")
	whse_code$=callpoint!.getUserInput()
	read record (ivcWhseCode_dev,key=firm_id$+"C"+whse_code$,dom=*next)ivcWhseCode$
	if ivcWhseCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif



