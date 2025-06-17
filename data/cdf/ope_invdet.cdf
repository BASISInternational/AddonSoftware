[[OPE_INVDET.ADEL]]
print "Det:ADEL"; rem debug

rem --- redisplay totals

	gosub disp_grid_totals

	callpoint!.setDevObject("details_changed","Y")

[[OPE_INVDET.ADGE]]
rem --- Disable header buttons

	callpoint!.setOptionEnabled("CRCH",0)
	callpoint!.setOptionEnabled("COMM",0)
	callpoint!.setOptionEnabled("CRAT",0)
	callpoint!.setOptionEnabled("DINV",0)
	callpoint!.setOptionEnabled("CINV",0)
	callpoint!.setOptionEnabled("UINV",0)
	callpoint!.setOptionEnabled("PRNT",0)
	callpoint!.setOptionEnabled("CASH",0)

[[OPE_INVDET.ADIS]]
rem ---display extended price
	ordqty=num(rec_data.qty_ordered)
	unit_price=num(rec_data.unit_price)
	new_ext_price=ordqty*unit_price
	callpoint!.setColumnData("OPE_INVDET.EXT_PRICE",str(new_ext_price))
	callpoint!.setStatus("MODIFIED-REFRESH")

[[OPE_INVDET.AGCL]]
print "Det:AGCL"; rem debug

rem --- Set detail defaults and disabled columns

	callpoint!.setTableColumnAttribute("OPE_INVDET.LINE_CODE","DFLT", user_tpl.line_code$)
	callpoint!.setTableColumnAttribute("OPE_INVDET.WAREHOUSE_ID","DFLT", user_tpl.warehouse_id$)

	if user_tpl.skip_whse$ = "Y" then
		rem callpoint!.setColumnEnabled(-1, "OPE_INVDET.WAREHOUSE_ID", 0)
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = user_tpl.warehouse_id$
		gosub set_avail	
	endif

rem --- Did we change rows?

	currRow = callpoint!.getValidationRow()

	if currRow <> user_tpl.cur_row
		gosub clear_avail
		user_tpl.cur_row = currRow

		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		gosub set_avail
	endif

rem --- Set column size for memo_1024 field very small so it doesn't take up room, but still available for hover-over of memo contents

	grid! = util.getGrid(Form!)
	col_hdr$=callpoint!.getTableColumnAttribute("OPE_INVDET.MEMO_1024","LABS")
	memo_1024_col=util.getGridColumnNumber(grid!, col_hdr$)
	grid!.setColumnWidth(memo_1024_col,15)

[[OPE_INVDET.AGDR]]
rem --- Disable by line type

	line_code$ = callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
	gosub disable_by_linetype

rem --- Initialize UM_SOLD ListButton except when line type is non-stock
	if user_tpl.line_type$="N" then
		callpoint!.setColumnEnabled(row,"OPE_INVDET.UM_SOLD",1)
	else
		dtlGrid!=util.getGrid(Form!)
		col_hdr$=callpoint!.getTableColumnAttribute("OPE_INVDET.UM_SOLD","LABS")
		col_ref=util.getGridColumnNumber(dtlGrid!, col_hdr$)
		row=callpoint!.getValidationRow()
		nxt_ctlID=util.getNextControlID()
		umList!=Form!.addListButton(nxt_ctlID,10,10,100,100,"",$0810$)
		umList!.addItem("")
		dtlGrid!.setCellListControl(row,col_ref,umList!)
		dtlGrid!.setCellListSelection(row,col_ref,0,0)
		if cvs(callpoint!.getColumnData("OPE_INVDET.UM_SOLD"),2)<>"" then
			ivm01_dev=fnget_dev("IVM_ITEMMAST")
			ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
			dim ivm01a$:ivm01_tpl$
			ivm01a_key$=firm_id$+callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
			find record (ivm01_dev,key=ivm01a_key$,err=*endif)ivm01a$

			rem --- Add IVM_ITEMMAST.UNIT_OF_SALE to the ListButton
			umList!.removeAllItems()
			umList!.addItem(ivm01a.unit_of_sale$)
			if callpoint!.getDevObject("sell_purch_um")="Y" and ivm01a.sell_purch_um$="Y" then
				rem --- Add PURCHASE_UM to the ListButton
				umList!.addItem(ivm01a.purchase_um$)
			endif

		endif
		dtlGrid!.setCellListControl(row,col_ref,umList!)
		if umList!.getItemCount()>1 then
			rem --- Set existing UM_SOLD as the default.
			if callpoint!.getColumnData("OPE_INVDET.UM_SOLD")=umList!.getItemAt(0) then
				dtlGrid!.setCellListSelection(row,col_ref,0,1)
			else
				dtlGrid!.setCellListSelection(row,col_ref,1,1)
			endif
			callpoint!.setColumnEnabled(row,"OPE_INVDET.UM_SOLD",1)
		else
			callpoint!.setColumnData("OPE_INVDET.UM_SOLD",umList!.getItemAt(0),1)
			callpoint!.setColumnEnabled(row,"OPE_INVDET.UM_SOLD",0)
		endif
	endif

[[OPE_INVDET.AGRE]]
rem --- Skip if (not a new row and not row modifed) or row deleted

	this_row = callpoint!.getValidationRow()
	if callpoint!.getGridRowNewStatus(this_row) <> "Y" and callpoint!.getGridRowModifyStatus(this_row) <> "Y" then
		break; rem --- exit callpoint
	endif

	if  callpoint!.getGridRowDeleteStatus(this_row) = "Y"
		break; rem --- exit callpoint
	endif

	user_tpl.detail_modified = 1
	callpoint!.setDevObject("details_changed","Y")
	
rem --- Warehouse and Item must be correct, don't let user leave corrupt row

	wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
	item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	warn  = 1

	gosub check_item_whse	

	if user_tpl.item_wh_failed then 
		callpoint!.setFocus(this_row,"OPE_INVDET.WAREHOUSE_ID",1)
		break; rem --- exit callpoint
	endif

rem --- Initialize/update OPT_INVKITDET Kit Components grid for this detail line's kit
	if callpoint!.getDevObject("kit")<>"N" and num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED"))<>0 then
		rem --- Get current and prior values
		dim kitDetailLine$:fnget_tpl$("OPE_INVDET")
		kitDetailLine$=rec_data$
		kitDetailLine.qty_shipped=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))

		curr_whse$ = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		curr_item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		prior_whse$ = callpoint!.getDevObject("prior_whse")
		prior_item$ = callpoint!.getDevObject("prior_item")
		cust$    = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		ar_type$ = callpoint!.getColumnData("OPE_INVDET.AR_TYPE")
		order$   = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice_no$= callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		seq$     = callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")

		rem --- Get the kit's item descripton
		ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
		dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
		findrecord(ivmItemMast_dev,key=firm_id$+kitDetailLine.item_id$)ivmItemMast$
		callpoint!.setDevObject("kitDesc",ivmItemMast.item_desc$)

		rem --- Displaying a kit' description requires the Inventory item description lengths.
		ivsParams_dev=fnget_dev("IVS_PARAMS")
		dim ivsParams$:fnget_tpl$("IVS_PARAMS")
		findrecord(ivsParams_dev,key=firm_id$+"IV00")ivsParams$
		itemDescLen! = BBjAPI().makeVector()
		itemDescLen!.addItem(num(ivsParams.desc_len_01$))
		itemDescLen!.addItem(num(ivsParams.desc_len_02$))
		itemDescLen!.addItem(num(ivsParams.desc_len_03$))
		callpoint!.setDevObject("itemDescLen",itemDescLen!)

		rem --- Was this kit just added to the order?
		shortage_vect!=BBjAPI().makeVector()
		callpoint!.setDevObject("shortageVect",shortage_vect!)
		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or
:		(curr_whse$<>prior_whse$ or  curr_item$<>prior_item$) then
			rem --- Explode this kit into its components
			bmmBillMat_dev=fnget_dev("BMM_BILLMAT")
			dim bmmBillMat$:fnget_tpl$("BMM_BILLMAT")
			ivm01_dev=fnget_dev("IVM_ITEMMAST")
			dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
			ivm02_dev=fnget_dev("IVM_ITEMWHSE")
			dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")
			optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
			dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")

			kit_item$=kitDetailLine.item_id$
			kit_ordered=kitDetailLine.qty_ordered
			kit_shipped=kitDetailLine.qty_shipped
			nextLineNo=1
			call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","U","",qty_mask$,0,qty_mask
			call stbl("+DIR_PGM")+"adc_getmask.aon","","IV","I","",ivIMask$,0,0
			lineMask$=pad("",len(callpoint!.getColumnData("OPE_INVDET.LINE_NO")),"0")

			gosub explodeKit
		endif

		rem --- Was the order for this kit changed?
		shortage_vect!=BBjAPI().makeVector()
		callpoint!.setDevObject("shortageVect",shortage_vect!)
		skippedComponents_vect!=BBjAPI().makeVector()
		callpoint!.setDevObject("skippedComponentsVect",skippedComponents_vect!)
		if (curr_whse$=prior_whse$ or curr_item$=prior_item$) and
:		callpoint!.getGridRowModifyStatus(callpoint!.getValidationRow())="Y" and 
:		callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
			round_precision = num(callpoint!.getDevObject("precision"))

			rem --- Update this kit's components for the changes made to the order
			kit_ordered=kitDetailLine.qty_ordered
			kit_shipped=kitDetailLine.qty_shipped
			kit_commit$=kitDetailLine.commit_flag$
			kit_prior_qty=callpoint!.getDevObject("prior_qty")

			optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
			dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
			trip_key$=firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$
			read(optInvKitDet_dev,key=trip_key$,knum="AO_STAT_CUST_ORD",dom=*next)
			while 1
				thisKey$=key(optInvKitDet_dev,end=*break)
				if pos(trip_key$=thisKey$)<>1 then break
				extractrecord(optInvKitDet_dev)optInvKitDet$
				comp_per_kit=optInvKitDet.comp_per_kit
				if comp_per_kit=0 then
					rem --- Custom component
					adjusted_kit_ordered=optInvKitDet.qty_ordered

					rem --- Warn custom component quantities not updated
					skipped_vect!=BBjAPI().makeVector()
					skipped_vect!.addItem(optInvKitDet.item_id$)
					skipped_vect!.addItem(optInvKitDet.qty_ordered)
					skipped_vect!.addItem(optInvKitDet.qty_shipped)
					skippedComponents_vect!.addItem(skipped_vect!)
					callpoint!.setDevObject("skippedComponentsVect",skippedComponents_vect!)
				else
					rem --- Standard component
					adjusted_kit_ordered=round(kit_ordered*comp_per_kit,round_precision)
				endif

				rem --- If the modified kit record is committed and the existing component record is committed, then …
				if kit_commit$="Y" and optInvKitDet.commit_flag$="Y" then
					rem --- If adjusted kit_ordered>optInvKitDet.qty_ordered then ...
					if adjusted_kit_ordered>optInvKitDet.qty_ordered then
						rem --- Commit adjusted kit_ordered-optInvKitDet.qty_ordered
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

						items$[1]=optInvKitDet.warehouse_id$
						items$[2]=optInvKitDet.item_id$
						refs[0]=adjusted_kit_ordered-optInvKitDet.qty_ordered
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","CO",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					endif

					rem --- If adjusted kit_ordered<optInvKitDet.qty_ordered then ...
					if adjusted_kit_ordered<optInvKitDet.qty_ordered then
						rem --- Uncommit optInvKitDet.qty_ordered-adjusted kit_ordered
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

						items$[1]=optInvKitDet.warehouse_id$
						items$[2]=optInvKitDet.item_id$
						refs[0]=optInvKitDet.qty_ordered-adjusted_kit_ordered
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					endif
				endif

				rem --- If the modified kit record is committed and the existing component record is NOT committed, then ...
				if kit_commit$="Y" and optInvKitDet.commit_flag$<>"Y" then
					rem --- Commit the adjusted kit_ordered
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

					items$[1]=optInvKitDet.warehouse_id$
					items$[2]=optInvKitDet.item_id$
					refs[0]=adjusted_kit_ordered
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon","CO",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				endif

				rem --- If the modified kit record is NOT committed and the existing component record is committed, then ...
				if kit_commit$<>"Y" and optInvKitDet.commit_flag$="Y" then
					rem --- Uncommit optInvKitDet.qty_ordered
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

					items$[1]=optInvKitDet.warehouse_id$
					items$[2]=optInvKitDet.item_id$
					refs[0]=optInvKitDet.qty_ordered
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				endif

				rem --- If the modified kit record is NOT committed and the existing component record is NOT committed, then ... 
				if kit_commit$<>"Y" and optInvKitDet.commit_flag$<>"Y" then
					rem --- Do NOT commit/uncommit inventory
				endif

				rem --- Update this kit component record
				optInvKitDet.commit_flag$=kit_commit$
				prior_qty_ordered=optInvKitDet.qty_ordered
				prior_qty_shipped=optInvKitDet.qty_shipped
				if comp_per_kit<>0 then
					rem --- Kit standard component
					optInvKitDet.qty_ordered=round(kit_ordered*comp_per_kit,round_precision)
					if kit_commit$="Y" then
						optInvKitDet.qty_shipped=round(kit_shipped*comp_per_kit,round_precision)
					else
						optInvKitDet.qty_shipped=0
					endif
				else
					rem --- Kit custom component
					rem --- Do NOT change quantities for custom components
				endif
				optInvKitDet.qty_backord=optInvKitDet.qty_ordered-optInvKitDet.qty_shipped

				if callpoint!.getDevObject("priced_kit")="N" then
					rem --- Update unit_price and disc_percent if qty_ordered changed for non-priced kit
					prior_unit_price=optInvKitDet.unit_price
					if prior_qty_ordered<>optInvKitDet.qty_ordered then
						dim pc_files[6]
						pc_files[1] = fnget_dev("IVM_ITEMMAST")
						pc_files[2] = fnget_dev("IVM_ITEMWHSE")
						pc_files[3] = fnget_dev("IVM_ITEMPRIC")
						pc_files[4] = fnget_dev("IVC_PRICCODE")
						pc_files[5] = fnget_dev("ARS_PARAMS")
						pc_files[6] = fnget_dev("IVS_PARAMS")
						call stbl("+DIR_PGM")+"opc_pricing.aon",
:							pc_files[all],
:							firm_id$,
:							optInvKitDet.warehouse_id$,
:							optInvKitDet.item_id$,
:							str(callpoint!.getDevObject("priceCode")),
:							optInvKitDet.customer_id$,
:							str(callpoint!.getDevObject("orderDate")),
:							str(callpoint!.getDevObject("pricingCode")),
:							optInvKitDet.qty_ordered,
:							typeflag$,
:							price,
:							disc,
:							status
						if status=999 then
							typeflag$="N"
							price=0
							disc=0
						endif
						optInvKitDet.unit_price=price
						optInvKitDet.disc_percent=disc
					endif

					rem --- Update ext_price and taxable_amt if unit_price or qty_shipped changed for non-priced kit
					if prior_unit_price<>optInvKitDet.unit_price or prior_qty_shipped<>optInvKitDet.qty_shipped or
