[[IVC_WHSECODE.BDEL]]
rem --- When deleting the Warehouse ID code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("IVC_WHSECODE.CODE_INACTIVE","Y",1)
		callpoint!.setStatus("SAVE;ABORT")
		break
	endif

[[IVC_WHSECODE.BSHO]]
rem --- This firm using Bill Of Materials?
call stbl("+DIR_PGM")+"adc_application.aon","BM",info$[all]
callpoint!.setDevObject("usingBM",info$[20])

rem --- This firm using Materials Resource Planning?
call stbl("+DIR_PGM")+"adc_application.aon","MP",info$[all]
callpoint!.setDevObject("usingMP",info$[20])

rem --- This firm using Sales Order Processing?
call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
callpoint!.setDevObject("usingOP",info$[20])

rem --- This firm using Purchase Orders Processing?
call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
callpoint!.setDevObject("usingPO",info$[20])

rem --- This firm using Shop Floor Control?
call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
callpoint!.setDevObject("usingPO",info$[20])

rem --- Open/Lock files

files=41,begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="IVC_PHYSCODE",options$[1]="OTA"
files$[2]="IVE_ABCWHSE",options$[2]="OTA"
files$[3]="IVE_COSTCHG",options$[3]="OTA"
files$[4]="IVE_PHYSICAL",options$[4]="OTA"
files$[5]="IVE_PRICECHG",options$[5]="OTA"
files$[6]="IVE_TRANSDET",options$[6]="OTA"
files$[7]="IVE_TRANSFER",options$[7]="OTA"
files$[8]="IVE_TRANSFERDET",options$[8]="OTA"
files$[9]="IVE_TRANSFERHDR",options$[9]="OTA"
files$[10]="IVM_ITEMACT",options$[10]="OTA"
files$[11]="IVM_ITEMTIER",options$[11]="OTA"
files$[12]="IVM_ITEMWHSE",options$[12]="OTA"
files$[13]="IVM_LSACT",options$[13]="OTA"
files$[14]="IVM_LSMASTER",options$[14]="OTA"
files$[15]="IVS_PARAMS",options$[15]="OTA"
if callpoint!.getDevObject("usingBM")="Y" then
	files$[16]="BME_PRODUCT",options$[16]="OTA"
endif
if callpoint!.getDevObject("usingMP")="Y" then
	files$[17]="MPE_MATDET",options$[17]="OTA"
	files$[18]="MPE_PEGGING",options$[18]="OTA"
	files$[19]="MPE_PRODUCT",options$[19]="OTA"
	files$[20]="MPE_RESDEV",options$[20]="OTA"
	files$[21]="MPE_RESOURCE",options$[21]="OTA"
endif
if callpoint!.getDevObject("usingOP")="Y" then
	files$[22]="OPT_INVDET",options$[22]="OTA"
	files$[23]="OPM_POINTOFSALE",options$[23]="OTA"
	files$[24]="OPT_INVKITDET",options$[24]="OTA"
endif
if callpoint!.getDevObject("usingPO")="Y" then
	files$[25]="POE_ORDDET",options$[25]="OTA"
	files$[26]="POE_PODET",options$[26]="OTA"
	files$[27]="POE_POHDR",options$[27]="OTA"
	files$[28]="POE_QADET",options$[28]="OTA"
	files$[29]="POE_QAHDR",options$[29]="OTA"
	files$[30]="POE_RECDET",options$[30]="OTA"
	files$[31]="POE_RECHDR",options$[31]="OTA"
	files$[32]="POE_REPSURP",options$[32]="OTA"
	files$[33]="POE_REQDET",options$[33]="OTA"
	files$[34]="POE_REQHDR",options$[34]="OTA"
endif
if callpoint!.getDevObject("usingSF")="Y" then
	files$[35]="SFE_WOMASTR",options$[35]="OTA"
	files$[36]="SFE_WOMATDTL",options$[36]="OTA"
	files$[37]="SFE_WOMATHDR",options$[37]="OTA"
	files$[38]="SFE_WOMATISD",options$[38]="OTA"
	files$[39]="SFE_WOMATISH",options$[39]="OTA"
	files$[40]="SFE_WOMAT",options$[40]="OTA"
	files$[41]="SFS_PARAMS",options$[41]="OTA"
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

