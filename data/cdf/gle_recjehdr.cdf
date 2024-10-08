[[GLE_RECJEHDR.ADIS]]
gosub calc_grid_tots
gosub disp_totals

[[GLE_RECJEHDR.BSHO]]
num_files=3
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="GLS_PARAMS",open_opts$[1]="OTA"
open_tables$[2]="GLC_JOURNALCODE",open_opts$[2]="OTA"
open_tables$[3]="GLC_CYCLECODE",open_opts$[3]="OTA"
gosub open_tables
gls01_dev=num(open_chans$[1]),gls_params_tpl$=open_tpls$[1]
dim gls01a$:gls_params_tpl$
read record(gls01_dev,key=firm_id$+"GL00",dom=std_missing_params)gls01a$
user_tpl_str$="glint:c(5*),glworkfile:c(16*),je:c(1*),cycles:c(5*),debits_ofst:c(5*),credits_ofst:c(5*),bal_ofst:c(5*),units_ofst:c(5*)," +
:			"gls01a_ofst:c(5*),tot_db:c(10*),tot_cr:c(10*),tot_bal:c(10*),tot_units:c(10*)"
dim user_tpl$:user_tpl_str$
gl$="N"
status=0
source$=pgm(-2)
call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,source$,"GL",glw11$,gl$,status
if status<>0 goto std_exit
user_tpl.glint$=gl$
user_tpl.glworkfile$=glw11$
user_tpl.je$="N"
user_tpl.cycles$="Y"
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
callpoint!.setDevObject("units_flag",gls01a.units_flag$)

rem --- Disable display only columns
	dctls!=SysGUI!.makeVector()
	dctls!.addItem("<<DISPLAY>>.DEBIT_AMT")
	dctls!.addItem("<<DISPLAY>>.CREDIT_AMT")
	dctls!.addItem("<<DISPLAY>>.BALANCE")
	dctls!.addItem("<<DISPLAY>>.UNITS")
	gosub disable_ctls

[[GLE_RECJEHDR.BWRI]]
rem  --- see if in balance
bal=num(user_tpl.tot_bal$)
if bal<>0
	msg_id$="GL_JOURNAL_OOB"
	dim msg_tokens$[1]
	msg_tokens$[1]=str(bal)
	gosub disp_message
	callpoint!.setStatus("ABORT")
endif

[[GLE_RECJEHDR.CYCLE_CODE.AVAL]]
rem --- Don't allow inactive code
	glcCycleCode_dev=fnget_dev("GLC_CYCLECODE")
	dim glcCycleCode$:fnget_tpl$("GLC_CYCLECODE")
	cycle_code$=callpoint!.getUserInput()
	read record(glcCycleCode_dev,key=firm_id$+cycle_code$,dom=*next)glcCycleCode$
	if glcCycleCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(glcCycleCode.cycle_code$,3)
		msg_tokens$[2]=cvs(glcCycleCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[GLE_RECJEHDR.JOURNAL_ID.AVAL]]
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

[[GLE_RECJEHDR.<CUSTOM>]]
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



