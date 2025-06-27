[[POE_ORDDET.BSHO]]
rem --- Open files

	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVC_PRODCODE", open_opts$[1]="OTA"
	open_tables$[2]="IVC_WHSECODE", open_opts$[2]="OTA"
	open_tables$[3]="IVC_BUYCODE", open_opts$[3]="OTA"

	gosub open_tables

[[POE_ORDDET.BUYER_CODE.AVAL]]
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

[[POE_ORDDET.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::grid_entry"

[[POE_ORDDET.ITEM_ID.AVAL]]
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

[[POE_ORDDET.ITEM_ID.BINQ]]
rem --- Inventory Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("POE_ORDDET.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]=""
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"IV_ITEM_WHSE_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("POE_ORDDET.ITEM_ID") then 
		callpoint!.setColumnData("POE_ORDDET.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"POE_ORDDET.ITEM_ID",1)
endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_ORDDET.PRODUCT_TYPE.AVAL]]
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

[[POE_ORDDET.WAREHOUSE_ID.AVAL]]
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



