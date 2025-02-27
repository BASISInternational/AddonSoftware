[[ADC_BANKACCTCODE.ABA_NO.AVAL]]
rem --- Bank routing number required for Checking and Savings accounts
	aba_no$=callpoint!.getUserInput()
	bnk_acct_type$=callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_TYPE")
	if pos(bnk_acct_type$="CS") and cvs(aba_no$,2)="" then
		msg_id$="AD_ABANO_REQ"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Bank routing number must be 9-digit number, or blank, and pass 371371371 checksum test
	if cvs(aba_no$,2)<>"" then
		abaNo=-1
		abaNo=num(aba_no$,err=*next)
		if abaNo<0 or len(aba_no$)<>9 then
			msg_id$="AD_9DIGIT_ABANO"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
		rem --- 371371371 checksum test
		dim digit[9]
		for i=1 to 9
			digit[i]=num(aba_no$(i,1))
		next i
		if mod(3*(digit[1]+digit[4]+digit[7])+7*(digit[2]+digit[5]+digit[8])+1*(digit[3]+digit[6]+digit[9]),10)<>0 then
			msg_id$="AD_BAD_ABANO"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[ADC_BANKACCTCODE.ADIS]]
rem --- display formatted bank acct number (using MICR font if loaded on the client)

		disp_acct$=cvs(callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_NO"),3)
		micr_acct$=cvs(callpoint!.getColumnData("ADC_BANKACCTCODE.MICR_ACCT"),3)
		gosub format_acct_no

rem --- Disable and clear NXT_CHECK_NO and PP_PGM if this is NOT a checking account
	if callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_TYPE")<>"C" then
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.NXT_CHECK_NO",0)
		callpoint!.setColumnData("ADC_BANKACCTCODE.NXT_CHECK_NO","",1)
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.PP_PGM",0)
		callpoint!.setColumnData("ADC_BANKACCTCODE.PP_PGM","",1)
	else
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.NXT_CHECK_NO",1)
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.PP_PGM",1)
	endif

[[ADC_BANKACCTCODE.AREC]]
rem --- init static text field that displays MICR

	micr_static_ctl!=Form!.getControl(num(callpoint!.getDevObject("micr_static_ctl")))
	micr_static_ctl!.setText("")

[[ADC_BANKACCTCODE.BDEL]]
rem --- Don’t allow deletinging BNK_ACCT_CD if currently in use in either APS_ACH or GLM_BANKMASTER (glm-05)
	bnk_acct_cd$=callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_CD")

	rem --- Check for using APS_ACH
	apsAch_dev=fnget_dev("APS_ACH")
	dim apsAch$:fnget_tpl$("APS_ACH")
	readrecord(apsAch_dev,key=firm_id$+"AP00",dom=*next)apsAch$
	if apsAch.bnk_acct_cd$=bnk_acct_cd$ then
		rem --- Cannot delete this Bank Account Code. It is currently used for ACH Payments in AP Parameters.
		msg_id$="AD_BNKACCTCD_ACH"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

	rem --- Check for using GLM_BANKMASTER (glm-05)
	bnkAcctCd_used=0
	glm05_dev=fnget_dev("GLM_BANKMASTER")
	dim glm05a$:fnget_tpl$("GLM_BANKMASTER")
	read(glm05_dev,key=firm_id$,dom=*next)
	while 1
		readrecord(glm05_dev,end=*next)glm05a$
		if glm05a.firm_id$<>firm_id$ then break
		if glm05a.bnk_acct_cd$<>bnk_acct_cd$ then continue
		bnkAcctCd_used=1
		break
	wend
	if bnkAcctCd_used then
		rem --- Cannot delete this Bank Account Code. It is currently used in Bank Reconciliation for account %1.
    		call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
		msg_id$="AD_BNKACCTCD_BNKREC"
		dim msg_tokens$[1]
		msg_tokens$[1]=fnmask$(glm05a.gl_account$(1,gl_size),m0$)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[ADC_BANKACCTCODE.BNK_ACCT_NO.AVAL]]
rem --- Bank account number required for Checking and Savings accounts
	bnk_acct_no$=callpoint!.getUserInput()
	bnk_acct_type$=callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_TYPE")
	if pos(bnk_acct_type$="CS") and cvs(bnk_acct_no$,2)="" then
		msg_id$="AD_BNKACCT_REQ"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

rem --- Bank account number must be a number with at least 4 digits, or blank
	if cvs(bnk_acct_no$,2)<>"" then
		bnkAcctNo=-1
		bnkAcctNo=num(bnk_acct_no$,err=*next)
		if bnkAcctNo<0 or len(bnk_acct_no$)<4 then
			msg_id$="AD_BNKACCT_NUM"
			gosub disp_message
			callpoint!.setStatus("ABORT")
		endif
	endif

rem --- Reset micr account format if bank account number has changed
	if cvs(bnk_acct_no$,3)<>cvs(callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_NO"),3)
		callpoint!.setColumnData("ADC_BANKACCTCODE.MICR_ACCT",fill(len(cvs(bnk_acct_no$,3)),"#"),1)
		callpoint!.setStatus("MODIFIED")
	endif

[[ADC_BANKACCTCODE.BNK_ACCT_TYPE.AVAL]]
rem --- Disable and clear NXT_CHECK_NO and PP_PGM if this is NOT a checking account
	if callpoint!.getUserInput()<>"C" then
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.NXT_CHECK_NO",0)
		callpoint!.setColumnData("ADC_BANKACCTCODE.NXT_CHECK_NO","",1)
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.PP_PGM",0)
		callpoint!.setColumnData("ADC_BANKACCTCODE.PP_PGM","",1)
	else
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.NXT_CHECK_NO",1)
		callpoint!.setColumnEnabled("ADC_BANKACCTCODE.PP_PGM",1)
	endif

[[ADC_BANKACCTCODE.BSHO]]
	use ::ado_util.src::util

rem --- Open tables
	num_files=2
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APS_ACH",open_opts$[1]="OTA"
	open_tables$[2]="GLM_BANKMASTER",   open_opts$[2]="OTA"
	gosub open_tables

rem --- Add static text to display MICR for bank acct number
	micr_acct!=fnget_control!("ADC_BANKACCTCODE.MICR_ACCT")
	micrx=micr_acct!.getX()
	micry=micr_acct!.getY()
	micr_height=micr_acct!.getHeight()
	micr_width=micr_acct!.getWidth()

	nxt_ctlID=util.getNextControlID()
	Form!.addStaticText(nxt_ctlID,micrx,micry+micr_height+5,micr_width,micr_height,"")
	callpoint!.setDevObject("micr_static_ctl",nxt_ctlID)
	micr_ctl!=Form!.getControl(nxt_ctlID)
	micr_ctl!.setFont(SysGUI!.makeFont("MICR Encoding",14,SysGUI!.PLAIN))

[[ADC_BANKACCTCODE.DAYS_LEAD.AVAL]]
rem --- The Days Lead must be a whole number between 0 and 9.
	days_lead$=callpoint!.getUserInput()
	if len(days_lead$)>1 or pos(days_lead$="0123456789",1)=0 then
		msg_id$="AD_DAYS_LEAD_0_9"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[ADC_BANKACCTCODE.MICR_ACCT.AVAL]]
rem --- sanity test input
rem --- micr_acct length needs to be at least as long as the decrypted bank account number
rem --- any character not a # must be space, or one of the MICR characters (should 0 thru 9 be allowed or only A,B,C,D?)

	bnk_acct_no$=cvs(callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_NO"),3)
	micr_acct$=callpoint!.getRawUserInput()
	micr_len=pos("#"=micr_acct$,1,0)
	mask = mask("","^[A-D#\ ]+$")

	disp_acct$=bnk_acct_no$
	if len(bnk_acct_no$)=micr_len and mask(micr_acct$)
		gosub format_acct_no
	else
		msg_id$="AD_BNKACCT_MICR"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[ADC_BANKACCTCODE.MICR_PRINT.AVAL]]
rem --- default micr_acct to a # for each character of bank account number

	if callpoint!.getUserInput()<>"Y"
		micr_static_ctl!=Form!.getControl(num(callpoint!.getDevObject("micr_static_ctl")))
		micr_static_ctl!.setText("")
	else
		if cvs(callpoint!.getColumnData("ADC_BANKACCTCODE.MICR_ACCT"),3)="" 
			bnk_acct_no$=cvs(callpoint!.getColumnData("ADC_BANKACCTCODE.BNK_ACCT_NO"),3)
			callpoint!.setColumnData("ADC_BANKACCTCODE.MICR_ACCT",pad(callpoint!.getColumnData("ADC_BANKACCTCODE.MICR_ACCT"),len(bnk_acct_no$),"#"),1)
		endif
	endif

[[ADC_BANKACCTCODE.PP_PGM.AVAL]]
rem --- Verify program exists
	pp_pgm$=cvs(callpoint!.getUserInput(),3)
	if pp_pgm$<>"" then
		pgmPath$=util.resolvePathStbls(pp_pgm$,err=*next)
		if pgmPath$="" then
			msg_id$="PROG_NOT_FOUND"
			dim msg_tokens$[1]
			msg_tokens$[1]=pp_pgm$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
		resolvedPgmPath$=BBjAPI().getFileSystem().resolvePath(pgmPath$,err=*next)
		if resolvedPgmPath$="" then
			msg_id$="PROG_NOT_FOUND"
			dim msg_tokens$[1]
			msg_tokens$[1]=pgmPath$
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

[[ADC_BANKACCTCODE.<CUSTOM>]]
rem ====================================================
format_acct_no:
rem --- send in bank_acct_no as disp_acct$ and the micr_acct$ formatting string; parse and display in static text
rem --- will display using MICR font, if present on client, otherwise just shows regular characters (0 - 9, A - D)

	micr_static_ctl!=Form!.getControl(num(callpoint!.getDevObject("micr_static_ctl")))
	if callpoint!.getColumnData("ADC_BANKACCTCODE.MICR_PRINT")="Y"
		cntr=1
		p=1
		while p
			p=pos("#"<>micr_acct$,1,cntr)
			if p<>0
				disp_acct$=disp_acct$(1,p-1)+micr_acct$(p,1)+disp_acct$(p)
				cntr=cntr+1
			endif
		wend
		micr_static_ctl!.setText(disp_acct$)
	else
		micr_static_ctl!.setText("")
	endif
	return


#include [+ADDON_LIB]fnget_control.src
#include [+ADDON_LIB]std_functions.aon



