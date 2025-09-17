[[OPT_FILLMNTHDR.ACUS]]
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
				tabCtrl!=Form!.getControl(ctl_ID)
				tabIndex=tabCtrl!.getSelectedIndex()
				Picking_Tab$=Translate!.getTranslation("DDM_TABLE_TABG-OPT_FILLMNTHDR-01-DD_ATTR_TABG")
				Packing_and_Shipping$=Translate!.getTranslation("DDM_TABLE_TABG-OPT_FILLMNTHDR-02-DD_ATTR_TABG")
				if pos(tabCtrl!.getTitleAt(tabIndex)=Picking_Tab$)=1 then
					rem --- Picking Tab has focus
				endif
				if pos(tabCtrl!.getTitleAt(tabIndex)=Packing_and_Shipping$)=1 then
					rem --- Packing & Shipping Tab has focus
					rem --- Need to refresh display if a new OPT_CARTHDR record was added via Pick Item button (also see AWRI)
					if callpoint!.getDevObject("refreshRecord") then
						optFillmntHdr_key$=callpoint!.getRecordKey()
						callpoint!.setStatus("RECORD:["+optFillmntHdr_key$+"]")
						callpoint!.setDevObject("refreshRecord",0)
					endif
				endif
			break
		swend
	endif

[[OPT_FILLMNTHDR.ADEL]]
rem --- Set record deleted flag
	callpoint!.setDevObject("recordDeleted",1)

[[OPT_FILLMNTHDR.ADIS]]
rem --- Capture starting record data so can tell later if anything changed
	callpoint!.setDevObject("initial_rec_data$",rec_data$)

rem --- Hold onto ar_ship_via and shipping_id for use in opt_carthdr
	callpoint!.setDevObject("ar_ship_via",callpoint!.getColumnData("OPT_FILLMNTHDR.AR_SHIP_VIA"))
	callpoint!.setDevObject("shipping_id",callpoint!.getColumnData("OPT_FILLMNTHDR.SHIPPING_ID"))

rem --- Initializations
	callpoint!.setDevObject("recordDeleted",0)
	callpoint!.setDevObject("refreshRecord",0)
	callpoint!.setDevObject("removedOptCartDet",new java.util.HashMap())
	callpoint!.setDevObject("removedOptCartLsDet",new java.util.HashMap())

rem --- Show total weight and total freight amount
	weight=0
	freight_amt=0
	optCartHdr_dev=fnget_dev("OPT_CARTHDR")
	dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
	optCartHdr_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
	read(optCartHdr_dev,key=optCartHdr_trip$,knum="AO_STATUS",dom=*next)
	while 1
		optCartHdr_key$=key(optCartHdr_dev,end=*break)
		if pos(optCartHdr_trip$=optCartHdr_key$)<>1 then break
		readrecord(optCartHdr_dev)optCartHdr$
		weight=weight+optCartHdr.weight
		freight_amt=freight_amt+optCartHdr.freight_amt
	wend
	callpoint!.setColumnData("<<DISPLAY>>.WEIGHT",str(weight),1)
	callpoint!.setColumnData("<<DISPLAY>>.FREIGHT_AMT",str(freight_amt),1)

rem --- Disable/enable fields if all_packed, or not.
	all_packed$=callpoint!.getColumnData("OPT_FILLMNTHDR.ALL_PACKED")
	if all_packed$="Y" then
		rem --- Enable Print List button if all_packed
		callpoint!.setOptionEnabled("PRNT",1)

		rem --- Disable fields
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPMNT_DATE",0)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.AR_SHIP_VIA",0)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPPING_ID",0)
	else
		rem --- Disable Print List button
		callpoint!.setOptionEnabled("PRNT",0)

		rem --- Enable fields
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPMNT_DATE",1)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.AR_SHIP_VIA",1)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPPING_ID",1)
	endif
	callpoint!.setDevObject("all_packed",all_packed$)

rem --- Force Edit Mode for new records, and select the appropriate grid/tab
	tabFocus=callpoint!.getDevObject("tabFocus")
	if tabFocus>-1 then
		callpoint!.setStatus("EDITON")

		tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
		tabCtrl!.setSelectedIndex(tabFocus)
	endif

[[OPT_FILLMNTHDR.ALL_PACKED.AVAL]]
rem --- Skip if all_packed hasn't changed
	all_packed$=callpoint!.getUserInput()
	if cvs(all_packed$,2)=cvs(callpoint!.getColumnData("OPT_FILLMNTHDR.ALL_PACKED"),2) then break

rem --- Warn if reprint is required
	if all_packed$="N" and callpoint!.getColumnData("OPT_FILLMNTHDR.PRINT_STATUS")="Y" then
		msg_id$="OP_REPRINT_FILLMNT"
		gosub disp_message
		if msg_opt$="N"
			callpoint!.setColumnData("OPT_FILLMNTHDR.ALL_PACKED","Y",1)
			callpoint!.setStatus("ABORT")
			break
		else
			rem --- When Packing List is printed again, it will be a reprint.
			callpoint!.setColumnData("OPT_FILLMNTHDR.PRINT_STATUS","N")
			callpoint!.setColumnData("OPT_FILLMNTHDR.REPRINT_FLAG","Y")
		endif
	endif

