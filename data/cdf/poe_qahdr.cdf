[[POE_QAHDR.BSHO]]
rem --- Open Files
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APC_TERMSCODE",open_opts$[1]="OTA"
	open_tables$[2]="APM_VENDADDR",open_opts$[2]="OTA"
	open_tables$[3]="IVC_WHSECODE",open_opts$[3]="OTA"

	gosub open_tables

[[POE_QAHDR.PURCH_ADDR.AVAL]]
rem --- Don't allow inactive code
	apmVendAddr_dev=fnget_dev("APM_VENDADDR")
	dim apmVendAddr$:fnget_tpl$("APM_VENDADDR")
	purch_addr$=callpoint!.getUserInput()
	vendor_id$=callpoint!.getColumnData("POE_QAHDR.VENDOR_ID")
	read record(apmVendAddr_dev,key=firm_id$+vendor_id$+purch_addr$,dom=*next)apmVendAddr$
	if apmVendAddr.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apmVendAddr.purch_addr$,3)
		msg_tokens$[2]=cvs(apmVendAddr.city$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_QAHDR.TERMS_CODE.AVAL]]
rem --- Don't allow inactive code
	apcTermsCode_dev=fnget_dev("APC_TERMSCODE")
	dim apcTermsCode$:fnget_tpl$("APC_TERMSCODE")
	ap_terms_code$=callpoint!.getUserInput()
	read record(apcTermsCode_dev,key=firm_id$+"C"+ap_terms_code$,dom=*next)apcTermsCode$
	if apcTermsCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcTermsCode.terms_codeap$,3)
		msg_tokens$[2]=cvs(apcTermsCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_QAHDR.WAREHOUSE_ID.AVAL]]
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



