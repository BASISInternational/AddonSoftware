[[SFE_WOMASTR.ACUS]]
rem --- Process custom event
rem This routine is executed when callbacks have been set to run a 'custom event'.
rem Analyze gui_event$ and notice$ to see which control's callback triggered the event, and what kind of event it is.
rem See basis docs notice() function, noticetpl() function, notify event, grid control notify events for more info.

	dim gui_event$:tmpl(gui_dev)
	dim notify_base$:noticetpl(0,0)
	gui_event$=SysGUI!.getLastEventString()
	ctl_ID=dec(gui_event.ID$)

	notify_base$=notice(gui_dev,gui_event.x%)
	dim notice$:noticetpl(notify_base.objtype%,gui_event.flags%)
	notice$=notify_base$

	rem --- The tab control
	if ctl_ID=num(stbl("+TAB_CTL")) then
		switch notice.code
			case 2; rem --- ON_TAB_SELECT
				rem --- 2nd Tab is for Additional Information
				tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
				if tabCtrl!.getSelectedIndex() = 1 then
					rem --- Refresh <<DISPLAY>> fields and static label for non-stock item description
					gosub refreshDisplayFields
				else
					rem --- Hide static label for non-stock item description
					nonStock_desc!=callpoint!.getDevObject("nonStock_desc")
					nonStock_desc!.setVisible(0)
				endif
			break
		swend
	endif