rem --- Validate fulfillment if marked all_packed
	if all_packed$="Y" then
		rem --- Warn if OPT_FILLMNTDET.QTY_PICKED<>OPT_FILLMNTDET.QTY_SHIPPED for an ITEM_ID
		validationFailed=0
		opcLineCode_dev=fnget_dev("OPC_LINECODE")
		dim opcLineCode$:fnget_tpl$("OPC_LINECODE")
		optFillmntDet_dev=fnget_dev("OPT_FILLMNTDET")
		dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
		ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
		customer_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.ORDER_NO")
		ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_INV_NO")
		optFillmntDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
		read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
			if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
			readrecord(optFillmntDet_dev)optFillmntDet$

			rem --- Is this item pickable?
			if optFillmntdet.qty_shipped<0 then continue
			row=num(optFillmntdet.line_no$)-1
			dropshipMap!=callpoint!.getDevObject("dropshipMap")
			linetypeMap!=callpoint!.getDevObject("linetypeMap")
			if dropshipMap!.get(row)="Y" or pos(linetypeMap!.get(row)="MO") then continue

			if optFillmntdet.qty_shipped<>optFillmntdet.qty_picked then
				msg_id$ = "OP_NOT_COMPLETE_PICK"
				dim msg_tokens$[1]
				if cvs(optFillmntdet.item_id$,2)<>"" then
					item$=optFillmntdet.item_id$
				else
					item$=optFillmntdet.order_memo$
				endif
				msg_tokens$[1]=cvs(item$,3)
				gosub disp_message
				if msg_opt$="N" then all_packed$="N"
			endif
		wend
		if all_packed$="N" then
			callpoint!.setStatus("ABORT")
			callpoint!.setColumnData("OPT_FILLMNTHDR.ALL_PACKED","N",1)
			break
		endif

		rem --- Warn if the sum of OPT_FILLMNTLSDET.QTY_PICKED for an ITEM_ID is not equal to OPT_FILLMNTDET.QTY_PICKED
		validationFailed=0
		optFillmntLsDet_dev=fnget_dev("OPT_FILLMNTLSDET")
		dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
		optFillmntDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
		read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
			if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
			readrecord(optFillmntDet_dev)optFillmntDet$

			rem --- Is this item pickable?
			if optFillmntdet.qty_shipped<0 then continue
			row=num(optFillmntdet.line_no$)-1
			dropshipMap!=callpoint!.getDevObject("dropshipMap")
			linetypeMap!=callpoint!.getDevObject("linetypeMap")
			if dropshipMap!.get(row)="Y" or pos(linetypeMap!.get(row)="MO") then continue

			rem --- Is this a lot/serial item?
			lotser_item$="N"
			if cvs(optFillmntDet.item_id$, 2)<>""
				ivm01_dev=fnget_dev("IVM_ITEMMAST")
				dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
				read record (ivm01_dev, key=firm_id$+optFillmntDet.item_id$, dom=*endif) ivm01a$
				if pos(ivm01a.lotser_flag$="LS") then lotser_item$="Y"
			endif
			if lotser_item$<>"Y" then continue

			totalLsPicked=0
			optFillmntLsDet_trip$=optFillmntDet_trip$+optFillmntDet.orddet_seq_ref$
			read(optFillmntLsDet_dev,key=optFillmntLsDet_trip$,knum="AO_STATUS",dom=*next)
			while 1
				optFillmntLsDet_key$=key(optFillmntLsDet_dev,end=*break)
				if pos(optFillmntLsDet_trip$=optFillmntLsDet_key$)<>1 then break
				readrecord(optFillmntLsDet_dev)optFillmntLsDet$
				totalLsPicked=totalLsPicked+optFillmntLsDet.qty_picked
			wend
			if totalLsPicked=optFillmntdet.qty_picked then continue
			validationFailed=1
			break
		wend
		if validationFailed then
			msg_id$ = "OP_INCOMPLETE_LSPICK"
			dim msg_tokens$[1]
			if cvs(optFillmntdet.item_id$,2)<>"" then
				item$=optFillmntdet.item_id$
			else
				item$=optFillmntdet.order_memo$
			endif
			msg_tokens$[1]=item$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			callpoint!.setColumnData("OPT_FILLMNTHDR.ALL_PACKED","N",1)
			break
		endif

		rem --- Warn if the sum of the OPT_CARTDET.QTY_PACKED for all the packed cartons is not equal to OPT_FILLMNTDET.QTY_PICKED for an ITEM_ID
		validationFailed=0
		optCartDet2_dev=fnget_dev("OPT_CARTDET2")
		dim optCartDet2$:fnget_tpl$("OPT_CARTDET2")
		optFillmntDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
		read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
			if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
			readrecord(optFillmntDet_dev)optFillmntDet$

			rem --- Is this item pickable?
			if optFillmntdet.qty_shipped<0 then continue
			row=num(optFillmntdet.line_no$)-1
			dropshipMap!=callpoint!.getDevObject("dropshipMap")
			linetypeMap!=callpoint!.getDevObject("linetypeMap")
			if dropshipMap!.get(row)="Y" or pos(linetypeMap!.get(row)="MO") then continue

			totalPacked=0
			optCartDet2_trip$=optFillmntDet_trip$+optFillmntDet.orddet_seq_ref$
			read(optCartDet2_dev,key=optCartDet2_trip$,knum="AO_ORDDET_CART",dom=*next)
			while 1
				optCartDet2_key$=key(optCartDet2_dev,end=*break)
				if pos(optCartDet2_trip$=optCartDet2_key$)<>1 then break
				readrecord(optCartDet2_dev)optCartDet2$
				totalPacked=totalPacked+optCartDet2.qty_packed
			wend
			if totalPacked=optFillmntdet.qty_picked then continue
			validationFailed=1
			break
		wend
		if validationFailed then
			msg_id$ = "OP_NOT_COMPLETE_PACK"
			dim msg_tokens$[1]
			if cvs(optFillmntdet.item_id$,2)<>"" then
				item$=optFillmntdet.item_id$
			else
				item$=optFillmntdet.order_memo$
			endif
			msg_tokens$[1]=item$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			callpoint!.setColumnData("OPT_FILLMNTHDR.ALL_PACKED","N",1)
			break
		endif


		rem --- Warn if the sum of the OPT_CARTLSDET.QTY_PACKED for an ITEM_ID and LOTSER_NO in a packed carton is not equal to the the OPT_CARTDET.QTY_PACKED for the ITEM_ID in the packed carton
		validationFailed=0
		optCartLsDet2_dev=fnget_dev("OPT_CARTLSDET2")
		dim optCartLsDet2$:fnget_tpl$("OPT_CARTLSDET2")
		optFillmntDet_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
		read(optFillmntDet_dev,key=optFillmntDet_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optFillmntDet_key$=key(optFillmntDet_dev,end=*break)
			if pos(optFillmntDet_trip$=optFillmntDet_key$)<>1 then break
			readrecord(optFillmntDet_dev)optFillmntDet$

			rem --- Is this item pickable?
			if optFillmntdet.qty_shipped<0 then continue
			row=num(optFillmntdet.line_no$)-1
			dropshipMap!=callpoint!.getDevObject("dropshipMap")
			linetypeMap!=callpoint!.getDevObject("linetypeMap")
			if dropshipMap!.get(row)="Y" or pos(linetypeMap!.get(row)="MO") then continue

			rem --- Is this a lot/serial item?
			lotser_item$="N"
			if cvs(optFillmntDet.item_id$, 2)<>"" 
				ivm01_dev=fnget_dev("IVM_ITEMMAST")
				dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
				read record (ivm01_dev, key=firm_id$+optFillmntDet.item_id$, dom=*endif) ivm01a$
				if pos(ivm01a.lotser_flag$="LS") then lotser_item$="Y"
			endif
			if lotser_item$<>"Y" then continue

			totalLsPacked=0
			optCartLsDet2_trip$=optFillmntDet_trip$+optFillmntDet.orddet_seq_ref$
			read(optCartLsDet2_dev,key=optCartLsDet2_trip$,knum="AO_ORDDET_CART",dom=*next)
			while 1
				optCartLsDet2_key$=key(optCartLsDet2_dev,end=*break)
				if pos(optCartLsDet2_trip$=optCartLsDet2_key$)<>1 then break
				readrecord(optCartLsDet2_dev)optCartLsDet2$
				totalLsPacked=totalLsPacked+optCartLsDet2.qty_packed
			wend
			if totalLsPacked=optFillmntdet.qty_picked then continue
			validationFailed=1
			break
		wend
		if validationFailed then
			msg_id$ = "OP_INCOMPLETE_LSPACK"
			dim msg_tokens$[1]
			if cvs(optFillmntdet.item_id$,2)<>"" then
				item$=optFillmntdet.item_id$
			else
				item$=optFillmntdet.order_memo$
			endif
			msg_tokens$[1]=item$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			callpoint!.setColumnData("OPT_FILLMNTHDR.ALL_PACKED","N",1)
			break
		endif
	endif

rem --- Disable/enable fields and Print List button if all_packed or not.
	if all_packed$="Y" then
		rem --- Enable Print List button
		callpoint!.setOptionEnabled("PRNT",1)

		rem --- Disable fields
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPMNT_DATE",0)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.AR_SHIP_VIA",0)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPPING_ID",0)
	else
		rem --- Disable Print List button
		callpoint!.setOptionEnabled("PRNT",0)

		rem --- Enable fields
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPMNT_DATE",1)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.AR_SHIP_VIA",1)
		callpoint!.setColumnEnabled("OPT_FILLMNTHDR.SHIPPING_ID",1)
	endif
	callpoint!.setDevObject("all_packed",all_packed$)

