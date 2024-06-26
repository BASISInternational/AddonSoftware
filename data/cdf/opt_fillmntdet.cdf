[[OPT_FILLMNTDET.AGCL]]
rem --- Get and hold on to columns for qty_picked_dsp and qty_shipped_dsp
	pickGrid!=callpoint!.getDevObject("pickGrid")
	picked_hdr$=callpoint!.getTableColumnAttribute("<<DISPLAY>>.QTY_PICKED_DSP","LABS")
	picked_col=util.getGridColumnNumber(pickGrid!,picked_hdr$)
	callpoint!.setDevObject("picked_col",picked_col)
	shipped_hdr$=callpoint!.getTableColumnAttribute("<<DISPLAY>>.QTY_SHIPPED_DSP","LABS")
	shipped_col=util.getGridColumnNumber(pickGrid!,shipped_hdr$)
	callpoint!.setDevObject("shipped_col",shipped_col)

rem --- Create linetypeMap, dropshipMap and unitcostMap HashMaps
	linetypeMap!= new java.util.HashMap()
	callpoint!.setDevObject("linetypeMap",linetypeMap!)
	dropshipMap!= new java.util.HashMap()
	callpoint!.setDevObject("dropshipMap",dropshipMap!)
	unitcostMap!= new java.util.HashMap()
	callpoint!.setDevObject("unitcostMap",unitcostMap!)

[[OPT_FILLMNTDET.AGDR]]
rem --- Get corresponding order detail line.
	opeOrdDet_dev=fnget_dev("OPE_ORDDET")
	dim opeOrdDet$:fnget_tpl$("OPE_ORDDET")
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_FILLMNTDET.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_INV_NO")
	orddet_seq_ref$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDDET_SEQ_REF")
	opeOrdDet_key$=firm_id$+ar_type$+customer_id$+order_no$+ar_inv_no$+orddet_seq_ref$
	findrecord(opeOrdDet_dev,key=opeOrdDet_key$,dom=*next)opeOrdDet$

	unitcostMap!=callpoint!.getDevObject("unitcostMap")
	unitcostMap!.put(callpoint!.getValidationRow(),opeOrdDet.unit_cost)

	rem --- Do NOT allow returns!
	qty_picked=num(callpoint!.getColumnData("OPT_FILLMNTDET.QTY_PICKED"))
	ship_qty=num(callpoint!.getColumnData("OPT_FILLMNTDET.QTY_SHIPPED"))

rem --- What is this line type? Is this a dropship detail line?
	curr_row=callpoint!.getValidationRow()
	pickGrid!=callpoint!.getDevObject("pickGrid")
	picked_col=callpoint!.getDevObject("picked_col")
	linetypeMap!=callpoint!.getDevObject("linetypeMap")
	dropshipMap!=callpoint!.getDevObject("dropshipMap")
	opcLineCode_dev=fnget_dev("OPC_LINECODE")
	dim opcLineCode$:fnget_tpl$("OPC_LINECODE")
	findrecord (opcLineCode_dev, key=firm_id$+opeOrdDet.line_code$, dom=*next)opcLineCode$
	linetypeMap!.put(curr_row,opcLineCode.line_type$)
	dropshipMap!.put(curr_row,opcLineCode.dropship$)
	if pos(opcLineCode.line_type$="MO") or opcLineCode.dropship$="Y" or ship_qty<=0 then
		pickGrid!.setRowFont(curr_row,callpoint!.getDevObject("italicFont"))
		pickGrid!.setRowForeColor(curr_row,callpoint!.getDevObject("disabledColor"))
		pickGrid!.setCellEditable(curr_row,picked_col,0)
	else
		if qty_picked<>ship_qty then
			pickGrid!.setCellFont(curr_row,picked_col,callpoint!.getDevObject("boldFont"))
			pickGrid!.setCellForeColor(curr_row,picked_col,callpoint!.getDevObject("redColor"))
		else
			pickGrid!.setCellFont(curr_row,picked_col,callpoint!.getDevObject("plainFont"))
			pickGrid!.setCellForeColor(curr_row,picked_col,callpoint!.getDevObject("blackColor"))
		endif
		if callpoint!.getDevObject("all_packed")<>"Y" and callpoint!.isEditMode() then
			if callpoint!.isEditMode() then
				pickGrid!.setCellEditable(curr_row,picked_col,1)
			else
				pickGrid!.setCellEditable(curr_row,picked_col,0)
			endif
		else
			rem --- Cannot change qty_picked when "All Packed"
			pickGrid!.setCellEditable(curr_row,picked_col,0)
		endif
	endif

