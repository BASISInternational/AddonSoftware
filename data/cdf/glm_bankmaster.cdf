[[GLM_BANKMASTER.ADTW]]
rem " --- Recalc Summary Info

	gosub calc_totals

[[GLM_BANKMASTER.AOPT-DETL]]
rem " --- Recalc Summary Info

	gosub calc_totals

	gl_account$=callpoint!.getColumnData("GLM_BANKMASTER.GL_ACCOUNT")
	call stbl("+DIR_PGM")+"glr_bankmaster.aon",gl_account$

[[GLM_BANKMASTER.AOPT-POST]]
rem --- Check Statement Date and Amount

	pri_date$=callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_DATE")
	cur_date$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
	amt=num(callpoint!.getColumnData("GLM_BANKMASTER.CUR_STMT_AMT"))

	dim msg_tokens$[0]
	msg_opt$=""
	if cur_date$<pri_date$
		msg_id$="GL_BANK_PRIDATE"
		gosub disp_message
		if msg_opt$="N"
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

	dim msg_tokens$[0]
	msg_opt$=""
	if amt<=0
		msg_id$="GL_BANK_NEGBAL"
		gosub disp_message
		if msg_opt$="N"
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem " --- Recalc Summary Info

	gosub calc_totals

	balanced$="Y"
	if over_under$<>"" 
		call stbl("+DIR_PGM")+"adc_getmask.aon","","GL","A","",m1$,0,0
		balanced$="N"
		msg_id$="BANK_OOB"
		dim msg_tokens$[2]
		msg_tokens$[1]=over_under$
		msg_tokens$[2]=str(abs(num(callpoint!.getColumnData("GLM_BANKMASTER.BOOK_BALANCE"))-end_bal):m1$)
		msg_opt$=""
		gosub disp_message
	endif

rem " --- See if they want to print
	
	msg_id$="PRINT_TRANS"
	dim msg_tokens$[1]
	msg_opt$=""
	gosub disp_message
	if msg_opt$="Y"
		gl_account$=callpoint!.getColumnData("GLM_BANKMASTER.GL_ACCOUNT")
		call stbl("+DIR_PGM")+"glr_bankmaster.aon",gl_account$
	endif

rem --- If balanced, see if they want to remove paid transactions

	if balanced$="Y"
		msg_id$="REMOVE_PAID"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		if msg_opt$="Y"
rem --- Remove Paid Checks
			read (glt05_dev,key=firm_id$+gl_acct$,dom=*next)
			while 1
				dim glt05a$:user_tpl.glt05_tpl$
				readrecord (glt05_dev,end=*break)glt05a$
				if glt05a.firm_id$<>firm_id$ break
				if glt05a.gl_account$<>gl_acct$ break
				if glt05a.paid_code$<>"P" and glt05a.paid_code$<>"V" continue
				if glt05a.bnk_chk_date$>st_date$ continue
				remove (glt05_dev,key=glt05a.firm_id$+glt05a.gl_account$+glt05a.bnk_acct_cd$+glt05a.check_no$,dom=*next)
			wend

