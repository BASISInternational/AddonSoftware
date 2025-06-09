[[POE_ROGHDR.ADIS]]
rem --- Display Vendor Purchase Address
	gosub vend_purchase_addr

rem --- For inventoried lot/serial items, item qty_returned must equal sum of lot/serial items qty_returned.
	poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
	dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

	po_no$=callpoint!.getColumnData("POE_ROGHDR.PO_NO")
	receiver_no$=callpoint!.getColumnData("POE_ROGHDR.RECEIVER_NO")
	return_date$=callpoint!.getColumnData("POE_ROGHDR.RETURN_DATE")
	return_auth$=callpoint!.getColumnData("POE_ROGHDR.RETURN_AUTH")

	dim gridrec$:fnget_tpl$("POE_ROGDET")
	rowData!=cast(BBjVector,GridVect!.getItem(0))
	for curr_row=0 to rowData!.size()-1
		gridrec$=rowData!.getItem(curr_row)
		item_id$=gridrec.item_id$
		gosub lot_ser_check
		if lotser_item$="Y" then
			lotser_returned=0
			trip_key$=firm_id$+po_no$+receiver_no$+return_date$+pad(return_auth$,15)+gridrec.rec_int_seq_ref$
			read(poe_roglsdet_dev,key=trip_key$,knum="PRIMARY",dom=*next)
			while 1
				poe_roglsdet_key$=key(poe_roglsdet_dev,end=*break)
				if pos(trip_key$=poe_roglsdet_key$)<>1 then break
				readrecord(poe_roglsdet_dev)poe_roglsdet$
				lotser_returned=lotser_returned+poe_roglsdet.qty_returned
			wend

			qty_returned=gridrec.qty_returned
			if lotser_returned<>qty_returned then
				msg_id$="PO_ROG_LSQTY_WARN1"
				dim msg_tokens$[2]
				msg_tokens$[1]=str(qty_returned)
				msg_tokens$[2]=str(lotser_returned)
				gosub disp_message

				rem --- Show problem qty_returned in bold red
				curr_row=num(gridrec.line_no$)-1
				qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

				grid! = util.getGrid(Form!)
				grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("boldFont"))
				grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("redColor"))
			else
				rem --- Reset color and font for qty_returned
				qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

				grid! = util.getGrid(Form!)
				grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("plainFont"))
				grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("blackColor"))
			endif
		endif
	next curr_row

[[POE_ROGHDR.ARAR]]
rem --- Display Vendor Purchase Address
	gosub vend_purchase_addr

[[POE_ROGHDR.AREC]]
rem --- Initialize Return Date
	callpoint!.setColumnData("POE_ROGHDR.RETURN_DATE",sysinfo.system_date$,1)

