[[OPC_PRICECDS.BDEL]]
rem --- When deleting the Customer Pricing Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("OPC_PRICECDS.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

rem --- Check if code is used as a default code

	num_files = 1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARS_CUSTDFLT", open_opts$[1]="OTA"
	gosub open_tables
	ars_custdflt_dev = num(open_chans$[1])
	dim ars_rec$:open_tpls$[1]

	find record(ars_custdflt_dev,key=firm_id$+"D",dom=*next)ars_rec$
	if ars_rec.pricing_code$ = callpoint!.getColumnData("OPC_PRICECDS.PRICING_CODE") then
		callpoint!.setMessage("OP_PRICE_CD_IN_DFLT")
		callpoint!.setStatus("ABORT")
	endif

[[OPC_PRICECDS.BSHO]]
rem --- Open/Lock files
	num_files=4
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARM_CUSTDET",open_opts$[1]="OTA"
	open_tables$[2]="ARS_CUSTDFLT",open_opts$[2]="OTA"
	open_tables$[3]="IVC_PRICCODE",open_opts$[3]="OTA"
	open_tables$[4]="OPT_INVHDR",open_opts$[4]="OTA"
	gosub open_tables

[[OPC_PRICECDS.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Customer Pricing Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("OPC_PRICECDS.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPC_PRICECDS.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	pricing_code$=callpoint!.getColumnData("OPC_PRICECDS.PRICING_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("ARM_CUSTDET")
	checkTables!.addItem("ARS_CUSTDFLT")
	checkTables!.addItem("IVC_PRICCODE")
	checkTables!.addItem("OPT_INVHDR")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		if thisTable$="OPT_INVHDR" then
			read(table_dev,key=firm_id$+"E",knum="AO_STATUS",dom=*next)
		else
			read(table_dev,key=firm_id$,dom=*next)
		endif
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if thisTable$="OPT_INVHDR" and table_tpl.trans_status$<>"E" then break
			if table_tpl.pricing_code$=pricing_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]="OP "+Translate!.getTranslation("DDM_ELEMENTS-PRICING_CODE-DD_ATTR_LABL")
				switch (BBjAPI().TRUE)
                				case thisTable$="ARM_CUSTDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARS_CUSTDFLT"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARS_CUSTDFLT-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVC_PRICCODE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVC_PRICCODE-DD_ATTR_WINT")
                    				break
                				case thisTable$="OPT_INVHDR"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPT_INVHDR-DD_ATTR_WINT")
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
		callpoint!.setColumnData("OPC_PRICECDS.CODE_INACTIVE","N",1)
	endif

return



