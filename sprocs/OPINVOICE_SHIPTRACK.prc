rem ----------------------------------------------------------------------------
rem --- OP Invoice Printing
rem --- Program: OPINVOICE_SHIPTRACK.prc
rem --- Description: Stored Procedure to create Shipment Tracking detail for a jasper-based OP invoice 
rem 
rem --- AddonSoftware
rem --- Copyright BASIS International Ltd.  All Rights Reserved.

rem --- opc_invoice.aon is used to print (1) On-Demand (from Invoice Entry--
rem --- ope_invhdr.cdf), (2) Batch (from menu: OP Invoice Printing--
rem --- opr_invoice.aon), and (3) Historical Invoices (from Invoice History
rem --- Inquiry--opt_invhdr.cdf).

rem --- opc_invoice.aon uses four sprocs and four .jaspers to generate invoicest:
rem ---    - OPINVOICE_HDR.prc / OPInvoiceHdr.jasper
rem ---    - OPINVOICE_DET.prc / OPInvoiceDet.jasper
rem ---    - OPINVOICE_DET_LOTSER.prc / OPInvoiceDet-LotSer.jasper
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
    ship_seq_no$ =           sp!.getParameter("SHIP_SEQ_NO")
	barista_wd$ =            sp!.getParameter("BARISTA_WD")

	chdir barista_wd$

rem --- Get Barista System Program directory

	sypdir$=""
	sypdir$=stbl("+DIR_SYP",err=*next)
	
	pgmdir$=stbl("+DIR_PGM",err=*next)

rem --- create the in memory recordset for return

	dataTemplate$ = ""
	dataTemplate$ = dataTemplate$ + "tracking_no:c(1*), carrier_code:c(1*), scac_code:c(1*)" 
	
	rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- Open Files    
rem --- Note 'files' and 'channels[]' are used in close loop, so don't re-use

    files=3,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]    

    files$[1]="opt_shiptrack",     ids$[1]="OPT_SHIPTRACK"
    files$[2]="arc_carriercode",   ids$[2]="ARC_CARRIERCODE"
    files$[3]="arc_scaccode",      ids$[3]="ARC_SCACCODE"
	
	call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status

    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif
    
	files_opened = files; rem used in loop to close files

    optShipTrack_dev = channels[1]
    arcCarrierCode_dev = channels[2]
    arcScacCode_dev = channels[3]
    
    dim optShipTrack$:templates$[1]
    dim arcCarrierCode$:templates$[2]
    dim arcScacCode$:templates$[3]

rem --- Get shipment tracking information for this order

	sqlprep$=""
	sqlprep$=sqlprep$+"SELECT TRACKING_NO, CARRIER_CODE, SCAC_CODE, VOID_FLAG"
	sqlprep$=sqlprep$+" FROM opt_shiptrack"
	sqlprep$=sqlprep$+" WHERE firm_id="       +"'"+ firm_id$+"'"
	sqlprep$=sqlprep$+"   AND ar_type="       +"'"+ ar_type$+"'"
	sqlprep$=sqlprep$+"   AND customer_id= ?"
	sqlprep$=sqlprep$+"   AND order_no="      +"'"+ order_no$+"'"
    sqlprep$=sqlprep$+"   AND ship_seq_no="   +"'"+ ship_seq_no$+"'"

	sql_chan=sqlunt
	sqlopen(sql_chan,mode="PROCEDURE",err=*next)stbl("+DBNAME")
	sqlprep(sql_chan)sqlprep$
	dim read_tpl$:sqltmpl(sql_chan)
	sqlexec(sql_chan)customer_id$

rem --- Process through SQL results 

    trackingNos!=new java.util.HashMap()
	while 1
		read_tpl$ = sqlfetch(sql_chan,end=*break)
		
        if read_tpl.void_flag$="Y" then
            trackingNos!.remove(read_tpl.tracking_no$)
        else
            redim arcCarrierCode$
            carrier_code$=cvs(read_tpl.carrier_code$,2)
            readrecord(arcCarrierCode_dev,key=firm_id$+read_tpl.carrier_code$,dom=*next)arcCarrierCode$
            if cvs(arcCarrierCode.carrier_name$,2)<>"" then
                carrier_code$=carrier_code$+" - "+cvs(arcCarrierCode.carrier_name$,2)
            endif

            redim arcScacCode$
            scac_code$=cvs(read_tpl.scac_code$,2)         
            readrecord(arcScacCode_dev,key=firm_id$+read_tpl.scac_code$,dom=*next)arcScacCode$
            if cvs(arcScacCode.carrier_name$,2)<>"" then
                scac_code$=scac_code$+" - "+cvs(arcScacCode.carrier_name$,2)
            endif

            trackingVec!=BBjAPI().makeVector()
            trackingVec!.addItem(carrier_code$)
            trackingVec!.addItem(scac_code$)
            trackingNos!.put(read_tpl.tracking_no$,trackingVec!)
        endif

	wend

    if trackingNos!.size()>0 then
        trackingIter!=trackingNos!.keySet().iterator()
        while trackingIter!.hasNext()
            tracking_no$=trackingIter!.next()
            trackingVec!=trackingNos!.get(tracking_no$)
            
            data! = rs!.getEmptyRecordData()
            data!.setFieldValue("TRACKING_NO", tracking_no$)
            data!.setFieldValue("CARRIER_CODE", trackingVec!.getItem(0))
            data!.setFieldValue("SCAC_CODE", trackingVec!.getItem(1))
            rs!.insert(data!)
        wend
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
