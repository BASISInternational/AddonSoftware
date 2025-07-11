[[IVM_ITEMWHSE.ABC_CODE.AVAL]]
if (callpoint!.getUserInput()<"A" or callpoint!.getUserInput()>"Z") and cvs(callpoint!.getUserInput(),2)<>"" callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.ADIS]]
rem --- Draw attention when on-order quantities don't add up
	qty_on_order=num(callpoint!.getColumnData("IVM_ITEMWHSE.QTY_ON_ORDER"))
	po_qty=num(callpoint!.getColumnData("<<DISPLAY>>.ON_ORD_PO"))
	womast_qty=num(callpoint!.getColumnData("<<DISPLAY>>.ON_ORD_WO"))
	if qty_on_order<>po_qty+womast_qty then
		call stbl("+DIR_SYP",err=*endif)+"bac_create_color.bbj","+ENTRY_ERROR_COLOR","255,224,224",rdErrorColor!,""
		qtyOnOrder!=callpoint!.getControl("IVM_ITEMWHSE.QTY_ON_ORDER")
		qtyOnOrder!.setBackColor(rdErrorColor!)
	endif

rem --- Draw attention when commit quantities don't add up
	qty_commit=num(callpoint!.getColumnData("IVM_ITEMWHSE.QTY_COMMIT"))
	op_qty=num(callpoint!.getColumnData("<<DISPLAY>>.COMMIT_SO"))
	womatdtl_qty=num(callpoint!.getColumnData("<<DISPLAY>>.COMMIT_WO"))
	if qty_commit<>op_qty+womatdtl_qty then
		call stbl("+DIR_SYP",err=*endif)+"bac_create_color.bbj","+ENTRY_ERROR_COLOR","255,224,224",rdErrorColor!,""
		qtyCommit!=callpoint!.getControl("IVM_ITEMWHSE.QTY_COMMIT")
		qtyCommit!.setBackColor(rdErrorColor!)
	endif

rem --- Enable/disable fields for kitted items
	gosub disableKitFields

rem --- Disable cost fields when there are transactions for this item, or it is a kit
	ivt04_dev=fnget_dev("IVT_ITEMTRAN")
	warehouse_id$=callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")
	item_id$=callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")
	read(ivt04_dev,key=firm_id$+warehouse_id$+item_id$,dom=*next)
	ivt04_key$=""
	ivt04_key$=key(ivt04_dev,end=*next)
	if pos(firm_id$+warehouse_id$+item_id$=ivt04_key$)=1 or pos(callpoint!.getDevObject("kit")="YP") then
		rem --- Disable cost fields
		enable=0
	else
		rem --- Enable cost fields
		enable=1
	endif
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.UNIT_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.AVG_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.STD_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.REP_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.LANDED_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.LAST_PO_COST",enable)

rem --- If select in Physical Intentory, location and cycle can't change
	if callpoint!.getColumnData("IVM_ITEMWHSE.SELECT_PHYS") = "Y" then
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LOCATION",0)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PI_CYCLECODE",0)
		call stbl("+DIR_SYP")+"bac_message.bbj","IV_PHY_INV_SELECT",msg_tokens$[all],msg_opt$,table_chans$[all]
	else
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LOCATION",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PI_CYCLECODE",1)
	endif

[[IVM_ITEMWHSE.AENA]]
rem --- Disable Barista menu items
	wctl$="31031"; rem --- Save-As menu item in barista.ini
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)="X"
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP")

[[IVM_ITEMWHSE.AOPT-HIST]]
iv_item_id$=callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")
iv_whse_id$=callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")

call stbl("+DIR_PGM")+"ivr_itmWhseAct.aon",iv_item_id$,iv_whse_id$,table_chans$[all]

