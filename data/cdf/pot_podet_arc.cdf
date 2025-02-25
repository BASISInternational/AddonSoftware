[[POT_PODET_ARC.AGCL]]
rem --- Set column size for memo_1024 field very small so it doesn't take up room, but still available for hover-over of memo contents
	use ::ado_util.src::util

	grid! = util.getGrid(Form!)
	col_hdr$=callpoint!.getTableColumnAttribute("POT_PODET_ARC.MEMO_1024","LABS")
	memo_1024_col=util.getGridColumnNumber(grid!, col_hdr$)
	grid!.setColumnWidth(memo_1024_col,15)

[[POT_PODET_ARC.AGDR]]
rem --- Sum PO total amount
	total_amt=num(callpoint!.getDevObject("total_amt"))
	total_amt=total_amt+round(num(callpoint!.getColumnData("POT_PODET_ARC.QTY_ORDERED"))*num(callpoint!.getColumnData("POT_PODET_ARC.UNIT_COST")),2)
	callpoint!.setDevObject("total_amt",str(total_amt))