:					optInvKitDet.commit_flag$<>kit_commit$ then
						optInvKitDet.ext_price=round(optInvKitDet.qty_shipped * optInvKitDet.unit_price, 2)

						redim ivmItemMast$
						readrecord(ivmItemMast_dev,key=firm_id$+optInvKitDet.item_id$,dom=*next)ivmItemMast$
						if (user_tpl.line_taxable$="Y" and ivmItemMast.taxable_flag$="Y") or callpoint!.getDevObject("use_tax_service")="Y" then 
							optInvKitDet.taxable_amt=optInvKitDet.ext_price
						else
							optInvKitDet.taxable_amt=0
						endif
					endif
				endif

				writerecord(optInvKitDet_dev)optInvKitDet$

				rem --- Warn if ship quantity is more than currently available.
				ivm02_dev=fnget_dev("IVM_ITEMWHSE")
				dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")
				readrecord(ivm02_dev,key=firm_id$+optInvKitDet.warehouse_id$+optInvKitDet.item_id$,dom=*next)ivm02a$
				shipqty=optInvKitDet.qty_shipped
				available=ivm02a.qty_on_hand-(ivm02a.qty_commit-shipqty); rem --- Note: ivm_itemwhse record read AFTER this component was committed
				if shipqty>available then
					available_vect!=BBjAPI().makeVector()
					available_vect!.addItem(optInvKitDet.item_id$)
					available_vect!.addItem(shipqty)
					available_vect!.addItem(available)
					shortage_vect!.addItem(available_vect!)
				endif
				callpoint!.setDevObject("shortageVect",shortage_vect!)
			wend

			rem --- For non-priced Kits, make updates for changes made to the Kit in case it has custom components
			if callpoint!.getDevObject("priced_kit")="N" then
				rem --- Update kit's detail row and Totals tab
				key_pfx$ = firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$
				gosub updateKitTotals

				rem --- Set header REPRINT_FLAG
				if pos(callpoint!.getColumnData("OPE_INVDET.PICK_FLAG")="YM") then
					callpoint!.setHeaderColumnData("OPE_INVHDR.REPRINT_FLAG","Y")
				endif
			endif
		endif

		rem --- Auto launch Kit Components grid if allowed and NOT following Kit Components button
		ars01_dev = fnget_dev("ARS_PARAMS")
		dim ars01a$:fnget_tpl$("ARS_PARAMS")
		read record (ars01_dev, key=firm_id$+"AR00") ars01a$
		if ars01a.launch_kit_grid$="Y" and callpoint!.getDevObject("kit_details_changed")<>"Y" then
			rem --- Hold on to this detail record for use in OPT_INVKITDET grid
			callpoint!.setDevObject("kitDetailLine",rec_data$)
			callpoint!.setDevObject("orderDate",user_tpl.order_date$)
			callpoint!.setDevObject("priceCode",user_tpl.price_code$)
			callpoint!.setDevObject("pricingCode",user_tpl.pricing_code$)
			callpoint!.setDevObject("lineCodeTaxable",user_tpl.line_taxable$)
			callpoint!.setDevObject("allowBO",user_tpl.allow_bo$)
			callpoint!.setDevObject("cashSale",callpoint!.getHeaderColumnData("OPE_INVHDR.CASH_SALE"))
			callpoint!.setDevObject("invoice_type",  callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE"))
			callpoint!.setDevObject("print_status",callpoint!.getHeaderColumnData("OPE_INVHDR.PRINT_STATUS")) 
			callpoint!.setDevObject("reprint_flag",callpoint!.getHeaderColumnData("OPE_INVHDR.REPRINT_FLAG"))
	
			key_pfx$ = firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$

			dim dflt_data$[6,1]
			dflt_data$[1,0] = "TRANS_STATUS"
			dflt_data$[1,1] = "E"
			dflt_data$[2,0] = "AR_TYPE"
			dflt_data$[2,1] = ar_type$
			dflt_data$[3,0] = "CUSTOMER_ID"
			dflt_data$[3,1] = cust$
			dflt_data$[4,0] = "ORDER_NO"
			dflt_data$[4,1] = order$
			dflt_data$[5,0] = "AR_INV_NO"
			dflt_data$[5,1] = invoice_no$
			dflt_data$[6,0] = "ORDDET_SEQ_REF"
			dflt_data$[6,1] = seq$

			call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:				"OPT_INVKITDET", 
:				stbl("+USER_ID"), 
:				"MNT", 
:				key_pfx$, 
:				table_chans$[all], 
:				"",
:				dflt_data$[all]

			rem --- For non-priced Kits, make updates for changes made in the Kit Components grid
			if callpoint!.getDevObject("kit_details_changed")="Y" and callpoint!.getDevObject("priced_kit")="N" then
				rem --- Update kit's detail row and Totals tab
				gosub updateKitTotals

				rem --- Set header REPRINT_FLAG
				if pos(callpoint!.getColumnData("OPE_INVDET.PICK_FLAG")="YM") then
					callpoint!.setHeaderColumnData("OPE_INVHDR.REPRINT_FLAG","Y")
				endif
			endif
		else
			rem --- Report shortages if any
			gosub reportShortages		
		endif

		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Returns

	if num( callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP") ) < 0 then
		callpoint!.setColumnData( "<<DISPLAY>>.QTY_SHIPPED_DSP", callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP") )
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0")
	endif

rem --- Verify Qty Ordered is not 0

	if pos(user_tpl.line_type$="SNP") then
		if num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")) = 0
			msg_id$="OP_QTY_ZERO"
			gosub disp_message
			callpoint!.setFocus(this_row,"<<DISPLAY>>.QTY_ORDERED_DSP",1)
			break; rem --- exit callpoint
		endif
	endif

rem --- What is extended price?

	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))

	if pos(user_tpl.line_type$="SNP") then
		ext_price = round( num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP")) * unit_price, 2)
	else
		ext_price = round( num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE")), 2)
	endif

rem --- Check for minimum line extension

	commit_flag$    = callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")
	qty_backordered = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))

	if user_tpl.line_type$ <> "M" and 
:		qty_backorderd = 0         and 
:		commit_flag$ = "Y"         and
:		abs(ext_price) < user_tpl.min_line_amt 
:	then
		msg_id$ = "OP_LINE_UNDER_MIN"
		dim msg_tokens$[1]
		msg_tokens$[1] = str(user_tpl.min_line_amt:user_tpl.amount_mask$)
		gosub disp_message
	endif

rem --- Set taxable amount

	if (user_tpl.line_taxable$ = "Y" and ( pos(user_tpl.line_type$ = "OMN") or user_tpl.item_taxable$ = "Y" )) or
: 	callpoint!.getDevObject("use_tax_service")="Y" then 
		callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", str(ext_price))
	endif

rem --- Set price and discount

	std_price  = num(callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC"))
	disc_per   = num(callpoint!.getColumnData("OPE_INVDET.DISC_PERCENT"))
	
	if std_price then
		callpoint!.setColumnData("OPE_INVDET.DISC_PERCENT", str(round(100 - unit_price * 100 / std_price, 2)) )
	else
		if disc_per <> 100 then
			round_precision = num(callpoint!.getDevObject("precision"))
			callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", str(round(unit_price * 100 / (100 - disc_per), round_precision)) )
		endif
	endif
	
rem --- For uncommitted "O" line type sales (not quotes), move ext_price to unit_price until committed

	if callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE") <> "P" and
:		callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "N"         and
:		user_tpl.line_type$ = "O"                                        and
:		ext_price <> 0
:	then
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", str(round(ext_price, round_precision)) )
		callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", "0")
		callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", "0")
	endif

rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	gosub update_record_fields

rem --- Set header order totals

	gosub disp_grid_totals

rem --- Has customer credit been exceeded?

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	creditRemaining = ordHelp!.getCreditLimit()-ordHelp!.getTotalAging()-ordHelp!.getOpenOrderAmount()-ordHelp!.getOpenBoAmount()-ordHelp!.getHeldOrderAmount()
	if num(callpoint!.getHeaderColumnData("<<DISPLAY>>.NET_SALES")) > creditRemaining then 
		gosub credit_exceeded
	endif

	callpoint!.setStatus("MODIFIED;REFRESH")

[[OPE_INVDET.AGRN]]
rem --- See if we're coming back from Recalc button

	if callpoint!.getDevObject("rcpr_row") <> ""
		callpoint!.setFocus(num(callpoint!.getDevObject("rcpr_row")),"<<DISPLAY>>.UNIT_PRICE_DSP")
		callpoint!.setDevObject("rcpr_row","")
		callpoint!.setDevObject("details_changed","Y")
		break
	endif

rem (Fires regardles of new or existing row.  Use callpoint!.getGridRowNewStatus(callpoint!.getValidationRow()) to distinguish the two)

rem --- Initialize "kit" DevObject
	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
	dim ivm01a$:ivm01_tpl$
	item$=callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	ivm01a_key$=firm_id$+item$
	find record (ivm01_dev,key=ivm01a_key$,err=*next)ivm01a$
	if pos(ivm01a.kit$="YP")=0 then
		rem --- Regular non-kit item
		callpoint!.setDevObject("kit","N")
		callpoint!.setDevObject("priced_kit","N")
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 1)
		callpoint!.setOptionEnabled("RCPR",1)

	else
		if ivm01a.kit$="Y" then
			rem --- Non-priced kit
			callpoint!.setDevObject("kit","Y")
			callpoint!.setDevObject("priced_kit","N")
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 0)
			callpoint!.setOptionEnabled("RCPR",0)
		endif
		if ivm01a.kit$="P" then
			rem --- Priced kit
			callpoint!.setDevObject("kit","Y")
			callpoint!.setDevObject("priced_kit","Y")
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 1)
			callpoint!.setOptionEnabled("RCPR",1)
		endif
	endif
	callpoint!.setDevObject("kit_component","N")

rem --- Disable by line type (Needed because Barista is skipping Line Code)

	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow())) <> "Y"
		line_code$ = callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
		gosub disable_by_linetype
	else
		gosub able_backorder
		gosub able_qtyshipped
	endif

rem --- Disable cost if necessary

	if pos(user_tpl.line_type$="SP") and num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP")) then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)
	endif

rem --- Set item tax flag

	gosub set_item_taxable

rem --- Set item price if item and whse exist

	item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")

	if item$<>"" and wh$<>"" then
		file$ = "IVM_ITEMWHSE"
		dim itemwhse$:fnget_tpl$(file$)
		start_block = 1
		
		if start_block then
			find record (fnget_dev(file$), key=firm_id$+wh$+item$, dom=*endif) itemwhse$
			user_tpl.item_price = itemwhse.cur_price
		endif
	endif

