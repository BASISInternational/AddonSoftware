[[OPT_INVKITDET.ADEL]]
rem --- Set Kit Component grid's kit_detail_changed flag
	callpoint!.setDevObject("kit_details_changed","Y")

[[OPT_INVKITDET.AGDR]]
rem --- Disable by line type
	line_code$ = callpoint!.getColumnData("OPT_INVKITDET.LINE_CODE")
	gosub disable_by_linetype

rem --- Initialize UM_SOLD ListButton except when line type is non-stock
	row = callpoint!.getValidationRow()
	if callpoint!.getDevObject("component_line_type")="N" then
		callpoint!.setColumnEnabled(row,"OPT_INVKITDET.UM_SOLD",1)
	else
		declare BBjStandardGrid grid!
		grid!=Form!.getControl(num(stbl("+GRID_CTL")))
		col_hdr$=callpoint!.getTableColumnAttribute("OPT_INVKITDET.UM_SOLD","LABS")
		col_ref=util.getGridColumnNumber(grid!, col_hdr$)
		row=callpoint!.getValidationRow()
		nxt_ctlID=util.getNextControlID()
		umList!=Form!.addListButton(nxt_ctlID,10,10,100,100,"",$0810$)
		umList!.addItem("")
		grid!.setCellListControl(row,col_ref,umList!)
		grid!.setCellListSelection(row,col_ref,0,0)
		if cvs(callpoint!.getColumnData("OPT_INVKITDET.UM_SOLD"),2)<>"" then
			ivm01_dev=fnget_dev("IVM_ITEMMAST")
			ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
			dim ivm01a$:ivm01_tpl$
			ivm01a_key$=firm_id$+callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
			find record (ivm01_dev,key=ivm01a_key$,err=*endif)ivm01a$

			rem --- Add IVM_ITEMMAST.UNIT_OF_SALE to the ListButton
			umList!.removeAllItems()
			umList!.addItem(ivm01a.unit_of_sale$)
			if callpoint!.getDevObject("sell_purch_um")="Y" and ivm01a.sell_purch_um$="Y" then
				rem --- Add PURCHASE_UM to the ListButton
				umList!.addItem(ivm01a.purchase_um$)
			endif
		endif
		grid!.setCellListControl(row,col_ref,umList!)
		if umList!.getItemCount()>1 then
			rem --- Set existing UM_SOLD as the default.
			if callpoint!.getColumnData("OPT_INVKITDET.UM_SOLD")=umList!.getItemAt(0) then
				grid!.setCellListSelection(row,col_ref,0,1)
			else
				grid!.setCellListSelection(row,col_ref,1,1)
			endif
			callpoint!.setColumnEnabled(row,"OPT_INVKITDET.UM_SOLD",1)
		else
			callpoint!.setColumnData("OPT_INVKITDET.UM_SOLD",umList!.getItemAt(0),1)
			callpoint!.setColumnEnabled(row,"OPT_INVKITDET.UM_SOLD",0)
		endif
	endif

[[OPT_INVKITDET.AGDS]]
rem  --- Report component shortages
	gosub reportShortages

rem --- Warn when custom components are not updated.
	skippedComponents_vect!=callpoint!.getDevObject("skippedComponentsVect")
	if skippedComponents_vect!.size()>0 then
		call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","U","",qty_mask$,0,qty_mask
		call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","I","",ivIMask$,0,0

		warning$=""
		kit_id$=cvs(callpoint!.getColumnData("OPT_INVKITDET.KIT_ID"),3)
		order$=Translate!.getTranslation("AON_ORDER")+": "
		ship$=Translate!.getTranslation("AON_SHIP")+": "
		space=len(order$)+15
		for i=0 to skippedComponents_vect!.size()-1
			skipped_vect!=skippedComponents_vect!.getItem(i)
			item_id$=cvs(fnmask$(skipped_vect!.getItem(0),ivIMask$),3)
			orderqty$=order$+cvs(str(skipped_vect!.getItem(2):qty_mask$),3)
			shipqty$=ship$+cvs(str(skipped_vect!.getItem(1):qty_mask$),3)
			warning$=warning$+item_id$+"    "+orderqty$+pad("",space-len(orderqty$)," ")+shipqty$+$0A$
		next i

		msg_id$="OP_KIT_COMP_UPDATE"
		dim msg_tokens$[2]
		msg_tokens$[1]=kit_id$
		msg_tokens$[2]=warning$
		gosub disp_message
		callpoint!.setStatus("ACTIVATE")
	endif

[[OPT_INVKITDET.AGRE]]
rem --- Skip if (not a new row and not row modified) or row deleted
	this_row = callpoint!.getValidationRow()
	if callpoint!.getGridRowNewStatus(this_row) <> "Y" and callpoint!.getGridRowModifyStatus(this_row) <> "Y" then
		break; rem --- exit callpoint
	endif
	if  callpoint!.getGridRowDeleteStatus(this_row) = "Y"
		break; rem --- exit callpoint
	endif
	
rem --- Warehouse and Item must be correct, don't let user leave corrupt row
	wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
	item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
	warn  = 1

	gosub check_item_whse	

	if callpoint!.getDevObject("item_wh_failed") then 
		callpoint!.setFocus(this_row,"OPT_INVKITDET.ITEM_ID",1)
		break; rem --- exit callpoint
	endif

