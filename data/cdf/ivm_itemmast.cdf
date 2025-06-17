[[IVM_ITEMMAST.ABC_CODE.AVAL]]
if (callpoint!.getUserInput()<"A" or callpoint!.getUserInput()>"Z") and callpoint!.getUserInput()<>" " callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.ADIS]]
rem --- Set Description Segments

	desc$ = pad(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_DESC"), 90)
	gosub set_desc_segs

rem --- Save old Bar Code and UPC Code for Synonym Maintenance

	user_tpl.old_barcode$=callpoint!.getColumnData("IVM_ITEMMAST.BAR_CODE")
	user_tpl.old_upc$=callpoint!.getColumnData("IVM_ITEMMAST.UPC_CODE")

rem --- store lot/serialized flag in devObject for use later

	callpoint!.setDevObject("lot_serial_flag",callpoint!.getColumnData("IVM_ITEMMAST.LOTSER_FLAG"))

rem --- set flag in devObject to say we're not on a new record

	callpoint!.setDevObject("new_rec","N")

rem --- Store starting product_type so we'll know later if it was changed.
	callpoint!.setDevObject("start_product_type",callpoint!.getColumnData("IVM_ITEMMAST.PRODUCT_TYPE"))

	gosub enableLS
	gosub enableSellPurchUM

rem --- Show TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		taxSvcCd$=cvs(callpoint!.getColumnData("IVM_ITEMMAST.TAX_SVC_CD"),2)
		if taxSvcCd$<>"" then
			salesTax!=callpoint!.getDevObject("salesTax")
			success=0
			desc$=salesTax!.getTaxSvcCdDesc(taxSvcCd$,err=*next); success=1
			if success then
				if desc$<>"" then
					rem --- Good code entered
					tax_svc_cd_desc!.setText(desc$)
				else
					rem --- Bad code entered
					msg_id$="OP_BAD_TAXSVC_CD"
					dim msg_tokens$[1]
					msg_tokens$[1]=taxSvcCd$
					gosub disp_message

					tax_svc_cd_desc!.setText("?????")
				endif
			else
				rem --- AvaTax call error
				tax_svc_cd_desc!.setText("?????")
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

rem --- disable lot/ser trans hist if item isn't lot/serial
	if pos(callpoint!.getColumnData("IVM_ITEMMAST.LOTSER_FLAG")="LS")=0 callpoint!.setOptionEnabled("LTRN",0)


	rem --- Lotted/serialized items cannot be kitted
	if callpoint!.getColumnData("IVM_ITEMMAST.LOTSER_FLAG")<>"N" then
		callpoint!.setColumnData("IVM_ITEMMAST.KIT","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",0)
	else
		if callpoint!.getDevObject("bm_installed")="Y" then
			rem --- Kitting is not allowed if the corresponding BOM is NOT a phantom and it include either operations or subcontracts
			bmm01_dev=fnget_dev("BMM_BILLMAST")
			dim bmm01$:fnget_tpl$("BMM_BILLMAST")
			item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
			findrecord(bmm01_dev,key=firm_id$+item_id$,dom=*next)bmm01$
			if bmm01.phantom_bill$="Y" then
				bmm03_dev=fnget_dev("BMM_BILLOPER")
				bmm03Found=0
				read(bmm03_dev,key=firm_id$+item_id$,dom=*next)
				bmm03_key$=key(bmm03_dev,end=*next)
				if pos(firm_id$+item_id$=bmm03_key$) then bmm03Found=1

				bmm05_dev=fnget_dev("BMM_BILLSUB")
				bmm05Found=0
				read(bmm05_dev,key=firm_id$+item_id$,dom=*next)
				bmm05_key$=key(bmm05_dev,end=*next)
				if pos(firm_id$+item_id$=bmm05_key$) then bmm03Found=1

				if bmm03Found or bmm05Found then
					callpoint!.setColumnData("IVM_ITEMMAST.KIT","N",1)
					callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",0)
				endif
			else
				callpoint!.setColumnData("IVM_ITEMMAST.KIT","N",1)
				callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",0)
			endif
		endif
	endif
	callpoint!.setDevObject("kit",callpoint!.getColumnData("IVM_ITEMMAST.KIT"))

rem --- Enable/disable fields for kitted items
	gosub disableKitFields

[[IVM_ITEMMAST.AENA]]
rem --- Disable Barista menu items
	wctl$="31031"; rem --- Save-As menu item in barista.ini
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)="X"
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP")

[[IVM_ITEMMAST.AOPT-BOMU]]
rem --- Display Where Used from BOMs

cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"BMR_MATERIALUSED",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-CITM]]
rem --- Copy item

	cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
	user_id$=stbl("+USER_ID")
	dim dflt_data$[1,1]
	dflt_data$[1,0]="OLD_ITEM"
	dflt_data$[1,1]=cp_item_id$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"IVM_COPYITEM",
:		user_id$,
:		"",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

rem --- Edit the item just copied

	new_item_id$ = str(callpoint!.getDevObject("new_item_id"))

	if new_item_id$ <> "" then
		callpoint!.setStatus("RECORD:["+firm_id$+new_item_id$+"]")
	endif

