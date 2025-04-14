[[APE_MANCHECKHDR.AABO]]
rem --- need to go thru gridVect!; any record NOT already in ape-22 (detail) should be removed from ape-12 (gl dist)
rem --- this can happen in this program, since dist grid is launched/handled from dtl grid -- we might write out
rem --- one or more ape-12 recs, then come back to main form and abort, which won't save the ape-22 recs...
	recVect!=gridVect!.getItem(0)
	dim gridrec$:dtlg_param$[1,3]
	numrecs=recVect!.size()
	ape12_dev=fnget_dev("APE_MANCHECKDIST")
	ape22_dev=fnget_dev("@APE_MANCHECKDET")

	if numrecs>0
		for reccnt=0 to numrecs-1
			gridrec$=recVect!.getItem(reccnt)
			if cvs(gridrec$,3)<>""
				remove_ky$=firm_id$+gridrec.ap_type$+gridrec.bnk_acct_cd$+gridrec.check_no$+gridrec.vendor_id$+gridrec.ap_inv_no$
				ape22_ky$=remove_ky$+"00"
				read(ape22_dev,key=ape22_ky$,dom=*next);continue
				read (ape12_dev,key=remove_ky$,dom=*next)
				while 1
					k$=key(ape12_dev,end=*break)
					if pos(remove_ky$=k$)<>1 then break
					remove(ape12_dev,key=k$)
				wend
			endif
		next reccnt		
	endif

[[APE_MANCHECKHDR.ADEL]]
rem --- Verify all G/L Distribution records get deleted. (Workaround to Barista Bug 5979)

	ape12_dev=fnget_dev("APE_MANCHECKDIST")
	ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
	bnk_acct_cd$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
	check_no$=callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO")
	vend$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")

	read(ape12_dev,key=firm_id$+ap_type$+bnk_acct_cd$+check_no$+vend$,dom=*next)
	while 1
		ape12_key$=key(ape12_dev,end=*break)
		read(ape12_dev)
		if pos(firm_id$+ap_type$+bnk_acct_cd$+check_no$+vend$=ape12_key$)<>1 break
		remove (ape12_dev,key=ape12_key$)
	wend

[[APE_MANCHECKHDR.ADIS]]
user_tpl.existing_tran$="Y"
user_tpl.reuse_chk$=""
tmp_vendor_id$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")
gosub get_vendor_history
gosub disp_vendor_comments
ctl_name$="APE_MANCHECKHDR.TRANS_TYPE"
ctl_stat$="D"
gosub disable_fields
ctl_name$="APE_MANCHECKHDR.VENDOR_ID"
gosub disable_fields
if callpoint!.getColumnData("APE_MANCHECKHDR.TRANS_TYPE")="M"
	gosub calc_tots
	gosub disp_tots
	callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_INV",str(tinv))
   	callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_DISC",str(tdisc))
	callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_RETEN",str(tret))
	callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_CHECK",str(tinv-tdisc-tret))

	rem --- Enable Print Check button if manual check is for more than zero and hasn't been printed
	if tinv-tdisc-tret > 0 and callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_PRINTED")<>"Y" then
		callpoint!.setOptionEnabled("PCHK",1)
	else
		callpoint!.setOptionEnabled("PCHK",0)
	endif
else
	ctl_name$="APE_MANCHECKHDR.CHECK_DATE"
	ctl_stat$="D"
	gosub disable_fields
	gosub disable_grid

rem --- Disable Print Check button
	callpoint!.setOptionEnabled("PCHK",0)
endif
rem --- disable inv#/date/dist code cells corres to existing data -- only allow change on inv/disc cols
curr_rows!=GridVect!.getItem(0)
curr_rows=curr_rows!.size()
if curr_rows
gosub enable_grid
dtlGrid!=Form!.getChildWindow(1109).getControl(5900)
	for wk=0 to curr_rows-1
		dtlGrid!.setCellEditable(wk,0,0)
		dtlGrid!.setCellEditable(wk,1,0)
		dtlGrid!.setCellEditable(wk,2,0)
	next wk
endif

rem --- Set checking account list to the entered BNK_ACCT_CD
	bnkAcctCd$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
	callpoint!.setColumnData("<<DISPLAY>>.CHECK_ACCTS",bnkAcctCd$,1)

rem --- Preventing manual check from being modified after it has been printed on-demand, except for changing Trans Type to Void (V).
	if callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_PRINTED")="Y" then
		callpoint!.setColumnEnabled("APE_MANCHECKHDR.VENDOR_ID",0)
		callpoint!.setColumnEnabled("APE_MANCHECKHDR.CHECK_DATE",0)
		gosub disable_grid
	endif

[[APE_MANCHECKHDR.AOPT-PCHK]]
rem --- Make sure modified records are saved before printing
	if pos("M"=callpoint!.getRecordStatus())
		msg_id$="AD_SAVE_BEFORE_PRINT"
		gosub disp_message
		break
	endif

rem --- Add Barista soft lock for this record if not already in edit mode
	ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
	bnk_acct_no$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
	check_no$=callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO")
	vendor_id$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")

	if !callpoint!.isEditMode() then
		rem --- Is there an existing soft lock?
		lock_table$="APE_MANCHECKHDR"
		lock_record$=firm_id$+ap_type$+bnk_acct_no$+check_no$+vendor_id$
		lock_type$="C"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		if lock_status$="" then
			rem --- Add temporary soft lock used just for this print task
			lock_type$="L"
			call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
		else
			rem --- Record locked by someone else
			msg_id$="ENTRY_REC_LOCKED"
			gosub disp_message
			break
		endif
	endif

rem --- Print check now
	callpoint!.setDevObject("printMode", "OnDemand")

	rem --- Build invVect! with invoices for this on-demand print check
	invVect!=BBjAPI().makeVector()
	dim ape22a$:fnget_tpl$("@APE_MANCHECKDET")
	gridRows!=GridVect!.getItem(0)
	if gridRows!.size() then
		for i=0 to gridRows!.size()-1
			ape22a$=gridRows!.getItem(i)
			invVect!.addItem(ape22a.ap_inv_no$)
			callpoint!.setDevObject("invVect",invVect!)
		next i
	endif

	user_id$=stbl("+USER_ID")
 
	dim dflt_data$[5,1]
	dflt_data$[1,0]="CHECK_DATE"
	dflt_data$[1,1]=callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_DATE")
	dflt_data$[2,0]="CHECK_NO"
	dflt_data$[2,1]=check_no$
	dflt_data$[3,0]="CHECK_ACCTS"
	dflt_data$[3,1]=bnk_acct_no$
	dflt_data$[4,0]="VENDOR_ID"
	dflt_data$[4,1]=vendor_id$
	dflt_data$[5,0]="AP_TYPE"
	dflt_data$[5,1]=ap_type$

	ChkObj!=new java.util.HashMap()
	ChkObj!.put("check_date",callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_DATE"))
	ChkObj!.put("bnk_acct_cd",callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD"))
	ChkObj!.put("check_no",check_no$)
	ChkObj!.put("ap_type",ap_type$)
	ChkObj!.put("vendor_id",vendor_id$)

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:	                       "APR_CHECKS",
:	                       user_id$,
:	                       "",
:	                       "",
:	                       table_chans$[all],
:	                       "",
:	                       dflt_data$[all],
:	                       "",
:	                       ChkObj!

rem --- Update check_printed flag
	if callpoint!.getDevObject("updateChkPrintFlag")<>null() and callpoint!.getDevObject("updateChkPrintFlag")="Y" then
		callpoint!.setColumnData("APE_MANCHECKHDR.CHECK_PRINTED","Y")
		callpoint!.setOptionEnabled("PCHK",0)
		callpoint!.setDevObject("updateChkPrintFlag","N")
		
		rem --- Get current form data and write it to disk
		gosub get_disk_rec
		writerecord(ape02_dev)ape02a$
	endif

rem --- Remove temporary soft lock used just for this print task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[APE_MANCHECKHDR.APFE]]
rem  --- Enable Print Check button if manual check is for more than zero and hasn't been printed
	if callpoint!.getColumnData("APE_MANCHECKHDR.TRANS_TYPE")="M" and 
:		num(callpoint!.getColumnData("<<DISPLAY>>.DISP_TOT_CHECK"))>0 and
:		callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_PRINTED")<>"Y" then
		callpoint!.setOptionEnabled("PCHK",1)
	else
		callpoint!.setOptionEnabled("PCHK",0)
	endif

rem --- Refresh form with current data on disk that might have been updated elsewhere
	if callpoint!.getDevObject("updateDiskData")<>null() and callpoint!.getDevObject("updateDiskData")="Y" then
		batch_no$=callpoint!.getColumnData("APE_MANCHECKHDR.BATCH_NO")
		ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
		bnk_acct_cd$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
		check_no$=callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO")
		vendor_id$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")
		callpoint!.setStatus("RECORD:["+firm_id$+batch_no$+ap_type$+bnk_acct_cd$+check_no$+vendor_id$+"]")

		callpoint!.setDevObject("updateDiskData","N")
	endif

[[APE_MANCHECKHDR.AP_TYPE.AVAL]]
user_tpl.dflt_ap_type$=callpoint!.getUserInput()
if user_tpl.dflt_ap_type$=""
	user_tpl.dflt_ap_type$="  "
	callpoint!.setUserInput(user_tpl.dflt_ap_type$)
endif

apm10_dev=fnget_dev("APC_TYPECODE")
dim apm10a$:fnget_tpl$("APC_TYPECODE")
readrecord (apm10_dev,key=firm_id$+"A"+user_tpl.dflt_ap_type$,dom=*next)apm10a$
if cvs(apm10a$,2)<>""
	user_tpl.dflt_dist_cd$=apm10a.ap_dist_code$
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

[[APE_MANCHECKHDR.AREA]]
user_tpl.existing_tran$="Y"
user_tpl.reuse_chk$=""

[[APE_MANCHECKHDR.AREC]]
user_tpl.reuse_chk$=""
user_tpl.dflt_gl_account$=""
callpoint!.setColumnData("<<DISPLAY>>.comments","")
callpoint!.setColumnData("APE_MANCHECKHDR.RETAIN_APPROVALS","Y")

rem --- if not multi-type then set the defalut AP Type
if user_tpl.multi_types$="N" then
	callpoint!.setColumnData("APE_MANCHECKHDR.AP_TYPE",user_tpl.dflt_ap_type$)
endif

[[APE_MANCHECKHDR.ARER]]
rem --- Initialize BNK_ACCT_CD for the first checking account in the list
	bnkAcctCdList!=callpoint!.getDevObject("bnkAcctCdList")
	bnkAcctCd$=bnkAcctCdList!.getItem(0)
	callpoint!.setColumnData("<<DISPLAY>>.CHECK_ACCTS",bnkAcctCd$,1)
	callpoint!.setColumnData("APE_MANCHECKHDR.BNK_ACCT_CD",bnkAcctCd$)

rem --- Initialize check_no if next check number is available
	nextChkList!=callpoint!.getDevObject("nextCheckList")
	if nextChkList!.size()>0 then
		rem --- Initialize CHECK_NO for the first Checking Account in ListButton
		callpoint!.setColumnData("APE_MANCHECKHDR.CHECK_NO",nextChkList!.getItem(0),1)
	else
		rem --- Clear CHECK_NO
		callpoint!.setColumnData("APE_MANCHECKHDR.CHECK_NO","",1)
	endif

[[APE_MANCHECKHDR.ARNF]]
if num(stbl("+BATCH_NO"),err=*next)<>0
	rem --- Check if this record exists in a different batch
	tableAlias$=callpoint!.getAlias()
	primaryKey$=callpoint!.getColumnData("APE_MANCHECKHDR.FIRM_ID")+
:		callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")+
:		callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO")+
:		callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")
	call stbl("+DIR_PGM")+"adc_findbatch.aon",tableAlias$,primaryKey$,Translate!,table_chans$[all],existingBatchNo$,status
	if status or existingBatchNo$<>"" then callpoint!.setStatus("NEWREC")
endif

[[APE_MANCHECKHDR.ASVA]]
rem --- Update next check number (if not a reversal or void per bug 10509)

	if pos(callpoint!.getColumnData("APE_MANCHECKHDR.TRANS_TYPE")="RV")=0
		adcBnkAcct_dev=fnget_dev("ADC_BANKACCTCODE")
		dim adcBnkAcct$:fnget_tpl$("ADC_BANKACCTCODE")

		bnkAcctCd$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
		extractrecord(adcBnkAcct_dev,key=firm_id$+bnkAcctCd$,dom=*next)adcBnkAcct$; rem Advisory Locking
		if cvs(adcBnkAcct.bnk_acct_cd$,2)<>"" then
			check_no$=callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO")
			nextCheck$=cvs(str(num(check_no$)+1),3)
			adcBnkAcct.nxt_check_no$=pad(nextCheck$,len(check_no$),"R","0")
			writerecord(adcBnkAcct_dev)adcBnkAcct$

			rem --- Update list of next check numbers for the current checking account
			chkAcctCtl!=callpoint!.getControl("<<DISPLAY>>.CHECK_ACCTS")
			index=chkAcctCtl!.getSelectedIndex()
			nextChkList!=callpoint!.getDevObject("nextCheckList")
			nextChkList!.setItem(index,adcBnkAcct.nxt_check_no$)
		endif
	endif

[[APE_MANCHECKHDR.AWIN]]
rem --- Inits
	use ::ado_func.src::func
	use ::ado_util.src::util
	use ::BBUtils.bbj::BBUtils

rem --- Open/Lock files
	files=30,begfile=1,endfile=17
	dim files$[files],options$[files],chans$[files],templates$[files]
	files$[1]="APE_MANCHECKHDR",options$[1]="OTA"
	files$[2]="APE_MANCHECKDIST",options$[2]="OTA"
	files$[3]="APE_MANCHECKDET",options$[3]="OTAN";rem --- "ape-22, channel stored in user_tpl$ and used in detail grid callpoints when reading by AO_VEND_INV key
	files$[4]="APM_VENDMAST",options$[4]="OTA"
	files$[5]="APM_VENDHIST",options$[5]="OTA"
	files$[6]="APT_INVOICEHDR",options$[6]="OTA"
	files$[7]="APT_INVOICEDET",options$[7]="OTA"
	files$[8]="APT_CHECKHISTORY",options$[8]="OTA"
	files$[9]="APC_TYPECODE",options$[9]="OTA"
	files$[10]="APC_DISTRIBUTION",options$[10]="OTA"
	files$[11]="APS_PARAMS",options$[11]="OTA"
	files$[12]="GLS_PARAMS",options$[12]="OTA"
	files$[13]="APS_PAYAUTH",options$[13]="OTA@"
	files$[14]="APT_INVIMAGE",options$[14]="OTA"
	files$[15]="APE_MANCHECKDET",options$[15]="OTA@";rem --- "ape-22, used in AABO to compare grid against what's on disk
	files$[16]="ADC_BANKACCTCODE",options$[16]="OTA"
	files$[17]="APC_DISTRIBUTION",options$[17]="OTA"

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

	aps01_dev=num(chans$[11])
	gls01_dev=num(chans$[12])
	aps_payauth=num(chans$[13])
	dim aps01a$:templates$[11],gls01a$:templates$[12],aps_payauth$:templates$[13]

	user_tpl_str$="firm_id:c(2),glint:c(1),glyr:c(4),glper:c(2),glworkfile:c(16),"
	user_tpl_str$=user_tpl_str$+"amt_msk:c(15),multi_types:c(1),multi_dist:c(1),ret_flag:c(1),"
	user_tpl_str$=user_tpl_str$+"misc_entry:c(1),post_closed:c(1),units_flag:c(1),"
	user_tpl_str$=user_tpl_str$+"existing_tran:c(1),existing_invoice:c(1),reuse_chk:c(1),"
	user_tpl_str$=user_tpl_str$+"dflt_ap_type:c(2),dflt_dist_cd:c(2),dflt_gl_account:c(10),"
	user_tpl_str$=user_tpl_str$+"tinv_vpos:c(1),tdisc_vpos:c(1),tret_vpos:c(1),tchk_vpos:c(1),"
	user_tpl_str$=user_tpl_str$+"ap_type_vpos:c(1),vendor_id_vpos:c(1),ape22_dev1:n(5)"

	dim user_tpl$:user_tpl_str$
	user_tpl.firm_id$=firm_id$
	user_tpl.ape22_dev1=num(chans$[3])

rem --- set up UserObj! as vector

	UserObj!=SysGUI!.makeVector()
	
	ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_INV","CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_INV","CTLI"))
	tinv!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_DISC","CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_DISC","CTLI"))
	tdisc!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_RETEN","CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_RETEN","CTLI"))
	tret!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctlContext=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_CHECK","CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute("<<DISPLAY>>.DISP_TOT_CHECK","CTLI"))
	tchk!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctlContext=num(callpoint!.getTableColumnAttribute("APE_MANCHECKHDR.AP_TYPE","CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute("APE_MANCHECKHDR.AP_TYPE","CTLI"))
	ap_type!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	ctlContext=num(callpoint!.getTableColumnAttribute("APE_MANCHECKHDR.VENDOR_ID","CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute("APE_MANCHECKHDR.VENDOR_ID","CTLI"))
	vendor_id!=SysGUI!.getWindow(ctlContext).getControl(ctlID)

	UserObj!.addItem(tinv!)
	user_tpl.tinv_vpos$="0"
	UserObj!.addItem(tdisc!)
	user_tpl.tdisc_vpos$="1"
	UserObj!.addItem(tret!)
	user_tpl.tret_vpos$="2"
	UserObj!.addItem(tchk!)
	user_tpl.tchk_vpos$="3"
	UserObj!.addItem(ap_type!)
	user_tpl.ap_type_vpos$="4"
	UserObj!.addItem(vendor_id!)
	user_tpl.vendor_id_vpos$="5"

rem --- Additional File Opens

	gl$="N"
	status=0
	source$=pgm(-2)
	call stbl("+DIR_PGM")+"glc_ctlcreate.aon",err=*next,source$,"AP",glw11$,gl$,status
	if status<>0 goto std_exit
	user_tpl.glint$=gl$
	user_tpl.glworkfile$=glw11$

	if gl$="Y"
		files=22,begfile=20,endfile=22
		dim files$[files],options$[files],chans$[files],templates$[files]
		files$[20]="GLM_ACCT",options$[20]="OTA";rem --- "glm-01"
		files$[21]="GLM_BANKMASTER",options$[21]="OTA"
		files$[22]=glw11$,options$[22]="OTAS";rem --- s means no err if tmplt not found

		call stbl("+DIR_SYP")+"bac_open_tables.bbj",
:			begfile,
:			endfile,
:			files$[all],
:			options$[all],
:			chans$[all],
:			templates$[all],
:			table_chans$[all],
:			batch,
:			status$
		if status$<>"" then
			bbjAPI!=bbjAPI()
			rdFuncSpace!=bbjAPI!.getGroupNamespace()
			rdFuncSpace!.setValue("+build_task","OFF")
			release
		endif
	endif

rem --- Retrieve parameter data
               
	aps01a_key$=firm_id$+"AP00"
	find record (aps01_dev,key=aps01a_key$,err=std_missing_params) aps01a$
	callpoint!.setDevObject("multi_types",aps01a.multi_types$)
	callpoint!.setDevObject("scan_docs_to",aps01a.scan_docs_to$)

	call stbl("+DIR_PGM")+"adc_getmask.aon","","AP","A","",amt_mask$,0,0

	user_tpl.amt_msk$=amt_mask$
	user_tpl.multi_types$=aps01a.multi_types$
	user_tpl.dflt_ap_type$=aps01a.ap_type$
	user_tpl.multi_dist$=aps01a.multi_dist$
	user_tpl.dflt_dist_cd$=aps01a.ap_dist_code$
	user_tpl.ret_flag$=aps01a.ret_flag$
	user_tpl.misc_entry$=aps01a.misc_entry$
	user_tpl.post_closed$=aps01a.post_closed$

	if user_tpl.multi_types$<>"Y"
		apm10_dev=fnget_dev("APC_TYPECODE")
		dim apm10a$:fnget_tpl$("APC_TYPECODE")
		readrecord (apm10_dev,key=firm_id$+"A"+user_tpl.dflt_ap_type$,dom=*next)apm10a$
		if cvs(apm10a$,2)<>""
			user_tpl.dflt_dist_cd$=apm10a.ap_dist_code$
		endif
	endif

	gls01a_key$=firm_id$+"GL00"
	find record (gls01_dev,key=gls01a_key$,err=std_missing_params) gls01a$
	user_tpl.units_flag$=gls01a.units_flag$
	callpoint!.setDevObject("GLMisc",user_tpl.misc_entry$)
	callpoint!.setDevObject("GLUnits",user_tpl.units_flag$)
	callpoint!.setDevObject("gl_int",user_tpl.glint$)
	callpoint!.setDevObject("dist_amt","")
	callpoint!.setDevObject("dflt_gl","")
	callpoint!.setDevObject("dflt_dist","")
	callpoint!.setDevObject("tot_inv","")

rem --- Get Payment Authorization parameter record

	readrecord(aps_payauth,key=firm_id$+"AP00",dom=*next)aps_payauth$
	callpoint!.setDevObject("use_pay_auth",aps_payauth.use_pay_auth)

rem --- Create vector of urls for viewed invoice images

	urlVect!=BBjAPI().makeVector()
	callpoint!.setDevObject("urlVect",urlVect!)

[[APE_MANCHECKHDR.BDEL]]
rem --- Prevent manual check from being deleted after it has been printed on-demand
	if callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_PRINTED")="Y" then
		msg_id$="AP_DELETE_MANCHK"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

[[APE_MANCHECKHDR.BEND]]
rem --- remove software lock on batch, if batching

	batch$=stbl("+BATCH_NO",err=*next)
	if num(batch$)<>0
		lock_table$="ADM_PROCBATCHES"
		lock_record$=firm_id$+stbl("+PROCESS_ID")+batch$
		lock_type$="X"
		lock_status$=""
		lock_disp$=""
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

rem --- Remove images copied temporarily to web servier for viewing
	urlVect!=callpoint!.getDevObject("urlVect")
	if urlVect!.size()
		for wk=0 to urlVect!.size()-1
			BBUtils.deleteFromWebServer(urlVect!.get(wk))
		next wk
	endif

[[APE_MANCHECKHDR.BPFX]]
rem --- don't allow access to the grid if doing a void or reversal
rem --- there is a disable_grid routine which works, but F7 still tries to jump there and causes Barista error

if pos(callpoint!.getColumnData("APE_MANCHECKHDR.TRANS_TYPE")="RV")<>0
	callpoint!.setStatus("ABORT")
endif

rem --- Is only one invoice per check allowed?
	apm02_dev=fnget_dev("APM_VENDHIST")				
	dim apm02a$:fnget_tpl$("APM_VENDHIST")
	vendor_id$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")
	ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
	readrecord(apm02_dev,key=firm_id$+vendor_id$+ap_type$,dom=*next)apm02a$
	callpoint!.setDevObject("oneInvPerChk",apm02a.one_inv_per_chk$)

rem --- Disable Print Check button
	callpoint!.setOptionEnabled("PCHK",0)

[[APE_MANCHECKHDR.BSHO]]
rem --- Disable ap type control if param for multi-types is N

	if user_tpl.multi_types$="N" 
		ctl_name$="APE_MANCHECKHDR.AP_TYPE"
		ctl_stat$="I"
		gosub disable_fields
	endif

rem --- Disable button

	callpoint!.setOptionEnabled("OINV",0)

rem --- Initialize Checking Account ListButton with all checking accounts
	chkAcctList!=BBjAPI().makeVector()
	bnkAcctCdList!=BBjAPI().makeVector()
	nextChkLIst!=BBjAPI().makeVector()
	codeList!=BBjAPI().makeVector()

	adcBnkAcct_dev=fnget_dev("ADC_BANKACCTCODE")
	dim adcBnkAcct$:fnget_tpl$("ADC_BANKACCTCODE")
	read(adcBnkAcct_dev,key=firm_id$,dom=*next)
	while 1
		readrecord(adcBnkAcct_dev,end=*break)adcBnkAcct$
		if adcBnkAcct.firm_id$<>firm_id$ then break
		if adcBnkAcct.bnk_acct_type$="C" then
			bnkAcctCdList!.addItem(adcBnkAcct.bnk_acct_cd$)
			chkAcctList!.addItem(adcBnkAcct.acct_desc$)
			nextChkList!.addItem(adcBnkAcct.nxt_check_no$)
			codeList!.addItem(adcBnkAcct.bnk_acct_cd$)
		endif
	wend
	callpoint!.setDevObject("bnkAcctCdList",bnkAcctCdList!)
	callpoint!.setDevObject("nextCheckList",nextChkList!)

	chkAcctCtl!=callpoint!.getControl("<<DISPLAY>>.CHECK_ACCTS")
	chkAcctCtl!.removeAllItems()
	chkAcctCtl!.insertItems(0,chkAcctList!)
	chkAcctCtl!.selectIndex(0)
	ldat$=func.buildListButtonList(chkAcctList!,codeList!)
	callpoint!.setTableColumnAttribute("<<DISPLAY>>.CHECK_ACCTS","LDAT",ldat$)

	if bnkAcctCdList!.size()>0 then
		rem --- Initialize CHECK_NO for the selected checking account
		bnkAcctCd$=bnkAcctCdList!.getItem(0)
		callpoint!.setColumnData("APE_MANCHECKHDR.BNK_ACCT_CD",bnkAcctCd$)
	else
		rem --- Initialize CHECK_NO for the selected checking account
		callpoint!.setColumnData("APE_MANCHECKHDR.BNK_ACCT_CD","")

		rem --- Disable Checking Account ListButton
		callpoint!.setColumnEnabled("<<DISPLAY>>.CHECK_ACCTS",0)
	endif

[[APE_MANCHECKHDR.BTBL]]
rem --- Get Batch information

call stbl("+DIR_PGM")+"adc_getbatch.aon",callpoint!.getAlias(),"",table_chans$[all]
callpoint!.setTableColumnAttribute("APE_MANCHECKHDR.BATCH_NO","PVAL",$22$+stbl("+BATCH_NO")+$22$)

[[APE_MANCHECKHDR.BWRI]]
rem --- make sure we have entered mandatory elements of header, and that ap_type/vendor are valid together

dont_write$=""

if cvs(callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_DATE"),3)="" or
:	cvs(callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO"),3)="" or
:	(cvs(callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID"),3)="" and callpoint!.getColumnData("APE_MANCHECKHDR.TRANS_TYPE")<>"V") then
	dont_write$="Y"
endif

if cvs(callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID"),3)<>"" then
	vend_hist$=""
	tmp_vendor_id$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")
	gosub get_vendor_history
	if vend_hist$<>"Y" then dont_write$="Y"
endif

if dont_write$="Y"
	msg_id$="AP_MANCHKWRITE"
	gosub disp_message
	callpoint!.setStatus("ABORT")
	break
endif

rem --- Negative checks are not allowed.
	if num(callpoint!.getColumnData("<<DISPLAY>>.DISP_TOT_CHECK"))<0 then
		msg_id$="AP_NEGATIVE_CHK"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[<<DISPLAY>>.CHECK_ACCTS.AVAL]]
rem --- Initialize CHECK_NO for the selected checking account if it has changed
	bnk_acct_cd$=pad(callpoint!.getUserInput(),len(rec_data.bnk_acct_cd$))
	if callpoint!.getColumnData("<<DISPLAY>>.CHECK_ACCTS")=bnk_acct_cd$ then break

	chkAcctCtl!=callpoint!.getControl("<<DISPLAY>>.CHECK_ACCTS")
	index=chkAcctCtl!.getSelectedIndex()
	nextChkList!=callpoint!.getDevObject("nextCheckList")
	callpoint!.setColumnData("APE_MANCHECKHDR.CHECK_NO",nextChkList!.getItem(index),1)

rem --- Initialize BNK_ACCT_CD for the selected checking account

	callpoint!.setColumnData("APE_MANCHECKHDR.BNK_ACCT_CD",bnk_acct_cd$)

[[APE_MANCHECKHDR.CHECK_DATE.AVAL]]
gl$=user_tpl.glint$
ckdate$=callpoint!.getUserInput()

if gl$="Y"
	call stbl("+DIR_PGM")+"glc_datecheck.aon",ckdate$,"N",per$,yr$,status
	if user_tpl.glyr$<>yr$ or user_tpl.glper$<>per$
		call stbl("+DIR_PGM")+"glc_datecheck.aon",ckdate$,"Y",per$,yr$,status
		if status>99
			callpoint!.setStatus("ABORT")
		else
			user_tpl.glyr$=yr$
			user_tpl.glper$=per$
		endif
	endif
endif

[[APE_MANCHECKHDR.CHECK_NO.AVAL]]
rem --- Look in entry file for this check number.
rem --- If found, use setStatus("RECORD") to call it up. (bug 8510)
rem --- If not found, then look in check history.
rem --- If found there, then offer to do reversal or re-use check number, depending on check type.
rem --- (if open Computer or Manual check, can reverse; if already a Void or Reversal, offer to reuse check#)

	batch_no$=callpoint!.getColumnData("APE_MANCHECKHDR.BATCH_NO")
	ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
	bnk_acct_cd$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
	check_no$=callpoint!.getUserInput()
	tmpky$=""

	ape_mancheckhdr=fnget_dev("APE_MANCHECKHDR")

	read (ape_mancheckhdr,key=firm_id$+batch_no$+ap_type$+bnk_acct_cd$+check_no$,dom=*next)
	tmpky$=key(ape_mancheckhdr,end=*next)
	if pos(firm_id$+batch_no$+ap_type$+bnk_acct_cd$+check_no$=tmpky$)=1
		callpoint!.setStatus("RECORD:["+tmpky$+"]")
		break
	endif

rem --- not found in entry file, so see if in open checks

	if cvs(check_no$,3)<>""
		apt05_dev = fnget_dev("APT_CHECKHISTORY")
		dim apt05a$:fnget_tpl$("APT_CHECKHISTORY")

		read (apt05_dev,key=firm_id$+ap_type$+bnk_acct_cd$+check_no$,dom=*next)
		readrecord (apt05_dev,end=*next)apt05a$

		if apt05a.firm_id$=firm_id$  and apt05a.ap_type$=ap_type$  and apt05a.bnk_acct_cd$=bnk_acct_cd$ and apt05a.check_no$=check_no$

			vendor_id$=apt05a.vendor_id$

			rem --- Reverse? (Check is Manual or Computer generated)

			if pos(apt05a.trans_type$="ACM") then
				if apt05a.trans_type$="A" then
					msg_id$="AP_REVERSE_ACH"
				else
					msg_id$="AP_REVERSE"
				endif
				msg_opt$=""
				gosub disp_message

				if msg_opt$="Y"
					callpoint!.setColumnData("APE_MANCHECKHDR.TRANS_TYPE","R",1)
					callpoint!.setColumnUndoData("APE_MANCHECKHDR.TRANS_TYPE","R")
					ctl_name$="APE_MANCHECKHDR.AP_TYPE"
					ctl_stat$="D"
					gosub disable_fields
					ctl_name$="APE_MANCHECKHDR.CHECK_NO"
					ctl_stat$="D"
					gosub disable_fields
					ctl_name$="APE_MANCHECKHDR.TRANS_TYPE"
					ctl_stat$="D"
					gosub disable_fields
					ctl_name$="APE_MANCHECKHDR.VENDOR_ID"
					gosub disable_fields
					callpoint!.setColumnData("APE_MANCHECKHDR.CHECK_DATE",apt05a.check_date$,1)
					callpoint!.setColumnData("APE_MANCHECKHDR.VENDOR_ID",vendor_id$,1)

					rem --- Sum totals for this check
					while 1
						tot_inv=tot_inv+apt05a.invoice_amt
						tot_dis=tot_dis+apt05a.discount_amt
						tot_reten=tot_reten+apt05a.retention

						readrecord (apt05_dev,end=*break)apt05a$
						if apt05a.firm_id$<>firm_id$ or apt05a.ap_type$<>ap_type$ or apt05a.bnk_acct_cd$<>bnk_acct_cd$ or apt05a.check_no$<>check_no$ then break
					wend

					callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_INV",str(tot_inv),1)
					callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_DISC",str(tot_dis),1)
					callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_RETEN",str(tot_reten),1)
					callpoint!.setColumnData("<<DISPLAY>>.DISP_TOT_CHECK",str(tot_inv-tot_dis-tot_reten),1)
					tmp_vendor_id$=vendor_id$
					gosub disp_vendor_comments
					gosub disable_grid
					callpoint!.setStatus("MODIFIED")

					rem --- Retain invoice payment approvals?
					if callpoint!.getDevObject("use_pay_auth") then
						msg_id$="AP_RETAIN_PAY_APPROV"
						msg_opt$=""
						gosub disp_message
						if msg_opt$="N" then callpoint!.setColumnData("APE_MANCHECKHDR.RETAIN_APPROVALS","N")
					endif
				else
					callpoint!.setStatus("ABORT")
				endif
			else
				rem --- Recycle? (check is Void or Reversed)

				if pos(apt05a.trans_type$="VR") then
					x=num(apt05a.check_no$,err=*endif); rem --- Cannot re-use ACH check numbers, which contain an alpha character.
					msg_id$="AP_OPEN_CHK"
					msg_opt$=""
					gosub disp_message

					if msg_opt$="Y"
						user_tpl.reuse_chk$="Y"
						callpoint!.setColumnData("APE_MANCHECKHDR.TRANS_TYPE","M",1)
					else
						callpoint!.setStatus("ABORT")
					endif
				endif
			endif
		else
			rem --- Cannot enter a new ACH check number. Must be an existing ACH check number, i.e. it is not numeric.
			checkNo=-1
			checkNo=num(check_no$,err=*next)		
			if checkNo<0 then
				callpoint!.setColumnData("APE_MANCHECKHDR.CHECK_NO","",1)
				callpoint!.setStatus("ABORT")
				break
			endif
		endif
	endif

[[APE_MANCHECKHDR.TRANS_TYPE.AVAL]]
if callpoint!.getUserInput()="R"
	msg_id$="AP_REUSE_ERR"
	gosub disp_message
	callpoint!.setStatus("ABORT")

	rem --- Disable Print Check button
	callpoint!.setOptionEnabled("PCHK",0)
endif

if callpoint!.getUserInput()="V"
	ctl_name$="APE_MANCHECKHDR.VENDOR_ID"
	ctl_stat$="D"
	gosub disable_fields
	gosub disable_grid							

	rem --- Disable Print Check button
	callpoint!.setOptionEnabled("PCHK",0)
endif
						
if callpoint!.getUserInput()="M"
	ctl_name$="APE_MANCHECKHDR.VENDOR_ID"
	ctl_stat$=" "
	gosub disable_fields
	gosub enable_grid							

	rem --- Enable Print Check button if manual check is for more than zero and hasn't been printed yet
	if num(callpoint!.getColumnData("<<DISPLAY>>.DISP_TOT_CHECK"))>0 and 
:		callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_PRINTED")<>"Y" then callpoint!.setOptionEnabled("PCHK",1)
endif

rem --- Preventing manual check from being modified after it has been printed on-demand, except for changing Trans Type to Void (V).
	if callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_PRINTED")="Y" then
		callpoint!.setColumnEnabled("APE_MANCHECKHDR.VENDOR_ID",0)
		callpoint!.setColumnEnabled("APE_MANCHECKHDR.CHECK_DATE",0)
		gosub disable_grid
	endif

[[APE_MANCHECKHDR.VENDOR_ID.AVAL]]
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
	   callpoint!.setStatus("ACTIVATE")
	endif
	tmp_vendor_id$=callpoint!.getUserInput()			
	gosub disp_vendor_comments
	gosub get_vendor_history
	if vend_hist$=""
		if user_tpl.multi_types$="Y"
			msg_id$="AP_VEND_BAD_APTYPE"
			gosub disp_message
			callpoint!.setStatus("CLEAR;NEWREC")
		endif
	endif

	callpoint!.setColumnData("APE_MANCHECKHDR.VENDOR_NAME",apm01a.vendor_name$)

[[APE_MANCHECKHDR.VENDOR_ID.BINP]]
rem --- set devObject with AP Type and a temp vend indicator, so if we decide to set up a temporary vendor from here,
rem --- we'll know which AP type to use, and we can automatically set the temp vendor flag in the vendor master

callpoint!.setDevObject("passed_in_temp_vend","Y")
callpoint!.setDevObject("passed_in_AP_type",callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE"))

[[APE_MANCHECKHDR.VENDOR_ID.BINQ]]
rem --- Set filter_defs$[] to only show vendors of given AP Type

ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")

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
:		"AP_VEND_PAYTO",
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
	callpoint!.setColumnData("APE_MANCHECKHDR.VENDOR_ID",apm_vend_key.vendor_id$,1)
endif	
callpoint!.setStatus("ACTIVATE-ABORT")

[[APE_MANCHECKHDR.<CUSTOM>]]
disp_vendor_comments:
	apm01_dev=fnget_dev("APM_VENDMAST")
	dim apm01a$:fnget_tpl$("APM_VENDMAST")
	readrecord(apm01_dev,key=firm_id$+tmp_vendor_id$,dom=*next)apm01a$
	callpoint!.setColumnData("<<DISPLAY>>.comments",apm01a.memo_1024$,1)
return

disable_grid:
	w!=Form!.getChildWindow(1109)
	c!=w!.getControl(5900)
	c!.setEnabled(0)
return

enable_grid:
	w!=Form!.getChildWindow(1109)
	c!=w!.getControl(5900)
	c!.setEnabled(1)
return

disable_fields:
	rem --- used to disable/enable controls depending on parameter settings
	rem --- send in control to toggle (format "ALIAS.CONTROL_NAME"), and D or space to disable/enable
	wctl$=str(num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI")):"00000")
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)=ctl_stat$
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP")
return

calc_tots:
	recVect!=GridVect!.getItem(0)
	dim gridrec$:dtlg_param$[1,3]
	numrecs=recVect!.size()
	tinv=0,tdisc=0,tret=0
	if numrecs>0
		for reccnt=0 to numrecs-1
			gridrec$=recVect!.getItem(reccnt)
			tinv=tinv+gridrec.invoice_amt
			tdisc=tdisc+gridrec.discount_amt
			tret=tret+gridrec.retention
		next reccnt
	endif
return

disp_tots:
    rem --- get context and ID of display controls for totals, and redisplay w/ amts from calc_tots
    
    tinv!=UserObj!.getItem(num(user_tpl.tinv_vpos$))
    tinv!.setValue(tinv)
    tdisc!=UserObj!.getItem(num(user_tpl.tdisc_vpos$))
    tdisc!.setValue(tdisc)
    tret!=UserObj!.getItem(num(user_tpl.tret_vpos$))
    tret!.setValue(tret)
    tchk!=UserObj!.getItem(num(user_tpl.tchk_vpos$))
    tchk!.setValue(tinv-tdisc-tret)
    return

get_vendor_history:
	apm02_dev=fnget_dev("APM_VENDHIST")				
	dim apm02a$:fnget_tpl$("APM_VENDHIST")
	vend_hist$=""
	readrecord(apm02_dev,key=firm_id$+tmp_vendor_id$+
:		callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE"),dom=*next)apm02a$
	if apm02a.firm_id$+apm02a.vendor_id$+apm02a.ap_type$=firm_id$+tmp_vendor_id$+
:		callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
			user_tpl.dflt_dist_cd$=apm02a.ap_dist_code$
			user_tpl.dflt_gl_account$=apm02a.gl_account$
			callpoint!.setDevObject("dflt_gl",apm02a.gl_account$)
			callpoint!.setDevObject("dflt_dist",apm02a.ap_dist_code$)
			vend_hist$="Y"
	endif
return

rem ==========================================================================
get_disk_rec: rem --- Get disk record, update with current form data
              rem     OUT: found - true/false (1/0)
              rem          ordhdr_rec$, updated (if record found)
              rem          ordhdr_dev
rem ==========================================================================
	ape02_dev=fnget_dev("APE_MANCHECKHDR")
	ape02_tpl$=fnget_tpl$("APE_MANCHECKHDR")
	dim ape02a$:ape02_tpl$

	ap_type$=callpoint!.getColumnData("APE_MANCHECKHDR.AP_TYPE")
	bnk_acct_cd$=callpoint!.getColumnData("APE_MANCHECKHDR.BNK_ACCT_CD")
	check_no$=callpoint!.getColumnData("APE_MANCHECKHDR.CHECK_NO")
	vendor_id$=callpoint!.getColumnData("APE_MANCHECKHDR.VENDOR_ID")
	found = 0
	extractrecord(ape02_dev,key=firm_id$+ap_type$+bnk_acct_cd$+check_no$+vendor_id$, dom=*next)ape02a$; found = 1; rem Advisory Locking

	rem --- Copy in any form data that's changed
	ape02a$ = util.copyFields(ape02_tpl$, callpoint!)
	ape02a$ = field(ape02a$)

	if !found then 
		writerecord(ape02_dev,  dom=*endif)ape02a$
		ape02_key$=firm_id$+ape02a.ap_type$+ape02a.bnk_acct_cd$+ape02a.check_no$+ape02a.vendor_id$
		extractrecord(ape02_dev,key=ape02_key$)ape02a$; rem Advisory Locking
		callpoint!.setStatus("SETORIG")
	endif
return

#include [+ADDON_LIB]std_missing_params.aon
#include [+ADDON_LIB]std_functions.aon



