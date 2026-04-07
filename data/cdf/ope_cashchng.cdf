[[OPE_CASHCHNG.ASVA]]
rem --- Capture the new customer_id to use
	callpoint!.setDevObject("newCustomerId",callpoint!.getColumnData("OPE_CASHCHNG.CUSTOMER_ID"))

[[OPE_CASHCHNG.BSHO]]
rem --- Initializations
	callpoint!.setDevObject("newCustomerId","")

rem --- Open needed files
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARM_CUSTMAST",  open_opts$[1]="OTA"
	open_tables$[2]="OPS_PARAMS",  open_opts$[2]="OTA"
	open_tables$[3]="OPM_POINTOFSALE",  open_opts$[3]="OTA"

	gosub open_tables
        
	opsParams=num(open_chans$[2]); dim opsParams$:open_tpls$[2]

 rem --- Get needed OP params
	readrecord(opsParams,key=firm_id$+"AR00")opsParams$
	callpoint!.setDevObject("allow_cash_sale",opsParams.cash_sale$)
	callpoint!.setDevObject("cash_customer",opsParams.customer_id$)

[[OPE_CASHCHNG.CUSTOMER_ID.AVAL]]
rem --- Don't allow using inactive customer
	newCustomerId$=callpoint!.getUserInput()
	armCustMast_dev=fnget_dev("ARM_CUSTMAST")
	dim armCustMast$:fnget_tpl$("ARM_CUSTMAST")
	findrecord(armCustMast_dev,key=firm_id$+newCustomerId$,err=*next)armCustMast$
	if armCustMast.cust_inactive$="Y" then
		call stbl("+DIR_PGM")+"adc_getmask.aon","CUSTOMER_ID","","","",m0$,0,customer_size
		msg_id$="AR_CUST_INACTIVE"
		dim msg_tokens$[2]
	   	msg_tokens$[1]=fnmask$(armCustMast.customer_id$(1,customer_size),m0$)
		msg_tokens$[2]=cvs(armCustMast.customer_name$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Do NOT allow new customer to be the "cash customer"
	if callpoint!.getDevObject("allow_cash_sale")="Y" and cvs(newCustomerId$,2)=cvs(callpoint!.getDevObject("cash_customer"),2) then
		msg_id$="OP_NOT_CSH_CUST"
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Do NOT allow new customer to be a POS Default Quote Customer
	quoteCustomer=0
	opmPointOfSale_dev=fnget_dev("OPM_POINTOFSALE")
	dim opmPointOfSale$:fnget_tpl$("OPM_POINTOFSALE")
	read(opmPointOfSale_dev,key=firm_id$,dom=*next)
	while 1
		opmPointOfSale_key$=key(opmPointOfSale_dev,end=*break)
		if pos(firm_id$=opmPointOfSale_key$)<>1 then break
		readrecord(opmPointOfSale_dev)opmPointOfSale$
		if newCustomerId$=opmPointOfSale.quote_cust_id$ then
			msg_id$="OP_CASH_TO_QUOTE"
			gosub disp_message
			quoteCustomer=1
			break
		endif
	wend
	if quoteCustomer then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Initialize "new" fields
	callpoint!.setColumnData("OPE_CASHCHNG.ADDR_LINE_1",armCustMast.addr_line_1$,1)
	callpoint!.setColumnData("OPE_CASHCHNG.ADDR_LINE_2",armCustMast.addr_line_2$,1)
	callpoint!.setColumnData("OPE_CASHCHNG.ADDR_LINE_3",armCustMast.addr_line_3$,1)
	callpoint!.setColumnData("OPE_CASHCHNG.ADDR_LINE_4",armCustMast.addr_line_4$,1)
	callpoint!.setColumnData("OPE_CASHCHNG.CITY",armCustMast.city$,1)
	callpoint!.setColumnData("OPE_CASHCHNG.STATE_CODE",armCustMast.state_code$,1)

[[OPE_CASHCHNG.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon



