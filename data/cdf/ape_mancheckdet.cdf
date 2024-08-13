[[APE_MANCHECKDET.ADEL]]
rem --- Recalc totals for header
	gosub calc_tots
	gosub disp_tots

[[APE_MANCHECKDET.ADGE]]
rem --- Enable/disable RET_FLAG column
	if user_tpl.ret_flag$="Y"
		callpoint!.setColumnEnabled(-1,"APE_MANCHECKDET.RETENTION",1)
	else
		callpoint!.setColumnEnabled(-1,"APE_MANCHECKDET.RETENTION",0)
	endif

[[APE_MANCHECKDET.AGCL]]
rem --- Set preset val for batch_no

	callpoint!.setTableColumnAttribute("APE_MANCHECKDET.BATCH_NO","PVAL",$22$+stbl("+BATCH_NO")+$22$)

[[APE_MANCHECKDET.AGDR]]
rem --- Enable/disable current INVOICE_DATE, AP_DIST_CODE and AP_INV_MEMO cells
	apt_invoicehdr_dev=fnget_dev("APT_INVOICEHDR")
	ap_type$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE")
	vendor_id$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID")
	invoice_no$=callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
	invoice_found=0
	find(apt_invoicehdr_dev,key=firm_id$+ap_type$+vendor_id$+invoice_no$, dom=*next); invoice_found=1

	if invoice_found then
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.INVOICE_DATE",0)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",0)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_INV_MEMO",0)
	else
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.INVOICE_DATE",1)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_INV_MEMO",1)
		if user_tpl.multi_dist$="Y"
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",1)
		else
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",0)
		endif
	endif

[[APE_MANCHECKDET.AGRE]]
gosub calc_tots
gosub disp_tots

[[APE_MANCHECKDET.AGRN]]
rem --- Enable Load Image and View Images options as needed

	curr_row=callpoint!.getValidationRow()
	rowstatus$ = callpoint!.getGridRowNewStatus(curr_row) + callpoint!.getGridRowModifyStatus(curr_row) + callpoint!.getGridRowDeleteStatus(curr_row)

    if  callpoint!.getDevObject("scan_docs_to")<>"NOT" and pos("Y"=rowstatus$)=0 then

		callpoint!.setOptionEnabled("VIMG",1)
		callpoint!.setOptionEnabled("LIMG",1)
	else
		
		callpoint!.setOptionEnabled("VIMG",0)
		callpoint!.setOptionEnabled("LIMG",0)
	endif
  

[[APE_MANCHECKDET.AOPT-LIMG]]
rem --- Select invoice image and upload for current grid row
	curr_row=callpoint!.getValidationRow()
	rowstatus$ = callpoint!.getGridRowNewStatus(curr_row) + callpoint!.getGridRowModifyStatus(curr_row) + callpoint!.getGridRowDeleteStatus(curr_row)

	if pos("Y" = rowstatus$) = 0 then 
		files=2
		dim channels[files],templates$[files]
		channels[1]=fnget_dev("APM_VENDMAST"),templates$[1]=fnget_tpl$("APM_VENDMAST")
		channels[2]=fnget_dev("APT_INVIMAGE"),templates$[2]=fnget_tpl$("APT_INVIMAGE")
		ap_type$ = callpoint!.getColumnData("APE_MANCHECKDET.AP_TYPE")
		vendor_id$ = callpoint!.getColumnData("APE_MANCHECKDET.VENDOR_ID")
		ap_inv_no$ = callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
		man_check$ ="Y"
		if callpoint!.getDevObject("scan_docs_to")<>"NOT" then
			scan_docs_to$=callpoint!.getDevObject("scan_docs_to")
		endif

		call "apc_imageupload.aon", channels[all],templates$[all],ap_type$,vendor_id$,ap_inv_no$,man_check$,scan_docs_to$,status
	endif

[[APE_MANCHECKDET.AOPT-OINV]]
rem -- Call inquiry program to view open invoices this vendor
rem -- only allow if trans_type is manual (vs reversal/void)
	trans_type$ = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.TRANS_TYPE")
	if trans_type$ = "M" then 
		ap_type$    = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE")
		vendor_id$  = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID")

		rem --- Select an open invoice
		if cvs(ap_type$, 2) <> "" and cvs(vendor_id$, 2) <> "" then

			dim filter_defs$[4,2]
			filter_defs$[1,0]="APT_INVOICEHDR.FIRM_ID"
			filter_defs$[1,1]="='"+firm_id$+"'"
			filter_defs$[1,2]="LOCK"
			filter_defs$[2,0]="APT_INVOICEHDR.AP_TYPE"
			filter_defs$[2,1]="='"+ap_type$+"'"
			filter_defs$[2,2]="LOCK"
			filter_defs$[3,0]="APT_INVOICEHDR.VENDOR_ID"
			filter_defs$[3,1]="='"+vendor_id$+"'"
			filter_defs$[3,2]="LOCK"
			filter_defs$[4,0]="APT_INVOICEHDR.INVOICE_BAL"
			filter_defs$[4,1]="<>0"
			filter_defs$[4,2]="LOCK"
			call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"APT_INVOICEHDR","BUILD",table_chans$[all],apt_invoicehdr_key$,filter_defs$[all]

			if apt_invoicehdr_key$ <>"" then
				apt01_dev = fnget_dev("APT_INVOICEHDR")
				dim apt01a$:fnget_tpl$("APT_INVOICEHDR")

				apt11_dev = fnget_dev("APT_INVOICEDET")
				dim apt11a$:fnget_tpl$("APT_INVOICEDET")

				ape22_dev1 = user_tpl.ape22_dev1
				dim ape22a$:fnget_tpl$("APE_MANCHECKDET")

				call stbl("+DIR_SYP")+"bac_key_template.bbj","APT_INVOICEHDR","PRIMARY",key_tpl$,rd_table_chans$[all],status$
				dim apt01_key$:key_tpl$

				call stbl("+DIR_SYP")+"bac_key_template.bbj","APE_MANCHECKDET","AO_VEND_INV",ape22_key1_tmpl$,table_chans$[all],status$
				dim ape22_key$:ape22_key1_tmpl$

				rem --- Process selected invoices
				detailRecWritten=0
				totalInvAmt=0
				totalDiscAmt=0
				totalRetAmt=0
				while len(apt_invoicehdr_key$)
					apt01_key$=apt_invoicehdr_key$(1,pos("^"=apt_invoicehdr_key$)-1)
					apt_invoicehdr_key$=apt_invoicehdr_key$(pos("^"=apt_invoicehdr_key$)+1)

					rem --- Warn if only one invoice per check allowed
					if callpoint!.getDevObject("oneInvPerChk")="Y" and detailRecWritten then
						msg_id$="AP_ONE_INV_PER_CHK"
						dim msg_tokens$[2]
						msg_tokens$[1]=cvs(ap_type$,2)
						msg_tokens$[2]=vendor_id$
						gosub disp_message

						rem --- Stop processing additional selected invoices
						break
					endif

					rem --- Is invoice already in check register?
					read record (apt01_dev, key=apt01_key$, dom=*continue) apt01a$
					if apt01a.selected_for_pay$="Y"
						msg_id$="AP_INV_ON_CHK_REGSTR"
						dim msg_tokens$[1]
						msg_tokens$[1]=cvs(apt01a.ap_inv_no$,2)
						gosub disp_message
						continue
					endif

					rem --- Is invoice on hold?
					if apt01a.hold_flag$ = "Y" then
						msg_id$="AP_INV_HOLD2"
						dim msg_tokens$[1]
						msg_tokens$[1]=cvs(apt01a.ap_inv_no$,2)
						gosub disp_message
						continue
					endif

					rem --- Is invoice already in ape_mancheckdet for a different check?
					read (ape22_dev1, key=firm_id$+apt01a.ap_type$+apt01a.vendor_id$+apt01a.ap_inv_no$, knum="AO_VEND_INV", dom=*next)
					ape22_key$ = key(ape22_dev1, end=*next)
					if pos(firm_id$+ap_type$+vendor_id$+apt01a.ap_inv_no$ = ape22_key$) = 1 and
:						ape22_key.bnk_acct_cd$+ape22_key.check_no$ <> callpoint!.getColumnData("APE_MANCHECKDET.BNK_ACCT_CD")+callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_NO")
:					then
						msg_id$="AP_INV_IN_MANCHCK"
						dim msg_tokens$[1]
						msg_tokens$[1]=cvs(apt01a.ap_inv_no$,2)
						gosub disp_message
						continue
					endif

					rem --- Is invoice already in the grid?
					recVect!=GridVect!.getItem(0)
					dim gridrec$:dtlg_param$[1,3]
					numrecs=recVect!.size()
					if numrecs>0
						for reccnt=0 to numrecs-1
							gridrec$=recVect!.getItem(reccnt)
							if gridrec.ap_inv_no$=apt01_key.ap_inv_no$ then
								msg_id$="AP_INV_IN_DTL_GRID"
								dim msg_tokens$[1]
								msg_tokens$[1]=cvs(apt01_key.ap_inv_no$,2)
								gosub disp_message
								continue
							endif
						next reccnt
					endif

					rem --- Verify the GL Cash Account for the invoice's Distribution Code matches the GLM_BANKMASTER GL Account for the BNK_ACCT_CD
					ap_inv_no$=apt01_key.ap_inv_no$
					ap_dist_code$=apt01a.ap_dist_code$
					gosub validateDistCd
					if badDistCd then continue

					rem --- Total open invoice amounts
					inv_amt    = num(apt01a.invoice_amt$)
					disc_amt   = num(apt01a.discount_amt$)
					ret_amt    = num(apt01a.retention$)

					apt11_key$=apt01_key$
					read(apt11_dev, key=apt11_key$, dom=*next)
					while 1
						read record(apt11_dev, end=*break) apt11a$
						if pos(apt11_key$ = apt11a$)<> 1 then break
						inv_amt  = inv_amt  + num(apt11a.trans_amt$)
						disc_amt = disc_amt + num(apt11a.trans_disc$)
						ret_amt  = ret_amt  + num(apt11a.trans_ret$)
					wend
					totalInvAmt=totalInvAmt+inv_amt
					totalDiscAmt=totalDiscAmt+disc_amt
					totalRetAmt=totalRetAmt+ret_amt

					rem --- Write ape_mancheckdet (ope-22) record
					redim ape22a$
					ape22a.firm_id$=firm_id$
					ape22a.ap_type$=ap_type$
					ape22a.bnk_acct_cd$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
					ape22a.check_no$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_NO")
					ape22a.vendor_id$=vendor_id$
					ape22a.ap_inv_no$=apt01a.ap_inv_no$
					ape22a.sequence_00$="00"
					ape22a.ap_dist_code$=apt01a.ap_dist_code$
					ape22a.invoice_date$=apt01a.invoice_date$
					ape22a.ap_inv_memo$=apt01a.ap_inv_memo$
					ape22a.invoice_amt=inv_amt
					ape22a.discount_amt=disc_amt
					ape22a.retention=ret_amt
					ape22a.net_paid_amt=inv_amt-disc_amt
					ape22a.batch_no$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BATCH_NO")
					ape22a$=field(ape22a$)
					writerecord(ape22_dev1)ape22a$
					detailRecWritten=1
				wend

				rem --- Write ape_mancheckhdr (ope-02) record
				if detailRecWritten then
					ape02_dev = fnget_dev("APE_MANCHECKHDR")
					dim ape02a$:fnget_tpl$("APE_MANCHECKHDR")
					ape02a.firm_id$=firm_id$
					ape02a.ap_type$=ap_type$
					ape02a.bnk_acct_cd$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
					ape02a.check_no$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_NO")
					ape02a.vendor_id$=vendor_id$
					ape02a.trans_type$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.TRANS_TYPE")
					ape02a.check_date$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_DATE")
					ape02a.vendor_name$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_NAME")
					ape02a.batch_no$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BATCH_NO")
					ape02a.retain_approvals$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.RETAIN_APPROVALS")
					ape02a$=field(ape02a$)
					writerecord(ape02_dev)ape02a$
					batch_key$=ape02a.firm_id$+ape02a.batch_no$+ape02a.ap_type$+ape02a.bnk_acct_cd$+
