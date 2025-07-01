[[ARS_CUSTDFLT.AREC]]
rem --- Initialize new record

	if callpoint!.getDevObject("cm_installed")="Y" then
		hold_new$=callpoint!.getDevObject("hold_new")
		callpoint!.setColumnData("ARS_CUSTDFLT.CRED_HOLD",hold_new$)
	else
		callpoint!.setColumnData("ARS_CUSTDFLT.CRED_HOLD","N")
	endif

	callpoint!.setColumnData("ARS_CUSTDFLT.INV_HIST_FLG","Y")

[[ARS_CUSTDFLT.AR_CYCLECODE.AVAL]]
rem --- Don't allow inactive code
	armCycleCode_dev=fnget_dev("ARM_CYCLECOD")
	dim armCycleCode$:fnget_tpl$("ARM_CYCLECOD")
	ar_cyclecode$=callpoint!.getUserInput()
	read record(armCycleCode_dev,key=firm_id$+"A"+ar_cyclecode$,dom=*next)armCycleCode$
	if armCycleCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(armCycleCode.ar_cyclecode$,3)
		msg_tokens$[2]=cvs(armCycleCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.AR_DIST_CODE.AVAL]]
rem --- Don't allow inactive code
	arcDistCode_dev=fnget_dev("ARC_DISTCODE")
	dim arcDistCode$:fnget_tpl$("ARC_DISTCODE")
	ar_dist_code$=callpoint!.getUserInput()
	read record(arcDistCode_dev,key=firm_id$+"D"+ar_dist_code$,dom=*next)arcDistCode$
	if arcDistCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcDistCode.ar_dist_code$,3)
		msg_tokens$[2]=cvs(arcDistCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.AR_TERMS_CODE.AVAL]]
rem --- Don't allow inactive code
	arc_termcode_dev=fnget_dev("ARC_TERMCODE")
	dim arm10a$:fnget_tpl$("ARC_TERMCODE")
	ar_terms_code$=callpoint!.getUserInput()
	read record(arc_termcode_dev,key=firm_id$+"A"+ar_terms_code$,dom=*next)arm10a$
	if arm10a.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arm10a.ar_terms_code$,3)
		msg_tokens$[2]=cvs(arm10a.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.AWIN]]
rem --- Get AR parameters

	num_files=10
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="ARS_CREDIT",open_opts$[2]="OTA"
	open_tables$[3]="ARC_CUSTTYPE",open_opts$[3]="OTA"
	open_tables$[4]="ARC_DISTCODE",open_opts$[4]="OTA"
	open_tables$[5]="ARC_SALECODE",open_opts$[5]="OTA"
	open_tables$[6]="ARC_TERMCODE",open_opts$[6]="OTA"
	open_tables$[7]="ARC_TERRCODE",open_opts$[7]="OTA"
	open_tables$[8]="ARM_CYCLECOD",open_opts$[8]="OTA"
	open_tables$[9]="OPC_DISCCODE",open_opts$[9]="OTA"
	open_tables$[10]="OPC_MESSAGE",open_opts$[10]="OTA"

	gosub open_tables

	ars01a_dev=num(open_chans$[1]);dim ars01a$:open_tpls$[1]
	ars01c_dev=num(open_chans$[2]);dim ars01c$:open_tpls$[2]

rem --- Check to see if main AR param rec (firm/AR/00) exists; if not, tell user to set it up first

	ars01a_key$=firm_id$+"AR00"
	find record (ars01a_dev,key=ars01a_key$,err=*next) ars01a$
	if cvs(ars01a.current_per$,2)=""
		msg_id$="AR_PARAM_ERR"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		gosub remove_process_bar
		release
	endif

rem --- Get Credit Management parameters

	ars01c_key$=firm_id$+"AR01"
	find record (ars01c_dev,key=ars01c_key$,err=*next) ars01c$
	callpoint!.setDevObject("cm_installed",ars01c.sys_install$)
	callpoint!.setDevObject("hold_new",ars01c.hold_new$)