rem --- Remove Paid Transactions
			read (glt15_DEV,key=firm_id$+gl_acct$,dom=*next)
			while 1
				dim glt15a$:user_tpl.glt15_tpl$
				readrecord (glt15_dev,end=*break)glt15a$
				if glt15a.firm_id$<>firm_id$ break
				if glt15a.gl_account$<>gl_acct$ break
				if glt15a.posted_code$<>"P" and glt15a.posted_code$<>"V" continue
				if glt15a.trns_date$>st_date$ continue
				remove (glt15_dev,key=glt15a.firm_id$+glt15a.gl_account$+glt15a.trans_no$,dom=*next)
			wend
		endif

		rem --- poll the statement date and amount
		callpoint!.setColumnData("GLM_BANKMASTER.PRI_END_DATE",callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE"))
		callpoint!.setColumnData("GLM_BANKMASTER.CURSTM_DATE","")
		callpoint!.setColumnData("GLM_BANKMASTER.PRI_END_AMT",callpoint!.getColumnData("GLM_BANKMASTER.CUR_STMT_AMT"))
		callpoint!.setColumnData("GLM_BANKMASTER.CUR_STMT_AMT","0")
		callpoint!.setColumnData("GLM_BANKMASTER.BOOK_BALANCE","0")
		rec_data.pri_end_date$=callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_DATE")
		rec_data.curstm_date$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
		rec_data.pri_end_amt$=callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_AMT")
		rec_data.cur_stmt_amt$=callpoint!.getColumnData("GLM_BANKMASTER.CUR_STMT_AMT")
		rec_data.book_balance$=callpoint!.getColumnData("GLM_BANKMASTER.BOOK_BALANCE")
		writerecord(fnget_dev("GLM_BANKMASTER"))rec_data$
		glm05_key$=rec_data.firm_id$+rec_data.gl_account$
		extractrecord(fnget_dev("GLM_BANKMASTER"),key=glm05_key$)x$; rem Advisory Locking

	endif

[[GLM_BANKMASTER.AOPT-RECL]]
rem --- Validate Current Statement Date
	stmtdate$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
	if num(stmtdate$)=0
		msg_id$="INVALID_DATE"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		break
	endif

rem --- get the Prior Statement Date
	priordate$=callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_DATE")

rem --- Initialize displayColumns! object
	if displayColumns!=null() then
		use ::glo_DisplayColumns.aon::DisplayColumns
		displayColumns!=new DisplayColumns(firm_id$)
	endif

rem --- Find G/L Record"
	dim glm02a$:user_tpl.glm02_tpl$
	dim glt06a$:user_tpl.glt06_tpl$
	dim gls01a$:user_tpl.gls01_tpl$
	glm02_dev=user_tpl.glm02_dev
	glt06_dev=user_tpl.glt06_dev
	gls01_dev=user_tpl.gls01_dev
	readrecord(gls01_dev,key=firm_id$+"GL00")gls01a$
	gosub check_date
	if status then
		callpoint!.setStatus("ABORT")
		break
	endif

	r0$=firm_id$+callpoint!.getColumnData("GLM_BANKMASTER.GL_ACCOUNT"),s0$=""
	if stmtyear=priorgl s0$=r0$+displayColumns!.getYear("2"); rem "Use prior year actual
	if stmtyear=currentgl s0$=r0$+displayColumns!.getYear("0"); rem "Use current year actual
	if stmtyear=nextgl s0$=r0$+displayColumns!.getYear("4"); rem "Use next year actual
	if s0$="" 
		msg_id$="INVALID_DATE"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		exit; rem "Invalid statement year
	endif
	read record (glm02_dev,key=s0$,dom=*next) glm02a$

rem --- Calculate Balance"
	total_amt=glm02a.begin_amt,total_units=glm02a.begin_units
	for x=1 to stmtperiod
		total_amt=total_amt+nfield(glm02a$,"period_amt_"+str(x:"00"))
		total_units=total_units+nfield(glm02a$,"period_units_"+str(x:"00"))
	next x
	call stbl("+DIR_PGM")+"adc_daydates.aon",stmtdate$,nextday$,1
	d0$=r0$+stmtyear$+stmtperiod$+nextday$,amount=0
	readrecord (glt06_dev,key=d0$,dom=*next)

rem --- Accumulate transactions for period after statement date"
	while 1
		k$=key(glt06_dev,END=*break)
		if pos(r0$=k$)<>1 break
		if k$(13,6)<>stmtyear$+stmtperiod$ break
		dim glt06a$:fattr(glt06a$)
		read record (glt06_dev,key=k$)glt06a$
		amount=amount+glt06a.trans_amt
	wend

rem --- Back out transactions for period after statement date"
	total_amt=total_amt-amount

rem --- All Done"
	callpoint!.setColumnData("GLM_BANKMASTER.BOOK_BALANCE",str(total_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.BOOK_BAL",str(total_amt),1)
	callpoint!.setStatus("SAVE")

rem " --- Recalc Summary Info

	gosub calc_totals

[[GLM_BANKMASTER.AOPT-TRAN]]
rem --- Pass current statement date to check detail and deposits/other transaction grids
	stmtdate$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
	rdFuncSpace!=BBjAPI().getGroupNamespace()
	rdFuncSpace!.setValue(stbl("+USER_ID")+": BANKMASTER stmtdate",stmtdate$)

rem --- Set arguments to SCALL bax_launch_task.bbj
	bar_dir$=(new java.io.File(dir(""))).getCanonicalPath()
	run_arg$="bbj -tT0 -q -WD"+$22$+bar_dir$+$22$
:		+" -c"+$22$+bar_dir$+"/sys/config/enu/barista.cfg"+$22$
:		+" "+$22$+bar_dir$+"/sys/prog/bax_launch_task.bbj"+$22$

rem --- Launch Check Detail grid
	rdAdmin!=rdFuncSpace!.getValue("+bar_admin_"+cvs(stbl("+USER_ID",err=*next),11),err=*next)
	user_arg$=" - "
:		+" -u"+rdAdmin!.getUser()
:		+" -p"+rdAdmin!.getPassword()
:		+" -y"+"T"
:		+" -t"+"GLT_BANKCHECKS"
:		+" -w"

	scall_result=scall(run_arg$+user_arg$+" &",err=*next)

rem --- Launch Deposits/Other Transactions grid
	user_arg$=" - "
:		+" -u"+rdAdmin!.getUser()
:		+" -p"+rdAdmin!.getPassword()
:		+" -y"+"T"
:		+" -t"+"GLT_BANKOTHER"
:		+" -w"

	scall_result=scall(run_arg$+user_arg$+" &",err=*next)

rem --- Wait for both grids to exit so amounts on Statement Information tab can be updated
	wait(5)
	gridInUse$="In Use"
	while cvs(gridInUse$,2)<>""
		wait(2)
		gridInUse$=""
		gridInUse$=rdFuncSpace!.getValue(stbl("+USER_ID")+": GLT_BANKCHECKS",err=*next)
		gridInUse$=rdFuncSpace!.getValue(stbl("+USER_ID")+": GLT_BANKOTHER",err=*next)
	wend
	gosub calc_totals

rem --- Remove stmtdate from GroupNamespace after the grids have launched
	rdFuncSpace!.removeValue(stbl("+USER_ID")+": BANKMASTER stmtdate")

[[GLM_BANKMASTER.ARAR]]
rem --- Display Bank Account Information
	bnk_acct_cd$=callpoint!.getColumnData("GLM_BANKMASTER.BNK_ACCT_CD")
	gosub displayBankInfo

rem --- Calculate Summary info
  	gosub calc_totals

rem --- Disable prior statement date/amt (will enable if there is no prior info so user can enter it)
	callpoint!.setColumnEnabled("GLM_BANKMASTER.PRI_END_DATE",0)
	callpoint!.setColumnEnabled("GLM_BANKMASTER.PRI_END_AMT",0)

[[GLM_BANKMASTER.ASHO]]
rem --- Warn if same Bank Account Code used for multiple GL Accounts
	bnkAcctMap!= new HashMap()
   	glm05_dev=fnget_dev("GLM_BANKMASTER")
   	dim glm05_tpl$:fnget_tpl$("GLM_BANKMASTER")
	read(glm05_dev,key=firm_id$,dom=*next)
	while 1
		readrecord(glm05_dev,end=*break)glm05_tpl$
		if glm05_tpl.firm_id$<>firm_id$ then break
		if bnkAcctMap!.containsKey(glm05_tpl.bnk_acct_cd$)
			glAcctVect!=bnkAcctMap!.get(glm05_tpl.bnk_acct_cd$)
		else
			glAcctVect!=BBjAPI().makeVector()
		endif
		glAcctVect!.addItem(glm05_tpl.gl_account$)
		bnkAcctMap!.put(glm05_tpl.bnk_acct_cd$,glAcctVect!)
	wend

	call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
	bnkAcctIter!=bnkAcctMap!.keySet().iterator()
	while bnkAcctIter!.hasNext()
		thisBnkAcct!=bnkAcctIter!.next()
		glAcctVect!=bnkAcctMap!.get(thisBnkAcct!)
		if glAcctVect!.size()>1 then
			glAccts$=""
			for i=0 to glAcctVect!.size()-1
				if i>0 then glAccts$=glAccts$+"; "
				thisGlAcct$=glAcctVect!.getItem(i)
				glAccts$=glAccts$+fnmask$(thisGlAcct$(1,gl_size),m0$)
			next i
			msg_id$="GL_BNKACCT_WARN"
			dim msg_tokens$[2]
			msg_tokens$[1]=thisBnkAcct!
			msg_tokens$[2]=glAccts$
			gosub disp_message
		endif
	wend

[[GLM_BANKMASTER.BDTW]]
rem --- Pass current statement date to check detail and other transaction listings
	stmtdate$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
	callpoint!.setDevObject("stmtdate",stmtdate$)

[[GLM_BANKMASTER.BNK_ACCT_CD.AVAL]]
rem --- Do NOT allow the same Bank Account Code for multiple GL Accounts
	bnk_acct_cd$=callpoint!.getUserInput()
	gl_account$=callpoint!.getColumnData("GLM_BANKMASTER.GL_ACCOUNT")
   	glm05_dev=fnget_dev("GLM_BANKMASTER")
   	dim glm05_tpl$:fnget_tpl$("GLM_BANKMASTER")

	other_glAcct$=""
	read(glm05_dev,key=firm_id$,dom=*next)
	while 1
		readrecord(glm05_dev,end=*break)glm05_tpl$
		if glm05_tpl.firm_id$<>firm_id$ then break
		if glm05_tpl.bnk_acct_cd$=bnk_acct_cd$ and glm05_tpl.gl_account$<>gl_account$ then
			other_glAcct$=glm05_tpl.gl_account$
			break
		endif
	wend
	if other_glAcct$<>"" then
		call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
		msg_id$="GL_BNKACCT_USED"
		dim msg_tokens$[2]
		msg_tokens$[1]=bnk_acct_cd$
		msg_tokens$[2]=fnmask$(other_glAcct$(1,gl_size),m0$)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Display Bank Account Information
	gosub displayBankInfo

[[GLM_BANKMASTER.BSHO]]
rem --- Inits
	use java.util.HashMap
	rem --- Encryptor for bank acct #
	use ::sys/prog/bao_encryptor.bbj::Encryptor; rem --- Encryptor for bank acct #

rem --- Open/Lock files
	dir_pgm$=stbl("+DIR_PGM")
	sys_pgm$=stbl("+DIR_SYP")

	num_files=6
	dim files$[num_files],options$[num_files],ids$[num_files],templates$[num_files],channels[num_files]
	files$[1]="gls_params",ids$[1]="GLS_PARAMS",options$[1]="OTA"
	files$[2]="glt-06",ids$[2]="GLT_TRANSDETAIL",options$[2]="OTA"; rem ars-10D
	files$[3]="glm-02",ids$[3]="GLM_ACCTSUMMARY",options$[3]="OTA"
	files$[4]="glt-05",ids$[4]="GLT_BANKCHECKS",options$[4]="OTA"
	files$[5]="glt-15",ids$[5]="GLT_BANKOTHER",options$[5]="OTA"
	files$[6]="adc_bankacctcode",ids$[6]="ADC_BANKACCTCODE",options$[6]="OTA"
	call stbl("+DIR_PGM")+"adc_fileopen.aon",action,1,num_files,files$[all],options$[all],
:                              ids$[all],templates$[all],channels[all],batch,status
	if status then
		remove_process_bar:
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
	 	release
	endif

	gls01_dev=channels[1]
	glt06_dev=channels[2]
	glm02_dev=channels[3]
	glt05_dev=channels[4]
	glt15_dev=channels[5]

rem --- Set up user_tpl$

	dim user_tpl$:"gls01_tpl:c(2048),glt06_tpl:c(1024),glm02_tpl:c(1024),glt05_tpl:c(1024),glt15_tpl:c(1024),"+
:	"gls01_dev:n(4),glt06_dev:n(4),glm02_dev:n(4),glt05_dev:n(4),glt15_dev:n(4)"

	user_tpl.gls01_tpl$=templates$[1]
	user_tpl.glt06_tpl$=templates$[2]
	user_tpl.glm02_tpl$=templates$[3]
	user_tpl.glt05_tpl$=templates$[4]
	user_tpl.glt15_tpl$=templates$[5]
	user_tpl.gls01_dev=gls01_dev
	user_tpl.glt06_dev=glt06_dev
	user_tpl.glm02_dev=glm02_dev
	user_tpl.glt05_dev=glt05_dev
	user_tpl.glt15_dev=glt15_dev

rem - Set up disabled controls

	dim dctl$[18]
	dctl$[1]="<<DISPLAY>>.BANK_NAME"
	dctl$[2]="<<DISPLAY>>.ADDRESS_LINE_1"
	dctl$[3]="<<DISPLAY>>.ADDRESS_LINE_2"
	dctl$[4]="<<DISPLAY>>.ADDRESS_LINE_3"
	dctl$[5]="<<DISPLAY>>.ACCT_DESC"
	dctl$[6]="<<DISPLAY>>.BNK_ACCT_TYPE"
	dctl$[7]="<<DISPLAY>>.ABA_NO"
	dctl$[8]="<<DISPLAY>>.BNK_ACCT_NO"
	dctl$[9]="<<DISPLAY>>.STMT_AMT"
	dctl$[10]="<<DISPLAY>>.CHECKS_OUT"
	dctl$[11]="<<DISPLAY>>.TRANS_OUT"
	dctl$[12]="<<DISPLAY>>.END_BAL"
	dctl$[13]="<<DISPLAY>>.NO_CHECKS"
	dctl$[14]="<<DISPLAY>>.NO_TRANS"
	dctl$[15]="<<DISPLAY>>.BOOK_BAL"
	dctl$[16]="<<DISPLAY>>.DIFFERENCE"
	dctl$[17]="<<DISPLAY>>.CASH_IN"
	dctl$[18]="<<DISPLAY>>.CASH_OUT"
	gosub disable_ctls

rem --- Set up Encryptor
	encryptor! = new Encryptor()
	config_id$ = "BANK_ACCT_AUTH"
	encryptor!.setConfiguration(config_id$)
	callpoint!.setDevObject("encryptor",encryptor!)

[[GLM_BANKMASTER.CURSTM_DATE.AVAL]]
rem --- If there is no prior statement date/amount, enable and prompt user to enter them
	if cvs(callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_DATE"),3)=""
		callpoint!.setColumnEnabled("GLM_BANKMASTER.PRI_END_DATE",1)
		callpoint!.setColumnEnabled("GLM_BANKMASTER.PRI_END_AMT",1)
		callpoint!.setMessage("GL_NO_PRI_DATE")
		callpoint!.setFocus("GLM_BANKMASTER.PRI_END_DATE")
	endif

rem --- Current statement date must be after prior statement end date
	curstm_date$=callpoint!.getUserInput()
	pri_end_date$=callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_DATE")
	if cvs(pri_end_date$,2)<>"" and pri_end_date$>curstm_date$ then
		msg_id$="GL_BANK_PRIDATE"
		gosub disp_message
		if msg_opt$="N"
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Current statement date must be in prior, current or next fiscal year
	call stbl("+DIR_PGM")+"glc_ctlcreate.aon",pgm(-2),"GL","","",status
	call stbl("+DIR_PGM")+"glc_datecheck.aon",curstm_date$,"N",period$,year$,glstatus
	if glstatus=101 then
		dim msg_tokens$[1]
		msg_tokens$[1]=fndate$(curstm_date$)+" "+Translate!.getTranslation("AON_IS_NOT_IN_THE_PRIOR,_CURRENT_OR_NEXT_GL_YEAR.")
		call stbl("+DIR_SYP")+"bac_message.bbj","GENERIC_WARN",msg_tokens$[all],msg_opt$,table_chans$[all]
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Recalc Summary Info
	gosub calc_totals

[[GLM_BANKMASTER.CUR_STMT_AMT.AVAL]]
rem " --- Recalc Summary Info

	gosub calc_totals

[[GLM_BANKMASTER.GL_ACCOUNT.AVAL]]
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
      callpoint!.setStatus("ACTIVATE")
   endif

[[<<DISPLAY>>.TEMP_TAB_STOP.BINP]]
rem --- "Hidden" field to allow enter/tab from single enabled field
rem --- Temporary workaround for Barista bug 6925

	callpoint!.setFocus("<<DISPLAY>>.BNK_ACCT_CD")
	callpoint!.setStatus("ABORT")
	break

[[GLM_BANKMASTER.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon
rem ====================================================
check_date: rem --- Check Statement Ending Date
rem ====================================================

	call stbl("+DIR_PGM")+"adc_fiscalperyr.aon",firm_id$,stmtdate$,stmtperiod$,stmtyear$,table_chans$[all],status
	if status then return

	stmtperiod=num(stmtperiod$)
	stmtperiod$=str(stmtperiod:"00")
	stmtyear=num(stmtyear$)
	if gls01a.gl_yr_closed$="Y" currentgl=num(gls01a.current_year$) else currentgl=num(gls01a.current_year$)-1; rem "GL year end closed?
	priorgl=currentgl-1
	nextgl=currentgl+1
	
	call stbl("+DIR_PGM")+"adc_fiscalperyr.aon",firm_id$,priordate$,priordateperiod$,priordateyear$,table_chans$[all],status
	if status then return

	priordateperiod=num(priordateperiod$)
	priordateperiod$=str(priordateperiod:"00")
	priordateyear=num(priordateyear$)
	if gls01a.gl_yr_closed$="Y" prior_currentgl=num(gls01a.current_year$) else prior_currentgl=num(gls01a.current_year$)-1; rem "GL year end closed?
	prior_priorgl=prior_currentgl-1
	prior_nextgl=prior_currentgl+1

	return

rem ====================================================
calc_totals: rem --- Calculate Totals for Summary Information
rem ====================================================

	glt05_dev=user_tpl.glt05_dev
	glt15_dev=user_tpl.glt15_dev
	gl_acct$=callpoint!.getColumnData("GLM_BANKMASTER.GL_ACCOUNT")
	st_date$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
	out_checks_amt=0
	out_checks=0
	out_trans_amt=0
	out_trans=0
	over_under$=""
	if pos("CUR_STMT_AMT.AVAL"=callpoint!.getCallpointEvent())
		statement_amt=num(callpoint!.getUserInput())
	else
		statement_amt=num(callpoint!.getColumnData("GLM_BANKMASTER.CUR_STMT_AMT"))
	endif
	callpoint!.setColumnData("<<DISPLAY>>.STMT_AMT",str(statement_amt))
	book_balance = num(callpoint!.getColumnData("GLM_BANKMASTER.BOOK_BALANCE"))
	callpoint!.setColumnData("<<DISPLAY>>.BOOK_BAL",str(book_balance))

rem --- Find Outstanding Checks
	read (glt05_dev,key=firm_id$+gl_acct$,dom=*next)
	while 1
		dim glt05a$:user_tpl.glt05_tpl$
		readrecord (glt05_dev,end=*break)glt05a$
		if glt05a.firm_id$<>firm_id$ break
		if glt05a.gl_account$<>gl_acct$ break
		if glt05a.paid_code$<>"O" continue
		if glt05a.bnk_chk_date$>st_date$ continue
		out_checks_amt=out_checks_amt+glt05a.check_amount,out_checks=out_checks+1
	wend

rem --- Find Outstanding Transactions
	read (glt15_DEV,key=firm_id$+gl_acct$,dom=*next)
	while 1
		dim glt15a$:user_tpl.glt15_tpl$
		readrecord (glt15_dev,end=*break)glt15a$
		if glt15a.firm_id$<>firm_id$ break
		if glt15a.gl_account$<>gl_acct$ break
		if glt15a.posted_code$<>"O" continue
		if glt15a.trns_date$>st_date$ continue
		out_trans_amt=out_trans_amt+glt15a.trans_amt,out_trans=out_trans+1
	wend

rem --- Find total cash inflows and total cash outflows
	gosub calc_inflows_outflows
	cash_inc_dec = inflows +outflows

rem --- Setup display variables

	callpoint!.setColumnData("<<DISPLAY>>.CHECKS_OUT",str(out_checks_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.NO_CHECKS",str(out_checks),1)
	callpoint!.setColumnData("<<DISPLAY>>.TRANS_OUT",str(out_trans_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.NO_TRANS",str(out_trans),1)
	end_bal=statement_amt-out_checks_amt+out_trans_amt
	callpoint!.setColumnData("<<DISPLAY>>.END_BAL",str(end_bal),1)
	difference = num(callpoint!.getColumnData("GLM_BANKMASTER.BOOK_BALANCE")) - end_bal
	callpoint!.setColumnData("<<DISPLAY>>.DIFFERENCE",str(difference),1)
	callpoint!.setColumnData("<<DISPLAY>>.CASH_IN",str(inflows),1)
	callpoint!.setColumnData("<<DISPLAY>>.CASH_OUT",str(outflows),1)
	callpoint!.setColumnData("<<DISPLAY>>.CASH_INC_DEC",str(cash_inc_dec),1)

	if end_bal<num(callpoint!.getColumnData("GLM_BANKMASTER.BOOK_BALANCE")) over_under$="SHORT"
	if end_bal>num(callpoint!.getColumnData("GLM_BANKMASTER.BOOK_BALANCE")) over_under$="OVER"
	return

rem ====================================================
disable_ctls:rem --- disable selected control
rem ====================================================

	for dctl=1 to 14
		dctl$=dctl$[dctl]
		if dctl$<>""
			wctl$=str(num(callpoint!.getTableColumnAttribute(dctl$,"CTLI")):"00000")
			wmap$=callpoint!.getAbleMap()
			wpos=pos(wctl$=wmap$,8)
			wmap$(wpos+6,1)="I"
			callpoint!.setAbleMap(wmap$)
			callpoint!.setStatus("ABLEMAP")
		endif
	next dctl
	return

rem ====================================================
calc_inflows_outflows:rem --- calc the inflow total and outflow total
rem ====================================================

	inflows=0
	outflows=0

rem --- get the Prior and Current Statement Dates
	stmtdate$=callpoint!.getColumnData("GLM_BANKMASTER.CURSTM_DATE")
	priordate$=callpoint!.getColumnData("GLM_BANKMASTER.PRI_END_DATE")
	
	if len(stmtdate$) = 8 and len(priordate$) = 8 then

		rem --- Find G/L Record"
		dim glt06a$:user_tpl.glt06_tpl$
		dim gls01a$:user_tpl.gls01_tpl$
		glt06_dev=user_tpl.glt06_dev
		gls01_dev=user_tpl.gls01_dev
		readrecord(gls01_dev,key=firm_id$+"GL00")gls01a$
		gosub check_date
		if !status then
			rem --- Initialize displayColumns! object
			if displayColumns!=null() then
				displayColumns!=new DisplayColumns(firm_id$)
			endif
			r1$=firm_id$+callpoint!.getColumnData("GLM_BANKMASTER.GL_ACCOUNT"),s1$=""
			if priordateyear=prior_priorgl s1$=r1$+displayColumns!.getYear("2"); rem "Use prior yea1r actual
			if priordateyear=prior_currentgl s1$=r1$+displayColumns!.getYear("0"); rem "Use current year actual
			if priordateyear=prior_nextgl s1$=r1$+displayColumns!.getYear("4"); rem "Use next year actual
			if s1$<>"" then 
				rem --- accumulate transactions in the statment period"
				call stbl("+DIR_PGM")+"adc_daydates.aon",priordate$,followingday$,1
				d1$=r1$+priordateyear$+priordateperiod$+followingday$
				readrecord (glt06_dev,key=d1$,dom=*next)
				while 1
					k$=key(glt06_dev,END=*break)
					if pos(r1$=k$)<>1 then break
					if k$(19,8)>stmtdate$ then break
					dim glt06a$:fattr(glt06a$)
					read record (glt06_dev,key=k$)glt06a$
					if glt06a.trans_amt > 0 then
						inflows=inflows+glt06a.trans_amt
					else	
						outflows=outflows+glt06a.trans_amt		
					endif
				wend
			endif
		endif
	endif

	return

rem ====================================================
displayBankInfo: rem --- Display Bank Account Information
rem 		IN: bnk_acct_cd$
rem ====================================================
	adcBankAcctCode_dev=fnget_dev("ADC_BANKACCTCODE")
	dim adcBankAcctCode$:fnget_tpl$("ADC_BANKACCTCODE")
	encryptor!=callpoint!.getDevObject("encryptor")
	findrecord(adcBankAcctCode_dev,key=firm_id$+bnk_acct_cd$,dom=*next)adcBankAcctCode$
	callpoint!.setColumnData("<<DISPLAY>>.BANK_NAME",adcBankAcctCode.bank_name$,1)
	callpoint!.setColumnData("<<DISPLAY>>.ADDRESS_LINE_1",adcBankAcctCode.address_line_1$,1)
	callpoint!.setColumnData("<<DISPLAY>>.ADDRESS_LINE_2",adcBankAcctCode.address_line_2$,1)
	callpoint!.setColumnData("<<DISPLAY>>.ADDRESS_LINE_3",adcBankAcctCode.address_line_3$,1)
	callpoint!.setColumnData("<<DISPLAY>>.ACCT_DESC",adcBankAcctCode.acct_desc$,1)
	callpoint!.setColumnData("<<DISPLAY>>.BNK_ACCT_TYPE",adcBankAcctCode.bnk_acct_type$,1)
	callpoint!.setColumnData("<<DISPLAY>>.ABA_NO",adcBankAcctCode.aba_no$,1)
	callpoint!.setColumnData("<<DISPLAY>>.BNK_ACCT_NO",encryptor!.decryptData(cvs(adcBankAcctCode.bnk_acct_no$,3)),1)

	return



