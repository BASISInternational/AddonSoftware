[[SFR_WODETRPT.BILL_NO.BINQ]]
rem --- Bill of Materials Item/Whse Lookup
	call stbl("+DIR_SYP")+"bac_key_template.bbj","IVM_ITEMWHSE","PRIMARY",key_tpl$,rd_table_chans$[all],status$
	dim ivmItemWhse_key$:key_tpl$
	dim filter_defs$[2,2]
	filter_defs$[1,0]="IVM_ITEMWHSE.FIRM_ID"
	filter_defs$[1,1]="='"+firm_id$ +"'"
	filter_defs$[1,2]="LOCK"
	filter_defs$[2,0]="IVM_ITEMWHSE.WAREHOUSE_ID"
	filter_defs$[2,1]="='"+callpoint!.getColumnData("SFR_WODETRPT.WAREHOUSE_ID")+"'"
	filter_defs$[2,2]="LOCK"
	
	call stbl("+DIR_SYP")+"bax_query.bbj",gui_dev,form!,"BM_ITEMWHS_LK","",table_chans$[all],ivmItemWhse_key$,filter_defs$[all]

	rem --- Get which bill_no control was used
	bill_no$="SFR_WODETRPT.BILL_NO_1"
	if num(callpoint!.getControlID())<>callpoint!.getControl(bill_no$).getID() then
		bill_no$="SFR_WODETRPT.BILL_NO_2"
	endif

	rem --- Update bill_no control text if changed
	if cvs(ivmItemWhse_key$,2)<>"" and ivmItemWhse_key.item_id$<>callpoint!.getColumnData(bill_no$) then 
		callpoint!.setColumnData(bill_no$,ivmItemWhse_key.item_id$,1)
		callpoint!.setStatus("MODIFIED")
	endif

	callpoint!.setStatus("ACTIVATE-ABORT")
[[SFR_WODETRPT.BILL_NO.AVAL]]
rem --- Validate against BOM_BILLMAST

	bmm_billmast=fnget_dev("BMM_BILLMAST")
	found=0
	bill$=callpoint!.getUserInput()
	while 1
		find (bmm_billmast,key=firm_id$+bill$,dom=*break)
		found=1
		break
	wend

	if found=0 and cvs(bill$,3)<>""
		msg_id$="INPUT_ERR_DATA"
		gosub disp_message
		callpoint!.setStatus("ABORT")
	endif
[[SFR_WODETRPT.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon
[[SFR_WODETRPT.REPORT_SEQ.AVAL]]
rem ---- If By Bill and a whse hasn't been entered, default whse

whse_columndat$=callpoint!.getColumnData("SFR_WODETRPT.WAREHOUSE_ID")

if callpoint!.getUserInput()="B"
	if cvs(whse_columndat$,2)="" then 
		whse$=callpoint!.getDevObject("dflt_whse")
		callpoint!.setColumnData("SFR_WODETRPT.WAREHOUSE_ID",whse$,1)
	endif
endif
[[SFR_WODETRPT.AREC]]
rem --- Set default Warehouse

	whse$=callpoint!.getDevObject("dflt_whse")
	callpoint!.setColumnData("SFR_WODETRPT.WAREHOUSE_ID",whse$,1)

[[SFR_WODETRPT.BSHO]]
rem --- Open needed IV tables
rem --- Get default warehouse from IV params
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",open_opts$[1]="OTA"
	gosub open_tables

	ivs01_dev=num(open_chans$[1])
	dim ivs01a$:open_tpls$[1]

	read record (ivs01_dev,key=firm_id$+"IV00")ivs01a$

	callpoint!.setDevObject("multi_wh",ivs01a.multi_whse$)	
	callpoint!.setDevObject("dflt_whse",ivs01a.warehouse_id$)

rem --- Open and read shop floor param to see if BOM and/or OP are installed
rem --- Then remove Bill and/or Cust from listbutton based on installed? status
rem           (form builds list w/o regards to the params)
						
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="sfs_params",open_opts$[1]="OTA"
	gosub open_tables
	sfs01_dev=num(open_chans$[1]),sfs_params_tpl$=open_tpls$[1]
						
	dim sfs01a$:sfs_params_tpl$
		
	readrecord(sfs01_dev,key=firm_id$+"SF00",dom=std_missing_params)sfs01a$
	bm$=sfs01a.bm_interface$
	op$=sfs01a.ar_interface$
					
	rem --  Potentially remove list options based on module installed? status
						
		if op$<>"Y" or bm$<>"Y"
			listID=num(callpoint!.getTableColumnAttribute("SFR_WODETRPT.REPORT_SEQ","CTLI"))
			list!=Form!.getControl(listID)
			
			tmpVector! = list!.getAllItems()
			tmpVectSize = num(tmpVector!.size())
			indx = tmpVectSize-1
						
			rem -- Work backwards thru vector so index stays aligned with shrinking list!
			while indx >=0
				if bm$<>"Y"
					if pos("B - B"= tmpVector!.getItem(indx))
						list!.removeItemAt(indx)
					endif
				endif
				if op$<>"Y"
					if pos("C - C"= tmpVector!.getItem(indx))
						list!.removeItemAt(indx)
		   			endif
				endif
				indx=indx-1
			wend
		endif

	if bm$="Y"
		num_files=1
		dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
		open_tables$[1]="BMM_BILLMAST",open_opts$[1]="OTA"
		gosub open_tables
	endif
