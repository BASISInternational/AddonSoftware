[[POE_RECDET.ADEL]]
gosub update_header_tots

rem --- if this line is new (i.e., NOT from a PO) reverse the OO quantity and remove the dropship link, if applicable

poe_podet_dev=fnget_dev("POE_PODET")
podet_exists=0
findrecord(poe_podet_dev,key=firm_id$+callpoint!.getColumnData("POE_RECDET.PO_NO")+callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO"),dom=*next); podet_exists=1
if !podet_exists then

	poe_linked_dev=fnget_dev("POE_LINKED")
	remove (poe_linked_dev,key=firm_id$+callpoint!.getColumnData("POE_RECDET.PO_NO")+callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO"),dom=*next)

	curr_qty = -(num(callpoint!.getColumnUndoData("POE_RECDET.QTY_ORDERED"))-num(callpoint!.getColumnUndoData("POE_RECDET.QTY_PREV_REC"))) * num(callpoint!.getColumnUndoData("POE_RECDET.CONV_FACTOR"))
	if curr_qty<>0 and callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")<>"Y" then gosub update_iv_oo

endif

rem --- also delete lot/ser records

poe_reclsdet_dev=fnget_dev("POE_RECLSDET")
dim poe_reclsdet$:fnget_tpl$("POE_RECLSDET")

receiver_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
po_int_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")

read (poe_reclsdet_dev,key=firm_id$+receiver_no$+po_int_seq_ref$,dom=*next)
while 1
	read record (poe_reclsdet_dev,end=*break)poe_reclsdet$
	if pos(firm_id$+receiver_no$+po_int_seq_ref$=poe_reclsdet$)<>1 then break
	remove (poe_reclsdet_dev,key=firm_id$+poe_reclsdet.receiver_no$+poe_reclsdet.po_int_seq_ref$+poe_reclsdet.sequence_no$,dom=*next)
wend

rem --- If WO present, remove link in corresponding wo detail lines
rem --- Use start WO as WO may have been changed without saving before the delete.
if callpoint!.getDevObject("SF_installed")="Y" then
	wo_no_was$=callpoint!.getDevObject("start_wo_no")
	wo_seq_ref_was$=callpoint!.getDevObject("start_wo_seq_ref")
	if cvs(wo_no_was$,3)<>""
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		po_line_code$=callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE")
		read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
		if poc_linecode.line_type$="S"
			sfe_womatl=fnget_dev("SFE_WOMATL")
			dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")
			find record (sfe_womatl,key=firm_id$+sfe_womatl.wo_location$+wo_no_was$+wo_seq_ref_was$,knum="AO_MAT_SEQ",dom=*endif)sfe_womatl$
			sfe_womatl.po_no$=""
			sfe_womatl.pur_ord_seq_ref$=""
			sfe_womatl.po_status$=""
			sfe_womatl$=field(sfe_womatl$)
			write record (sfe_womatl)sfe_womatl$
		endif
		if poc_linecode.line_type$="N"
			sfe_wosub=fnget_dev("SFE_WOSUBCNT")
			dim sfe_wosub$:fnget_tpl$("SFE_WOSUBCNT")
			find record (sfe_wosub,key=firm_id$+sfe_wosub.wo_location$+wo_no_was$+wo_seq_ref_was$,knum="AO_SUBCONT_SEQ",dom=*endif)sfe_wosub$
			sfe_wosub.po_no$=""
			sfe_wosub.pur_ord_seq_ref$=""
			sfe_wosub.po_status$=""
			sfe_wosub$=field(sfe_wosub$)
			write record (sfe_wosub)sfe_wosub$
		endif
	endif		
endif

[[POE_RECDET.ADGE]]
rem --- if there are order lines to display/access in the sales order line item listbutton, set the LDAT and list display
rem --- get the detail grid, then get the listbutton within the grid; set the list on the listbutton, and put the listbutton back in the grid

ldat$=callpoint!.getDevObject("so_ldat")
if ldat$<>""
	callpoint!.setTableColumnAttribute("POE_RECDET.SO_INT_SEQ_REF","LDAT",ldat$)
	g!=callpoint!.getDevObject("dtl_grid")
	col_hdr$=callpoint!.getTableColumnAttribute("POE_RECDET.SO_INT_SEQ_REF","LABS")
	col_ref=util.getGridColumnNumber(g!, col_hdr$)
	c!=g!.getColumnListControl(col_ref)
	c!.removeAllItems()
	order_list!=callpoint!.getDevObject("so_lines_list")
	c!.insertItems(0,order_list!)
	g!.setColumnListControl(col_ref,c!)	
endif 

rem --- Disable SO Seq No column
	callpoint!.setColumnEnabled(-1,"POE_RECDET.SO_INT_SEQ_REF",0)

rem ---Disable/enable the warehouse_id column
if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" then
	if callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")="Y" then
		callpoint!.setColumnEnabled(-1,"POE_RECDET.WAREHOUSE_ID",0)
	else
		callpoint!.setColumnEnabled(-1,"POE_RECDET.WAREHOUSE_ID",1)
	endif
endif

[[POE_RECDET.AGCL]]
rem print 'show';rem debug

use ::ado_util.src::util

rem --- set default line code based on param file
callpoint!.setTableColumnAttribute("POE_RECDET.PO_LINE_CODE","DFLT",str(callpoint!.getDevObject("dflt_po_line_code")))

callpoint!.setDevObject("po_rows","")

rem --- set preset val for batch_no

	callpoint!.setTableColumnAttribute("POE_RECDET.BATCH_NO","PVAL",$22$+stbl("+BATCH_NO")+$22$)

rem --- Set column size for memo_1024 field very small so it doesn't take up room, but still available for hover-over of memo contents

	grid! = util.getGrid(Form!)
	col_hdr$=callpoint!.getTableColumnAttribute("POE_RECDET.MEMO_1024","LABS")
	memo_1024_col=util.getGridColumnNumber(grid!, col_hdr$)
	grid!.setColumnWidth(memo_1024_col,15)

[[POE_RECDET.AGDR]]
rem --- After Grid Display Row
total_amt=num(callpoint!.getDevObject("total_amt"))
total_amt=total_amt+round(num(callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))*num(callpoint!.getColumnData("POE_RECDET.UNIT_COST")),2)
callpoint!.setDevObject("total_amt",str(total_amt))

gosub update_line_type_info

[[POE_RECDET.AGRE]]
rem --- check data to see if o.k. to leave row (only if the row isn't marked as deleted)

if callpoint!.getGridRowDeleteStatus(num(callpoint!.getValidationRow()))<>"Y"

	ok_to_write$="Y"
	newStatus$=callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())

	if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE"),3)=""
		ok_to_write$="N"
		focus_column$="POE_RECDET.PO_LINE_CODE"
		translate$="AON_LINE_CODE"
	else
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		po_line_code$=callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE")
		read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
		line_type$=poc_linecode.line_type$
	endif

	if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID"),3)="" 
		ok_to_write$="N"
		focus_column$="POE_RECDET.WAREHOUSE_ID"
		translate$="AON_WAREHOUSE"
	endif

	qty_ordered=num(callpoint!.getColumnData("POE_RECDET.QTY_ORDERED"))
	qty_received=num(callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))
	qty_prev_rec=num(callpoint!.getColumnData("POE_RECDET.QTY_PREV_REC"))
	if newStatus$="Y" then
		whse$=callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
		item$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
		ivm_itemwhse=fnget_dev("IVM_ITEMWHSE")
		dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
		findrecord (ivm_itemwhse,key=firm_id$+whse$+item$,dom=*break) ivm_itemwhse$
		qty_on_hand=ivm_itemwhse.qty_on_hand
	endif

	if ok_to_write$="Y" and pos(line_type$="SD")<>0 
		if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_RECDET.ITEM_ID"),3)=""
			ok_to_write$="N"
			focus_column$="POE_RECDET.ITEM_ID"
			translate$="AON_ITEM"
		endif
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))<=0
			ok_to_write$="N"
			focus_column$="POE_RECDET.CONV_FACTOR"
			translate$="AON_CONVERSION_FACTOR"
		endif
		if ok_to_write$="Y" and qty_ordered=0 or 
