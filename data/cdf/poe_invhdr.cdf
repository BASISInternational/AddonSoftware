[[POE_INVHDR.AABO]]
rem --- user has elected not to save record (we are NOT in immediate write, so save takes care of header and detail at once)
rem --- if rec_data$ is empty (i.e., new record never written), make sure no GL Dists are left orphaned (i.e., remove them)

if callpoint!.getRecordMode()="A"
	poe_invgl=fnget_dev("POE_INVGL")
	k$=""
	invgl_key$=callpoint!.getColumnData("POE_INVHDR.FIRM_ID")+
:		callpoint!.getColumnData("POE_INVHDR.AP_TYPE")+
:		callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")+
:		callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")

	read (poe_invgl,key=invgl_key$,dom=*next)
	while 1
		k$=key(poe_invgl,end=*break)
		if pos(invgl_key$=k$)<>1 then break
		remove (poe_invgl,key=k$)	
	wend	
endif

[[POE_INVHDR.ACCT_DATE.AVAL]]
rem make sure accting date is in an appropriate GL period
acctdate$=callpoint!.getUserInput()        
gl$=callpoint!.getDevObject("gl_int")
if gl$="Y" then
	call stbl("+DIR_PGM")+"glc_datecheck.aon",acctdate$,"Y",acctPer$,acctYr$,status
	if status>99
		callpoint!.setStatus("ABORT")
		break
	else
		callpoint!.setDevObject("gl_year",acctYr$)
		callpoint!.setDevObject("gl_per",acctPer$)
	endif
endif

rem --- Warn if the GL period for a Receipt Date is after the GL period for the Accounting Date
if gl$="Y" then
	dtlVect!=cast(BBjVector, GridVect!.getItem(0))
	rows=dtlVect!.size()
	if rows>0 then
		dim poe_invsel$:fnget_tpl$("POE_INVSEL")
		pot_rechdr_dev=fnget_dev("POT_RECHDR")
		dim pot_rechdr$:fnget_tpl$("POT_RECHDR")
		for row=0 to rows-1
			poe_invsel$=dtlVect!.getItem(row)
			po_no$=poe_invsel.po_no$
			receiver_no$=cvs(poe_invsel.receiver_no$,2)
			read(pot_rechdr_dev,key=firm_id$+po_no$+receiver_no$,knum="PRIMARY",dom=*next)pot_rechdr$
			while 1
				if receiver_no$="" then
					rem --- NOTE: A blank receiver means all receivers for the PO
					pot_rechdr_key$=key(pot_rechdr_dev,end=*break)
					if pos(firm_id$=pot_rechdr_key$)<>1 then break
					readrecord(pot_rechdr_dev)pot_rechdr$
						tmp_receiver_no$=pot04a$.receiver_no$
					else
						tmp_receiver_no$=receiver_no$
				endif

				recpt_date$=pot_rechdr.recpt_date$
				call pgmdir$+"adc_fiscalperyr.aon",firm_id$,recpt_date$,recptPer$,recptYr$,table_chans$[all],status
				if recptYr$+recptPer$>acctYr$+acctPer$ then
					msg_id$="PO_WARN_RECEIPT_DATE"
					dim msg_tokens$[4]
					msg_tokens$[1]=fndate$(acctdate$)
					msg_tokens$[2]=fndate$(recpt_date$)
					msg_tokens$[3]=po_no$
					msg_tokens$[4]=tmp_receiver_no$
					gosub disp_message
				endif

				if receiver_no$<>"" then break
			wend
		next row
	endif
endif

[[POE_INVHDR.ADEL]]
rem -- setting a delete flag so we know in BREX not to bother checking if out of balance

callpoint!.setDevObject("deleted","Y")

[[POE_INVHDR.ADIS]]
vendor_id$=callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")
gosub vendor_info
gosub disp_vendor_comments

rem --- get disc % assoc w/ terms in this rec, and disp distributed bal
apm10c_dev=fnget_dev("APC_TERMSCODE")
dim apm10c$:fnget_tpl$("APC_TERMSCODE")
ap_terms_code$ = callpoint!.getColumnData("POE_INVHDR.AP_TERMS_CODE")
while 1
	readrecord(apm10c_dev,key=firm_id$+"C"+ap_terms_code$,dom=*break)apm10c$
	callpoint!.setDevObject("disc_pct",apm10c.disc_percent$)
	callpoint!.setDevObject("inv_amt",callpoint!.getColumnData("POE_INVHDR.INVOICE_AMT"))
	callpoint!.setDevObject("tot_dist","")
	callpoint!.setDevObject("tot_gl","")
	gosub calc_gl_tots	
	gosub calc_grid_tots
	gosub disp_dist_bal
	vendor_id$ = callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")
	gosub disp_vendor_comments
	callpoint!.setStatus("REFRESH")
	break
wend

rem --- Is this a new invoice or an adjustment to an existing invoice?
ap_inv_no$=callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")
gosub invoiceOrAdjustment

rem --- Enable/disable cc_trans_date depending on whether or not creditcard_id is blank.
	if cvs(callpoint!.getColumnData("POE_INVHDR.CREDITCARD_ID"),2)="" then
		callpoint!.setColumnEnabled("POE_INVHDR.CC_TRANS_DATE",0)
	else
		callpoint!.setColumnEnabled("POE_INVHDR.CC_TRANS_DATE",1)
	endif

[[POE_INVHDR.AOPT-GDIS]]
pfx$=firm_id$+callpoint!.getColumnData("POE_INVHDR.AP_TYPE")+callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")+callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")
dim dflt_data$[3,1]
dflt_data$[1,0]="AP_TYPE"
dflt_data$[1,1]=callpoint!.getColumnData("POE_INVHDR.AP_TYPE")
dflt_data$[2,0]="VENDOR_ID"
dflt_data$[2,1]=callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")
dflt_data$[3,0]="AP_INV_NO"
dflt_data$[3,1]=callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")
call stbl("+DIR_SYP")+"bam_run_prog.bbj","POE_INVGL",stbl("+USER_ID"),"MNT",pfx$,table_chans$[all],"",dflt_data$[all]

gosub calc_gl_tots
gosub calc_grid_tots
gosub disp_dist_bal

[[POE_INVHDR.AOPT-INVD]]
rem --- Add Barista soft lock for this record if not already in edit mode
ap_type$=callpoint!.getColumnData("POE_INVHDR.AP_TYPE")
vendor_id$=callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")
ap_inv_no$=callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")

