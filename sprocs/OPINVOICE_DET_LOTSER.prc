rem ----------------------------------------------------------------------------
rem --- OP Invoice Printing
rem --- Program: OPINVOICE_DET_LOTSER.prc
rem --- Description: Stored Procedure to create Lot/Serial detail for a jasper-based OP invoice 
rem 
rem --- AddonSoftware
rem --- Copyright BASIS International Ltd.  All Rights Reserved.

rem --- opc_invoice.aon is used to print (1) On-Demand (from Invoice Entry--
rem --- ope_invhdr.cdf), (2) Batch (from menu: OP Invoice Printing--
rem --- opr_invoice.aon), and (3) Historical Invoices (from Invoice History
rem --- Inquiry--opt_invhdr.cdf).

rem --- opc_invoice.aon uses five sprocs and five .jaspers to generate invoices:
rem ---    - OPINVOICE_HDR.prc / OPInvoiceHdr.jasper
rem ---    - OPINVOICE_DET.prc / OPInvoiceDet.jasper
rem ---    - OPINVOICE_DET_LOTSER.prc / OPInvoiceDet-LotSer.jasper
rem ---    - OPINVOICE_DET_KITCOMP.prc / OPInvoiceDet-KitComp.jasper <=== new for v24 Kitting feature
rem ---    - OPINVOICE_SHIPTRACK.prc / OPInvoiceShipTrack.jasper

rem ----------------------------------------------------------------------------

	seterr sproc_error

rem --- Use statements and Declares

	declare BBjStoredProcedureData sp!
	declare BBjRecordSet rs!
	declare BBjRecordData data!

	use ::ado_func.src::func

rem --- Get the infomation object for the Stored Procedure

	sp! = BBjAPI().getFileSystem().getStoredProcedureData()


rem --- Get 'IN' SPROC parameters 
	firm_id$ =               sp!.getParameter("FIRM_ID")
	ar_type$ =               sp!.getParameter("AR_TYPE")
	customer_id$ =           sp!.getParameter("CUSTOMER_ID")
	order_no$ =              sp!.getParameter("ORDER_NO")
    ar_inv_no$ =             sp!.getParameter("AR_INV_NO")
	ope11_internal_seq_no$ = sp!.getParameter("INTERNAL_SEQ_NO")
	ope11_qty_shipped =  num(sp!.getParameter("OPE11_QTY_SHIPPED")); rem To conditionally print writein lines for missing Lot/Serial shipped qtys
	qty_mask$ =              sp!.getParameter("QTY_MASK")
	lotser_flag$ =           sp!.getParameter("LOTSER_FLAG")
	barista_wd$ =            sp!.getParameter("BARISTA_WD")
    report_type$ =           sp!.getParameter("REPORT_TYPE")

	chdir barista_wd$

rem --- Get Barista System Program directory

	sypdir$=""
	sypdir$=stbl("+DIR_SYP",err=*next)

	pgmdir$=stbl("+DIR_PGM",err=*next)

rem --- create the in memory recordset for return

	dataTemplate$ = ""
	dataTemplate$ = dataTemplate$ + "lotser_no:c(1*), qty_shipped_raw:c(1*)"

	rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- Initializationas

	total_lotser_qty_shipped = 0

    rem --- Report types
    on_demand$="1"
    batch_inv$="2"
    historical$="3"

rem --- Open Files    
rem --- Note 'files' and 'channels[]' are used in close loop, so don't re-use

    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]

    files$[1]="opt-21",      ids$[1]="OPE_ORDLSDET"

	call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status

    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")
        throw "File open error.",1001
    endif

	files_opened = files; rem used in loop to close files

    ope21_dev = channels[1]

    dim ope21a$:templates$[1]

rem --- Get any associated Lots/SerialNumbers

    if report_type$=historical$ then
        trans_status$="U"
    else
        trans_status$="E"
    endif

	sqlprep$=""
	sqlprep$=sqlprep$+"SELECT LOTSER_NO, QTY_SHIPPED"
	sqlprep$=sqlprep$+" FROM ope_ordlsdet"
	sqlprep$=sqlprep$+" WHERE firm_id="       +"'"+ firm_id$+"'"
    sqlprep$=sqlprep$+"   AND trans_status="  +"'"+ trans_status$+"'"
	sqlprep$=sqlprep$+"   AND ar_type="       +"'"+ ar_type$+"'"
	sqlprep$=sqlprep$+"   AND customer_id= ?"
	sqlprep$=sqlprep$+"   AND order_no="      +"'"+ order_no$+"'"
    sqlprep$=sqlprep$+"   AND ar_inv_no="     +"'"+ ar_inv_no$+"'"
	sqlprep$=sqlprep$+"   AND orddet_seq_ref="+"'"+ ope11_internal_seq_no$+"'"

	sql_chan=sqlunt
	sqlopen(sql_chan,mode="PROCEDURE",err=*next)stbl("+DBNAME")
	sqlprep(sql_chan)sqlprep$
	dim read_tpl$:sqltmpl(sql_chan)
	sqlexec(sql_chan)customer_id$

rem --- Process through SQL results 

	while 1

		read_tpl$ = sqlfetch(sql_chan,end=*break)

		data! = rs!.getEmptyRecordData()

		ls_qty_shipped = num (read_tpl.qty_shipped$)

		data!.setFieldValue("LOTSER_NO", read_tpl.lotser_no$)
		data!.setFieldValue("QTY_SHIPPED_RAW", str(ls_qty_shipped))

		rs!.insert(data!)

		total_lotser_qty_shipped = total_lotser_qty_shipped + ls_qty_shipped
	wend

	rem --- Compare LS shipped qty with Item's Shipped Qty
	rem --- If they do not match, send underscores to 
	rem --- prompt for L/S entry/write-in on the invoice.

	if total_lotser_qty_shipped <> ope11_qty_shipped

		for y=1 to max(abs(ope11_qty_shipped - total_lotser_qty_shipped),1)
			data! = rs!.getEmptyRecordData()

			data!.setFieldValue("LOTSER_NO", FILL(20,"_"))
			data!.setFieldValue("QTY_SHIPPED_RAW", "0")

			rs!.insert(data!)

			if lotser_flag$="L" then break
		next y

	endif

rem --- Tell the stored procedure to return the result set.
	sp!.setRecordSet(rs!)

	goto std_exit


sproc_error:rem --- SPROC error trap/handler
    rd_err_text$="", err_num=err
    if tcb(2)=0 and tcb(5) then rd_err_text$=pgm(tcb(5),tcb(13),err=*next)
    x$=stbl("+THROWN_ERR","TRUE")
    throw "["+pgm(-2)+"] "+str(tcb(5))+": "+rd_err_text$,err_num

std_exit:

	rem --- Close files
		x = files_opened
		while x>=1
			close (channels[x],err=*next)
			x=x-1
		wend

    end