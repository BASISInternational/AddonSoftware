[[OPT_FILLMNTLSDET.AGDS]]
rem --- Can't use qty_shipped and qty_picked from opt_fillmntdet. Must total them up here.
	committedNow! = cast(java.util.HashMap, callpoint!.getDevObject("committed_now"))
	qty_shipped=0
	qty_picked=0
	dim ivmLsMaster$:fnget_tpl$("IVM_LSMASTER")
	lotserNo_size=len(ivmLsMaster.lotser_no$)

	grid! = Form!.getControl(num(stbl("+GRID_CTL")))
	col_hdr$=callpoint!.getTableColumnAttribute("OPT_FILLMNTLSDET.LOTSER_NO","LABS")
	lotserNo_column=util.getGridColumnNumber(grid!,col_hdr$)
	col_hdr$=callpoint!.getTableColumnAttribute("OPT_FILLMNTLSDET.QTY_SHIPPED","LABS")
	qtyShipped_column=util.getGridColumnNumber(grid!,col_hdr$)
	col_hdr$=callpoint!.getTableColumnAttribute("OPT_FILLMNTLSDET.QTY_PICKED","LABS")
	qtyPicked_column=util.getGridColumnNumber(grid!,col_hdr$)
	if grid!.getNumRows()>1 then
		for row=0 to grid!.getNumRows()-2
			qty_shipped=qty_shipped+num(grid!.getCellText(row,qtyShipped_column))

			already_picked=num(grid!.getCellText(row,qtyPicked_column))
			qty_picked=qty_picked+already_picked
			lotser_no$=pad(grid!.getCellText(row,lotserNo_column),lotserNo_size)
			if callpoint!.getColumnData("OPT_FILLMNTLSDET.OE_COMMITTED")="Y" then
				rem --- CommittedNow needs to be qty_shipped if lot/serial number was committed in Order Entry
				committedNow!.put(lotser_no$, num(grid!.getCellText(row,qtyShipped_column)))
			else
				committedNow!.put(lotser_no$, already_picked)
			endif
		next row
	endif

	left_to_ship=num(callpoint!.getDevObject("item_ship_qty"))-qty_shipped
	callpoint!.setDevObject("left_to_ship",left_to_ship)
	left_to_pick=num(callpoint!.getDevObject("item_ship_qty"))-qty_picked
	callpoint!.setDevObject("left_to_pick",left_to_pick)
	callpoint!.setDevObject("committed_now", CommittedNow!)

[[OPT_FILLMNTLSDET.AGRE]]
rem --- Skip if qty_picked not changed
	qty_picked=num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_PICKED"))
	prev_qtyPicked=callpoint!.getDevObject("prev_qtyPicked")
	if qty_picked=prev_qtyPicked then break

rem --- Skip if lot/serial number was committed in Order Entry
	if callpoint!.getColumnData("OPT_FILLMNTLSDET.OE_COMMITTED")="Y" then break

rem --- Check quantities, do commits if this row isn't deleted
	curr_lot$ = callpoint!.getColumnData("OPT_FILLMNTLSDET.LOTSER_NO")
	if callpoint!.getGridRowDeleteStatus(callpoint!.getValidationRow() )<>"Y" and cvs(curr_lot$,2)<>""  then

		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or
:		   callpoint!.getGridRowModifyStatus(callpoint!.getValidationRow())="Y" 
:		then
			lot_qty = qty_picked
			ls_no$=curr_lot$
			gosub check_avail
			if aborted then
				callpoint!.setFocus(callpoint!.getValidationRow(),"OPT_FILLMNTLSDET.QTY_PICKED",1)
				break
			endif
		endif

		rem --- Commit lots if inventoried and not a dropship. (Quotes are already filtered out of Order Fulfillment.)
		if callpoint!.getDevObject("dropship_line")<>"Y" and !callpoint!.getDevObject("non_inventory") then
			rem --- Get current and prior values
			curr_qty=qty_picked
			prior_lot$=callpoint!.getDevObject("prior_lot")
			prior_qty=prev_qtyPicked

			rem --- Has there been any change?
			if curr_lot$<>prior_lot$ or curr_qty<>prior_qty then
				rem --- Initialize inventory item update
				status=999
				call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				if status then exitto std_exit

				rem --- Uncommit prior amount
				if cvs(prior_lot$,3)<>"" and prior_qty then
					commit_lot$=prior_lot$
					commit_qty=prior_qty
					increasing=0
					gosub commit_lots
				endif

				rem --- Commit current amount
				commit_lot$=curr_lot$
				commit_qty=curr_qty 
				increasing=1
				gosub commit_lots
			endif
		endif
	endif

