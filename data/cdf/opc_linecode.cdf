[[OPC_LINECODE.ADIS]]
rem --- Show TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		taxSvcCd$=cvs(callpoint!.getColumnData("OPC_LINECODE.TAX_SVC_CD"),2)
		if taxSvcCd$<>"" then
			salesTax!=callpoint!.getDevObject("salesTax")
			success=0
			desc$=salesTax!.getTaxSvcCdDesc(taxSvcCd$,err=*next); success=1
			if success then
				if desc$<>"" then
					rem --- Good code entered
					tax_svc_cd_desc!.setText(desc$)
				else
					rem --- Bad code entered
					msg_id$="OP_BAD_TAXSVC_CD"
					dim msg_tokens$[1]
					msg_tokens$[1]=taxSvcCd$
					gosub disp_message

					tax_svc_cd_desc!.setText("?????")
				endif
			else
				rem --- AvaTax call error
				tax_svc_cd_desc!.setText("?????")
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[OPC_LINECODE.ARAR]]
rem --- Enable-Disable all fields
	gosub disable_ctls

[[OPC_LINECODE.AREC]]
rem --- Clear TAX_SVC_CD description
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		tax_svc_cd_desc!.setText("")
	endif

[[OPC_LINECODE.AR_DIST_CODE.AVAL]]
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

rem --- Either fill or blank out 3 G/L display fields
	callpoint!.setColumnData("OPC_LINECODE.AR_DIST_CODE",ar_dist_code$)
	gosub display_gl_fields

[[OPC_LINECODE.ASHO]]
rem --- Get connection to Sales Tax Service
	callpoint!.setDevObject("salesTax",null())
	ops_params_dev=fnget_dev("OPS_PARAMS")
	dim ops_params$:fnget_tpl$("OPS_PARAMS")
	find record (ops_params_dev,key=firm_id$+"AR00",err=std_missing_params)ops_params$
	if cvs(ops_params.sls_tax_intrface$,2)<>"" then
		rem --- Get connection to Sales Tax Service
		salesTax!=new AvaTaxInterface(firm_id$)
		if salesTax!.connectClient(Form!,err=connectErr) then
			callpoint!.setDevObject("salesTax",salesTax!)
			callpoint!.setColumnEnabled("IVC_PRODCODE.TAX_SVC_CD",1)
		else
			salesTax!.close()
		endif
	endif

	break

connectErr:
	if salesTax!<>null() then salesTax!.close()

	break

[[OPC_LINECODE.BEND]]
rem --- Close connection to Sales Tax Service
	salesTax!=callpoint!.getDevObject("salesTax")
	if salesTax!<>null() then
		salesTax!.close()
	endif

[[OPC_LINECODE.BREA]]
rem --- re-enable all fields
	dim dctl$[7],dmap$[7]
	dctl$[1]="GL_REV_ACCT"
	dctl$[2]="TAXABLE_FLAG"
	dctl$[3]="DROPSHIP"
	dctl$[4]="PRODUCT_TYPE"
	dctl$[5]="AR_DIST_CODE"
	dctl$[6]="PROD_TYPE_PR"
	dctl$[7]="MESSAGE_TYPE"
	gosub disable_ctls

[[OPC_LINECODE.BSHO]]
rem --- Inits
	use ::ado_util.src::util
	use ::opo_AvaTaxInterface.aon::AvaTaxInterface

rem --- Open/Lock files
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARC_DISTCODE",open_opts$[1]="OTA"
	open_tables$[2]="OPS_PARAMS",open_opts$[2]="OTA"
	open_tables$[3]="IVC_PRODCODE",open_opts$[3]="OTA"
	gosub open_tables
	arc_dist_dev=num(open_chans$[1]),arc_dist_tpl$=open_tpls$[1]

rem --- setup for G/L Parameter
	call stbl("+DIR_PGM")+"adc_application.aon","OP",info$[all]
	dim user_tpl$:"gl:c(1),dist_dev:n(4),dist_tpl:c(500)"
	user_tpl.gl$=info$[9]
	user_tpl.dist_dev=arc_dist_dev
	user_tpl.dist_tpl$=arc_dist_tpl$

