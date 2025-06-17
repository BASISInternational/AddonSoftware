[[IVR_PRICECHGPCT.ASVA]]
rem --- Percent change can't be zero

	if num( callpoint!.getColumnData("IVR_PRICECHGPCT.PERCENT_CHANGE") ) = 0 then
		callpoint!.setMessage("IV_PCT_CHG_INVALID")
		callpoint!.setStatus("ABORT")
	endif

[[IVR_PRICECHGPCT.BSHO]]
rem --- Open files

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVC_PRODCODE", open_opts$[1]="OTA"

	gosub open_tables

rem --- Get Batch information
rem --- this will let oper set up or select a batch (if batching turned on)
rem --- stbl("+BATCH_NO) will either be zero (not batching) or contain the batch#

call stbl("+DIR_PGM")+"adc_getbatch.aon",callpoint!.getAlias(),"",table_chans$[all]

rem --- Inits

	pgmdir$=""
	pgmdir$=stbl("+DIR_PGM")

rem --- is AP installed?  If not, disable vendor fields

	call pgmdir$ + "adc_application.aon", "AP", info$[all]
	ap_installed = (info$[20] = "Y")

	if !ap_installed then
		callpoint!.setColumnEnabled("IVR_PRICECHGPCT.VENDOR_ID_1", -1)
		callpoint!.setColumnEnabled("IVR_PRICECHGPCT.VENDOR_ID_2", -1)
	endif

[[IVR_PRICECHGPCT.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[IVR_PRICECHGPCT.ITEM_ID.AVAL]]
rem --- Can't change price for non-priced kits, which is the sum of the price of its components
	item_id$=callpoint!.getUserInput()
	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
	findrecord(ivm01_dev,key=firm_id$+item_id$,dom=*next)ivm01a$
	if ivm01a.kit$="Y" then
		msg_id$="IV_KIT_PRICE_CHNG"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

[[IVR_PRICECHGPCT.PERCENT_CHANGE.AVAL]]
rem --- Percent can't be zero

	if num( callpoint!.getUserInput() ) = 0 then
		callpoint!.setStatus("ABORT")
	endif

[[IVR_PRICECHGPCT.PRODUCT_TYPE.AVAL]]
rem --- Don't allow inactive code
	ivcProdCode_dev=fnget_dev("IVC_PRODCODE")
	dim ivcProdCode$:fnget_tpl$("IVC_PRODCODE")
	prod_code$=callpoint!.getUserInput()
	read record (ivcProdCode_dev,key=firm_id$+"A"+prod_code$,dom=*next)ivcProdCode$
	if ivcProdCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcProdCode.product_type$,3)
		msg_tokens$[2]=cvs(ivcProdCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