[[IVM_ITEMWHSE.AOPT-IHST]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")
cp_whse_id$=callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[4,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
dflt_data$[3,0]="WAREHOUSE_ID_1"
dflt_data$[3,1]=cp_whse_id$
dflt_data$[4,0]="WAREHOUSE_ID_2"
dflt_data$[4,1]=cp_whse_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_TRANSHIST",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMWHSE.AOPT-LIFO]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")
cp_whse_id$=callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[4,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
dflt_data$[3,0]="WAREHOUSE_ID_1"
dflt_data$[3,1]=cp_whse_id$
dflt_data$[4,0]="WAREHOUSE_ID_2"
dflt_data$[4,1]=cp_whse_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_LIFOFIFO",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMWHSE.ARAR]]
rem --- Get total on Open PO lines

	podet_dev=fnget_dev("POE_PODET")
	dim podet_tpl$:fnget_tpl$("POE_PODET")
	pohdr_dev=fnget_dev("POE_POHDR")
	dim pohdr_tpl$:fnget_tpl$("POE_POHDR")

	whse$=callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")
	item$=callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")
	po_qty=0
	op_qty=0
	womast_qty=0
	womatdtl_qty=0

	read(podet_dev,key=firm_id$+whse$+item$,knum="WHSE_ITEM",dom=*next)

	while 1
		read record (podet_dev,end=*break) podet_tpl$
		if firm_id$<>podet_tpl.firm_id$ break
		if whse$<>podet_tpl.warehouse_id$ break
		if item$<>podet_tpl.item_id$ break

		rem --- Skip if this is a drop ship item
		findrecord(pohdr_dev,key=firm_id$+podet_tpl.po_no$,dom=*continue)pohdr_tpl$
		if cvs(callpoint!.getDevObject("dropship_whse"),2)="" and pohdr_tpl.dropship$="Y" then continue

		po_qty = po_qty + (podet_tpl.qty_ordered - podet_tpl.qty_received)*podet_tpl.conv_factor
	wend

rem --- Include non-drop ship items added in PO Receipt Entry that aren't in the original PO
	rechdr_dev=fnget_dev("POE_RECHDR")
	dim rechdr_tpl$:fnget_tpl$("POE_RECHDR")
	recdet_dev=fnget_dev("POE_RECDET")
	dim recdet_tpl$:fnget_tpl$("POE_RECDET")
	read (recdet_dev,key=firm_id$+item$,knum="ITEM_PO",dom=*next)
	while 1
		read record(recdet_dev,end=*break)recdet_tpl$
		if firm_id$+item$<>recdet_tpl.firm_id$+recdet_tpl.item_id$ then break
		if recdet_tpl.warehouse_id$<>whse$ then continue

		rem --- Skip if this is a drop ship item
		findrecord(rechdr_dev,key=firm_id$+recdet_tpl.receiver_no$,dom=*continue)rechdr_tpl$
		if cvs(callpoint!.getDevObject("dropship_whse"),2)="" and rechdr_tpl.dropship$="Y" then continue

		rem --- Skip if this item was in the original PO
		podet_exists=0
		readrecord(podet_dev,key=firm_id$+recdet_tpl.po_no$+recdet_tpl.internal_seq_no$,knum="PRIMARY",dom=*next); podet_exists=1
		if podet_exists then continue

		rem --- Update po_qty for this warehouse and item
		po_qty=po_qty+((recdet_tpl.qty_ordered-recdet_tpl.qty_prev_rec)*recdet_tpl.conv_factor)
	wend

	callpoint!.setColumnData("<<DISPLAY>>.ON_ORD_PO",str(po_qty))

rem --- Get total on Open SO lines

	if pos(callpoint!.getDevObject("kit")="YP")=0 then
		opdet_dev=fnget_dev("OPE_ORDDET")
		dim opdet_tpl$:fnget_tpl$("OPE_ORDDET")
		ophdr_dev=fnget_dev("OPE_ORDHDR")
		dim ophdr_tpl$:fnget_tpl$("OPE_ORDHDR")
		opm02_dev=fnget_dev("OPC_LINECODE")
		dim opm02_tpl$:fnget_tpl$("OPC_LINECODE")

		read(opdet_dev,key=firm_id$+"E"+item$+whse$,knum="STAT_ITEM_CUS_IN",dom=*next)

		while 1
			optdet_key$=key(opdet_dev,end=*break)
			if pos(firm_id$+"E"+item$+whse$=optdet_key$)<>1 then break
			read record (opdet_dev) opdet_tpl$
			if opdet_tpl.commit_flag$<>"Y" then continue

			rem --- "Check header records for quotes
			find record (ophdr_dev,key=opdet_tpl.firm_id$+opdet_tpl.ar_type$+opdet_tpl.customer_id$+opdet_tpl.order_no$+opdet_tpl.ar_inv_no$,dom=*continue) ophdr_tpl$
			if ophdr_tpl.invoice_type$="P" or pos(opdet_tpl.trans_status$="ER")=0 then continue

			rem --- "Check line code for drop ships
			find record (opm02_dev,key=opdet_tpl.firm_id$+opdet_tpl.line_code$,dom=*continue) opm02_tpl$
			if pos(opm02_tpl.line_type$="MNO")<>0 or (cvs(callpoint!.getDevObject("dropship_whse"),2)="" and opm02_tpl.dropship$="Y") then continue

			op_qty = op_qty + opdet_tpl.qty_ordered
			endif
		wend

		callpoint!.setColumnData("<<DISPLAY>>.COMMIT_SO",str(op_qty),1)
	endif

rem --- Get total on WO Finished Goods (On Order)

	if callpoint!.getDevObject("wo_installed") = "Y"
		womast_dev=fnget_dev("SFE_WOMASTR")
		dim womast_tpl$:fnget_tpl$("SFE_WOMASTR")

		read(womast_dev,key=firm_id$+whse$+item$,knum="AO_WH_ITM_LOC_WO",dom=*next)

		while 1
			read record (womast_dev,end=*break) womast_tpl$
			if firm_id$<>womast_tpl.firm_id$ break
			if whse$<>womast_tpl.warehouse_id$ break
			if item$<>womast_tpl.item_id$ break
			if womast_tpl.wo_status$ = "O"
				womast_qty = womast_qty + (womast_tpl.sch_prod_qty - womast_tpl.qty_cls_todt)
			endif
		wend

		callpoint!.setColumnData("<<DISPLAY>>.ON_ORD_WO",str(womast_qty))

rem --- Get WO commits

		if pos(callpoint!.getDevObject("kit")="YP")=0 then
			womatdtl_dev=fnget_dev("SFE_WOMATDTL")
			dim womatdtl_tpl$:fnget_tpl$("SFE_WOMATDTL")
			womatisd_dev=fnget_dev("SFE_WOMATISD")
			dim womatisd_tpl$:fnget_tpl$("SFE_WOMATISD")

			rem --- Get WO commits for open WOs
			read(womatdtl_dev,key=firm_id$+whse$+item$,knum="AO_WH_ITM_LOC_WO",dom=*next)
			while 1
				read record (womatdtl_dev,end=*break)womatdtl_tpl$
				if firm_id$<>womatdtl_tpl.firm_id$ break
				if whse$<>womatdtl_tpl.warehouse_id$ break
				if item$<>womatdtl_tpl.item_id$ break
				womatdtl_qty = womatdtl_qty + womatdtl_tpl.qty_ordered - womatdtl_tpl.tot_qty_iss
			wend

			rem --- Include additional committments made after WO was released
			read(womatisd_dev,key=firm_id$+whse$+item$,knum="AO_WH_ITM_LOC_WO",dom=*next)
			while 1
				read record (womatisd_dev,end=*break)womatisd_tpl$
				if firm_id$<>womatisd_tpl.firm_id$ break
				if whse$<>womatisd_tpl.warehouse_id$ break
				if item$<>womatisd_tpl.item_id$ break
				rem --- Skip commits already counted for open WOs
				if cvs(womatisd_tpl.womatdtl_seq_ref$,2)="" then
					rem --- Not part of released WO
					womatdtl_qty = womatdtl_qty + womatisd_tpl.qty_ordered
				else
					rem --- Only count portion of issue's qty_issued that is greater than released WO's qty_ordered
					womatdtl_key$=firm_id$+womatisd_tpl.wo_location$+womatisd_tpl.wo_no$+womatisd_tpl.womatdtl_seq_ref$
					findrecord(womatdtl_dev,key=womatdtl_key$,knum="PRIMARY",err=*endif)womatdtl_tpl$
					if womatisd_tpl.qty_ordered - womatisd_tpl.tot_qty_iss > womatdtl_tpl.qty_ordered - womatdtl_tpl.tot_qty_iss then
						womatdtl_qty = womatdtl_qty - womatdtl_tpl.qty_ordered
						womatdtl_qty = womatdtl_qty + womatisd_tpl.qty_ordered
					endif
				endif
			wend

			callpoint!.setColumnData("<<DISPLAY>>.COMMIT_WO",str(womatdtl_qty),1)
		endif
	endif

[[IVM_ITEMWHSE.AREC]]
rem --- Initialize product_type with ivm_itemmast product_type
	itemmast_dev=fnget_dev("IVM_ITEMMAST")
	dim itemmast_tpl$:fnget_tpl$("IVM_ITEMMAST")
	readrecord(itemmast_dev,key=firm_id$+callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID"),dom=*next)itemmast_tpl$
	callpoint!.setColumnData("IVM_ITEMWHSE.PRODUCT_TYPE",itemmast_tpl.product_type$)

rem --- Enable/disable fields for kitted items
	gosub disableKitFields

rem --- Enable cost fields for new item if not a kit
	if pos(callpoint!.getDevObject("kit")="YP") then
		rem --- Disable cost fields
		enable=0
	else
		rem --- Enable cost fields
		enable=1
	endif
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.UNIT_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.AVG_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.STD_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.REP_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.LANDED_COST",enable)
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.LAST_PO_COST",enable)

[[IVM_ITEMWHSE.AR_DIST_CODE.AVAL]]
rem --- Don't allow inactive code
	arcDistCode_dev=fnget_dev("ARC_DISTCODE")
	dim arcDistCode$:fnget_tpl$("ARC_DISTCODE")
	ar_dist_code$=callpoint!.getUserInput()
	read record(arcDistCode_dev,key=firm_id$+"D"+ar_dist_code$,dom=*next)arcDistCode$
	if arcDistCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcDistCode.ar_dist_code$,3)
		msg_tokens$[2]=cvs(arcDistCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVM_ITEMWHSE.AVG_COST.AVAL]]
rem --- Update unit_cost if using average costing and average cost changes
	avg_cost$=callpoint!.getUserInput()
	if callpoint!.getDevObject(cost_method$)="A" and avg_cost$<>callpoint!.getColumnData("IVM_ITEMWHSE.AVG_COST") then
		callpoint!.setColumnData("IVM_ITEMWHSE.UNIT_COST",avg_cost$,1)
	endif

[[IVM_ITEMWHSE.BDEL]]
rem --- Allow this warehouse to be deleted?

	action$ = "W"
	whse$   = callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")
	item$   = callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")

	call stbl("+DIR_PGM")+"ivc_deleteitem.aon", action$, whse$, item$, rd_table_chans$[all], status
	if status then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.BSHO]]
