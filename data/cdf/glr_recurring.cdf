[[GLR_RECURRING.ARAR]]
rem --- Initialize Posting Date with system date
	dim sysinfo$:stbl("+SYSINFO_TPL")
	sysinfo$=stbl("+SYSINFO")
	callpoint!.setColumnData("GLR_RECURRING.POSTING_DATE",sysinfo.system_date$,1)

[[GLR_RECURRING.BSHO]]
rem --- Open/Lock files
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="GLC_CYCLECODE",open_opts$[1]="OTA"

	gosub open_tables

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
	callpoint!.setDevObject("glint",gl$)

[[GLR_RECURRING.CYCLE_CODE.AVAL]]
rem --- Warn about inactive code Cycle Code
	glcCycleCode_dev=fnget_dev("GLC_CYCLECODE")
	dim glcCycleCode$:fnget_tpl$("GLC_CYCLECODE")
	cycle_code$=callpoint!.getUserInput()
	findrecord(glcCycleCode_dev,key=firm_id$+cycle_code$,dom=*next)glcCycleCode$
	if glcCycleCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(glcCycleCode.cycle_code$,3)
		msg_tokens$[2]=cvs(glcCycleCode.code_desc$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[GLR_RECURRING.POSTING_DATE.AVAL]]
rem --- Skip validation if date checked before and it has not changed.
	if callpoint!.getDevObject("glint")="Y" and callpoint!.getUserInput()<>callpoint!.getColumnData("GLR_RECURRING.POSTING_DATE") then
		call stbl("+DIR_PGM")+"glc_datecheck.aon",callpoint!.getUserInput(),"Y",period$,year$,status
		if status>100 callpoint!.setStatus("ABORT")
	endif