rem --- Returns
	if num( callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP") ) < 0 then
		callpoint!.setColumnData( "<<DISPLAY>>.QTY_SHIPPED_DSP", callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"),1)
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0",1)
	endif

rem --- Verify Qty Ordered is not 0 for unprinted S, N or P line types
	if pos(callpoint!.getDevObject("component_line_type")="SNP") and cvs(callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG"),2)="" then
		if num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")) = 0
			msg_id$="OP_QTY_ZERO"
			gosub disp_message
			callpoint!.setFocus(this_row,"<<DISPLAY>>.QTY_ORDERED_DSP",1)
			callpoint!.setStatus("ABORT")
			break; rem --- exit callpoint
		endif
	endif

rem --- What is extended price?
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	if pos(callpoint!.getDevObject("component_line_type")="SNP") then
		ext_price = round( num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP")) * unit_price, 2 )
	else
		ext_price = round( num(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE")), 2 )
	endif

rem --- Check for minimum line extension for non-priced kit components
	commit_flag$    = callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")
	qty_backordered = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
	min_ord_amt=callpoint!.getDevObject("min_line_amt")
	if callpoint!.getDevObject("component_line_type") <> "M" and callpoint!.getDevObject("priced_kit") <> "Y" and
:		qty_backorderd = 0         and 
:		commit_flag$ = "Y"         and
:		abs(ext_price) < min_ord_amt 
:	then
		msg_id$ = "OP_LINE_UNDER_MIN"
		dim msg_tokens$[1]
		msg_tokens$[1] = str(min_ord_amt:callpoint!.getDevObject("amount_mask"))
		gosub disp_message
	endif

rem --- Set taxable amount
	if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 	callpoint!.getDevObject("use_tax_service")="Y" then 
		callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
	endif

rem --- Set price and discount for non-priced kits
	if callpoint!.getDevObject("priced_kit") <> "Y" then
		std_price  = num(callpoint!.getColumnData("OPT_INVKITDET.STD_LIST_PRC"))
		disc_per   = num(callpoint!.getColumnData("OPT_INVKITDET.DISC_PERCENT"))
		if std_price then
			callpoint!.setColumnData("OPT_INVKITDET.DISC_PERCENT", str(round(100 - unit_price * 100 / std_price, 2)))
		else
			if disc_per <> 100 then
				round_precision = num(callpoint!.getDevObject("precision"))
				callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC", str(round(unit_price * 100 / (100 - disc_per), round_precision)))
			endif
		endif
	endif

rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	gosub update_record_fields

[[OPT_INVKITDET.AGRN]]
rem --- Initialize kit_whse_item_warned flag
	callpoint!.setDevObject("kit_whse_item_warned","")

rem --- Coming back from Recalc button?
	if callpoint!.getDevObject("rcpr_row")<>"" and callpoint!.getDevObject("priced_kit")<>"Y" then
		callpoint!.setFocus(num(callpoint!.getDevObject("rcpr_row")),"<<DISPLAY>>.UNIT_PRICE_DSP")
		callpoint!.setDevObject("rcpr_row","")
		callpoint!.setDevObject("kit_details_changed","Y")
		break
	endif

rem --- Disable by line type (Needed because Barista is skipping Line Code)
	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow())) <> "Y"
		line_code$ = callpoint!.getColumnData("OPT_INVKITDET.LINE_CODE")
		callpoint!.setColumnData("OPT_INVKITDET.LINE_CODE",line_code$,1); rem --- Make sure current correct line code is displayed re Bug 10052
		gosub disable_by_linetype
	else
		gosub able_backorder
		gosub able_qtyshipped
	endif

rem --- Disable cost if necessary
	if pos(callpoint!.getDevObject("component_line_type")="SP") and num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP")) then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)
	endif

rem --- Set item tax flag
	gosub set_item_taxable

rem --- Set component previous values
	callpoint!.setDevObject("component_prev_unitprice",num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")))
	callpoint!.setDevObject("component_prev_ext_price",num(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE")))
	callpoint!.setDevObject("component_prior_whse",callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID"))
	callpoint!.setDevObject("component_prior_item",callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID"))
	prev_qty_ord=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	callpoint!.setDevObject("component_prev_qty_ord",prev_qty_ord)
	callpoint!.setDevObject("component_prior_qty",prev_qty_ord*num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR")))
	callpoint!.setDevObject("component_prev_shipqty",num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP")))
	callpoint!.setDevObject("component_prev_boqty",num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP")))
	callpoint!.setDevObject("component_prior_commit",callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG"))

rem --- Set buttons
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow()) <> "Y" then
		gosub enable_repricing
		gosub enable_addl_opts
	endif

[[OPT_INVKITDET.AOPT-ADDL]]
rem --- Additional Options
	if callpoint!.getDevObject("component_line_type") = "M" then break

rem --- Setup a templated string to pass information back and forth from form
	declare BBjTemplatedString a!
	tmpl$ =  "LINE_TYPE:C(1)," +
:				"LINE_DROPSHIP:C(1)," +
:				"INVOICE_TYPE:C(1)," +
:				"COMMIT_FLAG:C(1)," +
:				"MAN_PRICE:C(1)," +
:				"PRINT_FLAG:C(1)," +
:				"EST_SHP_DATE:C(8)," +
:				"INTERNAL_SEQ_NO:c(12)," +
:				"STD_LIST_PRC:N(7*)," +
:				"DISC_PERCENT:N(7*)," +
:				"UNIT_PRICE:N(7*)," +
:				"isEditMode:N(1*)"
	a! = BBjAPI().makeTemplatedString(tmpl$)
	
	a!.setFieldValue("LINE_TYPE",  str(callpoint!.getDevObject("component_line_type")))
	a!.setFieldValue("LINE_DROPSHIP", str(callpoint!.getDevObject("component_line_dropship")))
	a!.setFieldValue("INVOICE_TYPE", str(callpoint!.getDevObject("invoice_type")))
	a!.setFieldValue("STD_LIST_PRC", callpoint!.getColumnData("OPT_INVKITDET.STD_LIST_PRC"))
	a!.setFieldValue("DISC_PERCENT", callpoint!.getColumnData("OPT_INVKITDET.DISC_PERCENT"))
	a!.setFieldValue("UNIT_PRICE",   callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	a!.setFieldValue("EST_SHP_DATE", callpoint!.getColumnData("OPT_INVKITDET.EST_SHP_DATE"))
	a!.setFieldValue("COMMIT_FLAG",  callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG"))
	a!.setFieldValue("MAN_PRICE",    callpoint!.getColumnData("OPT_INVKITDET.MAN_PRICE"))
	a!.setFieldValue("PRINT_FLAG",   callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG"))
	a!.setFieldValue("isEditMode",   callpoint!.isEditMode())
	a!.setFieldValue("INTERNAL_SEQ_NO",   callpoint!.getColumnData("OPT_INVKITDET.ORDDET_SEQ_REF"))
	callpoint!.setDevObject("additional_options", a!)

	dim dflt_data$[7,1]
	dflt_data$[1,0] = "STD_LIST_PRC"
	dflt_data$[1,1] = callpoint!.getColumnData("OPT_INVKITDET.STD_LIST_PRC")
	dflt_data$[2,0] = "DISC_PERCENT"
	dflt_data$[2,1] = callpoint!.getColumnData("OPT_INVKITDET.DISC_PERCENT")
	dflt_data$[3,0] = "NET_PRICE"
	dflt_data$[3,1] = callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")
	dflt_data$[4,0] = "EST_SHP_DATE"
	dflt_data$[4,1] = callpoint!.getColumnData("OPT_INVKITDET.EST_SHP_DATE")
	dflt_data$[5,0] = "COMMIT_FLAG"
	dflt_data$[5,1] = callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")
	dflt_data$[6,0] = "MAN_PRICE"
	dflt_data$[6,1] = callpoint!.getColumnData("OPT_INVKITDET.MAN_PRICE")
	dflt_data$[7,0] = "PRINTED"
	dflt_data$[7,1] = callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG")

rem --- Launch form and capture entries
	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPE_ADDL_OPTS", 
:		stbl("+USER_ID"), 
:		"MNT", 
:		"", 
:		table_chans$[all], 
:		"",
:		dflt_data$[all]

	orig_commit$ = callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")

	a! = cast(BBjTemplatedString, callpoint!.getDevObject("additional_options"))
	callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC", a!.getFieldAsString("STD_LIST_PRC"))
	callpoint!.setColumnData("OPT_INVKITDET.DISC_PERCENT", a!.getFieldAsString("DISC_PERCENT"))
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",   a!.getFieldAsString("UNIT_PRICE"))
	callpoint!.setColumnData("OPT_INVKITDET.EST_SHP_DATE", a!.getFieldAsString("EST_SHP_DATE"))
	callpoint!.setColumnData("OPT_INVKITDET.COMMIT_FLAG",  a!.getFieldAsString("COMMIT_FLAG"))
	callpoint!.setColumnData("OPT_INVKITDET.MAN_PRICE",    a!.getFieldAsString("MAN_PRICE"))
	callpoint!.setColumnData("OPT_INVKITDET.PICK_FLAG",    a!.getFieldAsString("PRINT_FLAG"))

rem --- Does a revised picking list need to be printed?
	if a!.getFieldAsString("PRINT_FLAG")="N" and callpoint!.getDevObject("print_status")="Y" and callpoint!.getDevObject("reprint_flag")="Y" then
		callpoint!.setColumnData("OPT_INVKITDET.PICK_FLAG","M")
	endif

rem --- Need to commit?
	committed_changed=0
	if callpoint!.getDevObject("invoice_type")<>"P" and callpoint!.getDevObject("component_line_dropship")="N" then
		if orig_commit$ = "Y" and callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "N" then
			committed_changed=1
			if callpoint!.getDevObject("component_line_type")<>"O" then
				callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0")
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", "0")
				callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", "0")
				callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", "0")
			else
				callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", str(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE")))
				callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", "0")
				callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", "0")
			endif
		endif

		if orig_commit$ = "N" and callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "Y" then
			committed_changed=1
			callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")))
			if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 			callpoint!.getDevObject("use_tax_service")="Y" then 
				callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
			endif
			rem --- Warn if ship quantity is more than currently available.
			gosub check_ship_qty

			if callpoint!.getDevObject("component_line_type")="O" and 
:			num(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE")) = 0 and 
:			num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")) 
:			then
				callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")))
				callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", "0")
				callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC", "0")
			endif
		endif
	endif

	rem --- Extend price if the order quantity has changed
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	ext_price=round(qty_shipped * unit_price, 2)
	callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(ext_price),1)

	rem --- Set taxable amount
	if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 	callpoint!.getDevObject("use_tax_service")="Y" then 
		callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
	endif

	gosub able_backorder
	gosub able_qtyshipped

	callpoint!.setStatus("MODIFIED;REFRESH")

[[OPT_INVKITDET.AOPT-COMM]]
rem --- Invoke the Comments dialog
	gosub comment_entry

[[OPT_INVKITDET.AOPT-RCPR]]
rem --- Are things set to reprice component of non-priced kit?
	if pos(callpoint!.getDevObject("component_line_type")="SP") and callpoint!.getDevObject("priced_kit")<>"Y" then
		qty_ord = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
		if qty_ord then 
			rem --- Do repricing
			conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
			gosub pricing
			callpoint!.setColumnData("OPT_INVKITDET.MAN_PRICE", "N")
			callpoint!.setStatus("MODIFIED")
		endif
	endif

[[OPT_INVKITDET.AREC]]
rem --- Initialize new record based on the kit's detail line
	dim kitDetailLine$:fnget_tpl$("OPT_INVDET")
	kitDetailLine$=callpoint!.getDevObject("kitDetailLine")
	call stbl("+DIR_SYP")+"bas_sequences.bbj", "INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
	callpoint!.setColumnData("OPT_INVKITDET.INTERNAL_SEQ_NO",int_seq_no$)
	callpoint!.setColumnData("OPT_INVKITDET.LINE_CODE",kitDetailLine.line_code$)
	callpoint!.setColumnData("OPT_INVKITDET.KIT_ID",kitDetailLine.item_id$)
	callpoint!.setColumnData("OPT_INVKITDET.WAREHOUSE_ID",kitDetailLine.warehouse_id$)
	callpoint!.setColumnData("OPT_INVKITDET.EST_SHP_DATE",kitDetailLine.est_shp_date$)
	kit_desc$=callpoint!.getDevObject("kit_desc")
	callpoint!.setColumnData("OPT_INVKITDET.MEMO_1024",kit_desc$)
	callpoint!.setColumnData("OPT_INVKITDET.ORDER_MEMO",kit_desc$)
	callpoint!.setColumnData("OPT_INVKITDET.COMMIT_FLAG",kitDetailLine.commit_flag$)

rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPT_INVKITDET.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPT_INVKITDET.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPT_INVKITDET.CREATED_TIME",date(0:"%Hz%mz"))
	callpoint!.setColumnData("OPT_INVKITDET.AUDIT_NUMBER","0")

rem --- Set defaults for new record
	callpoint!.setColumnData("OPT_INVKITDET.MAN_PRICE","N")
	callpoint!.setColumnData("OPT_INVKITDET.ITEM_ID", "")
	callpoint!.setColumnData("OPT_INVKITDET.PICK_FLAG", "")
	callpoint!.setColumnData("OPT_INVKITDET.VENDOR_ID", "")
	callpoint!.setColumnData("OPT_INVKITDET.DROPSHIP", "")
	callpoint!.setColumnData("OPT_INVKITDET.COMP_PER_KIT", "0"); rem --- Zero for custom components not part of the defined kit
	gosub clear_all_numerics

rem --- Disable by line type
	line_code$ = callpoint!.getColumnData("OPT_INVKITDET.LINE_CODE")
	gosub disable_by_linetype

rem --- Initialize detail line for the line_code
	if callpoint!.getDevObject("component_line_type")="O" then
		if cvs(callpoint!.getColumnData("OPT_INVKITDET.ORDER_MEMO"),3) = "" then
			callpoint!.setColumnData("OPT_INVKITDET.ORDER_MEMO",cvs(opc_linecode.code_desc$,3))
			callpoint!.setColumnData("OPT_INVKITDET.MEMO_1024",cvs(opc_linecode.code_desc$,3))
		endif
	endif

	if callpoint!.getDevObject("component_line_type")<>"M" then
		callpoint!.setColumnData("OPT_INVKITDET.CONV_FACTOR","1")
	else
		callpoint!.setColumnData("OPT_INVKITDET.CONV_FACTOR","0")
	endif

	rem --- set Product Type if indicated by line code record
	if opc_linecode.prod_type_pr$ = "D" 
		callpoint!.setColumnData("OPT_INVKITDET.PRODUCT_TYPE", opc_linecode.product_type$)
	else
		callpoint!.setColumnData("OPT_INVKITDET.PRODUCT_TYPE", "")
	endif

	rem --- Initialize UM_SOLD ListButton with a blank item for new rows except when line type is non-stock
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" and callpoint!.getDevObject("component_line_type")<>"N" then
		rem --- Skip if UM_SOLD ListButton is already initialized
		declare BBjStandardGrid grid!
		grid!=Form!.getControl(num(stbl("+GRID_CTL")))
		col_hdr$=callpoint!.getTableColumnAttribute("OPT_INVKITDET.UM_SOLD","LABS")
		col_ref=util.getGridColumnNumber(grid!, col_hdr$)
		row=callpoint!.getValidationRow()
		umList!=null()
		umList!=grid!.getCellListControl(row,col_ref,err=*next)
		if umList!=null() then
			nxt_ctlID=util.getNextControlID()
			umList!=Form!.addListButton(nxt_ctlID,10,10,100,100,"",$0810$)
			umList!.addItem("")
			grid!.setCellListControl(row,col_ref,umList!)
			grid!.setCellListSelection(row,col_ref,0,0)
		endif
	endif

	callpoint!.setDevObject("item_wh_failed",1)

[[OPT_INVKITDET.ASHO]]
rem --- Disable grid for Invoice History Inquiry
	if callpoint!.getDevObject("disable_grid")<>null() and callpoint!.getDevObject("disable_grid")="Y" then
		formControls!=Form!.getAllControls()
		for i=0 to formControls!.size()-1
			nextControl!=formControls!.getItem(i)
			rem --- Grid control type is 107
			if nextControl!.getControlType()=107 then
				nextControl!.setEditable(0)
				break
			endif
		next i
	endif

[[OPT_INVKITDET.AWRI]]
rem --- Has this row been modified?
	if callpoint!.getGridRowModifyStatus( callpoint!.getValidationRow() ) <> "Y" then 
		break; rem --- exit callpoint
	endif

rem --- Set Kit Component grid's kit_detail_changed flag
	callpoint!.setDevObject("kit_details_changed","Y")

rem --- Get current and prior values
	curr_whse$ = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
	curr_item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
	curr_qty   = num(callpoint!.getColumnData("OPT_INVKITDET.QTY_ORDERED"))
	curr_commit$=callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")

	prior_whse$ = callpoint!.getDevObject("component_prior_whse")
	prior_item$ = callpoint!.getDevObject("component_prior_item")
	prior_qty   = callpoint!.getDevObject("component_prior_qty")
	prior_commit$=callpoint!.getDevObject("component_prior_commit")

	line_ship_date$=callpoint!.getColumnData("OPT_INVKITDET.EST_SHP_DATE")
	cust$    = callpoint!.getColumnData("OPT_INVKITDET.CUSTOMER_ID")
	ar_type$ = callpoint!.getColumnData("OPT_INVKITDET.AR_TYPE")
	order$   = callpoint!.getColumnData("OPT_INVKITDET.ORDER_NO")
	invoice_no$= callpoint!.getColumnData("OPT_INVKITDET.AR_INV_NO")
	seq$     = callpoint!.getColumnData("OPT_INVKITDET.INTERNAL_SEQ_NO")

rem --- Don't commit/uncommit Quotes
	if  callpoint!.getDevObject("invoice_type")="P" goto awri_update_hdr

rem --- Update inventory if there have been any changes
	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))="Y" or
:		((curr_whse$<>prior_whse$ or curr_item$<>prior_item$ or curr_qty<>prior_qty) and curr_commit$=prior_commit$) then
		rem --- Initialize inventory item update
		status=999
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then goto awri_update_hdr

		ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
		dim curr_itemmast$:fnget_tpl$("IVM_ITEMMAST")
		read record (ivm_itemmast_dev, key=firm_id$+curr_item$, dom=awri_update_hdr) curr_itemmast$
		if cvs(prior_item$,2)<>"" then
			dim prior_itemmast$:fnget_tpl$("IVM_ITEMMAST")
			read record (ivm_itemmast_dev, key=firm_id$+prior_item$, dom=awri_update_hdr) prior_itemmast$
		endif

		rem --- If item or warehouse is different then uncommit previous, else commit current
		if (prior_whse$<>"" and prior_whse$<>curr_whse$) or (prior_item$<>"" and prior_item$<>curr_item$) then
			rem --- Uncommit prior item and warehouse
			if prior_whse$<>"" and prior_item$<>"" and prior_qty<>0 then
				items$[1] = prior_whse$
				items$[2] = prior_item$
				refs[0]   = prior_qty

				if !pos(prior_itemmast.lotser_flag$="LS") or prior_itemmast.inventoried$<>"Y" then
					if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
					endif
				else
					found_lot=0
					ope_ordlsdet_dev=fnget_dev("OPE_ORDLSDET")
					dim ope_ordlsdet$:fnget_tpl$("OPE_ORDLSDET")
					read (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$,knum="PRIMARY", dom=*next)
					while 1
						read record (ope_ordlsdet_dev, end=*break) ope_ordlsdet$
						if pos(firm_id$+ar_type$+cust$+order$+invoice_no$+seq$=ope_ordlsdet$)<>1 then break
						if pos(ope_ordlsdet.trans_status$="ER")=0 then continue
						found_lot=1
						items$[3] = ope_ordlsdet.lotser_no$
						refs[0]   = ope_ordlsdet.qty_ordered
						if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
								call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
							if status then goto awri_update_hdr
						endif
						remove (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$+ope_ordlsdet.sequence_no$)
					wend
					read (ope_ordlsdet_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

					if found_lot=0
						if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
							call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
							if status then goto awri_update_hdr
						endif
					endif
				endif
			endif

			rem --- Commit quantity for current item and warehouse
			if curr_whse$<>"" and curr_item$<>"" and curr_qty<>0 then
				items$[1] = curr_whse$
				items$[2] = curr_item$
				refs[0]   = curr_qty

				if line_ship_date$<=stbl("OPE_DEF_COMMIT",err=*next) then
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon","CO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then goto awri_update_hdr
				endif
			endif
		endif

rem --- If new record, or item and warehouse haven't changed, then commit difference
		if (prior_whse$="" or prior_whse$=curr_whse$) and (prior_item$="" or prior_item$=curr_item$) then
			rem --- Commit quantity for current item and warehouse
			if curr_whse$<>"" and curr_item$<>"" and curr_qty - prior_qty <> 0
				items$[1] = curr_whse$
				items$[2] = curr_item$
				refs[0]   = curr_qty - prior_qty

				if curr_qty - prior_qty > 0 then
					rem --- Commit
					if line_ship_date$<=stbl("OPE_DEF_COMMIT",err=*next) then
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","CO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
					endif
				else
					rem --- Uncommit
					refs[0]=abs(refs[0])
					if !pos(curr_itemmast.lotser_flag$="LS") or curr_itemmast.inventoried$<>"Y" then
						if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
							call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
							if status then goto awri_update_hdr
						endif
					else
						rem --- Uncommit lotted/serialized and inventoried items
						found_lot=0
						committed_qty=0
						ope_ordlsdet_dev=fnget_dev("OPE_ORDLSDET")
						dim ope_ordlsdet$:fnget_tpl$("OPE_ORDLSDET")
						read (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$,knum="PRIMARY", dom=*next)
						while 1
							extractrecord (ope_ordlsdet_dev, end=*break) ope_ordlsdet$
							if pos(firm_id$+ar_type$+cust$+order$+invoice_no$+seq$=ope_ordlsdet$)<>1 then read(ope_ordlsdet_dev); break
							if pos(ope_ordlsdet.trans_status$="ER")=0 then continue
							found_lot=1
							if committed_qty + ope_ordlsdet.qty_ordered <= curr_qty then
								 committed_qty=committed_qty + ope_ordlsdet.qty_ordered
								continue
							else
								refs[0]=ope_ordlsdet.qty_ordered - (curr_qty - committed_qty)
								committed_qty = curr_qty
							endif
							items$[3] = ope_ordlsdet.lotser_no$
							if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
								call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
								if status then goto awri_update_hdr
							endif
							if ope_ordlsdet.qty_ordered=refs[0] then
								remove (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$+ope_ordlsdet.sequence_no$)
							else
								ope_ordlsdet.qty_ordered=ope_ordlsdet.qty_ordered-refs[0]
								writerecord(ope_ordlsdet_dev)ope_ordlsdet$
							endif
						wend
						read (ope_ordlsdet_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

						if found_lot=0
							if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
								call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
								if status then goto awri_update_hdr
							endif
						endif
					endif
				endif
			endif
		endif
	endif

rem --- Only do the next if the commit flag has been changed (i.e. via Additional button/form)
rem --- Note: AWRI will have been executed before launching that form to do first/main commit.
rem --- When form is dismissed, row is marked modified, so when leaving it, AWRI will fire again,
rem --- and that's when this code should be hit.
	if curr_commit$ <> prior_commit$
		rem --- Initialize inventory item update
		status=999
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then goto awri_update_hdr

		action$=""
		if curr_commit$ ="N" and prior_commit$ = "Y" then action$="UC"
		if curr_commit$ = "Y" and prior_commit$ <> "Y" then action$="CO"

		rem --- uncommit or commit, depending on action$
		if curr_qty<>0 and action$<>"" and curr_item$<>"" then
			items$[1] = curr_whse$
			items$[2] = curr_item$
			refs[0]   = curr_qty

			ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
			dim curr_itemmast$:fnget_tpl$("IVM_ITEMMAST")
			read record (ivm_itemmast_dev, key=firm_id$+curr_item$, dom=awri_update_hdr) curr_itemmast$

		        if action$="CO" or !pos(curr_itemmast.lotser_flag$="LS") or curr_itemmast.inventoried$<>"Y" then
				call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				if status then goto awri_update_hdr
			else
				rem --- Uncommitted lotted/serialized and inventoried items
				found_lot=0
				ope_ordlsdet_dev=fnget_dev("OPE_ORDLSDET")
				dim ope_ordlsdet$:fnget_tpl$("OPE_ORDLSDET")
				read (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$,knum="PRIMARY", dom=*next)
				while 1
					read record (ope_ordlsdet_dev, end=*break) ope_ordlsdet$
					if pos(firm_id$+ar_type$+cust$+order$+invoice_no$+seq$=ope_ordlsdet$)<>1 then break
					if pos(ope_ordlsdet.trans_status$="ER")=0 then continue
					found_lot=1
					items$[3] = ope_ordlsdet.lotser_no$
					refs[0]   = ope_ordlsdet.qty_ordered
					if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
					endif
					remove (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$+ope_ordlsdet.sequence_no$)
				wend
				read (ope_ordlsdet_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

				if found_lot=0
					if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y" then
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
					endif
				endif
			endif
		endif
	endif

awri_update_hdr: rem --- Update header

rem --- set prior's = curr's here, since row has been written
rem --- this way, if we stay on the same row, as will be the case if we've pressed Recalc, Lot/Ser, or Additional buttons,
rem --- then next time thru AWRI it won't see a false difference between curr and pri, so won't over-commit
	callpoint!.setDevObject("component_prior_whse", curr_whse$)
	callpoint!.setDevObject("component_prior_item", curr_item$)
	callpoint!.setDevObject("component_prior_qty", curr_qty)
	callpoint!.setDevObject("component_prior_commit", curr_commit$)

[[OPT_INVKITDET.BDEL]]
rem --- Require existing modified rows be saved before deleting so can't uncommit quantity different from what was committed
	if callpoint!.getGridRowModifyStatus(num(callpoint!.getValidationRow()))="Y" and
:	callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))<>"Y" then
		msg_id$="OP_MODIFIED_DELETE"
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Set qty_ordered to zero rather than deleting the detail line if it's already been printed on a picking list.
	if pos(callpoint!.getDevObject("component_line_type")="NSP") then
		pick_flag$=callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG")
		if pos(pick_flag$="YM") then
			msg_id$="OP_DELETE_ZEROED"
			gosub disp_message
			if msg_opt$="O" then
				callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP","0",1)
				callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP","0",1)
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP","0",1)
				callpoint!.setColumnData("OPT_INVKITDET.QTY_ORDERED","0")
				callpoint!.setColumnData("OPT_INVKITDET.QTY_BACKORD","0")
				callpoint!.setColumnData("OPT_INVKITDET.QTY_SHIPPED","0")
				callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE","0",1)
				callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT","0")
				callpoint!.setColumnData("OPT_INVKITDET.PICK_FLAG","M")
				callpoint!.setDevObject("kit_details_changed","Y")
				callpoint!.setStatus("ACTIVATE-MODIFIED-ABORT")
			else
				callpoint!.setStatus("ACTIVATE-ABORT")
			endif
			break
		endif
	endif

rem --- Update inventory commitments
	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))<>"Y" and
:		callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y"
:	then
		action$="UC"
		gosub uncommit_iv
	endif

[[OPT_INVKITDET.BEND]]
rem  --- Report component shortages
	gosub reportShortages

rem --- No longer working with kit components
	callpoint!.setDevObject("kit_component","N")

[[OPT_INVKITDET.BGDR]]
rem --- Initialize UM_SOLD related <DISPLAY> fields
	conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
	if conv_factor=0 then conv_factor=1
	unit_cost=num(callpoint!.getColumnData("OPT_INVKITDET.UNIT_COST"))*conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP",str(unit_cost))
	qty_ordered=num(callpoint!.getColumnData("OPT_INVKITDET.QTY_ORDERED"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP",str(qty_ordered))
	unit_price=num(callpoint!.getColumnData("OPT_INVKITDET.UNIT_PRICE"))*conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",str(unit_price))
	qty_backord=num(callpoint!.getColumnData("OPT_INVKITDET.QTY_BACKORD"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP",str(qty_backord))
	qty_shipped=num(callpoint!.getColumnData("OPT_INVKITDET.QTY_SHIPPED"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP",str(qty_shipped))
	std_list_prc=num(callpoint!.getColumnData("OPT_INVKITDET.STD_LIST_PRC"))*conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC",str(std_list_prc))

[[OPT_INVKITDET.BSHO]]
rem --- Get the kit's item description
	dim kitDetailLine$:fnget_tpl$("OPT_INVDET")
	kitDetailLine$=callpoint!.getDevObject("kitDetailLine")
	ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
	dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
	findrecord(ivmItemMast_dev,key=firm_id$+kitDetailLine.item_id$)ivmItemMast$
	callpoint!.setDevObject("kitDesc",ivmItemMast.item_desc$)
	call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","I","",ivIMask$,0,0
	item$=cvs(fnmask$(kitDetailLine.item_id$,ivIMask$),3)

	rem --- Displaying a kit' description requires the Inventory item description lengths.
	ivsParams_dev=fnget_dev("IVS_PARAMS")
	dim ivsParams$:fnget_tpl$("IVS_PARAMS")
	findrecord(ivsParams_dev,key=firm_id$+"IV00")ivsParams$
	itemDescLen! = BBjAPI().makeVector()
	itemDescLen!.addItem(num(ivsParams.desc_len_01$))
	itemDescLen!.addItem(num(ivsParams.desc_len_02$))
	itemDescLen!.addItem(num(ivsParams.desc_len_03$))
	itemDesc$=fnitem$(ivmItemMast.item_desc$,itemDescLen!.getItem(0),itemDescLen!.getItem(1),itemDescLen!.getItem(2))
	callpoint!.setDevObject("kit_desc",Translate!.getTranslation("AON_KIT","Kit")+": "+item$+" "+itemDesc$)

rem --- Set column size for memo_1024 field very small so it doesn't take up room, but still available for hover-over of memo contents
	declare BBjStandardGrid grid!
	grid!=Form!.getControl(num(stbl("+GRID_CTL")))
	col_hdr$=callpoint!.getTableColumnAttribute("OPT_INVKITDET.MEMO_1024","LABS")
	memo_1024_col=util.getGridColumnNumber(grid!, col_hdr$)
	grid!.setColumnWidth(memo_1024_col,15)

rem --- Initialize Kit Component grid's kit_detail_changed flag
	callpoint!.setDevObject("kit_details_changed","N")
	callpoint!.setDevObject("kit_component","Y")

[[OPT_INVKITDET.BUDE]]
rem --- Update inventory commitments
	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))<>"Y" and
:		callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y"
:	then
		action$="CO"
		gosub uncommit_iv
	endif

[[OPT_INVKITDET.BWRI]]
rem --- Set values based on line type
	file$ = "OPC_LINECODE"
	dim linecode_rec$:fnget_tpl$(file$)
	line_code$ = callpoint!.getColumnData("OPT_INVKITDET.LINE_CODE")
	find record(fnget_dev(file$), key=firm_id$+line_code$) linecode_rec$

rem --- If line type is Memo, or a priced kit, clear the extended price
	if linecode_rec.line_type$ = "M" or callpoint!.getDevObject("priced_kit")="Y" then 
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", "0")
	endif

rem --- Clear quantities if line type is Memo or Other
	if pos(linecode_rec.line_type$="MO") then
		callpoint!.setColumnData("OPT_INVKITDET.QTY_ORDERED", "0")
		callpoint!.setColumnData("OPT_INVKITDET.QTY_BACKORD", "0")
		callpoint!.setColumnData("OPT_INVKITDET.QTY_SHIPPED", "0")
	endif

rem --- Order quantity is required for unprinted S, N and P line types
	if pos(linecode_rec.line_type$="SNP") and cvs(callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG"),2)="" then
		if num(callpoint!.getColumnData("OPT_INVKITDET.QTY_ORDERED")) = 0 then
			msg_id$="OP_QTY_ZERO"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Set product types for certain line types 
	if pos(linecode_rec.line_type$="NOP") then
		if linecode_rec.prod_type_pr$ = "D" then			
			callpoint!.setColumnData("OPT_INVKITDET.PRODUCT_TYPE", linecode_rec.product_type$)
		else
			if linecode_rec.prod_type_pr$ = "N" then
				callpoint!.setColumnData("OPT_INVKITDET.PRODUCT_TYPE", "")
			endif
		endif
	endif

rem --- Initialize RTP modified fields for modified existing records
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
		callpoint!.setColumnData("OPT_INVKITDET.MOD_USER", sysinfo.user_id$)
		callpoint!.setColumnData("OPT_INVKITDET.MOD_DATE", date(0:"%Yd%Mz%Dz"))
		callpoint!.setColumnData("OPT_INVKITDET.MOD_TIME", date(0:"%Hz%mz"))
	endif

rem --- Does a revised picking list need to be printed?
	if callpoint!.getGridRowModifyStatus(callpoint!.getValidationRow()) ="Y" and
:	callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG")="Y" then
		callpoint!.setColumnData("OPT_INVKITDET.PICK_FLAG","M")
	endif

[[OPT_INVKITDET.EXT_PRICE.AVAL]]
rem --- Round 
	if num(callpoint!.getUserInput()) <> num(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE"))
		callpoint!.setUserInput( str(round( num(callpoint!.getUserInput()), 2)) )
	endif

rem --- For uncommitted "O" line type sales (not quotes), move ext_price to unit_price until committed
	if callpoint!.getDevObject("invoice_type") <> "P" and callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "N" and 
:		callpoint!.getDevObject("component_line_type") = "O" then
		rem --- Don't overwrite existing unit_price with zero
		if num(callpoint!.getUserInput()) then
			callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", callpoint!.getUserInput(),1)
			callpoint!.setUserInput("0")
			callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", "0")
		endif
	endif

[[OPT_INVKITDET.EXT_PRICE.AVEC]]
rem --- Update taxable_amt if ext_price changed
	if num(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE")) <> callpoint!.getDevObject("component_prev_ext_price") then
		if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 		callpoint!.getDevObject("use_tax_service")="Y" then 
			qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
			unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
			ext_price=round(qty_shipped * unit_price, 2)
			callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
		endif
	endif

[[OPT_INVKITDET.EXT_PRICE.BINP]]
rem --- Set previous extended price
	callpoint!.setDevObject("component_prev_ext_price",num(callpoint!.getColumnData("OPT_INVKITDET.EXT_PRICE")))

[[OPT_INVKITDET.ITEM_ID.AINV]]
rem --- Skip check for item synonyms
	callpoint!.setStatus("ABORT")
	break

[[OPT_INVKITDET.ITEM_ID.AVAL]]
rem --- Skip if the item_id has NOT changed
	item$=callpoint!.getUserInput()
	prev_item$=callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
	if cvs(item$,3)=cvs(prev_item$,3) then break

rem --- Don't allow changing the item if the detail line has already been printed on a picking list.
	item$=callpoint!.getUserInput()
	prev_item$=callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
	if pos(callpoint!.getDevObject("component_line_type")="NSP") and cvs(item$,3)<>cvs(prev_item$,3) then
		pick_flag$=callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG")
		if pos(pick_flag$="YM") then
			msg_id$="OP_CANNOT_CHG_ITEM"
			gosub disp_message
			if msg_opt$="O" then
				item$=prev_item$
				callpoint!.setUserInput(item$)
				callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP","0",1)
				callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP","0",1)
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP","0",1)
				callpoint!.setColumnData("OPT_INVKITDET.QTY_ORDERED","0")
				callpoint!.setColumnData("OPT_INVKITDET.QTY_BACKORD","0")
				callpoint!.setColumnData("OPT_INVKITDET.QTY_SHIPPED","0")
				callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE","0",1)
				callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT","0")
				callpoint!.setColumnData("OPT_INVKITDET.PICK_FLAG","M")
				callpoint!.setDevObject("kit_details_changed","Y")
				callpoint!.setStatus("ACTIVATE-MODIFIED")
				gosub clear_all_numerics
			else
				callpoint!.setColumnData("OPT_INVKITDET.ITEM_ID",prev_item$,1)
				callpoint!.setStatus("ACTIVATE-ABORT")
				break
			endif
		endif
	endif

rem "Inventory Inactive Feature"
	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
	dim ivm01a$:ivm01_tpl$
	ivm01a_key$=firm_id$+item$
	find record (ivm01_dev,key=ivm01a_key$,err=*break)ivm01a$
	if ivm01a.item_inactive$="Y" then
		msg_id$="IV_ITEM_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Kits not allowed in the Kit Components grid
	if pos(ivm01a.kit$="YP") then
		msg_id$="OP_KIT_NOT_ALLOW"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Kit components cannot be lotted/serialized
	if pos(ivm01a.lotser_flag$="LS") then
		msg_id$="OP_KIT_NOT_LOTSER"
		dim msg_tokens$[2]
		msg_tokens$[1]=item$
		if ivm01a.lotser_flag$="L" then
			msg_tokens$[2]=Translate!.getTranslation("AON_LOTTED")
		else
			msg_tokens$[2]=Translate!.getTranslation("AON_SERIALIZED")
		endif
		gosub disp_message
		callpoint!.setUserInput("")
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Check item/warehouse combination and setup values
	wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
	if cvs(wh$,2)="" then
        		warn = 0
	else
		rem --- Skip warning if already warned for this whse-item combination
		if callpoint!.getDevObject("kit_whse_item_warned")=wh$+":"+item$ then
			warn = 0
		else
			warn = 1
		endif
	endif
	gosub check_item_whse

	if !callpoint!.getDevObject("item_wh_failed") then 
		conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
		if conv_factor=0 then conv_factor=1
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP", str(ivm02a.unit_cost*conv_factor),1)
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",str(ivm02a.cur_price),1)
		callpoint!.setDevObject("component_price", ivm02a.cur_price)
		qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(round(qty_shipped * ivm02a.cur_price, 2)),1)

		if pos(callpoint!.getDevObject("component_line_prod_type_pr")="DN")=0
			callpoint!.setColumnData("OPT_INVKITDET.PRODUCT_TYPE", ivm01a.product_type$,1)
		endif
		if pos(callpoint!.getDevObject("component_line_type")="SP") and num(ivm02a.unit_cost$)=0
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP",1)
		endif

		rem --- Check if item superseded
		if cvs(item$,3)<>cvs(prev_item$,3) and ivm01a.alt_sup_flag$="S" then
			msg_id$="OP_SUPERSEDED_ITEM"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(item$,2)
			msg_tokens$[2]=cvs(ivm01a.alt_sup_item$,2)
			msg_tokens$[3]=str(callpoint!.getDevObject("component_avail"))
			gosub disp_message
			callpoint!.setStatus("ACTIVATE")
			if msg_opt$="C" then
				callpoint!.setStatus("ABORT")
				break
			else
				if callpoint!.getDevObject("component_avail")<=0 then
					msg_id$="OP_SUPERSEDE_CONFIRM"
					dim msg_tokens$[1]
					msg_tokens$[1]=cvs(item$,2)
					gosub disp_message
					callpoint!.setStatus("ACTIVATE")
					if msg_opt$="N" then
						callpoint!.setStatus("ABORT")
						break
					endif
				endif
			endif
		endif
	endif

rem --- Initialize UM_SOLD ListButton for a new or changed item
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or cvs(item$,3)<>cvs(prev_item$,3) then
		declare BBjStandardGrid grid!
		grid!=Form!.getControl(num(stbl("+GRID_CTL")))
		col_hdr$=callpoint!.getTableColumnAttribute("OPT_INVKITDET.UM_SOLD","LABS")
		col_ref=util.getGridColumnNumber(grid!, col_hdr$)
		row=callpoint!.getValidationRow()
		umList!=grid!.getCellListControl(row,col_ref)
		umList!.removeAllItems()
		if pos(callpoint!.getDevObject("component_line_type")="SP") then
			rem --- Add IVM_ITEMMAST.UNIT_OF_SALE to the ListButton
			umList!.addItem(ivm01a.unit_of_sale$)
			if callpoint!.getDevObject("sell_purch_um")="Y" and ivm01a.sell_purch_um$="Y" then
				rem --- Add PURCHASE_UM to the ListButton
				umList!.addItem(ivm01a.purchase_um$)
			endif
		else
			rem --- Add blank line to the ListButton
			umList!.addItem("")
		endif
		grid!.setCellListControl(row,col_ref,umList!)
		if umList!.getItemCount()>1 then
			rem --- Set existing UM_SOLD as the default.
			if callpoint!.getColumnData("OPT_INVKITDET.UM_SOLD")=umList!.getItemAt(0) then
				grid!.setCellListSelection(row,col_ref,0,1)
				callpoint!.setColumnData("OPT_INVKITDET.UM_SOLD",umList!.getItemAt(0),1)
			else
				grid!.setCellListSelection(row,col_ref,1,1)
				callpoint!.setColumnData("OPT_INVKITDET.UM_SOLD",umList!.getItemAt(1),1)
			endif
			callpoint!.setColumnEnabled(row,"OPT_INVKITDET.UM_SOLD",1)
		else
			callpoint!.setColumnData("OPT_INVKITDET.UM_SOLD",umList!.getItemAt(0),1)
		endif

		rem --- Initialize CONV_FACTOR
		callpoint!.setColumnData("OPT_INVKITDET.CONV_FACTOR","1")
	endif

[[OPT_INVKITDET.ITEM_ID.AVEC]]
rem --- Enable repricing button
	gosub enable_repricing

rem --- Set item tax flag
	gosub set_item_taxable

[[OPT_INVKITDET.ITEM_ID.BINP]]
rem --- Enable repricing and options buttons
	gosub enable_repricing
	gosub enable_addl_opts

[[OPT_INVKITDET.ITEM_ID.BINQ]]
rem --- Inventory Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]=""
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"IV_ITEM_WHSE_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID") then 
		callpoint!.setColumnData("OPT_INVKITDET.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPT_INVKITDET.ITEM_ID",1)
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[OPT_INVKITDET.MEMO_1024.AVAL]]
rem --- Store first part of memo_1024 in order_memo.
rem --- This AVAL is hit if user navigates via arrows or clicks on the memo_1024 field, and double-clicks or ctrl-F to bring up editor.
rem --- If on a memo line or using ctrl-C or Comments button, code in the comment_entry: subroutine is hit instead.

	disp_text$=callpoint!.getUserInput()
	if disp_text$<>callpoint!.getColumnUndoData("OPT_INVKITDET.MEMO_1024")
		memo_len=len(callpoint!.getColumnData("OPT_INVKITDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("OPT_INVKITDET.MEMO_1024",disp_text$)
		callpoint!.setColumnData("OPT_INVKITDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

[[OPT_INVKITDET.ORDER_MEMO.BINP]]
rem --- Invoke the Comments dialog
	gosub comment_entry

[[OPT_INVKITDET.PRODUCT_TYPE.AVAL]]
rem --- Don't allow inactive code
	ivcProdCode_dev=fnget_dev("IVC_PRODCODE")
	dim ivcProdCode$:fnget_tpl$("IVC_PRODCODE")
	prod_code$=callpoint!.getUserInput()
	read record (ivcProdCode_dev,key=firm_id$+"A"+prod_code$,dom=*next)ivcProdCode$
	if ivcProdCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcProdCode.product_type$,3)
		msg_tokens$[2]=cvs(ivcProdCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[<<DISPLAY>>.QTY_BACKORD_DSP.AVAL]]
rem --- Skip if qty_backord not changed
	boqty  = num(callpoint!.getUserInput())
	prev_boqty=callpoint!.getDevObject("component_prev_boqty")
	if boqty = prev_boqty then break

rem --- Re-calculate qty_shipped and ext_price unless already shipping extra or it's a new line.
	ordqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or qty_shipped<=ordqty - prev_boqty then
		qty_shipped = ordqty - boqty
	endif

	if qty_shipped < 0 then
		callpoint!.setUserInput(str(prev_boqty))
		msg_id$ = "BO_EXCEEDS_ORD"
		gosub disp_message
		callpoint!.setStatus("ABORT-REFRESH")
		break; rem --- exit callpoint
	endif

	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_shipped),1)

rem --- Warn if ship quantity is more than currently available.
	gosub check_ship_qty

[[<<DISPLAY>>.QTY_BACKORD_DSP.AVEC]]
rem --- Extend price if the backorder quantity has changed
	if num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP")) <> callpoint!.getDevObject("component_prev_boqty") then
		qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
		ext_price=round(qty_shipped * unit_price, 2)
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(ext_price),1)

		rem --- Set taxable amount
		if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 		callpoint!.getDevObject("use_tax_service")="Y" then 
			callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
		endif
	endif

[[<<DISPLAY>>.QTY_BACKORD_DSP.BINP]]
rem --- Get prev qty / enable repricing, options
	callpoint!.setDevObject("component_prev_boqty",num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP")))
	gosub enable_repricing
	gosub enable_addl_opts

rem --- Has a valid whse/item been entered?
	if callpoint!.getDevObject("item_wh_failed") then 
		item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

[[<<DISPLAY>>.QTY_ORDERED_DSP.AVAL]]
rem --- Skip if qty_ordered not changed
	qty_ord  = num(callpoint!.getUserInput())
	prev_qty_ord=callpoint!.getDevObject("component_prev_qty_ord")
	if qty_ord = prev_qty_ord then break

	if qty_ord = 0 and cvs(callpoint!.getColumnData("OPT_INVKITDET.PICK_FLAG"),2)="" then
		msg_id$="OP_QTY_ZERO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Can NOT change order quantity for a kit's standard components (i.e. this component is part of the defined kit)
	if num(callpoint!.getColumnData("OPT_INVKITDET.COMP_PER_KIT"))<>0 then
		msg_id$="OP_KIT_ITEM_ORDQTY"
		dim msg_tokens$[2]
		msg_tokens$[1] = cvs(callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID"),2)
		msg_tokens$[2] = cvs(callpoint!.getColumnData("OPT_INVKITDET.KIT_ID"),2)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP",str(prev_qty_ord),1)
		break
	endif

rem --- Re-calculate qty_shipped and ext_price unless already shipping extra or it's a new line.
	boqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or qty_shipped<=prev_qty_ord - boqty then
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0",1)
		if qty_ord < 0 then
			callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_ord),1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP",0)
		else
			if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "Y" or callpoint!.getDevObject("invoice_type") = "P" then
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_ord),1)
			else
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", "0",1)
			endif
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP",1)
		endif
	endif

rem --- Recalc quantities
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	if callpoint!.getDevObject("component_line_type") <> "N" and
:		callpoint!.getColumnData("OPT_INVKITDET.MAN_PRICE") <> "Y" and
:		( (qty_ord and qty_ord <> prev_qty_ord) or unit_price = 0 )
:	then
		conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
		gosub pricing
	endif

rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP",str(qty_ord))
	gosub update_record_fields

rem --- Warn if ship quantity is more than currently available.
	gosub check_ship_qty

[[<<DISPLAY>>.QTY_ORDERED_DSP.AVEC]]
rem --- Extend price if the order quantity has changed
	if num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")) <> callpoint!.getDevObject("component_prev_qty_ord") then
		qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
		ext_price=round(qty_shipped * unit_price, 2)
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(ext_price),1)

		rem --- Set taxable amount
		if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 		callpoint!.getDevObject("use_tax_service")="Y" then 
			callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
		endif
	endif

rem --- Enable buttons
	gosub enable_repricing
	gosub enable_addl_opts

rem --- When needed, set focus on Unit Price for non-priced kitts
	if callpoint!.getDevObject("focusPrice")="Y" and callpoint!.getDevObject("priced_kit")="N" then
 		callpoint!.setFocus(callpoint!.getValidationRow(),"<<DISPLAY>>.UNIT_PRICE_DSP",1)
	endif

[[<<DISPLAY>>.QTY_ORDERED_DSP.BINP]]
rem --- Get prev qty / enable repricing, options
	callpoint!.setDevObject("component_prev_qty_ord",num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")))
	gosub enable_repricing
	gosub enable_addl_opts

rem --- Has a valid whse/item been entered?
	if callpoint!.getDevObject("item_wh_failed") then 
		item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

rem --- Init DevObject for use when forcing focus to price, if need-be
	callpoint!.setDevObject("focusPrice","")

[[<<DISPLAY>>.QTY_SHIPPED_DSP.AVAL]]
rem --- Skip if qty_shipped not changed
	shipqty  = num(callpoint!.getUserInput())
	prev_shipqty=callpoint!.getDevObject("component_prev_shipqty")
	if shipqty = prev_shipqty then break

rem --- Warn if ship quantity is more than order quantity
	ordqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	if shipqty > ordqty then
		msg_id$="SHIP_EXCEEDS_ORD"
		dim msg_tokens$[1]
		if ordqty=0 then
			msg_tokens$[1] = "???"
		else
			msg_tokens$[1] = str(round(100*(ordqty-shipqty)/ordqty,1):"###0.0 ")
		endif
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setUserInput(str(prev_shipqty))
			callpoint!.setStatus("ABORT-REFRESH")
			break; rem --- exit callpoint
		endif
		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Back order allowed?
	if callpoint!.getDevObject("allowBO") = "N" or callpoint!.getDevObject("cashSale") = "Y" then
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0",1)
	else
		rem --- Re-calculate qty_shipped and ext_price unless already shipping extra or it's a new line.
		boqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or prev_shipqty<=ordqty - boqty then
			callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", str(max(0, ordqty - shipqty)),1)
		endif
	endif

rem --- Warn if ship quantity is more than currently available.
	gosub check_ship_qty

[[<<DISPLAY>>.QTY_SHIPPED_DSP.AVEC]]
rem --- Extend price if the shipped quantity has changed
	if num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP")) <> callpoint!.getDevObject("component_prev_shipqty") then
		qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
		ext_price=round(qty_shipped * unit_price, 2)
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(ext_price),1)

		rem --- Set taxable amount
		if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 		callpoint!.getDevObject("use_tax_service")="Y" then 
			callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
		endif
	endif

[[<<DISPLAY>>.QTY_SHIPPED_DSP.BINP]]
rem --- Get prev qty / enable repricing, options
	callpoint!.setDevObject("component_prev_shipqty",num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP")))
	gosub enable_repricing
	gosub enable_addl_opts

rem --- Has a valid whse/item been entered?
	if callpoint!.getDevObject("item_wh_failed") then 
		item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

[[OPT_INVKITDET.STD_LIST_PRC.BINP]]
rem --- Enable the Recalc Price and Additional Options buttons
	gosub enable_repricing
	gosub enable_addl_opts

[[OPT_INVKITDET.UM_SOLD.AVAL]]
rem --- Initialize CONV_FACTOR when UM_SOLD changed
	um_sold$=callpoint!.getUserInput()
	prev_um_sold$=callpoint!.getDevObject("prev_um_sold")
	if um_sold$<>prev_um_sold$ then
		conv_factor=1

		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		item$=callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		find record (ivm01_dev,key=firm_id$+item$,err=*endif)ivm01a$
		if um_sold$=ivm01a.purchase_um$ then
			conv_factor=ivm01a.conv_factor
		endif
		callpoint!.setColumnData("OPT_INVKITDET.CONV_FACTOR",str(conv_factor))

		rem --- Re-calculate cost
		ivm02_dev = fnget_dev("IVM_ITEMWHSE")
		dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")
		wh$=callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		read record (ivm02_dev, key=firm_id$+wh$+item$, dom=*endif) ivm02a$
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP", str(ivm02a.unit_cost*conv_factor))

		rem --- Re-calculate price
		qty_ord=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
		gosub pricing
	endif

[[OPT_INVKITDET.UM_SOLD.BINP]]
rem --- Get current CONV_FACTOR so we'll know if it gets changed
	declare BBjStandardGrid dtlGrid!
	dtlGrid!=Form!.getControl(num(stbl("+GRID_CTL")))
	col_hdr$=callpoint!.getTableColumnAttribute("OPT_INVKITDET.UM_SOLD","LABS")
	col_ref=util.getGridColumnNumber(dtlGrid!, col_hdr$)
	row=callpoint!.getValidationRow()
	prev_um_sold$=dtlGrid!.getCellText(row,col_ref)
	callpoint!.setDevObject("prev_um_sold",prev_um_sold$)

[[<<DISPLAY>>.UNIT_COST_DSP.AVAL]]
rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP",str(callpoint!.getUserInput()))
	gosub update_record_fields

[[<<DISPLAY>>.UNIT_PRICE_DSP.AVAL]]
rem --- Set Manual Price flag and round price
	round_precision = num(callpoint!.getDevObject("precision"))
	unit_price = round(num(callpoint!.getUserInput()),round_precision)
	if num(callpoint!.getUserInput()) <> num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
		callpoint!.setUserInput(str(unit_price))
	endif

	prev_unitprice=callpoint!.getDevObject("component_prev_unitprice")
	if pos(callpoint!.getDevObject("component_line_type")="SP") and 
:		prev_unitprice 		and 
:		unit_price <> prev_unitprice 
:	then 
		callpoint!.setColumnData("OPT_INVKITDET.MAN_PRICE", "Y")
	endif

rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",str(unit_price))
	gosub update_record_fields

rem --- Warn if unit price is zero
	if unit_price=0 then
		msg_id$="OP_ZERO_UNIT_PRICE"
		dim msg_tokens$[1]
		msg_tokens$[1] =callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")
		gosub disp_message
		if msg_opt$="N" then
			callpoint!.setStatus("ABORT")
			break
		endif
		callpoint!.setStatus("ACTIVATE")
	endif

[[<<DISPLAY>>.UNIT_PRICE_DSP.AVEC]]
rem --- Extend price if the unit price has changed
	if num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")) <> callpoint!.getDevObject("component_prev_unitprice") then
		qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
		unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
		ext_price=round(qty_shipped * unit_price, 2)
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(ext_price),1)

		rem --- Set taxable amount
		if (callpoint!.getDevObject("component_line_taxable")="Y" and (pos(callpoint!.getDevObject("component_line_type")="OMN") or callpoint!.getDevObject("component_taxable")="Y" )) or
: 		callpoint!.getDevObject("use_tax_service")="Y" then 
			callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", str(ext_price))
		endif
	endif

[[<<DISPLAY>>.UNIT_PRICE_DSP.BINP]]
rem --- Set previous unit price / enable repricing and options
	callpoint!.setDevObject("component_prev_unitprice",num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")))
	gosub enable_repricing
	gosub enable_addl_opts

rem --- Has a valid whse/item been entered?
	if callpoint!.getDevObject("item_wh_failed") then 
		item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

[[OPT_INVKITDET.<CUSTOM>]]
rem =========================================================
reportShortages: rem --- Warn if ship quantity is more than currently available.
rem =========================================================
	if callpoint!.getDevObject("warn_not_avail")="Y" then
		rem --- Get needed masks
		call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","U","",qty_mask$,0,qty_mask
		call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","I","",ivIMask$,0,0

		rem --- Report shortages
		shortage_vect!=callpoint!.getDevObject("shortageVect")
		if shortage_vect!.size()>0 then
			warning$=""
			kit_id$=cvs(callpoint!.getColumnData("OPT_INVKITDET.KIT_ID"),3)
			ship$=Translate!.getTranslation("AON_SHIP")+": "
			available$=Translate!.getTranslation("AON_AVAILABLE")+": "
			space=len(ship$)+15
			for i=0 to shortage_vect!.size()-1
				available_vect!=shortage_vect!.getItem(i)
				item_id$=cvs(fnmask$(available_vect!.getItem(0),ivIMask$),3)
				shipqty$=ship$+cvs(str(available_vect!.getItem(1):qty_mask$),3)
				availqty$=available$+cvs(str(available_vect!.getItem(2):qty_mask$),3)
				warning$=warning$+item_id$+"    "+shipqty$+pad("",space-len(shipqty$)," ")+availqty$+$0A$
			next i

			msg_id$="OP_KIT_EXCEEDS_AVAIL"
			dim msg_tokens$[2]
			msg_tokens$[1]=kit_id$
			msg_tokens$[2]=warning$
			gosub disp_message
			callpoint!.setStatus("ACTIVATE")
		endif
	endif
	shortage_vect!=BBjAPI().makeVector()
	callpoint!.setDevObject("shortageVect",shortage_vect!)

	return

rem ===========================================================================
check_item_whse: rem --- Check that a warehouse record exists for this item
                 rem      IN: wh$
                 rem          item$
                 rem          warn    (1=warn if failed, 0=no warning)
                 rem     OUT: DevObject "item_wh_failed"
rem ===========================================================================
	callpoint!.setDevObject("item_wh_failed",0)
	this_row = callpoint!.getValidationRow()
	if callpoint!.getGridRowDeleteStatus(this_row) <> "Y" then
		if pos(callpoint!.getDevObject("component_line_type")="SP") then
			callpoint!.setDevObject("item_wh_failed",1)
			callpoint!.setDevObject("component_avail",0)
			if cvs(item$, 2) <> "" and cvs(wh$, 2) <> "" then
				ivm02_dev = fnget_dev("IVM_ITEMWHSE")
				dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")
				find record (ivm02_dev, key=firm_id$+wh$+item$, knum="PRIMARY", dom=*endif) ivm02a$
				callpoint!.setDevObject("item_wh_failed",0)
				callpoint!.setDevObject("component_avail",ivm02a.qty_on_hand-ivm02a.qty_commit)
			endif

			if callpoint!.getDevObject("item_wh_failed") and warn then 
				callpoint!.setMessage("IV_NO_WHSE_ITEM")
				callpoint!.setStatus("ABORT")
				callpoint!.setDevObject("whse_item_warned",wh$+":"+item$)
			endif
		endif
	endif

	return

rem =============================================================================
disable_by_linetype: rem --- Set enable/disable based on line type
		rem --- A kit must be a non-dropship line_type S or P item.
		rem --- The kit's components must have the same line_type as the kit.
		rem      IN: line_code$
rem =============================================================================
	opcLineCode_dev=fnget_dev("OPC_LINECODE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
	find record (opcLineCode_dev, key=firm_id$+line_code$, dom=*next) opc_linecode$
	callpoint!.setDevObject("component_line_type",opc_linecode.line_type$)
	callpoint!.setDevObject("component_line_taxable",opc_linecode.taxable_flag$)
	callpoint!.setDevObject("component_line_dropship",opc_linecode.dropship$)
	callpoint!.setDevObject("component_line_prod_type_pr",opc_linecode.prod_type_pr$)

rem --- Disable/enable Item ID
	if pos(opc_linecode.line_type$="SP") then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.ITEM_ID",1)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.ITEM_ID",0)
	endif

rem --- Disable/enable Order Memo
	if pos(opc_linecode.line_type$="MNO") then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.ORDER_MEMO",1)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.ORDER_MEMO",0)
	endif

rem --- Disable/enable Extended Price
	if pos(opc_linecode.line_type$="O") then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.EXT_PRICE",1)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.EXT_PRICE",0)
	endif

	if pos(opc_linecode.line_type$="SP")>0 and num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))<>0 and
:	callpoint!.getDevObject("priced_kit")="N" then
		callpoint!.setOptionEnabled("RCPR",1)
	else
		callpoint!.setOptionEnabled("RCPR",0)
	endif

rem --- Disable/enable UM Sold
	if opc_linecode.line_type$="N" then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.UM_SOLD",1)
	else
		enable_UmSold=0
		if callpoint!.getDevObject("sell_purch_um")="Y" then
			item_id$=callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
			if pos(opc_linecode.line_type$="SP") and cvs(item_id$,2)<>"" then
				ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
				dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
				readrecord(ivm_itemmast_dev,key=firm_id$+item_id$,dom=*endif)ivm_itemmast$
				if ivm_itemmast.sell_purch_um$="Y" then enable_UmSold=1
			endif
		endif
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.UM_SOLD", enable_UmSold)
	endif

rem --- Disable/enable displayed unit price and quantity ordered
	if pos(opc_linecode.line_type$="NSP") then
		if callpoint!.getDevObject("priced_kit")="N" then
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 1)
		else
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 0)
		endif
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_ORDERED_DSP", 1)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 0)
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_ORDERED_DSP", 0)
	endif

rem --- Disable/enable unit cost (can't just enable/disable this field by line type)
	if pos(opc_linecode.line_type$="NSP") = 0 
		rem --- always disable cost if line type Memo or Other
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)
	else
		if opc_linecode.line_type$="N"
			rem --- always have cost enabled for Nonstock
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 1)
		else				
			rem --- Standard or sPecial line 
			rem --- note: when item id is entered, cost will get enabled in that AVAL if S or P and cost = 0 (or dropshippable)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)				
		endif
	endif

rem --- Product Type Processing
	if cvs(line_code$,2) <> "" 
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.PRODUCT_TYPE", 0)
		if opc_linecode.prod_type_pr$ = "E" 
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPT_INVKITDET.PRODUCT_TYPE", 1)
		endif
	endif

rem --- Disable Back orders if necessary
	gosub able_backorder

rem --- Disable qty shipped if necessary
	gosub able_qtyshipped

rem --- Enable Comment button
	callpoint!.setOptionEnabled("COMM",1)

	return

rem ==========================================================================
able_backorder: rem --- All the factors for enabling or disabling back orders
rem ==========================================================================
	if callpoint!.getDevObject("allowBO") = "N" or 
:	pos(callpoint!.getDevObject("component_line_type")="MO") or
:	callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "N" or
:	callpoint!.getDevObject("cashSale") = "Y"
:	then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP", 0)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP", 1)

		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow()) = "Y" then
			callpoint!.setColumnData("OPT_INVKITDET.QTY_BACKORD", "0")
			callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0")
		endif
	endif
    
	return

