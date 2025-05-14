[[POE_ROGLSDET.BEND]]
rem --- Return the sum of the lot/serial items qty_returned
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

	callpoint!.setDevObject("lotser_returned",lotser_returned)