rem --- Disable qty_picked on picking tab
	pickGrid!=callpoint!.getDevObject("pickGrid")
	rows=pickGrid!.getNumRows()
	if rows>1 then
		disabledColor!=callpoint!.getDevObject("disabledColor")
		all_packed$=callpoint!.getColumnData("OPT_FILLMNTHDR.ALL_PACKED")
		picked_col=callpoint!.getDevObject("picked_col")
		for i=0 to rows-2
			if pickGrid!.getCellForeColor(i,picked_col)<>disabledColor! then
				if all_packed$="Y" then
					pickGrid!.setCellEditable(i,picked_col,0)
				else
					pickGrid!.setCellEditable(i,picked_col,1)
				endif
			endif
		next i
	endif

[[OPT_FILLMNTHDR.AOPT-PRNT]]
rem --- Make sure modified records are saved before printing Packing List
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_INV_NO")

	if pos("M"=callpoint!.getRecordStatus())
		rem --- Add Barista soft lock for this record if not already in edit mode
		if !callpoint!.isEditMode() then
			rem --- Is there an existing soft lock?
			lock_table$="OPT_FILLMNTHDR"
			lock_record$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
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
		optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
		optFillmntHdr_tpl$=fnget_tpl$("OPT_FILLMNTHDR")
		dim optFillmntHdr$:optFillmntHdr_tpl$
		optFillmntHdr$=util.copyFields(optFillmntHdr_tpl$, callpoint!)
		optFillmntHdr$=field(optFillmntHdr$)
		if cvs(optFillmntHdr.firm_id$,2)="" then optFillmntHdr.firm_id$=firm_id$
		writerecord(optFillmntHdr_dev)optFillmntHdr$
		extractrecord(optFillmntHdr_dev, key=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$, dom=*next)optFillmntHdr$; rem Advisory Locking
		callpoint!.setStatus("SETORIG")
	endif

rem --- Print Packing List for this Order
	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[4,1]
	dflt_data$[1,0]="CUSTOMER_ID"
	dflt_data$[1,1]=customer_id$
	dflt_data$[2,0]="ORDER_NO"
	dflt_data$[2,1]=order_no$

	rem --- Pass additional info needed in OPR_PACKLIST
	callpoint!.setDevObject("ar_type",ar_type$)
	callpoint!.setDevObject("ar_inv_no",ar_inv_no$)
	callpoint!.setDevObject("reprint_flag",callpoint!.getColumnData("OPT_FILLMNTHDR.REPRINT_FLAG"))

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "OPR_PACKLIST",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all]	

rem --- Update print_status flag
	if callpoint!.getColumnData("OPT_FILLMNTHDR.PRINT_STATUS")<>"Y" then
		msg_id$="OP_PACK_LST_PRINTED"
		gosub disp_message
		if msg_opt$="Y" then
			callpoint!.setColumnData("OPT_FILLMNTHDR.PRINT_STATUS","Y")

			rem --- Get current form data and write it to disk
			optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
			optFillmntHdr_tpl$=fnget_tpl$("OPT_FILLMNTHDR")
			dim optFillmntHdr$:optFillmntHdr_tpl$
			optFillmntHdr$=util.copyFields(optFillmntHdr_tpl$, callpoint!)
			optFillmntHdr$=field(optFillmntHdr$)
			if cvs(optFillmntHdr.firm_id$,2)="" then optFillmntHdr.firm_id$=firm_id$
			writerecord(optFillmntHdr_dev)optFillmntHdr$
			extractrecord(optFillmntHdr_dev, key=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$, dom=*next)optFillmntHdr$; rem Advisory Locking
			callpoint!.setStatus("SETORIG")
			callpoint!.setStatus("MODIFIED")
		endif
	endif

rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

rem --- Get focus back on this form
	callpoint!.setStatus("ACTIVATE")

[[OPT_FILLMNTHDR.APFE]]
rem --- Enable Print List button if all_packed
	if callpoint!.getColumnData("OPT_FILLMNTHDR.ALL_PACKED")="Y"  then callpoint!.setOptionEnabled("PRNT",1)

[[OPT_FILLMNTHDR.ARAR]]
rem --- If First/Last Record was used, did it return an Order?
	if callpoint!.getDevObject("FirstLastRecord")<>null() and callpoint!.getDevObject("FirstLastRecord")<>"" then
		whichRecord$=callpoint!.getDevObject("FirstLastRecord")
		callpoint!.setDevObject("FirstLastRecord","")

		optFillmntHdr_dev = fnget_dev("OPT_FILLMNTHDR")
		dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
		status$=callpoint!.getColumnData("OPT_FILLMNTHDR.TRANS_STATUS")
		ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
		next_key$=""

		if whichRecord$="FIRST" then
			rem --- Locate FIRST valid OPT_FILLMNTHDR record to display
			read(optFillmntHdr_dev,key=firm_id$+status$+ar_type$,dom=*next)
			read record (optFillmntHdr_dev, dir=0, end=*next) optFillmntHdr$
			if optFillmntHdr.firm_id$+optFillmntHdr.trans_status$+optFillmntHdr.ar_type$=firm_id$+status$+ar_type$ then
				next_key$=key(optFillmntHdr_dev)
			endif
		endif

		if whichRecord$="LAST" then
			rem --- Locate LAST valid OPT_FILLMNTHDR record to display
			p_key$=""
			p_key$ = keyp(optFillmntHdr_dev, end=*next)
			if p_key$<>"" then
				read record (optFillmntHdr_dev, key=p_key$) optFillmntHdr$
				if optFillmntHdr.firm_id$+optFillmntHdr.trans_status$+optFillmntHdr.ar_type$=firm_id$+status$+ar_type$
					next_key$=p_key$
				endif
			endif
		endif

		rem --- Display next OPT_FILLMNTHDR record
		if next_key$<>"" then
			callpoint!.setStatus("RECORD:["+next_key$+"]")
			break
		else
			msg_id$ = "OP_NO_FULFILLMENT"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	endif

