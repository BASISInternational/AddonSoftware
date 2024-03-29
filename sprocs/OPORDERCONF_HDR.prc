rem ----------------------------------------------------------------------------
rem --- OP Order Confirmation
rem --- Program: OPORDERCONF_HDR.prc
rem --- Description: Stored Procedure to create header for a jasper-based OP Order Confirmation

rem --- Copyright BASIS International Ltd.  All Rights Reserved.

rem --- opc_ordconf.aon is used to print (1) On-Demand (from Order Entry--
rem --- ope_ordhdr.cdf), (2) Batch (from menu: OP Print Order Confirmations --
rem --- opr_ordconf.aon).

rem --- opc_ordconf.aon uses three sprocs and three .jaspers to generate confirmations:
rem ---    - OPORDCONF_HDR.prc / OPOrderConfHdr.jasper
rem ---    - OPORDCONF_DET.prc / OPOrderConfDet.jasper
rem ---    - OPORDCONF_DET_LOTSER.prc / OPOrderConfDet-LotSer.jasper
rem ----------------------------------------------------------------------------

seterr sproc_error

declare BBjStoredProcedureData sp!
declare BBjRecordSet rs!
declare BBjRecordData data!

rem --- Get the infomation object for the Stored Procedure
sp! = BBjAPI().getFileSystem().getStoredProcedureData()

rem --- get SPROC parameters

firm_id$ =     sp!.getParameter("FIRM_ID")
ar_type$ =     sp!.getParameter("AR_TYPE")
customer_id$ = sp!.getParameter("CUSTOMER_ID")
order_no$ =    sp!.getParameter("ORDER_NO")
ar_inv_no$ =   sp!.getParameter("AR_INV_NO")
cust_mask$ =   sp!.getParameter("CUST_MASK")
cust_size = num(sp!.getParameter("CUST_SIZE"))
barista_wd$ =  sp!.getParameter("BARISTA_WD")
report_type$ = sp!.getParameter("REPORT_TYPE")

chdir barista_wd$

rem --- create the in memory recordset for return

dataTemplate$ = ""
dataTemplate$ = dataTemplate$ + "order_date:C(10),"
datatemplate$ = datatemplate$ + "bill_addr_line1:C(30),bill_addr_line2:C(30),bill_addr_line3:C(30),"
datatemplate$ = datatemplate$ + "bill_addr_line4:C(30),bill_addr_line5:C(30),bill_addr_line6:C(30),"
datatemplate$ = datatemplate$ + "bill_addr_line7:C(30),"
datatemplate$ = datatemplate$ + "ship_addr_line1:C(30),ship_addr_line2:C(30),ship_addr_line3:C(30),"
datatemplate$ = datatemplate$ + "ship_addr_line4:C(30),ship_addr_line5:C(30),ship_addr_line6:C(30),"
datatemplate$ = datatemplate$ + "ship_addr_line7:C(30),"
dataTemplate$ = dataTemplate$ + "salesrep_code:C(3),salesrep_desc:C(20),cust_po_num:C(20),ship_via:C(10),"
dataTemplate$ = dataTemplate$ + "fob:C(15),ship_date:C(10),terms_code:C(3),terms_desc:C(20),"
datatemplate$ = datatemplate$ + "inv_std_message:C(1024*=1),"
dataTemplate$ = dataTemplate$ + "discount_amt_raw:C(1*),tax_amt_raw:C(1*),freight_amt_raw:C(1*),total_sale_raw:C(1*)"

rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)
    
rem --- Use statements and Declares
	
    use ::ado_func.src::func
    use ::sys/prog/bao_option.bbj::Option
    
    declare Option option!
    declare BBjVector custIds!
    declare BBjVector orderNos!

rem --- Retrieve the program path

    pgmdir$=""
    pgmdir$=stbl("+DIR_PGM",err=*next)
    sypdir$=""
    sypdir$=stbl("+DIR_SYP",err=*next)

rem --- Init

    start_block = 1
    nothing_printed = 1	

    rem --- Report types
    on_demand$="1"
    batch_inv$="2"

