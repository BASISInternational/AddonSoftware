[[POE_ROGHDR.ADIS]]
rem --- Display Vendor Purchase Address
	gosub vend_purchase_addr

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
			redim poe_rogdet$
			poe_rogdet.firm_id$=poe_recdet.firm_id$
			poe_rogdet.po_no$=poe_recdet.po_no$
			poe_rogdet.receiver_no$=poe_recdet.receiver_no$
			poe_rogdet.return_date$=return_date$
			poe_rogdet.return_auth$=return_auth$
			poe_rogdet.rec_int_seq_ref$=poe_recdet.internal_seq_no$
			poe_rogdet.line_no$=poe_recdet.po_line_no$
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
			redim poe_rogdet$
			poe_rogdet.firm_id$=pot_recdet.firm_id$
			poe_rogdet.po_no$=pot_recdet.po_no$
			poe_rogdet.receiver_no$=pot_recdet.receiver_no$
			poe_rogdet.return_date$=return_date$
			poe_rogdet.return_auth$=return_auth$
			poe_rogdet.rec_int_seq_ref$=pot_recdet.po_int_seq_ref$
			poe_rogdet.line_no$=pot_recdet.po_line_no$
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
	num_files=10
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

	gosub open_tables

	poe_rogdet_dev=num(open_chans$[1])
	poe_roglsdet_dev=num(open_chans$[2])
	poe_rechdr_dev=num(open_chans$[3])
	poe_recdet_dev=num(open_chans$[4])
	poe_reclsdet_dev=num(open_chans$[5])
	pot_rechdr_dev=num(open_chans$[6])
	pot_recdet_dev=num(open_chans$[7])
	pot_reclsdet_dev=num(open_chans$[8])
	apm_vendaddr_dev=num(open_chans$[9])
	apm_vendmast_dev=num(open_chans$[10])

	dim poe_rogdet$:open_tpls$[1]
	dim poe_roglsdet$:open_tpls$[2]
	dim poe_rechdr$:open_tpls$[3]
	dim poe_recdet$:open_tpls$[4]
	dim poe_reclsdet$:open_tpls$[5]
	dim pot_recdet$:open_tpls$[6]
	dim pot_rechdr$:open_tpls$[7]
	dim pot_reclshdr$:open_tpls$[8]
	dim apm_vendaddr$:open_tpls$[9]
	dim apm_vendmast$:open_tpls$[10]

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
rem --- Do custom query
	query_id$="PO_REC_OPEN+HIST"
	query_mode$="DEFAULT"
	dim filter_defs$[2,2]
	filter_defs$[1,0] = "POE_RECHDR.FIRM_ID"
	filter_defs$[1,1] = "='"+callpoint!.getColumnData("POE_ROGHDR.FIRM_ID")+"'"
	filter_defs$[1,2] = "LOCK"
	filter_defs$[2,0] = "POE_RECHDR.VENDOR_ID"
	filter_defs$[2,1] = "='" + callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")+"'"
	filter_defs$[2,2] = "LOCK"

	dim search_defs$[2]
	search_defs$[0]="POE_RECHDR.PO_NO"
	search_defs$[2]="D"

	key_pfx$=callpoint!.getColumnData("POE_ROGHDR.FIRM_ID")+callpoint!.getColumnData("POE_ROGHDR.VENDOR_ID")
	key_id$="AO_VEND_RCVR_PO"

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
:			"POE_RECHDR",
:			key_id$,
:			poe_rechdr_key$,
:			table_chans$[all],
:			status$

		dim poe_rechdr_key$:poe_rechdr_key$
		poe_rechdr_key$=sel_key$
		callpoint!.setColumnData("POE_ROGHDR.PO_NO",poe_rechdr_key.po_no$,1)
		callpoint!.setColumnData("POE_ROGHDR.RECEIVER_NO",poe_rechdr_key.receiver_no$,1)
		callpoint!.setStatus("MODIFIED")
	endif
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