:						ape02a.check_no$+ape02a.vendor_id$
					extractrecord (ape02_dev, key=batch_key$)ape02a$; rem Advisory Locking
					callpoint!.setDevObject("updateDiskData","Y")

					rem --- Make sure all grid entries have been written to file.
					recVect!=GridVect!.getItem(0)
					dim gridrec$:dtlg_param$[1,3]
					numrecs=recVect!.size()
					if numrecs>0
						for reccnt=0 to numrecs-1
							gridrec$=recVect!.getItem(reccnt)
							if cvs(gridrec.ap_inv_no$,2)<>"" then
								gridrec$=field(gridrec$)
								writerecord(ape22_dev1)gridrec$
							endif
						next reccnt
					endif

					rem --- Refresh this updated Manual Check Entry
					gosub calc_tots
					tinv=tinv+totalInvAmt
					tdisc=tdisc+totalDiscAmt
					tret=tret+totalRetAmt
					gosub disp_tots

					callpoint!.setStatus("REFGRID")
				endif
			else
				rem --- Set focus on first cell of current row if Open Invoice lookup is aborted, i.e. nothing selected.
				callpoint!.setFocus(num(callpoint!.getValidationRow()),"APE_MANCHECKDET.AP_INV_NO",1)
				callpoint!.setStatus("ACTIVATE")
			endif
		else
			callpoint!.setMessage("AP_NO_TYPE_OR_VENDOR")
			callpoint!.setStatus("ABORT")
		endif
	else
		callpoint!.setMessage("AP_NO_INV_INQ")
		callpoint!.setStatus("ABORT")
	endif

[[APE_MANCHECKDET.AOPT-VIMG]]
rem --- Displaye invoice images
	curr_row=callpoint!.getValidationRow()
	rowstatus$ = callpoint!.getGridRowNewStatus(curr_row) + callpoint!.getGridRowModifyStatus(curr_row) + callpoint!.getGridRowDeleteStatus(curr_row)

	if pos("Y" = rowstatus$) = 0 then 
		ap_type$ = callpoint!.getColumnData("APE_MANCHECKDET.AP_TYPE")
		vendor_id$ = callpoint!.getColumnData("APE_MANCHECKDET.VENDOR_ID")
		ap_inv_no$ = callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")

		call stbl("+DIR_PGM")+"apc_imageviewer.aon", ap_type$, vendor_id$, ap_inv_no$, table_chans$[all], urls!

		if urls!.size()>0 then
			urlVect!=callpoint!.getDevObject("urlVect")
			for i=0 to urls!.size()-1
				thisURL$=urls!.getItem(i)
				urlVect!.add(thisURL$)
			next i
			callpoint!.setDevObject("urlVect",urlVect!)
		endif
	endif

