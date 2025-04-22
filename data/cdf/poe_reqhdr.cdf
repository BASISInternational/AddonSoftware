[[POE_REQHDR.ADEL]]
rem --- also delete requisition print record

poe_reqprint_dev=fnget_dev("POE_REQPRINT")
remove (poe_reqprint_dev,key=firm_id$+callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")+callpoint!.getColumnData("POE_REQHDR.REQ_NO"),dom=*next)

[[POE_REQHDR.ADIS]]
vendor_id$=callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")
purch_addr$=callpoint!.getColumnData("POE_REQHDR.PURCH_ADDR")
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

[[POE_REQHDR.AOPT-COPY]]
rem --- Get vendor to copy this Requisition to
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
			lock_table$="POE_REQHDR"
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
		writerecord(poeReqHdr_dev)poeReqHdr$
	endif

rem --- Copy this Requisition using new vendor
	call stbl("+DIR_SYP")+"bas_sequences.bbj","REQ_NO",seq_id$,rd_table_chans$[all]
	if seq_id$<>"" then
		rem --- Copy header record
		poe_reqhdr_dev  = fnget_dev("POE_REQHDR")
		dim poe_reqhdr$:fnget_tpl$("POE_REQHDR")
		req_no$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")
		found = 0
		extractrecord(poe_reqhdr_dev, key=firm_id$+req_no$, dom=*next)poe_reqhdr$; found = 1; rem Advisory Locking
		if found then
			poe_reqhdr.req_no$=seq_id$
			poe_reqhdr.vendor_id$=new_vendor$
			poe_reqhdr.purch_addr$=new_purchAddr$
			poe_reqhdr.entered_by$=""

			poe_reqhdr$=field(poe_reqhdr$)
			write record (poe_reqhdr_dev) poe_reqhdr$
			poe_reqhdr_key$=poe_reqhdr.firm_id$+poe_reqhdr.req_no$
			extractrecord(poe_reqhdr_dev,key=poe_reqhdr_key$)poe_reqhdr$; rem Advisory Locking
			callpoint!.setStatus("SETORIG")

			rem --- Copy detail records
			poe_reqdet_dev = fnget_dev("POE_REQDET")
			dim poe_reqdet$:fnget_tpl$("POE_REQDET")
			poe_reqdet_dev2=fnget_dev("2_POE_REQDET")
			poc_linecode_dev=fnget_dev("POC_LINECODE")
			dim poc_linecode$:fnget_tpl$("POC_LINECODE")

			read(poe_reqdet_dev, key=firm_id$+req_no$,dom=*next)
			while 1
				poe_reqdet_key$=key(poe_reqdet_dev,end=*break)
				if pos(firm_id$+req_no$=poe_reqdet_key$)<>1 then break
				readrecord(poe_reqdet_dev)poe_reqdet$
				call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
				poe_reqdet.req_no$=poe_reqhdr.req_no$
				poe_reqdet.internal_seq_no$=int_seq_no$

				status=0
				call stbl("+DIR_PGM")+"poc_itemvend.aon","R","R",
:					poe_reqhdr.vendor_id$,
:					poe_reqhdr.ord_date$,
:					poe_reqdet.item_id$,
:					poe_reqdet.conv_factor,
:					unit_cost,
:					poe_reqdet.req_qty,
:					callpoint!.getDevObject("iv_prec"),
:					status

				if status=0 then poe_reqdet.unit_cost=unit_cost
				poe_reqdet$=field(poe_reqdet$)
				writerecord(poe_reqdet_dev2)poe_reqdet$
			wend
			callpoint!.setStatus("RECORD:["+poe_reqhdr.firm_id$+poe_reqhdr.req_no$+"]")
		else
			callpoint!.setStatus("NEWREC")
		endif
	endif

rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[POE_REQHDR.AOPT-DPRT]]
rem --- on-demand requisition print

vendor_id$=callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")
req_no$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")

gosub queue_for_printing

if cvs(vendor_id$,3)<>"" and cvs(req_no$,3)<>""
	gosub queue_for_printing

	historical_print$=""
	call "por_reqprint.aon",vendor_id$,req_no$,historical_print$,table_chans$[all]
endif

[[POE_REQHDR.AOPT-DUPP]]
rem --- Duplicate Old Purchase Requisition
	dim filter_defs$[2,2]
	filter_defs$[1,0] = "POT_REQHDR_ARC.FIRM_ID"
	filter_defs$[1,1] = "='"+firm_id$+"'"
	filter_defs$[1,2] = "LOCK"
	if cvs(callpoint!.getColumnData("POE_REQHDR.VENDOR_ID"),2)<>"" then
		filter_defs$[2,0] = "POT_REQHDR_ARC.VENDOR_ID"
		filter_defs$[2,1] = "='"+callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")+"'"
		filter_defs$[2,2] = "LOCK"
	endif

	call stbl("+DIR_SYP")+"bax_query.bbj",
:		gui_dev,
:		Form!,
:		"PO_HIST_REQ",
:		"DEFAULT",
:		table_chans$[all],
:		sel_key$,
:		filter_defs$[all]


	if sel_key$<>""
		call stbl("+DIR_SYP")+"bac_key_template.bbj",
