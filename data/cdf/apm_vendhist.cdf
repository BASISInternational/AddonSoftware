[[APM_VENDHIST.ADIS]]
rem --- Enable/disable 1099 Type ListButton
irs1099!=callpoint!.getControl("APM_VENDHIST.IRS1099_TYPE_BOX")
if callpoint!.getDevObject("vendor_1099")="Y" then
	irs1099!.setEnabled(1)
else
	irs1099!.setEnabled(0)
endif

rem --- Enable/disable Edit History option
if callpoint!.getDevObject("vendor_1099")="Y" and callpoint!.getColumnData("APM_VENDHIST.IRS1099_TYPE_BOX")<>"X" then
	callpoint!.setOptionEnabled("EDIT",1)	
else
	callpoint!.setOptionEnabled("EDIT",0)
endif

rem --- Disable editable Purchase History fields
callpoint!.setColumnEnabled("APM_VENDHIST.YTD_PURCH",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PYR_PURCH",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NYR_PURCH",0)
callpoint!.setColumnEnabled("APM_VENDHIST.YTD_DISCS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PRI_YR_DISCS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NYR_DISC",0)
callpoint!.setColumnEnabled("APM_VENDHIST.YTD_PAYMENTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PYR_PAYMENTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NYR_PAYMENTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.CUR_CAL_PMTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PRI_CAL_PMT",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NXT_CYR_PMTS",0)

[[APM_VENDHIST.AENA]]
rem --- see if interfacing to GL
	call stbl("+DIR_PGM")+"adc_application.aon","AP",info$[all]
	gl$=info$[9];rem --- gl interface?

if gl$<>"Y"
	ctl_name$="APM_VENDHIST.GL_ACCOUNT"
	ctl_stat$="I"
	gosub disable_fields
endif

[[APM_VENDHIST.AFMC]]
rem --- Show fiscal year in field prompts
apCurrentFiscalYr$=callpoint!.getDevObject("apCurrentFiscalYr")
apPriorFiscalYr$=str(num(apCurrentFiscalYr$)-1)
apNextFiscalYr$=str(num(apCurrentFiscalYr$)+1)
callpoint!.setTableColumnAttribute("APM_VENDHIST.YTD_PURCH","PROM",apCurrentFiscalYr$+" Fiscal YTD Purchases")
callpoint!.setTableColumnAttribute("APM_VENDHIST.PYR_PURCH","PROM",apPriorFiscalYr$+" Fiscal Year Purchases")
callpoint!.setTableColumnAttribute("APM_VENDHIST.NYR_PURCH","PROM",apNextFiscalYr$+" Fiscal Year Purchases")
callpoint!.setTableColumnAttribute("APM_VENDHIST.YTD_DISCS","PROM",apCurrentFiscalYr$+" Fiscal YTD Discounts")
callpoint!.setTableColumnAttribute("APM_VENDHIST.PRI_YR_DISCS","PROM",apPriorFiscalYr$+" Fiscal Year Discounts")
callpoint!.setTableColumnAttribute("APM_VENDHIST.NYR_DISC","PROM",apNextFiscalYr$+" Fiscal Year Discounts")
callpoint!.setTableColumnAttribute("APM_VENDHIST.YTD_PAYMENTS","PROM",apCurrentFiscalYr$+" Fiscal YTD Payments")
callpoint!.setTableColumnAttribute("APM_VENDHIST.PYR_PAYMENTS","PROM",apPriorFiscalYr$+" Fiscal Year Payments")
callpoint!.setTableColumnAttribute("APM_VENDHIST.NYR_PAYMENTS","PROM",apNextFiscalYr$+" Fiscal Year Payments")

rem --- Show 1099 calendar year in field prompts
current1099Yr$=callpoint!.getDevObject("current1099Yr")
prior1099Yr$=str(num(current1099Yr$)-1)
next1099Yr$=str(num(current1099Yr$)+1)
callpoint!.setTableColumnAttribute("APM_VENDHIST.CUR_CAL_PMTS","PROM",current1099Yr$+" Calendar YTD Payments")
callpoint!.setTableColumnAttribute("APM_VENDHIST.PRI_CAL_PMT","PROM",prior1099Yr$+" Calendar Year Payments")
callpoint!.setTableColumnAttribute("APM_VENDHIST.NXT_CYR_PMTS","PROM",next1099Yr$+" Calendar Year Payments")

[[APM_VENDHIST.AOPT-EDIT]]
rem --- For IRS 1099 forms, allow updating Purchase History when password entered
if callpoint!.getDevObject("vendor_1099")="Y" and callpoint!.getColumnData("APM_VENDHIST.IRS1099_TYPE_BOX")<>"X" then
	if callpoint!.isEditMode()=0 then
		msg_id$="AD_EDIT_MODE_REQUIRE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

	msg_id$="AP_EDIT_PURCH_HIST"
	gosub disp_message
	if pos("PASSVALID"=msg_opt$)<>0
		rem --- Enable editable Purchase History fields
		callpoint!.setColumnEnabled("APM_VENDHIST.YTD_PURCH",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.PYR_PURCH",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.NYR_PURCH",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.YTD_DISCS",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.PRI_YR_DISCS",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.NYR_DISC",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.YTD_PAYMENTS",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.PYR_PAYMENTS",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.NYR_PAYMENTS",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.CUR_CAL_PMTS",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.PRI_CAL_PMT",1)
		callpoint!.setColumnEnabled("APM_VENDHIST.NXT_CYR_PMTS",1)
	endif
endif

[[APM_VENDHIST.AP_DIST_CODE.AVAL]]
rem --- Don't allow inactive code
	apcDistribution_dev=fnget_dev("APC_DISTRIBUTION")
	dim apcDistribution$:fnget_tpl$("APC_DISTRIBUTION")
	ap_dist_code$=callpoint!.getUserInput()
	read record(apcDistribution_dev,key=firm_id$+"B"+ap_dist_code$,dom=*next)apcDistribution$
	if apcDistribution.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcDistribution.ap_dist_code$,3)
		msg_tokens$[2]=cvs(apcDistribution.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[APM_VENDHIST.AP_TERMS_CODE.AVAL]]
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

