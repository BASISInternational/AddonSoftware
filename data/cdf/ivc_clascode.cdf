[[IVC_CLASCODE.ADIS]]
rem --- Show TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		taxSvcCd$=cvs(callpoint!.getColumnData("IVC_CLASCODE.TAX_SVC_CD"),2)
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

[[IVC_CLASCODE.AREC]]
rem --- Clear TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		tax_svc_cd_desc!.setText("")
	endif

[[IVC_CLASCODE.ASHO]]
rem --- Disable TAX_SVC_CD when OP is not installed
	callpoint!.setDevObject("salesTax",null())
	if callpoint!.getDevObject("op")<>"Y" then
		callpoint!.setColumnEnabled("IVC_CLASCODE.TAX_SVC_CD",-1)
	else
		rem --- Disable TAX_SVC_CD when OP is not using a Sales Tax Service
		ops_params_dev=fnget_dev("OPS_PARAMS")
		dim ops_params$:fnget_tpl$("OPS_PARAMS")
		find record (ops_params_dev,key=firm_id$+"AR00",err=std_missing_params)ops_params$
		if cvs(ops_params.sls_tax_intrface$,2)="" then
			callpoint!.setColumnEnabled("IVC_CLASCODE.TAX_SVC_CD",-1)
		else
			rem --- Disable TAX_SVC_CD when not using Product Type for the Tax Service Code Source
			if ops_params.tax_svc_cd_src$<>"C" then
				callpoint!.setColumnEnabled("IVC_CLASCODE.TAX_SVC_CD",-1)
			else
				rem --- Get connection to Sales Tax Service
				salesTax!=new AvaTaxInterface(firm_id$)
				if salesTax!.connectClient(Form!,err=connectErr) then
					callpoint!.setDevObject("salesTax",salesTax!)
					callpoint!.setColumnEnabled("IVC_CLASCODE.TAX_SVC_CD",1)
				else
					callpoint!.setColumnEnabled("IVC_CLASCODE.TAX_SVC_CD",0)
					salesTax!.close()
				endif
			endif
		endif
	endif

	break

connectErr:
	callpoint!.setColumnEnabled("IVC_CLASCODE.TAX_SVC_CD",0)
	if salesTax!<>null() then salesTax!.close()

	break

[[IVC_CLASCODE.BDEL]]
rem --- Make sure item class being deleted isn't used in ivm-01

ivm01_dev=fnget_dev("IVM_ITEMMAST")
ivs_defaults=fnget_dev("IVS_DEFAULTS")
dim ivs_defaults$:fnget_tpl$("IVS_DEFAULTS")
item_class$ = callpoint!.getColumnData("IVC_CLASCODE.ITEM_CLASS")

read (ivm01_dev,key=firm_id$+item_class$,knum="AO_ITMCLS_ITEM",dom=*next)
k$="", k$=key(ivm01_dev,err=*next)
if pos(firm_id$+item_class$=k$)=1
	msg_id$="IV_CLASS_IN_USE"
	gosub disp_message
	callpoint!.setStatus("ABORT")
endif

rem --- Make sure this item class isn't a default

readrecord (ivs_defaults,key=firm_id$+"D",dom=*next)ivs_defaults$

if ivs_defaults.item_class$=item_class$ then
	msg_id$="IV_CLASS_DEFAULT"
	gosub disp_message
	callpoint!.setStatus("ABORT")
	return
endif

rem --- When deleting the CLASS Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("IVC_CLASCODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_CLASCODE.BEND]]
rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[IVC_CLASCODE.BSHO]]
rem --- Initial Imports
use ::ado_util.src::util
use ::opo_AvaTaxInterface.aon::AvaTaxInterface

rem --- Check Installations
call dir_pgm1$+"adc_application.aon","OP",info$[all]
op$=info$[20]
callpoint!.setDevObject("op",op$)

rem --- Define Files Based on Installations
num_files=6
dim open_tables$[1:num_files], open_opts$[1:num_files], open_chans$[1:num_files], open_tpls$[1:num_files]

open_tables$[1]="IVS_PARAMS", open_opts$[1]="OTA"
open_tables$[2]="IVM_ITEMMAST", open_opts$[2]="OTA"
open_tables$[3]="IVS_DEFAULTS", open_opts$[3]="OTA"

if op$="Y" then
    open_tables$[4]="OPS_PARAMS", open_opts$[4]="OTA"
endif

open_tables$[5]="IVC_PRICCODE", open_opts$[5]="OTA"
open_tables$[6]="IVC_PRODCODE", open_opts$[6]="OTA"

gosub open_tables


rem --- Error Check
if status$<>"" then
    remove_process_bar:
    bbjAPI!=bbjAPI()
    rdFuncSpace!=bbjAPI!.getGroupNamespace()
    rdFuncSpace!.setValue("+build_task","OFF")
    release
endif

[[IVC_CLASCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Buyer Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_CLASCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[IVC_CLASCODE.TAX_SVC_CD.AVAL]]
rem --- Validate TAX_SVC_CD
	taxSvcCd$=cvs(callpoint!.getUserInput(),2)
	priorTaxSvcCd$=cvs(callpoint!.getColumnData("IVC_CLASCODE.TAX_SVC_CD"),2)
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

					callpoint!.setColumnData("IVC_CLASCODE.TAX_SVC_CD",priorTaxSvcCd$,1)
					callpoint!.setStatus("ABORT")
					break
				endif
			else
				rem --- AvaTax call error
				callpoint!.setColumnData("IVC_CLASCODE.TAX_SVC_CD",priorTaxSvcCd$,1)
				callpoint!.setStatus("ABORT")
				break
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[IVC_CLASCODE.<CUSTOM>]]
rem #include fnget_control.src
	def fnget_control!(ctl_name$)
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	get_control!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
	return get_control!
	fnend
rem #endinclude fnget_control.src

#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	item_class$=callpoint!.getColumnData("IVC_CLASCODE.item_class")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVC_PRICCODE")
	checkTables!.addItem("IVC_PRODCODE")
	checkTables!.addItem("IVM_ITEMMAST")
	checkTables!.addItem("IVS_DEFAULTS")
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		read(table_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.item_class$=item_class$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2] 
				msg_tokens$[1]=Translate!.getTranslation("DDM_ELEMENTS-ITEM_CLASS-DD_ATTR_LABL=Item Class")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVC_PRICCODE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVC_PRICCODE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVC_PRODCODE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVC_PRODCODE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVM_ITEMMAST"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMMAST-DD_ATTR_WINT")
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
		callpoint!.setColumnData("IVC_CLASCODE.CODE_INACTIVE","N",1)

	endif
	return