[[OPT_FILLMNTDET.AGDS]]
rem --- Provide visual warning when quantity picked is NOT equal to the ship quantity
	pickGrid!=callpoint!.getDevObject("pickGrid")
	rows=pickGrid!.getNumRows()
	if rows<2 then break

	picked_col=callpoint!.getDevObject("picked_col")
	shipped_col=callpoint!.getDevObject("shipped_col")
	dropshipMap!=callpoint!.getDevObject("dropshipMap")
	linetypeMap!=callpoint!.getDevObject("linetypeMap")
	for i=0 to rows-2
		qty_picked=num(pickGrid!.getCellText(i,picked_col))
		ship_qty=num(pickGrid!.getCellText(i,shipped_col))
		if qty_picked<>ship_qty and dropshipMap!.get(i)<>"Y" and pos(linetypeMap!.get(i)="MO")=0 and
:		qty_picked>=0 and ship_qty>=0 then
			pickGrid!.setCellFont(i,picked_col,callpoint!.getDevObject("boldFont"))
			pickGrid!.setCellForeColor(i,picked_col,callpoint!.getDevObject("redColor"))
			if callpoint!.getDevObject("all_packed")<>"Y" then
				pickGrid!.setCellEditable(i,picked_col,1)
			else
				rem --- Cannot change qty_picked when "All Packed"
				pickGrid!.setCellEditable(i,picked_col,0)
			endif
		else
			if dropshipMap!.get(i)="Y" or pos(linetypeMap!.get(i)="MO") or qty_picked<0 or ship_qty<0 then
				pickGrid!.setCellFont(i,picked_col,callpoint!.getDevObject("italicFont"))
				pickGrid!.setCellForeColor(i,picked_col,callpoint!.getDevObject("disabledColor"))
				pickGrid!.setCellEditable(i,picked_col,0)
			else
				pickGrid!.setCellFont(i,picked_col,callpoint!.getDevObject("plainFont"))
				pickGrid!.setCellForeColor(i,picked_col,callpoint!.getDevObject("blackColor"))
				if callpoint!.getDevObject("all_packed")<>"Y"and callpoint!.isEditMode() then
					pickGrid!.setCellEditable(i,picked_col,1)
				else
					rem --- Cannot change qty_picked when "All Packed"
					pickGrid!.setCellEditable(i,picked_col,0)
				endif
			endif
		endif
	next i

[[OPT_FILLMNTDET.AGRE]]
rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	gosub update_record_fields

[[OPT_FILLMNTDET.AGRN]]
rem --- Auto launch lot/serial grid once
	callpoint!.setDevObject("autoLaunchGrid",1)

rem --- Force focus on the row's qty_picked cell
	row=callpoint!.getValidationRow()
	callpoint!.setFocus(row,"<<DISPLAY>>.QTY_PICKED_DSP",1)

rem --- Enable/disable qty_picked cell
	pickGrid!=callpoint!.getDevObject("pickGrid")
	disabledColor!=callpoint!.getDevObject("disabledColor")
	picked_col=callpoint!.getDevObject("picked_col")
	if pickGrid!.getCellForeColor(row,picked_col)=disabledColor! then
		pickGrid!.setCellEditable(row,picked_col,0)
	else
		if callpoint!.getDevObject("all_packed")="Y" then
			pickGrid!.setCellEditable(row,picked_col,0)
		else
			if callpoint!.isEditMode() then
				pickGrid!.setCellEditable(row,picked_col,1)
			else
				pickGrid!.setCellEditable(row,picked_col,0)
			endif
		endif
	endif

rem --- Get order detail line unit_cost
	unitcostMap!=callpoint!.getDevObject("unitcostMap")
	callpoint!.setDevObject("unit_cost",unitcostMap!.get(row))

rem --- Is this a dropship detail line?
	dropshipMap!=callpoint!.getDevObject("dropshipMap")
	if dropshipMap!.get(row)="Y" then
		callpoint!.setDevObject("dropship_line","Y")
	else
		callpoint!.setDevObject("dropship_line","N")
	endif

 rem --- Enable/disable lotted/serialized button
	item_id$ = callpoint!.getColumnData("OPT_FILLMNTDET.ITEM_ID")
	ship_qty  = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	gosub lot_ser_check

	if callpoint!.isEditMode() and lotser_item$="Y" and ship_qty>0 and dropshipMap!.get(row)<>"Y"  then
		callpoint!.setOptionEnabled("LENT",1)
	else
		callpoint!.setOptionEnabled("LENT",0)
	endif