: 		(NewStatus$="" and qty_received<0 and abs(qty_received)>qty_prev_rec) or
: 		(NewStatus$="Y" and qty_received<0 and abs(qty_received)>qty_on_hand)
			ok_to_write$="N"
			focus_column$="POE_RECDET.QTY_RECEIVED"
			translate$="AON_QUANTITY_RECEIVED"
		endif
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))<0
			ok_to_write$="N"
			focus_column$="POE_RECDET.UNIT_COST"
			translate$="AON_UNIT_COST"
		endif
	endif

	if ok_to_write$="Y" and line_type$="N" 
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))<0
			ok_to_write$="N"
			focus_column$="POE_RECDET.UNIT_COST"
			translate$="AON_UNIT_COST"
		endif
		if ok_to_write$="Y" and qty_ordered=0 or 
: 		(NewStatus$="" and qty_received<0 and abs(qty_received)>qty_prev_rec) or
: 		(NewStatus$="Y" and qty_received<0 and abs(qty_received)>qty_on_hand)
			ok_to_write$="N"
			focus_column$="POE_RECDET.QTY_RECEIVED"
			translate$="AON_QUANTITY_RECEIVED"
		endif
	endif

	if ok_to_write$="Y" and line_type$="O" 
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))<0
			ok_to_write$="N"
			focus_column$="POE_RECDET.UNIT_COST"
			translate$="AON_UNIT_COST"
		endif
	endif

	if ok_to_write$="Y" and pos(line_type$="NOV")<>0
		if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_RECDET.ORDER_MEMO"),3)="" 
			ok_to_write$="N"
			focus_column$="POE_RECDET.ORDER_MEMO"
			translate$="AON_MEMO"
		endif
	endif

	if ok_to_write$="Y" and callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")="Y" and callpoint!.getDevObject("OP_installed")="Y"
		if ok_to_write$="Y" and pos(line_type$="DSNO")<>0
			if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_RECDET.SO_INT_SEQ_REF"),3)="" 
				ok_to_write$="N"
				focus_column$="POE_RECDET.SO_INT_SEQ_REF"
				translate$="AON_SO_SEQ_NO"
			endif
		endif
	endif

	if ok_to_write$<>"Y"
		msg_id$="PO_REQD_DET"
		dim msg_tokens$[1]
		msg_tokens$[1]=""
		if translate$<>""
			msg_tokens$[1]=Translate!.getTranslation(translate$)
		endif
		gosub disp_message
		callpoint!.setFocus(num(callpoint!.getValidationRow()),focus_column$,1)
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

goto Bug8251; rem --- Bypassing this code per Bug 8251	
	rem -- now loop thru entire gridVect to make sure SO line reference, if used, isn't used >1 time

	dtl!=gridVect!.getItem(0)
	so_lines_referenced$=""
	dup_so_lines$=""

	if dtl!.size()
		dim rec$:dtlg_param$[1,3]
		for x=0 to dtl!.size()-1
			if callpoint!.getGridRowDeleteStatus(x)<>"Y"
				rec$=dtl!.getItem(x)
				if cvs(rec.so_int_seq_ref$,3)<>""
					if pos(rec.so_int_seq_ref$+"^"=so_lines_referenced$)<>0 
						msg_id$="PO_DUP_SO_LINE"
						gosub disp_message
						callpoint!.setFocus(num(callpoint!.getValidationRow()),"POE_RECDET.SO_INT_SEQ_REF",1)
						break
					else
						so_lines_referenced$=so_lines_referenced$+rec.so_int_seq_ref$+"^"
					endif
				endif
			endif
		next x
	endif	
Bug8251:

	rem --- Disable SO Seq No column if SO line reference is okay
	if msg_id$<>"PO_DUP_SO_LINE" then
		callpoint!.setColumnEnabled(-1,"POE_RECDET.SO_INT_SEQ_REF",0)
	endif
endif

rem --- look at wo number; if different than it was when we entered the row, update and/or remove link in corresponding wo detail line

if callpoint!.getDevObject("SF_installed")="Y" then
	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$

	wo_no_was$=callpoint!.getDevObject("start_wo_no")
	wo_seq_ref_was$=callpoint!.getDevObject("start_wo_seq_ref")

	wo_no_now$=callpoint!.getColumnData("POE_RECDET.WO_NO")
	wo_seq_ref_now$=callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF")

	sfe_womatl=fnget_dev("SFE_WOMATL")
	sfe_wosub=fnget_dev("SFE_WOSUBCNT")

	dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")
	dim sfe_wosub$:fnget_tpl$("SFE_WOSUBCNT")

	if wo_no_was$+wo_seq_ref_was$<>wo_no_now$+wo_seq_ref_now$
		rem --- used to reference different wo# (i.e., changed from one wo# to another, or have now removed the wo# from this PO line)
		if cvs(wo_no_was$,3)<>""
			if line_type$="S"
				find record (sfe_womatl,key=firm_id$+sfe_womatl.wo_location$+wo_no_was$+wo_seq_ref_was$,knum="AO_MAT_SEQ",dom=*endif)sfe_womatl$
				sfe_womatl.po_no$=""
				sfe_womatl.pur_ord_seq_ref$=""
				sfe_womatl.po_status$=""
				sfe_womatl$=field(sfe_womatl$)
				write record (sfe_womatl)sfe_womatl$
			endif
			if line_type$="N"
				find record (sfe_wosub,key=firm_id$+sfe_wosub.wo_location$+wo_no_was$+wo_seq_ref_was$,knum="AO_SUBCONT_SEQ",dom=*endif)sfe_wosub$
				sfe_wosub.po_no$=""
				sfe_wosub.pur_ord_seq_ref$=""
				sfe_wosub.po_status$=""
				sfe_wosub$=field(sfe_wosub$)
				write record (sfe_wosub)sfe_wosub$
			endif
		endif		
		rem --- now references different wo# (i.e., changed from one wo# to another, or have now set a wo# on this PO line)
		if cvs(wo_no_now$,3)<>""
			if line_type$="S"
				find record (sfe_womatl,key=firm_id$+sfe_womatl.wo_location$+wo_no_now$+wo_seq_ref_now$,knum="AO_MAT_SEQ",dom=*endif)sfe_womatl$
				sfe_womatl.po_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
				sfe_womatl.pur_ord_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
				sfe_womatl$.po_status$="C"
				sfe_womatl$=field(sfe_womatl$)
				write record (sfe_womatl)sfe_womatl$
			endif
			if line_type$="N"
				find record (sfe_wosub,key=firm_id$+sfe_wosub.wo_location$+wo_no_now$+wo_seq_ref_now$,knum="AO_SUBCONT_SEQ",dom=*endif)sfe_wosub$
				sfe_wosub.po_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
				sfe_wosub.pur_ord_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
				sfe_wosub.po_status$="C"
				sfe_wosub$=field(sfe_wosub$)
				write record (sfe_wosub)sfe_wosub$
			endif
		endif
	endif

	rem --- Re-set "start" values to current values
	callpoint!.setDevObject("start_wo_no",callpoint!.getColumnData("POE_RECDET.WO_NO"))
	callpoint!.setDevObject("start_wo_seq_ref",callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF"))
endif

rem --- if received > ordered - previously received, warn, but not fatal

	if qty_received > qty_ordered - qty_prev_rec
		callpoint!.setMessage("PO_REC_QTY_WARN")
	endif

[[POE_RECDET.AGRN]]
rem --- save current qty/price this row

callpoint!.setDevObject("qty_this_row",callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))
callpoint!.setDevObject("cost_this_row",callpoint!.getColumnData("POE_RECDET.UNIT_COST"))

