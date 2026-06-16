[[OPR_ODERSTATITEM.AREC]]
rem --- Set default Warehouse
	whse$=callpoint!.getDevObject("dflt_whse")
	callpoint!.setColumnData("OPR_ODERSTATITEM.WAREHOUSE_ID",whse$,1)
	if callpoint!.getDevObject("multi_whse")<>"Y" then callpoint!.setColumnEnabled("OPR_ODERSTATITEM.WAREHOUSE_ID",0)

[[OPR_ODERSTATITEM.BSHO]]
rem --- Open files
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"

	gosub open_tables

rem --- Get multiple warehouse flag and default warehouse
	ivs01_dev=num(open_chans$[1])
	dim ivs01a$:open_tpls$[1]
	read record (ivs01_dev,key=firm_id$+"IV00")ivs01a$
	callpoint!.setDevObject("multi_whse",ivs01a.multi_whse$)
	callpoint!.setDevObject("dflt_whse",ivs01a.warehouse_id$)



