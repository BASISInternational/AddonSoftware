[[OPC_TAXCODE.ADIS]]
rem --- Enable G/L Account"
	if user_tpl.gl$="Y" then
		if num(callpoint!.getColumnData("OPC_TAXCODE.TAX_RATE"))<>0 
			enableit$=""
		else
			enableit$="I"
		endif
		gosub able_gl
	endif

[[OPC_TAXCODE.ARAR]]
rem --- Calculate and display all the extra tax codes
	if user_tpl.gl$<>"Y" then
		enableit$="I"
	else
		if num(callpoint!.getColumnData("OPC_TAXCODE.USE_TAX_SERVICE")) then
			enableit$=""
		else
			if rec_data.tax_rate=0 then
				enableit$="I"
			else
				enableit$=""
			endif
		endif
	endif
	gosub able_gl
	opm06_dev=user_tpl.opm06_dev
	dim opm06a$:user_tpl.opm06_tpl$
	callpoint!.setColumnData("<<DISPLAY>>.TAX_TOTAL","0")
	total_pct=num(rec_data.tax_rate$)
	for x=1 to 10
		dim opm06a$:fattr(opm06a$)
		next_code$=field(rec_data$,"AR_TOT_CODE_"+str(x:"00"))
		if cvs(next_code$,2)<>""
			read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
			callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_"+str(x:"00"),opm06a.tax_rate$)
			callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_"+str(x:"00"),opm06a.code_desc$)
			total_pct=total_pct+num(opm06a.tax_rate$)
			field user_tpl$,"code",[x]=next_code$
			field user_tpl$,"rate",[x]=num(opm06a.tax_rate$)
		else
			callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_"+str(x:"00"),"")
			callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_"+str(x:"00"),"")
			field user_tpl$,"rate",[x]=0
		endif
	next x
	field user_tpl$,"this_rate"=rec_data.tax_rate
	field user_tpl$,"this_code"=rec_data.op_tax_code$
	callpoint!.setColumnData("<<DISPLAY>>.TAX_TOTAL",str(total_pct))
	callpoint!.setStatus("REFRESH-ABLEMAP")

[[OPC_TAXCODE.AR_TOT_CODE_01.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=1
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[1]=callpoint!.getUserInput()
		field user_tpl$,"rate",[1]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_01",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_01",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_01","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_02.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=2
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[2]=callpoint!.getUserInput()
		field user_tpl$,"rate",[2]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_02",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_02",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_02","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_03.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=3
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[3]=callpoint!.getUserInput()
		field user_tpl$,"rate",[3]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_03",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_03",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_03","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_04.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=4
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[4]=callpoint!.getUserInput()
		field user_tpl$,"rate",[4]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_04",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_04",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_04","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_05.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=5
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[5]=callpoint!.getUserInput()
		field user_tpl$,"rate",[5]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_05",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_05",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_05","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_06.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=6
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[6]=callpoint!.getUserInput()
		field user_tpl$,"rate",[6]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_06",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_06",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_06","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_07.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=7
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[7]=callpoint!.getUserInput()
		field user_tpl$,"rate",[7]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_07",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_07",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_07","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_08.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=8
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[8]=callpoint!.getUserInput()
		field user_tpl$,"rate",[8]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_08",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_08",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_08","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_09.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=9
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[9]=callpoint!.getUserInput()
		field user_tpl$,"rate",[9]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_09",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_09",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_09","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.AR_TOT_CODE_10.AVAL]]
