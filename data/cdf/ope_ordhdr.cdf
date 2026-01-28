[[OPE_ORDHDR.ACUS]]
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
					callpoint!.setFocus("OPE_ORDHDR.FREIGHT_AMT",1)
					if num(callpoint!.getColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC"))=1 then
						taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
						taxAmount_warn!.setVisible(1)
						if cvs(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"),2)<>"" and
:						cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),2)<>"" then
							disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
							freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
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

[[OPE_ORDHDR.ADEL]]
rem --- Remove from ope-04

	ope_prntlist_dev=fnget_dev("OPE_PRNTLIST")
	remove (ope_prntlist_dev,key=firm_id$+"O"+"  "+
:		callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")+
:		callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),dom=*next)

rem --- Set flags

	user_tpl.record_deleted = 1

rem --- clear availability

	gosub clear_avail

[[OPE_ORDHDR.ADIS]]
rem --- Finish changing customer for this order
	removeThisRecord$=callpoint!.getDevObject("RemoveThisRecord")
	callpoint!.setDevObject("RemoveThisRecord","")
	if removeThisRecord$<>"" then
		rem --- Remove order records for the previous customer
		optInvHdr_dev2=fnget_dev("2_OPT_INVHDR")
		dim previous_optInvHdr$:fnget_tpl$("OPT_INVHDR")
		findrecord(optInvHdr_dev2,key=removeThisRecord$,knum="AO_STATUS",dom=*next)previous_optInvHdr$
		previous_arType$=previous_optInvHdr.ar_type$
		previous_customerId$=previous_optInvHdr.customer_id$
		previous_orderNo$=previous_optInvHdr.order_no$
		previous_invoiceNo$=previous_optInvHdr.ar_inv_no$
		previous_orderDate$=previous_optInvHdr.order_date$
		previous_optInvHdr_key$=firm_id$+previous_arType$+previous_customerId$+previous_orderNo$+previous_invoiceNo$

		rem --- Remove OPE_ORDHDR record for the previous customer
		if cvs(previous_customerId$,2)<>"" then
			remove(optInvHdr_dev2,key=previous_optInvHdr_key$)

			rem --- Remove OPE_ORDDET records for the previous customer
			optInvDet_dev2=fnget_dev("2_OPT_INVDET")
			read(optInvDet_dev2,key=previous_optInvHdr_key$,knum="PRIMARY",dom=*next)
			while 1
				optInvDet_key2$=key(optInvDet_dev2,end=*break)
				if pos(previous_optInvHdr_key$=optInvDet_key2$)<>1 then break
				remove(optInvDet_dev2,key=optInvDet_key2$)
			wend

			rem --- Remove OPE_ORDLSDET records for the previous customer
			opeOrdLSDet_dev2=fnget_dev("2_OPE_ORDLSDET")
			read(opeOrdLSDet_dev2,key=previous_optInvHdr_key$,knum="PRIMARY",dom=*next)
			while 1
				opeOrdLSDet_key2$=key(opeOrdLSDet_dev2,end=*break)
				if pos(previous_optInvHdr_key$=opeOrdLSDet_key2$)<>1 then break
				remove(opeOrdLSDet_dev2,key=opeOrdLSDet_key2$)
			wend

			rem --- Remove OPT_INVKITDET records for the previous customer
			optInvKitDet_dev2=fnget_dev("2_OPT_INVKITDET")
			read(optInvKitDet_dev2,key=previous_optInvHdr_key$,knum="PRIMARY",dom=*next)
			while 1
				optInvKitDet_key2$=key(optInvKitDet_dev2,end=*break)
				if pos(previous_optInvHdr_key$=optInvKitDet_key2$)<>1 then break
				remove(optInvKitDet_dev2,key=optInvKitDet_key2$)
			wend

			rem --- Remove OPE_ORDSHIP record for the previous customer
			opeOrdShip_dev=fnget_dev("OPE_ORDSHIP")
			find(opeOrdShip_dev,key=opeOrdShip_key$,knum="PRIMARY", dom=*next)x$
			remove(opeOrdShip_dev,key=firm_id$+previous_customerId$+previous_orderNo$+previous_invoiceNo$+"B",dom=*next)
			remove(opeOrdShip_dev,key=firm_id$+previous_customerId$+previous_orderNo$+previous_invoiceNo$+"S",dom=*next)

			rem --- Remove OPE_PRNTLIST record for the previous customer
			opePrntList_dev=fnget_dev("OPE_PRNTLIST")
			opePrntList_key$=firm_id$+"O"+previous_arType$+previous_customerId$+previous_orderNo$
			find(opePrntList_dev,key=opePrntList_key$,knum="PRIMARY", dom=*next)x$
			remove(opePrntList_dev,key=opePrntList_key$,dom=*next)

			rem --- Remove OPE_CREDDATE record for the previous customer
			opeCredDate_dev=fnget_dev("OPE_CREDDATE")
			opeCredDate_key$=firm_id$+previous_orderDate$+previous_customerId$+previous_orderNo$
			remove(opeCredDate_dev,key=opeCredDate_key$,dom=*next)
		endif

		rem --- ADIS, Re-calculate order sales tax for the new customer
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

rem --- Check for void

	if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE") = "V" then
		msg_id$="OP_ORDINV_VOID"
		gosub disp_message
		callpoint!.setStatus("NEWREC")
		break; rem --- exit from callpoint			
	endif

rem --- Check for invoice
		
	if callpoint!.getColumnData("OPE_ORDHDR.ORDINV_FLAG") = "I" then
		msg_id$ = "OP_IS_INVOICE"
		gosub disp_message
		callpoint!.setStatus("NEWREC")
		break; rem --- exit from callpoint			
	endif		

rem --- Check locked status

	gosub check_lock_flag

	if locked=1 then 
		user_tpl.do_end_of_form = 0
		callpoint!.setStatus("NEWREC")
		break; rem --- exit callpoint
	endif

rem --- Prevent changes to an Order when it's currently in Fulfillment
	inFulfillment=0
	optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
	ar_type$  = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	customer_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	find(optFillmntHdr_dev,key=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$,knum="AO_STATUS",dom=*next); inFulfillment=1
	if inFulfillment then
		msg_id$ = "OP_IN_FILLMNTHDR"
		gosub disp_message
		user_tpl.do_end_of_form = 0
		callpoint!.setStatus("NEWREC")
		break
	endif

rem --- Reprint order?

	if callpoint!.getColumnData("OPE_ORDHDR.REPRINT_FLAG") <> "Y" then
		cust_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
		order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
		ar_type$  = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
		gosub check_if_reprintable
	else
		callpoint!.setDevObject("reprintable",1)
	endif

rem --- Show customer data

	cust_id$ = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	gosub display_customer
	gosub add_to_batch_print

	if callpoint!.getColumnData("OPE_ORDHDR.CASH_SALE") <> "Y" then 
		gosub display_aging
		gosub check_credit

		rem --- Finish changing customer for this order. Show Credit Status for the new customer.
		if removeThisRecord$<>"" then
			if user_tpl.credit_installed$ = "Y" and user_tpl.display_bal$ = "A" then
				call user_tpl.pgmdir$+"opc_creditmgmnt.aon", cust_id$, "", table_chans$[all], callpoint!, status
				callpoint!.setDevObject("credit_status_done", "Y")
				callpoint!.setStatus("ACTIVATE")
			endif
		endif
	endif

	gosub disp_cust_comments

rem --- Display Ship to information

	ship_to_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_to_no$   = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	order_no$     = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	gosub ship_to_info

rem --- Set comm percent (if calling up a B/O, it will have been cleared);rem bug 8001

	slsp$=callpoint!.getColumnData("OPE_ORDHDR.SLSPSN_CODE")
	gosub get_comm_percent

rem --- Enable buttons

	callpoint!.setOptionEnabled("PRNT",1)
	callpoint!.setOptionEnabled("RPRT",num(callpoint!.getDevObject("reprintable")))
	callpoint!.setOptionEnabled("TTLS",1)
	callpoint!.setOptionEnabled("SHPT",1)
	callpoint!.setOptionEnabled("AGNG",iff(callpoint!.getDevObject("on_demand_aging")="Y",1,0))
	if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P" then callpoint!.setOptionEnabled("OACK",1)
	callpoint!.setOptionEnabled("CUST",1)

rem --- Disable buttons
	callpoint!.setOptionEnabled("BACK",0)

rem --- Enable/disable Freight Amount
	if cvs(callpoint!.getColumnData("OPE_ORDHDR.SHIPPING_ID"),2)<>"" then
		callpoint!.setColumnEnabled("OPE_ORDHDR.FREIGHT_AMT",0)
		callpoint!.setColumnData("OPE_ORDHDR.FREIGHT_AMT",str(0),1)
	else
		callpoint!.setColumnEnabled("OPE_ORDHDR.FREIGHT_AMT",1)
	endif

rem --- Set all previous values

	user_tpl.prev_ext_cost     = num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_COST"))
	user_tpl.prev_disc_code$   = callpoint!.getColumnData("OPE_ORDHDR.DISC_CODE")
	user_tpl.prev_ship_to$     = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	user_tpl.prev_sales_total  = num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES"))

rem --- Reset default warehouse for existing order
	user_tpl.warehouse_id$ = callpoint!.getDevObject("defaultWhse")

rem --- Set codes	and flags

	user_tpl.price_code$   = callpoint!.getColumnData("OPE_ORDHDR.PRICE_CODE")
	user_tpl.pricing_code$ = callpoint!.getColumnData("OPE_ORDHDR.PRICING_CODE")
	user_tpl.order_date$   = callpoint!.getColumnData("OPE_ORDHDR.ORDER_DATE")
	user_tpl.disc_code$    = callpoint!.getColumnData("OPE_ORDHDR.DISC_CODE")
	user_tpl.new_order     = 0
	user_tpl.record_deleted = 0

rem --- Set OrderHelper object fields

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setCust_id(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"))
	ordHelp!.setOrder_no(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"))
	ordHelp!.setInv_type(callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE"))
	ordHelp!.setTaxCode(callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE"))
	print "---OrderHelper object fields set"; rem debug

rem --- Clear availability

	gosub clear_avail

rem --- Capture current totals so we can tell later if they were changed in the grid

	callpoint!.setDevObject("initial_rec_data$",rec_data$)
	callpoint!.setDevObject("discount_amt",callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	callpoint!.setDevObject("freight_amt",callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	callpoint!.setDevObject("tax_amount",callpoint!.getColumnData("OPE_ORDHDR.TAX_AMOUNT"))
	callpoint!.setDevObject("taxable_amt",callpoint!.getColumnData("OPE_ORDHDR.TAXABLE_AMT"))
	callpoint!.setDevObject("total_cost",callpoint!.getColumnData("OPE_ORDHDR.TOTAL_COST"))
	callpoint!.setDevObject("total_sales",callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES"))
	callpoint!.setDevObject("commit_sls_tax","N")

rem --- Show TAX_AMOUNT footnote warning if sales tax calculation was previously deferred
	taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
	taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
	if num(callpoint!.getColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC"))=1 then
		taxAmount_fnote!.setVisible(1)
		gosub isTotalsTab
		if isTotalsTab then taxAmount_warn!.setVisible(1)

		rem - Update sales tax calculation to use SalesInvoice for sales tax service
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	else
		taxAmount_warn!.setVisible(0)
		taxAmount_fnote!.setVisible(0)
	endif

rem --- Fix bad records with missing ordinv_flag

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDINV_FLAG"),2)="" then
		callpoint!.setColumnData("OPE_ORDHDR.ORDINV_FLAG","O")
		callpoint!.setStatus("SAVE")
	endif

rem --- Create soCreateWO! instance if needed

	op_create_wo$=callpoint!.getDevObject("op_create_wo")
	if op_create_wo$="A" then
		rem --- Clean up previous instance as necessary
		if soCreateWO!<>null() then soCreateWO!.close()

		customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
		soCreateWO!=new SalesOrderCreateWO(firm_id$,customer_id$,order_no$)

		rem --- Initialize soCreateWO! only if order NOT on Credit Hold and NOT a Quote
		if callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")<>"C" and
:		callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P" then
			soCreateWO!.initIsnWOMap(GridVect!.getItem(0))
			if soCreateWO!.woCount() then
				callpoint!.setOptionEnabled("WOLN",1)
			else
				callpoint!.setOptionEnabled("WOLN",0)
			endif

			rem --- If order was created via Duplicate Invoice, then create all possible Work Orders.
			if user_tpl.hist_ord$="Y" and callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P" then
				soCreateWO!.setCreateWO(Boolean.valueOf("true"))
				user_tpl.hist_ord$=""
			endif
		endif

		callpoint!.setDevObject("soCreateWO",soCreateWO!)
		callpoint!.setDevObject("createWOs_status","")
	endif

rem --- Disable Ship To fields

	ship_to_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	gosub disable_shipto

rem --- Using a sales tax service?
	tax_code$=callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE")
	gosub usingTaxService

rem --- Capture order records used for the Acknowledgement
	gosub getOrdAckRecs

rem --- Have ship-to or bill-to address changed?
	ordship_dev = fnget_dev("OPE_ORDSHIP")
	dim ordship_tpl$:fnget_tpl$("OPE_ORDSHIP")
	cust_id$ = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	addressChanged=0
	if callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")<>"B" then
		readrecord (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*next) ordship_tpl$
		if cvs(ordship_tpl.name$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SNAME"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_1$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD1"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_2$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD2"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_3$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD3"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_4$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD4"),2) then addressChanged=1
		if cvs(ordship_tpl.city$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SCITY"),2) then addressChanged=1
		if cvs(ordship_tpl.state_code$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SSTATE"),2) then addressChanged=1
		if cvs(ordship_tpl.zip_code$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SZIP"),2) then addressChanged=1
		if cvs(ordship_tpl.cntry_id$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SCNTRY_ID"),2) then addressChanged=1
	endif

	if addressChanged=0 then
		rem --- Ship-to address didn't change, so check the bill-to address
		redim ordship_tpl$
		readrecord (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"B", dom=*next) ordship_tpl$
		if cvs(ordship_tpl.name$,2)<> "" then addressChanged=1
		if cvs(ordship_tpl.addr_line_1$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BADD1"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_2$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BADD2"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_3$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BADD3"),2) then addressChanged=1
		if cvs(ordship_tpl.addr_line_4$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BADD4"),2) then addressChanged=1
		if cvs(ordship_tpl.city$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BCITY"),2) then addressChanged=1
		if cvs(ordship_tpl.state_code$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BSTATE"),2) then addressChanged=1
		if cvs(ordship_tpl.zip_code$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BZIP"),2) then addressChanged=1
		if cvs(ordship_tpl.cntry_id$,2)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.BCNTRY_ID"),2) then addressChanged=1
	endif

	if addressChanged then
		rem --- Write Order Addresses file
		gosub write_address_file

		rem --- Force a reprint of the Picking List
		if callpoint!.getColumnData("OPE_ORDHDR.PRINT_STATUS")<>"N" then
			order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
			gosub add_to_batch_print
			callpoint!.setColumnData("OPE_ORDHDR.REPRINT_FLAG","Y")
			callpoint!.setStatus("SAVE")

			msg_id$="OP_PICKLIST_REPRINT"
			gosub disp_message
		endif
	endif

rem --- Show static Order Type label for this Order
	gosub orderType_display

[[OPE_ORDHDR.AFMC]]
rem --- Inits

	use ::ado_util.src::util
	use ::ado_order.src::OrderHelper
	use ::adc_array.aon::ArrayObject
	use ::opo_AvaTaxInterface.aon::AvaTaxInterface
	use ::opo_SalesOrderCreateWO.aon::SalesOrderCreateWO

rem --- Create Inventory Availability window

	grid!  = util.getGrid(Form!)
	child! = util.getChild(Form!)
	cxt    = SysGUI!.getAvailableContext()

	mwin! = child!.addChildWindow(15000, 0, 10, 100, 75, "", $00000800$, cxt)
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
 	userObj!.addItem(mwin!.addStaticText(15109,695,50,160,15,"",$0000$)); rem Alt/Super (10)

rem --- Add static label warning for TAX_AMOUNT to identify it as possibly being incorrect
	tax_amount!=fnget_control!("OPE_ORDHDR.TAX_AMOUNT")
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
	order_no!=fnget_control!("OPE_ORDHDR.ORDER_NO")
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

rem --- Add static label to identify this Order as either a Sale or a Quote
	order_no!=fnget_control!("OPE_ORDHDR.ORDER_NO")
	order_no_x=order_no!.getX()
	order_no_y=order_no!.getY()
	order_no_height=order_no!.getHeight()
	order_no_width=order_no!.getWidth()
	label_width=50
	nxt_ctlID=util.getNextControlID()
	orderType_label!=Form!.addStaticText(nxt_ctlID,order_no_x+105,order_no_y+2,label_width,order_no_height-6,"")
	orderType_label!.setText("")
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	orderType_label!.setBackColor(tabCtrl!.getBackColor())
	defaultFont!=order_no!.getFont()
	boldFont!=SysGUI!.makeFont(defaultFont!.getName(),defaultFont!.getSize()+2,1)
	orderType_label!.setFont(boldFont!)
	orderType_label!.setVisible(0)
	callpoint!.setDevObject("orderType_label",orderType_label!)

	colorGreen!=SysGUI!.makeColor(0,205,0)
	callpoint!.setDevObject("colorGreen",colorGreen!)

[[OPE_ORDHDR.AOPT-AGNG]]
rem --- Update this customer's aging stats if allowed by param
	
	rem --- Skip unless current processing date is greater than last aging date
	armCustDet_dev=fnget_dev("ARM_CUSTDET")
	dim armCustDet$:fnget_tpl$("ARM_CUSTDET")
	armCustDet.firm_id$=firm_id$
	armCustDet.customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
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

[[OPE_ORDHDR.AOPT-BACK]]
rem --- Launch the Backordered Items Inquiry
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPE_ORDHDR","AO_STATUS",key_tpl$,rd_table_chans$[all],status$
	dim aoStatus_key$:key_tpl$
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPE_ORDHDR","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim primary_key$:key_tpl$

	dim filter_defs$[1,2]
	filter_defs$[0,0]="OPT_INVDET.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="OPT_INVDET.TRANS_STATUS"
	filter_defs$[1,1]="='E'"
	filter_defs$[1,2]="LOCK"

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"OP_BACKORD_ITEMS",
:		"",
:		table_chans$[all],
:		primary_key$,
:		filter_defs$[all]

rem ... Load selected order
	if cvs(primary_key$,2)<>"" then
		aoStatus_key.firm_id$=primary_key.firm_id$
		aoStatus_key.trans_status$="E"
		aoStatus_key.ar_type$=primary_key.ar_type$
		aoStatus_key.customer_id$=primary_key.customer_id$
		aoStatus_key.order_no$=primary_key.order_no$
		aoStatus_key.ar_inv_no$=primary_key.ar_inv_no$
		callpoint!.setStatus("RECORD:["+aoStatus_key$+"]")
	endif

[[OPE_ORDHDR.AOPT-CINV]]
rem --- Credit Historical Invoice

	line_sign=-1
	gosub copy_order

[[OPE_ORDHDR.AOPT-CRAT]]
rem --- Do Credit Action

	callpoint!.setDevObject("cred_action_from_print_now","")
	if callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")<>"C" then callpoint!.setDevObject("credit_action_done", "Y")

	gosub do_credit_action

	if action$ <> "U" then
		user_tpl.do_end_of_form = 0			
		if action$="D" then
			callpoint!.setStatus("NEWREC")
		else
			callpoint!.setStatus("SAVE-RECORD:[callpoint!.getRecordKey()]")
		endif
	end

[[OPE_ORDHDR.AOPT-CRCH]]
rem --- Force totalling open orders for credit status

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.forceTotalOpenOrders()

rem --- Do credit status (management)

	cust_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"); rem can be null

	print "---Credit installed: ", user_tpl.credit_installed$; rem debug
	print "---Display balance : ", user_tpl.display_bal$; rem debug

	if user_tpl.credit_installed$ = "Y" and user_tpl.display_bal$ <> "N" and cvs(cust_id$, 2) <> "" then
		print "---about to start credit management"; rem debug
		call user_tpl.pgmdir$+"opc_creditmgmnt.aon", cust_id$, order_no$, table_chans$[all], callpoint!, status
		callpoint!.setDevObject("credit_status_done", "Y")
		callpoint!.setStatus("ACTIVATE")
	endif

[[OPE_ORDHDR.AOPT-CUST]]
rem --- Launch ope_custchng form to change current customer
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	invoice_type$=callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")
	current_key$=callpoint!.getRecordKey()


	dim dflt_data$[3,1]
	dflt_data$[1,0] = "ORDER_NO"
	dflt_data$[1,1] = order_no$
	dflt_data$[2,0] = "CURR_CUSTOMER_ID"
	dflt_data$[2,1] = customer_id$
	dflt_data$[3,0] = "RECALCULATE"
	if invoice_type$="P" then
		dflt_data$[3,1] = "0"
	else
		dflt_data$[3,1] = "1"
	endif

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPE_CUSTCHNG", 
:		stbl("+USER_ID"), 
:		"", 
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

	rem --- Make sure focus returns to this form
	callpoint!.setStatus("ACTIVATE")

rem --- Handle abort from new Change Order/Quote Customer form
	if callpoint!.getDevObject("customerChange_status")="Cancel" then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Can't change Sale to a POS Default Quote Customer
	if invoice_type$="S" then
		quoteCustomer=0
		newCustomerId$=callpoint!.getDevObject("newCustomerId")
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
	endif

rem --- Can't change Quote to the Default Cash Customer
	if invoice_type$="P" then
		newCustomerId$=callpoint!.getDevObject("newCustomerId")
		if user_tpl.cash_sale$="Y" and user_tpl.cash_cust$=newCustomerId$ then
			msg_id$="OP_QUOTE_TO_CASH"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Save modified records before updating current order for the new customer
	if pos("M"=callpoint!.getRecordStatus())
		rem --- Add Barista soft lock for this record if not already in edit mode
		if !callpoint!.isEditMode() then
			rem --- Is there an existing soft lock?
			lock_table$="OPT_INVHDR"
			lock_record$=current_key$
			lock_type$="C"
			lock_status$=""
			lock_disp$=""
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
			if lock_status$="" then
				rem --- Add temporary soft lock used just for this task
				lock_type$="L"
				call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
			else
				rem --- Record locked by someone else
				msg_id$="ENTRY_REC_LOCKED"
				gosub disp_message
				break
			endif
		endif

		rem --- Get current form data and write it to disk
		gosub get_disk_rec
		write record (ordhdr_dev) ordhdr_rec$
	endif

rem --- Update and write new order records for the new customer
	optInvHdr_dev2=fnget_dev("2_OPT_INVHDR")
	dim optInvHdr$:fnget_tpl$("OPT_INVHDR")
	optInvHdrDev2_key$=firm_id$+callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")+customer_id$+order_no$+ar_inv_no$
	readrecord(optInvHdr_dev2,key=optInvHdrDev2_key$,knum="PRIMARY")optInvHdr$

	rem --- Recalculate item prices and order Discount Amount?
	recalcPriceDiscAmt=num(callpoint!.getDevObject("recalcPriceDiscAmt"))

	rem --- Update order header record new customer
	newCustomerId$=callpoint!.getDevObject("newCustomerId")
	optInvHdr.customer_id$=newCustomerId$

	rem --- Default order to new customer Bill-To Address
	optInvHdr.shipto_type$="B"
	optInvHdr.shipto_no$=""

	rem --- Zero freight amount for new customer's ship-to address
	optInvHdr.freight_amt=0

	rem --- Re-send acknowledgement for new customer
	optInvHdr.ord_conf_printed$ = "N"

	rem --- Re-print Picking List for new customer
	optInvHdr.print_status$="N"
	optInvHdr.lock_status$="N"
	optInvHdr.reprint_flag$=""

	rem --- Order not a cash sale for new customer
	optInvHdr.cash_sale$="N"

	rem --- Get needed customer records for new customer
	arm01_dev=fnget_dev("ARM_CUSTMAST")
	dim arm01a$:fnget_tpl$("ARM_CUSTMAST")
	arm02_dev=fnget_dev("ARM_CUSTDET")
	dim arm02a$:fnget_tpl$("ARM_CUSTDET")
	readrecord(arm01_dev,key=firm_id$+newCustomerId$,dom=*next)arm01a$
	readrecord(arm02_dev,key=firm_id$+newCustomerId$+callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE"),dom=*next)arm02a$

	rem --- Use new order defaults for new customer (see AVAL)
	optInvHdr.ar_ship_via$=arm01a.ar_ship_via$
	optInvHdr.shipping_id$=arm01a.shipping_id$
	optInvHdr.shipping_email$=arm01a.shipping_email$
	optInvHdr.slspsn_code$=arm02a.slspsn_code$
	optInvHdr.terms_code$=arm02a.ar_terms_code$
	optInvHdr.disc_code$=arm02a.disc_code$
	optInvHdr.ar_dist_code$=arm02a.ar_dist_code$
	optInvHdr.message_code$=arm02a.message_code$
	optInvHdr.territory$=arm02a.territory$
	optInvHdr.tax_code$=arm02a.tax_code$
	optInvHdr.pricing_code$=arm02a.pricing_code$
	optInvHdr.fob$=arm01a.fob$

rem --- Update order detail records for new customer
	round_precision = num(callpoint!.getDevObject("precision"))
	hdr_total_sales=0

	dim pc_files[6]
	pc_files[1] = fnget_dev("IVM_ITEMMAST")
	pc_files[2] = fnget_dev("IVM_ITEMWHSE")
	pc_files[3] = fnget_dev("IVM_ITEMPRIC")
	pc_files[4] = fnget_dev("IVC_PRICCODE")
	pc_files[5] = fnget_dev("ARS_PARAMS")
	pc_files[6] = fnget_dev("IVS_PARAMS")

	ivm01_dev = fnget_dev("IVM_ITEMMAST")
	dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
	ivm02_dev = fnget_dev("IVM_ITEMWHSE")
	dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")
	opc_linecode_dev = fnget_dev("OPC_LINECODE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")

	optInvDet_dev=fnget_dev("OPT_INVDET")
	optInvDet_dev2=fnget_dev("2_OPT_INVDET")
	dim optInvDet$:fnget_tpl$("OPT_INVDET")
	read(optInvDet_dev,key=optInvHdrDev2_key$,dom=*next,knum="PRIMARY")
	while 1
		readrecord(optInvDet_dev,end=*break)optInvDet$
		if pos(optInvHdrDev2_key$=optInvDet$)<>1 then break

		rem --- Update order detail record for new customer
		optInvDet.customer_id$=newCustomerId$

		rem --- Re-print Picking List for new customer
		optInvDet.pick_flag$="N"

		rem ---Update order detail pricing for new customer
		if recalcPriceDiscAmt then
			rem --- Use calculated Unit Price for new customer
			optInvDet.man_price$="N"

			redim ivm01a$
			findrecord(ivm01_dev,key=firm_id$+optInvDet.item_id$,dom=*next)ivm01a$
			redim opc_linecode$
			findrecord(opc_linecode_dev,key=firm_id$+optInvDet.line_code$,dom=*next)opc_linecode$
			if pos(opc_linecode.line_type$="SP") and optInvDet.qty_ordered<>0 then
				rem --- Do repricing (see OPE_ORDDET and OPE_ORDDET pricing subroutines)
				qty_ord=optInvDet.qty_ordered
				conv_factor=optInvDet.conv_factor
				if conv_factor=0 then conv_factor=1


				call stbl("+DIR_PGM")+"opc_pricing.aon",
:					pc_files[all],
:					firm_id$,
:					optInvDet.warehouse_id$,
:					optInvDet.item_id$,
:					user_tpl.price_code$,
:					newCustomerId$,
:					optInvHdr.order_date$,
:					optInvHdr.price_code$,
:					qty_ord*conv_factor,
:					typeflag$,
:					price,
:					disc,
:					status

				if status=0 then
					optInvDet.unit_price=price
					optInvDet.disc_percent=disc

					if disc=100 then
						redim ivm02a$
						findrecord(ivm02_dev,key=firm_id$+optInvDet.warehouse_id$+optInvDet.item_id$,dom=*next)imv02a$
						optInvDet.std_list_prc=ivm02a.cur_price
					else
						optInvDet.std_list_prc=round((price*100) / (100-disc), round_precision)
					endif

					optInvDet.ext_price=round(optInvDet.qty_shipped * price, 2)
				endif
			endif

			rem --- Update order detail taxable_amt for new customer (see OPE_ORDDET AGRE)
			if (opc_linecode.taxable_flag$ = "Y" and ( pos(opc_linecode.line_type$ = "OMN") or ivm01a.taxable_flag$ = "Y" )) or
: 			callpoint!.getDevObject("use_tax_service")="Y" then
				optInvDet.taxable_amt=optInvDet.ext_price
			endif
	
			rem --- For uncommitted "O" line type sales (not quotes), move ext_price to unit_price until committed (see OPE_ORDDET AGRE)
			if optInvHdr.invoice_type$<>"P" and optInvDet.commit_flag$="N" and opc_linecode.line_type$="O" and optInvDet.ext_price<>0 then
				optInvDet.unit_price=optInvDet.ext_price
				optInvDet.ext_price=0
				optInvDet.taxable_amt=0
			endif
		endif

		rem --- Sum total sales for order header
		hdr_total_sales=hdr_total_sales+optInvDet.ext_price

		rem --- Write order detail record for new customer
		optInvDet.mod_user$=sysinfo.user_id$
		optInvDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optInvDet.mod_time$=date(0:"%Hz%mz")
		writerecord(optInvDet_dev2)optInvDet$
	wend

	rem --- Update order total_sales for new customer (see see INVOICE_TYPE AVAL)
	optInvHdr.total_sales=hdr_total_sales

	rem --- Update order discount_amt for new customer (see DISC_CODE AVAL)
	if recalcPriceDiscAmt then
		disccode_dev = fnget_dev("OPC_DISCCODE")
		dim disccode_rec$:fnget_tpl$("OPC_DISCCODE")
		find record (disccode_dev, key=firm_id$+optInvHdr.disc_code$, dom=*next) disccode_rec$
		new_disc_amt = round(disccode_rec.disc_percent *hdr_total_sales/100, 2)
		optInvHdr.discount_amt=new_disc_amt
	endif

	rem --- Force order sales tax re-calculation for new customer
	rem --- Order taxable_amt and tax_amount are updated in ADIS when order is re-displayed for new customer
	optInvHdr.no_sls_tax_calc=1

	rem --- Write order header record for new customer
	optInvHdr.mod_user$=sysinfo.user_id$
	optInvHdr.mod_date$=date(0:"%Yd%Mz%Dz")
	optInvHdr.mod_time$=date(0:"%Hz%mz")
	writerecord(optInvHdr_dev2)optInvHdr$

	rem --- Update OPE_ORDLSDET for new customer
	ope21_dev = fnget_dev("OPE_ORDLSDET")
	ope21_dev2=fnget_dev("2_OPE_ORDLSDET")
	dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
	read (ope21_dev, key=optInvHdrDev2_key$,knum="PRIMARY",dom=*next)
	while 1
		readrecord(ope21_dev,end=*break)ope21a$
		if pos(optInvHdrDev2_key$=ope21a$)<>1 then break

		rem --- Update order lot/serial detail record for new customer
		ope21a.customer_id$=newCustomerId$

		rem --- Write order lot/serial detail record for new customer
		ope21a.mod_user$=sysinfo.user_id$
		ope21a.mod_date$=date(0:"%Yd%Mz%Dz")
		ope21a.mod_time$=date(0:"%Hz%mz")
		writerecord(ope21_dev2)ope21a$
	wend
	read(ope21_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next)

	rem --- Update OPT_INVKITDET for new customer
	optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
	optInvKitDet_dev2=fnget_dev("2_OPT_INVKITDET")
	dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
	read (optInvKitDet_dev, key=optInvHdrDev2_key$,knum="PRIMARY",dom=*next)
	while 1
		readrecord(optInvKitDet_dev,end=*break)optInvKitDet$
		if pos(optInvHdrDev2_key$=optInvKitDet$)<>1 then break

		rem --- Update order lot/serial detail record for new customer
		optInvKitDet.customer_id$=newCustomerId$

		rem --- Write order lot/serial detail record for new customer
		optInvKitDet.mod_user$=sysinfo.user_id$
		optInvKitDet.mod_date$=date(0:"%Yd%Mz%Dz")
		optInvKitDet.mod_time$=date(0:"%Hz%mz")
		writerecord(optInvKitDet_dev2)optInvKitDet$
	wend
	read(optInvKitDet_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next)

	rem --- Update OPE_PRNTLIST for new customer
	ope_prntlist_dev=fnget_dev("OPE_PRNTLIST")
	dim ope_prntlist$:fnget_tpl$("OPE_PRNTLIST")
	ope_prntlist.firm_id$=firm_id$
	ope_prntlist.ordinv_flag$="O"
	ope_prntlist.ar_type$="  "
	ope_prntlist.customer_id$=newCustomerId$
	ope_prntlist.order_no$=order_no$
	ope_prntlist.no_sls_tax_calc=1
	writerecord(ope_prntlist_dev)ope_prntlist$

rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

	rem --- Re-launch Order Entry form for the order with the new customer
	rem --- In ADIS, re-calculate order sales tax for the new customer if callpoint!.getDevObject("RemoveThisRecord") is NOT blank
	rem --- In ADIS, check the new customer's credit if callpoint!.getDevObject("RemoveThisRecord") is NOT blank
	rem --- In ADIS, remove order records for the previous customer if callpoint!.getDevObject("RemoveThisRecord") is NOT blank
	callpoint!.setDevObject("RemoveThisRecord",current_key$)
	callpoint!.setStatus("RECORD:["+firm_id$+"E"+"  "+newCustomerId$+order_no$+ar_inv_no$+"]")

[[OPE_ORDHDR.AOPT-DINV]]
rem --- Duplicate Historical Invoice

	line_sign=1
	gosub copy_order

[[OPE_ORDHDR.AOPT-OACK]]
rem --- Has the Order changed since Acknowledgement was printed?
	gosub ordChangedForAck

rem --- If Acknowledgement is currently printed and the order has changed, ask if they want it reprinted.
	if callpoint!.getColumnData("OPE_ORDHDR.ORD_CONF_PRINTED")="Y" and !orderChanged then
		msg_id$="OP_REPRINT_ACK"
		gosub disp_message
		if msg_opt$<>"Y" then break
	endif

rem --- Create Order Acknowledgement/Confirmation (for doc queue, or manually email)
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")

rem --- Make sure modified records are saved before doing Acknowledgement
	if pos("M"=callpoint!.getRecordStatus())
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

		rem --- Get current form data and write it to disk
		gosub get_disk_rec
		write record (ordhdr_dev) ordhdr_rec$
	endif

	gosub do_order_conf

rem --- Refresh form with current data on disk that might have been updated elsewhere
	callpoint!.setStatus("RECORD:["+firm_id$+"E"+"  "+customer_id$+order_no$+ar_inv_no$+"]")

rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

rem --- Capture order records used for the Acknowledgement
	gosub getOrdAckRecs

[[OPE_ORDHDR.AOPT-PRNT]]
rem --- Print Now
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")

rem --- Make sure modified records are saved before printing
	if pos("M"=callpoint!.getRecordStatus())
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

		rem --- Get current form data and write it to disk
		gosub get_disk_rec
		write record (ordhdr_dev) ordhdr_rec$
		ordhdr_key$=ordhdr_rec.firm_id$+ordhdr_rec.trans_status$+ordhdr_rec.ar_type$+ordhdr_rec.customer_id$+ordhdr_rec.order_no$+ordhdr_rec.ar_inv_no$
		extractrecord(ordhdr_dev,key=ordhdr_key$)ordhdr_rec$; rem Advisory Locking

		rem --- Do not need to callpoint!.setStatus("SETORIG") here because the
		rem --- callpoint!.setStatus("RECORD:["+ ... "]") at the end of this callpoint will do it.
	endif

rem --- Print a counter Picking Slip

	arm02_dev=fnget_dev("ARM_CUSTDET")
	dim arm02a$:fnget_tpl$("ARM_CUSTDET")
	read record (arm02_dev,key=firm_id$+customer_id$+"  ",dom=*next) arm02a$

	rem --- No need to check credit first
	if (user_tpl.credit_installed$="Y" and callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")="R") or 
: 		user_tpl.credit_installed$ <> "Y" or 
:		user_tpl.pick_hold$ = "Y"         or
:		callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE") = "P" or
:		arm02a.cred_hold$="E"
:	then
		rem --- Okay to print
		if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")="P" then
			rem --- Print Quotation
			gosub print_quote
		else
			rem --- Print Picking List
			gosub do_picklist
		endif
		user_tpl.do_end_of_form = 0
	else
		rem --- Can't print until released from credit

		callpoint!.setDevObject("cred_action_from_print_now","Y")
		gosub do_credit_action

		if pos(action$ = "XUS") or (pos(action$ = "RM") and str(callpoint!.getDevObject("document_printed")) <> "Y") then 
			rem --- Couldn't do credit action, or did credit action w/ no problem, or released from credit but didn't print
			if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")="P" then
				rem --- Print Quotation
				gosub print_quote
			else
				rem --- Print Picking List
				gosub do_picklist
			endif
			user_tpl.do_end_of_form = 0
		else
			if action$ = "R" and str(callpoint!.getDevObject("document_printed")) = "Y" then 

			rem --- Released from credit and did print

				user_tpl.do_end_of_form = 0
			else
				rem --- Not printed because there was no credit action
			endif
		endif
	endif

rem --- Refresh form with current data on disk that might have been updated elsewhere
	callpoint!.setStatus("RECORD:["+firm_id$+"E"+"  "+customer_id$+order_no$+ar_inv_no$+"]")

rem --- Remove temporary soft lock used just for this print task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[OPE_ORDHDR.AOPT-RPRT]]
rem --- Reprint Next Run
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")

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

rem --- Check for printing in next batch and set

	if user_tpl.credit_installed$="Y" and user_tpl.pick_hold$<>"Y" and
:		callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")="C"
:	then
		msg_id$ = "OP_CR_HOLD_NOPRINT"
	else
		order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
		gosub add_to_batch_print
		callpoint!.setColumnData("OPE_ORDHDR.REPRINT_FLAG","Y")
		print "---Reprint_flag set to Y"; rem debug
		callpoint!.setStatus("SAVE")
		msg_id$ = "OP_BATCH_PRINT"
	endif

	dim msg_tokens$[1]
	msg_tokens$[1] = Translate!.getTranslation("AON_ORDER")
	gosub disp_message

rem --- Remove temporary soft lock used just for this print task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[OPE_ORDHDR.AOPT-RTAX]]
rem --- Recalculate sales tax now
	disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_ORDHDR.AOPT-SHP2]]
rem --- Launch Customer Ship-To Address form
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
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
	dflt_data$[10,1] = callpoint!.getColumnData("OPE_ORDHDR.SLSPSN_CODE")
	dflt_data$[11,0] = "TERRITORY"
	dflt_data$[11,1] = callpoint!.getColumnData("OPE_ORDHDR.TERRITORY")
	dflt_data$[12,0] = "TAX_CODE"
	dflt_data$[12,1] = callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE")
	dflt_data$[13,0] = "AR_SHIP_VIA"
	dflt_data$[13,1] = callpoint!.getColumnData("OPE_ORDHDR.AR_SHIP_VIA")
	dflt_data$[14,0] = "SHIPPING_ID"
	dflt_data$[14,1] = callpoint!.getColumnData("OPE_ORDHDR.SHIPPING_ID")
	dflt_data$[15,0] = "SHIPPING_EMAIL"
	dflt_data$[15,1] = callpoint!.getColumnData("OPE_ORDHDR.SHIPPING_EMAIL")

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

[[OPE_ORDHDR.AOPT-SHPT]]
rem --- Launch Shipment Tracking maintenance grid
	ar_type$=callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ship_seq_no$=callpoint!.getColumnData("OPE_ORDHDR.SHIP_SEQ_NO")
	key_pfx$=firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"OPT_SHIPTRACK",
:       stbl("+USER_ID"),
:       "MNT",
:       key_pfx$,
:       table_chans$[all]

	rem --- Make sure focus returns to this form
	callpoint!.setStatus("ACTIVATE")

[[OPE_ORDHDR.AOPT-WOLN]]
rem --- Launch ope_createwos form to create selected work orders

	rem --- Update soCreateWO! with CURRENT detail grid line_no so ope_createwos grid sorts in the same order.
	soCreateWO!=callpoint!.getDevObject("soCreateWO")
	soCreateWO!.updateLineNo(GridVect!.getItem(0))

	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")

	dim dflt_data$[2,1]
	dflt_data$[1,0] = "CUSTOMER_ID"
	dflt_data$[1,1] = customer_id$
	dflt_data$[2,0] = "ORDER_NO"
	dflt_data$[2,1] = order_no$
	key_pfx$=firm_id$+customer_id$+order_no$

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPE_CREATEWOS", 
:		stbl("+USER_ID"), 
:		"", 
:		key_pfx$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

	rem --- Make sure focus returns to this form
	callpoint!.setStatus("ACTIVATE")

	rem --- Re-initialize soCreateWO! if ope_createwos form not Cancelled and no new warnings
	if callpoint!.getDevObject("createWOs_status")<>"Cancel" and !soCreateWO!.getWarn() then
		soCreateWO!.initIsnWOMap(GridVect!.getItem(0))
	else
		rem --- Clear ope_createwos form Cancel
		callpoint!.setDevObject("createWOs_status","")
	endif

[[OPE_ORDHDR.APFE]]
rem --- Enable buttons as appropriate

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"),2)<>""
		if user_tpl.credit_installed$="Y"
			callpoint!.setOptionEnabled("CRCH",1)
		endif
		callpoint!.setOptionEnabled("AGNG",iff(callpoint!.getDevObject("on_demand_aging")="Y",1,0))

		if cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),2)=""
			callpoint!.setOptionEnabled("DINV",1)
			callpoint!.setOptionEnabled("CINV",1)
			callpoint!.setOptionEnabled("RPRT",0)
			callpoint!.setOptionEnabled("PRNT",0)
			callpoint!.setOptionEnabled("TTLS",0)
			rem callpoint!.setOptionEnabled("CRAT",0); rem --- handled via opc_creditmsg.aon call below
			callpoint!.setOptionEnabled("WOLN",0)
			callpoint!.setOptionEnabled("SHPT",0)
			callpoint!.setOptionEnabled("RTAX",0)
			callpoint!.setOptionEnabled("OACK",0)
			callpoint!.setOptionEnabled("CUST",0)
		else
			callpoint!.setOptionEnabled("DINV",0)
			callpoint!.setOptionEnabled("CINV",0)
			callpoint!.setOptionEnabled("RPRT",num(callpoint!.getDevObject("reprintable")))
			callpoint!.setOptionEnabled("PRNT",1)
			callpoint!.setOptionEnabled("TTLS",1)
			rem callpoint!.setOptionEnabled("CRAT",1); rem --- handled via opc_creditmsg.aon call below
			callpoint!.setOptionEnabled("SHPT",1)
			callpoint!.setOptionEnabled("RTAX",1)
			if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P" then callpoint!.setOptionEnabled("OACK",1)
			callpoint!.setOptionEnabled("CUST",1)

			op_create_wo$=callpoint!.getDevObject("op_create_wo")
			if op_create_wo$="A" then
				soCreateWO!=callpoint!.getDevObject("soCreateWO")
				if soCreateWO!<>null() and soCreateWO!.woCount() then
					rem --- Enable Work Order Links button only if order NOT on Credit Hold and NOT a Quote
					if callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")<>"C" and
:					callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P" then
						callpoint!.setOptionEnabled("WOLN",1)
					endif
				else
					callpoint!.setOptionEnabled("WOLN",0)
				endif
			endif
		endif
	endif

	if !callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("CINV",0)
		callpoint!.setOptionEnabled("DINV",0)
		rem callpoint!.setOptionEnabled("CRAT",0); rem --- handled via opc_creditmsg.aon call below
		callpoint!.setOptionEnabled("PRNT",0)
		callpoint!.setOptionEnabled("RPRT",0)
		callpoint!.setOptionEnabled("RTAX",0)
		callpoint!.setOptionEnabled("OACK",0)
		callpoint!.setOptionEnabled("CUST",0)
	endif

rem --- Set Backordered text field

	call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!

rem --- Update sales tax calculation if it was previously deferred
	if num(callpoint!.getColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC"))=1 then
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

rem --- Set MODIFIED if totals were changed in the grid

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"),3)<>"" 
:	and cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),3)<>""
:	and str(callpoint!.getDevObject("discount_amt"))<>"null"
:	and str(callpoint!.getDevObject("freight_amt"))<>"null"
:	and str(callpoint!.getDevObject("tax_amount"))<>"null"
:	and str(callpoint!.getDevObject("taxable_amt"))<>"null"
:	and str(callpoint!.getDevObject("total_cost"))<>"null"
:	and str(callpoint!.getDevObject("total_sales"))<>"null" then

		if num(callpoint!.getDevObject("discount_amt"))<>num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
:		or num(callpoint!.getDevObject("freight_amt"))<>num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
:		or num(callpoint!.getDevObject("tax_amount"))<>num(callpoint!.getColumnData("OPE_ORDHDR.TAX_AMOUNT"))
:		or num(callpoint!.getDevObject("taxable_amt"))<>num(callpoint!.getColumnData("OPE_ORDHDR.TAXABLE_AMT"))
:		or num(callpoint!.getDevObject("total_cost"))<>num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_COST"))
:		or num(callpoint!.getDevObject("total_sales"))<>num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES")) then
			callpoint!.setStatus("MODIFIED")
		endif
	endif	

rem --- Update REPRINT_FLAG for workaround to Barista Bug 10297
	if callpoint!.getDevObject("ReprintFlag")="Y" and callpoint!.getColumnData("OPE_ORDHDR.PRINT_STATUS")="Y" then
		callpoint!.setColumnData("OPE_ORDHDR.REPRINT_FLAG","Y",1)
	endif

[[OPE_ORDHDR.ARAR]]
rem --- If First/Last Record was used, did it return an Order?

	if callpoint!.getDevObject("FirstLastRecord")<>null() and callpoint!.getDevObject("FirstLastRecord")<>"" then
		whichRecord$=callpoint!.getDevObject("FirstLastRecord")
		callpoint!.setDevObject("FirstLastRecord","")

		rem --- Filter on quotes, or orders, or both
		entry_filter$=callpoint!.getDevObject("entry_filter")

		invoice_type$=callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")
		if callpoint!.getColumnData("OPE_ORDHDR.ORDINV_FLAG")<>"O" or invoice_type$="V" or
:			(entry_filter$="Q" and invoice_type$<>"P") or (entry_filter$="O" and invoice_type$<>"S") then
			ope01_dev = fnget_dev("OPE_ORDHDR")
			dim ope01a$:fnget_tpl$("OPE_ORDHDR")
			status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
			ar_type$=callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
			next_key$=""

			if whichRecord$="FIRST" then
				rem --- Locate FIRST valid order to display
				while 1
					read record (ope01_dev, dir=0, end=*break) ope01a$
					if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$<>firm_id$+status$+ar_type$ then break
					if (ope01a.ordinv_flag$ = "O" and ope01a.invoice_type$ <> "V") and
:					(entry_filter$="B" or (entry_filter$="Q" and ope01a.invoice_type$="P") or (entry_filter$="O" and ope01a.invoice_type$="S")) then
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
				rem --- Locate LAST valid order to display
				while 1
					p_key$ = keyp(ope01_dev, end=*break)
					read record (ope01_dev, key=p_key$) ope01a$
					if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$<>firm_id$+status$+ar_type$ then break
					if (ope01a.ordinv_flag$ = "O" and ope01a.invoice_type$ <> "V") and
:					(entry_filter$="B" or (entry_filter$="Q" and ope01a.invoice_type$="P") or (entry_filter$="O" and ope01a.invoice_type$="S")) then
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

			rem --- Display next order
			if next_key$<>"" then
				callpoint!.setStatus("RECORD:["+next_key$+"]")
				break
			else
				if entry_filter$="Q" then
					msg_id$ = "OP_NO_OPEN_QUOTES"
				else
					msg_id$ = "OP_NO_OPEN_ORDERS"
				endif
				gosub disp_message
				callpoint!.setStatus("ABORT-NEWREC")
				break
			endif
		endif
	endif

rem --- Set data

	user_tpl.order_date$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_DATE")

	gosub isTotalsTab
	if isTotalsTab then
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
	callpoint!.setOptionEnabled("RPRT",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("TTLS",0)
	callpoint!.setOptionEnabled("WOLN",0)
	callpoint!.setOptionEnabled("SHPT",0)
	callpoint!.setOptionEnabled("RTAX",0)
	callpoint!.setOptionEnabled("AGNG",0)
	callpoint!.setOptionEnabled("OACK",0)
	callpoint!.setOptionEnabled("CUST",0)

rem --- Clear order helper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.newOrder()
	ordHelp!.setCust_id(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"))

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

	callpoint!.setDevObject("reprintable",0)
	callpoint!.setDevObject("disc_code",callpoint!.getColumnData("OPE_ORDHDR.DISC_CODE"))

	disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	gosub disp_totals

	callpoint!.setDevObject("orig_net_sales",net_sales);rem --- used when determining if over credit limit CAH

rem --- setup messages

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"),2) = "" or
:	   cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),2) = ""
		break
	endif
	gosub init_msgs
	callpoint!.setDevObject("msg_printed",callpoint!.getColumnData("PRINT_STATUS"))
	if callpoint!.getColumnData("OPE_ORDHDR.BACKORD_FLAG") = "B"
		callpoint!.setDevObject("msg_backorder","Y")
	endif
	if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")="P"
		callpoint!.setDevObject("msg_quote","Y")
	endif
	if num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES")) < 0
		callpoint!.setDevObject("msg_credit_memo","Y")
	endif
	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	over_credit_limit = ordHelp!.calcOverCreditLimit()
	if over_credit_limit = 1
		callpoint!.setDevObject("msg_exceeded","Y")
	else
		callpoint!.setDevObject("msg_credit_okay","Y")
	endif
	if callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")="C"
		callpoint!.setDevObject("msg_hold","Y")
	endif
	if callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")="R"
		callpoint!.setDevObject("msg_released","Y")
	endif

	call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!

rem --- Show OP Invoice Print Report Controls
	admRptCtlRcp=fnget_dev("ADM_RPTCTL_RCP")
	dim admRptCtlRcp$:fnget_tpl$("ADM_RPTCTL_RCP")
	admRptCtlRcp.dd_table_alias$="OPR_INVOICE"
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
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

[[OPE_ORDHDR.AREC]]
rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPE_ORDHDR.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPE_ORDHDR.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPE_ORDHDR.CREATED_TIME",date(0:"%Hz%mz"))
	callpoint!.setColumnData("OPE_ORDHDR.AUDIT_NUMBER","0")

rem --- Clear availability information
	
	gosub clear_avail
	callpoint!.setDevObject("was_on_tot_tab","N")
	callpoint!.setDevObject("details_changed","N")
	callpoint!.setDevObject("new_rec","Y")
	callpoint!.setDevObject("create_quote","S")
	callpoint!.setDevObject("initial_rec_data$",rec_data$)
	callpoint!.setDevObject("force_wolink_grid",0)
	callpoint!.setDevObject("RemoveThisRecord","")

	gosub init_msgs

rem --- Set flags

	user_tpl.record_deleted = 0

rem --- Disable Ship To fields

	ship_to_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	gosub disable_shipto

rem --- Make sure sales tax gets calculated, and hide possible leftover TAX_AMOUNT warnings
	callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(1))
	callpoint!.setDevObject("commit_sls_tax","N")
	taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
	taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
	taxAmount_fnote!.setVisible(0)
	taxAmount_warn!.setVisible(0)

rem --- Acknowledgement not printed yet for new order, so save empty HashMap if doing them on demand
	if callpoint!.getDevObject("auto_ord_conf")="Y" then
		ackRecsMap!=new java.util.HashMap()
		callpoint!.setDevObject("ackRecsMap",ackRecsMap!)
	endif

rem --- Reset default warehouse for new order
	user_tpl.warehouse_id$ = callpoint!.getDevObject("defaultWhse")

rem --- Enable Freight Amount
	callpoint!.setColumnEnabled("OPE_ORDHDR.FREIGHT_AMT",1)

rem --- Enable Backordered button
	callpoint!.setOptionEnabled("BACK",1)

rem --- Hide Order static label
	orderType_label!=callpoint!.getDevObject("orderType_label")
	orderType_label!.setVisible(0)

[[OPE_ORDHDR.AR_DIST_CODE.AVAL]]
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

[[OPE_ORDHDR.ASHO]]
rem --- Get default dates, POS station

	call stbl("+DIR_SYP")+"bam_run_prog.bbj", "OPE_ORDDATES", stbl("+USER_ID"), "MNT", "", table_chans$[all]
	user_tpl.def_ship$   = stbl("OPE_DEF_SHIP",err=*next)
	if cvs(user_tpl.def_ship$,2)="" then release
	user_tpl.def_commit$ = stbl("OPE_DEF_COMMIT")

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

[[OPE_ORDHDR.ASIZ]]
rem --- Create Empty Availability window

	grid! = util.getGrid(Form!)
	grid!.setSize(grid!.getWidth(), grid!.getHeight() - 75)

	cwin! = util.getChild(Form!).getControl(15000)
	cwin!.setLocation(cwin!.getX(), grid!.getY() + grid!.getHeight())
	cwin!.setSize(grid!.getWidth(), cwin!.getHeight())

	mwin!=cwin!.getControl(15999)
	mwin!.setSize(grid!.getWidth(), mwin!.getHeight())

rem --- Resize customer comments box (display only) to align w/ Order/Invoice Comments (memo_1024)

	cmts!=callpoint!.getControl("<<DISPLAY>>.COMMENTS")
	memo!=callpoint!.getControl("OPE_ORDHDR.MEMO_1024")
	cmts!.setSize(memo!.getWidth(),cmts!.getHeight())

[[OPE_ORDHDR.ASVA]]
rem --- Check Ship-to's

	shipto_no$  = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

[[OPE_ORDHDR.AWRI]]
rem --- Disable buttons/options
	if !callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("CINV",0)
		callpoint!.setOptionEnabled("DINV",0)
		callpoint!.setOptionEnabled("CRAT",0)
		callpoint!.setOptionEnabled("RTAX",0)
	endif

rem --- Update devObjects with current values written to file
	callpoint!.setDevObject("discount_amt",num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT")))
	callpoint!.setDevObject("freight_amt",num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT")))
	callpoint!.setDevObject("tax_amount",num(callpoint!.getColumnData("OPE_ORDHDR.TAX_AMOUNT")))
	callpoint!.setDevObject("taxable_amt",num(callpoint!.getColumnData("OPE_ORDHDR.TAXABLE_AMT")))
	callpoint!.setDevObject("total_cost",num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_COST")))
	callpoint!.setDevObject("total_sales",num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES")))

[[OPE_ORDHDR.BDEL]]
rem --- User approval required if packages have already been shipped

	trackingNos!=new java.util.HashMap()
	ar_type$=callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	ship_seq_no$=callpoint!.getColumnData("OPE_ORDHDR.SHIP_SEQ_NO")
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

rem --- Get user approval to delete if there are any WOs linked to this Sales Order

	op_create_wo$=callpoint!.getDevObject("op_create_wo")
	if op_create_wo$="A" then
		soCreateWO! = callpoint!.getDevObject("soCreateWO")
		if !soCreateWO!.unlinkWOs() then
			callpoint!.setStatus("ACTIVATE-ABORT")
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

rem --- Remove committments for detail records by calling ATAMO

	ope11_dev = fnget_dev("OPE_ORDDET")
	dim ope11a$:fnget_tpl$("OPE_ORDDET")

	opc_linecode_dev = fnget_dev("OPC_LINECODE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")

	ivs01_dev = fnget_dev("IVS_PARAMS")
	dim ivs01a$:fnget_tpl$("IVS_PARAMS")
	read record (ivs01_dev, key=firm_id$+"IV00") ivs01a$

	ope31_dev = fnget_dev("OPE_ORDSHIP")
	cashrct_dev = fnget_dev("OPE_INVCASH")
	creddate_dev = fnget_dev("OPE_CREDDATE")

	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	ar_type$  = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	cust$     = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	ord$      = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	ord_date$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_DATE")
	inv_type$ = callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")

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

[[OPE_ORDHDR.BEND]]
rem --- As necessary, handle Cancel and new warnings from ope_createwos form

	op_create_wo$=callpoint!.getDevObject("op_create_wo")
	if op_create_wo$="A" then
		soCreateWO!=callpoint!.getDevObject("soCreateWO")

		createWOs_status$=callpoint!.getDevObject("createWOs_status",err=*next)
		if createWOs_status$="Cancel" or soCreateWO!.getWarn()then
			rem --- Handle Cancel and warn the same as it must be handled in BREX
			callpoint!.setStatus("RECORD:["+firm_id$+"E"+"  "+callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")+callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")+"]")

			rem --- A new soCreateWO! instance will be created, so need to close files in this one.
			soCreateWO!.close()
		endif
	endif

rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTaxObject")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[OPE_ORDHDR.BFST]]
rem --- Set flag that First Record has been selected
	callpoint!.setDevObject("FirstLastRecord","FIRST")

[[OPE_ORDHDR.BLST]]
rem --- Set flag that Last Record has been selected
	callpoint!.setDevObject("FirstLastRecord","LAST")

[[OPE_ORDHDR.BNEK]]
rem --- Is next record an order and not void?

	file_name$ = "OPE_ORDHDR"
	ope01_dev = fnget_dev(file_name$)
	dim ope01a$:fnget_tpl$(file_name$)

rem --- Position the file at the correct record

	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	ar_type$=callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	if callpoint!.getDevObject("new_rec")="Y"
		start_key$=firm_id$+trans_status$+ar_type$
		cust_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
		if cvs(cust_id$,2)<>""
			start_key$=start_key$+cust_id$
			order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
			if cvs(order_no$,2)<>""
				start_key$=start_key$+order_no$+callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
			endif
		endif
		read (ope01_dev,key=start_key$,dom=*next)
	else
		current_key$=callpoint!.getRecordKey()
		read(ope01_dev,key=current_key$,dom=*next)
	endif

	rem --- Filter on quotes, or orders, or both
	entry_filter$=callpoint!.getDevObject("entry_filter")

	hit_eof=0
	while 1
		read record (ope01_dev, dir=0, end=eof) ope01a$

		if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$ = firm_id$+trans_status$+ar_type$ then
			if (ope01a.ordinv_flag$ = "O" and ope01a.invoice_type$ <> "V") and
:			(entry_filter$="B" or (entry_filter$="Q" and ope01a.invoice_type$="P") or (entry_filter$="O" and ope01a.invoice_type$="S")) then
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
		read (ope01_dev, key=firm_id$+trans_status$+ar_type$, dom=*next)
		hit_eof=hit_eof+1
		if hit_eof>1 then
			msg_id$ = "OP_NO_OPEN_ORDERS"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	wend

[[OPE_ORDHDR.BNEX]]
rem --- Check for Order Total

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

	if pos(callpoint!.getDevObject("totals_warn")="24")>0
		if pos(callpoint!.getDevObject("was_on_tot_tab")="N") > 0
			if callpoint!.getDevObject("details_changed")="Y" and callpoint!.getDevObject("rcpr_row")=""
				callpoint!.setMessage("OP_TOTALS_TAB")
				callpoint!.setFocus("OPE_ORDHDR.FREIGHT_AMT")
				callpoint!.setDevObject("was_on_tot_tab","Y")
				callpoint!.setStatus("ABORT-ACTIVATE")
				break
			endif
		endif
	endif

[[OPE_ORDHDR.BOVE]]
rem --- Restrict lookup to open orders and open invoices
	rem --- Filter on quotes, or orders, or both
	entry_filter$=callpoint!.getDevObject("entry_filter")

	rem bug 7564 --- cust_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	custControl!=callpoint!.getControl("OPE_ORDHDR.CUSTOMER_ID")
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
	filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")+"'"
	filter_defs$[2,2]="LOCK"
	if cvs(cust_id$, 2) <> "" then
		filter_defs$[3,0] = "OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1] = "='" + cust_id$ + "'"
		filter_defs$[3,2]="LOCK"
	endif
	filter_defs$[4,0]="OPT_INVHDR.INVOICE_TYPE"
	switch pos(entry_filter$="BOQ")
		case 1
			filter_defs$[4,1]="<>'V'"
			break
		case 2
			filter_defs$[4,1]="='S'"
			break
		case 3
			filter_defs$[4,1]="='P'"
			break
		case default
			filter_defs$[4,1]="<>'V'"
			break
	swend
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
		if cust_id$<>"" and cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),3)<>"" then
			callpoint!.setStatus("SAVE-RECORD:[" + selected_keys$(1,len(ao_status_key$)) +"]")
		else
			callpoint!.setStatus("RECORD:[" + selected_keys$(1,len(ao_status_key$)) +"]")
		endif
	else
		callpoint!.setStatus("ABORT")
	endif
	callpoint!.setStatus("ACTIVATE")

[[OPE_ORDHDR.BPFX]]
rem --- Disable header buttons

	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("CRAT",0)
	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("RPRT",0)
	callpoint!.setOptionEnabled("TTLS",0)
	callpoint!.setOptionEnabled("WOLN",0)
	callpoint!.setOptionEnabled("SHPT",0)
	callpoint!.setOptionEnabled("RTAX",0)
	callpoint!.setOptionEnabled("AGNG",0)
	callpoint!.setOptionEnabled("OACK",0)
	callpoint!.setOptionEnabled("CUST",0)

rem --- Capture current totals so we can tell later if they were changed in the grid

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"),3)<>"" and cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),3)<>""
		callpoint!.setDevObject("discount_amt",callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		callpoint!.setDevObject("freight_amt",callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		callpoint!.setDevObject("tax_amount",callpoint!.getColumnData("OPE_ORDHDR.TAX_AMOUNT"))
		callpoint!.setDevObject("taxable_amt",callpoint!.getColumnData("OPE_ORDHDR.TAXABLE_AMT"))
		callpoint!.setDevObject("total_cost",callpoint!.getColumnData("OPE_ORDHDR.TOTAL_COST"))
		callpoint!.setDevObject("total_sales",callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES"))
	endif

rem --- Initialize ReprintFlag devObject used for workaround to Barista Bug 10297
	callpoint!.setDevObject("ReprintFlag","")

[[OPE_ORDHDR.BPRI]]
rem --- Check for Order Total

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

	if pos(callpoint!.getDevObject("totals_warn")="24")>0
		if pos(callpoint!.getDevObject("was_on_tot_tab")="N") > 0
			if callpoint!.getDevObject("details_changed")="Y" and callpoint!.getDevObject("rcpr_row")=""
				callpoint!.setMessage("OP_TOTALS_TAB")
				callpoint!.setFocus("OPE_ORDHDR.FREIGHT_AMT")
				callpoint!.setDevObject("was_on_tot_tab","Y")
				callpoint!.setStatus("ABORT-ACTIVATE")
				break
			endif
		endif
	endif

[[OPE_ORDHDR.BPRK]]
rem --- Is previous record an order and not void?

	file_name$ = "OPE_ORDHDR"
	ope01_dev = fnget_dev(file_name$)
	dim ope01a$:fnget_tpl$(file_name$)

rem --- Position the file at the correct record

	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	ar_type$=callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	if callpoint!.getDevObject("new_rec")="Y"
		start_key$=firm_id$+trans_status$+ar_type$
		cust_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
		if cvs(cust_id$,2)<>""
			start_key$=start_key$+cust_id$
			order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
			if cvs(order_no$,2)<>""
				start_key$=start_key$+order_no$
			endif
		endif
		read(ope01_dev,key=start_key$,dir=0,dom=*next)
	else
		current_key$=callpoint!.getRecordKey()
		read(ope01_dev,key=current_key$,dir=0,dom=*next)
	endif

	rem --- Filter on quotes, or orders, or both
	entry_filter$=callpoint!.getDevObject("entry_filter")

	hit_eof=0
	while 1
		p_key$ = keyp(ope01_dev, end=eof_pkey)
		read record (ope01_dev, key=p_key$) ope01a$

		if ope01a.firm_id$+ope01a.trans_status$+ope01a.ar_type$=firm_id$+trans_status$+ar_type$ then 
			if (ope01a.ordinv_flag$ = "O" and ope01a.invoice_type$ <> "V") and
:			(entry_filter$="B" or (entry_filter$="Q" and ope01a.invoice_type$="P") or (entry_filter$="O" and ope01a.invoice_type$="S")) then
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
		read (ope01_dev, key=firm_id$+trans_status$+ar_type$+$ff$, dom=*next)
		hit_eof=hit_eof+1
		if hit_eof>1 then
			msg_id$ = "OP_NO_OPEN_ORDERS"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	wend

[[OPE_ORDHDR.BREX]]
rem --- Are both Customer and Order entered?

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"), 2) = "" or 
:		cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"), 2) = ""
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

rem --- Launch ope_createwos form to create selected work orders

	op_create_wo$=callpoint!.getDevObject("op_create_wo")
	if op_create_wo$="A" then
		soCreateWO!=callpoint!.getDevObject("soCreateWO")
		if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P" and callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")<>"C"
:		and (soCreateWO!.isChanged() or callpoint!.getDevObject("force_wolink_grid"))then
			rem --- Order NOT on Credit Hold and Order NOT a Quote, and there is something new to show (a change)

			rem --- Re-initialize soCreateWO! if SO was released from Credit Hold and create all possible Work Orders
			if action$="R" then
				soCreateWO!.initIsnWOMap(GridVect!.getItem(0))
				soCreateWO!.setCreateWO(Boolean.valueOf("true"))
			endif

			rem --- Skip unless there are validate candidate WOs could be created
			if soCreateWO!.woCount() then

				rem --- Update soCreateWO! with CURRENT detail grid line_no so ope_createwos grid sorts in the same order.
				soCreateWO!.updateLineNo(GridVect!.getItem(0))

				customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
				order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")

				dim dflt_data$[2,1]
				dflt_data$[1,0] = "CUSTOMER_ID"
				dflt_data$[1,1] = customer_id$
				dflt_data$[2,0] = "ORDER_NO"
				dflt_data$[2,1] = order_no$
				key_pfx$=firm_id$+customer_id$+order_no$

				call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:					"OPE_CREATEWOS", 
:					stbl("+USER_ID"), 
:					"", 
:					key_pfx$,
:					table_chans$[all],
:					"",
:					dflt_data$[all]

				rem --- Make sure focus returns to this form
				callpoint!.setStatus("ACTIVATE")
			endif
		endif

		rem --- Close files that may be open in soCreateWO! instance
		soCreateWO!.close()
	endif
	callpoint!.setDevObject("force_wolink_grid",0)

rem --- Skip Acknowledgements for quotes
	if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")<>"P"
		rem --- Has the Order changed since Acknowledgement was printed?
		gosub ordChangedForAck

		rem --- Ask to print Acknowledgement again if Order has changed
		if orderChanged then
			if callpoint!.getDevObject("auto_ord_conf")="Y" then
				rem --- Do Acknowledgement without launching the form
				cust_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
				order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
				call stbl("+DIR_PGM")+"opc_ordconf.aon::auto_on_demand", cust_id$, order_no$, table_chans$[all], status

				callpoint!.setColumnData("OPE_ORDHDR.ORD_CONF_PRINTED","Y")
				callpoint!.setColumnData("OPE_ORDHDR.MOD_USER",sysinfo.user_id$)
				callpoint!.setColumnData("OPE_ORDHDR.MOD_DATE",date(0:"%Yd%Mz%Dz"))
				callpoint!.setColumnData("OPE_ORDHDR.MOD_TIME",date(0:"%Hz%mz"))
				callpoint!.setStatus("SAVE")
			else
				msg_id$="OP_CREATE_CONF"
				gosub disp_message
				if msg_opt$="Y" then
					rem --- Mark acknowledgement as unprinted so can be printed in next batch
					callpoint!.setColumnData("OPE_ORDHDR.ORD_CONF_PRINTED","N")
					callpoint!.setStatus("SAVE")
				endif
			endif
		endif

		rem --- Automatically print Order Acknowledgement as needed
		if callpoint!.getDevObject("auto_ord_conf")="Y" and callpoint!.getColumnData("OPE_ORDHDR.ORD_CONF_PRINTED")<>"Y" then
			rem --- Do Acknowledgement without launching the form
			cust_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
			order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
			call stbl("+DIR_PGM")+"opc_ordconf.aon::auto_on_demand", cust_id$, order_no$, table_chans$[all], status
		endif
	endif

rem --- Is flag down?

	if !user_tpl.do_end_of_form then
		user_tpl.do_end_of_form = 1
		break; rem --- exit callpoint
	endif	

rem --- Credit action

	rem --- Header record will exist if at least one detail line has been entered.
	if GridVect!.getItem(0).size()>0 then
		if callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")<>"R" and
: 		ordHelp!.calcOverCreditLimit() and callpoint!.getDevObject("credit_action_done") <> "Y" then
			callpoint!.setDevObject("cred_action_from_print_now","")
			gosub do_credit_action
			if action$<>"D" then callpoint!.setStatus("SAVE")
		endif
	endif

[[OPE_ORDHDR.BSHO]]
rem --- Documentation
rem     Old s$(7,1) = 0 -> user_tpl.hist_ord$ = "Y" - order came from history
rem                 = 1 -> user_tpl.hist_ord$ = "N"

rem --- Open needed files

	num_files=56
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
	open_tables$[25]="OPE_ORDDET",   open_opts$[25]="OTA"
	open_tables$[26]="OPT_INVSHIP",  open_opts$[26]="OTA"
	open_tables$[27]="OPE_CREDDATE", open_opts$[27]="OTA"
	open_tables$[28]="IVC_WHSECODE", open_opts$[28]="OTA"
	open_tables$[29]="IVS_PARAMS",   open_opts$[29]="OTA"
	open_tables$[30]="OPE_ORDLSDET", open_opts$[30]="OTA"
	open_tables$[31]="IVM_ITEMPRIC", open_opts$[31]="OTA"
	open_tables$[32]="IVC_PRICCODE", open_opts$[32]="OTA"
	rem open_tables$[33]="", open_opts$[33]=""
	open_tables$[34]="OPE_PRNTLIST", open_opts$[34]="OTA"
	open_tables$[35]="OPM_POINTOFSALE",open_opts$[35]="OTA"
	open_tables$[36]="ARC_SALECODE", open_opts$[36]="OTA"
	open_tables$[37]="OPC_DISCCODE", open_opts$[37]="OTA"
	open_tables$[38]="OPC_TAXCODE",  open_opts$[38]="OTA"
	open_tables$[39]="OPE_ORDHDR",   open_opts$[39]="OTA"
	open_tables$[40]="ARC_TERMCODE", open_opts$[40]="OTA"
	open_tables$[41]="IVM_ITEMSYN",open_opts$[41]="OTA"
	open_tables$[42]="OPT_INVHDR",open_opts$[42]="OTAN[2_]"
	open_tables$[43]="OPT_SHIPTRACK",open_opts$[43]="OTA"
	open_tables$[44]="ARM_CUSTPMTS",   open_opts$[44]="OTA"
	open_tables$[45]="OPT_INVDET",open_opts$[45]="OTAN[2_]"
	open_tables$[46]="OPE_ORDLSDET", open_opts$[46]="OTA[2_]"
	open_tables$[47]="ADM_RPTCTL_RCP",open_opts$[47]="OTA"
	open_tables$[48]="OPT_FILLMNTHDR",open_opts$[48]="OTA"
	open_tables$[49]="OPT_INVKITDET",open_opts$[49]="OTA"
	open_tables$[50]="OPT_INVKITDET", open_opts$[50]="OTA[2_]"
	open_tables$[51]="ARC_DISTCODE", open_opts$[51]="OTA"
	open_tables$[52]="ARC_TERRCODE", open_opts$[52]="OTA"
	open_tables$[53]="IVC_PRODCODE", open_opts$[53]="OTA"
	open_tables$[54]="OPC_DISCCODE", open_opts$[54]="OTA"
	open_tables$[55]="OPC_MESSAGE", open_opts$[55]="OTA"
	open_tables$[56]="ARM_CUSTITEMS", open_opts$[56]="OTA"

	gosub open_tables

	callpoint!.setDevObject("opt_invlookup",open_chans$[42])
	callpoint!.setDevObject("opt_invlookup_tpl",open_tpls$[42])

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
	callpoint!.setDevObject("op_create_wo",ars01a.op_create_wo$)
	callpoint!.setDevObject("sls_tax_intrface", cvs(ars01a.sls_tax_intrface$,2))
	callpoint!.setDevObject("warn_not_avail",ars01a.warn_not_avail$)
	callpoint!.setDevObject("auto_ord_conf",ars01a.auto_ord_conf$)
	callpoint!.setDevObject("hide_cost",ars01a.hide_cost$)
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
	callpoint!.setDevObject("dropship_whse",ivs01a.dropship_whse$)

rem --- see if blank warehouse exists

	blank_whse$="N"
	dim ivm10c$:open_tpls$[28]
	start_block = 1
	
	if start_block then
		read record (num(open_chans$[28]), key=firm_id$+"C"+ivm10c.warehouse_id$, dom=*endif) ivm10c$
		blank_whse$="Y"
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
		column!.addItem("OPE_ORDHDR.JOB_NO")
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
	UserObj!.addItem( util.getControl(callpoint!, "OPE_ORDHDR.TOTAL_SALES") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_ORDHDR.TOTAL_COST") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_ORDHDR.TAX_AMOUNT") )
	UserObj!.addItem( util.getControl(callpoint!, "OPE_ORDHDR.DISCOUNT_AMT") )
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
:		"user_entry:c(1), " +
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
:		"record_deleted:u(1), " +
:		"item_wh_failed:u(1), " +
:		"do_end_of_form:u(1), " +
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
	user_tpl.record_deleted    = 0
	user_tpl.item_wh_failed    = 1
	user_tpl.do_end_of_form    = 1
	user_tpl.new_order         = 0
	user_tpl.credit_limit_warned = 0
	user_tpl.shipto_warned     = 0

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

rem --- Save the indices of the controls for the Avail Window, setup in AFMC

	user_tpl.avail_oh      = 2
	user_tpl.avail_comm    = 3
	user_tpl.avail_avail   = 4
	user_tpl.avail_oo      = 5
	user_tpl.avail_wh      = 6
	user_tpl.avail_type    = 7
	user_tpl.dropship_flag = 8
	user_tpl.manual_price  = 9
	user_tpl.alt_super     = 10
	user_tpl.ord_tot_obj   = 11; rem set here in BSHO

	callpoint!.setDevObject("subtot_disp","12")
	callpoint!.setDevObject("net_sales_disp","13")
	callpoint!.setDevObject("total_sales_disp","14")
	callpoint!.setDevObject("total_cost","15")
	callpoint!.setDevObject("tax_amt_disp","16")
	callpoint!.setDevObject("disc_amt_disp","17")
	callpoint!.setDevObject("backord_disp","18")
	callpoint!.setDevObject("credit_disp","19")
	callpoint!.setDevObject("man_hold",ars_credit.man_hold$)

rem --- Create GL Posting Control
	gl$="N"
	call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,pgm(-2),"OP",glw11$,gl$,status
	user_tpl.glint$=gl$
	callpoint!.setDevObject("glint",gl$)

	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("KITS",0)
	callpoint!.setOptionEnabled("RCPR",0)
	callpoint!.setOptionEnabled("WHSE",0)
	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)
	callpoint!.setOptionEnabled("RPRT",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("ADDL",0)
	callpoint!.setOptionEnabled("TTLS",0)
	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("CRAT",0)
	callpoint!.setOptionEnabled("WOLN",0)
	callpoint!.setOptionEnabled("AGNG",0)
	callpoint!.setOptionEnabled("OACK",0)
	callpoint!.setOptionEnabled("CUST",0)

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
	callpoint!.setDevObject("force_wolink_grid",0)
	callpoint!.setDevObject("OP_TOTALS_TAB_msg",1)

rem --- setup message_tpl$

	gosub init_msgs

rem --- Set callback for a tab being selected, and save the tab control ID
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	tabCtrl!.setCallback(BBjTabCtrl.ON_TAB_SELECT,"custom_event")

rem --- Initialize ReprintFlag devObject used for workaround to Barista Bug 10297
	callpoint!.setDevObject("ReprintFlag","")

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

[[OPE_ORDHDR.BWAR]]
rem --- Has customer and order number been entered?
	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))

	if ordHelp!.getCust_id() = "" or ordHelp!.getOrder_no() = "" then
		break; rem --- exit callpoint
	endif

rem --- Write Order Addresses file
	gosub write_address_file

rem --- Calculate Taxes
	disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_ORDHDR.BWRI]]
rem --- Has customer and order number been entered?

	cust_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")

	if cvs(cust_id$, 2) = "" or cvs(order_no$, 2) = "" then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Check Ship-to's

	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	shipto_no$  = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")

rem --- Check for Order Total

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

rem --- Check to see if we need to go to the totals tab

rem --- Force focus on the Totals tab

	if pos(callpoint!.getDevObject("totals_warn")="24")>0
		if pos(callpoint!.getDevObject("was_on_tot_tab")="N") > 0
			if callpoint!.getDevObject("details_changed")="Y" and callpoint!.getDevObject("rcpr_row")="" and
:			callpoint!.getDevObject("OP_TOTALS_TAB_msg") then
				callpoint!.setMessage("OP_TOTALS_TAB")
				callpoint!.setFocus("OPE_ORDHDR.FREIGHT_AMT")
				callpoint!.setDevObject("was_on_tot_tab","Y")
				callpoint!.setStatus("ABORT-ACTIVATE")
				break
			endif
		endif
	endif
	callpoint!.setDevObject("OP_TOTALS_TAB_msg",1)

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
			if callpoint!.getColumnData("OPE_ORDHDR.PRINT_STATUS")="Y" then callpoint!.setColumnData("OPE_ORDHDR.REPRINT_FLAG","Y",1)
		endif
	endif

[[OPE_ORDHDR.CUSTOMER_ID.AINP]]
rem --- If cash customer, get correct customer number
	callpoint!.setDevObject("defaultCustomer","")
	if user_tpl.cash_sale$="Y" and cvs(callpoint!.getUserInput(),1+2+4)="C" then
		callpoint!.setDevObject("defaultCustomer","C")
		callpoint!.setColumnData("OPE_ORDHDR.CUSTOMER_ID", user_tpl.cash_cust$,1)
		callpoint!.setColumnData("OPE_ORDHDR.CASH_SALE", "Y")
	endif

rem --- Get requested Quote customer
	if cvs(callpoint!.getUserInput(),1+2+4)="Q" then
		opmPointOfSale_dev=fnget_dev("OPM_POINTOFSALE")
		dim opmPointOfSale$:fnget_tpl$("OPM_POINTOFSALE")
		station$ = "DEFAULT"
		station$ = stbl("OPE_DEF_STATION", err=*next)
		find record (opmPointOfSale_dev, key=firm_id$+pad(station$, 16), dom=*next)opmPointOfSale$
		if cvs(opmPointOfSale.quote_cust_id$,2)<>"" then
			callpoint!.setDevObject("defaultCustomer","Q")
			callpoint!.setColumnData("OPE_ORDHDR.CUSTOMER_ID",opmPointOfSale.quote_cust_id$,1)
		else
			rem --- POS Default Quote Customer not setup
			callpoint!.setUserInput("")
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Disable Backordered button
	callpoint!.setOptionEnabled("BACK",0)

[[OPE_ORDHDR.CUSTOMER_ID.AVAL]]
rem --- Customer Inactive Feature
	cust_id$ = callpoint!.getUserInput()

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

rem --- Display customer level credit info

	over_credit_limit = ordHelp!.calcOverCreditLimit()
	if over_credit_limit = 1
		callpoint!.setDevObject("msg_exceeded","Y")
	else
		callpoint!.setDevObject("msg_credit_okay","Y")
	endif
	call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!

rem --- The cash customer?

	if user_tpl.cash_sale$="Y" and cust_id$ = user_tpl.cash_cust$
		callpoint!.setColumnData("OPE_ORDHDR.CASH_SALE", "Y")
		callpoint!.setColumnData("OPE_ORDHDR.SHIPTO_TYPE","M",1)
       else
		callpoint!.setColumnData("OPE_ORDHDR.CASH_SALE", "N")
	endif

rem --- Is this new Order for a Sale or Quote?
	sale_or_quote$=""
	orderType_label!=callpoint!.getDevObject("orderType_label")
	defaultCustomer$=callpoint!.getDevObject("defaultCustomer")
	if defaultCustomer$="" then
		if user_tpl.cash_sale$="Y" and cust_id$ = user_tpl.cash_cust$ then
			rem --- This is the Default Cash Customer so this Order is for a Sale
			sale_or_quote$="S"
			defaultCustomer$="C"
			callpoint!.setDevObject("defaultCustomer",defaultCustomer$)
		else
			rem --- Is this a POS Default Quote Customer?
			opmPointOfSale_dev=fnget_dev("OPM_POINTOFSALE")
			dim opmPointOfSale$:fnget_tpl$("OPM_POINTOFSALE")
			read(opmPointOfSale_dev,key=firm_id$,dom=*next)
			while 1
				opmPointOfSale_key$=key(opmPointOfSale_dev,end=*break)
				if pos(firm_id$=opmPointOfSale_key$)<>1 then break
				readrecord(opmPointOfSale_dev)opmPointOfSale$
				if cust_id$=opmPointOfSale.quote_cust_id$ then
					rem --- This is a POS Default Quote Customer, so this Order is for a Quote
					sale_or_quote$="Q"
					defaultCustomer$="Q"
					callpoint!.setDevObject("defaultCustomer",defaultCustomer$)
					break
				endif
			wend

			if sale_or_quote$="" then
				rem --- Defaulting Orders to Quotes?
				station$ = "DEFAULT"
				station$ = stbl("OPE_DEF_STATION", err=*next)
				redim opmPointOfSale$
				find record (opmPointOfSale_dev, key=firm_id$+pad(station$, 16), dom=*next)opmPointOfSale$
				if opmPointOfSale.default_to_quote then
					rem --- Orders are defaulting to Quotes 
					sale_or_quote$="Q"
				else
					rem --- This Order isn't for a Quote, so it must be for a Sale.
					sale_or_quote$="S"
				endif
			endif
		endif
	else
		if defaultCustomer$="C" then
			rem --- This is the Default Cash Customer so this Order is for a Sale
			sale_or_quote$="S"
		endif
		if defaultCustomer$="Q" then
		rem --- This is the POS Default Quote Customer so this Order is for a Quote
			sale_or_quote$="Q"
		endif
	endif

	if sale_or_quote$="S" then
		rem --- This Order is for a Sale
		orderType_label!.setText("Sale")
		orderType_label!.setForeColor(callpoint!.getDevObject("colorGreen"))
		orderType_label!.setVisible(1)
	endif

	if sale_or_quote$="Q" then
		rem --- This Order is for a Quote
		callpoint!.setDevObject("create_quote","P")
		orderType_label!.setText("Quote")
 		orderType_label!.setForeColor(BBjColor.RED)
		orderType_label!.setVisible(1)

		rem --- Enable expire date and disable order acknowledgements
		callpoint!.setColumnEnabled("OPE_ORDHDR.EXPIRE_DATE", 1)
		callpoint!.setOptionEnabled("OACK",0)

		rem --- Set Invoice Type in OrderHelper object
		ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
		ordHelp!.setInv_type("P")
	endif

rem --- Show customer data

	if callpoint!.getColumnData("OPE_ORDHDR.CASH_SALE")<>"Y" and defaultCustomer$<>"Q" then 
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

rem --- Enable buttons

	if cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"), 2) = "" and callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("DINV",1)
		callpoint!.setOptionEnabled("CINV",1)
	endif

	if user_tpl.credit_installed$="Y"
		callpoint!.setOptionEnabled("CRCH",1)
	endif
	callpoint!.setOptionEnabled("AGNG",iff(callpoint!.getDevObject("on_demand_aging")="Y",1,0))

[[OPE_ORDHDR.CUSTOMER_PO_NO.AVAL]]
rem --- Check for duplicate PO numbers

	found_dupes! = BBjAPI().makeVector()
	if callpoint!.getDevObject("check_po_dupes")="Y" and cvs(callpoint!.getUserInput(),2)<>"" then
		po_no$=pad(callpoint!.getUserInput(),num(callpoint!.getTableColumnAttribute("OPE_ORDHDR.CUSTOMER_PO_NO","MAXL")))
		cust_no$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
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
			callpoint!.setDevObject("customer",callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID"))
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

[[OPE_ORDHDR.DISCOUNT_AMT.AVAL]]
rem --- Discount Amount cannot exceed Total Sales Amount

	disc_amt = num(callpoint!.getUserInput())
	total_sales = num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES"))
	if (total_sales >= 0 and disc_amt > total_sales) or (total_sales < 0 and disc_amt < total_sales) then
		disc_amt = total_sales
		callpoint!.setUserInput(str(disc_amt))
	endif

rem --- Skip if the disc_amt hasn't changed
	if disc_amt=num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT")) then break

rem --- Force recalculate totals

	callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(1))
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_ORDHDR.DISCOUNT_AMT.BINP]]
rem --- Now we've been on the Totals tab

	callpoint!.setDevObject("was_on_tot_tab","Y")

[[OPE_ORDHDR.DISC_CODE.AVAL]]
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

rem --- Set discount code for use in Order Totals if it changed
	disc_code$ = callpoint!.getUserInput()
	if cvs(disc_code$,3)=cvs(callpoint!.getColumnData("OPE_ORDHDR.DISC_CODE"),3) then break

	user_tpl.disc_code$ = disc_code$
	callpoint!.setDevObject("disc_code",user_tpl.disc_code$)

	file_name$ = "OPC_DISCCODE"
	disccode_dev = fnget_dev(file_name$)
	dim disccode_rec$:fnget_tpl$(file_name$)

	find record (disccode_dev, key=firm_id$+user_tpl.disc_code$, dom=*next) disccode_rec$
	new_disc_per = disccode_rec.disc_percent

	new_disc_amt = round(disccode_rec.disc_percent * num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES")) / 100, 2)
	callpoint!.setColumnData("OPE_ORDHDR.DISCOUNT_AMT",str(new_disc_amt))

	disc_amt = new_disc_amt
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_ORDHDR.FREIGHT_AMT.AVAL]]
rem --- Skip if the FREIGHT_AMT hasn't changed
	freight_amt = num(callpoint!.getUserInput())
	if freight_amt=num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT")) then break

rem --- Force recalculate totals

	callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(1))
	disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	gosub calculate_tax

[[OPE_ORDHDR.FREIGHT_AMT.BINP]]
rem --- Now we've been on the Totals tab

	callpoint!.setDevObject("was_on_tot_tab","Y")

[[OPE_ORDHDR.INVOICE_TYPE.AVAL]]
rem --- Convert Quote?

	inv_type$ = callpoint!.getUserInput()

	if rec_data.invoice_type$="S" then 
		if inv_type$="P" then 
			msg_id$="OP_NO_CONVERT"
			gosub disp_message
			inv_type$="S"
			callpoint!.setColumnData("OPE_ORDHDR.INVOICE_TYPE",inv_type$,1)
			callpoint!.setStatus("ABORT")
			callpoint!.setUserInput(inv_type$)
		endif
	else
		if rec_data.invoice_type$="P" and inv_type$="S" then 
			msg_id$="CONVERT_QUOTE"
			gosub disp_message

			if msg_opt$ = "Y" then 
				rem --- Print pick list in next batch
				order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
				gosub add_to_batch_print
				callpoint!.setColumnData("OPE_ORDHDR.REPRINT_FLAG","")
	
				callpoint!.setColumnData("OPE_ORDHDR.PRINT_STATUS","N")
				callpoint!.setColumnData("OPE_ORDHDR.INVOICE_TYPE","S",1)

				ope11_dev        = fnget_dev("OPE_ORDDET")
				ivs01_dev        = fnget_dev("IVS_PARAMS")
				opc_linecode_dev = fnget_dev("OPC_LINECODE")
				dim ope11a$:fnget_tpl$("OPE_ORDDET")
				dim ivs01a$:fnget_tpl$("IVS_PARAMS")
				dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
				
				read record (ivs01_dev, key=firm_id$+"IV00") ivs01a$

				old_prec = tcb(14)
				precision num(ivs01a.precision$)
				total_sales=0
				taxable_amt=0

				trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
				ar_type$ = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
				cust$    = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
				ord$     = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
				read record (ope11_dev, key=firm_id$+trans_status$+ar_type$+cust$+ord$, dom=*next)

				while 1
					extract record (ope11_dev, end=*break) ope11a$; rem Advisory Locking

					if pos(firm_id$+trans_status$+ar_type$+cust$+ord$=ope11a.firm_id$+ope11a.trans_status$+
:						ope11a.ar_type$+ope11a.customer_id$+ope11a.order_no$)<>1 then
						read(ope11_dev)
						break
					endif

					linecode_found=0
					read record (opc_linecode_dev, key=firm_id$+ope11a.line_code$, dom=*next) opc_linecode$; linecode_found=1
					if !linecode_found then
						read(ope11_dev)
						continue
					endif
					ope11a.commit_flag$ = "Y"
					ope11a.pick_flag$   = "N"
					if ope11a.est_shp_date$>user_tpl.def_commit$ then ope11a.commit_flag$="N"

					if ope11a.commit_flag$="N" then 
						if opc_linecode.line_type$<>"O" then 
							ope11a.qty_backord = 0
							ope11a.qty_shipped = 0
							ope11a.ext_price   = 0
							ope11a.taxable_amt = 0
						else 
							if ope11a.ext_price<>0 then 
								ope11a.unit_price  = ope11a.ext_price
								ope11a.ext_price   = 0
								ope11a.taxable_amt = 0
							endif
						endif
					endif

					if pos(opc_linecode.line_type$="SP")>0 and opc_linecode.dropship$<>"Y" and
:						ope11a.commit_flag$<>"N"
:					then
						wh_id$    = ope11a.warehouse_id$
						item_id$  = ope11a.item_id$
						ls_id$    = ""
						qty       = ope11a.qty_ordered
						line_sign = 1
						gosub update_totals
					endif

					total_sales=total_sales+ope11a.ext_price
					taxable_amt=taxable_amt+ope11a.taxable_amt
					ope11a$=field(ope11a$)
					write record (ope11_dev) ope11a$
				wend

				rem --- Recalculate discount and tax if the total sales amount has changed.
				rem --- Otherwise leave the discount amount alone as it may have been entered manually.
				if total_sales<>num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES")) then
					rem --- Recalculate discount for current total sales
					disccode_dev = fnget_dev("OPC_DISCCODE")
					dim disccode_rec$:fnget_tpl$("OPC_DISCCODE")
					find record (disccode_dev, key=firm_id$+user_tpl.disc_code$, dom=*next) disccode_rec$
					disc_amt = round(disccode_rec.disc_percent * total_sales / 100, 2)
					callpoint!.setColumnData("OPE_ORDHDR.DISCOUNT_AMT",str(disc_amt))

					rem --- Recalculate tax and update totals display
					callpoint!.setColumnData("OPE_ORDHDR.TOTAL_SALES",str(total_sales))
					callpoint!.setColumnData("OPE_ORDHDR.TAXABLE_AMT",str(taxable_amt))
					freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
					gosub calculate_tax
				endif

				precision old_prec
				rec_data.invoice_type$ = "S"

				callpoint!.setDevObject("msg_quote","N")
				callpoint!.setDevObject("msg_printed","N")
				call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!

				rem --- Reload detail grid with updated ope-11 (ope_orddet) records
				callpoint!.setStatus("REFGRID")

				rem --- Create all possible Work Orders when Quote changed to Sale
				op_create_wo$=callpoint!.getDevObject("op_create_wo")
				if op_create_wo$="A" then
					soCreateWO!=callpoint!.getDevObject("soCreateWO")
					soCreateWO!.initIsnWOMap(GridVect!.getItem(0))
					soCreateWO!.setCreateWO(Boolean.valueOf("true"))
				endif

				rem --- Update static Order Type label for this Order
				gosub orderType_display
			else
				rem --- Changed their mind about converting a quote
				inv_type$="P"
				callpoint!.setColumnData("OPE_ORDHDR.INVOICE_TYPE",inv_type$,1)
				callpoint!.setStatus("ABORT")
				callpoint!.setUserInput(inv_type$)
			endif
		endif
	endif

rem --- Enable/disable expire date based on value, and order acknowledgements

	if inv_type$ = "S" then
		callpoint!.setColumnData("OPE_ORDHDR.EXPIRE_DATE","",1)
		callpoint!.setColumnEnabled("OPE_ORDHDR.EXPIRE_DATE", 0)
		callpoint!.setOptionEnabled("OACK",1)
	else
		callpoint!.setColumnEnabled("OPE_ORDHDR.EXPIRE_DATE", 1)
		callpoint!.setOptionEnabled("OACK",0)
	endif

rem --- Set type in OrderHelper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setInv_type(inv_type$)

[[OPE_ORDHDR.MESSAGE_CODE.AVAL]]
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

[[OPE_ORDHDR.ORDER_DATE.AVAL]]
rem --- Warn if Order Date isn't in an appropriate GL period
	order_date$=callpoint!.getUserInput()        
	if user_tpl.glint$="Y" 
		call stbl("+DIR_PGM")+"glc_datecheck.aon",order_date$,"Y",per$,yr$,status
	endif

rem --- Set user template info

	user_tpl.order_date$=order_date$

[[OPE_ORDHDR.ORDER_NO.AVAL]]
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
			user_tpl.new_order=1

			rem --- Create soCreateWO! instance if needed
			op_create_wo$=callpoint!.getDevObject("op_create_wo")
			if op_create_wo$="A" then
				rem --- Clean up previous instance as necessary
				if soCreateWO!<>null() then soCreateWO!.close()

				customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
				soCreateWO!=new SalesOrderCreateWO(firm_id$,customer_id$,order_no$)
				callpoint!.setDevObject("soCreateWO",soCreateWO!)
				callpoint!.setDevObject("createWOs_status","")
			endif
		endif
	endif

rem --- Does order exist?

	ope01_dev = fnget_dev("OPE_ORDHDR")
	dim ope01a$:fnget_tpl$("OPE_ORDHDR")

	ar_type$ = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	cust_id$ = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")

	rem --- Restrict to only order with Entry transaction status
	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	ope01_trip$=firm_id$+trans_status$+ar_type$+cust_id$+order_no$
	read(ope01_dev, key=ope01_trip$, dom=*next)
	ope01_key$=key(ope01_dev,end=*next)
	if pos(ope01_trip$=ope01_key$)=1 then
		found = 1
		readrecord(ope01_dev,key=ope01_key$)ope01a$
	else
		found = 0
	endif

rem --- A new record must be the next sequence

	if found = 0 and user_tpl.new_order=0 then
		msg_id$ = "OP_NEW_ORD_USE_SEQ"
		gosub disp_message	
		callpoint!.setFocus("OPE_ORDHDR.ORDER_NO")
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

	rem --- Check for invoice
		
		if ope01a.ordinv_flag$ = "I" then
			msg_id$ = "OP_IS_INVOICE"
			gosub disp_message
			callpoint!.setStatus("NEWREC")
			break; rem --- exit from callpoint			
		endif		

	rem --- Check locked status

		gosub check_lock_flag

		if locked=1 then 
			user_tpl.do_end_of_form = 0
			callpoint!.setStatus("ABORT")
			break; rem --- exit callpoint
		endif

	rem --- Set Codes		
        
		user_tpl.price_code$   = ope01a.price_code$
		user_tpl.pricing_code$ = ope01a.pricing_code$
		user_tpl.order_date$   = ope01a.order_date$

	else

	rem --- New record

		cust_id$   = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
		order_no$  = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
		rem --- Set dflt invoice type in OrderHelper object

		ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
		ordHelp!.setInv_type(str(callpoint!.getDevObject("create_quote")))

		arm02_dev=fnget_dev("ARM_CUSTDET")
		dim arm02a$:fnget_tpl$("ARM_CUSTDET")
		read record (arm02_dev, key=firm_id$+cust_id$+"  ", dom=*next) arm02a$

		arm01_dev=fnget_dev("ARM_CUSTMAST")
		dim arm01a$:fnget_tpl$("ARM_CUSTMAST")
		read record (arm01_dev,key=firm_id$+cust_id$, dom=*next) arm01a$

		callpoint!.setColumnData("OPE_ORDHDR.SHIPMNT_DATE",user_tpl.def_ship$)
		callpoint!.setColumnData("OPE_ORDHDR.INVOICE_TYPE",str(callpoint!.getDevObject("create_quote")),1)
		callpoint!.setColumnData("OPE_ORDHDR.ORDINV_FLAG","O")
		callpoint!.setColumnData("OPE_ORDHDR.INVOICE_DATE",sysinfo.system_date$)
		callpoint!.setColumnData("OPE_ORDHDR.AR_SHIP_VIA",arm01a.ar_ship_via$)
		callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_ID",arm01a.shipping_id$)
		callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_EMAIL",arm01a.shipping_email$)
		callpoint!.setColumnData("OPE_ORDHDR.SLSPSN_CODE",arm02a.slspsn_code$)
		callpoint!.setColumnData("OPE_ORDHDR.TERMS_CODE",arm02a.ar_terms_code$)
		callpoint!.setColumnData("OPE_ORDHDR.DISC_CODE",arm02a.disc_code$)
		callpoint!.setColumnData("OPE_ORDHDR.AR_DIST_CODE",arm02a.ar_dist_code$)
		callpoint!.setColumnData("OPE_ORDHDR.PRINT_STATUS","N")
		callpoint!.setColumnData("OPE_ORDHDR.MESSAGE_CODE",arm02a.message_code$)
		callpoint!.setColumnData("OPE_ORDHDR.TERRITORY",arm02a.territory$)
		callpoint!.setColumnData("OPE_ORDHDR.ORDER_DATE",sysinfo.system_date$)
		callpoint!.setColumnData("OPE_ORDHDR.TAX_CODE",arm02a.tax_code$)
		callpoint!.setColumnData("OPE_ORDHDR.PRICING_CODE",arm02a.pricing_code$)
		callpoint!.setColumnData("OPE_ORDHDR.ORD_TAKEN_BY",sysinfo.user_id$)
		callpoint!.setColumnData("OPE_ORDHDR.FOB",arm01a.fob$)

		callpoint!.setDevObject("disc_code",arm02a.disc_code$)
		user_tpl.disc_code$    = arm02a.disc_code$

		ordHelp!.setTaxCode(arm02a.tax_code$)

		slsp$ = arm02a.slspsn_code$
		gosub get_comm_percent

		gosub get_op_params

		user_tpl.price_code$   = ""
		user_tpl.pricing_code$ = arm02a.pricing_code$
		user_tpl.order_date$   = sysinfo.system_date$

	endif

rem --- Set lock (debug, not working correctly at the moment)

	rem callpoint!.setColumnData("OPE_ORDHDR.LOCK_STATUS", "Y")
	callpoint!.setColumnData("OPE_ORDHDR.LOCK_STATUS", "N"); rem debug, forcing the lock off for now
	rem callpoint!.setStatus("SAVE")

rem --- Add to batch print list

	order_no$ = callpoint!.getUserInput()
	gosub add_to_batch_print

rem --- Enable/Disable buttons

	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)

	if new_seq$ = "N" then 
		if user_tpl.credit_installed$="Y" and user_tpl.pick_hold$<>"Y" and
:			callpoint!.getColumnData("OPE_ORDHDR.CREDIT_FLAG")="C"
:		then
			callpoint!.setOptionEnabled("RPRT",0)
		else
			callpoint!.setOptionEnabled("RPRT",1)
		endif
	endif

	callpoint!.setStatus("REFRESH")

rem --- Set order in OrderHelper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setOrder_no(order_no$)

[[OPE_ORDHDR.PRICE_CODE.AVAL]]
rem --- Set user template info

	user_tpl.price_code$=callpoint!.getUserInput()

[[OPE_ORDHDR.PRICING_CODE.AVAL]]
rem --- Set user template info

	user_tpl.pricing_code$=callpoint!.getUserInput()

[[<<DISPLAY>>.SADD1.AVAL]]
rem --- Check Ship-to's

	shipto_no$  = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getUserInput()+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD1 was changed
	sadd1$=callpoint!.getUserInput()
	if cvs(sadd1$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD1"),3) then
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SADD2.AVAL]]
rem --- Check Ship-to's

	shipto_no$  = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getUserInput()+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD2 was changed
	sadd2$=callpoint!.getUserInput()
	if cvs(sadd2$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD2"),3) then
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SADD3.AVAL]]
rem --- Check Ship-to's

	shipto_no$  = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getUserInput()+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif

rem --- Update sales tax calculation if SADD3 was changed
	sadd3$=callpoint!.getUserInput()
	if cvs(sadd3$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD3"),3) then
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SADD4.AVAL]]
rem --- Check Ship-to's

	shipto_no$  = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getUserInput()
	gosub check_shipto
	if user_tpl.shipto_warned
		break; rem --- exit callpoint
	endif


rem --- Update sales tax calculation if SADD4 was changed
	sadd4$=callpoint!.getUserInput()
	if cvs(sadd4$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SADD4"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SCITY.AVAL]]
rem --- Update sales tax calculation if SCITY was changed
	scity$=callpoint!.getUserInput()
	if cvs(city$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SCITY"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SCNTRY_ID.AVAL]]
rem --- Update sales tax calculation if SCNTRY_ID was changed
	scntry_id$=callpoint!.getUserInput()
	if cvs(scntry_id$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SCNTRY_ID"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[OPE_ORDHDR.SHIPMNT_DATE.AVAL]]
rem --- Warn if Shipment Date isn't in an appropriate GL period
	shipmnt_date$=callpoint!.getUserInput()        
	if user_tpl.glint$="Y" 
		call stbl("+DIR_PGM")+"glc_datecheck.aon",shipmnt_date$,"Y",per$,yr$,status
	endif

[[OPE_ORDHDR.SHIPPING_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

[[OPE_ORDHDR.SHIPPING_ID.AVAL]]
rem --- Enable/disable Freight Amount
	shipping_id$=callpoint!.getUserInput()
	if shipping_id$=callpoint!.getColumnData("OPE_ORDHDR.SHIPPING_ID") then break

	if cvs(shipping_id$,2)<>"" then
		callpoint!.setColumnEnabled("OPE_ORDHDR.FREIGHT_AMT",0)
		callpoint!.setColumnData("OPE_ORDHDR.FREIGHT_AMT",str(0),1)
	else
		callpoint!.setColumnEnabled("OPE_ORDHDR.FREIGHT_AMT",1)
	endif

[[OPE_ORDHDR.SHIPTO_NO.AVAL]]
rem --- Check Ship-to's if SHIPTO_NO has changed
	shipto_no$  = callpoint!.getUserInput()
	if cvs(shipto_no$,3)=cvs(callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO"),3) then break

rem --- Don't allow inactive code
	armCustShip_dev=fnget_dev("ARM_CUSTSHIP")
	dim armCustShip$:fnget_tpl$("ARM_CUSTSHIP")
	customer_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
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

	shipto_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	ship_addr$=callpoint!.getColumnData("<<DISPLAY>>.SADD1")+callpoint!.getColumnData("<<DISPLAY>>.SADD2")+
:		callpoint!.getColumnData("<<DISPLAY>>.SADD3")+callpoint!.getColumnData("<<DISPLAY>>.SADD4")
	gosub check_shipto
	if user_tpl.shipto_warned
		callpoint!.setDevObject("abort_shipto_no",1)
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

rem --- Remove manual ship-record, if necessary

	cust_id$    = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$   = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")

	if user_tpl.prev_ship_to$ = "000099" and shipto_no$ <> "000099" then
		remove (fnget_dev("OPE_ORDSHIP"), key=firm_id$+cust_id$+order_no$+invoice_no$, dom=*next)
	endif

rem --- Display Ship to information

	ship_to_no$  = callpoint!.getUserInput()
	ship_to_type$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
	gosub ship_to_info

[[OPE_ORDHDR.SHIPTO_NO.BINP]]
print "SHIPTO:BINP"; rem debug

rem --- Save old value

	user_tpl.prev_ship_to$ = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")

rem --- Allow changing shipto_type when abort shipto_no
	if callpoint!.getDevObject("abort_shipto_no")<>null() then
		if num(callpoint!.getDevObject("abort_shipto_no"),err=*endif)
			callpoint!.setDevObject("abort_shipto_no",0)
			callpoint!.setFocus("OPE_ORDHDR.SHIPTO_TYPE")
			callpoint!.setStatus("ABORT")
			break; rem --- exit callpoint
		endif
	endif

[[OPE_ORDHDR.SHIPTO_TYPE.AVAL]]
rem -- Deal with which Ship To type if it has changed
	ship_to_type$ = callpoint!.getUserInput()
	if cvs(ship_to_type$,3)=cvs(callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE"),3) and callpoint!.getRecordMode()<>"A" then break

	ship_to_no$   = callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO")
	cust_id$      = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$     = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")

	gosub ship_to_info

rem --- Disable Ship To fields

	gosub disable_shipto

[[OPE_ORDHDR.SLSPSN_CODE.AVAL]]
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

[[<<DISPLAY>>.SNAME.BDRL]]
rem --- Skip if not for a manual ship-to in edit mode
	shipto_type$=callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE")
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
	filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")+"'"
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
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[<<DISPLAY>>.SZIP.AVAL]]
rem --- Update sales tax calculation if SZIP was changed
	szip$=callpoint!.getUserInput()
	if cvs(szip$,3)<>cvs(callpoint!.getColumnData("<<DISPLAY>>.SZIP"),3) then 
		disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
		freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
		gosub calculate_tax
	endif

[[OPE_ORDHDR.TAX_CODE.AVAL]]
rem --- Skip if the TAX_CODE hasn't changed
	tax_code$=callpoint!.getUserInput()
	if tax_code$=callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE") then break

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

rem --- Set code in the Order Helper object

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	ordHelp!.setTaxCode(tax_code$)

rem --- Calculate Taxes

	disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
	gosub calculate_tax

[[OPE_ORDHDR.TERRITORY.AVAL]]
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

[[OPE_ORDHDR.<CUSTOM>]]
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
			report_type$="Unkown"
			break
	swend
	callpoint!.setColumnData("<<DISPLAY>>.REPORT_TYPE",report_type$,1)

	rem --- also display cust type
	callpoint!.setColumnData("<<DISPLAY>>.CUST_TP",   custdet_tpl.customer_type$)

	user_tpl.credit_limit = custdet_tpl.credit_limit

	return

rem ==========================================================================
check_credit: rem --- Check credit limit of customer
              rem     (ope_db, 5400-5499)
rem ==========================================================================

	arm02_dev=fnget_dev("ARM_CUSTDET")
	dim arm02a$:fnget_tpl$("ARM_CUSTDET")
	read record (arm02_dev,key=firm_id$+cust_id$+"  ",dom=*next) arm02a$

	if arm02a.cred_hold$<>"E"
		ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
		creditRemaining = ordHelp!.getCreditLimit()-ordHelp!.getTotalAging()-ordHelp!.getOpenOrderAmount()-ordHelp!.getOpenBoAmount()-ordHelp!.getHeldOrderAmount()+num(callpoint!.getDevObject("orig_net_sales"))
		if user_tpl.credit_limit<>0 and !user_tpl.credit_limit_warned and num(callpoint!.getColumnData("<<DISPLAY>>.NET_SALES")) > creditRemaining then

			msg_id$ = "OP_OVER_CREDIT_LIMIT"
			dim msg_tokens$[1]
			msg_tokens$[1] = str(user_tpl.credit_limit:user_tpl.amount_mask$)
			gosub disp_message
			callpoint!.setStatus("ACTIVATE")

			callpoint!.setDevObject("msg_exceeded","Y")
			user_tpl.credit_limit_warned = 1
		endif
	endif

	return

rem ==========================================================================
ship_to_info: rem --- Get and display Bill To Information
              rem      IN: ship_to_type$
              rem          cust_id$
              rem          ship_to_no$
              rem          order_no$
rem ==========================================================================

	custmast_dev=fnget_dev("ARM_CUSTMAST")
	dim custmast$:fnget_tpl$("ARM_CUSTMAST")
	findrecord(custmast_dev,key=firm_id$+cust_id$,dom=*next)custmast$

	ar_type$=callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	custdet_dev=fnget_dev("ARM_CUSTDET")
	dim custdet$:fnget_tpl$("ARM_CUSTDET")
	read record(custdet_dev,key=firm_id$+cust_id$+ar_type$,dom=*next)custdet$

	if ship_to_type$<>"M" then 

		if ship_to_type$="S" then 
			custship_dev=fnget_dev("ARM_CUSTSHIP")
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
			if ship_to_type$<>callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE") or
:                       ship_to_no$<>callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_NO") then
				rem --- Initialize for change
				callpoint!.setColumnData("OPE_ORDHDR.SLSPSN_CODE",custship_tpl.slspsn_code$)
				callpoint!.setColumnData("OPE_ORDHDR.TERRITORY",custship_tpl.territory$)
				callpoint!.setColumnData("OPE_ORDHDR.TAX_CODE",custship_tpl.tax_code$)
				if cvs(custship_tpl.ar_ship_via$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.AR_SHIP_VIA",custship_tpl.ar_ship_via$)
				if cvs(custship_tpl.shipping_id$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_ID",custship_tpl.shipping_id$)
				if cvs(custship_tpl.shipping_email$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_EMAIL",custship_tpl.shipping_email$)
			endif
		else
			callpoint!.setColumnData("OPE_ORDHDR.SHIPTO_NO","")
			callpoint!.setColumnData("<<DISPLAY>>.SNAME",Translate!.getTranslation("AON_SAME"))
			callpoint!.setColumnData("<<DISPLAY>>.SADD1","")
			callpoint!.setColumnData("<<DISPLAY>>.SADD2","")
			callpoint!.setColumnData("<<DISPLAY>>.SADD3","")
			callpoint!.setColumnData("<<DISPLAY>>.SADD4","")
			callpoint!.setColumnData("<<DISPLAY>>.SCITY","")
			callpoint!.setColumnData("<<DISPLAY>>.SSTATE","")
			callpoint!.setColumnData("<<DISPLAY>>.SZIP","")
			callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID","")
			if ship_to_type$<>callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE") then
				rem --- Initialize for change
				callpoint!.setColumnData("OPE_ORDHDR.SLSPSN_CODE",custdet.slspsn_code$)
				callpoint!.setColumnData("OPE_ORDHDR.TERRITORY",custdet.territory$)
				callpoint!.setColumnData("OPE_ORDHDR.TAX_CODE",custdet.tax_code$)
				if cvs(custmast.ar_ship_via$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.AR_SHIP_VIA",custmast.ar_ship_via$,1)
				if cvs(custmast.shipping_id$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_ID",custmast.shipping_id$)
				if cvs(custmast.shipping_email$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_EMAIL",custmast.shipping_email$)
			endif
		endif

	else

		callpoint!.setColumnData("OPE_ORDHDR.SHIPTO_NO","")
		if ship_to_type$<>callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE") then
			if custdet.slspsn_code$<>callpoint!.getColumnData("OPE_ORDHDR.SLSPSN_CODE") or
:			custdet.territory$<>callpoint!.getColumnData("OPE_ORDHDR.TERRITORY") or
:			custdet.tax_code$<>callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE") or
:			(cvs(custmast.ar_ship_via$,2)<>"" and cvs(custmast.ar_ship_via$,2)<>callpoint!.getColumnData("OPE_ORDHDR.AR_SHIP_VIA")) or
:			(cvs(custmast.shipping_id$,2)<>"" and cvs(custmast.shipping_id$,2)<>callpoint!.getColumnData("OPE_ORDHDR.SHIPPING_ID")) or
:			(cvs(custmast.shipping_email$,2)<>"" and cvs(custmast.shipping_email$,2)<>callpoint!.getColumnData("OPE_ORDHDR.SHIPPING_EMAIL")) then
				msg_id$="OP_SHIPTO_CODE_CHGS"
				gosub disp_message

				rem --- Initialize for change
				callpoint!.setColumnData("OPE_ORDHDR.SLSPSN_CODE",custdet.slspsn_code$)
				callpoint!.setColumnData("OPE_ORDHDR.TERRITORY",custdet.territory$)
				callpoint!.setColumnData("OPE_ORDHDR.TAX_CODE",custdet.tax_code$)
				if cvs(custmast.ar_ship_via$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.AR_SHIP_VIA",custmast.ar_ship_via$,1)
				if cvs(custmast.shipping_id$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_ID",custmast.shipping_id$)
				if cvs(custmast.shipping_email$,2)<>"" then callpoint!.setColumnData("OPE_ORDHDR.SHIPPING_EMAIL",custmast.shipping_email$)
			endif
		endif

		ordship_dev=fnget_dev("OPE_ORDSHIP")
		dim ordship_tpl$:fnget_tpl$("OPE_ORDSHIP")
		invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
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

	disc_amt = num(callpoint!.getColumnData("OPE_ORDHDR.DISCOUNT_AMT"))
	freight_amt = num(callpoint!.getColumnData("OPE_ORDHDR.FREIGHT_AMT"))
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
check_lock_flag: rem --- Check manual record lock
                 rem     OUT: locked = 1 or 0
rem ==========================================================================

	locked=0

	switch pos( callpoint!.getColumnData("OPE_ORDHDR.LOCK_STATUS") = "NYS123" )
		case 1
			break

		case 2
			msg_id$="ORD_LOCKED"
			dim msg_tokens$[1]

			if callpoint!.getColumnData("OPE_ORDHDR.PRINT_STATUS")="B" then 
				msg_tokens$[1]=Translate!.getTranslation("AON__BY_BATCH_PRINTING")
				gosub disp_message

				if msg_opt$="Y"
					callpoint!.setColumnData("OPE_ORDHDR.LOCK_STATUS","N")
					callpoint!.setStatus("SAVE")
				else
					locked=1
				endif
			endif
			break

		case 3
			msg_id$="ORD_ON_REG"
			gosub disp_message
			locked=1
			break

		case 4
		case 5
			msg_id$="INVOICE_IN_UPDATE"
			gosub disp_message
			locked=1
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
copy_order: rem --- Duplicate or Credit Historical Invoice
            rem      IN: line_sign = 1/-1
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
		filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")+"'"
		filter_defs$[2,2]="LOCK"
		filter_defs$[3,0]="OPT_INVHDR.CUSTOMER_ID"
		filter_defs$[3,1]="='"+callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")+"'"
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

		msg_id$="OP_CREATE_QUOTE"
		gosub disp_message
		create_quote$=msg_opt$
		callpoint!.setDevObject("create_quote",create_quote$)

		rem --- Can't do Quote for Default Cash Customer
		if create_quote$="P" and callpoint!.getDevObject("defaultCustomer")="C" then
			msg_id$="OP_CASH_NOT_QUOTE"
			gosub disp_message
			copy_ok$="N"
			return
		endif

		rem --- Can't do Sale for POS Default Quote Customer
		if create_quote$="S" and callpoint!.getDevObject("defaultCustomer")="Q" then
			msg_id$="OP_QUOTE_NOT_SALE"
			gosub disp_message
			copy_ok$="N"
			return
		endif

		if line_sign=1 then 
			msg_id$ = "OP_REPRICE_ORD"
			gosub disp_message
			reprice$ = msg_opt$
		endif

		seq_id$=cvs(callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO"),2)
		if seq_id$="" then
			call stbl("+DIR_SYP")+"bas_sequences.bbj","ORDER_NO",seq_id$,rd_table_chans$[all]
		endif

		if seq_id$<>"" then 
			ope01_dev = fnget_dev("OPE_ORDHDR")
			dim ope01a$:fnget_tpl$("OPE_ORDHDR")
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
			ope01a.invoice_type$ = create_quote$
			ope01a.lock_status$ = "N"
			ope01a.order_date$     = sysinfo.system_date$
			ope01a.order_no$       = seq_id$
			ope01a.ordinv_flag$    = "O"
			ope01a.ord_taken_by$   = sysinfo.user_id$
			ope01a.print_status$   = "N"
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

			dim ope11a$:fnget_tpl$("OPE_ORDDET")
			ope11_dev=fnget_dev("OPE_ORDDET")

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
			line_no_mask$=callpoint!.getDevObject("line_no_mask")

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

				if create_quote$="P"
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
			read(ope11_dev,knum="AO_STAT_CUST_ORD",dom=*next); rem --- reset key to OPE_ORDDET form's key

			callpoint!.setStatus("RECORD:["+firm_id$+callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")+ope01a.ar_type$+ope01a.customer_id$+ope01a.order_no$+ope01a.ar_inv_no$+"]")
			user_tpl.hist_ord$ = "Y"

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

	inv_type$ = callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")

	call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",iv_files[all],ivs01a$,iv_info$[all],iv_refs$[all],iv_refs[all],table_chans$[all],status
	iv_info$[1] = wh_id$
	iv_info$[2] = item_id$
	iv_info$[3] = ls_id$
	iv_refs[0]  = qty

	while 1
		if pos(opc_linecode.line_type$="SP")=0 then break
		if opc_linecode.dropship$="Y" or inv_type$="P" then break; rem "Dropship or quote
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

	inv_type$ = callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")

	ope21_dev = fnget_dev("OPE_ORDLSDET")
	dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
	read (ope21_dev, key=firm_id$+ar_type$+cust$+ord$+invoice$+ord_seq$,knum="PRIMARY",dom=*next)

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
	read (ope21_dev, key="",knum="AO_STAT_CUST_ORD",dom=*next)

	return

rem ==========================================================================
pricing: rem --- Call Pricing routine
         rem      IN: ope11a$ - Order Detail record
         rem          seq_id$ - order number
         rem          ivm02_dev
         rem          ivs01_dev
rem ==========================================================================

	ope01_dev = fnget_dev("OPE_ORDHDR")
	dim ope01a$:fnget_tpl$("OPE_ORDHDR")

	ivm02_dev = fnget_dev("IVM_ITEMWHSE")
	dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")

	ivs01_dev = fnget_dev("IVS_PARAMS")
	dim ivs01a$:fnget_tpl$("IVS_PARAMS")

	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
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
disp_cust_comments: rem --- Display customer comment
                    rem      IN: cust_id$
rem ==========================================================================

	arm01_dev=fnget_dev("ARM_CUSTMAST")
	dim arm01a$:fnget_tpl$("ARM_CUSTMAST")
	read record (arm01_dev, key=firm_id$+cust_id$, dom=*next) arm01a$
	callpoint!.setColumnData("<<DISPLAY>>.comments", arm01a.memo_1024$,1)

	return

rem ==========================================================================
add_to_batch_print: rem --- Add to batch print file
                    rem      IN: order_no$
rem ==========================================================================

	ope_prntlist_dev = fnget_dev("OPE_PRNTLIST")
	dim ope_prntlist$:fnget_tpl$("OPE_PRNTLIST")

	ope_prntlist.firm_id$     = firm_id$
	ope_prntlist.ordinv_flag$ = "O"
	ope_prntlist.ar_type$     = "  "
	ope_prntlist.customer_id$ = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	ope_prntlist.order_no$    = order_no$
	ope_prntlist_key$=ope_prntlist.firm_id$+ope_prntlist.ordinv_flag$+ope_prntlist.ar_type$+ope_prntlist.customer_id$+ope_prntlist.order_no$
	rec_missing=1
	extractrecord(ope_prntlist_dev,key=ope_prntlist_key$,dom=*next); rec_missing=0
	if rec_missing then callpoint!.setDevObject("force_wolink_grid",1)

	ope_prntlist$ = field(ope_prntlist$)
	write record (ope_prntlist_dev) ope_prntlist$

	return

rem ==========================================================================
check_if_reprintable: rem --- Are There Reprintable Detail Lines? 
                      rem      IN: ar_type$
                      rem          cust_id$
                      rem          order_no$
                      rem     OUT: reprintable = 1/0 (stored in devObject)
rem ==========================================================================

	reprintable = 0
	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	
	ope11_dev = fnget_dev("OPE_ORDDET")
	dim ope11a$:fnget_tpl$("OPE_ORDDET")
	read (ope11_dev, key=firm_id$+trans_status$+ar_type$+cust_id$+order_no$, dom=*next)

	while 1
		read record (ope11_dev, end=*break) ope11a$
		if pos(firm_id$+trans_status$+ar_type$+cust_id$+order_no$ = ope11a.firm_id$+ope11a.trans_status$+ope11a.ar_type$+ope11a.customer_id$+ope11a.order_no$) <> 1 then break

		if ope11a.pick_flag$ = "Y" then 
			reprintable = 1
			break
		endif
	wend

	callpoint!.setDevObject("reprintable",reprintable)

	return 

rem ==========================================================================
do_credit_action: rem --- Launch the credit action program / form
                  rem     OUT: action$
rem ==========================================================================

	inv_type$ = callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")
	cust_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	action$   = "X"; rem Never called opc_creditaction.aon

rem --- Should we call Credit Action?

	if user_tpl.credit_installed$ = "Y" and inv_type$ <> "P" and cvs(cust_id$, 2) <> "" and cvs(order_no$, 2) <> "" and
:			(callpoint!.getColumnData("CREDIT_FLAG")<>"R" or (callpoint!.getColumnData("CREDIT_FLAG")="R" and user_tpl.credit_limit_warned))
		callpoint!.setColumnData("CREDIT_FLAG","");rem - let credit action form reset the credit flag
		callpoint!.setDevObject("run_by", "order")
		call user_tpl.pgmdir$+"opc_creditaction.aon", cust_id$, order_no$, invoice_no$, table_chans$[all], callpoint!, action$, status
		callpoint!.setStatus("ACTIVATE")
		if status = 999 then goto std_exit

		if action$ = "D" then 
			rem --- Delete the order
			callpoint!.setStatus("DELETE-NEWREC")
			return
		endif

		if action$="R" then
			rem --- Order released
			callpoint!.setDevObject("msg_released","Y")
			callpoint!.setDevObject("msg_hold","")
			call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!
		endif

		if action$="H" then
			rem --- Order held
			callpoint!.setDevObject("msg_hold","Y")
			call user_tpl.pgmdir$+"opc_creditmsg.aon","H",callpoint!,UserObj!
		endif
	else
		action$ = "U"
	endif

	return

rem ==========================================================================
do_picklist: rem --- Print a Pick List
rem ==========================================================================
 
	cp_cust_id$=callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	cp_order_no$=callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	cp_invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[3,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=cp_cust_id$
	dflt_data$[2,0]="ORDER_NO"
	dflt_data$[2,1]=cp_order_no$
	dflt_data$[3,0]="INVOICE_TYPE"
	dflt_data$[3,1]=callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPR_ODERPICKDMD",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]	

	return

rem ==========================================================================
print_quote: rem --- Print Quotation
rem IN: customer_id$
rem IN: order_no$
rem ==========================================================================
	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[3,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=customer_id$
	dflt_data$[2,0]="ORDER_NO"
	dflt_data$[2,1]=order_no$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPR_QUOTES_DMD",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]	

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
	callpoint!.setColumnData("OPE_ORDHDR.COMM_PERCENT", salecode_rec.comm_rate$)

	return

rem ==========================================================================
get_disk_rec: rem --- Get disk record, update with current form data
              rem     OUT: found - true/false (1/0)
              rem          ordhdr_rec$, updated (if record found)
              rem          ordhdr_dev
rem ==========================================================================

	file_name$  = "OPE_ORDHDR"
	ordhdr_dev  = fnget_dev(file_name$)
	ordhdr_tpl$ = fnget_tpl$(file_name$)
	dim ordhdr_rec$:ordhdr_tpl$

	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	cust_id$  = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")

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
	ttl_ext_price = num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES"))
	ttl_ext_cost = num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_COST"))
	tax_amt = num(callpoint!.getColumnData("OPE_ORDHDR.TAX_AMOUNT"))
	sub_tot = ttl_ext_price - disc_amt
	net_sales = sub_tot + tax_amt + freight_amt

	callpoint!.setColumnData("OPE_ORDHDR.TOTAL_COST",str(ttl_ext_cost),1)
	callpoint!.setColumnData("OPE_ORDHDR.DISCOUNT_AMT",str(disc_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.SUBTOTAL", str(sub_tot),1)
	callpoint!.setColumnData("<<DISPLAY>>.NET_SALES", str(net_sales),1)
	callpoint!.setColumnData("OPE_ORDHDR.FREIGHT_AMT",str(freight_amt),1)
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
	tax_code$=callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE")
	gosub usingTaxService

	if eventFrom$="OPE_ORDHDR.AOPT-RTAX" or (num(callpoint!.getColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC"))=1 and 
:		(isTotalsTab or pos(eventFrom$="OPE_ORDHDR.ADIS:OPE_ORDHDR.BWAR")))

		rem --- Get current form data for tax calculation
		ordhdr_dev=fnget_dev("OPE_ORDHDR")
		ordhdr_tpl$=fnget_tpl$("OPE_ORDHDR")
		dim ordhdr_rec$:ordhdr_tpl$
		ordhdr_rec$ = util.copyFields(ordhdr_tpl$, callpoint!)
		ordhdr_rec$ = field(ordhdr_rec$)
		ordhdr_rec.discount_amt=disc_amt
		ordhdr_rec.freight_amt=freight_amt

		if callpoint!.getDevObject("use_tax_service")="Y" then
			rem --- Use sales tax service
			salesTax!=callpoint!.getDevObject("salesTaxObject")
			success=0
			taxProps!=salesTax!.calculateTax(ordhdr_rec$,"SalesOrder",err=*next); success=1
			if !success then
				rem --- Sales tax calculation failed
				callpoint!.setColumnData("OPE_ORDHDR.TAX_AMOUNT","0",1)
				callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(1),1)

				taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
				taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
				taxAmount_warn!.setVisible(1)
				taxAmount_fnote!.setVisible(1)

				msg_id$="OP_TAX_CALC_FAILED"
				dim msg_tokens$[1]
				msg_tokens$[1] = Translate!.getTranslation("AON_ORDER")
				gosub disp_message
			else
				callpoint!.setColumnData("OPE_ORDHDR.TAX_AMOUNT",taxProps!.getProperty("tax_amount"),1)
				callpoint!.setColumnData("OPE_ORDHDR.TAXABLE_AMT",taxProps!.getProperty("taxable_amt"),1)
				callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(0),1)
				callpoint!.setDevObject("commit_sls_tax","Y")

				taxAmount_warn!=callpoint!.getDevObject("taxAmount_warn")
				taxAmount_fnote!=callpoint!.getDevObject("taxAmount_fnote")
				taxAmount_warn!.setVisible(0)
				taxAmount_fnote!.setVisible(0)

				rem --- Force write if not in Edit mode.
				if !callpoint!.isEditMode() then gosub forceWrite
			endif
		else
			if cvs(callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE"),2) <> "" then
				ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
				ordHelp!.setTaxCode(callpoint!.getColumnData("OPE_ORDHDR.TAX_CODE"))
				taxable_sales = num(ordHelp!.getTaxableSales())
				taxAndTaxableVect! = ordHelp!.calculateTax(disc_amt, freight_amt,taxable_sales,
:					num(callpoint!.getColumnData("OPE_ORDHDR.TOTAL_SALES")))

				tax_amount = taxAndTaxableVect!.getItem(0)
				taxable_amt = taxAndTaxableVect!.getItem(1)

				callpoint!.setColumnData("OPE_ORDHDR.TAX_AMOUNT",str(tax_amount),1)
				callpoint!.setColumnData("OPE_ORDHDR.TAXABLE_AMT",str(taxable_amt),1)
				callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(0),1)
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
		if !isTotalsTab and pos(eventFrom$="OPE_ORDHDR.ADIS:OPE_ORDHDR.BWAR")=0 then
			callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(1),1)
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
		if user_tpl.cash_sale$<>"Y" or callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID") <> user_tpl.cash_cust$
			msg_id$ = "OP_MAN_SHIPTO_NEEDED"
			gosub disp_message
			user_tpl.shipto_warned = 1
		endif
	endif

	if user_tpl.shipto_warned
		shiptoType!=callpoint!.getControl("OPE_ORDHDR.SHIPTO_TYPE")
		shiptoType_ctx=shiptoType!.getContextID()
		sysgui!.setContext(shiptoType_ctx)
		callpoint!.setFocus("OPE_ORDHDR.SHIPTO_TYPE")
	endif
		
	return

rem ==========================================================================
disable_shipto: rem --- Disable Ship To fields
rem IN: ship_to_type$
rem ==========================================================================

	declare BBjVector column!
	column! = BBjAPI().makeVector()
	
	column!.addItem("OPE_ORDHDR.SHIPTO_NO")
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
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	if tabCtrl!.getSelectedIndex() = tabCtrl!.getNumTabs()-1 then isTotalsTab=1; rem --- Last tab is the Totals tab

	return

rem ==========================================================================
forceWrite: rem --- Force write if not in Edit mode.
rem IN: firm_id$
rem IN: customer_id$
rem IN: order_no$
rem IN: ar_inv_no$
rem IN: ordhdr_dev
rem IN: ordhdr_rec$ from util.copyFields(ordhdr_tpl$, callpoint!)
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
			ordhdr_rec.tax_amount$=callpoint!.getColumnData("OPE_ORDHDR.TAX_AMOUNT")
			ordhdr_rec.taxable_amt$=callpoint!.getColumnData("OPE_ORDHDR.TAXABLE_AMT")
			ordhdr_rec.no_sls_tax_calc=num(callpoint!.getColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC"))
			write record (ordhdr_dev) ordhdr_rec$
			callpoint!.setStatus("SETORIG")

			rem --- Remove temporary soft lock
			lock_type$="U"
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		else
			rem --- Record locked by someone else
			callpoint!.setColumnData("OPE_ORDHDR.TAX_AMOUNT","0")
			callpoint!.setColumnData("OPE_ORDHDR.NO_SLS_TAX_CALC",str(1))

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
do_order_conf: rem --- Generate order confirmation
rem IN: customer_id$
rem IN: order_no$
rem ==========================================================================

rem --- launch option entry form to generate confirmation

	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[3,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=customer_id$
	dflt_data$[2,0]="ORDER_NO"
	dflt_data$[2,1]=order_no$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPR_ORDCONF_DMD",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]	

	return

rem ==========================================================================
getOrdAckRecs: rem --- Capture order records used for the Acknowledgement
rem IN: - none -
rem OUT: ackRecsMap! (set in DevObject "ackRecsMap")
rem ==========================================================================
	ackRecsMap!=new java.util.HashMap()

	rem --- Capture order header record
	ope01_dev = fnget_dev("OPE_ORDHDR")
	dim ope01a$:fnget_tpl$("OPE_ORDHDR")
	trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
	ar_type$ = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
	cust_id$ = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	ope01_key$=firm_id$+trans_status$+ar_type$+cust_id$+order_no$+invoice_no$
	readrecord(ope01_dev, key=ope01_key$, dom=*next)ope01a$
	ackRecsMap!.put(ope01_key$,ope01a$)

	rem --- Capture order detail  and lot/serial records
	ope11_dev = fnget_dev("OPE_ORDDET")
	dim ope11a$:fnget_tpl$("OPE_ORDDET")
	ope21_dev = fnget_dev("OPE_ORDLSDET")
	dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
	read(ope11_dev,key=ope01_key$,dom=*next)
	while 1
		ope11_key$=key(ope11_dev,end=*break)
		if pos(ope01_key$=ope11_key$)<>1 then break
		readrecord(ope11_dev)ope11a$
		ackRecsMap!.put(ope11_key$,ope11a$)

		rem --- Capture lot/serial records
		ope21_trip$=firm_id$+ar_type$+cust_id$+order_no$+invoice_no$+ope11a.internal_seq_no$
		read(ope21_dev,key=ope21_trip$,knum="PRIMARY",dom=*next)
		while 1
			ope21_key$=key(ope21_dev,end=*break)
			if pos(ope21_trip$=ope21_key$)<>1 then break
			readrecord(ope21_dev)ope21a$
			ackRecsMap!.put(ope21_key$,ope21a$)
		wend
		read(ope21_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next)
	wend

	callpoint!.setDevObject("ackRecsMap",ackRecsMap!)

	return

rem ==========================================================================
ordChangedForAck: rem --- Has the Order changed since Acknowledgement was printed?
rem IN: - none -
rem OUT: orderChanged
rem ==========================================================================
	if  pos("M"=callpoint!.getRecordStatus()) then
		orderChanged=1
	else
		orderChanged=0
		if callpoint!.getColumnData("OPE_ORDHDR.ORD_CONF_PRINTED")="Y" then
			ackRecsMap!=callpoint!.getDevObject("ackRecsMap")

			rem --- Check order header record
			ope01_dev = fnget_dev("OPE_ORDHDR")
			dim ope01a$:fnget_tpl$("OPE_ORDHDR")
			trans_status$=callpoint!.getColumnData("OPE_ORDHDR.TRANS_STATUS")
			ar_type$ = callpoint!.getColumnData("OPE_ORDHDR.AR_TYPE")
			cust_id$ = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
			order_no$ = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
			invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
			ope01_key$=firm_id$+trans_status$+ar_type$+cust_id$+order_no$+invoice_no$
			if !ackRecsMap!.containsKey(ope01_key$) then
				orderChanged=1
			else
				ackRec!=ackRecsMap!.get(ope01_key$)
				readrecord(ope01_dev,key=ope01_key$)ope01a$
				if ope01a$<>ackRec! then
					orderChanged=1
				else
					rem --- Check order detail  and lot/serial records
					ope11_dev = fnget_dev("OPE_ORDDET")
					dim ope11a$:fnget_tpl$("OPE_ORDDET")
					ope21_dev = fnget_dev("OPE_ORDLSDET")
					dim ope21a$:fnget_tpl$("OPE_ORDLSDET")
					read(ope11_dev,key=ope01_key$,dom=*next)
					while 1
						ope11_key$=key(ope11_dev,end=*break)
						if pos(ope01_key$=ope11_key$)<>1 then break
						if !ackRecsMap!.containsKey(ope11_key$) then
							orderChanged=1
							break
						else
							ackRec!=ackRecsMap!.get(ope11_key$)
							readrecord(ope11_dev)ope11a$
							if ope11a$<>ackRec! then
								orderChanged=1
								break
							else
								rem --- Check lot/serial records
								ope21_trip$=firm_id$+ar_type$+cust_id$+order_no$+invoice_no$+ope11a.internal_seq_no$
								read(ope21_dev,key=ope21_trip$,knum="PRIMARY",dom=*next)
								while 1
									ope21_key$=key(ope21_dev,end=*break)
									if pos(ope21_trip$=ope21_key$)<>1 then break
									if !ackRecsMap!.containsKey(ope21_key$) then
										orderChanged=1
										break
									else
										ackRec!=ackRecsMap!.get(ope21_key$)
										readrecord(ope21_dev)ope21a$
										if ope21a$<>ackRec! then
											orderChanged=1
											break
										endif
									endif
								wend
								read(ope21_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next)
								if orderChanged then break
							endif
						endif
					wend
				endif
			endif
		endif
	endif

	return

rem ==========================================================================
write_address_file: rem --- Write Order Addresses file
rem IN: - none -
rem OUT: - none -
rem ==========================================================================
	cust_id$    = callpoint!.getColumnData("OPE_ORDHDR.CUSTOMER_ID")
	order_no$   = callpoint!.getColumnData("OPE_ORDHDR.ORDER_NO")
	invoice_no$=callpoint!.getColumnData("OPE_ORDHDR.AR_INV_NO")
	ordship_dev = fnget_dev("OPE_ORDSHIP")

	rem --- Capture Bill-To address
	dim ordship_tpl$:fnget_tpl$("OPE_ORDSHIP")
	extract record (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"B", dom=*next) ordship_tpl$; rem Advisory Locking
	ordship_tpl.firm_id$     = firm_id$
	ordship_tpl.customer_id$ = cust_id$
	ordship_tpl.order_no$    = order_no$
	ordship_tpl.ar_inv_no$=invoice_no$
	ordship_tpl.address_type$ = "B"
	ordship_tpl.name$ = ""
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
	
	if callpoint!.getColumnData("OPE_ORDHDR.SHIPTO_TYPE") = "B" then 
		rem --- Ship-to address is the same as the bill-to address
		extract record (ordship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*next) ordship_tpl$; rem Advisory Locking
		ordship_tpl.address_type$ = "S"
		ordship_tpl.name$ = Translate!.getTranslation("AON_SAME")
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
orderType_display: rem --- Refresh orderType_label
rem ==========================================================================
	orderType_label!=callpoint!.getDevObject("orderType_label")
	if callpoint!.getColumnData("OPE_ORDHDR.INVOICE_TYPE")="P" then
		rem --- This Order is a Quote
		orderType_label!.setText("Quote")
	 	orderType_label!.setForeColor(BBjColor.RED)
		orderType_label!.setVisible(1)
	else
		rem --- This Order is a Sale
		orderType_label!.setText("Sale")
		orderType_label!.setForeColor(callpoint!.getDevObject("colorGreen"))
		orderType_label!.setVisible(1)
	endif

	return



