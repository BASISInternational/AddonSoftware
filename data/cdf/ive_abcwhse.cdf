[[IVE_ABCWHSE.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[IVE_ABCWHSE.WAREHOUSE_ID.AVAL]]
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



