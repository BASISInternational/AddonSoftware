[[GLM_FINCOLUMNS.AGDR]]
rem --- Disable all the other cells if the PER_TYPE_CDE is blank
	per_type_cde$=cvs(callpoint!.getUserInput(),2)
	if per_type_cde$="X" or cvs(per_type_cde$,2)="" then
		rem --- Disable and clear cells
		status=0
		row=callpoint!.getValidationRow()
		callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.ACTBUD",status)
		callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.AMT_OR_UNITS",status)
		callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.HEADING",status)
		callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.HEAD_ALIGNMENT",status)
		callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.HEAD_SPAN_COLS",status)
		callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.RATIOPCT",status)
	endif

[[GLM_FINCOLUMNS.HEAD_ALIGNMENT.AVAL]]
rem --- Verify only valid characters used
	chars$=callpoint!.getUserInput()
	validChars$="LRC^"
	gosub validate_chars
	if bad_char then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Verify valid alignment entered
	bad_align=0
	while chars$<>""
		rem --- Strip leading ^
		while chars$<>"" and chars$(1,1)="^"
			if len(chars$)=1 then
				chars$=""
			else
				chars$=chars$(2)
			endif
		wend
		rem --- Get alignment for next line of heading
		pos=pos("^"=chars$)
		if pos then
			align$=chars$(1,pos-1)
			chars$=chars$(pos)
		else
			align$=chars$
			chars$=""
		endif
		Rem --- Only single character alignment codes are allowed
		if len(align$)>1 then
			bad_align=1
			break
		endif
	wend
	if bad_align then
		msg_id$="AD_INVALID_ALIGN"
		dim msg_tokens$[1]
		msg_tokens$[1]=align$
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[GLM_FINCOLUMNS.HEAD_SPAN_COLS.AVAL]]
rem --- Verify only valid characters used
	chars$=callpoint!.getUserInput()
	validChars$="0123456789^"
	gosub validate_chars
	if bad_char then
		callpoint!.setStatus("ABORT")
		break
	endif

rem --- Verify valid number of columns entered
	colmax=8
	g!=form!.getControl(num(stbl("+GRID_CTL")))
	col=g!.getSelectedRow()+1; rem --- current column
	bad_cols=0
	while chars$<>""
		rem --- Strip leading ^
		while chars$<>"" and chars$(1,1)="^"
			if len(chars$)=1 then
				chars$=""
			else
				chars$=chars$(2)
			endif
		wend
		rem --- Get number of columns for next line of heading
		spanCols=0
		pos=pos("^"=chars$)
		if pos then
			spanCols=num(chars$(1,pos-1),err=*next)
			chars$=chars$(pos)
		else
			spanCols=num(chars$,err=*next)
			chars$=""
		endif
		Rem --- Can't span more columns than there are columns left to span
		if spanCols>colmax-col+1 then
			bad_cols=1
			break
		endif
	wend
	if bad_cols then
		msg_id$="AD_INVALID_SPAN_COLS"
		dim msg_tokens$[2]
		msg_tokens$[1]=str(spanCols)
		msg_tokens$[2]=str(colmax-col+1)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[GLM_FINCOLUMNS.PER_TYPE_CDE.AVAL]]
rem --- Disable all the other cells if the PER_TYPE_CDE is blank
	per_type_cde$=cvs(callpoint!.getUserInput(),2)
	if per_type_cde$="X" or cvs(per_type_cde$,2)="" then
		rem --- Disable and clear cells
		status=0
		callpoint!.setColumnData("GLM_FINCOLUMNS.ACTBUD","",1)
		callpoint!.setColumnData("GLM_FINCOLUMNS.AMT_OR_UNITS","",1)
		callpoint!.setColumnData("GLM_FINCOLUMNS.HEADING","",1)
		callpoint!.setColumnData("GLM_FINCOLUMNS.HEAD_ALIGNMENT","",1)
		callpoint!.setColumnData("GLM_FINCOLUMNS.HEAD_SPAN_COLS","1",1)
		callpoint!.setColumnData("GLM_FINCOLUMNS.RATIOPCT","",1)
	else
		rem --- Enable cells
		status=1
	endif
	row=callpoint!.getValidationRow()
	callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.ACTBUD",status)
	callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.AMT_OR_UNITS",status)
	callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.HEADING",status)
	callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.HEAD_ALIGNMENT",status)
	callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.HEAD_SPAN_COLS",status)
	callpoint!.setColumnEnabled(row,"GLM_FINCOLUMNS.RATIOPCT",status)

[[GLM_FINCOLUMNS.<CUSTOM>]]
validate_chars: rem --- Verify only valid characters entered
	bad_char=0
	pos=len(chars$)
	while pos
		if pos(chars$(pos,1)=validChars$)=0 then break
		pos=pos-1
	wend
	if pos
		msg_id$="AD_INVALID_CHAR"
		dim msg_tokens$[2]
		msg_tokens$[1]=chars$(pos,1)
		msg_tokens$[2]=validChars$
		gosub disp_message
		bad_char=1
	endif
	return