rem --- Initializations
	callpoint!.setDevObject("new_rec","N")

[[OPT_FILLMNTHDR.AREC]]
rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPT_FILLMNTHDR.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPT_FILLMNTHDR.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPT_FILLMNTHDR.CREATED_TIME",date(0:"%Hz%mz"))

rem --- Capture starting record data so can tell later if anything changed
	callpoint!.setDevObject("initial_rec_data$",rec_data$)

rem --- Initializations
	callpoint!.setDevObject("recordDeleted",0)
	callpoint!.setDevObject("refreshRecord",0)
	callpoint!.setDevObject("all_packed","N")
	callpoint!.setDevObject("new_rec","Y")
	callpoint!.setDevObject("removedOptCartDet",new java.util.HashMap())
	callpoint!.setDevObject("removedOptCartLsDet",new java.util.HashMap())

rem --- Disable Print List button
	callpoint!.setOptionEnabled("PRNT",0)

[[OPT_FILLMNTHDR.ARNF]]
rem --- Confirm the Order is ready to be filled.
	msg_id$="OP_ORD_READY_TO_FILL"
	gosub disp_message
	if msg_opt$="N"
		callpoint!.setStatus("ABORT")
		break
	else
		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Check Barista soft lock for the Order to make sure it isn't currently being edited.
rem --- Add Barista soft lock for the Order to make sure it cannot be edited.
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_INV_NO")
	lock_table$="OPT_INVHDR"
	lock_record$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
	lock_type$="C"
	lock_status$=""
	lock_disp$=""
	call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	if lock_status$="" then
		rem --- Add temporary soft lock
		lock_type$="L"
		lock_status$=""
		lock_disp$="M"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		if lock_status$<>""
			callpoint!.setStatus("NEWREC")
			break
		endif
	else
		rem --- Record locked by someone else
		msg_id$="ENTRY_REC_LOCKED"
		gosub disp_message
		callpoint!.setStatus("NEWREC")
		break
	endif

rem --- Initialize inventory item update
	status=999
	call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
	if status then exitto std_exit

rem --- Initialize new Order Fulfillment Entry with corresponding OPE_ORDHDR data
	opeOrdHdr_dev=fnget_dev("OPE_ORDHDR")
	dim opeOrdHdr$:fnget_tpl$("OPE_ORDHDR")
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVHDR","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim opeOrdHdr_key$:key_tpl$
	opeOrdHdr_key.firm_id$=firm_id$
	opeOrdHdr_key.ar_type$=ar_type$
	opeOrdHdr_key.customer_id$=customer_id$
	opeOrdHdr_key.order_no$=order_no$
	opeOrdHdr_key.ar_inv_no$=""

	readrecord(opeOrdHdr_dev,key=opeOrdHdr_key$,knum="PRIMARY",dom=*next)opeOrdHdr$

	optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
	dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
	optFillmntHdr.firm_id$=firm_id$
	optFillmntHdr.ar_type$=opeOrdHdr.ar_type$
	optFillmntHdr.customer_id$=opeOrdHdr.customer_id$
	optFillmntHdr.order_no$=opeOrdHdr.order_no$
	optFillmntHdr.ar_inv_no$=opeOrdHdr.ar_inv_no$
	optFillmntHdr.shipmnt_date$=opeOrdHdr.shipmnt_date$
	optFillmntHdr.ar_ship_via$=opeOrdHdr.ar_ship_via$
	optFillmntHdr.shipping_id$=opeOrdHdr.shipping_id$
	optFillmntHdr.created_user$=sysinfo.user_id$
	optFillmntHdr.created_date$=date(0:"%Yd%Mz%Dz")
	optFillmntHdr.created_time$=date(0:"%Hz%mz")
	optFillmntHdr.trans_status$="E"
	writerecord(optFillmntHdr_dev)optFillmntHdr$

rem --- Hold onto ar_ship_via and shipping_id for use in opt_carthdr
	callpoint!.setDevObject("ar_ship_via",optFillmntHdr.ar_ship_via$)
	callpoint!.setDevObject("shipping_id",optFillmntHdr.shipping_id$)

rem --- Initialize item Qty Picked?
	msg_id$="OP_INIT_QTY_PICKED"
	gosub disp_message
	if msg_opt$="N"
		init_qtyPicked=0
	else
		init_qtyPicked=1
	endif