rem --- Add static label for displaying TAX_SVC_CD description
	tax_svc_cd!=fnget_control!("OPC_LINECODE.TAX_SVC_CD")
	tax_svc_cd_x=tax_svc_cd!.getX()
	tax_svc_cd_y=tax_svc_cd!.getY()
	tax_svc_cd_height=tax_svc_cd!.getHeight()
	tax_svc_cd_width=tax_svc_cd!.getWidth()
	code_desc!=fnget_control!("OPC_LINECODE.CODE_DESC")
	code_desc_width=code_desc!.getWidth()
	nxt_ctlID=util.getNextControlID()
	tax_svc_cd_desc!=Form!.addStaticText(nxt_ctlID,tax_svc_cd_x+tax_svc_cd_width+5,tax_svc_cd_y+3,int(code_desc_width*1.5),tax_svc_cd_height,"")
	callpoint!.setDevObject("tax_svc_cd_desc",tax_svc_cd_desc!)

[[OPC_LINECODE.DROPSHIP.AVAL]]
rem --- Maybe disable Distribution Code
	callpoint!.setColumnData("OPC_LINECODE.DROPSHIP", callpoint!.getUserInput())
	gosub disable_ctls

[[OPC_LINECODE.GL_REV_ACCT.AVAL]]
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*break) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE-ABORT")
   endif

[[OPC_LINECODE.LINE_TYPE.AVAL]]
rem --- Disable fields that don't apply
	callpoint!.setColumnData("OPC_LINECODE.LINE_TYPE", callpoint!.getUserInput())
	gosub disable_ctls

[[OPC_LINECODE.PRODUCT_TYPE.AVAL]]
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

[[OPC_LINECODE.PROD_TYPE_PR.AVAL]]
rem --- Maybe disable Product Type
	callpoint!.setColumnData("OPC_LINECODE.PROD_TYPE_PR", callpoint!.getUserInput())
	gosub disable_ctls

[[OPC_LINECODE.TAX_SVC_CD.AVAL]]
rem --- Validate TAX_SVC_CD
	taxSvcCd$=cvs(callpoint!.getUserInput(),2)
	priorTaxSvcCd$=cvs(callpoint!.getColumnData("OPC_LINECODE.TAX_SVC_CD"),2)
	if taxSvcCd$<>priorTaxSvcCd$ then
		tax_svc_cd_desc!=callpoint!.getDevObject("tax_svc_cd_desc")
		if taxSvcCd$<>"" then
			salesTax!=callpoint!.getDevObject("salesTax")
			success=0
			desc$=salesTax!.getTaxSvcCdDesc(taxSvcCd$,err=*next); success=1
			if success then
				if desc$<>"" then
					rem --- Good code entered
					tax_svc_cd_desc!.setText(desc$)
				else
					rem --- Bad code entered
					msg_id$="OP_BAD_TAXSVC_CD"
					dim msg_tokens$[1]
					msg_tokens$[1]=taxSvcCd$
					gosub disp_message

					callpoint!.setColumnData("OPC_LINECODE.TAX_SVC_CD",priorTaxSvcCd$,1)
					callpoint!.setStatus("ABORT")
					break
				endif
			else
				rem --- AvaTax call error
				callpoint!.setColumnData("OPC_LINECODE.TAX_SVC_CD",priorTaxSvcCd$,1)
				callpoint!.setStatus("ABORT")
				break
			endif
		else
			rem --- No code entered, so clear description.
			tax_svc_cd_desc!.setText("")
		endif
	endif

