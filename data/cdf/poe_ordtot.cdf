[[POE_ORDTOT.BSHO]]
rem --- Open files

	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVC_PRODCODE", open_opts$[1]="OTA"
	open_tables$[2]="IVC_BUYCODE", open_opts$[2]="OTA"

	gosub open_tables

[[POE_ORDTOT.BUYER_CODE.AVAL]]
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

[[POE_ORDTOT.ITEM_ID.AVAL]]
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

[[POE_ORDTOT.PRODUCT_TYPE.AVAL]]
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



