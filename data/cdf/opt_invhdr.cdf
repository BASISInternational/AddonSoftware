[[OPT_INVHDR.ACUS]]
rem --- Process custom event -- used in this pgm to select/de-select checkboxes in grid
rem --- See basis docs notice() function, noticetpl() function, notify event, grid control notify events for more info
rem --- This routine is executed when callbacks have been set to run a 'custom event'
rem --- Analyze gui_event$ and notice$ to see which control's callback triggered the event, and what kind
rem --- of event it is... in this case, we're toggling checkboxes on/off in form grid control

	dim gui_event$:tmpl(gui_dev)
	dim notify_base$:noticetpl(0,0)
	gui_event$=SysGUI!.getLastEventString()
	ev!=BBjAPI().getLastEvent()

	if ev!.getEventName()="BBjTimerEvent" and gui_event.y=10000
		BBjAPI().removeTimer(10000)
		highlightBillTo=callpoint!.getDevObject("highlightBillTo")
		highlightShipTo=callpoint!.getDevObject("highlightSipTo")

		if highlightBillto then
			valRGB!=SysGUI!.makeColor(255,255,102); rem --- yellow
			badd1!=callpoint!.getControl("<<DISPLAY>>.BADD1")
			badd1!.setBackColor(valRGB!)

			badd2!=callpoint!.getControl("<<DISPLAY>>.BADD2")
			badd2!.setBackColor(valRGB!)

			badd3!=callpoint!.getControl("<<DISPLAY>>.BADD3")
			badd3!.setBackColor(valRGB!)

			badd4!=callpoint!.getControl("<<DISPLAY>>.BADD4")
			badd4!.setBackColor(valRGB!)

			bcity!=callpoint!.getControl("<<DISPLAY>>.BCITY")
			bcity!.setBackColor(valRGB!)

			bstate!=callpoint!.getControl("<<DISPLAY>>.BSTATE")
			bstate!.setBackColor(valRGB!)

			bzip!=callpoint!.getControl("<<DISPLAY>>.BZIP")
			bzip!.setBackColor(valRGB!)

			bcntry_id!=callpoint!.getControl("<<DISPLAY>>.BCNTRY_ID")
			bcntry_id!.setBackColor(valRGB!)
		endif

		if highlightShipto then
			valRGB!=SysGUI!.makeColor(255,255,102); rem --- yellow
			sname!=callpoint!.getControl("<<DISPLAY>>.SNAME")
			sname!.setBackColor(valRGB!)

			sadd1!=callpoint!.getControl("<<DISPLAY>>.SADD1")
			sadd1!.setBackColor(valRGB!)

			sadd2!=callpoint!.getControl("<<DISPLAY>>.SADD2")
			sadd2!.setBackColor(valRGB!)

			sadd3!=callpoint!.getControl("<<DISPLAY>>.SADD3")
			sadd3!.setBackColor(valRGB!)

			sadd4!=callpoint!.getControl("<<DISPLAY>>.SADD4")
			sadd4!.setBackColor(valRGB!)

			scity!=callpoint!.getControl("<<DISPLAY>>.SCITY")
			scity!.setBackColor(valRGB!)

			sstate!=callpoint!.getControl("<<DISPLAY>>.SSTATE")
			sstate!.setBackColor(valRGB!)

			szip!=callpoint!.getControl("<<DISPLAY>>.SZIP")
			szip!.setBackColor(valRGB!)

			scntry_id!=callpoint!.getControl("<<DISPLAY>>.SCNTRY_ID")
			scntry_id!.setBackColor(valRGB!)
		endif
	endif

[[OPT_INVHDR.ADIS]]
rem --- Display invoice total

	net_sales=num(callpoint!.getColumnData("OPT_INVHDR.TOTAL_SALES"))-
:			  num(callpoint!.getColumnData("OPT_INVHDR.DISCOUNT_AMT"))+
:			  num(callpoint!.getColumnData("OPT_INVHDR.TAX_AMOUNT"))+
:			  num(callpoint!.getColumnData("OPT_INVHDR.FREIGHT_AMT"))

	callpoint!.setColumnData("<<DISPLAY>>.ORDER_TOT",str(net_sales),1)