[[POE_ROGHDR.ARNF]]
rem --- Write POE_ROGHDR, POE_ROGDET and POE_ROGLSDET records for the entered Receiver
	po_no$=callpoint!.getColumnData("POE_ROGHDR.PO_NO")
	receiver_no$=callpoint!.getColumnData("POE_ROGHDR.RECEIVER_NO")
	return_date$=callpoint!.getColumnData("POE_ROGHDR.RETURN_DATE")
	return_auth$=callpoint!.getColumnData("POE_ROGHDR.RETURN_AUTH")
	vendor_id$=callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")
	purch_addr$=callpoint!.getColumnData("POE_ROGHDR.PURCH_ADDR")

	poe_roghdr_dev=fnget_dev("POE_ROGHDR")
	dim poe_roghdr$:fnget_tpl$("POE_ROGHDR")
	poe_roghdr.firm_id$=firm_id$
	poe_roghdr.po_no$=po_no$
	poe_roghdr.receiver_no$=receiver_no$
	poe_roghdr.return_date$=return_date$
	poe_roghdr.return_auth$=return_auth$
	poe_roghdr.vendor_id$=vendor_id$
	poe_roghdr.purch_addr$=purch_add$
	poe_roghdr$=field(poe_roghdr$)
	writerecord(poe_roghdr_dev)poe_roghdr$

	poc_LineCode_dev=fnget_dev("POC_LINECODE")
	dim poc_LineCode$:fnget_tpl$("POC_LINECODE")
	poe_rechdr_dev=fnget_dev("POE_RECHDR")
	dim poe_rechdr$:fnget_tpl$("POE_RECHDR")
	recordFound=0
	find(poe_rechdr_dev,key=firm_id$+receiver_no$,knum="PRIMARY",dom=*next); recordFound=1
	if recordFound then
		rem --- Receiver is in entry
		poe_recdet_dev=fnget_dev("POE_RECDET")
		dim poe_recdet$:fnget_tpl$("POE_RECDET")
		poe_reclsdet_dev=fnget_dev("POE_RECLSDET")
		dim poe_reclsdet$:fnget_tpl$("POE_RECLSDET")
		poe_rogdet_dev=fnget_dev("POE_ROGDET")
		dim poe_rogdet$:fnget_tpl$("POE_ROGDET")
		poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
		dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

		read(poe_recdet_dev,key=firm_id$+receiver_no$,dom=*next)
		while 1
			poe_recdet_key$=key(poe_recdet_dev,end=*break)
			if pos(firm_id$+receiver_no$=poe_recdet_key$)<>1 then break
			readrecord(poe_recdet_dev)poe_recdet$

			rem --- Must be S, N or O line type
			findrecord(poc_LineCode_dev,key=firm_id$+poe_recdet.po_line_code$,dom=*continue)poc_LineCode$
			if pos(poc_LineCode.line_type$="SN")=0 then continue

			redim poe_rogdet$
			poe_rogdet.firm_id$=poe_recdet.firm_id$
			poe_rogdet.po_no$=poe_recdet.po_no$
			poe_rogdet.receiver_no$=poe_recdet.receiver_no$
			poe_rogdet.return_date$=return_date$
			poe_rogdet.return_auth$=return_auth$
			poe_rogdet.rec_int_seq_ref$=poe_recdet.internal_seq_no$
			poe_rogdet.line_no$=poe_recdet.po_line_no$
			poe_rogdet.line_code$=poe_recdet.po_line_code$
			poe_rogdet.warehouse_id$=poe_recdet.warehouse_id$
			poe_rogdet.item_id$=poe_recdet.item_id$
			poe_rogdet.ns_item_id$=poe_recdet.ns_item_id$
			poe_rogdet.order_memo$=poe_recdet.order_memo$
			poe_rogdet.memo_1024$=poe_recdet.memo_1024$
			poe_rogdet.return_reason$=""
			poe_rogdet.unit_measure$=poe_recdet.unit_measure$
			poe_rogdet.conv_factor=poe_recdet.conv_factor
			poe_rogdet.qty_ordered=poe_recdet.qty_ordered
			poe_rogdet.qty_prev_rec=poe_recdet.qty_prev_rec
			poe_rogdet.qty_received=poe_recdet.qty_received
			poe_rogdet.qty_returned=0
			poe_rogdet.replace_qty=0
			poe_rogdet$=field(poe_rogdet$)
			writerecord(poe_rogdet_dev)poe_rogdet$

			read(poe_reclsdet_dev,key=firm_id$+receiver_no$+poe_recdet.internal_seq_no$,dom=*next)
			while 1
				poe_reclsdet_key$=key(poe_reclsdet_dev,end=*break)
				if pos(firm_id$+receiver_no$+poe_recdet.internal_seq_no$=poe_reclsdet_key$)<>1 then break
				readrecord(poe_reclsdet_dev)poe_reclsdet$
				redim poe_roglsdet$
				poe_roglsdet.firm_id$=poe_reclsdet.firm_id$
				poe_roglsdet.po_no$=poe_reclsdet.po_no$
				poe_roglsdet.receiver_no$=poe_reclsdet.receiver_no$
				poe_roglsdet.return_date$=return_date$
				poe_roglsdet.return_auth$=return_auth$
				poe_roglsdet.rec_int_seq_ref$=poe_recdet.internal_seq_no$
				poe_roglsdet.sequence_no$=poe_reclsdet.sequence_no$
				poe_roglsdet.warehouse_id$=poe_recdet.warehouse_id$
				poe_roglsdet.item_id$=poe_recdet.item_id$
				poe_roglsdet.lotser_no$=poe_reclsdet.lotser_no$
				poe_roglsdet.qty_prev_rec=0
				poe_roglsdet.qty_received=poe_reclsdet.qty_received
				poe_roglsdet.qty_returned=0
				poe_roglsdet$=field(poe_roglsdet$)
				writerecord(poe_roglsdet_dev)poe_roglsdet$
			wend
		wend
	else
		rem --- Receiver not in entry so check history for it
		pot_recdet_dev=fnget_dev("POT_RECDET")
		dim pot_recdet$:fnget_tpl$("POT_RECDET")
		pot_reclsdet_dev=fnget_dev("POT_RECLSDET")
		dim pot_reclsdet$:fnget_tpl$("POT_RECLSDET")
		poe_rogdet_dev=fnget_dev("POE_ROGDET")
		dim poe_rogdet$:fnget_tpl$("POE_ROGDET")
		poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
		dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

		read(pot_recdet_dev,key=firm_id$+po_no$+receiver_no$,dom=*next)
		while 1
			pot_recdet_key$=key(pot_recdet_dev,end=*break)
			if pos(firm_id$+po_no$+receiver_no$=pot_recdet_key$)<>1 then break
			readrecord(pot_recdet_dev)pot_recdet$

			rem --- Must be S, N or O line type
			findrecord(poc_LineCode_dev,key=firm_id$+pot_recdet.po_line_code$,dom=*continue)poc_LineCode$
			if pos(poc_LineCode.line_type$="SN")=0 then continue

			redim poe_rogdet$
			poe_rogdet.firm_id$=pot_recdet.firm_id$
			poe_rogdet.po_no$=pot_recdet.po_no$
			poe_rogdet.receiver_no$=pot_recdet.receiver_no$
			poe_rogdet.return_date$=return_date$
			poe_rogdet.return_auth$=return_auth$
			poe_rogdet.rec_int_seq_ref$=pot_recdet.po_int_seq_ref$
			poe_rogdet.line_no$=pot_recdet.po_line_no$
			poe_rogdet.line_code$=pot_recdet.po_line_code$
			poe_rogdet.warehouse_id$=pot_recdet.warehouse_id$
			poe_rogdet.item_id$=pot_recdet.item_id$
			poe_rogdet.ns_item_id$=pot_recdet.ns_item_id$
			poe_rogdet.order_memo$=pot_recdet.order_memo$
			poe_rogdet.memo_1024$=pot_recdet.memo_1024$
			poe_rogdet.return_reason$=""
			poe_rogdet.unit_measure$=pot_recdet.unit_measure$
			poe_rogdet.conv_factor=pot_recdet.conv_factor
			poe_rogdet.qty_ordered=pot_recdet.qty_ordered
			poe_rogdet.qty_prev_rec=pot_recdet.qty_prev_rec
			poe_rogdet.qty_received=pot_recdet.qty_received
			poe_rogdet.qty_returned=0
			poe_rogdet$=field(poe_rogdet$)
			poe_rogdet.replace_qty=0
			writerecord(poe_rogdet_dev)poe_rogdet$

			read(pot_reclsdet_dev,key=firm_id$+receiver_no$+pot_recdet.po_int_seq_ref$,dom=*next)
			while 1
				pot_reclsdet_key$=key(pot_reclsdet_dev,end=*break)
				if pos(firm_id$+receiver_no$+pot_recdet.po_int_seq_ref$=pot_reclsdet_key$)<>1 then break
				readrecord(pot_reclsdet_dev)pot_reclsdet$
				redim poe_roglsdet$
				poe_roglsdet.firm_id$=pot_reclsdet.firm_id$
				poe_roglsdet.po_no$=pot_reclsdet.po_no$
				poe_roglsdet.receiver_no$=pot_reclsdet.receiver_no$
				poe_roglsdet.return_date$=return_date$
				poe_roglsdet.return_auth$=return_auth$
				poe_roglsdet.rec_int_seq_ref$=pot_recdet.po_int_seq_ref$
				poe_roglsdet.sequence_no$=pot_reclsdet.sequence_no$
				poe_roglsdet.warehouse_id$=pot_recdet.warehouse_id$
				poe_roglsdet.item_id$=pot_recdet.item_id$
				poe_roglsdet.lotser_no$=pot_reclsdet.lotser_no$
				poe_roglsdet.qty_prev_rec=0
				poe_roglsdet.qty_received=pot_reclsdet.qty_received
				poe_roglsdet.qty_returned=0
				poe_roglsdet$=field(poe_roglsdet$)
				writerecord(poe_roglsdet_dev)poe_roglsdet$
			wend
		wend
	endif

