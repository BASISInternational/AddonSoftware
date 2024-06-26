[[GLE_JRNLHDR.ADIS]]
rem --- calc and display totals (debits/credits, etc.)
gosub calc_grid_tots
gosub disp_totals

[[GLE_JRNLHDR.ARAR]]
rem --- Initialize dev object for this record
	if cvs(callpoint!.getColumnData("GLE_JRNLHDR.REVERSE_DATE"),3)<>"" then
		callpoint!.setDevObject("reverse_date_checked",1)
	else
		callpoint!.setDevObject("reverse_date_checked",0)
	endif

[[GLE_JRNLHDR.ARER]]
rem --- Initializations for new record
	callpoint!.setDevObject("reverse_date_checked",0)

[[GLE_JRNLHDR.ARNF]]
if num(stbl("+BATCH_NO"),err=*next)<>0
	rem --- Check if this record exists in a different batch
	tableAlias$=callpoint!.getAlias()
	primaryKey$=callpoint!.getColumnData("GLE_JRNLHDR.FIRM_ID")+
:		callpoint!.getColumnData("GLE_JRNLHDR.JOURNAL_ID")+
:		callpoint!.getColumnData("GLE_JRNLHDR.JE_TRANS_ID")
	call stbl("+DIR_PGM")+"adc_findbatch.aon",tableAlias$,primaryKey$,Translate!,table_chans$[all],existingBatchNo$,status
	if status or existingBatchNo$<>"" then callpoint!.setStatus("NEWREC")
endif

[[GLE_JRNLHDR.BEND]]
rem --- remove software lock on batch, if batching

	batch$=stbl("+BATCH_NO",err=*next)
	if num(batch$)<>0
		lock_table$="ADM_PROCBATCHES"
		lock_record$=firm_id$+stbl("+PROCESS_ID")+batch$
		lock_type$="X"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[GLE_JRNLHDR.BREA]]
rem --- Initialize date check devObjects
	callpoint!.setDevObject("trans_date_checked",0)
	callpoint!.setDevObject("reserve_date_checked",0)

[[GLE_JRNLHDR.BSHO]]
num_files=1
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="GLS_PARAMS",open_opts$[1]="OTA"
gosub open_tables

gls01_dev=num(open_chans$[1]),gls_params_tpl$=open_tpls$[1]
dim gls01a$:gls_params_tpl$

read record(gls01_dev,key=firm_id$+"GL00",dom=std_missing_params)gls01a$

user_tpl_str$="glint:c(5*),je:c(1*),debits_ofst:c(5*),credits_ofst:c(5*),bal_ofst:c(5*),units_ofst:c(5*)," +
:			"gls01a_ofst:c(5*),tot_db:c(10*),tot_cr:c(10*),tot_bal:c(10*),tot_units:c(10*)"
dim user_tpl$:user_tpl_str$

gl$="N"
status=0
source$=pgm(-2)
call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,source$,"GL",glw11$,gl$,status
if status<>0 then
	msg_id$="GLC_CTLCREATE_ERR"
	dim msg_tokens$[1]
	msg_tokens$[1]=str(status)
	gosub disp_message
	callpoint!.setStatus("EXIT")
	break
endif

user_tpl.glint$=gl$
user_tpl.je$="Y"

rem --- set up UserObj! as vector to store display controls (total debits, total credits, balance, units) and store param rec
UserObj!=SysGUI!.makeVector()
ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DEBIT_AMT","CTLC"))
ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DEBIT_AMT","CTLI"))
debits!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.CREDIT_AMT","CTLC"))
ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.CREDIT_AMT","CTLI"))
credits!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.BALANCE","CTLC"))
ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.BALANCE","CTLI"))
bal!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.UNITS","CTLC"))
ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.UNITS","CTLI"))
units!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

UserObj!.addItem(debits!)
user_tpl.debits_ofst$="0"
UserObj!.addItem(credits!)
user_tpl.credits_ofst$="1"
UserObj!.addItem(bal!)
user_tpl.bal_ofst$="2"
UserObj!.addItem(units!)
user_tpl.units_ofst$="3"
UserObj!.addItem(gls01a$)
user_tpl.gls01a_ofst$="4"

rem --- Need to disable units column in grid if gls01a.units_flag$ isn't "Y"
callpoint!.setDevObject("units_flag",gls01a.units_flag$)

rem --- Disable display only columns
	dctls!=SysGUI!.makeVector()
	dctls!.addItem("<<DISPLAY>>.DEBIT_AMT")
	dctls!.addItem("<<DISPLAY>>.CREDIT_AMT")
	dctls!.addItem("<<DISPLAY>>.BALANCE")
	dctls!.addItem("<<DISPLAY>>.UNITS")
	gosub disable_ctls

[[GLE_JRNLHDR.BTBL]]
rem --- Get Batch information

call stbl("+DIR_PGM")+"adc_getbatch.aon",callpoint!.getAlias(),"",table_chans$[all]
callpoint!.setTableColumnAttribute("GLE_JRNLHDR.BATCH_NO","PVAL",$22$+stbl("+BATCH_NO")+$22$)

[[GLE_JRNLHDR.BWRI]]
rem --- Validate dates if they haven't been validated yet
if user_tpl.glint$="Y"
	if !callpoint!.getDevObject("trans_date_checked") then
		call stbl("+DIR_PGM")+"glc_datecheck.aon",callpoint!.getColumnData("GLE_JRNLHDR.TRANS_DATE"),"Y",period$,year$,status
		if status>100  then
			callpoint!.setFocus("GLE_JRNLHDR.TRANS_DATE")
			callpoint!.setStatus("ABORT-ACTIVATE")
			break
		endif
	endif
	if cvs(callpoint!.getColumnData("GLE_JRNLHDR.REVERSE_DATE"),3)<>"" and !callpoint!.getDevObject("reverse_date_checked") then
		callpoint!.setDevObject("reverse_date_checked",1)
		call stbl("+DIR_PGM")+"glc_datecheck.aon",callpoint!.getColumnData("GLE_JRNLHDR.REVERSE_DATE"),"Y",period$,year$,status
		if status>100 then 
			callpoint!.setFocus("GLE_JRNLHDR.REVERSE_DATE")
			callpoint!.setStatus("ABORT-ACTIVATE")
			break
		endif
	endif
endif

rem --- see if in balance
bal=num(user_tpl.tot_bal$)
if bal<>0
	call stbl("+DIR_PGM")+"adc_getmask.aon","","GL","A","",m0$,0,0
	msg_id$="GL_JOURNAL_OOB"
	dim msg_tokens$[1]
	msg_tokens$[1]=str(bal:m0$)
	gosub disp_message
	if pos("PASSVALID"=msg_opt$)=0
		callpoint!.setStatus("ABORT")
	endif
endif