if !callpoint!.isEditMode() then
	rem --- Is there an existing soft lock?
	lock_table$="POE_INVHDR"
	lock_record$=firm_id$+ap_type$+vendor_id$+ap_inv_no$
	lock_type$="C"
	lock_status$=""
	lock_disp$=""
	call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	if lock_status$="" then
		rem --- Add temporary soft lock used just for this task
		lock_type$="L"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	else
		rem --- Record locked by someone else
		msg_id$="ENTRY_REC_LOCKED"
		gosub disp_message
		break
	endif
endif

rem --- Launch poe_invdet form
dist_bal=num(callpoint!.getColumnData("POE_INVHDR.INVOICE_AMT"))-num(callpoint!.getDevObject("tot_gl"))
callpoint!.setDevObject("invdet_bal",str(dist_bal));rem send in Invoice Header Amt - g/l amount

pfx$=firm_id$+ap_type$+vendor_id$+ap_inv_no$
dim dflt_data$[3,1]
dflt_data$[1,0]="AP_TYPE"
dflt_data$[1,1]=ap_type$
dflt_data$[2,0]="VENDOR_ID"
dflt_data$[2,1]=vendor_id$
dflt_data$[3,0]="AP_INV_NO"
dflt_data$[3,1]=ap_inv_no$
call stbl("+DIR_SYP")+"bam_run_prog.bbj","POE_INVDET",stbl("+USER_ID"),"MNT",pfx$,table_chans$[all],"",dflt_data$[all]

rem --- re-align invsel w/ invdet based on changes user may have made in invdet
rem --- corresponds to 6000 logic from old POE.EC

poe_invsel_dev=fnget_dev("POE_INVSEL")
poe_invdet_dev=fnget_dev("POE_INVDET")

dim poe_invsel$:fnget_tpl$("POE_INVSEL")
dim poe_invdet$:fnget_tpl$("POE_INVDET")

other=0
dim x$:str(callpoint!.getDevObject("poe_invsel_key"))
last$=""

tot_dist=0
ky$=firm_id$+ap_type$+vendor_id$+ap_inv_no$
read (poe_invsel_dev,key=ky$,dom=*next)
while 1
	read record (poe_invsel_dev,end=*break)poe_invsel$
	if pos(ky$=poe_invsel$)<>1 then break
	if cvs(poe_invsel.po_no$,3)="" then let x$=poe_invsel.firm_id$+poe_invsel.ap_type$+poe_invsel.vendor_id$+poe_invsel.ap_inv_no$+poe_invsel.line_no$
	tot_invsel=0,last$=poe_invsel.firm_id$+poe_invsel.ap_type$+poe_invsel.vendor_id$+poe_invsel.ap_inv_no$,last_seq$=poe_invsel.line_no$
	read (poe_invdet_dev,key=ky$,dom=*next)
	while 1
		read record (poe_invdet_dev,end=*break)poe_invdet$
		if pos(ky$=poe_invdet$)<>1 then break
		if cvs(poe_invdet.po_no$,3)="" then other=1; continue
		if poe_invdet.po_no$<>poe_invsel.po_no$ then continue
		if cvs(poe_invsel.receiver_no$,3)<>"" and poe_invsel.receiver_no$<>poe_invdet.receiver_no$ then continue
		tot_invsel=tot_invsel+round(num(poe_invdet.unit_cost$)*num(poe_invdet.qty_received$),2)
	wend
	poe_invsel.total_amount$=str(tot_invsel)
	poe_invsel$=field(poe_invsel$)
	write record (poe_invsel_dev)poe_invsel$
	tot_dist=tot_dist+tot_invsel
wend

if other
	tot_other=0
	read (poe_invdet_dev,key=ky$,dom=*next)
	while 1
		read record (poe_invdet_dev,end=*break)poe_invdet$
		if pos(ky$=poe_invdet$)<>1 then break
		if cvs(poe_invdet.po_no$,3)<>"" then continue
		tot_other=tot_other+num(poe_invdet.unit_cost$)
	wend
	dim poe_invsel$:fattr(poe_invsel$)
	if cvs(x$,3)="" then x$=last$+str(num(last_seq$)+1:"000")
	poe_invsel.firm_id$=x.firm_id$
	poe_invsel.ap_type$=x.ap_type$
	poe_invsel.vendor_id$=x.vendor_id$
	poe_invsel.ap_inv_no$=x.ap_inv_no$
	poe_invsel.line_no$=x.line_no$
	find record (poe_invsel_dev,key=x$,dom=*next)poe_invsel$
	poe_invsel.total_amount$=str(tot_other)
	poe_invsel$=field(poe_invsel$)
	write record (poe_invsel_dev)poe_invsel$
	tot_dist=tot_dist+tot_other
endif

callpoint!.setDevObject("tot_dist",str(tot_dist))
callpoint!.setStatus("RECORD:["+ky$+"]")

rem --- Remove temporary soft lock used just for this task 
if !callpoint!.isEditMode() and lock_type$="L" then
	lock_type$="U"
	call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
endif

[[POE_INVHDR.APFE]]
rem --- when re-entering primary form, enable GL button
rem --- only enable invoice detail button if we've already written some poe_invdet records
rem --- also re-initialize the "deleted" flag

if cvs(callpoint!.getColumnData("POE_INVHDR.AP_INV_NO"),2)<>"" and
:	num(callpoint!.getColumnData("POE_INVHDR.INVOICE_AMT"))<>0
	if callpoint!.getDevObject("gl_installed")="Y" and callpoint!.getDevObject("cash_basis")<>"Y"
		callpoint!.setOptionEnabled("GDIS",1)
	endif
endif

poe_invdet=fnget_dev("POE_INVDET")

k$=""
invdet_key$=callpoint!.getColumnData("POE_INVHDR.FIRM_ID")+callpoint!.getColumnData("POE_INVHDR.AP_TYPE")+
:	callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")+callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")


read (poe_invdet,key=invdet_key$,dom=*next)
k$=key(poe_invdet,end=*next)
if pos(invdet_key$=k$)=1
	callpoint!.setOptionEnabled("INVD",1)
else
	callpoint!.setOptionEnabled("INVD",0)
endif

callpoint!.setDevObject("deleted","")

