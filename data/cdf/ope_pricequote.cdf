[[OPE_PRICEQUOTE.AOPT-AVLE]]
rem -- call query to show pricing/availability

item_id$=callpoint!.getColumnData("OPE_PRICEQUOTE.ITEM_ID")

if cvs(item_id$,3) <>""

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

endif

[[OPE_PRICEQUOTE.BSHO]]
num_files=9
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="ARM_CUSTMAST",open_opts$[1]="OTA"
open_tables$[2]="ARM_CUSTDET",open_opts$[2]="OTA"
open_tables$[3]="OPC_PRICECDS",open_opts$[3]="OTA"
open_tables$[4]="IVM_ITEMWHSE",open_opts$[4]="OTA"
open_tables$[5]="IVC_PRICCODE",open_opts$[5]="OTA"
open_tables$[6]="IVM_ITEMMAST",open_opts$[6]="OTA"
open_tables$[7]="IVM_ITEMPRIC",open_opts$[7]="OTA"
open_tables$[8]="IVC_WHSECODE",open_opts$[8]="OTA"
open_tables$[9]="IVC_CLASCODE",open_opts$[9]="OTA"
gosub open_tables
arm01_dev=num(open_chans$[1]),arm01_tpl$=open_tpls$[1]
arm02_dev=num(open_chans$[2]),arm02_tpl$=open_tpls$[2]
opm05_dev=num(open_chans$[3]),opm05_tpl$=open_tpls$[3]
ivm02_dev=num(open_chans$[4]),ivm02_tpl$=open_tpls$[4]
ivcprice_dev=num(open_chans$[5]),ivcprice_tpl$=open_tpls$[5]
ivm01_dev=num(open_chans$[6]),ivm01_tpl$=open_tpls$[6]
ivm06_dev=num(open_chans$[7]),ivm06_tpl$=open_tpls$[7]
ivcwhse_dev=num(open_chans$[8]),ivcwhse_tpl$=open_tpls$[8]


rem --- If BM is installed, open BMM_BILLMAT
	bm_sf$="N"
	dim info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","BM",info$[all]
	bm$=info$[20]
	if bm$="Y" then
		num_files = 1
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="BMM_BILLMAT", open_opts$[1]="OTA"
		gosub open_tables
	endif

[[OPE_PRICEQUOTE.CUSTOMER_ID.AVAL]]
rem "Customer Inactive Feature"
customer_id$=callpoint!.getUserInput()
arm01_dev=fnget_dev("ARM_CUSTMAST")
arm01_tpl$=fnget_tpl$("ARM_CUSTMAST")
dim arm01a$:arm01_tpl$
arm01a_key$=firm_id$+customer_id$
find record (arm01_dev,key=arm01a_key$,err=*break) arm01a$
if arm01a.cust_inactive$="Y" then
   call stbl("+DIR_PGM")+"adc_getmask.aon","CUSTOMER_ID","","","",m0$,0,customer_size
   msg_id$="AR_CUST_INACTIVE"
   dim msg_tokens$[2]
   msg_tokens$[1]=fnmask$(arm01a.customer_id$(1,customer_size),m0$)
   msg_tokens$[2]=cvs(arm01a.customer_name$,2)
   gosub disp_message
   callpoint!.setStatus("ACTIVATE")
endif