rem --- Don't allow inactive code
	opcTaxCode_dev=fnget_dev("OPC_TAXCODE")
	dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
	ar_tot_code$=callpoint!.getUserInput()
	read record(opcTaxCode_dev,key=firm_id$+ar_tot_code$,dom=*next)opcTaxCode$
	if opcTaxCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcTaxCode.op_tax_code$,3)
		msg_tokens$[2]=cvs(opcTaxCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put new rate into array and calc total
	cur_fld=10
	gosub check_code
	if ok$="Y"
		opm06_dev=user_tpl.opm06_dev
		dim opm06a$:user_tpl.opm06_tpl$
		next_code$=callpoint!.getUserInput()
		read record (opm06_dev,key=firm_id$+next_code$,dom=*next) opm06a$
		field user_tpl$,"code",[10]=callpoint!.getUserInput()
		field user_tpl$,"rate",[10]=opm06a.tax_rate
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_10",opm06a.code_desc$)
		callpoint!.setColumnData("<<DISPLAY>>.TAX_RATE_10",opm06a.tax_rate$)
		gosub calc_total
	else
		callpoint!.setUserInput("")
		callpoint!.setColumnData("<<DISPLAY>>.TAX_DESC_10","")
		callpoint!.setStatus("REFRESH")
	endif

[[OPC_TAXCODE.BDEL]]
rem --- When deleting the Tax Code, warn if there are any current/active transactions for the code, and disallow if there are any.
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
		callpoint!.setColumnData("OPC_TAXCODE.CODE_INACTIVE","Y",1)
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
	if ars_rec.tax_code$ = callpoint!.getColumnData("OPC_TAXCODE.OP_TAX_CODE") then
		callpoint!.setMessage("OP_TAX_CODE_IN_DFLT")
		callpoint!.setStatus("ABORT")
	endif

[[OPC_TAXCODE.BREC]]
rem --- clear out temporary rates
	for x=1 to 10
		field user_tpl$,"code",[x]=""
		field user_tpl$,"rate",[x]=0
	next x
	field user_tpl$,"this_rate"=0
	field user_tpl$,"this_code"=""

[[OPC_TAXCODE.BSHO]]
rem --- Open/Lock files
	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="OPC_TAXCODE",open_opts$[1]="OTA"
	open_tables$[2]="OPS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="ARM_CUSTDET",open_opts$[3]="OTA"
	open_tables$[4]="ARM_CUSTSHIP",open_opts$[4]="OTA"
	open_tables$[5]="ARS_CUSTDFLT",open_opts$[5]="OTA"
	open_tables$[6]="OPT_INVHDR",open_opts$[6]="OTA"

	gosub open_tables

	ops_params_dev=num(open_chans$[2])
	dim ops_params$:open_tpls$[2]

rem --- Keep info in user_tpl$
	dim user_tpl$:"opm06_dev:n(4),opm06_tpl:c(500),this_rate:n(10),code[10]:c(10),rate[10]:n(10),this_code:c(10),gl:C(1),gl_installed:c(1)"
	user_tpl.opm06_dev=num(open_chans$[1])
	user_tpl.opm06_tpl$=open_tpls$[1]
	call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
	user_tpl.gl$=info$[9]
	if info$[9]<>"Y"
		enableit$="I"
		gosub able_gl
	endif
	call stbl("+DIR_PGM")+"adc_application.aon","GL",info$[all]
	user_tpl.gl_installed$=info$[20]

rem --- Get OP Parametes
	find record (ops_params_dev,key=firm_id$+"AR00",err=std_missing_params)ops_params$
	callpoint!.setDevObject("sls_tax_intrface",cvs(ops_params.sls_tax_intrface$,2))

[[OPC_TAXCODE.CODE_INACTIVE.AVAL]]
rem --- When deactivating the Tax Code, warn if there are any current/active transactions for the code, and disallow if there are any.
	current_inactive$=callpoint!.getUserInput()
	prior_inactive$=callpoint!.getColumnData("OPC_TAXCODE.CODE_INACTIVE")
	if current_inactive$="Y" and prior_inactive$<>"Y" then
		gosub check_active_code
		if found then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPC_TAXCODE.GL_ACCOUNT.AVAL]]
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*break) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE-ABORT")
   endif

[[OPC_TAXCODE.GL_ACCOUNT.BINP]]
if user_tpl.gl_installed$="Y"
	callpoint!.setTableColumnAttribute("OPC_TAXCODE.GL_ACCOUNT","MINL","1")
endif

[[OPC_TAXCODE.OP_TAX_CODE.AVAL]]
rem --- Don't allow add of blank code
while 1
	code$=callpoint!.getUserInput()
	if cvs(code$,2)=""
		find (user_tpl.opm06_dev,key=firm_id$+code$,dom=*next);break
		callpoint!.setMessage("INVALID_ENTRY")
		callpoint!.setStatus("ABORT")
	endif
	break
wend

[[OPC_TAXCODE.TAX_RATE.AVAL]]
rem --- Enable/Disable G/L Account"
	if user_tpl.gl$<>"Y" then
		enableit$="I"
	else
		if num(callpoint!.getColumnData("OPC_TAXCODE.USE_TAX_SERVICE")) then
			enableit$=""
		else
			if num(callpoint!.getUserInput())=0 then
				enableit$="I"
			else
				enableit$=""
			endif
		endif
	endif
	gosub able_gl

	user_tpl.this_rate=num(callpoint!.getUserInput())
	gosub calc_total