rem --- Initialize Picking tab with corresponding OPE_ORDDET data
	allPicked=1
	optFillmntDet_dev=fnget_dev("OPT_FILLMNTDET")
	dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
	opeOrdDet_dev=fnget_dev("OPE_ORDDET")
	dim opeOrdDet$:fnget_tpl$("OPE_ORDDET")
	ivmItemWhse_dev=fnget_dev("IVM_ITEMWHSE")
	dim ivmItemWhse$:fnget_tpl$("IVM_ITEMWHSE")
	lineNo=0
	read(opeOrdDet_dev,key=opeOrdHdr_key$,knum="PRIMARY",dom=*next)
	while 1
		opeOrdDet_key$=key(opeOrdDet_dev,end=*break)
		if pos(opeOrdHdr_key$=opeOrdDet_key$)<>1 then break
		readrecord(opeOrdDet_dev)opeOrdDet$

		rem --- Initialize OPT_FILLMNTLSDET with corresponding OPE_ORDLSDET data
		lsPicked=0
		optFillmntLsDet_dev=fnget_dev("OPT_FILLMNTLSDET")
		dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
		opeOrdLsDet_dev=fnget_dev("OPE_ORDLSDET")
		dim opeOrdLsDet$:fnget_tpl$("OPE_ORDLSDET")
		read(opeOrdLsDet_dev,key=opeOrdDet_key$,knum="PRIMARY",dom=*next)
		while 1
			opeOrdLsDet_key$=key(opeOrdLsDet_dev,end=*break)
			if pos(opeOrdDet_key$=opeOrdLsDet_key$)<>1 then break
			readrecord(opeOrdLsDet_dev)opeOrdLsDet$

			redim optFillmntLsDet$
			optFillmntLsDet.firm_id$=firm_id$
			optFillmntLsDet.ar_type$=opeOrdLsDet.ar_type$
			optFillmntLsDet.customer_id$=opeOrdLsDet.customer_id$
			optFillmntLsDet.order_no$=opeOrdLsDet.order_no$
			optFillmntLsDet.ar_inv_no$=opeOrdLsDet.ar_inv_no$
			optFillmntLsDet.orddet_seq_ref$=opeOrdLsDet.orddet_seq_ref$
			optFillmntLsDet.sequence_no$=opeOrdLsDet.sequence_no$
			optFillmntLsDet.lotser_no$=opeOrdLsDet.lotser_no$
			if opeOrdLsDet.qty_ordered>0 then
				rem --- Cannot have an order qty greater than zero unless the lot/serial number was committed in Order Entry 
				optFillmntLsDet.oe_committed$="Y"
			else
				optFillmntLsDet.oe_committed$="N"
			endif
			optFillmntLsDet.created_user$=sysinfo.user_id$
			optFillmntLsDet.created_date$=date(0:"%Yd%Mz%Dz")
			optFillmntLsDet.created_time$=date(0:"%Hz%mz")
			optFillmntLsDet.trans_status$="E"
			optFillmntLsDet.qty_shipped=opeOrdLsDet.qty_shipped
			optFillmntLsDet.qty_picked=opeOrdLsDet.qty_shipped
			optFillmntLsDet.unit_cost=opeOrdLsDet.unit_cost
			writerecord(optFillmntLsDet_dev)optFillmntLsDet$

			lsPicked=lsPicked+optFillmntLsDet.qty_picked
		wend
        
		rem --- Get warehouse location for this item
		redim ivmItemWhse$
		readrecord(ivmItemWhse_dev,key=firm_id$+opeOrdDet.warehouse_id$+opeOrdDet.item_id$,dom=*next)ivmItemWhse$

		rem --- Initialize OPT_FILLMNTDET with corresponding OPE_ORDDET data
		ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
		dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
		readrecord(ivmItemMast_dev,key=firm_id$+opeOrdDet.item_id$,dom=*next)ivmItemMast$
		if pos(ivmItemMast.kit$="YP")=0 then
			rem --- Initialize OPT_FILLMNTDET with this OPE_ORDDET data record
			redim optFillmntDet$
			optFillmntDet.firm_id$=firm_id$
			optFillmntDet.ar_type$=opeOrdDet.ar_type$
			optFillmntDet.customer_id$=opeOrdDet.customer_id$
			optFillmntDet.order_no$=opeOrdDet.order_no$
			optFillmntDet.ar_inv_no$=opeOrdDet.ar_inv_no$
			lineNo=lineNo+1
			optFillmntDet.line_no$=pad(str(lineNo),len(opeOrdDet.line_no$),"R","0")
			optFillmntDet.orddet_seq_ref$=opeOrdDet.internal_seq_no$
			optFillmntDet.warehouse_id$=opeOrdDet.warehouse_id$
			optFillmntDet.item_id$=opeOrdDet.item_id$
			optFillmntDet.order_memo$=opeOrdDet.order_memo$
			optFillmntDet.memo_1024$=opeOrdDet.memo_1024$
			optFillmntDet.um_sold$=opeOrdDet.um_sold$
			optFillmntDet.location$=ivmItemWhse.location$
			optFillmntDet.created_user$=sysinfo.user_id$
			optFillmntDet.created_date$=date(0:"%Yd%Mz%Dz")
			optFillmntDet.created_time$=date(0:"%Hz%mz")
			optFillmntDet.trans_status$="E"
			optFillmntDet.qty_shipped=opeOrdDet.qty_shipped
			if init_qtyPicked then
				if pos(ivmItemMast.lotser_flag$="LS") and ivmItemMast.inventoried$="Y" then
					optFillmntDet.qty_picked=lsPicked
				else
					optFillmntDet.qty_picked=opeOrdDet.qty_shipped
				endif
			else
				optFillmntDet.qty_picked=0
			endif
			optFillmntDet.conv_factor=opeOrdDet.conv_factor
			writerecord(optFillmntDet_dev)optFillmntDet$

			if optFillmntDet.qty_picked<>opeOrdDet.qty_shipped then allPicked=0
		else
			rem --- Explode this kit into its components and initialize OPT_FILLMNTDET with the OPT_INVKITDET data
			optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
			dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
			optInvKitDet_key$=firm_id$+opeOrdDet.ar_type$+opeOrdDet.customer_id$+opeOrdDet.order_no$+opeOrdDet.ar_inv_no$+opeOrdDet.internal_seq_no$
			read(optInvKitDet_dev,key=optInvKitDet_key$,dom=*next)
			while 1
				thisKey$=key(optInvKitDet_dev,end=*break)
				if pos(optInvKitDet_key$=thisKey$)<>1 then break
				readrecord(optInvKitDet_dev,key=thisKey$)optInvKitDet$

				redim optFillmntDet$
				optFillmntDet.firm_id$=firm_id$
				optFillmntDet.ar_type$=optInvKitDet.ar_type$
				optFillmntDet.customer_id$=optInvKitDet.customer_id$
				optFillmntDet.order_no$=optInvKitDet.order_no$
				optFillmntDet.ar_inv_no$=optInvKitDet.ar_inv_no$
				lineNo=lineNo+1
				optFillmntDet.line_no$=pad(str(lineNo),len(optInvKitDet.line_no$),"R","0")
				optFillmntDet.orddet_seq_ref$=optInvKitDet.internal_seq_no$
				optFillmntDet.warehouse_id$=optInvKitDet.warehouse_id$
				optFillmntDet.item_id$=optInvKitDet.item_id$
				optFillmntDet.order_memo$=optInvKitDet.order_memo$
				optFillmntDet.memo_1024$=optInvKitDet.memo_1024$
				optFillmntDet.um_sold$=optInvKitDet.um_sold$
				optFillmntDet.location$=ivmItemWhse.location$
				optFillmntDet.created_user$=sysinfo.user_id$
				optFillmntDet.created_date$=date(0:"%Yd%Mz%Dz")
				optFillmntDet.created_time$=date(0:"%Hz%mz")
				optFillmntDet.trans_status$="E"
				optFillmntDet.qty_shipped=optInvKitDet.qty_shipped
				if init_qtyPicked then
					optFillmntDet.qty_picked=optInvKitDet.qty_shipped
				else
					optFillmntDet.qty_picked=0
				endif
				optFillmntDet.conv_factor=optInvKitDet.conv_factor
				writerecord(optFillmntDet_dev)optFillmntDet$

				if optFillmntDet.qty_picked<>opeOrdDet.qty_shipped then allPicked=0
			wend
		endif
	wend