rem --- Relaunch form with all the initialized data
	rec_key$=poe_roghdr.firm_id$+poe_roghdr.po_no$+poe_roghdr.receiver_no$+poe_roghdr.return_date$+poe_roghdr.return_auth$
	callpoint!.setStatus("RECORD:["+rec_key$+"]")

[[POE_ROGHDR.ASHO]]
rem --- Set up a color and font to be used when qty returned is NOT equal to the sum of lot/serial number qty returned
	grid! = util.getGrid(Form!)
	plainFont!=grid!.getRowFont(0)
	boldFont!=sysGUI!.makeFont(plainFont!.getName(),plainFont!.getSize(),1);rem bold
	callpoint!.setDevObject("plainFont",plainFont!)
	callpoint!.setDevObject("boldFont",boldFont!)

	RGB$="255,0,0"
	gosub get_RGB
	callpoint!.setDevObject("redColor",BBjAPI().getSysGui().makeColor(R,G,B))

	RGB$="0,0,0"
	gosub get_RGB
	callpoint!.setDevObject("blackColor",BBjAPI().getSysGui().makeColor(R,G,B))

[[POE_ROGHDR.BDEL]]
rem --- Delete POE_ROGDET and POE_ROGLSDET records when the POE_ROGHDR record is deleted
	poe_roghdr_dev=fnget_dev("POE_ROGHDR")
	poe_rogdet_dev=fnget_dev("POE_ROGDET")
	poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
	dim poe_roghdr$:fnget_tpl$("POE_ROGHDR")
	dim poe_rogdet$:fnget_tpl$("POE_ROGDET")

	po_no$=callpoint!.getColumnData("POE_ROGHDR.PO_NO")
	receiver_no$=callpoint!.getColumnData("POE_ROGHDR.RECEIVER_NO")
	return_date$=callpoint!.getColumnData("POE_ROGHDR.RETURN_DATE")
	poe_roghdr.return_auth$=callpoint!.getColumnData("POE_ROGHDR.RETURN_AUTH")
	poe_roghdr_key$=firm_id$+po_no$+receiver_no$+return_date$+poe_roghdr.return_auth$

	rem --- Remove POE_ROGDET records
	read(poe_rogdet_dev,key=poe_roghdr_key$,dom=*next)
	while 1
		poe_rogdet_key$=key(poe_rogdet_dev,end=*break)
		if pos(poe_roghdr_key$=poe_rogdet_key$)<>1 then break

		rem --- Remove POE_ROGLSDET records
		read(poe_roglsdet_dev,key=poe_rogdet_key$,dom=*next)
		while 1
			poe_roglsdet_key$=key(poe_roglsdet_dev,end=*break)
			if pos(poe_rogdet_key$=poe_roglsdet_key$)<>1 then break

			remove(poe_roglsdet_dev,key=poe_roglsdet_key$,dom=*next)
		wend

		remove(poe_rogdet_dev,key=poe_rogdet_key$,dom=*next)
	wend

	rem --- Remove POE_ROGHDR recore
	remove(poe_roghdr_dev,key=poe_roghdr_key$,dom=*next)