rem --- Open extra tables

num_files=14
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="POE_PODET",open_opts$[1]="OTA"
open_tables$[2]="OPE_ORDDET",open_opts$[2]="OTA"
if callpoint!.getDevObject("wo_installed") = "Y"
	open_tables$[3]="SFE_WOMASTR",open_opts$[3]="OTA"
	open_tables$[4]="SFE_WOMATDTL",open_opts$[4]="OTA"
	open_tables$[5]="SFE_WOMATISD",open_opts$[5]="OTA"
endif
open_tables$[6]="OPE_ORDHDR",open_opts$[6]="OTA"
open_tables$[7]="OPC_LINECODE",open_opts$[7]="OTA"
open_tables$[8]="POE_RECHDR",open_opts$[8]="OTA"
open_tables$[9]="POE_RECDET",open_opts$[9]="OTA"
open_tables$[10]="POE_POHDR",open_opts$[10]="OTA"
if callpoint!.getDevObject("ap_installed") = "Y"
	open_tables$[11]="IVM_ITEMVEND",open_opts$[11]="OTA"
endif
open_tables$[12]="IVC_WHSECODE",open_opts$[12]="OTA"
open_tables$[13]="IVC_PHYSCODE",open_opts$[13]="OTA"
open_tables$[14]="IVC_PHYSCODE",open_opts$[14]="OTA"

