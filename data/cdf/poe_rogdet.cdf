[[POE_ROGDET.ADGE]]
rem --- Get the grid column for Qty Returned
	grid! = util.getGrid(Form!)
	grid_hdr$=callpoint!.getTableColumnAttribute("POE_ROGDET.QTY_RETURNED","LABS")
	grid_col=util.getGridColumnNumber(grid!,grid_hdr$)
	callpoint!.setDevObject("qtyReturned_col",grid_col)

[[POE_ROGDET.AGCL]]
rem --- Set column size for memo_1024 field very small so it doesn't take up room, but still available for hover-over of memo contents
	use ::ado_util.src::util

	grid! = util.getGrid(Form!)
	col_hdr$=callpoint!.getTableColumnAttribute("POE_ROGDET.MEMO_1024","LABS")
	memo_1024_col=util.getGridColumnNumber(grid!, col_hdr$)
	grid!.setColumnWidth(memo_1024_col,15)

[[POE_ROGDET.AGRE]]
rem --- For inventoried lot/serial items, item qty_returned must equal sum of lot/serial items qty_returned.
	qty_returned=num(callpoint!.getColumnData("POE_ROGDET.QTY_RETURNED"))
	item_id$=callpoint!.getColumnData("POE_ROGDET.ITEM_ID")
	gosub lot_ser_check
	if lotser_item$="Y" then
		poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
		dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

		po_no$=callpoint!.getColumnData("POE_ROGDET.PO_NO")
		receiver_no$=callpoint!.getColumnData("POE_ROGDET.RECEIVER_NO")
		return_date$=callpoint!.getColumnData("POE_ROGDET.RETURN_DATE")
		return_auth$=callpoint!.getColumnData("POE_ROGDET.RETURN_AUTH")
		rec_int_seq_ref$=callpoint!.getColumnData("POE_ROGDET.REC_INT_SEQ_REF")

		lotser_returned=0
		trip_key$=firm_id$+po_no$+receiver_no$+return_date$+return_auth$+rec_int_seq_ref$
		read(poe_roglsdet_dev,key=trip_key$,knum="PRIMARY",dom=*next)
		while 1
			poe_roglsdet_key$=key(poe_roglsdet_dev,end=*break)
			if pos(trip_key$=poe_roglsdet_key$)<>1 then break
			readrecord(poe_roglsdet_dev)poe_roglsdet$
			lotser_returned=lotser_returned+poe_roglsdet.qty_returned
		wend

		if lotser_returned<>qty_returned then
			msg_id$="PO_ROG_LSQTY_WARN1"
			dim msg_tokens$[2]
			msg_tokens$[1]=str(qty_returned)
			msg_tokens$[2]=str(lotser_returned)
			gosub disp_message

			rem --- Show problem qty_returned in bold red
			curr_row=callpoint!.getValidationRow()
			qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

			grid! = util.getGrid(Form!)
			grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("boldFont"))
			grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("redColor"))
			callpoint!.setFocus(curr_row,"POE_ROGDET.QTY_RETURNED",1)

			callpoint!.setStatus("ABORT")
			break
		else
			rem --- Reset color and font for qty_returned
			curr_row=callpoint!.getValidationRow()
			qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

			grid! = util.getGrid(Form!)
			grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("plainFont"))
			grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("blackColor"))
		endif
	endif

[[POE_ROGDET.AGRN]]
rem --- Enable/disable lotted/serialized button
	item_id$ = callpoint!.getColumnData("POE_ROGDET.ITEM_ID")
	gosub lot_ser_check

	if callpoint!.isEditMode() and lotser_item$="Y" then
		callpoint!.setOptionEnabled("LENT",1)
	else
		callpoint!.setOptionEnabled("LENT",0)
	endif

rem --- Enable comment button
	callpoint!.setOptionEnabled("COMM",1)

[[POE_ROGDET.AOPT-COMM]]
rem --- invoke the comments dialog
	gosub comment_entry