:			"POT_REQHDR_ARC",
:			"PRIMARY",
:			pot_reqhdr_key$,
:			table_chans$[all],
:			status$

		if cvs(callpoint!.getColumnData("POE_REQHDR.REQ_NO"),2)="" then
			call stbl("+DIR_SYP")+"bas_sequences.bbj","REQ_NO",seq_id$,rd_table_chans$[all]
		else
			seq_id$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")
		endif
		if seq_id$<>"" then
			rem --- Copy header record
			poe_reqhdr_dev = fnget_dev("POE_REQHDR")
			dim poe_reqhdr$:fnget_tpl$("POE_REQHDR")

			pot_reqhdr_dev = fnget_dev("POT_REQHDR_ARC")
			dim pot_reqhdr$:fnget_tpl$("POT_REQHDR_ARC")
			dim pot_reqhdr_key$:pot_reqhdr_key$
			pot_reqhdr_key$=sel_key$(1,len(pot_reqhdr_key$))
			read record (pot_reqhdr_dev, key=pot_reqhdr_key$,dom=*endif) pot_reqhdr$

			call stbl("+DIR_PGM")+"adc_copyfile.aon",pot_reqhdr$,poe_reqhdr$,status
			if status=0 then
				warn_SalesOrder=0
				warn_WorkOrder=0

				dim sysinfo$:stbl("+SYSINFO_TPL")
				sysinfo$=stbl("+SYSINFO")
				today$=sysinfo.system_date$
				today_jul=jul(num(today$(1,4)),num(today$(5,2)),num(today$(7,2)))
				rec_ord_date_jul=jul(num(pot_reqhdr.ord_date$(1,4)),num(pot_reqhdr.ord_date$(5,2)),num(pot_reqhdr.ord_date$(7,2)))
				rec_promise_date_jul=jul(num(pot_reqhdr.promise_date$(1,4)),num(pot_reqhdr.promise_date$(5,2)),num(pot_reqhdr.promise_date$(7,2)))
				rec_not_b4_date_jul=jul(num(pot_reqhdr.not_b4_date$(1,4)),num(pot_reqhdr.not_b4_date$(5,2)),num(pot_reqhdr.not_b4_date$(7,2)))
				rec_reqd_date_jul=jul(num(pot_reqhdr.reqd_date$(1,4)),num(pot_reqhdr.reqd_date$(5,2)),num(pot_reqhdr.reqd_date$(7,2)))

				poe_reqhdr.req_no$=seq_id$
				poe_reqhdr.ord_date$=today$
				if cvs(pot_reqhdr.promise_date$,2)<>"" then poe_reqhdr.promise_date$=date(today_jul+(rec_promise_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
				if cvs(pot_reqhdr.not_b4_date$,2)<>"" poe_reqhdr.not_b4_date$=date(today_jul+(rec_not_b4_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
				if cvs(pot_reqhdr.reqd_date$,2)<>"" poe_reqhdr.reqd_date$=date(today_jul+(rec_reqd_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
				poe_reqhdr.entered_by$=""
				if cvs(poe_reqhdr.order_no$,2)<>"" then
					warn_SalesOrder=1
					poe_reqhdr.order_no$=""
				endif

				poe_reqhdr$=field(poe_reqhdr$)
				write record (poe_reqhdr_dev) poe_reqhdr$
				poe_reqhdr_key$=poe_reqhdr.firm_id$+poe_reqhdr.req_no$
				extractrecord(poe_reqhdr_dev,key=poe_reqhdr_key$)poe_reqhdr$; rem Advisory Locking
				callpoint!.setStatus("SETORIG")

				rem --- Copy detail records
				poe_reqdet_dev = fnget_dev("POE_REQDET")
				dim poe_reqdet$:fnget_tpl$("POE_REQDET")

				pot_reqdet_dev = fnget_dev("POT_REQDET_ARC")
				dim pot_reqdet$:fnget_tpl$("POT_REQDET_ARC")
				read(pot_reqdet_dev, key=pot_reqhdr_key$,dom=*next)
				while 1
					pot_reqdet_key$=key(pot_reqdet_dev,end=*break)
					if pos(pot_reqhdr_key$=pot_reqdet_key$)<>1 then break
					readrecord(pot_reqdet_dev)pot_reqdet$

					redim poe_reqdet$
					call stbl("+DIR_PGM")+"adc_copyfile.aon",pot_reqdet$,poe_reqdet$,status
					if status then continue

					call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]
					recdet_reqd_date_jul=jul(num(pot_reqdet.reqd_date$(1,4)),num(pot_reqdet.reqd_date$(5,2)),num(pot_reqdet.reqd_date$(7,2)))
					recdet_promise_date_jul=jul(num(pot_reqdet.promise_date$(1,4)),num(pot_reqdet.promise_date$(5,2)),num(pot_reqdet.promise_date$(7,2)))
					recdet_not_b4_date_jul=jul(num(pot_reqdet.not_b4_date$(1,4)),num(pot_reqdet.not_b4_date$(5,2)),num(pot_reqdet.not_b4_date$(7,2)))

					poe_reqdet.req_no$=poe_reqhdr.req_no$
					poe_reqdet.internal_seq_no$=int_seq_no$
					if cvs(pot_reqdet.reqd_date$,2)<>"" poe_reqdet.reqd_date$=date(today_jul+(recdet_reqd_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
					if cvs(pot_reqdet.promise_date$,2)<>"" then poe_reqdet.promise_date$=date(today_jul+(recdet_promise_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
					if cvs(pot_reqdet.not_b4_date$,2)<>"" poe_reqdet.not_b4_date$=date(today_jul+(recdet_not_b4_date_jul-rec_ord_date_jul):"%Yl%Mz%Dz")
					if cvs(poe_reqdet.wo_no$,2)<>"" then
						warn_WorkOrder=1
						poe_reqdet.wo_no$=""
					endif
					poe_reqdet.wk_ord_seq_ref$=""
					poe_reqdet.so_int_seq_ref$=""

					status=0
					call stbl("+DIR_PGM")+"poc_itemvend.aon","R","R",
:						poe_reqhdr.vendor_id$,
:						poe_reqhdr.ord_date$,
:						poe_reqdet.item_id$,
:						poe_reqdet.conv_factor,
:						unit_cost,
:						poe_reqdet.req_qty,
:						callpoint!.getDevObject("iv_prec"),
:						status

					if status=0 then poe_reqdet.unit_cost=unit_cost
					poe_reqdet$=field(poe_reqdet$)
					write record (poe_reqdet_dev) poe_reqdet$
				wend
				callpoint!.setStatus("RECORD:["+poe_reqhdr.firm_id$+poe_reqhdr.req_no$+"]")

				rem --- Warn if sales order not duplicated
				if warn_SalesOrder then
					msg_id$="PO_SO_NOT_DUPD"
					gosub disp_message
				endif

				rem --- Warn if WO not duplicated
				if warn_WorkOrder then
					msg_id$="PO_WO_NOT_DUPD"
					gosub disp_message
				endif
			endif
		endif
	endif

[[POE_REQHDR.AOPT-QPRT]]
gosub queue_for_printing
msg_id$="PO_REQ_QPRT"
gosub disp_message

[[POE_REQHDR.APFE]]
rem --- set total order amt

total_amt=num(callpoint!.getDevObject("total_amt"))
callpoint!.setColumnData("<<DISPLAY>>.ORDER_TOTAL",str(total_amt))
tamt!=callpoint!.getDevObject("tamt")
tamt!.setValue(total_amt)

rem --- check dtl_posted flag to see if dropship fields should be disabled

gosub enable_dropship_fields 

rem --- enable/disable buttons
	req_no$=cvs(callpoint!.getColumnData("POE_REQHDR.REQ_NO"),3)
	if req_no$<>"" then
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

[[POE_REQHDR.AP_TERMS_CODE.AVAL]]
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

[[POE_REQHDR.ARAR]]
vendor_id$=callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")
purch_addr$=callpoint!.getColumnData("POE_REQHDR.PURCH_ADDR")
gosub vendor_info
gosub purch_addr_info
gosub whse_addr_info
gosub form_inits

rem ---	depending on whether or not drop-ship flag is selected and OE is installed...
rem ---	if drop-ship is selected, load up sales order line#'s for the detail grid's so reference listbutton

if callpoint!.getColumnData("POE_REQHDR.DROPSHIP")="Y"

	if callpoint!.getDevObject("OP_installed")="Y"
		tmp_customer_id$=callpoint!.getColumnData("POE_REQHDR.CUSTOMER_ID")
		tmp_order_no$=callpoint!.getColumnData("POE_REQHDR.ORDER_NO")
		gosub get_dropship_order_lines

	endif
endif

[[POE_REQHDR.AREC]]
gosub  form_inits

[[POE_REQHDR.ARNF]]
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
	callpoint!.setColumnData("POE_REQHDR.WAREHOUSE_ID",ivs_params.warehouse_id$,1)
	gosub whse_addr_info
	callpoint!.setColumnData("POE_REQHDR.ORD_DATE",sysinfo.system_date$,1)
	callpoint!.setColumnData("POE_REQHDR.PO_FRT_TERMS",pos_params.po_frt_terms$,1)
	callpoint!.setColumnData("POE_REQHDR.AP_SHIP_VIA",pos_params.ap_ship_via$,1)
	callpoint!.setColumnData("POE_REQHDR.FOB",pos_params.fob$,1)
	callpoint!.setColumnData("POE_REQHDR.HOLD_FLAG",pos_params.hold_flag$,1)
	callpoint!.setColumnData("POE_REQHDR.PO_MSG_CODE",pos_params.po_req_msg_code$,1)

[[POE_REQHDR.AWRI]]
rem --- need to put out poe_reqprint record

gosub queue_for_printing

[[POE_REQHDR.BDEL]]
rem --- Update links to Work Orders
	SF_installed$=callpoint!.getDevObject("SF_installed")
	if SF_installed$="Y" then
		req_no$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")
		poe_reqdet_dev=fnget_dev("POE_REQDET")
		dim poe_reqdet$:fnget_tpl$("POE_REQDET")
		poc_linecode_dev=fnget_dev("POC_LINECODE")
		dim poc_linecode$:fnget_tpl$("POC_LINECODE")
		sfe_womatl_dev=fnget_dev("SFE_WOMATL")
		sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")

		read (poe_reqdet_dev,key=firm_id$+req_no$,dom=*next)
		while 1
			poe_reqdet_key$=key(poe_reqdet_dev,end=*break)
            		if pos(firm_id$+req_no$=poe_reqdet_key$)<>1 then break
			read record (poe_reqdet_dev) poe_reqdet$
			if cvs(poe_reqdet.wo_no$,2)="" then continue

			dim poc_linecode$:fattr(poc_linecode$)
			find record (poc_linecode_dev,key=firm_id$+poe_reqdet.po_line_code$,dom=*continue) poc_linecode$
			if pos(poc_linecode.line_type$="NS")<>0 then
				old_wo$=poe_reqdet.wo_no$
				old_woseq$=poe_reqdet.wk_ord_seq_ref$
				new_wo$=""
				new_woseq$=""
				req_no$=poe_reqdet.req_no$
				req_seq$=poe_reqdet.internal_seq_no$
				call pgmdir$+"poc_requpdate.aon",sfe_womatl_dev,sfe_wosubcnt_dev,
:					req_no$,req_seq$,"R",poc_linecode.line_type$,old_wo$,old_woseq$,new_wo$,new_woseq$,status
			endif
		wend
	endif

rem --- Archive Requisition before deletion?
	msg_id$="PO_ARCHIVE_REQ"
	gosub disp_message
	if msg_opt$="Y"
		rem --- Add to historical Purchase Requisition archive before it gets deleted
		poe_reqhdr_dev = fnget_dev("POE_REQHDR")
		dim poe_reqhdr$:fnget_tpl$("POE_REQHDR")
		poe_reqdet_dev = fnget_dev("POE_REQDET")
		dim poe_reqdet$:fnget_tpl$("POE_REQDET")
		pot_reqhdr_dev = fnget_dev("POT_REQHDR_ARC")
		dim pot_reqhdr$:fnget_tpl$("POT_REQHDR_ARC")
		pot_reqdet_dev = fnget_dev("POT_REQDET_ARC")

		poe_reqhdr_key$=callpoint!.getRecordKey()
		find record (poe_reqhdr_dev,key=poe_reqhdr_key$,dom=*endif) poe_reqhdr$

		call stbl("+DIR_PGM")+"adc_copyfile.aon",poe_reqhdr$,pot_reqhdr$,status	
		write record (pot_reqhdr_dev) pot_reqhdr$

		read (poe_reqdet_dev,key=poe_reqhdr.firm_id$+poe_reqhdr.req_no$,dom=*next)
		while 1
			read record (poe_reqdet_dev,end=*break) poe_reqdet$
			if pos(poe_reqhdr.firm_id$+poe_reqhdr.req_no$=poe_reqdet.firm_id$+poe_reqdet.req_no$)<>1 then break
			writerecord(pot_reqdet_dev)poe_reqdet$
		wend
	endif

[[POE_REQHDR.BPFX]]
rem --- disable buttons
	callpoint!.setOptionEnabled("QPRT",0)
	callpoint!.setOptionEnabled("DPRT",0)
	callpoint!.setOptionEnabled("DUPP",0)
	callpoint!.setOptionEnabled("COPY",0)

[[POE_REQHDR.BSHO]]
rem --- inits

	use ::ado_func.src::func
	use ::ado_util.src::util

rem --- Open Files
	num_files=16
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="IVS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="POS_PARAMS",open_opts$[3]="OTA"
	open_tables$[4]="APM_VENDHIST",open_opts$[4]="OTA"
	open_tables$[5]="IVM_ITEMWHSE",open_opts$[5]="OTA"
	open_tables$[6]="IVM_ITEMVEND",open_opts$[6]="OTA"
	open_tables$[7]="IVM_ITEMMAST",open_opts$[7]="OTA"
	open_tables$[8]="IVM_ITEMSYN",open_opts$[8]="OTA"
	open_tables$[9]="POE_REQPRINT",open_opts$[9]="OTA"
	open_tables$[10]="APM_VENDMAST",open_opts$[10]="OTA"
	open_tables$[11]="POE_REQDET",open_opts$[11]="OTA"
	open_tables$[12]="POE_REQDET",open_opts$[12]="OTAN[2_]"
	open_tables$[13]="POT_REQHDR_ARC",open_opts$[13]="OTA"
	open_tables$[14]="POT_REQDET_ARC",open_opts$[14]="OTA"
	open_tables$[15]="APC_TERMSCODE",open_opts$[15]="OTA"
	open_tables$[16]="APM_VENDADDR",open_opts$[16]="OTA"

	gosub open_tables
	aps_params_dev=num(open_chans$[1]),aps_params_tpl$=open_tpls$[1]
	ivs_params_dev=num(open_chans$[2]),ivs_params_tpl$=open_tpls$[2]
	pos_params_dev=num(open_chans$[3]),pos_params_tpl$=open_tpls$[3]
	apm_vendhist_dev=num(open_chans$[4]),apm_vendhist_tpl$=open_tpls$[4]
	ivm_itemwhse_dev=num(open_chans$[5]),ivm_itemwhse_tpl$=open_tpls$[5]
	ivm_itemvend_dev=num(open_chans$[6]),ivm_itemvend_tpl$=open_tpls$[6]

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
		callpoint!.setTableColumnAttribute("POE_REQHDR.DROPSHIP","DFLT", "N")
		callpoint!.setColumnEnabled("POE_REQHDR.DROPSHIP",-1)
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
		callpoint!.setColumnEnabled("POE_REQHDR.ORDER_NO",-1)
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
	callpoint!.setDevObject("dropship_whse",ivs_params.dropship_whse$)	

rem --- store dtlGrid! and column for sales order line# reference listbutton (within grid) in devObject

	dtlWin!=Form!.getChildWindow(1109)
	dtlGrid!=dtlWin!.getControl(5900)
	callpoint!.setDevObject("dtl_grid",dtlGrid!)

[[POE_REQHDR.CUSTOMER_ID.AVAL]]
if callpoint!.getUserInput()<>callpoint!.getColumnData("POE_REQHDR.CUSTOMER_ID") then
	rem --- if dropshipping, retrieve specified sales order and display shipto address
	callpoint!.setColumnData("POE_REQHDR.ORDER_NO","",1)
	callpoint!.setColumnData("POE_REQHDR.SHIPTO_NO","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_1","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_2","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_3","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_4","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_CITY","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_NAME","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_STATE_CD","",1)
	callpoint!.setColumnData("POE_REQHDR.DS_ZIP_CODE","",1)

	tmp_customer_id$=callpoint!.getUserInput()
	gosub shipto_cust;rem will refresh address w/ that from order once order# is entered
endif
	

[[POE_REQHDR.DROPSHIP.AVAL]]
rem --- Update the Ship To Warehouse if the DROPSHIP setting changes
dropship$=callpoint!.getUserInput()
if dropship$<>callpoint!.getColumnData("POE_REQHDR.DROPSHIP") and cvs(callpoint!.getDevObject("dropship_whse"),2)<>"" then
	if dropship$="Y" then
		callpoint!.setColumnEnabled("POE_REQHDR.WAREHOUSE_ID",0)
		callpoint!.setColumnData("POE_REQHDR.WAREHOUSE_ID",str(callpoint!.getDevObject("dropship_whse")),1)
		gosub whse_addr_info
	endif

	if dropship$="N" then
		callpoint!.setColumnEnabled("POE_REQHDR.WAREHOUSE_ID",1)
		callpoint!.setColumnData("POE_REQHDR.WAREHOUSE_ID","",1)
		gosub whse_addr_info
		callpoint!.setFocus("POE_REQHDR.WAREHOUSE_ID",1)
	endif
endif

rem --- if turning off dropship flag, clear devObject items

if callpoint!.getUserInput()="N"
	callpoint!.setDevObject("ds_orders","N")
	callpoint!.setDevObject("so_ldat","")
	callpoint!.setDevObject("so_lines_list","")
	callpoint!.setColumnData("POE_REQHDR.ORDER_NO","",1)
	callpoint!.setColumnData("POE_REQHDR.SHIPTO_NO","",1)
endif

gosub enable_dropship_fields

[[POE_REQHDR.NOT_B4_DATE.AVAL]]
not_b4_date$=cvs(callpoint!.getUserInput(),2)
if not_b4_date$<>"" then
	if not_b4_date$<callpoint!.getColumnData("POE_REQHDR.ORD_DATE") then callpoint!.setStatus("ABORT")
	if not_b4_date$>callpoint!.getColumnData("POE_REQHDR.REQD_DATE") then callpoint!.setStatus("ABORT")
	promise_date$=cvs(callpoint!.getColumnData("POE_REQHDR.PROMISE_DATE"),2)
	if promise_date$<>"" and not_b4_date$>promise_date$ then callpoint!.setStatus("ABORT")
endif

[[POE_REQHDR.ORDER_NO.AVAL]]
rem --- if dropshipping, retrieve specified sales order and display shipto address

if cvs(callpoint!.getColumnData("POE_REQHDR.CUSTOMER_ID"),3)<>""

	tmp_customer_id$=callpoint!.getColumnData("POE_REQHDR.CUSTOMER_ID")
	tmp_order_no$=callpoint!.getUserInput()

	gosub dropship_shipto
	gosub get_dropship_order_lines

	if callpoint!.getDevObject("ds_orders")<>"Y" and cvs(tmp_order_no$,3)<>""
		msg_id$="PO_NO_SO_LINES"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif			
endif

[[POE_REQHDR.PROMISE_DATE.AVAL]]
tmp$=cvs(callpoint!.getUserInput(),2)
if tmp$<>"" and tmp$<callpoint!.getColumnData("POE_REQHDR.ORD_DATE") then callpoint!.setStatus("ABORT")

[[POE_REQHDR.PURCH_ADDR.AVAL]]
rem --- Don't allow inactive code
	apmVendAddr_dev=fnget_dev("APM_VENDADDR")
	dim apmVendAddr$:fnget_tpl$("APM_VENDADDR")
	purch_addr$=callpoint!.getUserInput()
	vendor_id$=callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")
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

[[POE_REQHDR.REQD_DATE.AVAL]]
tmp$=callpoint!.getUserInput()
if tmp$<>"" and tmp$<callpoint!.getColumnData("POE_REQHDR.ORD_DATE") then callpoint!.setStatus("ABORT")

[[POE_REQHDR.REQ_NO.AVAL]]
rem --- don't allow user to assign new req# -- use Barista seq#
rem --- if user made null entry (to assign next seq automatically) then getRawUserInput() will be empty
rem --- if not empty, then the user typed a number -- if an existing requisition, fine; if not, abort

if cvs(callpoint!.getRawUserInput(),3)<>""
	msk$=callpoint!.getTableColumnAttribute("POE_REQHDR.REQ_NO","MSKI")
	find_requisition$=str(num(callpoint!.getRawUserInput()):msk$)
	poe_reqhdr_dev=fnget_dev("POE_REQHDR")
	dim poe_reqhdr$:fnget_tpl$("POE_REQHDR")
	read record (poe_reqhdr_dev,key=firm_id$+find_requisition$,dom=*next)poe_reqhdr$
	if poe_reqhdr.firm_id$<>firm_id$ or  poe_reqhdr.req_no$<>find_requisition$
		msg_id$="PO_INVAL_REQ"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif
endif

[[POE_REQHDR.SHIPTO_NO.AVAL]]
rem --- if dropshipping, retrieve/display specified shipto address

	shipto$=cvs(callpoint!.getUserInput(),3)
	tmp_customer_id$=callpoint!.getColumnData("POE_REQHDR.CUSTOMER_ID")
	
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
		callpoint!.setColumnData("POE_REQHDR.DS_NAME",rec.name$,1)
	endif

[[POE_REQHDR.VENDOR_ID.AVAL]]
rem --- Update vendor info if vendor changed
rem "VENDOR INACTIVE - FEATURE"
vendor_id$=callpoint!.getUserInput()
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

	if vendor_id$<>callpoint!.getColumnData("POE_REQHDR.VENDOR_ID") then
		gosub vendor_info
		gosub disp_vendor_comments

		rem --- set defaults from Parameter record
		pos_params_chn=fnget_dev("POS_PARAMS")
		dim pos_params$:fnget_tpl$("POS_PARAMS")
		read record(pos_params_chn,key=firm_id$+"PO00")pos_params$
		callpoint!.setColumnData("POE_REQHDR.PO_FRT_TERMS",pos_params.po_frt_terms$,1)
		callpoint!.setColumnData("POE_REQHDR.AP_SHIP_VIA",pos_params.ap_ship_via$,1)
		callpoint!.setColumnData("POE_REQHDR.FOB",pos_params.fob$,1)

		rem --- Now override the defaults with the Vendor info if not blank
		if cvs(apm01a.ap_ship_via$,3)<>""
			callpoint!.setColumnData("POE_REQHDR.AP_SHIP_VIA",apm01a.ap_ship_via$,1)
		endif
		if cvs(apm01a.fob$,3)<>""
			callpoint!.setColumnData("POE_REQHDR.FOB",apm01a.fob$,1)
		endif
		if cvs(apm01a.po_frt_terms$,3)<>""
			callpoint!.setColumnData("POE_REQHDR.PO_FRT_TERMS",apm01a.po_frt_terms$,1)
		endif

		rem --- Use Terms Code from vendor's first AP type record
		apm02_dev=fnget_dev("APM_VENDHIST")
		dim apm02a$:fnget_tpl$("APM_VENDHIST")
		read record(apm02_dev,key=firm_id$+vendor_id$,dom=*next)
		tmp$=key(apm02_dev,end=done_apm_vendhist)
		if pos(firm_id$+vendor_id$=tmp$)<>1 then goto done_apm_vendhist
		read record(apm02_dev,key=tmp$)apm02a$
		done_apm_vendhist:
		callpoint!.setColumnData("POE_REQHDR.AP_TERMS_CODE",apm02a.ap_terms_code$,1)
	endif

[[POE_REQHDR.WAREHOUSE_ID.AVAL]]
rem --- Don't allow IVS_PARAMS.DROPSHIP_WHSE for non-dropship requisition
if callpoint!.getUserInput()=callpoint!.getDevObject("dropship_whse") and callpoint!.getColumnData("POE_REQHDR.DROPSHIP")<>"Y" then
	msg_id$="PO_NOT_DROPSHIP_ENTRY"
	dim msg_tokens$[1]
	msg_tokens$[1]=callpoint!.getDevObject("dropship_whse")
	gosub disp_message
	callpoint!.setStatus("ABORT")
	break
endif

gosub whse_addr_info

[[POE_REQHDR.<CUSTOM>]]
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
	callpoint!.setColumnData("<<DISPLAY>>.PA_ZIP_CODE",apm05a.zip_code$,1)
	callpoint!.setColumnData("<<DISPLAY>>.PA_CNTRY_ID",apm05a.cntry_id$,1)
return

whse_addr_info: rem --- get and display Warehouse Address Info when not a dropship
	ivc_whsecode_dev=fnget_dev("IVC_WHSECODE")
	dim ivc_whsecode$:fnget_tpl$("IVC_WHSECODE")
	if callpoint!.getColumnData("POE_REQHDR.DROPSHIP")<>"Y" then
		if pos("WAREHOUSE_ID.AVAL"=callpoint!.getCallpointEvent())<>0
			warehouse_id$=callpoint!.getUserInput()
		else
			warehouse_id$=callpoint!.getColumnData("POE_REQHDR.WAREHOUSE_ID")
		endif
	endif
	read record(ivc_whsecode_dev,key=firm_id$+"C"+warehouse_id$,dom=*next)ivc_whsecode$
	callpoint!.setColumnData("<<DISPLAY>>.W_ADDR1",ivc_whsecode.addr_line_1$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_ADDR2",ivc_whsecode.addr_line_2$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_CITY",ivc_whsecode.city$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_STATE",ivc_whsecode.state_code$,1)
	callpoint!.setColumnData("<<DISPLAY>>.W_ZIP_CODE",ivc_whsecode.zip_code$,1)

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
		readrecord(ope_ordhdr_dev)ope_ordhdr$
		if pos(ope_ordhdr.trans_status$="ER")=0 then continue
		break; rem --- new order can have at most just one new invoice, if any
	wend

	shipto_no$=ope_ordhdr.shipto_no$
	callpoint!.setColumnData("POE_REQHDR.SHIPTO_NO",shipto_no$,1)
	if cvs(shipto_no$,3)=""
		gosub shipto_cust
	endif
	if num(shipto_no$,err=*endif)=99
		read record (ope_ordship_dev,key=firm_id$+tmp_customer_id$+tmp_order_no$+ope_ordhdr.ar_inv_no$+"S",dom=*next)ope_ordship$
		dim rec$:fattr(ope_ordship$)
		if pos(ope_ordship.trans_status$="ER") then rec$=ope_ordship$
		gosub fill_dropship_address
		callpoint!.setColumnData("POE_REQHDR.DS_NAME",rec.name$,1)
	endif
	if num(shipto_no$,err=*endif)>0 and num(shipto_no$,err=*endif)<99
		read record (arm_custship_dev,key=firm_id$+tmp_customer_id$+shipto_no$,dom=*next)arm_custship$
		dim rec$:fattr(arm_custship$)
		rec$=arm_custship$
		gosub fill_dropship_address
		callpoint!.setColumnData("POE_REQHDR.DS_NAME",rec.name$,1)
	endif

return

shipto_cust:

	arm_custmast_dev=fnget_dev("ARM_CUSTMAST")
	dim arm_custmast$:fnget_tpl$("ARM_CUSTMAST")

	read record (arm_custmast_dev,key=firm_id$+tmp_customer_id$,dom=*next)arm_custmast$
	dim rec$:fattr(arm_custmast$)
	rec$=arm_custmast$
	gosub fill_dropship_address
	callpoint!.setColumnData("POE_REQHDR.DS_NAME",rec.customer_name$)

return

fill_dropship_address:
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_1",rec.addr_line_1$)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_2",rec.addr_line_2$)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_3",rec.addr_line_3$)
	callpoint!.setColumnData("POE_REQHDR.DS_ADDR_LINE_4",rec.addr_line_4$)
	callpoint!.setColumnData("POE_REQHDR.DS_CITY",rec.city$)
	callpoint!.setColumnData("POE_REQHDR.DS_STATE_CD",rec.state_code$)
	callpoint!.setColumnData("POE_REQHDR.DS_ZIP_CODE",rec.zip_code$)
return

get_dropship_order_lines:
rem --- read thru selected sales order and build list of lines for which line code is marked as drop-ship
	ope_ordhdr_dev=fnget_dev("OPE_ORDHDR")
	ope_orddet_dev=fnget_dev("OPE_ORDDET")
	ivm_itemmast_dev=fnget_dev("IVM_ITEMMAST")
	ivm_itemwhse_dev=fnget_dev("IVM_ITEMWHSE")
	opc_linecode_dev=fnget_dev("OPC_LINECODE")
	poe_reqdet_dev = fnget_dev("POE_REQDET")

	dim ope_ordhdr$:fnget_tpl$("OPE_ORDHDR")
	dim ope_orddet$:fnget_tpl$("OPE_ORDDET")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
	dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
	dim poe_reqdet$:fnget_tpl$("POE_REQDET")

	order_lines!=SysGUI!.makeVector()
	order_items!=SysGUI!.makeVector()
	order_list!=SysGUI!.makeVector()
	callpoint!.setDevObject("ds_orders","N")

	found_ope_ordhdr=0
	read(ope_ordhdr_dev,key=firm_id$+ope_ordhdr.ar_type$+tmp_customer_id$+tmp_order_no$,knum="PRIMARY",dom=*next)
	while 1
		ope_ordhdr_key$=key(ope_ordhdr_dev,end=*break)
		if pos(firm_id$+ope_ordhdr.ar_type$+tmp_customer_id$+tmp_order_no$=ope_ordhdr_key$)<>1 then break
		readrecord(ope_ordhdr_dev)ope_ordhdr$
		if pos(ope_ordhdr.trans_status$="ER")=0 then continue
		found_ope_ordhdr=1
		break; rem --- new order can have at most just one new invoice, if any
	wend
	if !found_ope_ordhdr then return


	rowVect!=gridvect!.getItem(0)		
	row=0
	req_no$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")
	read (ope_orddet_dev,key=ope_ordhdr_key$,knum="PRIMARY",dom=*next)
	while 1
		ope_orddet_key$=key(ope_orddet_dev,end=*break)
		if pos(ope_ordhdr_key$=ope_orddet_key$)<>1 then break
		read record (ope_orddet_dev)ope_orddet$
		if pos(ope_orddet.trans_status$="ER")=0 then continue
		if pos(ope_orddet.line_code$=callpoint!.getDevObject("oe_ds_line_codes"))<>0
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

			rem --- Add this SO dropship detail line to the PPurchase Requisition detail grid
			if callpoint!.getEvent()<>"ARAR" and rowVect!.size()=0 then
				row=row+1
				call stbl("+DIR_SYP")+"bas_sequences.bbj","INTERNAL_SEQ_NO",int_seq_no$,table_chans$[all]

				redim ivm_itemmast$
				readrecord(ivm_itemmast_dev,key=firm_id$+ope_orddet.item_id$,dom=*next)ivm_itemmast$
				warehouse_id$=callpoint!.getColumnData("POE_REQHDR.WAREHOUSE_ID")
				redim ivm_itemwhse$
				readrecord(ivm_itemwhse_dev,key=firm_id$+warehouse_id$+ope_orddet.item_id$,dom=*next)ivm_itemwhse$

				vendor_id$=callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")
				ord_date$=callpoint!.getColumnData("POE_REQHDR.ORD_DATE")
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
				call stbl("+DIR_PGM")+"poc_itemvend.aon","R","R",vendor_id$,ord_date$,item_id$,1,unit_cost,qty_ordered,callpoint!.getDevObject("iv_prec"),status

				redim poe_reqdet$
				poe_reqdet.firm_id$=firm_id$
				poe_reqdet.req_no$=req_no$
				poe_reqdet.internal_seq_no$=int_seq_no$
				poe_reqdet.po_line_no$=str(row:"000")
				poe_reqdet.po_line_code$=ope_orddet.line_code$
				if cvs(ivm_itemmast.item_id$,2)<>"" then
					poe_reqdet.unit_measure$=ivm_itemmast.purchase_um$
				else
					rem --- Non-stock dropship
					poe_reqdet.unit_measure$=ope_orddet.um_sold$
				endif
				poe_reqdet.reqd_date$=callpoint!.getColumnData("POE_REQHDR.REQD_DATE")
				poe_reqdet.promise_date$=callpoint!.getColumnData("POE_REQHDR.PROMISE_DATE")
				poe_reqdet.not_b4_date$=callpoint!.getColumnData("POE_REQHDR.NOT_B4_DATE")
				poe_reqdet.so_int_seq_ref$=ope_orddet.internal_seq_no$
				poe_reqdet.warehouse_id$=warehouse_id$
				poe_reqdet.item_id$=item_id$
				poe_reqdet.order_memo$=ope_orddet.order_memo$
				poe_reqdet.conv_factor=conv_factor
				poe_reqdet.unit_cost=unit_cost
				poe_reqdet.req_qty=qty_ordered
				poe_reqdet.reserved_num_01=0
				poe_reqdet.reserved_num_02=0
				poe_reqdet.reserved_num_03=0
				poe_reqdet.reserved_num_04=0
				poe_reqdet.reserved_num_05=0
				poe_reqdet.reserved_num_06=0
				poe_reqdet.reserved_num_07=0
				poe_reqdet.reserved_num_08=0
				poe_reqdet.dealer_num_01=0
				poe_reqdet.dealer_num_02=0
				if opc_linecode.line_type$="N" then poe_reqdet.ns_item_id$=ope_orddet.order_memo$
				poe_reqdet.memo_1024$=ope_orddet.memo_1024$

				poe_reqdet$=field(poe_reqdet$)
				writerecord(poe_reqdet_dev)poe_reqdet$
			endif
		endif
	wend

	if row>0 then
		rem --- Display SO dropship detail lines added to the PO detail grid
		callpoint!.setStatus("REFGRID")
	endif

	if order_lines!.size()=0 
		callpoint!.setDevObject("ds_orders","N")
		callpoint!.setDevObject("so_ldat","")
		callpoint!.setDevObject("so_lines_list","")
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
	endif	
return

form_inits:
rem --- setting up for new rec or nav to diff rec

callpoint!.setDevObject("ds_orders","")
callpoint!.setDevObject("so_ldat","")
callpoint!.setDevObject("so_lines_list","")
callpoint!.setDevObject("total_amt","0")
callpoint!.setDevObject("dtl_posted","")

rem --- dropship not allowed without AR
if callpoint!.getDevObject("AR_installed")<>"Y"
	callpoint!.setTableColumnAttribute("POE_REQHDR.DROPSHIP","DFLT", "N")
	callpoint!.setColumnEnabled("POE_REQHDR.DROPSHIP",-1)
endif

return

enable_dropship_fields:
rem --- Disables/enables dropship fields if detail has (or hasn't) been created for this requisition.
rem --- Since warehouse in hdr can't be changed once detail is posted, handling that control here, too.

rem --- Dropship disabled and set to 'N' in BSHO when AR is not installed
rem --- Sale order number disabled in BSHO when OP is not installed
if callpoint!.getDevObject("dtl_posted")="Y"
	callpoint!.setColumnEnabled("POE_REQHDR.WAREHOUSE_ID",0)
	callpoint!.setColumnEnabled("POE_REQHDR.DROPSHIP",0)
	callpoint!.setColumnEnabled("POE_REQHDR.CUSTOMER_ID",0)
	callpoint!.setColumnEnabled("POE_REQHDR.ORDER_NO",0)			
	callpoint!.setColumnEnabled("POE_REQHDR.SHIPTO_NO",0)			
else
	callpoint!.setColumnEnabled("POE_REQHDR.WAREHOUSE_ID",1)
	rem --- disable customer number, sales order number and shipto number if not a dropship
	if callpoint!.getColumnData("POE_REQHDR.DROPSHIP")="Y"
		callpoint!.setColumnEnabled("POE_REQHDR.CUSTOMER_ID",1)
		if callpoint!.getDevObject("OP_installed")="Y" then
			callpoint!.setColumnEnabled("POE_REQHDR.ORDER_NO",1)
			callpoint!.setColumnEnabled("POE_REQHDR.SHIPTO_NO",0)
		else
			callpoint!.setColumnEnabled("POE_REQHDR.ORDER_NO",0)
			callpoint!.setColumnEnabled("POE_REQHDR.SHIPTO_NO",1)
		endif
	else
		callpoint!.setColumnEnabled("POE_REQHDR.CUSTOMER_ID",0)
		callpoint!.setColumnEnabled("POE_REQHDR.ORDER_NO",0)
		callpoint!.setColumnEnabled("POE_REQHDR.SHIPTO_NO",0)			
	endif
endif

return

queue_for_printing:

poe_reqprint_dev=fnget_dev("POE_REQPRINT")
dim poe_reqprint$:fnget_tpl$("POE_REQPRINT")

poe_reqprint.firm_id$=firm_id$
poe_reqprint.vendor_id$=callpoint!.getColumnData("POE_REQHDR.VENDOR_ID")
poe_reqprint.req_no$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")

writerecord (poe_reqprint_dev)poe_reqprint$

return

rem ==========================================================================
get_disk_rec: rem --- Get disk record, update with current form data
              rem     OUT: found - true/false (1/0)
              rem           : ordhdr_rec$, updated (if record found)
              rem           : ordhdr_dev
rem ==========================================================================
	poeReqHdr_dev  = fnget_dev("POE_REQHDR")
	poeReqHdr_tpl$ = fnget_tpl$("POE_REQHDR")
	dim poeReqHdr$:poeReqHdr_tpl$
	req_no$=callpoint!.getColumnData("POE_REQHDR.REQ_NO")
	found = 0
	extractrecord(poeReqHdr_dev, key=firm_id$+req_no$, dom=*next) poeReqHdr$; found = 1; rem Advisory Locking

	rem --- Copy in any form data that's changed
	poeReqHdr$ = util.copyFields(poeReqHdr_tpl$, callpoint!)
	poeReqHdr$ = field(poeReqHdr$)

	if !found then 
		extractrecord(poeReqHdr_dev, key=firm_id$+req_no$, dom=*next) poeReqHdr$; rem Advisory Locking
		callpoint!.setStatus("SETORIG")
	endif

	return



