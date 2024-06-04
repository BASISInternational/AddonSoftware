[[CRM_CUSTMAST.ARER]]
callpoint!.setColumnData("CRM_CUSTDET.INV_HIST_FLG","Y")

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
	files=4,begfile=1,endfile=files
	dim files$[files],options$[files],chans$[files],templates$[files]
	files$[1]="ARC_CUSTTYPE",options$[1]="OTA"
	files$[2]="ARC_DISTCODE",options$[2]="OTA"
	files$[3]="ARC_SALECODE",options$[3]="OTA"
	files$[4]="ARC_TERMCODE",options$[4]="OTA"
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

[[CRM_CUSTMAST.PAY_AUTH_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
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