rem ==========================================================================
able_qtyshipped: rem --- All the factors for enabling or disabling qty shipped
rem ==========================================================================
	if pos(callpoint!.getDevObject("component_line_type")="NSP") and
:	callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "Y"
:	then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP", 1)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP", 0)
	endif

    
	return

rem ==========================================================================
clear_all_numerics: rem --- Clear all order detail numeric fields
rem ==========================================================================
	callpoint!.setColumnData("OPT_INVKITDET.UNIT_COST", "0")
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP","0")
	callpoint!.setColumnData("OPT_INVKITDET.UNIT_PRICE", "0")
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP","0")
	callpoint!.setColumnData("OPT_INVKITDET.QTY_ORDERED", "0")
	callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP","0")
	callpoint!.setColumnData("OPT_INVKITDET.QTY_BACKORD", "0")
	callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP","0")
	callpoint!.setColumnData("OPT_INVKITDET.QTY_SHIPPED", "0")
	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP","0")
	callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC", "0")
	callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", "0")
	callpoint!.setColumnData("OPT_INVKITDET.TAXABLE_AMT", "0")
	callpoint!.setColumnData("OPT_INVKITDET.DISC_PERCENT", "0")
	callpoint!.setColumnData("OPT_INVKITDET.COMM_PERCENT", "0")
	callpoint!.setColumnData("OPT_INVKITDET.COMM_AMT", "0")
	callpoint!.setColumnData("OPT_INVKITDET.SPL_COMM_PCT", "0")

	return