[[APM_VENDHIST.AP_TYPE.AVAL]]
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

[[APM_VENDHIST.ARAR]]
rem --- Get correct Open Invoice amount

	apt_invhdr=fnget_dev("APT_INVOICEHDR")
	dim apt_invhdr$:fnget_tpl$("APT_INVOICEHDR")
	apt_invdet=fnget_dev("APT_INVOICEDET")
	dim apt_invdet$:fnget_tpl$("APT_INVOICEDET")
	vendor_id$=callpoint!.getColumnData("APM_VENDHIST.VENDOR_ID")
	ap_type$=callpoint!.getColumnData("APM_VENDHIST.AP_TYPE")
	open_invs=0

rem --- Main process

	read(apt_invhdr,key=firm_id$+ap_type$+vendor_id$,dom=*next)
	while 1
		read record (apt_invhdr,end=*break) apt_invhdr$
		if pos(firm_id$+ap_type$+vendor_id$=apt_invhdr$)<>1 break
		open_invs=open_invs+apt_invhdr.invoice_amt
		hdr_key$=firm_id$+ap_type$+vendor_id$+apt_invhdr.ap_inv_no$
		read(apt_invdet,key=hdr_key$,dom=*next)
		while 1
			read record(apt_invdet,end=*break) apt_invdet$
			if apt_invdet.firm_id$+apt_invdet.ap_type$+apt_invdet.vendor_id$+apt_invdet.ap_inv_no$<>hdr_key$ break
			open_invs=open_invs+apt_invdet.trans_amt
		wend
	wend

	callpoint!.setColumnData("APM_VENDHIST.OPEN_INVS",str(open_invs),1)

[[APM_VENDHIST.AREC]]
if user_tpl.multi_types$<>"Y" 
	callpoint!.setColumnData("APM_VENDHIST.AP_TYPE",user_tpl.dflt_ap_type$)
	callpoint!.setStatus("REFRESH")
endif

[[APM_VENDHIST.ARER]]
rem --- Enable/disable 1099 Type ListButton
irs1099!=callpoint!.getControl("APM_VENDHIST.IRS1099_TYPE_BOX")
if callpoint!.getDevObject("vendor_1099")="Y" then
	irs1099!.setEnabled(1)
else
	irs1099!.setEnabled(0)
endif

rem --- Initialize 1099 Type ListButton
callpoint!.setColumnData("APM_VENDHIST.IRS1099_TYPE_BOX","X",1)

rem --- Disable Edit History option
callpoint!.setOptionEnabled("EDIT",0)	

rem --- Disable editable Purchase History fields
callpoint!.setColumnEnabled("APM_VENDHIST.YTD_PURCH",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PYR_PURCH",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NYR_PURCH",0)
callpoint!.setColumnEnabled("APM_VENDHIST.YTD_DISCS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PRI_YR_DISCS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NYR_DISC",0)
callpoint!.setColumnEnabled("APM_VENDHIST.YTD_PAYMENTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PYR_PAYMENTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NYR_PAYMENTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.CUR_CAL_PMTS",0)
callpoint!.setColumnEnabled("APM_VENDHIST.PRI_CAL_PMT",0)
callpoint!.setColumnEnabled("APM_VENDHIST.NXT_CYR_PMTS",0)

[[APM_VENDHIST.ARNF]]
rem --- initialize new record

	apc_typecode=fnget_dev("APC_TYPECODE")
	dim apc_typecode$:fnget_tpl$("APC_TYPECODE")
	read record (apc_typecode,key=firm_id$+"A"+callpoint!.getColumnData("APM_VENDHIST.AP_TYPE"),dom=*next)apc_typecode$

	if user_tpl.multi_dist$<>"Y"
		ap_dist_code$=callpoint!.getDevObject("aps_single_dist_code")
	else
		ap_dist_code$=apc_typecode.ap_dist_code$
	endif

	callpoint!.setColumnData("APM_VENDHIST.AP_DIST_CODE",ap_dist_code$,1)
	callpoint!.setColumnData("APM_VENDHIST.PAYMENT_GRP",apc_typecode.payment_grp$,1)
	callpoint!.setColumnData("APM_VENDHIST.AP_TERMS_CODE",apc_typecode.ap_terms_code$,1)
	callpoint!.setColumnData("APM_VENDHIST.GL_ACCOUNT",apc_typecode.gl_account$,1)
	if callpoint!.getDevObject("vendor_1099")="Y" then
		callpoint!.setColumnData("APM_VENDHIST.IRS1099_TYPE_BOX",apc_typecode.irs1099_type_box$,1)
	else
		callpoint!.setColumnData("APM_VENDHIST.IRS1099_TYPE_BOX","X",1)
	endif

	callpoint!.setStatus("MODIFIED")

[[APM_VENDHIST.BDEL]]
rem --- disallow deletion of apm-02 if any of the buckets are non-zero, or if referenced in apt-01 (open invoices)

can_delete$=""

if num(callpoint!.getColumnData("APM_VENDHIST.OPEN_INVS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.OPEN_RET"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.YTD_PURCH"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.PYR_PURCH"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.NYR_PURCH"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.YTD_DISCS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.PRI_YR_DISCS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.NYR_DISC"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.YTD_PAYMENTS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.PYR_PAYMENTS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.NYR_PAYMENTS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.CUR_CAL_PMTS"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.PRI_CAL_PMT"))<>0 or
:	num(callpoint!.getColumnData("APM_VENDHIST.NXT_CYR_PMTS"))<>0
 
	can_delete$="N"

endif

if can_delete$=""
	ape01_dev=fnget_dev("APE_INVOICEHDR")
	apt01_dev=fnget_dev("APT_INVOICEHDR")

	wky$=firm_id$+callpoint!.getColumnData("APM_VENDHIST.AP_TYPE")+callpoint!.getColumnData("APM_VENDHIST.VENDOR_ID")
	wk$=""
	read(ape01_dev,key=wky$,dom=*next)
	wk$=key(ape01_dev,end=*next)
	if pos(wky$=wk$)=1 can_delete$="N"
	wk$=""
	read(apt01_dev,key=wky$,dom=*next)
	wk$=key(apt01_dev,end=*next)
	if pos(wky$=wk$)=1 can_delete$="N"		
endif

	if can_delete$=""
		rem --- Do NOT allow APM_VENDHIST record to be deleted if the ap_type+vendor is in APM_CCVEND.
		vendor_id$=callpoint!.getColumnData("APM_VENDHIST.VENDOR_ID")
		ap_type$=callpoint!.getColumnData("APM_VENDHIST.AP_TYPE")
		apmCcVend_dev=fnget_dev("APM_CCVEND")
		dim apmCcVend$:fnget_tpl$("APM_CCVEND")
		read(apmCcVend_dev,key=firm_id$+vendor_id$,knum="AO_VEND_CC",dom=*next)
		while 1
			apmCcVend_key$=key(apmCcVend_dev,end=*break)
			if pos(firm_id$+vendor_id$=apmCcVend_key$)<>1 then break
			readrecord(apmCcVend_dev)apmCcVend$
			if apmCcVend.cc_aptype$=ap_type$ then
				can_delete$="N"
				break
			endif
		wend
	endif