[[OPT_FILLMNTLSDET.AGRN]]
rem --- Disable lotser_no and qty_shipped fields if lot/serial number was committed in Order Entry, or is "All Packed"
	if callpoint!.getColumnData("OPT_FILLMNTLSDET.OE_COMMITTED")="Y" or callpoint!.getDevObject("all_packed")="Y" then
		row=callpoint!.getValidationRow()
		callpoint!.setColumnEnabled(row,"OPT_FILLMNTLSDET.LOTSER_NO",0)
		callpoint!.setColumnEnabled(row,"OPT_FILLMNTLSDET.QTY_SHIPPED",0)
	endif

rem --- Disable qty_picked when "All Packed"
	if callpoint!.getDevObject("all_packed")="Y" then
		row=callpoint!.getValidationRow()
		callpoint!.setColumnEnabled(row,"OPT_FILLMNTLSDET.QTY_PICKED",0)
	endif

rem --- Keep track of starting qty picked for this line, so we can accurately check avail qty minus what's already been committed
	callpoint!.setDevObject("prev_qtyPicked",num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_PICKED")))
	callpoint!.setDevObject("prior_lot",callpoint!.getColumnData("OPT_FILLMNTLSDET.LOTSER_NO"))

[[OPT_FILLMNTLSDET.AOPT-LLOK]]
rem --- See if there are any lots/serials for this item
	wh$=callpoint!.getDevObject("wh")
	item_id$=callpoint!.getDevObject("item_id")
	item_ship_qty=num( callpoint!.getDevObject("item_ship_qty") )
	ivmLsMaster_dev= fnget_dev("IVM_LSMASTER")
	read (ivmLsMaster_dev, key=firm_id$+wh$+item_id$, knum="AO_WH_ITM_FLAG", dom=*next)
	ivmLsMaster_key$=key(ivmLsMaster_dev, end=*next)

	if pos(firm_id$+wh$+item_id$=ivmLsMaster_key$)=1 then
		dim dflt_data$[3,1]
		dflt_data$[1,0] = "ITEM_ID"
		dflt_data$[1,1] = item_id$
		dflt_data$[2,0] = "WAREHOUSE_ID"
		dflt_data$[2,1] = wh$
		dflt_data$[3,0] = "LOTS_TO_DISP"
		if item_ship_qty > 0 then
			dflt_data$[3,1] = "O"; rem --- default to open lots
		else
			dflt_data$[3,1] = "C"; rem --- closed lots for returns 
		endif

		call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:			"IVC_LOTLOOKUP",
:			stbl("+USER_ID"),
:			"",
:			"",
:			table_chans$[all],
:			"",
:			dflt_data$[all]

		callpoint!.setStatus("ACTIVATE")

		rem --- Test lot and available qty
		if callpoint!.getDevObject("selected_lot") <> null() then 
			if callpoint!.getDevObject("lotser_flag") = "S" then
				lot_ser$ = Translate!.getTranslation("AON_SERIAL_NUMBER")
			else
				lot_ser$ = Translate!.getTranslation("AON_LOT")
			endif

			ls_no$=str(callpoint!.getDevObject("selected_lot"))
			committedNow! = cast(java.util.HashMap, callpoint!.getDevObject("committed_now"))
			if committedNow!.containsKey(ls_no$) then
				msg_id$ = "OP_LOT_SELECTED"
				dim msg_tokens$[1]
				msg_tokens$[1] = lot_ser$
				gosub disp_message
				break
			endif
			
			lot_avail = num(callpoint!.getDevObject("selected_lot_avail"))
			if !lot_avail and item_ship_qty > 0 then
				msg_id$ = "OP_LOT_NONE_AVAIL"
				dim msg_tokens$[1]
				msg_tokens$[1] = lot_ser$
				gosub disp_message
				break
			endif

			if lot_avail > 0 and item_ship_qty < 0 and callpoint!.getDevObject("lotser_flag") = "S" then
				msg_id$ = "OP_LOT_RTN_AVAIL";rem --- cannot return serialized item if it is available
				dim msg_tokens$[1]
				msg_tokens$[1] = lot_ser$
				gosub disp_message
				break
			endif

			rem --- Set the detail grid to the data selected in the lookup
			lot_cost = num(callpoint!.getDevObject("selected_lot_cost"))
			ship_qty=min(lot_avail,callpoint!.getDevObject("left_to_ship")) 
			if ship_qty<0 and callpoint!.getDevObject("lotser_flag")="S"  then ship_qty=-1;rem --- can only return -1 at a time when serialized

			callpoint!.setColumnData( "OPT_FILLMNTLSDET.LOTSER_NO", ls_no$,1)
			callpoint!.setColumnData( "OPT_FILLMNTLSDET.QTY_SHIPPED", str(ship_qty),1)
			callpoint!.setDevObject("left_to_ship",abs(callpoint!.getDevObject("left_to_ship") - abs(ship_qty) ) * sgn(ship_qty))

			callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_PICKED", str(ship_qty),1)
			callpoint!.setColumnData("OPT_FILLMNTLSDET.UNIT_COST", str(lot_cost))
			callpoint!.setStatus("MODIFIED")
		endif

	else
		msg_id$="IV_NO_OPENLOTS"
		gosub disp_message
	endif

[[OPT_FILLMNTLSDET.AREC]]
rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPT_FILLMNTLSDET.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPT_FILLMNTLSDET.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPT_FILLMNTLSDET.CREATED_TIME",date(0:"%Hz%mz"))

[[OPT_FILLMNTLSDET.AUDE]]
rem --- Skip if lot/serial number was committed in Order Entry
	if callpoint!.getColumnData("OPT_FILLMNTLSDET.OE_COMMITTED")="Y" then break

rem --- Re-commit lot/serial number if undeleting an existing (not new) row
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
		status=999
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then exitto std_exit

		commit_lot$=callpoint!.getColumnUndoData("OPT_FILLMNTLSDET.LOTSER_NO")
		commit_qty=num(callpoint!.getColumnUndoData("OPT_FILLMNTLSDET.QTY_PICKED"))
		increasing=1
		gosub commit_lots
	endif

[[OPT_FILLMNTLSDET.BDEL]]
rem --- Cannot delete if lot/serial number was committed in Order Entry
	if callpoint!.getColumnData("OPT_FILLMNTLSDET.OE_COMMITTED")="Y" then 
		msg_id$ = "OP_CANNOT_DEL_LS"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- If not a new row, uncommit the lot/serial number
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
		status=999
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then exitto std_exit

		commit_lot$=callpoint!.getColumnUndoData("OPT_FILLMNTLSDET.LOTSER_NO")
		commit_qty=num(callpoint!.getColumnUndoData("OPT_FILLMNTLSDET.QTY_PICKED"))
		increasing=0
		gosub commit_lots
	endif

[[OPT_FILLMNTLSDET.BEND]]
rem --- Get the total quantity picked
	declare BBjVector GridVect!
	qtyPicked=0
	aborted=0

	dim gridrec$:fattr(rec_data$)
	numrecs=GridVect!.size()
	if numrecs>0 then 
		for reccnt=0 to numrecs-1
			gridrec$=str(GridVect!.getItem(reccnt))
			if cvs(gridrec$,3)<>"" and callpoint!.getGridRowDeleteStatus(reccnt)<>"Y" then 
				rem --- Check available
				qty_picked=gridrec.qty_picked
				lot_qty=qty_picked
				ls_no$=gridrec.lotser_no$
				if cvs(ls_no$,2)<>"" then
					gosub check_avail
					if aborted then
						callpoint!.setFocus(reccnt,"OPT_FILLMNTLSDET.QTY_PICKED",1)
						break
					endif
				endif

				rem --- Total lines
				qtyPicked=qtyPicked+gridrec.qty_picked
			endif
		next reccnt
		if aborted then break
	endif

rem --- Warn if quantity picked does not match item's ship quantity
	item_ship_qty=num(callpoint!.getDevObject("item_ship_qty"))
	if qtyPicked<>item_ship_qty then
		msg_id$ = "OP_BAD_PICK_QTY"
		dim msg_tokens$[2]
		msg_tokens$[1] = str(qtyPicked)
		msg_tokens$[2] = str(item_ship_qty)
		gosub disp_message
		if msg_opt$="N"
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Send back total quantity picked
	callpoint!.setDevObject("total_picked",qtyPicked)

[[OPT_FILLMNTLSDET.BSHO]]
rem --- Use util object
	use ::ado_util.src::util

rem --- Set a flag for non-inventoried items
	ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
	dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
	item_id$=callpoint!.getDevObject("item_id")
	findrecord (ivmItemMast_dev,key=firm_id$+item_id$,dom=*next)ivmItemMast$
	if ivmItemMast$.inventoried$<>"Y" or callpoint!.getDevObject("dropship_line")="Y" then
		callpoint!.setDevObject("non_inventory",1)
	else
		callpoint!.setDevObject("non_inventory",0)
	endif

rem --- Create a HashMap so that we know what's been committed during this session
	committedNow! = new java.util.HashMap()
	callpoint!.setDevObject("committed_now", committedNow!)

rem --- No Serial/lot lookup for non-inventory items
	if callpoint!.getDevObject("non_inventory") then
		callpoint!.setOptionEnabled("LLOK", 0)
	else
		callpoint!.setOptionEnabled("LLOK", 1)
	endif

[[OPT_FILLMNTLSDET.BWRI]]
rem --- Initialize RTP modified fields for modified existing records
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
		callpoint!.setColumnData("OPT_FILLMNTLSDET.MOD_USER", sysinfo.user_id$)
		callpoint!.setColumnData("OPT_FILLMNTLSDET.MOD_DATE", date(0:"%Yd%Mz%Dz"))
		callpoint!.setColumnData("OPT_FILLMNTLSDET.MOD_TIME", date(0:"%Hz%mz"))
	endif

[[OPT_FILLMNTLSDET.LOTSER_NO.AVAL]]
rem --- Get lot/serial record fields
	wh$=callpoint!.getDevObject("wh")
	item_id$=callpoint!.getDevObject("item_id")
	item_ship_qty=num( callpoint!.getDevObject("item_ship_qty") )

rem --- Non-inventoried items do not have to exist (but can't be blank)
 	ls_no$=callpoint!.getUserInput()
	if callpoint!.getDevObject("non_inventory") then
		if cvs(ls_no$,2)="" then
			msg_id$ = "IV_SERLOT_BLANK"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		callpoint!.setColumnData("OPT_FILLMNTLSDET.UNIT_COST", str(callpoint!.getDevObject("unit_cost")))
	endif

rem --- Validate open lot number
	ivmLsMaster_dev = fnget_dev("IVM_LSMASTER")
	dim ivmLsMaster$:fnget_tpl$("IVM_LSMASTER")
	if !callpoint!.getDevObject("non_inventory") then
		read record (ivmLsMaster_dev, key=firm_id$+wh$+item_id$+ls_no$, dom=*next) ivmLsMaster$
		if cvs(ivmLsMaster.lotser_no$,2)="" then
			msg_id$ = "IV_LOT_MUST_EXIST"
			gosub disp_message
			callpoint!.setFocus(callpoint!.getValidationRow(),"OPT_FILLMNTLSDET.LOTSER_NO",1)
			break
		endif

		if ivmLsMaster.closed_flag$ = "C" and item_ship_qty > 0 then
			msg_id$ = "IV_SERLOT_CLOSED"
			gosub disp_message
			callpoint!.setFocus(callpoint!.getValidationRow(),"OPT_FILLMNTLSDET.LOTSER_NO",1)
			break
		endif

		if ivmLsMaster.qty_on_hand - ivmLsMaster.qty_commit <= 0 and item_ship_qty > 0 then
			msg_id$="IV_LOT_NO_AVAIL"
			gosub disp_message
			callpoint!.setFocus(callpoint!.getValidationRow(),"OPT_FILLMNTLSDET.LOTSER_NO",1)
			break
		endif

		if callpoint!.getDevObject("lotser_flag")="S" and ivmLsMaster.qty_on_hand > 0 and item_ship_qty < 0 then
			msg_id$="OP_LOT_RTN_AVAIL";rem --- cannot return serialized item that is still on hand
			gosub disp_message
			callpoint!.setFocus(callpoint!.getValidationRow(),"OPT_FILLMNTLSDET.LOTSER_NO",1)
			break
		endif
	endif

rem --- Set defaults
	if num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED")) = 0 then
		left_to_ship=callpoint!.getDevObject("left_to_ship")
		if callpoint!.getDevObject("lotser_flag")="S" then
			if item_ship_qty>0
				callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED","1",1)
				left_to_ship = left_to_ship - 1
			else
				callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED","-1",1)
				left_to_ship = left_to_ship + 1			
			endif
		else
			if callpoint!.getDevObject("non_inventory") then
				ship_qty = left_to_ship
			else
				ship_qty = min(ivmLsMaster.qty_on_hand, left_to_ship)
			endif
			callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED", str(ship_qty),1)
		endif
		callpoint!.setDevObject("left_to_ship",left_to_ship)
	endif

	if num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_PICKED")) = 0 then
		if callpoint!.getDevObject("lotser_flag")="S" then
			if item_ship_qty>0
				callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_PICKED","1",1)
			else
				callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_PICKED","-1",1)
			endif
		else
			callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_PICKED",callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED"),1)
		endif
	endif

	if num(callpoint!.getColumnData("OPT_FILLMNTLSDET.UNIT_COST")) = 0 then
		callpoint!.setColumnData("OPT_FILLMNTLSDET.UNIT_COST", ivmLsMaster.unit_cost$)
	endif

