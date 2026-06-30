rem ----------------------------------------------------------------------------
rem Program: ARCUSTDETAIL_JOBS.prc
rem Description: Stored Procedure to create a Customer Detail Jobs Listing
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
    customer_id$ = sp!.getParameter("CUSTOMER_ID")
    amt_mask$ = sp!.getParameter("AMT_MASK")
    barista_wd$ = sp!.getParameter("BARISTA_WD")

    chdir barista_wd$

rem --- create the in memory recordset for return
    dataTemplate$ = "job_no:C(10),customer_name:C(30),addr_line_1:C(30),addr_line_2:C(30),city:C(30),state_code:C(2),zip_code:C(9),"
    dataTemplate$ = dataTemplate$ + "contact_name:C(20),phone_no:C(20),phone_exten:C(4),retain_job:C(1),lien_date:C(8),lien_no:C(12),"
    dataTemplate$ = dataTemplate$ + "lien_amount:C(1*),fst_shp_date:C(8),total_sales:C(1*),lstinv_date:C(8)"
    dataTemplate$ = dataTemplate$ + ""

    rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- open files
    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]
    files$[1]="opm-09",ids$[1]="OPM_CUSTJOBS"

    call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status
    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif

    opm09_dev=channels[1]
    
    rem --- Dimension string templates

	dim opm09$:templates$[1]
    
rem --- positional read
    read(opm09_dev,key = firm_id$+customer_id$,dom=*next)

rem --- main loop
    while 1
        readrecord(opm09_dev,end=*break)opm09$
        if opm09.firm_id$<>firm_id$ then break
        if opm09.customer_id$<>customer_id$ then break
      
        rem --- put data into recordset
        
        data! = rs!.getEmptyRecordData()
        data!.setFieldValue("JOB_NO",opm09.job_no$)
    	data!.setFieldValue("CUSTOMER_NAME",opm09.customer_name$)
        data!.setFieldValue("ADDR_LINE_1",opm09.addr_line_1$)
        data!.setFieldValue("ADDR_LINE_2",opm09.addr_line_2$)
        data!.setFieldValue("CITY",opm09.city$)
        data!.setFieldValue("STATE_CODE",opm09.state_code$)

        call stbl("+DIR_SYP")+"bac_getmask.bbj","P",cvs(opm09.zip_code$,2),"",postal_mask$
        postal$=cvs(opm09.zip_code$,2)
        postal$=str(postal$:postal_mask$,err=*next)
        data!.setFieldValue("ZIP_CODE",postal$)

        data!.setFieldValue("CONTACT_NAME",opm09.contact_name$)
        
        call stbl("+DIR_SYP")+"bac_getmask.bbj","T",cvs(opm09.phone_no$,2),"",phone_mask$
        phone$=cvs(opm09.phone_no$,2)
        phone$=str(phone$:phone_mask$,err=*next)
        data!.setFieldValue("PHONE_NO",phone$)
        
        data!.setFieldValue("PHONE_EXTEN",opm09.phone_exten$)
        data!.setFieldValue("LIEN_DATE",func.formatDate(opm09.lien_date$))
        data!.setFieldValue("LIEN_NO",opm09.lien_no$)
        data!.setFieldValue("LIEN_AMOUNT",str(opm09.lien_amount:amt_mask$))
        data!.setFieldValue("FST_SHP_DATE",func.formatDate(opm09.fst_shp_date$))
        data!.setFieldValue("LSTINV_DATE",func.formatDate(opm09.lstinv_date$))
        data!.setFieldValue("TOTAL_SALES",str(opm09.total_sales:amt_mask$))

        rs!.insert(data!)
        
    wend

rem --- close files
    close(opm09_dev)

    sp!.setRecordSet(rs!)
    end

sproc_error:rem --- SPROC error trap/handler
    rd_err_text$="", err_num=err
    if tcb(2)=0 and tcb(5) then rd_err_text$=pgm(tcb(5),tcb(13),err=*next)
    x$=stbl("+THROWN_ERR","TRUE")
    throw "["+pgm(-2)+"] "+str(tcb(5))+": "+rd_err_text$,err_num
    
std_exit:
    end
