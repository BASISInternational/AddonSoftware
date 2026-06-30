rem ----------------------------------------------------------------------------
rem Program: APVENDDETAIL_PURCH.prc
rem Description: Stored Procedure to create a Vendor Detail Purchases Listing
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
    vendor_id$ = sp!.getParameter("VENDOR_ID")
    barista_wd$ = sp!.getParameter("BARISTA_WD")

    chdir barista_wd$

rem --- create the in memory recordset for return
    dataTemplate$ = "firm_id:C(2),vendor_id:C(6),purch_addr:C(2),name:C(30),addr_line_1:C(30),addr_line_2:C(30),city:C(30),state_code:C(2),"
    dataTemplate$ = dataTemplate$ + "zip_code:C(9),cntry_id:C(2),phone_no:C(20),phone_exten:C(4),contact_name:C(20),fax_no:C(20),"
    dataTemplate$ = dataTemplate$ + "fob:C(15),ap_ship_via:C(15)"

    rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- open files
    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]
    files$[1]="apm-05",ids$[1]="APM_VENDADDR"

    call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status
    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif

    apm05_dev=channels[1]
    
    rem --- Dimension string templates

	dim apm05$:templates$[1]
    
rem --- positional read
    read(apm05_dev,key = firm_id$+vendor_id$,dom=*next)

rem --- main loop
    while 1
        readrecord(apm05_dev,end=*break)apm05$
        if apm05.firm_id$<>firm_id$ then break
        if apm05.vendor_id$<>vendor_id$ then break
      
        rem --- put data into recordset
        
        data! = rs!.getEmptyRecordData()
    	data!.setFieldValue("FIRM_ID",apm05.firm_id$)
    	data!.setFieldValue("VENDOR_ID",apm05.vendor_id$)
    	data!.setFieldValue("PURCH_ADDR",apm05.purch_addr$)
    	data!.setFieldValue("NAME",apm05.name$)
        data!.setFieldValue("ADDR_LINE_1",apm05.addr_line_1$)
        data!.setFieldValue("ADDR_LINE_2",apm05.addr_line_2$)
        data!.setFieldValue("CITY",apm05.city$)
        data!.setFieldValue("STATE_CODE",apm05.state_code$)

        call stbl("+DIR_SYP")+"bac_getmask.bbj","P",cvs(apm05.zip_code$,2),"",postal_mask$
        postal$=cvs(apm05.zip_code$,2)
        postal$=str(postal$:postal_mask$,err=*next)
        data!.setFieldValue("ZIP_CODE",postal$)

        data!.setFieldValue("CNTRY_ID",apm05.cntry_id$)
        
        call stbl("+DIR_SYP")+"bac_getmask.bbj","T",cvs(apm05.phone_no$,2),"",phone_mask$
        phone$=cvs(apm05.phone_no$,2)
        phone$=str(phone$:phone_mask$,err=*next)
        data!.setFieldValue("PHONE_NO",phone$)
        
        data!.setFieldValue("PHONE_EXTEN",apm05.phone_exten$)
        data!.setFieldValue("CONTACT_NAME",apm05.contact_name$)

        fax$=cvs(apm05.fax_no$,2)
        fax$=str(fax$:phone_mask$,err=*next)
        data!.setFieldValue("FAX_NO",fax$)
        
        data!.setFieldValue("FOB",apm05.fob$)
        data!.setFieldValue("AP_SHIP_VIA",apm05.ap_ship_via$)

        rs!.insert(data!)
        
    wend

rem --- close files
    close(apm05_dev)

    sp!.setRecordSet(rs!)
    end

sproc_error:rem --- SPROC error trap/handler
    rd_err_text$="", err_num=err
    if tcb(2)=0 and tcb(5) then rd_err_text$=pgm(tcb(5),tcb(13),err=*next)
    x$=stbl("+THROWN_ERR","TRUE")
    throw "["+pgm(-2)+"] "+str(tcb(5))+": "+rd_err_text$,err_num
    
std_exit:
    end