rem print "AGRN "
rem print "qty this row: ",callpoint!.getDevObject("qty_this_row")
rem print "cost this row: ",callpoint!.getDevObject("cost_this_row")

	callpoint!.setDevObject("prior_whse",callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID"))
	callpoint!.setDevObject("prior_item",callpoint!.getColumnData("POE_RECDET.ITEM_ID"))
	callpoint!.setDevObject("prior_qty_ordered",num(callpoint!.getColumnData("POE_RECDET.QTY_ORDERED")))
	callpoint!.setDevObject("prior_prev_rec",num(callpoint!.getColumnData("POE_RECDET.QTY_PREV_REC")))
	callpoint!.setDevObject("prior_conv_factor",num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR")))

item_id$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
gosub enable_serial

	gosub update_line_type_info

rem --- save current po status flag, po/req# and line#

	callpoint!.setDevObject("start_wo_no",callpoint!.getColumnData("POE_RECDET.WO_NO"))
	callpoint!.setDevObject("start_wo_seq_ref",callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF"))
	callpoint!.setDevObject("wo_looked_up","N")

[[POE_RECDET.AOPT-COMM]]
rem --- invoke the comments dialog

	gosub comment_entry

[[POE_RECDET.AOPT-LENT]]
rem --- Save current context so we'll know where to return from lot lookup

	declare BBjStandardGrid grid!
	grid! = util.getGrid(Form!)
	grid_ctx=grid!.getContextID()

rem --- Go get Lot Numbers

	item_id$ = callpoint!.getColumnData("POE_RECDET.ITEM_ID")
rem	gosub lot_ser_check

rem --- Is this item lot/serial?

	ivm_itemmast=fnget_dev("IVM_ITEMMAST")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")

	read record (ivm_itemmast,key=firm_id$+item_id$,dom=*break)ivm_itemmast$

	if pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y"
	
		receiver_no$   = callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
		po_int_seq_ref$ = callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
		po_no$=callpoint!.getColumnData("POE_RECDET.PO_NO")
		unit_cost=num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))
		qty_received=num(callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))
		conv_factor=num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))

		grid!.focus()
		dim dflt_data$[3,1]
		dflt_data$[1,0] = "RECEIVER_NO"
		dflt_data$[1,1] = receiver_no$
		dflt_data$[2,0] = "PO_INT_SEQ_REF"
		dflt_data$[2,1] = po_int_seq_ref$
		dflt_data$[3,0]="PO_NO"
		dflt_data$[3,1]=po_no$

		callpoint!.setDevObject("ls_po_no",po_no$)
		callpoint!.setDevObject("ls_unit_cost",unit_cost/conv_factor)
		callpoint!.setDevObject("ls_qty_received",qty_received*conv_factor)

		lot_pfx$ = firm_id$+receiver_no$+po_int_seq_ref$

		call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:			"POE_RECLSDET", 
:			stbl("+USER_ID"), 
:			"MNT", 
:			lot_pfx$, 
:			table_chans$[all], 
:			dflt_data$[all]

		if ivm_itemmast.lotser_flag$="S"
			ivm_lsmaster_dev=fnget_dev("IVM_LSMASTER")
			dim ivm_lsmaster$:fnget_tpl$("IVM_LSMASTER")
			poe_reclsdet_dev=fnget_dev("POE_RECLSDET")
			dim poe_reclsdet$:fnget_tpl$("POE_RECLSDET")
			rcvr_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
			int_seq$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
			wh$=callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
			item$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")

			read(poe_reclsdet_dev,key=firm_id$+rcvr_no$+int_seq$,dom=*next)
			while 1
				poe_reclsdet_key$=key(poe_reclsdet_dev,end=*break)
				if pos(firm_id$+rcvr_no$+int_seq$=poe_reclsdet_key$)<>1 break
				readrecord(poe_reclsdet_dev,key=poe_reclsdet_key$)poe_reclsdet$
				readrecord(ivm_lsmaster_dev,key=firm_id$+wh$+item$+poe_reclsdet.lotser_no$,dom=*continue)ivm_lsmaster$
				if ivm_lsmaster.qty_on_hand>0 and poe_reclsdet.qty_received<>-1 then
					remove (poe_reclsdet_dev,key=poe_reclsdet_key$)
					msg_id$="IV_SER_ZERO_QOH"
					gosub disp_message
				endif
			wend
		endif

		callpoint!.setStatus("ACTIVATE")

		rem --- Return focus to where we were (Detail line grid)
		sysgui!.setContext(grid_ctx)
	endif

[[POE_RECDET.AREC]]
callpoint!.setDevObject("qty_this_row",0)
callpoint!.setDevObject("cost_this_row",0)
callpoint!.setColumnData("POE_RECDET.PO_NO",callpoint!.getHeaderColumnData("POE_RECHDR.PO_NO"))

rem --- Comments button initially disabled
callpoint!.setOptionEnabled("COMM",0)

rem --- Enable SO Seq No column if there are order lines to display/access in the sales order line item listbutton
ldat$=callpoint!.getDevObject("so_ldat")
if ldat$<>"" then
	callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"POE_RECDET.SO_INT_SEQ_REF",1)
endif

rem --- Initialize warehouse_id for dropships
if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")="Y" then
	callpoint!.setColumnData("POE_RECDET.WAREHOUSE_ID",str(callpoint!.getDevObject("dropship_whse")),1)
	callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"POE_RECDET.WAREHOUSE_ID",0)
endif

[[POE_RECDET.AUDE]]
gosub update_header_tots

gosub update_line_type_info

rem --- if this line is new (i.e., NOT from a PO) restore the OO

poe_podet_dev=fnget_dev("POE_PODET")
podet_exists=0
findrecord(poe_podet_dev,key=firm_id$+callpoint!.getColumnData("POE_RECDET.PO_NO")+callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO"),dom=*next); podet_exists=1
if !podet_exists then

	curr_qty = (num(callpoint!.getColumnData("POE_RECDET.QTY_ORDERED"))-num(callpoint!.getColumnData("POE_RECDET.QTY_PREV_REC"))) * num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))
	dropship$=callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")
	if curr_qty<>0 and (dropship$<>"Y" or (cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and dropship$="Y")) then gosub update_iv_oo

endif

rem --- If WO present, restore link in corresponding wo detail lines
	wo_no_now$=callpoint!.getColumnData("POE_RECDET.WO_NO")
	wo_seq_ref_now$=callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF")
	if cvs(wo_no_now$,3)<>""
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		po_line_code$=callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE")
		read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
		if poc_linecode.line_type$="S"
			sfe_womatl=fnget_dev("SFE_WOMATL")
			dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")
			find record (sfe_womatl,key=firm_id$+sfe_womatl.wo_location$+wo_no_now$+wo_seq_ref_now$,knum="AO_MAT_SEQ",dom=*endif)sfe_womatl$
			sfe_womatl.po_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
			sfe_womatl.pur_ord_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
			sfe_womatl$.po_status$="C"
			sfe_womatl$=field(sfe_womatl$)
			write record (sfe_womatl)sfe_womatl$
		endif
		if poc_linecode.line_type$="N"
			sfe_wosub=fnget_dev("SFE_WOSUBCNT")
			dim sfe_wosub$:fnget_tpl$("SFE_WOSUBCNT")
				find record (sfe_wosub,key=firm_id$+sfe_wosub.wo_location$+wo_no_now$+wo_seq_ref_now$,knum="AO_SUBCONT_SEQ",dom=*endif)sfe_wosub$
				sfe_wosub.po_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
				sfe_wosub.pur_ord_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
				sfe_wosub.po_status$="C"
				sfe_wosub$=field(sfe_wosub$)
				write record (sfe_wosub)sfe_wosub$
		endif
	endif		