rem --- Set previous values

	round_precision = num(callpoint!.getDevObject("precision"))
	user_tpl.prev_ext_price  = num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE"))
	user_tpl.prev_ext_cost   = round(num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP")) * num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")),round_precision)
	user_tpl.prev_line_code$ = callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
	user_tpl.prev_item$      = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	user_tpl.prev_qty_ord    = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	user_tpl.prev_boqty      = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
	user_tpl.prev_shipqty    = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	user_tpl.prev_unitprice  = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	callpoint!.setDevObject("prior_whse",callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID"))
	callpoint!.setDevObject("prior_item",callpoint!.getColumnData("OPE_INVDET.ITEM_ID"))
	callpoint!.setDevObject("prior_qty",user_tpl.prev_qty_ord*num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR")))
	callpoint!.setDevObject("prior_commit",callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG"))

	callpoint!.setDevObject("whse_item_warned","")

rem --- Set buttons

	rem if !user_tpl.new_detail then...

	gosub able_lot_button
	gosub able_kits_button

	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow()) = "" then
		gosub enable_repricing
		gosub enable_addl_opts
	endif

	if cvs(callpoint!.getColumnData("OPE_INVDET.ITEM_ID"),2)<>"" then
		callpoint!.setOptionEnabled("WHSE",1)
	else
		callpoint!.setOptionEnabled("WHSE",0)
	endif

rem --- Set availability info

	gosub set_avail

rem --- May want to skip line code entry, and/or warehouse code entry, the first time.
	callpoint!.setDevObject("skipLineCode",user_tpl.skip_ln_code$)
	callpoint!.setDevObject("skipWHCode",user_tpl.skip_whse$)

rem --- Initialize Kit Component grid's kit_detail_changed flag
	callpoint!.setDevObject("kit_details_changed","N")

[[OPE_INVDET.AOPT-ADDL]]
rem --- Additional Options

	if user_tpl.line_type$ = "M" then break; rem --- exit callpoint

rem --- Save current context so we'll know where to return

	declare BBjStandardGrid grid!
	grid! = util.getGrid(Form!)
	grid_ctx=grid!.getContextID()

rem --- Setup a templated string to pass information back and forth from form

	declare BBjTemplatedString a!

	tmpl$ =  "LINE_TYPE:C(1)," +
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

	dim dflt_data$[7,1]
	dflt_data$[1,0] = "STD_LIST_PRC"
	dflt_data$[1,1] = callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC")
	dflt_data$[2,0] = "DISC_PERCENT"
	dflt_data$[2,1] = callpoint!.getColumnData("OPE_INVDET.DISC_PERCENT")
	dflt_data$[3,0] = "NET_PRICE"
	dflt_data$[3,1] = callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")
	dflt_data$[4,0] = "EST_SHP_DATE"
	dflt_data$[4,1] = callpoint!.getColumnData("OPE_INVDET.EST_SHP_DATE")
	dflt_data$[5,0] = "COMMIT_FLAG"
	dflt_data$[5,1] = callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")
	dflt_data$[6,0] = "MAN_PRICE"
	dflt_data$[6,1] = callpoint!.getColumnData("OPE_INVDET.MAN_PRICE")
	dflt_data$[7,0] = "PRINTED"
	dflt_data$[7,1] = callpoint!.getColumnData("OPE_INVDET.PICK_FLAG")
	
	a!.setFieldValue("LINE_TYPE",    user_tpl.line_type$)
	a!.setFieldValue("INVOICE_TYPE", callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE"))
	a!.setFieldValue("STD_LIST_PRC", callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC"))
	a!.setFieldValue("DISC_PERCENT", callpoint!.getColumnData("OPE_INVDET.DISC_PERCENT"))
	a!.setFieldValue("UNIT_PRICE",   callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	a!.setFieldValue("EST_SHP_DATE", callpoint!.getColumnData("OPE_INVDET.EST_SHP_DATE"))
	a!.setFieldValue("COMMIT_FLAG",  callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG"))
	a!.setFieldValue("MAN_PRICE",    callpoint!.getColumnData("OPE_INVDET.MAN_PRICE"))
	a!.setFieldValue("PRINT_FLAG",   callpoint!.getColumnData("OPE_INVDET.PICK_FLAG"))
	a!.setFieldValue("isEditMode",   callpoint!.isEditMode())
	a!.setFieldValue("INTERNAL_SEQ_NO",   callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO"))

	callpoint!.setDevObject("additional_options", a!)

	orig_commit$ = callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")

rem --- Call form

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPE_ADDL_OPTS", 
:		stbl("+USER_ID"), 
:		"MNT", 
:		"", 
:		table_chans$[all], 
:		"",
:		dflt_data$[all]

rem --- Write back here

	a! = cast(BBjTemplatedString, callpoint!.getDevObject("additional_options"))
	callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", a!.getFieldAsString("STD_LIST_PRC"))
	callpoint!.setColumnData("OPE_INVDET.DISC_PERCENT", a!.getFieldAsString("DISC_PERCENT"))
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",   a!.getFieldAsString("UNIT_PRICE"))
	callpoint!.setColumnData("OPE_INVDET.EST_SHP_DATE", a!.getFieldAsString("EST_SHP_DATE"))
	callpoint!.setColumnData("OPE_INVDET.COMMIT_FLAG",  a!.getFieldAsString("COMMIT_FLAG"))
	callpoint!.setColumnData("OPE_INVDET.MAN_PRICE",    a!.getFieldAsString("MAN_PRICE"))
	callpoint!.setColumnData("OPE_INVDET.PICK_FLAG",    a!.getFieldAsString("PRINT_FLAG"))

rem --- Need to commit?

	committed_changed=0
	if callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE") <> "P" then
		if orig_commit$ = "Y" and callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "N" then
			committed_changed=1
			if user_tpl.line_type$ <> "O" then
				callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0")
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", "0")
				callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", "0")
				callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", "0")
			else
				callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", str(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE")))
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", "0")
				callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", "0")
				callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", "0")
			endif
		endif

		if orig_commit$ = "N" and callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "Y" then
			committed_changed=1
			callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")))
			if (user_tpl.line_taxable$ = "Y" and ( pos(user_tpl.line_type$ = "OMN") or user_tpl.item_taxable$ = "Y" )) or
: 			callpoint!.getDevObject("use_tax_service")="Y" then 
				callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", str(ext_price))
			endif
			rem --- Warn if ship quantity is more than currently available.
			gosub check_ship_qty

			if user_tpl.line_type$ = "O" and 
:				num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE")) = 0 and 
:				num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")) 
:			then
				callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", str(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")))
				callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", "0")
				callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", "0")
			endif
		endif
	endif

	rem --- Grid vector must be updated before updating Totals tab
	declare BBjVector dtlVect!
	dtlVect!=cast(BBjVector, GridVect!.getItem(0))
	dim dtl_rec$:dtlg_param$[1,3]
	dtl_rec$=cast(BBjString, dtlVect!.getItem(callpoint!.getValidationRow()))
	dtl_rec.commit_flag$=callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")
	dtl_rec.est_shp_date$=callpoint!.getColumnData("OPE_INVDET.EST_SHP_DATE")
	dtl_rec.std_list_prc=num(callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC"))
	dtl_rec.disc_percent=num(callpoint!.getColumnData("OPE_INVDET.DISC_PERCENT"))
	dtl_rec.unit_price=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	dtl_rec.qty_backord=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
	dtl_rec.qty_shipped=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	dtl_rec.ext_price=num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE"))
	dtl_rec.taxable_amt=num(callpoint!.getColumnData("OPE_INVDET.TAXABLE_AMT"))
	dtlVect!.setItem(callpoint!.getValidationRow(),dtl_rec$)
	GridVect!.setItem(0,dtlVect!)

	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	unit_price  = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	gosub disp_ext_amt

	gosub able_lot_button
	gosub able_backorder
	gosub able_qtyshipped

	callpoint!.setStatus("REFRESH")

rem --- Return focus to where we were (Detail line grid)

	sysgui!.setContext(grid_ctx)

[[OPE_INVDET.AOPT-COMM]]
rem --- invoke the comments dialog

	gosub comment_entry

[[OPE_INVDET.AOPT-KITS]]
rem --- Save current context so we'll know where to return from Git Components grid
	declare BBjStandardGrid grid!
	grid! = util.getGrid(Form!)
	grid_ctx=grid!.getContextID()

rem --- Launch OPT_INVKITDET Kit Components grid for this detail line's kit
	rem --- Hold on to this detail record for use in OPT_INVKITDET grid
	callpoint!.setDevObject("kitDetailLine",rec_data$)
	callpoint!.setDevObject("orderDate",user_tpl.order_date$)
	callpoint!.setDevObject("priceCode",user_tpl.price_code$)
	callpoint!.setDevObject("pricingCode",user_tpl.pricing_code$)
	callpoint!.setDevObject("lineCodeTaxable",user_tpl.line_taxable$)
	callpoint!.setDevObject("allowBO",user_tpl.allow_bo$)
	callpoint!.setDevObject("cashSale",callpoint!.getHeaderColumnData("OPE_INVHDR.CASH_SALE"))
	callpoint!.setDevObject("invoice_type",  callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE"))
	callpoint!.setDevObject("print_status",callpoint!.getHeaderColumnData("OPE_INVHDR.PRINT_STATUS")) 
	callpoint!.setDevObject("reprint_flag",callpoint!.getHeaderColumnData("OPE_INVHDR.REPRINT_FLAG"))
	shortage_vect!=BBjAPI().makeVector()
	callpoint!.setDevObject("shortageVect",shortage_vect!)
	skippedComponents_vect!=BBjAPI().makeVector()
	callpoint!.setDevObject("skippedComponentsVect",skippedComponents_vect!)

	ar_type$ = callpoint!.getColumnData("OPE_INVDET.AR_TYPE")
	cust$ = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
	order$ = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
	invoice_no$ = callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
	seq$ = callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
	key_pfx$ = firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$

	dim dflt_data$[6,1]
	dflt_data$[1,0] = "TRANS_STATUS"
	dflt_data$[1,1] = "E"
	dflt_data$[2,0] = "AR_TYPE"
	dflt_data$[2,1] = ar_type$
	dflt_data$[3,0] = "CUSTOMER_ID"
	dflt_data$[3,1] = cust$
	dflt_data$[4,0] = "ORDER_NO"
	dflt_data$[4,1] = order$
	dflt_data$[5,0] = "AR_INV_NO"
	dflt_data$[5,1] = invoice_no$
	dflt_data$[6,0] = "ORDDET_SEQ_REF"
	dflt_data$[6,1] = seq$

	call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:		"OPT_INVKITDET", 
:		stbl("+USER_ID"), 
:		"MNT", 
:		key_pfx$, 
:		table_chans$[all], 
:		"",
:		dflt_data$[all]

rem --- For non-priced Kits, make updates for changes made in the Kit Components grid
	if callpoint!.getDevObject("kit_details_changed")="Y" and callpoint!.getDevObject("priced_kit")="N" then
		rem --- Update kit's detail row and Totals tab
		gosub updateKitTotals

		rem --- Set header REPRINT_FLAG
		if pos(callpoint!.getColumnData("OPE_INVDET.PICK_FLAG")="YM") then
			callpoint!.setHeaderColumnData("OPE_INVHDR.REPRINT_FLAG","Y")
		endif
	endif

rem --- Return focus to where we were in Detail Line grid
	sysgui!.setContext(grid_ctx)
	callpoint!.setStatus("ACTIVATE")

[[OPE_INVDET.AOPT-LENT]]
rem --- Save current context so we'll know where to return from lot lookup

	declare BBjStandardGrid grid!
	grid! = util.getGrid(Form!)
	grid_ctx=grid!.getContextID()

rem --- Go get Lot Numbers

	item_id$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	gosub lot_ser_check

rem --- Is this item lot/serial?

	if lotted$ = "Y" then
		ar_type$ = callpoint!.getColumnData("OPE_INVDET.AR_TYPE")
		cust$    = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order$   = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice$=callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		int_seq$ = callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")

		if cvs(cust$,2) <> ""

		rem --- Run the Lot/Serial# detail entry form
		rem      IN: call/enter list
		rem          the DevObjects set below

			callpoint!.setDevObject("from",          "invoice_entry")
			callpoint!.setDevObject("wh",            callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID"))
			callpoint!.setDevObject("item",          callpoint!.getColumnData("OPE_INVDET.ITEM_ID"))
			callpoint!.setDevObject("ord_qty",       callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
			callpoint!.setDevObject("dropship_line", user_tpl.line_dropship$)
			callpoint!.setDevObject("invoice_type",  callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE"))
			callpoint!.setDevObject("unit_cost",       callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP"))
			callpoint!.setDevObject("isEditMode_SerialEntry", callpoint!.isEditMode())

			grid!.focus()

			dim dflt_data$[6,1]
			dflt_data$[1,0] = "AR_TYPE"
			dflt_data$[1,1] = ar_type$
			dflt_data$[2,0] = "TRANS_STATUS"
			dflt_data$[2,1] = "E"
			dflt_data$[3,0] = "CUSTOMER_ID"
			dflt_data$[3,1] = cust$
			dflt_data$[4,0] = "ORDER_NO"
			dflt_data$[4,1] = order$
			dflt_data$[5,0] = "AR_INV_NO"
			dflt_data$[5,1] = invoice$
			dflt_data$[6,0] = "ORDDET_SEQ_REF"
			dflt_data$[6,1] = int_seq$
			lot_pfx$ = firm_id$+"E"+ar_type$+cust$+order$+invoice$+int_seq$

			if callpoint!.isEditMode() then
				proc_mode$="MNT"
			else
				proc_mode$="MNT-LCK"
			endif

			do_opeOrdlsdet=1
			while do_opeOrdlsdet
				do_opeOrdlsdet=0
				call stbl("+DIR_SYP") + "bam_run_prog.bbj", 
:					"OPE_ORDLSDET", 
:					stbl("+USER_ID"), 
:					proc_mode$, 
:					lot_pfx$, 
:					table_chans$[all], 
:					dflt_data$[all]

				rem --- Updated backordered and extension if qty shipped changed
				qty_shipped = num(callpoint!.getDevObject("total_shipped"))
				prev_ship_qty=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
				if qty_shipped<>prev_ship_qty then
					rem --- Warn if ship quantity is more than order quantity
					ordqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
					if qty_shipped > ordqty then
						msg_id$="SHIP_EXCEEDS_ORD"
						dim msg_tokens$[1]
						if ordqty=0 then
							msg_tokens$[1] = "???"
						else
							msg_tokens$[1] = str(round(100*(ordqty-qty_shipped)/ordqty,1):"###0.0 ")
						endif
						gosub disp_message
						if msg_opt$="C" then
							rem --- Back to OPE_ORDLSDET form so user can correct the ship quantity
							do_opeOrdlsdet=1
						endif
					endif
				endif
			wend


			if qty_shipped<>prev_ship_qty then
				unit_price  = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_shipped),1)
				callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", str(round(qty_shipped * unit_price, 2)),1)
				rem --- Warn if ship quantity is more than currently available.
				gosub check_ship_qty

				rem --- Re-calculate qty_backord unless already shipping extra or it's a new line.
				qty_ordered = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
				qty_backord = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
				if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or prev_ship_qty<=qty_ordered - boqty then
					if qty_ordered > 0 then
						qty_backord=max(qty_ordered - qty_shipped, 0)
					else
						qty_backord=min(qty_ordered - qty_shipped, 0)
					endif
					callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", str(qty_backord),1)
				endif

				rem --- Grid vector must be updated before updating the discount amount
				declare BBjVector dtlVect!
				dtlVect!=cast(BBjVector, GridVect!.getItem(0))
				dim dtl_rec$:dtlg_param$[1,3]
				dtl_rec$=cast(BBjString, dtlVect!.getItem(callpoint!.getValidationRow()))
				if dtl_rec.qty_shipped=qty_shipped
					qty_shipped_changed=0
				else
					dtl_rec.qty_shipped=qty_shipped
					dtl_rec.qty_backord=qty_backord
					dtl_rec.ext_price=round(qty_shipped * unit_price, 2)
					qty_shipped_changed=1
					dtlVect!.setItem(callpoint!.getValidationRow(),dtl_rec$)
					GridVect!.setItem(0,dtlVect!)
				endif

				gosub disp_ext_amt
			endif

		rem --- Return focus to where we were (Detail line grid)

			sysgui!.setContext(grid_ctx)
		endif
	endif

[[OPE_INVDET.AOPT-RCPR]]
rem --- Are things set for a reprice?

	if pos(user_tpl.line_type$="SP") then
		qty_ord = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
		if qty_ord then 

		rem --- Save current column so we'll know where to set focus when we return

			return_to_col = util.getGrid(Form!).getSelectedColumn()

		rem --- Do repricing
			conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
			gosub pricing

			rem --- Grid vector must be updated before updating Totals tab
			qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
			unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
			declare BBjVector dtlVect!
			dtlVect!=cast(BBjVector, GridVect!.getItem(0))
			dim dtl_rec$:dtlg_param$[1,3]
			dtl_rec$=cast(BBjString, dtlVect!.getItem(callpoint!.getValidationRow()))
			dtl_rec.qty_shipped=qty_shipped
			dtl_rec.unit_price=unit_price
			dtlVect!.setItem(callpoint!.getValidationRow(),dtl_rec$)
			GridVect!.setItem(0,dtlVect!)
			gosub disp_ext_amt

			callpoint!.setDevObject("rcpr_row",str(callpoint!.getValidationRow()))
			callpoint!.setColumnData("OPE_INVDET.MAN_PRICE", "N")
			gosub manual_price_flag

		endif
	endif

[[OPE_INVDET.AOPT-WHSE]]
rem --- Show availability for this item
	item_id$=callpoint!.getColumnData("OPE_INVDET.ITEM_ID")

	selected_key$ = ""
	dim filter_defs$[1,2]
	filter_defs$[0,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="IVM_ITEMWHSE.ITEM_ID"
	filter_defs$[1,1]="='"+item_id$+"'"
	filter_defs$[1,2]="LOCK"

	dim search_defs$[3]

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"IV_PRICE_AVAIL",
:		"",
:		table_chans$[all],
:		selected_key$,
:		filter_defs$[all],
:		search_defs$[all],
:		"",
:		""

[[OPE_INVDET.AREC]]
rem --- Initialize RTP trans_status and created fields
	rem --- TRANS_STATUS set to "E" via form Preset Value
	callpoint!.setColumnData("OPE_INVDET.CREATED_USER",sysinfo.user_id$)
	callpoint!.setColumnData("OPE_INVDET.CREATED_DATE",date(0:"%Yd%Mz%Dz"))
	callpoint!.setColumnData("OPE_INVDET.CREATED_TIME",date(0:"%Hz%mz"))
	callpoint!.setColumnData("OPE_INVDET.AUDIT_NUMBER","0")

rem --- Backorder is zero and disabled on a new record

	callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0")
	callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP", 0)

rem --- Set defaults for new record

	inv_type$  = callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE")
	ship_date$ = callpoint!.getHeaderColumnData("OPE_INVHDR.SHIPMNT_DATE")

	callpoint!.setColumnData("OPE_INVDET.MAN_PRICE", "N")
	callpoint!.setColumnData("OPE_INVDET.EST_SHP_DATE", ship_date$)

	rem --- For new lines may want to skip line code entry the first time.
	callpoint!.setDevObject("skipLineCode",user_tpl.skip_ln_code$)

	rem --- For new lines may want to skip warehouse code entry the first time.
	callpoint!.setDevObject("skipWHCode",user_tpl.skip_whse$)

	rem --- Is the default line code for dropships?
	file$ = "OPC_LINECODE"
	dim opc_linecode$:fnget_tpl$(file$)
	opc_linecode.dropship$ = "N"
	find record (fnget_dev(file$), key=firm_id$+user_tpl.line_code$, dom=*next) opc_linecode$

	rem --- Allow blank memo lines when default line code is a Memo line type
	if opc_linecode.line_type$="M" then
		line_code$=user_tpl.line_code$
		gosub line_code_init
		callpoint!.setStatus("MODIFIED")
	endif

	if inv_type$ = "P" or ship_date$ > user_tpl.def_commit$ then
 		callpoint!.setColumnData("OPE_INVDET.COMMIT_FLAG", "N")
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP", 0)
	else
		callpoint!.setColumnData("OPE_INVDET.COMMIT_FLAG", "Y")
 	endif

	rem --- Initialize CONV_FACTOR
	callpoint!.setColumnData("OPE_INVDET.CONV_FACTOR","1")

rem --- Buttons start disabled

	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("KITS",0)
	callpoint!.setOptionEnabled("RCPR",0)
	callpoint!.setOptionEnabled("ADDL",0)
	callpoint!.setOptionEnabled("COMM",0)
	callpoint!.setOptionEnabled("WHSE",0)
	callpoint!.setStatus("REFRESH")

rem --- Initialize Kit Component grid's kit_detail_changed flag
	callpoint!.setDevObject("kit_details_changed","N")

[[OPE_INVDET.AUDE]]
print "Det:AUDE"; rem debug

rem --- redisplay totals

	gosub disp_grid_totals

	callpoint!.setDevObject("details_changed","Y")

[[OPE_INVDET.AWRI]]
rem --- Commit inventory

rem --- Turn off the print flag in the header?

	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow()) = "Y" or
:	   callpoint!.getGridRowModifyStatus(callpoint!.getValidationRow()) ="Y" or
:	   callpoint!.getGridRowDeleteStatus(callpoint!.getValidationRow()) = "Y"
		callpoint!.setHeaderColumnData("OPE_INVHDR.PRINT_STATUS","N")
		callpoint!.setDevObject("msg_printed","N")
	endif

rem --- Is this row deleted?

	if callpoint!.getGridRowModifyStatus( callpoint!.getValidationRow() ) <> "Y" then 
		break; rem --- exit callpoint
	endif

rem --- Get current and prior values

	curr_whse$ = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
	curr_item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	curr_qty   = num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED"))
	curr_commit$=callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")

	prior_whse$ = callpoint!.getDevObject("prior_whse")
	prior_item$ = callpoint!.getDevObject("prior_item")
	prior_qty   = callpoint!.getDevObject("prior_qty")
	prior_commit$=callpoint!.getDevObject("prior_commit")

	cust$    = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
	ar_type$ = callpoint!.getColumnData("OPE_INVDET.AR_TYPE")
	order$   = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
	invoice_no$= callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
	seq$     = callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")

rem --- Don't commit/uncommit Quotes or Dropships

	if callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE") = "P" or
:	(cvs(callpoint!.getDevObject("dropship_whse"),2)="" and user_tpl.line_dropship$ = "Y")
		goto awri_update_hdr
	endif

rem --- Has there been any change?

	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))="Y" or
:		((curr_whse$ <> prior_whse$ or  curr_item$ <> prior_item$ or curr_qty   <> prior_qty) and curr_commit$ = prior_commit$)
:	then

		rem --- Initialize inventory item update

		status=999
		call user_tpl.pgmdir$+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then goto awri_update_hdr

		ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
		dim curr_itemmast$:fnget_tpl$("IVM_ITEMMAST")
		read record (ivm_itemmast_dev, key=firm_id$+curr_item$, dom=awri_update_hdr) curr_itemmast$
		if cvs(prior_item$,2)<>"" then
			dim prior_itemmast$:fnget_tpl$("IVM_ITEMMAST")
			read record (ivm_itemmast_dev, key=firm_id$+prior_item$, dom=awri_update_hdr) prior_itemmast$
		endif

rem --- Items or warehouses are different: uncommit previous

		if (prior_whse$<>"" and prior_whse$<>curr_whse$) or 
:		   (prior_item$<>"" and prior_item$<>curr_item$)
:		then

			rem --- Uncommit prior item and warehouse

			if prior_whse$<>"" and prior_item$<>"" and prior_qty<>0 then
				items$[1] = prior_whse$
				items$[2] = prior_item$
				refs[0]   = prior_qty
				
				if !pos(prior_itemmast.lotser_flag$="LS") or prior_itemmast.inventoried$<>"Y" then
					call user_tpl.pgmdir$+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then goto awri_update_hdr

					rem --- NOTE: ivc_itemupdt.aon skips kits
					rem --- Uncommit kit components for prior item
					ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
					dim prior_itemmast$:fnget_tpl$("IVM_ITEMMAST")
					read record (ivm_itemmast_dev, key=firm_id$+prior_item$, dom=*next) prior_itemmast$
					if pos(prior_itemmast.kit$="YP") then
						optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
						dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
						optInvKitDet_key$=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$
						read(optInvKitDet_dev,key=optInvKitDet_key$,knum="PRIMARY",dom=*next)
						while 1
							thisKey$=key(optInvKitDet_dev,end=*break)
							if pos(optInvKitDet_key$=thisKey$)<>1 then break
							readrecord(optInvKitDet_dev,key=thisKey$)optInvKitDet$
							remove(optInvKitDet_dev,key=thisKey$)

							items$[1]=optInvKitDet.warehouse_id$
							items$[2]=optInvKitDet.item_id$
							refs[0]=optInvKitDet.qty_ordered
							call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						wend
						read(optInvKitDet_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next); rem --- Reset to alternate key
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
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
						remove (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$+ope_ordlsdet.sequence_no$)
					wend
					read (ope_ordlsdet_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

					if found_lot=0
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
					endif
				endif
			endif

			rem --- Commit quantity for current item and warehouse

			if curr_whse$<>"" and curr_item$<>"" and curr_qty<>0 then
				items$[1] = curr_whse$
				items$[2] = curr_item$
				refs[0]   = curr_qty 

				print "-----Commit: item = ", cvs(items$[2], 2), ", WH: ", items$[1], ", qty =", refs[0]; rem debug

				call user_tpl.pgmdir$+"ivc_itemupdt.aon","CO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				if status then goto awri_update_hdr
			endif
		endif

rem --- New record or item and warehouse haven't changed: commit difference

		if	(prior_whse$="" or prior_whse$=curr_whse$) and 
:			(prior_item$="" or prior_item$=curr_item$) 
:		then

			rem --- Commit quantity for current item and warehouse

			if curr_whse$<>"" and curr_item$<>"" and curr_qty - prior_qty <> 0
				items$[1] = curr_whse$
				items$[2] = curr_item$
				refs[0]   = curr_qty - prior_qty

				if curr_qty - prior_qty > 0 then
    					rem --- Commit
					call user_tpl.pgmdir$+"ivc_itemupdt.aon","CO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then goto awri_update_hdr
				else
					rem --- Uncommit
					refs[0]=abs(refs[0])
					if !pos(curr_itemmast.lotser_flag$="LS") or curr_itemmast.inventoried$<>"Y" then
						call user_tpl.pgmdir$+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
						if status then goto awri_update_hdr
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
							call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
							if status then goto awri_update_hdr
							if ope_ordlsdet.qty_ordered=refs[0] then
								remove (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$+ope_ordlsdet.sequence_no$)
							else
								ope_ordlsdet.qty_ordered=ope_ordlsdet.qty_ordered-refs[0]
								writerecord(ope_ordlsdet_dev)ope_ordlsdet$
							endif
 						wend
						read (ope_ordlsdet_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

						if found_lot=0
							call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
							if status then goto awri_update_hdr
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
		call user_tpl.pgmdir$+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
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
				call user_tpl.pgmdir$+"ivc_itemupdt.aon",action$,chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
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
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then goto awri_update_hdr
					remove (ope_ordlsdet_dev, key=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$+ope_ordlsdet.sequence_no$)
				wend
				read (ope_ordlsdet_dev, key="",knum="AO_STAT_CUST_ORD", dom=*next)

				if found_lot=0
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then goto awri_update_hdr
				endif
			endif
		endif
	endif

awri_update_hdr: rem --- Update header

	rem --- disp_grid_totals already executed in AGRE, so no need to do it again here
	rem gosub disp_grid_totals

	file$ = "OPC_LINECODE"
	dim opc_linecode$:fnget_tpl$(file$)
	line_code$=callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
	find record (fnget_dev(file$), key=firm_id$+line_code$, dom=*endif) opc_linecode$

	if opc_linecode.line_type$<>"M"
		callpoint!.setDevObject("details_changed","Y")
	endif

rem --- set prior's = curr's here, since row has been written
rem --- this way, if we stay on the same row, as will be the case if we've pressed Recalc, Lot/Ser, or Additional buttons,
rem --- then next time thru AWRI it won't see a false difference between curr and pri, so won't over-commit

	callpoint!.setDevObject("prior_whse", curr_whse$)
	callpoint!.setDevObject("prior_item", curr_item$)
	callpoint!.setDevObject("prior_qty", curr_qty)
	callpoint!.setDevObject("prior_commit", curr_commit$)

[[OPE_INVDET.BDEL]]
rem --- Require existing modified rows be saved before deleting so can't uncommit quantity different from what was committed (bug 8087)
	if callpoint!.getGridRowModifyStatus(num(callpoint!.getValidationRow()))="Y" and
:	callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))<>"Y" then
		msg_id$="OP_MODIFIED_DELETE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif


rem --- Prevent deleting Sales Order detail lines currently "linked" to Purchase Orders
	if callpoint!.getDevObject("po_installed")="Y" then
		linked=0
		customer_id$=callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order_no$=callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		internal_seq_no$=callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
		poeLinked_dev = fnget_dev("POE_LINKED")
		dim poeLinked$:fnget_tpl$("POE_LINKED")
		read(poeLinked_dev,key=firm_id$+customer_id$+order_no$,knum="AO_CUST_ORD",dom=*next)
		while 1
			poeLinked_key$=key(poeLinked_dev,end=*break)
			if pos(firm_id$+customer_id$+order_no$=poeLinked_key$)<>1 then break
			readrecord(poeLinked_dev)poeLinked$
			if poeLinked.opedet_seq_ref$=internal_seq_no$ then
				linked=1
				break
			endif
		wend

		if linked then
			msg_id$ = "OP_ITEM_PO_LINKED"
			dim msg_tokens$[1]
			msg_tokens$[1] = Translate!.getTranslation("AON_PURCHASE_ORDER")+" "+poeLinked.po_no$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Check for Requisitions "linked" to this Sales Order detail line
		linked=0
		poeReqhdr_dev = fnget_dev("POE_REQHDR")
		dim poeReqhdr$:fnget_tpl$("POE_REQHDR")
		read(poeReqhdr_dev,key=firm_id$,dom=*next)
		while 1
			poeReqhdr_key$=key(poeReqhdr_dev,end=*break)
			if pos(firm_id$=poeReqhdr_key$)<>1 then break
			readrecord(poeReqhdr_dev)poeReqhdr$
			if poeReqhdr.order_no$=order_no$ then
				poeReqdet_dev = fnget_dev("POE_REQDET")
				dim poeReqdet$:fnget_tpl$("POE_REQDET")
				read(poeReqdet_dev,key=firm_id$+poeReqhdr.req_no$,dom=*next)
				while 1
					poeReqdet_key$=key(poeReqdet_dev,end=*break)
					if pos(firm_id$+poeReqhdr.req_no$=poeReqdet_key$)<>1 then break
					readrecord(poeReqdet_dev)poeReqdet$
					if poeReqdet.so_int_seq_ref$=internal_seq_no$ then
						linked=1
						break
					endif

				wend

				break
			endif
		wend

		if linked then
			msg_id$ = "OP_ITEM_PO_LINKED"
			dim msg_tokens$[1]
			msg_tokens$[1] = Translate!.getTranslation("AON_PURCHASE_REQUISITION")+" "+poeReqhdr.req_no$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Update inventory commitments
	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))<>"Y" and
:		callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")="Y"
:	then
		action$="UC"
		gosub uncommit_iv
	endif

rem --- Delete ope_ordlsdet records for lot/serial items. NOTE: Barista's Undelete does NOT cascade.
	item_id$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	gosub lot_ser_check
	if lotted$ = "Y" then
		rem --- Use a HashMap to temporarily hold onto deleted records so they can be undeleted later.
		if callpoint!.getDevObject("undeleteRecs")=null() then
			undeleteRecs!=new HashMap()
			callpoint!.setDevObject("undeleteRecs",undeleteRecs!)
		endif
		undeleteRecs!=callpoint!.getDevObject("undeleteRecs")

		rem --- Delete ope_ordlsdet records entered for this lot/serial items
		ope_ordlsdet_dev=fnget_dev("OPE_ORDLSDET")
		dim ope_ordlsdet$:fnget_tpl$("OPE_ORDLSDET")
		ar_type$=callpoint!.getColumnData("OPE_INVDET.AR_TYPE") 
		cust$=callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order$=callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice_no$=callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		seq$=callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
		ope_ordlsdet_key$=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$
		read(ope_ordlsdet_dev,key=ope_ordlsdet_key$,knum="PRIMARY",dom=*next)
		while 1
			thisKey$=key(ope_ordlsdet_dev,end=*break)
			if pos(ope_ordlsdet_key$=thisKey$)<>1 then break
			readrecord(ope_ordlsdet_dev,key=thisKey$)ope_ordlsdet$
			remove(ope_ordlsdet_dev,key=thisKey$)

			rem --- Hold onto this record for now so it can be undeleted if necessary.
			undeleteRecs!.put(thisKey$,ope_ordlsdet$)
		wend
		read(ope_ordlsdet_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next); rem --- Reset to alternate key
	endif

rem --- Delete opt_invkitdet records. NOTE: Barista's Undelete does NOT cascade.
	if callpoint!.getDevObject("kit")="Y" then
		rem --- Use a HashMap to temporarily hold onto deleted records so they can be undeleted later.
		if callpoint!.getDevObject("undeleteRecs")=null() then
			undeleteRecs!=new HashMap()
			callpoint!.setDevObject("undeleteRecs",undeleteRecs!)
		endif
		undeleteRecs!=callpoint!.getDevObject("undeleteRecs")

		rem --- Delete the kit's components
		optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
		dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
		ar_type$=callpoint!.getColumnData("OPE_INVDET.AR_TYPE") 
		cust$=callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order$=callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice_no$=callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		seq$=callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
		optInvKitDet_key$=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$
		read(optInvKitDet_dev,key=optInvKitDet_key$,knum="PRIMARY",dom=*next)
		while 1
			thisKey$=key(optInvKitDet_dev,end=*break)
			if pos(optInvKitDet_key$=thisKey$)<>1 then break
			readrecord(optInvKitDet_dev,key=thisKey$)optInvKitDet$
			remove(optInvKitDet_dev,key=thisKey$)

			rem --- Hold onto this record for now so it can be undeleted if necessary.
			undeleteRecs!.put(thisKey$,optInvKitDet$)
		wend
		read(optInvKitDet_dev,key="",knum="AO_STAT_CUST_ORD",dom=*next); rem --- Reset to alternate key
    endif

[[OPE_INVDET.BDGX]]
rem --- Disable detail-only buttons

	callpoint!.setOptionEnabled("LENT",0)
	callpoint!.setOptionEnabled("KITS",0)
	callpoint!.setOptionEnabled("RCPR",0)
	callpoint!.setOptionEnabled("ADDL",0)
	callpoint!.setOptionEnabled("COMM",0)
	callpoint!.setOptionEnabled("WHSE",0)

rem --- Set header total amounts

	use ::ado_order.src::OrderHelper

	cust_id$  = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
	order_no$ = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
	inv_type$ = callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE")

	if cvs(cust_id$,3)<>"" and cvs(order_no$,3)<>"" then

		ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
		ordHelp!.setTaxCode(callpoint!.getHeaderColumnData("OPE_INVHDR.TAX_CODE"))
		ordHelp!.totalSalesDisk(cust_id$, order_no$, inv_type$)
		
		callpoint!.setHeaderColumnData( "OPE_INVHDR.TOTAL_SALES", str(round(ordHelp!.getExtPrice(),2)))
		round_precision = num(callpoint!.getDevObject("precision"))
		callpoint!.setHeaderColumnData( "OPE_INVHDR.TOTAL_COST",  str(round(ordHelp!.getExtCost(),round_precision)))

		callpoint!.setStatus("REFRESH;SETORIG")

	endif

[[OPE_INVDET.BGDR]]
rem --- Initialize UM_SOLD related <DISPLAY> fields
	conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
	if conv_factor=0 then conv_factor=1
	unit_cost=num(callpoint!.getColumnData("OPE_INVDET.UNIT_COST"))*conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP",str(unit_cost))
	qty_ordered=num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP",str(qty_ordered))
	unit_price=num(callpoint!.getColumnData("OPE_INVDET.UNIT_PRICE"))*conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",str(unit_price))
	qty_backord=num(callpoint!.getColumnData("OPE_INVDET.QTY_BACKORD"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP",str(qty_backord))
	qty_shipped=num(callpoint!.getColumnData("OPE_INVDET.QTY_SHIPPED"))/conv_factor
	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP",str(qty_shipped))
	std_list_prc=num(callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC"))*conv_factor
	callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC",str(std_list_prc))

[[OPE_INVDET.BUDE]]
rem --- Undelete ope_ordlsdet records for lot/serial items. NOTE: Barista's Undelete does NOT cascade.
	item_id$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	gosub lot_ser_check
	if lotted$ = "Y" then
		rem --- Undelete ope_ordlsdet records entered for this lot/serial items
		ope_ordlsdet_dev=fnget_dev("OPE_ORDLSDET")
		dim ope_ordlsdet$:fnget_tpl$("OPE_ORDLSDET")
		ar_type$=callpoint!.getColumnData("OPE_INVDET.AR_TYPE") 
		cust$=callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order$=callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice_no$=callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		seq$=callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
		ope_ordlsdet_key$=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$

		restoredRecs!=BBjAPI().makeVector()
		undeleteRecs!=callpoint!.getDevObject("undeleteRecs")
		undeleteRecIter!=undeleteRecs!.keySet().iterator()
		while undeleteRecIter!.hasNext()
			undeleteRecKey$=undeleteRecIter!.next()
			if pos(ope_ordlsdet_key$=undeleteRecKey$)<>1 then continue
			ope_ordlsdet$=undeleteRecs!.get(undeleteRecKey$)
			writerecord(ope_ordlsdet_dev)ope_ordlsdet$
			restoredRecs!.addItem(undeleteRecKey$)
		wend
		restoredRecsIter!=restoredRecs!.iterator()
		while restoredRecsIter!.hasNext()
			restoredRecKey$=restoredRecsIter!.next()
			undeleteRecs!.remove(restoredRecKey$)
		wend
	endif

rem --- Undelete opt_invkitdet records. NOTE: Barista's Undelete does NOT cascade.
	if callpoint!.getDevObject("kit")="Y" then
		rem --- Undelete the kit's components
		optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
		dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
		ar_type$=callpoint!.getColumnData("OPE_INVDET.AR_TYPE") 
		cust$=callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order$=callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice_no$=callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		seq$=callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
		optInvKitDet_key$=firm_id$+ar_type$+cust$+order$+invoice_no$+seq$

		restoredRecs!=BBjAPI().makeVector()
		undeleteRecs!=callpoint!.getDevObject("undeleteRecs")
		undeleteRecIter!=undeleteRecs!.keySet().iterator()
		while undeleteRecIter!.hasNext()
			undeleteRecKey$=undeleteRecIter!.next()
			if pos(optInvKitDet_key$=undeleteRecKey$)<>1 then continue
			optInvKitDet$=undeleteRecs!.get(undeleteRecKey$)
			writerecord(optInvKitDet_dev)optInvKitDet$
			restoredRecs!.addItem(undeleteRecKey$)
		wend
		restoredRecsIter!=restoredRecs!.iterator()
		while restoredRecsIter!.hasNext()
			restoredRecKey$=restoredRecsIter!.next()
			undeleteRecs!.remove(restoredRecKey$)
		wend
	endif

rem --- Update inventory commitments
	if callpoint!.getGridRowNewStatus(num(callpoint!.getValidationRow()))<>"Y" and
:		callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")="Y"
:	then
		action$="CO"
		gosub uncommit_iv
	endif

[[OPE_INVDET.BWRI]]
print "Det:BWRI"; rem debug

rem --- Set values based on line type

	file$ = "OPC_LINECODE"
	dim linecode_rec$:fnget_tpl$(file$)
	line_code$ = callpoint!.getColumnData("OPE_INVDET.LINE_CODE")

	find record(fnget_dev(file$), key=firm_id$+line_code$) linecode_rec$

rem --- If line type is Memo, clear the extended price

	if linecode_rec.line_type$ = "M" then 
		callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", "0")
	endif

rem --- Clear quantities if line type is Memo or Other

	if pos(linecode_rec.line_type$="MO") then
		callpoint!.setColumnData("OPE_INVDET.QTY_ORDERED", "0")
		callpoint!.setColumnData("OPE_INVDET.QTY_BACKORD", "0")
		callpoint!.setColumnData("OPE_INVDET.QTY_SHIPPED", "0")
	endif

rem --- Order quantity is required for S, N and P line types

	if pos(linecode_rec.line_type$="SNP") then
		if num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED")) = 0 then
			msg_id$="OP_QTY_ZERO"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Set product types for certain line types 

	if pos(linecode_rec.line_type$="NOP") then
		if linecode_rec.prod_type_pr$ = "D" then			
			callpoint!.setColumnData("OPE_INVDET.PRODUCT_TYPE", linecode_rec.product_type$)
		else
			if linecode_rec.prod_type_pr$ = "N" then
				callpoint!.setColumnData("OPE_INVDET.PRODUCT_TYPE", "")
			endif
		endif
	endif

rem --- Initialize RTP modified fields for modified existing records
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then
		callpoint!.setColumnData("OPE_INVDET.MOD_USER", sysinfo.user_id$)
		callpoint!.setColumnData("OPE_INVDET.MOD_DATE", date(0:"%Yd%Mz%Dz"))
		callpoint!.setColumnData("OPE_INVDET.MOD_TIME", date(0:"%Hz%mz"))
	endif

[[OPE_INVDET.EXT_PRICE.AVAL]]
rem --- Round 

	if num(callpoint!.getUserInput()) <> num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE"))
		callpoint!.setUserInput( str(round( num(callpoint!.getUserInput()), 2)) )
	endif

rem --- For uncommitted "O" line type sales (not quotes), move ext_price to unit_price until committed
	if callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE") <> "P" and
:	callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "N" and user_tpl.line_type$ = "O" 
:	then
		rem --- Don't overwrite existing unit_price with zero
		if num(callpoint!.getUserInput()) then
			callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", callpoint!.getUserInput())
			callpoint!.setUserInput("0")
			callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", "0")
			callpoint!.setStatus("REFRESH")
		endif
	endif

[[OPE_INVDET.EXT_PRICE.AVEC]]
rem --- Extend price now that grid vector has been updated, if the backorder quantity has changed
if num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE")) <> user_tpl.prev_ext_price then
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	gosub disp_ext_amt
endif

[[OPE_INVDET.EXT_PRICE.BINP]]
rem --- Set previous extended price

	user_tpl.prev_ext_price  = num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE"))

[[OPE_INVDET.ITEM_ID.AINV]]
rem --- Skip check for item synonyms

	if callpoint!.getDevObject("skip_ItemId_AINV") then
		callpoint!.setDevObject("skip_ItemId_AINV",0)
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Item synonym processing

	rem --- Get starting item so we know if it gets changed
	item_id$=callpoint!.getUserInput()

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::grid_entry"

	rem --- Item will not have changed if AVAL did an ABORT 
	if item_id$=callpoint!.getUserInput() then
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.ITEM_ID",1)
	endif

[[OPE_INVDET.ITEM_ID.AVAL]]
rem "Inventory Inactive Feature"

	item$=callpoint!.getUserInput()
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
		callpoint!.setDevObject("skip_ItemId_AINV",1)
		break
	endif

rem --- Check item/warehouse combination and setup values

	if item$<>user_tpl.prev_item$ then
		gosub clear_all_numerics
	endif

	wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
	if cvs(wh$,2)="" then
		warn = 0
	else
		rem --- Skip warning if already warned for this whse-item combination
		if callpoint!.getDevObject("whse_item_warned")=wh$+":"+item$ then
			warn = 0
		else
			warn = 1
		endif
	endif
	gosub check_item_whse

	if !user_tpl.item_wh_failed then 
		gosub set_avail
		conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
		if conv_factor=0 then conv_factor=1
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP", str(ivm02a.unit_cost*conv_factor))
		callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", str(ivm02a.cur_price*conv_factor))
		if pos(user_tpl.line_prod_type_pr$="DN")=0
			callpoint!.setColumnData("OPE_INVDET.PRODUCT_TYPE", ivm01a.product_type$)
		endif
		user_tpl.item_price = ivm02a.cur_price
		if pos(user_tpl.line_type$="SP") and num(ivm02a.unit_cost$)=0 or (user_tpl.line_dropship$="Y" and user_tpl.dropship_cost$="Y")
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP",1)
		endif

		rem --- Check if item superseded
		if item$<>user_tpl.prev_item$ and ivm01a.alt_sup_flag$="S" then
			msg_id$="OP_SUPERSEDED_ITEM"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(item$,2)
			msg_tokens$[2]=cvs(ivm01a.alt_sup_item$,2)
			msg_tokens$[3]=avail$[3]
			gosub disp_message
			callpoint!.setStatus("ACTIVATE")
			if msg_opt$="C" then
				callpoint!.setStatus("ABORT")
				callpoint!.setDevObject("skip_ItemId_AINV",1)
				break
			else
				if num(avail$[3])<=0 then
					msg_id$="OP_SUPERSEDE_CONFIRM"
					dim msg_tokens$[1]
					msg_tokens$[1]=cvs(item$,2)
					gosub disp_message
					callpoint!.setStatus("ACTIVATE")
					if msg_opt$="N" then
						callpoint!.setStatus("ABORT")
						callpoint!.setDevObject("skip_ItemId_AINV",1)
						break
					endif
				endif
			endif
		endif

		callpoint!.setStatus("REFRESH")
	endif

rem --- Initialize UM_SOLD ListButton for a new or changed item
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or item$<>user_tpl.prev_item$ then
		dtlGrid!=util.getGrid(Form!)
		col_hdr$=callpoint!.getTableColumnAttribute("OPE_INVDET.UM_SOLD","LABS")
		col_ref=util.getGridColumnNumber(dtlGrid!, col_hdr$)
		row=callpoint!.getValidationRow()
		umList!=dtlGrid!.getCellListControl(row,col_ref)
		umList!.removeAllItems()
		if pos(user_tpl.line_type$="SP") then
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
		dtlGrid!.setCellListControl(row,col_ref,umList!)
		if umList!.getItemCount()>1 then
			dtlGrid!.setCellListSelection(row,col_ref,0,1)
			callpoint!.setColumnEnabled(row,"OPE_INVDET.UM_SOLD",1)
		else
			callpoint!.setColumnData("OPE_INVDET.UM_SOLD",umList!.getItemAt(0),1)
		endif

		rem --- Initialize CONV_FACTOR
		callpoint!.setColumnData("OPE_INVDET.CONV_FACTOR","1")
	endif

rem --- Initialize "kit" DevObject
	if pos(ivm01a.kit$="YP") then
		rem --- Can NOT dropship a kit
		file$ = "OPC_LINECODE"
		opcLineCode_dev=fnget_dev("OPC_LINECODE")
		dim opcLineCode$:fnget_tpl$("OPC_LINECODE")
		line_code$=callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
		findrecord(opcLineCode_dev,key=firm_id$+line_code$,dom=*endif)opcLineCode$
		if opcLineCode.dropship$="Y" then
			msg_id$="OP_DROPSHIP_KIT"
			dim msg_tokens$[1]
			msg_tokens$[1]=cvs(item$,2)
			gosub disp_message
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		endif

		callpoint!.setDevObject("kit","Y")
		if ivm01a.kit$="P"then
			callpoint!.setDevObject("priced_kit","Y")
		else
			callpoint!.setDevObject("priced_kit","N")
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 0)
			callpoint!.setOptionEnabled("RCPR",0)
		endif
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP",0)

		rem --- Initialize UNIT_PRICE for newly entered non-priced kits
		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" and callpoint!.getDevObject("priced_kit")="N" then
			callpoint!.setDevObject("orderDate",user_tpl.order_date$)
			callpoint!.setDevObject("priceCode",user_tpl.price_code$)
			callpoint!.setDevObject("pricingCode",user_tpl.pricing_code$)

			round_precision = num(callpoint!.getDevObject("precision"))
			bmmBillMat_dev=fnget_dev("BMM_BILLMAT")
			dim bmmBillMat$:fnget_tpl$("BMM_BILLMAT")
			ivm01_dev=fnget_dev("IVM_ITEMMAST")
			dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
			dim kitDetailLine$:fnget_tpl$("OPE_INVDET")
			kitDetailLine$=rec_data$
			kit_item$=item$
			kit_ordered=1
			kitExtendedPrice=0
			gosub getKitExtendedPrice
			callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",str(kitExtendedPrice),1)
		endif
	else
		callpoint!.setDevObject("kit","N")
		callpoint!.setDevObject("priced_kit","N")
	endif

rem --- Enable/disable KITS button
	gosub able_kits_button

rem --- Enable Total Whse Availability option
	callpoint!.setOptionEnabled("WHSE",1)

[[OPE_INVDET.ITEM_ID.AVEC]]
rem --- Set buttons

	gosub enable_repricing
	gosub able_lot_button

rem --- Set item tax flag

	gosub set_item_taxable

[[OPE_INVDET.ITEM_ID.BINP]]
rem --- Set previous item / enable repricing, options, lot

	user_tpl.prev_item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button
	callpoint!.setDevObject("skip_ItemId_AINV",0)

[[OPE_INVDET.ITEM_ID.BINQ]]
rem --- Inventory Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]=""
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"IV_ITEM_WHSE_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("OPE_INVDET.ITEM_ID") then 
		callpoint!.setColumnData("OPE_INVDET.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.ITEM_ID",1)
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[OPE_INVDET.LINE_CODE.AVAL]]
rem --- Initialize detail line for this line_code

	line_code$ = callpoint!.getUserInput()
	gosub line_code_init

[[OPE_INVDET.LINE_CODE.AVEC]]
rem --- Line code may not be displayed correctly when selected via arrow key instead of mouse
	callpoint!.setStatus("REFRESH:LINE_CODE")

[[OPE_INVDET.LINE_CODE.BINP]]
rem --- Set previous value / enable repricing, options, lots

	rem --- Clear previous line_code for new rows
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" then
		user_tpl.prev_line_code$=""
	else
		user_tpl.prev_line_code$ = callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
	endif
	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

rem --- Force focus on Warehouse when Line Code entry is skipped

	if callpoint!.getDevObject("skipLineCode") = "Y" then
		rem --- initialize detail line for default line_code
		line_code$ = callpoint!.getColumnData("OPE_INVDET.LINE_CODE")
		gosub line_code_init

		callpoint!.setDevObject("skipLineCode","N"); rem --- skip line code entry only once
		if  callpoint!.getDevObject("skipWHCode") = "Y" then
			if pos(user_tpl.line_type$="SP") then
				callpoint!.setDevObject("skipWHCode","N")
				callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.ITEM_ID",1)
			else
				callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.ORDER_MEMO",1)
			endif
		else
			callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.WAREHOUSE_ID",1)
		endif
	endif

[[OPE_INVDET.MEMO_1024.AVAL]]
rem --- store first part of memo_1024 in order_memo
rem --- this AVAL is hit if user navigates via arrows or clicks on the memo_1024 field, and double-clicks or ctrl-F to bring up editor
rem --- if on a memo line or using ctrl-C or Comments button, code in the comment_entry: subroutine is hit instead

	disp_text$=callpoint!.getUserInput()
	if disp_text$<>callpoint!.getColumnUndoData("OPE_INVDET.MEMO_1024")
		memo_len=len(callpoint!.getColumnData("OPE_INVDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("OPE_INVDET.MEMO_1024",disp_text$)
		callpoint!.setColumnData("OPE_INVDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

[[OPE_INVDET.ORDER_MEMO.BINP]]
rem --- invoke the comments dialog

	gosub comment_entry

[[OPE_INVDET.PRODUCT_TYPE.AVAL]]
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
	if boqty = user_tpl.prev_boqty then break

rem --- Re-calculate qty_shipped and ext_price unless already shipping extra or it's a new line.
	ordqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or qty_shipped<=ordqty - user_tpl.prev_boqty then
		qty_shipped = ordqty - boqty
	endif

	if qty_shipped < 0 then
		callpoint!.setUserInput(str(user_tpl.prev_boqty))
		msg_id$ = "BO_EXCEEDS_ORD"
		gosub disp_message
		callpoint!.setStatus("ABORT-REFRESH")
		break; rem --- exit callpoint
		endif

	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_shipped),1)

	rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP",str(boqty))
	gosub update_record_fields

rem --- Enable/disable KITS button
	gosub able_kits_button

rem --- Warn if ship quantity is more than currently available.
	gosub check_ship_qty

[[<<DISPLAY>>.QTY_BACKORD_DSP.AVEC]]
rem --- Extend price now that grid vector has been updated, if the backorder quantity has changed
if num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP")) <> user_tpl.prev_boqty then
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	gosub disp_ext_amt
endif

[[<<DISPLAY>>.QTY_BACKORD_DSP.BINP]]
rem --- Set previous qty / enable repricing, options, lots

	user_tpl.prev_boqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

rem --- Has a valid whse/item been entered?

	if user_tpl.item_wh_failed then
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

[[<<DISPLAY>>.QTY_ORDERED_DSP.AVAL]]
rem --- Skip if qty_ordered not changed
	qty_ord  = num(callpoint!.getUserInput())
	if qty_ord = user_tpl.prev_qty_ord then break

	if qty_ord = 0 then
		msg_id$="OP_QTY_ZERO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

rem --- Re-calculate qty_shipped and ext_price unless already shipping extra or it's a new line.
	boqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or qty_shipped<=user_tpl.prev_qty_ord - boqty then
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0",1)
		if qty_ord < 0 then
			callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_ord),1)
			util.disableGridCell(Form!,user_tpl.bo_col,callpoint!.getValidationRow())
			util.disableGridCell(Form!,user_tpl.shipped_col,callpoint!.getValidationRow())
		else
			if callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "Y" or callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE") = "P" then
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", str(qty_ord),1)
			else
				callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP", "0",1)
			endif
			util.enableGridCell(Form!,user_tpl.bo_col,callpoint!.getValidationRow())
			util.enableGridCell(Form!,user_tpl.shipped_col,callpoint!.getValidationRow())
		endif
	endif

rem --- Recalc quantities and extended price

	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	if user_tpl.line_type$ <> "N" and
:		callpoint!.getColumnData("OPE_INVDET.MAN_PRICE") <> "Y" and
:		( (qty_ord and qty_ord <> user_tpl.prev_qty_ord) or unit_price = 0 )
:	then
		conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
		gosub pricing
	endif

	rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP",str(qty_ord))
	gosub update_record_fields

rem --- Warn if ship quantity is more than currently available.
	gosub check_ship_qty

rem --- Skip UNIT_PRICE for non-priced kits
	if callpoint!.getDevObject("kit")="Y" and callpoint!.getDevObject("priced_kit")="N" then callpoint!.setFocus(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP",1)

rem --- Enable/disable KITS button
	gosub able_kits_button

[[<<DISPLAY>>.QTY_ORDERED_DSP.AVEC]]
rem --- Extend price now that grid vector has been updated, if the order quantity has changed
if num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP")) <> user_tpl.prev_qty_ord then
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	gosub disp_ext_amt
endif

rem --- Enable buttons
	gosub able_lot_button
	gosub enable_repricing
	gosub enable_addl_opts

if callpoint!.getDevObject("focusPrice")="Y"
 	callpoint!.setFocus(callpoint!.getValidationRow(),"<<DISPLAY>>.UNIT_PRICE_DSP",1)
endif

[[<<DISPLAY>>.QTY_ORDERED_DSP.BINP]]
rem --- Get prev qty / enable repricing, options, lots

	user_tpl.prev_qty_ord = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

rem --- Has a valid whse/item been entered?

	if user_tpl.item_wh_failed then
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

rem --- init devobject for use when forcing focus to price, if need-be

	callpoint!.setDevObject("focusPrice","")

[[<<DISPLAY>>.QTY_SHIPPED_DSP.AVAL]]
rem --- Skip if qty_shipped not changed
	shipqty  = num(callpoint!.getUserInput())
	if shipqty = user_tpl.prev_shipqty then break

rem --- recalc quantities and extended price

rem --- Warn if ship quantity is more than order quantity
	ordqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	if shipqty > ordqty  then
		msg_id$="SHIP_EXCEEDS_ORD"
		dim msg_tokens$[1]
		if ordqty=0 then
			msg_tokens$[1] = "???"
		else
			msg_tokens$[1] = str(round(100*(ordqty-shipqty)/ordqty,1):"###0.0 ")
		endif
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setUserInput(str(user_tpl.prev_shipqty))
			callpoint!.setStatus("ABORT-REFRESH")
			break; rem --- exit callpoint
		endif
		callpoint!.setStatus("ACTIVATE")
	endif

	cash_sale$ = callpoint!.getHeaderColumnData("OPE_INVHDR.CASH_SALE")
	if user_tpl.allow_bo$ = "N" or cash_sale$ = "Y" then
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0",1)
	else
		rem --- Re-calculate qty_shipped and ext_price unless already shipping extra or it's a new line.
		boqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))
		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or user_tpl.prev_shipqty<=ordqty - boqty then
			callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", str(max(0, ordqty - shipqty)),1)
		endif
	endif

	rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
	callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP",str(shipqty))
	gosub update_record_fields

rem --- Enable/disable KITS button
	gosub able_kits_button

rem --- Warn if ship quantity is more than currently available.
	gosub check_ship_qty

[[<<DISPLAY>>.QTY_SHIPPED_DSP.AVEC]]
rem --- Extend price now that grid vector has been updated, if the shipped quantity has changed
qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
if qty_shipped <> user_tpl.prev_shipqty then
	unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	gosub disp_ext_amt
endif

[[<<DISPLAY>>.QTY_SHIPPED_DSP.BINP]]
rem --- Set previous amount / enable repricing, options, lots

	user_tpl.prev_shipqty = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

rem --- Has a valid whse/item been entered?

	if user_tpl.item_wh_failed then
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

[[OPE_INVDET.STD_LIST_PRC.BINP]]
rem --- Enable the Recalc Price button, Additional Options, Lots

	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

[[OPE_INVDET.UM_SOLD.AVAL]]
rem --- Initialize CONV_FACTOR when UM_SOLD changed
	um_sold$=callpoint!.getUserInput()
	prev_um_sold$=callpoint!.getDevObject("prev_um_sold")
	if um_sold$<>prev_um_sold$ then
		conv_factor=1

		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		item$=callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		find record (ivm01_dev,key=firm_id$+item$,err=*endif)ivm01a$
		if um_sold$=ivm01a.purchase_um$ then
			conv_factor=ivm01a.conv_factor
		endif
		callpoint!.setColumnData("OPE_INVDET.CONV_FACTOR",str(conv_factor))

		rem --- Re-calculate cost
		wh$=callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		gosub set_avail
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP", str(ivm02a.unit_cost*conv_factor))

		rem --- Re-calculate price
		qty_ord=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
		gosub pricing
	endif

[[OPE_INVDET.UM_SOLD.BINP]]
rem --- Get current CONV_FACTOR so we'll know if it gets changed
	dtlGrid!=util.getGrid(Form!)
	col_hdr$=callpoint!.getTableColumnAttribute("OPE_INVDET.UM_SOLD","LABS")
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
	unit_price = round(num(callpoint!.getUserInput()), round_precision)
	if num(callpoint!.getUserInput()) <> num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
		callpoint!.setUserInput(str(unit_price))
	endif

	if pos(user_tpl.line_type$="SP") and 
:		user_tpl.prev_unitprice 		and 
:		unit_price <> user_tpl.prev_unitprice 
:	then 
		callpoint!.setColumnData("OPE_INVDET.MAN_PRICE", "Y")
		gosub manual_price_flag
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
rem --- Extend price now that grid vector has been updated, if the unit price has changed
unit_price = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
if unit_price <> user_tpl.prev_unitprice then
	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	gosub disp_ext_amt
endif

[[<<DISPLAY>>.UNIT_PRICE_DSP.BINP]]
rem --- Set previous unit price / enable repricing, options, lots

	user_tpl.prev_unitprice  = num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

rem --- Has a valid whse/item been entered?

	if user_tpl.item_wh_failed then
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		warn  = 1
		gosub check_item_whse
	endif

[[OPE_INVDET.WAREHOUSE_ID.AVAL]]
rem --- Check item/warehouse combination, Set Available

	wh$   = callpoint!.getUserInput()
	if wh$<>callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID") then
		rem --- Do not allow entry of IVS_PARAMS.DROPSHIP_WHSE if it is NOT blank.
		if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and wh$=callpoint!.getDevObject("dropship_whse") then
			msg_id$ = "OP_NOT_DROPSHIP_ITEM"
			dim msg_tokens$[1]
			msg_tokens$[1] = callpoint!.getDevObject("dropship_whse")
			gosub disp_message
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		endif

		gosub clear_all_numerics
		callpoint!.setStatus("REFRESH")

		rem --- Use just entered warehouse as the new default warehouse.
		user_tpl.warehouse_id$=wh$
	endif


	item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
    	if cvs(item$,2)="" then
        		warn = 0
	else
		rem --- Skip warning if already warned for this whse-item combination
		if callpoint!.getDevObject("whse_item_warned")=wh$+":"+item$ then
			warn = 0
		else
			warn = 1
		endif
	endif
    	gosub check_item_whse

rem --- Item probably isn't set yet, but we don't know that for sure
	if !user_tpl.item_wh_failed then gosub set_avail

[[OPE_INVDET.WAREHOUSE_ID.AVEC]]
rem --- Set Recalc Price button

	gosub enable_repricing

[[OPE_INVDET.WAREHOUSE_ID.BINP]]
rem --- Enable repricing, options, lots

	gosub enable_repricing
	gosub enable_addl_opts
	gosub able_lot_button

rem --- Force focus when Warehouse Code entry is skipped

	if callpoint!.getDevObject("skipWHCode") = "Y" then
		callpoint!.setDevObject("skipWHCode","N"); rem --- skip warehouse code entry only once
		if pos(user_tpl.line_type$="SP") then 
			callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.ITEM_ID",1)
		else
			callpoint!.setFocus(num(callpoint!.getValidationRow()),"OPE_INVDET.ORDER_MEMO",1)
		endif
		break
	endif

[[OPE_INVDET.<CUSTOM>]]
rem ==========================================================================
update_record_fields: rem --- Use UM_SOLD related <DISPLAY> fields to update the real record fields
rem ==========================================================================

	conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
	if conv_factor=0 then
		conv_factor=1
		callpoint!.setColumnData("OPE_INVDET.CONV_FACTOR",str(conv_factor))
	endif
	unit_cost=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP"))/conv_factor
	callpoint!.setColumnData("OPE_INVDET.UNIT_COST",str(unit_cost))
	qty_ordered=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))*conv_factor
	callpoint!.setColumnData("OPE_INVDET.QTY_ORDERED",str(qty_ordered))
	unit_price=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))/conv_factor
	callpoint!.setColumnData("OPE_INVDET.UNIT_PRICE",str(unit_price))
	qty_backord=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_BACKORD_DSP"))*conv_factor
	callpoint!.setColumnData("OPE_INVDET.QTY_BACKORD",str(qty_backord))
	qty_shipped=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))*conv_factor
	callpoint!.setColumnData("OPE_INVDET.QTY_SHIPPED",str(qty_shipped))
	std_list_prc=num(callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC"))/conv_factor
	callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC",str(std_list_prc))

	return

rem ==========================================================================
disp_grid_totals: rem --- Get order totals and display, save header totals
rem ==========================================================================
	rem --- Using a sales tax service?
	use_tax_service=0
	if callpoint!.getDevObject("sls_tax_intrface")<>"" then
		opc_taxcode_dev = fnget_dev("OPC_TAXCODE")
		dim opc_taxcode$:fnget_tpl$("OPC_TAXCODE")
		findrecord(opc_taxcode_dev,key=firm_id$+callpoint!.getHeaderColumnData("OPE_INVHDR.TAX_CODE"),dom=*next)opc_taxcode$
		use_tax_service=opc_taxcode.use_tax_service
	endif

	gosub calculate_discount

	freight_amt = num(callpoint!.getHeaderColumnData("OPE_INVHDR.FREIGHT_AMT"))
	sub_tot = ttl_ext_price - disc_amt
	net_sales = sub_tot + ttl_tax + freight_amt

	salesamt! = UserObj!.getItem(num(callpoint!.getDevObject("total_sales_disp")))
	salesamt!.setValue(ttl_ext_price)
	discamt! = UserObj!.getItem(num(callpoint!.getDevObject("disc_amt_disp")))
	discamt!.setValue(disc_amt)
	subamt! = UserObj!.getItem(num(callpoint!.getDevObject("subtot_disp")))
	subamt!.setValue(sub_tot)
	netamt! = UserObj!.getItem(num(callpoint!.getDevObject("net_sales_disp")))
	netamt!.setValue(net_sales)
	taxamt! = UserObj!.getItem(num(callpoint!.getDevObject("tax_amt_disp")))
	taxamt!.setValue(ttl_tax)
	ordamt! = UserObj!.getItem(user_tpl.ord_tot_obj)
	ordamt!.setValue(net_sales)

	callpoint!.setHeaderColumnData("OPE_INVHDR.TOTAL_SALES", str(round(ttl_ext_price,2)))
	callpoint!.setHeaderColumnData("OPE_INVHDR.DISCOUNT_AMT",str(round(disc_amt,2)))
	callpoint!.setHeaderColumnData("<<DISPLAY>>.SUBTOTAL", str(sub_tot))
	callpoint!.setHeaderColumnData("<<DISPLAY>>.NET_SALES", str(net_sales))
	if !use_tax_service then
		callpoint!.setHeaderColumnData("OPE_INVHDR.TAX_AMOUNT",str(round(ttl_tax,2)))
		callpoint!.setHeaderColumnData("OPE_INVHDR.TAXABLE_AMT",str(round(ttl_taxable,2)))
	endif
	callpoint!.setHeaderColumnData("OPE_INVHDR.FREIGHT_AMT",str(round(freight_amt,2)))
	callpoint!.setHeaderColumnData("<<DISPLAY>>.ORDER_TOT", str(net_sales))

	cm$=callpoint!.getDevObject("msg_credit_memo")

	if cm$="Y" and ttl_ext_price>=0 callpoint!.setDevObject("msg_credit_memo","N")
	if cm$<>"Y" and ttl_ext_price<0 callpoint!.setDevObject("msg_credit_memo","Y")
	call user_tpl.pgmdir$+"opc_creditmsg.aon","D",callpoint!,UserObj!

	return

rem ==========================================================================
calculate_discount: rem --- Calculate Discount Amount
rem ==========================================================================

	gosub calc_grid_totals

	rem --- Don't update discount unless extended price has changed, otherwise might overwrite manually entered discount.
	rem --- Must always update for a new, deleted  or undeleted record, or when from lot/serial entry and qty_shipped was 
	rem --- changed, or when from Additional and committed was changed.
	disc_amt=num(callpoint!.getHeaderColumnData("OPE_INVHDR.DISCOUNT_AMT"))
	if user_tpl.prev_ext_price<>num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE")) or 
:	callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" or
:	callpoint!.getGridRowDeleteStatus(callpoint!.getValidationRow())="Y" or
:	callpoint!.getEvent()="AUDE" or
:	(callpoint!.getEvent()="AOPT-LENT" and qty_shipped_changed) or
:	(callpoint!.getEvent()="AOPT-ADDL" and committed_changed) then
		disc_code$=callpoint!.getDevObject("disc_code")

		file_name$ = "OPC_DISCCODE"
		disccode_dev = fnget_dev(file_name$)
		dim disccode_rec$:fnget_tpl$(file_name$)

		find record (disccode_dev, key=firm_id$+disc_code$, dom=*next) disccode_rec$

		ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
		if ordHelp!.getInv_type() = "" then
			ttl_ext_price = 0
		else
			ttl_ext_price=totalsVect!.getItem(0)
		endif

		disc_amt = round(disccode_rec.disc_percent * ttl_ext_price / 100, 2)
		callpoint!.setHeaderColumnData("OPE_INVHDR.DISCOUNT_AMT",str(round(disc_amt,2)))
	endif

	if use_tax_service then
		rem --- Skip tax calculation for individual detail lines, except for memos, when using sales tax service
		if user_tpl.line_type$ <> "M" then 	callpoint!.setHeaderColumnData("OPE_INVHDR.NO_SLS_TAX_CALC",str(1))
	else
		rem --- Calculate tax
		freight_amt = num(callpoint!.getHeaderColumnData("OPE_INVHDR.FREIGHT_AMT"))
		taxAndTaxableVect! = ordHelp!.calculateTax(disc_amt, freight_amt, ttl_taxable_sales, ttl_ext_price)
		ttl_tax = taxAndTaxableVect!.getItem(0)
		ttl_taxable = taxAndTaxableVect!.getItem(1)
	endif

	return

rem ==========================================================================
calc_grid_totals: rem --- Roll thru all detail line, totaling ext_price
                  rem     OUT: ttl_ext_price
rem ==========================================================================

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))

	if ordHelp!.getInv_type() = "" then
		ttl_ext_price = 0
		ttl_ext_cost = 0
		ttl_taxable_sales = 0
	else
		ordHelp!.setTaxCode(callpoint!.getHeaderColumnData("OPE_INVHDR.TAX_CODE"))
		totalsVect!=ordHelp!.totalSalesCostTaxable(cast(BBjVector, GridVect!.getItem(0)), cast(Callpoint, callpoint!))
		ttl_ext_price=totalsVect!.getItem(0)
		ttl_ext_cost=totalsVect!.getItem(1)
		ttl_taxable_sales=totalsVect!.getItem(2)
	endif

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

	wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
	item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	cust$ = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
	ord$  = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")

	if cvs(item$, 2)="" or cvs(wh$, 2)="" then 
		callpoint!.setStatus("ABORT")
		return
	endif

	warn = 0
	gosub check_item_whse

	if user_tpl.item_wh_failed then 
		callpoint!.setStatus("ABORT")
		return
	endif

	if callpoint!.getDevObject("kit")<>"Y" or callpoint!.getDevObject("priced_kit")="Y" then
		rem --- Pricing a non-kitted item, or a priced kitted item
		dim pc_files[6]
		pc_files[1] = fnget_dev("IVM_ITEMMAST")
		pc_files[2] = fnget_dev("IVM_ITEMWHSE")
		pc_files[3] = fnget_dev("IVM_ITEMPRIC")
		pc_files[4] = fnget_dev("IVC_PRICCODE")
		pc_files[5] = fnget_dev("ARS_PARAMS")
		pc_files[6] = fnget_dev("IVS_PARAMS")

		call stbl("+DIR_PGM")+"opc_pricing.aon",
:			pc_files[all],
:			firm_id$,
:			wh$,
:			item$,
:			user_tpl.price_code$,
:			cust$,
:			user_tpl.order_date$,
:			user_tpl.pricing_code$,
:			qty_ord*conv_factor,
:			typeflag$,
:			price,
:			disc,
:			status

		if status=999 then
			exitto std_exit
		else
			price=price*conv_factor
		endif
	else
		rem --- Pricing a non-priced kitted item
		optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
		dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
		total_unit_price=0
		ar_type$ = callpoint!.getColumnData("OPE_INVDET.AR_TYPE")
		cust$ = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
		order$ = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
		invoice_no$ = callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
		seq$ = callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
		key_pfx$ = firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$
		read(optInvKitDet_dev,key=key_pfx$,knum="AO_STAT_CUST_ORD",dom=*next)
		while 1
			thisKey$=key(optInvKitDet_dev,end=*break)
			if pos(key_pfx$=thisKey$)<>1 then break
			readrecord(optInvKitDet_dev)optInvKitDet$
			total_unit_price=total_unit_price+optInvKitDet.unit_price*optInvKitDet.qty_ordered
		wend

		if total_unit_price then
			rem --- Kit unit price for both standard and custom components
			kit_unit_price=round(total_unit_price/num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED")),2)
			price=round(kit_unit_price*conv_factor,2)
			disc=0
		else
			rem --- Kit not exploded yet so price based on only standard components 
			callpoint!.setDevObject("orderDate",user_tpl.order_date$)
			callpoint!.setDevObject("priceCode",user_tpl.price_code$)
			callpoint!.setDevObject("pricingCode",user_tpl.pricing_code$)

			bmmBillMat_dev=fnget_dev("BMM_BILLMAT")
			dim bmmBillMat$:fnget_tpl$("BMM_BILLMAT")
			ivm01_dev=fnget_dev("IVM_ITEMMAST")
			dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
			dim kitDetailLine$:fnget_tpl$("OPE_INVDET")
			kitDetailLine$=rec_data$
			kit_item$=item$
			kit_ordered=qty_ord
			kitExtendedPrice=0
			gosub getKitExtendedPrice
			price=kitExtendedPrice/kit_ordered
			disc=0
		endif
	endif

	if price=0 and callpoint!.getVariableName()<>"<<DISPLAY>>.QTY_ORDERED_DSP" then
		msg_id$="ENTER_PRICE"
		gosub disp_message
		enter_price_message = 1
		callpoint!.setDevObject("focusPrice","Y")
		callpoint!.setStatus("ACTIVATE")
	else
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP", str(round(price, round_precision)) )
		callpoint!.setColumnData("OPE_INVDET.DISC_PERCENT", str(disc))
		callpoint!.setDevObject("focusPrice","")
	endif

	if disc=100 then
		callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", str(user_tpl.item_price))
	else
		callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", str( round((price*100) / (100-disc), round_precision) ))
	endif

	rem callpoint!.setStatus("REFRESH")
	callpoint!.setStatus("REFRESH:UNIT_PRICE_DSP")

rem --- Recalc and display extended price

	qty_shipped = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))
	unit_price = price
	if pos(user_tpl.line_type$="NSP")
		callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", str(round(qty_shipped * unit_price, 2)) )
	endif

	user_tpl.prev_unitprice = unit_price

	return

rem ==========================================================================
set_avail: rem --- Set data in Availability window
           rem      IN: item$
           rem          wh$
rem ==========================================================================

	dim avail$[6]

	ivm01_dev = fnget_dev("IVM_ITEMMAST")
	dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")

	ivm02_dev = fnget_dev("IVM_ITEMWHSE")
	dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")

	ivc_whcode_dev = fnget_dev("IVC_WHSECODE")
	dim ivm10c$:fnget_tpl$("IVC_WHSECODE")

	inv_avail_title!=callpoint!.getDevObject("inv_avail_title")
	inv_avail_title!.setVisible(0)

	good_item$="N"
	start_block = 1

	if start_block then
		read record (ivm01_dev, key=firm_id$+item$, dom=*endif) ivm01a$
		read record (ivm02_dev, key=firm_id$+wh$+item$, dom=*endif) ivm02a$
		read record (ivc_whcode_dev, key=firm_id$+"C"+wh$, dom=*endif) ivm10c$
		good_item$="Y"

		if callpoint!.getColumnData("OPE_INVDET.UM_SOLD")<>ivm01a.unit_of_sale$ then
			title_txt$="[ "+ivm01a.purchase_um$+" = "+str(ivm01a.conv_factor)+" * "+ivm01a.unit_of_sale$+" ]"
			inv_avail_title!.setText(title_txt$)
			inv_avail_title!.setVisible(1)
		endif
	endif

	if good_item$="Y" then
		avail$[1] = str(ivm02a.qty_on_hand)
		avail$[2] = str(ivm02a.qty_commit)
		avail$[3] = str(ivm02a.qty_on_hand-ivm02a.qty_commit)
		avail$[4] = str(ivm02a.qty_on_order)
		avail$[5] = ivm10c.short_name$
		avail$[6] = ivm01a.item_type$
	endif

	userObj!.getItem(user_tpl.avail_oh).setText(avail$[1])
	userObj!.getItem(user_tpl.avail_comm).setText(avail$[2])
	userObj!.getItem(user_tpl.avail_avail).setText(avail$[3])
	userObj!.getItem(user_tpl.avail_oo).setText(avail$[4])
	userObj!.getItem(user_tpl.avail_wh).setText(avail$[5])
	userObj!.getItem(user_tpl.avail_type).setText(avail$[6])

	if user_tpl.line_dropship$ = "Y" then
		userObj!.getItem(user_tpl.dropship_flag).setText(Translate!.getTranslation("AON_**DROPSHIP**"))
	else
		userObj!.getItem(user_tpl.dropship_flag).setText("")
	endif

 	if good_item$="Y"
 		switch pos(ivm01a.alt_sup_flag$="AS")
 			case 1
 				userObj!.getItem(user_tpl.alt_super).setText(Translate!.getTranslation("AON_ALTERNATE:_")+cvs(ivm01a.alt_sup_item$,3))
 			break
 			case 2
 				userObj!.getItem(user_tpl.alt_super).setText(Translate!.getTranslation("AON_SUPERSEDED:_")+cvs(ivm01a.alt_sup_item$,3))
 			break
 			case default
 				userObj!.getItem(user_tpl.alt_super).setText("")
 			break
 		swend
	else
		userObj!.getItem(user_tpl.alt_super).setText("")
 	endif

	gosub manual_price_flag

	return

rem ==========================================================================
manual_price_flag: rem --- Set manual price flag
rem ==========================================================================

	if callpoint!.getColumnData("OPE_INVDET.MAN_PRICE") = "Y" then 
		userObj!.getItem(user_tpl.manual_price).setText(Translate!.getTranslation("AON_**MANUAL_PRICE**"))
	else
		userObj!.getItem(user_tpl.manual_price).setText("")
	endif

	return

rem ==========================================================================
clear_avail: rem --- Clear Availability Window
rem ==========================================================================

	inv_avail_title!=callpoint!.getDevObject("inv_avail_title")
	inv_avail_title!.setVisible(0)

	userObj!.getItem(user_tpl.avail_oh).setText("")
	userObj!.getItem(user_tpl.avail_comm).setText("")
	userObj!.getItem(user_tpl.avail_avail).setText("")
	userObj!.getItem(user_tpl.avail_oo).setText("")
	userObj!.getItem(user_tpl.avail_wh).setText("")
	userObj!.getItem(user_tpl.avail_type).setText("")
	userObj!.getItem(user_tpl.dropship_flag).setText("")
	userObj!.getItem(user_tpl.manual_price).setText("")
	userObj!.getItem(user_tpl.alt_super).setText("")

return

rem ==========================================================================
check_new_row: rem --- Check to see if we're on a new row, *** DEPRECATED, see AGCL
rem ==========================================================================

	currRow = callpoint!.getValidationRow()

	if currRow <> user_tpl.cur_row
		gosub clear_avail
		user_tpl.cur_row = currRow
		gosub set_avail
	endif

	return

rem ==========================================================================
uncommit_iv: rem --- Uncommit Inventory
rem              --- Make sure action$ is set before entry
rem ==========================================================================

	ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")

	ope_ordlsdet_dev=fnget_dev("OPE_ORDLSDET")
	dim ope_ordlsdet$:fnget_tpl$("OPE_ORDLSDET")

	ord_type$ = callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE")
	trans_status$=callpoint!.getColumnData("OPE_INVDET.TRANS_STATUS")
	cust$    = callpoint!.getColumnData("OPE_INVDET.CUSTOMER_ID")
	ar_type$ = callpoint!.getColumnData("OPE_INVDET.AR_TYPE")
	order$   = callpoint!.getColumnData("OPE_INVDET.ORDER_NO")
	invoice_no$= callpoint!.getColumnData("OPE_INVDET.AR_INV_NO")
	seq$     = callpoint!.getColumnData("OPE_INVDET.INTERNAL_SEQ_NO")
	wh$      = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
	item$    = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	line_ship_date$=callpoint!.getColumnData("OPE_INVDET.EST_SHP_DATE")
	ord_qty  = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
	if conv_factor=0 then conv_factor=1

	if cvs(item$, 2)<>"" and cvs(wh$, 2)<>"" and ord_qty and ord_type$<>"P" and 
:	(user_tpl.line_dropship$ = "N" or (cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" and user_tpl.line_dropship$ = "Y")) then
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		read record (ivm_itemmast_dev, key=firm_id$+item$, dom=*next) ivm_itemmast$

		items$[1]=wh$
		items$[2]=item$
		refs[0]=ord_qty*conv_factor

		if !pos(ivm_itemmast.lotser_flag$="LS") or ivm_itemmast.inventoried$<>"Y" then
			if callpoint!.getDevObject("kit")<>"Y" then
				call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
			else
				rem --- Skip the kit, and do its components instead.
				optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
				dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")
				optInvKitDet_key$=firm_id$+"E"+ar_type$+cust$+order$+invoice_no$+seq$
				read(optInvKitDet_dev,key=optInvKitDet_key$,knum="AO_STAT_CUST_ORD",dom=*next)
				while 1
					thisKey$=key(optInvKitDet_dev,end=*break)
					if pos(optInvKitDet_key$=thisKey$)<>1 then break
					readrecord(optInvKitDet_dev)optInvKitDet$

					items$[1]=optInvKitDet.warehouse_id$
					items$[2]=optInvKitDet$.item_id$
					refs[0]=optInvKitDet.qty_ordered
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				wend
			endif
		else
			found_lot=0
			trip_key$=firm_id$+trans_status$+ar_type$+cust$+order$+invoice_no$+seq$
			read (ope_ordlsdet_dev, key=trip_key$,knum="AO_STAT_CUST_ORD",dom=*next)

			while 1
				this_key$=key(ope_ordlsdet_dev,end=*break)
				if pos(trip_key$=this_key$)<>1 then break
				read record (ope_ordlsdet_dev, end=*break) ope_ordlsdet$
				items$[3] = ope_ordlsdet.lotser_no$
				refs[0]   = ope_ordlsdet.qty_ordered
				if (action$="CO" and line_ship_date$<=user_tpl.def_commit$) or
:				(callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")="Y") then
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				endif
				found_lot=1
			wend

			if found_lot=0
				if (action$="CO" and line_ship_date$<=user_tpl.def_commit$) or
:				(callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG")="Y") then
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
				endif
			endif
		endif
	endif

	return

rem ==========================================================================
disable_by_linetype: rem --- Set enable/disable based on line type
	rem --- <<CALLPOINT>> enable in item#, memo, ordered and ext price on form handles enable/disable
	rem --- based strictly on line type, via the callpoint!.setStatus("ENABLE:"+opc_linecode.line_type$) command.
	rem --- cost, price, product type, backordered and shipped are enabled/disabled directly based on additional conditions
	rem      IN: line_code$
rem ==========================================================================

	file$ = "OPC_LINECODE"
	dim opc_linecode$:fnget_tpl$(file$)
	find record (fnget_dev(file$), key=firm_id$+line_code$, dom=*endif) opc_linecode$

	rem --- Shouldn't be possible to have a bad line_code$ at this point.
	rem --- If it happens, add error trap to send to OPE_INVDET.LINE_CODE.

	callpoint!.setStatus("ENABLE:"+opc_linecode.line_type$)
	user_tpl.line_type$     = opc_linecode.line_type$
	user_tpl.line_taxable$  = opc_linecode.taxable_flag$
	user_tpl.line_dropship$ = opc_linecode.dropship$
	user_tpl.line_prod_type_pr$ = opc_linecode.prod_type_pr$

	if pos(opc_linecode.line_type$="SP")>0 and num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))<>0 and
:	callpoint!.isEditMode() and (callpoint!.getDevObject("kit")<>"Y" or callpoint!.getDevObject("priced_kit")="Y") then
		callpoint!.setOptionEnabled("RCPR",1)
	else
		callpoint!.setOptionEnabled("RCPR",0)
	endif

rem --- Disable/enable WAREHOUSE_ID
	if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" then
		if user_tpl.line_dropship$="Y" then
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPE_INVDET.WAREHOUSE_ID",0)
		else
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPE_INVDET.WAREHOUSE_ID",1)
		endif
	endif

rem --- Disable/enable UM Sold
	if user_tpl.line_type$="N" then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPE_INVDET.UM_SOLD",1)
	else
		enable_UmSold=0
		if callpoint!.getDevObject("sell_purch_um")="Y" then
			item_id$=callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
			if pos(opc_linecode.line_type$="SP")>0 and cvs(item_id$,2)<>"" then
				ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
				dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
				readrecord(ivm_itemmast_dev,key=firm_id$+item_id$,dom=*endif)ivm_itemmast$
				if ivm_itemmast.sell_purch_um$="Y" then enable_UmSold=1
			endif
		endif
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPE_INVDET.UM_SOLD", enable_UmSold)
	endif

rem --- Disable/enable displayed unit price and quantity ordered
	if pos(user_tpl.line_type$="NSP") then
		if callpoint!.getDevObject("kit")<>"Y" or callpoint!.getDevObject("priced_kit")="Y" then
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", callpoint!.isEditMode())
		else
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 0)
		endif
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_ORDERED_DSP", callpoint!.isEditMode())
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_PRICE_DSP", 0)
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_ORDERED_DSP", 0)
	endif

rem --- Disable/enable unit cost (can't just enable/disable this field by line type)
	if pos(user_tpl.line_type$="NSP") = 0 then
		rem --- always disable cost if line type Memo or Other
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)
	else
		if user_tpl.line_dropship$ = "Y"
			if user_tpl.dropship_cost$ = "N" then
				rem --- if a drop-shippable line code, but enter codst on drop-ship param isn't set, disable, else enable cost
				callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)
			else
				callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 1)
			endif
		else
			if user_tpl.line_type$="N"
				rem --- always have cost enabled for Nonstock
				callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 1)
			else
				rem --- Standard or sPecial line
				rem --- note: when item id is entered, cost will get enabled in that AVAL if S or P and cost = 0 (or if dropshippable)
				callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.UNIT_COST_DSP", 0)
			endif
		endif
	endif