[[OPT_FILLMNTLSDET.QTY_PICKED.AVAL]]
rem --- Skip if qty_picked not changed
	qty_picked=num(callpoint!.getUserInput())
	prev_qtyPicked=num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_PICKED"))
	if qty_picked=prev_qtyPicked then break

rem --- Do not allow returns
	if qty_picked<0 then
		msg_id$ = "OP_INV_FOR_RETURNS"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Warn if quantity picked is more than ship quantity
	ship_qty=num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED"))
	if qty_picked>ship_qty then
		msg_id$="OP_PICK_EXCEEDS_SHIP"
		dim msg_tokens$[2]
		msg_tokens$[1]=str(qty_picked)
		msg_tokens$[2]=str(ship_qty)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setUserInput(str(prev_qtyPicked))
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPT_FILLMNTLSDET.QTY_SHIPPED.AVAL]]
rem --- Skip if qty_shipped not changed
	ship_qty=num(callpoint!.getUserInput())
	prev_shipqty=num(callpoint!.getColumnData("OPT_FILLMNTLSDET.QTY_SHIPPED"))
	if ship_qty = prev_shipqty then break

rem --- Do not allow returns
	if ship_qty<0 then
		msg_id$ = "OP_INV_FOR_RETURNS"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem ---- If serial (as opposed to lots), qty must be 1 or -1
	if callpoint!.getDevObject("lotser_flag")="S" and cvs(callpoint!.getColumnData("OPT_FILLMNTLSDET.LOTSER_NO"),2)<>"" and
