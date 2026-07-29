[[SFE_WOPRTLCMMT.AREC]]
rem --- Initialize SCH_PROD_QTY and PRTL_CMMT_QTY
	wo_sch_prod_qty=callpoint!.getDevObject ("wo_sch_prod_qty")
	callpoint!.setColumnData("SFE_WOPRTLCMMT.SCH_PROD_QTY",str(wo_sch_prod_qty))
	callpoint!.setColumnData("SFE_WOPRTLCMMT.PRTL_CMMT_QTY",str(wo_sch_prod_qty))
	callpoint!.setDevObject("prtl_cmmt_qty",wo_sch_prod_qty)

rem --- PRTL_CMMT_QTY cannot be greater than SCH_PROD_QTY
	callpoint!.setTableColumnAttribute("SFE_WOPRTLCMMT.PRTL_CMMT_QTY","MAXV",str(wo_sch_prod_qty))

[[SFE_WOPRTLCMMT.ASVA]]
rem --- Report back the PRTL_CMMT_QTY
	callpoint!.setDevObject("prtl_cmmt_qty",num(callpoint!.getColumnData("SFE_WOPRTLCMMT.PRTL_CMMT_QTY")))