rem --- Open Files    
rem --- Note 'files' and 'channels[]' are used in close loop, so don't re-use

    files=15,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]    

    files$[1]="arm-01",       ids$[1]="ARM_CUSTMAST"
    files$[2]="arm-02",       ids$[2]="ARM_CUSTDET"
    files$[3]="arm-03",       ids$[3]="ARM_CUSTSHIP"
    files$[4]="arc_termcode", ids$[4]="ARC_TERMCODE"
    files$[5]="arc_cashcode", ids$[5]="ARC_CASHCODE"
    files$[6]="arc_salecode", ids$[6]="ARC_SALECODE"
    files$[7]="ivm-01",       ids$[7]="IVM_ITEMMAST"
    files$[8]="opt-01",       ids$[8]="OPE_INVHDR"
    files$[9]="ope-04",       ids$[9]="OPE_PRNTLIST"	
    files$[10]="opt-31",      ids$[10]="OPE_ORDSHIP"
    files$[11]="opt-41",      ids$[11]="OPE_INVCASH"    
    files$[12]="opm-09",      ids$[12]="OPM_CUSTJOBS"
    files$[13]="opc_message",      ids$[13]="OPC_MESSAGE"
    files$[14]="ars_cc_custpmt",ids$[14]="ARS_CC_CUSTPMT"
    files$[15]="ars_params",  ids$[15]="ARS_PARAMS"

	call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status

    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif
    
	files_opened = files; rem used in loop to close files
	
    arm01_dev = channels[1]
    arm02_dev = channels[2]
    arm03_dev = channels[3]
    arm10a_dev = channels[4]
    arm10c_dev = channels[5]
    arm10f_dev = channels[6]
    ivm01_dev = channels[7]
    ope01_dev = channels[8]
    ope04_dev = channels[9]
    ope31_dev = channels[10]
    ope41_dev = channels[11]
    opm09_dev = channels[12]
    opc_message = channels[13]
    ars_cc_custpmt=channels[14]
    arsParams_dev=channels[15]
    
	
    dim arm01a$:templates$[1]
    dim arm01a1$:templates$[1]
    dim arm02a$:templates$[2]
    dim arm03a$:templates$[3]
    dim arm10a$:templates$[4]
    dim arm10c$:templates$[5]
    dim arm10f$:templates$[6]
    dim ivm01a$:templates$[7]
    dim ope01a$:templates$[8]
    dim ope04a$:templates$[9]	
    dim ope31a$:templates$[10]
    dim ope41a$:templates$[11]
    dim opm09a$:templates$[12]
    dim opc_message$:templates$[13]
    dim ars_cc_custpmt$:templates$[14]
    dim arsParams$:templates$[15]
	
rem --- Initialize Data

    dim table_chans$[512,6]

	max_stdMsg_lines = 10
	stdMsg_len = 40
	rem dim stdMessage$(max_stdMsg_lines * stdMsg_len)
	
	max_billAddr_lines = 7
	bill_addrLine_len = 30
	dim b$(max_billAddr_lines * bill_addrLine_len)
	
	max_custAddr_lines = 7
	cust_addrLine_len = 30	
	dim c$(max_custAddr_lines * cust_addrLine_len)
	
	order_date$ =   ""
	slspsn_code$ =  ""
	slspsn_desc$ =  ""
	cust_po_no$ =   ""
	ship_via$ =     ""
	fob$ =          ""
	ship_date$ =    ""
	terms_code$ =   ""
	terms_desc$ =   ""
	discount_amt$ = ""
    tax_amt$ =      ""
    freight_amt$ =  ""
	