[[POE_INVHDR.AP_DIST_CODE.AVAL]]
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

[[POE_INVHDR.AP_INV_NO.AVAL]]
rem --- Is this a new invoice or an adjustment to an existing invoice?
ap_inv_no$=callpoint!.getUserInput()
gosub invoiceOrAdjustment

[[POE_INVHDR.AP_TERMS_CODE.AVAL]]
rem --- Don't allow inactive code
	apcTermsCode_dev=fnget_dev("APC_TERMSCODE")
	dim apcTermsCode$:fnget_tpl$("APC_TERMSCODE")
	ap_terms_code$=callpoint!.getUserInput()
	read record(apcTermsCode_dev,key=firm_id$+"C"+ap_terms_code$,dom=*next)apcTermsCode$
	if apcTermsCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcTermsCode.terms_codeap$,3)
		msg_tokens$[2]=cvs(apcTermsCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem re-calc due and discount dates based on terms code
if callpoint!.getUserInput()<>callpoint!.getColumnData("POE_INVHDR.AP_TERMS_CODE")
	terms_cd$=callpoint!.getUserInput()	
	invdate$=callpoint!.getColumnData("POE_INVHDR.INV_DATE")
	tmp_inv_date$=callpoint!.getColumnData("POE_INVHDR.INV_DATE")
	gosub calculate_due_and_discount
	disc_amt=round(num(callpoint!.getColumnData("POE_INVHDR.NET_INV_AMT"))*(num(callpoint!.getDevObject("disc_pct"))/100),2)
	callpoint!.setColumnData("POE_INVHDR.DISCOUNT_AMT",str(disc_amt))
	callpoint!.setStatus("REFRESH")
endif

[[POE_INVHDR.AP_TYPE.AVAL]]
ap_type$=callpoint!.getUserInput()
if ap_type$=""
	ap_type$="  "
	callpoint!.setUserInput(ap_type$)
	callpoint!.setStatus("REFRESH")
endif

apm10_dev=fnget_dev("APC_TYPECODE")
dim apm10a$:fnget_tpl$("APC_TYPECODE")
readrecord (apm10_dev,key=firm_id$+"A"+ap_type$,dom=*next)apm10a$
if cvs(apm10a$,2)<>""
	callpoint!.setDevObject("dflt_dist_cd",apm10a.ap_dist_code$)
endif

rem --- Don't allow inactive code
	if apm10a.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apm10a.ap_type$,3)
		msg_tokens$[2]=cvs(apm10a.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_INVHDR.ARAR]]
if cvs(callpoint!.getColumnData("POE_INVHDR.AP_INV_NO"),2)<>""then
	if callpoint!.getDevObject("gl_installed")="Y" and callpoint!.getDevObject("cash_basis")<>"Y"
		callpoint!.setOptionEnabled("GDIS",1)
	endif
endif

[[POE_INVHDR.AREC]]
callpoint!.setColumnData("<<DISPLAY>>.comments","")
callpoint!.setDevObject("inv_amt","")
callpoint!.setDevObject("tot_dist","")
callpoint!.setDevObject("tot_gl","")
callpoint!.setColumnData("<<DISPLAY>>.DIST_BAL","0")
rem --- Re-enable disabled fields
callpoint!.setColumnEnabled("POE_INVHDR.INV_DATE",1)
callpoint!.setColumnEnabled("POE_INVHDR.NET_INV_AMT",1)
callpoint!.setColumnEnabled("POE_INVHDR.CC_TRANS_DATE",0)
rem --- disable opt buttons
callpoint!.setOptionEnabled("INVD",0)
callpoint!.setOptionEnabled("GDIS",0)

rem --- Clear inv_adj_label
Form!.getControl(num(callpoint!.getDevObject("inv_adj_label"))).setText("")

[[POE_INVHDR.ARNF]]
rem --- set defaults

terms_cd$=callpoint!.getDevObject("dflt_terms_cd")
invdate$=stbl("+SYSTEM_DATE")
tmp_inv_date$=callpoint!.getColumnData("POE_INVHDR.INV_DATE")
gosub calculate_due_and_discount
callpoint!.setColumnData("POE_INVHDR.AP_DIST_CODE",str(callpoint!.getDevObject("dflt_dist_cd")))
callpoint!.setColumnData("POE_INVHDR.AP_TERMS_CODE",str(callpoint!.getDevObject("dflt_terms_cd")))
callpoint!.setColumnData("POE_INVHDR.PAYMENT_GRP",str(callpoint!.getDevObject("dflt_pymt_grp")))
callpoint!.setColumnData("POE_INVHDR.INV_DATE",stbl("+SYSTEM_DATE"))

if cvs(str(callpoint!.getDevObject("dflt_acct_date")),2)<>""
	callpoint!.setColumnData("POE_INVHDR.ACCT_DATE",str(callpoint!.getDevObject("dflt_acct_date")))
else
	callpoint!.setColumnData("POE_INVHDR.ACCT_DATE",stbl("+SYSTEM_DATE"))
endif
callpoint!.setColumnData("POE_INVHDR.HOLD_FLAG","N")

callpoint!.setStatus("REFRESH")

[[POE_INVHDR.ASHO]]
rem --- get default date
call stbl("+DIR_SYP")+"bam_run_prog.bbj","POE_INVDATE",stbl("+USER_ID"),"MNT","",table_chans$[all]
callpoint!.setDevObject("dflt_acct_date",stbl("DEF_ACCT_DATE"))

[[POE_INVHDR.ASIZ]]
rem --- Resize vendor  comments box (display only) to align w/ Invoice Comments (memo_1024)

	cmts!=callpoint!.getControl("<<DISPLAY>>.COMMENTS")
	memo!=callpoint!.getControl("POE_INVHDR.MEMO_1024")
	cmts!.setSize(memo!.getWidth(),cmts!.getHeight())

[[POE_INVHDR.AWRI]]
rem --- look thru gridVect for any rows we've deleted from invsel... delete corres rows from invdet