[[ARS_CUSTDFLT.BSHO]]
rem --- Determine if optional modules are installed

	call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
	op$=info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","SA",info$[all]
	sa$=info$[20]

rem --- Disable fields that require OP

	if op$<>"Y" then
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.FRT_TERMS",-1)
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.MESSAGE_CODE",-1)
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.PRICING_CODE",-1)
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.SA_FLAG",-1)
	endif

	rem --- Detail invoice history is always retained now, so disable that check box.
	callpoint!.setColumnEnabled("ARS_CUSTDFLT.INV_HIST_FLG",-1)

rem --- Disable fields that require SA

	if sa$<>"Y" then
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.SA_FLAG",-1)
	endif

rem --- Check Credit Management parameters

	if callpoint!.getDevObject("cm_installed")="Y" then
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.CREDIT_LIMIT",-1)
	else
		callpoint!.setColumnEnabled("ARS_CUSTDFLT.CRED_HOLD",-1)
	endif

[[ARS_CUSTDFLT.CUSTOMER_TYPE.AVAL]]
rem --- Don't allow inactive code
	arcCustType_dev=fnget_dev("ARC_CUSTTYPE")
	dim arcCustType$:fnget_tpl$("ARC_CUSTTYPE")
	customer_type$=callpoint!.getUserInput()
	read record(arcCustType_dev,key=firm_id$+"L"+customer_type$,dom=*next)arcCustType$
	if arcCustType.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcCustType.customer_type$,3)
		msg_tokens$[2]=cvs(arcCustType.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.DISC_CODE.AVAL]]
rem --- Don't allow inactive code
	opcDiscCode_dev=fnget_dev("OPC_DISCCODE")
	dim opcDiscCode$:fnget_tpl$("OPC_DISCCODE")
	disc_code$=callpoint!.getUserInput()
	read record(opcDiscCode_dev,key=firm_id$+disc_code$,dom=*next)opcDiscCode$
	if opcDiscCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcDiscCode.disc_code$,3)
		msg_tokens$[2]=cvs(opcDiscCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.MESSAGE_CODE.AVAL]]
rem --- Don't allow inactive code
	opcMessage_dev=fnget_dev("OPC_MESSAGE")
	dim opcMessage$:fnget_tpl$("OPC_MESSAGE")
	message_code$=callpoint!.getUserInput()
	read record(opcMessage_dev,key=firm_id$+message_code$,dom=*next)opcMessage$
	if opcMessage.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcMessage.message_code$,3)
		msg_tokens$[2]=cvs(opcMessage.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.SLSPSN_CODE.AVAL]]
rem --- Don't allow inactive code
	arcSaleCode_dev=fnget_dev("ARC_SALECODE")
	dim arcSaleCode$:fnget_tpl$("ARC_SALECODE")
	slspsn_code$=callpoint!.getUserInput()
	read record(arcSaleCode_dev,key=firm_id$+"F"+slspsn_code$,dom=*next)arcSaleCode$
	if arcSaleCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcSaleCode.slspsn_code$,3)
		msg_tokens$[2]=cvs(arcSaleCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.TERRITORY.AVAL]]
rem --- Don't allow inactive code
	arcTerrCode_dev=fnget_dev("ARC_TERRCODE")
	dim arcTerrCode$:fnget_tpl$("ARC_TERRCODE")
	territory$=callpoint!.getUserInput()
	read record(arcTerrCode_dev,key=firm_id$+"H"+territory$,dom=*next)arcTerrCode$
	if arcTerrCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcTerrCode.territory$,3)
		msg_tokens$[2]=cvs(arcTerrCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARS_CUSTDFLT.<CUSTOM>]]
remove_process_bar:

bbjAPI!=bbjAPI()
rdFuncSpace!=bbjAPI!.getGroupNamespace()
rdFuncSpace!.setValue("+build_task","OFF")

return



