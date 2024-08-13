[[APT_INVOICEHDR.ADIS]]
rem --- Enable/Disable View Image button
	invimage_dev=fnget_dev("APT_INVIMAGE")
	dim invimage$:fnget_tpl$("APT_INVIMAGE")
	vendor_id$ = callpoint!.getColumnData("APT_INVOICEHDR.VENDOR_ID")
	ap_inv_no$ = callpoint!.getColumnData("APT_INVOICEHDR.AP_INV_NO")

	read(invimage_dev, key=firm_id$+vendor_id$+ap_inv_no$, dom=*next)
	invimage_key$=key(invimage_dev,end=*next)
	if pos(firm_id$+vendor_id$+ap_inv_no$=invimage_key$)<>1 then
		rem --- No invoice images available
		callpoint!.setOptionEnabled("VIDI",0)
	else
		rem --- Have invoice image
		callpoint!.setOptionEnabled("VIDI",1)
	endif

[[APT_INVOICEHDR.AOPT-VIDI]]
rem --- Display invoice images
	ap_type$ = callpoint!.getColumnData("APT_INVOICEHDR.AP_TYPE")
	vendor_id$ = callpoint!.getColumnData("APT_INVOICEHDR.VENDOR_ID")
	ap_inv_no$ = callpoint!.getColumnData("APT_INVOICEHDR.AP_INV_NO")

	call stbl("+DIR_PGM")+"apc_imageviewer.aon", ap_type$, vendor_id$, ap_inv_no$, table_chans$[all], urls!

	if urls!.size()>0 then
		urlVect!=callpoint!.getDevObject("urlVect")
		for i=0 to urls!.size()-1
			thisURL$=urls!.getItem(i)
			urlVect!.add(thisURL$)
		next i
		callpoint!.setDevObject("urlVect",urlVect!)
	endif

[[APT_INVOICEHDR.ARAR]]
rem --- Initialize MAN_CK_* check boxes
	if callpoint!.getColumnData("APT_INVOICEHDR.MC_INV_FLAG")="M" then
		callpoint!.setColumnData("<<DISPLAY>>.MAN_CK_INV","Y",1)
	endif
	if callpoint!.getColumnData("APT_INVOICEHDR.MC_INV_ADJ")="A" then
		callpoint!.setColumnData("<<DISPLAY>>.MAN_CK_ADJ","Y",1)
	endif
	if callpoint!.getColumnData("APT_INVOICEHDR.MC_INV_REV")="R" then
		callpoint!.setColumnData("<<DISPLAY>>.MAN_CK_REV","Y",1)
	endif

[[APT_INVOICEHDR.AWIN]]
	use ::BBUtils.bbj::BBUtils

[[APT_INVOICEHDR.BEND]]
rem --- Remove images copied temporarily to web servier for viewing
	urlVect!=callpoint!.getDevObject("urlVect")
	if urlVect!.size()
		for wk=0 to urlVect!.size()-1
			BBUtils.deleteFromWebServer(urlVect!.get(wk))
		next wk
	endif

[[APT_INVOICEHDR.BSHO]]
rem --- Open files

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APT_INVIMAGE",open_opts$[1]="OTA"
	gosub open_tables

rem --- Init a vector to store urls for viewed images

	urlVect!=BBjAPI().makeVector()
	callpoint!.setDevObject("urlVect",urlVect!)



