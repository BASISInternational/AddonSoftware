[[APM_VENDREPL.BDEL]]
rem --- check knum3 of ivm-01; if firm/buyer/vendor key is present, disallow deletion

ivm01_dev=fnget_dev("IVM_ITEMMAST")
wky$=firm_id$+callpoint!.getColumnData("APM_VENDREPL.BUYER_CODE")+callpoint!.getColumnData("APM_VENDREPL.VENDOR_ID")
wky1$=""
read(ivm01_dev,knum="AO_BUYR_VEND_ITM",key=wky$,dom=*next)
wky1$=key(ivm01_dev,end=*next)
if pos(wky$=wky1$)=1
	msg_id$="AP_DEL_REPL"
	gosub disp_message
	callpoint!.setStatus("ABORT")
endif

[[APM_VENDREPL.BSHO]]
rem --- Open necessary channel

	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVM_ITEMMAST",open_opts$[1]="OTA"
	open_tables$[2]="APM_VENDADDR",open_opts$[2]="OTA"
	open_tables$[3]="IVC_BUYCODE",open_opts$[3]="OTA"
	gosub open_tables

rem --- Disable Buyer Code if IV not installed
	call stbl("+DIR_PGM")+"adc_application.aon","IV",info$[all]
	iv$=info$[20]
	if iv$<>"Y"
		dim dctl$[1]
		dctl$[1]="APM_VENDREPL.BUYER_CODE"
		gosub disable_ctls
	endif

[[APM_VENDREPL.BUYER_CODE.AVAL]]
rem --- Don't allow inactive code
	ivc_buycode=fnget_dev("IVC_BUYCODE")
	dim ivc_buycode$:fnget_tpl$("IVC_BUYCODE")
	buyer_code$=callpoint!.getUserInput()
	read record (ivc_buycode,key=firm_id$+"F"+buyer_code$,dom=*next)ivc_buycode$
	if ivc_buycode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivc_buycode.buyer_code$,3)
		msg_tokens$[2]=cvs(ivc_buycode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[APM_VENDREPL.PURCH_ADDR.AVAL]]
rem --- Don't allow inactive code
	apmVendAddr_dev=fnget_dev("APM_VENDADDR")
	dim apmVendAddr$:fnget_tpl$("APM_VENDADDR")
	purch_addr$=callpoint!.getUserInput()
	vendor_id$=callpoint!.getColumnData("APM_VENDREPL.VENDOR_ID")
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

[[APM_VENDREPL.<CUSTOM>]]
disable_ctls:rem --- disable selected control

    for dctl=1 to 1
        dctl$=dctl$[dctl]
        if dctl$<>""
            wctl$=str(num(callpoint!.getTableColumnAttribute(dctl$,"CTLI")):"00000")
	 wmap$=callpoint!.getAbleMap()
            wpos=pos(wctl$=wmap$,8)
            wmap$(wpos+6,1)="I"
	 callpoint!.setAbleMap(wmap$)
            callpoint!.setStatus("ABLEMAP")
        endif
    next dctl
    return

#include [+ADDON_LIB]std_missing_params.aon



