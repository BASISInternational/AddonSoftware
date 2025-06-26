[[IVC_PRODCODE.ADIS]]
rem --- Show TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		taxSvcCd$=cvs(callpoint!.getColumnData("IVC_PRODCODE.TAX_SVC_CD"),2)
		if taxSvcCd$<>"" then
			salesTax!=callpoint!.getDevObject("salesTax")
			success=0
			desc$=salesTax!.getTaxSvcCdDesc(taxSvcCd$,err=*next); success=1
			if success then
				if desc$<>"" then
					rem --- Good code entered
					tax_svc_cd_desc!.setText(desc$)
				else
					rem --- Bad code entered
					msg_id$="OP_BAD_TAXSVC_CD"
					dim msg_tokens$[1]
					msg_tokens$[1]=taxSvcCd$
					gosub disp_message

					tax_svc_cd_desc!.setText("?????")
				endif
			else
				rem --- AvaTax call error
				tax_svc_cd_desc!.setText("?????")
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[IVC_PRODCODE.AREC]]
rem --- Clear TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		tax_svc_cd_desc!.setText("")
	endif

[[IVC_PRODCODE.AR_DIST_CODE.AVAL]]
rem --- Don't allow inactive code
	arcDistCode_dev=fnget_dev("ARC_DISTCODE")
	dim arcDistCode$:fnget_tpl$("ARC_DISTCODE")
	ar_dist_code$=callpoint!.getUserInput()
	read record(arcDistCode_dev,key=firm_id$+"D"+ar_dist_code$,dom=*next)arcDistCode$
	if arcDistCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcDistCode.ar_dist_code$,3)
		msg_tokens$[2]=cvs(arcDistCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVC_PRODCODE.ASHO]]
rem --- Disable TAX_SVC_CD when OP is not installed
	callpoint!.setDevObject("salesTax",null())
	if callpoint!.getDevObject("op")<>"Y" then
		callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",-1)
	else
		rem --- Disable TAX_SVC_CD when OP is not using a Sales Tax Service
		ops_params_dev=fnget_dev("OPS_PARAMS")
		dim ops_params$:fnget_tpl$("OPS_PARAMS")
		find record (ops_params_dev,key=firm_id$+"AR00",err=std_missing_params)ops_params$
		if cvs(ops_params.sls_tax_intrface$,2)="" then
			callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",-1)
		else
			rem --- Disable TAX_SVC_CD when not using Product Type for the Tax Service Code Source
			if ops_params.tax_svc_cd_src$<>"P" then
				callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",-1)
			else
				rem --- Get connection to Sales Tax Service
				salesTax!=new AvaTaxInterface(firm_id$)
				if salesTax!.connectClient(Form!,err=connectErr) then
					callpoint!.setDevObject("salesTax",salesTax!)
					callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",1)
				else
					callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",0)
					salesTax!.close()
				endif
			endif
		endif
	endif

	break

connectErr:
	callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",0)
	if salesTax!<>null() then salesTax!.close()

	break

[[IVC_PRODCODE.BDEL]]
rem --- Make sure prod type being deleted isn't used in ivm-01

ivm01_dev=fnget_dev("IVM_ITEMMAST")
ivs_defaults=fnget_dev("IVS_DEFAULTS")
dim ivs_defaults$:fnget_tpl$("IVS_DEFAULTS")
prod_type$ = callpoint!.getColumnData("IVC_PRODCODE.PRODUCT_TYPE")

read (ivm01_dev,key=firm_id$+prod_type$,knum="AO_PROD_ITEM",dom=*next)
k$="", k$=key(ivm01_dev,err=*next)
if pos(firm_id$+prod_type$=k$)=1
	dim msg_tokens$[1]
	msg_tokens$[1]=Translate!.getTranslation("AON_THIS_PRODUCT_TYPE_IS_ASSIGNED_TO_ONE_OR_MORE_INVENTORY_ITEMS.")
	msg_id$="IV_NO_DELETE"
	gosub disp_message
	callpoint!.setStatus("ABORT")
	break
endif

rem --- Make sure this prod type isn't a default

readrecord (ivs_defaults,key=firm_id$+"D",dom=*next)ivs_defaults$

if ivs_defaults.product_type$=prod_type$ then
	msg_id$="IV_PROD_DEFAULT"
	gosub disp_message
	callpoint!.setStatus("ABORT")
	break
endif

rem --- When deleting the Product Type code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("IVC_PRODCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_PRODCODE.BEND]]
rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[IVC_PRODCODE.BSHO]]
rem --- Inits

use ::ado_util.src::util
use ::opo_AvaTaxInterface.aon::AvaTaxInterface

rem --- Is Accounts Receivable installed?
call dir_pgm1$+"adc_application.aon","AR",info$[all]
ar$=info$[20]

rem --- Is Sales Order Processing installed?

call dir_pgm1$+"adc_application.aon","OP",info$[all]
op$=info$[20]
callpoint!.setDevObject("op",op$)
callpoint!.setDevObject("usingOP",op$)

rem --- This firm using Purchase Orders?
call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
callpoint!.setDevObject("usingPO",info$[20])

rem --- Open/Lock files

files=12
begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="IVS_PARAMS",options$[1]="OTA"
files$[2]="IVM_ITEMMAST",options$[2]="OTA"
files$[3]="IVM_ITEMWHSE",options$[3]="OTA"
files$[4]="IVS_DEFAULTS",options$[4]="OTA"
files$[12]="IVC_TYPECODE",options$[12]="OTA"
if op$="Y" then 
	files$[5]="OPS_PARAMS",options$[5]="OTA"
	files$[6]="OPC_LINECODE",options$[6]="OTA"
	files$[7]="OPT_INVDET",options$[7]="OTA"
	files$[8]="OPT_INVKITDET",options$[8]="OTA"
endif
if ar$="Y" then files$[9]="ARC_DISTCODE",options$[9]="OTA"
if usingPO$="Y" then 
	files$[10]="POE_ORDDET",options$[10]="OTA"
	files$[11]="POE_ORDTOT",options$[11]="OTA"
endif

call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:                                 chans$[all],templates$[all],table_chans$[all],batch,status$
if status$<>"" then
	remove_process_bar:
	bbjAPI!=bbjAPI()
	rdFuncSpace!=bbjAPI!.getGroupNamespace()
	rdFuncSpace!.setValue("+build_task","OFF")
	release
endif
ivs01_dev=num(chans$[1])

rem --- Dimension miscellaneous string templates

dim ivs01a$:templates$[1]

rem --- init/parameters

ivs01a_key$=firm_id$+"IV00"
find record (ivs01_dev,key=ivs01a_key$,err=std_missing_params) ivs01a$

rem --- Disable SA_LEVEL when SA is not installed

call stbl("+DIR_PGM")+"adc_application.aon","SA",info$[all]
sa$=info$[20]
if sa$<>"Y"
	ctl_name$="IVC_PRODCODE.SA_LEVEL"
	ctl_stat$="D"
	gosub disable_fields
	callpoint!.setTableColumnAttribute("IVC_PRODCODE.SA_LEVEL","DFLT","N")
endif

rem --- Disable AR_DIST_CODE when AR is not installed

if ar$<>"Y"
	ctl_name$="IVC_PRODCODE.AR_DIST_CODE"
	ctl_stat$="D"
	gosub disable_fields
endif

rem --- Add static label for displaying TAX_SVC_CD description
tax_svc_cd!=fnget_control!("IVC_PRODCODE.TAX_SVC_CD")
tax_svc_cd_x=tax_svc_cd!.getX()
tax_svc_cd_y=tax_svc_cd!.getY()
tax_svc_cd_height=tax_svc_cd!.getHeight()
tax_svc_cd_width=tax_svc_cd!.getWidth()
code_desc!=fnget_control!("IVC_PRODCODE.CODE_DESC")
code_desc_width=code_desc!.getWidth()
nxt_ctlID=util.getNextControlID()
tax_svc_cd_desc!=Form!.addStaticText(nxt_ctlID,tax_svc_cd_x+tax_svc_cd_width+5,tax_svc_cd_y+3,int(code_desc_width*1.5),tax_svc_cd_height,"")
callpoint!.setDevObject("tax_svc_cd_desc",tax_svc_cd_desc!)

[[IVC_PRODCODE.BUYER_CODE.AVAL]]
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

[[IVC_PRODCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Product Type code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_PRODCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[IVC_PRODCODE.ITEM_CLASS.AVAL]]
	ivc_clascode=fnget_dev("IVC_CLASCODE")
	dim ivc_clascode$:fnget_tpl$("IVC_CLASCODE")
	item_class$=callpoint!.getUserInput()
	read record (ivc_clascode,key=firm_id$+item_class$,dom=*next)ivc_clascode$
	if ivc_clascode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivc_clascode.item_class$,3)
		msg_tokens$[2]=cvs(ivc_clascode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVC_PRODCODE.ITEM_TYPE.AVAL]]