gosub open_tables

rem --- Get IV params

ivs01_dev=fnget_dev("IVS_PARAMS")
dim ivs01a$:fnget_tpl$("IVS_PARAMS")

ivs01a_key$=firm_id$+"IV00"
find record (ivs01_dev,key=ivs01a_key$,err=std_missing_params) ivs01a$
callpoint!.setDevObject("dropship_whse",ivs01a.dropship_whse$)

rem --- Disable Option menu options

if pos(ivs01a.lifofifo$="LF")=0 then callpoint!.setOptionEnabled("LIFO",0)
if !pos(callpoint!.getDevObject("lot_serial_flag")="LS") then
	callpoint!.setOptionEnabled("IVM_LSMASTER",0)
else
	callpoint!.setOptionEnabled("IVM_LSMASTER",1)
endif
callpoint!.setDevObject(cost_method$,ivs01a.cost_method$)

rem --- Get item defaults

ivs10d_dev = fnget_dev("IVS_DEFAULTS")
dim ivs10d$:fnget_tpl$("IVS_DEFAULTS")

ivs10d_key$ = firm_id$ + "D"
find record(ivs10d_dev, key=ivs10d_key$, dom=*next) ivs10d$
callpoint!.setDevObject("ivs10d",ivs10d$)

callpoint!.setTableColumnAttribute("IVM_ITEMWHSE.BUYER_CODE","DFLT",ivs10d.buyer_code$)
callpoint!.setTableColumnAttribute("IVM_ITEMWHSE.AR_DIST_CODE","DFLT",ivs10d.ar_dist_code$)
callpoint!.setTableColumnAttribute("IVM_ITEMWHSE.ABC_CODE","DFLT",ivs10d.abc_code$)
callpoint!.setTableColumnAttribute("IVM_ITEMWHSE.EOQ_CODE","DFLT",ivs10d.eoq_code$)
callpoint!.setTableColumnAttribute("IVM_ITEMWHSE.ORD_PNT_CODE","DFLT",ivs10d.ord_pnt_code$)
callpoint!.setTableColumnAttribute("IVM_ITEMWHSE.SAF_STK_CODE","DFLT",ivs10d.saf_stk_code$)