[[SFE_WOMASTR.ADIS]]
rem --- Set new record flag

	callpoint!.setDevObject("new_rec","N")
	callpoint!.setDevObject("wo_status",callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS"))
	callpoint!.setDevObject("wo_category",callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY"))
	callpoint!.setDevObject("wo_no",callpoint!.getColumnData("SFE_WOMASTR.WO_NO"))
	callpoint!.setDevObject("wo_loc",callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION"))
	callpoint!.setDevObject("warehouse_id",callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID"))

rem --- Disable/enable based on status of closed/open

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="C"
		callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.BILL_REV",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.CUSTOMER_ID",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_01",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_02",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_NO",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_REV",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.EST_YIELD",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.FORECAST",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.ORDER_NO",0)
		callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_ID",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.OPENED_DATE",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.PRIORITY",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.SCH_PROD_QTY",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.UNIT_MEASURE",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.WAREHOUSE_ID",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_TYPE",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_STATUS",0)
	else
		callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.BILL_REV",1)
		if callpoint!.getDevObject("ar")="Y"
			callpoint!.setColumnEnabled("SFE_WOMASTR.CUSTOMER_ID",1)
		endif
		if callpoint!.getDevObject("wo_category")="N" then
			callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_01",1)
			callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_02",1)
		else
			callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_01",0)
			callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_02",0)
		endif
		if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="O" then
			rem --- Can't change after WO is released
			callpoint!.setColumnEnabled("SFE_WOMASTR.WAREHOUSE_ID",0)
			callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_NO",0)
			callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_REV",0)
		else
			callpoint!.setColumnEnabled("SFE_WOMASTR.WAREHOUSE_ID",1)
			callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_NO",1)
			callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_REV",1)
		endif
		callpoint!.setColumnEnabled("SFE_WOMASTR.EST_YIELD",1)
		if callpoint!.getDevObject("mp")="Y"
			callpoint!.setColumnEnabled("SFE_WOMASTR.FORECAST",1)
		endif
		callpoint!.setColumnEnabled("SFE_WOMASTR.OPENED_DATE",1)
		if callpoint!.getDevObject("op")="Y"			
			callpoint!.setColumnEnabled("SFE_WOMASTR.ORDER_NO",1)
			callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_ID",1)
		endif
		callpoint!.setColumnEnabled("SFE_WOMASTR.PRIORITY",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.SCH_PROD_QTY",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.UNIT_MEASURE",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_TYPE",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_STATUS",1)
	endif

rem --- Disable Options (buttons) for a Closed Work Order

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="C"
		callpoint!.setOptionEnabled("SCHD",0)
		callpoint!.setOptionEnabled("RELS",0)
	else
		callpoint!.setOptionEnabled("SCHD",1)
		callpoint!.setOptionEnabled("RELS",1)
	endif

rem -- Disable Lot/Serial button if no LS

	if callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="I" and pos(callpoint!.getColumnData("SFE_WOMASTR.LOTSER_FLAG")="LS")
		callpoint!.setOptionEnabled("LSNO",1)
	else
		callpoint!.setOptionEnabled("LSNO",0)
	endif

rem --- Always disable these fields for an existing record

	callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",0)

rem --- disable Copy function if closed or not an N category

	if callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")<>"N" or 
:	callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="C"
		callpoint!.setOptionEnabled("COPY",0)
	else
		callpoint!.setOptionEnabled("COPY",1)
	endif

rem --- As necessary, explode Bills for Sales Order auto-generated WOs

	if callpoint!.getDevObject("bm")="Y" and callpoint!.getDevObject("op")="Y" and callpoint!.getDevObject("op_create_wo")="A" then
		rem --- BM and OP are installed, and OP is creating planned WOs
		if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="P" and
:		callpoint!.getColumnData("SFE_WOMASTR.WO_TYPE")=callpoint!.getDevObject("op_create_wo_typ") then
			rem --- This is a planned WO of the type created by OP
			if cvs(callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID"),2)<>"" and cvs(callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO"),2)<>"" and
:			num(callpoint!.getColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF"))>0 then
				rem --- This WO is linked to a Sales Order
				bmm_billmast=fnget_dev("BMM_BILLMAST")
				dim bmm_billmast$:fnget_tpl$("BMM_BILLMAST")
				bill_no$=callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID")
				readrecord(bmm_billmast,key=firm_id$+bill_no$,dom=*next)bmm_billmast$
				if bmm_billmast.bill_no$=bill_no$ and bmm_billmast.phantom_bill$<>"Y" then
					rem --- This WO is for a Bill, and the Bill is not a phantom
					record_found=0
					wo_location$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
					wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
					sfe_womastr_key$=firm_id$+wo_location$+wo_no$

					sfe_womatl_dev=fnget_dev("SFE_WOMATL")
					read(sfe_womatl_dev,key=sfe_womastr_key$,dom=*next)
					this_key$=key(sfe_womatl_dev,end=*next)
					if pos(sfe_womastr_key$=this_key$)=1 then record_found=1

					if !record_found then
						sfe_wooprtn_dev=fnget_dev("SFE_WOOPRTN")
						read(sfe_wooprtn_dev,key=sfe_womastr_key$,dom=*next)
						this_key$=key(sfe_wooprtn_dev,end=*next)
						if pos(sfe_womastr_key$=this_key$)=1 then record_found=1
					endif

					if !record_found then
						sfe_wosubcnt_dev=fnget_dev("SFE_WOSUBCNT")
						read(sfe_wosubcnt_dev,key=sfe_womastr_key$,dom=*next)
						this_key$=key(sfe_wosubcnt_dev,end=*next)
						if pos(sfe_womastr_key$=this_key$)=1 then record_found=1
					endif

					if !record_found then
						rem --- Bill hasn't been exploded yet for this WO
						callpoint!.setDevObject("new_rec","Y")

						key_pfx$=sfe_womastr_key$
						dim dflt_data$[3,1]
						dflt_data$[1,0]="FIRM_ID"
						dflt_data$[1,1]=firm_id$
						dflt_data$[2,0]="WO_LOCATION"
						dflt_data$[2,1]=wo_location$
						dflt_data$[3,0]="WO_NO"
						dflt_data$[3,1]=wo_no$

						call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:							"SFE_WOMATL",
:							stbl("+USER_ID"),
:							"MNT",
:							key_pfx$,
:							table_chans$[all],
:							"",
:							dflt_data$[all]

						callpoint!.setDevObject("new_rec","N")
					endif
				endif
			endif
		endif
	endif


rem --- See if any transactions exist - disable WO Type if so

	loc$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
	wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
	trans$="N"
	chan_dev=fnget_dev("SFT_OPNMATTR")
	dim chan_rec$:fnget_tpl$("SFT_OPNMATTR")
	read (chan_dev,key=firm_id$+loc$+wo_no$,dom=*next)
	while 1
		read record (chan_dev,end=*break) chan_rec$
		if chan_rec.firm_id$<>firm_id$ or
:			chan_rec.wo_location$<>loc$ or
:			chan_rec.wo_no$<>wo_no$ break
		tran$="Y"
		break
	wend

	if tran$="N"
		chan_dev=fnget_dev("SFT_OPNOPRTR")
		dim chan_rec$:fnget_tpl$("SFT_OPNOPRTR")
		read (chan_dev,key=firm_id$+loc$+wo_no$,dom=*next)
		while 1
			read record (chan_dev,end=*break) chan_rec$
			if chan_rec.firm_id$<>firm_id$ or
:				chan_rec.wo_location$<>loc$ or
:				chan_rec.wo_no$<>wo_no$ break
			tran$="Y"
			break
		wend
	endif

	if tran$="N"
		chan_dev=fnget_dev("SFT_OPNSUBTR")
		dim chan_rec$:fnget_tpl$("SFT_OPNSUBTR")
		read (chan_dev,key=firm_id$+loc$+wo_no$,dom=*next)
		while 1
			read record (chan_dev,end=*break) chan_rec$
			if chan_rec.firm_id$<>firm_id$ or
:				chan_rec.wo_location$<>loc$ or
:				chan_rec.wo_no$<>wo_no$ break
			tran$="Y"
			break
		wend
	endif

	if tran$="Y"
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_TYPE",0)
	endif

rem --- Disable WO Status if Open or Closed

	status$=callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")
	if pos(status$="OC")=0
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_STATUS",1)
	else
		callpoint!.setColumnEnabled("SFE_WOMASTR.WO_STATUS",0)
	endif

rem --- Disable qty/yield if data exists in sfe_womatl (sfe-22)

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")<>"C" and callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="I"

		sfe_womatl_dev=fnget_dev("SFE_WOMATL")
		dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")

		read (sfe_womatl_dev,key=firm_id$+loc$+wo_no$,dom=*next)
		while 1
			read record (sfe_womatl_dev,end=*break)sfe_womatl$
			if sfe_womatl$.firm_id$+sfe_womatl.wo_location$+sfe_womatl.wo_no$=firm_id$+loc$+wo_no$
				callpoint!.setColumnEnabled("SFE_WOMASTR.SCH_PROD_QTY",0)
				callpoint!.setColumnEnabled("SFE_WOMASTR.EST_YIELD",0)
				rem - this gets to be annoying - callpoint!.setMessage("SF_MATS_EXIST")
			endif
			break
		wend
	endif

rem --- set DevObjects

	callpoint!.setDevObject("prod_qty",callpoint!.getColumnData("SFE_WOMASTR.SCH_PROD_QTY"))
	callpoint!.setDevObject("wo_est_yield",callpoint!.getColumnData("SFE_WOMASTR.EST_YIELD"))
	callpoint!.setDevObject("wo_category",callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY"))
	callpoint!.setDevObject("lock_ref_num",callpoint!.getColumnData("SFE_WOMASTR.LOCK_REF_NUM"))

rem --- Refresh <<DISPLAY>> fields and static label for non-stock item description
	gosub refreshDisplayFields

[[SFE_WOMASTR.ADTW]]
rem --- Re-launch sfe_womatl form after a bill is exploded
	while callpoint!.getDevObject("explode_bills")="Y"
		key_pfx$=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")+callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

		dim dflt_data$[3,1]
		dflt_data$[1,0]="FIRM_ID"
		dflt_data$[1,1]=firm_id$
		dflt_data$[2,0]="WO_LOCATION"
		dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
		dflt_data$[3,0]="WO_NO"
		dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

		call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:			"SFE_WOMATL",
:			stbl("+USER_ID"),
:			"MNT",
:			key_pfx$,
:			table_chans$[all],
:			"",
:			dflt_data$[all]
	wend

[[SFE_WOMASTR.AENA]]
rem --- Disable Barista menu items
	wctl$="31031"; rem --- Save-As menu item in barista.ini
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)="X"
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP")

[[SFE_WOMASTR.AFMC]]
rem --- The type of code seen below is often done in BSHO, but the code at the end that changes the prompt for the Bill/Item control
rem --- won't work there (too late).

rem --- Initializations

	use ::ado_func.src::func
	use ::ado_util.src::util
	use ::opo_SalesOrderCreateWO.aon::SalesOrderCreateWO

rem --- Set new record flag

	callpoint!.setDevObject("new_rec","Y")
	callpoint!.setDevObject("mark_to_explode",""); rem --- this needs to be initialized for sfe_womatl form here
	callpoint!.setDevObject("explode_bills","N")

rem --- Open tables

	num_files=28
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="SFS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="SFC_WOTYPECD",open_opts$[3]="OTA"
	open_tables$[4]="SFT_OPNMATTR",open_opts$[4]="OTA"
	open_tables$[5]="SFT_OPNOPRTR",open_opts$[5]="OTA"
	open_tables$[6]="SFT_OPNSUBTR",open_opts$[6]="OTA"
	
	open_tables$[8]="OPE_ORDHDR",open_opts$[8]="OTA"
	open_tables$[9]="OPE_ORDDET",open_opts$[9]="OTA"
	open_tables$[10]="IVM_ITEMMAST",open_opts$[10]="OTA"
	open_tables$[11]="OPC_LINECODE",open_opts$[11]="OTA"
	open_tables$[12]="GLS_CALENDAR",open_opts$[12]="OTA"
	open_tables$[13]="SFT_CLSMATTR",open_opts$[13]="OTA"
	open_tables$[14]="SFT_CLSOPRTR",open_opts$[14]="OTA"
	open_tables$[15]="SFT_CLSSUBTR",open_opts$[15]="OTA"
	open_tables$[16]="SFT_CLSLSTRN",open_opts$[16]="OTA"
	open_tables$[17]="SFT_OPNLSTRN",open_opts$[17]="OTA"
	open_tables$[18]="IVM_ITEMWHSE",open_opts$[18]="OTA"
	open_tables$[19]="SFE_WOSCHDL",open_opts$[19]="OTA"
	open_tables$[20]="SFE_WOMATHDR",open_opts$[20]="OTA"
	open_tables$[21]="SFE_WOMATDTL",open_opts$[21]="OTA"
	open_tables$[22]="SFE_WOMATISH",open_opts$[22]="OTA"
	open_tables$[23]="SFE_WOMATISD",open_opts$[23]="OTA"
	open_tables$[24]="SFE_WOLSISSU",open_opts$[24]="OTA"
	open_tables$[25]="SFE_WOLOTSER",open_opts$[25]="OTA"
	open_tables$[26]="SFE_WOMASTR",open_opts$[26]="OTA@"
	open_tables$[27]="IVM_LSMASTER",open_opts$[27]="OTA@"
	open_tables$[28]="IVC_WHSECODE",open_opts$[28]="OTA"

	gosub open_tables

	sfs_params=num(open_chans$[2])
	dim sfs_params$:open_tpls$[2]
	read record (sfs_params,key=firm_id$+"SF00",dom=std_missing_params) sfs_params$

	rem --- Get end date of previous SF period
	gls_calendar=num(open_chans$[12])
	dim gls_calendar_wk$:open_tpls$[12]
	sf_prevper=num(sfs_params.current_per$)-1
	sf_prevper_year=num(sfs_params.current_year$)
	if sf_prevper=0 then
		sf_prevper_year=sf_prevper_year-1
		read record (gls_calendar,key=firm_id$+str(sf_prevper_year:"0000"),dom=std_missing_params) gls_calendar_wk$
		sf_prevper=num(gls_calendar_wk.total_pers$)
	endif
	call stbl("+DIR_PGM")+"adc_perioddates.aon",sf_prevper,sf_prevper_year,beg_date$,end_date$,table_chans$[all],status
	if status=0 then callpoint!.setDevObject("sf_prevper_enddate",end_date$)

	ivs_params=num(open_chans$[1])
	dim ivs_params$:open_tpls$[1]
	read record (ivs_params,key=firm_id$+"IV00",dom=std_missing_params) ivs_params$
	callpoint!.setDevObject("default_wh",ivs_params.warehouse_id$)
	callpoint!.setDevObject("iv_precision",ivs_params.precision$)

	bm$=sfs_params.bm_interface$
	op$=sfs_params.ar_interface$
	po$=sfs_params.po_interface$
	pr$=sfs_params.pr_interface$

	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]

	if bm$="Y"
		call stbl("+DIR_PGM")+"adc_application.aon","BM",info$[all]
		bm$=info$[20]
	endif

	if bm$<>"Y"
		open_tables$[1]="SFC_OPRTNCOD",open_opts$[1]="OTA"
	else
		open_tables$[1]="BMC_OPCODES",open_opts$[1]="OTA"
		open_tables$[2]="BMM_BILLMAST",open_opts$[2]="OTA"
		rem open_tables$[3]="",open_opts$[3]=""
		open_tables$[4]="BMM_BILLMAT",open_opts$[4]="OTA"
		open_tables$[5]="BMM_BILLOPER",open_opts$[5]="OTA"
		open_tables$[6]="BMM_BILLSUB",open_opts$[6]="OTA"
	endif

	callpoint!.setDevObject("bm",bm$)
	x$=stbl("bm",bm$);rem for downstream rpt when callpoint! object not defined

	gosub open_tables

	callpoint!.setDevObject("opcode_chan",num(open_chans$[1]))
	callpoint!.setDevObject("opcode_tpl",open_tpls$[1])

	op_create_wo$=""
	op_create_wo_typ$=""
	if op$="Y"
		call stbl("+DIR_PGM")+"adc_application.aon","AR",info$[all]
		ar$=info$[20]
		call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
		op$=info$[20]

		num_files=1
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="OPS_PARAMS",open_opts$[1]="OTA"
		gosub open_tables
		opsParams_dev=num(open_chans$[1])
		dim opsParams$:open_tpls$[1]

		readrecord(opsParams_dev,key=firm_id$+"AR00",dom=*next)opsParams$
		op_create_wo$=opsParams.op_create_wo$
		op_create_wo_typ$=opsParams.op_create_wo_typ$
	endif
	callpoint!.setDevObject("ar",ar$)
	callpoint!.setDevObject("op",op$)
	callpoint!.setDevObject("op_create_wo",op_create_wo$)
	callpoint!.setDevObject("op_create_wo_typ",op_create_wo_typ$)

	if po$="Y"
		call stbl("+DIR_PGM")+"adc_application.aon","PO",info$[all]
		po$=info$[20]

		num_files=2
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]

		open_tables$[1]="POE_PODET",open_opts$[1]="OTA"
		open_tables$[2]="POE_REQDET",open_opts$[2]="OTA"

		gosub open_tables

	endif
	callpoint!.setDevObject("po",po$)
	x$=stbl("po",po$)

	if pr$="Y"
		call stbl("+DIR_PGM")+"adc_application.aon","PR",info$[all]
		pr$=info$[20]
	endif
	callpoint!.setDevObject("pr",pr$)
	x$=stbl("pr",pr$)

	call stbl("+DIR_PGM")+"adc_application.aon","MP",info$[all]
	callpoint!.setDevObject("mp",info$[20])
	mp$=info$[20]

rem --- alter control label and prompt for Bill No vs. Item ID depending on whether or not bm$=Y
	
	wctl!=callpoint!.getControl("ITEM_ID")
	wctl_id=wctl!.getID()-1000
	wcontext=num(callpoint!.getTableColumnAttribute("SFE_WOMASTR.ITEM_ID","CTLC"))
	lbl_ctl!=SysGUI!.getWindow(wcontext).getControl(wctl_id)
	if bm$="Y"
		lbl_ctl!.setText(Translate!.getTranslation("AON_BILL_NUMBER:","Bill Number:",1))
		callpoint!.setTableColumnAttribute("SFE_WOMASTR.ITEM_ID","PROM",Translate!.getTranslation("AON_ENTER_BILL_NUMBER","Enter a valid Bill of Materials number",1))
		rem callpoint!.setTableColumnAttribute("SFE_WOMASTR.ITEM_ID", "IDEF", "BOM_LOOKUP")
	else
		lbl_ctl!.setText(Translate!.getTranslation("AON_INVENTORY_ITEM_ID:","Inventory Item ID:",1))
		callpoint!.setTableColumnAttribute("SFE_WOMASTR.ITEM_ID","PROM",Translate!.getTranslation("AON_ENTER_INVENTORY_ITEM_ID","Enter a valid Inventory Item ID",1))
	endif

rem --- Add static label for non-stock item description
	itemId!=callpoint!.getControl("SFE_WOMASTR.ITEM_ID")
	tempWin!=SysGUI!.getWindow(itemId!.getContextID())
	itemId_x=itemId!.getX()
	itemId_y=itemId!.getY()
	itemId_height=itemId!.getHeight()
	itemId_width=itemId!.getWidth()
	label_width=250
	nxt_ctlID=util.getNextControlID()
	nonStock_desc!=Form!.addStaticText(nxt_ctlID,itemId_x+itemId_width+40,itemId_y+65,label_width,itemId_height-6,"")
	nonStock_desc!.setFont(tempWin!.getFont())
	nonStock_desc!.setBackColor(tempWin!.getBackColor())
	nonStock_desc!.setForeColor(SysGUI!.makeColor(0,0,96))
	nonStock_desc!.setText("")
	nonStock_desc!.setVisible(0)
	callpoint!.setDevObject("nonStock_desc",nonStock_desc!)

[[SFE_WOMASTR.AOPT-COPY]]
rem --- Copy from other Work Order
	wo_loc$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
	wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	rem --- Add Barista soft lock for this record if not already in edit mode
	if !callpoint!.isEditMode() then
		rem --- Is there an existing soft lock?
		lock_table$="SFE_WOMASTR"
		lock_record$=firm_id$+wo_loc$+wo_no$
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

rem --- Check to make sure there aren't existing requirements

	woe02_dev=fnget_dev("SFE_WOOPRTN")
	woe22_dev=fnget_dev("SFE_WOMATL")
	woe32_dev=fnget_dev("SFE_WOSUBCNT")

	found_reqs=0

	read(woe02_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
	while 1
		k$=key(woe02_dev,end=*break)
		if pos(firm_id$+wo_loc$+wo_no$=k$)=0 break
		found_reqs=1
		break
	wend

	read(woe22_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
	while 1
		k$=key(woe22_dev,end=*break)
		if pos(firm_id$+wo_loc$+wo_no$=k$)=0 break
		found_reqs=1
		break
	wend

	read(woe32_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
	while 1
		k$=key(woe32_dev,end=*break)
		if pos(firm_id$+wo_loc$+wo_no$=k$)=0 break
		found_reqs=1
		break
	wend

	if found_reqs=1
		msg_id$="REQS_EXIST"
		gosub disp_message
		break
	endif

rem --- Check for mandatory data

	if callpoint!.getDevObject("wo_category")<>"N" or
:		num(callpoint!.getColumnData("SFE_WOMASTR.EST_YIELD"))=0 or
:		cvs(callpoint!.getColumnData("SFE_WOMASTR.OPENED_DATE"),3)="" or
:		num(callpoint!.getColumnData("SFE_WOMASTR.SCH_PROD_QTY"))=0 or
:		cvs(callpoint!.getColumnData("SFE_WOMASTR.UNIT_MEASURE"),3)="" or
:		cvs(callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID"),3)="" or
:		pos(callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="QP")=0 
		
		msg_id$="SF_MISSING_INFO"
		gosub disp_message
		break
	endif
	
rem --- Copy the Work Order

	callpoint!.setDevObject("category",callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY"))
	callpoint!.setDevObject("wo_loc",callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION"))
	callpoint!.setDevObject("wo_no",callpoint!.getColumnData("SFE_WOMASTR.WO_NO"))
	callpoint!.setDevObject("eststt_date",callpoint!.getColumnData("SFE_WOMASTR.ESTSTT_DATE"))
	callpoint!.setDevObject("opened_date",callpoint!.getColumnData("SFE_WOMASTR.OPENED_DATE"))

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SFE_WOCOPY",
:		stbl("+USER_ID"),
:		"MNT",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

rem --- Set LOCK_REF_NUM=Y for copied WO
	callpoint!.setColumnData("SFE_WOMASTR.LOCK_REF_NUM","Y",1)
	lockRefNum!=callpoint!.getControl("SFE_WOMASTR.LOCK_REF_NUM")
	lockRefNum!.setSelected(1)

rem --- Get memo_1024 comments from WO that was copied
	memo_1024$=callpoint!.getDevObject("memo_1024")
	callpoint!.setColumnData("SFE_WOMASTR.MEMO_1024",memo_1024$,1)
	memoRefNum!=callpoint!.getControl("SFE_WOMASTR.MEMO_1024")
	memoRefNum!.setText(memo_1024$)

	callpoint!.setStatus("SAVE")

rem --- No need to remove temporary soft lock used just for this task since the SAVE takes care of it.

[[SFE_WOMASTR.AOPT-CSTS]]
rem --- Display Cost Summary

	callpoint!.setDevObject("wo_status",callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS"))
	callpoint!.setDevObject("closed_date",callpoint!.getColumnData("SFE_WOMASTR.CLOSED_DATE"))

	run stbl("+DIR_PGM")+"sfe_costsumm.aon"

[[SFE_WOMASTR.AOPT-DRPT]]
rem --- WO Detail Report (Hard Copy)

	key_pfx$=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")+callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	dim dflt_data$[3,1]
	dflt_data$[1,0]="FIRM_ID"
	dflt_data$[1,1]=firm_id$
	dflt_data$[2,0]="WO_LOCATION"
	dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
	dflt_data$[3,0]="WO_NO"
	dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SFR_WOHARDCOPY",
:		stbl("+USER_ID"),
:		access$,
:		key_pfx$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[SFE_WOMASTR.AOPT-JOBS]]
rem --- Display Job Status

	callpoint!.setDevObject("wo_status",callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS"))
	callpoint!.setDevObject("closed_date",callpoint!.getColumnData("SFE_WOMASTR.CLOSED_DATE"))

	run stbl("+DIR_PGM")+"sfe_jobstat.aon"

[[SFE_WOMASTR.AOPT-LSNO]]
rem --- launch sfe_wolotser form to assign lot/serial numbers
rem --- should only be enabled if on an inventory type WO, if item is lotted/serialized, and if params have LS set.
	callpoint!.setDevObject("warehouse_id",callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID"))
	callpoint!.setDevObject("item_id",callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID"))
	callpoint!.setDevObject("cls_inp_qty",callpoint!.getColumnData("SFE_WOMASTR.CLS_INP_QTY"))
	callpoint!.setDevObject("qty_cls_todt",callpoint!.getColumnData("SFE_WOMASTR.QTY_CLS_TODT"))
	callpoint!.setDevObject("closed_cost",callpoint!.getColumnData("SFE_WOMASTR.CLOSED_COST"))
	callpoint!.setDevObject("wolotser_action","schedule")
	callpoint!.setDevObject("lotser",callpoint!.getColumnData("SFE_WOMASTR.LOTSER_FLAG"))

	key_pfx$=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")+callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	dim dflt_data$[3,1]
	dflt_data$[1,0]="SFE_WOLOTSER.FIRM_ID"
	dflt_data$[1,1]=firm_id$
	dflt_data$[2,0]="SFE_WOLOTSER.WO_LOCATION"
	dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
	dflt_data$[3,0]="SFE_WOLOTSER.WO_NO"
	dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SFE_WOLOTSER",
:		stbl("+USER_ID"),
:		access$,
:		key_pfx$,
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[SFE_WOMASTR.AOPT-RELS]]
rem --- Release/Commit the Work Order

	rem --- Add Barista soft lock for this record if not already in edit mode
	if !callpoint!.isEditMode() then
		rem --- Is there an existing soft lock?
		lock_table$="SFE_WOMASTR"
		lock_record$=firm_id$+callpoint!.getDevObject("wo_loc")+callpoint!.getDevObject("wo_no")
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

	callpoint!.setDevObject("wo_status",callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS"))

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SFE_RELEASEWO",
:		stbl("+USER_ID"),
:		"MNT",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

	if callpoint!.getDevObject("wo_status")="O"
		callpoint!.setColumnData("SFE_WOMASTR.WO_STATUS","O")
		callpoint!.setStatus("SAVE-RECORD:["+firm_id$+callpoint!.getDevObject("wo_loc")+callpoint!.getDevObject("wo_no")+"]")
	endif

	rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[SFE_WOMASTR.AOPT-SCHD]]
rem --- Schedule the Work Order
	wo_location$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
	wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	rem --- Add Barista soft lock for this record if not already in edit mode
	if !callpoint!.isEditMode() then
		rem --- Is there an existing soft lock?
		lock_table$="SFE_WOMASTR"
		lock_record$=firm_id$+wo_location$+wo_no$
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

	callpoint!.setDevObject("wo_no",wo_no$)
	callpoint!.setDevObject("wo_location",wo_location$)
	callpoint!.setDevObject("order_no",callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO"))
	callpoint!.setDevObject("item_id",callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID"))
	callpoint!.setDevObject("customer_id",callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID"))
	callpoint!.setDevObject("order_no",callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO"))
	callpoint!.setDevObject("sls_ord_seq_ref",callpoint!.getColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF"))
	callpoint!.setDevObject("prev_estcmp_date",callpoint!.getColumnData("SFE_WOMASTR.ESTCMP_DATE"))

	sched_flag$=callpoint!.getColumnData("SFE_WOMASTR.SCHED_FLAG")
	eststt_date$=callpoint!.getColumnData("SFE_WOMASTR.ESTSTT_DATE")
	estcmp_date$=callpoint!.getColumnData("SFE_WOMASTR.ESTCMP_DATE")

	dim dflt_data$[3,1]
	dflt_data$[1,0]="SCHED_FLAG"
	dflt_data$[1,1]=sched_flag$
	dflt_data$[2,0]="ESTSTT_DATE"
	dflt_data$[2,1]=eststt_date$
	dflt_data$[3,0]="ESTCMP_DATE"
	dflt_data$[3,1]=estcmp_date$

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SFR_SCHEDWO",
:		stbl("+USER_ID"),
:		"MNT",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

	sched_method$=callpoint!.getDevObject("sched_method")
	start_date$=callpoint!.getDevObject("start_date")
	comp_date$=callpoint!.getDevObject("comp_date")

	rem --- sched_method$ is blank if sfr_schedwo was exited without scheduling
	if sched_method$<>"" and
:	(sched_method$<>sched_flag$ or start_date$<>eststt_date$ or comp_date$<>estcmp_date$) then
		callpoint!.setColumnData("SFE_WOMASTR.SCHED_FLAG",sched_method$,1)
		callpoint!.setColumnData("SFE_WOMASTR.ESTSTT_DATE",start_date$,1)
		callpoint!.setColumnData("SFE_WOMASTR.ESTCMP_DATE",comp_date$,1)
		callpoint!.setStatus("SAVE-RECORD:["+firm_id$+callpoint!.getDevObject("wo_loc")+callpoint!.getDevObject("wo_no")+"]")
	endif

	rem --- Remove temporary soft lock used just for this task 
	if !callpoint!.isEditMode() and lock_type$="L" then
		lock_type$="U"
		call stbl("+DIR_SYP")+"bac_lock_record.bbj",lock_table$,lock_record$,lock_type$,lock_disp$,rd_table_chan,table_chans$[all],lock_status$
	endif

[[SFE_WOMASTR.AOPT-TRNS]]
rem --- Work Order Transaction History report

	callpoint!.setDevObject("closed_date",callpoint!.getColumnData("SFE_WOMASTR.CLOSED_DATE"))

	dim dflt_data$[5,1]
	dflt_data$[1,0]="WO_NO"
	dflt_data$[1,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
	dflt_data$[2,0]="WO_STATUS"
	dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")
	dflt_data$[3,0]="CLOSED_DATE"
	dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.CLOSED_DATE")
	dflt_data$[4,0]="GL_END_DATE"
	dflt_data$[4,1]=callpoint!.getDevObject("sf_prevper_enddate")
	dflt_data$[5,0]="WO_LOCATION"
	dflt_data$[5,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")

	call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:		"SFE_TRANSHIST",
:		stbl("+USER_ID"),
:		"MNT",
:		"",
:		table_chans$[all],
:		"",
:		dflt_data$[all]

[[SFE_WOMASTR.AREC]]
rem --- Set new record flag

	callpoint!.setDevObject("new_rec","Y")
	callpoint!.setDevObject("wo_status",callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS"))
	callpoint!.setDevObject("wo_no","")
	callpoint!.setDevObject("wo_loc","")

rem --- Disable Additional Options

	callpoint!.setOptionEnabled("SCHD",0)
	callpoint!.setOptionEnabled("RELS",0)
	callpoint!.setOptionEnabled("COPY",0)
	callpoint!.setOptionEnabled("LSNO",0)

rem --- set defaults

	callpoint!.setColumnData("SFE_WOMASTR.LOCK_REF_NUM","N")
	callpoint!.setDevObject("lock_ref_num",callpoint!.getColumnData("SFE_WOMASTR.LOCK_REF_NUM"))
	callpoint!.setColumnData("SFE_WOMASTR.WAREHOUSE_ID",str(callpoint!.getDevObject("default_wh")))
	callpoint!.setDevObject("warehouse_id",str(callpoint!.getDevObject("default_wh")))
	callpoint!.setColumnData("SFE_WOMASTR.OPENED_DATE",stbl("+SYSTEM_DATE"))
	callpoint!.setColumnData("SFE_WOMASTR.ESTSTT_DATE",stbl("+SYSTEM_DATE"))
	callpoint!.setDevObject("prod_qty","1")
	callpoint!.setDevObject("wo_est_yield","100")

rem --- enable all enterable fields

	callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.BILL_REV",1)
	if callpoint!.getDevObject("ar")="Y"
		callpoint!.setColumnEnabled("SFE_WOMASTR.CUSTOMER_ID",1)
	else
		callpoint!.setColumnEnabled("SFE_WOMASTR.CUSTOMER_ID",0)
	endif
	callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_01",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_02",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_NO",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_REV",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.EST_YIELD",1)
	if callpoint!.getDevObject("mp")="Y"
		callpoint!.setColumnEnabled("SFE_WOMASTR.FORECAST",1)
	else
		callpoint!.setColumnEnabled("SFE_WOMASTR.FORECAST",0)
	endif
	if callpoint!.getDevObject("op")="Y"
		callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_ID",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.ORDER_NO",1)
	else
		callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_ID",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.ORDER_NO",0)
	endif
	callpoint!.setColumnEnabled("SFE_WOMASTR.OPENED_DATE",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.PRIORITY",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.SCH_PROD_QTY",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.UNIT_MEASURE",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.WAREHOUSE_ID",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.WO_TYPE",1)
	callpoint!.setColumnEnabled("SFE_WOMASTR.WO_STATUS",1)

rem --- Hide static label for non-stock item description
	nonStock_desc!=callpoint!.getDevObject("nonStock_desc")
	nonStock_desc!.setText("")
	nonStock_desc!.setVisible(0)

[[SFE_WOMASTR.ASVA]]
rem --- Disable Scheduled Quantity and Yield if Inventory Item

	typecode_dev=fnget_dev("SFC_WOTYPECD")
	dim typecode$:fnget_tpl$("SFC_WOTYPECD")

	type$=callpoint!.getColumnData("SFE_WOMASTR.WO_TYPE")
	readrecord(typecode_dev,key=firm_id$+"A"+type$)typecode$
	if typecode.wo_category$="I"
		callpoint!.setColumnEnabled("SFE_WOMASTR.SCH_PROD_QTY",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.EST_YIELD",0)
	endif

[[SFE_WOMASTR.AWRI]]
rem --- create WO comments from BOM comments

	if callpoint!.getDevObject("bm")="Y" and callpoint!.getDevObject("new_rec")="Y"
		comments$=""	
		bmm01_dev=fnget_dev("BMM_BILLMAST")
		dim bmm01a$:fnget_tpl$("BMM_BILLMAST")
		item_id$=callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID")
		readrecord(bmm01_dev,key=firm_id$+item_id$,dom=*next)bmm01a$
		if bmm01a.firm_id$+bmm01a.bill_no$=firm_id$+item_id$ then
			comments$=cvs(bmm01a.memo_1024$,3)
		endif
		callpoint!.setColumnData("SFE_WOMASTR.MEMO_1024",comments$,1)
	endif

rem --- adjust OO if qty has changed on an open WO
rem --- as far as I can see, this can only happen if BOM not installed, otherwise can't change qty on an open WO

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="O" and callpoint!.getDevObject("new_rec")="N"

		new_prod_qty=num(callpoint!.getColumnData("SFE_WOMASTR.SCH_PROD_QTY"))
		old_prod_qty=num(callpoint!.getDevObject("prod_qty"))
		wo_category$=callpoint!.getDevObject("wo_category")

		if old_prod_qty<>new_prod_qty and wo_category$="I"

			rem --- initialize atamo
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
			items$[1]=callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID")
			items$[2]=callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID")

			rem --- update OO w/ delta of new_prod_qty-old_prod_qty
			refs[0]=new_prod_qty-old_prod_qty
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon","OO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status		
		endif
	endif

rem --- launch other form(s) based on WO category

	if callpoint!.getDevObject("new_rec")="Y"
		switch pos(callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="INR")

			case 1;rem --- if on a regular stock WO, show mats grid

				key_pfx$=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")+callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

				dim dflt_data$[3,1]
				dflt_data$[1,0]="FIRM_ID"
				dflt_data$[1,1]=firm_id$
				dflt_data$[2,0]="WO_LOCATION"
				dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
				dflt_data$[3,0]="WO_NO"
				dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

				call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:					"SFE_WOMATL",
:					stbl("+USER_ID"),
:					"MNT",
:					key_pfx$,
:					table_chans$[all],
:					"",
:					dflt_data$[all]

				callpoint!.setStatus("ACTIVATE")

			break

			case 2;rem --- if on non-stock, launch ops, then mats, then subs grids
				   rem --- note: if user closes each form w/ mouse-click on red X, this works, but there are (it looks like) timing issues
				   rem --- if using ctl-F4 -- it will close one form, then launch and immediately close another one

				key_pfx$=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")+callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

				dim dflt_data$[3,1]
				dflt_data$[1,0]="FIRM_ID"
				dflt_data$[1,1]=firm_id$
				dflt_data$[2,0]="WO_LOCATION"
				dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
				dflt_data$[3,0]="WO_NO"
				dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

				call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:					"SFE_WOOPRTN",
:					stbl("+USER_ID"),
:					"MNT",
:					key_pfx$,
:					table_chans$[all],
:					"",
:					dflt_data$[all]

launch_mats:
				call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:					"SFE_WOMATL",
:					stbl("+USER_ID"),
:					"MNT",
:					key_pfx$,
:					table_chans$[all],
:					"",
:					dflt_data$[all]

				if callpoint!.getDevObject("explode_bills")="Y" then goto launch_mats

				call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:					"SFE_WOSUBCNT",
:					stbl("+USER_ID"),
:					"MNT",
:					key_pfx$,
:					table_chans$[all],
:					"",
:					dflt_data$[all]

				callpoint!.setStatus("ACTIVATE")

			break

			case 3;rem --- if recurring, launch ops grid


				key_pfx$=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")+callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

				dim dflt_data$[3,1]
				dflt_data$[1,0]="FIRM_ID"
				dflt_data$[1,1]=firm_id$
				dflt_data$[2,0]="WO_LOCATION"
				dflt_data$[2,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
				dflt_data$[3,0]="WO_NO"
				dflt_data$[3,1]=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

				call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:					"SFE_WOOPRTN",
:					stbl("+USER_ID"),
:					"MNT",
:					key_pfx$,
:					table_chans$[all],
:					"",
:					dflt_data$[all]

				callpoint!.setStatus("ACTIVATE")

			break

			case default
			break

		swend
	endif

rem --- Set new_rec to N and disable Item Number

	callpoint!.setDevObject("new_rec","N")
	callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",0)

rem --- disable Copy function if closed or not an N category

	if callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")<>"N" or 
:	callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="C"
		callpoint!.setOptionEnabled("COPY",0)
	else
		callpoint!.setOptionEnabled("COPY",1)
	endif

rem --- enable Release/Commit

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")<>"C"
		callpoint!.setOptionEnabled("RELS",1)
		callpoint!.setOptionEnabled("SCHD",1)
	endif

[[SFE_WOMASTR.BDEL]]
rem --- Warn if this WO is linked to a Sales Order

	if cvs(callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID"),2)<>"" and 
:	cvs(callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO"),2)<>"" and 
:	num(callpoint!.getColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF"))>0 then
		msg_id$="SF_DELETE_LINKED_WO"
		dim msg_tokens$[2]
		msg_tokens$[1]=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
		msg_tokens$[2]=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
		gosub disp_message
		if msg_opt$<>"Y" then
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		endif
	endif

rem --- cascade delete will take care of removing:
rem ---   requirements (sfe_wooprtn/sfe-02, sfe_womatl/sfe-22, sfe_wosubcnt/sfe-32)
rem ---   sfe_closedwo, sfe_openedwo, sfe_wocommit, sfe_wotrans (the old sfe-04 A/B/C/D recs)
rem --- otherwise, need to:
rem --- 1. remove sfe_womathdr/sfe_womatdtl (sfe-13/23) and uncommit inventory
rem --- 2. reduce on-order if it's an inventory-category work order that's in "open" status
rem --- 3. remove schedule detail (sfe_woschdl/sfm-05)

	wo_location$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
	wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

	sfe13_dev=fnget_dev("SFE_WOMATHDR")
	dim sfe_womathdr$:fnget_tpl$("SFE_WOMATHDR")
	sfe23_dev=fnget_dev("SFE_WOMATDTL")
	dim sfe_womatdtl$:fnget_tpl$("SFE_WOMATDTL")
	
	rem --- Initialize inventory item update
	call stbl("+DIR_PGM")+"ivc_itemupdt.aon::init",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status

rem --- Loop thru materials detail - uncommit lot/serial only (i.e. atamo uncommits both item and lot/serial, so re-commit item and uncommit that qty later)

	read (sfe13_dev,key=firm_id$+wo_location$+wo_no$,dom=*next,dir=0)
	while 1
		sfe13_key$=key(sfe13_dev,end=*break)
		extract record (sfe13_dev)sfe_womathdr$; rem --- Advisory locking
		if pos(firm_id$+wo_location$+wo_no$=sfe13_key$)<>1 then break

		read (sfe23_dev,key=firm_id$+wo_location$+wo_no$,dom=*next)
		while 1
			sfe23_key$=key(sfe23_dev,end=*break)
			read record(sfe23_dev)sfe_womatdtl$
			if pos(firm_id$+wo_location$+wo_no$=sfe23_key$)<>1 then break
					
			rem --- Uncommit inventory
			items$[1]=sfe_womatdtl.warehouse_id$
			items$[2]=sfe_womatdtl.item_id$
			items$[3]=""
			refs[0]=max(0,sfe_womatdtl.qty_ordered-sfe_womatdtl.tot_qty_iss)
			call stbl("+DIR_PGM")+"ivc_itemupdt.aon","UC",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
			remove(sfe23_dev,key=sfe23_key$)
		wend

		remove (sfe13_dev,key=sfe13_key$);rem bottom of 13/23 loop
		break; rem should only be one sfe-13 per work order
	wend

rem --- Remove sfm-05 (sfe_woschdl)

	sfm05_dev=fnget_dev("SFE_WOSCHDL")
	dim sfe_woschdl$:fnget_tpl$("SFE_WOSCHDL")
	
	while 1
		read (sfm05_dev,key=firm_id$+wo_no$,knum="AON_WONUM",dom=*next)
		extract record(sfm05_dev,end=*break)sfe_woschdl$; rem --- Advisory locking
		if sfe_woschdl.firm_id$+sfe_woschdl.wo_no$<>firm_id$+wo_no$ then read(sfm05_dev); break
		remove (sfm05_dev,key=sfe_woschdl.firm_id$+sfe_woschdl.op_code$+sfe_woschdl.sched_date$+sfe_woschdl.wo_no$+sfe_woschdl.oper_seq_ref$,dom=*next)
	wend

	read (sfm05_dev,key="",knum=0,dom=*next);rem --- reset knum to primary

rem --- Reduce on order for scheduled prod qty

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="O" and callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="I"
		items$[1]=callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID")
		items$[2]=callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID")
		refs[0]=-(num(callpoint!.getColumnData("SFE_WOMASTR.SCH_PROD_QTY"))-num(callpoint!.getColumnData("SFE_WOMASTR.QTY_CLS_TODT")))
		call stbl("+DIR_PGM")+"ivc_itemupdt.aon","OO",chan[all],ivs01a$,items$[all],refs$[all],refs[all],table_chans$[all],status
	endif

[[SFE_WOMASTR.BDEQ]]
rem --- cannot delete closed work order

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")="C"
		callpoint!.setMessage("SF_NO_DELETE")
		callpoint!.setStatus("ABORT")
	else

rem --- prior to deleting a work order, need to check for open transactions; if any exist, can't delete

		wo_loc$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
		wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
		can_delete$="YES"

		for files=1 to 3
			if files=1
				wotran_dev=fnget_dev("SFT_OPNOPRTR")
				dim wotran$:fnget_tpl$("SFT_OPNOPRTR")
			endif
			if files=2
				wotran_dev=fnget_dev("SFT_OPNMATTR")
				dim wotran$:fnget_tpl$("SFT_OPNMATTR")
			endif
			if files=3
				wotran_dev=fnget_dev("SFT_OPNSUBTR")
				dim wotran$:fnget_tpl$("SFT_OPNSUBTR")
			endif
			read(wotran_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)

			while 1
				wotran_key$=key(wotran_dev,end=*break)
				if pos(firm_id$+wo_loc$+wo_no$=wotran_key$)=1 then can_delete$="NO"
				break
			wend
		next files

		sfe15_dev=fnget_dev("SFE_WOMATISH")
		read (sfe15_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
		while 1
			sfe15_key$=key(sfe15_dev,end=*break)
			if pos(firm_id$+wo_loc$+wo_no$=sfe15_key$)=1 then can_delete$="NO"
			break
		wend

		if can_delete$="NO"
			callpoint!.setMessage("SF_OPEN_TRANS")
			callpoint!.setStatus("ABORT")
		endif
	endif
	

[[SFE_WOMASTR.BSHO]]
rem --- Set callback for a tab being selected, and save the tab control ID
	tabCtrl!=Form!.getControl(num(stbl("+TAB_CTL")))
	tabCtrl!.setCallback(BBjTabCtrl.ON_TAB_SELECT,"custom_event")

[[SFE_WOMASTR.CUSTOMER_ID.AVAL]]
rem --- Disable Order info if Customer not entered

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")<>"C"
		rem --- Warn if changing link info for a linked WO
		customer_id$=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
		if cvs(customer_id$,2)<>"" and callpoint!.getUserInput()<>customer_id$ then
			msg_id$="SF_CHANGE_SO_LINK"
			dim msg_tokens$[2]
			msg_tokens$[1]=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
			msg_tokens$[2]=customer_id$
			gosub disp_message
			if msg_opt$<>"Y" then
				callpoint!.setColumnData("SFE_WOMASTR.CUSTOMER_ID",customer_id$,1)
				callpoint!.setStatus("ACTIVATE-ABORT")
				break
			endif

		rem --- Add WO comment with the changed SO link info plus audit info.
		wo_comment$ =Translate!.getTranslation("AON_SALES_ORDER")+" "+Translate!.getTranslation("AON_CUSTOMER")+" "
		wo_comment$ =wo_comment$+Translate!.getTranslation("AON_LINK_CHANGED_FROM")+" "
		wo_comment$ =wo_comment$+customer_id$+" " +Translate!.getTranslation("AON_TO")+" " +callpoint!.getUserInput()
		gosub add_wo_comment
		endif

		if cvs(callpoint!.getUserInput(),3)=""
			callpoint!.setColumnEnabled("SFE_WOMASTR.ORDER_NO",0)
			callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_ID",0)
			callpoint!.setColumnData("SFE_WOMASTR.ORDER_NO","",1)
			callpoint!.setColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF","",1)
			callpoint!.setColumnData("<<DISPLAY>>.LINE_NO","",1)
		else
			callpoint!.setColumnEnabled("SFE_WOMASTR.ORDER_NO",1)
		endif

		if callpoint!.getUserInput()<>customer_id$ then
			callpoint!.setColumnData("SFE_WOMASTR.ORDER_NO","",1)
			callpoint!.setColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF","",1)
		endif
	endif

[[SFE_WOMASTR.EST_YIELD.AVAL]]
rem --- Set DevObject

	callpoint!.setDevObject("wo_est_yield",callpoint!.getUserInput())

rem --- Informational warning for category N WO's - requirements may need to be adjusted if qty/yield is changed

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")<>"C" and callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="N"
		if callpoint!.getRecordMode()="C" and callpoint!.getColumnUndoData("SFE_WOMASTR.EST_YIELD")<>callpoint!.getUserInput()
			callpoint!.setMessage("SF_ADJ_REQS")
		endif
	endif

[[SFE_WOMASTR.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"
	item$=callpoint!.getUserInput()
	callpoint!.setColumnData("SFE_WOMASTR.ITEM_ID",item$,1)

[[<<DISPLAY>>.ITEM_ID.AVAL]]
rem --- Validate manually entered SO Item IDs
	item_id$=cvs(callpoint!.getUserInput(),2)
	if item_id$="" then
		if item_id$<>cvs(callpoint!.getColumnData("<<DISPLAY>>.ITEM_ID"),2) then
			rem --- Warn if changing link info for a linked WO
			sls_ord_seq_ref$=""
			gosub checkWOtoSOlink
			if linkStatus$="OK" then
				rem --- Refresh static label for non-stock item description
				nonStock_desc!=callpoint!.getDevObject("nonStock_desc")
				nonStock_desc!.setText("")
				callpoint!.setColumnData("<<DISPLAY>>.LINE_NO","",1)
				callpoint!.setColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF","",1)
				break
			else
				callpoint!.setColumnData("<<DISPLAY>>.ITEM_ID",callpoint!.getColumnData("<<DISPLAY>>.ITEM_ID"),1)
				callpoint!.setStatus("ACTIVATE-ABORT")
				break
			endif
		else
			nonStock_desc!=callpoint!.getDevObject("nonStock_desc")
			if nonStock_desc!.getText()="" then callpoint!.setColumnData("<<DISPLAY>>.LINE_NO","",1)
			break
		endif
	endif
	if item_id$=cvs(callpoint!.getColumnData("<<DISPLAY>>.ITEM_ID"),2) then break

rem --- Can't manufacture kits
	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	dim ivm01a$:fnget_tpl$("IVM_ITEMMAST")
	findrecord(ivm01_dev,key=firm_id$+pad(item_id$,len(ivm01a.item_id$),"L"," "),dom=*next)ivm01a$
	if pos(ivm01a.kit$="YP") then
		msg_id$="SF_KIT_WO"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Verify there is an existing Sales Order detail line with TRANS_STATUS=E for this SO item.
	ope11_dev=fnget_dev("OPE_ORDDET")
	dim ope11a$:fnget_tpl$("OPE_ORDDET")
	sfe01_dev=fnget_dev("@SFE_WOMASTR")
	dim sfe01a$:fnget_tpl$("@SFE_WOMASTR")
	opcLineCode_dev=fnget_dev("OPC_LINECODE")
	dim opcLineCode$:fnget_tpl$("OPC_LINECODE")
	wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
	wo_cat$=callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")
	wo_bom$=cvs(callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID"),2)
	customer_id$=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
	dim foundRecord$:fnget_tpl$("OPE_ORDDET")
	foundItem=0
	goodLineNo$=""
	goodInternalSeqNo$=""

	ope11_trip_key$=firm_id$+ope11a.ar_type$+customer_id$+order_no$
	read(ope11_dev,key=ope11_trip_key$,dom=*next)
	while 1
		ope11_key$=key(ope11_dev,end=*break)
		if pos(ope11_trip_key$=ope11_key$)<>1 break
		readrecord(ope11_dev)ope11a$
		if item_id$<>cvs(ope11a.item_id$,2) or ope11a.trans_status$<>"E" then continue

		rem --- Skip existing SO-WO links except to this WO
		wrongWOLink=0
		sfe01_trip_key$=firm_id$+customer_id$+order_no$+ope11a.internal_seq_no$
		read(sfe01_dev,key=sfe01_trip_key$,knum="AO_CST_ORD_LINE",dom=*next)
		while 1
			sfe01_key$=key(sfe01_dev,end=*break)
			if pos(sfe01_trip_key$=sfe01_key$)<>1 then break
			readrecord(sfe01_dev)sfe01a$
			if sfe01a.wo_no$<>wo_no$ then continue
			wrongWOLink=1
			break
		wend
		if wrongWOLink then continue

		rem --- Skip order detail lines that are not consistent with the WO category
		readrecord(opcLineCode_dev,key=firm_id$+ope11a.line_code$,dom=*continue)opcLineCode$
		if wo_cat$="R" then continue
		if wo_cat$="I" and pos(opcLineCode.line_type$="SP")=0 then continue
		if wo_cat$="N" and pos(opcLineCode.line_type$="N")=0 then continue

		rem --- If the WO Category is Inventoried (I), then the WO BOM and SO Item must be the same.
		if wo_cat$="I" and item_id$<>wo_bom$ then continue

		foundItem=foundItem+1
		goodLineNo$=ope11a.line_no$
		goodInternalSeqNo$=ope11a.internal_seq_no$
	wend

	if foundItem=1 then
		callpoint!.setColumnData("<<DISPLAY>>.LINE_NO",goodLineNo$,1)
		callpoint!.setColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF",goodInternalSeqNo$,1)
	else
		if foundItem=0 then
			msg_id$="SF_SO_ITEM_MISSING"
			dim msg_tokens$[3]
			msg_tokens$[1]=item_id$
			msg_tokens$[2]=order_no$
			msg_tokens$[3]=customer_id$
			gosub disp_message
			callpoint!.setUserInput(cvs(callpoint!.getColumnData("<<DISPLAY>>.ITEM_ID"),2))
			callpoint!.setColumnData("SFE_WOMASTR.CUSTOMER_ID",customer_id$,1)
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		else
			msg_id$="SF_SO_ITEM_DUPLICATES"
			dim msg_tokens$[3]
			msg_tokens$[1]=item_id$
			msg_tokens$[2]=order_no$
			msg_tokens$[3]=customer_id$
			gosub disp_message
			callpoint!.setUserInput(cvs(callpoint!.getColumnData("<<DISPLAY>>.ITEM_ID"),2))
			callpoint!.setColumnData("SFE_WOMASTR.CUSTOMER_ID",customer_id$,1)
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		endif
	endif

[[SFE_WOMASTR.ITEM_ID.AVAL]]
rem "Inventory Inactive Feature"
item_id$=callpoint!.getUserInput()
ivm01_dev=fnget_dev("IVM_ITEMMAST")
ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
dim ivm01a$:ivm01_tpl$
ivm01a_key$=firm_id$+item_id$
find record (ivm01_dev,key=ivm01a_key$,err=*break)ivm01a$
if ivm01a.item_inactive$="Y" then
   msg_id$="IV_ITEM_INACTIVE"
   dim msg_tokens$[2]
   msg_tokens$[1]=cvs(ivm01a.item_id$,2)
   msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
   gosub disp_message
   callpoint!.setStatus("ACTIVATE-ABORT")
   goto std_exit
endif

rem --- Can't manufacture kits
	if pos(ivm01a.kit$="YP") then
		msg_id$="SF_KIT_WO"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
		break
	endif

rem --- Set default values if item_id changed
	if callpoint!.getUserInput()=callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID") then break

	ivm_itemmast=fnget_dev("IVM_ITEMMAST")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")

	read record (ivm_itemmast,key=firm_id$+callpoint!.getUserInput(),dom=*break)ivm_itemmast$
	callpoint!.setColumnData("SFE_WOMASTR.UNIT_MEASURE",ivm_itemmast.unit_of_sale$,1)
	if pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y"
		callpoint!.setColumnData("SFE_WOMASTR.LOTSER_FLAG",ivm_itemmast.lotser_flag$)
		callpoint!.setOptionEnabled("LSNO",1)
	else
		callpoint!.setColumnData("SFE_WOMASTR.LOTSER_FLAG","N")
		callpoint!.setOptionEnabled("LSNO",0)
	endif

	if callpoint!.getDevObject("bm")="Y"
		bmm_billmast=fnget_dev("BMM_BILLMAST")
		dim bmm_billmast$:fnget_tpl$("BMM_BILLMAST")
		while 1
			found_bill$="N"
			read record (bmm_billmast,key=firm_id$+callpoint!.getUserInput(),dom=*break) bmm_billmast$
			found_bill$="Y"
			break
		wend
		if found_bill$="N"
			msg_id$="SF_NO_BILL"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
		callpoint!.setColumnData("SFE_WOMASTR.DRAWING_NO",bmm_billmast.drawing_no$,1)
		callpoint!.setColumnData("SFE_WOMASTR.DRAWING_REV",bmm_billmast.drawing_rev$,1)
		callpoint!.setColumnData("SFE_WOMASTR.EST_YIELD",bmm_billmast.est_yield$,1)
		callpoint!.setColumnData("SFE_WOMASTR.SCH_PROD_QTY",bmm_billmast.std_lot_size$,1)
		callpoint!.setColumnData("SFE_WOMASTR.UNIT_MEASURE",bmm_billmast.unit_measure$,1)
		callpoint!.setColumnData("SFE_WOMASTR.BILL_REV",bmm_billmast.bill_rev$,1)
	endif

rem --- Set default Completion Date

	if cvs(callpoint!.getColumnData("SFE_WOMASTR.ESTCMP_DATE"),2)="" and
:		callpoint!.getColumnData("SFE_WOMASTR.SCHED_FLAG")="M"
		ivm_itemwhse=fnget_dev("IVM_ITEMWHSE")
		dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
		read record (ivm_itemwhse,key=firm_id$+callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID")+
:			callpoint!.getUserInput(),dom=*next)ivm_itemwhse$
		new_date$=""
		leadtime=ivm_itemwhse.lead_time
		call stbl("+DIR_PGM")+"adc_daydates.aon",stbl("+SYSTEM_DATE"),new_date$,leadtime
		if new_date$<>"N"
			callpoint!.setColumnData("SFE_WOMASTR.ESTCMP_DATE",new_date$,1)
		endif
	endif

[[<<DISPLAY>>.ITEM_ID.BINQ]]
rem --- Skip if not in edit mode
	if !callpoint!.isEditMode() then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Put Work Order Number, Category and BOM in Group Namespace
	BBjAPI().getGroupNamespace().setValue("WO_NO_for_OP_ORDDET_ITEMS",callpoint!.getColumnData("SFE_WOMASTR.WO_NO"))
	BBjAPI().getGroupNamespace().setValue("WO_CAT_for_OP_ORDDET_ITEMS",callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY"))
	BBjAPI().getGroupNamespace().setValue("WO_BOM_for_OP_ORDDET_ITEMS",callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID"))

rem --- Historical Invoice Detail lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVDET","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim optInvDet_key$:key_tpl$
	dim filter_defs$[5,2]
	filter_defs$[1,0]="OPT_INVDET.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="OPT_INVDET.AR_TYPE"
	filter_defs$[2,1]="=''"
	filter_defs$[2,2]="LOCK"
	filter_defs$[3,0]="OPT_INVDET.CUSTOMER_ID"
	filter_defs$[3,1]="='"+callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")+"'"
	filter_defs$[3,2]="LOCK"
	filter_defs$[4,0]="OPT_INVDET.ORDER_NO"
	filter_defs$[4,1]="='"+callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")+"'"
	filter_defs$[4,2]="LOCK"
	filter_defs$[5,0]="OPT_INVDET.TRANS_STATUS"
	filter_defs$[5,1]="<>'U'"
	filter_defs$[5,2]="LOCK"
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"OP_ORDDET_ITEMS","",table_chans$[all],optInvDet_key$,filter_defs$[all]

	rem --- Update sales order sequence reference
	if cvs(optInvDet_key$,2)<>"" then
		ope11_dev=fnget_dev("OPE_ORDDET")
		dim ope11a$:fnget_tpl$("OPE_ORDDET")
		readrecord(ope11_dev,key=optInvDet_key$(1,len(optInvDet_key$)-1),dom=*next)ope11a$

		rem --- Warn if changing link info for a linked WO
		sls_ord_seq_ref$=ope11a.internal_seq_no$
		gosub checkWOtoSOlink
		if linkStatus$="OK" then
			callpoint!.setColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF",ope11a.internal_seq_no$,1)

			rem --- Refresh static label for non-stock item description
			gosub refreshNonStockDescription

			callpoint!.setStatus("MODIFIED")
		endif
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")

[[SFE_WOMASTR.LOCK_REF_NUM.AVAL]]
rem --- Notify when LOCK_REF_NUM is changed
	prev_lockrefnum$=callpoint!.getDevObject("prev_lockrefnum")
	lock_ref_num$=callpoint!.getUserInput()
	callpoint!.setDevObject("lock_ref_num",lock_ref_num$)
	if lock_ref_num$<>prev_lockrefnum$ then
		dim msg_tokens$[2]
		if lock_ref_num$="Y" then
			msg_tokens$[1] = "lock"
			msg_tokens$[2] = "cannot"
		else
			msg_tokens$[1] = "unlock"
			msg_tokens$[2] = "can"
		endif
		msg_id$="SF_REFNUM_LOCK"
		gosub disp_message
		if msg_opt$<>"Y" then 
			callpoint!.setColumnData("SFE_WOMASTR.LOCK_REF_NUM",prev_lockrefnum$,1)
			callpoint!.setStatus("ABORT")
		endif
	endif

[[SFE_WOMASTR.LOCK_REF_NUM.BINP]]
rem --- Need to know if LOCK_REF_NUM is changed
	prev_lockrefnum$=callpoint!.getColumnData("SFE_WOMASTR.LOCK_REF_NUM")
	callpoint!.setDevObject("prev_lockrefnum",prev_lockrefnum$)

[[SFE_WOMASTR.OPENED_DATE.AVAL]]
rem --- need to see if date has been changed; if so, prompt to change in sfe-02/22/23 as well


	prev_dt$=cvs(callpoint!.getColumnUndoData("SFE_WOMASTR.OPENED_DATE"),3)
	new_dt$=callpoint!.getUserInput()
	if prev_dt$<>"" and prev_dt$<>new_dt$ and callpoint!.getDevObject("new_rec")<>"Y" then
		msg_id$="SF_CHANGE_DTS"
		gosub disp_message

		if msg_opt$="Y"
			sfe02_dev=fnget_dev("SFE_WOOPRTN")
			sfe22_dev=fnget_dev("SFE_WOMATL")
			sfe23_dev=fnget_dev("SFE_WOMATDTL")

			dim sfe_wooprtn$:fnget_tpl$("SFE_WOOPRTN")
			dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")
			dim sfe_womatdtl$:fnget_tpl$("SFE_WOMATDTL")

			wo_loc$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
			wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")

			rem --- operations requirements - 6500 in sfe_ab
			read (sfe02_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
			while 1
				k$=key(sfe02_dev,end=*break)
				extractrecord(sfe02_dev)sfe_wooprtn$; rem --- Advisory locking
				if sfe_wooprtn.firm_id$+sfe_wooprtn.wo_location$+sfe_wooprtn.wo_no$<>firm_id$+wo_loc$+wo_no$ then break
				sfe_wooprtn.require_date$=new_dt$
				sfe_wooprtn$=field(sfe_wooprtn$)
				writerecord(sfe02_dev)sfe_wooprtn$
			wend
	
			rem --- materials requirements - 6600 in sfe_ab
			read (sfe22_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
			while 1
				k$=key(sfe22_dev,end=*break)
				extractrecord(sfe22_dev)sfe_womatl$; rem --- Advisory locking
				if sfe_womatl.firm_id$+sfe_womatl.wo_location$+sfe_womatl.wo_no$<>firm_id$+wo_loc$+wo_no$ then break
				sfe_womatl.require_date$=new_dt$
				sfe_womatl$=field(sfe_womatl$)
				writerecord(sfe22_dev)sfe_womatl$
			wend

			rem --- materials commitments - 6800 in sfe_ab
			read (sfe23_dev,key=firm_id$+wo_loc$+wo_no$,dom=*next)
			while 1
				k$=key(sfe23_dev,end=*break)
				extractrecord(sfe23_dev)sfe_womatdtl$; rem --- Advisory locking
				if sfe_womatdtl.firm_id$+sfe_womatdtl.wo_location$+sfe_womatdtl.wo_no$<>firm_id$+wo_loc$+wo_no$ then break
				sfe_womatdtl.require_date$=new_dt$
				sfe_womatdtl$=field(sfe_womatdtl$)
				writerecord(sfe23_dev)sfe_womatdtl$
			wend

		endif
	endif

[[SFE_WOMASTR.ORDER_NO.AVAL]]
rem --- Validate Open Sales Order

	rem --- Warn if changing link info for a linked WO
	order_no$=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
	if cvs(order_no$,2)<>"" and callpoint!.getUserInput()<>order_no$ then
		msg_id$="SF_CHANGE_SO_LINK"
		dim msg_tokens$[2]
		msg_tokens$[1]=order_no$
		msg_tokens$[2]=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
		gosub disp_message
		if msg_opt$<>"Y" then
			callpoint!.setColumnData("SFE_WOMASTR.ORDER_NO",order_no$,1)
			callpoint!.setStatus("ACTIVATE-ABORT")
			break
		endif

		rem --- Add WO comment with the changed SO link info plus audit info.
		wo_comment$ =Translate!.getTranslation("AON_SALES_ORDER")+" "+Translate!.getTranslation("AON_ORDER")+" "
		wo_comment$ =wo_comment$+Translate!.getTranslation("AON_LINK_CHANGED_FROM")+" "
		wo_comment$ =wo_comment$+order_no$+" " +Translate!.getTranslation("AON_TO")+" " +callpoint!.getUserInput()
		gosub add_wo_comment
	endif

	if cvs(callpoint!.getUserInput(),2)<>cvs(order_no$,2)
		callpoint!.setColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF","",1)
	endif

	if cvs(callpoint!.getUserInput(),2)<>""
		ope_ordhdr=fnget_dev("OPE_ORDHDR")
		dim ope_ordhdr$:fnget_tpl$("OPE_ORDHDR")
		cust$=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
		order$=callpoint!.getUserInput()
		found_ord$="N"
		read (ope_ordhdr,key=firm_id$+ope_ordhdr.ar_type$+cust$+order$,knum="PRIMARY",dom=*next)
		while 1
			ope_ordhdr_key$=key(ope_ordhdr,end=*break)
			if pos(firm_id$+ope_ordhdr.ar_type$+cust$+order$=ope_ordhdr_key$)<>1 then break
			readrecord(ope_ordhdr)ope_ordhdr$
			if pos(ope_ordhdr.trans_status$="ER")=0 then continue
			found_ord$="Y"
			break; rem --- new order can have at most just one new invoice, if any
		wend

		if found_ord$="N"
			msg_id$="SF_INVALID_SO_ORD"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

	endif

	callpoint!.setColumnEnabled("<<DISPLAY>>.ITEM_ID",1)

[[SFE_WOMASTR.SCH_PROD_QTY.AVAL]]
rem --- Verify minimum quantity > 0

	if num(callpoint!.getUserInput())<=0
		msg_id$="IV_QTY_GT_ZERO"
		gosub disp_message
		callpoint!.setColumnData("SFE_WOMASTR.SCH_PROD_QTY",callpoint!.getColumnData("SFE_WOMASTR.SCH_PROD_QTY"),1)
		callpoint!.setStatus("ABORT")
	endif

rem --- Enable Copy Button

	if callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="N" and num(callpoint!.getUserInput())>0 and callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("COPY",1)
	endif

	callpoint!.setDevObject("prod_qty",callpoint!.getUserInput())

rem --- Informational warning for category N WO's - requirements may need to be adjusted if qty/yield is changed

	if callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")<>"C" and callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")="N"
		if callpoint!.getRecordMode()="C" and callpoint!.getColumnUndoData("SFE_WOMASTR.SCH_PROD_QTY")<>callpoint!.getUserInput()
			callpoint!.setMessage("SF_ADJ_REQS")
		endif
	endif

[[SFE_WOMASTR.WAREHOUSE_ID.AVAL]]
rem --- Don't allow inactive code
	ivcWhseCode_dev=fnget_dev("IVC_WHSECODE")
	dim ivcWhseCode$:fnget_tpl$("IVC_WHSECODE")
	whse_code$=callpoint!.getUserInput()
	read record (ivcWhseCode_dev,key=firm_id$+"C"+whse_code$,dom=*next)ivcWhseCode$
	if ivcWhseCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Is the warehouse being changed?
	if callpoint!.getUserInput()<>callpoint!.getColumnData("SFE_WOMASTR.WAREHOUSE_ID") then
		warehouse_id$=callpoint!.getUserInput()

		rem --- Don't allow changing warehouse if there are existing material requirements
		sfe_womatl_dev=fnget_dev("SFE_WOMATL")
		dim sfe_womatl$:fnget_tpl$("SFE_WOMATL")
		loc$=callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION")
		wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
		read (sfe_womatl_dev,key=firm_id$+loc$+wo_no$,dom=*next)
		sfe_womatl_key$=key(sfe_womatl_dev,end=*end)
		if pos(firm_id$+loc$+wo_no$=sfe_womatl_key$)=1 then
			msg_id$="SF_CANNOT_CHG_WHSE"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif

		rem --- Reset warehouse_id dev object to this warehouse
		callpoint!.setDevObject("warehouse_id",callpoint!.getUserInput())

		rem --- Warehouse has changed, so see if they want to recalculate the default manual completion date.
		if cvs(callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID"),2)<>"" and callpoint!.getColumnData("SFE_WOMASTR.SCHED_FLAG")="M" then
			msg_id$="SF_RECALC_COMP_DATE"
			gosub disp_message
			if msg_opt$="Y" then
 				ivm_itemwhse=fnget_dev("IVM_ITEMWHSE")
				dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")
				read record (ivm_itemwhse,key=firm_id$+warehouse_id$+callpoint!.getColumnData("SFE_WOMASTR.ITEM_ID"),dom=*next)ivm_itemwhse$
				new_date$=""
				leadtime=ivm_itemwhse.lead_time
				call stbl("+DIR_PGM")+"adc_daydates.aon",stbl("+SYSTEM_DATE"),new_date$,leadtime
				if new_date$<>"N"
					callpoint!.setColumnData("SFE_WOMASTR.ESTCMP_DATE",new_date$,1)
				endif
			endif
		endif
	endif

[[SFE_WOMASTR.WO_NO.AVAL]]
rem --- put WO number and loc in DevObject

	callpoint!.setDevObject("wo_no",callpoint!.getUserInput())
	callpoint!.setDevObject("wo_loc",callpoint!.getColumnData("SFE_WOMASTR.WO_LOCATION"))

[[SFE_WOMASTR.WO_STATUS.AVAL]]
rem --- Only allow changes to status if P or Q

	status$=callpoint!.getUserInput()
	old_status$=callpoint!.getColumnData("SFE_WOMASTR.WO_STATUS")
	if pos(status$="PQ")=0
		callpoint!.setUserInput(old_status$)
	endif
	callpoint!.setDevObject("wo_status",callpoint!.getUserInput())

[[SFE_WOMASTR.WO_TYPE.AVAL]]
rem --- Don't allow inactive code
	sfcWOType_dev=fnget_dev("SFC_WOTYPECD")
	dim sfcWOType$:fnget_tpl$("SFC_WOTYPECD")
	wo_type$=callpoint!.getUserInput()
	read record (sfcWOType_dev,key=firm_id$+"A"+wo_type$,dom=*next)sfcWOType$
	if sfcWOType.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(sfcWOType.wo_type$,3)
		msg_tokens$[2]=cvs(sfcWOType.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Only allow change to Type if it's the same Category

	typecode_dev=fnget_dev("SFC_WOTYPECD")
	dim typecode$:fnget_tpl$("SFC_WOTYPECD")

	cat$=callpoint!.getColumnData("SFE_WOMASTR.WO_CATEGORY")
	new_type$=callpoint!.getUserInput()
	readrecord(typecode_dev,key=firm_id$+"A"+new_type$)typecode$
	if callpoint!.getDevObject("new_rec")="N"
		if cvs(cat$,3)<>"" and cat$<>typecode.wo_category$
			msg_id$="WO_NO_CAT_CHG"
			gosub disp_message
			callpoint!.setStatus("ABORT")
			break
		endif
	endif

rem --- If new order, check for type of Work Order and disable Item or Descriptions

	if callpoint!.getDevObject("new_rec")="Y"
		callpoint!.setColumnData("SFE_WOMASTR.WO_CATEGORY",typecode.wo_category$,1)
		callpoint!.setDevObject("wo_category",typecode.wo_category$)
	endif

	if typecode.wo_category$<>"I"
		callpoint!.setColumnData("SFE_WOMASTR.ITEM_ID","",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",0)
		callpoint!.setColumnData("SFE_WOMASTR.LOTSER_FLAG","N",1)
		callpoint!.setOptionEnabled("LSNO",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_01",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_02",1)
	else
		if callpoint!.getDevObject("new_rec")="Y"
			callpoint!.setColumnEnabled("SFE_WOMASTR.ITEM_ID",1)
		endif
		callpoint!.setColumnData("SFE_WOMASTR.DESCRIPTION_01","",1)
		callpoint!.setColumnData("SFE_WOMASTR.DESCRIPTION_02","",1)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_01",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DESCRIPTION_02",0)
	endif

rem --- Enable Copy Button

	if typecode.wo_category$="N" and num(callpoint!.getColumnData("SFE_WOMASTR.SCH_PROD_QTY"))>0 and callpoint!.isEditMode() then
		callpoint!.setOptionEnabled("COPY",1)
	else
		callpoint!.setOptionEnabled("COPY",0)
	endif

rem --- Disable Drawing and Revision Number if Recurring type

	if typecode.wo_category$="R"
		callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_NO",0)
		callpoint!.setColumnEnabled("SFE_WOMASTR.DRAWING_REV",0)
	endif

[[SFE_WOMASTR.<CUSTOM>]]
rem =========================================================
add_wo_comment: rem --- Add work order comment
rem 	wo_comment$		input
rem =========================================================

	customer_id$=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
	order_no$=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
	wo_no$=callpoint!.getColumnData("SFE_WOMASTR.WO_NO")
	soCreateWO!=new SalesOrderCreateWO(firm_id$,customer_id$,order_no$)
	soCreateWO!.addWOCmnt(wo_no$,wo_comment$)
	soCreateWO!.close()
	soCreateWO!=null()

	return

rem =========================================================
refreshDisplayFields: rem --- Refresh <<DISPLAY>> fields and static label for non-stock item description
rem =========================================================
	nonStock_desc!=callpoint!.getDevObject("nonStock_desc")
	ope11_dev=fnget_dev("OPE_ORDDET")
	dim ope11a$:fnget_tpl$("OPE_ORDDET")
	call stbl("+DIR_SYP")+"bac_key_template.bbj","OPT_INVDET","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim optInvDet_key$:key_tpl$
	optInvDet_key.firm_id$=firm_id$
	optInvDet_key.ar_type$=""
	optInvDet_key.customer_id$=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
	optInvDet_key.order_no$=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
	optInvDet_key.ar_inv_no$=""
	optInvDet_key.internal_seq_no$=callpoint!.getColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF")
	readrecord(ope11_dev,key=optInvDet_key$,dom=*next)ope11a$

	rem --- Refresh static label for non-stock item description
	gosub refreshNonStockDescription

	return

rem =========================================================
refreshNonStockDescription: rem --- Refresh static label for non-stock item description
rem 	ope11a$		input
rem =========================================================
	opc_linecode=fnget_dev("OPC_LINECODE")
	dim opc_linecode$:fnget_tpl$("OPC_LINECODE")
	readrecord(opc_linecode,key=firm_id$+ope11a.line_code$,dom=*next)opc_linecode$
	nonStock_desc!=callpoint!.getDevObject("nonStock_desc")
	if opc_linecode.line_type$="N" then
		rem --- Set and show static label for non-stock item description
		nonStock_desc!.setText(ope11a.order_memo$)
		nonStock_desc!.setVisible(1)

		callpoint!.setColumnData("<<DISPLAY>>.ITEM_ID","",1)
	else
		rem --- Hide static label for non-stock item description
		nonStock_desc!.setText("")
		nonStock_desc!.setVisible(0)

		callpoint!.setColumnData("<<DISPLAY>>.ITEM_ID",ope11a.item_id$,1)
	endif
	callpoint!.setColumnData("<<DISPLAY>>.LINE_NO",ope11a.line_no$,1)

	return

rem =========================================================
checkWOtoSOlink: rem --- Warn if changing link info for a linked WO
rem 	sls_ord_seq_ref$	input
rem 	linkStatus$		output
rem =========================================================
	linkStatus$="OK"
	currentSlsOrdSeqRef$=callpoint!.getColumnData("SFE_WOMASTR.SLS_ORD_SEQ_REF")
	if num(currentSlsOrdSeqRef$)>0 and currentSlsOrdSeqRef$<>sls_ord_seq_ref$ then
		msg_id$="SF_CHANGE_SO_LINK"
		dim msg_tokens$[2]
		msg_tokens$[1]=callpoint!.getColumnData("SFE_WOMASTR.ORDER_NO")
		msg_tokens$[2]=callpoint!.getColumnData("SFE_WOMASTR.CUSTOMER_ID")
		gosub disp_message
		if msg_opt$<>"Y" then
			linkStatus$="BAD"
		else
			rem --- Add WO comment with the changed SO link info plus audit info.
			wo_comment$ =Translate!.getTranslation("AON_SALES_ORDER")+" "+Translate!.getTranslation("AON_DETAIL")+" "
			wo_comment$ =wo_comment$+Translate!.getTranslation("AON_LINE")+" "+Translate!.getTranslation("AON_LINK_CHANGED_FROM")+" "
			wo_comment$ =wo_comment$+currentSlsOrdSeqRef$+" " +Translate!.getTranslation("AON_TO")+" " +sls_ord_seq_ref$
			gosub add_wo_comment
		endif
	endif

	return

#include [+ADDON_LIB]std_missing_params.aon



