[[MPM_FORECAST.BSHO]]
rem --- Open/Lock files

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SFC_WOTYPECD",open_opts$[1]="OTA"

	gosub open_tables

[[MPM_FORECAST.WO_TYPE.AVAL]]
rem --- Don't allow inactive code
	sfcWOType_dev=fnget_dev("SFC_WOTYPECD")
	dim sfcWOType$:fnget_tpl$("SFC_WOTYPECD")
	wo_type$=callpoint!.getUserInput()
	read record (sfcWOType_dev,key=firm_id$+"A"+wo_type$,dom=*next)sfcWOType$
	if sfcWOType.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(sfcWOType.wo_type$,3)
		msg_tokens$[2]=cvs(sfcWOType.code_desc$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif



