rem ----------------------------------------------------------------------------
rem --- OP Invoice Printing
rem --- Program: OPINVOICE_DET_KITCOMP.prc
rem --- Description: Stored Procedure to show Kit Components for a given detail line (for the jasper-based OP invoice) 
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
	firm_id$ =        sp!.getParameter("FIRM_ID")
	ar_type$ =        sp!.getParameter("AR_TYPE")
	customer_id$ =    sp!.getParameter("CUSTOMER_ID")
	order_no$ =       sp!.getParameter("ORDER_NO")
    ar_inv_no$ =      sp!.getParameter("AR_INV_NO")
	qty_mask$ =       sp!.getParameter("QTY_MASK")
	amt_mask$ =       sp!.getParameter("AMT_MASK")
	price_mask$ =     sp!.getParameter("PRICE_MASK")
    ivIMask$ =        sp!.getParameter("ITEM_MASK")
	ext_mask$ =       sp!.getParameter("EXT_MASK")
	barista_wd$ =     sp!.getParameter("BARISTA_WD")
    report_type$ =    sp!.getParameter("REPORT_TYPE")
    orddet_seq_ref$ = sp!.getParameter("INTERNAL_SEQ_NO")
    priced_kit$ =     sp!.getParameter("PRICED_KIT")
    explode_priced_kit$ = sp!.getParameter("EXPLODE_PRICED_KIT")

	chdir barista_wd$

rem --- create the in memory recordset for return
	dataTemplate$ = ""
	dataTemplate$ = dataTemplate$ + "order_qty_masked:c(1*), ship_qty_masked:c(1*), backord_qty_masked:c(1*), "
	dataTemplate$ = dataTemplate$ + "item_id:c(1*), item_desc:c(1*), um:c(1*), "
	dataTemplate$ = dataTemplate$ + "price_raw:c(1*), price_masked:c(1*), "
	dataTemplate$ = dataTemplate$ + "extended_raw:c(1*), extended_masked:c(1*), ship_qty:c(1*)"

	rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)
	
rem --- Initializationas

    rem --- Report types
    on_demand$="1"
    batch_inv$="2"
    historical$="3"
	
rem --- Open Files    
rem --- Note 'files' and 'channels[]' are used in close loop, so don't re-use

    files=2,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]    

    files$[1]="ivm-01",      ids$[1]="IVM_ITEMMAST"
    files$[2]="opt_invkitdet",      ids$[2]="OPT_INVKITDET"

	call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status

    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif
    
	files_opened = files; rem used in loop to close files

    ivm01_dev   = channels[1]
    opt_invkitdet_dev   = channels[2]
    
    dim ivm01a$:templates$[1]
    dim opt_invkitdet$:templates$[2]
	
