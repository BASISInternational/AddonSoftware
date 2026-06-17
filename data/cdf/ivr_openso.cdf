[[IVR_OPENSO.AREC]]
rem --- Set default Warehouse
	whse$=callpoint!.getDevObject("default_whse")
	callpoint!.setColumnData("IVR_OPENSO.WAREHOUSE_ID",whse$,1)
	if callpoint!.getDevObject("multi_whse")<>"Y" then callpoint!.setColumnEnabled("IVR_OPENSO.WAREHOUSE_ID",0)

[[IVR_OPENSO.BSHO]]
rem --- Get IV params
	ivs01_dev=fnget_dev("IVS_PARAMS")
	dim ivs01a$:fnget_tpl$("IVS_PARAMS")
	ivs01a_key$=firm_id$+"IV00"
	find record (ivs01_dev,key=ivs01a_key$,err=std_missing_params) ivs01a$
	callpoint!.setDevObject("multi_whse",ivs01a.multi_whse$)
	callpoint!.setDevObject("default_whse",ivs01a.warehouse_id$)

[[IVR_OPENSO.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[IVR_OPENSO.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



