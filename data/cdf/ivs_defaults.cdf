[[IVS_DEFAULTS.AR_DIST_CODE.AVAL]]
rem --- Don't allow inactive code
	arcDistCode_dev=fnget_dev("ARC_DISTCODE")
	dim arcDistCode$:fnget_tpl$("ARC_DISTCODE")
	ar_dist_code$=callpoint!.getUserInput()
	read record(arcDistCode_dev,key=firm_id$+"D"+ar_dist_code$,dom=*next)arcDistCode$
	if arcDistCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(arcDistCode.ar_dist_code$,3)
		msg_tokens$[2]=cvs(arcDistCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVS_DEFAULTS.BSHO]]
rem --- Is Accounts Receivable installed?
	call dir_pgm1$+"adc_application.aon","AR",info$[all]
	ar$=info$[20]

rem --- Open/Lock Files
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	if ar$="Y" then
		open_tables$[1]="ARS_PARAMS",open_opts$[1]="OTA"
	endif
	open_tables$[2]="IVC_PRODCODE",open_opts$[2]="OTA"
	open_tables$[3]="IVC_TYPECODE",open_opts$[3]="OTA"
	gosub open_tables
	ars01_dev=num(open_chans$[1]),ars01_tpl$=open_tpls$[1]

rem --- Check for Distribute by Item

	dim user_tpl$:"dist_by_item:c(1)"
	user_tpl.dist_by_item$="N"
	if ars01_dev<>0
		dim ars01a$:ars01_tpl$
		read record (ars01_dev,key=firm_id$+"AR00",dom=*break) ars01a$
		user_tpl.dist_by_item$=ars01a.dist_by_item$
	endif

rem --- Always set Stocking Level to "W"
	callpoint!.setColumnData("IVS_DEFAULTS.STOCK_LEVEL","W")

rem --- Enable/Disable fields

	if user_tpl.dist_by_item$="Y"
		ctl_name$="IVS_DEFAULTS.GL_COGS_ACCT"
		ctl_stat$="I"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_COGS_ADJ"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_INV_ACCT"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_INV_ADJ"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_PPV_ACCT"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_PUR_ACCT"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.AR_DIST_CODE"
		ctl_stat$=" "
		gosub disable_fields
	else
		ctl_name$="IVS_DEFAULTS.GL_COGS_ACCT"
		ctl_stat$=" "
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_COGS_ADJ"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_INV_ACCT"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_INV_ADJ"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_PPV_ACCT"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.GL_PUR_ACCT"
		gosub disable_fields
		ctl_name$="IVS_DEFAULTS.AR_DIST_CODE"
		ctl_stat$="I"
		gosub disable_fields
	endif

[[IVS_DEFAULTS.BUYER_CODE.AVAL]]
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

[[IVS_DEFAULTS.GL_COGS_ACCT.AVAL]]
gosub gl_active

[[IVS_DEFAULTS.GL_COGS_ADJ.AVAL]]
gosub gl_active

[[IVS_DEFAULTS.GL_INV_ACCT.AVAL]]
gosub gl_active

[[IVS_DEFAULTS.GL_INV_ADJ.AVAL]]
gosub gl_active

[[IVS_DEFAULTS.GL_PPV_ACCT.AVAL]]
gosub gl_active

[[IVS_DEFAULTS.GL_PUR_ACCT.AVAL]]
gosub gl_active

[[IVS_DEFAULTS.ITEM_CLASS.AVAL]]
	ivc_clascode=fnget_dev("IVC_CLASCODE")
	dim ivc_clascode$:fnget_tpl$("IVC_CLASCODE")
	item_class$=callpoint!.getUserInput()
	read record (ivc_clascode,key=firm_id$+item_class$,dom=*next)ivc_clascode$
	if ivc_clascode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivc_clascode.item_class$,3)
		msg_tokens$[2]=cvs(ivc_clascode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVS_DEFAULTS.ITEM_TYPE.AVAL]]
rem --- Don't allow inactive code
	ivcTypeCode_dev=fnget_dev("IVC_TYPECODE")
	dim ivcTypeCode$:fnget_tpl$("IVC_TYPECODE")
	type_code$=callpoint!.getUserInput()
	read record (ivcTypeCode_dev,key=firm_id$+type_code$,dom=*next)ivcTypeCode$
	if ivcTypeCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcTypeCode.item_type$,3)
		msg_tokens$[2]=cvs(ivcTypeCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVS_DEFAULTS.PRODUCT_TYPE.AVAL]]
rem --- Don't allow inactive code
	ivcProdCode_dev=fnget_dev("IVC_PRODCODE")
	dim ivcProdCode$:fnget_tpl$("IVC_PRODCODE")
	prod_code$=callpoint!.getUserInput()
	read record (ivcProdCode_dev,key=firm_id$+"A"+prod_code$,dom=*next)ivcProdCode$
	if ivcProdCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcProdCode.product_type$,3)
		msg_tokens$[2]=cvs(ivcProdCode.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVS_DEFAULTS.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon

gl_active:
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*return) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE-ABORT")
   endif
return

disable_fields:
rem --- used to disable/enable controls depending on parameter settings
rem --- send in control to toggle (format "ALIAS.CONTROL_NAME"), and D or space to disable/enable

	wctl$=str(num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI")):"00000")
	wmap$=callpoint!.getAbleMap()
	wpos=pos(wctl$=wmap$,8)
	wmap$(wpos+6,1)=ctl_stat$
	callpoint!.setAbleMap(wmap$)
	callpoint!.setStatus("ABLEMAP-REFRESH")

	return



