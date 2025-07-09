[[MPE_PEGGING.BSHO]]
rem --- Open/Lock files

	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVC_WHSECODE",open_opts$[1]="OTA"
	open_tables$[2]="SFC_WOTYPECD",open_opts$[2]="OTA"

	gosub open_tables

[[MPE_PEGGING.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::grid_entry"

[[MPE_PEGGING.ITEM_ID.BINQ]]
rem --- Inventory Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("MPE_PEGGING.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]=""
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"IV_ITEM_WHSE_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Update item_id if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData("MPE_PEGGING.ITEM_ID") then 
		callpoint!.setColumnData("MPE_PEGGING.ITEM_ID",ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
		callpoint!.setFocus(num(callpoint!.getValidationRow()),"MPE_PEGGING.ITEM_ID",1)
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[MPE_PEGGING.WAREHOUSE_ID.AVAL]]
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

[[MPE_PEGGING.WO_TYPE.AVAL]]
rem --- Don't allow inactive code
	sfcWOType_dev=fnget_dev("SFC_WOTYPECD")
	dim sfcWOType$:fnget_tpl$("SFC_WOTYPECD")
	wo_type$=callpoint!.getUserInput()
	read record (sfcWOType_dev,key=firm_id$+"A"+wo_type$,dom=*next)sfcWOType$
	if sfcWOType.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(sfcWOType.wo_type$,3)
		msg_tokens$[2]=cvs(sfcWOType.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