rem --- Main

    if report_type$=historical$ then
        trans_status$="U"
    else
        trans_status$="E"
    endif
    read (opt_invkitdet_dev, key=firm_id$+trans_status$+ar_type$+customer_id$+order_no$+ar_inv_no$+orddet_seq_ref$, knum="AO_STAT_CUST_ORD", dom=*next)
	
    rem --- Kit component lines

        while 1
				
			order_qty_masked$ =   ""
			ship_qty_masked$ =    ""
			ship_qty$ =           ""
			backord_qty_masked$ = ""
			item_id$ =            ""
			item_desc$ =          ""
			um$ =                 ""
			price_raw$ =          ""
			price_masked$ =       ""
			ext_raw$ =            ""
			ext_masked$ =         ""	
			
            read record (opt_invkitdet_dev, end=*break) opt_invkitdet$

            if firm_id$     <> opt_invkitdet.firm_id$     then break
			if ar_type$     <> opt_invkitdet.ar_type$     then break
            if customer_id$ <> opt_invkitdet.customer_id$ then break
            if order_no$    <> opt_invkitdet.order_no$    then break
            if ar_inv_no$   <> opt_invkitdet.ar_inv_no$   then break
            if orddet_seq_ref$   <> opt_invkitdet.orddet_seq_ref$   then break
		
            dim ivm01a$:fattr(ivm01a$)
            item_description$ = "Item not found"
            ivm01a.item_desc$ = fnmask$(opt_invkitdet.item_id$,ivIMask$)
            find record (ivm01_dev, key=firm_id$+opt_invkitdet.item_id$, dom=*next) ivm01a$
            item_description$ = func.displayDesc(ivm01a.item_desc$)

            rem --- Item Detail

            order_qty_masked$= str(opt_invkitdet.qty_ordered/opt_invkitdet.conv_factor:qty_mask$)
			ship_qty_masked$= str(opt_invkitdet.qty_shipped/opt_invkitdet.conv_factor:qty_mask$)
			ship_qty$= str(opt_invkitdet.qty_shipped/opt_invkitdet.conv_factor)
			backord_qty_masked$= str(opt_invkitdet.qty_backord/opt_invkitdet.conv_factor:qty_mask$)

			item_desc$=cvs(fnmask$(opt_invkitdet.item_id$,ivIMask$),3)
            item_id$=cvs(fnmask$(opt_invkitdet.item_id$,ivIMask$),3)
			
            if priced_kit$<>"Y" or (priced_kit$="Y" and explode_priced_kit$<>"Y") then
    			price_raw$=   str(opt_invkitdet.unit_price*opt_invkitdet.conv_factor)
    			price_masked$=str(opt_invkitdet.unit_price*opt_invkitdet.conv_factor:price_mask$)
    
    			ext_raw$=   str(opt_invkitdet.ext_price)
    			ext_masked$=str(opt_invkitdet.ext_price:ext_mask$)
			endif
			
			um$=opt_invkitdet.um_sold$
			
			item_desc$=item_desc$+" "+cvs(item_description$,3)+iff(cvs(opt_invkitdet.memo_1024$,3)="",""," - "+cvs(opt_invkitdet.memo_1024$,3))

            if len(item_desc$) then if item_desc$(len(item_desc$),1)=$0A$ then item_desc$=item_desc$(1,len(item_desc$)-1)

			data! = rs!.getEmptyRecordData()
			data!.setFieldValue("ORDER_QTY_MASKED", order_qty_masked$)
			data!.setFieldValue("SHIP_QTY_MASKED", ship_qty_masked$)
			data!.setFieldValue("SHIP_QTY", ship_qty$)
			data!.setFieldValue("BACKORD_QTY_MASKED", backord_qty_masked$)
			data!.setFieldValue("ITEM_ID", item_id$)
			data!.setFieldValue("ITEM_DESC", item_desc$)
			data!.setFieldValue("UM", um$)
			data!.setFieldValue("PRICE_RAW", price_raw$)
			data!.setFieldValue("PRICE_MASKED", price_masked$)
			data!.setFieldValue("EXTENDED_RAW", ext_raw$)
			data!.setFieldValue("EXTENDED_MASKED", ext_masked$)

			rs!.insert(data!)		

        rem --- End of kit component lines

        wend

rem --- Tell the stored procedure to return the result set.

	sp!.setRecordSet(rs!)

	goto std_exit

rem --- fnmask$: Alphanumeric Masking Function (formerly fnf$)

    def fnmask$(q1$,q2$)
        if cvs(q1$,2)="" return ""
        if q2$="" q2$=fill(len(q1$),"0")
        if pos("E"=cvs(q1$,4)) goto alpha_mask
:      else return str(-num(q1$,err=alpha_mask):q2$,err=alpha_mask)
alpha_mask:
        q=1
        q0=0
        while len(q2$(q))
            if pos(q2$(q,1)="-()") q0=q0+1 else q2$(q,1)="X"
            q=q+1
        wend
        if len(q1$)>len(q2$)-q0 q1$=q1$(1,len(q2$)-q0)
        return str(q1$:q2$)
    fnend
	
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