[[IVM_ITEMMAST.AOPT-HCPY]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_ITEMDETAIL",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-IHST]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_TRANSHIST",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-ITAV]]
rem --- Show availability this item

	item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")

	selected_key$ = ""
	dim filter_defs$[1,2]
	filter_defs$[0,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"
	filter_defs$[1,0]="IVM_ITEMWHSE.ITEM_ID"
	filter_defs$[1,1]="='"+item_id$+"'"
	filter_defs$[1,2]="LOCK"

	dim search_defs$[3]

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"IV_PRICE_AVAIL",
:		"",
:		table_chans$[all],
:		selected_key$,
:		filter_defs$[all],
:		search_defs$[all],
:		"",
:		""

[[IVM_ITEMMAST.AOPT-LIFO]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_LIFOFIFO",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-LOOK]]
rem --- call the custom item lookup form, so we can look for an item by product type, synonym, etc.

select_key$=""
call stbl("+DIR_SYP")+"bam_run_prog.bbj","IVC_ITEMLOOKUP",stbl("+USER_ID"),"MNT","",table_chans$[all]
select_key$=str(bbjapi().getObjectTable().get("find_item"))
if select_key$="null" then select_key$=""
if select_key$<>"" then callpoint!.setStatus("RECORD:["+select_key$+"]")

[[IVM_ITEMMAST.AOPT-LTRN]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID_1"
dflt_data$[1,1]=cp_item_id$
dflt_data$[2,0]="ITEM_ID_2"
dflt_data$[2,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_LSTRANHIST",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-PORD]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID"
dflt_data$[1,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_OPENPO",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-RORD]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID"
dflt_data$[1,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_POREQS",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-SHST]]
rem --- Launch item sales analysis form
	user_id$=stbl("+USER_ID")
	year$=sysinfo.system_date$(1,4)
	product_type$=callpoint!.getColumnData("IVM_ITEMMAST.PRODUCT_TYPE")
	item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
	sam_item_key$=firm_id$+year$+product_type$+item_id$
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SAM_ITEM",
:		user_id$,
:		"EXP-INQ",
:		sam_item_key$,
:		table_chans$[all]

[[IVM_ITEMMAST.AOPT-SORD]]
cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="ITEM_ID"
dflt_data$[1,1]=cp_item_id$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	"IVR_OPENSO",
:	user_id$,
:	"",
:	"",
:	table_chans$[all],
:	"",
:	dflt_data$[all]

[[IVM_ITEMMAST.AOPT-STOK]]
rem --- Populate Stocking Info in Warehouses
	cp_item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
	user_id$=stbl("+USER_ID")
	dim dflt_data$[6,1]
	dflt_data$[1,0]="ITEM_ID"
	dflt_data$[1,1]=cp_item_id$
	ivs10d_dev=fnget_dev("IVS_DEFAULTS")
	ivs10d_tpl$=fnget_tpl$("IVS_DEFAULTS")
	dim ivs10d$:ivs10d_tpl$
	read record (ivs10d_dev,key=firm_id$+"D") ivs10d$
	dflt_data$[2,0]="ABC_CODE"
	dflt_data$[2,1]=ivs10d.abc_code$
	dflt_data$[3,0]="BUYER_CODE"
	dflt_data$[3,1]=ivs10d.buyer_code$
	dflt_data$[4,0]="EOQ_CODE"
	dflt_data$[4,1]=ivs10d.eoq_code$
	dflt_data$[5,0]="ORD_PNT_CODE"
	dflt_data$[5,1]=ivs10d.ord_pnt_code$
	dflt_data$[6,0]="SAF_STK_CODE"
	dflt_data$[6,1]=ivs10d.saf_stk_code$
	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                       "IVM_STOCK",
:                       user_id$,
:                   	"",
:                       "",
:                       table_chans$[all],
:                       "",
:                       dflt_data$[all]

[[IVM_ITEMMAST.AREC]]
rem -- Get default values for new record from ivs-10D, IVS_DEFAULTS

	ivs10_dev=fnget_dev("IVS_DEFAULTS")
	dim ivs10d$:fnget_tpl$("IVS_DEFAULTS")
	callpoint!.setColumnData("IVM_ITEMMAST.ALT_SUP_FLAG", "N")
	callpoint!.setColumnData("IVM_ITEMMAST.CONV_FACTOR", "1")
	callpoint!.setColumnData("IVM_ITEMMAST.ORDER_POINT", "D")
	callpoint!.setColumnData("IVM_ITEMMAST.BAR_CODE", callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID"))

	find record (ivs10_dev, key=firm_id$+"D", dom=*next) ivs10d$

	callpoint!.setColumnData("IVM_ITEMMAST.PRODUCT_TYPE",ivs10d.product_type$)
	callpoint!.setColumnData("IVM_ITEMMAST.UNIT_OF_SALE",ivs10d.unit_of_sale$)
	callpoint!.setColumnData("IVM_ITEMMAST.PURCHASE_UM",ivs10d.purchase_um$)
	callpoint!.setColumnData("IVM_ITEMMAST.TAXABLE_FLAG",ivs10d.taxable_flag$)
	callpoint!.setColumnData("IVM_ITEMMAST.BUYER_CODE",ivs10d.buyer_code$)
	callpoint!.setColumnData("IVM_ITEMMAST.LOTSER_FLAG",ivs10d.lotser_flag$)
	callpoint!.setColumnData("IVM_ITEMMAST.INVENTORIED",ivs10d.inventoried$)
	callpoint!.setColumnData("IVM_ITEMMAST.ITEM_CLASS",ivs10d.item_class$)
	callpoint!.setColumnData("IVM_ITEMMAST.STOCK_LEVEL","W")
	callpoint!.setColumnData("IVM_ITEMMAST.ABC_CODE",ivs10d.abc_code$)
	callpoint!.setColumnData("IVM_ITEMMAST.EOQ_CODE",ivs10d.eoq_code$)
	callpoint!.setColumnData("IVM_ITEMMAST.ORD_PNT_CODE",ivs10d.ord_pnt_code$)
	callpoint!.setColumnData("IVM_ITEMMAST.SAF_STK_CODE",ivs10d.saf_stk_code$)
	callpoint!.setColumnData("IVM_ITEMMAST.ITEM_TYPE",ivs10d.item_type$)
	callpoint!.setColumnData("IVM_ITEMMAST.GL_INV_ACCT",ivs10d.gl_inv_acct$)
	callpoint!.setColumnData("IVM_ITEMMAST.GL_COGS_ACCT",ivs10d.gl_cogs_acct$)
	callpoint!.setColumnData("IVM_ITEMMAST.GL_PUR_ACCT",ivs10d.gl_pur_acct$)
	callpoint!.setColumnData("IVM_ITEMMAST.GL_PPV_ACCT",ivs10d.gl_ppv_acct$)
	callpoint!.setColumnData("IVM_ITEMMAST.GL_INV_ADJ",ivs10d.gl_inv_adj$)
	callpoint!.setColumnData("IVM_ITEMMAST.GL_COGS_ADJ",ivs10d.gl_cogs_adj$)

	if user_tpl.sa$ <> "Y" then
		callpoint!.setColumnData("IVM_ITEMMAST.SA_LEVEL","N")
	else
		ivm10_dev = fnget_dev("IVC_PRODCODE")
		dim ivm10a$:fnget_tpl$("IVC_PRODCODE")
		find record(ivm10_dev, key=firm_id$+"A"+ivs10d.product_type$, dom=*next)ivm10a$
		callpoint!.setColumnData("IVM_ITEMMAST.SA_LEVEL", ivm10a.sa_level$)
	endif

	
	callpoint!.setStatus("REFRESH")

rem --- Clear TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		tax_svc_cd_desc!.setText("")
	endif

rem --- set flag in devObject to say we're on a new record

	callpoint!.setDevObject("new_rec","Y")

[[IVM_ITEMMAST.ARNF]]
rem --- item not found (so assuming new record); default bar code to item id

callpoint!.setColumnData("IVM_ITEMMAST.BAR_CODE", callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID"))
callpoint!.setStatus("REFRESH")

[[IVM_ITEMMAST.ASHO]]
callpoint!.setStatus("ABLEMAP-REFRESH")

rem --- Disable TAX_SVC_CD when OP is not installed
	callpoint!.setDevObject("salesTax",null())
	if callpoint!.getDevObject("op")<>"Y" then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.TAX_SVC_CD",-1)
	else
		rem --- Disable TAX_SVC_CD when OP is not using a Sales Tax Service
		ops_params_dev=fnget_dev("OPS_PARAMS")
		dim ops_params$:fnget_tpl$("OPS_PARAMS")
		find record (ops_params_dev,key=firm_id$+"AR00",err=std_missing_params)ops_params$
		if cvs(ops_params.sls_tax_intrface$,2)="" then
			callpoint!.setColumnEnabled("IVM_ITEMMAST.TAX_SVC_CD",-1)
		else
			rem --- Get connection to Sales Tax Service
			salesTax!=new AvaTaxInterface(firm_id$)
			if salesTax!.connectClient(Form!,err=connectErr) then
				callpoint!.setDevObject("salesTax",salesTax!)
				callpoint!.setColumnEnabled("IVM_ITEMMAST.TAX_SVC_CD",1)
			else
				callpoint!.setColumnEnabled("IVM_ITEMMAST.TAX_SVC_CD",0)
				salesTax!.close()
			endif
		endif
	endif

	break

connectErr:
	callpoint!.setColumnEnabled("IVM_ITEMMAST.TAX_SVC_CD",0)
	if salesTax!<>null() then salesTax!.close()

	break

[[IVM_ITEMMAST.AWRI]]
rem --- Write synonyms of the Item Number, UPC Code and Bar Code
	ivm_itemsyn_dev=fnget_dev("IVM_ITEMSYN")
	dim ivm_itemsyn$:fnget_tpl$("IVM_ITEMSYN")
	ivm_itemsyn.firm_id$=firm_id$
	item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
	ivm_itemsyn.item_synonym$=item_id$
	ivm_itemsyn.item_id$=item_id$
	ivm_itemsyn_key$=ivm_itemsyn.firm_id$+ivm_itemsyn.item_synonym$+ivm_itemsyn.item_id$
	extract record (ivm_itemsyn_dev,key=ivm_itemsyn_key$,dom=*next)x$; rem Advisory Locking
	ivm_itemsyn$=field(ivm_itemsyn$)
	write record (ivm_itemsyn_dev) ivm_itemsyn$

rem --- Remove old UPC Code and Bar Code
	if cvs(user_tpl.old_barcode$,3)<>"" and user_tpl.old_barcode$<>item_id$
		ivm_itemsyn.item_synonym$=user_tpl.old_barcode$
		ivm_itemsyn.item_id$=item_id$
		remove(ivm_itemsyn_dev,key=firm_id$+ivm_itemsyn.item_synonym$+ivm_itemsyn.item_id$,dom=*next)
	endif
	if cvs(user_tpl.old_upc$,3)<>"" and user_tpl.old_upc$<>item_id$
		ivm_itemsyn.item_synonym$=user_tpl.old_upc$
		ivm_itemsyn.item_id$=item_id$
		remove(ivm_itemsyn_dev,key=firm_id$+ivm_itemsyn.item_synonym$+ivm_itemsyn.item_id$,dom=*next)
	endif

rem --- Add new UPC Code and Bar Code
	if cvs(callpoint!.getColumnData("IVM_ITEMMAST.BAR_CODE"),3)<>""
		ivm_itemsyn.item_synonym$=callpoint!.getColumnData("IVM_ITEMMAST.BAR_CODE")
		ivm_itemsyn.item_id$=item_id$
		ivm_itemsyn_key$=ivm_itemsyn.firm_id$+ivm_itemsyn.item_synonym$+ivm_itemsyn.item_id$
		extract record (ivm_itemsyn_dev,key=ivm_itemsyn_key$,dom=*next)x$; rem Advisory Locking
		ivm_itemsyn$=field(ivm_itemsyn$)
		write record (ivm_itemsyn_dev) ivm_itemsyn$
	endif
	if cvs(callpoint!.getColumnData("IVM_ITEMMAST.UPC_CODE"),3)<>""
		ivm_itemsyn.item_synonym$=callpoint!.getColumnData("IVM_ITEMMAST.UPC_CODE")
		ivm_itemsyn.item_id$=item_id$
		ivm_itemsyn_key$=ivm_itemsyn.firm_id$+ivm_itemsyn.item_synonym$+ivm_itemsyn.item_id$
		extract record (ivm_itemsyn_dev,key=ivm_itemsyn_key$,dom=*next)x$; rem Advisory Locking
		ivm_itemsyn$=field(ivm_itemsyn$)
		write record (ivm_itemsyn_dev) ivm_itemsyn$
	endif

	user_tpl.old_barcode$=callpoint!.getColumnData("IVM_ITEMMAST.BAR_CODE")
	user_tpl.old_upc$=callpoint!.getColumnData("IVM_ITEMMAST.UPC_CODE")

rem --- store lot/serialized flag in devObject for use later

	callpoint!.setDevObject("lot_serial_flag",callpoint!.getColumnData("IVM_ITEMMAST.LOTSER_FLAG"))

rem --- if this is a newly added record, launch warehouse/stocking, vendors, and synonymns forms

	if callpoint!.getDevObject("new_rec")="Y"

		user_id$=stbl("+USER_ID")
		dim dflt_data$[2,1]
		dflt_data$[1,0]="ITEM_ID"
		dflt_data$[1,1]=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
		key_pfx$=firm_id$+callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
		call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:			"IVM_ITEMWHSE",
:			user_id$,
:			"",
:			key_pfx$,
:			table_chans$[all],
:			"",
:			dflt_data$[all]

		if pos(callpoint!.getColumnData("IVM_ITEMMAST.KIT")="YP")=0 then
			call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:				"IVM_ITEMVEND",
:				user_id$,
:				"",
:				key_pfx$,
:				table_chans$[all],
:				"",
:				dflt_data$[all]
		endif

		call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:			"IVM_ITEMSYN",
:			user_id$,
:			"",
:			key_pfx$,
:			table_chans$[all],
:			"",
:			dflt_data$[all]

	else

		rem --- If product_type changed, update ivm_itemwhse product_type.
		if callpoint!.getColumnData("IVM_ITEMMAST.PRODUCT_TYPE")<>callpoint!.getDevObject("start_product_type") then
			ivm_itemwhse_dev=fnget_dev("IVM_ITEMWHSE")
			dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
			rem --- Get current key and knum so they can be restored when done here.
			start_key$=key(ivm_itemwhse_dev,end=*next)
			start_knum=BBjAPI().getFileSystem().getFileInfo(ivm_itemwhse_dev).getCurrentKeyNumber()

			rem --- Update ivm_itemwhse product_type with ivm_itemmast product_type
			trip_key$=firm_id$+callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
			read(ivm_itemwhse_dev,key=trip_key$,knum="AO_ITEM_WH",dom=*next)
			while 1
				ivm_itemwhse_key$=key(ivm_itemwhse_dev,end=*break)
				if pos(trip_key$=ivm_itemwhse_key$)<>1 then break
				extractrecord(ivm_itemwhse_dev)ivm_itemwhse$
				ivm_itemwhse.product_type$=callpoint!.getColumnData("IVM_ITEMMAST.PRODUCT_TYPE")
				writerecord(ivm_itemwhse_dev)ivm_itemwhse$
			wend

			rem --- Reset key and knum back to their starting value
			read(ivm_itemwhse_dev,key=start_key$,knum=start_knum,dir=0,err=*next)
		endif

	endif

[[IVM_ITEMMAST.BDEL]]
rem --- Allow this item to be deleted?

	action$ = "I"
	whse$   = ""
	item$   = callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")

	if cvs(item$, 2) <> "" then
		call stbl("+DIR_PGM")+"ivc_deleteitem.aon", action$, whse$, item$, rd_table_chans$[all], status
		if status then callpoint!.setStatus("ABORT")
	endif

[[IVM_ITEMMAST.BDTW]]
rem --- Don't allow launching Vendor Detail form for kits
	if pos(callpoint!.getColumnData("IVM_ITEMMAST.KIT")="YP") and pos(callpoint!.getEventOptionStr()="DTLW-IVM_ITEMVEND") then
		msg_id$="OP_KIT_NO_VENDOR"
		dim msg_tokens$[1]
		msg_tokens$[1]=cvs(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID"),2)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVM_ITEMMAST.BEND]]
rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[IVM_ITEMMAST.BSHO]]
rem --- Inits

	use ::ado_util.src::util
	use ::ado_func.src::func
	use ::opo_AvaTaxInterface.aon::AvaTaxInterface

rem --- Is Sales Order Processing installed?

	call dir_pgm1$+"adc_application.aon","OP",info$[all]
	op$=info$[20]
	callpoint!.setDevObject("op",op$)

rem --- Open/Lock files

	num_files=12
	if op$="Y" then num_files=12
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="IVS_DEFAULTS",open_opts$[2]="OTA"
	open_tables$[3]="GLS_PARAMS",open_opts$[3]="OTA"
	open_tables$[4]="ARS_PARAMS",open_opts$[4]="OTA"
	open_tables$[5]="IVM_ITEMWHSE",open_opts$[5]="OTA"
	open_tables$[7]="IVM_ITEMSYN",open_opts$[7]="OTA"
	open_tables$[8]="IVT_ITEMTRAN",open_opts$[8]="OTA"
	open_tables$[9]="IVM_LSMASTER",open_opts$[9]="OTA"
	open_tables$[10]="IVM_LSACT",open_opts$[10]="OTA"
	open_tables$[11]="IVT_LSTRANS",open_opts$[11]="OTA"
	open_tables$[12]="IVC_PRODCODE",open_opts$[12]="OTA"
	if op$="Y" then open_tables$[9]="OPS_PARAMS",open_opts$[9]="OTA"

	gosub open_tables
	if status$ <> ""  then goto std_exit

	ivs01_dev=num(open_chans$[1]),ivs01d_dev=num(open_chans$[2]),gls01_dev=num(open_chans$[3])
	ars01_dev=num(open_chans$[4]),ivm02_dev=num(open_chans$[5])

rem --- Dimension miscellaneous string templates

	dim ivs01a$:open_tpls$[1],ivs01d$:open_tpls$[2],gls01a$:open_tpls$[3],ars01a$:open_tpls$[4]
	dim ivm02a$:open_tpls$[5]

rem --- check to see if main GL param rec (firm/GL/00) exists; if not, tell user to set it up first
	gls01a_key$=firm_id$+"GL00"
	find record (gls01_dev,key=gls01a_key$,err=*next) gls01a$
	if cvs(gls01a.current_per$,2)=""
		msg_id$="GL_PARAM_ERR"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		gosub remove_process_bar
		release
	endif

rem --- init/parameters

	dim info$[20]

	ivs01a_key$=firm_id$+"IV00"
	find record (ivs01_dev,key=ivs01a_key$,err=std_missing_params) ivs01a$

	dir_pgm1$=stbl("+DIR_PGM",err=*next)
	call dir_pgm1$+"adc_application.aon","AR",info$[all]
	ar$=info$[20]
	call dir_pgm1$+"adc_application.aon","AP",info$[all]
	ap$=info$[20]
	callpoint!.setDevObject("ap_installed",ap$)
	call dir_pgm1$+"adc_application.aon","BM",info$[all]
	bm$=info$[20]
	callpoint!.setDevObject("bm_installed",bm$)
	call dir_pgm1$+"adc_application.aon","GL",info$[all]
	gl$=info$[20]
	call dir_pgm1$+"adc_application.aon","OP",info$[all]
	op$=info$[20]
	callpoint!.setDevObject("op_installed",op$)
	call dir_pgm1$+"adc_application.aon","PO",info$[all]
	po$=info$[20]
	call dir_pgm1$+"adc_application.aon","SF",info$[all]
	wo$=info$[20]
	callpoint!.setDevObject("wo_installed",wo$)
	call dir_pgm1$+"adc_application.aon","SA",info$[all]
	sa$=info$[20]

rem --- Setup user_tpl$

	dim user_tpl$:"sa:c(1)," +
:                "desc_len_01:n(1*), desc_len_02:n(1*), desc_len_03:n(1*)," +
:                "prev_desc_seg_1:c(1*), prev_desc_seg_2:c(1*), prev_desc_seg_3:c(1*)," +
:                "old_upc:c(1*),old_barcode:c(1*)"

	user_tpl.sa$=sa$

rem --- Setup description lengths

	user_tpl.desc_len_01 = num(ivs01a.desc_len_01$)
	user_tpl.desc_len_02 = num(ivs01a.desc_len_02$)
	user_tpl.desc_len_03 = num(ivs01a.desc_len_03$)

	func.setLen1(int(user_tpl.desc_len_01))
	func.setLen2(int(user_tpl.desc_len_02))
	func.setLen3(int(user_tpl.desc_len_03))

rem --- Set user labels and lengths for description segments 

	util.changeText(Form!, Translate!.getTranslation("AON_SEGMENT_DESCRIPTION_1:"), cvs(ivs01a.user_desc_lb_01$, 2) + ":")
	callpoint!.setTableColumnAttribute("<<DISPLAY>>.ITEM_DESC_SEG_1", "MAXL", str(user_tpl.desc_len_01))
	first_desc!=util.getControl(Form!,callpoint!,"<<DISPLAY>>.ITEM_DESC_SEG_1")
	first_desc!.setMask(fill(user_tpl.desc_len_01,"X"))

	if cvs(ivs01a.user_desc_lb_02$, 2) <> "" then
		util.changeText(Form!, Translate!.getTranslation("AON_SEGMENT_DESCRIPTION_2:"), cvs(ivs01a.user_desc_lb_02$, 2) + ":")
	else
		util.changeText(Form!, Translate!.getTranslation("AON_SEGMENT_DESCRIPTION_2:"), "")
	endif

	if user_tpl.desc_len_02 <> 0 then
		callpoint!.setTableColumnAttribute("<<DISPLAY>>.ITEM_DESC_SEG_2", "MAXL", str(user_tpl.desc_len_02))
		second_desc!=util.getControl(Form!,callpoint!,"<<DISPLAY>>.ITEM_DESC_SEG_2")
		second_desc!.setMask(fill(user_tpl.desc_len_02,"X"))
	else
		callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_DESC_SEG_2", -1)
	endif

	if cvs(ivs01a.user_desc_lb_03$, 2) <> "" then 
		util.changeText(Form!, Translate!.getTranslation("AON_SEGMENT_DESCRIPTION_3:"), cvs(ivs01a.user_desc_lb_03$, 2) + ":")
	else
		util.changeText(Form!, Translate!.getTranslation("AON_SEGMENT_DESCRIPTION_3:"), "")
	endif

	if user_tpl.desc_len_03 <>0 then
		callpoint!.setTableColumnAttribute("<<DISPLAY>>.ITEM_DESC_SEG_3", "MAXL", str(user_tpl.desc_len_03))
		third_desc!=util.getControl(Form!,callpoint!,"<<DISPLAY>>.ITEM_DESC_SEG_3")
		third_desc!.setMask(fill(user_tpl.desc_len_03,"X"))
	else
		callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_DESC_SEG_3", -1)
	endif

rem --- Disable option menu items

	callpoint!.setOptionEnabled("STOK",0); rem --- per bug 5774, disabled for now
	if ap$<>"Y" then callpoint!.setOptionEnabled("IVM_ITEMVEND",0)
	if pos(ivs01a.lifofifo$="LF")=0 callpoint!.setOptionEnabled("LIFO",0)
	if op$<>"Y" callpoint!.setOptionEnabled("SORD",0)
	if po$<>"Y" callpoint!.setOptionEnabled("PORD",0)
	if bm$<>"Y" callpoint!.setOptionEnabled("BOMU",0)

rem --- additional file opens, depending on which apps are installed, param values, etc.

	more_files$=""
	files=0

	if pos(ivs01a.lifofifo$="LF")<>0 then 
		more_files$=more_files$+"IVM_ITEMTIER;"
		files=files+1
	endif

	if ar$="Y" then 
		more_files$=more_files$+"ARM_CUSTMAST;ARC_DISTCODE;"
		files=files+2
	endif

	if bm$="Y" then 
		more_files$=more_files$+"BMM_BILLMAST;BMM_BILLMAT;BMM_BILLOPER;BMM_BILLSUB;"
		files=files+4
	else
		rem --- Disable and hide KIT field when BM not installed
		callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",-1)
		kitCtrl!=callpoint!.getControl("IVM_ITEMMAST.KIT")
		kitCtrl!.setVisible(0)
		tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
		tabCtrl!.setLocation(tabCtrl!.getX(),tabCtrl!.getY()-25)
	endif

	if op$="Y" then 
		more_files$=more_files$+"OPS_PARAMS;OPE_ORDHDR;OPE_ORDDET;"
		files=files+3
	endif

	if po$="Y" then 
		more_files$=more_files$+"POE_REQHDR;POE_POHDR;POE_REQDET;POE_PODET;POC_LINECODE;POT_RECHDR;POT_RECDET;"
		files=files+7
	endif

	if wo$="Y" then 
		more_files$=more_files$+"SFE_WOMASTR;SFE_WOMATL;"
		files=files+2
	endif

	if files then
		begfile=1,endfile=files,wfile=1
		dim files$[files],options$[files],chans$[files],templates$[files]

		while pos(";"=more_files$)
			files$[wfile]=more_files$(1,pos(";"=more_files$)-1)
			more_files$=more_files$(pos(";"=more_files$)+1)
			wfile=wfile+1
		wend

		for wkx=begfile to endfile
			options$[wkx]="OTA"
		next wkx

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:	                                 	chans$[all],templates$[all],table_chans$[all],batch,status$
		if status$<>"" then
			remove_process_bar:
			bbjAPI!=bbjAPI()
			rdFuncSpace!=bbjAPI!.getGroupNamespace()
			rdFuncSpace!.setValue("+build_task","OFF")
			release
		endif
	endif

rem --- if gl installed, does it interface to inventory?

	if gl$="Y" 
		call dir_pgm1$+"adc_application.aon","IV",info$[all]
		gl$=info$[9]
	endif

rem --- Distribute GL by item?

	di$="N"
	if ar$="Y"
		rem --- check to see if main AR param rec (firm/AR/00) exists; if not, tell user to set it up first
		ars01a_key$=firm_id$+"AR00"
		find record (ars01_dev,key=ars01a_key$,err=*next) ars01a$
		if cvs(ars01a.current_per$,2)=""
			msg_id$="AR_PARAM_ERR"
			dim msg_tokens$[1]
			msg_opt$=""
			gosub disp_message
			gosub remove_process_bar
			release
		endif

		di$=ars01a.dist_by_item$
		if gl$="N" di$="N"
	endif
	callpoint!.setDevObject("di",di$)

rem --- Disable fields based on parameters

	able_map = 0
	wmap$=callpoint!.getAbleMap()

rem --- Don't allow SELL_PURCH_UM if not allowed in IVS_PARAMS or not using lotted/serialized inventory.
	allow_SellPurchUM$="Y"
	if ivs01a.sell_purch_um$<>"Y" then
		allow_SellPurchUM$="N"
	endif
	callpoint!.setDevObject("allow_SellPurchUM",allow_SellPurchUM$)

rem --- If you don't distribute by item, or there's no GL, disable GL fields

	if di$<>"N" or gl$<>"Y"
		fields_to_disable$="GL_INV_ACCT     GL_COGS_ACCT    GL_PUR_ACCT     GL_PPV_ACCT     GL_INV_ADJ      GL_COGS_ADJ     "
		for wfield=1 to len(fields_to_disable$)-1 step 16
			callpoint!.setColumnEnabled("IVM_ITEMMAST."+cvs(fields_to_disable$(wfield,16),3),-1)					
		next wfield
	endif

rem --- Disable Sales Analysis level if SA is not installed 

	if sa$<>"Y" then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.SA_LEVEL",-1)
	endif

rem ... Creating WOs from Sales Orders?
	op_create_wo$=""
	if op$="Y" then
		opsParams_dev=fnget_dev("OPS_PARAMS")
		dim opsParams$:fnget_tpl$("OPS_PARAMS")
		findrecord (opsParams_dev,key=firm_id$+"AR00",dom=*next)opsParams$
		op_create_wo$=opsParams.op_create_wo$
	endif
	callpoint!.setDevObject("op_create_wo",op_create_wo$)

rem --- Add static label for displaying TAX_SVC_CD description
tax_svc_cd!=fnget_control!("IVM_ITEMMAST.TAX_SVC_CD")
tax_svc_cd_x=tax_svc_cd!.getX()
tax_svc_cd_y=tax_svc_cd!.getY()
tax_svc_cd_height=tax_svc_cd!.getHeight()
tax_svc_cd_width=tax_svc_cd!.getWidth()
code_desc!=fnget_control!("IVM_ITEMMAST.UPC_CODE")
code_desc_width=code_desc!.getWidth()
nxt_ctlID=util.getNextControlID()
item_tab!=tax_svc_cd!.getParentWindow()
tax_svc_cd_desc!=item_tab!.addStaticText(nxt_ctlID,tax_svc_cd_x+tax_svc_cd_width+5,tax_svc_cd_y+3,int(code_desc_width*1.5),tax_svc_cd_height-3,"")
call stbl("+DIR_SYP")+"bac_create_color.bbj","+TAB_CHILD_COLOR","250,250,250",rdTabChildColor!,""
tax_svc_cd_desc!.setBackColor(rdTabChildColor!)
callpoint!.setDevObject("tax_svc_cd_desc",tax_svc_cd_desc!)

[[IVM_ITEMMAST.BUYER_CODE.AVAL]]
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

[[IVM_ITEMMAST.BWRI]]
rem --- Is item code blank?

	if cvs(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID"), 2) = "" then
		msg_id$ = "IV_BLANK_ID"
		gosub disp_message
		callpoint!.setFocus("IVM_ITEMMAST.ITEM_ID")
	endif

	if cvs(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_DESC"),3)="" then 
		msg_id$="IV_BLANK_DESC"
		gosub disp_message
		callpoint!.setFocus("<<DISPLAY>>.ITEM_DESC_SEG_1")
	endif

[[IVM_ITEMMAST.CONV_FACTOR.AVAL]]
if num(callpoint!.getUserInput())<0 then
	callpoint!.setStatus("ABORT")
endif

[[IVM_ITEMMAST.EOQ.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.GL_COGS_ACCT.AVAL]]
gosub gl_active

[[IVM_ITEMMAST.GL_COGS_ADJ.AVAL]]
gosub gl_active

[[IVM_ITEMMAST.GL_INV_ACCT.AVAL]]
gosub gl_active

[[IVM_ITEMMAST.GL_INV_ADJ.AVAL]]
gosub gl_active

[[IVM_ITEMMAST.GL_PPV_ACCT.AVAL]]
gosub gl_active

[[IVM_ITEMMAST.GL_PUR_ACCT.AVAL]]
gosub gl_active

[[IVM_ITEMMAST.INVENTORIED.AVAL]]
rem --- Can't change Inventoried flag if there is QOH

	prev_inv_flag$=callpoint!.getColumnData("IVM_ITEMMAST.INVENTORIED")
	this_inv_flag$ = callpoint!.getUserInput()
	if this_inv_flag$ <> prev_inv_flag$ then
		gosub check_qoh
		if qoh then
			msg_id$ = "IV_CANT_CHANGE_CODE"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			callpoint!.setColumnData("IVM_ITEMMAST.INVENTORIED",prev_inv_flag$,1)
		else
			if this_inv_flag$="Y" then
				callpoint!.setColumnEnabled("IVM_ITEMMAST.LOTSER_FLAG",0)
			else
				callpoint!.setColumnEnabled("IVM_ITEMMAST.LOTSER_FLAG",1)
			endif
		endif
	endif

[[IVM_ITEMMAST.ITEM_CLASS.AVAL]]
	ivc_clascode=fnget_dev("IVC_CLASCODE")
	dim ivc_clascode$:fnget_tpl$("IVC_CLASCODE")
	item_class$=callpoint!.getUserInput()
	read record (ivc_clascode,key=firm_id$+item_class$,dom=*next)ivc_clascode$
	if ivc_clascode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivc_clascode.item_class$,3)
		msg_tokens$[2]=cvs(ivc_clascode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[<<DISPLAY>>.ITEM_DESC_SEG_1.AVAL]]
rem --- Set this section back into desc, if modified

	desc$ = pad(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_DESC"), 60)
	seg$  = callpoint!.getUserInput()

	if seg$ <> user_tpl.prev_desc_seg_1$ then
		desc$(1, user_tpl.desc_len_01) = seg$
		callpoint!.setColumnData("IVM_ITEMMAST.ITEM_DESC", desc$,1)
		callpoint!.setColumnData("<<DISPLAY>>.DESC_DISPLAY", func.displayDesc(desc$),1)
		callpoint!.setColumnData("IVM_ITEMMAST.DISPLAY_DESC", func.displayDesc(desc$),1)
		callpoint!.setStatus("MODIFIED")
	endif

[[<<DISPLAY>>.ITEM_DESC_SEG_1.BINP]]
rem --- Set previous value

	user_tpl.prev_desc_seg_1$ = callpoint!.getColumnData("<<DISPLAY>>.ITEM_DESC_SEG_1")

[[<<DISPLAY>>.ITEM_DESC_SEG_2.AVAL]]
rem --- Set this section back into desc, if modified

	desc$ = pad(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_DESC"), 60)
	seg$  = callpoint!.getUserInput()

	if seg$ <> user_tpl.prev_desc_seg_2$ then
		desc$(1 + user_tpl.desc_len_01, user_tpl.desc_len_02) = seg$
		callpoint!.setColumnData("IVM_ITEMMAST.ITEM_DESC", desc$,1)
		callpoint!.setColumnData("<<DISPLAY>>.DESC_DISPLAY", func.displayDesc(desc$),1)
		callpoint!.setColumnData("IVM_ITEMMAST.DISPLAY_DESC", func.displayDesc(desc$),1)
		callpoint!.setStatus("MODIFIED")
	endif

[[<<DISPLAY>>.ITEM_DESC_SEG_2.BINP]]
rem --- Set previous value

	user_tpl.prev_desc_seg_2$ = callpoint!.getColumnData("<<DISPLAY>>.ITEM_DESC_SEG_2")

[[<<DISPLAY>>.ITEM_DESC_SEG_3.AVAL]]
rem --- Set this section back into desc, if modified

	desc$ = pad(callpoint!.getColumnData("IVM_ITEMMAST.ITEM_DESC"), 60)
	seg$  = callpoint!.getUserInput()

	if seg$ <> user_tpl.prev_desc_seg_3$ then
		desc$(1 + user_tpl.desc_len_01 + user_tpl.desc_len_02, user_tpl.desc_len_03) = seg$
		callpoint!.setColumnData("IVM_ITEMMAST.ITEM_DESC", desc$,1)
		callpoint!.setColumnData("<<DISPLAY>>.DESC_DISPLAY", func.displayDesc(desc$),1)
		callpoint!.setColumnData("IVM_ITEMMAST.DISPLAY_DESC", func.displayDesc(desc$),1)
		callpoint!.setStatus("MODIFIED")
	endif

[[<<DISPLAY>>.ITEM_DESC_SEG_3.BINP]]
rem --- Set previous value

	user_tpl.prev_desc_seg_3$ = callpoint!.getColumnData("<<DISPLAY>>.ITEM_DESC_SEG_3")

[[IVM_ITEMMAST.ITEM_ID.AVAL]]
rem --- See if Auto Numbering in effect

	if cvs(callpoint!.getUserInput(), 2) = "" then 
		ivs01_dev = fnget_dev("IVS_PARAMS")
		dim ivs01a$:fnget_tpl$("IVS_PARAMS")
		read record (ivs01_dev, key=firm_id$+"IV00") ivs01a$

		if ivs01a.auto_no_iv$="N" then
			callpoint!.setStatus("ABORT")
		else
			item_len = num(callpoint!.getTableColumnAttribute("IVM_ITEMMAST.ITEM_ID","MAXL"))
			if item_len=0 then item_len=20; rem Needed?
			if ivs01a.auto_no_iv$="C" then item_len=item_len-1

			call stbl("+DIR_SYP")+"bas_sequences.bbj","ITEM_ID",item_id$,table_chans$[all]
			if item_id$="" then
				callpoint!.setStatus("ABORT")
				break
			endif
			next_num=num(item_id$)

			dim max_num$(min(item_len,10),"9")
			if next_num>num(max_num$) then 
				msg_id$="NO_MORE_NUMBERS"
				gosub disp_message
				callpoint!.setStatus("ABORT")
				break
			else
				chk_digit$ = ""
				if ivs01a.auto_no_iv$="C" then 
					precision 4
					chk_digit$=str(tim*10000),chk_digit$=chk_digit$(len(chk_digit$),1)
					precision num(ivs01a.precision$)
				endif

				callpoint!.setUserInput(item_id$+chk_digit$)
				callpoint!.setStatus("REFRESH")
			endif
		endif
	endif

[[IVM_ITEMMAST.KIT.AVAL]]
rem --- Set DevObject whether or not this is a kit
	kit$=callpoint!.getUserInput()
	callpoint!.setDevObject("kit",kit$)

rem --- Clear and disable fields not needed for a kit
	gosub disableKitFields

[[IVM_ITEMMAST.LEAD_TIME.AVAL]]
if num(callpoint!.getUserInput())<0 or fpt(num(callpoint!.getUserInput())) then callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.LOTSER_FLAG.AVAL]]
rem --- Disable inventoried if not lotted/serialized
	lotser_flag$=callpoint!.getUserInput()
	if !pos(lotser_flag$="LS") then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.INVENTORIED",0)
		callpoint!.setColumnData("IVM_ITEMMAST.INVENTORIED","N",1)
	else
		callpoint!.setColumnEnabled("IVM_ITEMMAST.INVENTORIED",1)
	endif

rem --- Disable sell_purch_um if lotted/serialized, or sell_purch_um not allowed
	if pos(lotser_flag$="LS") or callpoint!.getDevObject("allow_SellPurchUM")="N" then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",0)
		callpoint!.setColumnData("IVM_ITEMMAST.SELL_PURCH_UM","N",1)
	else
		callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",1)
	endif

rem --- Lotted/serialized items cannot be kitted
	if lotser_flag$<>"N" then
		callpoint!.setColumnData("IVM_ITEMMAST.KIT","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",0)
	else
		if callpoint!.getDevObject("bm_installed")="Y" then
			rem --- Allow a kit if the corresponding BOM is a phantom and does NOT include operations or subcontracts
			bmm01_dev=fnget_dev("BMM_BILLMAST")
			dim bmm01$:fnget_tpl$("BMM_BILLMAST")
			item_id$=callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
			bomFound=0
			findrecord(bmm01_dev,key=firm_id$+item_id$,dom=*next)bmm01$; bomFound=1
			if bomFound then
				if bmm01.phantom_bill$="Y" then
					bmm03_dev=fnget_dev("BMM_BILLOPER")
					bmm03Found=0
					read(bmm03_dev,key=firm_id$+item_id$,dom=*next)
					bmm03_key$=key(bmm03_dev,end=*next)
					if pos(firm_id$+item_id$=bmm03_key$) then bmm03Found=1

					bmm05_dev=fnget_dev("BMM_BILLSUB")
					bmm05Found=0
					read(bmm05_dev,key=firm_id$+item_id$,dom=*next)
					bmm05_key$=key(bmm05_dev,end=*next)
					if pos(firm_id$+item_id$=bmm05_key$) then bmm03Found=1

					if !bmm03Found and !bmm05Found then
						callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",1)
					else
						callpoint!.setColumnData("IVM_ITEMMAST.KIT","N",1)
						callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",0)
					endif
				else
					callpoint!.setColumnData("IVM_ITEMMAST.KIT","N",1)
					callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",0)
				endif
			else
				callpoint!.setColumnEnabled("IVM_ITEMMAST.KIT",1)
			endif
		endif
	endif

[[IVM_ITEMMAST.MAXIMUM_QTY.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.MSRP.AVAL]]
if num(callpoint!.getUserInput())<0 then
	callpoint!.setStatus("ABORT")
endif

[[IVM_ITEMMAST.ORDER_POINT.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.PRODUCT_TYPE.AVAL]]
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

rem --- Set SA Level and item defaults if new record
	if callpoint!.getRecordMode()="A"
		ivm10_dev=fnget_dev("IVC_PRODCODE")
		dim ivm10a$:fnget_tpl$("IVC_PRODCODE")
		read record (ivm10_dev,key=firm_id$+"A"+callpoint!.getUserInput()) ivm10a$
		callpoint!.setColumnData("IVM_ITEMMAST.SA_LEVEL",ivm10a.sa_level$,1)

		if cvs(ivm10a.item_class$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.ITEM_CLASS", ivm10a.item_class$,1)
		if cvs(ivm10a.buyer_code$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.BUYER_CODE", ivm10a.buyer_code$,1)
		if cvs(ivm10a.unit_of_sale$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.UNIT_OF_SALE", ivm10a.unit_of_sale$,1)
		if cvs(ivm10a.purchase_um$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.PURCHASE_UM", ivm10a.purchase_um$,1)
		if cvs(ivm10a.lotser_flag$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.LOTSER_FLAG", ivm10a.lotser_flag$,1)
		if cvs(ivm10a.inventoried$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.INVENTORIED", ivm10a.inventoried$,1)
		if cvs(ivm10a.taxable_flag$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.TAXABLE_FLAG", ivm10a.taxable_flag$,1)
		if cvs(ivm10a.item_type$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.ITEM_TYPE", ivm10a.item_type$,1)
		if cvs(ivm10a.abc_code$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.ABC_CODE", ivm10a.abc_code$,1)
		if cvs(ivm10a.eoq_code$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.EOQ_CODE", ivm10a.eoq_code$,1)
		if cvs(ivm10a.ord_pnt_code$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.ORD_PNT_CODE", ivm10a.ord_pnt_code$,1)
		if cvs(ivm10a.saf_stk_code$,2)<>"" then callpoint!.setColumnData("IVM_ITEMMAST.SAF_STK_CODE", ivm10a.saf_stk_code$,1)
	endif

[[IVM_ITEMMAST.SAFETY_STOCK.AVAL]]
if num(callpoint!.getUserInput())<0 then callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.TAX_SVC_CD.AVAL]]
rem --- Validate TAX_SVC_CD
	taxSvcCd$=cvs(callpoint!.getUserInput(),2)
	priorTaxSvcCd$=cvs(callpoint!.getColumnData("IVM_ITEMMAST.TAX_SVC_CD"),2)
	if taxSvcCd$<>priorTaxSvcCd$ then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		if taxSvcCd$<>"" then
			salesTax!=callpoint!.getDevObject("salesTax")
			success=0
			desc$=salesTax!.getTaxSvcCdDesc(taxSvcCd$,err=*next); success=1
			if success then
				if desc$<>"" then
					rem --- Good code entered
					tax_svc_cd_desc!.setText(desc$)
				else
					rem --- Bad code entered
					msg_id$="OP_BAD_TAXSVC_CD"
					dim msg_tokens$[1]
					msg_tokens$[1]=taxSvcCd$
					gosub disp_message

					callpoint!.setColumnData("IVM_ITEMMAST.TAX_SVC_CD",priorTaxSvcCd$,1)
					callpoint!.setStatus("ABORT")
					break
				endif
			else
				rem --- AvaTax call error
				callpoint!.setColumnData("IVM_ITEMMAST.TAX_SVC_CD",priorTaxSvcCd$,1)
				callpoint!.setStatus("ABORT")
				break
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[<<DISPLAY>>.TEMP_TAB_STOP.BINP]]
rem --- "Hidden" field to allow enter/tab from single enabled field
rem --- Temporary workaround for Barista bug 6925

	callpoint!.setFocus("<<DISPLAY>>.ITEM_DESC_SEG_1")
	callpoint!.setStatus("ABORT")
	break

[[IVM_ITEMMAST.WEIGHT.AVAL]]
if num(callpoint!.getUserInput())<0 or num(callpoint!.getUserInput())>9999.99 callpoint!.setStatus("ABORT")

[[IVM_ITEMMAST.<CUSTOM>]]
rem #include fnget_control.src
	def fnget_control!(ctl_name$)
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	get_control!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
	return get_control!
	fnend
rem #endinclude fnget_control.src

#include [+ADDON_LIB]std_functions.aon

gl_active:
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*return) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE-ABORT")
   endif
return

rem ==========================================================================
set_desc_segs: rem --- Set the description segments
               rem      IN: desc$
rem ==========================================================================

	callpoint!.setColumnData("<<DISPLAY>>.ITEM_DESC_SEG_1", desc$(1, user_tpl.desc_len_01),1)
 	callpoint!.setColumnData("<<DISPLAY>>.ITEM_DESC_SEG_2", desc$(1 + user_tpl.desc_len_01, user_tpl.desc_len_02),1)
	callpoint!.setColumnData("<<DISPLAY>>.ITEM_DESC_SEG_3", desc$(1 + user_tpl.desc_len_01 + user_tpl.desc_len_02, user_tpl.desc_len_03),1)
	callpoint!.setColumnData("<<DISPLAY>>.DESC_DISPLAY", func.displayDesc(desc$, user_tpl.desc_len_01, user_tpl.desc_len_02, user_tpl.desc_len_03),1)

return

rem ==========================================================================
check_qoh: rem --- Check for any QOH for this item
           rem     OUT: qoh - 0 = none, <> 0 = some (may not be exact)
rem ==========================================================================

	item$ = callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID")
	file$ = "IVM_ITEMWHSE"
	itemwhse_dev = fnget_dev(file$)
	dim itemwhse_rec$:fnget_tpl$(file$)

	read (itemwhse_dev, key=firm_id$+item$, knum="AO_ITEM_WH", dom=*next)
	qoh = 0

	while 1
		read record (itemwhse_dev, end=*break) itemwhse_rec$
		if itemwhse_rec.firm_id$ <> firm_id$ or itemwhse_rec.item_id$ <> item$ then break
		qoh = itemwhse_rec.qty_on_hand
		if qoh then break
	wend

return

rem ==========================================================================
disableKitFields: rem --- Enable/disable fields for non-priced kitted items
rem ==========================================================================
	if callpoint!.getDevObject("kit")="Y" then
		rem --- Disable Availability button for non-priced kitted item
		callpoint!.setOptionEnabled("ITAV",0)

		rem --- Disable Item tab fields, except PRODUCT_TYPE, ITEM_CLASS, ITEM_TYPE and ITEM_INACTIVE for non-priced kitted item
		callpoint!.setColumnData("IVM_ITEMMAST.MSRP","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.MSRP",0)
		callpoint!.setColumnData("IVM_ITEMMAST.UPC_CODE","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.UPC_CODE",0)
		callpoint!.setColumnData("IVM_ITEMMAST.BAR_CODE","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.BAR_CODE",0)
		callpoint!.setColumnData("IVM_ITEMMAST.UNIT_OF_SALE","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.UNIT_OF_SALE",0)
		callpoint!.setColumnData("IVM_ITEMMAST.WEIGHT","0",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.WEIGHT",0)
		callpoint!.setColumnData("IVM_ITEMMAST.PURCHASE_UM","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.PURCHASE_UM",0)
		callpoint!.setColumnData("IVM_ITEMMAST.CONV_FACTOR","1",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.CONV_FACTOR",0)
		callpoint!.setColumnData("IVM_ITEMMAST.LOTSER_FLAG","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.LOTSER_FLAG",0)
		callpoint!.setColumnData("IVM_ITEMMAST.INVENTORIED","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.INVENTORIED",0)
		callpoint!.setColumnData("IVM_ITEMMAST.SELL_PURCH_UM","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PUCH_UM",0)
		callpoint!.setColumnData("IVM_ITEMMAST.ALT_SUP_FLAG","N",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.ALT_SUP_FLAG",0)
		callpoint!.setColumnData("IVM_ITEMMAST.ALT_SUP_ITEM","",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.ALT_SUP_ITEM",0)
	else
		rem --- Enable Availability button, except for priced kitted items
		if callpoint!.getDevObject("kit")="P" then
			callpoint!.setOptionEnabled("ITAV",0)
		else
			callpoint!.setOptionEnabled("ITAV",1)
		endif

		rem --- Enable Item tab fields
		callpoint!.setColumnEnabled("IVM_ITEMMAST.MSRP",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.UPC_CODE",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.BAR_CODE",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.UNIT_OF_SALE",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.WEIGHT",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.PURCHASE_UM",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.CONV_FACTOR",1)
		rem --- NOTE: The TAX_SVC_CD field remains permanently disable if there is no OP or not using a Sales Tax Service
		callpoint!.setColumnEnabled("IVM_ITEMMAST.TAX_SVC_CD",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.TAXABLE_FLAG",1)
		gosub enableLS; rem callpoint!.setColumnEnabled("IVM_ITEMMAST.LOTSER_FLAG",1)
		gosub enableSellPurchUM; rem callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",1)
		callpoint!.setColumnEnabled("IVM_ITEMMAST.ALT_SUP_FLAG",1)
		if pos(callpoint!.getColumnData("IVM_ITEMMAST.ALT_SUP_FLAG")="AS") then
			callpoint!.setColumnEnabled("IVM_ITEMMAST. ALT_SUP_ITEM",1)
		endif
	endif

	return

rem ==========================================================================
enableLS:
rem ==========================================================================
rem --- Disable inventoried if not lotted/serialized
	if pos(callpoint!.getColumnData("IVM_ITEMMAST.LOTSER_FLAG")="LS")=0 then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.INVENTORIED",0)
	else
		callpoint!.setColumnEnabled("IVM_ITEMMAST.INVENTORIED",1)
	endif

rem --- Disable lotted/serialized flag if inventoried=Y
	if callpoint!.getColumnData("IVM_ITEMMAST.INVENTORIED")="Y" then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.LOTSER_FLAG",0)
	else
		callpoint!.setColumnEnabled("IVM_ITEMMAST.LOTSER_FLAG",1)
	endif

	return

rem ==========================================================================
enableSellPurchUM:
rem ==========================================================================
rem --- Disable sell_purch_um if lotted/serialized, or sell_purch_um not allowed
	if pos(callpoint!.getColumnData("IVM_ITEMMAST.LOTSER_FLAG")="LS") or callpoint!.getDevObject("allow_SellPurchUM")="N" then
		callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",0)
	else
		rem --- Always disable if BOM and creating WOs from Sales Orders
		if callpoint!.getDevObject("bm_installed")="Y" and cvs(callpoint!.getDevObject("op_create_wo"),2)<>"" then
			bmm01_dev = fnget_dev("BMM_BILLMAST")
			found_bom=0
			find(bmm01_dev,key=firm_id$+callpoint!.getColumnData("IVM_ITEMMAST.ITEM_ID"),dom=*next); found_bom=1
			if found_bom then
				callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",0)
			else
				callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",1)
			endif
		else
			callpoint!.setColumnEnabled("IVM_ITEMMAST.SELL_PURCH_UM",1)
		endif
	endif

	return

rem ==========================================================================
#include [+ADDON_LIB]std_missing_params.aon
rem ==========================================================================