rem --- Remove Barista soft lock for the Order.
	lock_table$="OPT_INVHDR"
	lock_record$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
	lock_type$="U"
	lock_status$=""
	lock_disp$="M"
	call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$

rem --- Relaunch form with all the initialized data
	if allPicked then
		callpoint!.setDevObject("tabFocus",callpoint!.getDevObject("packShipTabIndex"))
	else
		callpoint!.setDevObject("tabFocus",callpoint!.getDevObject("pickTabIndex"))
	endif
	rec_key$=optFillmntHdr.firm_id$+optFillmntHdr.trans_status$+optFillmntHdr.ar_type$+optFillmntHdr.customer_id$+optFillmntHdr.order_no$+optFillmntHdr.ar_inv_no$
	callpoint!.setStatus("RECORD:["+rec_key$+"]")

[[OPT_FILLMNTHDR.AR_SHIP_VIA.AVAL]]
rem --- Hold onto ar_ship_via for use in opt_carthdr
	callpoint!.setDevObject("ar_ship_via",callpoint!.getUserInput())

[[OPT_FILLMNTHDR.ASHO]]
rem --- Get grid control on each tab
	Picking$=Translate!.getTranslation("DDM_TABLE_TABG-OPT_FILLMNTHDR-01-DD_ATTR_TABG")
	Packing_and_Shipping$=Translate!.getTranslation("DDM_TABLE_TABG-OPT_FILLMNTHDR-02-DD_ATTR_TABG")
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	numTabs=tabCtrl!.getNumTabs()
	for i=0 to numTabs-1
		if pos(tabCtrl!.getTitleAt(i)=Picking$)=1 then
			pickTab!=tabCtrl!.getControlAt(i)
			callpoint!.setDevObject("pickTabIndex",i)
			pickGrid!=pickTab!.getControl(num(stbl("+GRID_CTL"))+100*(i+1))
			callpoint!.setDevObject("pickGrid",pickGrid!)
		endif
		if pos(tabCtrl!.getTitleAt(i)=Packing_and_Shipping$)=1 then
			packShipTab!=tabCtrl!.getControlAt(i)
			callpoint!.setDevObject("packShipTabIndex",i)
			packShipGrid!=packShipTab!.getControl(num(stbl("+GRID_CTL"))+100*(i+1))
			callpoint!.setDevObject("packShipGrid",packShipGrid!)
		endif
	next i

rem --- Set callback for a tab being selected so can refresh display if a new OPT_CARTHDR record was added via Pick Item button
	tabCtrl!.setCallback(BBjTabCtrl.ON_TAB_SELECT,"custom_event")

rem --- Set up a color to be used when qty picked <> ship qty
	pickGrid!=callpoint!.getDevObject("pickGrid")
	plainFont!=pickGrid!.getRowFont(0)
	boldFont!=sysGUI!.makeFont(plainFont!.getName(),plainFont!.getSize(),3);rem bold italic
	italicFont!=sysGUI!.makeFont(plainFont!.getName(),plainFont!.getSize(),2);rem italic
	callpoint!.setDevObject("plainFont",plainFont!)
	callpoint!.setDevObject("boldFont",boldFont!)
	callpoint!.setDevObject("italicFont",italicFont!)

	RGB$="255,0,0"
	gosub get_RGB
	callpoint!.setDevObject("redColor",BBjAPI().getSysGui().makeColor(R,G,B))

	RGB$="0,0,0"
	gosub get_RGB
	callpoint!.setDevObject("blackColor",BBjAPI().getSysGui().makeColor(R,G,B))

	RGB$="115,147,179"
	gosub get_RGB
	callpoint!.setDevObject("disabledColor",BBjAPI().getSysGui().makeColor(R,G,B))

rem --- Get and hold on to controls for the <<DISPLAY>> field controls
	totalFreightAmtCtrl!=callpoint!.getControl("<<DISPLAY>>.FREIGHT_AMT")
	callpoint!.setDevObject("totalFreightAmtCtrl",totalFreightAmtCtrl!)

	totalWeightCtrl!=callpoint!.getControl("<<DISPLAY>>.WEIGHT")
	callpoint!.setDevObject("totalWeightCtrl",totalWeightCtrl!)

[[OPT_FILLMNTHDR.AWRI]]
rem --- Need to refresh display if a new OPT_CARTHDR record was added via Pick Item button (also see ACUS)
	if callpoint!.getDevObject("refreshRecord") then
		optFillmntHdr_key$=callpoint!.getRecordKey()
		callpoint!.setStatus("RECORD:["+optFillmntHdr_key$+"]")
		callpoint!.setDevObject("refreshRecord",0)
	endif

