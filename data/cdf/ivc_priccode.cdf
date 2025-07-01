[[IVC_PRICCODE.ADIS]]
rem --- Enable/disable break_disc_nn and break_amt_nn fields base on pricing_basis
	for x=0 to 10
		if callpoint!.getColumnData("IVC_PRICCODE.PRICING_BASIS")="P" then
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_DISC_"+str(x,"00"),1)
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_AMT_"+str(x,"00"),0)
		else
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_DISC_"+str(x,"00"),0)
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_AMT_"+str(x,"00"),1)
		endif
	next x

[[IVC_PRICCODE.AREC]]
rem --- Default pricing_basis is P, so disable break_amt_nn fields
	for x=0 to 10
		callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_AMT_"+str(x,"00"),0)
	next x

[[IVC_PRICCODE.BSHO]]
num_files=4
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="ARS_PARAMS",open_opts$[1]="OTA"
open_tables$[2]="IVS_PARAMS",open_opts$[2]="OTA"
open_tables$[3]="IVC_CLASCODE",open_opts$[3]="OTA"
open_tables$[4]="OPC_PRICECDS",open_opts$[4]="OTA"
gosub open_tables
ars_params_chn=num(open_chans$[1]),ars_params_tpl$=open_tpls$[1]
ivs_params_chn=num(open_chans$[2]),ivs_params_tpl$=open_tpls$[2]

rem --- check to see if main AR param rec (firm/AR/00) exists; if not, tell user to set it up first
	dim ars01a$:ars_params_tpl$
	ars01a_key$=firm_id$+"AR00"
	find record (ars_params_chn,key=ars01a_key$,err=*next) ars01a$
	if cvs(ars01a.current_per$,2)=""
		msg_id$="AR_PARAM_ERR"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		gosub remove_process_bar
		release
	endif

rem --- check to see if main IV param rec (firm/IV/00) exists; if not, tell user to set it up first
	dim ivs01a$:ivs_params_tpl$
	ivs01a_key$=firm_id$+"IV00"
	find record (ivs_params_chn,key=ivs01a_key$,err=*next) ivs01a$
	if cvs(ivs01a.warehouse_id$,2)=""
		msg_id$="IV_PARAM_ERR"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		gosub remove_process_bar
		release
	endif
	precision num(ivs01a.precision$)

[[IVC_PRICCODE.BWRI]]
rem --- compress zeroes
for x=1 to 9
	qty_var$="BREAK_QTY_"+str(x:"00")
	qty_var1$="BREAK_QTY_"+str(x+1:"00")
	disc_var$="BREAK_DISC_"+str(x:"00")
	disc_var1$="BREAK_DISC_"+str(x+1:"00")
	amt_var$="BREAK_AMT_"+str(x:"00")
	amt_var1$="BREAK_AMT_"+str(x+1:"00")
	if num(field(rec_data$,qty_var$))=0
		field rec_data$,qty_var$=field(rec_data$,qty_var1$)
		field rec_data$,qty_var1$="0"
		field rec_data$,disc_var$=field(rec_data$,disc_var1$)
		field rec_data$,disc_var1$="0"
		field rec_data$,amt_var$=field(rec_data$,amt_var1$)
		field rec_data$,amt_var1$="0"
	endif
next x
callpoint!.setStatus("REFRESH")

rem --- make sure each qty > previous one
ok$="Y"
for x=2 to 10
	wkvar$="BREAK_QTY_"+str(x:"00")
	wkvar1$="BREAK_QTY_"+str(x-1:"00")

	if num(field(rec_data$,wkvar$))<=num(field(rec_data$,wkvar1$)) and
:		num(field(rec_data$,wkvar$))<>0 and
:		num(field(rec_data$,wkvar1$))<>0
		ok$="N"
	endif
next x

if ok$="N"
	msg_id$="IV_QTYERR"
	gosub disp_message
	callpoint!.setStatus("ABORT-REFRESH")
endif

rem --- make sure Margin over Cost margins don't exceed 100
	if callpoint!.getColumnData("IVC_PRICCODE.IV_PRICE_MTH")="M"
		gosub validate_margin
	endif

if ok$="N"
	callpoint!.setStatus("ABORT-REFRESH")
endif
	

[[IVC_PRICCODE.ITEM_CLASS.AVAL]]
rem --- Don't allow inactive code
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

[[IVC_PRICCODE.PRICING_BASIS.AVAL]]
rem --- Enable/disable break_disc_nn and break_amt_nn fields base on pricing_basis
	for x=0 to 10
		if callpoint!.getColumnData("IVC_PRICCODE.PRICING_BASIS")="P" then
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_DISC_"+str(x,"00"),1)
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_AMT_"+str(x,"00"),0)
		else
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_DISC_"+str(x,"00"),0)
			callpoint!.setColumnEnabled("IVC_PRICCODE.BREAK_AMT_"+str(x,"00"),1)
		endif
	next x

[[IVC_PRICCODE.PRICING_CODE.AVAL]]
rem --- Don't allow inactive code
	opcPiceCDs_dev=fnget_dev("OPC_PRICECDS")
	dim opcPiceCDs$:fnget_tpl$("OPC_PRICECDS")
	pricing_code$=callpoint!.getUserInput()
	read record(opcPiceCDs_dev,key=firm_id$+pricing_code$,dom=*next)opcPiceCDs$
	if opcPiceCDs.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcPiceCDs.pricing_code$,3)
		msg_tokens$[2]=cvs(opcPiceCDs.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVC_PRICCODE.<CUSTOM>]]
validate_margin:
	ok$="Y"
	if callpoint!.getColumnData("IVC_PRICCODE.IV_PRICE_MTH")="M"
		for x=1 to 10
			disc_var$="BREAK_DISC_"+str(x:"00")
			if num(field(rec_data$,disc_var$))>=100
				msg_id$="IV_BADMARGIN"
				gosub disp_message
				ok$="N"
			endif
		next x
	endif
return

remove_process_bar: rem -- remove process bar
	bbjAPI!=bbjAPI()
	rdFuncSpace!=bbjAPI!.getGroupNamespace()
	rdFuncSpace!.setValue("+build_task","OFF")
return

#include [+ADDON_LIB]std_missing_params.aon



