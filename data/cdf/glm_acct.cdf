[[GLM_ACCT.ADEL]]
rem --- Remove all glm-02 recs

	glm02_dev=fnget_dev("GLM_ACCTSUMMARY")
	dim glm02a$:fnget_tpl$("GLM_ACCTSUMMARY")
	this_acct$=callpoint!.getColumnData("GLM_ACCT.GL_ACCOUNT")
	read(glm02_dev,key=firm_id$+this_acct$,dom=*next)
	while 1
		glm02_key$=key(glm02_dev,end=*break)
		read record (glm02_dev) glm02a$
		if pos(firm_id$+this_acct$=glm02a$)<>1 break
		remove (glm02_dev,key=glm02_key$)
	wend

[[GLM_ACCT.AOPT-SUMM]]
rem Summary Activity Inquiry

cp_acct$=""

rem --- need to set cp_acct$ from grid if we're running glm_acct as maint grid
while 1
	gridObj!=Form!.getControl(5000,err=*break)
	cp_acct$=gridObj!.getCellText(gridObj!.getSelectedRow(),0)
	break
wend

rem --- or set cp_acct$ by getting column data if we did an expand on a validated GL acct in some other form
if cp_acct$="" then cp_acct$=callpoint!.getColumnData("GLM_ACCT.GL_ACCOUNT")

user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="GL_ACCOUNT"
dflt_data$[1,1]=cp_acct$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                       "GLM_SUMMACTIVITY",
:                       user_id$,
:                   	  "",
:                       "",
:                       table_chans$[all],
:                       "",
:                       dflt_data$[all]

[[GLM_ACCT.AOPT-TRAN]]
rem Transaction History Inquiry

cp_acct$=""

rem --- need to set cp_acct$ from grid if we're running glm_acct as maint grid
while 1
	gridObj!=Form!.getControl(5000,err=*break)
	cp_acct$=gridObj!.getCellText(gridObj!.getSelectedRow(),0)
	break
wend

rem --- or set cp_acct$ by getting column data if we did an expand on a validated GL acct in some other form
if cp_acct$="" then cp_acct$=callpoint!.getColumnData("GLM_ACCT.GL_ACCOUNT")

user_id$=stbl("+USER_ID")
dim dflt_data$[2,1]
dflt_data$[1,0]="GL_ACCOUNT_1"
dflt_data$[1,1]=cp_acct$
dflt_data$[2,0]="GL_ACCOUNT_2"
dflt_data$[2,1]=cp_acct$
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                       "GLR_TRANSHISTORY",
:                       user_id$,
:                   	  "",
:                       "",
:                       table_chans$[all],
:                       "",
:                       dflt_data$[all]

[[GLM_ACCT.ARAR]]
rem --- Set initial values for period and year

	fiscal_per$=callpoint!.getDevObject("gls_cur_per")
	fiscal_yr$=callpoint!.getDevObject("gls_cur_yr")
	callpoint!.setColumnData("<<DISPLAY>>.CURRENT_PER",stbl("+PER"),1)
	callpoint!.setColumnData("<<DISPLAY>>.CURRENT_YEAR",stbl("+YEAR"),1)
	callpoint!.setColumnData("<<DISPLAY>>.FISCAL_PER",fiscal_per$,1)
	callpoint!.setColumnData("<<DISPLAY>>.FISCAL_YEAR",fiscal_yr$,1)

	gosub display_mtd_ytd

rem --- Set current selection in summ_dtl list 
	callpoint!.setColumnData("<<DISPLAY>>.SUMM_DTL",callpoint!.getColumnData("GLM_ACCT.DETAIL_FLAG"),1)

[[GLM_ACCT.AREC]]
rem --- Set Default value for Detail Flag

	detail_flag$=callpoint!.getDevObject("detail_flag")
	callpoint!.setColumnData("GLM_ACCT.DETAIL_FLAG",detail_flag$)
	callpoint!.setColumnData("<<DISPLAY>>.SUMM_DTL",detail_flag$,1)

[[GLM_ACCT.BDEL]]
rem --- Check for activity
	okay$="Y"
	mp=13
	reason$=""

rem --- Check glm-02 for activity

	displayColumns!=callpoint!.getDevObject("displayColumns")
	current_prior_next$=displayColumns!.getYear("0")+":"+displayColumns!.getYear("2")+":"+displayColumns!.getYear("4")
	glm02_dev=fnget_dev("GLM_ACCTSUMMARY")
	dim glm02a$:fnget_tpl$("GLM_ACCTSUMMARY")
	this_acct$=callpoint!.getColumnData("GLM_ACCT.GL_ACCOUNT")
	read(glm02_dev,key=firm_id$+this_acct$,dom=*next)
	while 1
		readrecord (glm02_dev,end=*break)glm02a$
		if pos(firm_id$+this_acct$=glm02a.firm_id$+glm02a.gl_account$)<>1 break
		if pos(glm02a.year$=current_prior_next$)=0 continue
		for x=1 to mp
			if nfield(glm02a$,"period_amt_"+str(x:"00"))<>0 okay$="N"
			if nfield(glm02a$,"period_units_"+str(x:"00"))<>0 okay$="N"
		next x
		if okay$="N"
			reason$=Translate!.getTranslation("AON_ACCOUNT_SUMMARY")
			break
		endif
	wend