:	abs(ship_qty) <> 1 then 
		msg_id$ = "IV_SERIAL_ONE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Check ship quantity against what's available on the Lot
	ivmLsMaster_dev = fnget_dev("IVM_LSMASTER")
	dim ivmLsMaster$:fnget_tpl$("IVM_LSMASTER")
	wh$=callpoint!.getDevObject("wh")
	item_id$=callpoint!.getDevObject("item_id")
 	ls_no$=callpoint!.getColumnData("OPT_FILLMNTLSDET.LOTSER_NO")

	read record (ivmLsMaster_dev, key=firm_id$+wh$+item_id$+ls_no$, dom=*next)ivmLsMaster$
	if cvs(ivmLsMaster.lotser_no$,2)<>"" then
		if ivmLsMaster.qty_on_hand - ivmLsMaster.qty_commit - ship_qty < 0
			dim msg_tokens$[1]
			msg_tokens$[0]=str(ivmLsMaster.qty_on_hand - ivmLsMaster.qty_commit)
			msg_id$="IV_QTY_OVER_AVAIL"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Update qty left to ship
	left_to_ship=callpoint!.getDevObject("left_to_ship")
	left_to_ship = left_to_ship + callpoint!.getDevObject("prev_qtyPicked") - ship_qty 
	callpoint!.setDevObject("left_to_ship",left_to_ship)