[[OPT_FILLMNTHDR.BDEL]]
rem --- Update qty_commit for deleted inventoried lot/serial numbers, but not for the item itself.
	optFillmntDet_dev=fnget_dev("OPT_FILLMNTDET")
	dim optFillmntDet$:fnget_tpl$("OPT_FILLMNTDET")
	optFillmntLsDet_dev=fnget_dev("OPT_FILLMNTLSDET")
	dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
	ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
	dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
	optFillmntHdr_key$=callpoint!.getRecordKey()
	read (optFillmntDet_dev,key=optFillmntHdr_key$,knum="AO_STATUS",dom=*next)
	while 1
		optFillMntDet_key$=key(optFillmntDet_dev,end=*break)
		if pos(optFillmntHdr_key$=optFillMntDet_key$)<>1 then break
		readrecord(optFillmntDet_dev)optFillmntDet$

		optFillmntLsDet_trip$=firm_id$+"E"+optFillmntDet.ar_type$+optFillmntDet.customer_id$+optFillmntDet.order_no$+optFillmntDet.ar_inv_no$+optFillmntDet.orddet_seq_ref$
		read(optFillmntLsDet_dev,key=optFillmntLsDet_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optFillmntLsDet_key$=key(optFillmntLsDet_dev,knum="AO_STATUS",end=*break)
			if pos(optFillmntLsDet_trip$=optFillmntLsDet_key$)<>1 then break
			remove_key$=key(optFillmntLsDet_dev,knum="PRIMARY")
			readrecord(optFillmntLsDet_dev,knum="AO_STATUS")optFillmntLsDet$

			rem --- Do Not uncommit if lot/serial number was committed in Order Entry
			if optFillmntLsDet.oe_committed$<>"Y" then
				rem --- Is this an inventoried lot/serial item?
				item$=optFillmntDet.item_id$
				findrecord (ivmItemMast_dev,key=firm_id$+item$,dom=*next)ivmItemMast$
				if ivmItemMast$.inventoried$="Y" then
					status=999
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then exitto std_exit

					rem --- Need to uncommit deleted inventoried lot/serial numbers, but leave the item committed.
					items$[1]=optFillmntDet.warehouse_id$
					items$[2]=optFillmntDet.item_id$
					items$[3]=optFillmntLsDet.lotser_no$
					refs[0]=optFillmntLsDet.qty_shipped
					action$="UC"
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					items$[3]=""
					action$="OE"
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				endif
			endif

			remove(optFillmntLsDet_dev,key=remove_key$)
		wend
	wend

rem --- All carton (OPT_CARTHDR, OPT_CARTDET and OPT_CARTLSDET) records need to be deleted when the Order Fulfillment record is deleted
	optCartHdr_dev=fnget_dev("OPT_CARTHDR")
	optCartDet_dev=fnget_dev("OPT_CARTDET")
	optCartLsDet_dev=fnget_dev("OPT_CARTLSDET")
	optFillmntHdr_key$=callpoint!.getRecordKey()
	read (optCartHdr_dev,key=optFillmntHdr_key$,knum="AO_STATUS",dom=*next)
	while 1
		optCartHdr_key$=key(optCartHdr_dev,end=*break)
		if pos(optFillmntHdr_key$=optCartHdr_key$)<>1 then break
		remove_optCartHdr$=key(optCartHdr_dev,knum="PRIMARY")

		read(optCartDet_dev,key=optCartHdr_key$,knum="AO_STATUS",dom=*next)
		while 1
			optCartDet_key$=key(optCartDet_dev,end=*break)
			if pos(optCartHdr_key$=optCartDet_key$)<>1 then break
			remove_optCartDet$=key(optCartDet_dev,knum="PRIMARY")

			read(optCartLsDet_dev,key=optCartDet_key$,knum="AO_STATUS",dom=*next)
			while 1
				optCartLsDet_key$=key(optCartLsDet_dev,end=*break)
				if pos(optCartDet_key$=optCartLsDet_key$)<>1 then break
				remove_optCartLsDet$=key(optCartLsDet_dev,knum="PRIMARY")

				remove(optCartLsDet_dev,key=remove_optCartLsDet$)
			wend			

			remove(optCartDet_dev,key=remove_optCartDet$)
		wend

		remove(optCartHdr_dev,key=remove_optCartHdr$)
	wend

[[OPT_FILLMNTHDR.BFST]]
rem --- Set flag that First Record has been selected
	callpoint!.setDevObject("FirstLastRecord","FIRST")

[[OPT_FILLMNTHDR.BLST]]
rem --- Set flag that Last Record has been selected
	callpoint!.setDevObject("FirstLastRecord","LAST")

[[OPT_FILLMNTHDR.BNEK]]
rem --- Position the file at the correct record
	optFillmntHdr_dev = fnget_dev("OPT_FILLMNTHDR")
	dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
	status$=callpoint!.getColumnData("OPT_FILLMNTHDR.TRANS_STATUS")
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
	if callpoint!.getDevObject("new_rec")="Y"
		start_key$=firm_id$+status$+ar_type$
		cust_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
		if cvs(cust_id$,2)<>""
			start_key$=start_key$+cust_id$
			order_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.ORDER_NO")
			if cvs(order_no$,2)<>""
				start_key$=start_key$+order_no$
			endif
		endif
		read (optFillmntHdr_dev,key=start_key$,dom=*next)
	else
		current_key$=callpoint!.getRecordKey()
		read(optFillmntHdr_dev,key=current_key$,dom=*next)
	endif

	hit_eof=0
	while 1
		read record (optFillmntHdr_dev, dir=0, end=eof)optFillmntHdr$
		if optFillmntHdr.firm_id$+optFillmntHdr.trans_status$+optFillmntHdr.ar_type$ = firm_id$+status$+ar_type$ then break

eof: rem --- If end-of-file or end-of-firm, rewind to first record of the firm
		read (optFillmntHdr_dev, key=firm_id$+status$+ar_type$, dom=*next)
		hit_eof=hit_eof+1
		if hit_eof>1 then
			msg_id$ = "OP_NO_FULFILLMENT"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	wend

[[OPT_FILLMNTHDR.BPFX]]
rem --- Disable Print List button
	callpoint!.setOptionEnabled("PRNT",0)

[[OPT_FILLMNTHDR.BPRK]]
rem --- Position the file at the correct record
	optFillmntHdr_dev = fnget_dev("OPT_FILLMNTHDR")
	dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
	status$=callpoint!.getColumnData("OPT_FILLMNTHDR.TRANS_STATUS")
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
	if callpoint!.getDevObject("new_rec")="Y"
		start_key$=firm_id$+status$+ar_type$
		cust_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
		if cvs(cust_id$,2)<>""
			start_key$=start_key$+cust_id$
			order_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.ORDER_NO")
			if cvs(order_no$,2)<>""
				start_key$=start_key$+order_no$
			endif
		endif
		read (optFillmntHdr_dev,key=start_key$,dom=*next)
	else
		current_key$=callpoint!.getRecordKey()
		read(optFillmntHdr_dev,key=current_key$,dir=0,dom=*next)
	endif

	hit_eof=0
	while 1
		p_key$ = keyp(optFillmntHdr_dev, end=eof_pkey)
		read record (optFillmntHdr_dev, key=p_key$)optFillmntHdr$
		if optFillmntHdr.firm_id$+optFillmntHdr.trans_status$+optFillmntHdr.ar_type$ = firm_id$+status$+ar_type$ then break

eof_pkey: rem --- If end-of-file or end-of-firm, rewind to last record of the firm
		read (optFillmntHdr_dev, key=firm_id$+status$+ar_type$+$FF$, dom=*next)
		hit_eof=hit_eof+1
		if hit_eof>1 then
			msg_id$ = "OP_NO_FULFILLMENT"
			gosub disp_message
			callpoint!.setStatus("ABORT-NEWREC")
			break
		endif
	wend

[[OPT_FILLMNTHDR.BREX]]
rem --- Skip warnings if record was deleted
	if callpoint!.getDevObject("recordDeleted") then break

rem --- Are there any items that weren't picked completely
	pickGrid!=callpoint!.getDevObject("pickGrid")
	picked_col=callpoint!.getDevObject("picked_col")
	shipped_col=callpoint!.getDevObject("shipped_col")

	gridRows=pickGrid!.getNumRows()
	if gridRows<2 then break
	pickedOK=1
	dropshipMap!=callpoint!.getDevObject("dropshipMap")
	linetypeMap!=callpoint!.getDevObject("linetypeMap")
	for row=0 to gridRows-2
		qty_picked=num(pickGrid!.getCellText(row,picked_col))
		ship_qty=num(pickGrid!.getCellText(row,shipped_col))
		if ship_qty>0 and qty_picked<>ship_qty and dropshipMap!.get(row)<>"Y" and pos(linetypeMap!.get(row)="MO")=0 then
			pickedOK=0
			break
		endif
	next row

	if !pickedOK then
		tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
		tabCtrl!.setSelectedIndex(callpoint!.getDevObject("pickTabIndex"))

		msg_id$ = "OP_PICK_QTY_BAD"
		gosub disp_message
		if msg_opt$="N"
			pickGrid!.setSelectedCell(row,picked_col)
			callpoint!.setStatus("ABORT-ACTIVATE")
			break
		endif
	endif

[[OPT_FILLMNTHDR.BSHO]]
rem --- Init Java classes
	use ::ado_util.src::util

rem --- Open needed files
	num_files=17
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	
	open_tables$[1]="OPE_ORDHDR",  open_opts$[1]="OTA"
	open_tables$[2]="OPE_ORDDET",  open_opts$[2]="OTA"
	open_tables$[3]="OPE_ORDLSDET",  open_opts$[3]="OTA"
	open_tables$[4]="OPT_FILLMNTDET",  open_opts$[4]="OTA"
	open_tables$[5]="OPT_FILLMNTLSDET",  open_opts$[5]="OTA"
	open_tables$[6]="OPT_CARTHDR",  open_opts$[6]="OTA"
	open_tables$[7]="OPT_CARTDET",  open_opts$[7]="OTA"
	open_tables$[8]="OPT_CARTDET2",  open_opts$[8]="OTA"
	open_tables$[9]="OPT_CARTLSDET",  open_opts$[9]="OTA"
	open_tables$[10]="OPT_CARTLSDET2", open_opts$[10]="OTA"
	open_tables$[11]="IVS_PARAMS",   open_opts$[11]="OTA"
	open_tables$[12]="IVM_ITEMMAST",   open_opts$[12]="OTA"
	open_tables$[13]="IVM_ITEMWHSE",   open_opts$[13]="OTA"
	open_tables$[14]="IVM_LSMASTER",   open_opts$[14]="OTA"
	open_tables$[15]="OPC_LINECODE",   open_opts$[15]="OTA"
	open_tables$[16]="ARC_SHIPVIACODE",   open_opts$[16]="OTA"
	open_tables$[17]="OPT_INVKITDET",   open_opts$[17]="OTA"

	gosub open_tables

rem --- Disable all detail grid buttons
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("PACK",0)
	callpoint!.setOptionEnabled("CART",0)

rem --- Initializations
	callpoint!.setDevObject("recordDeleted",0)
	callpoint!.setDevObject("shipping_id","")
	callpoint!.setDevObject("tabFocus",-1)

[[OPT_FILLMNTHDR.BWRI]]
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

[[OPT_FILLMNTHDR.ORDER_NO.AVAL]]
rem --- Validate this is an existing open Order (not Quote) with a printed Picking List
	orderNo$=callpoint!.getUserInput()
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
	
	opeOrdHdr_dev=fnget_dev("OPE_ORDHDR")
	dim opeOrdHdr$:fnget_tpl$("OPE_ORDHDR")
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVHDR","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim opeOrdHdr_key$:key_tpl$
	opeOrdHdr_key.firm_id$=firm_id$
	opeOrdHdr_key.ar_type$=ar_type$
	opeOrdHdr_key.customer_id$=customer_id$
	opeOrdHdr_key.order_no$=orderNo$
	opeOrdHdr_key.ar_inv_no$=""

	rem --- Use of ORDER_NO_LK Element Type guarantees this is an existing open Order or Quote
	readrecord(opeOrdHdr_dev,key=opeOrdHdr_key$,knum="PRIMARY",dom=*next)opeOrdHdr$

	rem --- Must be an Order, not a Quote
	if opeOrdHdr.invoice_type$<>"S" then
		msg_id$ = "OP_NOT_QUOTES"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

	rem --- Picking List must have been printed with no pending reprints
	rem --- NOTE: Picking List cannot be printed when the customer is on Credit Hold.
	if opeOrdHdr.print_status$<>"Y" or opeOrdHdr.reprint_flag$="Y" then
		msg_id$ = "OP_PICK_LST_REQUIRED"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[OPT_FILLMNTHDR.SHIPPING_ID.AVAL]]
