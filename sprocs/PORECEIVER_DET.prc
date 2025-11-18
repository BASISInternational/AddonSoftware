rem ----------------------------------------------------------------------------
rem --- PO Receiver Detail
rem --- Program: PORECEIVER_DET.prc 
rem
rem --- Copyright BASIS International Ltd.  All Rights Reserved.
rem
rem --- por_poreceiver.aon is used to drive on-demand PO receiver print
rem
rem --- There are two sprocs/.jaspers for this document:
rem ---    - PORECEIVER_HDR.prc / POReceiverHdr.jasper
rem ---    - PORECEIVER_DET.prc / POReceiverDet.jasper
rem
rem ----------------------------------------------------------------------------
rem goto wghTrace
endtrace
traceFile$="\temp\DETtrace_"+date(0:"%Yz%Mz%Dz%Hz%mz%sz")+".txt"
erase traceFile$,err=*next
string traceFile$
traceChan=unt
open(traceChan)traceFile$
settrace(traceChan,mode="UNTIMED")
wghTrace:

	seterr sproc_error

rem --- Use statements and Declares

	use ::ado_func.src::func

	declare BBjStoredProcedureData sp!
	declare BBjRecordSet rs!
	declare BBjRecordData data!    

	sp! = BBjAPI().getFileSystem().getStoredProcedureData()

rem --- Get 'IN' SPROC parameters 
	firm_id$=sp!.getParameter("FIRM_ID")
	po_no$=sp!.getParameter("PO_NO")
    vendor_id$=sp!.getParameter("VENDOR_ID")
	qty_mask$=sp!.getParameter("QTY_MASK")
    ivImask$=sp!.getParameter("ITEM_MASK")
    iv_precision$=sp!.getParameter("IV_PRECISION")
    prt_vdr_item$=sp!.getParameter("PRT_VDR_ITEM")
    hdr_msg_code$=sp!.getParameter("HDR_MSG_CODE")
    hdr_ship_from$=sp!.getParameter("HDR_SHIP_FROM")
    nof_prompt$=sp!.getParameter("NOF_PROMPT")
    vend_item_prompt$=sp!.getParameter("VEND_ITEM_PROMPT")
    promise_prompt$=sp!.getParameter("PROMISE_PROMPT")
    not_b4_prompt$=sp!.getParameter("NOT_B4_PROMPT")
    shipfrom_prompt$=sp!.getParameter("SHIPFROM_PROMPT")
    lot_serial_lines$=sp!.getParameter("LOT_SERIAL_LINES")
	barista_wd$=sp!.getParameter("BARISTA_WD")

	chdir barista_wd$

rem --- create the in-memory recordset for return
rem --- Note: No cost fields for receiver document

	dataTemplate$ = ""
	dataTemplate$ = dataTemplate$ + "QTY_EXPECTED:c(1*), ITEM_ID_DESC_MSG:c(1*), REQD_DATE:c(1*), LOCATION:c(1*), "
	dataTemplate$ = dataTemplate$ + "UNIT_MEASURE:c(1*), ALL_CHECKBOX:c(1*), QTY_RECEIVED:c(1*)"

	rs! = BBjAPI().createMemoryRecordSet(dataTemplate$)
	
rem --- Retrieve the program path

    pgmdir$=""
    pgmdir$=stbl("+DIR_PGM",err=*next)
    sypdir$=""
    sypdir$=stbl("+DIR_SYP",err=*next)
	
rem --- Open Files    
rem --- Note 'files' and 'channels[]' are used in close loop, so don't re-use

    files=7,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]    

    files$[1]="poe-12",ids$[1]="POE_PODET"
    files$[2]="poc_message",ids$[2]="POC_MESSAGE"
    files$[3]="pom-02",ids$[3]="POC_LINECODE"
    files$[4]="ivm-01",ids$[4]="IVM_ITEMMAST"
    files$[5]="ivm-05",ids$[5]="IVM_ITEMVEND"
    files$[6]="apm-05",ids$[6]="APM_VENDADDR"
    files$[7]="ivm-02",ids$[7]="IVM_ITEMWHSE"

	call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status

    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif
    
	files_opened = files; rem used in loop to close files

    poe_podet=channels[1]
    poc_message=channels[2]
    poc_linecode=channels[3]
    ivm_itemmast=channels[4]
    ivm_itemvend=channels[5]
    apm_vendaddr=channels[6]
    ivm_itemwhse=channels[7]
    
    dim poe_podet$:templates$[1]
    dim poc_message$:templates$[2]
    dim poc_linecode$:templates$[3]
    dim ivm_itemmast$:templates$[4]
    dim ivm_itemvend$:templates$[5]
    dim apm_vendaddr$:templates$[6]
    dim ivm_itemwhse$:templates$[7]
	