[[POE_ROGHDR.BSHO]]
rem --- Initialize sysinfo$
	dim sysinfo$:stbl("+SYSINFO_TPL")
	sysinfo$=stbl("+SYSINFO")

rem --- Open Files
	num_files=12
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="POE_ROGDET",open_opts$[1]="OTA"
	open_tables$[2]="POE_ROGLSDET",open_opts$[2]="OTA"
	open_tables$[3]="POE_RECHDR",open_opts$[3]="OTA"
	open_tables$[4]="POE_RECDET",open_opts$[4]="OTA"
	open_tables$[5]="POE_RECLSDET",open_opts$[5]="OTA"
	open_tables$[6]="POT_RECHDR",open_opts$[6]="OTA"
	open_tables$[7]="POT_RECDET",open_opts$[7]="OTA"
	open_tables$[8]="POT_RECLSDET",open_opts$[8]="OTA"
	open_tables$[9]="APM_VENDADDR",open_opts$[9]="OTA"
	open_tables$[10]="APM_VENDMAST",open_opts$[10]="OTA"
	open_tables$[11]="IVM_ITEMMAST",open_opts$[11]="OTA"
	open_tables$[12]="POC_LINECODE",open_opts$[12]="OTA"

	gosub open_tables

[[POE_ROGHDR.BWRI]]
rem --- For inventoried lot/serial items, item qty_returned must equal sum of lot/serial items qty_returned.
	poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
	dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

	po_no$=callpoint!.getColumnData("POE_ROGHDR.PO_NO")
	receiver_no$=callpoint!.getColumnData("POE_ROGHDR.RECEIVER_NO")
	return_date$=callpoint!.getColumnData("POE_ROGHDR.RETURN_DATE")
	return_auth$=callpoint!.getColumnData("POE_ROGHDR.RETURN_AUTH")

	dim gridrec$:fnget_tpl$("POE_ROGDET")
	rowData!=cast(BBjVector,GridVect!.getItem(0))
	for curr_row=0 to rowData!.size()-1
		gridrec$=rowData!.getItem(curr_row)
		item_id$=gridrec.item_id$
		gosub lot_ser_check
		if lotser_item$="Y" then
			lotser_returned=0
			trip_key$=firm_id$+po_no$+receiver_no$+return_date$+pad(return_auth$,15)+gridrec.rec_int_seq_ref$
			read(poe_roglsdet_dev,key=trip_key$,knum="PRIMARY",dom=*next)
			while 1
				poe_roglsdet_key$=key(poe_roglsdet_dev,end=*break)
				if pos(trip_key$=poe_roglsdet_key$)<>1 then break
				readrecord(poe_roglsdet_dev)poe_roglsdet$
				lotser_returned=lotser_returned+poe_roglsdet.qty_returned
			wend

			qty_returned=gridrec.qty_returned
			if lotser_returned<>qty_returned then
				msg_id$="PO_ROG_LSQTY_WARN1"
				dim msg_tokens$[2]
				msg_tokens$[1]=str(qty_returned)
				msg_tokens$[2]=str(lotser_returned)
				gosub disp_message
				callpoint!.setStatus("ABORT")

				rem --- Show problem qty_returned in bold red
				curr_row=num(gridrec.line_no$)-1
				qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

				grid! = util.getGrid(Form!)
				grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("boldFont"))
				grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("redColor"))

				callpoint!.setOptionEnabled("EDIT",1)
				break
			else
				rem --- Reset color and font for qty_returned
				qtyReturned_col=callpoint!.getDevObject("qtyReturned_col")

				grid! = util.getGrid(Form!)
				grid!.setCellFont(curr_row,qtyReturned_col,callpoint!.getDevObject("plainFont"))
				grid!.setCellForeColor(curr_row,qtyReturned_col,callpoint!.getDevObject("blackColor"))
			endif
		endif
	next curr_row

