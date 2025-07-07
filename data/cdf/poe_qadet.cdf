[[POE_QADET.BSHO]]
rem --- Open Files
	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVC_WHSECODE",open_opts$[1]="OTA"
	open_tables$[2]="IVC_WHSECODE",open_opts$[2]="OTA"

	gosub open_tables

[[POE_QADET.ITEM_ID.AINV]]
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

[[POE_QADET.PO_LINE_CODE.AVAL]]
rem --- Don't allow inactive code
	pocLineCode_dev=fnget_dev("POC_LINECODE")
	dim pocLineCode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getUserInput()
	read record(pocLineCode_dev,key=firm_id$+po_line_code$,dom=*next)pocLineCode$
	if pocLineCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(pocLineCode.po_line_code$,3)
		msg_tokens$[2]=cvs(pocLineCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_QADET.WAREHOUSE_ID.AVAL]]
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