rem --- Enable SHPT additional options if shipment tracking info exists
	optShipTrack_dev = fnget_dev("OPT_SHIPTRACK")
	ar_type$=callpoint!.getColumnData("OPT_INVHDR.AR_TYPE")
	ship_seq_no$=callpoint!.getColumnData("OPT_INVHDR.SHIP_SEQ_NO")
	trip_key$=firm_id$+ar_type$+cust_id$+order_no$+ship_seq_no$
	read(optShipTrack_dev,key=trip_key$,dom=*next)
	optShipTrack_key$=key(optShipTrack_dev,end=*next)
	if pos(trip_key$=optShipTrack_key$)=1 then
		callpoint!.setOptionEnabled("SHPT",1)
	else
		callpoint!.setOptionEnabled("SHPT",0)
	endif

rem --- Enable Print button for this record
	callpoint!.setOptionEnabled("PRNT",1)

rem --- Display bill-to and ship-to information
	cust_id$ = callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID")
	ship_to_type$ = callpoint!.getColumnData("OPT_INVHDR.SHIPTO_TYPE")
	ship_to_no$    = callpoint!.getColumnData("OPT_INVHDR.SHIPTO_NO")
	order_no$       = callpoint!.getColumnData("OPT_INVHDR.ORDER_NO")
	invoice_no$     = callpoint!.getColumnData("OPT_INVHDR.AR_INV_NO")
	gosub display_customer
	gosub ship_to_info

	if highlightBillTo or highlightShipTo then
		callpoint!.setDevObject("highlightBillTo",highlightBillTo)
		callpoint!.setDevObject("highlightSipTo",highlightShipTo)
		timerKey=10000
		waitTime=0.1
		BBjAPI().createTimer(timerKey,waitTime,"custom_event")
	endif

[[OPT_INVHDR.AFMC]]
rem --- Inits

	use ::ado_util.src::util
	use ::ado_order.src::OrderHelper
	use ::adc_array.aon::ArrayObject

[[OPT_INVHDR.AOPT-CART]]
rem --- Launch Order Fulfillment's Historical Carton Packing grid
	ar_type$=callpoint!.getColumnData("OPT_INVHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_INVHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPT_INVHDR.AR_INV_NO")
	key_pfx$=firm_id$+ar_type$+customer_id$+order_no$+ar_inv_no$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"OPT_CARTDETHIST",
:       stbl("+USER_ID"),
:       "QRY",
:       key_pfx$,
:       table_chans$[all]