rem --- Main

    read (poe_podet,key=firm_id$+po_no$,knum="DISPLAY_KEY",dom=*next)
    precision num(iv_precision$)
    
    while 1
    
        readrecord (poe_podet,end=*break) poe_podet$
        if pos(firm_id$+po_no$=poe_podet$)<>1 then break
        
        memo_1024$=poe_podet.memo_1024$
        if len(memo_1024$) and memo_1024$(len(memo_1024$))=$0A$ then memo_1024$=memo_1024$(1,len(memo_1024$)-1); rem --- trim trailing newline

        rem --- Calculate qty expected (ordered - received)
        qty=poe_podet.qty_ordered-poe_podet.qty_received
        
        rem --- Skip lines where qty expected <= 0 (fully received)
        find record (poc_linecode,key=firm_id$+poe_podet.po_line_code$,dom=*next) poc_linecode$
        if poc_linecode.line_type$="O" then qty=1
        if qty<=0 and pos(poc_linecode.line_type$="SNVO")>0 then continue; rem --- Skip completed lines for standard/non-stock/vendor/other

        action=pos(poc_linecode.line_type$="SNVMO")
        std_line=1
        nonstock_line=2
        vend_part_num=3
        message_line=4
        other_line=5

        switch action
        case std_line;   rem --- Standard Line

            dim ivm_itemmast$:fattr(ivm_itemmast$)
            ivm_itemmast.item_desc$=nof_prompt$
            find record (ivm_itemmast,key=firm_id$+poe_podet.item_id$,dom=*next) ivm_itemmast$
            
            rem --- Get warehouse location for stock items
            location$=""
            dim ivm_itemwhse$:fattr(ivm_itemwhse$)
            find record (ivm_itemwhse,key=firm_id$+poe_podet.warehouse_id$+poe_podet.item_id$,dom=*next) ivm_itemwhse$
            location$=cvs(ivm_itemwhse.location$,2)
                        
			qty_expected$=str(qty:qty_mask$)
			item_id_desc_msg$=fnmask$(ivm_itemmast.item_id$,ivIMask$);rem --- this field will contain the item id OR the description OR vendor part/address/message text, depending on the line
			reqd_date$=func.formatDate(poe_podet.reqd_date$)
			unit_measure$=poe_podet.unit_measure$
			all_checkbox$="[ ]"; rem --- Empty checkbox for manual fill-in
			qty_received$=""; rem --- Empty field for manual fill-in
            
            item_id_desc_msg$=cvs(fnmask$(ivm_itemmast.item_id$,ivIMask$),3)+" "+func.displayDesc(ivm_itemmast.item_desc$)

            if prt_vdr_item$="Y"
                dim ivm_itemvend$:fattr(ivm_itemvend$)
                find record (ivm_itemvend,key=firm_id$+vendor_id$+ivm_itemmast.item_id$,dom=*next) ivm_itemvend$
                if cvs(ivm_itemvend.vendor_item$,3)<>""
                    item_id_desc_msg$=item_id_desc_msg$+$0A$+vend_item_prompt$+ivm_itemvend.vendor_item$
                endif
            endif

            if cvs(memo_1024$,3)<>""
                item_id_desc_msg$=item_id_desc_msg$+$0A$+memo_1024$
            endif
            gosub add_to_recordset

            rem --- Add lot/serial lines if enabled and item is lot/serial controlled
            if lot_serial_lines$="Y" and pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y"
                if ivm_itemmast.lotser_flag$="S"
                    rem --- Add as many lines as qty expected for serial items
                    for i=1 to qty
                        item_id_desc_msg$="Serial #: _______________"
                        reqd_date$=""
                        location$=""
                        qty_expected$=""
                        unit_measure$=""
                        all_checkbox$=""
                        qty_received$=""
                        gosub add_to_recordset
                    next i
                else
                    rem --- Add 3 lines for lot controlled items
                    for i=1 to 3
                        item_id_desc_msg$="Lot #: _______________"
                        reqd_date$=""
                        location$=""
                        qty_expected$=""
                        unit_measure$=""
                        all_checkbox$=""
                        qty_received$=""
                        gosub add_to_recordset
                    next i
                endif
            endif

            break

        case nonstock_line; rem --- Non-Stock Line

            qty_expected$=str(qty:qty_mask$)
            item_id_desc_msg$=poe_podet.ns_item_id$
            reqd_date$=func.formatDate(poe_podet.reqd_date$)
            location$="Non-Stock"; rem --- Indicate no warehouse location
			unit_measure$=poe_podet.unit_measure$
			all_checkbox$="[ ]"
			qty_received$=""

            item_id_desc_msg$=item_id_desc_msg$+" "+memo_1024$
            gosub add_to_recordset
            
            break

        case vend_part_num; rem --- Vendor Part Number
        
            rem --- Vendor part number now added to the item description
            rem --- Skip separate line for vendor part number
                
            break

        case message_line; rem --- Message Line

            item_id_desc_msg$=memo_1024$
            reqd_date$=func.formatDate(poe_podet.reqd_date$)
            location$=""
            qty_expected$=""
            unit_measure$=""
            all_checkbox$=""
            qty_received$=""
            gosub add_to_recordset
                                
            break

        case other_line; rem --- Other Line
        
            qty_expected$=str(qty:qty_mask$)
            item_id_desc_msg$=memo_1024$
            reqd_date$=func.formatDate(poe_podet.reqd_date$)
            location$=""; rem --- No location for other items
            unit_measure$=poe_podet.unit_measure$
            all_checkbox$="[ ]"
            qty_received$=""
            gosub add_to_recordset
            
            break

        case default
            return
            break

    swend