[[GLE_JRNLHDR.JOURNAL_ID.AVAL]]
rem --- Don't allow inactive code
	glm03_dev=fnget_dev("GLC_JOURNALCODE")
	dim glm03a$:fnget_tpl$("GLC_JOURNALCODE")
	journal_id_cd$=callpoint!.getUserInput()
	read record(glm03_dev,key=firm_id$+journal_id_cd$,dom=*next)glm03a$
	if glm03a.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(glm03a.journal_id$,3)
		msg_tokens$[2]=cvs(glm03a.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- read glm03 -- make sure PERMIT_JE is "Y",
rem --- and update +GLCONTROL with POST_YR_END and POST_LOCKED flags, plus PERMIT_JE, if "Y"
if user_tpl.glint$="Y"
	status=1
	more=1
	glm03_dev=fnget_dev("GLC_JOURNALCODE")
	dim glm03a$:fnget_tpl$("GLC_JOURNALCODE")
	while more
		find(glm03_dev,key=firm_id$+callpoint!.getUserInput(),dom=*break)glm03a$
		status=0
		if glm03a.permit_je$="Y"
			dim glcontrol$:stbl("+GLCONTROL_TPL")
			glcontrol$=stbl("+GLCONTROL")
			glcontrol.journal_id$=glm03a.journal_id$
			glcontrol.post_yr_end$=glm03a.post_yr_end$
			glcontrol.post_locked$=glm03a.post_locked$
			if user_tpl.je$="Y"
				glcontrol.permit_je$="Y"
			endif
			glcontrol$=stbl("+GLCONTROL",glcontrol$)
		else
			msg_id$="GL_JID"
			gosub disp_message
			status=1
		endif
	
		break
	wend
	if status<>0 callpoint!.setStatus("ABORT")
	
endif

[[GLE_JRNLHDR.REVERSE_DATE.AVAL]]
rem --- perform date validation
if user_tpl.glint$="Y" and cvs(callpoint!.getUserInput(),3)<>""
rem --- Skip validation if date checked before and it has not changed.
	if !callpoint!.getDevObject("reverse_date_checked") or 
:	callpoint!.getUserInput()<>callpoint!.getColumnData("GLE_JRNLHDR.REVERSE_DATE") then
		callpoint!.setDevObject("reverse_date_checked",1)
		call stbl("+DIR_PGM")+"glc_datecheck.aon",callpoint!.getUserInput(),"Y",period$,year$,status
		if status>100 callpoint!.setStatus("ABORT")
	endif
endif

[[GLE_JRNLHDR.TRANS_DATE.AVAL]]
rem --- perform date validation
if user_tpl.glint$="Y"
rem --- Skip validation if date checked before and it has not changed.
	if !callpoint!.getDevObject("trans_date_checked") or 
:	callpoint!.getUserInput()<>callpoint!.getColumnData("GLE_JRNLHDR.TRANS_DATE") then
		callpoint!.setDevObject("trans_date_checked",1)
		call stbl("+DIR_PGM")+"glc_datecheck.aon",callpoint!.getUserInput(),"Y",period$,year$,status
		if status>100 callpoint!.setStatus("ABORT")
	endif
endif

[[GLE_JRNLHDR.<CUSTOM>]]
disable_ctls:rem --- disable selected control
	dctl=dctls!.size()	
	for wk=0 to dctl-1
		dctl$=dctls!.getItem(wk)
		if dctl$<>""
			wctl$=str(num(callpoint!.getTableColumnAttribute(dctl$,"CTLI")):"00000")
			wmap$=callpoint!.getAbleMap()
			wpos=pos(wctl$=wmap$,8)
			wmap$(wpos+6,1)="I"
			callpoint!.setAbleMap(wmap$)
			callpoint!.setStatus("ABLEMAP")
		endif
	next wk
	return
rem --- calculate total debits/credits/units and display in form header
calc_grid_tots:
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
            user_tpl.tot_db$=str(tdb)
	    user_tpl.tot_cr$=str(tcr)
	    user_tpl.tot_units$=str(tunits)
	    user_tpl.tot_bal$=str(tbal)
        endif
    return
disp_totals:
    rem --- get context and ID of display controls, and redisplay w/ amts from calc_grid_tots
    
    debits!=UserObj!.getItem(num(user_tpl.debits_ofst$))
    debits!.setValue(num(user_tpl.tot_db$))
    credits!=UserObj!.getItem(num(user_tpl.credits_ofst$))
    credits!.setValue(num(user_tpl.tot_cr$))
    bal!=UserObj!.getItem(num(user_tpl.bal_ofst$))
    bal!.setValue(num(user_tpl.tot_bal$))
    units!=UserObj!.getItem(num(user_tpl.units_ofst$))
    units!.setValue(num(user_tpl.tot_units$))
    return
#include [+ADDON_LIB]std_missing_params.aon



