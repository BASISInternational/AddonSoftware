[[APM_VENDADDR.ASHO]]
rem --- Warn if length of address lines has been restricted
	std_addr_line_len=num(callpoint!.getDevObject("std_addr_line_len"))
	maxl=num(callpoint!.getTableColumnAttribute("APM_VENDADDR.ADDR_LINE_1","MAXL"))
	if maxl<std_addr_line_len then
		msg_id$="AP_VEND_ADDR_LIMIT"
		gosub disp_message
	endif

[[APM_VENDADDR.BDEL]]
rem --- When deleting the Vendor Purchasing Address Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("APM_VENDADDR.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[APM_VENDADDR.BSHO]]
rem --- if running PO as V6Hybrid, constrain address/city input lengths

callpoint!.setDevObject("std_addr_line_len",callpoint!.getTableColumnAttribute("APM_VENDADDR.ADDR_LINE_1","MAXL"))
while 1
	v6h$=stbl("+V6DATA",err=*break)
	if v6h$<>""
		sym04_dev=unt
		open(sym04_dev)v6h$+"SYM-04"
		SYM04A: IOLIST A0$(1),A1$(1),A2$(1),A3$(1),A[ALL]
		dim A0$(2),A1$(64),A2$(50),A3$(50),A[2]
		A0$="PO"
		find(sym04_dev,key=A0$,dom=*break)IOL=SYM04A
		close(sym04_dev)
		installed$=A1$(39,1)
		if installed$="Y" then
			callpoint!.setTableColumnAttribute("APM_VENDADDR.ADDR_LINE_1","MAXL","24")
			addr1!=callpoint!.getControl("APM_VENDADDR.ADDR_LINE_1")
			addr1!.setLength(24)
			callpoint!.setTableColumnAttribute("APM_VENDADDR.ADDR_LINE_2","MAXL","24")
			addr2!=callpoint!.getControl("APM_VENDADDR.ADDR_LINE_2")
			addr2!.setLength(24)
			callpoint!.setTableColumnAttribute("APM_VENDADDR.CITY","MAXL","24")
			city!=callpoint!.getControl("APM_VENDADDR.CITY")
			city!.setLength(24)
		endif
	endif
	break
wend

[[APM_VENDADDR.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Vendor Purchasing Address Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("APM_VENDADDR.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[APM_VENDADDR.PURCH_ADDR.AINP]]
if cvs(callpoint!.getUserInput(),2)="" callpoint!.setStatus("ABORT")

if num(callpoint!.getUserInput())=0 callpoint!.setStatus("ABORT")

[[APM_VENDADDR.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	vendor_id$=callpoint!.getColumnData("APM_VENDADDR.VENDOR_ID")
	purch_addr$=callpoint!.getColumnData("APM_VENDADDR.PURCH_ADDR")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("APM_VENDREPL")
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_POHDR")
		checkTables!.addItem("POE_QAHDR")
		checkTables!.addItem("POE_RECHDR")
		checkTables!.addItem("POE_REQHDR")
	endif
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		dim msg_tokens$[2]
		switch (BBjAPI().TRUE)
                		case thisTable$="APM_VENDREPL"
				altKey$="PRIMARY"
                   		msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-APM_VENDREPL-DD_ATTR_WINT")
                    		break
               		case thisTable$="POE_POHDR"
				altKey$="AO_VEND_PO"
                    		msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_POHDR-DD_ATTR_WINT")
                    		break
                		case thisTable$="POE_QAHDR"
				altKey$="AO_VEND_RCVR_PO"
                    		msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QAHDR-DD_ATTR_WINT")
                    		break
                		case thisTable$="POE_RECHDR"
				altKey$="AO_VEND_RCVR_PO"
                    		msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_RECHDR-DD_ATTR_WINT")
                    		break
                		case thisTable$="POE_REQHDR"
				altKey$="AO_VEND_REQ"
                    		msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REQHDR-DD_ATTR_WINT")
                    		break
           		case default
                    		msg_tokens$[2]="???"
                    		break
            	swend
		read(table_dev,key=firm_id$+vendor_id$,knum=altKey$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$+table_tpl.vendor_id$<>firm_id$+vendor_id$ then break
			if table_tpl.purch_addr$=purch_addr$ then
				msg_id$="AD_CODE_IN_USE"
				msg_tokens$[1]=Translate!.getTranslation("DDM_TABLE_COLS-APM_VENDREPL-PURCH_ADDR-DD_ATTR_LABL")
				gosub disp_message

				found=1
				break
			endif
		wend
		if found then break
	next i

	if found then
		rem --- Uncheck the CODE_INACTIVE checkbox
		callpoint!.setColumnData("APM_VENDADDR.CODE_INACTIVE","N",1)
	endif

return