rem ==========================================================================
enable_repricing: rem --- Enable the Recalc Pricing button
rem ==========================================================================
	if pos(callpoint!.getDevObject("component_line_type")="SP") then 
		item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		warn  = 0
		gosub check_item_whse

		if !callpoint!.getDevObject("item_wh_failed") and num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")) and
:		callpoint!.getDevObject("priced_kit")="N" then
			callpoint!.setOptionEnabled("RCPR",1)
		else
			callpoint!.setOptionEnabled("RCPR",0)
		endif
	endif

	return

rem ==========================================================================
enable_addl_opts: rem --- Enable the Additional Options button
rem ==========================================================================
	if callpoint!.getDevObject("component_line_type") <> "M" then 
		item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
		warn  = 0
		gosub check_item_whse

		if ((!callpoint!.getDevObject("item_wh_failed")and num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))) or
:		callpoint!.getDevObject("component_line_type") = "O") then
			callpoint!.setOptionEnabled("ADDL",1)
		else
			callpoint!.setOptionEnabled("ADDL",0)
		endif
	endif

	return

rem ==========================================================================
set_item_taxable: rem --- Set the item taxable flag
rem ==========================================================================
	if pos(callpoint!.getDevObject("component_line_type")="SP") then
		ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
		dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
		item_id$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
		find record (ivmItemMast_dev, key=firm_id$+item_id$, dom=*next)ivmItemMast$
		callpoint!.setDevObject("component_taxable",ivmItemMast.taxable_flag$)
	endif

	rem --- Priced kits are not taxable
	if callpoint!.getDevObject("priced_kit")="Y" then callpoint!.setDevObject("component_taxable","N")

	return

