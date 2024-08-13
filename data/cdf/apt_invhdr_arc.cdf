[[APT_INVHDR_ARC.ADIS]]
rem --- Disable View Images option if there are no images for this invoice
	scan_docs_to$=callpoint!.getDevObject("scan_docs_to")
 	if pos(scan_docs_to$="GD BDA",3)=0 then
		callpoint!.setOptionEnabled("VIDI",0)
	else
		aptInvImage_dev=fnget_dev("APT_INVIMAGE")
		dim aptInvImage$:fnget_tpl$("APT_INVIMAGE")
		aptInvImage_trip$=firm_id$+callpoint!.getColumnData("APT_INVHDR_ARC.VENDOR_ID")+callpoint!.getColumnData("APT_INVHDR_ARC.AP_INV_NO")
    		read(aptInvImage_dev, key=aptInvImage_trip$, dom=*next)
		aptInvImage_key$=key(aptInvImage_dev,end=*next)
		if pos(aptInvImage_trip$=aptInvImage_key$)<>1 then
			callpoint!.setOptionEnabled("VIDI",0)
		else
			callpoint!.setOptionEnabled("VIDI",1)
		endif
	endif

rem --- Enable See Adjustments option if this invoice has adjustments
	thisKey$=callpoint!.getRecordKey()
	nextSeq$=str(num(callpoint!.getColumnData("APT_INVHDR_ARC.GENERIC_SEQ2"))+1:"00")
	aptInvHdrAct_dev2=fnget_dev("@APT_INVHDR_ARC")
	foundAdjustment=0
	find(aptInvHdrAct_dev2,key=thisKey$(1,len(thisKey$)-2)+nextSeq$,dom=*next); foundAdjustment=1
	if foundAdjustment then
		callpoint!.setOptionEnabled("ADJT",1)
	else
		callpoint!.setOptionEnabled("ADJT",0)
	endif

rem --- Show if this is an Adjustment
	adjustmentText!=callpoint!.getDevObject("adjustmentText")
	if num(callpoint!.getColumnData("APT_INVHDR_ARC.GENERIC_SEQ2"))>1 then
		adjustmentText!.setVisible(1)
	else
		adjustmentText!.setVisible(0)
	endif

[[APT_INVHDR_ARC.AFMC]]
rem --- Add static text for Adjustments
	ap_inv_no!=callpoint!.getControl("APT_INVHDR_ARC.AP_INV_NO")
	ap_inv_no_x=ap_inv_no!.getX()
	ap_inv_no_y=ap_inv_no!.getY()
	ap_inv_no_height=ap_inv_no!.getHeight()
	ap_inv_no_width=ap_inv_no!.getWidth()
	label_width=150

	nxt_ctlID=util.getNextControlID()
	adjustmentText!=Form!.addStaticText(nxt_ctlID,ap_inv_no_x+ap_inv_no_width+8,ap_inv_no_y+ap_inv_no_height+8,label_width,2*ap_inv_no_height,"")
	adjustmentText!.setText(Translate!.getTranslation("AON_ADJUSTMENTS"))
	adjustmentText!.setForeColor(BBjColor.RED)
	adjustmentText!.setVisible(0)

	adjustmentFont!=adjustmentText!.getFont()
	largeFont!=SysGUI!.makeFont(adjustmentFont!.getName(),2*adjustmentFont!.getSize(),1)
	adjustmentText!.setFont(largeFont!)
	callpoint!.setDevObject("adjustmentText",adjustmentText!)

[[APT_INVHDR_ARC.AOPT-ADJT]]
rem --- Show Adjustments in next record
	thisKey$=callpoint!.getRecordKey()
	nextSeq$=str(num(callpoint!.getColumnData("APT_INVHDR_ARC.GENERIC_SEQ2"))+1:"00")
	callpoint!.setStatus("RECORD:["+thiskey$(1,len(thisKey$)-2)+nextSeq$+"]")

[[APT_INVHDR_ARC.AOPT-VIDI]]
rem --- Display invoice images
	ap_type$ = callpoint!.getColumnData("APT_INVHDR_ARC.AP_TYPE")
	vendor_id$ = callpoint!.getColumnData("APT_INVHDR_ARC.VENDOR_ID")
	ap_inv_no$ = callpoint!.getColumnData("APT_INVHDR_ARC.AP_INV_NO")

	call stbl("+DIR_PGM")+"apc_imageviewer.aon", ap_type$, vendor_id$, ap_inv_no$, table_chans$[all], urls!

	if urls!.size()>0 then
		urlVect!=callpoint!.getDevObject("urlVect")
		for i=0 to urls!.size()-1
			thisURL$=urls!.getItem(i)
			urlVect!.add(thisURL$)
		next i
		callpoint!.setDevObject("urlVect",urlVect!)
	endif

[[APT_INVHDR_ARC.AP_INV_NO.AVAL]]
rem --- Show the first record for this invoice
	callpoint!.setColumnData("APT_INVHDR_ARC.GENERIC_SEQ2","01")

[[APT_INVHDR_ARC.AREC]]
rem --- Disable buttons/options for new record
	callpoint!.setOptionEnabled("ADJT",0)
	callpoint!.setOptionEnabled("VIDI",0)

rem --- Clear Adjustments text
	adjustmentText!=callpoint!.getDevObject("adjustmentText")
	adjustmentText!.setVisible(0)

[[APT_INVHDR_ARC.ASIZ]]
rem --- Resize customer vendor box (display only) to align w/Invoice Comments (memo_1024)

	cmts!=callpoint!.getControl("<<DISPLAY>>.COMMENTS")
	memo!=callpoint!.getControl("APT_INVHDR_ARC.MEMO_1024")
	cmts!.setSize(memo!.getWidth(),cmts!.getHeight())

[[APT_INVHDR_ARC.BSHO]]
rem --- Setup utility
	use ::ado_util.src::util

rem --- Open/Lock files
	files=4,begfile=1,endfile=files
	dim files$[files],options$[files],chans$[files],templates$[files]
	files$[1]="APT_INVHDR_ARC",options$[1]="OTA@"
	files$[2]="APS_PARAMS",options$[2]="OTA"
	files$[3]="APT_INVOICEHDR",options$[3]="OTA"
	files$[4]="APT_INVIMAGE",options$[4]="OTA"
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

rem --- Retrieve AP parameter data
	aps01_dev=num(chans$[2])
	dim aps01a$:templates$[2]
	aps01a_key$=firm_id$+"AP00"
	find record (aps01_dev,key=aps01a_key$,err=std_missing_params) aps01a$
	callpoint!.setDevObject("scan_docs_to",aps01a.scan_docs_to$)

rem --- Disable View Images options as needed
	scan_docs_to$=callpoint!.getDevObject("scan_docs_to")
 	if pos(scan_docs_to$="GD BDA",3)=0 then
		callpoint!.setOptionEnabled("VIDI",0)
	endif

[[APT_INVHDR_ARC.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



