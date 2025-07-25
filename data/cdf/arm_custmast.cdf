[[ARM_CUSTMAST.ADIS]]
rem --- retrieve dashboard pie or bar chart widget and refresh for current customer/balances
rem --- pie if all balances >=0, bar if any negatives, hide if all bals are 0

	rem --- test to see if widgets need to be re-created
	rem --- possible they've been destroyed if cust form was launched again from here (via Expresso or an option entry hyperlink)

	agingPieWidgetControl!=callpoint!.getDevObject("dbPieWidgetControl")
	agingBarWidgetControl!=callpoint!.getDevObject("dbBarWidgetControl")

	dim ars01a$:fnget_tpl$("ARS_PARAMS")
	ars01a$=callpoint!.getDevObject("ars01a$")
	if agingPieWidgetControl!.isDestroyed() or agingBarWidgetControl!.isDestroyed()
		gosub create_widgets
	endif

	bal_fut=num(callpoint!.getColumnData("ARM_CUSTDET.AGING_FUTURE"))
	bal_cur=num(callpoint!.getColumnData("ARM_CUSTDET.AGING_CUR"))
	bal_30=num(callpoint!.getColumnData("ARM_CUSTDET.AGING_30"))
	bal_60=num(callpoint!.getColumnData("ARM_CUSTDET.AGING_60"))
	bal_90=num(callpoint!.getColumnData("ARM_CUSTDET.AGING_90"))
	bal_120=num(callpoint!.getColumnData("ARM_CUSTDET.AGING_120"))


	if bal_fut<0 or bal_cur<0 or bal_30<0 or bal_60<0 or bal_90<0 or bal_120<0

		agingDashboardBarWidget!=callpoint!.getDevObject("dbBarWidget")
		agingBarWidget! = agingDashboardBarWidget!.getWidget()
		agingBarWidget!.setDataSetValue(Translate!.getTranslation("AON_FUT","Fut",1), "",bal_fut)
		agingBarWidget!.setDataSetValue(Translate!.getTranslation("AON_CUR","Cur",1), "", bal_cur)
		agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_1),"", bal_30)
		agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_2), "", bal_60)
		agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_3), "", bal_90)
		agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_4)+"+", "", bal_120)
		agingBarWidget!.refresh()

		agingPieWidgetControl!=callpoint!.getDevObject("dbPieWidgetControl")
		agingBarWidgetControl!=callpoint!.getDevObject("dbBarWidgetControl")	
		agingPieWidgetControl!.setVisible(0)
		agingBarWidgetControl!.setVisible(1)

	else

		days$=" "+Translate!.getTranslation("AON_DAYS","Days",1)+":"
		agingDashboardPieWidget!=callpoint!.getDevObject("dbPieWidget")
		agingPieWidget! = agingDashboardPieWidget!.getWidget()
		agingPieWidget!.setDataSetValue(Translate!.getTranslation("AON_FUTURE","Future",1), bal_fut)
		agingPieWidget!.setDataSetValue(Translate!.getTranslation("AON_CURRENT","Current",1), bal_cur)
		agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_1)+days$, bal_30 )
		agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_2)+days$, bal_60)
		agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_3)+days$, bal_90)
		agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_4)+"+"+days$, bal_120)
		agingPieWidget!.refresh()

		agingPieWidgetControl!=callpoint!.getDevObject("dbPieWidgetControl")
		agingBarWidgetControl!=callpoint!.getDevObject("dbBarWidgetControl")	
		agingPieWidgetControl!.setVisible(1)
		agingBarWidgetControl!.setVisible(0)

	endif

rem --- Draw attention when pay_auth_email doesn't match ARS_CC_CUSTPMT Report Control Recipients email-to address
	rem --- Get customer's ARS_CC_CUSTPMT Report Control Recipients email-to address
	customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	admRptCtlRcp_dev=fnget_dev("ADM_RPTCTL_RCP")
	dim admRptCtlRcp$:fnget_tpl$("ADM_RPTCTL_RCP")
	admRptCtlRcp.dd_table_alias$="ARS_CC_CUSTPMT"
	findrecord(admRptCtlRcp_dev,key=firm_id$+admRptCtlRcp.dd_table_alias$+customer_id$+admRptCtlRcp.vendor_id$,dom=*next)admRptCtlRcp$
	if cvs(admRptCtlRcp.customer_id$,3)<>"" then
		email_to$=admRptCtlRcp.email_to$
	else
		email_to$=""
	endif
	callpoint!.setDevObject("recipient_email_to",email_to$)

	rem --- Set background color for pay_auth_email
	payAuthEmail!=callpoint!.getControl("ARM_CUSTMAST.PAY_AUTH_EMAIL")

	if cvs(callpoint!.getColumnData("ARM_CUSTMAST.PAY_AUTH_EMAIL"),3)<>cvs(email_to$,3) and cvs(email_to$,3)<>"" then
		call stbl("+DIR_SYP",err=*endif)+"bac_create_color.bbj","+ENTRY_ERROR_COLOR","255,224,224",rdErrorColor!,""
		payAuthEmail!.setBackColor(rdErrorColor!)
		callpoint!.setDevObject("match_email_to","BAD")
	else
		addrLine1!=callpoint!.getControl("ARM_CUSTMAST.ADDR_LINE_1")
		payAuthEmail!.setBackColor(addrLine1!.getBackColor())
		callpoint!.setDevObject("match_email_to","OK")
	endif



	

[[ARM_CUSTMAST.AOPT-AGNG]]
rem --- Age this customer's transactions
rem --- use RECORD instead of REFRESH to make sure ADIS gets fired again, which will refresh the widget

	customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	if cvs(customer_id$,2)<>""
		rem --- Skip unless current processing date is greater than last aging date
		armCustDet_dev=fnget_dev("ARM_CUSTDET")
		dim armCustDet$:fnget_tpl$("ARM_CUSTDET")
		armCustDet.firm_id$=firm_id$
		armCustDet.customer_id$=customer_id$
		armCustDet.ar_type$=""
		readrecord(armCustDet_dev,key=armCustDet.firm_id$+armCustDet.customer_id$+armCustDet.ar_type$)armCustDet$
		if cvs(armCustDet.report_type$,2)="" then armCustDet.report_type$=iff(cvs(callpoint!.getDevObject("dflt_age_by"),2)="","I",callpoint!.getDevObject("dflt_age_by"))
		sysDate$=stbl("+SYSTEM_DATE")
		if sysDate$>armCustDet.report_date$ then
			endcust$=customer_id$
			call stbl("+DIR_PGM")+"arc_custaging.aon",customer_id$,endcust$,sysDate$,armCustDet.report_type$,status
		endif
		callpoint!.setStatus("RECORD:["+firm_id$+customer_id$+"]")
	endif