if gridVect!.size()

	poe_invdet_dev=fnget_dev("POE_INVDET")
	dim poe_invdet$:fnget_tpl$("POE_INVDET")
	recs!=gridVect!.getItem(0)
	dim poe_invsel$:dtlg_param$[1,3]
	if recs!.size()
		for x=0 to recs!.size()-1
			if callpoint!.getGridRowDeleteStatus(x)="Y"
				poe_invsel$=recs!.getItem(x)
				read (poe_invdet_dev,key=poe_invsel.firm_id$+poe_invsel.ap_type$+poe_invsel.vendor_id$+poe_invsel.ap_inv_no$,dom=*next)
				while 1
					read record (poe_invdet_dev,end=*break)poe_invdet$
					if pos(poe_invsel.firm_id$+poe_invsel.ap_type$+poe_invsel.vendor_id$+poe_invsel.ap_inv_no$=poe_invdet$)<>1 then break
					if poe_invsel.po_no$<>poe_invdet.po_no$ then continue
					if cvs(poe_invsel.receiver_no$,3)<>"" and poe_invsel.receiver_no$<>poe_invdet.receiver_no$ then continue
					remove (poe_invdet_dev,key=poe_invdet.firm_id$+poe_invdet.ap_type$+poe_invdet.vendor_id$+poe_invdet.ap_inv_no$+poe_invdet.line_no$,dom=*next)
				wend
			endif
		next x
	endif
endif

if callpoint!.getDevObject("gl_installed")="Y"
	callpoint!.setOptionEnabled("INVD",1)
	if callpoint!.getDevObject("cash_basis")<>"Y"
		callpoint!.setOptionEnabled("GDIS",1)
	endif
endif

rem --- also need final check of balance -- invoice amt - invsel amt - gl dist amt (invsel should already equal invdet)

if num(callpoint!.getColumnData("<<DISPLAY>>.DIST_BAL"))<>0
	msg_id$="PO_INV_NOT_DIST"
	gosub disp_message

endif

[[POE_INVHDR.BPFX]]
callpoint!.setOptionEnabled("INVD",0)
callpoint!.setOptionEnabled("GDIS",0)

[[POE_INVHDR.BREX]]
rem --- also need final check of balance -- invoice amt - invsel amt - gl dist amt (invsel should already equal invdet)

if callpoint!.getDevObject("deleted")<>"Y"
	gosub disp_dist_bal
	if num(callpoint!.getColumnData("<<DISPLAY>>.DIST_BAL"))<>0
		msg_id$="PO_INV_NOT_DIST"
		gosub disp_message

	endif
endif

[[POE_INVHDR.BSHO]]
rem --- add static label for displaying date/amount if pulling up open invoice
inv_no!=fnget_control!("POE_INVHDR.AP_INV_NO")
inv_no_x=inv_no!.getX()
inv_no_y=inv_no!.getY()
inv_no_height=inv_no!.getHeight()
inv_no_width=inv_no!.getWidth()
nxt_ctlID=num(stbl("+CUSTOM_CTL",err=std_error))
x$=stbl("+CUSTOM_CTL",str(nxt_ctlID+1))
Form!.addStaticText(nxt_ctlID,inv_no_x+inv_no_width+25,inv_no_y,inv_no_width,inv_no_height,"")
callpoint!.setDevObject("inv_adj_label",str(nxt_ctlID))

rem --- add the display control holding the distribution balance to devObject
dist_bal!=fnget_control!("<<DISPLAY>>.DIST_BAL")
callpoint!.setDevObject("dist_bal_control",dist_bal!)

rem --- may need to disable some ctls based on params
if callpoint!.getDevObject("multi_types")="N" 
	callpoint!.setColumnEnabled("POE_INVHDR.AP_TYPE",-1)
endif
if callpoint!.getDevObject("multi_dist")="N" 
	callpoint!.setColumnEnabled("POE_INVHDR.AP_DIST_CODE",-1)
endif
if callpoint!.getDevObject("retention")="N" 
	callpoint!.setColumnEnabled("POE_INVHDR.RETENTION",-1)
endif
callpoint!.setOptionEnabled("INVD",0)
callpoint!.setOptionEnabled("GDIS",0)
callpoint!.setOptionEnabled("INVB",0)

[[POE_INVHDR.BTBL]]
rem --- Open/Lock files
files=24,begfile=1,endfile=files
dim files$[files],options$[files],chans$[files],templates$[files]

files$[1]="APC_DISTRIBUTION",options$[1]="OTA"
files$[2]="APM_VENDMAST",options$[2]="OTA"
files$[3]="APM_VENDHIST",options$[3]="OTA"
files$[4]="APS_PARAMS",options$[4]="OTA"
files$[5]="GLS_PARAMS",options$[5]="OTA"
files$[6]="POS_PARAMS",options$[6]="OTA"
files$[7]="IVS_PARAMS",options$[7]="OTA"
files$[8]="POE_POHDR",options$[8]="OTA"
files$[9]="POE_PODET",options$[9]="OTA"
files$[10]="POT_RECHDR",options$[10]="OTA"
files$[11]="POT_RECDET",options$[11]="OTA"
files$[12]="APT_INVOICEHDR",options$[12]="OTA"
files$[13]="IVM_ITEMMAST",options$[13]="OTA"
files$[14]="POC_LINECODE",options$[14]="OTA"
files$[15]="APC_TERMSCODE",options$[15]="OTA"
files$[16]="APC_TYPECODE",options$[16]="OTA"
files$[17]="GLS_CALENDAR",options$[17]="OTA"
files$[18]="POT_INVDET",options$[18]="OTA"
files$[19]="APM_CCVEND",options$[19]="OTA"
files$[20]="APE_INVOICEHDR",options$[20]="OTA"
files$[21]="APE_CHECKS",options$[21]="OTA"
files$[22]="APE_MANCHECKDET",options$[22]="OTA"
files$[23]="APC_PAYMENTGROUP",options$[23]="OTA"
files$[24]="POE_RECHDR",options$[24]="OTA"

call stbl("+DIR_SYP")+"bac_open_tables.bbj",
:	begfile,
:	endfile,
:	files$[all],
:	options$[all],
:	chans$[all],
:	templates$[all],
:	table_chans$[all],
:	batch,
:	status$

if status$<>"" then
	remove_process_bar:
	bbjAPI!=bbjAPI()
	rdFuncSpace!=bbjAPI!.getGroupNamespace()
	rdFuncSpace!.setValue("+build_task","OFF")
	release
endif

aps01_dev=num(chans$[4])
gls01_dev=num(chans$[5])
pos01_dev=num(chans$[6])
ivs01_dev=num(chans$[7])
gls_calendar_dev=num(chans$[17])

