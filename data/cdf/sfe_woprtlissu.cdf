[[SFE_WOPRTLISSU.AREC]]
rem --- Initialize SCH_PROD_QTY and prtl_issu_qty
	wo_sch_prod_qty=callpoint!.getDevObject ("wo_sch_prod_qty")
	callpoint!.setColumnData("SFE_WOPRTLISSU.SCH_PROD_QTY",str(wo_sch_prod_qty))
	callpoint!.setColumnData("SFE_WOPRTLISSU.PRTL_ISSU_QTY",str(wo_sch_prod_qty))
	callpoint!.setDevObject("prtl_issu_qty",wo_sch_prod_qty)

rem --- prtl_issu_qty cannot be greater than SCH_PROD_QTY
	callpoint!.setTableColumnAttribute("SFE_WOPRTLISSU.PRTL_ISSU_QTY","MAXV",str(wo_sch_prod_qty))

[[SFE_WOPRTLISSU.ASVA]]
rem --- Report back the prtl_issu_qty
	callpoint!.setDevObject("prtl_issu_qty",num(callpoint!.getColumnData("SFE_WOPRTLISSU.PRTL_ISSU_QTY")))