[[POE_ROGHDR.PO_NO.AVAL]]
rem --- Must be an existing POE_RECHDR or POT_RECHDR record
	poe_rechdr_dev=fnget_dev("POE_RECHDR")
	dim poe_rechdr$:fnget_tpl$("POE_RECHDR")
	po_no$=callpoint!.getUserInput()
	vendor_id$=callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")
	recordFound=0

	tripKey$=firm_id$+vendor_id$
	read(poe_rechdr_dev,key=tripKey$,knum="AO_VEND_RCVR_PO",dom=*next)
	while 1
		thisKey$=key(poe_rechdr_dev,end=*break)
		if pos(tripKey$=thisKey$)<>1 then break
		readrecord(poe_rechdr_dev)poe_rechdr$
		if poe_rechdr.po_no$=po_no$ then
			recordFound=1
			callpoint!.setColumnData("POE_ROGHDR.RECEIVER_NO",poe_rechdr.receiver_no$,1)
			break
		endif
	wend

	if !recordFound then
		pot_rechdr_dev=fnget_dev("POT_RECHDR")
		dim pot_rechdr$:fnget_tpl$("POT_RECHDR")

		tripKey$=firm_id$+vendor_id$+po_no$
		read(pot_rechdr_dev,key=tripKey$,knum="VEND_PO_REC",dom=*next)
		while 1
			thisKey$=key(pot_rechdr_dev,end=*break)
			if pos(tripKey$=thisKey$)<>1 then break
			readrecord(pot_rechdr_dev)pot_rechdr$
			recordFound=1
			callpoint!.setColumnData("POE_ROGHDR.RECEIVER_NO",pot_rechdr.receiver_no$,1)
			break
		wend
	endif

	if !recordFound then
		msg_id$="PO_NOT_FND_FOR_VEND"
		dim msg_tokens$[2]
		msg_tokens$[1]=po_no$
		msg_tokens$[2]=vendor_id$
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Display Vendor Purchase Address
	callpoint!.setColumnData("POE_ROGHDR.PO_NO",po_no$)
	gosub vend_purchase_addr
	callpoint!.setColumnData("POE_ROGHDR.PURCH_ADDR",purch_addr$)

[[POE_ROGHDR.PO_NO.BDRL]]
rem --- Open work file used for drilldown
	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="POW_VENDORPOS",open_opts$[1]="OTA"
	open_tables$[2]="POW_RECEIPTDET",open_opts$[2]="OTA"
	gosub open_tables
	powVendorPOs_dev=num(open_chans$[1])
	powReceiptDet_dev=num(open_chans$[2])
	dim powVendorPOs$:open_tpls$[1]
	dim powReceiptDet$:open_tpls$[2]

	vendor_id$=callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")
	call stbl("+DIR_PGM")+"adc_clearpartial.aon","",powVendorPOs_dev,firm_id$+vendor_id$,status
	if status then
		callpoint!.setStatus("ABORT")
		goto close_work_file
	endif

	call stbl("+DIR_PGM")+"adc_clearpartial.aon","",powReceiptDet_dev,firm_id$,status
	if status then
		callpoint!.setStatus("ABORT")
		goto close_work_file
	endif