rem --- Date Promised or Not Before Date?

    if pos(poc_linecode.line_type$="VM")=0
        tmp1$=""
        tmp2$=""
        if cvs(poe_podet.promise_date$,2)<>""
            tmp1$=promise_prompt$+func.formatDate(poe_podet.promise_date$)
        endif
        if cvs(poe_podet.not_b4_date$,2)<>""
            tmp2$=not_b4_prompt$+func.formatDate(poe_podet.not_b4_date$)
        endif
        item_id_desc_msg$=tmp1$+" "+tmp2$
        if cvs(item_id_desc_msg$,2)<>"" then 
            reqd_date$=""
            location$=""
            qty_expected$=""
            unit_measure$=""
            all_checkbox$=""
            qty_received$=""
            gosub add_to_recordset
        endif
    endif

rem --- Detail line message code

    if cvs(poe_podet.po_msg_code$,2)<>""

        msg_cd$ = poe_podet.po_msg_code$
        gosub process_messages

    endif

    wend

rem --- Done with line item or line messages, wrap up with header level message and/or ship from

    if cvs(hdr_msg_code$,2)<>""
        msg_cd$=hdr_msg_code$
        gosub process_messages
    endif

    if cvs(hdr_ship_from$,2)<>""
        shipfrom_addrLines=5
        shipfrom_addrLine_len=30
        dim shipfrom$(shipfrom_addrLines*shipfrom_addrLine_len)
        
        find record (apm_vendaddr,key=firm_id$+vendor_id$+hdr_ship_from$,dom=*next) apm_vendaddr$

        temp_addr$= apm_vendaddr.addr_line_1$ + apm_vendaddr.addr_line_2$ + apm_vendaddr.city$ + apm_vendaddr.state_code$ + apm_vendaddr.zip_code$ + apm_vendaddr.cntry_id$
        call pgmdir$+"adc_address.aon",temp_addr$,30,3,9,shipfrom_addrLine_len
        shipfrom$(1,shipfrom_addrLine_len)=shipfrom_prompt$+apm_vendaddr.name$
        shipfrom$(shipfrom_addrLine_len+1)=temp_addr$
        
        for x=0 to shipfrom_addrLines-1
            item_id_desc_msg$=shipfrom$(x*shipfrom_addrLine_len+1,shipfrom_addrLine_len)
            if cvs(item_id_desc_msg$,2)="" then continue
            reqd_date$=""
            location$=""
            qty_expected$=""
            unit_measure$=""
            all_checkbox$=""
            qty_received$=""
            gosub add_to_recordset
        next x
    
    endif

rem --- Tell the stored procedure to return the result set.

	sp!.setRecordSet(rs!)

	goto std_exit

add_to_recordset:

    if len(item_id_desc_msg$)
        if item_id_desc_msg$(len(item_id_desc_msg$),1)=$0A$ then item_id_desc_msg$=item_id_desc_msg$(1,len(item_id_desc_msg$)-1)
    endif

    data! = rs!.getEmptyRecordData()
    data!.setFieldValue("QTY_EXPECTED",qty_expected$)
    data!.setFieldValue("ITEM_ID_DESC_MSG",item_id_desc_msg$)
    data!.setFieldValue("REQD_DATE",reqd_date$)
    data!.setFieldValue("LOCATION",location$)
    data!.setFieldValue("UNIT_MEASURE",unit_measure$)
    data!.setFieldValue("ALL_CHECKBOX",all_checkbox$)
    data!.setFieldValue("QTY_RECEIVED",qty_received$)

    rs!.insert(data!)

    qty_expected$=""
    item_id_desc_msg$=""
    reqd_date$=""
    location$=""
    unit_measure$=""
    all_checkbox$=""
    qty_received$=""

    return

process_messages:rem --- Header or Detail level message codes

    find record (poc_message,key=firm_id$+msg_cd$,dom=*return) poc_message$
    rem --- if type isn't Both or Purchase Order, skip it (other types R=Reqs, N=neither)
    memo$=poc_message.memo_1024$
    if len(memo$) and memo$(len(memo$))=$0A$ then memo$=memo$(1,len(memo$)-1); rem --- trim trailing newline
    if pos(poc_message.message_type$ = "BP")<>0 then
        item_id_desc_msg$=memo$
        reqd_date$=""
        location$=""
        qty_expected$=""
        unit_measure$=""
        all_checkbox$=""
        qty_received$=""
        gosub add_to_recordset
    endif

    return

rem --- Functions

	def fnmask$(q1$,q2$)
		if cvs(q1$,2)="" return ""
		if q2$="" q2$=fill(len(q1$),"0")
		return str(-num(q1$,err=alpha_mask):q2$,err=alpha_mask)
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