rem --- Enable Pack Carton button if, and only if, the QTY_PICKED_DSP is enabled
	linetypeMap!=callpoint!.getDevObject("linetypeMap")
	ship_qty=num(callpoint!.getColumnData("OPT_FILLMNTDET.QTY_SHIPPED"))
	qty_picked=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_PICKED_DSP"))
	if !callpoint!.isEditMode() or ship_qty<=0 or qty_picked<0 or dropshipMap!.get(row)="Y" or  pos(linetypeMap!.get(row)="MO") then
		callpoint!.setOptionEnabled("PACK",0)
	else
		callpoint!.setOptionEnabled("PACK",1)
	endif

[[OPT_FILLMNTDET.AOPT-LENT]]
rem --- Is this item lot/serial?
	item_id$=callpoint!.getColumnData("OPT_FILLMNTDET.ITEM_ID")
	gosub lot_ser_check
	if lotser_item$="Y" then
		ar_type$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_TYPE")
		cust$=callpoint!.getColumnData("OPT_FILLMNTDET.CUSTOMER_ID")
		order$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDER_NO")
		invoice$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_INV_NO")
		seq_ref$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDDET_SEQ_REF")

		key_pfx$=firm_id$+"E"+ar_type$+cust$+order$+invoice$+seq_ref$

		rem --- Pass additional info needed in OPT_FILLMNTLSDET
		callpoint!.setDevObject("item_ship_qty", callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		callpoint!.setDevObject("wh",callpoint!.getColumnData("OPT_FILLMNTDET.WAREHOUSE_ID"))
		callpoint!.setDevObject("item_id",callpoint!.getColumnData("OPT_FILLMNTDET.ITEM_ID"))
		callpoint!.setDevObject("ship_qty",callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))

		call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:			"OPT_FILLMNTLSDET", 
:			stbl("+USER_ID"), 
:			"MNT" ,
:			key_pfx$, 
:			table_chans$[all], 
:			dflt_data$[all]

		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Has the total quantity picked changed?
	start_qty_picked=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_PICKED_DSP"))
	total_picked=callpoint!.getDevObject("total_picked")
	if total_picked<>start_qty_picked then
		callpoint!.setColumnData("<<DISPLAY>>.QTY_PICKED_DSP",str(total_picked),1)
		callpoint!.setStatus("MODIFIED")
	endif

[[OPT_FILLMNTDET.AOPT-PACK]]
rem --- Launch Item Packing grid
	ar_type$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_TYPE")
	customer_id$=callpoint!.getColumnData("OPT_FILLMNTDET.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDER_NO")
	ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_INV_NO")
	orddet_seq_ref$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDDET_SEQ_REF")

	key_pfx$=firm_id$+"E"+ar_type$+customer_id$+order_no$+ar_inv_no$+orddet_seq_ref$

	rem --- Pass additional info needed in OPT_CARTDET2
	callpoint!.setDevObject("warehouse_id",callpoint!.getColumnData("OPT_FILLMNTDET.WAREHOUSE_ID"))
	callpoint!.setDevObject("item_id",callpoint!.getColumnData("OPT_FILLMNTDET.ITEM_ID"))
	callpoint!.setDevObject("order_memo",callpoint!.getColumnData("OPT_FILLMNTDET.ORDER_MEMO"))
	callpoint!.setDevObject("um_sold", callpoint!.getColumnData("OPT_FILLMNTDET.UM_SOLD"))
	callpoint!.setDevObject("qty_picked", callpoint!.getColumnData("OPT_FILLMNTDET.QTY_PICKED"))

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPT_CARTDET2", 
:		stbl("+USER_ID"), 
:		"MNT" ,
:		key_pfx$, 
:		table_chans$[all], 
:		dflt_data$[all]

	callpoint!.setStatus("ACTIVATE")

[[OPT_FILLMNTDET.AREC]]
rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPT_FILLMNTDET.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPT_FILLMNTDET.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPT_FILLMNTDET.CREATED_TIME",date(0:"%Hz%mz"))

