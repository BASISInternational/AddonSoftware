[[POE_POHDR.ADIS]]
vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
purch_addr$=callpoint!.getColumnData("POE_POHDR.PURCH_ADDR")
gosub vendor_info
gosub disp_vendor_comments
gosub purch_addr_info
gosub whse_addr_info

rem --- disable drop-ship checkbox, customer, order until/unless no detail exists

dtl!=gridvect!.getItem(0)		
if dtl!.size()
	callpoint!.setDevObject("dtl_posted","Y")
else
	callpoint!.setDevObject("dtl_posted","")
endif
gosub enable_dropship_fields 

rem --- Check if PO receiver or QA receiver exists for this PO.  If so, give warning and don't allow edits
vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")

rem --- Prepare to enable the Edit button and menu
able_map$ = callpoint!.getAbleMap()
if pos("31066B"=able_map$) then able_map$(pos("31066B"=able_map$,8)+6,1)=""; rem Edit (EDB) tool button
if pos("31066M"=able_map$) then able_map$(pos("31066M"=able_map$,8)+6,1)=""; rem Edit (EDB) menu item

poe_rechdr_dev=fnget_dev("POE_RECHDR")
dim poe_rechdr$:fnget_tpl$("POE_RECHDR")
read (poe_rechdr_dev,key=firm_id$+vendor_id$,knum="AO_VEND_RCVR_PO",dom=*next)
while 1
	poe_rechdr_key$=key(poe_rechdr_dev,end=*break)
	if pos(firm_id$+vendor_id$=poe_rechdr_key$)<>1 then break
	read record (poe_rechdr_dev)poe_rechdr$
	if poe_rechdr.po_no$<>po_no$ then continue

	msg_id$="PO_REC_EXISTS"
	gosub disp_message

	rem --- Prepare to disable the Edit button and menu
	if pos("31066B"=able_map$) then able_map$(pos("31066B"=able_map$,8)+6,1)="X"; rem Edit (EDB) tool button
	if pos("31066M"=able_map$) then able_map$(pos("31066M"=able_map$,8)+6,1)="X"; rem Edit (EDB) menu item
	break
wend

rem --- Enable/disable the Edit button and menu
callpoint!.setAbleMap(able_map$)
callpoint!.setStatus("ABLEMAP")

poe_qahdr_dev=fnget_dev("POE_QAHDR")
dim poe_qahdr$:fnget_tpl$("POE_QAHDR")
read (poe_qahdr_dev,key=firm_id$+po_no$+vendor_id$,knum="AO_PO_VEND_RCVR",dom=*next)
read record (poe_qahdr_dev,err=*next)poe_qahdr$
if poe_qahdr.firm_id$=firm_id$ and poe_qahdr.vendor_id$=vendor_id$ and poe_qahdr.po_no$=po_no$
	msg_id$="PO_QA_EXISTS"
	gosub disp_message
	callpoint!.setStatus("NEWREC")
	break
endif

so_lines_used$=callpoint!.getDevObject("so_lines_used")
if so_lines_used$="ALL" then
	msg_id$="PO_ALL_SO_LINES_USED"
	gosub disp_message
endif
if so_lines_used$="SOME" then
	msg_id$="PO_SO_LINES_USED"
	gosub disp_message
endif

[[POE_POHDR.AOPT-COPY]]
rem --- Get vendor to copy this PO to
	call stbl("+DIR_SYP")+"bam_run_prog.bbj", "POE_NEWVENDOR", stbl("+USER_ID"), "MNT", "", table_chans$[all]
	new_vendor$=cvs(callpoint!.getDevObject("new_vendor"),2)
	new_purchAddr$=cvs(callpoint!.getDevObject("new_purchAddr"),2)

rem --- Make sure focus returns to this form
	callpoint!.setStatus("ACTIVATE")

rem --- Save modified records before copying it for the new vendor
	if cvs(new_vendor$,2)="" then break
	if pos("M"=callpoint!.getRecordStatus())
		rem --- Add Barista soft lock for this record if not already in edit mode
		if !callpoint!.isEditMode() then
			rem --- Is there an existing soft lock?
			lock_table$="POE_POHDR"
			lock_record$=current_key$
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

		rem --- Get current form data and write it to disk
		gosub get_disk_rec
		writerecord(poePoHdr_dev)poePoHdr$
	endif

rem --- Copy this PO using new vendor
	call stbl("+DIR_SYP")+"bas_sequences.bbj","PO_NO",seq_id$,rd_table_chans$[all]
	if seq_id$<>"" then
		rem --- Copy header record
		poe_pohdr_dev  = fnget_dev("POE_POHDR")
		dim poe_pohdr$:fnget_tpl$("POE_POHDR")
		po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")
		found = 0
		extractrecord(poe_pohdr_dev, key=firm_id$+po_no$, dom=*next)poe_pohdr$; found = 1; rem Advisory Locking
		if found then
			poe_pohdr.po_no$=seq_id$
			poe_pohdr.vendor_id$=new_vendor$
			poe_pohdr.purch_addr$=new_purchAddr$
			poe_pohdr.req_no$=""
			poe_pohdr.entered_by$=""

			poe_pohdr$=field(poe_pohdr$)
			write record (poe_pohdr_dev) poe_pohdr$
			poe_pohdr_key$=poe_pohdr.firm_id$+poe_pohdr.po_no$
			extractrecord(poe_pohdr_dev,key=poe_pohdr_key$)poe_pohdr$; rem Advisory Locking
			callpoint!.setStatus("SETORIG")

			rem --- Copy detail records
			poe_podet_dev = fnget_dev("POE_PODET")
			dim poe_podet$:fnget_tpl$("POE_PODET")
			poe_podet_dev2=fnget_dev("2_POE_PODET")
			poc_linecode_dev=fnget_dev("POC_LINECODE")
			dim poc_linecode$:fnget_tpl$("POC_LINECODE")

			rem --- Initialize ATAMO
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status

			read(poe_podet_dev, key=firm_id$+po_no$,dom=*next)
			while 1
				poe_podet_key$=key(poe_podet_dev,end=*break)
				if pos(firm_id$+po_no$=poe_podet_key$)<>1 then break
				readrecord(poe_podet_dev)poe_podet$
				call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
				poe_podet.po_no$=poe_pohdr.po_no$
				poe_podet.internal_seq_no$=int_seq_no$

				status=0
				call stbl("+DIR_PGM")+"poc_itemvend.aon","R","P",
:					poe_pohdr.vendor_id$,
:					poe_pohdr.ord_date$,
:					poe_podet.item_id$,
:					poe_podet.conv_factor,
:					unit_cost,
:					poe_podet.qty_ordered,
:					callpoint!.getDevObject("iv_prec"),
:					status

				if status=0 then poe_podet.unit_cost=unit_cost
				poe_podet$=field(poe_podet$)
				writerecord(poe_podet_dev2)poe_podet$

				rem --- Update On Order quantity for this item, unless it's a dropship PO
				if callpoint!.getColumnData("POE_POHDR.DROPSHIP")<>"Y"
					redim poc_linecode$
					find record (poc_linecode_dev,key=firm_id$+poe_podet.po_line_code$,dom=*next)poc_linecode$
					if poc_linecode.line_type$="S"
						items$[0]=firm_id$
						items$[1]=poe_podet.warehouse_id$
						items$[2]=poe_podet.item_id$
						refs[0]=poe_podet.qty_ordered*poe_podet.conv_factor
						action$="OO"
						call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status
					endif
				endif
			wend
			callpoint!.setStatus("RECORD:["+poe_pohdr.firm_id$+poe_pohdr.po_no$+"]")
		else
			callpoint!.setStatus("NEWREC")
		endif
	endif

rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[POE_POHDR.AOPT-DPRT]]
rem --- PO changes must be saved before on-demand PO print

	if callpoint!.getRecordStatus()="M" then
		msg_id$="PO_SAVE_REQUIRED"
		gosub disp_message
	else
		vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
		po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")

		if cvs(vendor_id$,3)<>"" and cvs(po_no$,3)<>""
			gosub queue_for_printing

			dim dflt_data$[2,1]

			dflt_data$[1,0]="PO_NO"
			dflt_data$[1,1]=po_no$
			dflt_data$[2,0]="VENDOR_ID"
			dflt_data$[2,1]=vendor_id$

			call stbl("+DIR_SYP")+"bam_run_prog.bbj","POR_POPRINT_DMD",stbl("+USER_ID"),"","",table_chans$[all],"",dflt_data$[all]

		endif
	endif

[[POE_POHDR.AOPT-DUPP]]
rem --- Duplicate Old PO
	dim filter_defs$[2,2]
	filter_defs$[1,0] = "POT_POHDR_ARC.FIRM_ID"
	filter_defs$[1,1] = "='"+firm_id$+"'"
	filter_defs$[1,2] = "LOCK"
	if cvs(callpoint!.getColumnData("POE_POHDR.VENDOR_ID"),2)<>"" then
		filter_defs$[2,0] = "POT_POHDR_ARC.VENDOR_ID"
		filter_defs$[2,1] = "='"+callpoint!.getColumnData("POE_POHDR.VENDOR_ID")+"'"
		filter_defs$[2,2] = "LOCK"
	endif

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"PO_HIST_PO",
:		"DEFAULT",
:		table_chans$[all],
:		sel_key$,
:		filter_defs$[all]

	if sel_key$<>""
		call stbl("+DIR_SYP")+"bac_key_template.bbj",
