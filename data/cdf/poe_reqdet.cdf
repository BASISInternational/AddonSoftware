[[POE_REQDET.ADEL]]
gosub update_header_tots

rem --- Update links to Work Orders
	SF_installed$=callpoint!.getDevObject("SF_installed")
	wo_no$=callpoint!.getColumnData("POE_REQDET.WO_NO")
	if SF_installed$="Y" and cvs(wo_no$,2)<>"" then
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		sfe_womatl_dev=fnget_dev("SFE_WOMATL")
		sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")

		po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
		find record (poc_linecode_dev,key=firm_id$+po_line_code$,dom=*endif) poc_linecode$
		if pos(poc_linecode.line_type$="NS")<>0  then
			old_wo$=wo_no$
			old_woseq$=callpoint!.getColumnData("POE_REQDET.WK_ORD_SEQ_REF")
			new_wo$=""
			new_woseq$=""
			req_no$=callpoint!.getColumnData("POE_REQDET.REQ_NO")
			req_seq$=callpoint!.getColumnData("POE_REQDET.INTERNAL_SEQ_NO")
			call pgmdir$+"poc_requpdate.aon",sfe_womatl_dev,sfe_wosubcnt_dev,
:				req_no$,req_seq$,"R",poc_linecode.line_type$,old_wo$,old_woseq$,new_wo$,new_woseq$,status
		endif
	endif

[[POE_REQDET.ADGE]]
rem --- if there are order lines to display/access in the sales order line item listbutton, set the LDAT and list display
rem --- get the detail grid, then get the listbutton within the grid; set the list on the listbutton, and put the listbutton back in the grid

order_list!=callpoint!.getDevObject("so_lines_list")
ldat$=callpoint!.getDevObject("so_ldat")

if ldat$<>""
	callpoint!.setColumnEnabled(-1,"POE_REQDET.SO_INT_SEQ_REF",1)
	callpoint!.setTableColumnAttribute("POE_REQDET.SO_INT_SEQ_REF","LDAT",ldat$)
	g!=callpoint!.getDevObject("dtl_grid")
	col_hdr$=callpoint!.getTableColumnAttribute("POE_REQDET.SO_INT_SEQ_REF","LABS")
	col_ref=util.getGridColumnNumber(g!, col_hdr$)
	c!=g!.getColumnListControl(col_ref)
	c!.removeAllItems()
	c!.insertItems(0,order_list!)
	g!.setColumnListControl(col_ref,c!)	
else
	callpoint!.setColumnEnabled(-1,"POE_REQDET.SO_INT_SEQ_REF",0)
endif 

rem ---Disable/enable the warehouse_id column
if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" then
	if callpoint!.getHeaderColumnData("POE_REQHDR.DROPSHIP")="Y" then
		callpoint!.setColumnEnabled(-1,"POE_REQDET.WAREHOUSE_ID",0)
	else
		callpoint!.setColumnEnabled(-1,"POE_REQDET.WAREHOUSE_ID",1)
	endif
endif

[[POE_REQDET.ADTW]]
rem --- Initializations
	use ::sfo_SfUtils.aon::SfUtils

[[POE_REQDET.AGCL]]
rem print 'show';rem debug

use ::ado_util.src::util

rem --- set default line code based on param file
callpoint!.setTableColumnAttribute("POE_REQDET.PO_LINE_CODE","DFLT",str(callpoint!.getDevObject("dflt_po_line_code")))

rem --- Set column size for memo_1024 field very small so it doesn't take up room, but still available for hover-over of memo contents

	grid! = util.getGrid(Form!)
	col_hdr$=callpoint!.getTableColumnAttribute("POE_REQDET.MEMO_1024","LABS")
	memo_1024_col=util.getGridColumnNumber(grid!, col_hdr$)
	grid!.setColumnWidth(memo_1024_col,15)

[[POE_REQDET.AGDR]]
rem --- After Grid Display Row

po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
if cvs(po_line_code$,2)<>"" then  
    gosub update_line_type_info
endif


total_amt=num(callpoint!.getDevObject("total_amt"))
total_amt=total_amt+round(num(callpoint!.getColumnData("POE_REQDET.REQ_QTY"))*num(callpoint!.getColumnData("POE_REQDET.UNIT_COST")),2)
callpoint!.setDevObject("total_amt",str(total_amt))

	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$
	gosub enable_by_line_type

[[POE_REQDET.AGRE]]
rem --- check data to see if o.k. to leave row (only if the row isn't marked as deleted)

rem print "col data: ",callpoint!.getColumnData("POE_REQDET.REQ_QTY")
rem print "disk data: ",callpoint!.getColumnDiskData("POE_REQDET.REQ_QTY")

if callpoint!.getGridRowDeleteStatus(num(callpoint!.getValidationRow()))<>"Y"

	ok_to_write$="Y"

	if ok_to_write$="Y" and  cvs(callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE"),3)=""
		ok_to_write$="N"
		focus_column$="POE_REQDET.PO_LINE_CODE"
		translate$="AON_LINE_CODE"
	else
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
		read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
		line_type$=poc_linecode.line_type$
	endif

	if ok_to_write$="Y" and  cvs(callpoint!.getColumnData("POE_REQDET.WAREHOUSE_ID"),3)="" 
		ok_to_write$="N"
		focus_column$="POE_REQDET.WAREHOUSE_ID"
		translate$="AON_WAREHOUSE"
	endif

	if ok_to_write$="Y" and pos(line_type$="SD")<>0 
		if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_REQDET.ITEM_ID"),3)=""
			ok_to_write$="N"
			focus_column$="POE_REQDET.ITEM_ID"
			translate$="AON_ITEM"
		endif
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_REQDET.CONV_FACTOR"))<=0
			ok_to_write$="N"
			focus_column$="POE_REQDET.CONV_FACTOR"
			translate$="AON_CONVERSION_FACTOR"
		endif
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))<0
			ok_to_write$="N"
			focus_column$="POE_REQDET.UNIT_COST"
			translate$="AON_UNIT_COST"
		endif
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_REQDET.REQ_QTY"))<=0
			ok_to_write$="N"
			focus_column$="POE_REQDET.REQ_QTY"
			translate$="AON_QUANTITY_REQUIRED"
		endif
	endif

	if ok_to_write$="Y" and  line_type$="N" 
		if ok_to_write$="Y" and  num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))<0
			ok_to_write$="N"
			focus_column$="POE_REQDET.UNIT_COST"
			translate$="AON_UNIT_COST"
		endif
		if ok_to_write$="Y" and  num(callpoint!.getColumnData("POE_REQDET.REQ_QTY"))<=0
			ok_to_write$="N"
			focus_column$="POE_REQDET.REQ_QTY"
			translate$="AON_QUANTITY_REQUIRED"
		endif
	endif

	if ok_to_write$="Y" and line_type$="O" 
		if ok_to_write$="Y" and num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))<0
			ok_to_write$="N"
			focus_column$="POE_REQDET.UNIT_COST"
			translate$="AON_UNIT_COST"
		endif
	endif

	if ok_to_write$="Y" and pos(line_type$="NOV")<>0 
		if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_REQDET.ORDER_MEMO"),3)="" 
			ok_to_write$="N"
			focus_column$="POE_REQDET.ORDER_MEMO"
			translate$="AON_MEMO"
		endif
	endif

	if ok_to_write$="Y" and callpoint!.getHeaderColumnData("POE_REQHDR.DROPSHIP")="Y" and callpoint!.getDevObject("OP_installed")="Y"
		if ok_to_write$="Y" and pos(line_type$="DSNO")<>0
			if ok_to_write$="Y" and cvs(callpoint!.getColumnData("POE_REQDET.SO_INT_SEQ_REF"),3)="" 
				ok_to_write$="N"
				focus_column$="POE_REQDET.SO_INT_SEQ_REF"
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
						callpoint!.setFocus(num(callpoint!.getValidationRow()),"POE_REQDET.SO_INT_SEQ_REF",1)
						break
					else
						so_lines_referenced$=so_lines_referenced$+rec.so_int_seq_ref$+"^"
					endif
				endif
			endif
		next x
	endif
Bug8251:

endif

rem --- look at wo number; if different than it was when we entered the row, update and/or remove link in corresponding wo detail line
if callpoint!.getDevObject("SF_installed")="Y" then
	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$

	wo_no_was$=callpoint!.getDevObject("start_wo_no")
	wo_seq_ref_was$=callpoint!.getDevObject("start_wo_seq_ref")

	wo_no_now$=callpoint!.getColumnData("POE_REQDET.WO_NO")
	wo_seq_ref_now$=callpoint!.getColumnData("POE_REQDET.WK_ORD_SEQ_REF")

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
				sfe_womatl.po_no$=callpoint!.getColumnData("POE_REQDET.REQ_NO")
				sfe_womatl.pur_ord_seq_ref$=callpoint!.getColumnData("POE_REQDET.INTERNAL_SEQ_NO")
				sfe_womatl$.po_status$="R"
				sfe_womatl$=field(sfe_womatl$)
				write record (sfe_womatl)sfe_womatl$
			endif
			if line_type$="N"
				find record (sfe_wosub,key=firm_id$+sfe_wosub.wo_location$+wo_no_now$+wo_seq_ref_now$,knum="AO_SUBCONT_SEQ",dom=*endif)sfe_wosub$
				sfe_wosub.po_no$=callpoint!.getColumnData("POE_REQDET.REQ_NO")
				sfe_wosub.pur_ord_seq_ref$=callpoint!.getColumnData("POE_REQDET.INTERNAL_SEQ_NO")
				sfe_wosub.po_status$="R"
				sfe_wosub$=field(sfe_wosub$)
				write record (sfe_wosub)sfe_wosub$
			endif
		endif
	endif
endif

[[POE_REQDET.AGRN]]
rem --- save current qty/price this row

callpoint!.setDevObject("qty_this_row",callpoint!.getColumnData("POE_REQDET.REQ_QTY"))
callpoint!.setDevObject("cost_this_row",callpoint!.getColumnData("POE_REQDET.UNIT_COST"))

rem print "AGRN "
rem print "qty this row: ",callpoint!.getDevObject("qty_this_row")
rem print "cost this row: ",callpoint!.getDevObject("cost_this_row")

rem print "AGRN line_no: ",callpoint!.getColumnData("POE_REQDET.PO_LINE_NO")


	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$
	gosub enable_by_line_type

rem --- save current po status flag, po/req# and line#

	callpoint!.setDevObject("start_wo_no",callpoint!.getColumnData("POE_REQDET.WO_NO"))
	callpoint!.setDevObject("start_wo_seq_ref",callpoint!.getColumnData("POE_REQDET.WK_ORD_SEQ_REF"))
	callpoint!.setDevObject("wo_looked_up","N")

[[POE_REQDET.AOPT-COMM]]
rem --- invoke the comments dialog

	gosub comment_entry

[[POE_REQDET.AREC]]
callpoint!.setDevObject("qty_this_row",0)
callpoint!.setDevObject("cost_this_row",0)

rem --- set dates from Header

callpoint!.setColumnData("POE_REQDET.NOT_B4_DATE",callpoint!.getHeaderColumnData("POE_REQHDR.NOT_B4_DATE"))
callpoint!.setColumnData("POE_REQDET.REQD_DATE",callpoint!.getHeaderColumnData("POE_REQHDR.REQD_DATE"))
callpoint!.setColumnData("POE_REQDET.PROMISE_DATE",callpoint!.getHeaderColumnData("POE_REQHDR.PROMISE_DATE"))

rem --- Comments button initially disabled
callpoint!.setOptionEnabled("COMM",0)

rem --- REFRESH is needed in order to get the default PO_LINE_CODE set in AGCL
callpoint!.setStatus("REFRESH")

rem --- Initialize warehouse_id for dropships
if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and callpoint!.getHeaderColumnData("POE_REQHDR.DROPSHIP")="Y" then
	callpoint!.setColumnData("POE_REQDET.WAREHOUSE_ID",str(callpoint!.getDevObject("dropship_whse")),1)
endif

[[POE_REQDET.AUDE]]
gosub update_header_tots

rem --- Update links to Work Orders
	SF_installed$=callpoint!.getDevObject("SF_installed")
	wo_no$=callpoint!.getColumnUndoData("POE_REQDET.WO_NO")
	if SF_installed$="Y" and cvs(wo_no$,2)<>"" then
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		sfe_womatl_dev=fnget_dev("SFE_WOMATL")
		sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")

		po_line_code$=callpoint!.getColumnUndoData("POE_REQDET.PO_LINE_CODE")
		find record (poc_linecode_dev,key=firm_id$+po_line_code$,dom=*endif) poc_linecode$
		if pos(poc_linecode.line_type$="NS")<>0  then
			old_wo$=""
			old_woseq$=""
			new_wo$=wo_no$
			new_woseq$=callpoint!.getColumnUndoData("POE_REQDET.WK_ORD_SEQ_REF")
			req_no$=callpoint!.getColumnUndoData("POE_REQDET.REQ_NO")
			req_seq$=callpoint!.getColumnUndoData("POE_REQDET.INTERNAL_SEQ_NO")
			call pgmdir$+"poc_requpdate.aon",sfe_womatl_dev,sfe_wosubcnt_dev,
:				req_no$,req_seq$,"R",poc_linecode.line_type$,old_wo$,old_woseq$,new_wo$,new_woseq$,status
		endif
	endif

[[POE_REQDET.BDGX]]
rem -- loop thru gridVect; if there are any lines not marked deleted, set the callpoint!.setDevObject("dtl_posted") to Y

dtl!=gridVect!.getItem(0)
callpoint!.setDevObject("dtl_posted","")

if dtl!.size()
	for x=0 to dtl!.size()-1
		if callpoint!.getGridRowDeleteStatus(x)<>"Y" then callpoint!.setDevObject("dtl_posted","Y")
	next x
endif

callpoint!.setOptionEnabled("COMM",0)

[[POE_REQDET.BGDS]]
rem --- Re-initialize requisition total amount before it's accumulated again for each detail row
	callpoint!.setDevObject("total_amt","0")

