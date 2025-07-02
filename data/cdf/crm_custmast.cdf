[[CRM_CUSTMAST.ARER]]
callpoint!.setColumnData("CRM_CUSTDET.INV_HIST_FLG","Y")

[[CRM_CUSTDET.AR_CYCLECODE.AVAL]]
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

[[CRM_CUSTDET.AR_DIST_CODE.AVAL]]
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

[[CRM_CUSTDET.AR_TERMS_CODE.AVAL]]
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

[[CRM_CUSTMAST.BSHO]]
rem  Initializations
	use ::ado_util.src::util

rem --- Open/Lock files
	files=10,begfile=1,endfile=files
	dim files$[files],options$[files],chans$[files],templates$[files]
	files$[1]="ARC_CUSTTYPE",options$[1]="OTA"
	files$[2]="ARC_DISTCODE",options$[2]="OTA"
	files$[3]="ARC_SALECODE",options$[3]="OTA"
	files$[4]="ARC_TERMCODE",options$[4]="OTA"
	files$[5]="ARC_TERRCODE",options$[5]="OTA"
	files$[6]="ARM_CYCLECOD",options$[6]="OTA"
	files$[7]="OPC_DISCCODE",options$[7]="OTA"
	files$[8]="OPC_MESSAGE",options$[8]="OTA"
	files$[9]="OPC_PRICECDS",options$[9]="OTA"
	files$[10]="OPC_TAXCODE",options$[10]="OTA"
	call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:       	chans$[all],templates$[all],table_chans$[all],batch,status$
	if status$<>"" then
		remove_process_bar:
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif

[[CRM_CUSTDET.CUSTOMER_TYPE.AVAL]]
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

[[CRM_CUSTDET.DISC_CODE.AVAL]]
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

[[CRM_CUSTDET.MESSAGE_CODE.AVAL]]
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

[[CRM_CUSTMAST.PAY_AUTH_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

[[CRM_CUSTDET.PRICING_CODE.AVAL]]
rem --- Don't allow inactive code
	opcPiceCDs_dev=fnget_dev("OPC_PRICECDS")
	dim opcPiceCDs$:fnget_tpl$("OPC_PRICECDS")
	pricing_code$=callpoint!.getUserInput()
	read record(opcPiceCDs_dev,key=firm_id$+pricing_code$,dom=*next)opcPiceCDs$
	if opcPiceCDs.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcPiceCDs.pricing_code$,3)
		msg_tokens$[2]=cvs(opcPiceCDs.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[CRM_CUSTMAST.SHIPPING_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

[[CRM_CUSTDET.SLSPSN_CODE.AVAL]]
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

[[CRM_CUSTDET.TAX_CODE.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	tax_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+tax_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[CRM_CUSTDET.TERRITORY.AVAL]]
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



