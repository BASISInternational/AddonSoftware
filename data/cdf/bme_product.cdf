[[BME_PRODUCT.ADIS]]
rem --- set comments

	bill_no$=callpoint!.getColumnData("BME_PRODUCT.ITEM_ID")
	gosub disp_bill_comments

[[BME_PRODUCT.ARAR]]
rem --- Get Unit of Sale

	item$=callpoint!.getColumnData("BME_PRODUCT.ITEM_ID")
	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")

	while 1
		read record (ivm01_dev,key=firm_id$+item$,dom=*break)ivm01a$
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_OF_SALE",ivm01a.unit_of_sale$,1)
		break
	wend

	bill_no$=item$
	gosub disp_bill_comments

[[BME_PRODUCT.AREC]]
rem --- Set default warehouse

	if callpoint!.getDevObject("multi_wh")<>"Y"
		gosub disable_wh
	else
		wh$=callpoint!.getDevObject("def_wh")
		callpoint!.setColumnData("BME_PRODUCT.WAREHOUSE_ID",wh$)
	endif

	callpoint!.setColumnData("<<DISPLAY>>.COMMENTS","")

[[BME_PRODUCT.ARNF]]
if num(stbl("+BATCH_NO"),err=*next)<>0
	rem --- Check if this record exists in a different batch
	tableAlias$=callpoint!.getAlias()
	primaryKey$=callpoint!.getColumnData("BME_PRODUCT.FIRM_ID")+
:		callpoint!.getColumnData("BME_PRODUCT.WAREHOUSE_ID")+
:		callpoint!.getColumnData("BME_PRODUCT.PROD_DATE")+
:		callpoint!.getColumnData("BME_PRODUCT.BM_REFERENCE")+
:		callpoint!.getColumnData("BME_PRODUCT.ITEM_ID")
	call stbl("+DIR_PGM")+"adc_findbatch.aon",tableAlias$,primaryKey$,Translate!,table_chans$[all],existingBatchNo$,status
	if status or existingBatchNo$<>"" then callpoint!.setStatus("NEWREC")
endif

[[BME_PRODUCT.BEND]]
rem --- remove software lock on batch, if batching

	batch$=stbl("+BATCH_NO",err=*next)
	if num(batch$)<>0
		lock_table$="ADM_PROCBATCHES"
		lock_record$=firm_id$+stbl("+PROCESS_ID")+batch$
		lock_type$="X"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[BME_PRODUCT.BSHO]]
rem --- Open files

	num_files=5
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVM_ITEMMAST",open_opts$[1]="OTA"
	open_tables$[2]="IVM_ITEMWHSE",open_opts$[2]="OTA"
	open_tables$[3]="IVS_PARAMS",open_opts$[3]="OTA"
	open_tables$[4]="BMM_BILLMAST",open_opts$[4]="OTA"
	open_tables$[5]="IVC_WHSECODE",open_opts$[5]="OTA"
	gosub open_tables

rem --- get multiple warehouse flag and default warehouse

	ivs01_dev=num(open_chans$[3])
	dim ivs01a$:open_tpls$[3]
	read record (ivs01_dev,key=firm_id$+"IV00",dom=std_missing_params)ivs01a$

	callpoint!.setDevObject("multi_wh",ivs01a.multi_whse$)
	callpoint!.setDevObject("def_wh",ivs01a.warehouse_id$)
	if ivs01a.multi_whse$<>"Y"
		gosub disable_wh
	else
		callpoint!.setColumnData("BME_PRODUCT.WAREHOUSE_ID",ivs01a.warehouse_id$)
	endif

rem --- Additional Init
	gl$="N"
	status=0
	source$=pgm(-2)
	call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,source$,"IV",glw11$,gl$,status
	if status<>0 goto std_exit
	callpoint!.setDevObject("glint",gl$)

rem --- Additional Init

	gl$="N"
	status=0
	source$=pgm(-2)
	call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,source$,"BM",glw11$,gl$,status
	if status<>0 goto std_exit

[[BME_PRODUCT.BTBL]]
rem --- Get Batch information

call stbl("+DIR_PGM")+"adc_getbatch.aon",callpoint!.getAlias(),"",table_chans$[all]
callpoint!.setTableColumnAttribute("BME_PRODUCT.BATCH_NO","PVAL",$22$+stbl("+BATCH_NO")+$22$)

[[BME_PRODUCT.BWRI]]
rem --- Validate Quantity

	if num(callpoint!.getColumnData("BME_PRODUCT.QTY_ORDERED")) = 0
		msg_id$="IV_QTY_ZERO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[BME_PRODUCT.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

	callpoint!.setFocus("BME_PRODUCT.ITEM_ID")

[[BME_PRODUCT.ITEM_ID.AVAL]]
rem --- Validate Item/Whse
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
   callpoint!.setStatus("ACTIVATE-ABORT")
   goto std_exit