[[APE_MANCHECKDET.AP_DIST_CODE.AVAL]]
rem --- Don't allow inactive code
	apcDistribution_dev=fnget_dev("APC_DISTRIBUTION")
	dim apcDistribution$:fnget_tpl$("APC_DISTRIBUTION")
	ap_dist_code$=callpoint!.getUserInput()
	read record(apcDistribution_dev,key=firm_id$+"B"+ap_dist_code$,dom=*next)apcDistribution$
	if apcDistribution.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcDistribution.ap_dist_code$,3)
		msg_tokens$[2]=cvs(apcDistribution.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Verify the GL Cash Account for the invoice's Distribution Code matches the GLM_BANKMASTER GL Account for the BNK_ACCT_CD
	ap_dist_code$=callpoint!.getUserInput()
	ap_in_no$=callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
	gosub validateDistCd
	if badDistCd then
		callpoint!.setStatus("ABORT")
		break
	endif

[[APE_MANCHECKDET.AP_INV_NO.AVAL]]
rem --- Skip AVAL if AP_INV_NO wasn't changed to avoid re-initializing INVOICE_AMT, etc.
	if callpoint!.getUserInput()=callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO") and
:		callpoint!.getGridRowNewStatus(callpoint!.getValidationRow())<>"Y" then break

rem --- Check to make sure Invoice isn't already in the grid

	this_inv$=callpoint!.getUserInput()
	this_row=callpoint!.getValidationRow()
	recVect!=GridVect!.getItem(0)
	dim gridrec$:dtlg_param$[1,3]
	numrecs=recVect!.size()
	break_out=0
	if numrecs>0
		for reccnt=0 to numrecs-1
			if reccnt=this_row then continue
			if callpoint!.getGridRowDeleteStatus(reccnt)="Y" then continue
			gridrec$=recVect!.getItem(reccnt)
			if cvs(gridrec$,3)<> ""
				if gridrec.ap_inv_no$=this_inv$
					msg_id$="AP_DUPE_INV"
					gosub disp_message
					callpoint!.setStatus("ABORT")
					break_out=1
					break
				endif
			endif
		next reccnt
	endif
	if break_out=1 break

rem --- Look for Open Invoice

	apt_invoicehdr_dev = fnget_dev("APT_INVOICEHDR")
	apt_invoicedet_dev = fnget_dev("APT_INVOICEDET")
	dim apt01a$:fnget_tpl$("APT_INVOICEHDR")
	dim apt11a$:fnget_tpl$("APT_INVOICEDET")

	inv_amt  = 0
	disc_amt = 0
	ret_amt  = 0

	ap_type$    = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE")
	batch_no$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BATCH_NO")
	vendor_id$  = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID")
	invoice_no$ = callpoint!.getUserInput()
	bnk_acct_cd$ = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
	check_no$   = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_NO")

	ape02_key$ = firm_id$ + batch_no$ + ap_type$ + bnk_acct_cd$ + check_no$ + vendor_id$
	apt01ak1$ = firm_id$ + ap_type$ + vendor_id$ + invoice_no$ 
	ape22_dev1 = user_tpl.ape22_dev1

	call stbl("+DIR_SYP")+"bac_key_template.bbj",
:		"APE_MANCHECKDET",
:		"AO_VEND_INV",
:		ape22_key1_tmpl$,
:		table_chans$[all],
:		status$

	read record (apt_invoicehdr_dev, key=apt01ak1$, dom=*next) apt01a$

	if pos(apt01ak1$ = apt01a$) = 1 then
	rem --- Open Invoice record found
		if apt01a.selected_for_pay$ = "Y" then
			msg_id$="AP_INV_ON_CHK_REGSTR"
			dim msg_tokens$[1]
			msg_tokens$[1]=apt01a.ap_inv_no$
			gosub disp_message
			callpoint!.setStatus("ABORT-RECORD:["+ape02_key$+"]")
			goto end_of_inv_aval
		endif

		if apt01a.hold_flag$ = "Y" then
			callpoint!.setMessage("AP_INV_HOLD")
			callpoint!.setStatus("ABORT-RECORD:["+ape02_key$+"]")
			goto end_of_inv_aval		
		endif

		rem --- Is invoice already in ape_mancheckdet?
		dim ape22_key$:ape22_key1_tmpl$
		read (ape22_dev1, key=firm_id$+ap_type$+vendor_id$+invoice_no$, knum="AO_VEND_INV", dom=*next)
		ape22_key$ = key(ape22_dev1, end=*next)
		if pos(firm_id$+ap_type$+vendor_id$+invoice_no$ = ape22_key$) = 1 and
:			ape22_key.bnk_acct_cd$+ape22_key.check_no$ <> bnk_acct_cd$+check_no$
:		then
			callpoint!.setMessage("AP_INV_IN_USE:Manual Check")
			callpoint!.setStatus("ABORT-RECORD:["+ape02_key$+"]")
			goto end_of_inv_aval
		endif

		rem --- Verify the GL Cash Account for the invoice's Distribution Code matches the GLM_BANKMASTER GL Account for the BNK_ACCT_CD
		ap_dist_code$=apt01a.ap_dist_code$
		ap_inv_no$=invoice_no$
		gosub validateDistCd
		if badDistCd then
			callpoint!.setStatus("ABORT")
			break
		endif

	rem --- Accumulate totals

		inv_amt  = num(apt01a.invoice_amt$)
		disc_amt = num(apt01a.discount_amt$)
		ret_amt  = num(apt01a.retention$)

		apt11ak1$=apt01a.firm_id$+apt01a.ap_type$+apt01a.vendor_id$+apt01a.ap_inv_no$

		more_dtl=1
		read (apt_invoicedet_dev, key=apt11ak1$, dom=*next)	
							
		while more_dtl
			read record (apt_invoicedet_dev, end=*break) apt11a$

			if pos(apt11ak1$ = apt11a$) = 1 then 
				inv_amt  = inv_amt  + num(apt11a.trans_amt$)
				disc_amt = disc_amt + num(apt11a.trans_disc$)
				ret_amt  = ret_amt  + num(apt11a.trans_ret$)			
			else
				more_dtl=0
			endif
		wend

		callpoint!.setColumnData("APE_MANCHECKDET.INVOICE_DATE",apt01a.invoice_date$)
		callpoint!.setColumnData("APE_MANCHECKDET.AP_DIST_CODE",apt01a.ap_dist_code$)
		callpoint!.setColumnData("APE_MANCHECKDET.AP_INV_MEMO",apt01a.ap_inv_memo$)

		if inv_amt=0
			callpoint!.setMessage("AP_INVOICE_PAID")
		endif

	rem --- Disable inv date/dist code/memo, leaving only inv amt/disc amt enabled for open invoice

		w!=Form!.getChildWindow(1109)
		c!=w!.getControl(5900)
		c!.startEdit(c!.getSelectedRow(),5)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.INVOICE_DATE",0)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",0)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_INV_MEMO",0)

	else

		rem --- Is invoice already in ape_mancheckdet?
		dim ape22_key$:ape22_key1_tmpl$
		read (ape22_dev1, key=firm_id$+ap_type$+vendor_id$+invoice_no$, knum="AO_VEND_INV", dom=*next)
		ape22_key$ = key(ape22_dev1, end=*next)
		if pos(firm_id$+ap_type$+vendor_id$+invoice_no$ = ape22_key$) = 1 and