rem --- Product Type Processing

	if cvs(line_code$,2) <> "" 
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPE_INVDET.PRODUCT_TYPE", 0)
		if opc_linecode.prod_type_pr$ = "E" 
			callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"OPE_INVDET.PRODUCT_TYPE", 1)
		endif
	endif

rem --- Disable Back orders if necessary

	gosub able_backorder

rem --- Disable qty shipped if necessary

	gosub able_qtyshipped

rem --- Enable Comment button

	if callpoint!.isEditMode() then callpoint!.setOptionEnabled("COMM",1)

	return

rem ===========================================================================
check_item_whse: rem --- Check that a warehouse record exists for this item
                 rem      IN: wh$
                 rem          item$
                 rem          warn    (1=warn if failed, 0=no warning)
                 rem     OUT: user_tpl.item_wh_failed
                 rem          ivm02_dev
                 rem          ivm02a$ 
rem ===========================================================================

	user_tpl.item_wh_failed = 0
	this_row = callpoint!.getValidationRow()
	if callpoint!.getGridRowDeleteStatus(this_row) <> "Y" then
		if pos(user_tpl.line_type$="SP") then
			file$ = "IVM_ITEMWHSE"
			ivm02_dev = fnget_dev(file$)
			dim ivm02a$:fnget_tpl$(file$)
			user_tpl.item_wh_failed = 1

			if cvs(item$, 2) <> "" and cvs(wh$, 2) <> "" then
				find record (ivm02_dev, key=firm_id$+wh$+item$, knum="PRIMARY", dom=*endif) ivm02a$
				user_tpl.item_wh_failed = 0
			endif

			if user_tpl.item_wh_failed and warn then
				callpoint!.setMessage("IV_NO_WHSE_ITEM")
				callpoint!.setStatus("ABORT")
				callpoint!.setDevObject("whse_item_warned",wh$+":"+item$)
			endif
		endif
	endif

	return

rem ==========================================================================
clear_all_numerics: rem --- Clear all order detail numeric fields
rem ==========================================================================

		callpoint!.setColumnData("OPE_INVDET.UNIT_COST", "0")
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP","0",1)
		callpoint!.setColumnData("OPE_INVDET.UNIT_PRICE", "0")
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP","0",1)
		callpoint!.setColumnData("OPE_INVDET.QTY_ORDERED", "0")
		callpoint!.setColumnData("<<DISPLAY>>.QTY_ORDERED_DSP","0",1)
		callpoint!.setColumnData("OPE_INVDET.QTY_BACKORD", "0")
		callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP","0",1)
		callpoint!.setColumnData("OPE_INVDET.QTY_SHIPPED", "0")
		callpoint!.setColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP","0",1)
		callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC", "0")
		callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", "0",1)
		callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", "0")
		callpoint!.setColumnData("OPE_INVDET.DISC_PERCENT", "0")
		callpoint!.setColumnData("OPE_INVDET.COMM_PERCENT", "0")
		callpoint!.setColumnData("OPE_INVDET.COMM_AMT", "0")
		callpoint!.setColumnData("OPE_INVDET.SPL_COMM_PCT", "0")

return

rem ==========================================================================
enable_addl_opts: rem --- Enable the Additional Options button
rem ==========================================================================

	if user_tpl.line_type$ <> "M" then 
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		warn  = 0
		gosub check_item_whse

		if (!user_tpl.item_wh_failed and num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))) or
:		user_tpl.line_type$ = "O" and callpoint!.isEditMode() then
			callpoint!.setOptionEnabled("ADDL",1)
		else
			callpoint!.setOptionEnabled("ADDL",0)
		endif
	endif

	return

rem ==========================================================================
enable_repricing: rem --- Enable the Recalc Pricing button
rem ==========================================================================

	if pos(user_tpl.line_type$="SP") then 
		item$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		wh$   = callpoint!.getColumnData("OPE_INVDET.WAREHOUSE_ID")
		warn  = 0
		gosub check_item_whse

		if !user_tpl.item_wh_failed and num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP")) and 
:		callpoint!.isEditMode() and  (callpoint!.getDevObject("kit")<>"Y" or callpoint!.getDevObject("priced_kit")="Y") then
			callpoint!.setOptionEnabled("RCPR",1)
		else
			callpoint!.setOptionEnabled("RCPR",0)
		endif
	endif

	return

rem ==========================================================================
able_lot_button: rem --- Enable/disable Lot/Serial button
                 rem     OUT: lotted$
rem ==========================================================================

	item_id$   = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
	qty_ord = num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))
	gosub lot_ser_check

	if lotted$ = "Y" and qty_ord <> 0 and 
:	callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE")<>"P" and
:	callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "Y" and callpoint!.isEditMode()
:	then
		callpoint!.setOptionEnabled("LENT",1)
	else
		callpoint!.setOptionEnabled("LENT",0)
	endif

	return

rem ==========================================================================
able_kits_button: rem --- Enable/disable Kit Components KITS button
rem ==========================================================================

	if callpoint!.isEditMode() and callpoint!.getDevObject("kit")="Y" and
:	num(callpoint!.getColumnData("<<DISPLAY>>.QTY_ORDERED_DSP"))<>0 and
:	callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" and 
:	callpoint!.getGridRowModifyStatus(callpoint!.getValidationRow())<>"Y" then
		callpoint!.setOptionEnabled("KITS",1)
	else
		callpoint!.setOptionEnabled("KITS",0)
	endif

	return

rem ==========================================================================
lot_ser_check: rem --- Check for lotted item
               rem      IN: item_id$
               rem     OUT: lotted$ - Y/N
rem ==========================================================================

	lotted$="N"

	if cvs(item_id$, 2)<>"" 
		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		start_block = 1

		if start_block then
			read record (ivm01_dev, key=firm_id$+item_id$, dom=*endif) ivm01a$
			callpoint!.setDevObject("inventoried",ivm01a.inventoried$)

		rem --- In Invoice Entry, non-inventoried lotted/serial can enter lots

			if pos(ivm01a.lotser_flag$="LS") then 
				lotted$="Y"
				callpoint!.setDevObject("lotser_flag",ivm01a.lotser_flag$)
			endif
		endif
	endif

	return

rem ==========================================================================
disp_ext_amt: rem --- Calculate and display the extended amount
              rem      IN: qty_shipped
              rem          unit_price
              rem     OUT: ext_price set
rem ==========================================================================

	if pos(user_tpl.line_type$="NSP")
		rem --- Grid vector must be updated before updating Totals tab
		ext_price=round(qty_shipped * unit_price, 2)
		callpoint!.setColumnData("OPE_INVDET.EXT_PRICE", str(ext_price),1)
		declare BBjVector dtlVect!
		dtlVect!=cast(BBjVector, GridVect!.getItem(0))
		dim dtl_rec$:dtlg_param$[1,3]
		dtl_rec$=cast(BBjString, dtlVect!.getItem(callpoint!.getValidationRow()))
		dtl_rec.unit_price=unit_price
		dtl_rec.qty_shipped=qty_shipped
		dtl_rec.ext_price=ext_price
		dtlVect!.setItem(callpoint!.getValidationRow(),dtl_rec$)
		GridVect!.setItem(0,dtlVect!)
	endif

	gosub disp_grid_totals
	gosub check_if_tax
	if callpoint!.isEditMode() then callpoint!.setStatus("MODIFIED")

	return

rem ==========================================================================
set_item_taxable: rem --- Set the item taxable flag
rem ==========================================================================

	if pos(user_tpl.line_type$="SP") then
		item_id$ = callpoint!.getColumnData("OPE_INVDET.ITEM_ID")
		file$    = "IVM_ITEMMAST"
		dim itemmast$:fnget_tpl$(file$)
		start_block = 1

		if start_block then
			find record (fnget_dev(file$), key=firm_id$+item_id$, dom=*endif) itemmast$
			user_tpl.item_taxable$ = itemmast.taxable_flag$
		endif
	endif

	return

rem ==========================================================================
credit_exceeded: rem --- Credit Limit Exceeded (ope_cd, 5500-5599)
rem ==========================================================================

	if user_tpl.credit_limit <> 0 and !user_tpl.credit_limit_warned then
		msg_id$ = "OP_OVER_CREDIT_LIMIT"
		dim msg_tokens$[1]
		msg_tokens$[1] = str(user_tpl.credit_limit:user_tpl.amount_mask$)
		gosub disp_message
		callpoint!.setHeaderColumnData("<<DISPLAY>>.CREDIT_HOLD", Translate!.getTranslation("AON_***_OVER_CREDIT_LIMIT_***"))
		callpoint!.setDevObject("msg_exceeded","Y")
		user_tpl.credit_limit_warned = 1
		callpoint!.setStatus("ACTIVATE")
	endif

	return

rem ==========================================================================
able_backorder: rem --- All the factors for enabling or disabling back orders
rem ==========================================================================

	if user_tpl.allow_bo$ = "N" or 
:		pos(user_tpl.line_type$="MO") or
:		callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "N" or
:		callpoint!.getHeaderColumnData("OPE_INVHDR.CASH_SALE") = "Y"
:	then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP", 0)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_BACKORD_DSP", 1)

		rem if user_tpl.new_detail then...

		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow()) = "Y" then
			callpoint!.setColumnData("OPE_INVDET.QTY_BACKORD", "0")
			callpoint!.setColumnData("<<DISPLAY>>.QTY_BACKORD_DSP", "0")
		endif
	endif

	return

rem ==========================================================================
able_qtyshipped: rem --- All the factors for enabling or disabling qty shipped
rem ==========================================================================

	if pos(user_tpl.line_type$="NSP") and
:	callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "Y"
:	then
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP", 1)
	else
		callpoint!.setColumnEnabled(num(callpoint!.getValidationRow()),"<<DISPLAY>>.QTY_SHIPPED_DSP", 0)
	endif

    
	return

rem ==========================================================================
check_if_tax: rem --- Check If Taxable
rem ==========================================================================

	callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", "0")

	ordHelp! = cast(OrderHelper, callpoint!.getDevObject("order_helper_object"))
	creditRemaining = ordHelp!.getCreditLimit()-ordHelp!.getTotalAging()-ordHelp!.getOpenOrderAmount()-ordHelp!.getOpenBoAmount()-ordHelp!.getHeldOrderAmount()
	if num(callpoint!.getHeaderColumnData("<<DISPLAY>>.NET_SALES")) > creditRemaining then 
		gosub credit_exceeded
	endif

	if (user_tpl.line_taxable$ = "Y" and ( pos(user_tpl.line_type$ = "OMN") or user_tpl.item_taxable$ = "Y" )) or
: 	callpoint!.getDevObject("use_tax_service")="Y" then 
		callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT", callpoint!.getColumnData("OPE_INVDET.EXT_PRICE"))
	endif

	return

rem ==========================================================================
line_code_init: rem --- Initialize detail line for this line_code
rem ==========================================================================

	rem --- Set enable/disable based on line type
	gosub disable_by_linetype

	rem --- Has line code changed?
	if line_code$ <> user_tpl.prev_line_code$ then
		user_tpl.prev_line_code$=line_code$
		callpoint!.setColumnData("OPE_INVDET.MAN_PRICE", "N")
		callpoint!.setColumnData("OPE_INVDET.PRODUCT_TYPE", "")
		if cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" then
			if user_tpl.line_dropship$="Y" then
				user_tpl.warehouse_id$=callpoint!.getDevObject("dropship_whse")
			else
				if user_tpl.warehouse_id$=callpoint!.getDevObject("dropship_whse") then
					user_tpl.warehouse_id$ = callpoint!.getDevObject("defaultWhse")
				endif
			endif
		endif
		callpoint!.setColumnData("OPE_INVDET.WAREHOUSE_ID", user_tpl.warehouse_id$)
		callpoint!.setColumnData("OPE_INVDET.ITEM_ID", "")
		callpoint!.setColumnData("OPE_INVDET.EST_SHP_DATE", callpoint!.getHeaderColumnData("OPE_INVHDR.SHIPMNT_DATE"))
		callpoint!.setColumnData("OPE_INVDET.PICK_FLAG", "")
		callpoint!.setColumnData("OPE_INVDET.VENDOR_ID", "")
		callpoint!.setColumnData("OPE_INVDET.DROPSHIP", "")

		if callpoint!.getHeaderColumnData("OPE_INVHDR.INVOICE_TYPE") = "P" or 
:		callpoint!.getHeaderColumnData("OPE_INVHDR.SHIPMNT_DATE") > user_tpl.def_commit$ 
:		then
 			callpoint!.setColumnData("OPE_INVDET.COMMIT_FLAG", "N")
		else
			callpoint!.setColumnData("OPE_INVDET.COMMIT_FLAG", "Y")
	 	endif

		if opc_linecode.line_type$="O" then
			if cvs(callpoint!.getColumnData("OPE_INVDET.ORDER_MEMO"),3) = "" then
				callpoint!.setColumnData("OPE_INVDET.ORDER_MEMO",cvs(opc_linecode.code_desc$,3))
				callpoint!.setColumnData("OPE_INVDET.MEMO_1024",cvs(opc_linecode.code_desc$,3))
			endif
		endif

		rem --- Initialize UM_SOLD ListButton with a blank item for new rows except when line type is non-stock
		if callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())="Y" and opc_linecode.line_type$<>"N" then
			rem --- Skip if UM_SOLD ListButton is already initialized
			dtlGrid!=util.getGrid(Form!)
			col_hdr$=callpoint!.getTableColumnAttribute("OPE_INVDET.UM_SOLD","LABS")
			col_ref=util.getGridColumnNumber(dtlGrid!, col_hdr$)
			row=callpoint!.getValidationRow()
			umList!=null()
			umList!=dtlGrid!.getCellListControl(row,col_ref,err=*next)
			if umList!=null() then
				nxt_ctlID=util.getNextControlID()
				umList!=Form!.addListButton(nxt_ctlID,10,10,100,100,"",$0810$)
				umList!.addItem("")
				dtlGrid!.setCellListControl(row,col_ref,umList!)
				dtlGrid!.setCellListSelection(row,col_ref,0,0)
			endif
		endif

		gosub clear_all_numerics
		gosub clear_avail
		user_tpl.item_wh_failed = 1
	endif

	rem --- set Product Type if indicated by line code record
	if opc_linecode.prod_type_pr$ = "D" 
		callpoint!.setColumnData("OPE_INVDET.PRODUCT_TYPE", opc_linecode.product_type$)
	endif	
	if opc_linecode.prod_type_pr$ = "N"
		callpoint!.setColumnData("OPE_INVDET.PRODUCT_TYPE", "")
	endif

	return

rem ==========================================================================
comment_entry:
rem --- on a line where you can access the memo/non-stock (order_memo) field, pop the new memo_1024 editor instead
rem --- the editor can be popped on demand for any line using the Comments button (alt-C),
rem --- but will automatically pop for lines where the order_memo field is enabled.
rem ==========================================================================

	disp_text$=callpoint!.getColumnData("OPE_INVDET.MEMO_1024")
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
		memo_len=len(callpoint!.getColumnData("OPE_INVDET.ORDER_MEMO"))
		order_memo$=disp_text$
		order_memo$=order_memo$(1,min(memo_len,(pos($0A$=order_memo$+$0A$)-1)))

		callpoint!.setColumnData("OPE_INVDET.MEMO_1024",disp_text$)
		callpoint!.setColumnData("OPE_INVDET.ORDER_MEMO",order_memo$,1)

		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE")

	return

rem =========================================================
check_ship_qty: rem --- Warn if ship quantity is more than currently available.
rem =========================================================
	if callpoint!.getColumnData("OPE_INVDET.COMMIT_FLAG") = "Y" and user_tpl.line_type$ <> "N" and
