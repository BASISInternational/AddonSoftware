rem ----------------------------------------------------------------------------
rem Program: GLACCTLIST.prc
rem Description: Stored Procedure to create a jasper-based GL Account list for
rem              the General Ledger Accounts section in the Item Detail Listing.
rem AddonSoftware
rem Copyright BASIS International Ltd.
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
	firm_id$ = sp!.getParameter("FIRM_ID")
	item_id$ = sp!.getParameter("ITEM_ID")
    glAccount_mask$ = sp!.getParameter("GL_MASK")
    glAccount_size = num(sp!.getParameter("GL_LEN"))
    
rem --- Get Barista System Program directory
	sypdir$=""
	sypdir$=stbl("+DIR_SYP",err=*next)
	pgmdir$=stbl("+DIR_PGM",err=*next)

	barista_wd$=dir("")
	chdir barista_wd$
	
rem --- Create the in memory recordset for return
	dataTemplate$ = ""
	dataTemplate$ = dataTemplate$ + "gl_inv_acct:c(10*), gl_cogs_acct:c(10*), gl_pur_acct:c(10*), gl_ppv_acct:c(10*), gl_inv_adj:c(10*), gl_cogs_adj:c(10*),"
	dataTemplate$ = dataTemplate$ + "inv_desc:c(35*), cogs_desc:c(35*), pur_desc:c(35*), ppv_desc:c(35*), ivadj_desc:c(35*), cogsadj_desc:c(35*)"

	rs! = BBJAPI().createMemoryRecordSet(dataTemplate$)
	
rem --- Get GL Account info
	sqlprep$=""
	sqlprep$=sqlprep$+"SELECT gl_inv_acct, gl_cogs_acct, gl_pur_acct, gl_ppv_acct, gl_inv_adj, gl_cogs_adj, "
    sqlprep$=sqlprep$+"gl1.gl_acct_desc AS inv_desc,gl2.gl_acct_desc AS cogs_desc, gl3.gl_acct_desc AS pur_desc, "
    sqlprep$=sqlprep$+"gl4.gl_acct_desc AS ppv_desc, gl5.gl_acct_desc AS ivadj_desc, gl6.gl_acct_desc AS cogsadj_desc "
	sqlprep$=sqlprep$+"FROM ivm_itemmast "
    sqlprep$=sqlprep$+"LEFT JOIN glm_acct gl1 ON gl1.firm_id = '"+firm_id$+"' AND gl1.gl_account = ivm_itemmast.gl_inv_acct "    
    sqlprep$=sqlprep$+"LEFT JOIN glm_acct gl2 ON gl2.firm_id = '"+firm_id$+"' AND gl2.gl_account = ivm_itemmast.gl_cogs_acct "    
    sqlprep$=sqlprep$+"LEFT JOIN glm_acct gl3 ON gl3.firm_id = '"+firm_id$+"' AND gl3.gl_account = ivm_itemmast.gl_pur_acct "    
    sqlprep$=sqlprep$+"LEFT JOIN glm_acct gl4 ON gl4.firm_id = '"+firm_id$+"' AND gl4.gl_account = ivm_itemmast.gl_ppv_acct "    
    sqlprep$=sqlprep$+"LEFT JOIN glm_acct gl5 ON gl5.firm_id = '"+firm_id$+"' AND gl5.gl_account = ivm_itemmast.gl_inv_adj "    
    sqlprep$=sqlprep$+"LEFT JOIN glm_acct gl6 ON gl6.firm_id = '"+firm_id$+"' AND gl6.gl_account = ivm_itemmast.gl_cogs_adj "    
	sqlprep$=sqlprep$+"WHERE firm_id='"+firm_id$+"' "
	sqlprep$=sqlprep$+"AND item_id='"+item_id$+"'"

	sql_chan=sqlunt
	sqlopen(sql_chan,mode="PROCEDURE",err=*next)stbl("+DBNAME")
	sqlprep(sql_chan)sqlprep$
	dim read_tpl$:sqltmpl(sql_chan)
	sqlexec(sql_chan)

rem --- Process through SQL results 
	while 1
		read_tpl$ = sqlfetch(sql_chan,end=*break)

		data! = rs!.getEmptyRecordData()

		data!.setFieldValue("gl_inv_acct", fnmask$(read_tpl.gl_inv_acct$(1,glAccount_size),glAccount_mask$))
		data!.setFieldValue("gl_cogs_acct", fnmask$(read_tpl.gl_cogs_acct$(1,glAccount_size),glAccount_mask$))
		data!.setFieldValue("gl_pur_acct", fnmask$(read_tpl.gl_pur_acct$(1,glAccount_size),glAccount_mask$))
		data!.setFieldValue("gl_ppv_acct", fnmask$(read_tpl.gl_ppv_acct$(1,glAccount_size),glAccount_mask$))
		data!.setFieldValue("gl_inv_adj", fnmask$(read_tpl.gl_inv_adj$(1,glAccount_size),glAccount_mask$))
		data!.setFieldValue("gl_cogs_adj", fnmask$(read_tpl.gl_cogs_adj$(1,glAccount_size),glAccount_mask$))
		data!.setFieldValue("inv_desc", read_tpl.inv_desc$)
		data!.setFieldValue("cogs_desc", read_tpl.cogs_desc$)
		data!.setFieldValue("pur_desc", read_tpl.pur_desc$)
		data!.setFieldValue("ppv_desc", read_tpl.ppv_desc$)
		data!.setFieldValue("ivadj_desc", read_tpl.ivadj_desc$)
		data!.setFieldValue("cogsadj_desc", read_tpl.cogsadj_desc$)

		rs!.insert(data!)
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
	
	end