[[POE_RECDET.AWRI]]
rem --- if new row, updt ivm-05 (old poc.ua, now poc_itemvend) 

if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))="Y"

	vendor_id$=callpoint!.getHeaderColumnData("POE_RECHDR.VENDOR_ID")
	ord_date$=callpoint!.getHeaderColumnData("POE_RECHDR.ORD_DATE")
	item_id$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
	conv_factor=num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))
	unit_cost=num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))
	qty_ordered=num(callpoint!.getColumnData("POE_RECDET.QTY_ORDERED"))
	status=0

	call stbl("+DIR_PGM")+"poc_itemvend.aon","W","P",vendor_id$,ord_date$,item_id$,conv_factor,unit_cost,qty_ordered,callpoint!.getDevObject("iv_prec"),status
	
endif

rem --- also need to update POE_LINKED if this is a dropship

cust_id$=callpoint!.getHeaderColumnData("POE_RECHDR.CUSTOMER_ID")
order_no$=callpoint!.getHeaderColumnData("POE_RECHDR.ORDER_NO")
so_line_no$=callpoint!.getColumnData("POE_RECDET.SO_INT_SEQ_REF")

if num(so_line_no$)<>0

	poe_linked_dev=fnget_dev("POE_LINKED")
	dim poe_linked$:fnget_tpl$("POE_LINKED")

	poe_linked.firm_id$=firm_id$
	poe_linked.po_no$=callpoint!.getColumnData("POE_RECDET.PO_NO")
	poe_linked.poedet_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
	poe_linked.customer_id$=cust_id$
	poe_linked.order_no$=order_no$
	poe_linked.opedet_seq_ref$=so_line_no$

	write record (poe_linked_dev)poe_linked$

endif

rem --- Update inventory OO if not a dropship PO, and this is a new line (i.e., wasn't on PO)

poe_podet_dev=fnget_dev("POE_PODET")
podet_exists=0
findrecord(poe_podet_dev,key=firm_id$+callpoint!.getColumnData("POE_RECDET.PO_NO")+callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO"),dom=*next); podet_exists=1
dropship$=callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")
if (dropship$<>"Y" or (cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and dropship$="Y")) and !podet_exists then

	rem --- Get current and prior values

	curr_whse$ = callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
	curr_item$ = callpoint!.getColumnData("POE_RECDET.ITEM_ID")
	curr_qty   = (num(callpoint!.getColumnData("POE_RECDET.QTY_ORDERED"))-num(callpoint!.getColumnData("POE_RECDET.QTY_PREV_REC"))) * num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))

	prior_whse$ = callpoint!.getDevObject("prior_whse")
	prior_item$ = callpoint!.getDevObject("prior_item")
	prior_qty   = (callpoint!.getDevObject("prior_qty_ordered")-callpoint!.getDevObject("prior_prev_rec")) * callpoint!.getDevObject("prior_conv_factor")

	rem --- Has there been any change?

	if curr_whse$ <> prior_whse$ or 
:		curr_item$ <> prior_item$ or 
:		curr_qty   <> prior_qty 
:	then

		rem --- Initialize inventory item update

		status=999
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then exitto std_exit

		rem --- Items or warehouses are different: reverse OO on previous

		if (cvs(prior_whse$,2)<>"" and prior_whse$<>curr_whse$) or 
:		   (cvs(prior_item$,2)<>"" and prior_item$<>curr_item$)
:		then

		rem --- reverse OO prior item and warehouse

			if cvs(prior_whse$,2)<>"" and cvs(prior_item$,2)<>"" and prior_qty<>0 then
				items$[1] = prior_whse$
				items$[2] = prior_item$
				refs[0]   = -prior_qty

				print "---reverse OO: item = ", cvs(items$[2], 2), ", WH: ", items$[1], ", qty =", refs[0]; rem debug

				call stbl("+DIR_PGM")+"ivc_itemupdt.aon","OO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				if status then exitto std_exit
			endif

			rem --- Update OO quantity for current item and warehouse

			if curr_whse$<>"" and curr_item$<>"" and curr_qty<>0 then
				items$[1] = curr_whse$
				items$[2] = curr_item$
				refs[0]   = curr_qty 

				print "-----Update OO: item = ", cvs(items$[2], 2), ", WH: ", items$[1], ", qty =", refs[0]; rem debug

				call stbl("+DIR_PGM")+"ivc_itemupdt.aon","OO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				if status then exitto std_exit
			endif

		endif

		rem --- New record or item and warehouse haven't changed: update OO w difference

		if	(cvs(prior_whse$,2)="" or prior_whse$=curr_whse$) and 
:			(cvs(prior_item$,2)="" or prior_item$=curr_item$) 
:		then

			rem --- Update OO quantity for current item and warehouse

			if curr_whse$<>"" and curr_item$<>"" and curr_qty - prior_qty <> 0
				items$[1] = curr_whse$
				items$[2] = curr_item$
				refs[0]   = curr_qty - prior_qty

				print "-----Update OO: item = ", cvs(items$[2], 2), ", WH: ", items$[1], ", qty =", refs[0]; rem debug

				call stbl("+DIR_PGM")+"ivc_itemupdt.aon","OO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				if status then exitto std_exit
			endif

		endif

	endif
endif

rem --- if this is a lotted/serialized item, launch lot/serial entry

ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")

item_id$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
receiver_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
po_int_seq_ref$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
po_no$=callpoint!.getColumnData("POE_RECDET.PO_NO")
unit_cost=num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))
qty_received=num(callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))
conv_factor=num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))

declare BBjStandardGrid grid!
grid! = util.getGrid(Form!)
return_to_row = grid!.getSelectedRow()
return_to_col = grid!.getSelectedColumn()

read record (ivm_itemmast_dev,key=firm_id$+item_id$,dom=*break)ivm_itemmast$

if pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y"

	dim dflt_data$[3,1]
	dflt_data$[1,0] = "RECEIVER_NO"
	dflt_data$[1,1] = receiver_no$
	dflt_data$[2,0] = "PO_INT_SEQ_REF"
	dflt_data$[2,1] = po_int_seq_ref$
	dflt_data$[3,0]="PO_NO"
	dflt_data$[3,1]=po_no$

	callpoint!.setDevObject("ls_po_no",po_no$)
	callpoint!.setDevObject("ls_unit_cost",unit_cost/conv_factor)
	callpoint!.setDevObject("ls_qty_received",qty_received*conv_factor)

	lot_pfx$ = firm_id$+receiver_no$+po_int_seq_ref$

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"POE_RECLSDET", 
:		stbl("+USER_ID"), 
:		"MNT", 
:		lot_pfx$, 
:		table_chans$[all], 
:		dflt_data$[all]
	if ivm_itemmast.lotser_flag$="S"
		ivm_lsmaster_dev=fnget_dev("IVM_LSMASTER")
		dim ivm_lsmaster$:fnget_tpl$("IVM_LSMASTER")
		poe_reclsdet_dev=fnget_dev("POE_RECLSDET")
		dim poe_reclsdet$:fnget_tpl$("POE_RECLSDET")
		rcvr_no$=callpoint!.getColumnData("POE_RECDET.RECEIVER_NO")
		int_seq$=callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO")
		wh$=callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
		item$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")

		read(poe_reclsdet_dev,key=firm_id$+rcvr_no$+int_seq$,dom=*next)
		while 1
			poe_reclsdet_key$=key(poe_reclsdet_dev,end=*break)
			if pos(firm_id$+rcvr_no$+int_seq$=poe_reclsdet_key$)<>1 break
			readrecord(poe_reclsdet_dev,key=poe_reclsdet_key$)poe_reclsdet$
			readrecord(ivm_lsmaster_dev,key=firm_id$+wh$+item$+poe_reclsdet.lotser_no$,dom=*continue)ivm_lsmaster$
			if ivm_lsmaster.qty_on_hand>0
				remove (poe_reclsdet_dev,key=poe_reclsdet_key$)
				msg_id$="IV_SER_ZERO_QOH"
				gosub disp_message
			endif
		wend
	endif
	callpoint!.setStatus("ACTIVATE")

