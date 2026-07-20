[[ADM_RPTDIRDET.MODULE.AVAL]]
rem --- Verify a valid module ID was entered
	prod_id$=pad(callpoint!.getUserInput(),3)
	armModules_dev=fnget_dev("ADM_MODULES")
	dim armModules$:fnget_tpl$("ADM_MODULES")

	found=0
	findrecord(armModules_dev,key=stbl("+AON_APPCOMPANY",err=*next)+prod_id$,dom=*next)armModules$
	if armModules.asc_prod_id$=prod_id$ then
		found=1
	else
		rem --- Look for module in other applications besides Addon
		read(armModules_dev,key="",dom=*next)
		while 1
			redim armModules$
			readrecord(armModules_dev,end=*break)armModules$
			if armModules.asc_prod_id$=prod_id$ then
				found=1
				break
			endif
		wend
	endif

	if !found then
		message$=Translate!.getTranslation("AON_MODULE")+" "+Translate!.getTranslation("AON_NOT_FOUND")
		msg_id$="GENERIC_WARN"
		dim msg_tokens$[1]
		msg_tokens$[1]=Translate!.getTranslation("AON_MODULE")+" "+Translate!.getTranslation("AON_NOT_FOUND")
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