dim aps01a$:templates$[4],gls01a$:templates$[5],pos01a$:templates$[6],ivs01a$:templates$[7]
dim gls_calendar$:templates$[17]

rem --- Additional File Opens
gl$="N"
status=0
source$=pgm(-2)
call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,source$,"PO",glw11$,gl$,status
if status<>0 goto std_exit
callpoint!.setDevObject("gl_int",gl$)
callpoint!.setDevObject("glworkfile",glw11$)
if gl$="Y"
   files=2,begfile=1,endfile=2
   dim files$[files],options$[files],chans$[files],templates$[files]
   files$[1]="GLM_ACCT",options$[1]="OTA";rem --- "glm-01"
   files$[2]=glw11$,options$[2]="OTAS";rem --- s means no err if tmplt not found
	call stbl("+DIR_SYP")+"bac_open_tables.bbj",
:	begfile,
:	endfile,
:	files$[all],
:	options$[all],
:	chans$[all],
:	templates$[all],
:	table_chans$[all],
:	batch,
:	status$
	if status$<>"" then
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif
endif

rem --- check to see if main AP param rec (firm/AP/00) exists; if not, tell user to set it up first
aps01a_key$=firm_id$+"AP00"
find record (aps01_dev,key=aps01a_key$,err=*next) aps01a$
if cvs(aps01a.current_per$,2)=""
	msg_id$="AP_PARAM_ERR"
	dim msg_tokens$[1]
	msg_opt$=""
	gosub disp_message
	gosub remove_process_bar
	release
endif

callpoint!.setDevObject("multi_types",aps01a.multi_types$)
callpoint!.setDevObject("multi_dist",aps01a.multi_dist$)
callpoint!.setDevObject("dflt_dist_cd", aps01a.ap_dist_code$)
callpoint!.setDevObject("retention",aps01a.ret_flag$)
callpoint!.setDevObject("cash_basis",aps01a.cash_basis$)

rem --- See if GL is installed or linked to PO
	read record(pos01_dev,key=firm_id$+"PO00",dom=*next)pos01a$
	call stbl("+DIR_PGM")+"adc_application.aon","GL",info$[all]
	if info$[20]="N" or pos01a.post_to_gl$<>"Y"
		callpoint!.setDevObject("gl_installed","N")
	else
		callpoint!.setDevObject("gl_installed","Y")
	endif

rem --- check to see if main GL param rec (firm/GL/00) exists; if not, tell user to set it up first
	gls01a_key$=firm_id$+"GL00"
	find record (gls01_dev,key=gls01a_key$,err=*next) gls01a$
	if cvs(gls01a.current_per$,2)=""
		msg_id$="GL_PARAM_ERR"
		dim msg_tokens$[1]
		msg_opt$=""
		gosub disp_message
		gosub remove_process_bar
		release
	endif
	find record (gls_calendar_dev,key=firm_id$+gls01a.current_year$,err=*next) gls_calendar$

	callpoint!.setDevObject("units_flag",gls01a.units_flag$)
	callpoint!.setDevObject("gl_year",gls01a.current_year$)
	callpoint!.setDevObject("gl_per",gls01a.current_per$)
	callpoint!.setDevObject("gl_tot_pers",gls_calendar.total_pers$)

call stbl("+DIR_SYP")+"bac_key_template.bbj","POE_INVSEL","PRIMARY",poe_invsel_key_tpl$,table_chans$[all],status$
callpoint!.setDevObject("poe_invsel_key",poe_invsel_key_tpl$)

if aps01a.multi_types$<>"Y"
	callpoint!.setTableColumnAttribute("POE_INVHDR.AP_TYPE","PVAL",$22$+aps01a.ap_type$+$22$)

	rem --- get default distribution code	
	apc_typecode_dev=fnget_dev("APC_TYPECODE")
	dim apc_typecode$:fnget_tpl$("APC_TYPECODE")
	find record (apc_typecode_dev,key=firm_id$+"A"+aps01a.ap_type$,err=*next)apc_typecode$
	if cvs(apc_typecode$,2)<>""
		callpoint!.setDevObject("dflt_dist_cd", apc_typecode.ap_dist_code$)
	endif

	rem --- if not using multi distribution codes, initialize and disable Distribution Code
	if aps01a.multi_dist$<>"Y"
		callpoint!.setTableColumnAttribute("POE_INVHDR.AP_DIST_CODE","PVAL",$22$+apc_typecode.ap_dist_code$+$22$)
	endif
endif

[[POE_INVHDR.BWRI]]
rem --- re-check acct date
gl$=callpoint!.getDevObject("gl_int")
status=0
acctdate$=callpoint!.getColumnData("POE_INVHDR.ACCT_DATE")  
if gl$="Y" 
	call stbl("+DIR_PGM")+"glc_datecheck.aon",acctdate$,"Y",per$,yr$,status
	if status>99
		callpoint!.setStatus("ABORT")
	endif
endif

rem --- check vend hist file to be sure this vendor/ap type ok together; also make sure all key fields are entered

dont_write$=""

if cvs(callpoint!.getColumnData("POE_INVHDR.VENDOR_ID"),3)="" or
:	cvs(callpoint!.getColumnData("POE_INVHDR.AP_INV_NO"),3)="" then dont_write$="Y"

vendor_id$ = callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")
ap_type$=callpoint!.getColumnData("POE_INVHDR.AP_TYPE")
gosub get_vendor_history
if vend_hist$="" and callpoint!.getDevObject("multi_types")="Y" then dont_write$="Y"

if dont_write$="Y"
	msg_id$="AP_INVOICEWRITE"
	gosub disp_message
	callpoint!.setStatus("ABORT")
endif

[[POE_INVHDR.CREDITCARD_ID.AVAL]]
rem --- Skip if CREDITCARD_ID wasn't changed
	ccID$=callpoint!.getUserInput()
	if cvs(ccID$,2)=cvs(callpoint!.getDevObject("prior_CcID"),2) then break
	callpoint!.setStatus("MODIFIED")

