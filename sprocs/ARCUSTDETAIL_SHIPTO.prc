rem ----------------------------------------------------------------------------
rem Program: ARCUSTDETAIL_SHIPTO.prc
rem Description: Stored Procedure to create a Customer Detail Ship To Listing
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
    barista_wd$ = sp!.getParameter("BARISTA_WD")

    chdir barista_wd$

rem --- create the in memory recordset for return
    dataTemplate$ = "shipto_no:C(6),name:C(30),addr_line_1:C(30),addr_line_2:C(30),addr_line_3:C(30),addr_line_4:C(30),"
    dataTemplate$ = dataTemplate$ + "city:C(30),state_code:C(2),zip_code:C(9),ar_ship_via:C(10),shipping_email:C(80),"
    dataTemplate$ = dataTemplate$ + "contact_name:C(20),phone_no:C(20),phone_exten:C(4),db_no:C(9),sic_code:C(8),shipping_id:C(15),"
    dataTemplate$ = dataTemplate$ + "slspsn_code:C(3),sales_desc:C(20),territory:C(8),terr_desc:C(20),tax_code:C(10),tax_desc:C(20)"
    dataTemplate$ = dataTemplate$ + ""

    rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)

rem --- open files
    files=4,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]
    files$[1]="arm-03",ids$[1]="ARM_CUSTSHIP"
    files$[2]="arc_salecode",ids$[2]="ARC_SALECODE"
    files$[3]="arc_terrcode",ids$[3]="ARC_TERRCODE"
    files$[4]="opm-06",ids$[4]="OPC_TAXCODE"

    call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],ids$[all],templates$[all],channels[all],batch,status
    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif

    arm03_dev=channels[1]
    arcSaleCode_dev=channels[2]
    arcTerrCode_dev=channels[3]
    opm06_dev=channels[4]
    
    rem --- Dimension string templates

	dim arm03$:templates$[1]
	dim arcSaleCode$:templates$[2]
    dim arcTerrCode$:templates$[3]
    dim opm06$:templates$[4]
    
rem --- positional read
    read(arm03_dev,key = firm_id$+customer_id$,dom=*next)

rem --- main loop
    while 1
        readrecord(arm03_dev,end=*break)arm03$
        if arm03.firm_id$<>firm_id$ then break
        if arm03.customer_id$<>customer_id$ then break
      
        rem --- put data into recordset
        
        data! = rs!.getEmptyRecordData()
        data!.setFieldValue("SHIPTO_NO",arm03.shipto_no$)
    	data!.setFieldValue("NAME",arm03.name$)
        data!.setFieldValue("ADDR_LINE_1",arm03.addr_line_1$)
        data!.setFieldValue("ADDR_LINE_2",arm03.addr_line_2$)
        data!.setFieldValue("ADDR_LINE_3",arm03.addr_line_3$)
        data!.setFieldValue("ADDR_LINE_4",arm03.addr_line_4$)
        data!.setFieldValue("CITY",arm03.city$)
        data!.setFieldValue("STATE_CODE",arm03.state_code$)

        call stbl("+DIR_SYP")+"bac_getmask.bbj","P",cvs(arm03.zip_code$,2),"",postal_mask$
        postal$=cvs(arm03.zip_code$,2)
        postal$=str(postal$:postal_mask$,err=*next)
        data!.setFieldValue("ZIP_CODE",postal$)

        data!.setFieldValue("AR_SHIP_VIA",arm03.ar_ship_via$)
        data!.setFieldValue("SHIPPING_EMAIL",arm03.shipping_email$)
        data!.setFieldValue("CONTACT_NAME",arm03.contact_name$)
        
        call stbl("+DIR_SYP")+"bac_getmask.bbj","T",cvs(arm03.phone_no$,2),"",phone_mask$
        phone$=cvs(arm03.phone_no$,2)
        phone$=str(phone$:phone_mask$,err=*next)
        data!.setFieldValue("PHONE_NO",phone$)
        
        data!.setFieldValue("PHONE_EXTEN",arm03.phone_exten$)
        data!.setFieldValue("DB_NO",arm03.db_no$)
        data!.setFieldValue("SIC_CODE",arm03.sic_code$)
        data!.setFieldValue("SHIPPING_ID",arm03.shipping_id$)
        
        data!.setFieldValue("SLSPSN_CODE",arm03.slspsn_code$)
        arcSaleCode.code_desc$="*** Not Found ***"
        findrecord(arcSaleCode_dev,key=firm_id$+"F"+arm03.slspsn_code$,dom=*next)arcSaleCode$
        data!.setFieldValue("SALES_DESC",arcSaleCode.code_desc$)

        data!.setFieldValue("TERRITORY",arm03.territory$)
        arcTerrCode.code_desc$="*** Not Found ***"
        findrecord(arcTerrCode_dev,key=firm_id$+"H"+arm03.territory$,dom=*next)arcTerrCode$
        data!.setFieldValue("TERR_DESC",arcTerrCode.code_desc$)

        data!.setFieldValue("TAX_CODE",arm03.tax_code$)
        opm06.code_desc$="*** Not Found ***"
        findrecord(opm06_dev,key=firm_id$+arm03.tax_code$,dom=*next)opm06$
        data!.setFieldValue("TAX_DESC",opm06.code_desc$)

        rs!.insert(data!)
        
    wend

rem --- close files
    close(arm03_dev)
    close(arcSaleCode_dev)
    close(arcTerrCode_dev)
    close(opm06_dev)

    sp!.setRecordSet(rs!)
    end

sproc_error:rem --- SPROC error trap/handler
    rd_err_text$="", err_num=err
    if tcb(2)=0 and tcb(5) then rd_err_text$=pgm(tcb(5),tcb(13),err=*next)
    x$=stbl("+THROWN_ERR","TRUE")
    throw "["+pgm(-2)+"] "+str(tcb(5))+": "+rd_err_text$,err_num
    
std_exit:
    end
