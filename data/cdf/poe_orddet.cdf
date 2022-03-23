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