[[OPC_TAXCODE.USE_TAX_SERVICE.AVAL]]
rem --- Restrict changing USE_TAX_SVC if there are open orders or open invoices
	useTaxService$=callpoint!.getUserInput()
	priorUseTaxService$=callpoint!.getColumnData("OPC_TAXCODE.USE_TAX_SERVICE")
	if useTaxService$<>priorUseTaxService$ then

		sql$ = "SELECT COUNT(*) AS COUNT "
		sql$ = sql$ + "FROM OPT_INVHDR "
		sql$ = sql$ + "WHERE FIRM_ID = '" + firm_id$ + "' and TRANS_STATUS IN ('E','R') and INVOICE_TYPE<>'V'"

		sql_chan=sqlunt
		sqlopen(sql_chan)stbl("+DBNAME")
		sqlprep(sql_chan)sql$
		dim read_tpl$:sqltmpl(sql_chan)
		sqlexec(sql_chan)

		read_tpl$ = sqlfetch(sql_chan,err=*continue)
		count=read_tpl$.count
		sqlclose(sql_chan)

		if count then
			msg_id$="OP_CANNOT_CHG_STS"
			dim msg_tokens$[2]
			msg_tokens$[1]=Translate!.getTranslation("AON_USE_SLS_TAX_SVC")
			msg_tokens$[2]=str(count)
			gosub disp_message

			callpoint!.setColumnData("OPC_TAXCODE.USE_TAX_SERVICE",priorUseTaxService$,1)
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[OPC_TAXCODE.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon

#include [+ADDON_LIB]std_missing_params.aon

able_gl: rem --- enable/disable selected control
	wctl$=str(num(callpoint!.getTableColumnAttribute("OPC_TAXCODE.GL_ACCOUNT","CTLI")):"00000")
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)=enableit$
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP")
return

calc_total: rem Calculate Total Tax rate
	total_pct=user_tpl.this_rate
	for x=1 to 10
		total_pct=total_pct+nfield(user_tpl$,"rate",x)
	next x
	callpoint!.setColumnData("<<DISPLAY>>.TAX_TOTAL",str(total_pct))
	callpoint!.setStatus("REFRESH")
return

check_code: rem --- Check code
	ok$="Y"
	if cvs(callpoint!.getUserInput(),2)=cvs(user_tpl.this_code$,2) and
:		cvs(callpoint!.getUserInput(),2)<>""
		msg_id$="OP_SUBTAX_DUPE"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		ok$="N"
	endif
	for taxcode=1 to 10
		if taxcode<>cur_fld
			if cvs(callpoint!.getUserInput(),2)=cvs(field(user_tpl$,"code",taxcode),3) and
:				cvs(callpoint!.getUserInput(),2)<>""
				msg_id$="OP_TOTCODE_DUPE"
				gosub disp_message
				callpoint!.setStatus("ABORT")
				ok$="N"
			endif
		endif
	next taxcode
return

rem ==========================================================================
check_active_code: rem --- Warn if there are any current/active transactions for the code
rem ==========================================================================
	found=0
	op_tax_code$=callpoint!.getColumnData("OPC_TAXCODE.OP_TAX_CODE")

	checkTables!=BBjAPI().makeVector()
	checkTables!.addItem("ARM_CUSTDET")
	checkTables!.addItem("ARM_CUSTSHIP")
	checkTables!.addItem("ARS_CUSTDFLT")
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
			if table_tpl.tax_code$=op_tax_code$ then
				msg_id$="AD_CODE_IN_USE"
				dim msg_tokens$[2]
				msg_tokens$[1]=Translate!.getTranslation("DDM_ELEMENTS-OP_TAX_CODE-DD_ATTR_LABL")
				switch (BBjAPI().TRUE)
                				case thisTable$="ARM_CUSTDET"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTDET-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARM_CUSTSHIP"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARM_CUSTSHIP-DD_ATTR_WINT")
                    				break
                				case thisTable$="ARS_CUSTDFLT"
                   				msg_tokens$[2]=Translate!.getTranslation("DDM_TABLES-ARS_CUSTDFLT-DD_ATTR_WINT")
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

	rem --- Check if this Tax Code is being used in another Tax Code
	if !found then
		opcTaxCode_dev = fnget_dev("OPC_TAXCODE")
		dim opcTaxCode$:fnget_tpl$("OPC_TAXCODE")
		read(opcTaxCode_dev,key=firm_id$,dom=*next)
		while 1
			readrecord(opcTaxCode_dev,end=*break)opcTaxCode$
			if opcTaxCode.firm_id$<>firm_id$ then break
			for x=1 to 10
				next_code$=field(opcTaxCode$,"AR_TOT_CODE_"+str(x:"00"))
				if next_code$=op_tax_code$ then
					msg_id$="AD_CODE_IN_USE"
					dim msg_tokens$[2]
					msg_tokens$[1]=Translate!.getTranslation("DDM_ELEMENTS-OP_TAX_CODE-DD_ATTR_LABL")
					msg_tokens$[2]=Translate!.getTranslation("DDM_ELEMENTS-OP_TAX_CODE-DD_ATTR_LABL")+" "+cvs(opcTaxCode.op_tax_code$,2)
					gosub disp_message

					found=1
					break
				endif
			next x
			if found then break
		wend
	endif

	if found then
		rem --- Uncheck the CODE_INACTIVE checkbox
		callpoint!.setColumnData("OPC_TAXCODE.CODE_INACTIVE","N",1)
	endif

return



