[[GLT_BANKOTHER.ACUS]]
rem --- Process custom event

rem --- Handle grid pop-up menu selections
	dim gui_event$:tmpl(gui_dev)
	gui_event$=SysGUI!.getLastEventString()
	grid!=Form!.getControl(num(stbl("+GRID_CTL")))

	rem --- Verify event from grid
	if dec(gui_event.ID$) <> grid!.getID() then break; rem --- exit callpoint

	rem --- Get selected pop-up menu item
	popUpMenu!=grid!.getPopupMenu()
	menuItem!=popUpMenu!.getMenuItem(gui_event.y)
	itemText$=menuItem!.getText()
	tmpText$=itemText$+"( )"
	itemCode$=tmpText$(pos("("=tmpText$)+1)
	itemCode$=itemCode$(1,pos(")"=itemCode$)-1)
	item=gui_event.y-200

rem --- Update posted_code for selected grid rows
	col=7; rem --- posted_code grid column
	if itemCode$<>"" then
		gltBankOther_dev=fnget_dev("GLT_BANKOTHER")
		dim gltBankOther$:fnget_tpl$("GLT_BANKOTHER")
		selectedRows!=grid!.getSelectedRows()
		if selectedRows!.size()=0 then break
		for i=0 to selectedRows!.size()-1
			rem --- Update grid row
			row=selectedRows!.getItem(i)
			rem --- Check if current row and update "classically" if so
			if row=callpoint!.getValidationRow() then
				if callpoint!.getColumnData("GLT_BANKOTHER.POSTED_CODE")<>itemCode$ then
					callpoint!.setColumnData("GLT_BANKOTHER.POSTED_CODE",itemCode$,1)
					callpoint!.setStatus("MODIFIED")
				endif
			else
				grid!.setCellListSelection(row,col,item,1)
				rem --- Update record image, if necessary
 				gltBankOther$=GridVect!.getItem(row)
				if gltBankOther.posted_code$<>itemCode$ then
 					gltBankOther.posted_code$=itemCode$
					GridVect!.setItem(row,gltBankOther$)
					rem --- Set row as modified (disk icon)
					callpoint!.setGridRowModifyStatus(row,1)
				endif
			endif
		next i
	endif

[[GLT_BANKOTHER.AGRN]]
rem --- Update Total Amount for selected rows
	grid!=Form!.getControl(num(stbl("+GRID_CTL")))
	selectedRows!=grid!.getSelectedRows()
	if selectedRows!.size()=0 then break

	totalAmt=0
	dim gltBankOther$:fnget_tpl$("GLT_BANKOTHER")
	for i=0 to selectedRows!.size()-1
		row=selectedRows!.getItem(i)
		gltBankOther$=GridVect!.getItem(row)
		totalAmt=totalAmt+gltBankOther.trans_amt
	next i

	call stbl("+DIR_PGM")+"adc_getmask.aon","","GL","A","",m1$,0,m1 
	totalAmtCtrl!=callpoint!.getDevObject("totalAmtCtrl")
	totalAmtCtrl!.setText("Total Amount: "+cvs(str(totalAmt:m1$),3))

[[GLT_BANKOTHER.AOPT-UNDO]]
rem --- remove column sorting

	grid!=Form!.getControl(num(stbl("+GRID_CTL")))
	grid!.unsort()

[[GLT_BANKOTHER.AREA]]
rem --- Skip transactions after current statement date or if not same gl acct as entered on main form
	stmtdate$=callpoint!.getDevObject("stmtdate")
	glacct$=callpoint!.getDevObject("glacct")
	if callpoint!.getColumnData("GLT_BANKOTHER.TRNS_DATE")>stmtdate$ then
		callpoint!.setStatus("SKIP")
	endif
	if callpoint!.getColumnData("GLT_BANKOTHER.GL_ACCOUNT")<>glacct$ then
		callpoint!.setStatus("SKIP")
	endif

[[GLT_BANKOTHER.ASHO]]
rem ... Add Total Amount text control to navbar after Barista's buttons
	navWin!=Form!.getChildWindow(num(stbl("+NAVBAR_CTL")))
	ctrlVec!=navWin!.getAllControls()
	for i=0 to ctrlVec!.size()-1
		ctrl!=ctrlVec!.get(i)
		if ctrl!.getToolTipText()="Display additional options" then
			rem --- Barista's last navbar button
			break
		endif
	next i

	totalAmtCtrl!=navWin!.addStaticText(navWin!.getAvailableControlID(),ctrl!.getX()+40,ctrl!.getY()+5,175,ctrl!.getHeight(),"", $12001$)
	callpoint!.setDevObject("totalAmtCtrl",totalAmtCtrl!)

[[GLT_BANKOTHER.BEND]]
rem --- Let GLM_BANKMASTER form know this grid is no longer in use in case it was launched via All Transactions button
	rdFuncSpace!=BBjAPI().getGroupNamespace()
	rdFuncSpace!.removeValue(stbl("+USER_ID")+": GLT_BANKOTHER")

[[GLT_BANKOTHER.BSHO]]
rem --- Open/Lock files
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ART_DEPOSIT",open_opts$[1]="OTA@"

	gosub open_tables
	if status$ <> ""  then goto std_exit

rem --- Add pop-up menu to match ListButton items for posted_code
	popUpMenu!=SysGUI!.addPopupMenu()
	ldat$=callpoint!.getTableColumnAttribute("GLT_BANKOTHER.POSTED_CODE","LDAT")
	item=0
	xpos=pos(";"=ldat$)
	while xpos
		item$=ldat$(1,xpos-1)
		ldat$=ldat$(xpos+1)
		ypos=pos("~"=item$)
		desc$=cvs(item$(1,ypos-1),3)
		code$=cvs(item$(ypos+1),3)

		menuItem! = popUpMenu!.addMenuItem(-(200+item),desc$+" ("+code$+")")
		menuItem!.setCallback(menuItem!.ON_POPUP_ITEM_SELECT,"custom_event")
	
		item=item+1
		xpos=pos(";"=ldat$)
	wend

rem --- Make grid multi-select with pop-up menu
	grid!=Form!.getControl(num(stbl("+GRID_CTL")))
	grid!.setMultipleSelection(1)
	grid!.setSelectionMode(grid!.GRID_SELECT_ROW)
	grid!.setPopupMenu(popUpMenu!)

rem --- Make Number, Type, Trans Date, Amount, Cash Rec Cd and Code columns sortable by clicking on the Header
	grid!.setColumnUserSortable(0,1)
	grid!.setColumnUserSortable(1,1)
	grid!.setColumnUserSortable(2,1)
	grid!.setColumnUserSortable(4,1)
	grid!.setColumnUserSortable(5,1)
	grid!.setColumnUserSortable(7,1)
	grid!.setSortByMultipleColumns(1)

rem --- Get stmtdate in case launched via All Transactions button on GLM_BANKMASTER form
	rdFuncSpace!=BBjAPI().getGroupNamespace()
	stmtdate$=rdFuncSpace!.getValue(stbl("+USER_ID")+": BANKMASTER stmtdate",err=*next)
	glacct$=rdFuncSpace!.getValue(stbl("+USER_ID")+": BANKMASTER glacct",err=*next)
	callpoint!.setDevObject("stmtdate",stmtdate$)
	callpoint!.setDevObject("glacct",glacct$)

	rem --- Let GLM_BANKMASTER form know this grid is in use in case it was launched via All Transactions button
	rdFuncSpace!.setValue(stbl("+USER_ID")+": GLT_BANKOTHER","In Use")

[[GLT_BANKOTHER.CASH_REC_CD.AVAL]]
arm10_dev=fnget_dev("ARC_CASHCODE")
dim arm10c$:fnget_tpl$("ARC_CASHCODE")

wk_cash_cd$=callpoint!.getUserInput()

read record(arm10_dev,key=firm_id$+"C"+wk_cash_cd$,dom=*next)arm10c$
if arm10c.code_inactive$ = "Y"
	msg_id$="AR_CODE_INACTIVE"
	gosub disp_message
	callpoint!.setStatus("ABORT")
	break
endif

[[GLT_BANKOTHER.TRANS_NO.AVAL]]
rem --- Has the trans_no changed?
	trans_no$=callpoint!.getUserInput()
	if callpoint!.getColumnData("GLT_BANKOTHER.TRANS_NO")<>trans_no$ then
		rem --- Is this a Deposit trans_type"
		if callpoint!.getColumnData("GLT_BANKOTHER.TRANS_TYPE")="D" then
			rem --- Prevent re-using an existing DEPOSIT_ID
			deposit_dev=fnget_dev("@ART_DEPOSIT")
			deposit_tpl$=fnget_tpl$("@ART_DEPOSIT")
			deposit_id$=trans_no$
			found_deposit=0
			find(deposit_dev,key=firm_id$+deposit_id$,dom=*next); found_deposit=1
			if found_deposit then
				rem --- Warn DEPOSIT_ID has already been used
				msg_id$="AR_DEPOSIT_USED"
				gosub disp_message
				if msg_opt$="Y" then
					rem --- Assign next new DEPOSIT_ID
					call stbl("+DIR_SYP")+"bas_sequences.bbj","DEPOSIT_ID",deposit_id$,rd_table_chans$[all],"QUIET"
					callpoint!.setUserInput(deposit_id$)
				else
					callpoint!.setStatus("ABORT")
					break
				endif
			endif
		endif
	endif

[[GLT_BANKOTHER.TRANS_TYPE.AVAL]]
rem --- Has the trans_type changed?
	trans_type$=callpoint!.getUserInput()
	if callpoint!.getColumnData("GLT_BANKOTHER.TRANS_TYPE")<>trans_type$ then
		rem --- Is this a Deposit trans_type"
		if trans_type$="D" then
			rem --- Prevent re-using an existing DEPOSIT_ID
			deposit_dev=fnget_dev("@ART_DEPOSIT")
			deposit_tpl$=fnget_tpl$("@ART_DEPOSIT")
			deposit_id$=callpoint!.getColumnData("GLT_BANKOTHER.TRANS_NO")
			found_deposit=0
			find(deposit_dev,key=firm_id$+deposit_id$,dom=*next); found_deposit=1
			if found_deposit then
				rem --- Warn DEPOSIT_ID has already been used
				msg_id$="AR_DEPOSIT_USED"
				gosub disp_message
				if msg_opt$="Y" then
					rem --- Assign next new DEPOSIT_ID
					call stbl("+DIR_SYP")+"bas_sequences.bbj","DEPOSIT_ID",deposit_id$,rd_table_chans$[all],"QUIET"
					callpoint!.setColumnData("GLT_BANKOTHER.TRANS_NO",deposit_id$,1)
				else
					callpoint!.setStatus("ABORT")
					break
				endif
			endif

			rem --- Endisable the Cash Receipt Code column when the TRANS_TYPE=D.
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"GLT_BANKOTHER.CASH_REC_CD",1)
		else
			rem --- Clear and disable the Cash Receipt Code column when the TRANS_TYPE<>D.
			callpoint!.setColumnData("GLT_BANKOTHER.CASH_REC_CD","",1)
			callpoint!.setColumnEnabled(callpoint!.getValidationRow(),"GLT_BANKOTHER.CASH_REC_CD",0)
		endif
	endif