:	user_tpl.line_dropship$ <> "Y" and callpoint!.getDevObject("warn_not_avail")="Y" and callpoint!.getDevObject("kit")<>"Y" then
		conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
		if conv_factor=0 then
			conv_factor=1
			callpoint!.setColumnData("OPE_INVDET.CONV_FACTOR",str(conv_factor))
		endif

		shipqty=num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))*conv_factor
		prev_available=num(userObj!.getItem(user_tpl.avail_avail).getText())
		curr_available=prev_available+callpoint!.getDevObject("prior_qty")
		if shipqty>curr_available then
			msg_id$="SHIP_EXCEEDS_AVAIL"
			gosub disp_message
			callpoint!.setStatus("ACTIVATE")
		endif
	endif
	return

rem =========================================================
getKitExtendedPrice: rem --- Get a non-priced kit's extended price based on the sum of its standard components' extended price.
	rem    IN:	round_precision
	rem 		bmmBillMat_dev
	rem  	bmmBillMat$
	rem  	ivm01_dev
	rem  	ivm01a$
	rem		kitDetailLine$
	rem		kit_item$
	rem		kit_ordered
	rem		kitExtendedPrice
	rem OUT:	kitExtendedPrice
rem =========================================================
	if callpoint!.getDevObject("priced_kit")="Y" then return

	rem --- Explode this non-priced kit to get it's standard extended price
	read(bmmBillMat_dev,key=firm_id$+kit_item$,dom=*next)
	while 1
		kitKey$=key(bmmBillMat_dev,end=*break)
		if pos(firm_id$+kit_item$=kitKey$)<>1 then break
		readrecord(bmmBillMat_dev)bmmBillMat$
		if cvs(bmmBillMat.effect_date$,2)<>"" and sysinfo.system_date$<bmmBillMat.effect_date$ then continue
		if cvs(bmmBillMat.obsolt_date$,2)<>"" and sysinfo.system_date$>=bmmBillMat.obsolt_date$ then continue
		redim ivm01a$
		readrecord(ivm01_dev,key=firm_id$+bmmBillMat.item_id$,dom=*next)ivm01a$
		if ivm01a.kit$="Y" then
			rem --- Non-priced kit
			explodeKey$=kitKey$
			explodeItem$=kit_item$
			explodeOrdered=kit_ordered
			kit_item$=bmmBillMat.item_id$
			kit_ordered=round(explodeOrdered*bmmBillMat.qty_required,round_precision)
			gosub getKitExtendedPrice

			read(bmmBillMat_dev,key=explodeKey$)
			kit_item$=explodeItem$
			kit_ordered=explodeOrdered
			continue
		endif

		qty_ordered=round(kit_ordered*bmmBillMat.qty_required,round_precision)
		dim pc_files[6]
		pc_files[1] = fnget_dev("IVM_ITEMMAST")
		pc_files[2] = fnget_dev("IVM_ITEMWHSE")
		pc_files[3] = fnget_dev("IVM_ITEMPRIC")
		pc_files[4] = fnget_dev("IVC_PRICCODE")
		pc_files[5] = fnget_dev("ARS_PARAMS")
		pc_files[6] = fnget_dev("IVS_PARAMS")
		call stbl("+DIR_PGM")+"opc_pricing.aon",
:			pc_files[all],
:			firm_id$,
:			kitDetailLine.warehouse_id$,
:			bmmBillMat.item_id$,
:			str(callpoint!.getDevObject("priceCode")),
:			kitDetailLine.customer_id$,
:			str(callpoint!.getDevObject("orderDate")),
:			str(callpoint!.getDevObject("pricingCode")),
:			qty_ordered,
:			typeflag$,
:			price,
:			disc,
:			status
		if status=999 then
			typeflag$="N"
			price=0
			disc=0
		endif
		unit_price=price

		ext_price=round(qty_ordered * unit_price, 2)
		kitExtendedPrice=kitExtendedPrice+ext_price
	wend

	return

rem =========================================================
explodeKit: rem --- Explode kit
	rem    IN:	bmmBillMat_dev
	rem  	bmmBillMat$
	rem  	ivm01_dev
	rem  	ivm01a$
	rem   	ivm02_dev
	rem   	ivm02a$
	rem		optInvKitDet_dev
	rem		optInvKitDet$
	rem		kitDetailLine$
	rem		kit_item$
	rem		kit_ordered
	rem 		kit_shipped
	rem		nextLineNo
	rem 		qty_mask$
	rem 		ivIMask$
	rem 		lineMask$
	rem		shortage_vect!
	rem  OUT: shortage_vect!
rem =========================================================
	round_precision = num(callpoint!.getDevObject("precision"))

	rem --- Explode this kit
	read(bmmBillMat_dev,key=firm_id$+kit_item$,dom=*next)
	while 1
		kitKey$=key(bmmBillMat_dev,end=*break)
		if pos(firm_id$+kit_item$=kitKey$)<>1 then break
		readrecord(bmmBillMat_dev)bmmBillMat$
		if cvs(bmmBillMat.effect_date$,2)<>"" and sysinfo.system_date$<bmmBillMat.effect_date$ then continue
		if cvs(bmmBillMat.obsolt_date$,2)<>"" and sysinfo.system_date$>=bmmBillMat.obsolt_date$ then continue
		redim ivm01a$
		readrecord(ivm01_dev,key=firm_id$+bmmBillMat.item_id$,dom=*next)ivm01a$
		if pos(ivm01a.kit$="YP") then
			explodeKey$=kitKey$
			explodeItem$=kit_item$
			explodeOrdered=kit_ordered
			explodeShipped=kit_shipped
			kit_item$=bmmBillMat.item_id$
			kit_ordered=round(explodeOrdered*bmmBillMat.qty_required,round_precision)
			kit_shipped=round(explodeShipped*bmmBillMat.qty_required,round_precision)
			gosub explodeKit

			read(bmmBillMat_dev,key=explodeKey$)
			kit_item$=explodeItem$
			kit_ordered=explodeOrdered
			kit_shipped=explodeShipped
			continue
		endif

		redim optInvKitDet$
		optInvKitDet.firm_id$=kitDetailLine.firm_id$
		optInvKitDet.ar_type$=kitDetailLine.ar_type$
		optInvKitDet.customer_id$=kitDetailLine.customer_id$
		optInvKitDet.order_no$=kitDetailLine.order_no$
		optInvKitDet.ar_inv_no$=kitDetailLine.ar_inv_no$
		optInvKitDet.orddet_seq_ref$=kitDetailLine.internal_seq_no$
		call stbl("+DIR_SYP")+"bas_sequences.bbj", "INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
		optInvKitDet.internal_seq_no$=int_seq_no$

		optInvKitDet.line_no$=str(nextLineNo:lineMask$)
		nextLineNo=nextLineNo+1
		optInvKitDet.trans_status$="E"
		optInvKitDet.line_code$=kitDetailLine.line_code$
		optInvKitDet.kit_id$=kitDetailLine.item_id$
		optInvKitDet.warehouse_id$=kitDetailLine.warehouse_id$
		optInvKitDet.item_id$=bmmBillMat.item_id$
		optInvKitDet.product_type$=ivm01a.product_type$
		optInvKitDet.um_sold$=ivm01a.unit_of_sale$
		optInvKitDet.est_shp_date$=kitDetailLine.est_shp_date$
		optInvKitDet.commit_flag$=kitDetailLine.commit_flag$
		optInvKitDet.pick_flag$=""
		optInvKitDet.man_price$=kitDetailLine.man_price$
		optInvKitDet.vendor_id$=""
		optInvKitDet.dropship$=""

		item$=cvs(fnmask$(optInvKitDet.kit_id$,ivIMask$),3)
		itemDescLen!=callpoint!.getDevObject("itemDescLen")
		itemDesc$=fnitem$(callpoint!.getDevObject("kitDesc"),itemDescLen!.getItem(0),itemDescLen!.getItem(1),itemDescLen!.getItem(2))
		optInvKitDet.memo_1024$=Translate!.getTranslation("AON_KIT","Kit")+": "+item$+" "+itemDesc$
		optInvKitDet.order_memo$=optInvKitDet.memo_1024$

		optInvKitDet.created_user$=kitDetailLine.created_user$
		optInvKitDet.created_date$=kitDetailLine.created_date$
		optInvKitDet.created_time$=kitDetailLine.created_time$
		optInvKitDet.mod_user$=kitDetailLine.mod_user$
		optInvKitDet.mod_date$=kitDetailLine.mod_date$
		optInvKitDet.mod_time$=kitDetailLine.mod_time$
		optInvKitDet.arc_user$=kitDetailLine.arc_user$
		optInvKitDet.arc_date$=kitDetailLine.arc_date$
		optInvKitDet.arc_time$=kitDetailLine.arc_time$
		optInvKitDet.batch_no$=kitDetailLine.batch_no$
		optInvKitDet.audit_number=kitDetailLine.audit_number
		if optInvKitDet.um_sold$=ivm01a.purchase_um$ then
			optInvKitDet.conv_factor=ivm01a.conv_factor
		else
			optInvKitDet.conv_factor=1
		endif
		optInvKitDet.comp_per_kit=bmmBillMat.qty_required*kit_ordered/kitDetailLine.qty_ordered

		redim ivm02a$
		readrecord(ivm02_dev,key=firm_id$+optInvKitDet.warehouse_id$+optInvKitDet.item_id$,dom=*next)ivm02a$
		optInvKitDet.unit_cost=ivm02a.unit_cost
		optInvKitDet.qty_ordered=round(kit_ordered*bmmBillMat.qty_required,round_precision)

		dim pc_files[6]
		pc_files[1] = fnget_dev("IVM_ITEMMAST")
		pc_files[2] = fnget_dev("IVM_ITEMWHSE")
		pc_files[3] = fnget_dev("IVM_ITEMPRIC")
		pc_files[4] = fnget_dev("IVC_PRICCODE")
		pc_files[5] = fnget_dev("ARS_PARAMS")
		pc_files[6] = fnget_dev("IVS_PARAMS")
		call stbl("+DIR_PGM")+"opc_pricing.aon",
:			pc_files[all],
:			firm_id$,
:			optInvKitDet.warehouse_id$,
:			optInvKitDet.item_id$,
:			str(callpoint!.getDevObject("priceCode")),
:			kitDetailLine.customer_id$,
:			str(callpoint!.getDevObject("orderDate")),
:			str(callpoint!.getDevObject("pricingCode")),
:			optInvKitDet.qty_ordered,
:			typeflag$,
:			price,
:			disc,
:			status
		if status=999 then
			typeflag$="N"
			price=0
			disc=0
		endif
		if callpoint!.getDevObject("priced_kit")="Y" then
			price=0
			disc=0
		endif
		optInvKitDet.unit_price=price

		optInvKitDet.qty_shipped=round(kit_shipped*bmmBillMat.qty_required,round_precision)
		optInvKitDet.qty_backord=optInvKitDet.qty_ordered-optInvKitDet.qty_shipped
		optInvKitDet.std_list_prc=ivm02a.cur_price
		optInvKitDet.ext_price=round(optInvKitDet.qty_shipped * optInvKitDet.unit_price, 2)

		if (user_tpl.line_taxable$="Y" and ivm01a.taxable_flag$="Y") or callpoint!.getDevObject("use_tax_service")="Y" then 
			optInvKitDet.taxable_amt=optInvKitDet.ext_price
		else
			optInvKitDet.taxable_amt=0
		endif
		optInvKitDet.disc_percent=disc
		optInvKitDet.comm_percent=0
		optInvKitDet.comm_amt=0
		optInvKitDet.spl_comm_pct=0

		writerecord(optInvKitDet_dev)optInvKitDet$

		rem --- Commit inventory for this component
		if optInvKitDet.commit_flag$="Y" then
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

			items$[1]=optInvKitDet.warehouse_id$
			items$[2]=optInvKitDet.item_id$
			refs[0]=optInvKitDet.qty_ordered
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon","CO",channels[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
		endif

		rem --- Warn if ship quantity is more than currently available.
		shipqty=optInvKitDet.qty_shipped
		available=ivm02a.qty_on_hand-ivm02a.qty_commit; rem --- Note: ivm_itemwhse record read BEFORE this component was committed
		if shipqty>available then
			available_vect!=BBjAPI().makeVector()
			available_vect!.addItem(optInvKitDet.item_id$)
			available_vect!.addItem(shipqty)
			available_vect!.addItem(available)
			shortage_vect!.addItem(available_vect!)
			callpoint!.setDevObject("shortageVect",shortage_vect!)
		endif
	wend

	return

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
			kit_id$=cvs(callpoint!.getColumnData("OPE_INVDET.ITEM_ID"),3)
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

rem =========================================================
updateKitTotals: rem --- Update non-priced kit detail row with totals for the sum of its components
	rem    IN:	key_pfx$
rem =========================================================
	if callpoint!.getDevObject("priced_kit")="Y" then return

	optInvKitDet_dev=fnget_dev("OPT_INVKITDET")
	dim optInvKitDet$:fnget_tpl$("OPT_INVKITDET")

	total_cost=0
	total_unit_price=0
	total_list_price=0
	total_ext_price=0
	total_taxable_amt=0
	total_disc_percent=0
	total_comm_percent=0
	total_comm_amt=0
	manual_priced$="N"

	read(optInvKitDet_dev,key=key_pfx$,knum="AO_STAT_CUST_ORD",dom=*next)
	while 1
		thisKey$=key(optInvKitDet_dev,end=*break)
		if pos(key_pfx$=thisKey$)<>1 then break
		readrecord(optInvKitDet_dev)optInvKitDet$

		total_cost=total_cost+optInvKitDet.unit_cost*optInvKitDet.qty_ordered
		total_unit_price=total_unit_price+optInvKitDet.unit_price*optInvKitDet.qty_ordered
		total_list_price=total_list_price+optInvKitDet.std_list_prc*optInvKitDet.qty_ordered
		total_ext_price=total_ext_price+optInvKitDet.ext_price
		total_taxable_amt=total_taxable_amt+optInvKitDet.taxable_amt
		total_comm_amt=total_comm_amt+optInvKitDet.comm_amt
		if optInvKitDet.man_price$="Y" then manual_priced$="Y"
	wend

	if total_list_price then
		kit_disc_percent=round(100 - total_unit_price * 100 /total_list_price, 2)
	else
		kit_disc_percent=0
	endif
	if total_ext_price then
		kit_comm_percent=round(100 * total_comm_amt/total_ext_price,2)
	else
		kit_comm_percent=0
	endif
	kit_spl_comm_pct=kit_comm_percent

	conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
	if conv_factor=0 then
		conv_factor=1
		callpoint!.setColumnData("OPE_INVDET.CONV_FACTOR",str(conv_factor))
	endif
	kit_unit_cost=round(total_cost/num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED")),4)
	callpoint!.setColumnData("OPE_INVDET.UNIT_COST",str(kit_unit_cost))
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_COST_DSP",str(round(kit_unit_cost*conv_factor,4)),1)
	kit_unit_price=round(total_unit_price/num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED")),2)
	callpoint!.setColumnData("OPE_INVDET.UNIT_PRICE",str(kit_unit_price))
	callpoint!.setColumnData("<<DISPLAY>>.UNIT_PRICE_DSP",str(round(kit_unit_price*conv_factor,2)),1)
	kit_list_price=round(total_list_price/num(callpoint!.getColumnData("OPE_INVDET.QTY_ORDERED")),2)
	callpoint!.setColumnData("OPE_INVDET.EXT_PRICE",str(total_ext_price),1)

	callpoint!.setColumnData("OPE_INVDET.STD_LIST_PRC",str(kit_list_price))
	callpoint!.setColumnData("OPE_INVDET.TAXABLE_AMT",str(total_taxable_amt))
	callpoint!.setColumnData("OPE_INVDET.DISC_PERCENT",str(kit_disc_percent))
	callpoint!.setColumnData("OPE_INVDET.COMM_PERCENT",str(kit_comm_percent))
	callpoint!.setColumnData("OPE_INVDET.COMM_AMT",str(total_comm_amt))
	callpoint!.setColumnData("OPE_INVDET.SPL_COMM_PCT",str(kit_spl_comm_pct))
	callpoint!.setColumnData("OPE_INVDET.MAN_PRICE",manual_priced$)

	rem --- Grid vector must be updated before updating Totals tab
	declare BBjVector dtlVect!
	dtlVect!=cast(BBjVector, GridVect!.getItem(0))
	dim dtl_rec$:dtlg_param$[1,3]
	dtl_rec$=cast(BBjString, dtlVect!.getItem(callpoint!.getValidationRow()))
	dtl_rec.conv_factor=num(callpoint!.getColumnData("OPE_INVDET.CONV_FACTOR"))
	dtl_rec.unit_cost=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_COST_DSP"))
	dtl_rec.unit_price=num(callpoint!.getColumnData("<<DISPLAY>>.UNIT_PRICE_DSP"))
	dtl_rec.std_list_prc=num(callpoint!.getColumnData("OPE_INVDET.STD_LIST_PRC"))
	dtl_rec.ext_price=num(callpoint!.getColumnData("OPE_INVDET.EXT_PRICE"))
	dtl_rec.taxable_amt=num(callpoint!.getColumnData("OPE_INVDET.TAXABLE_AMT"))
	dtl_rec.disc_percent=num(callpoint!.getColumnData("OPE_INVDET.DISC_PERCENT"))
	dtl_rec.comm_percent=num(callpoint!.getColumnData("OPE_INVDET.COMM_PERCENT"))
	dtl_rec.comm_amt=num(callpoint!.getColumnData("OPE_INVDET.COMM_AMT"))
	dtl_rec.spl_comm_pct=num(callpoint!.getColumnData("OPE_INVDET.SPL_COMM_PCT"))
	dtl_rec.man_price$=manual_priced$
	dtlVect!.setItem(callpoint!.getValidationRow(),dtl_rec$)
	GridVect!.setItem(0,dtlVect!)

	qty_shipped=round(num(callpoint!.getColumnData("<<DISPLAY>>.QTY_SHIPPED_DSP"))*conv_factor,2)
	unit_price=round(kit_unit_price*conv_factor,4)
	gosub disp_ext_amt
	gosub manual_price_flag

	return

rem ==========================================================================
#include [+ADDON_LIB]std_missing_params.aon
rem ==========================================================================

rem ==========================================================================
rem 	Use util object
rem ==========================================================================

	use java.util.HashMap
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



