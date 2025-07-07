[[IVT_LSTRANS.BSHO]]
rem --- Is Purchase Orders installed?
	call dir_pgm1$+"adc_application.aon","PO",info$[all]
	po$=info$[20]

rem --- Open/Lock Files
	if po$="Y" then
		num_files=1
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="POC_LINECODE",open_opts$[1]="OTA"

		gosub open_tables
	endif

[[IVT_LSTRANS.PO_LINE_CODE.AVAL]]
rem --- Don't allow inactive code
	pocLineCode_dev=fnget_dev("POC_LINECODE")
	dim pocLineCode$:fnget_tpl$("POC_LINECODE")
	po_line_code$=callpoint!.getUserInput()
	read record(pocLineCode_dev,key=firm_id$+po_line_code$,dom=*next)pocLineCode$
	if pocLineCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE_OK"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(pocLineCode.po_line_code$,3)
		msg_tokens$[2]=cvs(pocLineCode.code_desc$,3)
		gosub disp_message
		if msg_opt$="C" then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif



