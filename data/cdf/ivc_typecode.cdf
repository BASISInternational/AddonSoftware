[[IVC_TYPECODE.ADIS]]
rem --- Show TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		taxSvcCd$=cvs(callpoint!.getColumnData("IVC_TYPECODE.TAX_SVC_CD"),2)
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

[[IVC_TYPECODE.AREC]]
rem --- Clear TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		tax_svc_cd_desc!.setText("")
	endif

[[IVC_TYPECODE.ASHO]]
rem --- Disable TAX_SVC_CD when OP is not installed
	callpoint!.setDevObject("salesTax",null())
	if callpoint!.getDevObject("op")<>"Y" then
		callpoint!.setColumnEnabled("IVC_TYPECODE.TAX_SVC_CD",-1)
	else
		rem --- Disable TAX_SVC_CD when OP is not using a Sales Tax Service
		ops_params_dev=fnget_dev("OPS_PARAMS")
		dim ops_params$:fnget_tpl$("OPS_PARAMS")
		find record (ops_params_dev,key=firm_id$+"AR00",err=std_missing_params)ops_params$
		if cvs(ops_params.sls_tax_intrface$,2)="" then
			callpoint!.setColumnEnabled("IVC_TYPECODE.TAX_SVC_CD",-1)
		else
			rem --- Disable TAX_SVC_CD when not using Product Type for the Tax Service Code Source
			if ops_params.tax_svc_cd_src$<>"T" then
				callpoint!.setColumnEnabled("IVC_TYPECODE.TAX_SVC_CD",-1)
			else
				rem --- Get connection to Sales Tax Service
				salesTax!=new AvaTaxInterface(firm_id$)
				if salesTax!.connectClient(Form!,err=connectErr) then
					callpoint!.setDevObject("salesTax",salesTax!)
					callpoint!.setColumnEnabled("IVC_TYPECODE.TAX_SVC_CD",1)
				else
					callpoint!.setColumnEnabled("IVC_TYPECODE.TAX_SVC_CD",0)
					salesTax!.close()
				endif
			endif
		endif
	endif

	break

connectErr:
	callpoint!.setColumnEnabled("IVC_TYPECODE.TAX_SVC_CD",0)
	if salesTax!<>null() then salesTax!.close()

	break

[[IVC_TYPECODE.BDEL]]
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
		callpoint!.setColumnData("IVC_TYPECODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_TYPECODE.BEND]]
rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[IVC_TYPECODE.BSHO]]
rem --- Inits

use ::ado_util.src::util
use ::opo_AvaTaxInterface.aon::AvaTaxInterface

rem --- Is Sales Order Processing installed?

call dir_pgm1$+"adc_application.aon","OP",info$[all]
op$=info$[20]
callpoint!.setDevObject("op",op$)

rem --- Open/Lock files

files=4
if op$="Y" then files=5
begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="IVS_PARAMS",options$[1]="OTA"
files$[2]="IVM_ITEMMAST",options$[2]="OTA"
files$[3]="IVS_DEFAULTS",options$[3]="OTA"
files$[4]="IVC_PRODCODE",options$[4]="OTA"
if op$="Y" then files$[5]="OPS_PARAMS",options$[5]="OTA"
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

rem --- Add static label for displaying TAX_SVC_CD description
tax_svc_cd!=fnget_control!("IVC_TYPECODE.TAX_SVC_CD")
tax_svc_cd_x=tax_svc_cd!.getX()
tax_svc_cd_y=tax_svc_cd!.getY()
tax_svc_cd_height=tax_svc_cd!.getHeight()
tax_svc_cd_width=tax_svc_cd!.getWidth()
code_desc!=fnget_control!("IVC_TYPECODE.CODE_DESC")
code_desc_width=code_desc!.getWidth()
nxt_ctlID=util.getNextControlID()
tax_svc_cd_desc!=Form!.addStaticText(nxt_ctlID,tax_svc_cd_x+tax_svc_cd_width+5,tax_svc_cd_y+3,int(code_desc_width*1.5),tax_svc_cd_height,"")
callpoint!.setDevObject("tax_svc_cd_desc",tax_svc_cd_desc!)

[[IVC_TYPECODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Item Type code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_TYPECODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[IVC_TYPECODE.TAX_SVC_CD.AVAL]]
rem --- Validate TAX_SVC_CD
	taxSvcCd$=cvs(callpoint!.getUserInput(),2)
	priorTaxSvcCd$=cvs(callpoint!.getColumnData("IVC_typeCODE.TAX_SVC_CD"),2)
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

					callpoint!.setColumnData("IVC_TYPECODE.TAX_SVC_CD",priorTaxSvcCd$,1)
					callpoint!.setStatus("ABORT")
					break
				endif
			else
				rem --- AvaTax call error
				callpoint!.setColumnData("IVC_TYPECODE.TAX_SVC_CD",priorTaxSvcCd$,1)
				callpoint!.setStatus("ABORT")
				break
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[IVC_TYPECODE.<CUSTOM>]]
rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	item_type$=callpoint!.getColumnData("IVC_TYPECODE.ITEM_TYPE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVM_ITEMMAST")
	checkTables!.addItem("IVC_PRODCODE")
	checkTables!.addItem("IVS_DEFAULTS")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.item_type$=item_type$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_ITEM_TYPE_")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVM_ITEMMAST"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMMAST-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVC_PRODCODE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVC_PRODCODE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVS_DEFAULTS"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVS_DEFAULTS-DD_ATTR_WINT")
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
		callpoint!.setColumnData("IVC_TYPECODE.CODE_INACTIVE","N",1)
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

#include [+ADDON_LIB]std_missing_params.aon