rem --- Build pow_vendorpos from receipts in poe_rechdr and pot_rechdr for this vendor
	sqlprep$=""
	sqlprep$=sqlprep$+"SELECT firm_id, vendor_id, po_no, receiver_no, warehouse_id, recpt_date, 'New' as status"
	sqlprep$=sqlprep$+" FROM poe_rechdr"
	sqlprep$=sqlprep$+" WHERE firm_id="+"'"+firm_id$+"'"+" AND vendor_id="+"'"+vendor_id$+"'"
	sqlprep$=sqlprep$+" UNION"
	sqlprep$=sqlprep$+" SELECT firm_id, vendor_id,po_no, receiver_no, warehouse_id, recpt_date, 'Updated' as status"
	sqlprep$=sqlprep$+" FROM pot_rechdr"
	sqlprep$=sqlprep$+" WHERE firm_id="+"'"+firm_id$+"'"+" AND vendor_id="+"'"+vendor_id$+"'"

	sql_chan=sqlunt
	sqlopen(sql_chan,err=*next)stbl("+DBNAME")
	sqlprep(sql_chan)sqlprep$
	dim read_tpl$:sqltmpl(sql_chan)
	sqlexec(sql_chan)

	rem --- Process through SQL results 
	poe_recdet_dev=fnget_dev("POE_RECDET")
	dim poe_recdet$:fnget_tpl$("POE_RECDET")
	pot_recdet_dev=fnget_dev("POT_RECDET")
	dim pot_recdet$:fnget_tpl$("POT_RECDET")
	while 1
		read_tpl$ = sqlfetch(sql_chan,end=*break)

		powVendorPOs.firm_id$=read_tpl.firm_id$
		powVendorPOs.vendor_id$=read_tpl.vendor_id$
		powVendorPOs.po_no$=read_tpl.po_no$
		powVendorPOs.receiver_no$=read_tpl.receiver_no$
		powVendorPOs.warehouse_id$=read_tpl.warehouse_id$
		powVendorPOs.recpt_date$=read_tpl.recpt_date$
		powVendorPOs.status$=read_tpl.status$
		writerecord(powVendorPOs_dev)powVendorPOs$

		rem --- Build pow_receiptdet from receipts in poe_recdet and pot_recdet for this vendor
		if cvs(powVendorPOs.status$,2)="New" then
			poe_recdet_trip$=firm_id$+powVendorPOs.po_no$+powVendorPOs.receiver_no$
			read(poe_recdet_dev,key=poe_recdet_trip$,knum="PO_RECVR",dom=*next)
			while 1
				poe_recdet_key$=key(poe_recdet_dev,end=*break)
				if pos(poe_recdet_trip$=poe_recdet_key$)<>1 then break
				readrecord(poe_recdet_dev)poe_recdet$

				powReceiptDet.firm_id$=poe_recdet.firm_id$
				powReceiptDet.po_no$=poe_recdet.po_no$
				powReceiptDet.receiver_no$=poe_recdet.receiver_no$
				powReceiptDet.po_int_seq_ref$=poe_recdet.internal_seq_no$
				powReceiptDet.po_line_no$=poe_recdet.po_line_no$
				powReceiptDet.po_line_code$=poe_recdet.po_line_code$
				powReceiptDet.warehouse_id$=poe_recdet.warehouse_id$
				powReceiptDet.item_id$=poe_recdet.item_id$
				powReceiptDet.recpt_date$=read_tpl.recpt_date$
				powReceiptDet.qty_ordered=poe_recdet.qty_ordered
				powReceiptDet.qty_received=poe_recdet.qty_received
				powReceiptDet.status$=read_tpl.status$
				writerecord(powReceiptDet_dev)powReceiptDet$
			wend
		else
			pot_recdet_trip$=firm_id$+powVendorPOs.po_no$+powVendorPOs.receiver_no$
			read(pot_recdet_dev,key=pot_recdet_trip$,knum="PRIMARY",dom=*next)
			while 1
				pot_recdet_key$=key(pot_recdet_dev,end=*break)
				if pos(pot_recdet_trip$=pot_recdet_key$)<>1 then break
				readrecord(pot_recdet_dev)pot_recdet$

				powReceiptDet.firm_id$=pot_recdet.firm_id$
				powReceiptDet.po_no$=pot_recdet.po_no$
				powReceiptDet.receiver_no$=pot_recdet.receiver_no$
				powReceiptDet.po_int_seq_ref$=pot_recdet.po_int_seq_ref$
				powReceiptDet.po_line_no$=pot_recdet.po_line_no$
				powReceiptDet.po_line_code$=pot_recdet.po_line_code$
				powReceiptDet.warehouse_id$=pot_recdet.warehouse_id$
				powReceiptDet.item_id$=pot_recdet.item_id$
				powReceiptDet.recpt_date$=read_tpl.recpt_date$
				powReceiptDet.qty_ordered=pot_recdet.qty_ordered
				powReceiptDet.qty_received=pot_recdet.qty_received
				powReceiptDet.status$=read_tpl.status$
				writerecord(powReceiptDet_dev)powReceiptDet$
			wend
		endif
	wend

