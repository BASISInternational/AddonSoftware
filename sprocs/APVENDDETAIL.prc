rem ----------------------------------------------------------------------------
rem Program: APVENDDETAIL.prc
rem Description: Stored Procedure to create a Vendor Detail Listing
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
    vendor_id_1$ = sp!.getParameter("VENDOR_ID_1")
    vendor_id_2$ = sp!.getParameter("VENDOR_ID_2")
    vendor_type$ = sp!.getParameter("VENDOR_TYPE")
    option_active$ = sp!.getParameter("OPTION_ACTIVE")
    vend_mask$ = sp!.getParameter("VEND_MASK")
    vend_size = num(sp!.getParameter("VEND_SIZE"))
    barista_wd$ = sp!.getParameter("BARISTA_WD")

    chdir barista_wd$

rem --- create the in memory recordset for return
    dataTemplate$ = "firm_id:c(2),vendor_id:C(1*),vendor:C(6),vendor_name:C(30),addr_line_1:C(30),addr_line_2:C(30),"
    dataTemplate$ = dataTemplate$ + "city:C(30),state_code:C(2),zip_code:C(9),phone_no:C(20),phone_exten:C(4),fax_no:C(20),"
    dataTemplate$ = dataTemplate$ + "contact_name:C(20),alt_sequence:C(10),hold_flag:C(1),federal_id:C(15),vendor_1099:C(1),"
    dataTemplate$ = dataTemplate$ + "vendor_acct:C(10),fob:C(15),ap_ship_via:C(15),opened_date:C(8),temp_vend:C(1),"
    dataTemplate$ = dataTemplate$ + "cntry_id:C(2),vend_inactive:C(1)"

    rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- open files
    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]
    files$[1]="apm-01",ids$[1]="APM_VENDMAST"

    call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status
    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif

    apm01_dev=channels[1]
    
    rem --- Dimension string templates

	dim apm01$:templates$[1]
    
rem --- positional read
    read(apm01_dev,key = firm_id$+vendor_id_1$,dom=*next)
    if cvs(vendor_id_1$,2)<>"" then read (apm01_dev,dir=-1,err=*next)

rem --- main loop
    while 1
        readrecord(apm01_dev,end=*break)apm01$
        if apm01.firm_id$<>firm_id$ then break
        if cvs(vendor_id_2$,2)<>"" and apm01.vendor_id$>vendor_id_2$ then break
        if apm01.vend_inactive$="Y" then continue
        if option_active$<>"" and apm01.vend_inactive$="Y" then continue; rem --- Exclude inactive vendors
        if vendor_type$="P" then
            if apm01.temp_vend$="Y" then continue
        else
            if vendor_type$="T" then
                if apm01.temp_vend$="N" then continue
            endif
        endif
       
        rem --- put data into recordset
        
        data! = rs!.getEmptyRecordData()
        data!.setFieldValue("FIRM_ID",firm_id$)
        data!.setFieldValue("VENDOR_ID",apm01.vendor_id$)
        data!.setFieldValue("VENDOR",fnmask$(apm01.vendor_id$(1,vend_size),vend_mask$))
    	data!.setFieldValue("VENDOR_NAME",apm01.vendor_name$)
        data!.setFieldValue("ADDR_LINE_1",apm01.addr_line_1$)
        data!.setFieldValue("ADDR_LINE_2",apm01.addr_line_2$)
        data!.setFieldValue("CITY",apm01.city$)
        data!.setFieldValue("STATE_CODE",apm01.state_code$)

        call stbl("+DIR_SYP")+"bac_getmask.bbj","P",cvs(apm01.zip_code$,2),"",postal_mask$
        postal$=cvs(apm01.zip_code$,2)
        postal$=str(postal$:postal_mask$,err=*next)
        data!.setFieldValue("ZIP_CODE",postal$)
        
        call stbl("+DIR_SYP")+"bac_getmask.bbj","T",cvs(apm01.phone_no$,2),"",phone_mask$
        phone$=cvs(apm01.phone_no$,2)
        phone$=str(phone$:phone_mask$,err=*next)
        data!.setFieldValue("PHONE_NO",phone$)
        
        data!.setFieldValue("PHONE_EXTEN",apm01.phone_exten$)
        
        fax$=cvs(apm01.fax_no$,2)
        fax$=str(fax$:phone_mask$,err=*next)
        data!.setFieldValue("FAX_NO",fax$)
        
        data!.setFieldValue("CONTACT_NAME",apm01.contact_name$)
        data!.setFieldValue("ALT_SEQUENCE",apm01.alt_sequence$)
        data!.setFieldValue("HOLD_FLAG",apm01.hold_flag$)
        data!.setFieldValue("FEDERAL_ID",apm01.federal_id$)
        data!.setFieldValue("VENDOR_1099",apm01.vendor_1099$)
        data!.setFieldValue("VENDOR_ACCT",apm01.vendor_acct$)
        data!.setFieldValue("FOB",apm01.fob$)
        data!.setFieldValue("AP_SHIP_VIA",apm01.ap_ship_via$)
        data!.setFieldValue("OPENED_DATE",func.formatDate(apm01.opened_date$))
        data!.setFieldValue("TEMP_VEND",apm01.temp_vend$)
        data!.setFieldValue("CNTRY_ID",apm01.cntry_id$)
        data!.setFieldValue("VEND_INACTIVE",apm01.vend_inactive$)

        rs!.insert(data!)
        
    wend

rem --- close files
    close(apm01_dev)

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