[[POE_ROGDET.AOPT-LENT]]
rem --- Is this item lot/serial?
	item_id$=callpoint!.getColumnData("POE_ROGDET.ITEM_ID")
	gosub lot_ser_check
	if lotser_item$="Y" then
		po_no$=callpoint!.getColumnData("POE_ROGDET.PO_NO")
		receiver_no$=callpoint!.getColumnData("POE_ROGDET.RECEIVER_NO")
		return_date$=callpoint!.getColumnData("POE_ROGDET.RETURN_DATE")
		return_auth$=callpoint!.getColumnData("POE_ROGDET.RETURN_AUTH")
		rec_int_seq_ref$=callpoint!.getColumnData("POE_ROGDET.REC_INT_SEQ_REF")

		key_pfx$=firm_id$+po_no$+receiver_no$+return_date$+return_auth$+rec_int_seq_ref$

		rem --- Pass additional info needed in POE_ROGLSDET
		callpoint!.setDevObject("qty_returned", num(callpoint!.getColumnData("POE_ROGDET.QTY_RETURNED")))

		call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:			"POE_ROGLSDET", 
:			stbl("+USER_ID"), 
:			"MNT" ,
:			key_pfx$, 
:			table_chans$[all], 
:			dflt_data$[all]

		callpoint!.setStatus("ACTIVATE")

		rem --- For inventoried lot/serial items, item qty_returned must equal sum of lot/serial items qty_returned.
		lotser_returned=callpoint!.getDevObject("lotser_returned")
		qty_returned=num(callpoint!.getColumnData("POE_ROGDET.QTY_RETURNED"))
		if lotser_returned<>qty_returned then
			msg_id$="PO_ROG_LSQTY_WARN1"
			dim msg_tokens$[2]
			msg_tokens$[1]=str(qty_returned)
			msg_tokens$[2]=str(lotser_returned)
			gosub disp_message

			rem --- Show problem qty_returned in bold red
			curr_row=callpoint!.getValidationRow()
			qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

			grid! = util.getGrid(Form!)
			grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("boldFont"))
			grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("redColor"))
		else
			rem --- Reset color and font for qty_returned
			curr_row=callpoint!.getValidationRow()
			qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

			grid! = util.getGrid(Form!)
			grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("plainFont"))
			grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("blackColor"))
		endif
	endif

[[POE_ROGDET.AREC]]
rem --- Lot/Serial button start disabled
	callpoint!.setOptionEnabled("LENT",0)

[[POE_ROGDET.BDGX]]
rem --- Disable detail-only buttons
	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("COMM",0)

[[POE_ROGDET.QTY_RETURNED.AVAL]]
rem --- QTY_RETURNED must be greater than or equal to zero, and less than or equal to QTY_RECEIVED
	qty_returned=num(callpoint!.getUserInput())
	qty_received=num(callpoint!.getColumnData("POE_ROGDET.QTY_RECEIVED"))
	if qty_returned<0 or qty_returned>qty_received then
		msg_id$="PO_ROG_QTY_WARN"
		dim msg_tokens$[1]
		msg_tokens$[1]=callpoint!.getColumnData("POE_ROGDET.QTY_RECEIVED")
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- For inventoried lot/serial items, item qty_returned must equal sum of lot/serial items qty_returned.
	item_id$=callpoint!.getColumnData("POE_ROGDET.ITEM_ID")
	gosub lot_ser_check
	if lotser_item$="Y" then
		po_no$=callpoint!.getColumnData("POE_ROGDET.PO_NO")
		receiver_no$=callpoint!.getColumnData("POE_ROGDET.RECEIVER_NO")
		return_date$=callpoint!.getColumnData("POE_ROGDET.RETURN_DATE")
		return_auth$=callpoint!.getColumnData("POE_ROGDET.RETURN_AUTH")
		rec_int_seq_ref$=callpoint!.getColumnData("POE_ROGDET.REC_INT_SEQ_REF")

		rem --- Launch the poe_roglsdet grid if the qty_returned was zero
		if num(callpoint!.getColumnData("POE_ROGDET.QTY_RETURNED"))=0 then
			rem --- Pass additional info needed in POE_ROGLSDET
			key_pfx$=firm_id$+po_no$+receiver_no$+return_date$+return_auth$+rec_int_seq_ref$
			callpoint!.setDevObject("qty_returned",qty_returned)

			call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:				"POE_ROGLSDET", 
:				stbl("+USER_ID"), 
:				"MNT" ,
:				key_pfx$, 
:				table_chans$[all], 
:				dflt_data$[all]

			lotser_returned=callpoint!.getDevObject("lotser_returned")
			callpoint!.setStatus("ACTIVATE")
		else
			poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
			dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

			lotser_returned=0
			trip_key$=firm_id$+po_no$+receiver_no$+return_date$+return_auth$+rec_int_seq_ref$
			read(poe_roglsdet_dev,key=trip_key$,knum="PRIMARY",dom=*next)
			while 1
				poe_roglsdet_key$=key(poe_roglsdet_dev,end=*break)
				if pos(trip_key$=poe_roglsdet_key$)<>1 then break
				readrecord(poe_roglsdet_dev)poe_roglsdet$
				lotser_returned=lotser_returned+poe_roglsdet.qty_returned
			wend
		endif

		if lotser_returned<>qty_returned then
			msg_id$="PO_ROG_LSQTY_WARN1"
			dim msg_tokens$[2]
			msg_tokens$[1]=str(qty_returned)
			msg_tokens$[2]=str(lotser_returned)
			gosub disp_message

			rem --- Show problem qty_returned in bold red
			curr_row=callpoint!.getValidationRow()
			qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

			grid! = util.getGrid(Form!)
			grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("boldFont"))
			grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("redColor"))
		else
			rem --- Reset color and font for qty_returned
			curr_row=callpoint!.getValidationRow()
			qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

			grid! = util.getGrid(Form!)
			grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("plainFont"))
			grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("blackColor"))
		endif
	endif

[[POE_ROGDET.REPLACE_QTY.AVAL]]
rem --- REPLACE_QTY must be greater than or equal zero, and less than or equal to QTY_RETURNED
	replace_qty=num(callpoint!.getUserInput())
	qty_returned=num(callpoint!.getColumnData("POE_ROGDET.QTY_RETURNED"))
	if replace_qty<0 or replace_qty>qty_returned then
		msg_id$="PO_ROG_REPLACE_QTY"
		dim msg_tokens$[1]
		msg_tokens$[1]=callpoint!.getColumnData("POE_ROGDET.QTY_RETURNED")
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_ROGDET.<CUSTOM>]]
rem ==========================================================================
comment_entry:
rem --- Pop the new memo_1024 editor to show (not editable) all of the memo/non-stock (order_memo) field.
rem ==========================================================================

	disp_text$=callpoint!.getColumnData("POE_ROGDET.MEMO_1024")
	sv_disp_text$=disp_text$

	editable$="NO"
	force_loc$="NO"
	baseWin!=null()
	startx=0
	starty=0
	shrinkwrap$="NO"
	html$="NO"
	dialog_result$=""

	call stbl("+DIR_SYP")+ "bax_display_text.bbj",
:		"PO Receipt Comments",
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

	callpoint!.setStatus("ACTIVATE")

	return

rem ==========================================================================
lot_ser_check: rem --- Check for lotted/serialized item
               rem      IN: item_id$
               rem   OUT: lotser_item$
rem ==========================================================================
	lotser_item$="N"
	if cvs(item_id$, 2)<>""
		ivm_itemMast_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm_itemMast$:fnget_tpl$("IVM_ITEMMAST")
		read record (ivm_itemMast_dev, key=firm_id$+item_id$, dom=*endif) ivm_itemMast$
		if pos(ivm_itemMast.lotser_flag$="LS") then lotser_item$="Y"
	endif

	return



