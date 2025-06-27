[[IVC_BUYCODE.BDEL]]
rem --- When deleting the Buyer Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("IVC_BUYCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_BUYCODE.BSHO]]
rem --- This firm using Inventory?
	call stbl("+DIR_PGM")+"adc_application.aon","AP",info$[all]
	callpoint!.setDevObject("usingAP",info$[20])

rem --- This firm using Purchase Order?
	call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
	callpoint!.setDevObject("usingPO",info$[20])

rem --- Open/Lock files
	num_files=9
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	if callpoint!.getDevObject("usingAP")="Y" then
		open_tables$[1]="APM_VENDREPL",open_opts$[1]="OTA"
	endif
	open_tables$[2]="IVC_PRODCODE",open_opts$[2]="OTA"
	open_tables$[3]="IVM_ITEMMAST",open_opts$[3]="OTA"
	open_tables$[4]="IVM_ITEMWHSE",open_opts$[4]="OTA"
	open_tables$[5]="IVS_DEFAULTS",open_opts$[5]="OTA"
	if callpoint!.getDevObject("usingPO")="Y" then
		open_tables$[6]="POE_ORDDET",open_opts$[6]="OTA"
		open_tables$[7]="POE_ORDHDR",open_opts$[7]="OTA"
		open_tables$[8]="POE_ORDTOT",open_opts$[8]="OTA"
		open_tables$[9]="POE_REPXREF",open_opts$[9]="OTA"
	endif

	gosub open_tables

[[IVC_BUYCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Buyer Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_BUYCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[IVC_BUYCODE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	buyer_code$=callpoint!.getColumnData("IVC_BUYCODE.BUYER_CODE")

	checkTables!=BBjAPI().makeVector()
	if callpoint!.getDevObject("usingAP")="Y" then
		checkTables!.addItem("APM_VENDREPL")
	endif
	checkTables!.addItem("IVC_PRODCODE")
	checkTables!.addItem("IVM_ITEMMAST")
	checkTables!.addItem("IVM_ITEMWHSE")
	checkTables!.addItem("IVS_DEFAULTS")
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_ORDDET")
		checkTables!.addItem("POE_ORDHDR")
		checkTables!.addItem("POE_ORDTOT")
		checkTables!.addItem("POE_REPXREF")
	endif
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.buyer_code$=buyer_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_OPERATIONS")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="APM_VENDREPL"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APM_VENDREPL-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVC_PRODCODE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVC_PRODCODE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVM_ITEMMAST"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMMAST-DD_ATTR_WINT")
						break
                				case thisTable$="IVM_ITEMWHSE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMWHSE-DD_ATTR_WINT")
						break
                				case thisTable$="IVS_DEFAULTS"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVS_DEFAULTS-DD_ATTR_WINT")
						break
                				case thisTable$="POE_ORDDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ORDDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_ORDHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ORDHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_ORDTOT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ORDTOT-DD_ATTR_WINT")
						break
                				case thisTable$="POE_REPXREF"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REPXREF-DD_ATTR_WINT")
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
		callpoint!.setColumnData("IVC_BUYCODE.CODE_INACTIVE","N",1)
	endif

return



