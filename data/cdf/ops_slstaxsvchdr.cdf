[[OPS_SLSTAXSVCHDR.ADIS]]
rem --- Enable/disable Test Connection
	if cvs(callpoint!.getDevObject("sls_tax_intrface"),2)=cvs(callpoint!.getColumnData("OPS_SLSTAXSVCHDR.SLS_TAX_INTRFACE"),2) then
		callpoint!.setOptionEnabled("CONN",1)
	else
		callpoint!.setOptionEnabled("CONN",0)
	endif

[[OPS_SLSTAXSVCHDR.AOPT-CONN]]
rem --- Test connection to sales tax service
	encryptor!=callpoint!.getDevObject("encryptor")

	dim gridRec$:dtlg_param$[1,3]
	rowData!=cast(BBjVector,GridVect!.getItem(0))
	for i=0 to rowData!.size()-1
		gridRec$=rowData!.getItem(i)
		attr$=cvs(gridRec.svc_config_attr$,2)
		value$=encryptor!.decryptData(cvs(gridRec.svc_config_value$,3))
		switch (BBjAPI().TRUE)
			case attr$ = "server"
				server$=value$
				break
			case attr$ = "accountNumber"
				accountNumber$=value$
				break
			case attr$ = "licenseKey"
				licenseKey$=value$
				break
			case attr$ = "testMode"
				if value$="true" then
					environment! = AvaTaxEnvironment.Sandbox
				else
					environment! = AvaTaxEnvironment.Production
				endif
				break
		swend
	next
	account_license$=accountNumber$+":"+licenseKey$
	call stbl("+DIR_SYP")+"bax_version.bbj",barVersion$,""

	rem --- Test connect to sales tax service
	salesTax!=new AvaTaxInterface(firm_id$)
	client! = new AvaTaxClient("AddonSoftware", barVersion$, server$, environment!).withSecurity(Base64.getEncoder().encode(account_license$))
	salesTax!.busyImageStart(Form!)
	ping! = client!.ping(err=pingErr)
	salesTax!.busyImageStop()
	salesTax!.close()
	if(ping!.getAuthenticated()) then
		msg_id$="WEB_SERVICE_CONN_OK"
		dim msg_tokens$[1]
		slsTaxIntrface!=callpoint!.getControl("OPS_SLSTAXSVCHDR.SLS_TAX_INTRFACE")
		msg_tokens$[1]=slsTaxIntrface!.getItemAt(slsTaxIntrface!.getSelectedIndex())
		gosub disp_message
	else
		msg_id$="WEB_SERVICE_CONN_NOK"
		dim msg_tokens$[2]
		slsTaxIntrface!=callpoint!.getControl("OPS_SLSTAXSVCHDR.SLS_TAX_INTRFACE")
		msg_tokens$[1]=slsTaxIntrface!.getItemAt(slsTaxIntrface!.getSelectedIndex())
		gosub disp_message

		callpoint!.setStatus("ABORT")
		break
	endif

	break

pingErr: rem --- Error during ping() test

	rd_err_text$="", err_num=err
	if tcb(2)=0 and tcb(5) then rd_err_text$=pgm(tcb(5),tcb(13),err=*next)
	if err_num=252 then
		E!=BBjAPI().getLastBBjException()
		rd_err_text$=rd_err_text$+$0A$+E!.getClass().getName()
		if E!.getMessage()<>null() then rd_err_text$=rd_err_text$+": "+E!.getMessage()
	endif

	msg_id$="AD_CHK_CONNECT"
	dim msg_tokens$[1]
	msg_tokens$[1]="["+pgm(-2)+"] "+str(tcb(5))+": "+$0A$+cvs(rd_err_text$,3)+" "+str(err_num)
	gosub disp_message

	salesTax!.busyImageStop()
	salesTax!.close()
	callpoint!.setStatus("ABORT")
	break

[[OPS_SLSTAXSVCHDR.APFE]]
rem --- Enable/disable Test Connection
	if cvs(callpoint!.getDevObject("sls_tax_intrface"),2)=cvs(callpoint!.getColumnData("OPS_SLSTAXSVCHDR.SLS_TAX_INTRFACE"),2) then
		callpoint!.setOptionEnabled("CONN",1)
	else
		callpoint!.setOptionEnabled("CONN",0)
	endif

