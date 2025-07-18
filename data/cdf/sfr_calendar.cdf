[[SFR_CALENDAR.BFMC]]
rem --- open files/init

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SFS_PARAMS",open_opts$[1]="OTA"

	gosub open_tables

	sfs_params=num(open_chans$[1])

	dim sfs_params$:open_tpls$[1]

	read record (sfs_params,key=firm_id$+"SF00",dom=std_missing_params)sfs_params$
	bm$=sfs_params.bm_interface$

	if bm$="Y"
		call stbl("+DIR_PGM")+"adc_application.aon","BM",info$[all]
		bm$=info$[20]
	endif
	callpoint!.setDevObject("bm",bm$)

	rem --- Open Operation Code table
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	if bm$<>"Y"
		callpoint!.setTableColumnAttribute("SFR_CALENDAR.OP_CODE","DTAB","SFC_OPRTNCOD")
		open_tables$[1]="SFC_OPRTNCOD",open_opts$[1]="OTA"
	else
		open_tables$[1]="BMC_OPCODES",open_opts$[1]="OTA"
	endif
	gosub open_tables

	callpoint!.setDevObject("opcode_chan",num(open_chans$[1]))
	callpoint!.setDevObject("opcode_tpl",open_tpls$[1])

[[SFR_CALENDAR.OP_CODE.AVAL]]
rem --- Don't allow inactive code
	opcode_dev=callpoint!.getDevObject("opcode_chan")
	dim opcode$:callpoint!.getDevObject("opcode_tpl")
	op_code$=callpoint!.getUserInput()
	found=0
	read record (opcode_dev,key=firm_id$+op_code$,dom=*next) opcode$;found=1
	if opcode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(opcode.op_code$,3)
		msg_tokens$[2]=cvs(opcode.code_desc$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Set default dates
	files=1,begfile=1,endfile=1
	dim files$[files],options$[files],chans$[files],templates$[files]
	files$[1]="SFM_OPCALNDR";options$[1]="OTA"
	call stbl("+DIR_SYP")+"bac_open_tables.bbj",
:		begfile,
:		endfile,
:		files$[all],
:		options$[all],
:		chans$[all],
:		templates$[all],
:		table_chans$[all],
:		batch,
:		status$

	if status$<>"" then
		remove_process_bar:
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif
	sfm04_dev=num(chans$[1])
	dim sfm04a$:templates$[1]
	more=1
	firm_id$=sysinfo.firm_id$
	opcode$=callpoint!.getUserInput()
	first_date$=""
	read (sfm04_dev,key=firm_id$+opcode$,dom=*next)
	k$=key(sfm04_dev,end=label1)
	if pos(firm_id$+opcode$=k$)=1 then 
		read record (sfm04_dev,key=k$) sfm04a$
		x$="01"
		for ii=1 to sfm04a.days_in_mth
			if nfield(sfm04a$,"hrs_per_day_"+str(ii:"00"))>=0 then let x$=str(ii:"00"); break
		next ii
		first_date$=fndate$(sfm04a.year$+sfm04a.month$+x$)
	endif 

label1:
	last_date$=""
	read (sfm04_dev,key=firm_id$+opcode$,dom=*next)
	while more
		k$=key(sfm04_dev,end=*break)
		if pos(firm_id$+opcode$=k$)<>1 then break
		read record (sfm04_dev,key=k$) sfm04a$
		x$=str(sfm04a.days_in_mth:"00")
		for ii=sfm04a.days_in_mth to 1 step -1
			if nfield(sfm04a$,"hrs_per_day_"+str(ii:"00"))>=0 then let x$=str(ii:"00"); break
		next ii
		let last_date$=fndate$(sfm04a.year$+sfm04a.month$+x$)
	wend   

	if cvs(callpoint!.getColumnData("SFR_CALENDAR.FIRST_DATE"),3)=""
		callpoint!.setColumnData("SFR_CALENDAR.FIRST_DATE",first_date$)
		callpoint!.setColumnData("SFR_CALENDAR.LAST_DATE",last_date$)
		if cvs(first_date$,2)="" then
			callpoint!.setColumnData("SFR_CALENDAR.PERIOD","")
			callpoint!.setColumnData("SFR_CALENDAR.YEAR","")
		else
			callpoint!.setColumnData("SFR_CALENDAR.PERIOD",first_date$(1,2))
			callpoint!.setColumnData("SFR_CALENDAR.YEAR",first_date$(7,4))
		endif
		if cvs(last_date$,2)="" then
			callpoint!.setColumnData("SFR_CALENDAR.PERIOD1","")
			callpoint!.setColumnData("SFR_CALENDAR.YEAR1","")
		else
			callpoint!.setColumnData("SFR_CALENDAR.PERIOD1",last_date$(1,2))
			callpoint!.setColumnData("SFR_CALENDAR.YEAR1",last_date$(7,4))
		endif
		callpoint!.setStatus("REFRESH")
	endif

[[SFR_CALENDAR.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