rem --- Main Read

    trans_status$="E"
    
    find record (ope01_dev, key=firm_id$+trans_status$+ar_type$+customer_id$+order_no$+ar_inv_no$, knum="AO_STATUS", dom=all_done) ope01a$

	order_date$ =   func.formatDate(ope01a.order_date$)
	cust_po_no$ =   ope01a.customer_po_no$
	ship_via$ =     ope01a.ar_ship_via$
	fob$ =          ope01a.fob$
	ship_date$ =    func.formatDate(ope01a.shipmnt_date$)
	discount_amt_raw$ = str(-ope01a.discount_amt:amt_mask$)
    tax_amt_raw$ =      str(ope01a.tax_amount:amt_mask$)
    freight_amt_raw$ =  str(ope01a.freight_amt:amt_mask$)
    total_sale_raw$ =  str(ope01a.total_sales:amt_mask$)
	discount_amt$ = str(discount_amt_raw:amt_mask$)
    tax_amt$ =      str(tax_amt_raw:amt_mask$)
    freight_amt$ =  str(freight_amt_raw:amt_mask$)

    rem --- Heading (bill-to address)
        
    declare BBjTemplatedString arm01!
    declare BBjTemplatedString arm03!
    declare BBjTemplatedString ope31!
    
    arm01! = BBjAPI().makeTemplatedString(fattr(arm01a$))
    arm03! = BBjAPI().makeTemplatedString(fattr(arm03a$))
    ope31! = BBjAPI().makeTemplatedString(fattr(ope31a$))

    found = 0
    start_block = 1

    if start_block then
        read record (arm01_dev, key=firm_id$+ope01a.customer_id$, dom=*endif) arm01!
        needAddress=1
        read record (ope31_dev, key=firm_id$+ope01a.customer_id$+ope01a.order_no$+ope01a.ar_inv_no$+"B", dom=*next) ope31!; needAddress=0
        if !needAddress then
            b$ = func.formatAddress(table_chans$[all], ope31!, bill_addrLine_len, max_billAddr_lines-1)
            b$ = pad(arm01!.getFieldAsString("CUSTOMER_NAME"), bill_addrLine_len) + b$
        else
            b$ = func.formatAddress(table_chans$[all], arm01!, bill_addrLine_len, max_billAddr_lines-1)
        endif

        if cvs(b$((max_billAddr_lines-1)*bill_addrLine_len),2)="" then
                b$ = pad(func.alphaMask(arm01!.getFieldAsString("CUSTOMER_ID"), cust_mask$), bill_addrLine_len) + b$
        endif
        found = 1
    endif

    if !found then
        b$ = pad("Customer not found", bill_addrLine_len*max_billAddr_lines)
    endif
        
rem --- Ship-To
    
    c$ = b$
    start_block = 1

    if ope01a.shipto_type$ <> "B" then 
        needAddress=1
        read record (ope31_dev, key=firm_id$+ope01a.customer_id$+ope01a.order_no$+ope01a.ar_inv_no$+"S", dom=*next) ope31!; needAddress=0
        if !needAddress or ope01a.shipto_type$="M" then
            c$ = func.formatAddress(table_chans$[all], ope31!, bill_addrLine_len, max_billAddr_lines-1)
        else
            rem --- Need non-manual ship-to address
            find record (arm03_dev,key=firm_id$+ope01a.customer_id$+ope01a.shipto_no$, dom=*next) arm03!
            c$ = func.formatAddress(table_chans$[all], arm03!, cust_addrLine_len, max_custAddr_lines)
        endif

        if cvs(c$((max_billAddr_lines-1)*bill_addrLine_len),2)="" then
                c$ = pad(func.alphaMask(arm01!.getFieldAsString("CUSTOMER_ID"), cust_mask$), bill_addrLine_len) + c$
        endif
    endif

    rem --- Terms

        dim arm10a$:fattr(arm10a$)
        arm10a.code_desc$ = "Not Found"
        find record (arm10a_dev,key=firm_id$+"A"+ope01a.terms_code$,dom=*next) arm10a$

		terms_code$ = ope01a.terms_code$
		terms_desc$ = arm10a.code_desc$
		
    rem --- Salesperson

        arm10f.code_desc$ = "Not Found"
        find record (arm10f_dev,key=firm_id$+"F"+ope01a.slspsn_code$,dom=*next) arm10f$

		slspsn_code$ = ope01a.slspsn_code$
		slspsn_desc$ = arm10f.code_desc$

	rem --- Job Name

        dim opm09a$:fattr(opm09a$)
        opm09a.customer_name$ = "Not Found"

        if opm09_dev then 
            find record (opm09_dev, key=firm_id$+ope01a.customer_id$+ope01a.job_no$, dom=*next) opm09a$
        else
            opm09a.customer_name$ = ope01a.job_no$
        endif

    rem --- Standard Message
		
		gosub get_stdMessage

    nothing_printed = 0
        
all_done:    rem --- End of invoice -- Send data out