[[OPC_LINECODE.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon

#include [+ADDON_LIB]std_functions.aon

rem #include fnget_control.src
	def fnget_control!(ctl_name$)
	ctlContext=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLC"))
	ctlID=num(callpoint!.getTableColumnAttribute(ctl_name$,"CTLI"))
	get_control!=SysGUI!.getWindow(ctlContext).getControl(ctlID)
	return get_control!
	fnend
rem #endinclude fnget_control.src

rem ========================================================
disable_ctls:rem --- Disable fields that don't apply
rem ========================================================
	dim dctl$[8],dmap$[8]
	dctl$[1]="GL_REV_ACCT"
	dctl$[2]="TAXABLE_FLAG"
	dctl$[3]="DROPSHIP"
	dctl$[4]="PRODUCT_TYPE"
	dctl$[5]="AR_DIST_CODE"
	dctl$[6]="PROD_TYPE_PR"
	dctl$[7]="MESSAGE_TYPE"
	dctl$[8]="TAX_SVC_CD"

	rem --- GL installed
	if user_tpl.gl$<>"Y"
		dmap$[1]="I"
	endif

	rem --- Line Types
	line_type$=callpoint!.getColumnData("OPC_LINECODE.LINE_TYPE")
	if line_type$ = "O"
		dmap$[3]="I"
		dmap$[5]="I"
		dmap$[7]="I"
	endif
	if line_type$="M"
		dmap$[1]="I"
		dmap$[2]="I"
		dmap$[3]="I"
		dmap$[4]="I"
		dmap$[5]="I"
		dmap$[6]="I"
		dmap$[8]="I"
	endif
	if line_type$="N"
		dmap$[1]="I"
		dmap$[7]="I"
	endif
	if line_type$="S"
		dmap$[1]="I"
		dmap$[4]="I"
		dmap$[5]="I"
		dmap$[6]="I"
		dmap$[7]="I"
		dmap$[8]="I"
	endif
	if line_type$="P"
		dmap$[1]="I"
		dmap$[7]="I"
		dmap$[8]="I"
	endif

	rem --- Dropship
	dropship$=callpoint!.getColumnData("OPC_LINECODE.DROPSHIP")
	if dropship$="Y"
		dmap$[5]=""
	endif

	rem --- Product Type Processing
	prod_type_pr$=callpoint!.getColumnData("OPC_LINECODE.PROD_TYPE_PR")
	if prod_type_pr$<>"D"
		dmap$[4]="I"
	endif

	rem --- Sales Tax Service
	if callpoint!.getDevObject("salesTax")=null() then
		dmap$[8]="I"
	endif

	rem --- disable selected controls
	for dctl=1 to 8
		dctl$=dctl$[dctl]
		wctl$=str(num(callpoint!.getTableColumnAttribute(dctl$,"CTLI")):"00000")
		wmap$=callpoint!.getAbleMap()
		wpos=pos(wctl$=wmap$,8)
		wmap$(wpos+6,1)=dmap$[dctl]
		callpoint!.setAbleMap(wmap$)
		callpoint!.setStatus("ABLEMAP")

		rem --- clear disabled fields
		if dmap$[dctl] = "I" then
			callpoint!.setColumnData("OPC_LINECODE."+dctl$,"")
		endif
	next dctl

	if cvs(callpoint!.getColumnData("OPC_LINECODE.MESSAGE_TYPE"),3)="" then callpoint!.setColumnData("OPC_LINECODE.MESSAGE_TYPE","B")

	callpoint!.setStatus("REFRESH")

	rem --- either fill or blank out 3 G/L display fields
	gosub display_gl_fields
return

rem ========================================================
display_gl_fields:rem --- fill or clear 3 G/L display fields
rem ========================================================
	if user_tpl.gl$="Y"
		dist_code$=callpoint!.getColumnData("OPC_LINECODE.AR_DIST_CODE")
		if cvs(dist_code$,2)=""
			callpoint!.setColumnData("<<DISPLAY>>.GL_COGS_ACCT","")
			callpoint!.setColumnData("<<DISPLAY>>.GL_INV_ACCT","")
			callpoint!.setColumnData("<<DISPLAY>>.GL_SLS_ACCT","")
		else
			dim dist_tpl$:user_tpl.dist_tpl$
			read record (user_tpl.dist_dev,key=firm_id$+"D"+dist_code$,dom=*next) dist_tpl$
			callpoint!.setColumnData("<<DISPLAY>>.GL_SLS_ACCT",dist_tpl.gl_sls_acct$)
			callpoint!.setColumnData("<<DISPLAY>>.GL_INV_ACCT",dist_tpl.gl_inv_acct$)
			callpoint!.setColumnData("<<DISPLAY>>.GL_COGS_ACCT",dist_tpl.gl_cogs_acct$)
		endif
		callpoint!.setStatus("REFRESH")
	endif
return