arm01_dev=fnget_dev("ARM_CUSTMAST")
dim arm01a$:fnget_tpl$("ARM_CUSTMAST")
arm02_dev=fnget_dev("ARM_CUSTDET")
dim arm02a$:fnget_tpl$("ARM_CUSTDET")
ar_type$="  "
opm05_dev=fnget_dev("OPC_PRICECDS")
dim opm05a$:fnget_tpl$("OPC_PRICECDS")
while 1
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_1","")
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_2","")
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_3","")
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_4","")
	callpoint!.setColumnData("<<DISPLAY>>.CITY","")
	callpoint!.setColumnData("<<DISPLAY>>.FAX_NO","")
	callpoint!.setColumnData("<<DISPLAY>>.PHONE_NO","")
	callpoint!.setColumnData("<<DISPLAY>>.STATE_CODE","")
	callpoint!.setColumnData("<<DISPLAY>>.ZIP_CODE","")
	callpoint!.setColumnData("<<DISPLAY>>.CONTACT_NAME","")
	callpoint!.setColumnData("OPE_PRICEQUOTE.PRICING_CODE","")
	readrecord(arm01_dev,key=firm_id$+callpoint!.getUserInput(),err=*break)arm01a$
	readrecord(arm02_dev,key=firm_id$+callpoint!.getUserInput()+ar_type$)arm02a$
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_1",arm01a.addr_line_1$)
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_2",arm01a.addr_line_2$)
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_3",arm01a.addr_line_3$)
	callpoint!.setColumnData("<<DISPLAY>>.ADDR_LINE_4",arm01a.addr_line_4$)
	callpoint!.setColumnData("<<DISPLAY>>.CITY",arm01a.city$)
	callpoint!.setColumnData("<<DISPLAY>>.FAX_NO",arm01a.fax_no$)
	callpoint!.setColumnData("<<DISPLAY>>.PHONE_NO",arm01a.phone_no$)
	callpoint!.setColumnData("<<DISPLAY>>.STATE_CODE",arm01a.state_code$)
	callpoint!.setColumnData("<<DISPLAY>>.ZIP_CODE",arm01a.zip_code$)
	callpoint!.setColumnData("<<DISPLAY>>.CONTACT_NAME",arm01a.contact_name$)
	callpoint!.setColumnData("OPE_PRICEQUOTE.PRICING_CODE",arm02a.pricing_code$)
	break
wend
cust_id$=callpoint!.getUserInput()
wh$=callpoint!.getColumnData("OPE_PRICEQUOTE.WAREHOUSE_ID")
item$=callpoint!.getColumnData("OPE_PRICEQUOTE.ITEM_ID")
gosub build_arrays
callpoint!.setStatus("REFRESH")

[[OPE_PRICEQUOTE.ITEM_CLASS.AVAL]]
rem --- Don't allow inactive code
	ivc_clascode=fnget_dev("IVC_CLASCODE")
	dim ivc_clascode$:fnget_tpl$("IVC_CLASCODE")
	item_class$=callpoint!.getUserInput()
	read record (ivc_clascode,key=firm_id$+item_class$,dom=*next)ivc_clascode$
	if ivc_clascode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPE_PRICEQUOTE.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[OPE_PRICEQUOTE.ITEM_ID.AVAL]]
rem "Inventory Inactive Feature"
item_id$=callpoint!.getUserInput()
ivm01_dev=fnget_dev("IVM_ITEMMAST")
ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
dim ivm01a$:ivm01_tpl$
ivm01a_key$=firm_id$+item_id$
find record (ivm01_dev,key=ivm01a_key$,err=*break)ivm01a$
if ivm01a.item_inactive$="Y" then
   msg_id$="IV_ITEM_INACTIVE"
   dim msg_tokens$[2]
   msg_tokens$[1]=cvs(ivm01a.item_id$,2)
   msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
   gosub disp_message
   callpoint!.setStatus("ACTIVATE")
endif

rem --- Validate Warehouse for this Item

ivm01_dev=fnget_dev("IVM_ITEMMAST")
ivm02_dev=fnget_dev("IVM_ITEMWHSE")
dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")

valid_wh$="N"
wh$=callpoint!.getColumnData("OPE_PRICEQUOTE.WAREHOUSE_ID")
while 1
	readrecord(ivm01_dev,key=firm_id$+callpoint!.getUserInput(),dom=*break)ivm01a$
	readrecord(ivm02_dev,key=firm_id$+wh$+
:			callpoint!.getUserInput(),dom=*break)ivm02a$
	valid_wh$="Y"
	break
wend
if valid_wh$="N"
	msg_id$="IV_ITEM_WHSE_INVALID"
	dim msg_tokens$[1]
	msg_tokens$[1]=wh$
	gosub disp_message
	callpoint!.setStatus("ABORT")