rem --- Entered CREDITCARD_ID cannot be inactive.
	if cvs(ccID$,2)<>"" then
		apmCcVend_dev=fnget_dev("APM_CCVEND")
		dim apmCcVend$:fnget_tpl$("APM_CCVEND")
		findrecord(apmCcVend_dev,key=firm_id$+ccID$)apmCcVend$
		if apmCcVend.code_inactive$="Y" then
			msg_id$="AD_CODE_INACTIVE"
			dim msg_tokens$[2]
			msg_tokens$[1]=cvs(ccID$,2)
			msg_tokens$[2]=cvs(apmCcVend.cc_desc$,2)
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem ---  Do NOT allow the AP_INV_NO if it already exists for the CREDITCARD_ID's Credit Card Vendor.
	if cvs(ccID$,2)<>"" then
		apmCcVend_dev=fnget_dev("APM_CCVEND")
		dim apmCcVend$:fnget_tpl$("APM_CCVEND")
		findrecord(apmCcVend_dev,key=firm_id$+ccID$)apmCcVend$
		cc_aptype$=apmCcVend.cc_aptype$
		cc_vendor$=apmCcVend.cc_vendor$

		rem --- Check POE_INVHDR
		ap_inv_no$=callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")
		poeInvHdr_dev=fnget_dev("POE_INVHDR")
		foundInvoice=0
		read(poeInvHdr_dev,key=firm_id$+cc_aptype$+cc_vendor$+ap_inv_no$,dom=*next); foundInvoice=1
		if foundInvoice then
			msg_id$="AP_CC_INV_USED"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(ap_inv_no$,2)
			msg_tokens$[2]=cvs(cc_vendor$,2)
			msg_tokens$[3]=Translate!.getTranslation("DDM_TABLES-POE_INVHDR-DD_ATTR_WINT")
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Check APE_INVOICEHDR
		apeInvoiceHdr_dev=fnget_dev("APE_INVOICEHDR")
		foundInvoice=0
		read(apeInvoiceHdr_dev,key=firm_id$+cc_aptype$+cc_vendor$+ap_inv_no$,knum="PRIMARY",dom=*next); foundInvoice=1
		if foundInvoice then
			msg_id$="AP_CC_INV_USED"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(ap_inv_no$,2)
			msg_tokens$[2]=cvs(cc_vendor$,2)
			msg_tokens$[3]=Translate!.getTranslation("DDM_TABLES-APE_INVOICEHDR-DD_ATTR_WINT")
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Check APE_CHECKS
		apeChecks_dev=fnget_dev("APE_CHECKS")
		foundInvoice=0
		read(apeChecks_dev,key=firm_id$+cc_aptype$+cc_vendor$+ap_inv_no$,dom=*next); foundInvoice=1
		if foundInvoice then
			msg_id$="AP_CC_INV_USED"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(ap_inv_no$,2)
			msg_tokens$[2]=cvs(cc_vendor$,2)
			msg_tokens$[3]=Translate!.getTranslation("AON_CHECK")
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Check APE_MANCHECKDET
		apeManCheckDet_dev=fnget_dev("APE_MANCHECKDET")
		read(apeManCheckDet_dev,key=firm_id$+cc_aptype$+cc_vendor$+ap_inv_no$,knum="AO_VEND_INV",dom=*next)
		apeManCheckDet_key$=key(apeManCheckDet_dev,end=*next)
		if pos(firm_id$+cc_aptype$+cc_vendor$+ap_inv_no$=apeManCheckDet_key$)=1 then
			msg_id$="AP_CC_INV_USED"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(ap_inv_no$,2)
			msg_tokens$[2]=cvs(cc_vendor$,2)
			msg_tokens$[3]=Translate!.getTranslation("AON_MANUAL_CHECK")
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Check APT_INVOICEHDR
		aptInvoiceHdr_dev=fnget_dev("APT_INVOICEHDR")
		dim aptInvoiceHdr$:fnget_tpl$("APT_INVOICEHDR")
		foundInvoice=0
		read(aptInvoiceHdr_dev,key=firm_id$+cc_aptype$+cc_vendor$+ap_inv_no$,dom=*next)aptInvoiceHdr$; foundInvoice=1
		if foundInvoice then
			msg_id$="AP_CC_INV_USED"
			dim msg_tokens$[3]
			msg_tokens$[1]=cvs(ap_inv_no$,2)
			msg_tokens$[2]=cvs(cc_vendor$,2)
			if aptInvoiceHdr.invoice_bal=0 then
				msg_tokens$[3]=Translate!.getTranslation("AON_INVOICE_HISTORY")
			else
				msg_tokens$[3]=Translate!.getTranslation("AON_CHECK")
			endif
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- Enable/disable cc_trans_date depending on whether or not creditcard_id is blank.
	if cvs(ccID$,2)="" then
		callpoint!.setColumnEnabled("POE_INVHDR.CC_TRANS_DATE",0)
		callpoint!.setColumnData("POE_INVHDR.CC_TRANS_DATE","",1)
	else
		callpoint!.setColumnEnabled("POE_INVHDR.CC_TRANS_DATE",1)
		if cvs(callpoint!.getColumnData("POE_INVHDR.CC_TRANS_DATE"),2)="" then
			invoice_date$=callpoint!.getColumnData("POE_INVHDR.INV_DATE")
			callpoint!.setColumnData("POE_INVHDR.CC_TRANS_DATE",invoice_date$,1)
		endif
	endif

[[POE_INVHDR.CREDITCARD_ID.BINP]]
rem --- Capture starting/current creditcard_id
	callpoint!.setDevObject("prior_CcID",callpoint!.getColumnData("POE_INVHDR.CREDITCARD_ID"))

[[POE_INVHDR.CREDITCARD_ID.BINQ]]
rem --- In lookup only show CREDITCARD_IDs that are active.
	dim filter_defs$[1,2]
	filter_defs$[0,0]="POE_INVHDR.FIRM_ID"
	filter_defs$[0,1]="='"+firm_id$+"'"
	filter_defs$[0,2]="LOCK"

	call STBL("+DIR_SYP")+"bax_query.bbj",
:		gui_dev, 
:		form!,
:		"AP_CREDITCARD_LK",
:		"DEFAULT",
:		table_chans$[all],
:		sel_key$,
:		filter_defs$[all]

	if sel_key$<>""
		apmCcVend_dev=fnget_dev("APM_CCVEND")
		dim apmCcVend$:fnget_tpl$("APM_CCVEND")
		thisKey$=sel_key$(1,pos("^"=sel_key$)-1)
		findrecord(apmCcVend_dev,key=thisKey$)apmCcVend$
		callpoint!.setColumnData("POE_INVHDR.CREDITCARD_ID",apmCcVend.creditcard_id$,1)
	endif	
	callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_INVHDR.INVOICE_AMT.AVAL]]
