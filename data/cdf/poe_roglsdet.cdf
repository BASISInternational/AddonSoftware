[[POE_ROGLSDET.BEND]]
rem --- Warn if the sum of lot/serial number qty_returned does not match item's qty_returned.
	poe_roglsdet_dev=fnget_dev("POE_ROGLSDET")
	dim poe_roglsdet$:fnget_tpl$("POE_ROGLSDET")

	po_no$=callpoint!.getColumnData("POE_ROGLSDET.PO_NO")
	receiver_no$=callpoint!.getColumnData("POE_ROGLSDET.RECEIVER_NO")
	return_date$=callpoint!.getColumnData("POE_ROGLSDET.RETURN_DATE")
	return_auth$=callpoint!.getColumnData("POE_ROGLSDET.RETURN_AUTH")
	rec_int_seq_ref$=callpoint!.getColumnData("POE_ROGLSDET.REC_INT_SEQ_REF")

	lotser_returned=0
	trip_key$=firm_id$+po_no$+receiver_no$+return_date$+return_auth$+rec_int_seq_ref$
	read(poe_roglsdet_dev,key=trip_key$,knum="PRIMARY",dom=*next)
	while 1
		poe_roglsdet_key$=key(poe_roglsdet_dev,end=*break)
		if pos(trip_key$=poe_roglsdet_key$)<>1 then break
		readrecord(poe_roglsdet_dev)poe_roglsdet$
		lotser_returned=lotser_returned+poe_roglsdet.qty_returned
	wend

	item_returned=callpoint!.getDevObject("qty_returned")
	if lotser_returned<>item_returned then
		msg_id$="PO_ROG_LSQTY_WARN2"
		dim msg_tokens$[2]
		msg_tokens$[1]=str(lotser_returned)
		msg_tokens$[2]=str(item_returned)
		gosub disp_message
	endif

	rem --- Return the sum of the lot/serial items qty_returned
	callpoint!.setDevObject("lotser_returned",lotser_returned)

[[POE_ROGLSDET.QTY_RETURNED.AVAL]]
rem --- QTY_RETURNED must be greater than or equal to zero, and less than or equal to QTY_RECEIVED
	qty_returned=num(callpoint!.getUserInput())
	qty_received=num(callpoint!.getColumnData("POE_ROGLSDET.QTY_RECEIVED"))
	if qty_returned<0 or qty_returned>qty_received then
		msg_id$="PO_ROG_QTY_WARN"
		dim msg_tokens$[1]
		msg_tokens$[1]=callpoint!.getColumnData("POE_ROGLSDET.QTY_RECEIVED")
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