else
	callpoint!.setColumnData("OPE_PRICEQUOTE.ITEM_CLASS",ivm01a.item_class$)
	callpoint!.setColumnData("OPE_PRICEQUOTE.CUR_PRICE",str(ivm02a.cur_price))
	callpoint!.setColumnData("<<DISPLAY>>.QTY_AVAIL",str(ivm02a.qty_on_hand-ivm02a.qty_commit))
	callpoint!.setColumnData("OPE_PRICEQUOTE.QTY_COMMIT",str(ivm02a.qty_commit))
	callpoint!.setColumnData("OPE_PRICEQUOTE.QTY_ON_HAND",str(ivm02a.qty_on_hand))
	cust_id$=callpoint!.getColumnData("OPE_PRICEQUOTE.CUSTOMER_ID")
	item$=callpoint!.getUserInput()
	gosub build_arrays
	callpoint!.setStatus("REFRESH")
endif

[[OPE_PRICEQUOTE.PRICING_CODE.AVAL]]
rem --- Don't allow inactive code
	opcPiceCDs_dev=fnget_dev("OPC_PRICECDS")
	dim opcPiceCDs$:fnget_tpl$("OPC_PRICECDS")
	pricing_code$=callpoint!.getUserInput()
	read record(opcPiceCDs_dev,key=firm_id$+pricing_code$,dom=*next)opcPiceCDs$
	if opcPiceCDs.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcPiceCDs.pricing_code$,3)
		msg_tokens$[2]=cvs(opcPiceCDs.code_desc$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPE_PRICEQUOTE.WAREHOUSE_ID.AVAL]]
rem --- Fill arrays
	cust_id$=callpoint!.getColumnData("OPE_PRICEQUOTE.CUSTOMER_ID")
	wh$=callpoint!.getUserInput()
	item$=callpoint!.getColumnData("OPE_PRICEQUOTE.ITEM_ID")

rem --- Validate the Item/Warehouse combination is valid

	ivm02_dev=fnget_dev("IVM_ITEMWHSE")
	found_it = 0
	if wh$="" or item$="" found_it = 1

	if found_it=0
		readrecord(ivm02_dev,key=firm_id$+wh$+item$,dom=*next); found_it = 1
	endif

	if found_it = 0
		msg_id$="IV_ITEM_WHSE_INVALID"
		dim msg_tokens$[1]
		msg_tokens$[1]=wh$
		gosub disp_message
		callpoint!.setStatus("ABORT")
	else
		gosub build_arrays
	endif