rem --- Don't allow inactive code
	ivcTypeCode_dev=fnget_dev("IVC_TYPECODE")
	dim ivcTypeCode$:fnget_tpl$("IVC_TYPECODE")
	type_code$=callpoint!.getUserInput()
	read record (ivcTypeCode_dev,key=firm_id$+type_code$,dom=*next)ivcTypeCode$
	if ivcTypeCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcTypeCode.item_type$,3)
		msg_tokens$[2]=cvs(ivcTypeCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVC_PRODCODE.TAX_SVC_CD.AVAL]]
rem --- Validate TAX_SVC_CD
	taxSvcCd$=cvs(callpoint!.getUserInput(),2)
	priorTaxSvcCd$=cvs(callpoint!.getColumnData("IVC_PRODCODE.TAX_SVC_CD"),2)
	if taxSvcCd$<>priorTaxSvcCd$ then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		if taxSvcCd$<>"" then
			salesTax!=callpoint!.getDevObject("salesTax")
			success=0
			desc$=salesTax!.getTaxSvcCdDesc(taxSvcCd$,err=*next); success=1
			if success then
				if desc$<>"" then
					rem --- Good code entered
					tax_svc_cd_desc!.setText(desc$)
				else
					rem --- Bad code entered
					msg_id$="OP_BAD_TAXSVC_CD"
					dim msg_tokens$[1]
					msg_tokens$[1]=taxSvcCd$
					gosub disp_message

					callpoint!.setColumnData("IVC_PRODCODE.TAX_SVC_CD",priorTaxSvcCd$,1)
					callpoint!.setStatus("ABORT")
					break
				endif
			else
				rem --- AvaTax call error
				callpoint!.setColumnData("IVC_PRODCODE.TAX_SVC_CD",priorTaxSvcCd$,1)
				callpoint!.setStatus("ABORT")
				break
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[IVC_PRODCODE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	product_type$=callpoint!.getColumnData("IVC_PRODCODE.PRODUCT_TYPE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVM_ITEMMAST")
	checkTables!.addItem("IVM_ITEMWHSE")
	checkTables!.addItem("IVS_DEFAULTS")
	if callpoint!.getDevObject("usingOP")="Y" then
		checkTables!.addItem("OPC_LINECODE")
		checkTables!.addItem("OPT_INVDET")
		checkTables!.addItem("OPT_INVKITDET")
	endif
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_ORDDET")
		checkTables!.addItem("POE_ORDTOT")
	endif
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		if thisTable$="OPT_INVDET" or hisTable$="OPT_INVKITDET" then
			read(table_dev,key=firm_id$+"E",knum="AO_STATUS",dom=*next)
		else
			read(table_dev,key=firm_id$,dom=*next)
		endif
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.product_type$=product_type$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_PRODUCT_TYPE")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVM_ITEMMAST"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMMAST-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVM_ITEMWHSE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMWHSE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVS_DEFAULTS"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVS_DEFAULTS-DD_ATTR_WINT")
						break
                				case thisTable$="OPC_LINECODE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPC_LINECODE-DD_ATTR_WINT")
						break
                				case thisTable$="OPT_INVDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPT_INVDET-DD_ATTR_WINT")
						break
                				case thisTable$="OPT_INVKITDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPT_INVKITDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_ORDDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ORDDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_ORDTOT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ORDTOT-DD_ATTR_WINT")
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
		callpoint!.setColumnData("IVC_PRODCODE.CODE_INACTIVE","N",1)
	endif

return

rem #include fnget_control.src
	def fnget_control!(ctl_name$)
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	get_control!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
	return get_control!
	fnend
rem #endinclude fnget_control.src

rem #include disable_fields.src

disable_fields:
	rem --- used to disable/enable controls
	rem --- ctl_name$ sent in with name of control to enable/disable (format "ALIAS.CONTROL_NAME")
	rem --- ctl_stat$ sent in as D or space, meaning disable/enable, respectively

	wctl$=str(num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI")):"00000")
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)=ctl_stat$
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP-REFRESH-ACTIVATE")

return

rem #endinclude disable_fields.src

#include [+ADDON_LIB]std_missing_params.aon