ivs01_dev=num(chans$[15])

rem --- Dimension miscellaneous string templates

dim ivs01a$:templates$[15]

rem --- init/parameters

ivs01a_key$=firm_id$+"IV00"
find record (ivs01_dev,key=ivs01a_key$,err=std_missing_params) ivs01a$

[[IVC_WHSECODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Warehouse ID code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("IVC_WHSECODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[IVC_WHSECODE.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	warehouse_id$=callpoint!.getColumnData("IVC_WHSECODE.WAREHOUSE_ID")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("IVC_PHYSCODE")
	checkTables!.addItem("IVE_ABCWHSE")
	checkTables!.addItem("IVE_COSTCHG")
	checkTables!.addItem("IVE_PHYSICAL")
	checkTables!.addItem("IVE_PRICECHG")
	checkTables!.addItem("IVE_TRANSDET")
	checkTables!.addItem("IVE_TRANSFER")
	checkTables!.addItem("IVE_TRANSFERDET")
	checkTables!.addItem("IVE_TRANSFERHDR")
	checkTables!.addItem("IVM_ITEMACT")
	checkTables!.addItem("IVM_ITEMTIER")
	checkTables!.addItem("IVM_ITEMWHSE")
	checkTables!.addItem("IVM_LSACT")
	checkTables!.addItem("IVM_LSMASTER")
	checkTables!.addItem("IVS_PARAMS")
	if callpoint!.getDevObject("usingBM")="Y" then
		checkTables!.addItem("BME_PRODUCT")
	endif
	if callpoint!.getDevObject("usingMP")="Y" then
		checkTables!.addItem("MPE_MATDET")
		checkTables!.addItem("MPE_PEGGING")
		checkTables!.addItem("MPE_PRODUCT")
		checkTables!.addItem("MPE_RESDEV")
		checkTables!.addItem("MPE_RESOURCE")
	endif
	if callpoint!.getDevObject("usingOP")="Y" then
		checkTables!.addItem("OPT_INVDET")
		checkTables!.addItem("OPM_POINTOFSALE")
		checkTables!.addItem("OPT_INVKITDET")
	endif
	if callpoint!.getDevObject("usingPO")="Y" then
		checkTables!.addItem("POE_ORDDET")
		checkTables!.addItem("POE_PODET")
		checkTables!.addItem("POE_POHDR")
		checkTables!.addItem("POE_QADET")
		checkTables!.addItem("POE_QAHDR")
		checkTables!.addItem("POE_RECDET")
		checkTables!.addItem("POE_RECHDR")
		checkTables!.addItem("POE_REPSURP")
		checkTables!.addItem("POE_REQDET")
		checkTables!.addItem("POE_REQHDR")
	endif
	if callpoint!.getDevObject("usingSF")="Y" then
		checkTables!.addItem("SFE_WOMASTR")
		checkTables!.addItem("SFE_WOMATDTL")
		checkTables!.addItem("SFE_WOMATHDR")
		checkTables!.addItem("SFE_WOMATISD")
		checkTables!.addItem("SFE_WOMATISH")
		checkTables!.addItem("SFE_WOMAT")
		checkTables!.addItem("SFS_PARAMS")
	endif
	for i=0 to checkTables!.size()-1
		thisTable$=checkTables!.getItem(i)
		table_dev = fnget_dev(thisTable$)
		dim table_tpl$:fnget_tpl$(thisTable$)
		if thisTable$="OPT_INVDET" or thisTable$="OPT_INVKITDET" then
			read(table_dev,key=firm_id$+"E",knum="STAT_WH_ITEM_ORD",dom=*next)
		else
			read(table_dev,key=firm_id$,dom=*next)
		endif
		while 1
			readrecord(table_dev,end=*break)table_tpl$
			if table_tpl.firm_id$<>firm_id$ then break
			if table_tpl.warehouse_id$=warehouse_id$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("AON_WAREHOUSE")+" "+Translate!.getTranslation("AON_CODE")
				switch (BBjAPI().TRUE)
                				case thisTable$="IVC_PHYSCODE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVC_PHYSCODE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVE_ABCWHSE"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_ABCWHSE-DD_ATTR_WINT")
                    				break
                				case thisTable$="IVE_COSTCHG"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_COSTCHG-DD_ATTR_WINT")
						break
                				case thisTable$="IVE_PHYSICAL"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_PHYSICAL-DD_ATTR_WINT")
						break
                				case thisTable$="IVE_PRICECHG"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_PRICECHG-DD_ATTR_WINT")
						break
                				case thisTable$="IVE_TRANSDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_TRANSDET-DD_ATTR_WINT")
						break
                				case thisTable$="IVE_TRANSFER"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_TRANSFER-DD_ATTR_WINT")
						break
                				case thisTable$="IVE_TRANSFERDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_TRANSFERDET-DD_ATTR_WINT")
						break
                				case thisTable$="IVE_TRANSFERHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVE_TRANSFERHDR-DD_ATTR_WINT")
						break
                				case thisTable$="IVM_ITEMACT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMACT-DD_ATTR_WINT")
						break
                				case thisTable$="IVM_ITEMTIER"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMTIER-DD_ATTR_WINT")
						break
                				case thisTable$="IVM_ITEMWHSE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_ITEMWHSE-DD_ATTR_WINT")
						break
                				case thisTable$="IVM_LSACT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_LSACT-DD_ATTR_WINT")
						break
                				case thisTable$="IVM_LSMASTER"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVM_LSMASTER-DD_ATTR_WINT")
						break
                				case thisTable$="IVS_PARAMS"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-IVS_PARAMS-DD_ATTR_WINT")
						break
                				case thisTable$="BME_PRODUCT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-BME_PRODUCT-DD_ATTR_WINT")
						break
                				case thisTable$="MPE_MATDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPE_MATDET-DD_ATTR_WINT")
						break
                				case thisTable$="MPE_PEGGING"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPE_PEGGING-DD_ATTR_WINT")
						break
                				case thisTable$="MPE_PRODUCT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPE_PRODUCT-DD_ATTR_WINT")
						break
                				case thisTable$="MPE_RESDEV"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPE_RESDEV-DD_ATTR_WINT")
						break
                				case thisTable$="MPE_RESOURCE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-MPE_RESOURCE-DD_ATTR_WINT")
						break
                				case thisTable$="OPT_INVDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPT_INVDET-DD_ATTR_WINT")
						break
                				case thisTable$="OPM_POINTOFSALE"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPM_POINTOFSALE-DD_ATTR_WINT")
						break
                				case thisTable$="OPT_INVKITDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-OPT_INVKITDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_ORDDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_ORDDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_PODET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_PODET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_POHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_POHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_QADET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QADET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_QAHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_QAHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_RECDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_RECDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_RECHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_RECHDR-DD_ATTR_WINT")
						break
                				case thisTable$="POE_REPSURP"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REPSURP-DD_ATTR_WINT")
						break
                				case thisTable$="POE_REQDET"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REQDET-DD_ATTR_WINT")
						break
                				case thisTable$="POE_REQHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-POE_REQHDR-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOMASTR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMASTR-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOMATDTL"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMATDTL-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOMATHDR"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMATHDR-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOMATISD"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMATISD-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOMATISH"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMATISH-DD_ATTR_WINT")
						break
                				case thisTable$="SFE_WOMAT"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFE_WOMAT-DD_ATTR_WINT")
						break
                				case thisTable$="SFS_PARAMS"
                    				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-SFS_PARAMS-DD_ATTR_WINT")
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
		callpoint!.setColumnData("IVC_WHSECODE.CODE_INACTIVE","N",1)
	endif

return