callpoint!.setColumnData("POE_INVHDR.NET_INV_AMT", callpoint!.getUserInput())
callpoint!.setDevObject("inv_amt",callpoint!.getUserInput())
if callpoint!.getDevObject("gl_int")="N" then callpoint!.setDevObject("tot_dist",callpoint!.getDevObject("inv_amt"))
gosub calc_grid_tots
gosub disp_dist_bal
callpoint!.setStatus("REFRESH")

[[POE_INVHDR.INV_DATE.AVAL]]
invdate$=callpoint!.getUserInput()
terms_cd$=callpoint!.getColumnData("POE_INVHDR.AP_TERMS_CODE")
if cvs(terms_cd$,3)="" then terms_cd$=callpoint!.getDevObject("dflt_terms_cd")
if cvs(callpoint!.getDevObject("dflt_acct_date"),2)=""
	callpoint!.setColumnData("POE_INVHDR.ACCT_DATE",callpoint!.getUserInput())
else
	callpoint!.setColumnData("POE_INVHDR.ACCT_DATE",str(callpoint!.getDevObject("dflt_acct_date")))
endif
tmp_inv_date$=callpoint!.getUserInput()
gosub calculate_due_and_discount
callpoint!.setStatus("REFRESH")

[[POE_INVHDR.NET_INV_AMT.AVAL]]
rem re-calc discount amount based on net x disc %
disc_amt=round(num(callpoint!.getUserInput())*(num(callpoint!.getDevObject("disc_pct"))/100),2)
callpoint!.setColumnData("POE_INVHDR.DISCOUNT_AMT",str(disc_amt))
callpoint!.setStatus("REFRESH:POE_INVHDR.DISCOUNT_AMT")

[[POE_INVHDR.PAYMENT_GRP.AVAL]]
rem --- Don't allow inactive code
	apcPaymentGroup_dev=fnget_dev("APC_PAYMENTGROUP")
	dim apcPaymentGroup$:fnget_tpl$("APC_PAYMENTGROUP")
	payment_grp$=callpoint!.getUserInput()
	read record(apcPaymentGroup_dev,key=firm_id$+"D"+payment_grp$,dom=*next)apcPaymentGroup$
	if apcPaymentGroup.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apcPaymentGroup.payment_grp$,3)
		msg_tokens$[2]=cvs(apcPaymentGroup.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[POE_INVHDR.VENDOR_ID.AVAL]]

rem "VENDOR INACTIVE - FEATURE"
vendor_id$ = callpoint!.getUserInput()
apm01_dev=fnget_dev("APM_VENDMAST")
apm01_tpl$=fnget_tpl$("APM_VENDMAST")
dim apm01a$:apm01_tpl$
apm01a_key$=firm_id$+vendor_id$
find record (apm01_dev,key=apm01a_key$,err=*break) apm01a$
if apm01a.vend_inactive$="Y" then
   call stbl("+DIR_PGM")+"adc_getmask.aon","VENDOR_ID","","","",m0$,0,vendor_size
   msg_id$="AP_VEND_INACTIVE"
   dim msg_tokens$[2]
   msg_tokens$[1]=fnmask$(apm01a.vendor_id$(1,vendor_size),m0$)
   msg_tokens$[2]=cvs(apm01a.vendor_name$,2)
   gosub disp_message
   callpoint!.setStatus("ACTIVATE-ABORT")
   goto std_exit
endif

ap_type$=callpoint!.getColumnData("POE_INVHDR.AP_TYPE")

gosub vendor_info
gosub disp_vendor_comments
gosub get_vendor_history

if vend_hist$="" and callpoint!.getDevObject("multi_types")="Y"
	msg_id$="AP_VEND_BAD_APTYPE"
	gosub disp_message
	callpoint!.setStatus("CLEAR-NEWREC")
endif

[[POE_INVHDR.VENDOR_ID.BINQ]]
rem --- Set filter_defs$[] to only show vendors of given AP Type

ap_type$=callpoint!.getColumnData("POE_INVHDR.AP_TYPE")

dim filter_defs$[2,2]
filter_defs$[0,0]="APM_VENDMAST.FIRM_ID"
filter_defs$[0,1]="='"+firm_id$+"'"
filter_defs$[0,2]="LOCK"

filter_defs$[1,0]="APM_VENDHIST.AP_TYPE"
filter_defs$[1,1]="='"+ap_type$+"'"
filter_defs$[1,2]="LOCK"


call STBL("+DIR_SYP")+"bax_query.bbj",
:		gui_dev, 
:		form!,
:		"AP_VEND_LK",
:		"DEFAULT",
:		table_chans$[all],
:		sel_key$,
:		filter_defs$[all]

if sel_key$<>""
	call stbl("+DIR_SYP")+"bac_key_template.bbj",
:		"APM_VENDMAST",
:		"PRIMARY",
:		apm_vend_key$,
:		table_chans$[all],
:		status$
	dim apm_vend_key$:apm_vend_key$
	apm_vend_key$=sel_key$
	callpoint!.setColumnData("POE_INVHDR.VENDOR_ID",apm_vend_key.vendor_id$,1)
endif	
callpoint!.setStatus("ACTIVATE-ABORT")

[[POE_INVHDR.<CUSTOM>]]
invoiceOrAdjustment: rem --- Is this a new invoice or an adjustment to an existing invoice?
	adjust_flag=0
	ap_type$=callpoint!.getColumnData("POE_INVHDR.AP_TYPE")
	vendor_id$=callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")
	apt01_dev=fnget_dev("APT_INVOICEHDR")
	find(apt01_dev,key=firm_id$+ap_type$+vendor_id$+ap_inv_no$,dom=*next); adjust_flag=1
	callpoint!.setDevObject("adjust_flag",adjust_flag)
	if adjust_flag then
		Form!.getControl(num(callpoint!.getDevObject("inv_adj_label"))).setText(Translate!.getTranslation("AON_(ADJUSTMENT)"))
		callpoint!.setColumnEnabled("POE_INVHDR.NET_INV_AMT",0)

		rem --- Don't allow credit card for adjustments
		callpoint!.setColumnEnabled("POE_INVHDR.CREDITCARD_ID",0)
	else
		Form!.getControl(num(callpoint!.getDevObject("inv_adj_label"))).setText(Translate!.getTranslation("AON_(INVOICE)"))

		rem --- Allow credit card for new invoice
		callpoint!.setColumnEnabled("POE_INVHDR.CREDITCARD_ID",1)
	endif