endif

	item$=callpoint!.getUserInput()
	wh$=callpoint!.getColumnData("BME_PRODUCT.WAREHOUSE_ID")
	gosub check_item_whse
	if callpoint!.getDevObject("item_wh_failed") = "1" break

rem --- Get item info from ivm_itemmast

	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
	read record (ivm01_dev,key=firm_id$+item$,dom=*next)ivm01a$
	if ivm01a.item_id$=item$ then
		rem --- Get Unit of Sale
		callpoint!.setColumnData("<<DISPLAY>>.UNIT_OF_SALE",ivm01a.unit_of_sale$,1)
	endif

	bill_no$=item$
	gosub disp_bill_comments

	rem --- Cannot update inventoried lotted/serialed items
	if pos(ivm01a.lotser_flag$="LS") and ivm01a.inventoried$="Y" then
		callpoint!.setColumnData("BME_PRODUCT.UPDATE_FLAG","N",1)
		callpoint!.setColumnEnabled("BME_PRODUCT.UPDATE_FLAG",0)
		msg_id$="NOT_UPDT_INV_LS_ITEM"
		gosub disp_message
	else
		callpoint!.setColumnEnabled("BME_PRODUCT.UPDATE_FLAG",1)
	endif

[[BME_PRODUCT.ITEM_ID.BINQ]]
rem --- Bill of Materials Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("BME_PRODUCT.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]="LOCK"
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"BM_ITEMWHS_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("BME_PRODUCT.ITEM_ID") then 
		callpoint!.setColumnData("BME_PRODUCT.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[BME_PRODUCT.PROD_DATE.AVAL]]
rem --- make sure accting date is in an appropriate GL period

	gl$=callpoint!.getDevObject("glint")
	prod_date$=callpoint!.getUserInput()        
	if gl$="Y" 
		call stbl("+DIR_PGM")+"glc_datecheck.aon",prod_date$,"Y",per$,yr$,status
		if status>99
			callpoint!.setStatus("ABORT")
		endif
	endif

[[BME_PRODUCT.QTY_ORDERED.AVAL]]
rem --- Check for zero quantity

	if num(callpoint!.getUserInput()) = 0
		callpoint!.setMessage("IV_QTY_ZERO")
		callpoint!.setStatus("ABORT")
	endif

[[BME_PRODUCT.WAREHOUSE_ID.AVAL]]
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

[[BME_PRODUCT.<CUSTOM>]]
rem ===========================================================================
check_item_whse: rem --- Check that a warehouse record exists for this item
                 rem      IN: wh$
                 rem          item$
                 rem     OUT: setDevObject item_wh_failed
rem ===========================================================================

	file$ = "IVM_ITEMWHSE"
	ivm02_dev = fnget_dev(file$)
	dim ivm02a$:fnget_tpl$(file$)
	callpoint!.setDevObject("item_wh_failed","1")
			
	if cvs(item$, 2) <> "" and cvs(wh$, 2) <> "" then
		find record (ivm02_dev, key=firm_id$+wh$+item$, knum="PRIMARY", dom=*endif) ivm02a$
		callpoint!.setDevObject("item_wh_failed","0")
	endif

	if callpoint!.getDevObject("item_wh_failed") = "1" then 
		callpoint!.setMessage("IV_NO_WHSE_ITEM")
		callpoint!.setStatus("ABORT")
	endif

	return


rem =======================================================
disp_bill_comments:
	rem --- input: bill_no$
rem =======================================================
	cmt_text$=""

	bmm01_dev=fnget_dev("BMM_BILLMAST")
	dim bmm01a$:fnget_tpl$("BMM_BILLMAST")
	bmm01_key$=firm_id$+bill_no$
	readrecord(bmm01_dev,key=bmm01_key$,dom=*next)bmm01a$
		 
	if bmm01a.firm_id$ = firm_id$ and bmm01a.bill_no$ = bill_no$ then
		cmt_text$ = cvs(bmm01a.memo_1024$,3)
	endif				
	callpoint!.setColumnData("<<DISPLAY>>.comments",cmt_text$,1)

return

disable_wh:
	dim ctl_name$[1]
	dim ctl_stat$[1]
	ctl_name$[1]="BME_PRODUCT.WAREHOUSE_ID"
	ctl_stat$[1]="D"
	wh$=callpoint!.getDevObject("def_wh")
	callpoint!.setColumnData("BME_PRODUCT.WAREHOUSE_ID",wh$,1)
	wctl$=str(num(callpoint!.getTableColumnAttribute(ctl_name$[1],"CTLI")):"00000")
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)=ctl_stat$[1]
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP-REFRESH-ACTIVATE")
return
#include [+ADDON_LIB]std_missing_params.aon