[[POE_REQDET.CONV_FACTOR.AVAL]]
rem --- Recalc Unit Cost

	prev_fact=num(callpoint!.getColumnData("POE_REQDET.CONV_FACTOR"))
	new_fact=num(callpoint!.getUserInput())
	unit_cost=num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))
	if num(callpoint!.getUserInput())<>prev_fact and prev_fact<>0
		unit_cost=unit_cost/prev_fact
		unit_cost=unit_cost*new_fact
		callpoint!.setColumnData("POE_REQDET.UNIT_COST",str(unit_cost),1)
		gosub update_header_tots
		callpoint!.setDevObject("cost_this_row",unit_cost)
	endif

[[POE_REQDET.ITEM_ID.AINV]]
rem --- Item synonym processing
 
	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::grid_entry"
     

[[POE_REQDET.ITEM_ID.AVAL]]
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

	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$
	gosub enable_by_line_type

[[POE_REQDET.ITEM_ID.BINQ]]
rem --- Inventory Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("POE_REQDET.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]=""
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"IV_ITEM_WHSE_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("POE_REQDET.ITEM_ID") then 
		callpoint!.setColumnData("POE_REQDET.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"POE_REQDET.ITEM_ID",1)
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_REQDET.MEMO_1024.AVAL]]
rem --- store first part of memo_1024 in order_memo
rem --- this AVAL is hit if user navigates via arrows or clicks on the memo_1024 field, and double-clicks or ctrl-F to bring up editor
rem --- if on a memo line or using ctrl-C or Comments button, code in the comment_entry: subroutine is hit instead

	disp_text$=callpoint!.getUserInput()
	if disp_text$<>callpoint!.getColumnUndoData("POE_REQDET.MEMO_1024")
		memo_len=len(callpoint!.getColumnData("POE_REQDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("POE_REQDET.MEMO_1024",disp_text$,1)
		callpoint!.setColumnData("POE_REQDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

[[POE_REQDET.ORDER_MEMO.BINP]]
rem --- invoke the comments dialog

	gosub comment_entry

[[POE_REQDET.PO_LINE_CODE.AVAL]]
rem --- Line Code - After Validataion

rem  print "userInput: ",callpoint!.getUserInput();rem debug
rem  print "columnData: ",callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE");rem debug
rem  print "undoData: ",callpoint!.getColumnUndoData("POE_REQDET.PO_LINE_CODE");rem debug
rem print "validation row:", callpoint!.getValidationRow()
rem print "new status:",callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))
rem print "modify status:",callpoint!.getGridRowModifyStatus(num(callpoint!.getValidationRow()))

gosub update_line_type_info

if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))="Y" or cvs(callpoint!.getUserInput(),2)<>cvs(callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE"),2) 

		callpoint!.setColumnData("POE_REQDET.PO_LINE_CODE",callpoint!.getUserInput())
		callpoint!.setColumnData("POE_REQDET.CONV_FACTOR","")
		callpoint!.setColumnData("POE_REQDET.FORECAST","")
		callpoint!.setColumnData("POE_REQDET.ITEM_ID","")
		callpoint!.setColumnData("POE_REQDET.LEAD_TIM_FLG","")
		callpoint!.setColumnData("POE_REQDET.LOCATION","")
		callpoint!.setColumnData("POE_REQDET.MEMO_1024","")
		callpoint!.setColumnData("POE_REQDET.NOT_B4_DATE",callpoint!.getHeaderColumnData("POE_REQHDR.NOT_B4_DATE"))
		callpoint!.setColumnData("POE_REQDET.NS_ITEM_ID","")
		callpoint!.setColumnData("POE_REQDET.ORDER_MEMO","")
		callpoint!.setColumnData("POE_REQDET.PO_MSG_CODE","")
		callpoint!.setColumnData("POE_REQDET.PROMISE_DATE",callpoint!.getHeaderColumnData("POE_REQHDR.PROMISE_DATE"))
		callpoint!.setColumnData("POE_REQDET.REQD_DATE",callpoint!.getHeaderColumnData("POE_REQHDR.REQD_DATE"))
		callpoint!.setColumnData("POE_REQDET.REQ_QTY","")
		callpoint!.setColumnData("POE_REQDET.SO_INT_SEQ_REF","")
		callpoint!.setColumnData("POE_REQDET.SOURCE_CODE","")
		callpoint!.setColumnData("POE_REQDET.UNIT_COST","")
		callpoint!.setColumnData("POE_REQDET.UNIT_MEASURE","")
		callpoint!.setColumnData("POE_REQDET.WAREHOUSE_ID",callpoint!.getHeaderColumnData("POE_REQHDR.WAREHOUSE_ID"))
		callpoint!.setColumnData("POE_REQDET.WO_NO","")
		callpoint!.setColumnData("POE_REQDET.WK_ORD_SEQ_REF","")
		callpoint!.setStatus("REFRESH")

	rem --- If a V line type immediately follows an S line type containing an item with this vendor's part number,
	rem --- that number is automatically displayed.
	if line_type$="V" and callpoint!.getValidationRow()>0  then
		rem --- Get line code for previous row
		dtl!=gridVect!.getItem(0)
		dim rec$:dtlg_param$[1,3]
		rec$=dtl!.getItem(callpoint!.getValidationRow()-1)
		prev_row_line_code$=rec.po_line_code$
		prev_row_item_id$=rec.item_id$

		rem --- Get line type for previous row's line code
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		read record(poc_linecode_dev,key=firm_id$+prev_row_line_code$,dom=*next)poc_linecode$
		prev_row_line_type$=poc_linecode.line_type$

		rem --- Get this vendor's part number for item
		if prev_row_line_type$="S" then
			ivm_itemvend_dev=fnget_dev("IVM_ITEMVEND")
			dim ivm_itemvend$:fnget_tpl$("IVM_ITEMVEND")
			vendor_id$=callpoint!.getHeaderColumnData("POE_REQHDR.VENDOR_ID")
			read record(ivm_itemvend_dev,key=firm_id$+vendor_id$+prev_row_item_id$,dom=*next)ivm_itemvend$
			callpoint!.setColumnData("POE_REQDET.ORDER_MEMO",ivm_itemvend.vendor_item$,1)
			callpoint!.setColumnData("POE_REQDET.MEMO_1024",ivm_itemvend.vendor_item$,1)
		endif
	endif
endif

if callpoint!.getDevObject("line_type")="O" 
	callpoint!.setColumnData("POE_REQDET.REQ_QTY","1")
else
	callpoint!.setColumnData("POE_REQDET.REQ_QTY","")
endif

gosub enable_by_line_type

if line_type$="M" and cvs(callpoint!.getColumnData("POE_REQDET.ORDER_MEMO"),2)=""
	callpoint!.setColumnData("POE_REQDET.ORDER_MEMO"," ")
	callpoint!.setStatus("MODIFIED")
endif

[[POE_REQDET.PO_MSG_CODE.AVAL]]
rem --- Don't allow inactive code
	pocMessage_dev=fnget_dev("POC_MESSAGE")
	dim pocMessage$:fnget_tpl$("POC_MESSAGE")
	po_msg_code$=callpoint!.getUserInput()
	read record(pocMessage_dev,key=firm_id$+po_msg_code$,dom=*next)pocMessage$
	if pocMessage.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(pocMessage.po_msg_code$,3)
		msg_tokens$[2]=cvs(pocMessage.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_REQDET.REQ_QTY.AVAL]]