return

vendor_info: rem --- get and display Vendor Information
	apm01_dev=fnget_dev("APM_VENDMAST")
	dim apm01a$:fnget_tpl$("APM_VENDMAST")
	read record(apm01_dev,key=firm_id$+vendor_id$,dom=*next)apm01a$
	callpoint!.setColumnData("<<DISPLAY>>.V_ADDR1",apm01a.addr_line_1$)
	callpoint!.setColumnData("<<DISPLAY>>.V_ADDR2",apm01a.addr_line_2$)
	callpoint!.setColumnData("<<DISPLAY>>.V_CITY",cvs(apm01a.city$,3)+", "+apm01a.state_code$+"  "+apm01a.zip_code$)
	callpoint!.setColumnData("<<DISPLAY>>.V_CNTRY_ID",apm01a.cntry_id$)
	callpoint!.setColumnData("<<DISPLAY>>.V_CONTACT",apm01a.contact_name$)
	callpoint!.setColumnData("<<DISPLAY>>.V_PHONE",apm01a.phone_no$)
	callpoint!.setColumnData("<<DISPLAY>>.V_FAX",apm01a.fax_no$)
	callpoint!.setStatus("REFRESH")
return

get_vendor_history:
rem --- set vendor_id$ and ap_type$ before coming in
	apm02_dev=fnget_dev("APM_VENDHIST")				
	dim apm02a$:fnget_tpl$("APM_VENDHIST")
	vend_hist$ = ""

	readrecord(apm02_dev,key=firm_id$+vendor_id$+ap_type$,dom=*next)apm02a$
	if cvs(apm02a.firm_id$,2) <> "" then
		callpoint!.setDevObject("dflt_dist_cd", apm02a.ap_dist_code$)
		callpoint!.setDevObject("dflt_gl_account", apm02a.gl_account$)
		callpoint!.setDevObject("dflt_terms_cd", apm02a.ap_terms_code$)
		callpoint!.setDevObject("dflt_pymt_grp", apm02a.payment_grp$)
		vend_hist$="Y"
	else
		callpoint!.setDevObject("dflt_gl_account", "")
		callpoint!.setDevObject("dflt_terms_cd", "")
		callpoint!.setDevObject("dflt_pymt_grp", "")
		vend_hist$=""
	endif
return

disp_vendor_comments:
	rem --- You must pass in vendor_id$ because we don't know whether it's verified or not

	apm01_dev=fnget_dev("APM_VENDMAST")
	dim apm01a$:fnget_tpl$("APM_VENDMAST")
	readrecord(apm01_dev,key=firm_id$+vendor_id$,dom=*next)apm01a$
	callpoint!.setColumnData("<<DISPLAY>>.comments",apm01a.memo_1024$,1)
return

calculate_due_and_discount:

	if cvs(callpoint!.getColumnData("POE_INVHDR.ACCT_DATE"),2)=""
		callpoint!.setColumnData("POE_INVHDR.ACCT_DATE",str(callpoint!.getDevObject("dflt_acct_date")))
	endif
	if str(callpoint!.getDevObject("dflt_acct_date"))=""
		callpoint!.setColumnData("POE_INVHDR.ACCT_DATE",tmp_inv_date$)
	endif
	apm10c_dev=fnget_dev("APC_TERMSCODE")
	dim apm10c$:fnget_tpl$("APC_TERMSCODE")
	
	readrecord(apm10c_dev,key=firm_id$+"C"+terms_cd$,dom=*next)apm10c$
	prox_days$=cvs(apm10c.prox_or_days$,3); if prox_days$="" prox_days$="D"
	due_dt$=""
	call stbl("+DIR_PGM")+"adc_duedate.aon",prox_days$,invdate$,num(apm10c.due_days$),due_dt$,status
	callpoint!.setColumnData("POE_INVHDR.DUE_DATE",due_dt$)
	due_dt$=""
	call stbl("+DIR_PGM")+"adc_duedate.aon",prox_days$,invdate$,num(apm10c.disc_days$),due_dt$,status
	callpoint!.setColumnData("POE_INVHDR.PO_DISC_DATE",due_dt$)
	callpoint!.setDevObject("disc_pct",apm10c.disc_percent$)
return

calc_gl_tots:

	poe_invgl_dev=fnget_dev("POE_INVGL")
	dim poe_invgl$:fnget_tpl$("POE_INVGL")

	tot_gl=0
	ky$=firm_id$+callpoint!.getColumnData("POE_INVHDR.AP_TYPE")+callpoint!.getColumnData("POE_INVHDR.VENDOR_ID")+callpoint!.getColumnData("POE_INVHDR.AP_INV_NO")
	read (poe_invgl_dev,key=ky$,dom=*next)

	while 1
		read record (poe_invgl_dev,end=*break)poe_invgl$
		if pos(ky$=poe_invgl$)<>1 then break
		tot_gl=tot_gl+poe_invgl.gl_post_amt
	wend
	callpoint!.setDevObject("tot_gl",str(tot_gl))
return

calc_grid_tots:
	recVect!=GridVect!.getItem(0)
	dim gridrec$:dtlg_param$[1,3]
	numrecs=recVect!.size()
	tdist=0
	if numrecs>0
		for reccnt=0 to numrecs-1
			gridrec$=recVect!.getItem(reccnt)
			if cvs(gridrec$,3)<>"" and callpoint!.getGridRowDeleteStatus(reccnt)<>"Y" then tdist=tdist+num(gridrec.total_amount$)
		next reccnt
		callpoint!.setDevObject("tot_dist",str(tdist))
	endif
return

disp_dist_bal:
	dist_bal=num(callpoint!.getDevObject("inv_amt"))-num(callpoint!.getDevObject("tot_dist"))-num(callpoint!.getDevObject("tot_gl"))
	callpoint!.setColumnData("<<DISPLAY>>.DIST_BAL",str(dist_bal))
	callpoint!.setStatus("REFRESH")		 
return

rem #include fnget_control.src
def fnget_control!(ctl_name$)
ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
get_control!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
return get_control!
fnend
rem #endinclude fnget_control.src
#include [+ADDON_LIB]std_missing_params.aon
#include [+ADDON_LIB]std_functions.aon



