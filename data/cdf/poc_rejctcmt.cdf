[[POC_REJCTCMT.BSHO]]
rem - this is run by POC_REJCTCODE

[[POC_REJCTCMT.REJECT_CODE.AVAL]]
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



