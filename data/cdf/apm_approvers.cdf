[[APM_APPROVERS.ADIS]]
rem --- enable/disable according to authorization level

if num(callpoint!.getColumnData("APM_APPROVERS.PAYABLES_CLERK"))=1
	callpoint!.setColumnData("APM_APPROVERS.PRELIM_APPROVAL","0",1)
	callpoint!.setColumnData("APM_APPROVERS.CHECK_SIGNER","0",1)
	callpoint!.setColumnData("APM_APPROVERS.SIGNATURE_FILE","",1)
	callpoint!.setColumnData("APM_APPROVERS.LIMIT_AUTH","0",1)
	callpoint!.setColumnData("APM_APPROVERS.MAX_AUTH_AMT","",1)

	callpoint!.setColumnEnabled("APM_APPROVERS.PRELIM_APPROVAL",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.CHECK_SIGNER",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.SIGNATURE_FILE",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.LIMIT_AUTH",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.MAX_AUTH_AMT",0)
else
	callpoint!.setColumnEnabled("APM_APPROVERS.PRELIM_APPROVAL",1)
	callpoint!.setColumnEnabled("APM_APPROVERS.CHECK_SIGNER",1)
endif

rem --- Enable/disable REVIEW_APPROVE
	if num(callpoint!.getColumnData("APM_APPROVERS.PRELIM_APPROVAL")) and num(callpoint!.getColumnData("APM_APPROVERS.CHECK_SIGNER")) then
		callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",1)
	else
		callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",0)
		callpoint!.setColumnData("APM_APPROVERS.REVIEW_APPROVE","0",1)
	endif

[[APM_APPROVERS.AREC]]
rem --- Disable REVIEW_APPROVE for new records
	callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",0)
	callpoint!.setColumnData("APM_APPROVERS.REVIEW_APPROVE","0",1)

[[APM_APPROVERS.BSHO]]
rem --- Inits
	use java.io.File

rem --- Open/Lock files

	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APS_PARAMS",open_opts$[1]="OTA@"
	open_tables$[2]="APS_PAYAUTH",open_opts$[2]="OTA@"
	open_tables$[3]="ADM_USER",open_opts$[3]="OTA"

	gosub open_tables

	aps01_dev=num(open_chans$[1])
	payauth_dev=num(open_chans$[2])

	dim aps01a$:open_tpls$[1]
	dim payauth$:open_tpls$[2]

rem --- Retrieve parameter data
	aps01a_key$=firm_id$+"AP00"
	find record (aps01_dev,key=aps01a_key$,err=std_missing_params) aps01a$

rem --- Verify using Payment Authorization
	payauth_key$=aps01a_key$
	dim payauth$:fattr(payauth$)
	find record(payauth_dev,key=payauth_key$,dom=*next)payauth$
	if !payauth.use_pay_auth then
		callpoint!.setMessage("PAYAUTH_PARAM_ERR")
		callpoint!.setStatus("EXIT")
		break
	endif
	callpoint!.setDevObject("send_email",payauth.send_email$)

[[APM_APPROVERS.CHECK_SIGNER.AVAL]]
rem --- Enable/disable REVIEW_APPROVE
	if num(callpoint!.getUserInput()) and num(callpoint!.getColumnData("APM_APPROVERS.PRELIM_APPROVAL")) then
		callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",1)
	else
		callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",0)
		callpoint!.setColumnData("APM_APPROVERS.REVIEW_APPROVE","0",1)
	endif

[[APM_APPROVERS.PAYABLES_CLERK.AVAL]]
rem --- if selected, disable/clear other fields

if num(callpoint!.getUserInput())=1
	callpoint!.setColumnData("APM_APPROVERS.PRELIM_APPROVAL","0",1)
	callpoint!.setColumnData("APM_APPROVERS.CHECK_SIGNER","0",1)
	callpoint!.setColumnData("APM_APPROVERS.REVIEW_APPROVE","0",1)
	callpoint!.setColumnData("APM_APPROVERS.SIGNATURE_FILE","",1)
	callpoint!.setColumnData("APM_APPROVERS.LIMIT_AUTH","0",1)
	callpoint!.setColumnData("APM_APPROVERS.MAX_AUTH_AMT","",1)

	callpoint!.setColumnEnabled("APM_APPROVERS.PRELIM_APPROVAL",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.CHECK_SIGNER",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.SIGNATURE_FILE",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.LIMIT_AUTH",0)
	callpoint!.setColumnEnabled("APM_APPROVERS.MAX_AUTH_AMT",0)
else
	callpoint!.setColumnEnabled("APM_APPROVERS.PRELIM_APPROVAL",1)
	callpoint!.setColumnEnabled("APM_APPROVERS.CHECK_SIGNER",1)
endif

[[APM_APPROVERS.PRELIM_APPROVAL.AVAL]]
rem --- Enable/disable REVIEW_APPROVE
	if num(callpoint!.getUserInput()) and num(callpoint!.getColumnData("APM_APPROVERS.CHECK_SIGNER")) then
		callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",1)
	else
		callpoint!.setColumnEnabled("APM_APPROVERS.REVIEW_APPROVE",0)
		callpoint!.setColumnData("APM_APPROVERS.REVIEW_APPROVE","0",1)
	endif

[[APM_APPROVERS.SIGNATURE_FILE.AVAL]]
rem --- Verify signature file exists
	signature_file$=callpoint!.getUserInput()
	sigFile!=new File(signature_file$)
	if ! sigFile!.exists() or sigFile!.isDirectory() then
		msg_id$="AD_FILE_NOT_FOUND"
		dim msg_tokens$[1]
		msg_tokens$[1]=signature_file$
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[APM_APPROVERS.USER_ID.AVAL]]
rem --- User must have an email address when sending notification emails
	if num(callpoint!.getDevObject("send_email")) then
		admUser_dev=fnget_dev("ADM_USER")
		dim admUser$:fnget_tpl$("ADM_USER")
		user_id$=callpoint!.getUserInput()
		findrecord(admUser_dev,key=user_id$,dom=*next)admUser$
		if cvs(admUser.email_address$,2)="" then
			msg_id$="AD_EMAIL_ADDR_NEEDED"
			dim msg_tokens$[1]
			msg_tokens$[1]=cvs(user_id$,2)
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[APM_APPROVERS.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