rem --- call poc.ua to retrieve unit cost from ivm-05, at least that's what v6 did here
rem --- send in: R/W for retrieve or write
rem                   R for req, P for PO, Q for QA recpt, C for PO recpt
rem                   vendor_id and ord_date from header rec
rem                   item_id,conv factor, unit cost, req qty or ordered qty from detail record
rem                   IV precision from iv params rec
rem 			status

vendor_id$=callpoint!.getHeaderColumnData("POE_REQHDR.VENDOR_ID")
ord_date$=callpoint!.getHeaderColumnData("POE_REQHDR.ORD_DATE")
item_id$=callpoint!.getColumnData("POE_REQDET.ITEM_ID")
conv_factor=num(callpoint!.getColumnData("POE_REQDET.CONV_FACTOR"))
unit_cost=num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))
req_qty=num(callpoint!.getUserInput())
status=0

call stbl("+DIR_PGM")+"poc_itemvend.aon","R","R",vendor_id$,ord_date$,item_id$,conv_factor,unit_cost,req_qty,callpoint!.getDevObject("iv_prec"),status

callpoint!.setColumnData("POE_REQDET.UNIT_COST",str(unit_cost),1)

gosub update_header_tots
callpoint!.setDevObject("qty_this_row",num(callpoint!.getUserInput()))
callpoint!.setDevObject("cost_this_row",unit_cost);rem setting both qty and cost because cost may have changed based on qty break

[[POE_REQDET.REQ_QTY.BINP]]
if callpoint!.getDevObject("line_type")="O"  
	callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQ_QTY",0)
	callpoint!.setFocus("POE_REQDET.UNIT_COST")
endif

[[POE_REQDET.SO_INT_SEQ_REF.BINP]]
rem --- Refresh display of ListButton selection
	callpoint!.setColumnData("POE_REQDET.SO_INT_SEQ_REF",callpoint!.getColumnData("POE_REQDET.SO_INT_SEQ_REF"),1)

[[POE_REQDET.UNIT_COST.AVAL]]
gosub update_header_tots
callpoint!.setDevObject("cost_this_row",num(callpoint!.getUserInput()))

[[POE_REQDET.WAREHOUSE_ID.AVAL]]
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
	if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and callpoint!.getHeaderColumnData("POE_REQHDR.DROPSHIP")<>"Y" then
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

	if callpoint!.getHeaderColumnData("POE_REQHDR.WAREHOUSE_ID")<>pad(callpoint!.getUserInput(),2)
		msg_id$="PO_WHSE_NOT_MATCH"
		gosub disp_message
	endif

	gosub validate_whse_item

[[POE_REQDET.WO_NO.AVAL]]
rem --- need to use custom query so we get back both po# and line#
rem --- throw message to user and abort manual entry

	if cvs(callpoint!.getUserInput(),3)<>""
		if callpoint!.getUserInput()<>callpoint!.getColumnData("POE_REQDET.WO_NO")
			if callpoint!.getDevObject("wo_looked_up")<>"Y"
				callpoint!.setMessage("PO_USE_QUERY")
				callpoint!.setStatus("ABORT")
			endif
			break
		else
			rem --- Warn existing transactions if WO is being closed complete.
			wo_no$=callpoint!.getUserInput()
			wo_location$="  "
			sfutils!=new SfUtils(firm_id$)
			closeComplete=sfutils!.woClosedComplete(wo_no$,wo_location$)
			sfutils!.close()
			if closeComplete then
				msg_id$="SF_CLOSE_COMP_EXIST"
				dim msg_tokens$[1]
				msg_tokens$[1]=wo_no$
				gosub disp_message
			endif
		endif
	else
		callpoint!.setColumnData("POE_REQDET.WK_ORD_SEQ_REF","",1)
	endif

	callpoint!.setDevObject("wo_looked_up","N")

[[POE_REQDET.WO_NO.BINQ]]
rem --- call custom inquiry
rem --- Query displays WO's for given firm/vendor, only showing those not already linked to a PO, and only non-stocks (per v6 validation code)

	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$

	switch pos(line_type$="NS")
		case 1;rem Non-Stock
			call stbl("+DIR_SYP")+"bac_key_template.bbj","SFE_WOSUBCNT","AO_SUBCONT_SEQ",key_tpl$,rd_table_chans$[all],status$
			dim sf_sub_key$:key_tpl$
			wo_loc$=sf_sub_key.wo_location$

			saved_wo$=callpoint!.getColumnData("POE_REQDET.WO_NO")
			saved_seq$=callpoint!.getColumnData("POE_REQDET.WK_ORD_SEQ_REF")
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
			filter_defs$[2,1]="='"+callpoint!.getHeaderColumnData("POE_REQHDR.VENDOR_ID")+"'"
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
			whse$=callpoint!.getColumnData("POE_REQDET.WAREHOUSE_ID")
			item$=callpoint!.getColumnData("POE_REQDET.ITEM_ID")
			ivm_itemwhse=fnget_dev("IVM_ITEMWHSE")
			dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
			read record (ivm_itemwhse,key=firm_id$+whse$+item$,dom=*break) ivm_itemwhse$
			if ivm_itemwhse.special_ord$<>"Y" break
			call stbl("+DIR_SYP")+"bac_key_template.bbj","SFE_WOMATL","AO_MAT_SEQ",key_tpl$,rd_table_chans$[all],status$
			dim sf_mat_key$:key_tpl$
			wo_loc$=sf_mat_key.wo_location$

			saved_wo$=callpoint!.getColumnData("POE_REQDET.WO_NO")
			saved_seq$=callpoint!.getColumnData("POE_REQDET.WK_ORD_SEQ_REF")
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
			filter_defs$[2,1]="='"+callpoint!.getColumnData("POE_REQDET.ITEM_ID")+"'"
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

rem --- Don't allow new transactions if WO is being closed complete. Warn existing transactions.
	sfutils!=new SfUtils(firm_id$)
	closeComplete=sfutils!.woClosedComplete(wo_no$,wo_location$)
	sfutils!.close()
	if closeComplete then
		msg_id$="SF_CLOSE_COMP_EXIST"
		dim msg_tokens$[1]
		msg_tokens$[1]=wo_no$
		gosub disp_message
		if wo_no$<>callpoint!.getColumnData("POE_REQDET.WO_NO") then
			callpoint!.setColumnData("POE_REQDET.WO_NO","",1)
			callpoint!.setColumnData("POE_REQDET.WK_ORD_SEQ_REF","",1)
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

	if cvs(wo_key$,3)<>""
		callpoint!.setColumnData("POE_REQDET.WO_NO",wo_no$,1)
		callpoint!.setColumnData("POE_REQDET.WK_ORD_SEQ_REF",wo_line$,1)
		callpoint!.setDevObject("wo_looked_up","Y")
	else
		callpoint!.setColumnData("POE_REQDET.WO_NO","",1)
		callpoint!.setColumnData("POE_REQDET.WK_ORD_SEQ_REF","",1)
		callpoint!.setDevObject("wo_looked_up","N")
	endif

	callpoint!.setStatus("MODIFIED-ACTIVATE-ABORT")

[[POE_REQDET.<CUSTOM>]]
rem ==========================================================================
update_line_type_info:
rem ==========================================================================
	poc_linecode_dev=fnget_dev("POC_LINECODE")
	dim poc_linecode$:fnget_tpl$("POC_LINECODE")

	if callpoint!.getVariableName()="POE_REQDET.PO_LINE_CODE" then
		po_line_code$=callpoint!.getUserInput()
	else
		po_line_code$=callpoint!.getColumnData("POE_REQDET.PO_LINE_CODE")
	endif
	read record(poc_linecode_dev,key=firm_id$+po_line_code$,dom=*next)poc_linecode$
	line_type$=poc_linecode.line_type$

	rem --- Dropship PO line codes are no longer supported. Now the entire PO must be dropshipped.
	if poc_linecode.dropship$="Y" and callpoint!.getHeaderColumnData("POE_REQHDR.DROPSHIP")<>"Y" then
		msg_id$="PO_DROPSHIP_LINE_CD "
		gosub disp_message
	endif

rem --- Manually enable/disable fields based on Line Type

rem	callpoint!.setStatus("ENABLE:"+poc_linecode.line_type$)
	switch pos(poc_linecode.line_type$="SNOMV")
		case 1; rem Standard
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NS_ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ITEM_ID",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ORDER_MEMO",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_MEASURE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.CONV_FACTOR",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQ_QTY",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_COST",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.LOCATION",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQD_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PROMISE_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NOT_B4_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PO_MSG_CODE",1)
			break
		case 2; rem Non-stock
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NS_ITEM_ID",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ORDER_MEMO",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_MEASURE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.CONV_FACTOR",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQ_QTY",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_COST",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.LOCATION",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQD_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PROMISE_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NOT_B4_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PO_MSG_CODE",1)
			break
		case 3; rem Other
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NS_ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ORDER_MEMO",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_MEASURE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.CONV_FACTOR",0)
			callpoint!.setColumnData("POE_REQDET.REQ_QTY","1")
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQ_QTY",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_COST",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.LOCATION",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQD_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PROMISE_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NOT_B4_DATE",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PO_MSG_CODE",1)
			break
		case 4; rem Memo
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NS_ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ORDER_MEMO",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_MEASURE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.CONV_FACTOR",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQ_QTY",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_COST",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.LOCATION",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQD_DATE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PROMISE_DATE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NOT_B4_DATE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PO_MSG_CODE",0)
			break
		case 5; rem Vendor Part Number
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NS_ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ITEM_ID",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.ORDER_MEMO",1)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_MEASURE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.CONV_FACTOR",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQ_QTY",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.UNIT_COST",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.LOCATION",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.REQD_DATE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PROMISE_DATE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.NOT_B4_DATE",0)
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"POE_REQDET.PO_MSG_CODE",0)
			break
		case default; rem everything else
			break
	swend
	callpoint!.setDevObject("line_type",poc_linecode.line_type$)

return

rem ==========================================================================
validate_whse_item:
rem ==========================================================================
	ivm_itemwhse_dev=fnget_dev("IVM_ITEMWHSE")
	dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
	change_flag=0

	if callpoint!.getVariableName()="POE_REQDET.ITEM_ID" then
		item_id$=callpoint!.getUserInput()
		if item_id$<>callpoint!.getColumnData("POE_REQDET.ITEM_ID") or callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y"
			change_flag=1
		 endif
	else
		item_id$=callpoint!.getColumnData("POE_REQDET.ITEM_ID")
	endif
	if callpoint!.getVariableName()="POE_REQDET.WAREHOUSE_ID" then
		whse$=callpoint!.getUserInput()
		if whse$<>callpoint!.getColumnData("POE_REQDET.WAREHOUSE_ID") or callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y"
			change_flag=1
		endif
	else
		whse$=callpoint!.getColumnData("POE_REQDET.WAREHOUSE_ID")
	endif
	
	if change_flag and cvs(item_id$,2)<>"" then
		read record (ivm_itemwhse_dev,key=firm_id$+whse$+item_id$,knum="PRIMARY",dom=missing_warehouse) ivm_itemwhse$
		ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
		read record(ivm_itemmast_dev,key=firm_id$+item_id$)ivm_itemmast$
		callpoint!.setColumnData("POE_REQDET.UNIT_MEASURE",ivm_itemmast.purchase_um$)
		callpoint!.setColumnData("POE_REQDET.CONV_FACTOR",str(ivm_itemmast.conv_factor))
		if num(callpoint!.getColumnData("POE_REQDET.CONV_FACTOR"))=0 then callpoint!.setColumnData("POE_REQDET.CONV_FACTOR",str(1))
		if cvs(callpoint!.getColumnData("POE_REQDET.LOCATION"),2)="" then callpoint!.setColumnData("POE_REQDET.LOCATION","STOCK")
		callpoint!.setColumnData("POE_REQDET.UNIT_COST",str(num(callpoint!.getColumnData("POE_REQDET.CONV_FACTOR"))*ivm_itemwhse.unit_cost))
		callpoint!.setStatus("REFRESH")
	endif