rem --- Format addresses to be bottom justified
	address$=b$
	line_len=bill_addrLine_len
	gosub format_address
	b$=address$
	
	address$=c$
	line_len=cust_addrLine_len
	gosub format_address
	c$=address$

		data! = rs!.getEmptyRecordData()
		data!.setFieldValue("ORDER_DATE", order_date$)

		data!.setFieldValue("BILL_ADDR_LINE1", b$((bill_addrLine_len*0)+1,bill_addrLine_len))
		data!.setFieldValue("BILL_ADDR_LINE2", b$((bill_addrLine_len*1)+1,bill_addrLine_len))
		data!.setFieldValue("BILL_ADDR_LINE3", b$((bill_addrLine_len*2)+1,bill_addrLine_len))
		data!.setFieldValue("BILL_ADDR_LINE4", b$((bill_addrLine_len*3)+1,bill_addrLine_len))
		data!.setFieldValue("BILL_ADDR_LINE5", b$((bill_addrLine_len*4)+1,bill_addrLine_len))
		data!.setFieldValue("BILL_ADDR_LINE6", b$((bill_addrLine_len*5)+1,bill_addrLine_len))
		data!.setFieldValue("BILL_ADDR_LINE7", b$((bill_addrLine_len*6)+1,bill_addrLine_len))

		data!.setFieldValue("SHIP_ADDR_LINE1", c$((cust_addrLine_len*0)+1,cust_addrLine_len))
		data!.setFieldValue("SHIP_ADDR_LINE2", c$((cust_addrLine_len*1)+1,cust_addrLine_len))
		data!.setFieldValue("SHIP_ADDR_LINE3", c$((cust_addrLine_len*2)+1,cust_addrLine_len))
		data!.setFieldValue("SHIP_ADDR_LINE4", c$((cust_addrLine_len*3)+1,cust_addrLine_len))
		data!.setFieldValue("SHIP_ADDR_LINE5", c$((cust_addrLine_len*4)+1,cust_addrLine_len))
		data!.setFieldValue("SHIP_ADDR_LINE6", c$((cust_addrLine_len*5)+1,cust_addrLine_len))
		data!.setFieldValue("SHIP_ADDR_LINE7", c$((cust_addrLine_len*6)+1,cust_addrLine_len))

		data!.setFieldValue("SALESREP_CODE", slspsn_code$)
		data!.setFieldValue("SALESREP_DESC", slspsn_desc$)
		data!.setFieldValue("CUST_PO_NUM", cust_po_no$)
		data!.setFieldValue("SHIP_VIA", ship_via$)
		data!.setFieldValue("FOB", fob$)
		data!.setFieldValue("SHIP_DATE", ship_date$)
		data!.setFieldValue("TERMS_CODE", terms_code$)
		data!.setFieldValue("TERMS_DESC", terms_desc$)

        memo_1024$=opc_message.memo_1024$
        if len(memo_1024$) and memo_1024$(len(memo_1024$))=$0A$ then memo_1024$=memo_1024$(1,len(memo_1024$)-1); rem --- trim trailing newline
		data!.setFieldValue("INV_STD_MESSAGE", memo_1024$)

		data!.setFieldValue("DISCOUNT_AMT_RAW", discount_amt_raw$)
		data!.setFieldValue("TAX_AMT_RAW", tax_amt_raw$)
		data!.setFieldValue("FREIGHT_AMT_RAW", freight_amt_raw$)
        data!.setFieldValue("TOTAL_SALE_RAW", total_sale_raw$)

		rs!.insert(data!)

rem Tell the stored procedure to return the result set.
	sp!.setRecordSet(rs!)
    
	goto std_exit

format_address: rem --- Reformat address to bottom justify

	dim tmp_address$(7*line_len)
	y=6*line_len+1
	for x=y to 1 step -line_len
		if cvs(address$(x,line_len),2)<>""
			tmp_address$(y,line_len)=address$(x,line_len)
			y=y-line_len
		endif
	next x
	address$=tmp_address$
	return

get_stdMessage: rem --- Get Standard Message lines

    ackMsgCd$="AK"
    ackMsgCd$=stbl("ACKNOWLEDGE_CODE",err=*next)
    redim opc_message$
    find record (opc_message, key=firm_id$+ackMsgCd$, dom=*next) opc_message$
    if cvs(opc_message.message_code$,2)="" then
        find record (opc_message, key=firm_id$+ope01a.message_code$, dom=*next) opc_message$
    endif
    
    return

rem --- Functions

    def fnline2y%(tmp0)=(tmp0*12)+12+top_of_detail+2


rem #include std_end.src

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
