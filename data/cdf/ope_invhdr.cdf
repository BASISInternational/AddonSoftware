[[OPE_INVHDR.ACUS]]
rem --- Process custom event
rem This routine is executed when callbacks have been set to run a 'custom event'.
rem Analyze gui_event$ and notice$ to see which control's callback triggered the event, and what kind of event it is.
rem See basis docs notice() function, noticetpl() function, notify event, grid control notify events for more info.

	dim gui_event$:tmpl(gui_dev)
	dim notify_base$:noticetpl(0,0)
	gui_event$=SysGUI!.getLastEventString()
	ctl_ID=dec(gui_event.ID$)

	notify_base$=notice(gui_dev,gui_event.x%)
	dim notice$:noticetpl(notify_base.objtype%,gui_event.flags%)
	notice$=notify_base$

	rem --- The tab control
	if ctl_ID=num(stbl("+TAB_CTL")) then
		switch notice.code
			case 2; rem --- ON_TAB_SELECT
				gosub isTotalsTab
				if isTotalsTab then
					callpoint!.setFocus("OPE_INVHDR.FREIGHT_AMT",1)
					if num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))=1 then
						taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
						taxAmount_warn!.setVisible(1)
						if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"),2)<>"" and
:						cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),2)<>"" then
							disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
							freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
							gosub calculate_tax
						endif
					endif
				else
					taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
					taxAmount_warn!.setVisible(0)
				endif
			break
		swend
	endif

[[OPE_INVHDR.ADEL]]
rem --- Set flag

	user_tpl.record_deleted = 1

rem --- clear availability

	gosub clear_avail

	file_name$ = "OPE_INVHDR"
	ope01_dev = fnget_dev(file_name$)
	ope01_tpl$=fnget_tpl$(file_name$)
	dim ope01a$:ope01_tpl$
	ope01a$ = util.copyFields(ope01_tpl$, callpoint!)
	ope01a.invoice_type$ = "V"
	ope01a.print_status$="Y"

	ope01a$ = field(ope01a$)
	write record (ope01_dev) ope01a$
	ope01_key$=ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$+ope01a.customer_id$+ope01a.order_no$+ope01a.ar_inv_no$
	extractrecord(ope01_dev,key=ope01_key$)ope01a$; rem Advisory Locking

[[OPE_INVHDR.ADIS]]
rem --- Check locked status

	gosub check_lock_flag

	if locked then
		user_tpl.do_end_of_form = 0
		callpoint!.setStatus("NEWREC")
		break; rem --- exit callpoint
	endif

rem --- Check Print flag

	gosub check_print_flag

	if locked then
		rem --- invoice locked so skip it and start a new one
		user_tpl.do_end_of_form = 0
		callpoint!.clearStatus()
		callpoint!.setStatus("NEWREC")
		break; rem --- exit callpoint
	endif

rem --- Check Fulfillment
	optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
	dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	ar_inv_no$=optFillmntHdr.ar_inv_no$
	inFulfillmnt=0
	extractrecord(optFillmntHdr_dev,key=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$,knum="AO_STATUS",dom=*next)optFillmntHdr$; inFulfillmnt=1
	if inFulfillmnt then
		packingDone=0
		if optFillmntHdr.all_packed$="Y" then packingDone=1

		rem --- All cartons shipped?
		shippingDone=1
		optCartHdr_dev = fnget_dev("OPT_CARTHDR")
		dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
		optCartHdr_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
		read(optCartHdr_dev,key=optCartHdr_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optCartHdr_key$=key(optCartHdr_dev,end=*break)
			if pos(optCartHdr_trip$=optCartHdr_key$)<>1then break
			readrecord(optCartHdr_dev)optCartHdr$
			if optCartHdr.shipped_flag$="Y" then continue
			shippingDone=0
			break
		wend

		if !packingDone or !shippingDone then
			rem --- Order not completed in Fulfillment, so skip it and start a new one
			msg_id$="OP_ORD_IN_FILLMNT"
			gosub disp_message

			user_tpl.do_end_of_form = 0
			callpoint!.clearStatus()
			callpoint!.setStatus("NEWREC")
			break; rem --- exit callpoint
		endif
	endif

rem --- Check for order, force to an Invoice

	if callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG") <> "I" then
		gosub make_invoice
		if locked then
			user_tpl.do_end_of_form = 0
		endif
	endif

rem --- Show customer data
	
	cust_id$ = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")

	if cvs(cust_id$,3)=""
		callpoint!.setStatus("NEWREC")
		break
	endif

	gosub display_customer

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE") <> "Y" then 
		gosub display_aging
		gosub check_credit
	endif

	gosub disp_cust_comments

rem --- Display Ship to information

	ship_to_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	ship_to_no$   = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	order_no$     = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	gosub ship_to_info

rem --- Set comm percent (if calling up a B/O, it will have been cleared);rem bug 8001 CAH

	slsp$=callpoint!.getColumnData("OPE_INVHDR.SLSPSN_CODE")
	gosub get_comm_percent

rem --- Enable buttons

	callpoint!.setOptionEnabled("PRNT", 1)
	callpoint!.setOptionEnabled("TTLS",1)
	callpoint!.setOptionEnabled("SHPT",1)
	gosub able_cash_sale

	if callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG") = "I" then
		callpoint!.setOptionEnabled("UINV",1)
	else
		callpoint!.setOptionEnabled("UINV",0)
	endif

	callpoint!.setOptionEnabled("AGNG",iff(callpoint!.getDevObject("on_demand_aging")="Y",1,0))

rem --- Enable/disable Freight Amount
	if cvs(callpoint!.getColumnData("OPE_INVHDR.SHIPPING_ID"),2)<>"" then
		callpoint!.setColumnEnabled("OPE_INVHDR.FREIGHT_AMT",0)
		callpoint!.setColumnData("OPE_INVHDR.FREIGHT_AMT",str(0),1)
	else
		callpoint!.setColumnEnabled("OPE_INVHDR.FREIGHT_AMT",1)
	endif

rem --- Set all previous values

	user_tpl.prev_ext_cost     = num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_COST"))
	user_tpl.prev_disc_code$   = callpoint!.getColumnData("OPE_INVHDR.DISC_CODE")
	user_tpl.prev_ship_to$     = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	user_tpl.prev_sales_total  = num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES"))

rem --- Reset default warehouse for existing order
	user_tpl.warehouse_id$ = callpoint!.getDevObject("defaultWhse")

rem --- Set other codes
        
	user_tpl.price_code$   = callpoint!.getColumnData("OPE_INVHDR.PRICE_CODE")
	user_tpl.pricing_code$ = callpoint!.getColumnData("OPE_INVHDR.PRICING_CODE")
	user_tpl.order_date$   = callpoint!.getColumnData("OPE_INVHDR.ORDER_DATE")
	user_tpl.disc_code$    = callpoint!.getColumnData("OPE_INVHDR.DISC_CODE")
	user_tpl.new_order     = 0
	user_tpl.record_deleted = 0

rem --- Set OrderHelper object fields

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setCust_id(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"))
	ordHelp!.setOrder_no(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"))
	ordHelp!.setInv_type(callpoint!.getColumnData("OPE_INVHDR.INVOICE_TYPE"))
	ordHelp!.setTaxCode(callpoint!.getColumnData("OPE_INVHDR.TAX_CODE"))

rem --- Clear availability

	gosub clear_avail

rem --- Capture current totals so we can tell later if they were changed in the grid

	callpoint!.setDevObject("initial_rec_data$",rec_data$)
	callpoint!.setDevObject("discount_amt",callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	callpoint!.setDevObject("freight_amt",callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	callpoint!.setDevObject("tax_amount",callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"))
	callpoint!.setDevObject("taxable_amt",callpoint!.getColumnData("OPE_INVHDR.TAXABLE_AMT"))
	callpoint!.setDevObject("total_cost",callpoint!.getColumnData("OPE_INVHDR.TOTAL_COST"))
	callpoint!.setDevObject("total_sales",callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES"))
	callpoint!.setDevObject("commit_sls_tax","N")

rem --- Show TAX_AMOUNT footnote warning if sales tax calculation was previously deferred
	taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
        taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
	if num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))=1 then
		taxAmount_fnote!.setVisible(1)
		gosub isTotalsTab
		if isTotalsTab then taxAmount_warn!.setVisible(1)

		rem - Update sales tax calculation to use SalesInvoice for sales tax service
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	else
		taxAmount_warn!.setVisible(0)
		taxAmount_fnote!.setVisible(0)
	endif

rem --- Disable Ship To fields

	ship_to_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	gosub disable_shipto

rem --- Using a sales tax service?
	tax_code$=callpoint!.getColumnData("OPE_INVHDR.TAX_CODE")
	gosub usingTaxService

rem --- Write Order Addresses file
	gosub write_address_file

[[OPE_INVHDR.AFMC]]
rem --- Inits

	use ::ado_util.src::util
	use ::ado_order.src::OrderHelper
	use ::adc_array.aon::ArrayObject
	use ::opo_AvaTaxInterface.aon::AvaTaxInterface

rem --- Create Inventory Availability window

	grid!  = util.getGrid(Form!)
	child! = util.getChild(Form!)
	cxt    = SysGUI!.getAvailableContext()

	mwin! = child!.addChildWindow(15000, 0, 10, child!.getWidth(), 75, "", $00000800$, cxt)
	mwin!.addGroupBox(15999, 0, 5, grid!.getWidth(), 65, Translate!.getTranslation("AON_INVENTORY_AVAILABILITY"), $$)

	mwin!.addStaticText(15001,15,25,75,15,Translate!.getTranslation("AON_ON_HAND:"),$$)
	mwin!.addStaticText(15002,15,40,75,15,Translate!.getTranslation("AON_COMMITTED:"),$$)
	mwin!.addStaticText(15003,215,25,75,15,Translate!.getTranslation("AON_AVAILABLE:"),$$)
	mwin!.addStaticText(15004,215,40,75,15,Translate!.getTranslation("AON_ON_ORDER:"),$$)
	mwin!.addStaticText(15005,415,25,75,15,Translate!.getTranslation("AON_WAREHOUSE:"),$$)
	mwin!.addStaticText(15006,415,40,75,15,Translate!.getTranslation("AON_TYPE:"),$$)

	inv_avail_title!=mwin!.addStaticText(15010,125,5,100,15,"",$4010$)
	callpoint!.setDevObject("inv_avail_title",inv_avail_title!)

rem --- Save controls in the global userObj! (vector)

	userObj! = SysGUI!.makeVector()
	userObj!.addItem(grid!) 
	userObj!.addItem(mwin!)

	userObj!.addItem(mwin!.addStaticText(15101,90,25,75,15,"",$8000$))
	userObj!.addItem(mwin!.addStaticText(15102,90,40,75,15,"",$8000$))
	userObj!.addItem(mwin!.addStaticText(15103,295,25,75,15,"",$8000$))
	userObj!.addItem(mwin!.addStaticText(15104,295,40,75,15,"",$8000$))
	userObj!.addItem(mwin!.addStaticText(15105,490,25,200,15,"",$0000$))
	userObj!.addItem(mwin!.addStaticText(15106,490,40,75,15,"",$0000$))
	userObj!.addItem(mwin!.addStaticText(15107,695,20,75,15,"",$0000$)); rem Dropship text (8)
	userObj!.addItem(mwin!.addStaticText(15108,695,35,160,15,"",$0000$)); rem Manual Price  (9)
	userObj!.addItem(mwin!.addStaticText(15109,695,50,160,15,"",$0000$)); rem Alt/Super  (10)

rem --- Add static label warning for TAX_AMOUNT to identify it as possibly being incorrect
	tax_amount!=fnget_control!("OPE_INVHDR.TAX_AMOUNT")
	tax_amount_x=tax_amount!.getX()
	tax_amount_y=tax_amount!.getY()
	tax_amount_height=tax_amount!.getHeight()
	tax_amount_width=tax_amount!.getWidth()
	label_width=15
	nxt_ctlID=util.getNextControlID()
	taxAmount_warn!=Form!.addStaticText(nxt_ctlID,tax_amount_x+tax_amount_width+8,tax_amount_y+85,label_width,tax_amount_height-6,"")
	taxAmount_warn!.setText("??")
	taxAmount_warn!.setForeColor(BBjColor.RED)
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	taxAmount_warn!.setBackColor(tabCtrl!.getBackColor())
	taxAmount_warn!.setVisible(0)
	callpoint!.setDevObject("taxAmount_warn",taxAmount_warn!)

rem --- Add static label footnote for TAX_AMOUNT to identify it as possibly being incorrect
	order_no!=fnget_control!("OPE_INVHDR.ORDER_NO")
	order_no_x=order_no!.getX()
	order_no_y=order_no!.getY()
	order_no_height=order_no!.getHeight()
	order_no_width=order_no!.getWidth()
	label_width=550
	nxt_ctlID=util.getNextControlID()
	taxAmount_fnote!=Form!.addStaticText(nxt_ctlID,order_no_x+150,order_no_y+30,label_width,order_no_height-6,"")
	taxAmount_fnote!.setText("?? - "+Translate!.getTranslation("AON_TAX_AMT_FNOTE"))
	taxAmount_fnote!.setForeColor(BBjColor.RED)
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	taxAmount_fnote!.setBackColor(tabCtrl!.getBackColor())
	taxAmount_fnote!.setVisible(0)
	callpoint!.setDevObject("taxAmount_fnote",taxAmount_fnote!)

[[OPE_INVHDR.AOPT-AGNG]]
rem --- Update this customer's aging stats if allowed by param
	
	rem --- Skip unless current processing date is greater than last aging date
	armCustDet_dev=fnget_dev("ARM_CUSTDET")
	dim armCustDet$:fnget_tpl$("ARM_CUSTDET")
	armCustDet.firm_id$=firm_id$
	armCustDet.customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	armCustDet.ar_type$=""
	readrecord(armCustDet_dev,key=armCustDet.firm_id$+armCustDet.customer_id$+armCustDet.ar_type$)armCustDet$
	if cvs(armCustDet.report_type$,2)="" then armCustDet.report_type$=iff(cvs(callpoint!.getDevObject("dflt_age_by"),2)="","I",callpoint!.getDevObject("dflt_age_by"))
	sysDate$=stbl("+SYSTEM_DATE")
	if sysDate$>armCustDet.report_date$ then
		customer_id$=armCustDet.customer_id$
		endcust$=customer_id$
		call stbl("+DIR_PGM")+"arc_custaging.aon",customer_id$,endcust$,sysDate$,armCustDet.report_type$,status
		rem --- re-read cust detail record and refresh aging fields
		readrecord(armCustDet_dev,key=armCustDet.firm_id$+armCustDet.customer_id$+armCustDet.ar_type$)armCustDet$
		callpoint!.setColumnData("<<DISPLAY>>.AGING_FUTURE",armCustDet.aging_future$,1)
		callpoint!.setColumnData("<<DISPLAY>>.AGING_CUR",armCustDet.aging_cur$,1)
		callpoint!.setColumnData("<<DISPLAY>>.AGING_30",armCustDet.aging_30$,1)
		callpoint!.setColumnData("<<DISPLAY>>.AGING_60",armCustDet.aging_60$,1)
		callpoint!.setColumnData("<<DISPLAY>>.AGING_90",armCustDet.aging_90$,1)
		callpoint!.setColumnData("<<DISPLAY>>.AGING_120",armCustDet.aging_120$,1)
		callpoint!.setColumnData("<<DISPLAY>>.REPORT_DATE",armCustDet.report_date$,1)
		switch pos(armCustDet.report_type$=" DI")
			case 1
				report_type$=""
				break
			case 2
				report_type$="D - Due Date"
				break
			case 3
				report_type$="I - Invoice Date"
				break
			case default
				report_type$="Unknown"
				break
		swend
		callpoint!.setColumnData("<<DISPLAY>>.REPORT_TYPE",report_type$,1)
	endif

[[OPE_INVHDR.AOPT-CASH]]
rem --- Check minimum cash sale
	min_csh_sale=callpoint!.getDevObject("min_csh_sale")
	ord_tot=num(callpoint!.getColumnData("<<DISPLAY>>.ORDER_TOT"))
	if ord_tot>0 and ord_tot<min_csh_sale
		call stbl("+DIR_PGM")+"adc_getmask.aon","","AR","A",imsk$,omsk$,ilen,olen
		msg_id$="OP_CASH_UNDER_MIN"
		dim msg_tokens$[1]
		msg_tokens$[1]=str(min_csh_sale:omsk$)
		gosub disp_message
		if msg_opt$="N"
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Allow overriding failed or deferred sales tax calculation
	gosub overrideSalesTax
	if abort then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Launch Cash Transaction

	gosub get_cash

rem --- Do we need to print an invoice first?

	if callpoint!.getDevObject( "print_invoice" ) = "Y" then
		gosub do_invoice
		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Start a new record after a cash sale

	if invoicePrinted and callpoint!.getDevObject("cash_code_type")<>"" then
		user_tpl.do_end_of_form = 0
		callpoint!.setStatus("NEWREC-ACTIVATE")
	endif

[[OPE_INVHDR.AOPT-CINV]]
rem --- Credit Historical Invoice

	line_sign=-1
	gosub copy_order

[[OPE_INVHDR.AOPT-CRCH]]
print "Hdr:AOPT:CRCH"; rem debug

rem --- Force totalling open orders for credit status

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.forceTotalOpenOrders()

rem --- Do credit status (management)

	cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"); rem can be null

	if user_tpl.credit_installed$ = "Y" and user_tpl.display_bal$ <> "N" and cvs(cust_id$, 2) <> "" then
		print "---about to start credit management"; rem debug
		call user_tpl.pgmdir$+"opc_creditmgmnt.aon", cust_id$, order_no$, table_chans$[all], callpoint!, status
		callpoint!.setDevObject("credit_status_done", "Y")
		callpoint!.setStatus("ACTIVATE")
	endif

[[OPE_INVHDR.AOPT-DINV]]
rem --- Duplicate Historical Invoice

	line_sign=1
	gosub copy_order

[[OPE_INVHDR.AOPT-PRNT]]
rem --- Print Now
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")

rem --- Make sure modified records are saved before printing
	if pos("M"=callpoint!.getRecordStatus())
		gosub get_disk_rec
		write record (ordhdr_dev) ordhdr_rec$
		ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
		extractrecord(ordhdr_dev,key=ordhdr_key$)ordhdr_rec$; rem Advisory Locking

		rem --- Do not need to callpoint!.setStatus("SETORIG") here because the
		rem --- callpoint!.setStatus("RECORD:["+ ... "]") at the end of this callpoint will do it.
	endif

rem --- Add Barista soft lock for this record if not already in edit mode
	if !callpoint!.isEditMode() then
		rem --- Is there an existing soft lock?
		lock_table$="OPT_INVHDR"
		lock_record$=firm_id$+"E"+"  "+customer_id$+order_no$+ar_inv_no$
		lock_type$="C"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		if lock_status$="" then
			rem --- Add temporary soft lock used just for this print task
			lock_type$="L"
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		else
			rem --- Record locked by someone else
			msg_id$="ENTRY_REC_LOCKED"
			gosub disp_message
			break
		endif
	endif

rem --- Allow overriding failed or deferred sales tax calculation
	gosub overrideSalesTax
	if abort then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Get cash if needed for cash transaction

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE") = "Y" then
		gosub check_cash_due
		if cash_due then
			gosub get_cash
		endif
	endif

rem --- Print a counter Invoice

	if callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG") <> "I" then
		gosub make_invoice
		break
	endif

rem --- No need to check credit first

	gosub do_invoice
	callpoint!.setStatus("ACTIVATE")
	if invoicePrinted then
		user_tpl.do_end_of_form = 0
		callpoint!.clearStatus()
		callpoint!.setStatus("NEWREC")
	endif

rem --- Remove temporary soft lock used just for this print task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[OPE_INVHDR.AOPT-RTAX]]
rem --- Recalculate sales tax now
	disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_INVHDR.AOPT-SHP2]]
rem --- Launch Customer Ship-To Address form
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	key_pfx$=firm_id$+customer_id$

	dim dflt_data$[15,1]
	dflt_data$[1,0] = "NAME"
	dflt_data$[1,1] = callpoint!.getColumnData("<<DISPLAY>>.SNAME")
	dflt_data$[2,0] = "ADDR_LINE_1"
	dflt_data$[2,1] = callpoint!.getColumnData("<<DISPLAY>>.SADD1")
	dflt_data$[3,0] = "ADDR_LINE_2"
	dflt_data$[3,1] = callpoint!.getColumnData("<<DISPLAY>>.SADD2")
	dflt_data$[4,0] = "ADDR_LINE_3"
	dflt_data$[4,1] = callpoint!.getColumnData("<<DISPLAY>>.SADD3")
	dflt_data$[5,0] = "ADDR_LINE_4"
	dflt_data$[5,1] = callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	dflt_data$[6,0] = "CITY"
	dflt_data$[6,1] = callpoint!.getColumnData("<<DISPLAY>>.SCITY")
	dflt_data$[7,0] = "STATE_CODE"
	dflt_data$[7,1] = callpoint!.getColumnData("<<DISPLAY>>.SSTATE")
	dflt_data$[8,0] = "ZIP_CODE"
	dflt_data$[8,1] = callpoint!.getColumnData("<<DISPLAY>>.SZIP")
	dflt_data$[9,0] = "CNTRY_ID"
	dflt_data$[9,1] = callpoint!.getColumnData("<<DISPLAY>>.SCNTRY_ID")
	dflt_data$[10,0] = "SLSPSN_CODE"
	dflt_data$[10,1] = callpoint!.getColumnData("OPE_INVHDR.SLSPSN_CODE")
	dflt_data$[11,0] = "TERRITORY"
	dflt_data$[11,1] = callpoint!.getColumnData("OPE_INVHDR.TERRITORY")
	dflt_data$[12,0] = "TAX_CODE"
	dflt_data$[12,1] = callpoint!.getColumnData("OPE_INVHDR.TAX_CODE")
	dflt_data$[13,0] = "AR_SHIP_VIA"
	dflt_data$[13,1] = callpoint!.getColumnData("OPE_INVHDR.AR_SHIP_VIA")
	dflt_data$[14,0] = "SHIPPING_ID"
	dflt_data$[14,1] = callpoint!.getColumnData("OPE_INVHDR.SHIPPING_ID")
	dflt_data$[15,0] = "SHIPPING_EMAIL"
	dflt_data$[15,1] = callpoint!.getColumnData("OPE_INVHDR.SHIPPING_EMAIL")

	callpoint!.setDevObject("createNewShipToAddr","true")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"ARM_CUSTSHIP",
:		stbl("+USER_ID"),
:       	"MNT",
:       	key_pfx$,
:       	table_chans$[all],
:		"",
:		dflt_data$[all]

	rem --- Make sure focus returns to this form
	callpoint!.setStatus("ACTIVATE")

[[OPE_INVHDR.AOPT-SHPT]]
rem --- Launch Shipment Tracking maintenance grid
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	ship_seq_no$=callpoint!.getColumnData("OPE_INVHDR.SHIP_SEQ_NO")
	key_pfx$=firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"OPT_SHIPTRACK",
:       stbl("+USER_ID"),
:       "MNT",
:       key_pfx$,
:       table_chans$[all]

[[OPE_INVHDR.AOPT-UINV]]
rem --- Undo Invoice
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	old_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")

rem --- Make sure modified records are saved before un-doing
	if pos("M"=callpoint!.getRecordStatus())
		gosub get_disk_rec
		write record (ordhdr_dev) ordhdr_rec$
		ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
		extractrecord(ordhdr_dev,key=ordhdr_key$)ordhdr_rec$; rem Advisory Locking

		rem --- Do not need to callpoint!.setStatus("SETORIG") here because the
		rem --- callpoint!.setStatus("RECORD:["+ ... "]") at the end of this callpoint will do it.
	endif

rem --- Add Barista soft lock for this record if not already in edit mode
	if !callpoint!.isEditMode() then
		rem --- Is there an existing soft lock?
		lock_table$="OPT_INVHDR"
		lock_record$=firm_id$+"E"+ar_type$+cust_id$+order_no$+old_inv_no$
		lock_type$="C"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		if lock_status$="" then
			rem --- Add temporary soft lock used just for this print task
			lock_type$="L"
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		else
			rem --- Record locked by someone else
			msg_id$="ENTRY_REC_LOCKED"
			gosub disp_message
			break
		endif
	endif

rem --- Cannot undo if cash has been applied to invoice
	cashrct_dev = fnget_dev("OPE_INVCASH")
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	old_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
	if cvs(old_inv_no$,2)="" then break
	cashrct_found=0
	read (cashrct_dev, key=firm_id$+ar_type$+cust_id$+order_no$+old_inv_no$,dom=*next);cashrct_found=1
	if cashrct_found then
		msg_id$ = "OP_CANNOT_UNDO_INV"
		gosub disp_message
		break
	endif

rem --- Void AvaTax transaction if using a sales tax service
	if callpoint!.getDevObject("use_tax_service")="Y" then
		salesTax!=callpoint!.getDevObject("salesTaxObject")
		if cvs(callpoint!.getColumnData("OPE_INVHDR.CREDIT_INVOICE"),2)="" then
			transType$="SalesInvoice"
		else
			transType$="ReturnInvoice"
		endif
		success=0
		success=salesTax!.voidTransaction(cust_id$, order_no$, old_inv_no$, transType$, err=*next)
		if !success then
			msg_id$ = "OP_CANNOT_VOID_INV"
			gosub disp_message
			break
		endif
	endif

rem --- Invoice History Header, set to void

	file_name$      = "OPT_INVHDR"
	opt_invhdr_dev  = fnget_dev(file_name$)
	opt_invhdr_tpl$ = fnget_tpl$(file_name$)
	dim opt_invhdr_rec$:opt_invhdr_tpl$

	opt_invhdr_rec$ = util.copyFields(opt_invhdr_tpl$, callpoint!)
	opt_invhdr_rec.invoice_type$ = "V"
	opt_invhdr_rec.tax_amount=0
	opt_invhdr_rec.freight_amt=0
	opt_invhdr_rec.discount_amt=0
	opt_invhdr_rec.comm_percent=0
	opt_invhdr_rec.taxable_amt=0
	opt_invhdr_rec.comm_amt=0
	opt_invhdr_rec.total_sales=0
	opt_invhdr_rec.total_cost=0

	opt_invhdr_rec.mod_user$=sysinfo.user_id$
	opt_invhdr_rec.mod_date$=date(0:"%Yd%Mz%Dz")
	opt_invhdr_rec.mod_time$=date(0:"%Hz%mz")
	opt_invhdr_rec.trans_status$="U"
	opt_invhdr_rec$ = field(opt_invhdr_rec$)
	write record (opt_invhdr_dev) opt_invhdr_rec$

rem --- Reprint order"

	msg_id$ = "OP_REPRINT_ALSO"
	gosub disp_message
	reprint$ = msg_opt$

rem --- Reset Invoice record to Order

	file_name$      = "OPE_INVHDR"
	ope_invhdr_dev  = fnget_dev(file_name$)
	ope_invhdr_tpl$ = fnget_tpl$(file_name$)
	dim ope_invhdr_rec$:ope_invhdr_tpl$

	ope_invhdr_rec$ = util.copyFields(ope_invhdr_tpl$, callpoint!)
	ope_invhdr_rec.ar_inv_no$ = ""
	ope_invhdr_rec.ordinv_flag$ = "O"
	ope_invhdr_rec.print_status$ = "Y"
	ope_invhdr_rec.lock_status$ = "N"
	ope_invhdr_rec.invoice_date$=""

	ope_invhdr_rec.mod_user$=sysinfo.user_id$
	ope_invhdr_rec.mod_date$=date(0:"%Yd%Mz%Dz")
	ope_invhdr_rec.mod_time$=date(0:"%Hz%mz")

	callpoint!.setColumnData("OPE_INVHDR.AR_INV_NO", "")
	callpoint!.setColumnData("OPE_INVHDR.ORDINV_FLAG", "O")
	callpoint!.setColumnData("OPE_INVHDR.PRINT_STATUS", "Y")
	callpoint!.setColumnData("OPE_INVHDR.LOCK_STATUS", "N")
	callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT", "0")
	callpoint!.setColumnData("OPE_INVHDR.FREIGHT_AMT", "0")
	callpoint!.setColumnData("OPE_INVHDR.DISCOUNT_AMT", "0")
	callpoint!.setColumnData("OPE_INVHDR.INVOICE_DATE","")
	callpoint!.setColumnData("OPE_INVHDR.MOD_USER",opt_invhdr_rec.mod_user$)
	callpoint!.setColumnData("OPE_INVHDR.MOD_DATE",opt_invhdr_rec.mod_date$)
	callpoint!.setColumnData("OPE_INVHDR.MOD_TIME",opt_invhdr_rec.mod_time$)
		
	if reprint$ = "Y" then
		ope_invhdr_rec.reprint_flag$ = "Y"
		callpoint!.setColumnData("OPE_INVHDR.REPRINT_FLAG", "Y")
	else
		ope_invhdr_rec.reprint_flag$ = ""
		callpoint!.setColumnData("OPE_INVHDR.REPRINT_FLAG", "")
	endif

	ope_invhdr_rec$ = field(ope_invhdr_rec$)
	write record (ope_invhdr_dev) ope_invhdr_rec$

rem --- Reset the print file

	file_name$ = "OPE_PRNTLIST"
	prntlist_dev = fnget_dev(file_name$)
	dim prntlist_rec$:fnget_tpl$(file_name$)

	remove (prntlist_dev, key=firm_id$+"I  "+cust_id$+order_no$, dom=*next)

	if reprint$ = "Y" then
		prntlist_rec.firm_id$     = firm_id$
		prntlist_rec.ordinv_flag$ = "O"
		prntlist_rec.customer_id$ = cust_id$
		prntlist_rec.order_no$    = order_no$
		prntlist_key$=prntlist_rec.firm_id$+prntlist_rec.ordinv_flag$+prntlist_rec.ar_type$+prntlist_rec.customer_id$+prntlist_rec.order_no$
		extract record(prntlist_dev,key=prntlist_key$,dom=*next)x$; rem Advisory Locking
		prntlist_rec$ = field(prntlist_rec$)
		write record (prntlist_dev) prntlist_rec$
	endif

	rem --- Replace ope_invdet ope-11 records
	ope11_dev = fnget_dev("OPE_INVDET")
	dim ope11a$:fnget_tpl$("OPE_INVDET")
	status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	ope11_trip$=firm_id$+status$+ar_type$+cust_id$+order_no$+old_inv_no$
	read (ope11_dev, key=ope11_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
	while 1
		ope11_key$=key(ope11_dev,end=*break)
		if pos(ope11_trip$=ope11_key$)<>1 then break
		extractrecord(ope11_dev)ope11a$; rem Advisory locking
		ope11a.ar_inv_no$=""
		ope11a.mod_user$=sysinfo.user_id$
		ope11a.mod_date$=date(0:"%Yd%Mz%Dz")
		ope11a.mod_time$=date(0:"%Hz%mz")
		ope11a$=field(ope11a$)
		writerecord(ope11_dev)ope11a$
		ope11_primary$=ope11a.firm_id$+ope11a.ar_type$+ope11a.customer_id$+ope11a.order_no$+old_inv_no$+ope11a.internal_seq_no$
		remove(ope11_dev,key=ope11_primary$)
		read(ope11_dev,key=ope11_key$,dom=*next)
	wend

	rem --- Replace ope_ordlsdet ope-21 records
	ope21_dev = fnget_dev("OPE_ORDLSDET")
	dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
	ope21_trip$=firm_id$+status$+ar_type$+cust_id$+order_no$+old_inv_no$
	read (ope21_dev, key=ope21_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
	while 1
		ope21_key$=key(ope21_dev,end=*break)
		if pos(ope21_trip$=ope21_key$)<>1 then break
		extractrecord(ope21_dev)ope21a$; rem Advisory locking
		ope21a.ar_inv_no$=""
		ope21a.mod_user$=sysinfo.user_id$
		ope21a.mod_date$=date(0:"%Yd%Mz%Dz")
		ope21a.mod_time$=date(0:"%Hz%mz")
		ope21a$=field(ope21a$)
		writerecord(ope21_dev)ope21a$
		ope21_primary$=ope21a.firm_id$+ope21a.ar_type$+ope21a.customer_id$+ope21a.order_no$+old_inv_no$+ope21a.orddet_seq_ref$+ope21a.sequence_no$
		remove(ope21_dev,key=ope21_primary$)
		read(ope21_dev,key=ope21_key$,dom=*next)
	wend

	rem --- Replace ope_ordship ope-31 records
	ope31_dev=fnget_dev("OPE_ORDSHIP")
	dim ope31a$:fnget_tpl$("OPE_ORDSHIP")
	ordship_found=0
	for i=1 to 2
		if i=1 then
			address_type$="B"
		else
			address_type$="S"
		endif
		ope31_key$=firm_id$+cust_id$+order_no$+old_inv_no$+address_type$
		extractrecord(ope31_dev,key=ope31_key$,dom=*next)ope31a$; ordship_found=1; rem Advisory locking
		if ordship_found and ope31a.trans_status$="E" then
			ope31a.ar_inv_no$=""
			ope31a.mod_user$=sysinfo.user_id$
			ope31a.mod_date$=date(0:"%Yd%Mz%Dz")
			ope31a.mod_time$=date(0:"%Hz%mz")
			ope31a$=field(ope31a$)
			writerecord(ope31_dev)ope31a$
			remove(ope31_dev,key=ope31_key$)
		endif
	next i

	rem --- Replace opt_invkitdet records
	optInvKitDet_dev = fnget_dev("OPT_INVKITDET")
	dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
	optInvKitDet_trip$=firm_id$+status$+ar_type$+cust_id$+order_no$+old_inv_no$
	read (optInvKitDet_dev, key=optInvKitDet_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
	while 1
		optInvKitDet_key$=key(optInvKitDet_dev,end=*break)
		if pos(optInvKitDet_trip$=optInvKitDet_key$)<>1 then break
		extractrecord(optInvKitDet_dev)optInvKitDet$; rem Advisory locking
		optInvKitDet.ar_inv_no$=""
		optInvKitDet.mod_user$=sysinfo.user_id$
		optInvKitDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optInvKitDet.mod_time$=date(0:"%Hz%mz")
		optInvKitDet$=field(optInvKitDet$)
		writerecord(optInvKitDet_dev)optInvKitDet$
		optInvKitDet_primary$=optInvKitDet.firm_id$+optInvKitDet.ar_type$+optInvKitDet.customer_id$+optInvKitDet.order_no$+old_inv_no$+optInvKitDet.orddet_seq_ref$+optInvKitDet.internal_seq_no$
		remove(optInvKitDet_dev,key=optInvKitDet_primary$)
		read(optInvKitDet_dev,key=optInvKitDet_key$,dom=*next)
	wend

rem --- Restore fulfillment records if using fulfillment
	optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
	didFulfillment=0
	extractrecord(optFillmntHdr_dev,key=firm_id$+"U"+ar_type$+cust_id$+order_no$+old_inv_no$,knum="AO_STATUS",dom=*next); didFulfillment=1
	if didFulfillment then
		rem --- Update TRANS_STATUS and AR_INV_NO in all 6 fulfillment tables
		optFillmntHdr_Primary_key$=firm_id$+ar_type$+cust_id$+order_no$+old_inv_no$
		trans_status$="E"
		ar_inv_no$=""
		gosub updateFulfillment
	endif

rem --- All Done

	user_tpl.do_end_of_form = 0
	callpoint!.setStatus("NEWREC")

rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[OPE_INVHDR.APFE]]
print "Hdr:APFE"; rem debug

rem --- Enable / Disable buttons

	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("AGNG",0)

	if cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),2) = "" then
		if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"),2) = ""
			callpoint!.setOptionEnabled("DINV",0)
			callpoint!.setOptionEnabled("CINV",0)
		else
			callpoint!.setOptionEnabled("DINV",1)
			callpoint!.setOptionEnabled("CINV",1)
		endif
		callpoint!.setOptionEnabled("PRNT",0)
		callpoint!.setOptionEnabled("UINV",0)
		callpoint!.setOptionEnabled("SHPT",0)
		callpoint!.setOptionEnabled("RTAX",0)
	else
		if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"),2) = "" then
			callpoint!.setOptionEnabled("PRNT",0)
			callpoint!.setOptionEnabled("SHPT",0)
			callpoint!.setOptionEnabled("CASH",0)
		else
			callpoint!.setOptionEnabled("PRNT",1)
			callpoint!.setOptionEnabled("SHPT",1)
			callpoint!.setOptionEnabled("TTLS",1)
			callpoint!.setOptionEnabled("RTAX",1)
			if user_tpl.credit_installed$="Y"
				callpoint!.setOptionEnabled("CRCH",1)
			endif
			callpoint!.setOptionEnabled("AGNG",iff(callpoint!.getDevObject("on_demand_aging")="Y",1,0))
			gosub able_cash_sale

			if callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG")<> "I" then
				callpoint!.setOptionEnabled("UINV",0)
			else
				callpoint!.setOptionEnabled("UINV",1)
			endif
		endif
	endif
	if !callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("CASH",0)
		callpoint!.setOptionEnabled("CINV",0)
		callpoint!.setOptionEnabled("DINV",0)
		callpoint!.setOptionEnabled("PRNT",0)
		callpoint!.setOptionEnabled("UINV",0)
		callpoint!.setOptionEnabled("RTAX",0)
	endif


rem --- Set Backordered text field

	call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!

rem --- Update sales tax calculation if it was previously deferred
	if num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))=1 then
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

rem --- Set MODIFIED if totals were changed in the grid

	if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"),3)<>"" 
:	and cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),3)<>""
:	and str(callpoint!.getDevObject("discount_amt"))<>"null"
:	and str(callpoint!.getDevObject("freight_amt"))<>"null"
:	and str(callpoint!.getDevObject("tax_amount"))<>"null"
:	and str(callpoint!.getDevObject("taxable_amt"))<>"null"
:	and str(callpoint!.getDevObject("total_cost"))<>"null"
:	and str(callpoint!.getDevObject("total_sales"))<>"null" then

		if num(callpoint!.getDevObject("discount_amt"))<>num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
:		or num(callpoint!.getDevObject("freight_amt"))<>num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
:		or num(callpoint!.getDevObject("tax_amount"))<>num(callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"))
:		or num(callpoint!.getDevObject("taxable_amt"))<>num(callpoint!.getColumnData("OPE_INVHDR.TAXABLE_AMT"))
:		or num(callpoint!.getDevObject("total_cost"))<>num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_COST"))
:		or num(callpoint!.getDevObject("total_sales"))<>num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES")) then
			callpoint!.setStatus("MODIFIED")
		endif
	endif	

[[OPE_INVHDR.ARAR]]
rem --- If First/Last Record was used, did it return an Invoice?

	if callpoint!.getDevObject("FirstLastRecord")<>null() and callpoint!.getDevObject("FirstLastRecord")<>"" then
		whichRecord$=callpoint!.getDevObject("FirstLastRecord")
		callpoint!.setDevObject("FirstLastRecord","")

		if callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG")<>"I" or callpoint!.getColumnData("OPE_INVHDR.INVOICE_TYPE")<>"S" then
			ope01_dev = fnget_dev("OPE_INVHDR")
			dim ope01a$:fnget_tpl$("OPE_INVHDR")
			status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
			ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
			next_key$=""

			if whichRecord$="FIRST" then
				rem --- Locate FIRST valid invoice to display
				while 1
					read record (ope01_dev, dir=0, end=*break) ope01a$
					if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$<>firm_id$+status$+ar_type$ then break
					if ope01a.invoice_type$ = "S" and ope01a.ordinv_flag$ = "I" then
						rem --- Have a keeper, stop looking
						next_key$=key(ope01_dev)
						break
					else
						rem --- Keep looking
						read (ope01_dev, end=*endif)
						continue
					endif
				wend
			endif

			if whichRecord$="LAST" then
				rem --- Locate LAST valid invoice to display
				while 1
					p_key$ = keyp(ope01_dev, end=*break)
					read record (ope01_dev, key=p_key$) ope01a$
					if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$<>firm_id$+status$+ar_type$ then break
					if ope01a.invoice_type$ = "S" and ope01a.ordinv_flag$ = "I" then
						rem --- Have a keeper, stop looking
						next_key$=p_key$
						break
					else
						rem --- Keep looking
						read (ope01_dev, key=p_key$, dir=0)
						continue
					endif
				wend
			endif

			rem --- Display next invoice
			if next_key$<>"" then
				callpoint!.setStatus("RECORD:["+next_key$+"]")
				break
			else
				msg_id$ = "OP_NO_OPEN_INVOICES"
				gosub disp_message
				callpoint!.setStatus("ABORT-NEWREC")
				break
			endif
		endif
	endif

rem --- Check for void

	if callpoint!.getColumnData("INVOICE_TYPE") = "V" then
		msg_id$="OP_ORDINV_VOID"
		gosub disp_message
		callpoint!.setStatus("NEWREC")
		break; rem --- exit from callpoint			
	endif

rem --- Check for quote
		
	if callpoint!.getColumnData("INVOICE_TYPE") = "P" then
		msg_id$ = "OP_IS_QUOTE"
		gosub disp_message
		callpoint!.setStatus("NEWREC")
		sysGUI!.flushEvents(err=*next)
		break; rem --- exit from callpoint			
	endif		

rem --- Set data

	idx=form!.getControl(num(stbl("+TAB_CTL"))).getSelectedIndex()
	if idx<>2
		callpoint!.setDevObject("was_on_tot_tab","N")
	else
		callpoint!.setDevObject("was_on_tot_tab","Y")
	endif
	callpoint!.setDevObject("details_changed","N")

	callpoint!.setDevObject("new_rec","N")

rem --- Set flags

	callpoint!.setDevObject("credit_status_done", "N")
	callpoint!.setDevObject("credit_action_done", "N")

	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("TTLS",0)
	callpoint!.setOptionEnabled("SHPT",0)
	callpoint!.setOptionEnabled("AGNG",0)
	callpoint!.setOptionEnabled("RTAX",0)

rem --- Clear order helper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.newOrder()
	ordHelp!.setCust_id(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"))

rem --- Reset all previous values

	user_tpl.prev_line_code$   = ""
	user_tpl.prev_item$        = ""
	user_tpl.prev_qty_ord      = 0
	user_tpl.prev_boqty        = 0
	user_tpl.prev_shipqty      = 0
	user_tpl.prev_ext_price    = 0
	user_tpl.prev_ext_cost     = 0
	user_tpl.prev_disc_code$   = ""
	user_tpl.prev_ship_to$     = ""
	user_tpl.prev_sales_total  = 0

	user_tpl.new_order = 0
	user_tpl.credit_limit_warned = 0
	user_tpl.shipto_warned = 0
	callpoint!.setDevObject("disc_code",callpoint!.getColumnData("OPE_INVHDR.DISC_CODE"))

	disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub disp_totals


rem --- setup messages

	if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"),2) = "" or
:	   cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),2) = ""
		break
	endif
	gosub init_msgs
	callpoint!.setDevObject("msg_printed",callpoint!.getColumnData("PRINT_STATUS"))
	if callpoint!.getColumnData("OPE_INVHDR.BACKORD_FLAG") = "B"
		callpoint!.setDevObject("msg_backorder","Y")
	endif
	if callpoint!.getColumnData("OPE_INVHDR.INVOICE_TYPE")="P"
		callpoint!.setDevObject("msg_quote","Y")
	endif
	if num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES")) < 0
		callpoint!.setDevObject("msg_credit_memo","Y")
	endif
	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	over_credit_limit = ordHelp!.calcOverCreditLimit()
	if over_credit_limit = 1
		callpoint!.setDevObject("msg_exceeded","Y")
	else
		callpoint!.setDevObject("msg_credit_okay","Y")
	endif
	if callpoint!.getColumnData("OPE_INVHDR.CREDIT_FLAG")="C"
		callpoint!.setDevObject("msg_hold","Y")
	endif
	if callpoint!.getColumnData("OPE_INVHDR.CREDIT_FLAG")="R"
		callpoint!.setDevObject("msg_released","Y")
	endif

	call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!

rem --- Show OP Invoice Print Report Controls
	admRptCtlRcp=fnget_dev("ADM_RPTCTL_RCP")
	dim admRptCtlRcp$:fnget_tpl$("ADM_RPTCTL_RCP")
	admRptCtlRcp.dd_table_alias$="OPR_INVOICE"
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	readrecord(admRptCtlRcp,key=firm_id$+customer_id$+admRptCtlRcp.dd_table_alias$,knum="AO_CUST_ALIAS",dom=*next)admRptCtlRcp$
	if admRptCtlRcp.email_yn$<>"Y" and admRptCtlRcp.fax_yn$<>"Y" then
		callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_NONE"))
	else
		if admRptCtlRcp.email_yn$="Y" and admRptCtlRcp.fax_yn$="Y" then
			callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_EMAIL")+" + "+Translate!.getTranslation("AON_FAX"))
		else
			if admRptCtlRcp.email_yn$="Y" then
				callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_EMAIL")+" "+Translate!.getTranslation("AON_ONLY"))
			else
				callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_FAX")+" "+Translate!.getTranslation("AON_ONLY"))
			endif
		endif
	endif

[[OPE_INVHDR.AREC]]
rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPE_INVHDR.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPE_INVHDR.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPE_INVHDR.CREATED_TIME",date(0:"%Hz%mz"))
	callpoint!.setColumnData("OPE_INVHDR.AUDIT_NUMBER","0")

rem --- clear availability

	gosub clear_avail
	callpoint!.setDevObject("was_on_tot_tab","N")
	callpoint!.setDevObject("details_changed","N")
	callpoint!.setDevObject("new_rec","Y")
	callpoint!.setDevObject("initial_rec_data$",rec_data$)
	callpoint!.setDevObject("use_tax_service","N")

	gosub init_msgs

rem --- Set flag

	user_tpl.record_deleted = 0

rem --- Disable Ship To fields

	ship_to_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	gosub disable_shipto

rem --- Make sure sales tax gets calculated, and hide possible leftover TAX_AMOUNT footnote warning
	callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1))
	callpoint!.setDevObject("commit_sls_tax","N")
	taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
	taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
	taxAmount_fnote!.setVisible(0)
	taxAmount_warn!.setVisible(0)

rem --- Reset default warehouse for new order
	user_tpl.warehouse_id$ = callpoint!.getDevObject("defaultWhse")

rem --- Enable Freight Amount
	callpoint!.setColumnEnabled("OPE_INVHDR.FREIGHT_AMT",1)

[[OPE_INVHDR.AR_DIST_CODE.AVAL]]
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

[[OPE_INVHDR.AR_DIST_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.AR_SHIP_VIA.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.ASHO]]
print "Hdr:ASHO"; rem debug

rem --- Get default POS station

	call stbl("+DIR_SYP")+"bam_run_prog.bbj", "OPE_INVSTATION", stbl("+USER_ID"), "MNT", "", table_chans$[all]

    rem --- Check for a POS record by station

	station$ = "DEFAULT"
	station$ = stbl("OPE_DEF_STATION", err=*next)

	file$ = "OPM_POINTOFSALE"
	pointofsale_dev=fnget_dev(file$)
	dim pointofsale_rec$:fnget_tpl$(file$)

	find record (pointofsale_dev, key=firm_id$+pad(station$, 16), dom=no_pointofsale) pointofsale_rec$
	goto end_pointofsale

no_pointofsale: rem --- Should we create a default record?

	msg_id$ = "POS_REC_NOT_FOUND"
	dim msg_tokens$[1]
	msg_tokens$[1] = cvs(station$, 2)

	gosub disp_message

	if msg_opt$ = "N" then
		callpoint!.setStatus("EXIT")
		break; rem --- Exit callpoint
	endif

rem --- Create a default POS record

	dim sysinfo$:stbl("+SYSINFO_TPL")
	sysinfo$=stbl("+SYSINFO")

	pointofsale_rec.firm_id$         = firm_id$
	pointofsale_rec.pos_station$ = pad(station$, 16)
	pointofsale_key$=pointofsale_rec.firm_id$+pointofsale_rec.pos_station$
	extractrecord(pointofsale_dev,key=pointofsale_key$,dom=*next)x$; rem Advisory Locking
	pointofsale_rec.skip_whse$       = "N"
	pointofsale_rec.val_ctr_prt$     = sysinfo.printer_id$
	pointofsale_rec.val_rec_prt$     = sysinfo.printer_id$
	pointofsale_rec.cntr_printer$    = sysinfo.printer_id$
	pointofsale_rec.rec_printer$     = sysinfo.printer_id$

	write record (pointofsale_dev) pointofsale_rec$
		
end_pointofsale:

	user_tpl.skip_whse$    = pointofsale_rec.skip_whse$
	user_tpl.warehouse_id$ = pointofsale_rec.warehouse_id$	
	callpoint!.setDevObject("defaultWhse",pointofsale_rec.warehouse_id$)

rem --- When using Sales Tax Service, get connection
	callpoint!.setDevObject("salesTaxObject",null())
	if callpoint!.getDevObject("sls_tax_intrface")<>"" then
		rem --- Get connection to Sales Tax Service
		salesTax!=new AvaTaxInterface(firm_id$)
		if salesTax!.connectClient(Form!,err=connectErr) then
			callpoint!.setDevObject("salesTaxObject",salesTax!)

			rem --- Warn if in test mode
			if salesTax!.isTestMode() then
				rem --- Skip warning if they were previously warned
				global_ns!=BBjAPI().getGlobalNamespace()
				nsValue!=global_ns!.getValue(info(3,2)+date(0)+"_SalesTaxSvcTestWarning",err=*next)
				if nsValue!=null() then
					msg_id$="OP_SLS_TAX_SVC_TEST"
					gosub disp_message

					global_ns!.setValue(info(3,2)+date(0)+"_SalesTaxSvcTestWarning","Test mode warning")
				endif
			endif
		else
			if salesTax!<>null() then salesTax!.close()
			salesTax!=null()
		endif
	endif

	break

connectErr:
	if salesTax!<>null() then salesTax!.close()
	salesTax!=null()

	break

[[OPE_INVHDR.ASIZ]]
print "Hdr:ASIZ"; rem debug

rem --- Create Empty Availability window

	grid! = util.getGrid(Form!)
	grid!.setSize(grid!.getWidth(), grid!.getHeight() - 75)

	cwin! = util.getChild(Form!).getControl(15000)
	cwin!.setLocation(cwin!.getX(), grid!.getY() + grid!.getHeight())
	cwin!.setSize(grid!.getWidth(), cwin!.getHeight())

	mwin! = cwin!.getControl(15999)
	mwin!.setSize(grid!.getWidth(), mwin!.getHeight())

rem --- Resize customer comments box (display only) to align w/ Order/Invoice Comments (memo_1024)

	cmts!=callpoint!.getControl("<<DISPLAY>>.COMMENTS")
	memo!=callpoint!.getControl("OPE_INVHDR.MEMO_1024")
	cmts!.setSize(memo!.getWidth(),cmts!.getHeight())

[[OPE_INVHDR.ASVA]]
rem --- Check Ship-to's

	shipto_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	shipto_no$  = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

[[OPE_INVHDR.AWRI]]
rem --- Disable buttons/options
	if !callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("CASH",0)
		callpoint!.setOptionEnabled("CINV",0)
		callpoint!.setOptionEnabled("DINV",0)
		callpoint!.setOptionEnabled("RTAX",0)
	endif

rem --- Update devObjects with current values written to file
	callpoint!.setDevObject("discount_amt",num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT")))
	callpoint!.setDevObject("freight_amt",num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT")))
	callpoint!.setDevObject("tax_amount",num(callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT")))
	callpoint!.setDevObject("taxable_amt",num(callpoint!.getColumnData("OPE_INVHDR.TAXABLE_AMT")))
	callpoint!.setDevObject("total_cost",num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_COST")))
	callpoint!.setDevObject("total_sales",num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES")))

[[OPE_INVHDR.BDEL]]
rem --- Display more meaningful deletion message

	msg_id$="OP_CONFIRM_DEL_INV"
	gosub disp_message
	if msg_opt$="N"
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- User approval required if packages have already been shipped

	rem --- Assumes num(ship_seq_no$)=0 until order is invoiced and sales register is updated.
	trackingNos!=new java.util.HashMap()
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	ship_seq_no$=callpoint!.getColumnData("OPE_INVHDR.SHIP_SEQ_NO")
	optShipTrack_dev = fnget_dev("OPT_SHIPTRACK")
	dim optShipTrack$:fnget_tpl$("OPT_SHIPTRACK")
	read(optShipTrack_dev,key=firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$,dom=*next)
	while 1
		optShipTrack_key$=key(optShipTrack_dev,end=*break)
		if pos(firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$=optShipTrack_key$)<>1 then break
		readrecord(optShipTrack_dev)optShipTrack$
		if optShipTrack.void_flag$="Y" then
			trackingNos!.remove(optShipTrack.tracking_no$)
		else
			trackingNos!.put(optShipTrack.tracking_no$,optShipTrack.tracking_no$)
		endif
	wend

	rem --- If packages shipped, need user approval to delete order.
	if trackingNos!.size()>0 then
		msg_id$="OP_PACKAGE_SHIPPED"
		gosub disp_message
		if msg_opt$="N" then
			callpoint!.setStatus("ABORT")
			break
		endif
		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Prevent deleting Sales Order or detail lines currently "linked" to Purchase Orders
	if callpoint!.getDevObject("po_installed")="Y" then
		poeLinked_dev = fnget_dev("POE_LINKED")
		dim poeLinked$:fnget_tpl$("POE_LINKED")
		read(poeLinked_dev,key=firm_id$+customer_id$+order_no$,knum="AO_CUST_ORD",dom=*next)
		poeLinked_key$=key(poeLinked_dev,end=*next)
		if pos(firm_id$+customer_id$+order_no$=poeLinked_key$)=1 then
			readrecord(poeLinked_dev)poeLinked$
			msg_id$ = "OP_ORDER_PO_LINKED"
			dim msg_tokens$[1]
			msg_tokens$[1] = Translate!.getTranslation("AON_PURCHASE_ORDER")+" "+poeLinked.po_no$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Check for Requisitions "linked" to this Sales Order
		linked=0
		poeReqhdr_dev = fnget_dev("POE_REQHDR")
		dim poeReqhdr$:fnget_tpl$("POE_REQHDR")
		read(poeReqhdr_dev,key=firm_id$,dom=*next)
		while 1
			poeReqhdr_key$=key(poeReqhdr_dev,end=*break)
			if pos(firm_id$=poeReqhdr_key$)<>1 then break
			readrecord(poeReqhdr_dev)poeReqhdr$
			if poeReqhdr.order_no$=order_no$ then
				linked=1
				break
			endif
		wend

		if linked then
			msg_id$ = "OP_ORDER_PO_LINKED"
			dim msg_tokens$[1]
			msg_tokens$[1] = Translate!.getTranslation("AON_PURCHASE_REQUISITION")+" "+poeReqhdr.req_no$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Void AvaTax transaction if using a sales tax service
	if callpoint!.getDevObject("use_tax_service")="Y" then
		ar_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
		salesTax!=callpoint!.getDevObject("salesTaxObject")
		if cvs(callpoint!.getColumnData("OPE_INVHDR.CREDIT_INVOICE"),2)="" then
			transType$="SalesInvoice"
		else
			transType$="ReturnInvoice"
		endif
		success=0
		success=salesTax!.voidTransaction(customer_id$, order_no$, ar_inv_no$, transType$, err=*next)
		if !success then
			msg_id$ = "OP_CANNOT_VOID_INV"
			gosub disp_message
			break
		endif
	endif

rem --- Remove fulfillment records if using fulfillment
	optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
	ar_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
	didFulfillment=0
	extractrecord(optFillmntHdr_dev,key=firm_id$+"U"+ar_type$+customer_id$+order_no$+ar_inv_no$,knum="AO_STATUS",dom=*next); didFulfillment=1
	if didFulfillment then
		rem --- Remove records from all 6 fulfillment tables
		optFillmntHdr_Primary_key$=firm_id$+ar_type$+customer_id$+order_no$+ar_inv_no$

		rem --- OPT_CARTLSDET
		optCartLsDet_dev = fnget_dev("OPT_CARTLSDET")
		dim optCartLsDet$:fnget_tpl$("OPT_CARTLSDET")
		optCartLsDet_trip$=optFillmntHdr_Primary_key$
		read(optCartLsDet_dev,key=optCartLsDet_trip$,knum="PRIMARY",dom=*next)
		while 1
			optCartLsDet_key$=key(optCartLsDet_dev,end=*break)
			if pos(optCartLsDet_trip$=optCartLsDet_key$)<>1 then break
			remove(optCartLsDet_dev,key=optCartLsDet_key$)
		wend

		rem --- OPT_FILLMNTLSDET
		optFillmntLsDet_dev = fnget_dev("OPT_FILLMNTLSDET")
		dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
		optFillmntLsDet_trip$=optFillmntHdr_Primary_key$
		read(optFillmntLsDet_dev,key=optFillmntLsDet_trip$,knum="PRIMARY",dom=*next)
		while 1
			optFillmntLsDet_key$=key(optFillmntLsDet_dev,end=*break)
			if pos(optFillmntLsDet_trip$=optFillmntLsDet_key$)<>1 then break
			remove(optFillmntLsDet_dev,key=optFillmntLsDet_key$)
		wend

		rem --- OPT_CARTDET
		optCartDet_dev = fnget_dev("OPT_CARTDET")
		dim optCartDet$:fnget_tpl$("OPT_CARTDET")
		optCartDet_trip$=optFillmntHdr_Primary_key$
		read(optCartDet_dev,key=optCartDet_trip$,knum="PRIMARY",dom=*next)
		while 1
			optCartDet_key$=key(optCartDet_dev,end=*break)
			if pos(optCartDet_trip$=optCartDet_key$)<>1 then break
			remove(optCartDet_dev,key=optCartDet_key$)
		wend

		rem --- OPT_FILLMNTDET
		optFillmntDet_dev = fnget_dev("OPT_FILLMNTDET")
		dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
		optFillmntDet_trip$=optFillmntHdr_Primary_key$
		read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="PRIMARY",dom=*next)
		while 1
			optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
			if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
			remove(optFillmntDet_dev,key=optFillmntDet_key$)
		wend

		rem --- OPT_CARTHDR
		optCartHdr_dev = fnget_dev("OPT_CARTHDR")
		dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
		optCartHdr_trip$=optFillmntHdr_Primary_key$
		read(optCartHdr_dev,key=optCartHdr_trip$,knum="PRIMARY",dom=*next)
		while 1
			optCartHdr_key$=key(optCartHdr_dev,end=*break)
			if pos(optCartHdr_trip$=optCartHdr_key$)<>1then break
			remove(optCartHdr_dev,key=optCartHdr_key$)
		wend

		rem --- OPT_FILLMNTHDR
		remove(optFillmntHdr_dev,key=optFillmntHdr_Primary_key$)
	endif

rem --- Set table variables
	file_name$ = "OPE_PRNTLIST"
	prntlist_dev = fnget_dev(file_name$)
	dim prntlist_rec$:fnget_tpl$(file_name$)

rem --- Retain Order is No

	callpoint!.setColumnData("OPE_INVHDR.INVOICE_TYPE","V")
	prntlist_rec.firm_id$     = firm_id$
	prntlist_rec.ordinv_flag$ = "I"
	prntlist_rec.customer_id$ = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	prntlist_rec.order_no$    = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	prntlist_key$=prntlist_rec.firm_id$+prntlist_rec.ordinv_flag$+prntlist_rec.ar_type$+prntlist_rec.customer_id$+prntlist_rec.order_no$
	remove(prntlist_dev,key=prntlist_key$,dom=*next)

	callpoint!.setStatus("SAVE")

rem --- Remove committments for detail records by calling ATAMO

	ope11_dev = fnget_dev("OPE_INVDET")
	dim ope11a$:fnget_tpl$("OPE_INVDET")

	opc_linecode_dev = fnget_dev("OPC_LINECODE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")

	ivs01_dev = fnget_dev("IVS_PARAMS")
	dim ivs01a$:fnget_tpl$("IVS_PARAMS")
	read record (ivs01_dev, key=firm_id$+"IV00") ivs01a$

	ope31_dev = fnget_dev("OPE_ORDSHIP")
	cashrct_dev = fnget_dev("OPE_INVCASH")
	creddate_dev = fnget_dev("OPE_CREDDATE")

	trans_status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	ar_type$  = callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	cust$     = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	ord$      = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	invoice$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
	ord_date$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_DATE")
	inv_type$ = callpoint!.getColumnData("OPE_INVHDR.INVOICE_TYPE")

	read (ope11_dev, key=firm_id$+trans_status$+ar_type$+cust$+ord$+invoice$, dom=*next)

	while 1
		read record (ope11_dev, end=*break) ope11a$

		if firm_id$<>ope11a.firm_id$ then break
		if trans_status$<>ope11a.trans_status$ then break
		if ar_type$<>ope11a.ar_type$ then break
		if cust$<>ope11a.customer_id$ then break
		if ord$<>ope11a.order_no$ then break
		if invoice$<>ope11a.ar_inv_no$ then break

		read record (opc_linecode_dev, key=firm_id$+ope11a.line_code$) opc_linecode$

		if opc_linecode.dropship$<>"Y" and ope11a.commit_flag$="Y" and inv_type$<>"P" then
			if pos(opc_linecode.line_type$="SP") then
				wh_id$    = ope11a.warehouse_id$
				item_id$  = ope11a.item_id$
				ls_id$    = ""
				qty       = ope11a.qty_ordered
				line_sign = -1
				gosub update_totals
			endif
		endif

			ord_seq$ = ope11a.internal_seq_no$
			gosub remove_lot_ser_det

		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		readrecord(ivm01_dev,key=firm_id$+ope11a.item_id$,dom=*next)ivm01a$
		if pos(ivm01a.kit$="YP") then
			rem --- Delete the kit's components
			optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
			dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
			ar_type$=ope11a.ar_type$ 
			cust$=ope11a.customer_id$
			order$=ope11a.order_no$
			invoice_no$=ope11a.ar_inv_no$
			seq$=ope11a.internal_seq_no$
			optInvKitDet_key$=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$
			read(optInvKitDet_dev,key=optInvKitDet_key$,knum="PRIMARY",dom=*next)
			while 1
				thisKey$=key(optInvKitDet_dev,end=*break)
				if pos(optInvKitDet_key$=thisKey$)<>1 then break
				remove(optInvKitDet_dev,key=thisKey$)
	wend
			read(optInvKitDet_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next); rem --- Reset to alternate key
		endif
	wend

	remove (ope31_dev, key=firm_id$+cust$+ord$+invoice$+"B", dom=*next)
	remove (ope31_dev, key=firm_id$+cust$+ord$+invoice$+"S", dom=*next)
	remove (cashrct_dev, key=firm_id$+ar_type$+cust$+ord$+invoice$, err=*next)

	if user_tpl.credit_installed$="Y" then
		remove (creddate_dev, key=firm_id$+ord_date$+cust$+ord$, err=*next)	
	endif

[[OPE_INVHDR.BEND]]
rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTaxObject")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[OPE_INVHDR.BFST]]
rem --- Set flag that First Record has been selected
	callpoint!.setDevObject("FirstLastRecord","FIRST")

[[OPE_INVHDR.BLST]]
rem --- Set flag that Last Record has been selected
	callpoint!.setDevObject("FirstLastRecord","LAST")

[[OPE_INVHDR.BNEK]]
rem --- Next record must be an invoice 

	file_name$ = "OPE_INVHDR"
	ope01_dev = fnget_dev(file_name$)
	dim ope01a$:fnget_tpl$(file_name$)

rem --- Position the file at the correct record

	status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	if callpoint!.getDevObject("new_rec")="Y"
		start_key$=firm_id$+status$+ar_type$
		cust_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
		if cvs(cust_id$,2)<>""
			start_key$=start_key$+cust_id$
			order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
			if cvs(order_no$,2)<>""
				start_key$=start_key$+order_no$+callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
			endif
		endif
		read (ope01_dev,key=start_key$,dom=*next)
	else
		current_key$=callpoint!.getRecordKey()
		read(ope01_dev,key=current_key$,dom=*next)
	endif

	hit_eof=0
	while 1
		read record (ope01_dev, dir=0, end=eof) ope01a$

		if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$ = firm_id$+status$+ar_type$ then
			if ope01a.invoice_type$ = "S" and ope01a.ordinv_flag$ = "I" then
				rem --- Have a keeper, stop looking
				break
			else
				rem --- Keep looking
				read (ope01_dev, end=*endif)
				continue
			endif
		endif
		rem --- End-of-firm

eof: rem --- If end-of-file or end-of-firm, rewind to first record of the firm
		read (ope01_dev, key=firm_id$+status$+ar_type$, dom=*next)
		hit_eof=hit_eof+1
		if hit_eof>1 then
			msg_id$ = "OP_NO_OPEN_INVOICES"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	wend

[[OPE_INVHDR.BNEX]]
rem --- Check for Order Total on non-cash sales

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE")<>"Y"  then
		ord_tot=num(callpoint!.getColumnData("<<DISPLAY>>.ORDER_TOT"))
		if ord_tot>0 and ord_tot<user_tpl.min_ord_amt
			call stbl("+DIR_PGM")+"adc_getmask.aon","","AR","A",imsk$,omsk$,ilen,olen
			msg_id$="OP_TOT_UNDER_MIN"
			dim msg_tokens$[1]
			msg_tokens$[1]=str(user_tpl.min_ord_amt:omsk$)
			gosub disp_message
			if msg_opt$="N"
				callpoint!.setStatus("ABORT")
				break
			endif
		endif
	endif

rem --- Check to see if we need to go to the totals tab

	if pos(callpoint!.getDevObject("totals_warn")="24")>0
		if pos(callpoint!.getDevObject("was_on_tot_tab")="N") > 0
			if callpoint!.getDevObject("details_changed")="Y" and callpoint!.getDevObject("rcpr_row")=""
				callpoint!.setMessage("OP_TOTALS_TAB")
				callpoint!.setFocus("OPE_INVHDR.FREIGHT_AMT")
				callpoint!.setDevObject("was_on_tot_tab","Y")
				callpoint!.setStatus("ABORT-ACTIVATE")
				break
			endif
		endif
	endif

[[OPE_INVHDR.BOVE]]
rem --- Restrict lookup to open orders and open invoices

	rem bug 7564 --- cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	custControl!=callpoint!.getControl("OPE_INVHDR.CUSTOMER_ID")
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
	filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")+"'"
	filter_defs$[2,2]="LOCK"
	if cvs(cust_id$, 2) <> "" then
		filter_defs$[3,0] = "OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1] = "='" + cust_id$ + "'"
		filter_defs$[3,2]="LOCK"
	endif
	filter_defs$[4,0]="OPT_INVHDR.INVOICE_TYPE"
	filter_defs$[4,1]="<>'V'"
	filter_defs$[4,2]="LOCK"

	dim search_defs$[3]

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"OP_ENTRY_1",
:		"",
:		table_chans$[all],
:		selected_keys$,
:		filter_defs$[all],
:		search_defs$[all],
:		"",
:		"AO_STATUS"

	if selected_keys$<>"" then 
		call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVHDR","AO_STATUS",key_tpl$,table_chans$[all],status$
		dim ao_status_key$:key_tpl$
		if cust_id$<>"" and cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),3)<>"" then
			callpoint!.setStatus("SAVE-RECORD:[" + selected_keys$(1,len(ao_status_key$)) +"]")
		else
			callpoint!.setStatus("RECORD:[" + selected_keys$(1,len(ao_status_key$)) +"]")
		endif
	else
		callpoint!.setStatus("ABORT")
	endif
	callpoint!.setStatus("ACTIVATE")

[[OPE_INVHDR.BPFX]]
print "Hdr:BPFX"; rem debug

rem --- Disable buttons

	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("CRAT",0)
	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)
	callpoint!.setOptionEnabled("UINV",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("CASH",0)
	callpoint!.setOptionEnabled("TTLS",0)
	callpoint!.setOptionEnabled("SHPT",0)
	callpoint!.setOptionEnabled("AGNG",0)
	callpoint!.setOptionEnabled("RTAX",0)

rem --- Capture current totals so we can tell later if they were changed in the grid

	if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"),3)<>"" and cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),3)<>""
		callpoint!.setDevObject("discount_amt",callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		callpoint!.setDevObject("freight_amt",callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		callpoint!.setDevObject("tax_amount",callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"))
		callpoint!.setDevObject("taxable_amt",callpoint!.getColumnData("OPE_INVHDR.TAXABLE_AMT"))
		callpoint!.setDevObject("total_cost",callpoint!.getColumnData("OPE_INVHDR.TOTAL_COST"))
		callpoint!.setDevObject("total_sales",callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES"))
	endif

[[OPE_INVHDR.BPRI]]
rem --- Check for Order Total on non-cash sales

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE")<>"Y"  then
		ord_tot=num(callpoint!.getColumnData("<<DISPLAY>>.ORDER_TOT"))
		if ord_tot>0 and ord_tot<user_tpl.min_ord_amt
			call stbl("+DIR_PGM")+"adc_getmask.aon","","AR","A",imsk$,omsk$,ilen,olen
			msg_id$="OP_TOT_UNDER_MIN"
			dim msg_tokens$[1]
			msg_tokens$[1]=str(user_tpl.min_ord_amt:omsk$)
			gosub disp_message
			if msg_opt$="N"
				callpoint!.setStatus("ABORT")
				break
			endif
		endif
	endif

rem --- Check to see if we need to go to the totals tab

	if pos(callpoint!.getDevObject("totals_warn")="24")>0
		if pos(callpoint!.getDevObject("was_on_tot_tab")="N") > 0
			if callpoint!.getDevObject("details_changed")="Y" and callpoint!.getDevObject("rcpr_row")=""
				callpoint!.setMessage("OP_TOTALS_TAB")
				callpoint!.setFocus("OPE_INVHDR.FREIGHT_AMT")
				callpoint!.setDevObject("was_on_tot_tab","Y")
				callpoint!.setStatus("ABORT-ACTIVATE")
				break
			endif
		endif
	endif

[[OPE_INVHDR.BPRK]]
rem --- Previous record must be an invoice

	file_name$ = "OPE_INVHDR"
	ope01_dev = fnget_dev(file_name$)
	dim ope01a$:fnget_tpl$(file_name$)

rem --- Position the file at the correct record

	status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	if callpoint!.getDevObject("new_rec")="Y"
		start_key$=firm_id$+status$+ar_type$
		cust_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
		if cvs(cust_id$,2)<>""
			start_key$=start_key$+cust_id$
			order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
			if cvs(order_no$,2)<>""
				start_key$=start_key$+order_no$
			endif
		endif
		read(ope01_dev,key=start_key$,dir=0,dom=*next)
	else
		current_key$=callpoint!.getRecordKey()
		read(ope01_dev,key=current_key$,dir=0,dom=*next)
	endif

	hit_eof=0
	while 1
		p_key$ = keyp(ope01_dev, end=eof_pkey)
		read record (ope01_dev, key=p_key$) ope01a$

		if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$=firm_id$+status$+ar_type$ then 
			if ope01a.invoice_type$ = "S" and ope01a.ordinv_flag$ = "I" then
				rem --- Have a keeper, stop looking
				break
			else
				rem --- Keep looking
				read (ope01_dev, key=p_key$, dir=0)
				continue
			endif
		endif
		rem --- End-of-firm

eof_pkey: rem --- If end-of-file or end-of-firm, rewind to last record in this firm
		read (ope01_dev, key=firm_id$+status$+ar_type$+$ff$, dom=*next)
		hit_eof=hit_eof+1
		if hit_eof>1 then
			msg_id$ = "OP_NO_OPEN_INVOICES"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	wend

[[OPE_INVHDR.BREX]]
rem --- Are both Customer and Order entered?

	if cvs(callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"), 2) = "" or 
:		cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"), 2) = ""
:	then
		callpoint!.setStatus("EXIT")
		break; rem --- exit callpoint
	endif

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))

	if ordHelp!.getCust_id() = "" or ordHelp!.getOrder_no() = "" then
		callpoint!.setStatus("EXIT")
		break; rem --- exit callpoint
	endif

rem --- Is record deleted?

	if user_tpl.record_deleted then
		break; rem --- exit callpoint
	endif

rem --- Make sure cash entered for cash sale

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE") = "Y"  then
		rem --- skip if total cash sale is zero
		if num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES"))<>0 then
			rem --- ope_invcash balance due must be zero before exiting
			gosub check_cash_due
			while cash_due
				gosub get_cash
				gosub check_cash_due

				rem --- allow deleting a cash invoice when cash hasn't been received
				if cash_due and cashrct.tendered_amt=0 then
					msg_id$ = "CASH_OR_DELETE"
					gosub disp_message
					if msg_opt$="D" then
						callpoint!.clearStatus()
						callpoint!.setStatus("DELETE")
						break
					endif
				endif
			wend
		endif
	endif

rem --- Is flag down?

	if !user_tpl.do_end_of_form then
		user_tpl.do_end_of_form = 1
		break; rem --- exit callpoint
	endif	

rem --- Does the total of lot/serial# match the qty shipped for each detail line?

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))

		declare BBjVector recs!
		recs! = BBjAPI().makeVector()

		recs! = cast( BBjVector, gridVect!.getItem(0) )
		dim gridrec$:dtlg_param$[1,3]

rem --- Detail loop

		if recs!.size() then 
			for row=0 to recs!.size()-1
				gridrec$ = recs!.getItem(row)

			if ordHelp!.isLottedSerial(gridrec.item_id$) and callpoint!.getGridRowDeleteStatus(row)<>"Y" then
					lot_ser_total = ordHelp!.totalLotSerialAmount( gridrec.internal_seq_no$ )

					if lot_ser_total <> gridrec.qty_shipped then
						msg_id$ = "OP_ITEM_LS_TOTAL"
						dim msg_tokens$[3]
						msg_tokens$[0] = str(gridrec.qty_shipped)
						msg_tokens$[1] = cvs(gridrec.item_id$, 2)
					msg_tokens$[2] = Translate!.getTranslation("AON__LOT/SERIAL_NUMBER(S)")
						msg_tokens$[3] = str(lot_ser_total)
						gosub disp_message
					endif
				endif
			next row
		endif

[[OPE_INVHDR.BSHO]]
print "Hdr:BSHO"; rem debug

rem --- Documentation
rem     Old s$(7,1) = 0 -> user_tpl.hist_ord$ = "Y" - order came from history
rem                 = 1 -> user_tpl.hist_ord$ = "N"

rem --- Open needed files

	num_files=52
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]

	open_tables$[1]="ARM_CUSTMAST",  open_opts$[1]="OTA"
	open_tables$[2]="ARM_CUSTSHIP",  open_opts$[2]="OTA"
	open_tables$[3]="OPE_ORDSHIP",   open_opts$[3]="OTA"
	open_tables$[4]="ARS_PARAMS",    open_opts$[4]="OTA"
	open_tables$[5]="ARM_CUSTDET",   open_opts$[5]="OTA"
	open_tables$[6]="OPE_INVCASH",   open_opts$[6]="OTA"
	open_tables$[7]="ARS_CREDIT",    open_opts$[7]="OTA"
	open_tables$[8]="OPC_LINECODE",  open_opts$[8]="OTA"
	open_tables$[11]="IVM_LSMASTER", open_opts$[11]="OTA"
	open_tables$[12]="IVX_LSCUST",   open_opts$[12]="OTA"
	open_tables$[13]="IVM_ITEMMAST", open_opts$[13]="OTA"
	open_tables$[15]="IVX_LSVEND",   open_opts$[15]="OTA"
	open_tables$[16]="IVM_ITEMWHSE", open_opts$[16]="OTA"
	open_tables$[17]="IVM_ITEMACT",  open_opts$[17]="OTA"
	open_tables$[18]="IVT_ITEMTRAN", open_opts$[18]="OTA"
	open_tables$[19]="IVM_ITEMTIER", open_opts$[19]="OTA"
	open_tables$[20]="IVM_ITEMACT",  open_opts$[20]="OTA"
	open_tables$[21]="IVM_ITEMVEND", open_opts$[21]="OTA"
	open_tables$[22]="IVT_LSTRANS",  open_opts$[22]="OTA"
	open_tables$[23]="OPT_INVHDR",   open_opts$[23]="OTA"
	open_tables$[24]="OPT_INVDET",   open_opts$[24]="OTA"
	open_tables$[25]="OPE_INVDET",   open_opts$[25]="OTA"
	open_tables$[26]="OPT_INVSHIP",  open_opts$[26]="OTA"
	open_tables$[27]="OPE_CREDDATE", open_opts$[27]="OTA"
	open_tables$[28]="IVC_WHSECODE", open_opts$[28]="OTA"
	open_tables$[29]="IVS_PARAMS",   open_opts$[29]="OTA"
	open_tables$[30]="OPE_ORDLSDET", open_opts$[30]="OTA"
	open_tables$[31]="IVM_ITEMPRIC", open_opts$[31]="OTA"
	open_tables$[32]="IVC_PRICCODE", open_opts$[32]="OTA"
	open_tables$[33]="OPT_FILLMNTHDR", open_opts$[33]="OTA"
	open_tables$[34]="OPE_PRNTLIST", open_opts$[34]="OTA"
	open_tables$[35]="OPM_POINTOFSALE", open_opts$[35]="OTA"
	open_tables$[36]="ARC_SALECODE", open_opts$[36]="OTA"
	open_tables$[37]="OPC_DISCCODE", open_opts$[37]="OTA"
	open_tables$[38]="OPC_TAXCODE",  open_opts$[38]="OTA"
	open_tables$[39]="OPE_INVHDR",   open_opts$[39]="OTA"
	open_tables$[40]="ARC_TERMCODE", open_opts$[40]="OTA"
	open_tables$[41]="IVM_ITEMSYN",open_opts$[41]="OTA"
	open_tables$[42]="OPT_SHIPTRACK",open_opts$[42]="OTA"
	open_tables$[43]="ARM_CUSTPMTS",   open_opts$[43]="OTA"
	open_tables$[44]="ADM_RPTCTL_RCP",open_opts$[44]="OTA"
	open_tables$[45]="OPT_FILLMNTDET", open_opts$[45]="OTA"
	open_tables$[46]="OPT_FILLMNTLSDET", open_opts$[46]="OTA"
	open_tables$[47]="OPT_CARTHDR", open_opts$[47]="OTA"
	open_tables$[48]="OPT_CARTDET", open_opts$[48]="OTA"
	open_tables$[49]="OPT_CARTLSDET", open_opts$[49]="OTA"
	open_tables$[50]="OPT_INVKITDET", open_opts$[50]="OTA"
	open_tables$[51]="ARC_DISTCODE", open_opts$[51]="OTA"
	open_tables$[52]="ARC_TERRCODE", open_opts$[52]="OTA"

	gosub open_tables

	callpoint!.setDevObject("opt_invlookup",open_chans$[23])
	callpoint!.setDevObject("opt_invlookup_tpl",open_tpls$[23])

rem --- Verify that there are line codes - abort if not.

	opc_linecode_dev=fnget_dev("OPC_LINECODE")
	readrecord(opc_linecode_dev,key=firm_id$,dom=*next)
	found_one$="N"
	while 1
		opc_linecode_key$=key(opc_linecode_dev,end=*break)
		if pos(firm_id$=opc_linecode_key$)=1 found_one$="Y"
		break
	wend
	if found_one$="N"
		msg_id$="MISSING_LINECODE"
		gosub disp_message
		release
	endif

rem --- Set table_chans$[all] into util object for getDev() and getTmpl()

	declare ArrayObject tableChans!

	call stbl("+DIR_PGM")+"adc_array.aon::str_array2object", table_chans$[all], tableChans!, status
	if status = 999 then goto std_exit
	util.setTableChans(tableChans!)

rem --- get AR Params

	dim ars01a$:open_tpls$[4]
	read record (num(open_chans$[4]), key=firm_id$+"AR00") ars01a$
	if ars01a.op_totals_warn$="" ars01a.op_totals_warn$="4"
	callpoint!.setDevObject("totals_warn",ars01a.op_totals_warn$)
	callpoint!.setDevObject("check_po_dupes",ars01a.op_check_dupe_po$)
	callpoint!.setDevObject("sls_tax_intrface", cvs(ars01a.sls_tax_intrface$,2))
	callpoint!.setDevObject("warn_not_avail",ars01a.warn_not_avail$)
	if ars01a.on_demand_aging$="Y"
		callpoint!.setDevObject("on_demand_aging",ars01a.on_demand_aging$)
		callpoint!.setDevObject("dflt_age_by",ars01a.dflt_age_by$)
	endif

	dim ars_credit$:open_tpls$[7]
	read record (num(open_chans$[7]), key=firm_id$+"AR01") ars_credit$

	rem --- Hide Unit Cost in detail grid?
	grid!  = util.getGrid(Form!)
	if ars01a.hide_cost$="Y" then
		grid!.setColumnWidth(8,0)
	else
		if grid!.getColumnWidth(8)<70 then grid!.setColumnWidth(8,70)
	endif

rem --- get IV Params

	dim ivs01a$:open_tpls$[29]
	read record (num(open_chans$[29]), key=firm_id$+"IV00") ivs01a$

	callpoint!.setDevObject("precision",ivs01a.precision$)
	callpoint!.setDevObject("sell_purch_um",ivs01a.sell_purch_um$)

rem --- See if blank warehouse exists

	blank_whse$ = "N"
	dim ivm10c$:open_tpls$[28]
	start_block = 1
	
	if start_block then
		read record (num(open_chans$[28]), key=firm_id$+"C"+ivm10c.warehouse_id$, dom=*endif) ivm10c$
		blank_whse$ = "Y"
	endif

rem --- If BM is installed, open BMM_BILLMAT
	bm$="N"
	dim info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","BM",info$[all]
	bm$=info$[20]
	if bm$="Y" then
		num_files = 1
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="BMM_BILLMAT", open_opts$[1]="OTA"
		gosub open_tables
	endif

rem --- If PO is installed, open PO files that may be needed
	po$="N"
	dim info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
	po$=info$[20]
	if po$="Y" then
		num_files = 3
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="POE_LINKED", open_opts$[1]="OTA"
		open_tables$[2]="POE_REQHDR", open_opts$[2]="OTA"
		open_tables$[3]="POE_REQDET", open_opts$[3]="OTA"
		gosub open_tables
	endif
	callpoint!.setDevObject("po_installed",po$)

rem --- Disable display fields

	declare BBjVector column!
	column! = BBjAPI().makeVector()

	column!.addItem("<<DISPLAY>>.BADD1")
	column!.addItem("<<DISPLAY>>.BADD2")
	column!.addItem("<<DISPLAY>>.BADD3")
	column!.addItem("<<DISPLAY>>.BADD4")
	column!.addItem("<<DISPLAY>>.BCITY")
	column!.addItem("<<DISPLAY>>.BSTATE")
	column!.addItem("<<DISPLAY>>.BZIP")
	column!.addItem("<<DISPLAY>>.BCNTRY_ID")
	column!.addItem("<<DISPLAY>>.ORDER_TOT")

	if ars01a.job_nos$<>"Y" then 
		column!.addItem("OPE_INVHDR.JOB_NO")
	endif

	callpoint!.setColumnEnabled(column!, 0)

	column!.clear()
	column!.addItem("<<DISPLAY>>.SNAME")
	column!.addItem("<<DISPLAY>>.SADD1")
	column!.addItem("<<DISPLAY>>.SADD2")
	column!.addItem("<<DISPLAY>>.SADD3")
	column!.addItem("<<DISPLAY>>.SADD4")
	column!.addItem("<<DISPLAY>>.SCITY")
	column!.addItem("<<DISPLAY>>.SSTATE")
	column!.addItem("<<DISPLAY>>.SZIP")
	column!.addItem("<<DISPLAY>>.SCNTRY_ID")
	column!.addItem("<<DISPLAY>>.AGING_FUTURE")
	column!.addItem("<<DISPLAY>>.AGING_CUR")
	column!.addItem("<<DISPLAY>>.AGING_30")
	column!.addItem("<<DISPLAY>>.AGING_60")
	column!.addItem("<<DISPLAY>>.AGING_90")
	column!.addItem("<<DISPLAY>>.AGING_120")
	column!.addItem("<<DISPLAY>>.TOT_AGING")
	callpoint!.setColumnEnabled(column!, 0)

rem --- Update Control Labels for aging days
	days$=" "+Translate!.getTranslation("AON_DAYS","Days",1)+":"
	util.changeControlLabel(SysGUI!, callpoint!, "<<DISPLAY>>.AGING_30", str(ars01a.age_per_days_1)+days$)
	util.changeControlLabel(SysGUI!, callpoint!, "<<DISPLAY>>.AGING_60", str(ars01a.age_per_days_2)+days$)
	util.changeControlLabel(SysGUI!, callpoint!, "<<DISPLAY>>.AGING_90", str(ars01a.age_per_days_3)+days$)
	util.changeControlLabel(SysGUI!, callpoint!, "<<DISPLAY>>.AGING_120", str(ars01a.age_per_days_4)+"+"+days$)

rem --- Save display control objects

	UserObj!.addItem( util.getControl(callpoint!, "<<DISPLAY>>.ORDER_TOT") )
	UserObj!.addItem( util.getControl(callpoint!, "<<DISPLAY>>.SUBTOTAL") )
	UserObj!.addItem( util.getControl(callpoint!, "<<DISPLAY>>.NET_SALES") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_INVHDR.TOTAL_SALES") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_INVHDR.TOTAL_COST") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_INVHDR.TAX_AMOUNT") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_INVHDR.DISCOUNT_AMT") )
	UserObj!.addItem( util.getControl(callpoint!, "<<DISPLAY>>.BACKORDERED") )
	UserObj!.addItem( util.getControl(callpoint!, "<<DISPLAY>>.CREDIT_HOLD") )

	callpoint!.setDevObject("backordered_control", util.getControl(callpoint!, "<<DISPLAY>>.BACKORDERED")); rem used in opc_creditcheck

rem --- Setup user_tpl$
    
	tpl$ = 
:		"credit_installed:c(1), " +
:		"balance:n(7*), " +
:		"credit_limit:n(7*), " +
:		"display_bal:c(1), " +
:		"ord_tot:n(7*), " +
:		"def_ship:c(8), " + 
:		"def_commit:c(8), " +
:		"blank_whse:c(1), " +
:		"line_code:c(1), " +
:		"line_type:c(1), " +
:		"dropship_whse:c(1), " +
:		"def_whse:c(10), " +
:		"avail_oh:u(1), " +
:		"avail_comm:u(1), " +
:		"avail_avail:u(1), " +
:		"avail_oo:u(1), " +
:		"avail_wh:u(1), " +
:		"avail_type:u(1), " +
:		"dropship_flag:u(1), " +
:		"manual_price:u(1), " +
:		"alt_super:u(1), " +
:		"ord_tot_obj:u(1), " +
:		"price_code:c(2), " +
:		"pricing_code:c(6), " +
:		"order_date:c(8), " +
:		"pick_hold:c(1), " +
:		"pgmdir:c(1*), " +
:		"skip_whse:c(1), " +
:		"warehouse_id:c(2), " +
:		"cur_row:n(5), " +
:		"skip_ln_code:c(1), " +
:		"hist_ord:c(1), " +
:		"cash_sale:c(1), " +
:		"cash_cust:c(6), " +
:		"bo_col:u(1), " +
:		"shipped_col:u(1), " +
:		"prod_type_col:u(1), " +
:		"unit_price_col:u(1), " +
:		"allow_bo:c(1), " +
:		"amount_mask:c(1*)," +
:		"line_taxable:c(1), " +
:		"item_taxable:c(1), " +
:		"min_line_amt:n(7*), " +
:		"min_ord_amt:n(7*), " +
:		"item_price:n(7*), " +
:		"line_dropship:c(1), " +
:		"dropship_cost:c(1), " +
:		"new_detail:u(1), " +
:		"prev_line_code:c(1*), " +
:		"prev_item:c(1*), " +
:		"prev_qty_ord:n(7*), " +
:		"prev_boqty:n(7*), " +
:		"prev_shipqty:n(7*), " +
:		"prev_ext_price:n(7*), " +
:		"prev_taxable:n(7*), " +
:		"prev_ext_cost:n(7*), " +
:		"prev_disc_code:c(1*), "+
:		"prev_ship_to:c(1*), " +
:		"prev_sales_total:n(7*), " +
:		"prev_unitprice:n(7*), " +
:		"detail_modified:u(1), " +
:		"record_deleted:u(1), " +
:		"item_wh_failed:u(1), " +
:		"do_end_of_form:u(1), " +
:		"picklist_warned:u(1), " +
:		"disc_code:c(1*), " +
:		"tax_code:c(1*), " +
:		"new_order:u(1), " +
:		"credit_limit_warned:u(1), " +
:		"shipto_warned:u(1), " +
:		"line_prod_type_pr:c(1), " +
:		"glint:c(1)"

	dim user_tpl$:tpl$

	user_tpl.credit_installed$ = ars_credit.sys_install$
	user_tpl.pick_hold$        = ars_credit.pick_hold$
	user_tpl.display_bal$      = ars_credit.display_bal$
	user_tpl.blank_whse$       = blank_whse$
	user_tpl.dropship_whse$    = ars01a.dropshp_whse$
	call stbl("+DIR_PGM")+"adc_getmask.aon","","AR","A","",amt_mask$,0,0
	user_tpl.amount_mask$      = amt_mask$
	user_tpl.line_code$        = ars01a.line_code$
	user_tpl.skip_ln_code$     = ars01a.skip_ln_code$
	user_tpl.cash_sale$        = ars01a.cash_sale$
	user_tpl.cash_cust$        = ars01a.customer_id$
	user_tpl.allow_bo$         = ars01a.backorders$
	user_tpl.dropship_cost$    = ars01a.dropshp_cost$
	user_tpl.min_ord_amt       = num(ars01a.min_ord_amt$)
	user_tpl.min_line_amt      = num(ars01a.min_line_amt$)
	user_tpl.def_whse$         = ivs01a.warehouse_id$
	user_tpl.pgmdir$           = stbl("+DIR_PGM",err=*next)
	user_tpl.cur_row           = -1
	user_tpl.detail_modified   = 0
	user_tpl.record_deleted    = 0
	user_tpl.item_wh_failed    = 1
	user_tpl.do_end_of_form    = 1
	user_tpl.picklist_warned   = 0
	user_tpl.new_order         = 0
	user_tpl.credit_limit_warned = 0
	user_tpl.shipto_warned     = 0

	callpoint!.setDevObject("min_csh_sale",ars01a.min_csh_sale)
	callpoint!.setDevObject("min_line_amt",user_tpl.min_line_amt)
	callpoint!.setDevObject("amount_mask",user_tpl.amount_mask$)

rem --- Columns for the util disableCell() method

	user_tpl.bo_col            = 11
	user_tpl.shipped_col       = 12

	user_tpl.prev_line_code$   = ""
	user_tpl.prev_item$        = ""
	user_tpl.prev_qty_ord      = 0
	user_tpl.prev_boqty        = 0
	user_tpl.prev_shipqty      = 0
	user_tpl.prev_ext_price    = 0; rem used in detail section to hold the line extension 
	user_tpl.prev_ext_cost     = 0
	user_tpl.prev_disc_code$   = ""
	user_tpl.prev_ship_to$     = ""
	user_tpl.prev_sales_total  = 0; rem used in totals section to hold the order sale total
	user_tpl.prev_unitprice    = 0

rem --- Ship and Commit dates

	dim sysinfo$:stbl("+SYSINFO_TPL")
	sysinfo$=stbl("+SYSINFO")

	pgmdir$ = ""
	pgmdir$ = stbl("+DIR_PGM")

	orddate$ = sysinfo.system_date$
	comdate$ = orddate$
	shpdate$ = orddate$

	comdays = num(ars01a.commit_days$)
	shpdays = num(ars01a.def_shp_days$)

	if comdays then call pgmdir$+"adc_daydates.aon", orddate$, comdate$, comdays
	if shpdays then call pgmdir$+"adc_daydates.aon", orddate$, shpdate$, shpdays

	user_tpl.def_ship$   = shpdate$
	user_tpl.def_commit$ = comdate$

rem --- Save the indices of the controls for the Avail Window, setup in AFMC

	user_tpl.avail_oh      = 2
	user_tpl.avail_comm    = 3
	user_tpl.avail_avail   = 4
	user_tpl.avail_oo      = 5
	user_tpl.avail_wh      = 6
	user_tpl.avail_type    = 7
	user_tpl.dropship_flag = 8
	user_tpl.manual_price  = 9
	user_tpl.alt_super = 10
	user_tpl.ord_tot_obj   = 11; rem set here in BSHO

	callpoint!.setDevObject("subtot_disp","12")
	callpoint!.setDevObject("net_sales_disp","13")
	callpoint!.setDevObject("total_sales_disp","14")
	callpoint!.setDevObject("total_cost","15")
	callpoint!.setDevObject("tax_amt_disp","16")
	callpoint!.setDevObject("disc_amt_disp","17")
	callpoint!.setDevObject("backord_disp","18")
	callpoint!.setDevObject("credit_disp","19")

rem --- Create GL Posting Control
	gl$="N"
	call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,pgm(-2),"OP",glw11$,gl$,status
	user_tpl.glint$=gl$

rem --- Enable buttons

	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("KITS",0)
	callpoint!.setOptionEnabled("RCPR",0)
	callpoint!.setOptionEnabled("WHSE",0)
	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)
	callpoint!.setOptionEnabled("UINV",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("CASH",0)
	callpoint!.setOptionEnabled("TTLS",0)
	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("CRAT",0)
	callpoint!.setOptionEnabled("AGNG",0)

rem --- Parse table_chans$[all] into an object

	declare ArrayObject tableChans!

	call pgmdir$+"adc_array.aon::str_array2object", table_chans$[all], tableChans!, status
	util.setTableChans(tableChans!)

rem --- Order Helper object

	declare OrderHelper ordHelp!

	ordHelp! = new OrderHelper(firm_id$, int(num(ivs01a.precision$)), callpoint!, dtlg_param$[1,3])
	callpoint!.setDevObject("order_helper_object", ordHelp!)

rem --- get mask for display sequence number used in detail lines (needed when creating duplicate/credit)

	call stbl("+DIR_PGM")+"adc_getmask.aon","LINE_NO","","","",line_no_mask$,0,0
	callpoint!.setDevObject("line_no_mask",line_no_mask$)

rem --- Set object for which customer number is being shown and that details haven't changed

	callpoint!.setDevObject("current_customer","")
	callpoint!.setDevObject("details_changed","N")
	callpoint!.setDevObject("rcpr_row","")

rem --- setup message_tpl$

	gosub init_msgs

rem --- Set callback for a tab being selected, and save the tab control ID
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	tabCtrl!.setCallback(BBjTabCtrl.ON_TAB_SELECT,"custom_event")

rem --- Use standard magnifying glass lookup image on SNAME drilldown button
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	childWin!=tabCtrl!.getControlAt(0); rem --- Addresses tab
	ctrlVect!=childWin!.getAllControls()
	for i=0 to ctrlVect!.size()-1
		thisCtrl!=ctrlVect!.get(i)
		if thisCtrl!.getControlType()<>28 then continue
		if thisCtrl!.getName()="tbnd_sname" then
			thisCtrl!.setImageFile(stbl("+DIR_IMG")+"im_tb_fnd_f.png",err=*next);buttonType=1
			break
		endif
	next i

[[OPE_INVHDR.BWAR]]
rem --- Has customer and order number been entered?
	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))

	if ordHelp!.getCust_id() = "" or ordHelp!.getOrder_no() = "" then
		break; rem --- exit callpoint
	endif

rem --- Write Order Addresses file
	gosub write_address_file

rem --- Calculate Taxes
	disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax
	order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	gosub add_to_batch_print

[[OPE_INVHDR.BWRI]]
rem --- Has customer and order number been entered?

	cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")

	if cvs(cust_id$, 2) = "" or cvs(order_no$, 2) = "" then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Check for Order Total on non-cash sales

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE")<>"Y"  then
		ord_tot=num(callpoint!.getColumnData("<<DISPLAY>>.ORDER_TOT"))
		if ord_tot>0 and ord_tot<user_tpl.min_ord_amt
			call stbl("+DIR_PGM")+"adc_getmask.aon","","AR","A",imsk$,omsk$,ilen,olen
			msg_id$="OP_TOT_UNDER_MIN"
			dim msg_tokens$[1]
			msg_tokens$[1]=str(user_tpl.min_ord_amt:omsk$)
			gosub disp_message
			if msg_opt$="N"
				callpoint!.setStatus("ABORT")
			endif
		endif
	endif

rem --- Check to see if we need to go to the totals tab

	if pos(callpoint!.getDevObject("totals_warn")="34")>0
		if pos(callpoint!.getDevObject("was_on_tot_tab")="N") > 0
			if callpoint!.getDevObject("details_changed")="Y" and callpoint!.getDevObject("rcpr_row")=""
				callpoint!.setMessage("OP_TOTALS_TAB")
				callpoint!.setFocus("OPE_INVHDR.FREIGHT_AMT")
				callpoint!.setDevObject("was_on_tot_tab","Y")
				callpoint!.setStatus("ABORT-ACTIVATE")
				break
			endif
		endif
	endif

rem --- Initialize RTP modified fields for modified existing records
	if callpoint!.getRecordMode()="C" then
		rem --- For immediate write forms must compare initial record to current record to see if modified.
		dim initial_rec_data$:fattr(rec_data$)
		initial_rec_data$=callpoint!.getDevObject("initial_rec_data$")
		if rec_data$<>initial_rec_data$ then
			rec_data.mod_user$=sysinfo.user_id$
			rec_data.mod_date$=date(0:"%Yd%Mz%Dz")
			rec_data.mod_time$=date(0:"%Hz%mz")
			callpoint!.setDevObject("initial_rec_data$",rec_data$)
		endif
	endif

[[OPE_INVHDR.CUSTOMER_ID.AINP]]
rem --- If cash customer, get correct customer number

	if user_tpl.cash_sale$="Y" and cvs(callpoint!.getUserInput(),1+2+4)="C" then
		callpoint!.setColumnData("OPE_INVHDR.CUSTOMER_ID", user_tpl.cash_cust$,1)
		callpoint!.setColumnData("OPE_INVHDR.CASH_SALE", "Y")
	endif

[[OPE_INVHDR.CUSTOMER_ID.AVAL]]
print "Hdr:CUSTOMER_ID.AVAL"; rem debug

rem --- Display customer

	cust_id$ = callpoint!.getUserInput()

	rem "Customer Inactive Feature"
	arm01_dev=fnget_dev("ARM_CUSTMAST")
	arm01_tpl$=fnget_tpl$("ARM_CUSTMAST")
	dim arm01a$:arm01_tpl$
	arm01a_key$=firm_id$+cust_id$
	find record (arm01_dev,key=arm01a_key$,err=*break) arm01a$
	if arm01a.cust_inactive$="Y" then
		call stbl("+DIR_PGM")+"adc_getmask.aon","CUSTOMER_ID","","","",m0$,0,customer_size
		msg_id$="AR_CUST_INACTIVE"
		dim msg_tokens$[2]
	   	msg_tokens$[1]=fnmask$(arm01a.customer_id$(1,customer_size),m0$)
		msg_tokens$[2]=cvs(arm01a.customer_name$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE")
	endif

	gosub display_customer

	custdet_dev = fnget_dev("ARM_CUSTDET")
	dim custdet_tpl$:fnget_tpl$("ARM_CUSTDET")

	find record (custdet_dev, key=firm_id$+cust_id$+"  ",dom=*next) custdet_tpl$

rem --- Set customer in OrderHelper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setCust_id(cust_id$)

rem --- The cash customer?

	if user_tpl.cash_sale$="Y" and cust_id$ = user_tpl.cash_cust$
		callpoint!.setColumnData("OPE_INVHDR.CASH_SALE", "Y")
		callpoint!.setColumnData("OPE_INVHDR.SHIPTO_TYPE","M",1)
	else
		callpoint!.setColumnData("OPE_INVHDR.CASH_SALE", "N")
	endif

rem --- Show customer data

	if callpoint!.getColumnData("OPE_INVHDR.CASH_SALE") <> "Y" then 
		gosub display_aging
		gosub check_credit

		if callpoint!.getDevObject("current_customer") <> cust_id$
			if user_tpl.credit_installed$ = "Y" and user_tpl.display_bal$ = "A" then
				call user_tpl.pgmdir$+"opc_creditmgmnt.aon", cust_id$, "", table_chans$[all], callpoint!, status
				callpoint!.setDevObject("credit_status_done", "Y")
				callpoint!.setStatus("ACTIVATE")
			endif
		endif
	endif

	callpoint!.setDevObject("current_customer",cust_id$)
	callpoint!.setDevObject("disc_code",custdet_tpl.disc_code$)
	user_tpl.disc_code$    = custdet_tpl.disc_code$

	gosub disp_cust_comments

rem --- Enable Duplicate buttons, printer

	if cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),2) = "" and callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("DINV", 1)
		callpoint!.setOptionEnabled("CINV", 1)
	endif

	if user_tpl.credit_installed$="Y"
		callpoint!.setOptionEnabled("CRCH",1)
	endif
	callpoint!.setOptionEnabled("AGNG",iff(callpoint!.getDevObject("on_demand_aging")="Y",1,0))

[[OPE_INVHDR.CUSTOMER_PO_NO.AVAL]]
rem --- Check for duplicate PO numbers

	found_dupes! = BBjAPI().makeVector()
	if callpoint!.getDevObject("check_po_dupes")="Y" and cvs(callpoint!.getUserInput(),2)<>"" then
		po_no$=pad(callpoint!.getUserInput(),num(callpoint!.getTableColumnAttribute("OPE_INVHDR.CUSTOMER_PO_NO","MAXL")))
		cust_no$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
		opt_invlookup_dev=num(callpoint!.getDevObject("opt_invlookup"))
		dim opt_invlookup$:fnget_tpl$("OPT_INVHDR")

		read (opt_invlookup_dev,key=firm_id$+po_no$+cust_no$,knum="AO_PO_CUST",dom=*next)
		while 1
			read record (opt_invlookup_dev,end=*break) opt_invlookup$
			if pos(firm_id$+po_no$+cust_no$=opt_invlookup.firm_id$+opt_invlookup.customer_po_no$+opt_invlookup.customer_id$)<>1 break
			if order_no$<>opt_invlookup.order_no$
				dupePO! = BBjAPI().makeVector()
				if opt_invlookup.trans_status$="U" then
					dupePO!.addItem("U")
				else
					dupePO!.addItem("O")
				endif
				dupePO!.addItem(opt_invlookup.order_no$)
				dupePO!.addItem(opt_invlookup.ar_inv_no$)
				found_dupes!.addItem(dupePO!)
			endif
		wend
	endif

	if found_dupes!.size()>0 then
		msg_id$="OP_DUPLICATE_POS"
		gosub disp_message
		if msg_opt$="D"
			callpoint!.setDevObject("customer",callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID"))
			callpoint!.setDevObject("found_dupe",found_dupes!)
			call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:				"OPE_DUPEPO", 
:				stbl("+USER_ID"), 
:				"", 
:				"", 
:				table_chans$[all], 
:				dflt_data$[all]
		endif
	endif

[[OPE_INVHDR.CUSTOMER_PO_NO.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.CUSTOMER_REL_NO.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.DISCOUNT_AMT.AVAL]]
rem --- Discount Amount cannot exceed Total Sales Amount

	disc_amt = num(callpoint!.getUserInput())
	total_sales = num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES"))
	if (total_sales >= 0 and disc_amt > total_sales) or (total_sales < 0 and disc_amt < total_sales) then
		disc_amt = total_sales
		callpoint!.setUserInput(str(disc_amt))
	endif

rem --- Skip if the disc_amt hasn't changed
	if disc_amt=num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT")) then break

rem --- Recalculate Tax Amount and Totals

	callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1))
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_INVHDR.DISCOUNT_AMT.BINP]]
rem --- Now we've been on the Totals tab

	callpoint!.setDevObject("was_on_tot_tab","Y")

rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.DISC_CODE.AVAL]]
rem --- Set discount code for use in Order Totals if it changed
	disc_code$ = callpoint!.getUserInput()
	if cvs(disc_code$,3)=cvs(callpoint!.getColumnData("OPE_INVHDR.DISC_CODE"),3) then break

	user_tpl.disc_code$ = callpoint!.getUserInput()
	callpoint!.setDevObject("disc_code",user_tpl.disc_code$)

	file_name$ = "OPC_DISCCODE"
	disccode_dev = fnget_dev(file_name$)
	dim disccode_rec$:fnget_tpl$(file_name$)

	find record (disccode_dev, key=firm_id$+user_tpl.disc_code$, dom=*next) disccode_rec$
	new_disc_per = disccode_rec.disc_percent

	new_disc_amt = round(disccode_rec.disc_percent * num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES")) / 100, 2)
	callpoint!.setColumnData("OPE_INVHDR.DISCOUNT_AMT",str(new_disc_amt))

	disc_amt = new_disc_amt
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_INVHDR.DISC_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.EXPIRE_DATE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.FREIGHT_AMT.AVAL]]
rem --- Skip if the FREIGHT_AMT hasn't changed
	freight_amt = num(callpoint!.getUserInput())
	if freight_amt=num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT")) then break

rem --- Recalculate Tax Amount and Totals

	callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1))
	disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	gosub calculate_tax

[[OPE_INVHDR.FREIGHT_AMT.BINP]]
rem --- Now we've been on the Totals tab

	callpoint!.setDevObject("was_on_tot_tab","Y")

rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.INVOICE_DATE.AVAL]]
rem --- Prevent Invoice Date in an appropriate GL period
	invoice_date$=callpoint!.getUserInput()        
	if user_tpl.glint$="Y" 
		call stbl("+DIR_PGM")+"glc_datecheck.aon",invoice_date$,"Y",per$,yr$,status
		if status>100 then callpoint!.setStatus("ABORT")
	endif

rem --- Recalculate Tax Amount and Totals

	if invoice_date$<>callpoint!.getColumnData("OPE_INVHDR.INVOICE_DATE") then
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[OPE_INVHDR.INVOICE_DATE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.INVOICE_TYPE.AVAL]]
print "Hdr:INVOICE_TYPE.AVAL"; rem debug

rem --- Enable/disable expire date based on value

	inv_type$ = callpoint!.getUserInput()
	print "---Invoice Type: ", inv_type$; rem debug

	if inv_type$ = "S" then
		callpoint!.setColumnEnabled("OPE_INVHDR.EXPIRE_DATE", 0)
	else
		callpoint!.setColumnEnabled("OPE_INVHDR.EXPIRE_DATE", 1)
	endif

rem --- Set type in OrderHelper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setInv_type(callpoint!.getUserInput())

[[OPE_INVHDR.INVOICE_TYPE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.JOB_NO.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.MESSAGE_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.MISC_NO.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.ORDER_DATE.AVAL]]
rem --- Warn if Order Date isn't in an appropriate GL period
	order_date$=callpoint!.getUserInput()        
	if user_tpl.glint$="Y" 
		call stbl("+DIR_PGM")+"glc_datecheck.aon",order_date$,"Y",per$,yr$,status
	endif

rem --- Set user template info

	user_tpl.order_date$=order_date$

[[OPE_INVHDR.ORDER_DATE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.ORDER_NO.AVAL]]
rem --- Do we need to create a new order number?

	order_no$ = callpoint!.getUserInput()

	if cvs(order_no$, 2) = "" then 

	rem --- Option on order no field to assign a new sequence on null must be cleared

		call stbl("+DIR_SYP")+"bas_sequences.bbj","ORDER_NO",order_no$,table_chans$[all]
		
		if order_no$ = "" then
			callpoint!.setStatus("ABORT")
			break; rem --- exit callpoint
		else
			callpoint!.setUserInput(order_no$)
			orderNo!=callpoint!.getControl("OPE_INVHDR.ORDER_NO")
			orderNo!.setText(order_no$)
			user_tpl.new_order=1
		endif
	endif

rem --- Does order exist?

	ope01_dev = fnget_dev("OPE_INVHDR")
	dim ope01a$:fnget_tpl$("OPE_INVHDR")

	ar_type$ = callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	cust_id$ = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")

	rem --- Restrict to only order with Entry transaction status
	trans_status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	ope01_trip$=firm_id$+trans_status$+ar_type$+cust_id$+order_no$
	read(ope01_dev, key=ope01_trip$, dom=*next)
	ope01_key$=key(ope01_dev,end=*next)
	if pos(ope01_trip$=ope01_key$)=1 then
		readrecord(ope01_dev,key=ope01_key$)ope01a$
		if cvs(ope01a.ar_inv_no$,2)="" then
			rem --- Order not invoiced yet
			found = 1
		else
			rem --- Order has existing invoice
			callpoint!.setStatus("RECORD:["+ope01_key$+"]")
			break
		endif
	else
		found = 0
	endif

rem --- A new record must be the next sequence

	if found = 0 and user_tpl.new_order=0 then
		msg_id$ = "OP_NEW_ORD_USE_SEQ"
		gosub disp_message	
		callpoint!.setFocus("OPE_INVHDR.ORDER_NO")
		break; rem --- exit from callpoint
	endif

	user_tpl.hist_ord$ = "N"

rem --- Existing record

	if found then 

	rem --- Check for void

		if ope01a.invoice_type$ = "V" then
			msg_id$="OP_ORDINV_VOID"
			gosub disp_message
			callpoint!.setStatus("NEWREC")
			break; rem --- exit from callpoint			
		endif

	rem --- Check for quote
		
		if ope01a.invoice_type$ = "P" then
			msg_id$ = "OP_IS_QUOTE"
			gosub disp_message
			callpoint!.setStatus("NEWREC")
			break; rem --- exit from callpoint			
		endif		

	rem --- Check for order, force to an Invoice

		if ope01a.ordinv_flag$ <> "I" then
			rem --- Force order to invoice in ADIS
			inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
			callpoint!.setStatus("RECORD:["+firm_id$+trans_status$+ar_type$+cust_id$+order_no$+inv_no$+"]")
			break; rem --- exit callpoint
		endif

	rem --- Set Codes
	        
		user_tpl.price_code$   = ope01a.price_code$
		user_tpl.pricing_code$ = ope01a.pricing_code$
		user_tpl.order_date$   = ope01a.order_date$

rem --- New record, set default  

	else

		call stbl("+DIR_SYP")+"bas_sequences.bbj", "INVOICE_NO", invoice_no$, table_chans$[all]

		if invoice_no$ = "" then
			callpoint!.setStatus("ABORT")
		endif

		callpoint!.setColumnData("OPE_INVHDR.AR_INV_NO", invoice_no$)

	        cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
		order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
		callpoint!.setColumnData("OPE_INVHDR.INVOICE_TYPE","S")

	rem --- Set default invoice type in OrderHelper object

		ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
		ordHelp!.setInv_type("S")
        
		arm02_dev = fnget_dev("ARM_CUSTDET")
		dim arm02a$:fnget_tpl$("ARM_CUSTDET")
		read record (arm02_dev, key=firm_id$+cust_id$+"  ", dom=*next) arm02a$

		arm01_dev = fnget_dev("ARM_CUSTMAST")
		dim arm01a$:fnget_tpl$("ARM_CUSTMAST")
		read record (arm01_dev, key=firm_id$+cust_id$, dom=*next) arm01a$
		
		callpoint!.setColumnData("OPE_INVHDR.INVOICE_TYPE","S")
		callpoint!.setColumnData("OPE_INVHDR.ORDINV_FLAG","I")
		callpoint!.setColumnData("OPE_INVHDR.INVOICE_DATE",sysinfo.system_date$)
		callpoint!.setColumnData("OPE_INVHDR.SHIPMNT_DATE",sysinfo.system_date$)
		callpoint!.setColumnData("OPE_INVHDR.AR_SHIP_VIA",arm01a.ar_ship_via$)
		callpoint!.setColumnData("OPE_INVHDR.SHIPPING_ID",arm01a.shipping_id$)
		callpoint!.setColumnData("OPE_INVHDR.SHIPPING_EMAIL",arm01a.shipping_email$)
		callpoint!.setColumnData("OPE_INVHDR.SLSPSN_CODE",arm02a.slspsn_code$)
		callpoint!.setColumnData("OPE_INVHDR.TERMS_CODE",arm02a.ar_terms_code$)
		callpoint!.setColumnData("OPE_INVHDR.DISC_CODE",arm02a.disc_code$)
		callpoint!.setColumnData("OPE_INVHDR.AR_DIST_CODE",arm02a.ar_dist_code$)
		callpoint!.setColumnData("OPE_INVHDR.PRINT_STATUS","N")
		callpoint!.setColumnData("OPE_INVHDR.MESSAGE_CODE",arm02a.message_code$)
		callpoint!.setColumnData("OPE_INVHDR.TERRITORY",arm02a.territory$)
		callpoint!.setColumnData("OPE_INVHDR.ORDER_DATE",sysinfo.system_date$)
		callpoint!.setColumnData("OPE_INVHDR.TAX_CODE",arm02a.tax_code$)
		callpoint!.setColumnData("OPE_INVHDR.PRICING_CODE",arm02a.pricing_code$)
		callpoint!.setColumnData("OPE_INVHDR.ORD_TAKEN_BY",sysinfo.user_id$)
		callpoint!.setColumnData("OPE_INVHDR.FOB",arm01a.fob$)

		callpoint!.setDevObject("disc_code",arm02a.disc_code$)
		user_tpl.disc_code$    = arm02a.disc_code$

		ordHelp!.setTaxCode(arm02a.tax_code$)

		slsp$ = arm02a.slspsn_code$
		gosub get_comm_percent

		gosub get_op_params

		user_tpl.price_code$   = ""
		user_tpl.pricing_code$ = arm02a.pricing_code$
		user_tpl.order_date$   = sysinfo.system_date$

		callpoint!.setOptionEnabled("UINV",0)

		rem --- Update sales tax calculation to use SalesInvoice for sales tax service
		callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC","1",1)
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

rem --- New or existing order

	order_no$ = callpoint!.getUserInput()
	gosub add_to_batch_print
	rem callpoint!.setColumnData("OPE_INVHDR.LOCK_STATUS", "Y")
	callpoint!.setColumnData("OPE_INVHDR.LOCK_STATUS", "N"); rem debug, forcing the lock off for now, not working correctly

rem --- Disable buttons

	callpoint!.setOptionEnabled("DINV", 0)
	callpoint!.setOptionEnabled("CINV", 0)

	callpoint!.setStatus("MODIFIED;REFRESH")

rem --- Set order in OrderHelper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setOrder_no(order_no$)

[[OPE_INVHDR.PRICE_CODE.AVAL]]
rem --- Set user template info

	user_tpl.price_code$=callpoint!.getUserInput()

[[OPE_INVHDR.PRICE_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.PRICING_CODE.AVAL]]
rem --- Set user template info

	user_tpl.pricing_code$=callpoint!.getUserInput()

[[OPE_INVHDR.PRICING_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[<<DISPLAY>>.SADD1.AVAL]]
rem --- Check Ship-to's

	shipto_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	shipto_no$  = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	ship_addr$=callpoint!.getUserInput()+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD1 was changed
	sadd1$=callpoint!.getUserInput()
	if cvs(sadd1$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD1"),3) then
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SADD2.AVAL]]
rem --- Check Ship-to's

	shipto_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	shipto_no$  = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getUserInput()+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD2 was changed
	sadd2$=callpoint!.getUserInput()
	if cvs(sadd2$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD2"),3) then
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SADD3.AVAL]]
rem --- Check Ship-to's

	shipto_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	shipto_no$  = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getUserInput()+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD3 was changed
	sadd3$=callpoint!.getUserInput()
	if cvs(sadd3$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD3"),3) then
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SADD4.AVAL]]
rem --- Check Ship-to's

	shipto_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	shipto_no$  = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getUserInput()
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD4 was changed
	sadd4$=callpoint!.getUserInput()
	if cvs(sadd4$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD4"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SCITY.AVAL]]
rem --- Update sales tax calculation if SCITY was changed
	scity$=callpoint!.getUserInput()
	if cvs(city$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SCITY"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SCNTRY_ID.AVAL]]
rem --- Update sales tax calculation if SCNTRY_ID was changed
	scntry_id$=callpoint!.getUserInput()
	if cvs(scntry_id$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SCNTRY_ID"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[OPE_INVHDR.SHIPMNT_DATE.AVAL]]
rem --- Warn if Shipment Date isn't in an appropriate GL period
	shipmnt_date$=callpoint!.getUserInput()        
	if user_tpl.glint$="Y" 
		call stbl("+DIR_PGM")+"glc_datecheck.aon",shipmnt_date$,"Y",per$,yr$,status
	endif

[[OPE_INVHDR.SHIPMNT_DATE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.SHIPPING_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

[[OPE_INVHDR.SHIPPING_ID.AVAL]]
rem --- Enable/disable Freight Amount
	shipping_id$=callpoint!.getUserInput()
	if shipping_id$=callpoint!.getColumnData("OPE_INVHDR.SHIPPING_ID") then break

	if cvs(shipping_id$,2)<>"" then
		callpoint!.setColumnEnabled("OPE_INVHDR.FREIGHT_AMT",0)
		callpoint!.setColumnData("OPE_INVHDR.FREIGHT_AMT",str(0),1)
	else
		callpoint!.setColumnEnabled("OPE_INVHDR.FREIGHT_AMT",1)
	endif

[[OPE_INVHDR.SHIPTO_NO.AVAL]]
rem --- Check Ship-to's if SHIPTO_NO has changed
	shipto_no$  = callpoint!.getUserInput()
	if cvs(shipto_no$,3)=cvs(callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO"),3) then break

rem --- Don't allow inactive code
	armCustShip_dev=fnget_dev("ARM_CUSTSHIP")
	dim armCustShip$:fnget_tpl$("ARM_CUSTSHIP")
	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	read record(armCustShip_dev,key=firm_id$+customer_id$+shipto_no$,dom=*next)armCustShip$
	if armCustShip.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(armCustShip.shipto_no$,3)
		msg_tokens$[2]=cvs(armCustShip.city$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

	shipto_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		callpoint!.setDevObject("abort_shipto_no",1)
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

rem --- Remove manual ship-record, if necessary

	cust_id$    = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$   = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")

	if user_tpl.prev_ship_to$ = "000099" and shipto_no$ <> "000099" then
		remove (fnget_dev("OPE_ORDSHIP"), key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*next)
	endif

rem --- Display Ship to information

	ship_to_no$  = callpoint!.getUserInput()
	ship_to_type$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	gosub ship_to_info

[[OPE_INVHDR.SHIPTO_NO.BINP]]
rem --- Save old value

	user_tpl.prev_ship_to$ = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")

rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

rem --- Allow changing shipto_type when abort shipto_no
	if callpoint!.getDevObject("abort_shipto_no")<>null() then
		if num(callpoint!.getDevObject("abort_shipto_no"),err=*endif)
			callpoint!.setDevObject("abort_shipto_no",0)
			callpoint!.setFocus("OPE_INVHDR.SHIPTO_TYPE")
			callpoint!.setStatus("ABORT")
			break; rem --- exit callpoint
		endif
	endif

[[OPE_INVHDR.SHIPTO_TYPE.AVAL]]
rem -- Deal with which Ship To type if it has changed
	ship_to_type$ = callpoint!.getUserInput()
	if cvs(ship_to_type$,3)=cvs(callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE"),3) and callpoint!.getRecordMode()<>"A" then break

	ship_to_type$ = callpoint!.getUserInput()
	ship_to_no$   = callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO")
	cust_id$      = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$     = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")

	gosub ship_to_info

rem --- Disable Ship To fields

	gosub disable_shipto

[[OPE_INVHDR.SHIPTO_TYPE.BINP]]
rem --- Do we need to create a new order number?

	if cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),2)=""
		call stbl("+DIR_SYP")+"bas_sequences.bbj","ORDER_NO",seq_id$,table_chans$[all]
		
		if len(seq_id$)=0 
			callpoint!.setStatus("ABORT")
			break; rem --- exit callpoint
		else
			callpoint!.setColumnData("OPE_INVHDR.ORDER_NO",seq_id$)
			callpoint!.setStatus("REFRESH")
		endif
	endif

rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.SLSPSN_CODE.AVAL]]
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

rem --- Set Commission Percent
	slsp$ = callpoint!.getUserInput()
	gosub get_comm_percent

[[OPE_INVHDR.SLSPSN_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[<<DISPLAY>>.SNAME.BDRL]]
rem --- Skip if not for a manual ship-to in edit mode
	shipto_type$=callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
	if shipto_type$<>"M" or !callpoint!.isEditMode() then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Manual ship-to historical address lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVHDR","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim optInvHdr_key$:key_tpl$
	dim filter_defs$[3,2]
	filter_defs$[1,0]="OPT_INVHDR.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="OPT_INVHDR.CUSTOMER_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")+"'"
	filter_defs$[2,2]="LOCK"
	filter_defs$[3,0]="OPT_INVHDR.SHIPTO_TYPE"
	filter_defs$[3,1]="='M'"
	filter_defs$[3,2]="LOCK"
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"OP_MAN_SHIPTO","",table_chans$[all],optInvHdr_key$,filter_defs$[all]

	rem --- Update manual ship-to address if changed
	if cvs(optInvHdr_key$,2)<>"" then 
		opt31_dev=fnget_dev("OPT_INVSHIP")
		dim opt31a$:fnget_tpl$("OPT_INVSHIP")
		opt31_key$=firm_id$+optInvHdr_key.customer_id$+optInvHdr_key.order_no$+optInvHdr_key.ar_inv_no$+"S"
		readrecord(opt31_dev,key=opt31_key$,dom=*next)opt31a$
		callpoint!.setColumnData("<<DISPLAY>>.SADD1",opt31a.addr_line_1$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD2",opt31a.addr_line_2$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD3",opt31a.addr_line_3$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD4",opt31a.addr_line_4$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SCITY",opt31a.city$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SSTATE",opt31a.state_code$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SZIP",opt31a.zip_code$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID",opt31a.cntry_id$,1)
		callpoint!.setColumnData("<<DISPLAY>>.SNAME",opt31a.name$,1)

		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[<<DISPLAY>>.SSTATE.AVAL]]
rem --- Update sales tax calculation if SSTATE was changed
	sstate$=callpoint!.getUserInput()
	if cvs(sstate$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SSTATE"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SZIP.AVAL]]
rem --- Update sales tax calculation if SZIP was changed
	szip$=callpoint!.getUserInput()
	if cvs(szip$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SZIP"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[OPE_INVHDR.TAX_AMOUNT.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.TAX_CODE.AVAL]]
rem --- Skip if the TAX_CODE hasn't changed
	tax_code$=callpoint!.getUserInput()
	if tax_code$=callpoint!.getColumnData("OPE_INVHDR.TAX_CODE") then break

rem --- Set code in the Order Helper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setTaxCode(tax_code$)

rem --- Calculate Taxes

	disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_INVHDR.TAX_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.TERMS_CODE.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.TERRITORY.AVAL]]
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

[[OPE_INVHDR.TERRITORY.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.TOTAL_SALES.BINP]]
rem --- Enable/Disable Cash Sale button
	gosub able_cash_sale

[[OPE_INVHDR.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon

rem #include fnget_control.src
	def fnget_control!(ctl_name$)
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	get_control!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
	return get_control!
	fnend
rem #endinclude fnget_control.src

rem ==========================================================================
display_customer: rem --- Get and display Bill To Information
                  rem      IN: cust_id$
rem ==========================================================================

	custmast_dev = fnget_dev("ARM_CUSTMAST")
	dim custmast_tpl$:fnget_tpl$("ARM_CUSTMAST")
	find record (custmast_dev, key=firm_id$+cust_id$,dom=*next) custmast_tpl$

	callpoint!.setColumnData("<<DISPLAY>>.BADD1",  custmast_tpl.addr_line_1$)
	callpoint!.setColumnData("<<DISPLAY>>.BADD2",  custmast_tpl.addr_line_2$)
	callpoint!.setColumnData("<<DISPLAY>>.BADD3",  custmast_tpl.addr_line_3$)
	callpoint!.setColumnData("<<DISPLAY>>.BADD4",  custmast_tpl.addr_line_4$)
	callpoint!.setColumnData("<<DISPLAY>>.BCITY",  custmast_tpl.city$)
	callpoint!.setColumnData("<<DISPLAY>>.BSTATE", custmast_tpl.state_code$)
	callpoint!.setColumnData("<<DISPLAY>>.BZIP",   custmast_tpl.zip_code$)
	callpoint!.setColumnData("<<DISPLAY>>.BCNTRY_ID",   custmast_tpl.cntry_id$)


	return

rem ==========================================================================
display_aging: rem --- Display customer aging
               rem      IN: cust_id$
rem ==========================================================================

	custdet_dev = fnget_dev("ARM_CUSTDET")
	dim custdet_tpl$:fnget_tpl$("ARM_CUSTDET")
	custpmts_dev = fnget_dev("ARM_CUSTPMTS")
	dim custpmts_tpl$:fnget_tpl$("ARM_CUSTPMTS")

	find record (custdet_dev, key=firm_id$+cust_id$+"  ",dom=*next) custdet_tpl$
	find record (custpmts_dev, key=firm_id$+cust_id$,dom=*next) custpmts_tpl$

	user_tpl.balance = custdet_tpl.aging_future+
:		custdet_tpl.aging_cur+
:		custdet_tpl.aging_30+
:		custdet_tpl.aging_60+
:		custdet_tpl.aging_90+
:		custdet_tpl.aging_120

	callpoint!.setColumnData("<<DISPLAY>>.AGING_120",    custdet_tpl.aging_120$)
	callpoint!.setColumnData("<<DISPLAY>>.AGING_30",     custdet_tpl.aging_30$)
	callpoint!.setColumnData("<<DISPLAY>>.AGING_60",     custdet_tpl.aging_60$)
	callpoint!.setColumnData("<<DISPLAY>>.AGING_90",     custdet_tpl.aging_90$)
	callpoint!.setColumnData("<<DISPLAY>>.AGING_CUR",    custdet_tpl.aging_cur$)
	callpoint!.setColumnData("<<DISPLAY>>.AGING_FUTURE", custdet_tpl.aging_future$)
	callpoint!.setColumnData("<<DISPLAY>>.TOT_AGING",    user_tpl.balance$)
	callpoint!.setColumnData("<<DISPLAY>>.AVG_DAYS",    custpmts_tpl.avg_days$)
	callpoint!.setColumnData("<<DISPLAY>>.LSTINV_DATE",    custpmts_tpl.lstinv_date$)
	callpoint!.setColumnData("<<DISPLAY>>.LSTPAY_DATE",    custpmts_tpl.lstpay_date$)
	callpoint!.setColumnData("<<DISPLAY>>.REPORT_DATE",    custdet_tpl.report_date$)

	switch pos(custdet_tpl.report_type$=" DI")
		case 1
			report_type$=""
			break
		case 2
			report_type$="D - Due Date"
			break
		case 3
			report_type$="I - Invoice Date"
			break
		case default
			report_type$="Unknown"
			break
	swend
	callpoint!.setColumnData("<<DISPLAY>>.REPORT_TYPE",report_type$,1)

	rem --- also display cust type
	callpoint!.setColumnData("<<DISPLAY>>.CUST_TP",   custdet_tpl.customer_type$)

	user_tpl.credit_limit = custdet_tpl.credit_limit

	return

rem ==========================================================================
check_credit: rem --- Check credit limit of customer
              rem     (ope_cb, 5400-5499)
rem ==========================================================================

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	creditRemaining = ordHelp!.getCreditLimit()-ordHelp!.getTotalAging()-ordHelp!.getOpenOrderAmount()-ordHelp!.getOpenBoAmount()-ordHelp!.getHeldOrderAmount()
	if user_tpl.credit_limit<>0 and !user_tpl.credit_limit_warned and num(callpoint!.getColumnData("<<DISPLAY>>.NET_SALES")) > creditRemaining then
   		if user_tpl.credit_installed$ <> "Y" then
      			msg_id$ = "OP_OVER_CREDIT_LIMIT"
			dim msg_tokens$[1]
			msg_tokens$[1] = str(custdet_tpl.credit_limit:user_tpl.amount_mask$)
         		gosub disp_message
     		endif  
   
		callpoint!.setDevObject("msg_exceeded","Y")
		user_tpl.credit_limit_warned = 1
	endif

	return

rem ==========================================================================
ship_to_info: rem --- Get and display Ship-To Information
              rem      IN: cust_id$
              rem          ship_to_type$
              rem          ship_to_no$
              rem          order_no$
rem ==========================================================================

	custmast_dev=fnget_dev("ARM_CUSTMAST")
	dim custmast$:fnget_tpl$("ARM_CUSTMAST")
	findrecord(custmast_dev,key=firm_id$+cust_id$,dom=*next)custmast$

	ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	custdet_dev=fnget_dev("ARM_CUSTDET")
	dim custdet$:fnget_tpl$("ARM_CUSTDET")
	read record(custdet_dev,key=firm_id$+cust_id$+ar_type$)custdet$


	if ship_to_type$<>"M" then

		if ship_to_type$="S" then
			custship_dev = fnget_dev("ARM_CUSTSHIP")
			dim custship_tpl$:fnget_tpl$("ARM_CUSTSHIP")
			read record (custship_dev, key=firm_id$+cust_id$+ship_to_no$, dom=*next) custship_tpl$

			callpoint!.setColumnData("<<DISPLAY>>.SNAME",custship_tpl.name$)
			callpoint!.setColumnData("<<DISPLAY>>.SADD1",custship_tpl.addr_line_1$)
			callpoint!.setColumnData("<<DISPLAY>>.SADD2",custship_tpl.addr_line_2$)
			callpoint!.setColumnData("<<DISPLAY>>.SADD3",custship_tpl.addr_line_3$)
			callpoint!.setColumnData("<<DISPLAY>>.SADD4",custship_tpl.addr_line_4$)
			callpoint!.setColumnData("<<DISPLAY>>.SCITY",custship_tpl.city$)
			callpoint!.setColumnData("<<DISPLAY>>.SSTATE",custship_tpl.state_code$)
			callpoint!.setColumnData("<<DISPLAY>>.SZIP",custship_tpl.zip_code$)
			callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID",custship_tpl.cntry_id$)
			if ship_to_type$<>callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE") or
:                       ship_to_no$<>callpoint!.getColumnData("OPE_INVHDR.SHIPTO_NO") then
				rem --- Initialize for change
				callpoint!.setColumnData("OPE_INVHDR.SLSPSN_CODE",custship_tpl.slspsn_code$)
				callpoint!.setColumnData("OPE_INVHDR.TERRITORY",custship_tpl.territory$)
				callpoint!.setColumnData("OPE_INVHDR.TAX_CODE",custship_tpl.tax_code$)
				if cvs(custship_tpl.ar_ship_via$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.AR_SHIP_VIA",custship_tpl.ar_ship_via$)
				if cvs(custship_tpl.shipping_id$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.SHIPPING_ID",custship_tpl.shipping_id$)
				if cvs(custship_tpl.shipping_email$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.SHIPPING_EMAIL",custship_tpl.shipping_email$)
			endif
		else
			callpoint!.setColumnData("OPE_INVHDR.SHIPTO_NO","")
			callpoint!.setColumnData("<<DISPLAY>>.SNAME",Translate!.getTranslation("AON_SAME"))
			callpoint!.setColumnData("<<DISPLAY>>.SADD1","")
			callpoint!.setColumnData("<<DISPLAY>>.SADD2","")
			callpoint!.setColumnData("<<DISPLAY>>.SADD3","")
			callpoint!.setColumnData("<<DISPLAY>>.SADD4","")
			callpoint!.setColumnData("<<DISPLAY>>.SCITY","")
			callpoint!.setColumnData("<<DISPLAY>>.SSTATE","")
			callpoint!.setColumnData("<<DISPLAY>>.SZIP","")
			callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID","")
			if ship_to_type$<>callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE") then
				rem --- Initialize for change
				callpoint!.setColumnData("OPE_INVHDR.SLSPSN_CODE",custdet.slspsn_code$)
				callpoint!.setColumnData("OPE_INVHDR.TERRITORY",custdet.territory$)
				callpoint!.setColumnData("OPE_INVHDR.TAX_CODE",custdet.tax_code$)
				if cvs(custmast.ar_ship_via$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.AR_SHIP_VIA",custmast.ar_ship_via$,1)
				if cvs(custmast.shipping_id$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.SHIPPING_ID",custmast.shipping_id$)
				if cvs(custmast.shipping_email$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.SHIPPING_EMAIL",custmast.shipping_email$)
			endif
		endif

	else

		callpoint!.setColumnData("OPE_INVHDR.SHIPTO_NO","")
		if ship_to_type$<>callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE") then
			if custdet.slspsn_code$<>callpoint!.getColumnData("OPE_INVHDR.SLSPSN_CODE") or
:			custdet.territory$<>callpoint!.getColumnData("OPE_INVHDR.TERRITORY") or
:			custdet.tax_code$<>callpoint!.getColumnData("OPE_INVHDR.TAX_CODE") OR
:			(cvs(custmast.ar_ship_via$,2)<>"" and cvs(custmast.ar_ship_via$,2)<>callpoint!.getColumnData("OPE_INVHDR.AR_SHIP_VIA")) or
:			(cvs(custmast.shipping_id$,2)<>"" and cvs(custmast.shipping_id$,2)<>callpoint!.getColumnData("OPE_INVHDR.SHIPPING_ID")) or
:			(cvs(custmast.shipping_email$,2)<>"" and cvs(custmast.shipping_email$,2)<>callpoint!.getColumnData("OPE_INVHDR.SHIPPING_EMAIL")) then
				msg_id$="OP_SHIPTO_CODE_CHGS"
				gosub disp_message

				rem --- Initialize for change
				callpoint!.setColumnData("OPE_INVHDR.SLSPSN_CODE",custdet.slspsn_code$)
				callpoint!.setColumnData("OPE_INVHDR.TERRITORY",custdet.territory$)
				callpoint!.setColumnData("OPE_INVHDR.TAX_CODE",custdet.tax_code$)
				if cvs(custmast.ar_ship_via$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.AR_SHIP_VIA",custmast.ar_ship_via$,1)
				if cvs(custmast.shipping_id$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.SHIPPING_ID",custmast.shipping_id$)
				if cvs(custmast.shipping_email$,2)<>"" then callpoint!.setColumnData("OPE_INVHDR.SHIPPING_EMAIL",custmast.shipping_email$)
			endif
		endif

		ordship_dev = fnget_dev("OPE_ORDSHIP")
		dim ordship_tpl$:fnget_tpl$("OPE_ORDSHIP")
		invoice_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
		read record (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*endif) ordship_tpl$

		callpoint!.setColumnData("<<DISPLAY>>.SNAME",ordship_tpl.name$)
		callpoint!.setColumnData("<<DISPLAY>>.SADD1",ordship_tpl.addr_line_1$)
		callpoint!.setColumnData("<<DISPLAY>>.SADD2",ordship_tpl.addr_line_2$)
		callpoint!.setColumnData("<<DISPLAY>>.SADD3",ordship_tpl.addr_line_3$)
		callpoint!.setColumnData("<<DISPLAY>>.SADD4",ordship_tpl.addr_line_4$)
		callpoint!.setColumnData("<<DISPLAY>>.SCITY",ordship_tpl.city$)
		callpoint!.setColumnData("<<DISPLAY>>.SSTATE",ordship_tpl.state_code$)
		callpoint!.setColumnData("<<DISPLAY>>.SZIP",ordship_tpl.zip_code$)
		callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID",ordship_tpl.cntry_id$)
	endif

	disc_amt = num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax

	callpoint!.setStatus("REFRESH")

	return

rem ==========================================================================
get_op_params:
rem ==========================================================================

	ars01_dev = fnget_dev("ARS_PARAMS")
	dim ars01a$:fnget_tpl$("ARS_PARAMS")

	read record (ars01_dev, key=firm_id$+"AR00") ars01a$

	return

rem ==========================================================================
disp_cust_comments: rem --- Display customer comments
                    rem      IN: cust_id$
rem ==========================================================================

	arm01_dev=fnget_dev("ARM_CUSTMAST")
	dim arm01a$:fnget_tpl$("ARM_CUSTMAST")
	read record (arm01_dev, key=firm_id$+cust_id$, dom=*next) arm01a$
	callpoint!.setColumnData("<<DISPLAY>>.comments", arm01a.memo_1024$,1)

	return

rem ==========================================================================
check_lock_flag: rem --- Check manual record lock
                 rem     OUT: locked = 1 or 0
rem ==========================================================================
	switch pos( callpoint!.getColumnData("OPE_INVHDR.LOCK_STATUS") = "NYS123" )
		case 1
			break

		case 2
			msg_id$="ORD_LOCKED"
			dim msg_tokens$[1]

			if callpoint!.getColumnData("OPE_INVHDR.PRINT_STATUS")="B" then 
				msg_tokens$[1]=Translate!.getTranslation("AON__BY_BATCH_PRINT")
				gosub disp_message

				if msg_opt$="Y"
					callpoint!.setColumnData("OPE_INVHDR.LOCK_STATUS", "N")
					callpoint!.setStatus("SAVE"); rem --- unlock at BWRI doesn't seem to work
				else
					locked=1

				endif
			endif
			break

		case 3
			msg_id$="ORD_ON_REG"
			gosub disp_message
			if pos("PASSVALID"=msg_opt$)=0
				locked=1
			endif
			break

		case 4
		case 5
			msg_id$="INVOICE_IN_UPDATE"
			gosub disp_message
			if pos("PASSVALID"=msg_opt$)=0
				locked=1
			endif
			break

		case 6
			msg_id$="INVOICE_UPDATED"
			gosub disp_message
			locked=1
			break

		case default
			break
	swend

	return

rem ==========================================================================
add_to_batch_print: rem --- Add to batch print file
                    rem      IN: order_no$
rem ==========================================================================

	ope_prntlist_dev = fnget_dev("OPE_PRNTLIST")
	dim ope_prntlist$:fnget_tpl$("OPE_PRNTLIST")
	cust_id$ = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")

	remove (ope_prntlist_dev, key=firm_id$+"O  "+cust_id$+order_no$, dom=*next)

	ope_prntlist.firm_id$     = firm_id$
	ope_prntlist.ordinv_flag$ = "I"
	ope_prntlist.ar_type$     = "  "
	ope_prntlist.customer_id$ = cust_id$
	ope_prntlist.order_no$    = order_no$
	ope_prntlist_key$=ope_prntlist.firm_id$+ope_prntlist.ordinv_flag$+ope_prntlist.ar_type$+ope_prntlist.customer_id$+ope_prntlist.order_no$
	extractrecord(ope_prntlist_dev,key=ope_prntlist_key$,dom=*next)x$; rem Advisory Lockint

	ope_prntlist.no_sls_tax_calc=num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))
	ope_prntlist$ = field(ope_prntlist$)
	write record (ope_prntlist_dev) ope_prntlist$

	return

rem ==========================================================================
check_print_flag: rem --- Check print flag
                  rem     OUT: locked = 1/0
rem ==========================================================================

	locked = 0
	ar_type$      = callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	cust_id$      = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$     = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	print_status$ = callpoint!.getColumnData("OPE_INVHDR.PRINT_STATUS")
	ordinv_flag$  = callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG")

	if ordinv_flag$ = "O" then 
		if print_status$ <> "Y" and !user_tpl.picklist_warned then 
			user_tpl.picklist_warned = 1
			msg_id$ = "OP_PICKLIST_NOT_DONE"
			gosub disp_message

			if msg_opt$ = "N" then
				gosub unlock_order
				locked=1
			endif
		endif
	else
		if ordinv_flag$ = "I" then 
			if print_status$ <> "N" then 
				msg_id$ = "OP_REPRINT_INVOICE"
				gosub disp_message

				if msg_opt$ = "N" then 
					gosub unlock_order
					locked=1
				else
					callpoint!.setColumnData("OPE_INVHDR.PRINT_STATUS", "N")
					callpoint!.setStatus("SAVE")
					gosub add_to_batch_print
				endif
			else
				gosub add_to_batch_print
			endif
		endif
	endif

	return 

rem ==========================================================================
update_totals: rem --- Update Order/Invoice Totals & Commit Inventory
               rem      IN: ope11a$
	       rem	      wh_id$
               rem          item_id$
               rem          ls_id$ 
               rem          qty
rem ==========================================================================

	inv_type$ = callpoint!.getColumnData("OPE_INVHDR.INVOICE_TYPE")

	call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",iv_files[all],ivs01a$,iv_info$[all],iv_refs$[all],iv_refs[all],table_chans$[all],status
	iv_info$[1] = wh_id$
	iv_info$[2] = item_id$
	iv_info$[3] = ls_id$
	iv_refs[0]  = qty

	while 1
		if pos(opc_linecode.line_type$="SP")=0 then break
		if opc_linecode.dropship$="Y" or inv_type$="P" then break; REM "Dropship or quote
		if line_sign>0 then iv_action$="OE" else iv_action$="UC"
		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		readrecord(ivm01_dev,key=firm_id$+item_id$,dom=*next)ivm01a$
		if pos(ivm01a.kit$="YP")=0 then
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon",iv_action$,iv_files[all],ivs01a$,iv_info$[all],iv_refs$[all],iv_refs[all],table_chans$[all],iv_status
		else
			rem --- Skip the kit, and do its components instead.
			optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
			dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
			ar_type$=ope11a.ar_type$ 
			cust$=ope11a.customer_id$
			order$=ope11a.order_no$
			invoice_no$=ope11a.ar_inv_no$
			seq$=ope11a.internal_seq_no$
			optInvKitDet_key$=firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$
			read(optInvKitDet_dev,key=optInvKitDet_key$,knum="AO_STAT_CUST_ORD",dom=*next)
			while 1
				thisKey$=key(optInvKitDet_dev,end=*break)
				if pos(optInvKitDet_key$=thisKey$)<>1 then break
				readrecord(optInvKitDet_dev)optInvKitDet$

				iv_info$[1] = optInvKitDet.warehouse_id$
				iv_info$[2] = optInvKitDet$.item_id$
				iv_refs[0]  = optInvKitDet.qty_ordered
				call stbl("+DIR_PGM")+"ivc_itemupdt.aon",iv_action$,iv_files[all],ivs01a$,iv_info$[all],iv_refs$[all],iv_refs[all],table_chans$[all],iv_status
			wend
		endif
		break
	wend

	return

rem ==========================================================================
remove_lot_ser_det: rem --- Remove Lot/Serial Detail
                    rem      IN: ar_type$
                    rem          cust$
                    rem          ord$     = order number
                    rem          invoice$ = invoice number
                    rem          ord_seq$ = internal seq number
rem ==========================================================================

	inv_type$ = callpoint!.getColumnData("OPE_INVHDR.INVOICE_TYPE")

	ope21_dev = fnget_dev("OPE_ORDLSDET")
	dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
	read (ope21_dev, key=firm_id$+ar_type$+cust$+ord$+invoice$+ord_seq$,knum="PRIMARY", dom=*next)

	while 1
		read record (ope21_dev, end=*break) ope21a$

		if firm_id$<>ope21a.firm_id$ then break
		if ar_type$<>ope21a.ar_type$ then break
		if cust$<>ope21a.customer_id$ then break
		if ord$<>ope21a.order_no$ then break
		if invoice$<>ope21a.ar_inv_no$ then break
		if ord_seq$<>ope21a.orddet_seq_ref$ then break

		if opc_linecode.dropship$<>"Y" and inv_type$<>"P" then 
			wh_id$    = ope11a.warehouse_id$
			item_id$  = ope11a.item_id$
			ls_id$    = ""
			qty       = ope21a.qty_ordered
			line_sign = 1
			gosub update_totals

			ls_id$    = ope21a.lotser_no$
			line_sign = -1
			gosub update_totals
		endif

		remove (ope21_dev, key=firm_id$+ar_type$+cust$+ord$+invoice$+ord_seq$+ope21a.sequence_no$)
	wend
	read (ope21_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

	return

rem ==========================================================================
copy_order: rem --- Duplicate or Credit Historical Invoice
            rem          line_sign = 1/-1
rem ==========================================================================

	copy_ok$="Y"

	while 1
		rd_key$ = ""
		dim filter_defs$[3,2]
		filter_defs$[0,0]="OPT_INVHDR.FIRM_ID"
		filter_defs$[0,1]="='"+firm_id$+"'"
		filter_defs$[0,2]="LOCK"
		filter_defs$[1,0]="OPT_INVHDR.TRANS_STATUS"
		filter_defs$[1,1]="='U'"
		filter_defs$[1,2]="LOCK"
		filter_defs$[2,0]="OPT_INVHDR.AR_TYPE"
		filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")+"'"
		filter_defs$[2,2]="LOCK"
		filter_defs$[3,0]="OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1]="='"+callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")+"'"
		filter_defs$[3,2]="LOCK"

		call stbl("+DIR_SYP")+"bax_query.bbj",
:			gui_dev,
:			Form!,
:			"OP_HISTINV",
:			"",
:			table_chans$[all],
:			rd_key$,
:			filter_defs$[all],
:			"",
:			"",
:			"AO_STAT_CUST_INV"

		if cvs(rd_key$,2)<>"" then 
			if rd_key$(len(rd_key$),1)="^"
				rd_key$=rd_key$(1,len(rd_key$)-1)
			endif

			call stbl("+DIR_SYP")+"bac_key_template.bbj",
:				"OPT_INVHDR",
:				"PRIMARY",
:				key_temp$,
:				table_chans$[all],
:				status$

			dim key_temp$:key_temp$
			key_temp$=rd_key$
			key_opt$=key_temp.firm_id$+key_temp.ar_type$+key_temp.customer_id$+key_temp.order_no$+key_temp.ar_inv_no$
			opt01_dev = fnget_dev("OPT_INVHDR")
			dim opt01a$:fnget_tpl$("OPT_INVHDR")
			read record (opt01_dev, key=key_opt$,knum="PRIMARY") opt01a$
			if opt01a.trans_status$<>"U" then
				rem --- Can only duplicate historical invoices
				msg_id$="OP_NO_HIST"
				gosub disp_message
				copy_ok$="N"
			endif
			break
		else
			copy_ok$="N"
			break
		endif

	wend

	reprice$="N"

	if copy_ok$="Y" then 

		if line_sign=1 then 
			msg_id$ = "OP_REPRICE_ORD"
			gosub disp_message
			reprice$ = msg_opt$
		endif

		seq_id$=cvs(callpoint!.getColumnData("OPE_INVHDR.ORDER_NO"),2)
		if seq_id$="" then
			call stbl("+DIR_SYP")+"bas_sequences.bbj","ORDER_NO",seq_id$,rd_table_chans$[all]
		endif

		if seq_id$<>"" then 
			ope01_dev = fnget_dev("OPE_INVHDR")
			dim ope01a$:fnget_tpl$("OPE_INVHDR")
			ope01a$=opt01a$
			ope01a.ar_inv_no$      = ""
			ope01a.backord_flag$   = ""
			ope01a.comm_amt        = ope01a.comm_amt*line_sign
			ope01a.customer_po_no$ = ""
			ope01a.discount_amt    = ope01a.discount_amt*line_sign
			callpoint!.setDevObject("disc_amt",str(ope01a.discount_amt))
			ope01a.expire_date$    = ""
			ope01a.freight_amt     = ope01a.freight_amt*line_sign
			callpoint!.setDevObject("frt_amt",str(ope01a.freight_amt))
			ope01a.invoice_date$   = user_tpl.def_ship$
			ope01a.invoice_type$   = "S"
			ope01a.lock_status$ = "N"
			ope01a.order_date$     = sysinfo.system_date$
			ope01a.order_no$       = seq_id$
			ope01a.ordinv_flag$    = "O"
			ope01a.ord_taken_by$   = sysinfo.user_id$
			ope01a.print_status$   = "Y"
			ope01a.reprint_flag$   = ""
			ope01a.credit_flag$    = ""
			ope01a.shipmnt_date$   = user_tpl.def_ship$
			ope01a.taxable_amt     = ope01a.taxable_amt*line_sign
			ope01a.tax_amount      = ope01a.tax_amount*line_sign
			ope01a.total_cost      = ope01a.total_cost*line_sign
			ope01a.total_sales     = ope01a.total_sales*line_sign
			ope01a.created_user$   = sysinfo.user_id$
			ope01a.created_date$   = date(0:"%Yd%Mz%Dz")
			ope01a.created_time$   = date(0:"%Hz%mz")
			ope01a.mod_user$   = ""
			ope01a.mod_date$   = ""
			ope01a.mod_time$   = ""
			ope01a.trans_status$   = "E"
			ope01a.arc_user$   = ""
			ope01a.arc_date$   = ""
			ope01a.arc_time$   = ""
			ope01a.batch_no$   = ""
			ope01a.audit_number   = 0
			ope01a.ship_seq_no$="001"
			if line_sign=-1 then ope01a.credit_invoice$=opt01a.ar_inv_no$
			if callpoint!.getDevObject("sls_tax_intrface")<>"" then
				opc_taxcode_dev = fnget_dev("OPC_TAXCODE")
				dim opc_taxcode$:fnget_tpl$("OPC_TAXCODE")
				findrecord(opc_taxcode_dev,key=firm_id$+opt01a.tax_code$,dom=*next)opc_taxcode$
				if opc_taxcode.use_tax_service then ope01a.no_sls_tax_calc=1
			endif

			ope01a$=field(ope01a$)
			write record (ope01_dev) ope01a$
			ope01_key$=ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$+ope01a.customer_id$+ope01a.order_no$+ope01a.ar_inv_no$
			extractrecord(ope01_dev,key=ope01_key$)ope01a$; rem Advisory Locking
			callpoint!.setStatus("SETORIG")

			order_no$=ope01a.order_no$
			gosub add_to_batch_print

			user_tpl.price_code$   = ope01a.price_code$
			user_tpl.pricing_code$ = ope01a.pricing_code$
			user_tpl.order_date$   = ope01a.order_date$

			rem --- Copy historical bill-to and ship-to addresses
			if line_sign=-1 then
				dim ope31a$:fnget_tpl$("OPE_ORDSHIP")
				ope31_dev=fnget_dev("OPE_ORDSHIP")
				dim opt31a$:fnget_tpl$("OPT_INVSHIP")
				opt31_dev=fnget_dev("OPT_INVSHIP")

				for i=1 to 2
					if i=1 then
						address_type$="B"
					else
						address_type$="S"
					endif
					read record (opt31_dev, key=firm_id$+opt01a.customer_id$+opt01a.order_no$+opt01a.ar_inv_no$+address_type$, dom=*continue) opt31a$
					if opt31a.trans_status$="U" then
						ope31a$=opt31a$
						ope31a.order_no$ = ope01a.order_no$
						ope31a.ar_inv_no$=""

						ope31a.created_user$   = sysinfo.user_id$
						ope31a.created_date$   = date(0:"%Yd%Mz%Dz")
						ope31a.created_time$   = date(0:"%Hz%mz")
						ope31a.mod_user$   = ""
						ope31a.mod_date$   = ""
						ope31a.mod_time$   = ""
						ope31a.trans_status$   = "E"
						ope31a.arc_user$   = ""
						ope31a.arc_date$   = ""
						ope31a.arc_time$   = ""
						ope31a.batch_no$   = ""
						ope31a.audit_number   = 0

						ope31_key$=ope31a.firm_id$+ope31a.customer_id$+ope31a.order_no$+ope31a.ar_inv_no$+address_type$
						extractrecord(ope31_dev,key=ope31_key$,dom=*next)x$; rem Advisory Locking
						ope31a$ = field(ope31a$)
						write record (ope31_dev) ope31a$
					endif
				next i
			endif

		rem --- Copy detail lines

			dim opt11a$:fnget_tpl$("OPT_INVDET")
			opt11_dev=fnget_dev("OPT_INVDET")

			dim ope11a$:fnget_tpl$("OPE_INVDET")
			ope11_dev=fnget_dev("OPE_INVDET")

			ope21_dev = fnget_dev("OPE_ORDLSDET")
			dim ope21a$:fnget_tpl$("OPE_ORDLSDET")

			ivm01_dev=fnget_dev("IVM_ITEMMAST")
			dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")

			ivm02_dev = fnget_dev("IVM_ITEMWHSE")
			dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")

			read (opt11_dev,knum="PRIMARY",dom=*next);rem set opt11 to use primary key
			read (opt11_dev, key=firm_id$+opt01a.ar_type$+opt01a.customer_id$+opt01a.order_no$+opt01a.ar_inv_no$, dom=*next)

			opc_linecode_dev = fnget_dev("OPC_LINECODE")
			dim opc_linecode$:fnget_tpl$("OPC_LINECODE")

			disp_line_no=0

			while 1
				read record (opt11_dev, end=*break) opt11a$

				if firm_id$+opt01a.ar_type$+opt01a.customer_id$+opt01a.order_no$+opt01a.ar_inv_no$ <>
:					opt11a.firm_id$+opt11a.ar_type$+opt11a.customer_id$+opt11a.order_no$+opt11a.ar_inv_no$ 
:				then 
					break
				endif

				if opt11a.trans_status$<>"U" then continue

				ope11a$=opt11a$

				if cvs(opt11a.line_code$,2)<>"" then 
					redim opc_linecode$ 
					read record (opc_linecode_dev, key=firm_id$+opt11a.line_code$, dom=*next) opc_linecode$
				endif

				if pos(opc_linecode.line_type$="SP") and reprice$="Y" then 
					gosub pricing
				endif

				if opc_linecode.line_type$<>"M" then 
					if opc_linecode.line_type$="O" and ope11a.commit_flag$="N" then 
						ope11a.ext_price  = ope11a.unit_price
						ope11a.unit_price = 0			
					endif

					if line_sign=-1 then 
						ope11a.qty_ordered = -ope11a.qty_shipped
						ope11a.ext_price   = -ope11a.ext_price
					endif

					if opc_linecode.line_type$<>"O" then 
						ope11a.qty_shipped = ope11a.qty_ordered
						ope11a.qty_backord = 0
						ope11a.taxable_amt = 0
						ope11a.ext_price   = round(ope11a.unit_price * ope11a.qty_shipped, 2)
					endif

					if callpoint!.getDevObject("sls_tax_intrface")<>"" and opc_taxcode.use_tax_service then
						ope11a.taxable_amt = ope11a.ext_price
					else
						if pos(opc_linecode.line_type$="SP")=0 then 
							if opc_linecode.taxable_flag$="Y" then 
								ope11a.taxable_amt = ope11a.ext_price
							endif
						else
							redim ivm01a$
							read record (ivm01_dev, key=firm_id$+ope11a.item_id$, dom=*next) ivm01a$
							if opc_linecode.taxable_flag$="Y" and ivm01a.taxable_flag$="Y" then 
								ope11a.taxable_amt = ope11a.ext_price
							endif

							rem --- Warn about superseded items
							if ivm01a.alt_sup_flag$="S" then
								redim ivm02a$
								readrecord (ivm02_dev, key=firm_id$+ope11a.warehouse_id$+ope11a.item_id$, dom=*next) ivm02a$

								msg_id$="OP_INCLUDES_SUPERSED"
								dim msg_tokens$[4]
								msg_tokens$[1]=str(ope11a.qty_ordered)
								msg_tokens$[2]=cvs(ope11a.item_id$,2)
								msg_tokens$[3]=cvs(ivm01a.alt_sup_item$,2)
								msg_tokens$[4]=str(ivm02a.qty_on_hand - ivm02a.qty_commit)
								gosub disp_message
							endif
						endif
					endif
				endif

				ope11a.order_no$     = ope01a.order_no$
        				ope11a.ar_inv_no$     = ""
				ope11a.est_shp_date$ = ope01a.shipmnt_date$
				ope11a.commit_flag$  = "Y"
				ope11a.pick_flag$    = "N"

				if ope11a.est_shp_date$>user_tpl.def_commit$ then 
					ope11a.commit_flag$ = "N"
				endif

				if user_tpl.blank_whse$="N" and cvs(ope11a.warehouse_id$,2)="" and 
:					opc_linecode.dropship$="Y" and user_tpl.dropship_whse$="N"
:				then
					ope11a.warehouse_id$ = user_tpl.def_whse$
				endif

                			ope11a.created_user$   = sysinfo.user_id$
				ope11a.created_date$   = date(0:"%Yd%Mz%Dz")
				ope11a.created_time$   = date(0:"%Hz%mz")
				ope11a.mod_user$   = ""
				ope11a.mod_date$   = ""
				ope11a.mod_time$   = ""
				ope11a.trans_status$   = "E"
				ope11a.arc_user$   = ""
				ope11a.arc_date$   = ""
				ope11a.arc_time$   = ""
				ope11a.batch_no$   = ""
				ope11a.audit_number   = 0

				call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
				ope11a.internal_seq_no$=int_seq_no$
				disp_line_no=disp_line_no+1
				line_no_mask$=callpoint!.getDevObject("line_no_mask")
				ope11a.line_no$=str(disp_line_no:line_no_mask$)
				ope11_key$=ope11a.firm_id$+ope11a.ar_type$+ope11a.customer_id$+ope11a.order_no$+ope11a.ar_inv_no$+ope11a.internal_seq_no$
				extractrecord(ope11_dev,key=ope11_key$,dom=*next,knum="PRIMARY")x$; rem Advisory Locking

				ope11a$ = field(ope11a$)
				write record (ope11_dev) ope11a$

				rem --- Commit inventory for this new order
				if ope11a.commit_flag$ ="Y" and pos(opc_linecode.line_type$="SP") then
					wh_id$=ope11a.warehouse_id$
					item_id$ =ope11a.item_id$
					ls_id$=""
					qty=ope11a.qty_ordered
					gosub update_totals; rem --- do ATAMO for item

						rem --- Process lotted/serialized items
						read(ope21_dev,key=ope11_key$,knum="PRIMARY",dom=*next)
						while 1
							ope21_key$=key(ope21_dev,end=*break)
							if pos(ope11_key$=ope21_key$)<>1 then break
							readrecord(ope21_dev)ope21a$

							ls_id$=ope21a.lotser_no$
							gosub update_totals; rem --- do ATAMO for lot/serial
						wend
						read(ope21_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next)
					endif
			wend
			read(ope11_dev,knum="AO_STAT_CUST_ORD",dom=*next); rem --- reset key to OPE_INVDET form's key

			callpoint!.setStatus("RECORD:["+firm_id$+callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")+ope01a.ar_type$+ope01a.customer_id$+ope01a.order_no$+ope01a.ar_inv_no$+"]")
			user_tpl.hist_ord$ = "Y"

		endif

	endif

	return

rem ==========================================================================
pricing: rem --- Call Pricing routine
         rem      IN: ope11a$ - Order Detail record
         rem          seq_id$ - order number
         rem          ivm02_dev
         rem          ivs01_dev
rem ==========================================================================

	ope01_dev = fnget_dev("OPE_INVHDR")
	dim ope01a$:fnget_tpl$("OPE_INVHDR")

	ivm02_dev = fnget_dev("IVM_ITEMWHSE")
	dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")

	ivs01_dev = fnget_dev("IVS_PARAMS")
	dim ivs01a$:fnget_tpl$("IVS_PARAMS")

	trans_status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	ordqty   =ope11a.qty_ordered
	wh$      =ope11a.warehouse_id$
	item$    =ope11a.item_id$
	ar_type$ =ope11a.ar_type$
	cust$    =ope11a.customer_id$
	ord$     =seq_id$
	inv_no$=ope01a.ar_inv_no$
	extract record (ope01_dev, key=firm_id$+trans_status$+ar_type$+cust$+ord$+inv_no$) ope01a$; rem Advisory Locking

	dim pc_files[6]
	pc_files[1] = fnget_dev("IVM_ITEMMAST")
	pc_files[2] = ivm02_dev
	pc_files[3] = fnget_dev("IVM_ITEMPRIC")
	pc_files[4] = fnget_dev("IVC_PRICCODE")
	pc_files[5] = fnget_dev("ARS_PARAMS")
	pc_files[6] = ivs01_dev

	call stbl("+DIR_PGM")+"opc_pricing.aon",pc_files[all],firm_id$,wh$,item$,user_tpl.price_code$,cust$,
:		user_tpl.order_date$,user_tpl.pricing_code$,ordqty,typeflag$,price,disc,status
	if status=999 then exitto std_exit

	if price=0 then
		msg_id$="ENTER_PRICE"
		gosub disp_message
	else
		ope11a.unit_price   = price
		ope11a.disc_percent = disc
	endif

	if disc=100 then
		read record (ivm02_dev, key=firm_id$+wh$+item$) ivm02a$
		ope11a.std_list_prc = ivm02a.cur_price
	else
		ope11a.std_list_prc = (price*100)/(100-disc)
	endif

	return

rem ==========================================================================
unlock_order: REM --- Unlock Order
rem ==========================================================================
	
	callpoint!.setColumnData("OPE_INVHDR.LOCK_STATUS", "N")
	callpoint!.setStatus("SAVE")

	return 

rem ==========================================================================
force_print_status: rem --- Force print status to N and write
rem ==========================================================================

	if callpoint!.getColumnData("OPE_INVHDR.PRINT_STATUS") = "Y" then
		callpoint!.setColumnData("OPE_INVHDR.PRINT_STATUS", "N")

	rem --- Write flag to file so opc_creditaction can see it

		gosub get_disk_rec
		write record (ordhdr_dev) ordhdr_rec$
		ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
		extractrecord(ordhdr_dev,key=ordhdr_key$)ordhdr_rec$; rem Advisory Locking

		callpoint!.setStatus("SETORIG")
	endif

	return

rem ==========================================================================
do_invoice: rem --- Print an Invoice
rem OUT: invoicePrinted
rem ==========================================================================
	invoicePrinted=1

rem --- Make sure everything's written back to disk

	gosub get_disk_rec
	write record (ordhdr_dev) ordhdr_rec$
	ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
rem	extractrecord(ordhdr_dev,key=ordhdr_key$)ordhdr_rec$; rem Advisory Locking - rem'd because invoice program does the extract

rem --- on demand invoice
 
	cp_cust_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	cp_order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[2,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=cp_cust_id$
	dflt_data$[2,0]="ORDER_NO"
	dflt_data$[2,1]=cp_order_no$
 
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPR_INV_DEMAND",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]

	rem --- How did form end?
	if callpoint!.getDevObject("oprInvDemand_end")="BEND" then
		rem --- User did Close (Ctrl+F4)
		invoicePrinted=0
		return
	endif

	return

rem ==========================================================================
clear_avail: rem --- Clear Availability Information
rem ==========================================================================

	userObj!.getItem(user_tpl.avail_oh).setText("")
	userObj!.getItem(user_tpl.avail_comm).setText("")
	userObj!.getItem(user_tpl.avail_avail).setText("")
	userObj!.getItem(user_tpl.avail_oo).setText("")
	userObj!.getItem(user_tpl.avail_wh).setText("")
	userObj!.getItem(user_tpl.avail_type).setText("")
	userObj!.getItem(user_tpl.dropship_flag).setText("")
	userObj!.getItem(user_tpl.manual_price).setText("")
	userObj!.getItem(user_tpl.alt_super).setText("")

	inv_avail_title!=callpoint!.getDevObject("inv_avail_title")
	inv_avail_title!.setVisible(0)

	return

rem ==========================================================================
get_comm_percent: rem --- Get commission percent from salesperson file
                  rem      IN: slsp$ - salesperson code
rem ==========================================================================

	file$ = "ARC_SALECODE"
	salecode_dev = fnget_dev(file$)
	dim salecode_rec$:fnget_tpl$(file$)

	find record (salecode_dev, key=firm_id$+"F"+slsp$, dom=*next) salecode_rec$
	callpoint!.setColumnData("OPE_INVHDR.COMM_PERCENT", salecode_rec.comm_rate$)

	return

rem ==========================================================================
make_invoice: rem --- Change an Order into an Invoice
rem ==========================================================================

	gosub check_print_flag

	customer_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	if !locked and cvs(customer_id$,2)<>"" and cvs(order_no$,2)<>"" and 
:		callpoint!.getColumnData("OPE_INVHDR.ORDINV_FLAG") <> "I" then

		rem --- Can't create invoice if someone has the order extracted.
		status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
		ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
		old_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
		lock_table$="OPT_INVHDR"
		lock_record$=firm_id$+status$+ar_type$+customer_id$+order_no$+old_inv_no$
		lock_type$="C"
		lock_disp$="M"
		lock_status$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		if lock_status$="ERR_LOCKED"
			locked = 1
			return
		endif

	rem --- Set Invoice number

		call stbl("+DIR_SYP")+"bas_sequences.bbj","INVOICE_NO",inv_no$,table_chans$[all]
		
		if inv_no$ = "" then
			callpoint!.setStatus("NEWREC")
			locked = 1
		else
			rem --- Was Fulfillment used for this order?
			optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
			dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
			didFulfillment=0
			extractrecord(optFillmntHdr_dev,key=firm_id$+"E"+ar_type$+customer_id$+order_no$+old_inv_no$,knum="AO_STATUS",dom=*next)optFillmntHdr$; didFulfillment=1

			rem --- Replace ope_ordship ope-31 records
			ope31_dev=fnget_dev("OPE_ORDSHIP")
			dim ope31a$:fnget_tpl$("OPE_ORDSHIP")
			old_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
			address_type$=callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE")
			for i=1 to 2
				if i=1 then
					address_type$="B"
				else
					address_type$="S"
				endif
				ope31_key$=firm_id$+customer_id$+order_no$+old_inv_no$+address_type$
				extractrecord(ope31_dev,key=ope31_key$,dom=*next)ope31a$; ordship_found=1; rem Advisory locking
				if ordship_found and ope31a.trans_status$="E" then
					ope31a.ar_inv_no$=inv_no$
					ope31a.mod_user$=sysinfo.user_id$
					ope31a.mod_date$=date(0:"%Yd%Mz%Dz")
					ope31a.mod_time$=date(0:"%Hz%mz")
					ope31a$=field(ope31a$)
					writerecord(ope31_dev)ope31a$
					remove(ope31_dev,key=ope31_key$)
				endif
			next i

			rem --- Replace ope_invdet ope-11 records
			skipNewOpe21Records$=""
			ope11_dev = fnget_dev("OPE_INVDET")
			dim ope11a$:fnget_tpl$("OPE_INVDET")
			ope11_trip$=firm_id$+status$+ar_type$+customer_id$+order_no$+old_inv_no$
			read (ope11_dev, key=ope11_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
			while 1
				ope11_key$=key(ope11_dev,end=*break)
				if pos(ope11_trip$=ope11_key$)<>1 then break
				extractrecord(ope11_dev)ope11a$; rem Advisory locking
				rem --- Skip new ope_invdet ope-11 records where QTY_ORDERED=0, QTY_SHIPPED=0 and QTY_BACKORD=0, if for NOT "M" and "O" line types.
				skipNewOpe11Record=0
				if ope11a.qty_ordered=0 and ope11a.qty_shipped=0 and ope11a.qty_backord=0 then
					opc_linecode_dev = fnget_dev("OPC_LINECODE")
					dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
					read record (opc_linecode_dev, key=firm_id$+ope11a.line_code$, dom=*next) opc_linecode$
					if pos(opc_linecode.line_type$="MO")=0 then
						skipNewOpe11Record=1
						skipNewOpe21Records$=skipNewOpe21Records$+ope11a.internal_seq_no$+";"
					endif
				endif
				if !skipNewOpe11Record then
					if didFulfillment then
						rem --- Use Fulfillment item picking info
						optFillmntDet_dev = fnget_dev("OPT_FILLMNTDET")
						dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
						optFillmntDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+old_inv_no$+ope11a.internal_seq_no$
						read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="AO_STATUS_ORDDET",dom=*next)
						while 1
							optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
							if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
							readrecord(optFillmntDet_dev)optFillmntDet$
							break
						wend
						rem --- Make sure this detail line is pickable
						if optFillmntDet.qty_shipped>0 then
							opc_linecode_dev = fnget_dev("OPC_LINECODE")
							dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
							read record (opc_linecode_dev, key=firm_id$+ope11a.line_code$, dom=*next) opc_linecode$
							if pos(opc_linecode.line_type$="MO")=0 and opc_linecode.dropship$<>"Y" then 
								ope11a.qty_shipped=optFillmntDet.qty_picked
								if ope11a.qty_shipped<=ope11a.qty_ordered then ope11a.qty_backord=ope11a.qty_ordered-ope11a.qty_shipped
							endif
						endif
					endif

					ope11a.ar_inv_no$=inv_no$
					ope11a.mod_user$=sysinfo.user_id$
					ope11a.mod_date$=date(0:"%Yd%Mz%Dz")
					ope11a.mod_time$=date(0:"%Hz%mz")
					ope11a$=field(ope11a$)
					writerecord(ope11_dev)ope11a$
				endif
				ope11_primary$=ope11a.firm_id$+ope11a.ar_type$+ope11a.customer_id$+ope11a.order_no$+old_inv_no$+ope11a.internal_seq_no$
				remove(ope11_dev,key=ope11_primary$)
				read(ope11_dev,key=ope11_key$,dom=*next)
			wend

			rem --- Replace opt_invkitdet order records with opt_invkitdet invoice records
			skipNewKitDetRecords$=""
			optInvKitDet_dev = fnget_dev("OPT_INVKITDET")
			dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
			optInvKitDet_trip$=firm_id$+status$+ar_type$+customer_id$+order_no$+old_inv_no$
			read (optInvKitDet_dev, key=optInvKitDet_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
			while 1
				optInvKitDet_key$=key(optInvkitDet_dev,end=*break)
				if pos(optInvKitDet_trip$=optInvKitDet_key$)<>1 then break
				extractrecord(optInvKitDet_dev)optInvKitDet$; rem Advisory locking
				rem --- Skip new opt_invkitdet records where QTY_ORDERED=0, QTY_SHIPPED=0 and QTY_BACKORD=0, if NOT for "M" and "O" line types.
				skipNewkitDetRecord=0
				if optInvKitDet.qty_ordered=0 and optInvKitDet.qty_shipped=0 and optInvKitDet.qty_backord=0 then
					opc_linecode_dev = fnget_dev("OPC_LINECODE")
					dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
					read record (opc_linecode_dev, key=firm_id$+optInvKitDet.line_code$, dom=*next)opc_linecode$
					if pos(opc_linecode.line_type$="MO")=0 then
						skipNewOpe11Record=1
						skipNewKitDetRecords$=skipNewKitDetRecords$+optInvKitDet.internal_seq_no$+";"
					endif
				endif
				if !skipNewOpe11Record then
					if didFulfillment then
						rem --- Use Fulfillment item picking info
						optFillmntDet_dev = fnget_dev("OPT_FILLMNTDET")
						dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
						optFillmntDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+old_inv_no$+ope11a.internal_seq_no$
						read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="AO_STATUS_ORDDET",dom=*next)
						while 1
							optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
							if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
							readrecord(optFillmntDet_dev)optFillmntDet$
							break
						wend
						rem --- Make sure this detail line is pickable
						if optFillmntDet.qty_shipped>0 then
							opc_linecode_dev = fnget_dev("OPC_LINECODE")
							dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
							read record (opc_linecode_dev, key=firm_id$+optInvKitDet.line_code$, dom=*next)opc_linecode$
							if pos(opc_linecode.line_type$="MO")=0 and opc_linecode.dropship$<>"Y" then 
								optInvKitDet.qty_shipped=optFillmntDet.qty_picked
								if optInvKitDet.qty_shipped<=optInvKitDet.qty_ordered then optInvKitDet.qty_backord=optInvKitDet.qty_ordered-optInvKitDet.qty_shipped
							endif
						endif
					endif
            
					optInvKitDet.ar_inv_no$=inv_no$
					optInvKitDet.mod_user$=sysinfo.user_id$
					optInvKitDet.mod_date$=date(0:"%Yd%Mz%Dz")
					optInvKitDet.mod_time$=date(0:"%Hz%mz")
					optInvKitDet$=field(optInvKitDet$)
					writerecord(optInvKitDet_dev)optInvKitDet$
				endif
				optInvKitDet_primary$=optInvKitDet.firm_id$+optInvKitDet.ar_type$+optInvKitDet.customer_id$+optInvKitDet.order_no$+old_inv_no$+optInvKitDet.orddet_seq_ref$+optInvKitDet.internal_seq_no$
				remove(optInvKitDet_dev,key=optInvKitDet_primary$)
				read(optInvKitDet_dev,key=optInvKitDet_key$,dom=*next)
			wend

			rem --- Replace ope_ordlsdet ope-21 records
			if didFulfillment then
				rem --- Remove any item lot/serial picking info from Order Entry
				ope21_dev = fnget_dev("OPE_ORDLSDET")
				dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
				status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
				ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
				ope21_trip$=firm_id$+status$+ar_type$+customer_id$+order_no$+old_inv_no$
				read (ope21_dev, key=ope21_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
				while 1
					ope21_key$=key(ope21_dev,end=*break)
					if pos(ope21_trip$=ope21_key$)<>1 then break
					extractrecord(ope21_dev)ope21a$; rem Advisory locking
					ope21_primary$=ope21a.firm_id$+ope21a.ar_type$+ope21a.customer_id$+ope21a.order_no$+old_inv_no$+ope21a.orddet_seq_ref$+ope21a.sequence_no$
					remove(ope21_dev,key=ope21_primary$)
					read(ope21_dev,key=ope21_key$,dom=*next)
				wend

				rem --- Use Fulfillment item lot/serial picking info
				optFillmntLsDet_dev = fnget_dev("OPT_FILLMNTLSDET")
				dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
				optFillmntLsDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+old_inv_no$
				read(optFillmntLsDet_dev,key=optFillmntLsDet_trip$,knum="AO_STATUS",dom=*next)
				while 1
					optFillmntLsDet_key$=key(optFillmntLsDet_dev,end=*break)
					if pos(optFillmntLsDet_trip$=optFillmntLsDet_key$)<>1 then break
					readrecord(optFillmntLsDet_dev)optFillmntLsDet$

					redim ope21a$
					ope21a.firm_id$=optFillmntLsDet.firm_id$
					ope21a.ar_type$=optFillmntLsDet.ar_type$
					ope21a.customer_id$=optFillmntLsDet.customer_id$
					ope21a.order_no$=optFillmntLsDet.order_no$
					ope21a.ar_inv_no$=inv_no$
					ope21a.orddet_seq_ref$=optFillmntLsDet.orddet_seq_ref$
					ope21a.sequence_no$=optFillmntLsDet.sequence_no$
					ope21a.lotser_no$=optFillmntLsDet.lotser_no$
					ope21a.created_user$=sysinfo.user_id$
					ope21a.created_date$=date(0:"%Yd%Mz%Dz")
					ope21a.created_time$=date(0:"%Hz%mz")
					ope21a.trans_status$="E"
					ope21a.qty_ordered=optFillmntLsDet.qty_shipped
					ope21a.qty_shipped=optFillmntLsDet.qty_picked
					ope21a.unit_cost=optFillmntLsDet.unit_cost
					ope21a$=field(ope21a$)
					writerecord(ope21_dev)ope21a$
				wend
			else
				ope21_dev = fnget_dev("OPE_ORDLSDET")
				dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
				status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
				ar_type$=callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
				ope21_trip$=firm_id$+status$+ar_type$+customer_id$+order_no$+old_inv_no$
				read (ope21_dev, key=ope21_trip$,knum="AO_STAT_CUST_ORD",dom=*next)
				while 1
					ope21_key$=key(ope21_dev,end=*break)
					if pos(ope21_trip$=ope21_key$)<>1 then break
					extractrecord(ope21_dev)ope21a$; rem Advisory locking
					rem --- Remove ope_ordlsdet ope-21 records that don't have matching ope_invdet ope-11 records.
					if pos(ope21a.orddet_seq_ref$+";"=skipNewOpe21Records$)=0 then
						ope21a.ar_inv_no$=inv_no$
						ope21a.mod_user$=sysinfo.user_id$
						ope21a.mod_date$=date(0:"%Yd%Mz%Dz")
						ope21a.mod_time$=date(0:"%Hz%mz")
						ope21a$=field(ope21a$)
						writerecord(ope21_dev)ope21a$
					endif
					ope21_primary$=ope21a.firm_id$+ope21a.ar_type$+ope21a.customer_id$+ope21a.order_no$+old_inv_no$+ope21a.orddet_seq_ref$+ope21a.sequence_no$
					remove(ope21_dev,key=ope21_primary$)
					read(ope21_dev,key=ope21_key$,dom=*next)
				wend
			endif

			rem --- Replace ope_invhdr ope-01 record
			ope01_dev = fnget_dev("OPE_INVHDR")
			dim ope01a$:fnget_tpl$("OPE_INVHDR")
			ordhdr_found=0
			ope01_key$=firm_id$+status$+ar_type$+customer_id$+order_no$+old_inv_no$
			extractrecord(ope01_dev,key=ope01_key$,knum="AO_STATUS",dom=*next)ope01a$; ordhdr_found=1; rem Advisory locking
			if ordhdr_found then
				if didFulfillment then
					rem --- Use Fulfillment and Carton header info
					freight_amt=0
					optCartHdr_dev = fnget_dev("OPT_CARTHDR")
					dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
					optCartHdr_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+old_inv_no$
					read(optCartHdr_dev,key=optCartHdr_trip$,knum="AO_STATUS",dom=*next)
					while 1
						optCartHdr_key$=key(optCartHdr_dev,end=*break)
						if pos(optCartHdr_trip$=optCartHdr_key$)<>1 then break
						readrecord(optCartHdr_dev)optCartHdr$
						freight_amt=freight_amt+optCartHdr.freight_amt
					wend

					ope01a.shipmnt_date$=optFillmntHdr.shipmnt_date$
					ope01a.ar_ship_via$=optFillmntHdr.ar_ship_via$
					ope01a.shipping_id$=optFillmntHdr.shipping_id$
					ope01a.freight_amt=freight_amt
					rem --- Also setColumnData since cannot use get_disk_rec with sales tax service
					callpoint!.setColumnData("OPE_INVHDR.SHIPMNT_DATE",ope01a.shipmnt_date$,1)
					callpoint!.setColumnData("OPE_INVHDR.AR_SHIP_VIA",ope01a.ar_ship_via$,1)
					callpoint!.setColumnData("OPE_INVHDR.SHIPPING_ID",ope01a.shipping_id$,1)
					callpoint!.setColumnData("OPE_INVHDR.FREIGHT_AMT",str(ope01a.freight_amt),1)
				endif
				ope01a.ar_inv_no$=inv_no$
				ope01a.ordinv_flag$="I"
				ope01a.invoice_date$=sysinfo.system_date$
				ope01a.print_status$="N"
				ope01a.lock_status$="N"
				ope01a.mod_user$=sysinfo.user_id$
				ope01a.mod_date$=date(0:"%Yd%Mz%Dz")
				ope01a.mod_time$=date(0:"%Hz%mz")
				rem --- Also setColumnData since cannot use get_disk_rec with sales tax service
				callpoint!.setColumnData("OPE_INVHDR.AR_INV_NO",ope01a.ar_inv_no$,1)
				callpoint!.setColumnData("OPE_INVHDR.ORDINV_FLAG",ope01a.ordinv_flag$,1)
				callpoint!.setColumnData("OPE_INVHDR.INVOICE_DATE",ope01a.invoice_date$,1)
				callpoint!.setColumnData("OPE_INVHDR.PRINT_STATUS",ope01a.print_status$,1)
				callpoint!.setColumnData("OPE_INVHDR.LOCK_STATUS",ope01a.lock_status$,1)
				callpoint!.setColumnData("OPE_INVHDR.MOD_USER",ope01a.mod_user$,1)
				callpoint!.setColumnData("OPE_INVHDR.MOD_DATE",ope01a.mod_date$,1)
				callpoint!.setColumnData("OPE_INVHDR.MOD_TIME",ope01a.mod_time$,1)

				rem --- Do NOT overwrite existing FREIGH_AMT previously entered in Order Entry.
				if !didFulfillment and ope01a.freight_amt=0 then
					rem --- Initialize FREIGHT_AMT when freight charges are available in OPT_SHIPTRACK
					trackingNos!=new java.util.HashMap()
					ar_type$=ope01a.ar_type$
					customer_id$=ope01a.customer_id$
					order_no$=ope01a.order_no$
					ship_seq_no$=callpoint!.getColumnData("OPE_INVHDR.SHIP_SEQ_NO")
					optShipTrack_dev = fnget_dev("OPT_SHIPTRACK")
					dim optShipTrack$:fnget_tpl$("OPT_SHIPTRACK")
					read(optShipTrack_dev,key=firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$,dom=*next)
					while 1
						optShipTrack_key$=key(optShipTrack_dev,end=*break)
						if pos(firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$=optShipTrack_key$)<>1 then break
						readrecord(optShipTrack_dev)optShipTrack$
						if optShipTrack.void_flag$="Y" then
							trackingNos!.remove(optShipTrack.tracking_no$)
						else
							trackingNos!.put(optShipTrack.tracking_no$,optShipTrack.cust_freight_amt)
						endif
					wend
					if trackingNos!.size()>0 then
						freight_amt=0
						trackingIter!=trackingNos!.keySet().iterator()
						while trackingIter!.hasNext()
							freight_amt=freight_amt+trackingNos!.get(trackingIter!.next())
						wend
						ope01a.freight_amt=freight_amt
						callpoint!.setColumnData("OPE_INVHDR.FREIGHT_AMT",str(ope01a.freight_amt),1)
					endif
				endif

				ope01a$=field(ope01a$)
				writerecord(ope01_dev)ope01a$
				ope01_primary$=ope01a.firm_id$+ope01a.ar_type$+ope01a.customer_id$+ope01a.order_no$+old_inv_no$
				remove(ope01_dev,key=ope01_primary$)

				if didFulfillment then
					rem --- Update TRANS_STATUS and AR_INV_NO in all 6 fulfillment tables
					optFillmntHdr_Primary_key$=firm_id$+ar_type$+customer_id$+order_no$+old_inv_no$
					trans_status$="U"
					ar_inv_no$=inv_no$
					gosub updateFulfillment

					rem --- Add to Shipment Tracking if not already there
					optShipTrack_dev = fnget_dev("OPT_SHIPTRACK")
					dim optShipTrack$:fnget_tpl$("OPT_SHIPTRACK")
					optCartHdr_dev = fnget_dev("OPT_CARTHDR")
					dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
					optCartHdr_trip$=firm_id$+"U"+ar_type$+customer_id$+order_no$+inv_no$
					read(optCartHdr_dev,key=optCartHdr_trip$,knum="AO_STATUS",dom=*next)
					while 1
						optCartHdr_key$=key(optCartHdr_dev,end=*break)
						if pos(optCartHdr_trip$=optCartHdr_key$)<>1 then break
						readrecord(optCartHdr_dev)optCartHdr$
						if cvs(optCartHdr.tracking_no$,2)="" then continue

						rem --- Is this carton already being tracked?
						alreadyTracked=0
						optShipTrack_trip$=firm_id$+ar_type$+customer_id$+order_no$
						read(optShipTrack_dev,key=optShipTrack_trip$,dom=*next)
						while 1
							optShipTrack_key$=key(optShipTrack_dev,end=*break)
							if pos(optShipTrack_trip$=optShipTrack_key$)<>1 then break
							readrecord(optShipTrack_dev)optShipTrack$
							if optShipTrack.tracking_no$<>optCartHdr.tracking_no$ then continue
							alreadyTracked=1
							break
						wend

						rem --- Enter Shipment Tracking info for cartons NOT already bein tracked
						if !alreadyTracked then
							ship_seq_no$=callpoint!.getColumnData("OPE_INVHDR.SHIP_SEQ_NO")
							if cvs(ship_seq_no$,2)="" then ship_seq_no$='001'

							redim optShipTrack$
							optShipTrack.firm_id$=firm_id$
							optShipTrack.ar_type$=ar_type$
							optShipTrack.customer_id$=customer_id$
							optShipTrack.order_no$=order_no$
							optShipTrack.ship_seq_no$=ship_seq_no$
							optShipTrack.tracking_no$=optCartHdr.tracking_no$
							optShipTrack.void_flag$="N"
							optShipTrack.scac_code$=optCartHdr.scac_code$
							optShipTrack.carrier_code$=optCartHdr.carrier_code$
							optShipTrack.create_date$=date(0:"%Yd%Mz%Dz")
							optShipTrack.weight=optCartHdr.weight
							optShipTrack.cust_freight_amt=optCartHdr.freight_amt
							optShipTrack.act_freight_amt=optCartHdr.freight_amt
							optShipTrack$=field(optShipTrack$)
							writerecord(optShipTrack_dev)optShipTrack$
						endif
					wend

				endif

				callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC","1",1)
				disc_amt=num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
				freight_amt=num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
				gosub calculate_tax
			endif

			gosub add_to_batch_print

			rem --- Load new invoice
			callpoint!.setStatus("RECORD:["+firm_id$+status$+ar_type$+customer_id$+order_no$+inv_no$+"]")
		endif
		
	endif

	return

rem ==========================================================================
get_cash: rem --- Launch the Cash Transaction form
rem ==========================================================================

	custmast_dev = fnget_dev("ARM_CUSTMAST")
	dim custmast_tpl$:fnget_tpl$("ARM_CUSTMAST")
	cust_id$=callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	find record (custmast_dev, key=firm_id$+cust_id$,dom=*next) custmast_tpl$

	callpoint!.setDevObject("tax_code",   callpoint!.getColumnData("OPE_INVHDR.TAX_CODE"))
	callpoint!.setDevObject("tax_amount",   callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"))
	callpoint!.setDevObject("freight_amt",  callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	callpoint!.setDevObject("discount_amt", callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	rem --- Init devObjects set by OPE_INVCASH in case user doesn't have access to that form
	callpoint!.setDevObject("print_invoice", "N")
	callpoint!.setDevObject("cash_code_type","")

	trans_status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")

	dim dflt_data$[5,1]
	dflt_data$[1,0]="INVOICE_DATE"
	dflt_data$[1,1]=callpoint!.getColumnData("OPE_INVHDR.INVOICE_DATE")
	dflt_data$[2,0]="AR_INV_NO"
	dflt_data$[2,1]=ar_inv_no$
	dflt_data$[3,0]="CUSTOMER_NAME"
	dflt_data$[3,1]=custmast_tpl.customer_name$
	dflt_data$[4,0]="TRANS_STATUS"
	dflt_data$[4,1]=trans_status$
	dflt_data$[5,0]="ORDER_NO"
	dflt_data$[5,1]=order_no$

	key_pfx$  = firm_id$+trans_status$+"  "+cust_id$+order_no$+ar_inv_no$

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPE_INVCASH", 
:		stbl("+USER_ID"), 
:		"", 
:		key_pfx$, 
:		table_chans$[all], 
:		"",
:		dflt_data$[all]

rem --- Update CASH_SALE flag

	if (user_tpl.cash_sale$="Y" or user_tpl.cash_cust$<>cust_id$) and callpoint!.getDevObject("cash_code_type")="" then
		callpoint!.setColumnData("OPE_INVHDR.CASH_SALE", "")
	else
		callpoint!.setColumnData("OPE_INVHDR.CASH_SALE", "Y")
	endif

rem --- Write flag to disk

	gosub get_disk_rec
	write record (ordhdr_dev) ordhdr_rec$
	ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
	extractrecord(ordhdr_dev,key=ordhdr_key$)ordhdr_rec$; rem Advisory Locking

	callpoint!.setStatus("SETORIG")
	return

rem ==========================================================================
get_disk_rec: rem --- Get disk record, update with current form data
              rem     OUT: ordhdr_rec$, updated
              rem          ordhdr_tpl$
              rem          ordhdr_dev
              rem          cust_id$
              rem          order_no$
rem ==========================================================================

	file_name$  = "OPE_INVHDR"
	ordhdr_dev  = fnget_dev(file_name$)
	ordhdr_tpl$ = fnget_tpl$(file_name$)
	dim ordhdr_rec$:ordhdr_tpl$

	trans_status$=callpoint!.getColumnData("OPE_INVHDR.TRANS_STATUS")
	cust_id$  = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")

	found = 0
	extract record (ordhdr_dev, key=firm_id$+trans_status$+"  "+cust_id$+order_no$+invoice_no$, dom=*next) ordhdr_rec$; found = 1; rem Advisory Locking

	rem --- Copy in any form data that's changed
	ordhdr_rec$ = util.copyFields(ordhdr_tpl$, callpoint!)
	ordhdr_rec$ = field(ordhdr_rec$)

	if !found then
		write record (ordhdr_dev,  dom=*endif) ordhdr_rec$
		ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
		extract record (ordhdr_dev, key=ordhdr_key$) ordhdr_rec$; rem Advisory Locking
		callpoint!.setStatus("SETORIG")
	endif

	return

rem ==========================================================================
disp_totals: rem --- Get order totals and display, save header totals
rem IN: disc_amt
rem IN: freight_amt
rem ==========================================================================

	prev_sub_tot=num(callpoint!.getColumnData("<<DISPLAY>>.SUBTOTAL"))
	prev_net_sales=num(callpoint!.getColumnData("<<DISPLAY>>.NET_SALES"))
	ttl_ext_price = num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES"))
	ttl_ext_cost = num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_COST"))
	tax_amt = num(callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"))
	sub_tot = ttl_ext_price - disc_amt
	net_sales = sub_tot + tax_amt + freight_amt

	callpoint!.setColumnData("OPE_INVHDR.TOTAL_COST",str(ttl_ext_cost),1)
	callpoint!.setColumnData("OPE_INVHDR.DISCOUNT_AMT",str(disc_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.SUBTOTAL", str(sub_tot),1)
	callpoint!.setColumnData("<<DISPLAY>>.NET_SALES", str(net_sales),1)
	callpoint!.setColumnData("OPE_INVHDR.FREIGHT_AMT",str(freight_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.ORDER_TOT",str(net_sales),1)

	if sub_tot<>prev_sub_tot or prev_net_sales<>net_sales then callpoint!.setStatus("MODIFIED")

	return

rem ==========================================================================
init_msgs: rem --- Clear out DevObjects for messages
rem ==========================================================================

	callpoint!.setDevObject("msg_printed","")
	callpoint!.setDevObject("msg_backorder","")
	callpoint!.setDevObject("msg_quote","")
	callpoint!.setDevObject("msg_credit_memo","")
	callpoint!.setDevObject("msg_exceeded","")
	callpoint!.setDevObject("msg_hold","")
	callpoint!.setDevObject("msg_credit_okay","")
	callpoint!.setDevObject("msg_released","")

	return

rem ==========================================================================
calculate_tax: rem --- Calculate and display Tax Amount
rem IN: disc_amt
rem IN: freight_amt
rem ==========================================================================

	rem --- Do sales tax calculation?
	rem --- Always do calculation if for Recalculate Tax additional option AOPT-RTAX
	rem --- Do calculation if previously skipped or failed, and on Totals tab or from BWAR.

	eventFrom$=callpoint!.getCallpointEvent()
	gosub isTotalsTab

	rem - See if we're using a tax service
	tax_code$=callpoint!.getColumnData("OPE_INVHDR.TAX_CODE")
	gosub usingTaxService

	if eventFrom$="OPE_INVHDR.AOPT-RTAX" or (num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))=1 and 
:		(isTotalsTab or pos(eventFrom$="OPE_INVHDR.ADIS:OPE_INVHDR.BWAR:OPE_INVHDR.AOPT-CASH:OPE_INVHDR.AOPT-PRNT")))

		rem --- Get current form data for tax calculation
		ordhdr_dev=fnget_dev("OPE_INVHDR")
		ordhdr_tpl$=fnget_tpl$("OPE_INVHDR")
		dim ordhdr_rec$:ordhdr_tpl$
		ordhdr_rec$ = util.copyFields(ordhdr_tpl$, callpoint!)
		ordhdr_rec$ = field(ordhdr_rec$)
		ordhdr_rec.discount_amt=disc_amt
		ordhdr_rec.freight_amt=freight_amt

		if callpoint!.getDevObject("use_tax_service")="Y" then
			rem --- Use sales tax service
			salesTax!=callpoint!.getDevObject("salesTaxObject")
			success=0
			taxProps!=salesTax!.calculateTax(ordhdr_rec$,"SalesInvoice",err=*next); success=1
			if !success then
				rem --- Sales tax calculation failed
				callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT","0",1)
				callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1),1)

				taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
				taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
				taxAmount_warn!.setVisible(1)
				taxAmount_fnote!.setVisible(1)

				msg_id$="OP_TAX_CALC_FAILED"
				dim msg_tokens$[1]
				msg_tokens$[1] = Translate!.getTranslation("AON_INVOICE")
				gosub disp_message
			else
				callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT",taxProps!.getProperty("tax_amount"),1)
				callpoint!.setColumnData("OPE_INVHDR.TAXABLE_AMT",taxProps!.getProperty("taxable_amt"),1)
				callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(0),1)
				callpoint!.setDevObject("commit_sls_tax","Y")

				taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
				taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
				taxAmount_warn!.setVisible(0)
				taxAmount_fnote!.setVisible(0)

				rem --- Force write if not in Edit mode.
				if !callpoint!.isEditMode() then gosub forceWrite
			endif
		else
			if cvs(callpoint!.getColumnData("OPE_INVHDR.TAX_CODE"),2) <> "" then
				ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
				ordHelp!.setTaxCode(callpoint!.getColumnData("OPE_INVHDR.TAX_CODE"))
				taxable_sales = num(ordHelp!.getTaxableSales())
				taxAndTaxableVect! = ordHelp!.calculateTax(disc_amt, freight_amt,taxable_sales,
:					num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES")))

				tax_amount = taxAndTaxableVect!.getItem(0)
				taxable_amt = taxAndTaxableVect!.getItem(1)

				callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT",str(tax_amount),1)
				callpoint!.setColumnData("OPE_INVHDR.TAXABLE_AMT",str(taxable_amt),1)
				callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(0),1)
				callpoint!.setDevObject("commit_sls_tax","Y")

				taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
				taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
				taxAmount_warn!.setVisible(0)
				taxAmount_fnote!.setVisible(0)

				rem --- Force write if not in Edit mode.
				if !callpoint!.isEditMode() then gosub forceWrite
			endif
		endif

		rem --- Refresh totals
		gosub disp_totals
	else
		rem --- Sales tax calculation has been deferred
		if !isTotalsTab and pos(eventFrom$="OPE_INVHDR.ADIS:OPE_INVHDR.BWAR:OPE_INVHDR.AOPT-CASH:OPE_INVHDR.AOPT-PRNT")=0 then
			callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1),1)
		endif
	endif
	callpoint!.setStatus("REFRESH")

	return

rem ==========================================================================
check_shipto: rem --- Check Ship-to's
rem IN: shipto_type$
rem IN: shipto_no$
rem IN: ship_addr$
rem ==========================================================================

	user_tpl.shipto_warned = 0
	if shipto_type$ = "S" and cvs(shipto_no$, 2) = "" then
		msg_id$ = "OP_SHIPTO_NO_MISSING"
		gosub disp_message
		user_tpl.shipto_warned = 1
	endif

	if shipto_type$ = "M" and cvs(ship_addr$, 2) = "" then
		rem --- Don't warn if cash customer
		if user_tpl.cash_sale$<>"Y" or callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID") <> user_tpl.cash_cust$
			msg_id$ = "OP_MAN_SHIPTO_NEEDED"
			gosub disp_message
			user_tpl.shipto_warned = 1
		endif
	endif

	if user_tpl.shipto_warned
		shiptoType!=callpoint!.getControl("OPE_INVHDR.SHIPTO_TYPE")
		shiptoType_ctx=shiptoType!.getContextID()
		sysgui!.setContext(shiptoType_ctx)
		callpoint!.setFocus("OPE_INVHDR.SHIPTO_TYPE")
	endif
		
	return


rem ==========================================================================
check_cash_due: rem --- Check ope_invcash balance due
rem OUT: cash_due
rem ==========================================================================

	cash_due=1
	cashrct_dev = fnget_dev("OPE_INVCASH")
	dim cashrct$:fnget_tpl$("OPE_INVCASH")
	ar_type$  = callpoint!.getColumnData("OPE_INVHDR.AR_TYPE")
	cust$     = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	ord$      = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	invoice$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")

	readrecord (cashrct_dev, key=firm_id$+ar_type$+cust$+ord$+invoice$, err=*next)cashrct$
	if cvs(cashrct.customer_id$,2)<>"" and cashrct.trans_status$="E" then
		if cashrct.tendered_amt>=cashrct.invoice_amt then cash_due=0
	endif

	return

rem ==========================================================================
able_cash_sale: rem --- Enable/Disable Cash Sale button
rem ==========================================================================

	idx=form!.getControl(num(stbl("+TAB_CTL"))).getSelectedIndex()
	if user_tpl.cash_sale$="Y" and idx=2 and callpoint!.isEditMode() then
		rem --- enable Cash Sale button when on Totals tab
		callpoint!.setOptionEnabled("CASH",1)
	else
		rem --- disable Cash Sale button when not on Totals tab
		callpoint!.setOptionEnabled("CASH",0)
	endif

	return

rem ==========================================================================
disable_shipto: rem --- Disable Ship To fields
rem IN: ship_to_type$
rem ==========================================================================

	declare BBjVector column!
	column! = BBjAPI().makeVector()
	
	column!.addItem("OPE_INVHDR.SHIPTO_NO")
	if ship_to_type$="S"
		status = 1
	else
		status = 0
	endif
	callpoint!.setColumnEnabled(column!, status)
	callpoint!.setDevObject("abort_shipto_no",0)

	column!.clear()
	column!.addItem("<<DISPLAY>>.SNAME")
	column!.addItem("<<DISPLAY>>.SADD1")
	column!.addItem("<<DISPLAY>>.SADD2")
	column!.addItem("<<DISPLAY>>.SADD3")
	column!.addItem("<<DISPLAY>>.SADD4")
	column!.addItem("<<DISPLAY>>.SCITY")
	column!.addItem("<<DISPLAY>>.SSTATE")
	column!.addItem("<<DISPLAY>>.SZIP")
	column!.addItem("<<DISPLAY>>.SCNTRY_ID")

	if ship_to_type$="M"
		status = 1
	else
		status = 0
	endif

	callpoint!.setColumnEnabled(column!, status)
	callpoint!.setOptionEnabled("SHP2",status)

	return

rem ==========================================================================
isTotalsTab: rem --- determine if the Totals tab has focus
rem OUT: isTotalsTab
rem ==========================================================================
	isTotalsTab=0
	formCtrls!=Form!.getAllControls()
	for i=0 to formCtrls!.size()-1
		thisCtrl!=formCtrls!.getItem(i)
		if thisCtrl!.getControlType() = SysGUI!.TAB_CONTROL then
			if thisCtrl!.getSelectedIndex() = thisCtrl!.getNumTabs()-1 then isTotalsTab=1; rem --- Last tab is the Totals tab
			break
		endif
	next i
	return

rem ==========================================================================
forceWrite: rem --- Force write if not in Edit mode.
rem IN: firm_id$
rem IN: customer_id$
rem IN: order_no$
rem IN: ar_inv_no$
rem IN: ordhdr_dev
rem IN: ordhdr_rec$ from earlier util.copyFields(ordhdr_tpl$, callpoint!)
rem ==========================================================================

	rem --- Force write if not in Edit mode.
	if !callpoint!.isEditMode() then
		rem --- Add Barista soft lock for this record if there isn't one already
		lock_table$="OPT_INVHDR"
		lock_record$=firm_id$+"E"+"  "+customer_id$+order_no$+ar_inv_no$
		lock_type$="C"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		if lock_status$="" then
			rem --- Add temporary soft lock
			lock_type$="L"
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$

			rem --- Update ordhdr_rec$ from earlier get_disk_rec, then write it to disk
			ordhdr_rec.tax_amount$=callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT")
			ordhdr_rec.taxable_amt$=callpoint!.getColumnData("OPE_INVHDR.TAXABLE_AMT")
			ordhdr_rec.no_sls_tax_calc=num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))
			write record (ordhdr_dev) ordhdr_rec$
			callpoint!.setStatus("SETORIG")

			rem --- Remove temporary soft lock
			lock_type$="U"
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		else
			rem --- Record locked by someone else
			callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT","0")
			callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1))

			taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
			taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
			taxAmount_fnote!.setVisible(1)
			gosub isTotalsTab
			if isTotalsTab then
				taxAmount_warn!.setVisible(1)
			else
				taxAmount_warn!.setVisible(0)
			endif

			msg_id$="ENTRY_REC_LOCKED"
			gosub disp_message
		endif
	endif

	return

rem ==========================================================================
overrideSalesTax: rem --- Allow overriding failed or deferred sales tax calculation
rem OUT: abort
rem ==========================================================================
	abort=0

	rem --- Make sure sales TAX_AMOUNT is current
	disc_amt=num(callpoint!.getColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	freight_amt=num(callpoint!.getColumnData("OPE_INVHDR.FREIGHT_AMT"))
	gosub calculate_tax
	startTaxAmount=num(callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"))

	rem --- Warn about failed or deferred sales tax calculation
	if num(callpoint!.getColumnData("OPE_INVHDR.NO_SLS_TAX_CALC"))=1 then
		rem --- Update OPE_PRNTLIST.NO_SLS_TAX_CALC for failed sales tax calculation
		order_no$=callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
		gosub add_to_batch_print

		msg_id$="GENERIC_WARN_CANCEL"
		dim msg_tokens$[1]
		msg_tokens$[1]=Translate!.getTranslation("AON_TAX_AMT_FNOTE")
		gosub disp_message
		if msg_opt$<>"O" then
			abort=1
			return
		endif

		rem --- Calculate Tax Amount using Tax Code's Tax Rate
		if cvs(callpoint!.getColumnData("OPE_INVHDR.TAX_CODE"),2) <> ""
			ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
			ordHelp!.setTaxCode(callpoint!.getColumnData("OPE_INVHDR.TAX_CODE"))
			taxable_sales = ordHelp!.getTaxableSales()
			taxAndTaxableVect! = ordHelp!.calculateTax(disc_amt, freight_amt,
:											taxable_sales,
:											num(callpoint!.getColumnData("OPE_INVHDR.TOTAL_SALES")))

			tax_amount = taxAndTaxableVect!.getItem(0)
			taxable_amt = taxAndTaxableVect!.getItem(1)

			callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT",str(tax_amount),1)
			callpoint!.setColumnData("OPE_INVHDR.TAXABLE_AMT",str(taxable_amt),1)
			callpoint!.setDevObject("altSlsTaxCal",str(tax_amount))

			rem --- Refresh totals
			gosub disp_totals
			callpoint!.setStatus("REFRESH")
		endif

		rem --- Let sales tax service users change the TAX_AMOUNT
		if callpoint!.getDevObject("use_tax_service")="Y" then
			user_id$=stbl("+USER_ID")
			dim dflt_data$[1,1]
			dflt_data$[1,0]="TAX_AMOUNT"
			dflt_data$[1,1]=str(tax_amount)
 
			call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPE_ALTSLSTAXCAL",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]

			rem --- How did form end?
			if callpoint!.getDevObject("altSlsTaxCal_end")="BEND" then
				rem --- User did Close (Ctrl+F4)
				abort=1
				return
			endif
		else
			rem --- Not using a sales tax service, and Tax Amount has been calculated using Tax Code's Tax Rate
			callpoint!.setColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(0),1)
		endif

		altSlsTaxCal=num(callpoint!.getDevObject("altSlsTaxCal"))
		if altSlsTaxCal<>startTaxAmount
			tax_amount=altSlsTaxCal
			callpoint!.setColumnData("OPE_INVHDR.TAX_AMOUNT",str(tax_amount),1)
			gosub disp_totals
			callpoint!.setStatus("REFRESH")

			rem --- Show Totals tab changes now
			taxAmount!=callpoint!.getControl("OPE_INVHDR.TAX_AMOUNT")
			taxAmount!.setText(cvs(callpoint!.getColumnData("OPE_INVHDR.TAX_AMOUNT"),2))
			netSales!=callpoint!.getControl("<<DISPLAY>>.NET_SALES")
			netSales!.setText(cvs(callpoint!.getColumnData("<<DISPLAY>>.NET_SALES"),2))
		endif

		rem --- Attempt to void any previously successful sales tax service transaction for this invoice
		if callpoint!.getDevObject("use_tax_service")="Y" then
			ar_inv_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
			salesTax!=callpoint!.getDevObject("salesTaxObject")
			if cvs(callpoint!.getColumnData("OPE_INVHDR.CREDIT_INVOICE"),2)="" then
				transType$="SalesInvoice"
			else
				transType$="ReturnInvoice"
			endif
			salesTax!.voidTransaction(customer_id$, order_no$, ar_inv_no$, transType$, err=*next)
		endif
	endif

	return

rem ==========================================================================
usingTaxService: rem ---  Using a sales tax service?
rem IN: tax_code$
rem ==========================================================================

	use_tax_service$="N"
	if callpoint!.getDevObject("sls_tax_intrface")<>"" then
		opc_taxcode_dev = fnget_dev("OPC_TAXCODE")
		dim opc_taxcode$:fnget_tpl$("OPC_TAXCODE")
		findrecord(opc_taxcode_dev,key=firm_id$+tax_code$,dom=*next)opc_taxcode$
		if opc_taxcode.use_tax_service then use_tax_service$="Y"
	endif
	callpoint!.setDevObject("use_tax_service",use_tax_service$)

	return

rem ==========================================================================
write_address_file: rem ---  Write Order Addresses file
rem IN: - none -
rem OUT: - none -
rem ==========================================================================
	cust_id$    = callpoint!.getColumnData("OPE_INVHDR.CUSTOMER_ID")
	order_no$   = callpoint!.getColumnData("OPE_INVHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_INVHDR.AR_INV_NO")
	ordship_dev = fnget_dev("OPE_ORDSHIP")

	rem --- Capture bill-to address
	dim ordship_tpl$:fnget_tpl$("OPE_ORDSHIP")
	extract record (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"B", dom=*next) ordship_tpl$; rem Advisory Locking
	ordship_tpl.firm_id$     = firm_id$
	ordship_tpl.customer_id$ = cust_id$
	ordship_tpl.order_no$    = order_no$
	ordship_tpl.ar_inv_no$ = invoice_no$
	ordship_tpl.address_type$ = "B"
	ordship_tpl.name$        = ""
	ordship_tpl.addr_line_1$ = callpoint!.getColumnData("<<DISPLAY>>.BADD1")
	ordship_tpl.addr_line_2$ = callpoint!.getColumnData("<<DISPLAY>>.BADD2")
	ordship_tpl.addr_line_3$ = callpoint!.getColumnData("<<DISPLAY>>.BADD3")
	ordship_tpl.addr_line_4$ = callpoint!.getColumnData("<<DISPLAY>>.BADD4")
	ordship_tpl.city$        = callpoint!.getColumnData("<<DISPLAY>>.BCITY")
	ordship_tpl.state_code$  = callpoint!.getColumnData("<<DISPLAY>>.BSTATE")
	ordship_tpl.zip_code$    = callpoint!.getColumnData("<<DISPLAY>>.BZIP")
	ordship_tpl.cntry_id$    = callpoint!.getColumnData("<<DISPLAY>>.BCNTRY_ID")
	ordship_tpl.created_user$   = sysinfo.user_id$
	ordship_tpl.created_date$   = date(0:"%Yd%Mz%Dz")
	ordship_tpl.created_time$   = date(0:"%Hz%mz")
	ordship_tpl.mod_user$   = ""
	ordship_tpl.mod_date$   = ""
	ordship_tpl.mod_time$   = ""
	ordship_tpl.trans_status$   = "E"
	ordship_tpl.arc_user$   = ""
	ordship_tpl.arc_date$   = ""
	ordship_tpl.arc_time$   = ""
	ordship_tpl.batch_no$   = ""
	ordship_tpl.audit_number   = 0
	ordship_tpl$ = field(ordship_tpl$)
	write record (ordship_dev) ordship_tpl$
	
	if callpoint!.getColumnData("OPE_INVHDR.SHIPTO_TYPE") = "B" then 
		rem --- Ship-to address is the same as the bill-to address
		extract record (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*next) ordship_tpl$; rem Advisory Locking
		ordship_tpl.address_type$ = "S"
		ordship_tpl.name$ = Translate!.getTranslation("AON_SAME")
		ordship_tpl$ = field(ordship_tpl$)
		ordship_tpl.created_user$   = sysinfo.user_id$
		ordship_tpl.created_date$   = date(0:"%Yd%Mz%Dz")
		ordship_tpl.created_time$   = date(0:"%Hz%mz")
		ordship_tpl.mod_user$   = ""
		ordship_tpl.mod_date$   = ""
		ordship_tpl.mod_time$   = ""
		ordship_tpl.trans_status$   = "E"
		ordship_tpl.arc_user$   = ""
		ordship_tpl.arc_date$   = ""
		ordship_tpl.arc_time$   = ""
		ordship_tpl.batch_no$   = ""
		ordship_tpl.audit_number   = 0
		write record (ordship_dev) ordship_tpl$
	else
		rem --- Capture ship-to, or manual ship-to address
		extract record (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*next) ordship_tpl$; rem Advisory Locking
		ordship_tpl.address_type$ = "S"
		ordship_tpl.name$        = callpoint!.getColumnData("<<DISPLAY>>.SNAME")
		ordship_tpl.addr_line_1$ = callpoint!.getColumnData("<<DISPLAY>>.SADD1")
		ordship_tpl.addr_line_2$ = callpoint!.getColumnData("<<DISPLAY>>.SADD2")
		ordship_tpl.addr_line_3$ = callpoint!.getColumnData("<<DISPLAY>>.SADD3")
		ordship_tpl.addr_line_4$ = callpoint!.getColumnData("<<DISPLAY>>.SADD4")
		ordship_tpl.city$        = callpoint!.getColumnData("<<DISPLAY>>.SCITY")
		ordship_tpl.state_code$  = callpoint!.getColumnData("<<DISPLAY>>.SSTATE")
		ordship_tpl.zip_code$    = callpoint!.getColumnData("<<DISPLAY>>.SZIP")
		ordship_tpl.cntry_id$    = callpoint!.getColumnData("<<DISPLAY>>.SCNTRY_ID")
		ordship_tpl.created_user$   = sysinfo.user_id$
		ordship_tpl.created_date$   = date(0:"%Yd%Mz%Dz")
		ordship_tpl.created_time$   = date(0:"%Hz%mz")
		ordship_tpl.mod_user$   = ""
		ordship_tpl.mod_date$   = ""
		ordship_tpl.mod_time$   = ""
		ordship_tpl.trans_status$   = "E"
		ordship_tpl.arc_user$   = ""
		ordship_tpl.arc_date$   = ""
		ordship_tpl.arc_time$   = ""
		ordship_tpl.batch_no$   = ""
		ordship_tpl.audit_number   = 0
		ordship_tpl$ = field(ordship_tpl$)
		write record (ordship_dev) ordship_tpl$
	endif

	return

rem ==========================================================================
updateFulfillment: rem ---  Update TRANS_STATUS and AR_INV_NO in all 6 fulfillment tables
rem IN: optFillmntHdr_Primary_key$
rem IN: trans_status$
rem IN: ar_inv_no$
rem OUT: - none -
rem ==========================================================================
	rem --- OPT_CARTLSDET
	optCartLsDet_dev = fnget_dev("OPT_CARTLSDET")
	dim optCartLsDet$:fnget_tpl$("OPT_CARTLSDET")
	optCartLsDet_trip$=optFillmntHdr_Primary_key$
	read(optCartLsDet_dev,key=optCartLsDet_trip$,knum="PRIMARY",dom=*next)
	while 1
		optCartLsDet_key$=key(optCartLsDet_dev,end=*break)
		if pos(optCartLsDet_trip$=optCartLsDet_key$)<>1 then break
		readrecord(optCartLsDet_dev)optCartLsDet$
		optCartLsDet.ar_inv_no$=ar_inv_no$
		optCartLsDet.trans_status$=trans_status$
		optCartLsDet.mod_user$=sysinfo.user_id$
		optCartLsDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optCartLsDet.mod_time$=date(0:"%Hz%mz")
		optCartLsDet$=field(optCartLsDet$)
		writerecord(optCartLsDet_dev)optCartLsDet$
		remove(optCartLsDet_dev,key=optCartLsDet_key$)
	wend

	rem --- OPT_FILLMNTLSDET
	optFillmntLsDet_dev = fnget_dev("OPT_FILLMNTLSDET")
	dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
	optFillmntLsDet_trip$=optFillmntHdr_Primary_key$
	read(optFillmntLsDet_dev,key=optFillmntLsDet_trip$,knum="PRIMARY",dom=*next)
	while 1
		optFillmntLsDet_key$=key(optFillmntLsDet_dev,end=*break)
		if pos(optFillmntLsDet_trip$=optFillmntLsDet_key$)<>1 then break
		readrecord(optFillmntLsDet_dev)optFillmntLsDet$
		optFillmntLsDet.ar_inv_no$=ar_inv_no$
		optFillmntLsDet.trans_status$=trans_status$
		optFillmntLsDet.mod_user$=sysinfo.user_id$
		optFillmntLsDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optFillmntLsDet.mod_time$=date(0:"%Hz%mz")
		optFillmntLsDet$=field(optFillmntLsDet$)
		writerecord(optFillmntLsDet_dev)optFillmntLsDet$
		remove(optFillmntLsDet_dev,key=optFillmntLsDet_key$)
	wend

	rem --- OPT_CARTDET
	optCartDet_dev = fnget_dev("OPT_CARTDET")
	dim optCartDet$:fnget_tpl$("OPT_CARTDET")
	optCartDet_trip$=optFillmntHdr_Primary_key$
	read(optCartDet_dev,key=optCartDet_trip$,knum="PRIMARY",dom=*next)
	while 1
		optCartDet_key$=key(optCartDet_dev,end=*break)
		if pos(optCartDet_trip$=optCartDet_key$)<>1 then break
		readrecord(optCartDet_dev)optCartDet$
		optCartDet.ar_inv_no$=ar_inv_no$
		optCartDet.trans_status$=trans_status$
		optCartDet.mod_user$=sysinfo.user_id$
		optCartDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optCartDet.mod_time$=date(0:"%Hz%mz")
		optCartDet$=field(optCartDet$)
		writerecord(optCartDet_dev)optCartDet$
		remove(optCartDet_dev,key=optCartDet_key$)
	wend

	rem --- OPT_FILLMNTDET
	optFillmntDet_dev = fnget_dev("OPT_FILLMNTDET")
	dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
	optFillmntDet_trip$=optFillmntHdr_Primary_key$
	read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="PRIMARY",dom=*next)
	while 1
		optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
		if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
		readrecord(optFillmntDet_dev)optFillmntDet$
		optFillmntDet.ar_inv_no$=ar_inv_no$
		optFillmntDet.trans_status$=trans_status$
		optFillmntDet.mod_user$=sysinfo.user_id$
		optFillmntDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optFillmntDet.mod_time$=date(0:"%Hz%mz")
		optFillmntDet$=field(optFillmntDet$)
		writerecord(optFillmntDet_dev)optFillmntDet$
		remove(optFillmntDet_dev,key=optFillmntDet_key$)
	wend

	rem --- OPT_CARTHDR
	optCartHdr_dev = fnget_dev("OPT_CARTHDR")
	dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
	optCartHdr_trip$=optFillmntHdr_Primary_key$
	read(optCartHdr_dev,key=optCartHdr_trip$,knum="PRIMARY",dom=*next)
	while 1
		optCartHdr_key$=key(optCartHdr_dev,end=*break)
		if pos(optCartHdr_trip$=optCartHdr_key$)<>1 then break
		readrecord(optCartHdr_dev)optCartHdr$
		optCartHdr.ar_inv_no$=ar_inv_no$
		optCartHdr.trans_status$=trans_status$
		optCartHdr.mod_user$=sysinfo.user_id$
		optCartHdr.mod_date$=date(0:"%Yd%Mz%Dz")
		optCartHdr.mod_time$=date(0:"%Hz%mz")
		optCartHdr$=field(optCartHdr$)
		writerecord(optCartHdr_dev)optCartHdr$
		remove(optCartHdr_dev,key=optCartHdr_key$)
	wend

	rem --- OPT_FILLMNTHDR
	optFillmntHdr_dev = fnget_dev("OPT_FILLMNTHDR")
	dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
	readrecord(optFillmntHdr_dev,key=optFillmntHdr_Primary_key$,knum="PRIMARY")optFillmntHdr$
	optFillmntHdr.ar_inv_no$=ar_inv_no$
	optFillmntHdr.trans_status$=trans_status$
	optFillmntHdr.mod_user$=sysinfo.user_id$
	optFillmntHdr.mod_date$=date(0:"%Yd%Mz%Dz")
	optFillmntHdr.mod_time$=date(0:"%Hz%mz")
	optFillmntHdr$=field(optFillmntHdr$)
	writerecord(optFillmntHdr_dev)optFillmntHdr$
	remove(optFillmntHdr_dev,key=optFillmntHdr_Primary_key$)

	return