return
		
rem ==========================================================================	
missing_warehouse:
rem ==========================================================================
	msg_id$="IV_ITEM_WHSE_INVALID"
	dim msg_tokens$[1]
	msg_tokens$[1]=whse$
	gosub disp_message
	callpoint!.setStatus("ABORT")

return

rem ==========================================================================
update_header_tots:
rem ==========================================================================

if pos(".AVAL"=callpoint!.getCallpointEvent())
	if callpoint!.getVariableName()="POE_REQDET.REQ_QTY"
		new_qty=num(callpoint!.getUserInput())
		new_cost=num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))
	endif
	if callpoint!.getVariableName()="POE_REQDET.UNIT_COST"
		new_qty=num(callpoint!.getColumnData("POE_REQDET.REQ_QTY"))
		new_cost=num(callpoint!.getUserInput())
	endif
	if callpoint!.getVariableName()="POE_REQDET.CONV_FACTOR"
		new_qty=num(callpoint!.getColumnData("POE_REQDET.REQ_QTY"))
		new_cost=unit_cost
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
	new_cost=num(callpoint!.getColumnData("POE_REQDET.UNIT_COST"))
	new_qty=num(callpoint!.getColumnData("POE_REQDET.REQ_QTY"))
	callpoint!.setDevObject("qty_this_row",0)
	callpoint!.setDevObject("cost_this_row",0)
	gosub calculate_header_tots
	callpoint!.setDevObject("qty_this_row",new_cost)
	callpoint!.setDevObject("cost_this_row",new_qty)
endif

return

rem ==========================================================================
calculate_header_tots:
rem ==========================================================================

total_amt=num(callpoint!.getDevObject("total_amt"))
old_price=round(num(callpoint!.getDevObject("qty_this_row"))*num(callpoint!.getDevObject("cost_this_row")),2) 
new_price=round(new_qty*new_cost,2)
new_total=total_amt-old_price+new_price
callpoint!.setDevObject("total_amt",new_total)
tamt!=callpoint!.getDevObject("tamt")
tamt!.setValue(new_total)
callpoint!.setHeaderColumnData("<<DISPLAY>>.ORDER_TOTAL",str(new_total))

rem print "amts:"
rem print "total_amt: ",total_amt
rem print "old_price: ",old_price
rem print "new_price: ",new_price
rem print "new_total: ",new_total

return

rem ==========================================================================
enable_by_line_type:
rem line_type$ : input
rem ==========================================================================

	this_row=callpoint!.getValidationRow()
	if callpoint!.getDevObject("SF_installed")="Y"
		if line_type$="N"
			callpoint!.setColumnEnabled(this_row,"POE_REQDET.WO_NO",1)
			callpoint!.setColumnEnabled(this_row,"POE_REQDET.WK_ORD_SEQ_REF",0)
		else
			whse$=callpoint!.getColumnData("POE_REQDET.WAREHOUSE_ID")
			if callpoint!.getCallpointEvent()="POE_REQDET.ITEM_ID.AVAL"
				item$=callpoint!.getUserInput()
			else
				item$=callpoint!.getColumnData("POE_REQDET.ITEM_ID")
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
				callpoint!.setColumnEnabled(this_row,"POE_REQDET.WO_NO",1)
				callpoint!.setColumnEnabled(this_row,"POE_REQDET.WK_ORD_SEQ_REF",0)
			else
				callpoint!.setColumnEnabled(this_row,"POE_REQDET.WO_NO",0)
				callpoint!.setColumnEnabled(this_row,"POE_REQDET.WK_ORD_SEQ_REF",0)
			endif
		endif
	else
		callpoint!.setColumnEnabled(this_row,"POE_REQDET.WO_NO",0)
		callpoint!.setColumnEnabled(this_row,"POE_REQDET.WK_ORD_SEQ_REF",0)
	endif

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
				wo_location$=sfe_wosub.wo_location$
				wo_no$=sfe_wosub.wo_no$
				wo_line$=sfe_wosub.internal_seq_no$
			break
			case 2;rem Special Order Item
				read record (sfe_womatl,key=wo_key$,knum="PRIMARY") sfe_womatl$
				wo_location$=sfe_womatl.wo_location$
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

	disp_text$=callpoint!.getColumnData("POE_REQDET.MEMO_1024")
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
		memo_len=len(callpoint!.getColumnData("POE_REQDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("POE_REQDET.MEMO_1024",disp_text$,1)
		callpoint!.setColumnData("POE_REQDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE")

	return