[[OPT_INVHDR.AOPT-PRNT]]
rem --- historical invoice
 
	cp_cust_id$=callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID")
	cp_order_no$=callpoint!.getColumnData("OPT_INVHDR.ORDER_NO")
	cp_invoice_no$=callpoint!.getColumnData("OPT_INVHDR.AR_INV_NO")
	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[3,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=cp_cust_id$
	dflt_data$[2,0]="ORDER_NO"
	dflt_data$[2,1]=cp_order_no$
	dflt_data$[3,0]="AR_INV_NO"
	dflt_data$[3,1]=cp_invoice_no$
 
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPR_HIST_INV",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]

	callpoint!.setStatus("ACTIVATE")

[[OPT_INVHDR.AOPT-SHPT]]
rem --- Launch Shipment Tracking grid (view only)
	ar_type$=callpoint!.getColumnData("OPT_INVHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_INVHDR.ORDER_NO")
	ship_seq_no$=callpoint!.getColumnData("OPT_INVHDR.SHIP_SEQ_NO")
	key_pfx$=firm_id$+ar_type$+customer_id$+order_no$+ship_seq_no$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"OPT_SHIPTRACK",
:       stbl("+USER_ID"),
:       "QRY",
:       key_pfx$,
:       table_chans$[all]

[[OPT_INVHDR.AOPT-STAX]]
rem --- Launch Sales Tax Trans History form
	customer_id$=callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_INVHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPT_INVHDR.AR_INV_NO")
	key_pfx$=firm_id$+customer_id$+order_no$+ar_inv_no$+"001"

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"OPT_SLSTAXTRANS",
:       stbl("+USER_ID"),
:       "QRY",
:       key_pfx$,
:       table_chans$[all]

[[OPT_INVHDR.APFE]]
rem --- Enable SHPT additional options if shipment tracking info exists
	optShipTrack_dev = fnget_dev("OPT_SHIPTRACK")
	ar_type$=callpoint!.getColumnData("OPT_INVHDR.AR_TYPE")
	ship_seq_no$=callpoint!.getColumnData("OPT_INVHDR.SHIP_SEQ_NO")
	trip_key$=firm_id$+ar_type$+cust_id$+order_no$+ship_seq_no$
	read(optShipTrack_dev,key=trip_key$,dom=*next)
	optShipTrack_key$=key(optShipTrack_dev,end=*next)
	if pos(trip_key$=optShipTrack_key$)=1 then
		callpoint!.setOptionEnabled("SHPT",1)
	else
		callpoint!.setOptionEnabled("SHPT",0)
	endif

rem --- Enable Print button
	if cvs(callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID"),3)<>"" and cvs(callpoint!.getColumnData("OPT_INVHDR.ORDER_NO"),3)<>"" and cvs(callpoint!.getColumnData("OPT_INVHDR.AR_INV_NO"),3)<>""
		callpoint!.setOptionEnabled("PRNT",1)
	endif

[[OPT_INVHDR.ARAR]]
rem --- Disable additional options for now
	callpoint!.setOptionEnabled("SHPT",0)

[[OPT_INVHDR.AREC]]
rem --- Disable Print button when no record displayed
	callpoint!.setOptionEnabled("PRNT",0)

[[OPT_INVHDR.AR_INV_NO.AVAL]]
rem --- If missing, set the customer for this invoice.
	if cvs(callpoint!.getColumnData("OPT_INVHDR.CUSTOMER_ID"),3)="" then
		opt_invhdr_dev = fnget_dev("OPT_INVHDR")
		dim opt_invhdr$:fnget_tpl$("OPT_INVHDR")
		ar_inv_no$=callpoint!.getUserInput()

		rem --- Find customer for this historical invioce
		customer_id$=""
		read(opt_invhdr_dev,key=firm_id$+"  "+ar_inv_no$,knum="AO_INV_CUST",dom=*next)
		while 1
			readrecord(opt_invhdr_dev,end=*break)opt_invhdr$
			if opt_invhdr.firm_id$+opt_invhdr.ar_type$+opt_invhdr.ar_inv_no$<>firm_id$+"  "+ar_inv_no$ then break
			if opt_invhdr.trans_status$<>"U" then continue
			callpoint!.setColumnData("OPT_INVHDR.CUSTOMER_ID",opt_invhdr.customer_id$,1)
			break
		wend

		rem --- Reset index back to AO_STAT_CUST_INV.
		read(opt_invhdr_dev,key=firm_id$,knum="AO_STAT_CUST_INV",dom=*next)
	endif

[[OPT_INVHDR.ASVA]]
rem --- Enable Print button when leave edit mode
	callpoint!.setOptionEnabled("PRNT",1)

[[OPT_INVHDR.BPFX]]
rem --- Disable additional options for now
	callpoint!.setOptionEnabled("SHPT",0)
	callpoint!.setOptionEnabled("PRNT",0)

[[OPT_INVHDR.BSHO]]
rem --- Open needed files

	num_files=40
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]

	open_tables$[1]="ARM_CUSTMAST",  open_opts$[1]="OTA"
	open_tables$[2]="ARM_CUSTSHIP",  open_opts$[2]="OTA"
	open_tables$[4]="ARS_PARAMS",    open_opts$[4]="OTA"
	open_tables$[5]="ARM_CUSTDET",   open_opts$[5]="OTA"
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
	open_tables$[26]="OPT_INVSHIP",  open_opts$[26]="OTA"
	open_tables$[28]="IVC_WHSECODE", open_opts$[28]="OTA"
	open_tables$[29]="IVS_PARAMS",   open_opts$[29]="OTA"
	open_tables$[31]="IVM_ITEMPRIC", open_opts$[31]="OTA"
	open_tables$[32]="IVC_PRICCODE", open_opts$[32]="OTA"
	rem open_tables$[33]="", open_opts$[33]=""
	open_tables$[35]="OPM_POINTOFSALE", open_opts$[35]="OTA"
	open_tables$[36]="ARC_SALECODE", open_opts$[36]="OTA"
	open_tables$[37]="OPC_DISCCODE", open_opts$[37]="OTA"
	open_tables$[38]="OPC_TAXCODE",  open_opts$[38]="OTA"
	open_tables$[39]="OPT_SHIPTRACK",  open_opts$[39]="OTA"
	open_tables$[40]="IVC_PRODCODE",  open_opts$[40]="OTA"
	
gosub open_tables

rem --- Set table_chans$[all] into util object for getDev() and getTmpl()

	declare ArrayObject tableChans!

	call stbl("+DIR_PGM")+"adc_array.aon::str_array2object", table_chans$[all], tableChans!, status
	if status = 999 then goto std_exit
	util.setTableChans(tableChans!)

rem --- get AR Params

	dim ars01a$:open_tpls$[4]
	read record (num(open_chans$[4]), key=firm_id$+"AR00") ars01a$

	dim ars_credit$:open_tpls$[7]
	read record (num(open_chans$[7]), key=firm_id$+"AR01") ars_credit$

rem --- get IV Params

	dim ivs01a$:open_tpls$[29]
	read record (num(open_chans$[29]), key=firm_id$+"IV00") ivs01a$

	callpoint!.setDevObject("sell_purch_um",ivs01a.sell_purch_um$)

rem --- See if blank warehouse exists

	blank_whse$ = "N"
	dim ivm10c$:open_tpls$[28]
	start_block = 1
	
	if start_block then
		read record (num(open_chans$[28]), key=firm_id$+"C"+ivm10c.warehouse_id$, dom=*endif) ivm10c$
		blank_whse$ = "Y"
	endif

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
		column!.addItem("OPT_INVHDR.JOB_NO")
	endif

	callpoint!.setColumnEnabled(column!, -1)

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

	callpoint!.setColumnEnabled(column!, -1)

rem --- Save display control objects

rem	UserObj!.addItem( util.getControl(callpoint!, "<<DISPLAY>>.ORDER_TOT") )

rem --- Setup user_tpl$
    
	tpl$ = 
:		"credit_installed:c(1), " +
:		"balance:n(15), " +
:		"credit_limit:n(15), " +
:		"display_bal:c(1), " +
:		"ord_tot:n(15), " +
:		"def_ship:c(8), " + 
:		"def_commit:c(8), " +
:		"blank_whse:c(1), " +
:		"line_code:c(1), " +
:		"line_type:c(1), " +
:		"dropship_whse:c(1), " +
:		"def_whse:c(10), " +
:     "avail_oh:u(1), " +
:     "avail_comm:u(1), " +
:     "avail_avail:u(1), " +
:     "avail_oo:u(1), " +
:     "avail_wh:u(1), " +
:     "avail_type:u(1), " +
:     "dropship_flag:u(1), " +
:		"manual_price:u(1), " +
:     "ord_tot_obj:u(1), " +
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
:		"prod_type_col:u(1), " +
:		"allow_bo:c(1), " +
:		"amount_mask:c(1*)," +
:		"line_taxable:c(1), " +
:		"item_taxable:c(1), " +
:		"min_line_amt:n(5), " +
:		"min_ord_amt:n(5), " +
:		"item_price:n(15), " +
:		"line_dropship:c(1), " +
:		"dropship_cost:c(1), " +
:		"new_detail:u(1), " +
:		"prev_line_code:c(1*), " +
:		"prev_item:c(1*), " +
:		"prev_qty_ord:n(15), " +
:		"prev_boqty:n(15), " +
:		"prev_shipqty:n(15), " +
:		"prev_ext_price:n(15), " +
:		"prev_taxable:n(15), " +
:		"prev_ext_cost:n(15), " +
:     "prev_disc_code:c(1*), "+
:     "prev_ship_to:c(1*), " +
:		"prev_sales_total:n(15), " +
:		"prev_unitprice:n(15), " +
:		"detail_modified:u(1), " +
:		"item_wh_failed:u(1), " +
:		"do_end_of_form:u(1), " +
:		"picklist_warned:u(1)"

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
	user_tpl.item_wh_failed    = 1
	user_tpl.do_end_of_form    = 1
	user_tpl.picklist_warned   = 0

rem --- Columns for the util disableCell() method

	user_tpl.bo_col            = 9
	user_tpl.prod_type_col     = 1

	user_tpl.prev_line_code$   = ""
	user_tpl.prev_item$        = ""
	user_tpl.prev_qty_ord      = 0
	user_tpl.prev_boqty        = 0
	user_tpl.prev_shipqty      = 0
	user_tpl.prev_ext_price    = 0; rem used in detail section to hold the line extension 
	user_tpl.prev_taxable      = 0
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
	user_tpl.ord_tot_obj   = 10; rem set here in BSHO

rem --- Parse table_chans$[all] into an object

	declare ArrayObject tableChans!

	call pgmdir$+"adc_array.aon::str_array2object", table_chans$[all], tableChans!, status
	util.setTableChans(tableChans!)

[[OPT_INVHDR.MEMO_1024.BINP]]
rem --- Disable Print button when in edit mode (this is the only editable field)
	callpoint!.setOptionEnabled("PRNT",0)

[[OPT_INVHDR.<CUSTOM>]]
rem ==========================================================================
display_customer: rem --- Get and display Bill To Information
              rem     IN: cust_id$
              rem          order_no$
              rem          invoice_no$
              rem  OUT: highlightBillTo
rem ==========================================================================

	highlightBillTo=0
	invship_dev = fnget_dev("OPT_INVSHIP")
	dim invship_tpl$:fnget_tpl$("OPT_INVSHIP")
	find record (invship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"B", dom=*next) invship_tpl$
	if cvs(invship_tpl.customer_id$,2)<>"" then
		rem --- Use the invoice historical bill-to info when available
		callpoint!.setColumnData("<<DISPLAY>>.BADD1",invship_tpl.addr_line_1$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BADD2",invship_tpl.addr_line_2$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BADD3",invship_tpl.addr_line_3$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BADD4",invship_tpl.addr_line_4$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BCITY",invship_tpl.city$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BSTATE",invship_tpl.state_code$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BZIP",invship_tpl.zip_code$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BCNTRY_ID",invship_tpl.cntry_id$,1)
	else
		custmast_dev = fnget_dev("ARM_CUSTMAST")
		dim custmast_tpl$:fnget_tpl$("ARM_CUSTMAST")
		find record (custmast_dev, key=firm_id$+cust_id$,dom=*next) custmast_tpl$
		callpoint!.setColumnData("<<DISPLAY>>.BADD1",  custmast_tpl.addr_line_1$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BADD2",  custmast_tpl.addr_line_2$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BADD3",  custmast_tpl.addr_line_3$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BADD4",  custmast_tpl.addr_line_4$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BCITY",  custmast_tpl.city$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BSTATE", custmast_tpl.state_code$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BZIP",   custmast_tpl.zip_code$,1)
		callpoint!.setColumnData("<<DISPLAY>>.BCNTRY_ID",   custmast_tpl.cntry_id$,1)
		highlightBillTo=1
	endif

	return

rem ==========================================================================
ship_to_info: rem --- Get and display Ship To Information
              rem     IN: cust_id$
              rem          ship_to_type$
              rem          ship_to_no$
              rem          order_no$
              rem          invoice_no$
              rem  OUT: highlightShipTo
rem ==========================================================================

	highlightShipTo=0
	if ship_to_type$="B" then
		callpoint!.setColumnData("<<DISPLAY>>.SNAME",Translate!.getTranslation("AON_SAME"),1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD1","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD2","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD3","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SADD4","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SCITY","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SSTATE","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SZIP","",1)
		callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID","",1)
		if highlightBillTo then highlightShipTo=1
	else
		invship_dev = fnget_dev("OPT_INVSHIP")
		dim invship_tpl$:fnget_tpl$("OPT_INVSHIP")
		find record (invship_dev, key=firm_id$+cust_id$+order_no$+invoice_no$+"S", dom=*next) invship_tpl$
		if cvs(invship_tpl.customer_id$,2)<>"" or ship_to_type$="M" then
			rem --- Use the invoice historical ship-to info when available
			callpoint!.setColumnData("<<DISPLAY>>.SNAME",invship_tpl.name$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD1",invship_tpl.addr_line_1$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD2",invship_tpl.addr_line_2$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD3",invship_tpl.addr_line_3$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD4",invship_tpl.addr_line_4$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SCITY",invship_tpl.city$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SSTATE",invship_tpl.state_code$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SZIP",invship_tpl.zip_code$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID",invship_tpl.cntry_id$,1)
		else
			custship_dev = fnget_dev("ARM_CUSTSHIP")
			dim custship_tpl$:fnget_tpl$("ARM_CUSTSHIP")
			find record (custship_dev, key=firm_id$+cust_id$+ship_to_no$, dom=*next) custship_tpl$
			callpoint!.setColumnData("<<DISPLAY>>.SNAME",custship_tpl.name$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD1",custship_tpl.addr_line_1$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD2",custship_tpl.addr_line_2$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD3",custship_tpl.addr_line_3$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SADD4",custship_tpl.addr_line_4$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SCITY",custship_tpl.city$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SSTATE",custship_tpl.state_code$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SZIP",custship_tpl.zip_code$,1)
			callpoint!.setColumnData("<<DISPLAY>>.SCNTRY_ID",custship_tpl.cntry_id$,1)
			highlightShipTo=1
		endif
	endif

	return



