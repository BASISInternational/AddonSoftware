[[ARM_CUSTSHIP.ADIS]]
rem --- Disable Manual Ship-to option for existing records
	callpoint!.setOptionEnabled("MANS",0)
	

[[ARM_CUSTSHIP.AOPT-MANS]]
rem --- Manual ship-to historical address lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVHDR","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim optInvHdr_key$:key_tpl$
	dim filter_defs$[3,2]
	filter_defs$[1,0]="OPT_INVHDR.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="OPT_INVHDR.CUSTOMER_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("ARM_CUSTSHIP.CUSTOMER_ID")+"'"
	filter_defs$[2,2]="LOCK"
	filter_defs$[3,0]="OPT_INVHDR.SHIPTO_TYPE"
	filter_defs$[3,1]="='M'"
	filter_defs$[3,2]="LOCK"
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"OP_MAN_SHIPTO","",table_chans$[all],optInvHdr_key$,filter_defs$[all]

	rem --- Update manual ship-to address if changed
	if cvs(optInvHdr_key$,2)<>"" then 
		opt31_dev=fnget_dev("OPT_INVSHIP")
		dim opt31a$:fnget_tpl$("OPT_INVSHIP")
		opt31_key$=firm_id$+optInvHdr_key.customer_id$+optInvHdr_key.order_no$+optInvHdr_key.ar_inv_no$+"S"
		readrecord(opt31_dev,key=opt31_key$,dom=*next)opt31a$
		callpoint!.setColumnData("ARM_CUSTSHIP.NAME",opt31a.name$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.ADDR_LINE_1",opt31a.addr_line_1$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.ADDR_LINE_2",opt31a.addr_line_2$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.ADDR_LINE_3",opt31a.addr_line_3$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.ADDR_LINE_4",opt31a.addr_line_4$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.CITY",opt31a.city$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.STATE_CODE",opt31a.state_code$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.ZIP_CODE",opt31a.zip_code$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.CNTRY_ID",opt31a.cntry_id$,1)

		sql_prep$="SELECT slspsn_code, territory, tax_code, ar_ship_via, shipping_id, shipping_email "
		sql_prep$=sql_prep$+"FROM opt_invhdr "
		sql_prep$=sql_prep$+"WHERE firm_id='"+firm_id$+"' and customer_id=?"+
:			" and order_no='"+optInvHdr_key.order_no$+"' and ar_inv_no='"+optInvHdr_key.ar_inv_no$+"' "

		sql_chan=sqlunt
		sqlopen(sql_chan,err=*endif)stbl("+DBNAME")
		sqlprep(sql_chan)sql_prep$
		dim read_tpl$:sqltmpl(sql_chan)
		sqlexec(sql_chan)optInvHdr_key.customer_id$

		read_tpl$ = sqlfetch(sql_chan,end=*endif)
		callpoint!.setColumnData("ARM_CUSTSHIP.SLSPSN_CODE",read_tpl.slspsn_code$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.TERRITORY",read_tpl.territory$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.TAX_CODE",read_tpl.tax_code$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.AR_SHIP_VIA",read_tpl.ar_ship_via$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.SHIPPING_ID",read_tpl.shipping_id$,1)
		callpoint!.setColumnData("ARM_CUSTSHIP.SHIPPING_EMAIL",read_tpl.shipping_email$,1)

		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE")

[[ARM_CUSTSHIP.AREC]]
rem --- Disable Manual Ship-to option for existing records
	callpoint!.setOptionEnabled("MANS",0)

[[ARM_CUSTSHIP.ARER]]
rem --- Need to be able to save new records coming from Order/Invoice Entry
	if callpoint!.getDevObject("createNewShipToAddr")<>null() then callpoint!.setStatus("MODIFIED")

[[ARM_CUSTSHIP.ARNF]]
rem -- Enable Manual Ship-to option for new records when OP is installed
	if callpoint!.getDevObject("op_installed")="Y" then callpoint!.setOptionEnabled("MANS",1)

[[ARM_CUSTSHIP.BDEL]]
rem --- When deleting the Customer Ship-To Address, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("ARM_CUSTSHIP.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[ARM_CUSTSHIP.BSHO]]
rem  Initializations
	use ::ado_util.src::util

rem --- Is Sales Order Processing installed for this firm?
	call pgmdir$+"adc_application.aon","OP",info$[all]
	op_installed$=info$[20]; rem ---OP installed?
	callpoint!.setDevObject("op_installed",op_installed$)

rem --- Open needed files

	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]

	if op_installed$="Y" then
		open_tables$[1]="OPT_INVSHIP",  open_opts$[1]="OTA"
		open_tables$[2]="OPT_INVHDR",  open_opts$[2]="OTA"
	endif
	open_tables$[3]="ARC_SALECODE",  open_opts$[3]="OTA"
	open_tables$[4]="ARC_TERRCODE",  open_opts$[4]="OTA"
	open_tables$[5]="ARM_CUSTEXMPT",  open_opts$[5]="OTA"
	open_tables$[6]="OPC_TAXCODE",  open_opts$[6]="OTA"

	gosub open_tables

rem --- 10395 ... Disable Manual Ship-to option for existing records
	callpoint!.setOptionEnabled("MANS",0)

[[ARM_CUSTSHIP.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Customer Ship-To Address, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("ARM_CUSTSHIP.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[ARM_CUSTSHIP.SHIPPING_EMAIL.AVAL]]
rem --- Validate email address
	email$=callpoint!.getUserInput()
	if !util.validEmailAddress(email$) then
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARM_CUSTSHIP.SLSPSN_CODE.AVAL]]
rem --- Don't allow inactive code
	arcSaleCode_dev=fnget_dev("ARC_SALECODE")
	dim arcSaleCode$:fnget_tpl$("ARC_SALECODE")
	slspsn_code$=callpoint!.getUserInput()
	read record(arcSaleCode_dev,key=firm_id$+"F"+slspsn_code$,dom=*next)arcSaleCode$
	if arcSaleCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcSaleCode.slspsn_code$,3)
		msg_tokens$[2]=cvs(arcSaleCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARM_CUSTSHIP.TAX_CODE.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	tax_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+tax_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARM_CUSTSHIP.TERRITORY.AVAL]]
rem --- Don't allow inactive code
	arcTerrCode_dev=fnget_dev("ARC_TERRCODE")
	dim arcTerrCode$:fnget_tpl$("ARC_TERRCODE")
	territory$=callpoint!.getUserInput()
	read record(arcTerrCode_dev,key=firm_id$+"H"+territory$,dom=*next)arcTerrCode$
	if arcTerrCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcTerrCode.territory$,3)
		msg_tokens$[2]=cvs(arcTerrCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ARM_CUSTSHIP.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	shipto_no$=callpoint!.getColumnData("ARM_CUSTSHIP.SHIPTO_NO")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("ARM_CUSTEXMPT")
	if callpoint!.getDevObject("op_installed")="Y" then
		checkTables!.addItem("OPT_INVHDR")
	endif
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
			if table_tpl.shipto_no$=shipto_no$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_CUSTOMER_SHIP-TO")
				switch (BBjAPI().TRUE)
                				case thisTable$="ARM_CUSTEXMPT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTEXMPT-DD_ATTR_WINT")
                    				break
                				case thisTable$="OPT_INVHDR"
						if table_tpl.ordinv_flag$="I" then
                    					msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPE_INVHDR-DD_ATTR_WINT")
						else
                    					msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPE_ORDHDR-DD_ATTR_WINT")
						endif
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
		callpoint!.setColumnData("ARM_CUSTSHIP.CODE_INACTIVE","N",1)
	endif

return



