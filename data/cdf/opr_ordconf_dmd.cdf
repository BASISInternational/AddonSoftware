[[OPR_ORDCONF_DMD.AREC]]
rem --- use ReportControl object to see if this customer is set up for email/fax of the invoice

	use ::ado_rptControl.src::ReportControl

	rpt_id$=pad("OPR_ORDCONF",16)

rem --- See if this document/recipient is set up in Addon Report Control

	reportControl!=new ReportControl()
	found=reportControl!.getRecipientInfo(rpt_id$,callpoint!.getColumnData("OPR_ORDCONF_DMD.CUSTOMER_ID"),"")
	
	if found and (reportControl!.getEmailYN()="Y" or reportControl!.getFaxYN()="Y")
		callpoint!.setColumnData("OPR_ORDCONF_DMD.PICK_CHECK","Y",1)
		callpoint!.setColumnEnabled("OPR_ORDCONF_DMD.PICK_CHECK",1)
	else
		callpoint!.setColumnData("OPR_ORDCONF_DMD.PICK_CHECK","N",1)
		callpoint!.setColumnEnabled("OPR_ORDCONF_DMD.PICK_CHECK",0)
	endif

	rem --- destroying here to make sure it doesn't keep opening files
	rem --- gets instantiated again in opc_orderconf since that program needs to handle both on-demand and batch
	reportControl!.destroy()
	reportControl! = null()

rem --- Pass along ORD_CONF_PRINTED value
	auto_ord_conf$=callpoint!.getDevObject("auto_ord_conf")
	callpoint!.setColumnData("OPR_ORDCONF_DMD.AUTO_ORD_CONF",auto_ord_conf$)

[[OPR_ORDCONF_DMD.BSHO]]
rem --- This form is only used for printing Order Acknowledgements
	callpoint!.setDevObject("sale_or_quote","S")