rem --- Set default picked qty for new line
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" then
		callpoint!.setColumnData("OPT_FILLMNTLSDET.QTY_PICKED", str(ship_qty),1)
	endif

[[OPT_FILLMNTLSDET.<CUSTOM>]]
rem ==========================================================================
check_avail: rem --- Check for available quantity
		rem      IN: lot_qty
		rem		 ls_no$
		rem   OUT: aborted - true/false
rem ==========================================================================
	aborted = 0
	wh$=callpoint!.getDevObject("wh")
	item_id$=callpoint!.getDevObject("item_id")

	ivmLsMaster_dev = fnget_dev("IVM_LSMASTER")
	dim ivmLsMaster$:fnget_tpl$("IVM_LSMASTER")
	read record (ivmLsMaster_dev, key=firm_id$+wh$+item_id$+ls_no$, dom=*next) ivmLsMaster$
	if cvs(ivmLsMaster.lotser_no$,2)<>"" then
		committedNow! = cast(java.util.HashMap, callpoint!.getDevObject("committed_now"))
		if committedNow!.containsKey(ls_no$) then
			commtd_now = num(committedNow!.get(ls_no$))
		else
			commtd_now = 0
		endif

		if lot_qty >= 0 and lot_qty > ivmLsMaster.qty_on_hand - ivmLsMaster.qty_commit + commtd_now then
			dim msg_tokens$[1]
			msg_tokens$[1] = str(ivmLsMaster.qty_on_hand - ivmLsMaster.qty_commit + commtd_now)
			msg_id$ = "IV_QTY_OVER_AVAIL"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			aborted=1
		endif
	endif

	return