[[OPS_SLSTAXSVCHDR.AREC]]
rem --- Disable Test Connection
	callpoint!.setOptionEnabled("CONN",0)

[[OPS_SLSTAXSVCHDR.ARNF]]
rem --- Initialize new records using the ZZ records
	ops_slstaxsvchdr_dev = fnget_dev("OPS_SLSTAXSVCHDR")
	dim ops_slstaxsvchdr$:fnget_tpl$("OPS_SLSTAXSVCHDR")
	ops_slstaxsvcdet_dev = fnget_dev("OPS_SLSTAXSVCDET")
	dim ops_slstaxsvcdet$:fnget_tpl$("OPS_SLSTAXSVCDET")

	rem --- Initialize ops_slstaxsvchdr record
	sls_tax_intrface$=callpoint!.getColumnData("OPS_SLSTAXSVCHDR.SLS_TAX_INTRFACE")
	readrecord(ops_slstaxsvchdr_dev,key="ZZ"+sls_tax_intrface$,dom=*next)ops_slstaxsvchdr$
	ops_slstaxsvchdr.firm_id$=firm_id$
	writerecord(ops_slstaxsvchdr_dev)ops_slstaxsvchdr$

	rem --- Initialize ops_slstaxsvcdet records
	read(ops_slstaxsvcdet_dev,key="ZZ"+sls_tax_intrface$,dom=*next)
	while 1
		nextDetKey$=key(ops_slstaxsvcdet_dev,end=*break)
		if pos("ZZ"+sls_tax_intrface$=nextDetKey$)<>1 then break
		readrecord(ops_slstaxsvcdet_dev)ops_slstaxsvcdet$
		ops_slstaxsvcdet.firm_id$=firm_id$
		writerecord(ops_slstaxsvcdet_dev)ops_slstaxsvcdet$
		read(ops_slstaxsvcdet_dev,key=nextDetKey$,dom=*next)
	wend

	rem --- Load new records into the form
	callpoint!.setStatus("RECORD:["+firm_id$+sls_tax_intrface$+"]")

[[OPS_SLSTAXSVCHDR.ASVA]]
rem --- Enable Test Connection
	if cvs(callpoint!.getDevObject("sls_tax_intrface"),2)=cvs(callpoint!.getColumnData("OPS_SLSTAXSVCHDR.SLS_TAX_INTRFACE"),2) then
		callpoint!.setOptionEnabled("CONN",1)
	endif

[[OPS_SLSTAXSVCHDR.BPFX]]
rem --- Disable Test Connection
	callpoint!.setOptionEnabled("CONN",0)

[[OPS_SLSTAXSVCHDR.BSHO]]
rem  --- Use statements
	use ::opo_AvaTaxInterface.aon::AvaTaxInterface
	use ::sys/prog/bao_encryptor.bbj::Encryptor

	use java.math.BigDecimal
	use java.util.Base64

	use net.avalara.avatax.rest.client.AvaTaxClient  
	use net.avalara.avatax.rest.client.enums.AvaTaxEnvironment 
	use net.avalara.avatax.rest.client.models.PingResultModel 

rem --- Get an Encryptor
	encryptor! = new Encryptor()
	encryptor!.setConfiguration("SLSTAXSVC_AUTH")
	callpoint!.setDevObject("encryptor",encryptor!)

rem --- Open/Lock files
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ARS_PARAMS",open_opts$[1]="OTA"
	gosub open_tables
	arsParams_dev=num(open_chans$[1])
	dim arsParams$:open_tpls$[1]

rem --- Retrieve AR parameter data
	readrecord(arsParams_dev,key=firm_id$+"AR00",dom=std_missing_params)arsParams$
	callpoint!.setDevObject("sls_tax_intrface",arsParams.sls_tax_intrface$)

[[OPS_SLSTAXSVCHDR.WAIT_TIME.AVAL]]
rem --- Verify wait_time is greater than zero
	wait_time=num(callpoint!.getUserInput())
	if wait_time<=0 then
		msg_id$="OP_MIN_WAIT_TIME"
		gosub disp_message

		callpoint!.setStatus("ABORT")
		break
	endif

[[OPS_SLSTAXSVCHDR.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