rem --- Buttons start disabled
	callpoint!.setOptionEnabled("LENT",0)

[[OPT_FILLMNTDET.BDGX]]
rem --- Disable detail-only buttons
	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("PACK",0)

[[OPT_FILLMNTDET.BGDR]]
rem --- Initialize UM_SOLD related <DISPLAY> fields
	conv_factor=num(callpoint!.getColumnData("OPT_FILLMNTDET.CONV_FACTOR"))
	if conv_factor=0 then conv_factor=1
	qty_shipped=num(callpoint!.getColumnData("OPT_FILLMNTDET.QTY_SHIPPED"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP",str(qty_shipped),1)
	qty_picked=num(callpoint!.getColumnData("OPT_FILLMNTDET.QTY_PICKED"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_PICKED_DSP",str(qty_picked),1)

[[OPT_FILLMNTDET.BWRI]]
rem --- Initialize RTP modified fields for modified existing records
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
		callpoint!.setColumnData("OPT_FILLMNTDET.MOD_USER", sysinfo.user_id$)
		callpoint!.setColumnData("OPT_FILLMNTDET.MOD_DATE", date(0:"%Yd%Mz%Dz"))
		callpoint!.setColumnData("OPT_FILLMNTDET.MOD_TIME", date(0:"%Hz%mz"))
	endif

[[<<DISPLAY>>.QTY_PICKED_DSP.AVAL]]
rem --- Auto launch lot/serial grid once
	callpoint!.setDevObject("autoLaunchGrid",1)

rem --- Do not allow returns
	qty_picked=num(callpoint!.getUserInput())
	if qty_picked<0 then
		msg_id$ = "OP_INV_FOR_RETURNS"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- For lot/serial items, item qty_picked must equal sum of lot/serial number qty_picked
	if callpoint!.getDevObject("lotser_item")="Y" then
		lotser_picked=0
		optFillmntLsDet_dev=fnget_dev("OPT_FILLMNTLSDET")
		dim optFillmntLsDet$:fnget_tpl$("OPT_FILLMNTLSDET")
		trans_status$=callpoint!.getColumnData("OPT_FILLMNTDET.TRANS_STATUS")
		ar_type$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_TYPE")
		customer_id$=callpoint!.getColumnData("OPT_FILLMNTDET.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDER_NO")
		ar_inv_no$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_INV_NO")
		orddet_seq_ref$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDDET_SEQ_REF")
		optFillmntDet_key$=firm_id$+trans_status$+ar_type$+customer_id$+order_no$+ar_inv_no$+orddet_seq_ref$
		read(optFillmntLsDet_dev,key=optFillmntDet_key$,knum="AO_STATUS",dom=*next)
		while 1
			optFillmntLsDet_key$=key(optFillmntLsDet_dev,end=*break)
			if pos(optFillmntDet_key$=optFillmntLsDet_key$)<>1 then break
			readrecord(optFillmntLsDet_dev)optFillmntLsDet$
			lotser_picked=lotser_picked+optFillmntLsDet.qty_picked
		wend

		if qty_picked<>lotser_picked then
			msg_id$ = "OP_SUM_LOTSER_PICKED"
			dim msg_tokens$[1]
			msg_tokens$[1]=str(lotser_picked)
			gosub disp_message
			callpoint!.setStatus("ABORT")
			callpoint!.setColumnData("<<DISPLAY>>.QTY_PICKED_DSP",str(lotser_picked),1)
			break
		endif
	endif

rem --- Provide visual warning when quantity picked is NOT equal to the ship quantity
	ship_qty=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	pickGrid!=callpoint!.getDevObject("pickGrid")
	curr_row=num(callpoint!.getValidationRow())
	picked_col=callpoint!.getDevObject("picked_col")

	if qty_picked<>ship_qty then
		pickGrid!.setCellFont(curr_row,picked_col,callpoint!.getDevObject("boldFont"))
		pickGrid!.setCellForeColor(curr_row,picked_col,callpoint!.getDevObject("redColor"))
	else
		pickGrid!.setCellFont(curr_row,picked_col,callpoint!.getDevObject("plainFont"))
		pickGrid!.setCellForeColor(curr_row,picked_col,callpoint!.getDevObject("blackColor"))
	endif

rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.QTY_PICKED_DSP",str(qty_picked))
	gosub update_record_fields

[[<<DISPLAY>>.QTY_PICKED_DSP.BINP]]
rem --- Automatically launch OPT_FILLMNTLSDET grid for lot/serial items
	item_id$=callpoint!.getColumnData("OPT_FILLMNTDET.ITEM_ID")
	gosub lot_ser_check
	if lotser_item$="Y" and 	callpoint!.getDevObject("autoLaunchGrid") then
		rem --- Get order detail line unit_cost
		unitcostMap!=callpoint!.getDevObject("unitcostMap")
		callpoint!.setDevObject("unit_cost",unitcostMap!.get(row))

		callpoint!.setDevObject("autoLaunchGrid",0)
		ar_type$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_TYPE")
		cust$=callpoint!.getColumnData("OPT_FILLMNTDET.CUSTOMER_ID")
		order$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDER_NO")
		invoice$=callpoint!.getColumnData("OPT_FILLMNTDET.AR_INV_NO")
		seq_ref$=callpoint!.getColumnData("OPT_FILLMNTDET.ORDDET_SEQ_REF")

		key_pfx$=firm_id$+"E"+ar_type$+cust$+order$+invoice$+seq_ref$

		rem --- Pass additional info needed in OPT_FILLMNTLSDET
		callpoint!.setDevObject("item_ship_qty", callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		callpoint!.setDevObject("wh",callpoint!.getColumnData("OPT_FILLMNTDET.WAREHOUSE_ID"))
		callpoint!.setDevObject("item_id",callpoint!.getColumnData("OPT_FILLMNTDET.ITEM_ID"))
		callpoint!.setDevObject("ship_qty",callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))

		call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:			"OPT_FILLMNTLSDET", 
:			stbl("+USER_ID"), 
:			"MNT" ,
:			key_pfx$, 
:			table_chans$[all], 
:			dflt_data$[all]

		callpoint!.setStatus("ACTIVATE")

		rem --- Has the total quantity picked changed?
		start_qty_picked=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_PICKED_DSP"))
		total_picked=callpoint!.getDevObject("total_picked")
		if total_picked<>start_qty_picked then
			callpoint!.setColumnData("<<DISPLAY>>.QTY_PICKED_DSP",str(total_picked),1)
			callpoint!.setStatus("MODIFIED")
		endif

		rem --- Provide visual warning when quantity picked is NOT equal to the ship quantity
		ship_qty=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		pickGrid!=callpoint!.getDevObject("pickGrid")
		curr_row=num(callpoint!.getValidationRow())
		picked_col=callpoint!.getDevObject("picked_col")

		if total_picked<>ship_qty then
			pickGrid!.setCellFont(curr_row,picked_col,callpoint!.getDevObject("boldFont"))
			pickGrid!.setCellForeColor(curr_row,picked_col,callpoint!.getDevObject("redColor"))
		else
			pickGrid!.setCellFont(curr_row,picked_col,callpoint!.getDevObject("plainFont"))
			pickGrid!.setCellForeColor(curr_row,picked_col,callpoint!.getDevObject("blackColor"))
		endif
	endif

[[OPT_FILLMNTDET.<CUSTOM>]]
rem ==========================================================================
lot_ser_check: rem --- Check for lotted/serialized item
               rem      IN: item_id$
               rem   OUT: lotser_item$
rem ==========================================================================
	lotser_item$="N"
	if cvs(item_id$, 2)<>""
		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		read record (ivm01_dev, key=firm_id$+item_id$, dom=*endif) ivm01a$
		if pos(ivm01a.lotser_flag$="LS") then lotser_item$="Y"
		callpoint!.setDevObject("lotser_item",lotser_item$)
		callpoint!.setDevObject("lotser_flag",ivm01a.lotser_flag$)
	endif


	return

rem ==========================================================================
update_record_fields: rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
rem ==========================================================================
	conv_factor=num(callpoint!.getColumnData("OPT_FILLMNTDET.CONV_FACTOR"))
	if conv_factor=0 then conv_factor=1
	qty_shipped=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))*conv_factor
	callpoint!.setColumnData("OPT_FILLMNTDET.QTY_SHIPPED",str(qty_shipped))
	qty_picked=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_PICKED_DSP"))*conv_factor
	callpoint!.setColumnData("OPT_FILLMNTDET.QTY_PICKED",str(qty_picked))

	return

rem ==========================================================================
rem 	Use util object
rem ==========================================================================
	use ::ado_util.src::util