[[ARM_CUSTMAST.AOPT-CRDT]]
rem --- Launch Customer Maintenance form for this customer
	user_id$=stbl("+USER_ID")
	customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	cred_hold$=callpoint!.getColumnData("ARM_CUSTDET.CRED_HOLD")
	cred_limit$=callpoint!.getColumnData("ARM_CUSTDET.CREDIT_LIMIT")
	memo_1024$=callpoint!.getColumnData("ARM_CUSTMAST.MEMO_1024")
	callpoint!.setDevObject("cred_hold",cred_hold$)
	callpoint!.setDevObject("cred_limit",cred_limit$)
	callpoint!.setDevObject("memo_1024",memo_1024$)

	dim dflt_data$[32,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=customer_id$
	dflt_data$[2,0]="ADDR_LINE_1"
	dflt_data$[2,1]=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_1")
	dflt_data$[3,0]="ADDR_LINE_2"
	dflt_data$[3,1]=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_2")
	dflt_data$[4,0]="ADDR_LINE_3"
	dflt_data$[4,1]=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_3")
	dflt_data$[5,0]="ADDR_LINE_4"
	dflt_data$[5,1]=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_4")
	dflt_data$[6,0]="CITY"
	dflt_data$[6,1]=callpoint!.getColumnData("ARM_CUSTMAST.CITY")
	dflt_data$[7,0]="STATE_CODE"
	dflt_data$[7,1]=callpoint!.getColumnData("ARM_CUSTMAST.STATE_CODE")
	dflt_data$[8,0]="ZIP_CODE"
	dflt_data$[8,1]=callpoint!.getColumnData("ARM_CUSTMAST.ZIP_CODE")
	dflt_data$[9,0]="COUNTRY"
	dflt_data$[9,1]=callpoint!.getColumnData("ARM_CUSTMAST.COUNTRY")
	dflt_data$[10,0]="CONTACT_NAME"
	dflt_data$[10,1]=callpoint!.getColumnData("ARM_CUSTMAST.CONTACT_NAME")
	dflt_data$[11,0]="PHONE_NO"
	dflt_data$[11,1]=callpoint!.getColumnData("ARM_CUSTMAST.PHONE_NO")
	dflt_data$[12,0]="PHONE_EXTEN"
	dflt_data$[12,1]=callpoint!.getColumnData("ARM_CUSTMAST.PHONE_EXTEN")
	dflt_data$[13,0]="FAX_NO"
	dflt_data$[13,1]=callpoint!.getColumnData("ARM_CUSTMAST.FAX_NO")
	dflt_data$[14,0]="SLSPSN_CODE"
	dflt_data$[14,1]=callpoint!.getColumnData("ARM_CUSTDET.SLSPSN_CODE")
	dflt_data$[15,0]="AR_TERMS_CODE"
	dflt_data$[15,1]=callpoint!.getColumnData("ARM_CUSTDET.AR_TERMS_CODE")
	dflt_data$[16,0]="CRED_HOLD"
	dflt_data$[16,1]=cred_hold$
	dflt_data$[17,0]="AGING_FUTURE"
	dflt_data$[17,1]=callpoint!.getColumnData("ARM_CUSTDET.AGING_FUTURE")
	dflt_data$[18,0]="AGING_CUR"
	dflt_data$[18,1]=callpoint!.getColumnData("ARM_CUSTDET.AGING_CUR")
	dflt_data$[19,0]="AGING_30"
	dflt_data$[19,1]=callpoint!.getColumnData("ARM_CUSTDET.AGING_30")
	dflt_data$[20,0]="AGING_60"
	dflt_data$[20,1]=callpoint!.getColumnData("ARM_CUSTDET.AGING_60")
	dflt_data$[21,0]="AGING_90"
	dflt_data$[21,1]=callpoint!.getColumnData("ARM_CUSTDET.AGING_90")
	dflt_data$[22,0]="AGING_120"
	dflt_data$[22,1]=callpoint!.getColumnData("ARM_CUSTDET.AGING_120")
	dflt_data$[23,0]="CREDIT_LIMIT"
	dflt_data$[23,1]=cred_limit$
	dflt_data$[24,0]="REV_DATE"
	dflt_data$[24,1]=""
	dflt_data$[25,0]="ORDER_NO"
	dflt_data$[25,1]=""
	dflt_data$[26,0]="ORDER_DATE"
	dflt_data$[26,1]=""
	dflt_data$[27,0]="SHIPMNT_DATE"
	dflt_data$[27,1]=""
	dflt_data$[28,0]="AVG_DAYS"
	dflt_data$[28,1]=callpoint!.getColumnData("ARM_CUSTPMTS.AVG_DAYS")
	dflt_data$[29,0]="LSTINV_DATE"
	dflt_data$[29,1]=callpoint!.getColumnData("ARM_CUSTPMTS.LSTINV_DATE")
	dflt_data$[30,0]="LSTPAY_DATE"
	dflt_data$[30,1]=callpoint!.getColumnData("ARM_CUSTPMTS.LSTPAY_DATE")
	dflt_data$[31,0]="REPORT_DATE"
	dflt_data$[31,1]=callpoint!.getColumnData("ARM_CUSTDET.REPORT_DATE")
	dflt_data$[32,0]="REPORT_TYPE"
	dflt_data$[32,1]=callpoint!.getColumnData("ARM_CUSTDET.REPORT_TYPE")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"OPE_CREDMAINT",
:		user_id$,
:		"",
:		firm_id$+customer_id$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

rem --- Refresh data that might have been changed in Credit Maintenance
rem --- use RECORD instead of REFRESH to make sure ADIS gets fired again, which will refresh the widget,
rem --- in case user refreshed aging info from w/in credit maintenance
	callpoint!.setStatus("RECORD:["+firm_id$+customer_id$+"]")

[[ARM_CUSTMAST.AOPT-HCPY]]
rem --- Go run the Hard Copy form

	callpoint!.setDevObject("cust_id",callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID"))
	cust$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")

	dim dflt_data$[2,1]
	dflt_data$[1,0]="CUSTOMER_ID_1"
	dflt_data$[1,1]=cust$
	dflt_data$[2,0]="CUSTOMER_ID_2"
	dflt_data$[2,1]=cust$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"ARR_DETAIL",
:		stbl("+USER_ID"),
:		"MNT",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[ARM_CUSTMAST.AOPT-IDTL]]
rem Invoice Dtl Inquiry

cp_cust_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="CUSTOMER_ID"
dflt_data$[1,1]=cp_cust_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                       "ARR_INVDETAIL",
:                       user_id$,
:                   	"",
:                       "",
:                       table_chans$[all],
:                       "",
:                       dflt_data$[all]

[[ARM_CUSTMAST.AOPT-INVC]]
rem --- Show invoices

	custControl!=callpoint!.getControl("ARM_CUSTMAST.CUSTOMER_ID")
	cust_id$=custControl!.getText()

	selected_key$ = ""
	dim filter_defs$[5,2]
	filter_defs$[0,0]="OPT_INVHDR.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="OPT_INVHDR.TRANS_STATUS"
	filter_defs$[1,1]="IN ('E','R','U')"
	filter_defs$[1,2]=""
	filter_defs$[2,0]="OPT_INVHDR.AR_TYPE"
	filter_defs$[2,1]="='  '"
	filter_defs$[2,2]="LOCK"
	if cvs(cust_id$, 2) <> "" then
		filter_defs$[3,0] = "OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1] = "='" + cust_id$ + "'"
		filter_defs$[3,2]="LOCK"
	endif
	filter_defs$[4,0]="OPT_INVHDR.INVOICE_TYPE"
	filter_defs$[4,1]="NOT IN ('V','P')"
	filter_defs$[4,2]="LOCK"
	filter_defs$[5,0]="OPT_INVHDR.ORDINV_FLAG"
	filter_defs$[5,1]="='I'"
	filter_defs$[5,2]="LOCK"

	dim search_defs$[3]

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"OP_INVOICES",
:		"",
:		table_chans$[all],
:		selected_keys$,
:		filter_defs$[all],
:		search_defs$[all],
:		"",
:		"AO_STATUS"

[[ARM_CUSTMAST.AOPT-INVQ]]
rem --- Show AR invoices

	custControl!=callpoint!.getControl("ARM_CUSTMAST.CUSTOMER_ID")
	cust_id$=custControl!.getText()

	dim filter_defs$[3,2]
	filter_defs$[0,0]="ART_INVHDR.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="ART_INVHDR.AR_TYPE"
	filter_defs$[1,1]="='  '"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0] = "ART_INVHDR.CUSTOMER_ID"
	filter_defs$[2,1] = "='" + cust_id$ + "'"
	filter_defs$[2,2]="LOCK"


	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"AR_INVOICES",
:		"",
:		table_chans$[all],
:		"",
:		filter_defs$[all]

[[ARM_CUSTMAST.AOPT-ORDR]]
rem --- Show orders

	custControl!=callpoint!.getControl("ARM_CUSTMAST.CUSTOMER_ID")
	cust_id$=custControl!.getText()

	selected_key$ = ""
	dim filter_defs$[5,2]
	filter_defs$[0,0]="OPT_INVHDR.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="OPT_INVHDR.TRANS_STATUS"
	filter_defs$[1,1]="IN ('E','R')"
	filter_defs$[1,2]=""
	filter_defs$[2,0]="OPT_INVHDR.AR_TYPE"
	filter_defs$[2,1]="='  '"
	filter_defs$[2,2]="LOCK"
	if cvs(cust_id$, 2) <> "" then
		filter_defs$[3,0] = "OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1] = "='" + cust_id$ + "'"
		filter_defs$[3,2]="LOCK"
	endif
	filter_defs$[4,0]="OPT_INVHDR.INVOICE_TYPE"
	filter_defs$[4,1]="NOT IN ('V','P')"
	filter_defs$[4,2]="LOCK"
	filter_defs$[5,0]="OPT_INVHDR.ORDINV_FLAG"
	filter_defs$[5,1]="='O'"
	filter_defs$[5,2]="LOCK"

	dim search_defs$[3]

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"OP_INVOICES",
:		"",
:		table_chans$[all],
:		selected_keys$,
:		filter_defs$[all],
:		search_defs$[all],
:		"",
:		"AO_STATUS"

[[ARM_CUSTMAST.AOPT-ORIV]]
rem Order/Invoice History Inq
rem --- assume this should only run if OP installed...
	if user_tpl.op_installed$="Y"
		cp_cust_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
		user_id$=stbl("+USER_ID")
		dim dflt_data$[2,1]
		dflt_data$[1,0]="CUSTOMER_ID"
		dflt_data$[1,1]=cp_cust_id$
		call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                           "ARR_ORDINVHIST",
:                           user_id$,
:                   	    "",
:                           "",
:                           table_chans$[all],
:                           "",
:                           dflt_data$[all]
	else
		msg_id$="AD_NO_OP"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
	endif
	callpoint!.setStatus("ACTIVATE")

[[ARM_CUSTMAST.AOPT-PHST]]
rem --- Show payments, with drill on check# to invoices paid with that check, and then drill on invoice# to AR Inv History

	custControl!=callpoint!.getControl("ARM_CUSTMAST.CUSTOMER_ID")
	cust_id$=custControl!.getText()

	if cvs(cust_id$,2)<>""
		dim filter_defs$[2,2]
		filter_defs$[0,0]="ART_CASHHDR.FIRM_ID"
		filter_defs$[0,1]="='"+firm_id$+"'"
		filter_defs$[0,2]="LOCK"
		filter_defs$[1,0]="ART_CASHHDR.AR_TYPE"
		filter_defs$[1,1]="='  '"
		filter_defs$[1,2]="LOCK"
		filter_defs$[2,0]="ART_CASHHDR.CUSTOMER_ID"
		filter_defs$[2,1]="='"+cust_id$+"'"
		filter_defs$[2,2]="LOCK"

		call stbl("+DIR_SYP")+"bax_query.bbj",