:			"POT_POHDR_ARC",
:			"PRIMARY",
:			pot_pohdr_key$,
:			table_chans$[all],
:			status$

		if cvs(callpoint!.getColumnData("POE_POHDR.PO_NO"),2)="" then
			call stbl("+DIR_SYP")+"bas_sequences.bbj","PO_NO",seq_id$,rd_table_chans$[all]
		else
			seq_id$=callpoint!.getColumnData("POE_POHDR.PO_NO")
		endif
		if seq_id$<>"" then
			rem --- Copy header record
			poe_pohdr_dev = fnget_dev("POE_POHDR")
			dim poe_pohdr$:fnget_tpl$("POE_POHDR")

			pot_pohdr_dev = fnget_dev("POT_POHDR_ARC")
			dim pot_pohdr$:fnget_tpl$("POT_POHDR_ARC")
			dim pot_pohdr_key$:pot_pohdr_key$
			pot_pohdr_key$=sel_key$(1,len(pot_pohdr_key$))
			read record (pot_pohdr_dev, key=pot_pohdr_key$,dom=*endif) pot_pohdr$

			call stbl("+DIR_PGM")+"adc_copyfile.aon",pot_pohdr$,poe_pohdr$,status
			if status=0 then
				dim sysinfo$:stbl("+SYSINFO_TPL")
				sysinfo$=stbl("+SYSINFO")
				today$=sysinfo.system_date$
				today_jul=jul(num(today$(1,4)),num(today$(5,2)),num(today$(7,2)))
				rec_ord_date_jul=jul(num(pot_pohdr.ord_date$(1,4)),num(pot_pohdr.ord_date$(5,2)),num(pot_pohdr.ord_date$(7,2)))
				rec_promise_date_jul=jul(num(pot_pohdr.promise_date$(1,4)),num(pot_pohdr.promise_date$(5,2)),num(pot_pohdr.promise_date$(7,2)))
				rec_not_b4_date_jul=jul(num(pot_pohdr.not_b4_date$(1,4)),num(pot_pohdr.not_b4_date$(5,2)),num(pot_pohdr.not_b4_date$(7,2)))
				rec_reqd_date_jul=jul(num(pot_pohdr.reqd_date$(1,4)),num(pot_pohdr.reqd_date$(5,2)),num(pot_pohdr.reqd_date$(7,2)))

				poe_pohdr.po_no$=seq_id$
				poe_pohdr.req_no$=""
				poe_pohdr.ord_date$=today$
				if cvs(pot_pohdr.promise_date$,2)<>"" then poe_pohdr.promise_date$=date(today_jul+(rec_promise_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
				if cvs(pot_pohdr.not_b4_date$,2)<>"" poe_pohdr.not_b4_date$=date(today_jul+(rec_not_b4_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
				if cvs(pot_pohdr.reqd_date$,2)<>"" poe_pohdr.reqd_date$=date(today_jul+(rec_reqd_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
				poe_pohdr.recpt_date$=""
				poe_pohdr.entered_by$=""

				poe_pohdr$=field(poe_pohdr$)
				write record (poe_pohdr_dev) poe_pohdr$
				poe_pohdr_key$=poe_pohdr.firm_id$+poe_pohdr.po_no$
				extractrecord(poe_pohdr_dev,key=poe_pohdr_key$)poe_pohdr$; rem Advisory Locking
				callpoint!.setStatus("SETORIG")

				rem --- Copy detail records
				poe_podet_dev = fnget_dev("POE_PODET")
				dim poe_podet$:fnget_tpl$("POE_PODET")
				poc_linecode_dev=fnget_dev("POC_LINECODE")
				dim poc_linecode$:fnget_tpl$("POC_LINECODE")

				rem --- Initialize ATAMO
				call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status

				pot_podet_dev = fnget_dev("POT_PODET_ARC")
				dim pot_podet$:fnget_tpl$("POT_PODET_ARC")
				read(pot_podet_dev, key=pot_pohdr_key$,dom=*next)
				while 1
					pot_podet_key$=key(pot_podet_dev,end=*break)
					if pos(pot_pohdr_key$=pot_podet_key$)<>1 then break
					readrecord(pot_podet_dev)pot_podet$

					redim poe_podet$
					call stbl("+DIR_PGM")+"adc_copyfile.aon",pot_podet$,poe_podet$,status
					if status then continue

					call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
					recdet_reqd_date_jul=jul(num(pot_podet.reqd_date$(1,4)),num(pot_podet.reqd_date$(5,2)),num(pot_podet.reqd_date$(7,2)))
					recdet_promise_date_jul=jul(num(pot_podet.promise_date$(1,4)),num(pot_podet.promise_date$(5,2)),num(pot_podet.promise_date$(7,2)))
					recdet_not_b4_date_jul=jul(num(pot_podet.not_b4_date$(1,4)),num(pot_podet.not_b4_date$(5,2)),num(pot_podet.not_b4_date$(7,2)))

					poe_podet.po_no$=poe_pohdr.po_no$
					poe_podet.internal_seq_no$=int_seq_no$
					if cvs(pot_podet.reqd_date$,2)<>"" poe_podet.reqd_date$=date(today_jul+(recdet_reqd_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
					if cvs(pot_podet.promise_date$,2)<>"" then poe_podet.promise_date$=date(today_jul+(recdet_promise_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
					if cvs(pot_podet.not_b4_date$,2)<>"" poe_podet.not_b4_date$=date(today_jul+(recdet_not_b4_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
					poe_podet.req_no$=""
					poe_podet.wo_no$=""
					poe_podet.wk_ord_seq_ref$=""
					poe_podet.so_int_seq_ref$=""
					poe_podet.qty_received=0
					poe_podet.qty_invoiced=0

					status=0
					call stbl("+DIR_PGM")+"poc_itemvend.aon","R","P",
:						poe_pohdr.vendor_id$,
:						poe_pohdr.ord_date$,
:						poe_podet.item_id$,
:						poe_podet.conv_factor,
:						unit_cost,
:						poe_podet.qty_ordered,
:						callpoint!.getDevObject("iv_prec"),
:						status

					if status=0 then poe_podet.unit_cost=unit_cost
					poe_podet$=field(poe_podet$)
					write record (poe_podet_dev) poe_podet$

					rem --- Update On Order quantity for this item, unless it's a dropship PO
					if callpoint!.getColumnData("POE_POHDR.DROPSHIP")<>"Y"
						redim poc_linecode$
						find record (poc_linecode_dev,key=firm_id$+poe_podet.po_line_code$,dom=*next)poc_linecode$
						if poc_linecode.line_type$="S"
							items$[0]=firm_id$
							items$[1]=poe_podet.warehouse_id$
							items$[2]=poe_podet.item_id$
							refs[0]=poe_podet.qty_ordered*poe_podet.conv_factor
							action$="OO"
							call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status
						endif
					endif
				wend
				callpoint!.setStatus("RECORD:["+poe_pohdr.firm_id$+poe_pohdr.po_no$+"]")
			endif
		endif
	endif

[[POE_POHDR.AOPT-QPRT]]
rem --- PO number and vendor ID required for printing PO

	vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
	po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")

	if cvs(vendor_id$,3)<>"" and cvs(po_no$,3)<>""
		gosub queue_for_printing
		msg_id$="PO_QPRT"
		gosub disp_message
	endif

[[POE_POHDR.APFE]]
rem --- set total order amt

total_amt=num(callpoint!.getDevObject("total_amt"))
callpoint!.setColumnData("<<DISPLAY>>.ORDER_TOTAL",str(total_amt),1)
tamt!=callpoint!.getDevObject("tamt")
tamt!.setValue(total_amt)

rem --- check dtl_posted flag to see if dropship fields should be disabled

gosub enable_dropship_fields 

rem --- enable/disable buttons

	po_no$=cvs(callpoint!.getColumnData("POE_POHDR.PO_NO"),3)
	req_no$=cvs(callpoint!.getColumnData("POE_POHDR.REQ_NO"),3)

	if po_no$<>"" then
		callpoint!.setOptionEnabled("QPRT",1)
		callpoint!.setOptionEnabled("DPRT",1)
		callpoint!.setOptionEnabled("DUPP",0)
		callpoint!.setOptionEnabled("COPY",1)
	else
		callpoint!.setOptionEnabled("QPRT",0)
		callpoint!.setOptionEnabled("DPRT",0)
		callpoint!.setOptionEnabled("DUPP",1)
		callpoint!.setOptionEnabled("COPY",0)
	endif

[[POE_POHDR.AP_TERMS_CODE.AVAL]]
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

[[POE_POHDR.ARAR]]
vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
purch_addr$=callpoint!.getColumnData("POE_POHDR.PURCH_ADDR")
gosub vendor_info
gosub purch_addr_info
gosub whse_addr_info
gosub form_inits

rem ---	depending on whether or not drop-ship flag is selected and OE is installed...
rem ---	if drop-ship is selected, load up sales order line#'s for the detail grid's so reference listbutton

callpoint!.setDevObject("so_lines_used","")
if callpoint!.getColumnData("POE_POHDR.DROPSHIP")="Y"

	if callpoint!.getDevObject("OP_installed")="Y"
		tmp_customer_id$=callpoint!.getColumnData("POE_POHDR.CUSTOMER_ID")
		tmp_order_no$=callpoint!.getColumnData("POE_POHDR.ORDER_NO")
		gosub get_dropship_order_lines

	endif
endif

rem --- Show Purchase Order Print Report Controls
admRptCtlRcp=fnget_dev("ADM_RPTCTL_RCP")
dim admRptCtlRcp$:fnget_tpl$("ADM_RPTCTL_RCP")
admRptCtlRcp.dd_table_alias$="POR_POPRINT"
vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
readrecord(admRptCtlRcp,key=firm_id$+vendor_id$+admRptCtlRcp.dd_table_alias$,knum="AO_VEND_ALIAS",dom=*next)admRptCtlRcp$
if admRptCtlRcp.email_yn$<>"Y" and admRptCtlRcp.fax_yn$<>"Y" then
	callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_NONE"))
else
	if admRptCtlRcp.email_yn$="Y" and admRptCtlRcp.fax_yn$="Y" then
		callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_EMAIL")+" + "+Translate!.getTranslation("AON_FAX"))
	else
		if admRptCtlRcp.email_yn$="Y" then
			callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_EMAIL")+" "+Translate!.getTranslation("AON_ONLY"))
		else
			callpoint!.setColumnData("<<DISPLAY>>.RPT_CTL",Translate!.getTranslation("AON_FAX")+" "+Translate!.getTranslation("AON_ONLY"))
		endif
	endif
endif

[[POE_POHDR.AREC]]
gosub  form_inits

[[POE_POHDR.ARNF]]
rem -- set default values
rem --- IV Params
	ivs_params_chn=fnget_dev("IVS_PARAMS")
	dim ivs_params$:fnget_tpl$("IVS_PARAMS")
	read record(ivs_params_chn,key=firm_id$+"IV00")ivs_params$
rem --- PO Params
	pos_params_chn=fnget_dev("POS_PARAMS")
	dim pos_params$:fnget_tpl$("POS_PARAMS")
	read record(pos_params_chn,key=firm_id$+"PO00")pos_params$
rem --- Set Defaults
	callpoint!.setColumnData("<<DISPLAY>>.ORDER_TOTAL","",1)
	callpoint!.setColumnData("POE_POHDR.WAREHOUSE_ID",ivs_params.warehouse_id$,1)
	gosub whse_addr_info
	callpoint!.setColumnData("POE_POHDR.ORD_DATE",sysinfo.system_date$,1)
	callpoint!.setColumnData("POE_POHDR.PO_FRT_TERMS",pos_params.po_frt_terms$,1)
	callpoint!.setColumnData("POE_POHDR.AP_SHIP_VIA",pos_params.ap_ship_via$,1)
	callpoint!.setColumnData("POE_POHDR.FOB",pos_params.fob$,1)
	callpoint!.setColumnData("POE_POHDR.HOLD_FLAG",pos_params.hold_flag$,1)
	callpoint!.setColumnData("POE_POHDR.PO_MSG_CODE",pos_params.po_msg_code$,1)

[[POE_POHDR.AWRI]]
rem --- need to put out poe_poprint record

gosub queue_for_printing

[[POE_POHDR.BDEL]]
rem --- don't allow deletion if any detail line on the PO has a non-zero qty received
rem --- otherwise, give option to retain requisition (if applicable), reverse OO quantity, delete print and link records

if callpoint!.getDevObject("qty_received")="Y" 

	msg_id$="PO_NO_DELETE"
	gosub disp_message
	callpoint!.setStatus("ABORT")

else

	rem --- ask if user wants to retain the requisition (if this PO came from one); if so, re-create it

	if cvs(callpoint!.getColumnData("POE_POHDR.REQ_NO"),3)<>""

		msg_id$="PO_RETAIN_REQ"
		msg_opt$=""
		gosub disp_message
		if msg_opt$="Y"

			poe_reqhdr_dev=fnget_dev("POE_REQHDR")
			poe_reqdet_dev=fnget_dev("POE_REQDET")
			poe_pohdr_dev=fnget_dev("POE_POHDR")
			poe_podet_dev=fnget_dev("POE_PODET")
			poc_linecode_dev=fnget_dev("POC_LINECODE")

			dim poe_reqhdr$:fnget_tpl$("POE_REQHDR")
			dim poe_reqdet$:fnget_tpl$("POE_REQDET")
			dim poe_pohdr$:fnget_tpl$("POE_POHDR")
			dim poe_podet$:fnget_tpl$("POE_PODET")
			dim poc_linecode$:fnget_tpl$("POC_LINECODE")

			po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")
			
			read record (poe_pohdr_dev,key=firm_id$+po_no$,dom=*break) poe_pohdr$
			call stbl("+DIR_PGM")+"adc_copyfile.aon",poe_pohdr$,poe_reqhdr$,status	
			poe_reqhdr$=field(poe_reqhdr$)
			write record (poe_reqhdr_dev) poe_reqhdr$

			read (poe_podet_dev,key=poe_pohdr.firm_id$+poe_pohdr.po_no$,dom=*next)

			while 1
				read record (poe_podet_dev,end=*break)poe_podet$
				if pos(firm_id$+poe_pohdr.po_no$=poe_podet$)<>1 then break
				if num(poe_podet.req_qty$)=0 then continue
				call stbl("+DIR_PGM")+"adc_copyfile.aon",poe_podet$,poe_reqdet$,status
				poe_reqdet.req_no$=poe_reqhdr.req_no$;rem dataport util doesn't yet fill req_no in det recs, so get from hdr
				poe_reqdet$=field(poe_reqdet$)
				write record (poe_reqdet_dev)poe_reqdet$
			wend

			rem --- Update links to Work Orders
			if callpoint!.getDevObject("SF_installed")="Y"
				sfe_womatl_dev=fnget_dev("SFE_WOMATL")
				sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")
				read (poe_reqdet_dev,key=firm_id$+poe_reqhdr.req_no$,dom=*next)
				while 1
					read record (poe_reqdet_dev,end=*break)poe_reqdet$
					if pos(firm_id$+poe_reqhdr.req_no$=poe_reqdet$)<>1 break
					if cvs(poe_reqdet.wo_no$,2)="" continue
					find record(poc_linecode_dev,key=firm_id$+poe_reqdet.po_line_code$,dom=*continue)poc_linecode$
					if pos(poc_linecode.line_type$="NS")=0 continue
					req_no$=poe_reqdet.req_no$
					req_seq$=poe_reqdet.internal_seq_no$
					line_type$=poc_linecode.line_type$
					old_wo$=poe_reqdet.wo_no$
					old_woseq$=poe_reqdet.wk_ord_seq_ref$
					new_wo$=old_wo$
					new_woseq$=old_woseq$
					call "poc_requpdate.aon",def_womatl_dev,sfe_wosubcnt_dev,req_no$,req_seq$,"R",line_type$,old_wo$,old_woseq$,new_wo$,new_woseq$,status
				wend
			endif
		else		
			rem --- Requisition NOT retained

			rem --- Update links to Work Orders
			if callpoint!.getDevObject("SF_installed")="Y" then
				po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")
				poe_podet_dev=fnget_dev("POE_PODET")
				dim poe_podet$:fnget_tpl$("POE_PODET")
				poc_linecode_dev=fnget_dev("POC_LINECODE")
				dim poc_linecode$:fnget_tpl$("POC_LINECODE")
				sfe_womatl_dev=fnget_dev("SFE_WOMATL")
				sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")

				read (poe_podet_dev,key=firm_id$+po_no$,dom=*next)
				while 1
					poe_podet_key$=key(poe_podet_dev,end=*break)
            				if pos(firm_id$+po_no$=poe_podet_key$)<>1 then break
					read record (poe_podet_dev) poe_podet$
					if cvs(poe_podet.wo_no$,2)="" then continue

					dim poc_linecode$:fattr(poc_linecode$)
					find record (poc_linecode_dev,key=firm_id$+poe_podet.po_line_code$,dom=*continue) poc_linecode$
					if pos(poc_linecode.line_type$="NS")<>0 then
						old_wo$=poe_podet.wo_no$
						old_woseq$=poe_podet.wk_ord_seq_ref$
						new_wo$=""
						new_woseq$=""
						po_no$=poe_podet.po_no$
						po_seq$=poe_podet.internal_seq_no$
						call pgmdir$+"poc_requpdate.aon",sfe_womatl_dev,sfe_wosubcnt_dev,
:							po_no$,po_seq$,"P",poc_linecode.line_type$,old_wo$,old_woseq$,new_wo$,new_woseq$,status
					endif
				wend
			endif
		endif
	endif

	rem ---  loop thru gridVect! and call atamo to reverse OO qty for each dtl row that isn't already marked deleted (skip dropship orders)

	if callpoint!.getColumnData("POE_POHDR.DROPSHIP")<>"Y"
		g!=gridVect!.getItem(0)
		dim poe_podet$:dtlg_param$[1,3]

		if g!.size()	
			for x=0 to g!.size()-1
				if callpoint!.getGridRowDeleteStatus(x)<>"Y"
					poe_podet$=g!.getItem(x)

					status = 999
					call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status
					if status then goto std_exit
		 
					items$[0]=firm_id$
		 			items$[1]=poe_podet.warehouse_id$
					items$[2]=poe_podet.item_id$
					refs[0]=-(poe_podet.qty_ordered - poe_podet.qty_received)*poe_podet.conv_factor
					action$="OO"

					if refs[0]<>0 then call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status
				endif
			next x
		endif
	endif

	rem ---  delete PO print records, and poe_linked records for dropships

	poe_poprint_dev=fnget_dev("POE_POPRINT")
	remove (poe_poprint_dev,key=firm_id$+callpoint!.getColumnData("POE_POHDR.VENDOR_ID")+callpoint!.getColumnData("POE_POHDR.PO_NO"),dom=*next)

	if callpoint!.getColumnData("POE_POHDR.DROPSHIP")="Y"

		poe_linked_dev=fnget_dev("POE_LINKED")
		dim poe_linked$:fnget_tpl$("POE_LINKED")
		read (poe_linked_dev,key=firm_id$+callpoint!.getColumnData("POE_POHDR.PO_NO"),dom=*next)

		while 1
			k$=key(poe_linked_dev,end=*break)
			read record (poe_linked_dev)poe_linked$
			if pos(firm_id$+callpoint!.getColumnData("POE_POHDR.PO_NO")=poe_linked$)<>1 then break
			remove (poe_linked_dev,key=k$)
		wend

	endif

endif

[[POE_POHDR.BPFX]]
rem --- disable buttons

	callpoint!.setOptionEnabled("QPRT",0)
	callpoint!.setOptionEnabled("DPRT",0)
	callpoint!.setOptionEnabled("DUPP",0)
	callpoint!.setOptionEnabled("COPY",0)

[[POE_POHDR.BSHO]]
rem print 'show';rem debug
rem --- inits

	use ::ado_func.src::func
	use ::ado_util.src::util
	use java.util.Properties

rem --- Open Files
	num_files=28
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="IVS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="POS_PARAMS",open_opts$[3]="OTA"
	open_tables$[4]="APM_VENDHIST",open_opts$[4]="OTA"
	open_tables$[5]="IVM_ITEMWHSE",open_opts$[5]="OTA"
	open_tables$[6]="IVM_ITEMVEND",open_opts$[6]="OTA"
	open_tables$[7]="POE_REQHDR",open_opts$[7]="OTA"
	open_tables$[8]="POE_REQDET",open_opts$[8]="OTA"
	open_tables$[9]="POE_POPRINT",open_opts$[9]="OTA"
	open_tables$[10]="IVM_ITEMMAST",open_opts$[10]="OTA"
	open_tables$[11]="POE_LINKED",open_opts$[11]="OTA"
	open_tables$[12]="IVM_ITEMSYN",open_opts$[12]="OTA"
	open_tables$[13]="POE_REQPRINT",open_opts$[13]="OTA"
	open_tables$[14]="POE_QAHDR",open_opts$[14]="OTA"
	open_tables$[15]="POE_RECHDR",open_opts$[15]="OTA"
	open_tables$[16]="POE_INVDET",open_opts$[16]="OTA"
	open_tables$[17]="APM_VENDMAST",open_opts$[17]="OTA"
	open_tables$[18]="POE_RECDET",open_opts$[18]="OTA"
	open_tables$[19]="APM_VENDADDR",open_opts$[19]="OTA"
	open_tables$[20]="POT_RECHDR",open_opts$[20]="OTA"
	open_tables$[21]="POT_RECDET",open_opts$[21]="OTA"
	open_tables$[22]="ADM_RPTCTL_RCP",open_opts$[22]="OTA"
	open_tables$[23]="POT_POHDR_ARC",open_opts$[23]="OTA"
	open_tables$[24]="POT_PODET_ARC",open_opts$[24]="OTA"
	open_tables$[25]="POE_PODET",open_opts$[25]="OTAN[2_]"
	open_tables$[26]="POT_REQHDR_ARC",open_opts$[26]="OTA"
	open_tables$[27]="POT_REQDET_ARC",open_opts$[27]="OTA"
	open_tables$[28]="APC_TERMSCODE",open_opts$[28]="OTA"

	gosub open_tables

	aps_params_dev=num(open_chans$[1]),aps_params_tpl$=open_tpls$[1]
	ivs_params_dev=num(open_chans$[2]),ivs_params_tpl$=open_tpls$[2]
	pos_params_dev=num(open_chans$[3]),pos_params_tpl$=open_tpls$[3]
	apm_vendhist_dev=num(open_chans$[4]),apm_vendhist_tpl$=open_tpls$[4]
	ivm_itemwhse_dev=num(open_chans$[5]),ivm_itemwhse_tpl$=open_tpls$[5]
	ivm_itemvend_dev=num(open_chans$[6]),ivm_itemvend_tpl$=open_tpls$[6]
	poe_reqhdr_dev=num(open_chans$[7]),poe_reqhdr_tpl$=open_tpls$[7]
	poe_reqdet_dev=num(open_chans$[8]),poe_reqdet_tpl$=open_tpls$[8]
	poe_poprint_dev=num(open_chans$[9]),poe_poprint_tpl$=open_tpls$[9]


rem --- Verify that there are line codes - abort if not.

	poc_linecode_dev=fnget_dev("POC_LINECODE")
	readrecord(poc_linecode_dev,key=firm_id$,dom=*next)
	found_one$="N"
	while 1
		poc_linecode_key$=key(poc_linecode_dev,end=*break)
		if pos(firm_id$=poc_linecode_key$)=1 found_one$="Y"
		break
	wend
	if found_one$="N"
		msg_id$="MISSING_LINECODE"
		gosub disp_message
		release
	endif

rem --- call adc_application to see if AR is installed; if so, open a couple tables for potential use if linking dropship to customer

	dim info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","AR",info$[all]
	callpoint!.setDevObject("AR_installed",info$[20])
	if info$[20]="Y"
		num_files=2
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="ARM_CUSTMAST",open_opts$[1]="OTA"
		open_tables$[2]="ARM_CUSTSHIP",open_opts$[2]="OTA"

		gosub open_tables
	else
		rem --- dropship not allowed without AR
		callpoint!.setTableColumnAttribute("POE_POHDR.DROPSHIP","DFLT", "N")
		callpoint!.setColumnEnabled("POE_POHDR.DROPSHIP",-1)
	endif

rem --- call adc_application to see if OP is installed; if so, open a couple tables for potential use if linking PO to SO for dropship

	dim info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
	callpoint!.setDevObject("OP_installed",info$[20])
	if info$[20]="Y"
		num_files=4
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="OPE_ORDSHIP",open_opts$[1]="OTA"
		open_tables$[2]="OPE_ORDHDR",open_opts$[2]="OTA"
		open_tables$[3]="OPE_ORDDET",open_opts$[3]="OTA"
		open_tables$[4]="OPC_LINECODE",open_opts$[4]="OTA"

		gosub open_tables
	
		opc_linecode_dev=num(open_chans$[4])
		dim opc_linecode$:open_tpls$[4]
		
		let oe_dropship$=""
		read record (opc_linecode_dev,key=firm_id$,dom=*next)
		
		while 1
			read record (opc_linecode_dev,end=*break)opc_linecode$
			if opc_linecode.firm_id$<>firm_id$ then break
			if opc_linecode.dropship$="Y" then oe_dropship$=oe_dropship$+opc_linecode.line_code$
		wend
		
		callpoint!.setDevObject("oe_ds_line_codes",oe_dropship$)
	else
		rem --- Sale order number not allowed without OP
		callpoint!.setColumnEnabled("POE_POHDR.ORDER_NO",-1)
	endif

rem --- call adc_application to see if SF is installed

	dim info$[20]
	call stbl("+DIR_PGM")+"adc_application.aon","SF",info$[all]
	callpoint!.setDevObject("SF_installed",info$[20])
	if info$[20]="Y"
		num_files=3
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="SFE_WOMATL",open_opts$[1]="OTA"
		open_tables$[2]="SFE_WOSUBCNT",open_opts$[2]="OTA"
		open_tables$[3]="SFE_WOMASTR",open_opts$[3]="OTA"
		gosub open_tables
	endif

rem --- AP Params
	dim aps_params$:aps_params_tpl$
	read record(aps_params_dev,key=firm_id$+"AP00")aps_params$

rem --- store total amount control in devObject

	tamt!=util.getControl(callpoint!,"<<DISPLAY>>.ORDER_TOTAL")
	callpoint!.setDevObject("tamt",tamt!)

rem --- store default PO Line Code from POS_PARAMS
	
	dim pos_params$:fnget_tpl$("POS_PARAMS")
	read record (pos_params_dev,key=firm_id$+"PO00")pos_params$
	callpoint!.setDevObject("dflt_po_line_code",pos_params.po_line_code$)
	
rem --- get IV precision

	dim ivs_params$:fnget_tpl$("IVS_PARAMS")
	read record (ivs_params_dev,key=firm_id$+"IV00")ivs_params$
	callpoint!.setDevObject("iv_prec",ivs_params.precision$)
	callpoint!.setDevObject("ivs_params_rec",ivs_params$)	

rem --- store dtlGrid! and column for sales order line# reference listbutton (within grid) in devObject

	dtlWin!=Form!.getChildWindow(1109)
	dtlGrid!=dtlWin!.getControl(5900)
	callpoint!.setDevObject("dtl_grid",dtlGrid!)
	callpoint!.setDevObject("so_seq_ref_col",13)

[[POE_POHDR.CUSTOMER_ID.AVAL]]
if callpoint!.getUserInput()<>callpoint!.getColumnData("POE_POHDR.CUSTOMER_ID") then
	rem --- if dropshipping, retrieve/display specified shipto address
	callpoint!.setColumnData("POE_POHDR.ORDER_NO","",1)
	callpoint!.setColumnData("POE_POHDR.SHIPTO_NO","",1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_1","",1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_2","",1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_3","",1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_4","",1)
	callpoint!.setColumnData("POE_POHDR.DS_CITY","",1)
	callpoint!.setColumnData("POE_POHDR.DS_NAME","",1)
	callpoint!.setColumnData("POE_POHDR.DS_STATE_CD","",1)
	callpoint!.setColumnData("POE_POHDR.DS_ZIP_CODE","",1)

	tmp_customer_id$=callpoint!.getUserInput()
	gosub shipto_cust;rem will refresh address w/ that from order once order# is entered
endif

[[POE_POHDR.DROPSHIP.AVAL]]
rem --- if turning off dropship flag, clear devObject items

dropship$=callpoint!.getUserInput()
if dropship$="N"
	callpoint!.setDevObject("ds_orders","N")
	callpoint!.setDevObject("so_ldat","")
	callpoint!.setDevObject("so_lines_list","")
	callpoint!.setColumnData("POE_POHDR.ORDER_NO","",1)
	callpoint!.setColumnData("POE_POHDR.SHIPTO_NO","",1)
endif

callpoint!.setColumnData("POE_POHDR.DROPSHIP",dropship$,1)
gosub enable_dropship_fields

[[POE_POHDR.NOT_B4_DATE.AVAL]]
ord_date$=cvs(callpoint!.getColumnData("POE_POHDR.ORD_DATE"),2)
req_date$=cvs(callpoint!.getColumnData("POE_POHDR.REQD_DATE"),2)
promise_date$=cvs(callpoint!.getColumnData("POE_POHDR.PROMISE_DATE"),2)
not_b4_date$=cvs(callpoint!.getUserInput(),2)

gosub validate_dates

[[POE_POHDR.ORDER_NO.AVAL]]
rem --- if dropshipping, retrieve specified sales order and display shipto address

if cvs(callpoint!.getColumnData("POE_POHDR.CUSTOMER_ID"),3)<>""

	tmp_customer_id$=callpoint!.getColumnData("POE_POHDR.CUSTOMER_ID")
	tmp_order_no$=callpoint!.getUserInput()

	gosub dropship_shipto
	gosub get_dropship_order_lines

	if callpoint!.getDevObject("ds_orders")<>"Y" and cvs(tmp_order_no$,3)<>""
		msg_id$="PO_NO_SO_LINES"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif			
endif

[[POE_POHDR.ORD_DATE.AVAL]]
ord_date$=cvs(callpoint!.getUserInput(),2)
req_date$=cvs(callpoint!.getColumnData("POE_POHDR.REQD_DATE"),2)
promise_date$=cvs(callpoint!.getColumnData("POE_POHDR.PROMISE_DATE"),2)
not_b4_date$=cvs(callpoint!.getColumnData("POE_POHDR.NOT_B4_DATE"),2)

gosub validate_dates

[[POE_POHDR.PO_NO.AVAL]]
rem --- don't allow user to assign new PO# -- use Barista seq#
rem --- if user made null entry (to assign next seq automatically) then getRawUserInput() will be empty
rem --- if not empty, then the user typed a number -- if an existing po, fine; if not, abort

if cvs(callpoint!.getRawUserInput(),3)<>""
	msk$=callpoint!.getTableColumnAttribute("POE_POHDR.PO_NO","MSKI")
	find_po$=str(num(callpoint!.getRawUserInput()):msk$)
	poe_pohdr_dev=fnget_dev("POE_POHDR")
	dim poe_pohdr$:fnget_tpl$("POE_POHDR")
	read record (poe_pohdr_dev,key=firm_id$+find_po$,dom=*next)poe_pohdr$
	if poe_pohdr.firm_id$<>firm_id$ or  poe_pohdr.po_no$<>find_po$
		msg_id$="PO_INVAL_PO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif
endif

[[POE_POHDR.PROMISE_DATE.AVAL]]
ord_date$=cvs(callpoint!.getColumnData("POE_POHDR.ORD_DATE"),2)
req_date$=cvs(callpoint!.getColumnData("POE_POHDR.REQD_DATE"),2)
promise_date$=cvs(callpoint!.getUserInput(),2)
not_b4_date$=cvs(callpoint!.getColumnData("POE_POHDR.NOT_B4_DATE"),2)

gosub validate_dates

if bad_date$="" then gosub warn_dates

[[POE_POHDR.PURCH_ADDR.AVAL]]
rem --- Don't allow inactive code
	apmVendAddr_dev=fnget_dev("APM_VENDADDR")
	dim apmVendAddr$:fnget_tpl$("APM_VENDADDR")
	purch_addr$=callpoint!.getUserInput()
	vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
	read record(apmVendAddr_dev,key=firm_id$+vendor_id$+purch_addr$,dom=*next)apmVendAddr$
	if apmVendAddr.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(apmVendAddr.purch_addr$,3)
		msg_tokens$[2]=cvs(apmVendAddr.city$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

	gosub purch_addr_info

[[POE_POHDR.REQD_DATE.AVAL]]
ord_date$=cvs(callpoint!.getColumnData("POE_POHDR.ORD_DATE"),2)
req_date$=cvs(callpoint!.getUserInput(),2)
promise_date$=cvs(callpoint!.getColumnData("POE_POHDR.PROMISE_DATE"),2)
not_b4_date$=cvs(callpoint!.getColumnData("POE_POHDR.NOT_B4_DATE"),2)

gosub validate_dates

if bad_date$="" then gosub warn_dates

[[POE_POHDR.REQ_NO.AVAL]]
rem --- Load PO from requisition

req_no$=cvs(callpoint!.getUserInput(),3)
if req_no$<>""

	msg_id$="PO_CREATE_REQ"
	gosub disp_message

	if msg_opt$="Y"

		rem --- write the po and podet recs, plus the print rec and poe_linked rec (if dropship)
		rem --- also call atamo to adjust on order qty for S line types

		status = 999
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",err=*next,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status
		if status then goto std_exit

		poe_reqhdr_dev=fnget_dev("POE_REQHDR")
		dim poe_reqhdr$:fnget_tpl$("POE_REQHDR")
		poe_pohdr_dev=fnget_dev("POE_POHDR")
		dim poe_pohdr$:fnget_tpl$("POE_POHDR")
		poe_reqdet_dev=fnget_dev("POE_REQDET")
		dim poe_reqdet$:fnget_tpl$("POE_REQDET")
		poe_podet_dev=fnget_dev("POE_PODET")
		poe_reqprint_dev=fnget_dev("POE_REQPRINT")
		pot_reqhdr_dev=fnget_dev("POT_REQHDR_ARC")
		dim pot_reqhdr$:fnget_tpl$("POT_REQHDR_ARC")
		pot_reqdet_dev=fnget_dev("POT_REQDET_ARC")

		poe_linked_dev=fnget_dev("POE_LINKED")
		dim poe_linked$:fnget_tpl$("POE_LINKED")
		poe_poprint_dev=fnget_dev("POE_POPRINT")
		dim poe_poprint$:fnget_tpl$("POE_POPRINT")
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")

		po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")
		req_no$=callpoint!.getUserInput()
		
		read record (poe_reqhdr_dev,key=firm_id$+req_no$,dom=*break) poe_reqhdr$
		call stbl("+DIR_PGM")+"adc_copyfile.aon",poe_reqhdr$,poe_pohdr$,status	
		poe_pohdr.po_no$=po_no$
		write record (poe_pohdr_dev) poe_pohdr$
		call stbl("+DIR_PGM")+"adc_copyfile.aon",poe_reqhdr$,pot_reqhdr$,status	
		pot_reqhdr.po_no$=po_no$
		write record (pot_reqhdr_dev) pot_reqhdr$

		poe_poprint.firm_id$=firm_id$
		poe_poprint.vendor_id$=poe_pohdr.vendor_id$
		poe_poprint.po_no$=poe_pohdr.po_no$
		write record (poe_poprint_dev)poe_poprint$

		read record(poe_reqdet_dev,key=firm_id$+req_no$,dom=*next)

		while 1
			read record(poe_reqdet_dev,end=*break) poe_reqdet$
			if poe_reqdet.req_no$<>req_no$ or poe_reqdet.firm_id$<>firm_id$ then break
			dim poe_podet$:fnget_tpl$("POE_PODET")
			call stbl("+DIR_PGM")+"adc_copyfile.aon",poe_reqdet$,poe_podet$,status
			poe_podet.po_no$=po_no$
			poe_podet.qty_ordered=poe_reqdet.req_qty
			write record (poe_podet_dev) poe_podet$
			write record (pot_reqdet_dev) poe_reqdet$

			find record (poc_linecode_dev,key=firm_id$+poe_podet.po_line_code$,dom=*next)poc_linecode$
			if poc_linecode.line_type$="S"
				items$[0]=firm_id$
				items$[1]=poe_podet.warehouse_id$
				items$[2]=poe_podet.item_id$
				refs[0]=poe_podet.qty_ordered*poe_podet.conv_factor
				action$="OO"
		                call stbl("+DIR_PGM")+"ivc_itemupdt.aon",action$,chan[all],ivs_params$,items$[all],refs$[all],refs[all],table_chans$[all],status
			endif

			rem --- Update work order?

			if callpoint!.getDevObject("SF_installed")<>"N" and pos(poc_linecode.line_type$="NS")<>0 and cvs(poe_podet.wo_no$,2)<>""
				sfe_womatl_dev=fnget_dev("SFE_WOMATL")
				sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")
				old_wo$=poe_podet.wo_no$
				old_woseq$=poe_podet.wk_ord_seq_ref$
				new_wo$=old_wo$
				new_woseq$=old_woseq$
				po_no$=poe_podet.po_no$
				po_seq$=poe_podet.internal_seq_no$
				call stbl("+DIR_PGM")+"poc_requpdate.aon",sfe_womatl_dev,sfe_wosubcnt_dev,
:					po_no$,po_seq$,"P",poc_linecode.line_type$,old_wo$,old_woseq$,new_wo$,new_woseq$,status
			endif

			rem --- Update PO to OP link

			if cvs(poe_pohdr.customer_id$+poe_pohdr.order_no$,2)<>""
				dim poe_linked$:fattr(poe_linked$)
				poe_linked.firm_id$=firm_id$
				poe_linked.po_no$=poe_pohdr.po_no$
				poe_linked.poedet_seq_ref$=poe_podet.internal_seq_no$
				poe_linked.customer_id$=poe_pohdr.customer_id$
				poe_linked.order_no$=poe_pohdr.order_no$
				poe_linked.opedet_seq_ref$=poe_podet.so_int_seq_ref$
				poe_linked$=field(poe_linked$)
				write record (poe_linked_dev) poe_linked$
			endif

		wend

		rem --- delete the requisition

		status=0
		dim files[20]
    		files[2]=poc_linecode_dev
		files[3]=poe_reqhdr_dev
    		files[4]=poe_reqdet_dev
    		files[5]=poe_reqprint_dev
		files[11]=fnget_dev("SFE_WOMATL")
		files[12]=fnget_dev("SFE_WOSUBCNT")
		files[13]=poe_linked_dev
	
		sf_installed$=str(callpoint!.getDevObject("SF_installed"))
        		dtl_tpl$=fattr(poe_reqdet$)
        		hdr_pri_key$=poe_reqhdr.firm_id$+poe_reqhdr.req_no$
       		hdr_alt_key1$=poe_reqhdr.firm_id$+poe_reqhdr.vendor_id$+poe_reqhdr.req_no$
		dim ivs_params$:fnget_tpl$("IVS_PARAMS")
		ivs_params$=str(callpoint!.getDevObject("ivs_params_rec"))
        		call stbl("+DIR_PGM")+"poc_deletepo.aon","R",files[all],sf_installed$,ivs_params$,hdr_pri_key$,hdr_alt_key1$,dtl_tpl$,table_chans$[all],status

		callpoint!.setStatus("RECORD:["+firm_id$+po_no$+"]")

	else

		callpoint!.setStatus("ABORT")

	endif
endif
	

[[POE_POHDR.SHIPTO_NO.AVAL]]
rem --- if dropshipping, retrieve/display specified shipto address

	shipto$=cvs(callpoint!.getUserInput(),3)
	tmp_customer_id$=callpoint!.getColumnData("POE_POHDR.CUSTOMER_ID")
	
	if shipto$="" then
		rem --- no shipto, so use customer's address
		gosub shipto_cust
	else
		arm_custship_dev=fnget_dev("ARM_CUSTSHIP")
		dim arm_custship$:fnget_tpl$("ARM_CUSTSHIP")
		read record (arm_custship_dev,key=firm_id$+tmp_customer_id$+shipto$,dom=*next)arm_custship$
		dim rec$:fattr(arm_custship$)
		rec$=arm_custship$
		gosub fill_dropship_address
		callpoint!.setColumnData("POE_POHDR.DS_NAME",rec.name$,1)
	endif

[[POE_POHDR.VENDOR_ID.AVAL]]
rem --- Update vendor info if vendor changed
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

	if vendor_id$<>callpoint!.getColumnData("POE_POHDR.VENDOR_ID") then
		gosub vendor_info
		gosub disp_vendor_comments

		rem --- Set defaults from Parameter record
		pos_params_chn=fnget_dev("POS_PARAMS")
		dim pos_params$:fnget_tpl$("POS_PARAMS")
		read record(pos_params_chn,key=firm_id$+"PO00")pos_params$
		callpoint!.setColumnData("POE_POHDR.PO_FRT_TERMS",pos_params.po_frt_terms$,1)
		callpoint!.setColumnData("POE_POHDR.AP_SHIP_VIA",pos_params.ap_ship_via$,1)
		callpoint!.setColumnData("POE_POHDR.FOB",pos_params.fob$,1)

		rem --- Now override the defaults with the Vendor info if not blank
		if cvs(apm01a.ap_ship_via$,3)<>""
			callpoint!.setColumnData("POE_POHDR.AP_SHIP_VIA",apm01a.ap_ship_via$,1)
		endif
		if cvs(apm01a.fob$,3)<>""
			callpoint!.setColumnData("POE_POHDR.FOB",apm01a.fob$,1)
		endif
		if cvs(apm01a.po_frt_terms$,3)<>""
			callpoint!.setColumnData("POE_POHDR.PO_FRT_TERMS",apm01a.po_frt_terms$,1)
		endif

		rem --- Use Terms Code from vendor's first AP type record
		apm02_dev=fnget_dev("APM_VENDHIST")
		dim apm02a$:fnget_tpl$("APM_VENDHIST")
		read(apm02_dev,key=firm_id$+vendor_id$,dom=*next)
		tmp$=key(apm02_dev,end=done_apm_vendhist)
		if pos(firm_id$+vendor_id$=tmp$)<>1 then goto done_apm_vendhist
		readrecord(apm02_dev,key=tmp$)apm02a$
		done_apm_vendhist:
		callpoint!.setColumnData("POE_POHDR.AP_TERMS_CODE",apm02a.ap_terms_code$,1)
	endif

[[POE_POHDR.WAREHOUSE_ID.AVAL]]
gosub whse_addr_info

[[POE_POHDR.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon
vendor_info: rem --- get and display Vendor Information
	apm01_dev=fnget_dev("APM_VENDMAST")
	dim apm01a$:fnget_tpl$("APM_VENDMAST")
	read record(apm01_dev,key=firm_id$+vendor_id$,dom=*next)apm01a$
	callpoint!.setColumnData("<<DISPLAY>>.V_ADDR1",apm01a.addr_line_1$,1)
	callpoint!.setColumnData("<<DISPLAY>>.V_ADDR2",apm01a.addr_line_2$,1)
	if cvs(apm01a.city$+apm01a.state_code$+apm01a.zip_code$,3)<>""
		callpoint!.setColumnData("<<DISPLAY>>.V_CITY",cvs(apm01a.city$,3)+", "+apm01a.state_code$+"  "+apm01a.zip_code$,1)
	else
		callpoint!.setColumnData("<<DISPLAY>>.V_CITY","",1)
	endif
	callpoint!.setColumnData("<<DISPLAY>>.V_CNTRY_ID",apm01a.cntry_id$,1)
	callpoint!.setColumnData("<<DISPLAY>>.V_CONTACT",apm01a.contact_name$,1)
	callpoint!.setColumnData("<<DISPLAY>>.V_PHONE",apm01a.phone_no$,1)
	callpoint!.setColumnData("<<DISPLAY>>.V_FAX",apm01a.fax_no$,1)
return

disp_vendor_comments:	
	rem --- You must pass in vendor_id$ because we don't know whether it's verified or not
	apm_vendmast_dev=fnget_dev("APM_VENDMAST")
	dim apm_vendmast$:fnget_tpl$("APM_VENDMAST")
	readrecord(apm_vendmast_dev,key=firm_id$+vendor_id$,dom=*next)apm_vendmast$		 
	callpoint!.setColumnData("<<DISPLAY>>.comments",apm_vendmast.memo_1024$,1)
return

purch_addr_info: rem --- get and display Purchase Address Info
	apm05_dev=fnget_dev("APM_VENDADDR")
	dim apm05a$:fnget_tpl$("APM_VENDADDR")
	read record(apm05_dev,key=firm_id$+vendor_id$+purch_addr$,dom=*next)apm05a$
	callpoint!.setColumnData("<<DISPLAY>>.PA_ADDR1",apm05a.addr_line_1$,1)
	callpoint!.setColumnData("<<DISPLAY>>.PA_ADDR2",apm05a.addr_line_2$,1)
	callpoint!.setColumnData("<<DISPLAY>>.PA_CITY",apm05a.city$,1)
	callpoint!.setColumnData("<<DISPLAY>>.PA_STATE",apm05a.state_code$,1)
	callpoint!.setColumnData("<<DISPLAY>>.PA_ZIP",apm05a.zip_code$,1)
	callpoint!.setColumnData("<<DISPLAY>>.PA_CNTRY_ID",apm05a.cntry_id$,1)
return

whse_addr_info: rem --- get and display Warehouse Address Info when not a dropship
	ivc_whsecode_dev=fnget_dev("IVC_WHSECODE")
	dim ivc_whsecode$:fnget_tpl$("IVC_WHSECODE")
	if callpoint!.getColumnData("POE_POHDR.DROPSHIP")<>"Y" then
		if pos("WAREHOUSE_ID.AVAL"=callpoint!.getCallpointEvent())<>0
			warehouse_id$=callpoint!.getUserInput()
		else
			warehouse_id$=callpoint!.getColumnData("POE_POHDR.WAREHOUSE_ID")
		endif
		read record(ivc_whsecode_dev,key=firm_id$+"C"+warehouse_id$,dom=*next)ivc_whsecode$
	endif
	callpoint!.setColumnData("<<DISPLAY>>.W_ADDR1",ivc_whsecode$.addr_line_1$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_ADDR2",ivc_whsecode$.addr_line_2$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_CITY",ivc_whsecode$.city$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_STATE",ivc_whsecode$.state_code$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_ZIP",ivc_whsecode$.zip_code$,1)
return

dropship_shipto: rem --- get and display shipto from Sales Order if dropship indicated, and OE installed

	ope_ordhdr_dev=fnget_dev("OPE_ORDHDR")
	arm_custship_dev=fnget_dev("ARM_CUSTSHIP")
	ope_ordship_dev=fnget_dev("OPE_ORDSHIP")

	dim ope_ordhdr$:fnget_tpl$("OPE_ORDHDR")
	dim arm_custship$:fnget_tpl$("ARM_CUSTSHIP")
	dim ope_ordship$:fnget_tpl$("OPE_ORDSHIP")

	read(ope_ordhdr_dev,key=firm_id$+ope_ordhdr.ar_type$+tmp_customer_id$+tmp_order_no$,knum="PRIMARY",dom=*next)
	while 1
		dim ope_ordhdr$:fattr(ope_ordhdr$)
		ope_ordhdr_key$=key(ope_ordhdr_dev,end=*break)
		if pos(firm_id$+ope_ordhdr.ar_type$+tmp_customer_id$+tmp_order_no$=ope_ordhdr_key$)<>1 then break
		read record (ope_ordhdr_dev)ope_ordhdr$
		if pos(ope_ordhdr.trans_status$="ER")=0 then continue
		break; rem --- new order can have at most just one new invoice, if any
	wend
	shipto_type$=ope_ordhdr.shipto_type$
	shipto_no$=ope_ordhdr.shipto_no$
	callpoint!.setColumnData("POE_POHDR.SHIPTO_NO",shipto_no$,1)
	if shipto_type$="B" then
		rem --- Bill-To
		gosub shipto_cust
	endif
	if shipto_type$="M" then
		rem --- Manual
		read record (ope_ordship_dev,key=firm_id$+tmp_customer_id$+tmp_order_no$+ope_ordhdr.ar_inv_no$+"S",dom=*next)ope_ordship$
		dim rec$:fattr(ope_ordship$)
		if pos(ope_ordship.trans_status$="ER") then rec$=ope_ordship$
		gosub fill_dropship_address
		callpoint!.setColumnData("POE_POHDR.DS_NAME",rec.name$,1)
	endif
	if shipto_type$="S" then
		rem --- Ship-to
		read record (arm_custship_dev,key=firm_id$+tmp_customer_id$+shipto_no$,dom=*next)arm_custship$
		dim rec$:fattr(arm_custship$)
		rec$=arm_custship$
		gosub fill_dropship_address
		callpoint!.setColumnData("POE_POHDR.DS_NAME",rec.name$,1)
	endif
return

shipto_cust:

	arm_custmast_dev=fnget_dev("ARM_CUSTMAST")
	dim arm_custmast$:fnget_tpl$("ARM_CUSTMAST")

	read record (arm_custmast_dev,key=firm_id$+tmp_customer_id$,dom=*next)arm_custmast$
	dim rec$:fattr(arm_custmast$)
	rec$=arm_custmast$
	gosub fill_dropship_address
	callpoint!.setColumnData("POE_POHDR.DS_NAME",rec.customer_name$,1)

return

fill_dropship_address:
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_1",rec.addr_line_1$,1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_2",rec.addr_line_2$,1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_3",rec.addr_line_3$,1)
	callpoint!.setColumnData("POE_POHDR.DS_ADDR_LINE_4",rec.addr_line_4$,1)
	callpoint!.setColumnData("POE_POHDR.DS_CITY",rec.city$,1)
	callpoint!.setColumnData("POE_POHDR.DS_STATE_CD",rec.state_code$,1)
	callpoint!.setColumnData("POE_POHDR.DS_ZIP_CODE",rec.zip_code$,1)
return

get_dropship_order_lines:
rem --- read thru selected sales order and build list of lines for which line code is marked as drop-ship
	ope_ordhdr_dev=fnget_dev("OPE_ORDHDR")
	ope_orddet_dev=fnget_dev("OPE_ORDDET")
	ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
	ivm_itemwhse_dev=fnget_dev("IVM_ITEMWHSE")
	opc_linecode_dev=fnget_dev("OPC_LINECODE")
	poe_linked_dev=fnget_dev("POE_LINKED")
	poe_podet_dev = fnget_dev("POE_PODET")

	dim ope_ordhdr$:fnget_tpl$("OPE_ORDHDR")
	dim ope_orddet$:fnget_tpl$("OPE_ORDDET")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
	dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
	dim poe_linked$:fnget_tpl$("POE_LINKED")
	dim poe_podet$:fnget_tpl$("POE_PODET")

	order_lines!=SysGUI!.makeVector()
	order_items!=SysGUI!.makeVector()
	order_list!=SysGUI!.makeVector()
	callpoint!.setDevObject("ds_orders","N")
	soLineType!=callpoint!.getDevObject("so_line_type")

	found_ope_ordhdr=0
	read(ope_ordhdr_dev,key=firm_id$+ope_ordhdr.ar_type$+tmp_customer_id$+tmp_order_no$,knum="PRIMARY",dom=*next)
	while 1
		ope_ordhdr_key$=key(ope_ordhdr_dev,end=*break)
		if pos(firm_id$+ope_ordhdr.ar_type$+tmp_customer_id$+tmp_order_no$=ope_ordhdr_key$)<>1 then break
		read record (ope_ordhdr_dev)ope_ordhdr$
		if pos(ope_ordhdr.trans_status$="ER")=0 then continue
		found_ope_ordhdr=1
		break; rem --- new order can have at most just one new invoice, if any
	wend
	if !found_ope_ordhdr then return

	rowVect!=gridvect!.getItem(0)		
	row=0
	so_on_another_po=0
	po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")
	read (ope_orddet_dev,key=ope_ordhdr_key$,dom=*next)
	while 1
		ope_orddet_key$=key(ope_orddet_dev,end=*break)
		if pos(ope_ordhdr_key$=ope_orddet_key$)<>1 then break
		read record (ope_orddet_dev)ope_orddet$
		if pos(ope_orddet.trans_status$="ER")=0 then continue
		if pos(ope_orddet.line_code$=callpoint!.getDevObject("oe_ds_line_codes"))<>0
			rem --- Check poe_linked to see if this SO detail line is on another PO
			redim poe_linked$
			readrecord(poe_linked_dev,key=firm_id$+tmp_customer_id$+tmp_order_no$+ope_orddet.internal_seq_no$,knum="AO_CUST_ORD",dom=*next)poe_linked$
			if cvs(poe_linked.po_no$,2)<>"" and poe_linked.po_no$<>po_no$ then
				rem --- Skip this SO detail line since it's already on another PO
				so_on_another_po=1
				continue
			endif

			if cvs(ope_orddet.item_id$,2)="" then
				rem --- Non-stock item
				order_lines!.addItem(ope_orddet.internal_seq_no$)
				nonstk_list$=nonstk_list$+ope_orddet.order_memo$
				work_var=pos(ope_orddet.order_memo$=item_list$,len(ope_orddet.order_memo$),0)
				if work_var>1
					work_var$=cvs(ope_orddet.order_memo$,2)+"("+str(work_var)+")"
				else
					work_var$=cvs(ope_orddet.order_memo$,2)
				endif
				order_items!.addItem(work_var$)
				order_list!.addItem(Translate!.getTranslation("AON_NON-STOCK")+": "+work_var$)
			else
				rem --- Inventoried item
				read record (ivm_itemmast_dev,key=firm_id$+ope_orddet.item_id$,dom=*next)ivm_itemmast$
				order_lines!.addItem(ope_orddet.internal_seq_no$)
				item_list$=item_list$+ope_orddet.item_id$
				work_var=pos(ope_orddet.item_id$=item_list$,len(ope_orddet.item_id$),0)
				if work_var>1
					work_var$=cvs(ope_orddet.item_id$,2)+"("+str(work_var)+")"
				else
					work_var$=cvs(ope_orddet.item_id$,2)
				endif
				order_items!.addItem(work_var$)
				order_list!.addItem(Translate!.getTranslation("AON_ITEM:_")+work_var$+" "+cvs(ivm_itemmast.display_desc$,3))
			endif

			rem --- Get Line Type for this drop ship OP detail line
			redim opc_linecode$
			read record (opc_linecode_dev,key=firm_id$+ope_orddet.line_code$,dom=*next)opc_linecode$
			soLineType!.setProperty(ope_orddet.internal_seq_no$,opc_linecode.line_type$)

			rem --- Add this SO dropship detail line to the PO detail grid
			if callpoint!.getEvent()<>"ARAR" and rowVect!.size()=0 then
				row=row+1
				call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]

				redim ivm_itemmast$
				readrecord(ivm_itemmast_dev,key=firm_id$+ope_orddet.item_id$,dom=*next)ivm_itemmast$
				warehouse_id$=callpoint!.getColumnData("POE_POHDR.WAREHOUSE_ID")
				redim ivm_itemwhse$
				readrecord(ivm_itemwhse_dev,key=firm_id$+warehouse_id$+ope_orddet.item_id$,dom=*next)ivm_itemwhse$

				vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
				ord_date$=callpoint!.getColumnData("POE_POHDR.ORD_DATE")
				item_id$=ope_orddet.item_id$
				if cvs(ivm_itemmast.item_id$,2)<>"" then
					conv_factor=ivm_itemmast.conv_factor
				else
					rem --- Non-stock dropship
					conv_factor=ope_orddet.conv_factor
				endif
				if conv_factor=0 then conv_factor=1
				if cvs(ivm_itemmast.item_id$,2)<>"" then
					unit_cost=ivm_itemwhse.unit_cost*conv_factor
				else
					rem --- Non-stock dropship
					unit_cost=ope_orddet.unit_cost*conv_factor
				endif
				req_qty=ope_orddet.qty_ordered/conv_factor
				qty_ordered=req_qty
				if fpt(qty_ordered)>0 then qty_ordered=int(qty_ordered)+1
				call stbl("+DIR_PGM")+"poc_itemvend.aon","R","P",vendor_id$,ord_date$,item_id$,1,unit_cost,qty_ordered,callpoint!.getDevObject("iv_prec"),status

				redim poe_podet$
				poe_podet.firm_id$=firm_id$
				poe_podet.po_no$=po_no$
				poe_podet.internal_seq_no$=int_seq_no$
				poe_podet.po_line_no$=str(row:"000")
				poe_podet.po_line_code$=ope_orddet.line_code$
				if cvs(ivm_itemmast.item_id$,2)<>"" then
					poe_podet.unit_measure$=ivm_itemmast.purchase_um$
				else
					rem --- Non-stock dropship
					poe_podet.unit_measure$=ope_orddet.um_sold$
				endif
				poe_podet.reqd_date$=callpoint!.getColumnData("POE_POHDR.REQD_DATE")
				poe_podet.promise_date$=callpoint!.getColumnData("POE_POHDR.PROMISE_DATE")
				poe_podet.not_b4_date$=callpoint!.getColumnData("POE_POHDR.NOT_B4_DATE")
				poe_podet.so_int_seq_ref$=ope_orddet.internal_seq_no$
				poe_podet.warehouse_id$=warehouse_id$
				poe_podet.item_id$=item_id$
				poe_podet.order_memo$=ope_orddet.order_memo$
				poe_podet.conv_factor=conv_factor
				poe_podet.unit_cost=unit_cost
				poe_podet.req_qty=req_qty
				poe_podet.qty_ordered=qty_ordered
				poe_podet.qa_wip_qty=0
				poe_podet.qa_rec_qty=0
				poe_podet.qa_rej_qty=0
				poe_podet.qty_received=0
				poe_podet.qty_invoiced=0
				poe_podet.reserved_num_01=0
				poe_podet.reserved_num_02=0
				poe_podet.dealer_num_01=0
				poe_podet.dealer_num_02=0
				if opc_linecode.line_type$="N" then poe_podet.ns_item_id$=ope_orddet.order_memo$
				poe_podet.memo_1024$=ope_orddet.memo_1024$

				poe_podet$=field(poe_podet$)
				writerecord(poe_podet_dev)poe_podet$

				rem --- Update ivm_itemvend (ivm-05) for this new detail grid row
				call stbl("+DIR_PGM")+"poc_itemvend.aon","W","P",vendor_id$,ord_date$,item_id$,1,unit_cost,qty_ordered,callpoint!.getDevObject("iv_prec"),status

				rem --- Update poe_linked (poe-08) for this new detail grid row
				redim poe_linked$
				poe_linked.firm_id$=firm_id$
				poe_linked.po_no$=poe_podet.po_no$
				poe_linked.poedet_seq_ref$=poe_podet.internal_seq_no$
				poe_linked.customer_id$=ope_orddet.customer_id$
				poe_linked.order_no$=ope_orddet.order_no$
				poe_linked.opedet_seq_ref$=ope_orddet.internal_seq_no$

				poe_linked$=field(poe_linked$)
				write record (poe_linked_dev)poe_linked$
			endif
		endif
	wend
	read(poe_linked_dev,key=firm_id$,knum="PRIMARY",dom=*next); rem --- Reset poe_linked key to PRIMARY

	if row>0 then
		rem --- Display SO dropship detail lines added to the PO detail grid
		callpoint!.setStatus("REFGRID")
	endif

	callpoint!.setDevObject("so_line_type",soLineType!)
	if order_lines!.size()=0 
		callpoint!.setDevObject("ds_orders","N")
		callpoint!.setDevObject("so_ldat","")
		callpoint!.setDevObject("so_lines_list","")
		callpoint!.setDevObject("so_line_type",new Properties())

		if so_on_another_po then
			callpoint!.setDevObject("so_lines_used","ALL")
		endif
	else 
		ldat$=""
		descVect!=BBjAPI().makeVector()
		codeVect!=BBjAPI().makeVector()
		for x=0 to order_lines!.size()-1
			descVect!.addItem(order_items!.getItem(x))
			codeVect!.addItem(order_lines!.getItem(x))
		next x
		ldat$=func.buildListButtonList(descVect!,codeVect!)

		callpoint!.setDevObject("ds_orders","Y")		
		callpoint!.setDevObject("so_ldat",ldat$)
		callpoint!.setDevObject("so_lines_list",order_list!)

		if so_on_another_po then
			callpoint!.setDevObject("so_lines_used","SOME")
		endif
	endif	
return


form_inits:
rem --- setting up for new rec or nav to diff rec

callpoint!.setDevObject("so_line_type",new Properties())
callpoint!.setDevObject("ds_orders","")
callpoint!.setDevObject("so_ldat","")
callpoint!.setDevObject("so_lines_list","")
callpoint!.setDevObject("qty_received","")
callpoint!.setDevObject("total_amt","0")
callpoint!.setDevObject("dtl_posted","")

rem --- dropship not allowed without AR
if callpoint!.getDevObject("AR_installed")<>"Y"
	callpoint!.setTableColumnAttribute("POE_POHDR.DROPSHIP","DFLT", "N")
	callpoint!.setColumnEnabled("POE_POHDR.DROPSHIP",-1)
endif

return

enable_dropship_fields:
rem --- Disables/enables dropship fields if detail has (or hasn't) been created for this requisition.
rem --- Since warehouse in hdr can't be changed once detail is posted, handling that control here, too.

rem --- Dropship disabled and set to 'N' in BSHO when AR is not installed
rem --- Sale order number disabled in BSHO when OP is not installed
if callpoint!.getDevObject("dtl_posted")="Y"
	callpoint!.setColumnEnabled("POE_POHDR.WAREHOUSE_ID",0)
	callpoint!.setColumnEnabled("POE_POHDR.DROPSHIP",0)
	callpoint!.setColumnEnabled("POE_POHDR.CUSTOMER_ID",0)
	callpoint!.setColumnEnabled("POE_POHDR.ORDER_NO",0)			
	callpoint!.setColumnEnabled("POE_POHDR.SHIPTO_NO",0)
else
	callpoint!.setColumnEnabled("POE_POHDR.WAREHOUSE_ID",1)
	rem --- disable customer number, sales order number and shipto number if not a dropship
	if callpoint!.getColumnData("POE_POHDR.DROPSHIP")="Y"
		callpoint!.setColumnEnabled("POE_POHDR.CUSTOMER_ID",1)
		if callpoint!.getDevObject("OP_installed")="Y" then
			callpoint!.setColumnEnabled("POE_POHDR.ORDER_NO",1)
			callpoint!.setColumnEnabled("POE_POHDR.SHIPTO_NO",0)
		else
			callpoint!.setColumnEnabled("POE_POHDR.ORDER_NO",0)
			callpoint!.setColumnEnabled("POE_POHDR.SHIPTO_NO",1)
		endif
	else
		callpoint!.setColumnEnabled("POE_POHDR.CUSTOMER_ID",0)
		callpoint!.setColumnEnabled("POE_POHDR.ORDER_NO",0)
		callpoint!.setColumnEnabled("POE_POHDR.SHIPTO_NO",0)
	endif
	gosub whse_addr_info
endif
return

queue_for_printing:

	poe_poprint_dev=fnget_dev("POE_POPRINT")
	dim poe_poprint$:fnget_tpl$("POE_POPRINT")

	poe_poprint.firm_id$=firm_id$
	poe_poprint.vendor_id$=callpoint!.getColumnData("POE_POHDR.VENDOR_ID")
	poe_poprint.po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")

	writerecord (poe_poprint_dev)poe_poprint$

return

validate_dates: rem --- validate dates

	bad_date$ = ""
	order_date$=Translate!.getTranslation("AON_ORDER_DATE")
	reqd_date$=Translate!.getTranslation("AON_REQUIRED")+" "+Translate!.getTranslation("AON_DATE")
	prom_date$=Translate!.getTranslation("AON_PROMISED")+" "+Translate!.getTranslation("AON_DATE")
	nb4_date$=Translate!.getTranslation("AON_NOT_BEFORE")+" "+Translate!.getTranslation("AON_DATE")
	after$=Translate!.getTranslation("AON_IS_AFTER")
	before$=Translate!.getTranslation("AON_IS_BEFORE")

	if ord_date$<>"" and req_date$<>"" and ord_date$>req_date$ then
		bad_date$ = order_date$+" "+after$+" "+reqd_date$
	endif

	if ord_date$<>"" and promise_date$<>"" and ord_date$>promise_date$ then
		bad_date$ = order_date$+" "+after$+" "+prom_date$
	endif

	if ord_date$<>"" and not_b4_date$<>"" and ord_date$>not_b4_date$ then
		bad_date$ = order_date$+" "+after$+" "+nb4_date$
	endif

	if req_date$<>"" and not_b4_date$<>"" and req_date$<not_b4_date$ then
		bad_date$ = reqd_date$+" "+before$+" "+nb4_date$
	endif

	if promise_date$<>"" and not_b4_date$<>"" and promise_date$<not_b4_date$ then
		bad_date$ = prom_date$+" "+before$+" "+nb4_date$
	endif

	if bad_date$ <> ""
		msg_id$="INVALID_PO_DATE"
		dim msg_tokens$[1]
		msg_tokens$[1]=bad_date$
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif

return

warn_dates: rem --- warn about possible bad dates

	warn_date$=""
	reqd_date$=Translate!.getTranslation("AON_REQUIRED")+" "+Translate!.getTranslation("AON_DATE")
	prom_date$=Translate!.getTranslation("AON_PROMISED")+" "+Translate!.getTranslation("AON_DATE")

	if req_date$<>"" and promise_date$<>"" and req_date$<promise_date$ then
		warn_date$ = reqd_date$+" "+before$+" "+prom_date$
	endif

	if warn_date$ <> ""
		msg_id$="WARN_PO_DATE"
		dim msg_tokens$[1]
		msg_tokens$[1]=warn_date$
		gosub disp_message
	endif

return

rem ==========================================================================
get_disk_rec: rem --- Get disk record, update with current form data
              rem     OUT: found - true/false (1/0)
              rem           : ordhdr_rec$, updated (if record found)
              rem           : ordhdr_dev
rem ==========================================================================
	poePoHdr_dev  = fnget_dev("POE_POHDR")
	poePoHdr_tpl$ = fnget_tpl$("POE_POHDR")
	dim poePoHdr$:poePoHdr_tpl$
	po_no$=callpoint!.getColumnData("POE_POHDR.PO_NO")
	found = 0
	extractrecord(poePoHdr_dev, key=firm_id$+po_no$, dom=*next) poePoHdr$; found = 1; rem Advisory Locking

	rem --- Copy in any form data that's changed
	poePoHdr$ = util.copyFields(poePoHdr_tpl$, callpoint!)
	poePoHdr$ = field(poePoHdr$)

	if !found then 
		extractrecord(poePoHdr_dev, key=firm_id$+po_no$, dom=*next) poePoHdr$; rem Advisory Locking
		callpoint!.setStatus("SETORIG")
	endif

	return