rem --- if AR dist by item param is not checked, disable the dist code field
if callpoint!.getDevObject("di")<>"Y"
	callpoint!.setColumnEnabled("AR_DIST_CODE",-1)
endif

rem --- Disable vendor_id if AP not installed
if callpoint!.getDevObject("ap_installed")<>"Y"
	callpoint!.setColumnEnabled("IVM_ITEMWHSE.VENDOR_ID",-1)
endif

[[IVM_ITEMWHSE.BUYER_CODE.AVAL]]
rem --- Don't allow inactive code
	ivc_buycode=fnget_dev("IVC_BUYCODE")
	dim ivc_buycode$:fnget_tpl$("IVC_BUYCODE")
	buyer_code$=callpoint!.getUserInput()
	read record (ivc_buycode,key=firm_id$+"F"+buyer_code$,dom=*next)ivc_buycode$
	if ivc_buycode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivc_buycode.buyer_code$,3)
		msg_tokens$[2]=cvs(ivc_buycode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[<<DISPLAY>>.COMMIT_WO.BDRL]]
rem --- don't run drilldown if SF isn't installed

	if callpoint!.getDevObject("wo_installed")<>"Y" then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.EOQ.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.LEAD_TIME.AVAL]]
if num(callpoint!.getUserInput())<0 or fpt(num(callpoint!.getUserInput())) then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.MAXIMUM_QTY.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[<<DISPLAY>>.ON_ORD_WO.BDRL]]
rem --- don't run drilldown if SF isn't installed

	if callpoint!.getDevObject("wo_installed")<>"Y" then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.ORDER_POINT.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.PI_CYCLECODE.AVAL]]