rem --- Hold onto shipping_id for use in opt_carthdr
	shipping_id$=callpoint!.getUserInput()
	if shipping_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.SHIPPING_ID") then break
	callpoint!.setDevObject("shipping_id",shipping_id$)

rem --- Zero Freight Amount when using 3rd Party Shipping ID
	if cvs(shipping_id$,2)<>"" then
		optCartHdr_dev=fnget_dev("OPT_CARTHDR")
		dim optCartHdr$:fnget_tpl$("OPT_CARTHDR")
		ar_type$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_TYPE")
		customer_id$=callpoint!.getColumnData("OPT_FILLMNTHDR.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.ORDER_NO")
		ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTHDR.AR_INV_NO")
		optCartHdr_trip$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$
		read(optCartHdr_dev,key=optCartHdr_trip$,knum="AO_STATUS",dom=*next)
		while 1
			optCartHdr_key$=key(optCartHdr_dev,end=*break)
			if pos(optCartHdr_trip$=optCartHdr_key$)<>1 then break
			readrecord(optCartHdr_dev)optCartHdr$
			optCartHdr.freight_amt=0
			writerecord(optCartHdr_dev)optCartHdr$
		wend

		rem --- Need to refresh display of OPT_CARTHDR Freight Amounts
		optFillmntHdr_dev=fnget_dev("OPT_FILLMNTHDR")
		dim optFillmntHdr$:fnget_tpl$("OPT_FILLMNTHDR")
		optFillmntHdr_key$=callpoint!.getRecordKey()
		readrecord(optFillmntHdr_dev,key=optFillmntHdr_key$)optFillmntHdr$
		optFillmntHdr.shipping_id$=shipping_id$
		writerecord(optFillmntHdr_dev)optFillmntHdr$
		callpoint!.setStatus("RECORD:["+optFillmntHdr_key$+"]")
	endif

[[OPT_FILLMNTHDR.<CUSTOM>]]
rem ==========================================================================
get_RGB: rem --- Parse Red, Green and Blue segments from RGB$ string
	rem --- input: RGB$
	rem --- output: R
	rem --- output: G
	rem --- output: B
rem ==========================================================================
	comma1=pos(","=RGB$,1,1)
	comma2=pos(","=RGB$,1,2)
	R=num(RGB$(1,comma1-1))
	G=num(RGB$(comma1+1,comma2-comma1-1))
	B=num(RGB$(comma2+1))

	return



