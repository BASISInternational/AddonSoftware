[[IVC_PHYSCODE.AREC]]
rem --- Initialize new record
	callpoint!.setColumnData("IVC_PHYSCODE.PENDING_ACTION","0",1)
	callpoint!.setColumnData("IVC_PHYSCODE.PHYS_INV_STS","0",1)

[[IVC_PHYSCODE.BDEQ]]
rem --- Prevent deleting pi_cyclecode if currently in use
	warehouse_id$=callpoint!.getColumnData("IVC_PHYSCODE.WAREHOUSE_ID")
	pi_cyclecode$=callpoint!.getColumnData("IVC_PHYSCODE.PI_CYCLECODE")
	ivmItemWhse_dev=fnget_dev("IVM_ITEMWHSE")
	dim ivmItemWhse$:fnget_tpl$("IVM_ITEMWHSE")
	read(ivmItemWhse_dev,key=firm_id$+warehouse_id$+pi_cyclecode$,knum="AO_WH_CYCLE_LOC",dom=*next)
	ivmItemWhse_key$=key(ivmItemWhse_dev,end=*break)
	if pos(firm_id$+warehouse_id$+pi_cyclecode$=ivmItemWhse_key$)=1 then
		msg_id$="IV_PI_CODE_IN_USE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVC_PHYSCODE.BSHO]]
rem --- Open files
	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVM_ITEMWHSE", open_opts$[1]="OTA"
	open_tables$[2]="IVC_WHSECODE", open_opts$[2]="OTA"

	gosub open_tables

[[IVC_PHYSCODE.WAREHOUSE_ID.AVAL]]
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