rem --- Don't allow inactive code
	ivcPhysCode_dev=fnget_dev("IVC_PHYSCODE")
	dim ivcPhysCode$:fnget_tpl$("IVC_PHYSCODE")
	pi_cyclecode$=callpoint!.getUserInput()
	warehouse_id$=callpoint!.getColumnData("IVM_ITEMWHSE.WAREHOUSE_ID")
	read record (ivcPhysCode_dev,key=firm_id$+warehouse_id$+pi_cyclecode$,dom=*next)ivcPhysCode$
	if ivcPhysCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcPhysCode.pi_cyclecode$,3)
		msg_tokens$[2]=cvs(ivcPhysCode.description$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVM_ITEMWHSE.PRODUCT_TYPE.AVAL]]
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

[[IVM_ITEMWHSE.REP_COST.AVAL]]
rem --- Update unit_cost if using replacement costing and replacement cost changes
	rep_cost$=callpoint!.getUserInput()
	if callpoint!.getDevObject(cost_method$)="R" and rep_cost$<>callpoint!.getColumnData("IVM_ITEMWHSE.REP_COST") then
		callpoint!.setColumnData("IVM_ITEMWHSE.UNIT_COST",rep_cost$,1)
	endif

[[IVM_ITEMWHSE.SAFETY_STOCK.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMWHSE.STD_COST.AVAL]]
rem --- Update unit_cost if using standard costing and standard cost changes
	std_cost$=callpoint!.getUserInput()
	if callpoint!.getDevObject(cost_method$)="S" and std_cost$<>callpoint!.getColumnData("IVM_ITEMWHSE.STD_COST") then
		callpoint!.setColumnData("IVM_ITEMWHSE.UNIT_COST",std_cost$,1)
	endif

[[IVM_ITEMWHSE.UNIT_COST.AVAL]]
rem --- Set default costs from unit cost

	unit_cost$ = callpoint!.getUserInput()
	if unit_cost$<>callpoint!.getColumnData("IVM_ITEMWHSE.UNIT_COST") then

		if num( callpoint!.getColumnData("IVM_ITEMWHSE.LANDED_COST") ) = 0 then
			callpoint!.setColumnData("IVM_ITEMWHSE.LANDED_COST",unit_cost$,1)
		endif

		if num( callpoint!.getColumnData("IVM_ITEMWHSE.LAST_PO_COST") ) = 0 then
			callpoint!.setColumnData("IVM_ITEMWHSE.LAST_PO_COST",unit_cost$,1)
		endif

		if num( callpoint!.getColumnData("IVM_ITEMWHSE.AVG_COST") ) = 0 or callpoint!.getDevObject(cost_method$)="A" then
			callpoint!.setColumnData("IVM_ITEMWHSE.AVG_COST",unit_cost$,1)
		endif

		if num( callpoint!.getColumnData("IVM_ITEMWHSE.STD_COST") ) = 0 or callpoint!.getDevObject(cost_method$)="S" then
			callpoint!.setColumnData("IVM_ITEMWHSE.STD_COST",unit_cost$,1)
		endif

		if num( callpoint!.getColumnData("IVM_ITEMWHSE.REP_COST") ) = 0 or callpoint!.getDevObject(cost_method$)="R" then
			callpoint!.setColumnData("IVM_ITEMWHSE.REP_COST",unit_cost$,1)
		endif
	endif

[[IVM_ITEMWHSE.VENDOR_ID.AVAL]]
rem "VENDOR INACTIVE - FEATURE"
vendor_id$ = callpoint!.getUserInput()
apm01_dev=fnget_dev("APM_VENDMAST")
apm01_tpl$=fnget_tpl$("APM_VENDMAST")
dim apm01a$:apm01_tpl$
apm01a_key$=firm_id$+vendor_id$
find record (apm01_dev,key=apm01a_key$,err=*break) apm01a$
if apm01a.vend_inactive$="Y" then
	call stbl("+DIR_PGM")+"adc_getmask.aon","VENDOR_ID","","","",m0$,0,vendor_size
	msg_id$="AP_VEND_INACTIVE"
	dim msg_tokens$[2]
	msg_tokens$[1]=fnmask$(apm01a.vendor_id$(1,vendor_size),m0$)
	msg_tokens$[2]=cvs(apm01a.vendor_name$,2)
	gosub disp_message
	callpoint!.setStatus("ACTIVATE")
