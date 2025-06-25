[[IVC_PHYSCODE.AREC]]
rem --- Initialize new record
	callpoint!.setColumnData("IVC_PHYSCODE.PENDING_ACTION","0",1)
	callpoint!.setColumnData("IVC_PHYSCODE.PHYS_INV_STS","0",1)

[[IVC_PHYSCODE.BDEL]]
rem --- When deleting the Physical Inventory Cycle code, warn if there are any current/active transactions for the code, and disallow if there are any.
	gosub check_active_code
	if found then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Do they want to deactivate code instead of deleting it?
	msg_id$="AD_DEACTIVATE_CODE"
	gosub disp_message
	if msg_opt$="Y" then
		rem --- Check the CODE_INACTIVE checkbox
		callpoint!.setColumnData("IVC_PHYSCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_PHYSCODE.BSHO]]
rem --- Open files
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVM_ITEMWHSE", open_opts$[1]="OTA"
	open_tables$[2]="IVE_PHYSICAL", open_opts$[2]="OTA"
	open_tables$[3]="IVC_WHSECODE", open_opts$[3]="OTA"

	gosub open_tables

[[IVC_PHYSCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Physical Inventory Cycle code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_PHYSCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

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

[[IVC_PHYSCODE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	pi_cyclecode$=callpoint!.getColumnData("IVC_PHYSCODE.PI_CYCLECODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVE_PHYSICAL")
	checkTables!.addItem("IVM_ITEMWHSE")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.pi_cyclecode$=pi_cyclecode$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2] 
				msg_tokens$[1]=Translate!.getTranslation("AON_PHYSICAL_INVENTORY")+" "+Translate!.getTranslation("AON_CYCLE_CODE_")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVE_PHYSICAL"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_PHYSICAL-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVM_ITEMWHSE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMWHSE-DD_ATTR_WINT")
						break
                				case default
                    				msg_tokens$[2]="???"
                    				break
            			swend
				gosub disp_message


				found=1
				break
			endif
		wend
		if found then break
	next i

	if found then
		rem --- Uncheck the CODE_INACTIVE checkbox
		callpoint!.setColumnData("IVC_PHYSCODE.CODE_INACTIVE","N",1)

	endif
	return



