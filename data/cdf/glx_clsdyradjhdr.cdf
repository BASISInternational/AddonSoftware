[[GLX_CLSDYRADJHDR.ADIS]]
rem --- Calc and display totals (debits/credits, etc.)
	gosub update_grid_tots

[[GLX_CLSDYRADJHDR.AFMC]]
rem --- Inits
	use ::ado_util.src::util

rem --- Add static label to display fiscal period description
	period!=callpoint!.getControl("<<DISPLAY>>.GL_PERIOD")
	period_x=period!.getX()
	period_y=period!.getY()
	period_height=period!.getHeight()
	period_width=period!.getWidth()
	desc_width=105
	nxt_ctlID=util.getNextControlID()
	period_desc!=Form!.addStaticText(nxt_ctlID,period_x+period_width+6,period_y+3,desc_width,period_height-6,"")
	RGB$=stbl("+HYPERLINK_COLOR")
	gosub get_RGB
	labelColor! = BBjAPI().makeColor(R,G,B); rem --- Blue color only. This is NOT a hyperlink.
	period_desc!.setForeColor(labelColor!)
	callpoint!.setDevObject("period_desc",period_desc!)

rem --- Capture totals controls for use in detail grid
	callpoint!.setDevObject("debitCtrl",callpoint!.getControl("<<DISPLAY>>.DEBIT_AMT"))
	callpoint!.setDevObject("creditCtrl",callpoint!.getControl("<<DISPLAY>>.CREDIT_AMT"))
	callpoint!.setDevObject("totalCtrl",callpoint!.getControl("<<DISPLAY>>.TOTAL_AMOUNT"))
	callpoint!.setDevObject("unitsCtrl",callpoint!.getControl("<<DISPLAY>>.UNITS"))

[[GLX_CLSDYRADJHDR.AREC]]
rem --- Clear static label for fiscal period description
	period_desc!=callpoint!.getDevObject("period_desc")
	period_desc!.setText("")

[[GLX_CLSDYRADJHDR.BSHO]]
rem --- Open files
	num_files=4
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="GLS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="GLC_JOURNALCODE",open_opts$[2]="OTA"
	open_tables$[3]="GLS_CALENDAR",open_opts$[3]="OTA"
	open_tables$[4]="GLM_ACCT",open_opts$[4]="OTA"

	gosub open_tables

	glsParams_dev=num(open_chans$[1]),apt01_tpl$=open_tpls$[1]
	dim glsParams$:apt01_tpl$

rem --- GL using units?
	readrecord(glsParams_dev,key=firm_id$+"GL00", dom=std_missing_params)glsParams$
	callpoint!.setDevObject("units_flag",glsParams.units_flag$)

[[GLX_CLSDYRADJHDR.BWRI]]
rem --- Check for out of balance
	balance=num(callpoint!.getColumnData("<<DISPLAY>>.TOTAL_AMOUNT"))
	if balance<>0 then
		rem --- Password override required for write when out of balance
		call stbl("+DIR_PGM")+"adc_getmask.aon","","GL","A","",m0$,0,0
		msg_id$="GL_JOURNAL_OOB"
		dim msg_tokens$[1]
		msg_tokens$[1]=str(balance:m0$)
		gosub disp_message
		if pos("PASSVALID"=msg_opt$)=0 then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[GLX_CLSDYRADJHDR.JOURNAL_ID.AVAL]]
rem --- Verify this Journal ID is allowed for Journal Entries.
	journal_id$=callpoint!.getUserInput()
	glcJournalCode_dev=fnget_dev("GLC_JOURNALCODE")
	dim glcJournalCode$:fnget_tpl$("GLC_JOURNALCODE")
	findrecord(glcJournalCode_dev,key=firm_id$+callpoint!.getUserInput(),dom=*next)glcJournalCode$
	if glcJournalCode.permit_je$<>"Y"
		msg_id$="GL_JID"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Warn about inactive code Journal ID code
	if glcJournalCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(glcJournalCode.journal_id$,3)
		msg_tokens$[2]=cvs(glcJournalCode.code_desc$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[GLX_CLSDYRADJHDR.TRANS_DATE.AVAL]]
rem --- Must be in an existing fiscal year.
	trans_date$=callpoint!.getUserInput()
	call pgmdir$+"adc_fiscalperyr.aon",firm_id$,trans_date$,period$,year$,table_chans$[all],status
	if status then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Must be in the prior fiscal year.
	glsParams_dev=fnget_dev("GLS_PARAMS")
	dim glsParams$:fnget_tpl$("GLS_PARAMS")
	readrecord(glsParams_dev,key=firm_id$+"GL00")glsParams$
	if num(year$)<>num(glsParams.current_year$)-1 then
		msg_id$="GL_NOT_PRIOR_YR"
		dim msg_tokens$[1]
		msg_tokens$[1]=str(num(glsParams.current_year$)-1)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif
	

rem --- Prior fiscal year must be closed fiscal.
	if glsParams.gl_yr_closed$<>"Y" then
		msg_id$="GL_PRI_YR_NOT_CLOSED"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Show the fiscal year and period
	callpoint!.setColumnData("<<DISPLAY>>.GL_YEAR",year$,1)
	callpoint!.setColumnData("<<DISPLAY>>.GL_PERIOD",period$,1)

rem --- Show description for fiscal period
	glsCalendar_dev=fnget_dev("GLS_CALENDAR")
	dim glsCalendar$:fnget_tpl$("GLS_CALENDAR")
	readrecord(glsCalendar_dev,key=firm_id$+year$,dom=*next)glsCalendar$
	periodName$=field(glsCalendar$,"period_name_"+period$)
	period_desc!=callpoint!.getDevObject("period_desc")
	period_desc!.setText(periodName$)

[[GLX_CLSDYRADJHDR.<CUSTOM>]]
update_grid_tots: rem --- Calculate total debits/credits/units and display in form header
	recVect!=GridVect!.getItem(0)
	dim gridrec$:dtlg_param$[1,3]
	numrecs=recVect!.size()
        if numrecs>0
		for reccnt=0 to numrecs-1
			gridrec$=recVect!.getItem(reccnt)
			tdb=tdb+num(gridrec.debit_amt$)
			tcr=tcr+num(gridrec.credit_amt$)
			tunits=tunits+num(gridrec.units$)
		next reccnt
		tbal=tdb-tcr

		callpoint!.setColumnData("<<DISPLAY>>.DEBIT_AMT",str(tdb),1)
		callpoint!.setColumnData("<<DISPLAY>>.CREDIT_AMT",str(tcr),1)
		callpoint!.setColumnData("<<DISPLAY>>.TOTAL_AMOUNT",str(tbal),1)
		callpoint!.setColumnData("<<DISPLAY>>.UNITS",str(tunits),1)
	endif

	return

rem ==========================================================================
get_RGB: rem --- Parse Red, Green and Blue segments from RGB$ string
	rem --- input: RGB$
	rem --- output: R
	rem --- output: G
	rem --- output: B
rem ==========================================================================
	comma1=pos(","=RGB$,1,1)
	comma2=pos(","=RGB$,1,2)
	R=num(RGB$(1,comma1-1))
	G=num(RGB$(comma1+1,comma2-comma1-1))
	B=num(RGB$(comma2+1))

	return

rem ==========================================================================
#include [+ADDON_LIB]std_missing_params.aon
#include [+ADDON_LIB]std_functions.aon
rem ==========================================================================