rem ==========================================================================
update_record_fields: rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
rem ==========================================================================
	conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
	if conv_factor=0 then
		conv_factor=1
		callpoint!.setColumnData("OPT_INVKITDET.CONV_FACTOR",str(conv_factor))
	endif
	unit_cost=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP"))/conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.UNIT_COST",str(unit_cost))
	qty_ordered=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))*conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.QTY_ORDERED",str(qty_ordered))
	unit_price=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))/conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.UNIT_PRICE",str(unit_price))
	qty_backord=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))*conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.QTY_BACKORD",str(qty_backord))
	qty_shipped=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))*conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.QTY_SHIPPED",str(qty_shipped))
	std_list_prc=num(callpoint!.getColumnData("OPT_INVKITDET.STD_LIST_PRC"))/conv_factor
	callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC",str(std_list_prc))

	return

rem ==========================================================================
pricing: rem --- Call Pricing routine
         rem      IN: qty_ord, conv_factor
         rem     OUT: price (UNIT_PRICE), disc (DISC_PERCENT), STD_LINE_PRC
         rem          enter_price_message (0/1)
rem ==========================================================================
	round_precision = num(callpoint!.getDevObject("precision"))
	enter_price_message = 0
	callpoint!.setDevObject("focusPrice","")

	wh$   = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
	item$ = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
	cust$ = callpoint!.getColumnData("OPT_INVKITDET.CUSTOMER_ID")
	ord$  = callpoint!.getColumnData("OPT_INVKITDET.ORDER_NO")

	if cvs(item$, 2)="" or cvs(wh$, 2)="" then 
		callpoint!.setStatus("ABORT")
		return
	endif

	warn = 0
	gosub check_item_whse

	if callpoint!.getDevObject("item_wh_failed") then 
		callpoint!.setStatus("ABORT")
		return
	endif

	rem --- Pricing a non-kitted item
	dim pc_files[6]
	pc_files[1] = fnget_dev("IVM_ITEMMAST")
	pc_files[2] = fnget_dev("IVM_ITEMWHSE")
	pc_files[3] = fnget_dev("IVM_ITEMPRIC")
	pc_files[4] = fnget_dev("IVC_PRICCODE")
	pc_files[5] = fnget_dev("ARS_PARAMS")
	pc_files[6] = fnget_dev("IVS_PARAMS")

	call stbl("+DIR_PGM")+"opc_pricing.aon",