rem --- Check glt-06 for history
	if okay$="Y"
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLT_TRANSDETAIL",options$[1]="OTA"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:			chans$[all],templates$[all],table_chans$[all],batch,status$

		glt06_dev=num(chans$[1])
		read (glt06_dev,key=firm_id$+this_acct$,dom=*next)
		while 1
			glt06_key$=key(glt06_dev,end=*break)
			if pos(firm_id$+this_acct$=glt06_key$)=1
				okay$="N"
				reason$=Translate!.getTranslation("AON_TRANSACTION_HISTORY")
			endif
			break
		wend

		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLT_TRANSDETAIL",options$[1]="CX"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:			chans$[all],templates$[all],table_chans$[all],batch,status$

	endif

rem ---Check Journal Entries for activity
	if okay$="Y"
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_JRNLDET",options$[1]="OTA"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$
		gle11_dev=num(chans$[1])
		read (gle11_dev,key=firm_id$+this_acct$,knum="BY ACCOUNT",dom=*next)
		while 1
			gle11_key$=key(gle11_dev,end=*break)
			if pos(firm_id$+this_acct$=gle11_key$)=1
				okay$="N"
				reason$=Translate!.getTranslation("AON_JOURNAL_ENTRY")
			endif
			break
		wend

		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_JRNLDET",options$[1]="CX"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$
	endif

rem ---Check Recurring Journal Entries for activity
	if okay$="Y"
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_RECJEDET",options$[1]="OTA"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$
		gle12_dev=num(chans$[1])
		read (gle12_dev,key=firm_id$+this_acct$,knum="BY ACCOUNT",dom=*next)
		while 1
			gle12_key$=key(gle12_dev,end=*break)
			if pos(firm_id$+this_acct$=gle12_key$)=1
				okay$="N"
				reason$=Translate!.getTranslation("AON_RECURRING_JOURNAL_ENTRY")
			endif
			break
		wend

		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_RECJEDET",options$[1]="CX"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$
	endif

rem ---Check Allocation Detail for activity
	if okay$="Y"
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_ALLOCDET",options$[1]="OTA"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$

		gle13_dev=num(chans$[1])
		read (gle13_dev,key=firm_id$+this_acct$,dom=*next)
		while 1
			gle13_key$=key(gle13_dev,end=*break)
			if pos(firm_id$+this_acct$=gle13_key$)=1
				okay$="N"
				reason$=Translate!.getTranslation("AON_ACCOUNT_ALLOCATION")
			endif
			break
		wend
		if okay$="Y"
			read (gle13_dev,key=firm_id$+this_acct$,knum="AO_DEST_ACCT",dom=*next)
			while 1
				gle13_key$=key(gle13_dev,end=*break)
				if pos(firm_id$+this_acct$=gle13_key$)=1
					okay$="N"
					reason$=Translate!.getTranslation("AON_ACCOUNT_ALLOCATION")
				endif
				break
			wend
		endif

		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_ALLOCDET",options$[1]="CX"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$

	endif

rem ---Check Daily Detail for activity
	if okay$="Y"
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_DAILYDETAIL",options$[1]="OTA"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$

		glt04_dev=num(chans$[1])
		read (glt04_dev,key=firm_id$+this_acct$,knum="AO_TRDAT_PROCESS",dom=*next)
		while 1
			glt04_key$=key(glt04_dev,end=*break)
			if pos(firm_id$+this_acct$=glt04_key$)=1
				okay$="N"
				reason$=Translate!.getTranslation("AON_DAILY_DETAIL")
			endif
			break
		wend

		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLE_DAILYDETAIL",options$[1]="CX"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:			chans$[all],templates$[all],table_chans$[all],batch,status$
	endif

rem --- Check Retained Earnings Account
	if okay$="Y"
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLS_EARNINGS",options$[1]="OTA"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$

		gls_earnings_dev=num(chans$[1])
		dim gls01b$:templates$[1]
		while 1
			read record(gls_earnings_dev,key=firm_id$+"GL01",err=*break)gls01b$
			if gls01b.gl_account$=this_acct$
				okay$="N"
				reason$=Translate!.getTranslation("AON_RETAINED_EARNINGS_ACCOUNT")
			endif
			break
		wend
		files=1,begfile=1,endfile=files
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[1]="GLS_EARNINGS",options$[1]="CX"

		call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:               		                  chans$[all],templates$[all],table_chans$[all],batch,status$

	endif