rem ==========================================================================
commit_lots: rem --- Commit lot/serial number only, not the item
		     rem --- NOTE: *** Do Not commit/uncommit if lot/serial number was committed in Order Entry ***
             rem      IN: commit_lot$
             rem           commit_qty
             rem           increasing - 0/1 to back out old/commit new
             rem     OUT: committedNow!
rem ==========================================================================

	items$[1]=callpoint!.getDevObject("wh")
	items$[2]=callpoint!.getDevObject("item_id")
	items$[3]=commit_lot$
	refs[0]=commit_qty
	if increasing then action$="OE" else action$="UC"
	call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
	if status then exitto std_exit
	items$[3]=""
	if increasing then action$="UC" else action$="OE"
	call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
	if status then exitto std_exit

	rem --- Keep track of what's been committed this session
	committedNow! = cast(java.util.HashMap, callpoint!.getDevObject("committed_now"))

	containsKey=committedNow!.containsKey(commit_lot$)
	if containsKey then	
		commtd_now = num(committedNow!.get(commit_lot$))
	else
		commtd_now = 0
	endif

	if increasing then
		commtd_now = commtd_now + commit_qty
	else
		commtd_now = commtd_now - commit_qty
	endif

	if containsKey then
		committedNow!.replace(commit_lot$, commtd_now)
	else
		committedNow!.put(commit_lot$, commtd_now)
	endif
	callpoint!.setDevObject("committed_now", CommittedNow!)

	return