endif

rem --- Make sure ivm_itemvend record exists for the stocking vendor
ivm05_dev=fnget_dev("IVM_ITEMVEND")
dim ivm05a$:fnget_tpl$("IVM_ITEMVEND")
item_id$=callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID")
findrecord(ivm05_dev,key=firm_id$+vendor_id$+item_id$,dom=*next)ivm05a$
if cvs(ivm05a.firm_id$,2)=""  then
	rem --- Create ivm_itemvend record for this vendor
	ivm05a.firm_id$=firm_id$
	ivm05a.vendor_id$=vendor_id$
	ivm05a.item_id$=item_id$
	ivm05a.prisec_flag$="P"
	ivm05a.break_qty_01=0
	ivm05a.break_qty_02=0
	ivm05a.break_qty_03=0
	ivm05a.unit_cost_01=0
	ivm05a.unit_cost_02=0
	ivm05a.unit_cost_03=0
	ivm05a.last_po_cost=0
	ivm05a.last_po_lead=0
	ivm05a.lead_time=0
	writerecord(ivm05_dev)ivm05a$

	call stbl("+DIR_PGM")+"adc_getmask.aon","VENDOR_ID","","","",m0$,0,vendor_size
	msg_id$="IV_ITEM_VEND_MISSING"
	dim msg_tokens$[1]
	msg_tokens$[1]=fnmask$(vendor_id$,m0$)
	gosub disp_message
	callpoint!.setStatus("ACTIVATE")
endif