:			gui_dev,
:			Form!,
:			"AR_CUST_PYMTS",
:			"",
:			table_chans$[all],
:			"",
:			filter_defs$[all]

	endif

[[ARM_CUSTMAST.AOPT-PRIC]]
rem --- Launch Price Quote Inquiry form
	dim dflt_data$[2,1]
	dflt_data$[1,0]="FIRM_ID"
	dflt_data$[1,1]=firm_id$
	dflt_data$[2,0]="CUSTOMER_ID"
	dflt_data$[2,1]=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"OPE_PRICEQUOTE",
:		stbl("+USER_ID"),
:		"MNT",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[ARM_CUSTMAST.AOPT-PYMT]]
rem --- Select invoice(s) for credit card payment
rem --- May be done via PayPal or Authorize.net hosted page
rem --- or using J2Pay library, as specified in ars_cc_custsvc

	cp_cust_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	user_id$=stbl("+USER_ID")

	arm_emailfax=fnget_dev("ARM_EMAILFAX")
	dim arm_emailfax$:fnget_tpl$("ARM_EMAILFAX")
	readrecord(arm_emailfax,key=firm_id$+cp_cust_id$,dom=*next)arm_emailfax$

	dim dflt_data$[9,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=cp_cust_id$
	dflt_data$[2,0]="ADDRESS_LINE_1"
	dflt_data$[2,1]=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_1")
	dflt_data$[3,0]="ADDRESS_LINE_2"
	dflt_data$[3,1]=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_2")
	dflt_data$[4,0]="CITY"
	dflt_data$[4,1]=callpoint!.getColumnData("ARM_CUSTMAST.CITY")
	dflt_data$[5,0]="STATE_CODE"
	dflt_data$[5,1]=callpoint!.getColumnData("ARM_CUSTMAST.STATE_CODE")
	dflt_data$[6,0]="ZIP_CODE"
	dflt_data$[6,1]=callpoint!.getColumnData("ARM_CUSTMAST.ZIP_CODE")
	dflt_data$[7,0]="CNTRY_ID"
	dflt_data$[7,1]=callpoint!.getColumnData("ARM_CUSTMAST.CNTRY_ID")
	dflt_data$[8,0]="PHONE_NO"
	dflt_data$[8,1]=callpoint!.getColumnData("ARM_CUSTMAST.PHONE_NO")
	dflt_data$[9,0]="EMAIL_ADDR"
	dflt_data$[9,1]=arm_emailfax.email_to$

	key_pfx$=cp_cust_id$
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"ARE_CCPMT",
:                user_id$,
:                "",
:                key_pfx$,
:                table_chans$[all],
:                "",
:                dflt_data$[all]

[[ARM_CUSTMAST.AOPT-QUOT]]
rem --- Show quotes

	custControl!=callpoint!.getControl("ARM_CUSTMAST.CUSTOMER_ID")
	cust_id$=custControl!.getText()

	selected_key$ = ""
	dim filter_defs$[4,2]
	filter_defs$[0,0]="OPT_INVHDR.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="OPT_INVHDR.TRANS_STATUS"
	filter_defs$[1,1]="IN ('E','R')"
	filter_defs$[1,2]=""
	filter_defs$[2,0]="OPT_INVHDR.AR_TYPE"
	filter_defs$[2,1]="='  '"
	filter_defs$[2,2]="LOCK"
	if cvs(cust_id$, 2) <> "" then
		filter_defs$[3,0] = "OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1] = "='" + cust_id$ + "'"
		filter_defs$[3,2]="LOCK"
	endif
	filter_defs$[4,0]="OPT_INVHDR.INVOICE_TYPE"
	filter_defs$[4,1]="='P'"
	filter_defs$[4,2]="LOCK"

	dim search_defs$[3]

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"OP_INVOICES",
:		"",
:		table_chans$[all],
:		selected_keys$,
:		filter_defs$[all],
:		search_defs$[all],
:		"",
:		"AO_STATUS"

[[ARM_CUSTMAST.AOPT-RCTL]]
rem --- Launch Report Control Recipients form for this customer
	user_id$=stbl("+USER_ID")
	customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")

	dim dflt_data$[2,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=customer_id$
	dflt_data$[2,0]="RECIPIENT_TP"
	dflt_data$[2,1]="C"

	key_pfx$=firm_id$+customer_id$
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"ADM_RPTRCP_CUST",
:		user_id$,
:		"",
:		key_pfx$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[ARM_CUSTMAST.AOPT-RESP]]
rem --- view electronic receipt response, if applicable 
	user_id$=stbl("+USER_ID")  
	cust_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")

	dim dflt_data$[1,1]
	dflt_data$[0,0]="ART_RESPHDR.FIRM_ID"
	dflt_data$[0,1]=firm_id$
	dflt_data$[1,0]="ART_RESPHDR.CUSTOMER_ID"
	dflt_data$[1,1]=cust_id$

	key_pfx$=callpoint!.getColumnData("ARM_CUSTMAST.FIRM_ID")+callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"ART_RESPHDR",
:		user_id$,
:		"",
:		key_pfx$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[ARM_CUSTMAST.AOPT-SHST]]
rem --- Launch customer sales analysis form
	user_id$=stbl("+USER_ID")
	year$=sysinfo.system_date$(1,4)
	customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	key_pfx$=firm_id$+year$+customer_id$
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SAM_CUSTOMER",
:		user_id$,
:		"",
:		key_pfx$,
:		table_chans$[all]

[[ARM_CUSTMAST.AOPT-STMT]]
rem On Demand Statement

cp_cust_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
user_id$=stbl("+USER_ID")
key_pfx$=cp_cust_id$

dim dflt_data$[2,1]
dflt_data$[1,0]="CUSTOMER_ID"
dflt_data$[1,1]=cp_cust_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                       "ARR_STMT_DEMAND",
:                       user_id$,
:                   	"",
:                       key_pfx$,
:                       table_chans$[all],
:                       "",
:                       dflt_data$[all]

[[ARM_CUSTMAST.AOPT-XMPT]]
rem --- Launch Customer Sales Tax Exemptions form for this customer
	user_id$=stbl("+USER_ID")
	customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")

	dim dflt_data$[1,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=customer_id$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"ARM_CUSTEXMPT",
:		user_id$,
:		"",
:		firm_id$+customer_id$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[ARM_CUSTMAST.AREA]]
rem --- Set New Customer flag
	user_tpl.new_cust$="N"

[[ARM_CUSTMAST.AREC]]
rem --- notes about defaults, other init:
rem --- if cm$ installed, and ars01c.hold_new$ is "Y", then default arm02a.cred_hold$ to "Y"
rem --- default arm02a.slspsn_code$,ar_terms_code$,disc_code$,ar_dist_code$,territory$,tax_code$
rem --- and inv_hist_flg$ per defaults in ops10d
dim ars10d$:user_tpl.cust_dflt_tpl$
ars10d$=user_tpl.cust_dflt_rec$
callpoint!.setColumnData("ARM_CUSTMAST.AR_SHIP_VIA",ars10d.ar_ship_via$,1)
callpoint!.setColumnUndoData("ARM_CUSTMAST.AR_SHIP_VIA",ars10d.ar_ship_via$)
callpoint!.setColumnData("ARM_CUSTMAST.FOB",ars10d.fob$,1)
callpoint!.setColumnUndoData("ARM_CUSTMAST.FOB",ars10d.fob$)
callpoint!.setColumnData("ARM_CUSTMAST.OPENED_DATE",date(0:"%Yd%Mz%Dz"))
callpoint!.setColumnData("ARM_CUSTMAST.RETAIN_CUST","Y")