if can_delete$="N"
	msg_id$="AP_VEND_ACTIVE"
	gosub disp_message
	callpoint!.setStatus("ABORT")
endif

[[APM_VENDHIST.BSHO]]
if user_tpl.multi_dist$="N"
	callpoint!.setColumnEnabled("APM_VENDHIST.AP_DIST_CODE",-1)
endif

[[APM_VENDHIST.BTBL]]
rem --- Retrieve parameter data

	aps01_dev=fnget_dev("APS_PARAMS")
	dim aps01a$:fnget_tpl$("APS_PARAMS")
	aps01a_key$=firm_id$+"AP00"
	find record (aps01_dev,key=aps01a_key$,err=std_missing_params) aps01a$ 

rem -- store info needed for validation, etc., in user_tpl$
	dim user_tpl$:"multi_types:c(1),multi_dist:c(1),ret_flag:c(1),dflt_ap_type:c(2),dflt_dist_code:c(2)"
	user_tpl.multi_types$=aps01a.multi_types$
	user_tpl.multi_dist$=aps01a.multi_dist$
	user_tpl.ret_flag$=aps01a.ret_flag$
 	user_tpl.dflt_ap_type$=aps01a.ap_type$
	user_tpl.dflt_dist_code$=aps01a.ap_dist_code$

rem --- if not using multi AP types, disable access to AP Type and get default distribution code

	if user_tpl.multi_types$<>"Y"
		callpoint!.setTableColumnAttribute("APM_VENDHIST.AP_TYPE","PVAL",$22$+user_tpl.dflt_ap_type$+$22$)

		rem --- get default distribution code	
		apc_typecode_dev=fnget_dev("APC_TYPECODE")
		dim apc_typecode$:fnget_tpl$("APC_TYPECODE")
		find record (apc_typecode_dev,key=firm_id$+"A"+user_tpl.dflt_ap_type$,err=*next)apc_typecode$
		if cvs(apc_typecode$,2)<>""
			user_tpl.dflt_dist_code$=apc_typecode.ap_dist_code$
		endif

		rem --- if not using multi distribution codes, initialize and disable Distribution Code
		if user_tpl.multi_dist$<>"Y"
			callpoint!.setTableColumnAttribute("APM_VENDHIST.AP_DIST_CODE","PVAL",$22$+user_tpl.dflt_dist_code$+$22$)
		endif
	endif

[[APM_VENDHIST.GL_ACCOUNT.AVAL]]
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*break) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE-ABORT")
   endif

[[APM_VENDHIST.PAYMENT_GRP.AVAL]]
rem --- Don't allow inactive code
	apcPaymentGroup_dev=fnget_dev("APC_PAYMENTGROUP")
	dim apcPaymentGroup$:fnget_tpl$("APC_PAYMENTGROUP")
	payment_grp$=callpoint!.getUserInput()
	read record(apcPaymentGroup_dev,key=firm_id$+"D"+payment_grp$,dom=*next)apcPaymentGroup$
	if apcPaymentGroup.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcPaymentGroup.payment_grp$,3)
		msg_tokens$[2]=cvs(apcPaymentGroup.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[APM_VENDHIST.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon
disable_fields:
	rem --- used to disable/enable controls depending on parameter settings
	rem --- send in control to toggle (format "ALIAS.CONTROL_NAME"), and D or space to disable/enable

	wctl$=str(num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI")):"00000")
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)=ctl_stat$
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP-REFRESH-ACTIVATE")

return

display_default_rec:

	apm_vendhist_dev=fnget_dev("APM_VENDHIST")
	dim apm_vendhist_tpl$:fnget_tpl$("APM_VENDHIST")
	while 1
		readrecord(apm_vendhist_dev,key=firm_id$+
:			callpoint!.getColumnData("APM_VENDHIST.VENDOR_ID")+
:			user_tpl.dflt_ap_type$,dom=*break)apm_vendhist_tpl$
		callpoint!.setStatus("RECORD:["+firm_id$+
:			callpoint!.getColumnData("APM_VENDHIST.VENDOR_ID")+
:			user_tpl.dflt_ap_type$+"]")
		break
	wend
return

#include [+ADDON_LIB]std_missing_params.aon



