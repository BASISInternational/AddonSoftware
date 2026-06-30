rem ----------------------------------------------------------------------------
rem Program: ARCUSTDETAIL.prc
rem Description: Stored Procedure to create a Customer Detail Listing
rem AddonSoftware
rem Copyright BASIS International Ltd.
rem ----------------------------------------------------------------------------

    seterr sproc_error

rem --- Use statements and Declares
    use ::ado_func.src::func

    declare BBjStoredProcedureData sp!
    declare BBjRecordSet rs!
    declare BBjRecordData data!

rem --- Get the infomation object for the Stored Procedure
    sp! = BBjAPI().getFileSystem().getStoredProcedureData()

rem --- Retrieve the program path
    pgmdir$=stbl("+DIR_PGM",err=*next)

rem --- get SPROC parameters
    firm_id$ = sp!.getParameter("FIRM_ID")
    customer_id_1$ = sp!.getParameter("CUSTOMER_ID_1")
    customer_id_2$ = sp!.getParameter("CUSTOMER_ID_2")
    option_active$ = sp!.getParameter("OPTION_ACTIVE")
    cust_mask$ = sp!.getParameter("CUST_MASK")
    cust_size = num(sp!.getParameter("CUST_SIZE"))
    barista_wd$ = sp!.getParameter("BARISTA_WD")

    chdir barista_wd$

rem --- create the in memory recordset for return
    dataTemplate$ = "firm_id:c(2),customer_id:C(1*),customer:C(6),customer_name:C(30),addr_line_1:C(30),addr_line_2:C(30),"
    dataTemplate$ = dataTemplate$ + "addr_line_3:C(30),addr_line_4:C(30),city:C(30),state_code:C(2),zip_code:C(9),"
    dataTemplate$ = dataTemplate$ + "phone_no:C(20),phone_exten:C(4),fax_no:C(20),contact_name:C(20),shipping_email:C(80),"
    dataTemplate$ = dataTemplate$ + "alt_sequence:C(10),opened_date:C(8),ar_ship_via:C(10),shipping_id:C(15),"
    dataTemplate$ = dataTemplate$ + "resale_no:C(20),db_no:C(9),sic_code:C(8),cust_inactive:C(1)"

    rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- open files
    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]
    files$[1]="arm-01",ids$[1]="ARM_CUSTMAST"

    call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status
    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif

    arm01_dev=channels[1]
    
    rem --- Dimension string templates

	dim arm01$:templates$[1]
    
rem --- positional read
    read(arm01_dev,key = firm_id$+customer_id_1$,dom=*next)
    if cvs(customer_id_1$,2)<>"" then read (arm01_dev,dir=-1,err=*next)

rem --- main loop
    while 1
        readrecord(arm01_dev,end=*break)arm01$
        if arm01.firm_id$<>firm_id$ then break
        if cvs(customer_id_2$,2)<>"" and arm01.customer_id$>customer_id_2$ then break
        if option_active$<>"" and arm01.cust_inactive$="Y" then continue; rem --- Exclude inactive customers
       
        rem --- put data into recordset
        
        data! = rs!.getEmptyRecordData()
        data!.setFieldValue("FIRM_ID",firm_id$)
        data!.setFieldValue("CUSTOMER_ID",arm01.customer_id$)
        data!.setFieldValue("CUSTOMER",fnmask$(arm01.customer_id$(1,cust_size),cust_mask$))
    	data!.setFieldValue("CUSTOMER_NAME",arm01.customer_name$)
        data!.setFieldValue("ADDR_LINE_1",arm01.addr_line_1$)
        data!.setFieldValue("ADDR_LINE_2",arm01.addr_line_2$)
        data!.setFieldValue("ADDR_LINE_3",arm01.addr_line_3$)
        data!.setFieldValue("ADDR_LINE_4",arm01.addr_line_4$)
        data!.setFieldValue("CITY",arm01.city$)
        data!.setFieldValue("STATE_CODE",arm01.state_code$)

        call stbl("+DIR_SYP")+"bac_getmask.bbj","P",cvs(arm01.zip_code$,2),"",postal_mask$
        postal$=cvs(arm01.zip_code$,2)
        postal$=str(postal$:postal_mask$,err=*next)
        data!.setFieldValue("ZIP_CODE",postal$)
        
        call stbl("+DIR_SYP")+"bac_getmask.bbj","T",cvs(arm01.phone_no$,2),"",phone_mask$
        phone$=cvs(arm01.phone_no$,2)
        phone$=str(phone$:phone_mask$,err=*next)
        data!.setFieldValue("PHONE_NO",phone$)
        
        data!.setFieldValue("PHONE_EXTEN",arm01.phone_exten$)
        
        fax$=cvs(arm01.fax_no$,2)
        fax$=str(fax$:phone_mask$,err=*next)
        data!.setFieldValue("FAX_NO",fax$)
        
        data!.setFieldValue("CONTACT_NAME",arm01.contact_name$)
        data!.setFieldValue("SHIPPING_EMAIL",arm01.shipping_email$)
        data!.setFieldValue("ALT_SEQUENCE",arm01.alt_sequence$)
        data!.setFieldValue("OPENED_DATE",func.formatDate(arm01.opened_date$))
        data!.setFieldValue("AR_SHIP_VIA",arm01.ar_ship_via$)
        data!.setFieldValue("SHIPPING_ID",arm01.shipping_id$)
        data!.setFieldValue("RESALE_NO",arm01.resale_no$)
        data!.setFieldValue("DB_NO",arm01.db_no$)
        data!.setFieldValue("SIC_CODE",arm01.sic_code$)
        data!.setFieldValue("CUST_INACTIVE",arm01.cust_inactive$)

        rs!.insert(data!)
        
    wend

rem --- close files
    close(arm01_dev)

    sp!.setRecordSet(rs!)
    end

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
    end