[[IVM_ITEMWHSE.WAREHOUSE_ID.AVAL]]
rem --- Don't allow inactive code
	ivcWhseCode_dev=fnget_dev("IVC_WHSECODE")
	dim ivcWhseCode$:fnget_tpl$("IVC_WHSECODE")
	whse_code$=callpoint!.getUserInput()
	read record (ivcWhseCode_dev,key=firm_id$+"C"+whse_code$,dom=*next)ivcWhseCode$
	if ivcWhseCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Do not allow dropshipping kitted items
	if pos(callpoint!.getDevObject("kit")="YP") and callpoint!.getUserInput()=callpoint!.getDevObject("dropship_whse") then
		msg_id$="OP_DROPSHIP_KIT"
		dim msg_tokens$[1]
		msg_tokens$[1]=cvs(callpoint!.getColumnData("IVM_ITEMWHSE.ITEM_ID"),2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

[[IVM_ITEMWHSE.<CUSTOM>]]
rem ==========================================================================
disableKitFields: rem --- Enable/disable fields for kitted items
rem ==========================================================================
	if pos(callpoint!.getDevObject("kit")="YP") then
		rem --- Disable Warehouse tab fields
		callpoint!.setColumnData("IVM_ITEMWHSE.LOCATION","",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LOCATION",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.SPECIAL_ORD","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SPECIAL_ORD",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.SELECT_PHYS","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SELECT_PHYS",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.LSTPHY_DATE","",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LSTPHY_DATE",0)
		if callpoint!.getDevObject("kit")="Y" then
			rem --- Disable price for non-priced kit items
			callpoint!.setColumnData("IVM_ITEMWHSE.CUR_PRICE","0",1)
			callpoint!.setColumnEnabled("IVM_ITEMWHSE.CUR_PRICE",0)
			callpoint!.setColumnData("IVM_ITEMWHSE.CUR_PRICE_CD","",1)
			callpoint!.setColumnEnabled("IVM_ITEMWHSE.CUR_PRICE_CD",0)
		else
			rem --- Enable price for priced kit items
			callpoint!.setColumnEnabled("IVM_ITEMWHSE.CUR_PRICE",1)
			callpoint!.setColumnEnabled("IVM_ITEMWHSE.CUR_PRICE_CD",1)
		endif
		callpoint!.setColumnData("IVM_ITEMWHSE.PRI_PRICE","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PRI_PRICE",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.PRI_PRICE_CD","",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PRI_PRICE_CD",0)
		rem --- UNIT_COST: Handled separately in ADIS and AREC
		rem --- LANDED_COST: Handled separately in ADIS and AREC
		rem --- LAST_PO_COST: Handled separately in ADIS and AREC
		rem --- AVG_COST: Handled separately in ADIS and AREC
		rem --- STD_COST: Handled separately in ADIS and AREC
		rem --- REP_COST: Handled separately in ADIS and AREC
		rem --- PRODUCT_TYPE: hidden don't clear, initialized to itemmast_tpl.product_type$

		rem --- Disable Stocking tab fields
		callpoint!.setColumnData("IVM_ITEMWHSE.ABC_CODE","",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.ABC_CODE",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.BUYER_CODE","",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.BUYER_CODE",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.VENDOR_ID","",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.VENDOR_ID",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.LEAD_TIME","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LEAD_TIME",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.MAXIMUM_QTY","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.MAXIMUM_QTY",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.ORDER_POINT","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.ORDER_POINT",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.EOQ","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.EOQ",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.SAFETY_STOCK","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SAFETY_STOCK",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.ORD_PNT_CODE","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.ORD_PNT_CODE",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.EOQ_CODE","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.EOQ_CODE",0)
		callpoint!.setColumnData("IVM_ITEMWHSE.SAF_STK_CODE","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SAF_STK_CODE",0)
	else
		rem --- Get inventory defaults
		dim ivs10d$:fnget_tpl$("IVS_DEFAULTS")
		ivs10d$=callpoint!.getDevObject("ivs10d")

		rem --- Enable Warehouse tab fields
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LOCATION",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PI_CYCLECODE",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SPECIAL_ORD",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SELECT_PHYS",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LSTPHY_DATE",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.CUR_PRICE",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.CUR_PRICE_CD",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PRI_PRICE",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.PRI_PRICE_CD",1)
		rem --- UNIT_COST: Handled separately in ADIS and AREC
		rem --- LANDED_COST: Handled separately in ADIS and AREC
		rem --- LAST_PO_COST: Handled separately in ADIS and AREC
		rem --- AVG_COST: Handled separately in ADIS and AREC
		rem --- STD_COST: Handled separately in ADIS and AREC
		rem --- REP_COST: Handled separately in ADIS and AREC
		rem --- PRODUCT_TYPE -- hidden don't clear, initialized to itemmast_tpl.product_type$

		rem --- Enable Stocking tab fields
		callpoint!.setColumnData("IVM_ITEMWHSE.ABC_CODE",ivs10d.abc_code$,1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.ABC_CODE",1)
		callpoint!.setColumnData("IVM_ITEMWHSE.BUYER_CODE",ivs10d.buyer_code$,1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.BUYER_CODE",1)
		rem --- NOTE: The VENDOR_ID field remains permanently disable if if AP not installed
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.VENDOR_ID",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.LEAD_TIME",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.MAXIMUM_QTY",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.ORDER_POINT",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.EOQ",1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SAFETY_STOCK",1)
		callpoint!.setColumnData("IVM_ITEMWHSE.ORD_PNT_CODE",ivs10d.ord_pnt_code$,1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.ORD_PNT_CODE",1)
		callpoint!.setColumnData("IVM_ITEMWHSE.EOQ_CODE",ivs10d.eoq_code$,1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.EOQ_CODE",1)
		callpoint!.setColumnData("IVM_ITEMWHSE.SAF_STK_CODE",ivs10d.saf_stk_code$,1)
		callpoint!.setColumnEnabled("IVM_ITEMWHSE.SAF_STK_CODE",1)
	endif

	return

#include [+ADDON_LIB]std_missing_params.aon
#include [+ADDON_LIB]std_functions.aon