rem --- Disallow delete if flag is set
	if okay$="N"
		msg_id$="ACTIVITY_EXISTS"
		dim msg_tokens$[1]
		msg_tokens$[1]=reason$
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[GLM_ACCT.BSHO]]
rem --- Initialize displayColumns! object

	use ::glo_DisplayColumns.aon::DisplayColumns
	displayColumns!=new DisplayColumns(firm_id$)
	callpoint!.setDevObject("displayColumns",displayColumns!)

rem --- Open/Lock files

files=4,begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]
files$[1]="GLS_PARAMS",options$[1]="OTA"
files$[2]="GLM_ACCTSUMMARY",options$[2]="OTA"
files$[3]="GLS_CALENDAR",options$[3]="OTA"
files$[4]="GLS_EARNINGS",options$[4]="OTA"

call dir_pgm$+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:                                 chans$[all],templates$[all],table_chans$[all],batch,status$

if status$<>"" then
	remove_process_bar:
	bbjAPI!=bbjAPI()
	rdFuncSpace!=bbjAPI!.getGroupNamespace()
	rdFuncSpace!.setValue("+build_task","OFF")
	release
endif

gls01_dev=num(chans$[1])
gls_calendar_dev=num(chans$[3])
dim gls01a$:templates$[1]
dim gls_calendar$:templates$[3]


rem --- init/parameters

gls01a_key$=firm_id$+"GL00"
find record (gls01_dev,key=gls01a_key$,err=std_missing_params) gls01a$
find record (gls_calendar_dev,key=firm_id$+gls01a.current_year$,err=*next) gls_calendar$
if cvs(gls_calendar.firm_id$,2)="" then
	msg_id$="AD_NO_FISCAL_CAL"
	dim msg_tokens$[1]
	msg_tokens$[1]=gls01a.current_year$
	gosub disp_message
	callpoint!.setStatus("EXIT")
	break
endif

	glyear=num(gls01a.current_year$)
	if gls01a.gl_yr_closed$ <> "Y" then 
		record$="4"
	else
		record$="0"
	endif
	callpoint!.setDevObject("rec_id",record$)
	callpoint!.setDevObject("cur_per",gls01a.current_per$)
	callpoint!.setDevObject("cur_year",gls01a.current_year$)
	x$=stbl("+YEAR",gls01a.current_year$)
	x$=stbl("+PER",gls01a.current_per$)
	callpoint!.setDevObject("tot_pers",gls_calendar.total_pers$)
	callpoint!.setDevObject("gl_yr_closed",gls01a.gl_yr_closed$)
	callpoint!.setDevObject("gls_cur_yr",gls01a.current_year$)
	callpoint!.setDevObject("gls_cur_per",gls01a.current_per$)
	if gls01a.detail_flag$<>"Y"
		callpoint!.setColumnEnabled("GLM_ACCT.DETAIL_FLAG",-1)
		callpoint!.setColumnEnabled("<<DISPLAY>>.SUMM_DTL",-1)
	endif
	callpoint!.setDevObject("detail_flag",gls01a.detail_flag$)

	tns!=BBjAPI().getNamespace("GLM_ACCT","drill",1)
	tns!.setValue("cur_per",gls01a.current_per$)

rem --- Create Yes-No version of summ_dtl list
	ldat_list$=pad(Translate!.getTranslation("AON_DETAIL"),15)+"~"+"Y ;"
	ldat_list$=ldat_list$+pad(Translate!.getTranslation("AON_SUMMARY"),15)+"~"+"N ;"

	callpoint!.setTableColumnAttribute("<<DISPLAY>>.SUMM_DTL","LDAT",ldat_list$)

	rem --- Remove code from ListButton display
	summ_dtl!=callpoint!.getControl("<<DISPLAY>>.SUMM_DTL")
	summ_dtl!.removeAllItems()
	summ_dtl!.addItem(Translate!.getTranslation("AON_DETAIL"))
	summ_dtl!.addItem(Translate!.getTranslation("AON_SUMMARY"))

[[GLM_ACCT.BWAR]]
rem --- Capture current selection in summ_dtl list 
	callpoint!.setColumnData("GLM_ACCT.DETAIL_FLAG",callpoint!.getColumnData("<<DISPLAY>>.SUMM_DTL"))

[[<<DISPLAY>>.CURRENT_PER.AINP]]
rem -- Ensure valid period

	period$=callpoint!.getUserInput()
	if num(period$)<1 or num(period$)>num(callpoint!.getDevObject("tot_pers"))
		msg_id$="INVALID_PERIOD"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[<<DISPLAY>>.CURRENT_PER.AVAL]]