rem --- Do custom query
	query_id$="PO_REC_OPEN+HIST"
	query_mode$="DEFAULT"
	dim filter_defs$[2,2]
	filter_defs$[1,0] = "POE_RECHDR.FIRM_ID"
	filter_defs$[1,1] = "='"+firm_id$+"'"
	filter_defs$[1,2] = "LOCK"
	filter_defs$[2,0] = "POE_RECHDR.VENDOR_ID"
	filter_defs$[2,1] = "='"+vendor_id$+"'"
	filter_defs$[2,2] = "LOCK"

	dim search_defs$[2]
	search_defs$[0]="POW_VENDORPOS.RECEIVER_NO"
	search_defs$[1]=""
	search_defs$[2]="D"

	key_pfx$=firm_id$+vendor_id$
	key_id$="PRIMARY"

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		form!,
:		query_id$,
:		query_mode$,
:		table_chans$[all],
:		sel_key$,
:		filter_defs$[all],
:		search_defs$[all],
:		key_pfx$,
:		key_id$

	if sel_key$<>""
		call stbl("+DIR_SYP")+"bac_key_template.bbj",
:			"POW_VENDORPOS",
:			key_id$,
:			powVendorPOs_key$,
:			table_chans$[all],
:			status$

		dim powVendorPOs_key$:powVendorPOs_key$
		powVendorPOs_key$=sel_key$
		callpoint!.setColumnData("POE_ROGHDR.PO_NO",powVendorPOs_key.po_no$,1)
		callpoint!.setColumnData("POE_ROGHDR.RECEIVER_NO",powVendorPOs.receiver_no$,1)
		callpoint!.setStatus("MODIFIED")
	endif

close_work_file: rem --- Close work file
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="POW_VENDORPOS",open_opts$[1]="C"
	gosub open_tables

	callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_ROGHDR.PO_NO.BINQ]]
rem --- Do custom query
	query_id$="PO_INVRECPT"
	query_mode$="DEFAULT"
	dim filter_defs$[2,2]
	filter_defs$[1,0] = "POT_RECHDR.FIRM_ID"
	filter_defs$[1,1] = "='"+callpoint!.getColumnData("POE_ROGHDR.FIRM_ID")+"'"
	filter_defs$[1,2] = "LOCK"
	filter_defs$[2,0] = "POT_RECHDR.VENDOR_ID"
	filter_defs$[2,1] = "='" + callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")+"'"
	filter_defs$[2,2] = "LOCK"

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		form!,
:		query_id$,
:		query_mode$,
:		table_chans$[all],
:		sel_key$,filter_defs$[all]

	if sel_key$<>""
		call stbl("+DIR_SYP")+"bac_key_template.bbj",
:			"POT_RECHDR",
:			"PRIMARY",
:			pot_rec_key$,
:			table_chans$[all],
:			status$

		dim pot_rec_key$:pot_rec_key$
		pot_rec_key$=sel_key$
		callpoint!.setColumnData("POE_ROGHDR.PO_NO",pot_rec_key.po_no$,1)
		callpoint!.setColumnData("POE_ROGHDR.RECEIVER_NO",pot_rec_key.receiver_no$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"POE_ROGHDR.PO_NO",1)
	endif
	callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_ROGHDR.RECEIVER_NO.AVAL]]
rem --- Must be an existing POE_RECHDR or POT_RECHDR record
	poe_rechdr_dev=fnget_dev("POE_RECHDR")
	dim poe_rechdr$:fnget_tpl$("POE_RECHDR")
	receiver_no$=callpoint!.getUserInput()
	po_no$=callpoint!.getColumnData("POE_ROGHDR.PO_NO")
	vendor_id$=callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")

	recordFound=0
	find(poe_rechdr_dev,key=firm_id$+vendor_id$+receiver_no$+po_no$,knum="AO_VEND_RCVR_PO",dom=*next); recordFound=1
	if !recordFound then
		pot_rechdr_dev=fnget_dev("POT_RECHDR")
		dim pot_rechdr$:fnget_tpl$("POT_RECHDR")

		find(pot_rechdr_dev,key=firm_id$+vendor_id$+po_no$+receiver_no$,knum="VEND_PO_REC",dom=*next); recordFound=1
		if !recordFound then
			msg_id$="PO_RCVR_FND_FOR_PO"
			dim msg_tokens$[2]
			msg_tokens$[1]=receiver_no$
			msg_tokens$[2]=po_no$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Display Vendor Purchase Address
	gosub vend_purchase_addr
	callpoint!.setColumnData("POE_ROGHDR.PURCH_ADDR",purch_addr$)