callpoint!.setColumnData("ARM_CUSTDET.AR_TERMS_CODE",ars10d.ar_terms_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.AR_TERMS_CODE",ars10d.ar_terms_code$)
callpoint!.setColumnData("ARM_CUSTDET.AR_DIST_CODE",ars10d.ar_dist_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.AR_DIST_CODE",ars10d.ar_dist_code$)
callpoint!.setColumnData("ARM_CUSTDET.SLSPSN_CODE",ars10d.slspsn_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.SLSPSN_CODE",ars10d.slspsn_code$)
callpoint!.setColumnData("ARM_CUSTDET.DISC_CODE",ars10d.disc_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.DISC_CODE",ars10d.disc_code$)
callpoint!.setColumnData("ARM_CUSTDET.TERRITORY",ars10d.territory$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.TERRITORY",ars10d.territory$)
callpoint!.setColumnData("ARM_CUSTDET.TAX_CODE",ars10d.tax_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.TAX_CODE",ars10d.tax_code$)
if cvs(ars10d.inv_hist_flg$,2)<>"" then
	callpoint!.setColumnData("ARM_CUSTDET.INV_HIST_FLG",ars10d.inv_hist_flg$,1)
	callpoint!.setColumnUndoData("ARM_CUSTDET.INV_HIST_FLG",ars10d.inv_hist_flg$)
else
	callpoint!.setColumnData("ARM_CUSTDET.INV_HIST_FLG","Y",1)
	callpoint!.setColumnUndoData("ARM_CUSTDET.INV_HIST_FLG","Y")
endif
if cvs(ars10d.cred_hold$,2)<>"" then
	callpoint!.setColumnData("ARM_CUSTDET.CRED_HOLD",ars10d.cred_hold$,1)
	callpoint!.setColumnUndoData("ARM_CUSTDET.CRED_HOLD",ars10d.cred_hold$)
else
	if user_tpl.cm_installed$="Y" then 
		callpoint!.setColumnData("ARM_CUSTDET.CRED_HOLD",user_tpl.dflt_cred_hold$,1)
		callpoint!.setColumnUndoData("ARM_CUSTDET.CRED_HOLD",user_tpl.dflt_cred_hold$)
	else
		callpoint!.setColumnData("ARM_CUSTDET.CRED_HOLD","N",1)
		callpoint!.setColumnUndoData("ARM_CUSTDET.CRED_HOLD","N")
	endif
endif
callpoint!.setColumnData("ARM_CUSTDET.CUSTOMER_TYPE",ars10d.customer_type$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.CUSTOMER_TYPE",ars10d.customer_type$)
callpoint!.setColumnData("ARM_CUSTDET.FRT_TERMS",ars10d.frt_terms$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.FRT_TERMS",ars10d.frt_terms$)
callpoint!.setColumnData("ARM_CUSTDET.MESSAGE_CODE",ars10d.message_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.MESSAGE_CODE",ars10d.message_code$)
callpoint!.setColumnData("ARM_CUSTDET.PRICING_CODE",ars10d.pricing_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.PRICING_CODE",ars10d.pricing_code$)
callpoint!.setColumnData("ARM_CUSTDET.LABEL_CODE",ars10d.label_code$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.LABEL_CODE",ars10d.label_code$)
callpoint!.setColumnData("ARM_CUSTDET.AR_CYCLECODE",ars10d.ar_cyclecode$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.AR_CYCLECODE",ars10d.ar_cyclecode$)
callpoint!.setColumnData("ARM_CUSTDET.SA_FLAG",ars10d.sa_flag$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.SA_FLAG",ars10d.sa_flag$)
callpoint!.setColumnData("ARM_CUSTDET.CREDIT_LIMIT",str(ars10d.credit_limit),1)
callpoint!.setColumnUndoData("ARM_CUSTDET.CREDIT_LIMIT",str(ars10d.credit_limit))
callpoint!.setColumnData("ARM_CUSTDET.FINANCE_CHG",ars10d.finance_chg$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.FINANCE_CHG",ars10d.finance_chg$)
callpoint!.setColumnData("ARM_CUSTDET.STATEMENTS",ars10d.statements$,1)
callpoint!.setColumnUndoData("ARM_CUSTDET.STATEMENTS",ars10d.statements$)

rem --- clear out the contents of the widgets

	dim ars01a$:fnget_tpl$("ARS_PARAMS")
	ars01a$=callpoint!.getDevObject("ars01a$")
	days$=" "+Translate!.getTranslation("AON_DAYS","Days",1)+":"
	agingDashboardPieWidget!=callpoint!.getDevObject("dbPieWidget")
	agingPieWidget! = agingDashboardPieWidget!.getWidget()
	agingPieWidget!.setDataSetValue(Translate!.getTranslation("AON_FUTURE","Future",1), 0)
	agingPieWidget!.setDataSetValue(Translate!.getTranslation("AON_CURRENT","Current",1), 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_1)+days$, 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_2)+days$, 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_3)+days$, 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_4)+"+"+days$, 0)
	agingPieWidget!.refresh()

	agingDashboardBarWidget!=callpoint!.getDevObject("dbBarWidget")
	agingBarWidget! = agingDashboardBarWidget!.getWidget()
	agingBarWidget!.setDataSetValue(Translate!.getTranslation("AON_FUT","Fut",1), "",0)
	agingBarWidget!.setDataSetValue(Translate!.getTranslation("AON_CUR","Cur",1), "", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_1),"", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_2), "", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_3), "", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_4)+"+", "", 0)
	agingBarWidget!.refresh()

	agingPieWidgetControl!=callpoint!.getDevObject("dbPieWidgetControl")
	agingPieWidgetControl!.setVisible(0)
	agingBarWidgetControl!=callpoint!.getDevObject("dbBarWidgetControl")
	agingBarWidgetControl!.setVisible(0)

[[ARM_CUSTDET.AR_CYCLECODE.AVAL]]
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

[[ARM_CUSTDET.AR_DIST_CODE.AVAL]]
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

[[ARM_CUSTDET.AR_TERMS_CODE.AVAL]]
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

rem --- look up terms code, arm10A...if cred_hold is Y for this terms code,
rem --- and cm$ is Y, set arm_custdet.cred_hold to Y as well
if user_tpl.cm_installed$="Y"
	if arm10a.cred_hold$="Y"
		callpoint!.setColumnData("ARM_CUSTDET.CRED_HOLD","Y",1)
	endif
endif

[[ARM_CUSTMAST.AWRI]]
rem --- Add ARS_CC_CUSTPMT Report Control Recipients record for this customer if one doesn't already exist
	if cvs(callpoint!.getColumnData("ARM_CUSTMAST.PAY_AUTH_EMAIL"),3)<>"" then
		customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
		admRptCtlRcp_dev=fnget_dev("ADM_RPTCTL_RCP")
		dim admRptCtlRcp$:fnget_tpl$("ADM_RPTCTL_RCP")
		admRptCtlRcp.dd_table_alias$="ARS_CC_CUSTPMT"
		findrecord(admRptCtlRcp_dev,key=firm_id$+admRptCtlRcp.dd_table_alias$+customer_id$+admRptCtlRcp.vendor_id$,dom=*next)admRptCtlRcp$

		if cvs(admRptCtlRcp.customer_id$,3)="" then
			rem --- Add ARS_CC_CUSTPMT record for this customer
			redim admRptCtlRcp$
			admRptCtlRcp.firm_id$=firm_id$
			admRptCtlRcp.dd_table_alias$="ARS_CC_CUSTPMT"
			admRptCtlRcp.customer_id$=customer_id$
			admRptCtlRcp.email_yn$="Y"
			admRptCtlRcp.email_to$=callpoint!.getColumnData("ARM_CUSTMAST.PAY_AUTH_EMAIL")

			rem --- Use Report Control default subject and message
			admRptCtl_dev=fnget_dev("ADM_RPTCTL")
			dim admRptCtl$:fnget_tpl$("ADM_RPTCTL")
			findrecord(admRptCtl_dev,key=firm_id$+admRptCtlRcp.dd_table_alias$,dom=*endif)admRptCtl$
			admRptCtlRcp.email_subject$=admRptCtl.dflt_subject$
			admRptCtlRcp.email_message$=admRptCtl.dflt_message$

			rem --- If available, use Report Control email account's from and reply-to
			admEmailAcct_dev=fnget_dev("ADM_EMAIL_ACCT")
			dim admEmailAcct$:fnget_tpl$("ADM_EMAIL_ACCT")
			findrecord(admEmailAcct_dev,key=firm_id$+admRptCtl.email_account$,dom=*next)admEmailAcct$
			if cvs(admEmailAcct.email_account$,3)<>"" then
				admRptCtlRcp.email_from$=admEmailAcct.email_from$
				admRptCtlRcp.email_replyto$=admEmailAcct.email_replyto$
			endif

			admRptCtlRcp$=field(admRptCtlRcp$)
			writerecord(admRptCtlRcp_dev)admRptCtlRcp$
			callpoint!.setDevObject("recipient_email_to",admRptCtlRcp.email_to$)
			callpoint!.setDevObject("match_email_to","OK")
		endif
	endif

	if callpoint!.getDevObject("match_email_to")<>"OK" then
		rem --- Set background color for bad pay_auth_email
		payAuthEmail!=callpoint!.getControl("ARM_CUSTMAST.PAY_AUTH_EMAIL")
		call stbl("+DIR_SYP",err=*endif)+"bac_create_color.bbj","+ENTRY_ERROR_COLOR","255,224,224",rdErrorColor!,""
		payAuthEmail!.setBackColor(rdErrorColor!)
	endif

[[ARM_CUSTMAST.BDEL]]
rem  --- Check for Open AR Invoices
	delete_msg$=""
	cust$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
	read(user_tpl.art01_dev,key=firm_id$+"  "+cust$,dom=*next)
	art01_key$=key(user_tpl.art01_dev,end=check_op_ord)
	if pos(firm_id$+"  "+cust$=art01_key$)<>1 goto check_op_ord
	delete_msg$=Translate!.getTranslation("AON_OPEN_INVOICES_EXIST_-_CUSTOMER_DELETION_NOT_ALLOWED")
	goto done_checking	

check_op_ord:
	if user_tpl.op_installed$<>"Y" goto done_checking
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="OPT_INVHDR",open_opts$[1]="OTA"
	gosub open_tables
	opt01_dev=num(open_chans$[1])
	dim opt01_tpl$:open_tpls$[1]

	read (opt01_dev,key=firm_id$+"  "+cust$,dom=*next)
	opt01_key$=key(opt01_dev,end=done_checking)              
	if pos(firm_id$+"  "+cust$=opt01_key$)<>1 goto done_checking
	readrecord(opt01_dev)opt01_tpl$
	if opt01_tpl.trans_status$="U"
		delete_msg$=Translate!.getTranslation("AON_HISTORICAL_INVOICES_EXIST_-_CUSTOMER_DELETION_NOT_ALLOWED")
	else
		delete_msg$=Translate!.getTranslation("AON_OPEN_ORDERS_EXIST_-_CUSTOMER_DELETION_NOT_ALLOWED")
	endif

done_checking:
	if delete_msg$<>""
		callpoint!.setMessage("NO_DELETE:"+delete_msg$)
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- If GM installed, remove cross reference(s) to GoldMine
	if user_tpl.gm_installed$="Y" then
		gmxCustomer_dev=fnget_dev("GMX_CUSTOMER")
		dim gmxCustomer$:fnget_tpl$("GMX_CUSTOMER")
		read(gmxCustomer_dev,key=firm_id$+cust$,knum="BY_ADDON",dom=*next)
		while 1
			gmxCustomer_key$=key(gmxCustomer_dev,end=*break)
			if pos(firm_id$+cust$=gmxCustomer_key$)<>1 then break
			readrecord(gmxCustomer_dev)gmxCustomer$
			remove(gmxCustomer_dev,key=gmxCustomer.gm_accountno$+gmxCustomer.gm_recid$)
			read(gmxCustomer_dev,key=firm_id$+cust$,knum="BY_ADDON",dom=*next)
		wend
	endif

[[ARM_CUSTMAST.BEND]]
rem --- call the close() method for the gmClient! object on the way out

	if user_tpl.gm_installed$="Y" then
		gmClient!=callpoint!.getDevObject("gmClient")
		gmClient!.close()
	endif

		

[[ARM_CUSTMAST.BREC]]
rem --- Set New Customer flag
	user_tpl.new_cust$="Y"

[[ARM_CUSTMAST.BSHO]]
rem --- Open/Lock files
	dir_pgm$=stbl("+DIR_PGM")
	sys_pgm$=stbl("+DIR_SYP")
	num_files=24

	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[2]="ARS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="ARS_CUSTDFLT",open_opts$[3]="OTA"
	open_tables$[4]="ARS_CREDIT",open_opts$[4]="OTA"
	open_tables$[5]="ARM_CUSTDET",open_opts$[5]="OTA"
	open_tables$[6]="ART_INVHDR",open_opts$[6]="OTA"
	open_tables$[7]="ART_INVDET",open_opts$[7]="OTA"
	open_tables$[8]="ARS_CC_CUSTSVC",open_opts$[8]="OTA"
	open_tables$[9]="ARM_EMAILFAX",open_opts$[9]="OTA"
	open_tables$[10]="ADM_RPTCTL",open_opts$[10]="OTA"
	open_tables$[11]="ADM_RPTCTL_RCP",open_opts$[11]="OTA"
	open_tables$[12]="ADM_EMAIL_ACCT",open_opts$[12]="OTA"
	open_tables$[13]="ARS_CC_CUSTPMT",open_opts$[13]="OTA"
	open_tables$[14]="ARC_CUSTTYPE",open_opts$[14]="OTA"
	open_tables$[15]="ARC_DISTCODE",open_opts$[15]="OTA"
	open_tables$[16]="ARC_SALECODE",open_opts$[16]="OTA"
	open_tables$[17]="ARC_TERMCODE",open_opts$[17]="OTA"
	open_tables$[18]="ARC_TERRCODE",open_opts$[18]="OTA"
	open_tables$[19]="ARM_CYCLECOD",open_opts$[19]="OTA"
	open_tables$[20]="OPC_DISCCODE",open_opts$[20]="OTA"
	open_tables$[21]="OPC_MESSAGE",open_opts$[21]="OTA"
	open_tables$[22]="OPC_PRICECDS",open_opts$[22]="OTA"
	open_tables$[23]="OPC_TAXCODE",open_opts$[23]="OTA"
	open_tables$[24]="OPM_FRTTERMS",open_opts$[24]="OTA"
	gosub open_tables

	ars01_dev=num(open_chans$[2])
	ars10_dev=num(open_chans$[3])
	ars01c_dev=num(open_chans$[4])
	arm02_dev=num(open_chans$[5])
	ars_cc_custsvc=num(open_chans$[8])
	ars_cc_custpmt=num(open_chans$[13])

rem --- Dimension miscellaneous string templates

	dim ars01a$:open_tpls$[2],ars10d$:open_tpls$[3],ars01c$:open_tpls$[4]
	dim arm02_tpl$:open_tpls$[5],ars_cc_custsvc$:open_tpls$[8],ars_cc_custpmt$:open_tpls$[13]

rem --- Retrieve parameter data
	dim info$[20]
	ars01a_key$=firm_id$+"AR00"
	find record (ars01_dev,key=ars01a_key$,err=std_missing_params) ars01a$
	callpoint!.setDevObject("ars01a$",ars01a$)
	callpoint!.setDevObject("on_demand_aging",ars01a.on_demand_aging$)
	callpoint!.setDevObject("dflt_age_by",ars01a.dflt_age_by$)
	ars01c_key$=firm_id$+"AR01"
	find record (ars01c_dev,key=ars01c_key$,err=std_missing_params) ars01c$                
	cm$=ars01c.sys_install$
	dflt_cred_hold$=ars01c.hold_new$
	find record (ars10_dev,key=firm_id$+"D",err=std_missing_params) ars10d$
	call stbl("+DIR_PGM")+"adc_application.aon","GL",info$[all]
	gl$=info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
	op$=info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","IV",info$[all]
	iv$=info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","SA",info$[all]
	sa$=info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","GM",info$[all]
	gm$=info$[20]
	dim user_tpl$:"app:c(2),gl_installed:c(1),op_installed:c(1),sa_installed:c(1),iv_installed:c(1),gm_installed:c(1),"+
:		"cm_installed:c(1),dflt_cred_hold:c(1),cust_dflt_tpl:c(1024),cust_dflt_rec:c(1024),new_cust:c(1),"+
:		"art01_dev:n(5)"
	user_tpl.app$="AR"
	user_tpl.gl_installed$=gl$
	user_tpl.op_installed$=op$
	user_tpl.iv_installed$=iv$
	user_tpl.sa_installed$=sa$
	user_tpl.gm_installed$=gm$
	user_tpl.cm_installed$=cm$
	user_tpl.dflt_cred_hold$=dflt_cred_hold$
	user_tpl.cust_dflt_tpl$=fattr(ars10d$)
	user_tpl.cust_dflt_rec$=ars10d$
	user_tpl.art01_dev=num(open_chans$[6])
	dim dctl$[17]
	if user_tpl.cm_installed$="Y"
 		dctl$[1]="ARM_CUSTDET.CREDIT_LIMIT"              
	endif
	if user_tpl.sa_installed$<>"Y" or user_tpl.op_installed$<>"Y"
 		dctl$[2]="ARM_CUSTDET.SA_FLAG"
	endif
	if ars01a.inv_hist_flg$="N"
		dctl$[3]="ARM_CUSTDET.INV_HIST_FLG"
	endif
	if user_tpl.op_installed$<>"Y"
		dctl$[3]="ARM_CUSTDET.INV_HIST_FLG"
		dctl$[4]="ARM_CUSTDET.TAX_CODE"
		dctl$[5]="ARM_CUSTDET.FRT_TERMS"
		dctl$[6]="ARM_CUSTDET.MESSAGE_CODE"
		dctl$[7]="ARM_CUSTDET.DISC_CODE"
		dctl$[8]="ARM_CUSTDET.PRICING_CODE"
		callpoint!.setOptionEnabled("QUOT",0)
		callpoint!.setOptionEnabled("ORDR",0)
		callpoint!.setOptionEnabled("INVC",0)
		callpoint!.setOptionEnabled("CRDT",0)
		callpoint!.setOptionEnabled("XMPT",0)
	endif
	dctl$[9]="<<DISPLAY>>.DSP_BALANCE"
	dctl$[10]="<<DISPLAY>>.DSP_MTD_PROFIT"
	dctl$[11]="<<DISPLAY>>.DSP_YTD_PROFIT"
	dctl$[12]="<<DISPLAY>>.DSP_PRI_PROFIT"
	dctl$[13]="<<DISPLAY>>.DSP_NXT_PROFIT"
	dctl$[14]="<<DISPLAY>>.DSP_MTD_PROF_PCT"
	dctl$[15]="<<DISPLAY>>.DSP_YTD_PROF_PCT"
	dctl$[16]="<<DISPLAY>>.DSP_PRI_PROF_PCT"
	dctl$[17]="<<DISPLAY>>.DSP_NXT_PROF_PCT"
	gosub disable_ctls

rem --- Disable Option for Jobs if OP not installed or Job flag not set
	if op$<>"Y" or ars01a.job_nos$<>"Y"
		callpoint!.setOptionEnabled("OPM_CUSTJOBS",0)
	endif

rem --- Disable Option for On Demand Aging if param not set
	if ars01a.on_demand_aging$<>"Y"
		callpoint!.setOptionEnabled("AGNG",0)
	endif

rem --- Additional/optional opens
	if user_tpl.gm_installed$="Y" then
		num_files=3
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="GMS_PARAMS",open_opts$[1]="OTA"
		open_tables$[2]="GMQ_CUSTOMER",open_opts$[2]="OTA"
		open_tables$[3]="GMX_CUSTOMER",open_opts$[3]="OTA"
		gosub open_tables

		rem --- Verify GM parameters have been entered
		find (num(open_chans$[1]),key=firm_id$+"GM",err=std_missing_params) 

		rem --- Get GoldMine interface client
		use ::gmo_GmInterfaceClient.aon::GmInterfaceClient
		gmClient!=new GmInterfaceClient()
		callpoint!.setDevObject("gmClient",gmClient!)
	endif

rem --- disable credit card payment and view response options if not processing credit card payments

	read(ars_cc_custsvc,key=firm_id$,dom=*next)
	callpoint!.setOptionEnabled("PYMT",0)
	callpoint!.setOptionEnabled("RESP",0)
	while 1
		readrecord(ars_cc_custsvc,end=*break)ars_cc_custsvc$
		if ars_cc_custsvc.firm_id$<>firm_id$ then break
		if ars_cc_custsvc.use_custsvc_cc$="Y"
			callpoint!.setOptionEnabled("PYMT",1)
			callpoint!.setOptionEnabled("RESP",1)
			break
		endif
	wend

	rem --- have checked ars_cc_custsvc; also check ars_cc_custpmt
	rem --- could be processing online cc pymts (ars_cc_custpmt) but not AR staff payments (ars_cc_custsvc)
	rem --- if that's the case, enable the option to view responses
	read(ars_cc_custpmt,key=firm_id$,dom=*next)
	while 1
		readrecord(ars_cc_custpmt,end=*break)ars_cc_custpmt$
		if ars_cc_custpmt.firm_id$<>firm_id$ then break
		if ars_cc_custpmt.allow_cust_cc$="Y"
			callpoint!.setOptionEnabled("RESP",1)
			break
		endif
	wend

rem --- Update Control Labels for aging days
	days$=" "+Translate!.getTranslation("AON_DAYS","Days",1)+":"
	use ::ado_util.src::util
	util.changeControlLabel(SysGUI!, callpoint!, "ARM_CUSTDET.AGING_30", str(ars01a.age_per_days_1)+days$)
	util.changeControlLabel(SysGUI!, callpoint!, "ARM_CUSTDET.AGING_60", str(ars01a.age_per_days_2)+days$)
	util.changeControlLabel(SysGUI!, callpoint!, "ARM_CUSTDET.AGING_90", str(ars01a.age_per_days_3)+days$)
	util.changeControlLabel(SysGUI!, callpoint!, "ARM_CUSTDET.AGING_120", str(ars01a.age_per_days_4)+"+"+days$)

rem --- Create/embed widgets to show aged balance

	gosub create_widgets

rem --- Set STBLs needed in Customer Sales Summary drilldown definition filters
	rem --- AR_MTDSALES_1 beginning and ending dates
	period=num(ars01a.current_per$)
	year=num(ars01a.current_year$)
	call stbl("+DIR_PGM")+"adc_perioddates.aon",period,year,begdate$,enddate$,table_chans$[all],status
	x$=stbl("MTD_BEG_DATE",begdate$)
	x$=stbl("MTD_END_DATE",enddate$)

	rem --- AR_NMNSALES_1 beginning and ending dates
	period=period+1
	call stbl("+DIR_PGM")+"adc_perioddates.aon",period,year,begdate$,enddate$,table_chans$[all],status
	x$=stbl("NMN_BEG_DATE",begdate$)
	x$=stbl("NMN_END_DATE",enddate$) 

	rem --- AR_YTDSALES_1 beginning date and ending dates
	period=1
	call stbl("+DIR_PGM")+"adc_perioddates.aon",period,year,begdate$,enddate$,table_chans$[all],status
	x$=stbl("YTD_BEG_DATE",begdate$)
	next_year=year+1
	call stbl("+DIR_PGM")+"adc_perioddates.aon",period,next_year,begdate$,enddate$,table_chans$[all],status
	x$=stbl("YTD_END_DATE",begdate$)

	rem --- AR_PYRSALES_1 beginning date and ending dates
	period=1
	last_year=year-1
	call stbl("+DIR_PGM")+"adc_perioddates.aon",period,last_year,begdate$,enddate$,table_chans$[all],status
	x$=stbl("PYTD_BEG_DATE",begdate$)
	call stbl("+DIR_PGM")+"adc_perioddates.aon",period,year,begdate$,enddate$,table_chans$[all],status
	x$=stbl("PYTD_END_DATE",begdate$)

[[ARM_CUSTMAST.BWRI]]
rem --- If GM installed, update GoldMine database as necessary
	if user_tpl.gm_installed$="Y" then
		customer_id$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_ID")
		customer_name$=callpoint!.getColumnData("ARM_CUSTMAST.CUSTOMER_NAME")
		contact_name$=callpoint!.getColumnData("ARM_CUSTMAST.CONTACT_NAME")

		rem --- Initialize new queue record for this customer/contact
		dim gmqCustomer$:fnget_tpl$("GMQ_CUSTOMER")
		dim initQueueRecord$:fattr(gmqCustomer$)
		gmqCustomer.firm_id$=firm_id$
		gmqCustomer.customer_id$=customer_id$
		rem gmqCustomer.gm_accountno$
		rem gmqCustomer.gm_recid$
		gmqCustomer.customer_name$=customer_name$
		gmqCustomer.contact_name$=contact_name$
		gmqCustomer.phone_no$=callpoint!.getColumnData("ARM_CUSTMAST.PHONE_NO")
		gmqCustomer.phone_exten$=callpoint!.getColumnData("ARM_CUSTMAST.PHONE_EXTEN")
		gmqCustomer.fax_no$=callpoint!.getColumnData("ARM_CUSTMAST.FAX_NO")
		gmqCustomer.addr_line_1$=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_1")
		gmqCustomer.addr_line_2$=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_2")
		gmqCustomer.addr_line_3$=callpoint!.getColumnData("ARM_CUSTMAST.ADDR_LINE_3")
		gmqCustomer.city$=callpoint!.getColumnData("ARM_CUSTMAST.CITY")
		gmqCustomer.state_code$=callpoint!.getColumnData("ARM_CUSTMAST.STATE_CODE")
		gmqCustomer.zip_code$=callpoint!.getColumnData("ARM_CUSTMAST.ZIP_CODE")
		gmqCustomer.cntry_id$=callpoint!.getColumnData("ARM_CUSTMAST.CNTRY_ID")
		gmqCustomer.country$=callpoint!.getColumnData("ARM_CUSTMAST.COUNTRY")
		initQueueRecord$=gmqCustomer$

		rem --- Check if this is a new GoldMine contact
		gmClient!=callpoint!.getDevObject("gmClient")
		gmqCustomer_dev=fnget_dev("GMQ_CUSTOMER")
		if !gmClient!.isGmContact(firm_id$,customer_id$,customer_name$,contact_name$) then
			rem --- Add new contact to GoldMine database
			writerecord(gmqCustomer_dev)gmqCustomer$
		else
			rem --- Update changed info for existing imported GoldMine contact(s) for this Addon customer
			rem --- Do NOT update existing un-imported GoldMine contact(s)
			gmxCustomer_dev=fnget_dev("GMX_CUSTOMER")
			dim gmxCustomer$:fnget_tpl$("GMX_CUSTOMER")
			read(gmxCustomer_dev,key=firm_id$+customer_id$,knum="BY_ADDON",dir=0,dom=*next)
			while 1
				gmxCustomer_key$=key(gmxCustomer_dev,end=*break)
				if pos(firm_id$+customer_id$=gmxCustomer_key$)<>1 then break
				readrecord(gmxCustomer_dev)gmxCustomer$

				rem --- Initialize new queue record for this customer/contact
				dim gmqCustomer$:fattr(gmqCustomer$)
				gmqCustomer$=initQueueRecord$
				gmqCustomer.gm_accountno$=gmxCustomer.gm_accountno$
				gmqCustomer.gm_recid$=gmxCustomer.gm_recid$

				rem --- Get current GoldMine data for this contact
				contactInfo!=gmClient!.getGmContactInfo(gmxCustomer.gm_accountno$,gmxCustomer.gm_recid$,firm_id$)
				if !contactInfo!.isEmpty() then
					rem --- If Barista's Undo data does NOT match the current GoldMine data, then do NOT add it to the queue
					gmProps!=gmClient!.mapToGoldMine("customer_name",callpoint!.getColumnUndoData("ARM_CUSTMAST.CUSTOMER_NAME"))
					if cvs(gmqCustomer.customer_name$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.CUSTOMER_NAME"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("COMPANY"),2) then
						gmqCustomer.customer_name$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("contact_name",callpoint!.getColumnUndoData("ARM_CUSTMAST.CONTACT_NAME"))
					if cvs(gmqCustomer.contact_name$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.CONTACT_NAME"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("CONTACT"),2) then
						gmqCustomer.contact_name$=""
					endif

					previousPhoneNo$=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.PHONE_NO"),2)
					if cvs(gmqCustomer.phone_no$,2)=previousPhoneNo$ or
:					previousPhoneNo$<>cvs(gmClient!.mapToAddon("PHONE1",cvs(contactInfo!.getProperty("PHONE1"),2)).getProperty("value1"),2) then
						gmqCustomer.phone_no$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("phone_exten",callpoint!.getColumnUndoData("ARM_CUSTMAST.PHONE_EXTEN"))
					if cvs(gmqCustomer.phone_exten$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.PHONE_EXTEN"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("EXT1"),2) then
						gmqCustomer.phone_exten$=""
					endif

					previousFaxNo$=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.FAX_NO"),2)
					if cvs(gmqCustomer.fax_no$,2)=previousFaxNo$ or
:					previousFaxNo$<>cvs(gmClient!.mapToAddon("FAX",cvs(contactInfo!.getProperty("FAX"),2)).getProperty("value1"),2) then
						gmqCustomer.fax_no$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("addr_line_1",callpoint!.getColumnUndoData("ARM_CUSTMAST.ADDR_LINE_1"))
					if cvs(gmqCustomer.addr_line_1$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.ADDR_LINE_1"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("ADDRESS1"),2) then
						gmqCustomer.addr_line_1$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("addr_line_2",callpoint!.getColumnUndoData("ARM_CUSTMAST.ADDR_LINE_2"))
					if cvs(gmqCustomer.addr_line_2$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.ADDR_LINE_2"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("ADDRESS2"),2) then
						gmqCustomer.addr_line_2$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("addr_line_3",callpoint!.getColumnUndoData("ARM_CUSTMAST.ADDR_LINE_3"))
					if cvs(gmqCustomer.addr_line_3$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.ADDR_LINE_3"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("ADDRESS3"),2) then
						gmqCustomer.addr_line_3$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("city",callpoint!.getColumnUndoData("ARM_CUSTMAST.CITY"))
					if cvs(gmqCustomer.city$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.CITY"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("CITY"),2) then
						gmqCustomer.city$=""
					endif

					gmProps!=gmClient!.mapToGoldMine("state_code",callpoint!.getColumnUndoData("ARM_CUSTMAST.STATE_CODE"))
					if cvs(gmqCustomer.state_code$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.STATE_CODE"),2) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("STATE"),2) then
						gmqCustomer.state_code$=""
					endif

					previousZipCode$=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.ZIP_CODE"),2)
					if cvs(gmqCustomer.zip_code$,2)=previousZipCode$ or
:					previousZipCode$<>cvs(gmClient!.mapToAddon("ZIP",cvs(contactInfo!.getProperty("ZIP"),2)).getProperty("value1"),2) then
						gmqCustomer.zip_code$=""
					endif

					gmProps!=gmClient!.mapToGoldMineCountry(callpoint!.getColumnUndoData("ARM_CUSTMAST.COUNTRY"),callpoint!.getColumnUndoData("ARM_CUSTMAST.CNTRY_ID"))
					if (cvs(gmqCustomer.cntry_id$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.CNTRY_ID"),2) and
:					cvs(gmqCustomer.country$,2)=cvs(callpoint!.getColumnUndoData("ARM_CUSTMAST.COUNTRY"),2)) or
:					cvs(gmProps!.getProperty("value1"),2)<>cvs(contactInfo!.getProperty("COUNTRY"),2) then
						gmqCustomer.cntry_id$=""
						gmqCustomer.country$=""
					endif
				endif

				rem --- Write record to the queue if something has changed
				if cvs(gmqCustomer.customer_name$,2)<>"" or
:				cvs(gmqCustomer.contact_name$,2)<>"" or
:				cvs(gmqCustomer.phone_no$,2)<>"" or
:				cvs(gmqCustomer.phone_exten$,2)<>"" or
:				cvs(gmqCustomer.fax_no$,2)<>"" or
:				cvs(gmqCustomer.addr_line_1$,2)<>"" or
:				cvs(gmqCustomer.addr_line_2$,2)<>"" or
:				cvs(gmqCustomer.addr_line_3$,2)<>"" or
:				cvs(gmqCustomer.city$,2)<>"" or
:				cvs(gmqCustomer.state_code$,2)<>"" or
:				cvs(gmqCustomer.zip_code$,2)<>"" or
:				cvs(gmqCustomer.cntry_id$,2)<>"" or
:				cvs(gmqCustomer.country$,2)<>"" then
					rem --- This arm_custmast record may have been updated again before the queue was processed
					dim queueRecord$:fattr(gmqCustomer$)
					extractrecord(gmqCustomer_dev,key=gmqCustomer.firm_id$+gmqCustomer.customer_id$+gmqCustomer.gm_accountno$+gmqCustomer.gm_recid$,dom=*next)queueRecord$

					if cvs(queueRecord.customer_name$,2)<>"" and cvs(gmqCustomer.customer_name$,2)="" then gmqCustomer.customer_name$=queueRecord.customer_name$
					if cvs(queueRecord.contact_name$,2)<>"" and cvs(gmqCustomer.contact_name$,2)="" then gmqCustomer.contact_name$=queueRecord.contact_name$
					if cvs(queueRecord.phone_no$,2)<>"" and cvs(gmqCustomer.phone_no$,2)="" then gmqCustomer.phone_no$=queueRecord.phone_no$
					if cvs(queueRecord.phone_exten$,2)<>"" and cvs(gmqCustomer.phone_exten$,2)="" then gmqCustomer.phone_exten$=queueRecord.phone_exten$
					if cvs(queueRecord.fax_no$,2)<>"" and cvs(gmqCustomer.fax_no$,2)="" then gmqCustomer.fax_no$=queueRecord.fax_no$
					if cvs(queueRecord.addr_line_1$,2)<>"" and cvs(gmqCustomer.addr_line_1$,2)="" then gmqCustomer.addr_line_1$=queueRecord.addr_line_1$
					if cvs(queueRecord.addr_line_2$,2)<>"" and cvs(gmqCustomer.addr_line_2$,2)="" then gmqCustomer.addr_line_2$=queueRecord.addr_line_2$
					if cvs(queueRecord.addr_line_3$,2)<>"" and cvs(gmqCustomer.addr_line_3$,2)="" then gmqCustomer.addr_line_3$=queueRecord.addr_line_3$
					if cvs(queueRecord.city$,2)<>"" and cvs(gmqCustomer.city$,2)="" then gmqCustomer.city$=queueRecord.city$
					if cvs(queueRecord.state_code$,2)<>"" and cvs(gmqCustomer.state_code$,2)="" then gmqCustomer.state_code$=queueRecord.state_code$
					if cvs(queueRecord.zip_code$,2)<>"" and cvs(gmqCustomer.zip_code$,2)="" then gmqCustomer.zip_code$=queueRecord.zip_code$
					if cvs(queueRecord.cntry_id$,2)<>"" and cvs(gmqCustomer.cntry_id$,2)="" then gmqCustomer.cntry_id$=queueRecord.cntry_id$
					if cvs(queueRecord.country$,2)<>"" and cvs(gmqCustomer.country$,2)="" then gmqCustomer.country$=queueRecord.country$

					writerecord(gmqCustomer_dev)gmqCustomer$
				endif
			wend
		endif

	endif

[[ARM_CUSTMAST.CUSTOMER_ID.AVAL]]
rem --- Validate Customer Number
	customer_id$=callpoint!.getUserInput()
	if num(customer_id$,err=*next)=0  then callpoint!.setStatus("ABORT")

[[ARM_CUSTMAST.CUSTOMER_NAME.AVAL]]
rem --- Set Alternate Sequence for new customers
	if user_tpl.new_cust$="Y"
		dim armCustmast$:fnget_tpl$("ARM_CUSTMAST")
		wk$=fattr(armCustmast$,"ALT_SEQUENCE")
		dim alt_sequence$(dec(wk$(10,2)))
		alt_sequence$(1)=callpoint!.getUserInput()
		callpoint!.setColumnData("ARM_CUSTMAST.ALT_SEQUENCE",alt_sequence$,1)
	endif

[[ARM_CUSTDET.CUSTOMER_TYPE.AVAL]]
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

[[ARM_CUSTDET.DISC_CODE.AVAL]]
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

[[ARM_CUSTDET.FRT_TERMS.AVAL]]
rem --- Don't allow inactive code
	opmFrtTerms_dev=fnget_dev("OPM_FRTTERMS")
	dim opmFrtTerms$:fnget_tpl$("OPM_FRTTERMS")
	frt_terms$=callpoint!.getUserInput()
	read record(opmFrtTerms_dev,key=firm_id$+"A"+frt_terms$,dom=*next)opmFrtTerms$
	if opmFrtTerms.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opmFrtTerms.frt_terms$,3)
		msg_tokens$[2]=cvs(opmFrtTerms.description$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARM_CUSTDET.MESSAGE_CODE.AVAL]]
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

[[ARM_CUSTMAST.PAY_AUTH_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Warn when pay_auth_email doesn't match ARS_CC_CUSTPMT Report Control Recipients email-to address
	pay_auth_email$=callpoint!.getUserInput()
	recipient_email_to$=cvs(callpoint!.getDevObject("recipient_email_to"),2)
	if recipient_email_to$<>"" and pay_auth_email$<>callpoint!.getColumnData("ARM_CUSTMAST.PAY_AUTH_EMAIL") then
		if cvs(pay_auth_email$,2)<>recipient_email_to$ then
			rem --- Set background color for bad pay_auth_email
			payAuthEmail!=callpoint!.getControl("ARM_CUSTMAST.PAY_AUTH_EMAIL")
			call stbl("+DIR_SYP",err=*endif)+"bac_create_color.bbj","+ENTRY_ERROR_COLOR","255,224,224",rdErrorColor!,""
			payAuthEmail!.setBackColor(rdErrorColor!)
			callpoint!.setDevObject("match_email_to","BAD")

			rem --- Warn pay_auth_email doesn't match ARS_CC_CUSTPMT Report Control Recipients email-to address
			msg_id$="AR_FIX_PAYAUTHEMAIL"
			dim msg_tokens$[1]
			gosub disp_message
			if msg_opt$="Y" then
				recipient_email_to$=callpoint!.getDevObject("recipient_email_to")
				callpoint!.setUserInput(recipient_email_to$)
				callpoint!.setDevObject("match_email_to","OK")
				callpoint!.setStatus("MODIFIED")
			else
				rem --- Set background color for bad pay_auth_email
				payAuthEmail!.setBackColor(rdErrorColor!)
			endif
		endif
	endif

[[ARM_CUSTMAST.PAY_AUTH_EMAIL.BINP]]
rem --- Warn when pay_auth_email doesn't match ARS_CC_CUSTPMT Report Control Recipients email-to address
	if callpoint!.getDevObject("match_email_to")<>"OK" then
		rem --- Set background color for bad pay_auth_email
		payAuthEmail!=callpoint!.getControl("ARM_CUSTMAST.PAY_AUTH_EMAIL")
		call stbl("+DIR_SYP",err=*endif)+"bac_create_color.bbj","+ENTRY_ERROR_COLOR","255,224,224",rdErrorColor!,""
		payAuthEmail!.setBackColor(rdErrorColor!)
		callpoint!.setDevObject("match_email_to","BAD")

		rem --- Warn pay_auth_email doesn't match ARS_CC_CUSTPMT Report Control Recipients email-to address
		msg_id$="AR_FIX_PAYAUTHEMAIL"
		dim msg_tokens$[1]
		gosub disp_message
		if msg_opt$="Y" then
			recipient_email_to$=callpoint!.getDevObject("recipient_email_to")
			callpoint!.setColumnData("ARM_CUSTMAST.PAY_AUTH_EMAIL",recipient_email_to$,1)
			callpoint!.setDevObject("match_email_to","OK")
			callpoint!.setStatus("MODIFIED")
		endif
	endif

[[ARM_CUSTDET.PRICING_CODE.AVAL]]
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

[[ARM_CUSTMAST.SHIPPING_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARM_CUSTDET.SLSPSN_CODE.AVAL]]
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

[[ARM_CUSTDET.TAX_CODE.AVAL]]
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

[[ARM_CUSTDET.TERRITORY.AVAL]]
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

[[ARM_CUSTMAST.<CUSTOM>]]
rem =======================================================
create_widgets:rem --- create pie and bar widgets to show aged balance (bar in case credits)
rem =======================================================

	use ::dashboard/widget.bbj::EmbeddedWidgetFactory
	use ::dashboard/widget.bbj::EmbeddedWidget
	use ::dashboard/widget.bbj::EmbeddedWidgetControl
	use ::dashboard/widget.bbj::BarChartWidget
	use ::dashboard/widget.bbj::ChartWidget

	ctl_name$="ARM_CUSTDET.AGING_FUTURE"
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	ctl1!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctl_name$="<<DISPLAY>>.DSP_BALANCE"
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	ctl2!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctl_name$="ARM_CUSTPMTS.NMTD_SALES"
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	ctl3!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	childWin!=SysGUI!.getWindow(ctlContext).getControl(0)
	save_ctx=SysGUI!.getContext()
	SysGUI!.setContext(ctlContext)

rem --- Create either a pie chart or bar chart - the latter if any of the aging buckets are negative

	rem --- pie
	name$="CUSTAGNG_PIE"
	title$ = Translate!.getTranslation("AON_AGING","Customer Aging",1)
	chartTitle$ = ""
	flat = 0
	legend=0
	numSlices=6
	widgetY=ctl1!.getY()
	widgetHeight=ctl2!.getY()+ctl2!.getHeight()-ctl1!.getY()
	widgetWidth=widgetHeight+widgetHeight*.75
	widgetX=ctl3!.getX()+ctl3!.getWidth()-widgetWidth

	agingDashboardPieWidget! = EmbeddedWidgetFactory.createPieChartEmbeddedWidget(name$,title$,chartTitle$,flat,legend,numSlices)
  	agingPieWidget! = agingDashboardPieWidget!.getWidget()
	agingPieWidget!.setChartColorTheme(ChartWidget.getColorThemeColorful2())
	agingPieWidget!.setLabelFormat("{0}: {1}", java.text.NumberFormat.getCurrencyInstance(), java.text.NumberFormat.getPercentInstance())
	
	days$=" "+Translate!.getTranslation("AON_DAYS","Days",1)+":"
	agingPieWidget!.setDataSetValue(Translate!.getTranslation("AON_FUTURE","Future",1), 0)
	agingPieWidget!.setDataSetValue(Translate!.getTranslation("AON_CURRENT","Current",1), 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_1)+days$, 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_2)+days$, 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_3)+days$, 0)
	agingPieWidget!.setDataSetValue(str(ars01a.age_per_days_4)+"+"+days$, 0)
	agingPieWidget!.setFontScalingFactor(1.2)

	agingPieWidgetControl! = new EmbeddedWidgetControl(agingDashboardPieWidget!,childWin!,widgetX,widgetY,widgetWidth,widgetHeight,$$)
	agingPieWidgetControl!.setVisible(0)

	rem --- bar
	name$="CUSTAGNG_BAR"
	title$ = Translate!.getTranslation("AON_AGING","Customer Aging",1)
	chartTitle$ = ""
	domainTitle$ = ""
	rangeTitle$ = Translate!.getTranslation("AON_BALANCE","Balance",1)
	flat = 0
	orientation=BarChartWidget.getORIENTATION_VERTICAL() 
	legend=1

	agingDashboardBarWidget! = EmbeddedWidgetFactory.createBarChartEmbeddedWidget(name$,title$,chartTitle$,domainTitle$,rangeTitle$,flat,orientation,legend)
	agingBarWidget! = agingDashboardBarWidget!.getWidget()
	agingBarWidget!.setChartColorTheme(ChartWidget.getColorThemeColorful2())
	agingBarWidget!.setChartRangeAxisToCurrency()

	agingBarWidget!.setDataSetValue(Translate!.getTranslation("AON_FUT","Fut",1), "",0)
	agingBarWidget!.setDataSetValue(Translate!.getTranslation("AON_CUR","Cur",1), "", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_1),"", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_2), "", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_3), "", 0)
	agingBarWidget!.setDataSetValue(str(ars01a.age_per_days_4)+"+", "", 0)

	agingBarWidgetControl! = new EmbeddedWidgetControl(agingDashboardBarWidget!,childWin!,widgetX,widgetY,widgetWidth,widgetHeight,$$)
	agingBarWidgetControl!.setVisible(0)

	callpoint!.setDevObject("dbPieWidget",agingDashboardPieWidget!)
	callpoint!.setDevObject("dbPieWidgetControl",agingPieWidgetControl!)
	callpoint!.setDevObject("dbBarWidget",agingDashboardBarWidget!)
	callpoint!.setDevObject("dbBarWidgetControl",agingBarWidgetControl!)

	SysGUI!.setContext(save_ctx)

	return

rem ===================================
disable_ctls:rem --- disable selected control
rem ===================================

    for dctl=1 to 17
        dctl$=dctl$[dctl]
        if dctl$<>""
            wctl$=str(num(callpoint!.getTableColumnAttribute(dctl$,"CTLI")):"00000")
	 wmap$=callpoint!.getAbleMap()
            wpos=pos(wctl$=wmap$,8)
            wmap$(wpos+6,1)="I"
	 callpoint!.setAbleMap(wmap$)
            callpoint!.setStatus("ABLEMAP")
        endif
    next dctl
    return

#include [+ADDON_LIB]std_missing_params.aon



