[[OPR_HIST_INV.AREC]]
rem --- use ReportControl object to see if this customer is set up for email/fax of the historical invoice

	use ::ado_rptControl.src::ReportControl

	rpt_id$=pad("OPR_INVOICE",16);rem use OPR_INVOICE for regular (batch) invoices, on-demand, and historical, so customers don't have to be set up multiple times

rem --- See if this document/recipient is set up in Addon Report Control

	reportControl!=new ReportControl()
	found=reportControl!.getRecipientInfo(rpt_id$,callpoint!.getColumnData("OPR_HIST_INV.CUSTOMER_ID"),"")
	
	if found and (reportControl!.getEmailYN()="Y" or reportControl!.getFaxYN()="Y")
		callpoint!.setColumnEnabled("OPR_HIST_INV.PICK_CHECK",1)
	else
		callpoint!.setColumnEnabled("OPR_HIST_INV.PICK_CHECK",0)
	endif

	rem --- destroying here to make sure it doesn't keep opening files
	rem --- gets instantiated again in opc_invoice since that program needs to handle both on-demand and batch
	reportControl!.destroy()
	reportControl! = null()
	