[[POE_ROGHDR.<CUSTOM>]]
vend_purchase_addr: rem --- Display Vendor Purchase Address
	poe_rechdr_dev=fnget_dev("POE_RECHDR")
	dim poe_rechdr$:fnget_tpl$("POE_RECHDR")

	purch_addr$=""
	recordFound=0
	receiver_no$=callpoint!.getColumnData("POE_ROGHDR.RECEIVER_NO")
	findrecord(poe_rechdr_dev,key=firm_id$+receiver_no$,knum="PRIMARY",dom=*next)poe_rechdr$; recordFound=1
	if recordFound then
		rem --- Receiver is in entry
		purch_addr$=poe_rechdr.purch_addr$
	else
		rem --- Receiver not in entry so check history for it
		pot_rechdr_dev=fnget_dev("POT_RECHDR")
		dim pot_rechdr$:fnget_tpl$("POT_RECHDR")

		po_no$=callpoint!.getColumnData("POE_ROGHDR.PO_NO")
		findrecord(pot_rechdr_dev,key=firm_id$+po_no$+receiver_no$,knum="PRIMARY",dom=*next)pot_rechdr$; recordFound=1
		if recordFound then purch_addr$=pot_rechdr.purch_addr$

	endif

	if cvs(purch_addr$,2)<>"" then
		vendor_id$=callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")

		apm_vendaddr_dev=fnget_dev("APM_VENDADDR")
		dim apm_vendaddr$:fnget_tpl$("APM_VENDADDR")
		readrecord(apm_vendaddr_dev,key=firm_id$+vendor_id$+purch_addr$,dom=*endif)apm_vendaddr$
		callpoint!.setColumnData("<<DISPLAY>>.V_ADDR1",apm_vendaddr.addr_line_1$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_ADDR2",apm_vendaddr.addr_line_2$,1)
		if cvs(apm_vendaddr.city$+apm_vendaddr.state_code$+apm_vendaddr.zip_code$,3)<>""
			callpoint!.setColumnData("<<DISPLAY>>.V_CITY",cvs(apm_vendaddr.city$,3)+", "+apm_vendaddr.state_code$+"  "+apm_vendaddr.zip_code$,1)
		else
			callpoint!.setColumnData("<<DISPLAY>>.V_CITY","",1)
		endif
		callpoint!.setColumnData("<<DISPLAY>>.V_CNTRY_ID",apm_vendaddr.cntry_id$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_CONTACT",apm_vendaddr.contact_name$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_PHONE",apm_vendaddr.phone_no$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_FAX",apm_vendaddr.fax_no$,1)
	else
		rem --- Purchase address not found, so use vendor's address
		vendor_id$=callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")

		apm_vendmast_dev=fnget_dev("APM_VENDMAST")
		dim apm_vendmast$:fnget_tpl$("APM_VENDMAST")
		readrecord(apm_vendmast_dev,key=firm_id$+vendor_id$,dom=*endif)apm_vendmast$
		callpoint!.setColumnData("<<DISPLAY>>.V_ADDR1",apm_vendmast.addr_line_1$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_ADDR2",apm_vendmast.addr_line_2$,1)
		if cvs(apm_vendmast.city$+apm_vendmast.state_code$+apm_vendmast.zip_code$,3)<>""
			callpoint!.setColumnData("<<DISPLAY>>.V_CITY",cvs(apm_vendmast.city$,3)+", "+apm_vendmast.state_code$+"  "+apm_vendmast.zip_code$,1)
		else
			callpoint!.setColumnData("<<DISPLAY>>.V_CITY","",1)
		endif
		callpoint!.setColumnData("<<DISPLAY>>.V_CNTRY_ID",apm_vendmast.cntry_id$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_CONTACT",apm_vendmast.contact_name$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_PHONE",apm_vendmast.phone_no$,1)
		callpoint!.setColumnData("<<DISPLAY>>.V_FAX",apm_vendmast.fax_no$,1)
	endif

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

rem ==========================================================================
rem 	Use util object
rem ==========================================================================
	use ::ado_util.src::util