endif

rem --- Re-set "prior" values to current values
	callpoint!.setDevObject("prior_whse",callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID"))
	callpoint!.setDevObject("prior_item",callpoint!.getColumnData("POE_RECDET.ITEM_ID"))
	callpoint!.setDevObject("prior_qty_ordered",num(callpoint!.getColumnData("POE_RECDET.QTY_ORDERED")))
	callpoint!.setDevObject("prior_prev_rec",num(callpoint!.getColumnData("POE_RECDET.QTY_PREV_REC")))
	callpoint!.setDevObject("prior_conv_factor",num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR")))
	callpoint!.setDevObject("start_wo_no",callpoint!.getColumnData("POE_RECDET.WO_NO"))
	callpoint!.setDevObject("start_wo_seq_ref",callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF"))

[[POE_RECDET.BDGX]]
rem -- loop thru gridVect; if there are any lines not marked deleted, set the callpoint!.setDevObject("dtl_posted") to Y

dtl!=gridVect!.getItem(0)
callpoint!.setDevObject("dtl_posted","")
if dtl!.size()
	for x=0 to dtl!.size()-1
		if callpoint!.getGridRowDeleteStatus(x)<>"Y" then callpoint!.setDevObject("dtl_posted","Y")
	next x
endif

callpoint!.setOptionEnabled("COMM",0)

[[POE_RECDET.BGDS]]
rem --- Re-initialize receipt total amount before it's accumulated again for each detail row
	callpoint!.setDevObject("total_amt","0")

[[POE_RECDET.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::grid_entry"

[[POE_RECDET.ITEM_ID.AVAL]]
rem --- Item ID - After Column Validataion
rem "Inventory Inactive Feature"
item_id$=callpoint!.getUserInput()
ivm01_dev=fnget_dev("IVM_ITEMMAST")
ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
dim ivm01a$:ivm01_tpl$
ivm01a_key$=firm_id$+item_id$
find record (ivm01_dev,key=ivm01a_key$,err=*break)ivm01a$
if ivm01a.item_inactive$="Y" then
   msg_id$="IV_ITEM_INACTIVE"
   dim msg_tokens$[2]
   msg_tokens$[1]=cvs(ivm01a.item_id$,2)
   msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
   gosub disp_message
   callpoint!.setStatus("ACTIVATE")
endif

rem --- Can't purchase kits
	if pos(ivm01a.kit$="YP") then
		msg_id$="PO_KIT_PURCHASE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

gosub validate_whse_item
if pos("ABORT"=callpoint!.getStatus())<>0
	callpoint!.setUserInput("")
endif

item_id$=callpoint!.getUserInput()
gosub enable_serial

[[POE_RECDET.ITEM_ID.BINQ]]
rem --- Inventory Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]=""
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"IV_ITEM_WHSE_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("POE_RECDET.ITEM_ID") then 
		callpoint!.setColumnData("POE_RECDET.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"POE_RECDET.ITEM_ID",1)
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_RECDET.MEMO_1024.AVAL]]
rem --- store first part of memo_1024 in order_memo
rem --- this AVAL is hit if user navigates via arrows or clicks on the memo_1024 field, and double-clicks or ctrl-F to bring up editor
rem --- if on a memo line or using ctrl-C or Comments button, code in the comment_entry: subroutine is hit instead

	disp_text$=callpoint!.getUserInput()
	if disp_text$<>callpoint!.getColumnUndoData("POE_RECDET.MEMO_1024")
		memo_len=len(callpoint!.getColumnData("POE_RECDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("POE_RECDET.MEMO_1024",disp_text$,1)
		callpoint!.setColumnData("POE_RECDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

[[POE_RECDET.ORDER_MEMO.BINP]]
rem --- invoke the comments dialog

	gosub comment_entry

[[POE_RECDET.PO_LINE_CODE.AVAL]]
rem --- Line Code - After Validataion
rem print 'show',;rem debug
rem print callpoint!.getUserInput();rem debug
rem print callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE");rem debug
rem print callpoint!.getColumnUndoData("POE_RECDET.PO_LINE_CODE");rem debug
rem print "validation row:", callpoint!.getValidationRow()
rem print "new status:",callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))
rem print "modify status:",callpoint!.getGridRowModifyStatus(num(callpoint!.getValidationRow()))

rem I think if line type changes on existing row, need to uncommit whatever's on this line (assuming old line code was a stock type)

if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))="Y" or cvs(callpoint!.getUserInput(),2)<>cvs(callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE"),2) then
rem if cvs(callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID"),3)="" or cvs(callpoint!.getUserInput(),2)<>cvs(callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE"),2) then
		callpoint!.setColumnData("POE_RECDET.CONV_FACTOR","")
		callpoint!.setColumnData("POE_RECDET.FORECAST","")
		callpoint!.setColumnData("POE_RECDET.ITEM_ID","")
		callpoint!.setColumnData("POE_RECDET.LEAD_TIM_FLG","")
		callpoint!.setColumnData("POE_RECDET.LOCATION","")
		callpoint!.setColumnData("POE_RECDET.MEMO_1024","")
		callpoint!.setColumnData("POE_RECDET.NOT_B4_DATE",callpoint!.getHeaderColumnData("POE_RECHDR.NOT_B4_DATE"))
		callpoint!.setColumnData("POE_RECDET.NS_ITEM_ID","")
		callpoint!.setColumnData("POE_RECDET.ORDER_MEMO","")
		callpoint!.setColumnData("POE_RECDET.PO_MSG_CODE","")
		callpoint!.setColumnData("POE_RECDET.PROMISE_DATE",callpoint!.getHeaderColumnData("POE_RECHDR.PROMISE_DATE"))
		callpoint!.setColumnData("POE_RECDET.REQD_DATE",callpoint!.getHeaderColumnData("POE_RECHDR.REQD_DATE"))
		callpoint!.setColumnData("POE_RECDET.REQ_QTY","")
		callpoint!.setColumnData("POE_RECDET.SO_INT_SEQ_REF","")
		callpoint!.setColumnData("POE_RECDET.SOURCE_CODE","")
		callpoint!.setColumnData("POE_RECDET.UNIT_COST","")
		callpoint!.setColumnData("POE_RECDET.UNIT_MEASURE","")
		callpoint!.setColumnData("POE_RECDET.WAREHOUSE_ID",callpoint!.getHeaderColumnData("POE_RECHDR.WAREHOUSE_ID"))
		callpoint!.setColumnData("POE_RECDET.WO_NO","")
		callpoint!.setColumnData("POE_RECDET.WK_ORD_SEQ_REF","")

endif

gosub update_line_type_info

if line_type$="M" and cvs(callpoint!.getColumnData("POE_RECDET.ORDER_MEMO"),2)=""
	callpoint!.setColumnData("POE_RECDET.ORDER_MEMO"," ")
	callpoint!.setStatus("MODIFIED")
endif

[[POE_RECDET.PO_LINE_CODE.AVEC]]
if callpoint!.getDevObject("line_type")="O" 
	callpoint!.setColumnData("POE_RECDET.QTY_ORDERED","1")
	callpoint!.setColumnData("POE_RECDET.QTY_RECEIVED","1")
else
	callpoint!.setColumnData("POE_RECDET.QTY_ORDERED","")
endif

callpoint!.setStatus("REFRESH")

[[POE_RECDET.QTY_ORDERED.AVAL]]
rem --- call poc_itemvend.aon (poc.ua) to retrieve unit cost from ivm-05

vendor_id$=callpoint!.getHeaderColumnData("POE_RECHDR.VENDOR_ID")
ord_date$=callpoint!.getHeaderColumnData("POE_RECHDR.ORD_DATE")
item_id$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
conv_factor=num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))
unit_cost=num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))
qty_ordered=num(callpoint!.getUserInput())
status=0

call stbl("+DIR_PGM")+"poc_itemvend.aon","R","P",vendor_id$,ord_date$,item_id$,conv_factor,unit_cost,qty_ordered,callpoint!.getDevObject("iv_prec"),status

callpoint!.setColumnData("POE_RECDET.UNIT_COST",str(unit_cost),1)

callpoint!.setDevObject("cost_this_row",unit_cost);rem re-setting cost because it may have changed based on qty break

[[POE_RECDET.QTY_RECEIVED.AVAL]]
gosub update_header_tots
callpoint!.setDevObject("qty_this_row",num(callpoint!.getUserInput()))

[[POE_RECDET.SO_INT_SEQ_REF.AVAL]]
rem --- Warn when dropship OP item does not match the PO item
	so_int_seq_ref$=callpoint!.getUserInput()
	if cvs(so_int_seq_ref$,2)="" then break

	ldat!=callpoint!.getDevObject("so_ldat")
	opItems!=BBjAPI().makeVector()
	opItems!.addAll(java.util.Arrays.asList(ldat!.split(";")))
	for i=0 to opItems!.size()-1
		thisItem$=opItems!.getItem(i)
		if pos("~"+so_int_seq_ref$=thisItem$) then
			rem --- This is the selected OP item. Does it match the PO item?
			opItem$=cvs(thisItem$(1,pos("~"=thisItem$)-1),3)
			if pos("("=opItem$) then opItem$=opItem$(1,pos("("=opItem$)-1)

			itemsMatch=0
			poItem$=cvs(callpoint!.getColumnData("POE_RECDET.ITEM_ID"),3)
			if poItem$<>"" then
				if poItem$=opItem$ then itemsMatch=1
			else
				poItem$=cvs(callpoint!.getColumnData("POE_RECDET.ORDER_MEMO"),7)
				if poItem$=cvs(opItem$,7) then
					itemsMatch=1
				else
					poItem$=cvs(callpoint!.getColumnData("POE_RECDET.NS_ITEM_ID"),7)
					if poItem$=cvs(opItem$,7) then
						itemsMatch=1
					endif
				endif
			endif

			if itemsMatch=0 then
				rem --- ListButton selection needs to be updated before the message is displayed.
				col_hdr$=callpoint!.getTableColumnAttribute("POE_RECDET.SO_INT_SEQ_REF","LABS")
				g!=callpoint!.getDevObject("dtl_grid")
				g!.setCellListSelection(num(callpoint!.getValidationRow()), util.getGridColumnNumber(g!, col_hdr$), i, 1)

				msg_id$="PO_DS_ITEM_MISMATCH"
				msg_opt$=""
				gosub disp_message
				if msg_opt$="C" then
					callpoint!.setColumnData("POE_RECDET.SO_INT_SEQ_REF",callpoint!.getColumnData("POE_RECDET.SO_INT_SEQ_REF"),1)
					callpoint!.setStatus("ABORT")
				endif
			endif

			break
		endif
	next i

[[POE_RECDET.SO_INT_SEQ_REF.BINP]]
rem --- Refresh display of ListButton selection
	callpoint!.setColumnData("POE_RECDET.SO_INT_SEQ_REF",callpoint!.getColumnData("POE_RECDET.SO_INT_SEQ_REF"),1)

[[POE_RECDET.UNIT_COST.AVAL]]
gosub update_header_tots
callpoint!.setDevObject("cost_this_row",num(callpoint!.getUserInput()))

[[POE_RECDET.WAREHOUSE_ID.AVAL]]
rem --- Don't allow inactive code
	ivcWhseCode_dev=fnget_dev("IVC_WHSECODE")
	dim ivcWhseCode$:fnget_tpl$("IVC_WHSECODE")
	whse_code$=callpoint!.getUserInput()
	read record (ivcWhseCode_dev,key=firm_id$+"C"+whse_code$,dom=*next)ivcWhseCode$
	if ivcWhseCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Don't allow use of dropship warehouse for non-dropship items
	if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")<>"Y" then
		if pad(callpoint!.getUserInput(),2)=callpoint!.getDevObject("dropship_whse") then
			msg_id$="PO_NOT_DROPSHIP_ENTR"
			dim msg_tokens$[1]
			msg_tokens$[1]=callpoint!.getDevObject("dropship_whse")
			gosub disp_message
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		endif
	endif

rem --- Warehouse ID - After Validataion

if callpoint!.getHeaderColumnData("POE_RECHDR.WAREHOUSE_ID")<>pad(callpoint!.getUserInput(),2)
	msg_id$="PO_WHSE_NOT_MATCH"
	gosub disp_message
	callpoint!.setStatus("ACTIVATE-ABORT")
	break
endif

gosub validate_whse_item

[[POE_RECDET.WO_NO.AVAL]]
rem --- need to use custom query so we get back both po# and line#
rem --- throw message to user and abort manual entry

	if cvs(callpoint!.getUserInput(),3)<>""
		if callpoint!.getUserInput()<>callpoint!.getColumnData("POE_RECDET.WO_NO")
			if callpoint!.getDevObject("wo_looked_up")<>"Y"
				callpoint!.setMessage("PO_USE_QUERY")
				callpoint!.setStatus("ABORT")
			endif
		endif
	else
		callpoint!.setColumnData("POE_RECDET.WK_ORD_SEQ_REF","",1)
	endif

	callpoint!.setDevObject("wo_looked_up","N")

[[POE_RECDET.WO_NO.BINQ]]
rem --- call custom inquiry
rem --- Query displays WO's for given firm/vendor, only showing those not already linked to a PO, and only non-stocks (per v6 validation code)

	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$

	switch pos(line_type$="NS")
		case 1;rem Non-Stock
			call stbl("+DIR_SYP")+"bac_key_template.bbj","SFE_WOSUBCNT","AO_SUBCONT_SEQ",key_tpl$,rd_table_chans$[all],status$
			dim sf_sub_key$:key_tpl$
			wo_loc$=sf_sub_key.wo_location$

			saved_wo$=callpoint!.getColumnData("POE_RECDET.WO_NO")
			saved_seq$=callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF")
			sub_dev=fnget_dev("SFE_WOSUBCNT")
			dim subs$:fnget_tpl$("SFE_WOSUBCNT")
			read record (sub_dev,key=firm_id$+sf_sub_key.wo_location$+saved_wo$+saved_seq$,knum="AO_SUBCONT_SEQ",dom=*next)subs$
			if cvs(subs.wo_no$,3)=""
				saved_wo$=""
				saved_seq$=""
			else
				saved_seq$=subs.subcont_seq$
			endif

			dim filter_defs$[6,2]
			filter_defs$[1,0]="SFE_WOSUBCNT.FIRM_ID"
			filter_defs$[1,1]="='"+firm_id$ +"'"
			filter_defs$[1,2]="LOCK"
			filter_defs$[2,0]="SFE_WOSUBCNT.VENDOR_ID"
			filter_defs$[2,1]="='"+callpoint!.getHeaderColumnData("POE_RECHDR.VENDOR_ID")+"'"
			filter_defs$[2,2]="LOCK"
			filter_defs$[3,0]="SFE_WOSUBCNT.PO_NO"
			filter_defs$[3,1]="=''"
			filter_defs$[3,2]="LOCK"
			filter_defs$[4,0]="SFE_WOSUBCNT.LINE_TYPE"
			filter_defs$[4,1]="='S' "
			filter_defs$[4,2]="LOCK"
			filter_defs$[5,0]="SFE_WOSUBCNT.WO_LOCATION"
			filter_defs$[5,1]="='"+sf_sub_key.wo_location$+"' "
			filter_defs$[5,2]="LOCK"
			filter_defs$[6,0]="SFE_WOMASTR.WO_STATUS"
			filter_defs$[6,1]="not in ('Q','C') "
			filter_defs$[6,2]="LOCK"

			call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"SF_SUBDETAIL","",table_chans$[all],sf_sub_key$,filter_defs$[all]
			wo_type$="N"
			wo_key$=sf_sub_key$
			if wo_key$="" wo_key$=firm_id$+wo_loc$+saved_wo$+saved_seq$
			break
		case 2;rem Special Order Item
			whse$=callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
			item$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
			ivm_itemwhse=fnget_dev("IVM_ITEMWHSE")
			dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
			read record (ivm_itemwhse,key=firm_id$+whse$+item$,dom=*break) ivm_itemwhse$
			if ivm_itemwhse.special_ord$<>"Y" break
			call stbl("+DIR_SYP")+"bac_key_template.bbj","SFE_WOMATL","AO_MAT_SEQ",key_tpl$,rd_table_chans$[all],status$
			dim sf_mat_key$:key_tpl$
			wo_loc$=sf_mat_key.wo_location$

			saved_wo$=callpoint!.getColumnData("POE_RECDET.WO_NO")
			saved_seq$=callpoint!.getColumnData("POE_RECDET.WK_ORD_SEQ_REF")
			mat_dev=fnget_dev("SFE_WOMATL")
			dim mats$:fnget_tpl$("SFE_WOMATL")
			read record (mat_dev,key=firm_id$+sf_mat_key.wo_location$+saved_wo$+saved_seq$,knum="AO_MAT_SEQ",dom=*next)mats$
			if cvs(mats.wo_no$,3)=""
				saved_wo$=""
				saved_seq$=""
			else
				saved_seq$=mats.material_seq$
			endif

			dim filter_defs$[5,2]
			filter_defs$[1,0]="SFE_WOMATL.FIRM_ID"
			filter_defs$[1,1]="='"+firm_id$ +"'"
			filter_defs$[1,2]="LOCK"
			filter_defs$[2,0]="SFE_WOMATL.ITEM_ID"
			filter_defs$[2,1]="='"+callpoint!.getColumnData("POE_RECDET.ITEM_ID")+"'"
			filter_defs$[2,2]="LOCK"
			filter_defs$[3,0]="SFE_WOMATL.WO_LOCATION"
			filter_defs$[3,1]="='"+sf_mat_key.wo_location$+"' "
			filter_defs$[3,2]="LOCK"
			filter_defs$[4,0]="SFE_WOMATL.LINE_TYPE"
			filter_defs$[4,1]="='S' "
			filter_defs$[4,2]="LOCK"
			filter_defs$[5,0]="SFE_WOMASTR.WO_STATUS"
			filter_defs$[5,1]="not in ('C','Q') "
			filter_defs$[5,2]="LOCK"
	
			call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"SF_MATDETAIL","",table_chans$[all],sf_mat_key$,filter_defs$[all]
			wo_type$="S"
			wo_key$=sf_mat_key$
			if wo_key$="" wo_key$=firm_id$+wo_loc$+saved_wo$+saved_seq$
		break
		case default
		break
	swend

	if cvs(wo_key$,3)=firm_id$ wo_key$=""

	gosub get_wo_info

	if cvs(wo_key$,3)<>""
		callpoint!.setColumnData("POE_RECDET.WO_NO",wo_no$,1)
		callpoint!.setColumnData("POE_RECDET.WK_ORD_SEQ_REF",wo_line$,1)
		callpoint!.setDevObject("wo_looked_up","Y")
	else
		callpoint!.setColumnData("POE_RECDET.WO_NO","",1)
		callpoint!.setColumnData("POE_RECDET.WK_ORD_SEQ_REF","",1)
		callpoint!.setDevObject("wo_looked_up","N")
	endif

	callpoint!.setStatus("MODIFIED-ACTIVATE-ABORT")

[[POE_RECDET.<CUSTOM>]]
update_line_type_info:

	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	if callpoint!.getVariableName()="POE_RECDET.PO_LINE_CODE" then
		po_line_code$=callpoint!.getUserInput()
	else
		po_line_code$=callpoint!.getColumnData("POE_RECDET.PO_LINE_CODE")
	endif
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$
	callpoint!.setStatus("ENABLE:"+poc_linecode.line_type$)
	callpoint!.setDevObject("line_type",poc_linecode.line_type$)
	gosub enable_by_line_type

	rem --- Dropship PO line codes are no longer supported. Now the entire PO must be dropshipped.
	if poc_linecode.dropship$="Y" and callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")<>"Y" then
		msg_id$="PO_DROPSHIP_LINE_CD "
		gosub disp_message
	endif

return

validate_whse_item:
	ivm_itemwhse_dev=fnget_dev("IVM_ITEMWHSE")
	dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
	change_flag=0
	if callpoint!.getVariableName()="POE_RECDET.ITEM_ID" then
		item_id$=callpoint!.getUserInput()
		if item_id$<>callpoint!.getColumnData("POE_RECDET.ITEM_ID") or callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" 
			change_flag=1
		 endif
	else
		item_id$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
	endif
	if callpoint!.getVariableName()="POE_RECDET.WAREHOUSE_ID" then
		whse$=callpoint!.getUserInput()
		if whse$<>callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID") or callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y"
			change_flag=1
		endif
	else
		whse$=callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
	endif
		
	if change_flag and cvs(item_id$,2)<>"" then
		read record (ivm_itemwhse_dev,key=firm_id$+whse$+item_id$,dom=missing_warehouse) ivm_itemwhse$
		ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
		read record(ivm_itemmast_dev,key=firm_id$+item_id$)ivm_itemmast$
		callpoint!.setColumnData("POE_RECDET.UNIT_MEASURE",ivm_itemmast.purchase_um$)
		callpoint!.setColumnData("POE_RECDET.CONV_FACTOR",str(ivm_itemmast.conv_factor))
		if num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))=0 then callpoint!.setColumnData("POE_RECDET.CONV_FACTOR",str(1))
		if cvs(callpoint!.getColumnData("POE_RECDET.LOCATION"),2)="" then callpoint!.setColumnData("POE_RECDET.LOCATION","STOCK")
		callpoint!.setColumnData("POE_RECDET.UNIT_COST",str(num(callpoint!.getColumnData("POE_RECDET.CONV_FACTOR"))*ivm_itemwhse.unit_cost))
		callpoint!.setStatus("REFRESH")
	endif
return
	
missing_warehouse:

	msg_id$="IV_ITEM_WHSE_INVALID"
	dim msg_tokens$[1]
	msg_tokens$[1]=whse$
	gosub disp_message
	callpoint!.setStatus("ABORT")

return

update_header_tots:

if pos(".AVAL"=callpoint!.getCallpointEvent())
	if callpoint!.getVariableName()="POE_RECDET.QTY_RECEIVED"
		new_qty=num(callpoint!.getUserInput())
		new_cost=num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))
	else
		new_qty=num(callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))
		new_cost=num(callpoint!.getUserInput())
	endif
	gosub calculate_header_tots
endif

if pos(".ADEL"=callpoint!.getCallpointEvent())
	new_qty=0
	new_cost=0
	gosub calculate_header_tots
	callpoint!.setDevObject("qty_this_row",0)
	callpoint!.setDevObject("cost_this_row",0)
endif

if pos(".AUDE"=callpoint!.getCallpointEvent())
	new_cost=num(callpoint!.getColumnData("POE_RECDET.UNIT_COST"))
	new_qty=num(callpoint!.getColumnData("POE_RECDET.QTY_RECEIVED"))
	callpoint!.setDevObject("qty_this_row",0)
	callpoint!.setDevObject("cost_this_row",0)
	gosub calculate_header_tots
	callpoint!.setDevObject("qty_this_row",new_qty)
	callpoint!.setDevObject("cost_this_row",new_cost)
endif

return

calculate_header_tots:

total_amt=num(callpoint!.getDevObject("total_amt"))
old_price=round(num(callpoint!.getDevObject("qty_this_row"))*num(callpoint!.getDevObject("cost_this_row")),2) 
new_price=round(new_qty*new_cost,2)
new_total=total_amt-old_price+new_price
callpoint!.setDevObject("total_amt",new_total)
poe_rechdr_tamt!=callpoint!.getDevObject("poe_rechdr_tamt")
poe_rechdr_tamt!.setValue(new_total)
callpoint!.setHeaderColumnData("<<DISPLAY>>.ORDER_TOTAL",str(new_total))

rem print "amts:"
rem print "total_amt: ",total_amt
rem print "old_price: ",old_price
rem print "new_price: ",new_price
rem print "new_total: ",new_total

return

update_iv_oo:
rem --- used for un/delete rows; make sure curr_qty is set (+/-) before entry

curr_whse$ = callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
curr_item$ = callpoint!.getColumnData("POE_RECDET.ITEM_ID")

rem --- Initialize inventory item update

status=999
call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
if status then exitto std_exit

items$[1] = curr_whse$
items$[2] = curr_item$
refs[0]   = curr_qty

print "---Update OO: item = ", cvs(items$[2], 2), ", WH: ", items$[1], ", qty =", refs[0]; rem debug
				
call stbl("+DIR_PGM")+"ivc_itemupdt.aon","OO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
if status then exitto std_exit

return

rem --- Enable/Disable Serial Button
enable_serial:

rem "IN: item_id$

	ivm_itemmast=fnget_dev("IVM_ITEMMAST")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")

	callpoint!.setOptionEnabled("LENT",0)
	read record (ivm_itemmast,key=firm_id$+item_id$,dom=*return)ivm_itemmast$

	if pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y"
		callpoint!.setOptionEnabled("LENT",1)
	endif
	callpoint!.setDevObject("lotser_flag",ivm_itemmast.lotser_flag$)

	return

rem ==========================================================================
enable_by_line_type:
rem line_type$ : input
rem ==========================================================================

	this_row=callpoint!.getValidationRow()

	poe_podet_dev=fnget_dev("POE_PODET")
	podet_exists=0
	findrecord(poe_podet_dev,key=firm_id$+callpoint!.getColumnData("POE_RECDET.PO_NO")+callpoint!.getColumnData("POE_RECDET.INTERNAL_SEQ_NO"),dom=*next); podet_exists=1

	if podet_exists then
		rem --- Disable fields from an existing PO
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.PO_LINE_CODE",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.WAREHOUSE_ID",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.ITEM_ID",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.NS_ITEM_ID",0)
		if line_type$="V" then callpoint!.setColumnEnabled(this_row,"POE_RECDET.ORDER_MEMO",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.UNIT_MEASURE",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.CONV_FACTOR",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.QTY_ORDERED",0)
	else
		rem --- Enable fields not on an existing PO

		rem --- Disable warehouse for drop ship lines, or when warehouse entered in header
		if (callpoint!.getHeaderColumnData("POE_RECHDR.DROPSHIP")="Y" or poc_linecode.dropship$="Y") or
:		cvs(callpoint!.getHeaderColumnData("POE_RECHDR.WAREHOUSE_ID"),2)<>"" then
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.WAREHOUSE_ID",1)
		else
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.WAREHOUSE_ID",0)
		endif
		if pos(line_type$="N") then
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.NS_ITEM_ID",1)
		else
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.NS_ITEM_ID",0)
		endif
		if pos(line_type$="S") then
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.ITEM_ID",1)
		else
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.ITEM_ID",0)
		endif
		if pos(line_type$="MNOV") then
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.ORDER_MEMO",1)
		else
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.ORDER_MEMO",0)
		endif
		if pos(line_type$="SNV") then
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.UNIT_MEASURE",1)
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.CONV_FACTOR",1)
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.QTY_ORDERED",1)
		else
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.UNIT_MEASURE",0)
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.CONV_FACTOR",0)
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.QTY_ORDERED",0)
		endif
	endif

	if callpoint!.getDevObject("SF_installed")="Y"
		if line_type$="N"
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.WO_NO",1)
			callpoint!.setColumnEnabled(this_row,"POE_RECDET.WK_ORD_SEQ_REF",0)
		else
			whse$=callpoint!.getColumnData("POE_RECDET.WAREHOUSE_ID")
			if callpoint!.getCallpointEvent()="POE_RECDET.ITEM_ID.AVAL"
				item$=callpoint!.getUserInput()
			else
				item$=callpoint!.getColumnData("POE_RECDET.ITEM_ID")
			endif
			ivm_itemwhse=fnget_dev("IVM_ITEMWHSE")
			dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
			spec_ord$="N"
			while 1
				read record (ivm_itemwhse,key=firm_id$+whse$+item$,dom=*break) ivm_itemwhse$
				if ivm_itemwhse.special_ord$="Y" spec_ord$="Y"
				break
			wend
			if spec_ord$="Y"
				callpoint!.setColumnEnabled(this_row,"POE_RECDET.WO_NO",1)
				callpoint!.setColumnEnabled(this_row,"POE_RECDET.WK_ORD_SEQ_REF",0)
			else
				callpoint!.setColumnEnabled(this_row,"POE_RECDET.WO_NO",0)
				callpoint!.setColumnEnabled(this_row,"POE_RECDET.WK_ORD_SEQ_REF",0)
			endif
		endif
	else
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.WO_NO",0)
		callpoint!.setColumnEnabled(this_row,"POE_RECDET.WK_ORD_SEQ_REF",0)
	endif

	callpoint!.setStatus("REFRESH")
	callpoint!.setDevObject("line_type",poc_linecode.line_type$)

	rem --- Enable Comment button
	callpoint!.setOptionEnabled("COMM",1)

return

rem ========================================================
get_wo_info:
rem wo_key$:		input
rem wo_no$:		output
rem wo_line$:		output
rem wo_type$:	input
rem ========================================================

	sfe_wosub=fnget_dev("SFE_WOSUBCNT")
	dim sfe_wosub$:fnget_tpl$("SFE_WOSUBCNT")

	sfe_womatl=fnget_dev("SFE_WOMATL")
	dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")

	rem --- wo_key$ will be firm/wo_loc/wo_no/seq - need to read the correct table to get ISN
	if wo_key$<>""
		if wo_key$(len(wo_key$),1)="^" then wo_key$=wo_key$(1,len(wo_key$)-1)
		switch pos(wo_type$="NS")
			case 1; rem Non-stock Subcontract line
				read record (sfe_wosub,key=wo_key$,knum="PRIMARY") sfe_wosub$
				wo_no$=sfe_wosub.wo_no$
				wo_line$=sfe_wosub.internal_seq_no$
			break
			case 2;rem Special Order Item
				read record (sfe_womatl,key=wo_key$,knum="PRIMARY") sfe_womatl$
				wo_no$=sfe_womatl.wo_no$
				wo_line$=sfe_womatl.internal_seq_no$
			break
			case default
			break	
		swend
			
	endif

	return

rem ==========================================================================
comment_entry:
rem --- on a line where you can access the memo/non-stock (order_memo) field, pop the new memo_1024 editor instead
rem --- the editor can be popped on demand for any line using the Comments button (alt-C),
rem --- but will automatically pop for lines where the order_memo field is enabled.
rem ==========================================================================

	disp_text$=callpoint!.getColumnData("POE_RECDET.MEMO_1024")
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
:		"Requisition/PO Comments",
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
		memo_len=len(callpoint!.getColumnData("POE_RECDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("POE_RECDET.MEMO_1024",disp_text$,1)
		callpoint!.setColumnData("POE_RECDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE")

	return