rem --- set variables

	per$=callpoint!.getUserInput()
	callpoint!.setDevObject("cur_per",per$)
	x$=stbl("+PER",per$)
	tns!=BBjAPI().getNamespace("GLM_ACCT","drill",1)
	tns!.setValue("cur_per",per$)
	gosub check_modified

	gosub display_mtd_ytd

[[<<DISPLAY>>.CURRENT_YEAR.AVAL]]
rem --- set variables

	yr$=callpoint!.getUserInput()
	callpoint!.setDevObject("cur_year",yr$)
	x$=stbl("+YEAR",yr$)

rem --- Set proper record ID
	record$=" "
	if num(yr$)=num(callpoint!.getDevObject("gls_cur_yr"))
		if callpoint!.getDevObject("gl_yr_closed") <> "Y"
			record$="4";rem Next Year Actual
		else
			record$="0";rem Current Year Actual
		endif
	endif
	if num(yr$)=num(callpoint!.getDevObject("gls_cur_yr"))-1
		if callpoint!.getDevObject("gl_yr_closed") <> "Y"
			record$="0";rem Current Year Actual
		else
			record$="2";rem Prior Year Actual
		endif
	endif
	if num(yr$)=num(callpoint!.getDevObject("gls_cur_yr"))+1
		if callpoint!.getDevObject("gl_yr_closed") <> "Y"
			record$=" ";rem Undefined
		else
			record$="4";rem Next Year Actual
		endif
	endif
	callpoint!.setDevObject("rec_id",record$)
	gosub check_modified

	gosub display_mtd_ytd

[[GLM_ACCT.GL_ACCT_TYPE.AVAL]]
rem --- The Retained Earnings account must be a Capital type account
	if callpoint!.getUserInput()<>callpoint!.getColumnData("GLM_ACCT.GL_ACCT_TYPE") then
		glsEarnings_dev=fnget_dev("GLS_EARNINGS")
		dim glsEarnings$:fnget_tpl$("GLS_EARNINGS")
		earningsFound=0
		readrecord(glsEarnings_dev,key=firm_id$+"GL01",dom=*next)glsEarnings$; earningsFound=1
		if earningsFound and callpoint!.getColumnData("GLM_ACCT.GL_ACCOUNT")=glsEarnings.gl_account$ then
			msg_id$="GL_BAD_RETAINED_ACCT"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[GLM_ACCT.<CUSTOM>]]
rem ======================================================
check_modified:
rem ======================================================

	det_flag$=callpoint!.getColumnData("GLM_ACCT.DETAIL_FLAG")
	dsk_det_flag$=callpoint!.getColumnDiskData("GLM_ACCT.DETAIL_FLAG")
	desc$=callpoint!.getColumnData("GLM_ACCT.GL_ACCT_DESC")
	dsk_desc$=callpoint!.getColumnDiskData("GLM_ACCT.GL_ACCT_DESC")
	type$=callpoint!.getColumnData("GLM_ACCT.GL_ACCT_TYPE")
	dsk_type$=callpoint!.getColumnDiskData("GLM_ACCT.GL_ACCT_TYPE")
	if det_flag$=dsk_det_flag$ and desc$=dsk_desc$ and type$=dsk_type$
		callpoint!.setStatus("CLEAR")
	endif

	return

rem ======================================================
display_mtd_ytd:
rem ======================================================

rem --- Display MTD and YTD

	glm02_dev=fnget_dev("GLM_ACCTSUMMARY")
	dim glm02$:fnget_tpl$("GLM_ACCTSUMMARY")
	acct_no$=callpoint!.getColumnData("GLM_ACCT.GL_ACCOUNT")
	rec_id$=callpoint!.getDevObject("rec_id")
	displayColumns!=callpoint!.getDevObject("displayColumns")
	year$=displayColumns!.getYear(rec_id$)
	cur_per=num(callpoint!.getDevObject("cur_per"))

	read record (glm02_dev,key=firm_id$+acct_no$+year$,dom=*next) glm02$
	cur_amt=nfield(glm02$,"period_amt_"+str(cur_per:"00"))
	ytd_amt=0
	for x=1 to cur_per
		ytd_amt=ytd_amt+nfield(glm02$,"period_amt_"+str(x:"00"))
	next x

	callpoint!.setColumnData("<<DISPLAY>>.MTD_TOTAL",str(cur_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.YTD_TOTAL",str(ytd_amt),1)
	callpoint!.setColumnData("<<DISPLAY>>.YTD_BALANCE",str(ytd_amt+glm02.begin_amt),1)

	return

#include [+ADDON_LIB]std_missing_params.aon



