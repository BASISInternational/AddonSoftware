[[APM_CCVEND.AREC]]
rem --- Initialize CREDITCARD_ID to start with the letter "C"
	callpoint!.setColumnData("APM_CCVEND.CREDITCARD_ID","C",1)

[[APM_CCVEND.AWIN]]
rem --- Inits
	use ::ado_func.src::func

[[APM_CCVEND.BDEL]]
rem --- Record cannot be deleted if the CREDITCARD_ID is in APE_INVOICEHDR
	gosub checkIfActive

	if ccID_active$="Y" then
		callpoint!.setColumnData("APM_CCVEND.CODE_INACTIVE","N",1)
		callpoint!.setStatus("ABORT")
	endif

[[APM_CCVEND.BSHO]]
rem --- Open needed files
	num_files=4
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	
	open_tables$[1]="APE_INVOICEHDR",  open_opts$[1]="OTA"
	open_tables$[2]="APM_VENDMAST",  open_opts$[2]="OTA"
	open_tables$[3]="APM_VENDHIST",  open_opts$[3]="OTA"
	open_tables$[4]="APC_TYPECODE",  open_opts$[4]="OTA"

	gosub open_tables

[[APM_CCVEND.CC_APTYPE.AVAL]]
rem --- Don't allow inactive code
	apcTypeCode_dev=fnget_dev("APC_TYPECODE")
	dim apcTypeCode$:fnget_tpl$("APC_TYPECODE")
	ap_type$=callpoint!.getUserInput()
	read record(apcTypeCode_dev,key=firm_id$+"A"+ap_type$,dom=*next)apcTypeCode$
	if apcTypeCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcTypeCode.ap_type$,3)
		msg_tokens$[2]=cvs(apcTypeCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[APM_CCVEND.CC_VENDOR.AVAL]]
rem --- Entered CC_VENDOR cannot be inactive.
	vendor$=callpoint!.getUserInput()
	apmVendMast_dev=fnget_dev("APM_VENDMAST")
	dim apmVendMast$:fnget_tpl$("APM_VENDMAST")
	findrecord(apmVendMast_dev,key=firm_id$+vendor$,dom=*next)apmVendMast$
	if apmVendMast.vend_inactive$="Y" then
		call stbl("+DIR_PGM")+"adc_getmask.aon","VENDOR_ID","","","",m0$,0,vendor_size
		msg_id$="AP_VEND_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=fnmask$(apmVendMast.vendor_id$(1,vendor_size),m0$)
		msg_tokens$[2]=cvs(apmVendMast.vendor_name$,2)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Entered CC_VENDOR must be for the entered CC_APTYPE.
	cc_aptype$=callpoint!.getColumnData("APM_CCVEND.CC_APTYPE")
	apmVendHist_dev=fnget_dev("APM_VENDHIST")
	goodVendor=0
	read(apmVendHist_dev,key=firm_id$+vendor$+cc_aptype$,dom=*next); goodVendor=1
	if !goodVendor then
		msg_id$="AP_VEND_BAD_APTYPE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[APM_CCVEND.CC_VENDOR.BINP]]
rem --- CC_APTYEP must be entered before CC_VENDOR
	if cvs(callpoint!.getColumnData("APM_CCVEND.CC_APTYPE"),2)="" then callpoint!.setFocus("APM_CCVEND.CC_APTYPE",1)

[[APM_CCVEND.CC_VENDOR.BINQ]]
rem --- In lookup only show vendors of given AP Type
	dim filter_defs$[2,2]
	filter_defs$[0,0]="APM_VENDMAST.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="APM_VENDHIST.AP_TYPE"
	filter_defs$[1,1]="='"+callpoint!.getColumnData("APM_CCVEND.CC_APTYPE")+"'"
	filter_defs$[1,2]="LOCK"

	call STBL("+DIR_SYP")+"bax_query.bbj",
:		gui_dev, 
:		form!,
:		"AP_VEND_LK",
:		"DEFAULT",
:		table_chans$[all],
:		sel_key$,
:		filter_defs$[all]

	if sel_key$<>""
		call stbl("+DIR_SYP")+"bac_key_template.bbj",
:			"APM_VENDMAST",
:			"PRIMARY",
:			apm_vend_key$,
:			table_chans$[all],
:			status$
		dim apm_vend_key$:apm_vend_key$
		apm_vend_key$=sel_key$
		callpoint!.setColumnData("APM_CCVEND.CC_VENDOR",apm_vend_key.vendor_id$,1)
	endif	
	callpoint!.setStatus("ACTIVATE-ABORT")

[[APM_CCVEND.CODE_INACTIVE.AVAL]]
rem --- Record cannot be marked inactive if the CREDITCARD_ID is in APE_INVOICEHDR
	inactive$=callpoint!.getUserInput()
	if inactive$="Y" then
		gosub checkIfActive

		if ccID_active$="Y" then
			callpoint!.setColumnData("APM_CCVEND.CODE_INACTIVE","N",1)
			callpoint!.setStatus("ABORT")
		endif
	endif

[[APM_CCVEND.CREDITCARD_ID.AVAL]]
rem --- Force CREDITCARD_ID entry to start with the letter "C"
	ccID$=callpoint!.getUserInput()
	if ccID$(1,1)<>"C" then
		if len(ccID$)=7 then
			msg_id$="AP_CC_ID"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		else
			callpoint!.setUserInput("C"+ccID$)
		endif
	endif

[[APM_CCVEND.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon

checkIfActive: rem --- Ceck if the CREDITCARD_ID is currently active in APE_INVOICEHDR
	ccID_active$="N"
	ccID$=callpoint!.getColumnData("APM_CCVEND.CREDITCARD_ID")
	apeInvoiceHdr_dev=fnget_dev("APE_INVOICEHDR")
	dim apeInvoiceHdr$:fnget_tpl$("APE_INVOICEHDR")
	read(apeInvoiceHdr_dev,key=firm_id$,dom=*next)
	while 1
		readrecord(apeInvoiceHdr_dev,end=*break)apeInvoiceHdr$
		if apeInvoiceHdr.firm_id$<>firm_id$ then break
		if apeInvoiceHdr.creditcard_id$<>ccID$ then continue

		msg_id$="AP_CCID_ACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=ccID$
		msg_tokens$[2]=apeInvoiceHdr.ap_inv_no$
		gosub disp_message
		ccID_active$="Y"
		break
	wend

	return



