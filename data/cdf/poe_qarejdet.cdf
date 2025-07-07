[[POE_QAREJDET.BSHO]]
rem --- open files

num_files=1
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="POC_REJCTCOD",open_opts$[1]="OTA"

gosub open_tables

[[POE_QAREJDET.REJECT_CODE.AVAL]]
rem --- Don't allow inactive code
	pocRejctCode_dev=fnget_dev("POC_REJCTCOD")
	dim pocRejctCode$:fnget_tpl$("POC_REJCTCOD")
	reject_code$=callpoint!.getUserInput()
	read record(pocRejctCode_dev,key=firm_id$+reject_code$,dom=*next)pocRejctCode$
	if pocRejctCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(pocRejctCode.reject_code$,3)
		msg_tokens$[2]=cvs(pocRejctCode.description$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