:			ape22_key.bnk_acct_cd$+ape22_key.check_no$ <> bnk_acct_cd$+check_no$
:		then
			callpoint!.setMessage("AP_INV_IN_USE:Manual Check")
			callpoint!.setStatus("ABORT-RECORD:["+ape02_key$+"]")
			goto end_of_inv_aval
		endif

	rem --- Enable inv date/dist code/memo if on invoice not in open invoice file
	rem --- Also have user confirm that the invoice wasn't found in Open Invoice file

		msg_id$="AP_EXT_INV"
		gosub disp_message

		w!=Form!.getChildWindow(1109)
		c!=w!.getControl(5900)
		c!.startEdit(c!.getSelectedRow(),1)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.INVOICE_DATE",1)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_INV_MEMO",1)
		if user_tpl.multi_dist$="Y"
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",1)
		else
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",0)
		endif
		callpoint!.setColumnData("APE_MANCHECKDET.AP_DIST_CODE",user_tpl.dflt_dist_cd$,1)
		callpoint!.setColumnData("APE_MANCHECKDET.INVOICE_DATE",callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_DATE"),1)

		rem --- Verify the GL Cash Account for the invoice's Distribution Code matches the GLM_BANKMASTER GL Account for the BNK_ACCT_CD
		ap_dist_code$=user_tpl.dflt_dist_cd$
		ap_inv_no$=invoice_no$
		gosub validateDistCd
		if badDistCd then
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

	callpoint!.setColumnData("APE_MANCHECKDET.INVOICE_AMT",str(inv_amt))
	callpoint!.setColumnData("APE_MANCHECKDET.DISCOUNT_AMT",str(disc_amt))
	callpoint!.setColumnData("APE_MANCHECKDET.RETENTION",str(ret_amt))
	callpoint!.setColumnData("APE_MANCHECKDET.NET_PAID_AMT",str(inv_amt-disc_amt))

	callpoint!.setOptionEnabled("OINV",0)

	callpoint!.setStatus("MODIFIED-REFRESH")

end_of_inv_aval:

[[APE_MANCHECKDET.AP_INV_NO.BINP]]
rem --- Should Open Invoice button be enabled?
	trans_type$ = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.TRANS_TYPE")
	invoice_no$ = callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")

	if trans_type$ = "M" and cvs(invoice_no$, 2) = "" then
		callpoint!.setOptionEnabled("OINV",1)
	else
		callpoint!.setOptionEnabled("OINV",0)
	endif

rem --- Is only one invoice per check allowed?
	if cvs(invoice_no$, 2) = "" and callpoint!.getDevObject("oneInvPerChk")="Y" then
		recVect!=GridVect!.getItem(0)
		if recVect!.size()>1 then
			rem --- Disable Open Invoice button
			callpoint!.setOptionEnabled("OINV",0)

			rem --- Warn only one invoice allowed
			msg_id$="AP_ONE_INV_PER_CHK"
			dim msg_tokens$[2]
			msg_tokens$[1]=cvs(callpoint!.getColumnData("APE_MANCHECKDET.AP_TYPE"),2)
			msg_tokens$[2]=callpoint!.getColumnData("APE_MANCHECKDET.VENDOR_ID")
			gosub disp_message

			rem --- Set focus on 1st cell of 1st row
			callpoint!.setFocus(0,"APE_MANCHECKDET.AP_INV_NO",0)
		endif
	endif

[[APE_MANCHECKDET.AREC]]
rem --- Enable/disable RET_FLAG column
	if user_tpl.ret_flag$="Y"
		callpoint!.setColumnEnabled(-1,"APE_MANCHECKDET.RETENTION",1)
	else
		callpoint!.setColumnEnabled(-1,"APE_MANCHECKDET.RETENTION",0)
	endif

[[APE_MANCHECKDET.AUDE]]
rem --- Recalc totals for header
	gosub calc_tots
	gosub disp_tots

rem --- Enable/disable current INVOICE_DATE, AP_DIST_CODE and AP_INV_MEMO cells
	apt_invoicehdr_dev=fnget_dev("APT_INVOICEHDR")
	ap_type$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE")
	vendor_id$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID")
	invoice_no$=callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
	invoice_found=0
	find(apt_invoicehdr_dev,key=firm_id$+ap_type$+vendor_id$+invoice_no$, dom=*next); invoice_found=1

	if invoice_found then
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.INVOICE_DATE",0)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",0)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_INV_MEMO",0)
	else
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.INVOICE_DATE",1)
		callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_INV_MEMO",1)
		if user_tpl.multi_dist$="Y"
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",1)
		else
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"APE_MANCHECKDET.AP_DIST_CODE",0)
		endif
	endif

rem --- Enable/disable RET_FLAG column
	if user_tpl.ret_flag$="Y"
		callpoint!.setColumnEnabled(-1,"APE_MANCHECKDET.RETENTION",1)
	else
		callpoint!.setColumnEnabled(-1,"APE_MANCHECKDET.RETENTION",0)
	endif

[[APE_MANCHECKDET.BDEL]]
rem --- Remove associated data records
	if cvs(rec_data$,3)<>"" then
		rem --- Delete GL distribution records for selected invoice
		gosub delete_gldist
	
		rem --- Delete images for selected invoice ONLY if it's NOT in apt_invoicehdr (apt-01)
		apt_invoicehdr_dev = fnget_dev("APT_INVOICEHDR")
		dim apt01a$:fnget_tpl$("APT_INVOICEHDR")
	
		ap_type$    = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE")
		vendor_id$  = callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID")
		invoice_no$ = callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")

		apt01_key$ = firm_id$ + ap_type$ + vendor_id$ + invoice_no$ 
		read record (apt_invoicehdr_dev, key=apt01_key$, dom=*next) apt01a$

		if pos(apt01_key$ = apt01a$)<>1 then
			rem --- Historical Invoice record NOT found
			invimage_dev=fnget_dev("APT_INVIMAGE")

			invimage_trip$ = firm_id$ + vendor_id$ + invoice_no$
			read(invimage_dev,key=invimage_trip$,dom=*next)
			while 1
				invimage_key$=key(invimage_dev,end=*break)
				if pos(invimage_trip$=invimage_key$)<>1 then break
				remove(invimage_dev,key=invimage_key$)
			wend
		endif
	endif
	
	

[[APE_MANCHECKDET.BDGX]]
rem --- Disable buttons when going to header

	callpoint!.setOptionEnabled("OINV",0)
	callpoint!.setOptionEnabled("VIMG",0)
	callpoint!.setOptionEnabled("LIMG",0)

[[APE_MANCHECKDET.BGDS]]
rem --- Inits

	use ::ado_util.src::util
	use ::BBUtils.bbj::BBUtils


	

[[APE_MANCHECKDET.DISCOUNT_AMT.AVAL]]
rem --- Adjust Net Paid Amt for the Discount amount
disc_amt=num(callpoint!.getUserInput())
inv_amt=num(callpoint!.getColumnData("APE_MANCHECKDET.INVOICE_AMT"))
ret_amt=num(callpoint!.getColumnData("APE_MANCHECKDET.RETENTION"))
callpoint!.setColumnData("APE_MANCHECKDET.NET_PAID_AMT",str(inv_amt-disc_amt-ret_amt),1)

callpoint!.setDevObject("dist_amt",callpoint!.getColumnData("APE_MANCHECKDET.INVOICE_AMT"))
callpoint!.setDevObject("dflt_dist",user_tpl.dflt_dist_cd$)
callpoint!.setDevObject("dflt_gl",user_tpl.dflt_gl_account$)
callpoint!.setDevObject("tot_inv",callpoint!.getColumnData("APE_MANCHECKDET.INVOICE_AMT"))
callpoint!.setStatus("MODIFIED-REFRESH")

[[APE_MANCHECKDET.DISCOUNT_AMT.AVEC]]
gosub calc_tots
gosub disp_tots

[[APE_MANCHECKDET.INVOICE_AMT.AVAL]]
rem --- Adjust Net Paid Amt for the Discount amount
inv_amt=num(callpoint!.getUserInput())
disc_amt=num(callpoint!.getColumnData("APE_MANCHECKDET.DISCOUNT_AMT"))
ret_amt=num(callpoint!.getColumnData("APE_MANCHECKDET.RETENTION"))
callpoint!.setColumnData("APE_MANCHECKDET.NET_PAID_AMT",str(inv_amt-disc_amt-ret_amt),1)

callpoint!.setDevObject("dist_amt",callpoint!.getUserInput())
callpoint!.setDevObject("dflt_dist",user_tpl.dflt_dist_cd$)
callpoint!.setDevObject("dflt_gl",user_tpl.dflt_gl_account$)
callpoint!.setDevObject("tot_inv",callpoint!.getUserInput())

rem --- if invoice # isn't in open invoice file, invoke GL Dist grid
apt_invoicehdr_dev=fnget_dev("APT_INVOICEHDR")			
dim apt01a$:fnget_tpl$("APT_INVOICEHDR")
ap_type$=field(apt01a$,"AP_TYPE")
vendor_id$=field(apt01a$,"VENDOR_ID")
ap_type$(1)=UserObj!.getItem(num(user_tpl.ap_type_vpos$)).getText()
vendor_id$(1)=UserObj!.getItem(num(user_tpl.vendor_id_vpos$)).getText()

apt01ak1$=firm_id$+ap_type$+vendor_id$+callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")

readrecord(apt_invoicehdr_dev,key=apt01ak1$,dom=*next)apt01a$
if apt01a$(1,len(apt01ak1$))<>apt01ak1$ and num(callpoint!.getUserInput())<>0

	rem --- make sure fields (ap type, vendor ID, check#) needed to build GL Dist recs are present, and that AP type/Vendor go together
	dont_allow$=""	
	gosub validate_mandatory_data

	if dont_allow$="Y"
		msg_id$="AP_MANCHKWRITE"
		gosub disp_message
	else	
		rem --- Save current context so we'll know where to return from GL Dist
		declare BBjStandardGrid grid!
		grid! = util.getGrid(Form!)
		grid_ctx=grid!.getContextID()
		curr_row=grid!.getSelectedRow()
		curr_col=grid!.getSelectedColumn()
		rem --- invoke GL Dist form
		gosub get_gl_tots
		callpoint!.setDevObject("invoice_amt",callpoint!.getUserInput())
		user_id$=stbl("+USER_ID")
		dim dflt_data$[1,1]
		dflt_data$[1,0]="GL_ACCOUNT"
		dflt_data$[1,1]=user_tpl.dflt_gl_account$
		key_pfx$=callpoint!.getColumnData("APE_MANCHECKDET.FIRM_ID")+callpoint!.getColumnData("APE_MANCHECKDET.AP_TYPE")+
:			callpoint!.getColumnData("APE_MANCHECKDET.BNK_ACCT_CD")+callpoint!.getColumnData("APE_MANCHECKDET.CHECK_NO")+
:			callpoint!.getColumnData("APE_MANCHECKDET.VENDOR_ID")+callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
		callpoint!.setDevObject("key_pfx",key_pfx$)
		call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:			"APE_MANCHECKDIST",
:			user_id$,
:			"MNT",
:			key_pfx$,
:			table_chans$[all],
:			"",
:			dflt_data$[all]
		rem --- Reset focus on detail row where GL Dist was executed
		sysgui!.setContext(grid_ctx)
		grid!.startEdit(curr_row,curr_col)
		callpoint!.setStatus("ACTIVATE")
	endif	
endif
callpoint!.setStatus("MODIFIED-REFRESH")

[[APE_MANCHECKDET.INVOICE_AMT.AVEC]]
gosub calc_tots
gosub disp_tots

[[APE_MANCHECKDET.RETENTION.AVAL]]
rem --- Adjust Net Paid Amt for the Retention amount
	ret_amt=num(callpoint!.getUserInput())
	inv_amt=num(callpoint!.getColumnData("APE_MANCHECKDET.INVOICE_AMT"))
	disc_amt=num(callpoint!.getColumnData("APE_MANCHECKDET.DISCOUNT_AMT"))
	callpoint!.setColumnData("APE_MANCHECKDET.NET_PAID_AMT",str(inv_amt-disc_amt-ret_amt),1)

[[APE_MANCHECKDET.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon

calc_tots:
	recVect!=GridVect!.getItem(0)
	dim gridrec$:dtlg_param$[1,3]
	numrecs=recVect!.size()
	tinv=0,tdisc=0,tret=0
	if numrecs>0
		for reccnt=0 to numrecs-1			
				gridrec$=recVect!.getItem(reccnt)
				if cvs(gridrec$,3)<> "" and callpoint!.getGridRowDeleteStatus(reccnt)<>"Y" 
					tinv=tinv+num(gridrec.invoice_amt$)
					tdisc=tdisc+num(gridrec.discount_amt$)
					tret=tret+num(gridrec.retention$)
				endif
		next reccnt
	endif
return

disp_tots:
    rem --- get context and ID of display controls for totals, and redisplay w/ amts from calc_tots
    rem --- also setHeaderColumnData so Barista's values for these display controls will stay in sync
    
    tinv!=UserObj!.getItem(num(user_tpl.tinv_vpos$))
    tinv!.setValue(tinv)
    callpoint!.setHeaderColumnData("<<DISPLAY>>.DISP_TOT_INV",str(tinv))
    tdisc!=UserObj!.getItem(num(user_tpl.tdisc_vpos$))
    tdisc!.setValue(tdisc)
    callpoint!.setHeaderColumnData("<<DISPLAY>>.DISP_TOT_DISC",str(tdisc))
    tret!=UserObj!.getItem(num(user_tpl.tret_vpos$))
    tret!.setValue(tret)
    callpoint!.setHeaderColumnData("<<DISPLAY>>.DISP_TOT_RETEN",str(tret))
    tchk!=UserObj!.getItem(num(user_tpl.tchk_vpos$))
    tchk!.setValue(tinv-tdisc-tret)
    callpoint!.setHeaderColumnData("<<DISPLAY>>.DISP_TOT_CHECK",str(tinv-tdisc-tret))
return

get_gl_tots:
	ape12_dev=fnget_dev("APE_MANCHECKDIST")				
	dim ape12a$:fnget_tpl$("APE_MANCHECKDIST")
	amt_dist=0
	ape12ak1$=firm_id$+callpoint!.getColumnData("APE_MANCHECKDET.AP_TYPE")+callpoint!.getColumnData("APE_MANCHECKDET.BNK_ACCT_CD")+
:	callpoint!.getColumnData("APE_MANCHECKDET.CHECK_NO")+callpoint!.getColumnData("APE_MANCHECKDET.VENDOR_ID")+
:	callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
	read(ape12_dev,key=ape12ak1$,dom=*next)
	more_dtl=1
	while more_dtl
		read record(ape12_dev,end=*break)ape12a$
		if ape12a$(1,len(ape12ak1$))=ape12ak1$
			amt_dist=amt_dist+num(ape12a.gl_post_amt$)
		else
			more_dtl=0
		endif
	wend
	callpoint!.setDevObject("dist_amt",str(amt_dist))
return

delete_gldist:
	ape12_dev=fnget_dev("APE_MANCHECKDIST")
	dim ape12a$:fnget_tpl$("APE_MANCHECKDIST")
	remove_ky$=firm_id$+callpoint!.getColumnData("APE_MANCHECKDET.AP_TYPE") +
:		callpoint!.getColumnData("APE_MANCHECKDET.BNK_ACCT_CD") +
:		callpoint!.getColumnData("APE_MANCHECKDET.CHECK_NO") +
:		callpoint!.getColumnData("APE_MANCHECKDET.VENDOR_ID") +
:		callpoint!.getColumnData("APE_MANCHECKDET.AP_INV_NO")
	read (ape12_dev,key=remove_ky$,dom=*next)
	while 1
		k$=key(ape12_dev,end=*break)
		if pos(remove_ky$=k$)<>1 then break
		remove(ape12_dev,key=k$)
	wend
return

validate_mandatory_data:

	dont_allow$=""

	if cvs(callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_DATE"),3)="" or
:		cvs(callpoint!.getHeaderColumnData("APE_MANCHECKHDR.CHECK_NO"),3)="" or
:		cvs(callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID"),3)="" then dont_allow$="Y"

	vend_hist$=""
	tmp_vendor_id$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.VENDOR_ID")
	gosub get_vendor_history
	if vend_hist$<>"Y" then dont_allow$="Y"

return

get_vendor_history:
	apm02_dev=fnget_dev("APM_VENDHIST")				
	dim apm02a$:fnget_tpl$("APM_VENDHIST")
	vend_hist$=""
	readrecord(apm02_dev,key=firm_id$+tmp_vendor_id$+
:		callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE"),dom=*next)apm02a$
	if apm02a.firm_id$+apm02a.vendor_id$+apm02a.ap_type$=firm_id$+tmp_vendor_id$+
:		callpoint!.getHeaderColumnData("APE_MANCHECKHDR.AP_TYPE")
			vend_hist$="Y"
	endif
return

validateDistCd:
rem --- When AP uses GL, the GL Cash Account for the invoice's Distribution Code must match the 
rem --- GLM_BANKMASTER GL Account for the BNK_ACCT_CD
	badDistCd=0
	if user_tpl.glint$="Y" then
		apcDistribution_dev = fnget_dev("APC_DISTRIBUTION")
		dim apcDistribution$:fnget_tpl$("APC_DISTRIBUTION")
		apcDistribution.gl_cash_acct$=user_tpl.dflt_gl_account$
		readrecord(apcDistribution_dev,key=firm_id$+"B"+ap_dist_code$,dom=*next)apcDistribution$

		glm05_dev = fnget_dev("GLM_BANKMASTER")
		dim glm05a$:fnget_tpl$("GLM_BANKMASTER")
		readrecord(glm05_dev,key=firm_id$+apcDistribution.gl_cash_acct$,dom=*next)glm05a$

		bnkAcctCd$=callpoint!.getHeaderColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
		if cvs(bnkAcctCd$,2)<>cvs(glm05a.bnk_acct_cd$,2) then
			badDistCd=1
			call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
			msg_id$="AP_BAD_DIST_CD"
			dim msg_tokens$[4]
			msg_tokens$[1]=ap_dist_code$
			msg_tokens$[2]=fnmask$(apcDistribution.gl_cash_acct$(1,gl_size),m0$)
			msg_tokens$[3]=cvs(bnkAcctCd$,2)
			msg_tokens$[4]=cvs(ap_inv_no$,2)
			gosub disp_message
		endif
	endif
return