:		pc_files[all],
:		firm_id$,
:		wh$,
:		item$,
:		callpoint!.getDevObject("priceCode"),
:		cust$,
:		callpoint!.getDevObject("orderDate"),
:		callpoint!.getDevObject("pricingCode"),
:		qty_ord*conv_factor,
:		typeflag$,
:		price,
:		disc,
:		status

	if status=999 then
		exitto std_exit
	else
		price=price*conv_factor
	endif
	if callpoint!.getDevObject("priced_kit")="Y" then
		price=0
		disc=0
	endif

	if price=0 and callpoint!.getVariableName()<>"<<DISPLAY>>.QTY_ORDERED_DSP" and
:	callpoint!.getDevObject("priced_kit")<>"Y" then
		msg_id$="ENTER_PRICE"
		gosub disp_message
		enter_price_message = 1
		callpoint!.setDevObject("focusPrice","Y")
		callpoint!.setStatus("ACTIVATE")
	else
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", str(round(price, round_precision)),1)
		callpoint!.setColumnData("OPT_INVKITDET.DISC_PERCENT", str(disc))
		callpoint!.setDevObject("focusPrice","")
	endif

	if disc=100 then
		callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC", str(callpoint!.getDevObject("component_price")))
	else
		callpoint!.setColumnData("OPT_INVKITDET.STD_LIST_PRC", str( round((price*100) / (100-disc), round_precision) ))
	endif

	rem --- Recalc and display extended price
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	unit_price = price
	if pos(callpoint!.getDevObject("component_line_type")="NSP")
		callpoint!.setColumnData("OPT_INVKITDET.EXT_PRICE", str(round(qty_shipped * unit_price, 2)),1)
	endif
	callpoint!.setDevObject("component_prev_unitprice",unit_price)

	return

rem =========================================================
check_ship_qty: rem --- Warn if ship quantity is more than currently available.
rem =========================================================
	if callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG") = "Y" and callpoint!.getDevObject("component_line_type") <> "N" and
:	callpoint!.getColumnData("OPT_INVKITDET.DROPSHIP") <> "Y" then
		conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
		if conv_factor=0 then
			conv_factor=1
			callpoint!.setColumnData("OPT_INVKITDET.CONV_FACTOR",str(conv_factor))
		endif

		shipqty=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))*conv_factor
		prev_available=callpoint!.getDevObject("component_avail")
		curr_available=prev_available+callpoint!.getDevObject("component_prior_qty")
		if shipqty>curr_available then
			rem --- Add this shortage to the shortage_vect!
			shortage_vect!=callpoint!.getDevObject("shortageVect")
			available_vect!=BBjAPI().makeVector()
			available_vect!.addItem(callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID"))
			available_vect!.addItem(shipqty)
			available_vect!.addItem(curr_available)
			shortage_vect!.addItem(available_vect!)
			callpoint!.setDevObject("shortageVect",shortage_vect!)

			if callpoint!.getDevObject("warn_not_avail")="Y" then
				msg_id$="SHIP_EXCEEDS_AVAIL"
				gosub disp_message
				callpoint!.setStatus("ACTIVATE")
			endif
		endif
	endif
	return

rem ==========================================================================
uncommit_iv: rem --- Uncommit Inventory
             rem --- Make sure action$ is set before entry
rem ==========================================================================
	ord_type$ = callpoint!.getDevObject("invoice_type")
	wh$      = callpoint!.getColumnData("OPT_INVKITDET.WAREHOUSE_ID")
	item$    = callpoint!.getColumnData("OPT_INVKITDET.ITEM_ID")
	line_ship_date$=callpoint!.getColumnData("OPT_INVKITDET.EST_SHP_DATE")
	ord_qty  = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	conv_factor=num(callpoint!.getColumnData("OPT_INVKITDET.CONV_FACTOR"))
	if conv_factor=0 then conv_factor=1

	if cvs(item$, 2)<>"" and cvs(wh$, 2)<>"" and ord_qty and ord_type$<>"P" and callpoint!.getDevObject("component_line_dropship")="N" then
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

		items$[1]=wh$
		items$[2]=item$
		refs[0]=ord_qty*conv_factor

		if (action$="CO" and line_ship_date$<=stbl("OPE_DEF_COMMIT",err=*next)) or
:		(callpoint!.getColumnData("OPT_INVKITDET.COMMIT_FLAG")="Y") then
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		endif
	endif

	return

rem ==========================================================================
comment_entry:
rem --- On a line where you can access the memo/non-stock (order_memo) field, pop the new memo_1024 editor instead.
rem --- The editor can be popped on demand for any line using the Comments button (alt-C),
rem --- but will automatically pop for lines where the order_memo field is enabled.
rem ==========================================================================

	disp_text$=callpoint!.getColumnData("OPT_INVKITDET.MEMO_1024")
	sv_disp_text$=disp_text$

	editable$="YES"
	force_loc$="NO"
	baseWin!=null()
	startx=0
	starty=0
	shrinkwrap$="NO"
	html$="NO"
	dialog_result$=""

	call stbl("+DIR_SYP")+ "bax_display_text.bbj",
:		"Pick List/Invoice Comments",
:		disp_text$, 
:		table_chans$[all], 
:		editable$, 
:		force_loc$, 
:		baseWin!, 
:		startx, 
:		starty, 
:		shrinkwrap$, 
:		html$, 
:		dialog_result$

	if disp_text$<>sv_disp_text$
		memo_len=len(callpoint!.getColumnData("OPT_INVKITDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("OPT_INVKITDET.MEMO_1024",disp_text$)
		callpoint!.setColumnData("OPT_INVKITDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE")

	return

rem ==========================================================================
rem 	Use util object
rem ==========================================================================

	use ::ado_util.src::util

rem ==========================================================================
rem --- fnmask$: Alphanumeric Masking Function (formerly fnf$)
rem ==========================================================================
    def fnmask$(q1$,q2$)
        if cvs(q1$,2)="" return ""
        if q2$="" q2$=fill(len(q1$),"0")
        if pos("E"=cvs(q1$,4)) goto alpha_mask
:      else return str(-num(q1$,err=alpha_mask):q2$,err=alpha_mask)
alpha_mask:
        q=1
        q0=0
        while len(q2$(q))
            if pos(q2$(q,1)="-()") q0=q0+1 else q2$(q,1)="X"
            q=q+1
        wend
        if len(q1$)>len(q2$)-q0 q1$=q1$(1,len(q2$)-q0)
        return str(q1$:q2$)
    fnend

rem ==========================================================================
rem --- Format inventory item description
rem ==========================================================================
    def fnitem$(q$,q1,q2,q3)
        q$=pad(q$,q1+q2+q3)
        return cvs(q$(1,q1)+" "+q$(q1+1,q2)+" "+q$(q1+q2+1,q3),32)
    fnend