[[OPE_PRICEQUOTE.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon
rem --- Build Pricing records
build_arrays:
	if cvs(cust_id$,2)="" or cvs(wh$,2)="" or cvs(item$,2)=""
		for x=1 to 10
			callpoint!.setColumnData("OPE_PRICEQUOTE.QTY_ORDERED_"+str(x:"00"),"")
			callpoint!.setColumnData("OPE_PRICEQUOTE.PCT_VALUE_"+str(x:"00"),"")
			callpoint!.setColumnData("OPE_PRICEQUOTE.BREAK_AMT_"+str(x:"00"),"")
			callpoint!.setColumnData("OPE_PRICEQUOTE.UNIT_PRICE_"+str(x:"00"),"")
			callpoint!.setColumnData("OPE_PRICEQUOTE.CONTRACT_PRICE_"+str(x:"00"),"")
			callpoint!.setColumnData("OPE_PRICEQUOTE.CONTRACT_QTY_"+str(x:"00"),"")
			callpoint!.setColumnData("<<DISPLAY>>.CONTRACT_DESC","")
		next x
	else
		arm01_dev=fnget_dev("ARM_CUSTDET")
		dim arm01a$:fnget_tpl$("ARM_CUSTDET")
		ivcprice_dev=fnget_dev("IVC_PRICCODE")
		dim ivcprice$:fnget_tpl$("IVC_PRICCODE")
		arm02_dev=fnget_dev("ARM_CUSTDET")
		dim arm02a$:fnget_tpl$("ARM_CUSTDET")
		ivm01_dev=fnget_dev("IVM_ITEMMAST")
		dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
		ivm02_dev=fnget_dev("IVM_ITEMWHSE")
		dim ivm02a$:fnget_tpl$("IVM_ITEMWHSE")
		ivm06_dev=fnget_dev("IVM_ITEMPRIC")
		dim ivm06a$:fnget_tpl$("IVM_ITEMPRIC")
		precision 9
		readrecord(arm02_dev,key=firm_id$+cust_id$+"  ")arm02a$
		readrecord(ivm01_dev,key=firm_id$+item$)ivm01a$
		readrecord (ivcprice_dev,key=firm_id$+"E"+ivm01a.item_class$+arm02a.pricing_code$,dom=*next)ivcprice$
		readrecord(ivm02_dev,key=firm_id$+wh$+item$,dom=*next)ivm02a$
		rem --- Get current unit price for non-priced kits
		if ivm01a.kit$="Y" then
			bmmBillMat_dev=fnget_dev("BMM_BILLMAT")
			dim bmmBillMat$:fnget_tpl$("BMM_BILLMAT")
			kit_item$=item$
			kit_unit_price=0
			gosub getKitUnitPrice
			ivm02a.cur_price=kit_unit_price
		endif
		listprice=ivm02a.cur_price*(100-ivcprice.break_disc_01)/100
		callpoint!.setColumnData("OPE_PRICEQUOTE.UNIT_PRICE_01",str(listprice))
		description$=cvs(ivcprice.code_desc$,2)

rem --- Method for pricing
		x$=Translate!.getTranslation("AON__(UNKNOWN_PRICING_METHOD)")
		if ivcprice.iv_price_mth$="C" x$=Translate!.getTranslation("AON__(MARK-UP_OVER_COST)")
		if ivcprice.iv_price_mth$="L" x$=Translate!.getTranslation("AON__(MARK-DOWN_FROM_LIST)")
		if ivcprice.iv_price_mth$="M" x$=Translate!.getTranslation("AON__(MARGIN_OVER_COST)")
		description$=description$+x$

rem --- Basis for pricing
		pricing_basis$="???"
		if ivcprice.pricing_basis$="A" then pricing_basis$=Translate!.getTranslation("AON_AMOUNT")
		if ivcprice.pricing_basis$="P" then pricing_basis$=Translate!.getTranslation("AON_PERCENT")

rem --- Display pricing table"
		callpoint!.setColumnData("<<DISPLAY>>.PRICE_METH",description$)
		callpoint!.setColumnData("<<DISPLAY>>.PRICING_BASIS",pricing_basis$)
		for x=1 to 10
			price=0
			amt=0
			percent=0
			cost=ivm02a.unit_cost
			if ivcprice.pricing_basis$="A" then
				rem --- Pricing by amount
				if nfield(ivcprice$,"BREAK_QTY_"+str(x:"00"))<>0 or nfield(ivcprice$,"BREAK_AMT_"+str(x:"00"))<>0
					amt=nfield(ivcprice$,"BREAK_AMT_"+str(x:"00"))
					gosub determine_price
				endif
			else
				rem --- Pricing by percent
				if nfield(ivcprice$,"BREAK_QTY_"+str(x:"00"))<>0 or nfield(ivcprice$,"BREAK_DISC_"+str(x:"00"))<>0
					percent=nfield(ivcprice$,"BREAK_DISC_"+str(x:"00"))
					gosub determine_price
				endif
			endif
			callpoint!.setColumnData("OPE_PRICEQUOTE.QTY_ORDERED_"+str(x:"00"),str(nfield(ivcprice$,"BREAK_QTY_"+str(x:"00"))))
			callpoint!.setColumnData("OPE_PRICEQUOTE.PCT_VALUE_"+str(x:"00"),str(percent))
			callpoint!.setColumnData("OPE_PRICEQUOTE.BREAK_AMT_"+str(x:"00"),str(amt))
			callpoint!.setColumnData("OPE_PRICEQUOTE.UNIT_PRICE_"+str(x:"00"),str(price))
		next x

rem --- Display Contract Price"
		for x=1 to 10
			callpoint!.setColumnData("OPE_PRICEQUOTE.CONTRACT_PRICE_"+str(x:"00"),"")
			callpoint!.setColumnData("OPE_PRICEQUOTE.CONTRACT_QTY_"+str(x:"00"),"")
			callpoint!.setColumnData("<<DISPLAY>>.CONTRACT_DESC","")
		next x
		while 1
			readrecord(ivm06_dev,key=firm_id$+cust_id$+item$,dom=*break)ivm06a$
			description$=cvs(ivm06a.code_desc$,2)
			if cvs(ivm06a.from_date$,2)="" from_date$=Translate!.getTranslation("AON_FIRST_DATE") else from_date$=fndate$(ivm06a.from_date$)
			if cvs(ivm06a.thru_date$,2)="" thru_date$=Translate!.getTranslation("AON_LAST_DATE") else thru_date$=fndate$(ivm06a.thru_date$)
			description$=description$+Translate!.getTranslation("AON__(FROM_")+from_date$+Translate!.getTranslation("AON__THROUGH_")+thru_date$+")"
			callpoint!.setColumnData("<<DISPLAY>>.CONTRACT_DESC",description$)
			for x=1 to 10
				callpoint!.setColumnData("OPE_PRICEQUOTE.CONTRACT_QTY_"+str(x:"00"),str(nfield(ivm06a$,"BREAK_QTY_"+str(x:"00"))))
				callpoint!.setColumnData("OPE_PRICEQUOTE.CONTRACT_PRICE_"+str(x:"00"),str(nfield(ivm06a$,"UNIT_PRICE_"+str(x:"00"))))
			next x
			break
		wend
		callpoint!.setStatus("REFRESH")
	endif
return

rem --- Determine Price
determine_price:
	if ivcprice.pricing_basis$="A" then
		rem --- Pricing by amount
		if ivcprice.iv_price_mth$="C"
			price=cost+amt
		endif
		if ivcprice.iv_price_mth$="L"
			price=ivm02a.cur_price-amt
		endif
		if ivcprice.iv_price_mth$="M"
			price=cost+amt
		endif
	else
		rem --- Pricing by percent
		if ivcprice.iv_price_mth$="C"
			factor=percent/100
			price=cost+cost*factor
		endif
		if ivcprice.iv_price_mth$="L"
			factor=percent/100
			price=ivm02a.cur_price-ivm02a.cur_price*factor
		endif
		if ivcprice.iv_price_mth$="M"
			factor=100/(100-percent)
			price=cost*factor
		endif
	endif
return

rem --- Get current unit price for non-priced kit based on its component's unit price
getKitUnitPrice:
	read(bmmBillMat_dev,key=firm_id$+kit_item$,dom=*next)
	while 1
		kitKey$=key(bmmBillMat_dev,end=*break)
		if pos(firm_id$+kit_item$=kitKey$)<>1 then break
		readrecord(bmmBillMat_dev)bmmBillMat$
		if cvs(bmmBillMat.effect_date$,2)<>"" and sysinfo.system_date$<bmmBillMat.effect_date$ then continue
		if cvs(bmmBillMat.obsolt_date$,2)<>"" and sysinfo.system_date$>=bmmBillMat.obsolt_date$ then continue
		redim ivm01a$
		readrecord(ivm01_dev,key=firm_id$+bmmBillMat.item_id$,dom=*next)ivm01a$
		if ivm01a.kit$="Y" then
			explodeKey$=kitKey$
			explodeItem$=kit_item$
			kit_item$=bmmBillMat.item_id$
			kit_ordered=round(explodeOrdered*bmmBillMat.qty_required,round_precision)
			kit_shipped=round(explodeShipped*bmmBillMat.qty_required,round_precision)
			gosub getKitUnitPrice

			read(bmmBillMat_dev,key=explodeKey$)
			kit_item$=explodeItem$
			continue
		endif

		dim component_ivm02a$:fattr(ivm02a$)
		readrecord(ivm02_dev,key=firm_id$+wh$+bmmBillMat.item_id$,dom=*next)component_ivm02a$
		kit_unit_price=kit_unit_price+component_ivm02a.cur_price
	wend
return



