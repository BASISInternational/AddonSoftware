[[ADX_UPGRADEWIZ.ACUS]]
rem --- Process custom event

rem This routine is executed when callbacks have been set to run a 'custom event'.
rem Analyze gui_event$ and notice$ to see which control's callback triggered the event, and what kind of event it is.
rem See basis docs notice() function, noticetpl() function, notify event, grid control notify events for more info.

	dim gui_event$:tmpl(gui_dev)
	dim notify_base$:noticetpl(0,0)
	gui_event$=SysGUI!.getLastEventString()
	ctl_ID=dec(gui_event.ID$)

	if gui_event.code$="N"
		notify_base$=notice(gui_dev,gui_event.x%)
		dim notice$:noticetpl(notify_base.objtype%,gui_event.flags%)
		notice$=notify_base$
	endif

	rem --- Edit app grid
	if ctl_ID=num(callpoint!.getDevObject("app_grid_id")) then

		e!=SysGUI!.getLastEvent()
		appGrid!=callpoint!.getDevObject("appGrid")
		appRowVect!=callpoint!.getDevObject("appRowVect")
		app_grid_def_cols=num(callpoint!.getDevObject("app_grid_def_cols"))
		index=e!.getRow()*app_grid_def_cols

		switch notice.code
			case 7; rem --- ON_GRID_EDIT_STOP
				rem --- Capture changes to app target
				if e!.getColumn()=5 then
					rem --- Modified target
					target$=cvs(appGrid!.getCellText(e!.getRow(),5),3)
					if target$<>appRowVect!.getItem(index+5) then
						rem --- Update appRowVect! for modified target
						appRowVect!.removeItem(index+5)
						appRowVect!.insertItem(index+5, target$); rem Target

						rem --- Update stblRowVect! for modified target (remove old, add new)
						stblRowVect!=callpoint!.getDevObject("stblRowVect")
						appName$=appRowVect!.get(index+0)
						gosub remove_app_stbl_vector; rem --- remove old rows
						oldDir$=appRowVect!.get(index+4)
						synFile$=oldDir$+"config/"+cvs(appName$,8)+".syn"
						newDir$=target$
						gosub build_stbl_vector; rem --- add new rows
						callpoint!.setDevObject("stblRowVect",stblRowVect!)
						gosub fill_stbl_grid
					endif
				endif
			break
			case 12; rem --- ON_GRID_KEY_PRESS
				rem ---  Allow space-bar toggle of checkboxes
				if (e!.getColumn()=2 or e!.getColumn()=3) and notice.wparam=32 then
					onoff=iff(appGrid!.getCellState(e!.getRow(),e!.getColumn()),0,1)
					gosub update_app_grid
				endif
			break
			case 30; rem --- ON_GRID_CHECK_ON and ON_GRID_CHECK_OFF
				rem --- isChecked() is the state when event sent before control is updated,
				rem --- so use !isChecked() to get current state of control
				if e!.getColumn()=2 or e!.getColumn()=3 then
					onoff=!e!.isChecked()
					gosub update_app_grid
				endif
			break
		swend
	endif

	rem --- Edit stbl grid
	if ctl_ID=num(callpoint!.getDevObject("stbl_grid_id")) then

		e!=SysGUI!.getLastEvent()
		stblGrid!=callpoint!.getDevObject("stblGrid")
		stblRowVect!=callpoint!.getDevObject("stblRowVect")
		stbl_grid_def_cols=num(callpoint!.getDevObject("stbl_grid_def_cols"))
		index=e!.getRow()*stbl_grid_def_cols

		switch notice.code
			case 7; rem --- ON_GRID_EDIT_STOP
				rem --- Capture changes to STBL target
				if e!.getColumn()=3 then
					rem --- Update stblRowVect! for modified target
					if cvs(stblGrid!.getCellText(e!.getRow(),0),3)="ADDON" then
						rem --- This row is for the ADDON application
						stbl$=pad(cvs(stblGrid!.getCellText(e!.getRow(),1),3),7)
						if stbl$(1,1)="+" and stbl$(4)="DATA" then
							rem --- This is an Addon +??DATA STBL
							if cvs(stblGrid!.getCellText(e!.getRow(),2),3)=cvs(stblGrid!.getCellText(e!.getRow(),3),3) then

								rem --- Have we shown a warning about same data paths before? 
								if callpoint!.getDevObject("same_dir_ok")="Y" then 
									break
								endif 

								rem --- Warn paths are the same and ask if that's correct
								msg_id$="AD_SAME_DATA_PATH"
								gosub disp_message
								if pos("Y"=msg_opt$)<>0 then 
									if pos("PASSVALID"=msg_opt$)<>0 then 
										callpoint!.setDevObject("same_dir_ok","Y")
									endif
								else 
									rem --- Not correct, restore previous value
									previousText$=stblRowVect!.getItem(index+3)
									stblGrid!.setCellText(e!.getRow(),3,previousText$)
								endif
							endif
						endif
					endif
					stblRowVect!.removeItem(index+3)
					stblRowVect!.insertItem(index+3, cvs(stblGrid!.getCellText(e!.getRow(),3),3)); rem Target
				endif
			break
		swend
	endif

[[ADX_UPGRADEWIZ.ADIS]]
rem --- Initialize old Barista admin_backup
	bar_dir$=cvs(callpoint!.getColumnData("ADX_UPGRADEWIZ.OLD_BAR_LOC"),3)+"/barista"
	gosub able_backup_sync_dir

rem --- Reload saved grid info if there is any for entered aon locations.
	adw_upgradewiz=fnget_dev("ADW_UPGRADEWIZ")
	dim adw_upgradewiz$:fnget_tpl$("ADW_UPGRADEWIZ")
	new_aon_loc$=callpoint!.getColumnData("ADX_UPGRADEWIZ.NEW_AON_LOC")
	old_aon_loc$=callpoint!.getColumnData("ADX_UPGRADEWIZ.OLD_AON_LOC")

	adw_upgradewiz.new_aon_loc$=new_aon_loc$
	adw_upgradewiz.old_aon_loc$=old_aon_loc$
	key$=adw_upgradewiz.new_aon_loc$+adw_upgradewiz.old_aon_loc$
	read(adw_upgradewiz,key=key$,dom=*next)
	adw_upgradewiz_key$=key(adw_upgradewiz,end=*next)
	if pos(key$=adw_upgradewiz_key$)=1 then
		appRowVect!=SysGUI!.makeVector()
		callpoint!.setDevObject("appRowVect",appRowVect!)
		stblRowVect!=SysGUI!.makeVector()
		callpoint!.setDevObject("stblRowVect",stblRowVect!)

		rem --- Reload saved APP grid info
		adw_upgradewiz.new_aon_loc$=new_aon_loc$
		adw_upgradewiz.old_aon_loc$=old_aon_loc$
		adw_upgradewiz.grid_id$="APP"
		key$=adw_upgradewiz.new_aon_loc$+adw_upgradewiz.old_aon_loc$+adw_upgradewiz.grid_id$
		read(adw_upgradewiz,key=key$,dom=*next)
		while 1
			adw_upgradewiz_key$=key(adw_upgradewiz,end=*break)
			if pos(key$=adw_upgradewiz_key$)<>1 then break
			readrecord(adw_upgradewiz)adw_upgradewiz$
			appRowVect!.addItem(cvs(adw_upgradewiz.app_id$,2))
			appRowVect!.addItem(cvs(adw_upgradewiz.app_parent$,2))
			appRowVect!.addItem(cvs(adw_upgradewiz.install$,2))
			appRowVect!.addItem(cvs(adw_upgradewiz.copy$,2))
			appRowVect!.addItem(cvs(adw_upgradewiz.source$,2))
			appRowVect!.addItem(cvs(adw_upgradewiz.target$,2))
		wend
		callpoint!.setDevObject("appRowVect",appRowVect!)
		skipStblVectorBuild=1
		gosub fill_app_grid

		rem --- Reload saved STBL grid info
		adw_upgradewiz.new_aon_loc$=new_aon_loc$
		adw_upgradewiz.old_aon_loc$=old_aon_loc$
		adw_upgradewiz.grid_id$="STBL"
		key$=adw_upgradewiz.new_aon_loc$+adw_upgradewiz.old_aon_loc$+adw_upgradewiz.grid_id$
		read(adw_upgradewiz,key=key$,dom=*next)
		while 1
			adw_upgradewiz_key$=key(adw_upgradewiz,end=*break)
			if pos(key$=adw_upgradewiz_key$)<>1 then break
			readrecord(adw_upgradewiz)adw_upgradewiz$
			stblRowVect!.addItem(cvs(adw_upgradewiz.app_id$,2))
			stblRowVect!.addItem(cvs(adw_upgradewiz.stbl_prefix$,2))
			stblRowVect!.addItem(cvs(adw_upgradewiz.source$,2))
			stblRowVect!.addItem(cvs(adw_upgradewiz.target$,2))
		wend
		callpoint!.setDevObject("stblRowVect",stblRowVect!)
		gosub fill_stbl_grid

		callpoint!.setStatus("REFRESH")
	endif

[[ADX_UPGRADEWIZ.AREC]]
rem --- Clear custom APP grid
	appRowVect!=SysGUI!.makeVector()
	callpoint!.setDevObject("appRowVect",appRowVect!)
	appGrid!=callpoint!.getDevObject("appGrid")
	appGrid!.clearMainGrid()

rem --- Clear custom STBL grid
	stblRowVect!=SysGUI!.makeVector()
	callpoint!.setDevObject("stblRowVect",stblRowVect!)
	stblGrid!=callpoint!.getDevObject("stblGrid")
	stblGrid!.clearMainGrid()

[[ADX_UPGRADEWIZ.ASHO]]
rem --- Don't allow running the utility if not launched from Addon demo system under Basis download location
	ddm_systems=fnget_dev("DDM_SYSTEMS")
	dim ddm_systems$:fnget_tpl$("DDM_SYSTEMS")
	readrecord(ddm_systems,key=pad("ADDON",16," "),knum="SYSTEM_ID",err=*next)ddm_systems$
	aonDir!=new java.io.File(ddm_systems.mount_dir$)
	aonDir$=aonDir!.getCanonicalPath()

	demoDir!=new java.io.File(System.getProperty("basis.BBjHome")+"/apps/aon")
	demoDir$=demoDir!.getCanonicalPath()

	if aonDir$<>demoDir$ then
		msg_id$="AD_MUST_BE_DEMO_SYS"
		dim msg_tokens$[1]
		msg_tokens$[1]=demoDir$
		gosub disp_message
		callpoint!.setStatus("EXIT")
	endif

rem --- The Install Wizard must be run directly on the server where the Addon demo is installed.
	if num(info(3,6))<>0 and num(info(3,6))<>1 then
		msg_id$="AD_NOT_ON_SERVER"
		dim msg_tokens$[1]
		msg_tokens$[1]=demoDir$
		gosub disp_message
		callpoint!.setStatus("EXIT")
		break
	endif

[[ADX_UPGRADEWIZ.ASIZ]]
rem --- Resize grids

	formHeight=Form!.getHeight()
	formWidth=Form!.getWidth()
	appGrid!=callpoint!.getDevObject("appGrid")
	appYpos=appGrid!.getY()
	appXpos=appGrid!.getX()
	availableHeight=formHeight-appYpos
	appHeight=int((availableHeight-15)/4)
	stblYpos=200+appHeight+15
	stblHeight=int(3*(availableHeight-15)/4)

	rem --- Resize application grid
	appGrid!.setSize(formWidth-2*appXpos,appHeight)
	appGrid!.setFitToGrid(1)

	rem --- Resize STBL grid
	stblGrid!=callpoint!.getDevObject("stblGrid")
	stblGrid!.setLocation(10,stblYpos)
	stblGrid!.setSize(formWidth-2*appXpos,stblHeight)
	stblGrid!.setFitToGrid(1)

[[ADX_UPGRADEWIZ.ASVA]]
rem --- Validate new database name

	db_name$ = callpoint!.getColumnData("ADX_UPGRADEWIZ.DB_NAME")
	gosub validate_new_db_name
	callpoint!.setColumnData("ADX_UPGRADEWIZ.DB_NAME",db_name$)
	if abort then
		callpoint!.setFocus("ADX_UPGRADEWIZ.DB_NAME")
		break
	endif

rem --- Validate Repository
	gitAuthID$=cvs(callpoint!.getColumnData("ADX_UPGRADEWIZ.GIT_AUTH_ID"),3)
	gosub validate_git_auth_id

rem --- Validate this is an officicial (tagged) release, not an RC
	gitAuthID$=cvs(callpoint!.getColumnData("ADX_UPGRADEWIZ.GIT_AUTH_ID"),3)
	gosub validate_release_tag

rem --- Validate base directory for installation

	new_loc$ = callpoint!.getColumnData("ADX_UPGRADEWIZ.BASE_DIR")
	gosub validate_base_dir
	callpoint!.setColumnData("ADX_UPGRADEWIZ.BASE_DIR", new_loc$)
	callpoint!.setColumnData("ADX_UPGRADEWIZ.NEW_AON_LOC",new_loc$+"/"+major_ver$+"/"+minor_ver$,1)
	if abort then break

rem --- Validate old aon install location

	old_aon_loc$ = callpoint!.getColumnData("ADX_UPGRADEWIZ.OLD_AON_LOC")
	gosub validate_old_aon_loc
	callpoint!.setColumnData("ADX_UPGRADEWIZ.OLD_AON_LOC",old_aon_loc$)
	if abort then
		callpoint!.setFocus("ADX_UPGRADEWIZ.OLD_AON_LOC")
		break
	endif

rem --- Validate old barista install location

	old_bar_loc$ = callpoint!.getColumnData("ADX_UPGRADEWIZ.OLD_BAR_LOC")
	gosub validate_old_bar_loc
	callpoint!.setColumnData("ADX_UPGRADEWIZ.OLD_BAR_LOC",old_bar_loc$)
	if abort then break

rem --- Validate sync backup directory when doing Create Sync File Backup

	if callpoint!.getDevObject("do_sync_backup")<>0 then
		sync_backup_dir$ = callpoint!.getColumnData("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR")
		gosub validate_sync_backup_dir
		callpoint!.setColumnData("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR",sync_backup_dir$)
		if abort then break
	endif

rem --- Make sure we get all entries in the grid by setting focus on some control besides the grid

	ctl!=callpoint!.getControl("ADX_UPGRADEWIZ.NEW_AON_LOC")
	ctl!.focus()

rem --- Capture app grid in Vector (order is important) for backend programs

	declare Vector appVect!
	declare ArrayList aList!

	appVect!=new Vector()
	appRowVect!=callpoint!.getDevObject("appRowVect")
	app_grid_def_cols=num(callpoint!.getDevObject("app_grid_def_cols"))

	for i=0 to appRowVect!.size()-1 step app_grid_def_cols
		aList!=new ArrayList()
		aList!.add(appRowVect!.getItem(i+0)); rem Application
		aList!.add(appRowVect!.getItem(i+1)); rem App Parent
		aList!.add(appRowVect!.getItem(i+2)); rem Install
		aList!.add(appRowVect!.getItem(i+3)); rem Copy
		aList!.add(appRowVect!.getItem(i+4)); rem Source
		aList!.add(appRowVect!.getItem(i+5)); rem Target
		appVect!.add(aList!)
	next i

	callpoint!.setDevObject("appVect",appVect!)

rem --- Capture stbl grid in data structure for backend programs

	declare HashMap appStblMap!
	declare Vector stblVect!

	appStblMap!=new HashMap()
	stblRowVect!=callpoint!.getDevObject("stblRowVect")
	stbl_grid_def_cols=num(callpoint!.getDevObject("stbl_grid_def_cols"))

	for i=0 to stblRowVect!.size()-1 step stbl_grid_def_cols
		aList!=new ArrayList()
		aList!.add(stblRowVect!.getItem(i+0)); rem Application
		aList!.add(stblRowVect!.getItem(i+1)); rem STBL or <prefix>
		aList!.add(stblRowVect!.getItem(i+2)); rem Source
		aList!.add(stblRowVect!.getItem(i+3)); rem Target

		app$=stblRowVect!.getItem(i+0)
		if appStblMap!.containsKey(app$) then
			stblVect! = cast(Vector, appStblMap!.get(app$))
			stblVect!.add(aList!)
		else
			stblVect! = new Vector()
			stblVect!.add(aList!)
			appStblMap!.put(app$, stblVect!)
		endif
	next i

	callpoint!.setDevObject("appStblMap",appStblMap!)

rem --- Clear ADW_UPGRADEWIZ records that do NOT have a corresponding entry in Barista's ADS_SELOPTS table.
rem --- Must do this before saving grid info in ADW_UPGRADEWIZ because !LAST_PROCESS record isn't written to ADS_SELOPTS until after ASVA.
	adw_upgradewiz=fnget_dev("ADW_UPGRADEWIZ")
	dim adw_upgradewiz$:fnget_tpl$("ADW_UPGRADEWIZ")
	ads_selopts=fnget_dev("ADS_SELOPTS")
	dim ads_selopts$:fnget_tpl$("ADS_SELOPTS")

	read(adw_upgradewiz,key="",dom=*next)
	while 1
		readrecord(adw_upgradewiz,end=*break)adw_upgradewiz$
		new_aon_loc$=adw_upgradewiz.new_aon_loc$
		old_aon_loc$=adw_upgradewiz.old_aon_loc$

		clear_records=1
		read(ads_selopts,key="ADX_UPGRADEWIZ",dom=*next)
		while 1
			ads_selopts_key$=key(ads_selopts,end=*break)
			if pos("ADX_UPGRADEWIZ"=ads_selopts_key$)<>1 then break
			readrecord(ads_selopts)ads_selopts$
			if pos("^"+cvs(new_aon_loc$,2)+"^"+cvs(old_aon_loc$,2)+"^"=ads_selopts.selection_opts$) then
				clear_records=0
				break
			endif
		wend

		if clear_records then
			adw_upgradewiz.new_aon_loc$=new_aon_loc$
			adw_upgradewiz.old_aon_loc$=old_aon_loc$
			key$=adw_upgradewiz.new_aon_loc$+adw_upgradewiz.old_aon_loc$
			read(adw_upgradewiz,key=key$,dom=*next)
			while 1
				adw_upgradewiz_key$=key(adw_upgradewiz,end=*break)
				if pos(key$=adw_upgradewiz_key$)<>1 then break
				remove(adw_upgradewiz,key=adw_upgradewiz_key$,dom=*next)
			wend
		endif
	wend

rem --- Save grid info in ADW_UPGRADEWIZ so it can be reloaded again.
rem --- Must do this after clearing orphan ADW_UPGRADEWIZ records because !LAST_PROCESS record isn't written to ADS_SELOPTS until after ASVA.
	adw_upgradewiz=fnget_dev("ADW_UPGRADEWIZ")
	dim adw_upgradewiz$:fnget_tpl$("ADW_UPGRADEWIZ")
	new_aon_loc$=callpoint!.getColumnData("ADX_UPGRADEWIZ.NEW_AON_LOC")
	old_aon_loc$=callpoint!.getColumnData("ADX_UPGRADEWIZ.OLD_AON_LOC")

	rem --- Save APP grid info
	appRowVect!=callpoint!.getDevObject("appRowVect")
	app_grid_def_cols=num(callpoint!.getDevObject("app_grid_def_cols"))
	for i=0 to appRowVect!.size()-1 step app_grid_def_cols
		redim adw_upgradewiz$
		adw_upgradewiz.new_aon_loc$=new_aon_loc$
		adw_upgradewiz.old_aon_loc$=old_aon_loc$
		adw_upgradewiz.grid_id$="APP"
		adw_upgradewiz.row$=str(i/app_grid_def_cols:"000")
		adw_upgradewiz.app_id$=appRowVect!.getItem(i+0)
		adw_upgradewiz.app_parent$=appRowVect!.getItem(i+1)
		adw_upgradewiz.install$=appRowVect!.getItem(i+2)
		adw_upgradewiz.copy$=appRowVect!.getItem(i+3)
		adw_upgradewiz.stbl_prefix$=""
		adw_upgradewiz.source$=appRowVect!.getItem(i+4)
		adw_upgradewiz.target$=appRowVect!.getItem(i+5)
		writerecord(adw_upgradewiz)adw_upgradewiz$
	next i

	rem --- Save STBL grid info
	stblRowVect!=callpoint!.getDevObject("stblRowVect")
	stbl_grid_def_cols=num(callpoint!.getDevObject("stbl_grid_def_cols"))
	for i=0 to stblRowVect!.size()-1 step stbl_grid_def_cols
		redim adw_upgradewiz$
		adw_upgradewiz.new_aon_loc$=new_aon_loc$
		adw_upgradewiz.old_aon_loc$=old_aon_loc$
		adw_upgradewiz.grid_id$="STBL"
		adw_upgradewiz.row$=str(i/stbl_grid_def_cols:"000")
		adw_upgradewiz.app_id$=stblRowVect!.getItem(i+0)
		adw_upgradewiz.app_parent$=""
		adw_upgradewiz.install$=""
		adw_upgradewiz.copy$=""
		adw_upgradewiz.stbl_prefix$=stblRowVect!.getItem(i+1)
		adw_upgradewiz.source$=stblRowVect!.getItem(i+2)
		adw_upgradewiz.target$=stblRowVect!.getItem(i+3)
		writerecord(adw_upgradewiz)adw_upgradewiz$
	next i

[[ADX_UPGRADEWIZ.AWIN]]
rem --- Add grids to form

	use ::ado_util.src::util

	rem --- Get column headings for grids
	aon_application_label$=Translate!.getTranslation("AON_APPLICATION")
	aon_app_parent_label$=Translate!.getTranslation("AON_APP_PARENT")
	aon_copy_label$=Translate!.getTranslation("AON_COPY")
	aon_install_label$=Translate!.getTranslation("AON_INSTALL")
	aon_source_label$=Translate!.getTranslation("AON_SOURCE")
	aon_stbl_prefix_lable$=Translate!.getTranslation("AON_STBL_PREFIX")
	aon_target_label$=Translate!.getTranslation("AON_TARGET")

	rem --- Add grid to form for applications to be copied and/or installed
	nxt_ctlID=num(stbl("+CUSTOM_CTL",err=std_error))
	appGrid!=Form!.addGrid(nxt_ctlID,10,200,850,80); rem --- ID, x, y, width, height
	callpoint!.setDevObject("appGrid",appGrid!)
	callpoint!.setDevObject("app_grid_id",str(nxt_ctlID))
	callpoint!.setDevObject("app_grid_def_cols",6)
	callpoint!.setDevObject("app_grid_min_rows",4)
	gosub format_app_grid
	appGrid!.setColumnStyle(2,SysGUI!.GRID_STYLE_UNCHECKED)
	appGrid!.setColumnEditable(2,1)
	appGrid!.setColumnStyle(3,SysGUI!.GRID_STYLE_UNCHECKED)
	appGrid!.setColumnEditable(3,1)
	appGrid!.setColumnEditable(5,1)
	appGrid!.setTabAction(SysGUI!.GRID_NAVIGATE_LEGACY)

	rem --- Add grid to form for updating STBLs and PREFIXs with paths
	nxt_ctlID=num(stbl("+CUSTOM_CTL",err=std_error))+1
	stblGrid!=Form!.addGrid(nxt_ctlID,10,295,850,250); rem --- ID, x, y, width, height
	callpoint!.setDevObject("stblGrid",stblGrid!)
	callpoint!.setDevObject("stbl_grid_id",str(nxt_ctlID))
	callpoint!.setDevObject("stbl_grid_def_cols",4)
	callpoint!.setDevObject("stbl_grid_min_rows",16)
	gosub format_stbl_grid
	stblGrid!.setColumnEditable(3,1)
	stblGrid!.setTabAction(SysGUI!.GRID_NAVIGATE_LEGACY)

	rem --- misc other init
	util.resizeWindow(Form!, SysGui!)

	rem --- set callbacks - processed in ACUS callpoint
	appGrid!.setCallback(appGrid!.ON_GRID_CHECK_ON,"custom_event")
	appGrid!.setCallback(appGrid!.ON_GRID_CHECK_OFF,"custom_event")
	appGrid!.setCallback(appGrid!.ON_GRID_KEY_PRESS,"custom_event")
	rem --- Currently ON_GRID_CELL_EDIT_STOP results in the loss of user input when 
	rem --- they Run Process (F5) before leaving the cell where text was entered.
	appGrid!.setCallback(appGrid!.ON_GRID_EDIT_STOP,"custom_event")
	rem --- Currently ON_GRID_CELL_EDIT_STOP results in the loss of user input when 
	rem --- they Run Process (F5) before leaving the cell where text was entered.
	stblGrid!.setCallback(stblGrid!.ON_GRID_EDIT_STOP,"custom_event")

[[ADX_UPGRADEWIZ.BASE_DIR.AVAL]]
rem --- Validate base directory for installation

	new_loc$ = callpoint!.getUserInput()
	gosub validate_base_dir
	if abort then
		callpoint!.setStatus("ABORT")
		break
	endif
	callpoint!.setUserInput(new_loc$)

rem --- Update new install loc
	major_ver$=callpoint!.getDevObject("major_ver")
	minor_ver$=callpoint!.getDevObject("minor_ver")
	new_aon_loc$=new_loc$+"/"+major_ver$+"/"+minor_ver$
	callpoint!.setColumnData("ADX_UPGRADEWIZ.NEW_AON_LOC",new_aon_loc$,1)

rem --- Set defaults for data STBLs
	prev_new_aon_loc$=cvs(callpoint!.getDevObject("prev_new_aon_loc"),3)
	prev_old_aon_loc$=cvs(callpoint!.getDevObject("prev_old_aon_loc"),3)
	if cvs(new_aon_loc$,3)<>prev_new_aon_loc$ then
		updateTargetPaths=1
		if prev_new_aon_loc$<>"" and prev_old_aon_loc$<>"" then
			msg_id$="AD_UPDT_TARGET_PATH"
			gosub disp_message
			if msg_opt$<>"Y"then
				updateTargetPaths=0
			endif
		endif

		rem --- Capture new aon location value so can tell later if it's been changed
		callpoint!.setDevObject("prev_new_aon_loc",new_aon_loc$)

		if updateTargetPaths then
			rem --- Initialize aon directory from new aon location
			filePath$=new_aon_loc$
			gosub fix_path
			aonNewDir$=filePath$+"/aon/"

			rem --- Use addon.syn file from BASIS product download location
			bbjHome$ = System.getProperty("basis.BBjHome")
			aonSynFile$=bbjHome$+"/apps/aon/config/addon.syn"

			rem --- Initialize STBL grid for ADDON, i.e. set defaults for data STBLs
			stblRowVect!=SysGUI!.makeVector()
			newDir$=aonNewDir$
			synFile$=aonSynFile$
			callpoint!.setColumnData("ADX_UPGRADEWIZ.BASE_DIR",new_loc$,1)
			gosub build_stbl_vector
			callpoint!.setDevObject("newSynRows",stblRowVect!)
			if prev_old_aon_loc$<>"" then
				gosub init_stbl_grid
				util.resizeWindow(Form!, SysGui!)
				callpoint!.setStatus("REFRESH")
			endif
		endif
	endif
	

[[ADX_UPGRADEWIZ.BSHO]]
rem --- Declare Java classes used

	use java.io.File
	use java.util.ArrayList
	use java.util.HashMap
	use java.util.Iterator
	use java.util.Vector
	use ::ado_file.src::FileObject
	use ::adx_upgradewiz.aon::AppHeritage
	use ::ado_GitRepoInterface.aon::GitRepoInterface

rem --- Initialize location values so can tell later if they have changed

	callpoint!.setDevObject("prev_new_aon_loc","")
	callpoint!.setDevObject("prev_old_aon_loc","")
	callpoint!.setDevObject("prev_old_bar_loc","")

rem --- Open/Lock files

	num_files=4
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ADM_MODULES",open_opts$[1]="OTA"
	open_tables$[2]="DDM_SYSTEMS",open_opts$[2]="OTA"
	open_tables$[3]="ADW_UPGRADEWIZ",open_opts$[3]="OTA"
	open_tables$[4]="ADS_SELOPTS",open_opts$[4]="OTA"

	gosub open_tables

rem --- Get this version of Addon. Use version of Barista in download.
	version_id$="??.??"
	major_ver$="v??"
	minor_ver$="v????"
	call stbl("+DIR_SYP")+"bax_version.bbj",version_id$,lic_id$
	major_ver$="v"+str(num(version_id$,err=*next):"00",err=*next)
	minor_ver$="v"+str(num(version_id$,err=*next)*100:"0000",err=*next)
	callpoint!.setDevObject("major_ver",major_ver$)
	callpoint!.setDevObject("minor_ver",minor_ver$)

[[ADX_UPGRADEWIZ.DB_NAME.AVAL]]
rem --- Validate new database name

	db_name$ = callpoint!.getUserInput()
	gosub validate_new_db_name
	callpoint!.setUserInput(db_name$)
	if abort then break

[[ADX_UPGRADEWIZ.GIT_AUTH_ID.AVAL]]
gitAuthID$=cvs(callpoint!.getUserInput(),3)
gosub validate_git_auth_id

[[ADX_UPGRADEWIZ.OLD_AON_LOC.AVAL]]
rem --- Validate old aon install location

	old_aon_loc$=(new File(callpoint!.getUserInput())).getCanonicalPath()
	gosub validate_old_aon_loc
	callpoint!.setUserInput(old_aon_loc$)
	if abort then break

rem --- Initializations when old aon install location changes
	prev_old_aon_loc$=cvs(callpoint!.getDevObject("prev_old_aon_loc"),3)
	prev_new_aon_loc$=cvs(callpoint!.getDevObject("prev_new_aon_loc"),3)
	if cvs(old_aon_loc$,3)<>prev_old_aon_loc$ then
		updateTargetPaths=1
		if prev_new_aon_loc$<>"" and prev_old_aon_loc$<>"" then
			msg_id$="AD_UPDT_TARGET_PATH"
			gosub disp_message
			if msg_opt$<>"Y"then
				updateTargetPaths=0
			endif
		endif

		rem --- Capture old aon location value so can tell later if it's been changed
		callpoint!.setDevObject("prev_old_aon_loc",old_aon_loc$)

		rem --- Initialize old Barista install location
		old_bar_loc$=old_aon_loc$
		gosub able_old_bar_loc

		rem --- Initialize old Barista admin_backup
		bar_dir$=cvs(callpoint!.getColumnData("ADX_UPGRADEWIZ.OLD_BAR_LOC"),3)+"/barista"
		gosub able_backup_sync_dir

		if updateTargetPaths then
			rem --- Initialize aon directory from new aon location
			filePath$=prev_new_aon_loc$
			gosub fix_path
			aonNewDir$=filePath$+"/aon/"

			rem --- Use addon.syn file from old aon location
			aonSynFile$=old_aon_loc$+"/aon/config/addon.syn"

			rem --- Initialize STBL grid for ADDON, i.e. set defaults for data STBLs
			stblRowVect!=SysGUI!.makeVector()
			newDir$=aonNewDir$
			synFile$=aonSynFile$
			gosub build_stbl_vector
			callpoint!.setDevObject("oldSynRows",stblRowVect!)
			if prev_new_aon_loc$<>"" then
				gosub init_stbl_grid
				util.resizeWindow(Form!, SysGui!)
				callpoint!.setStatus("REFRESH")
			endif
		
			rem --- Re-initialize app grid whenever old barista location changes
			rem --- Must be done after stbl grid is initialized
			if cvs(old_bar_loc$,3)<>cvs(callpoint!.getDevObject("prev_old_bar_loc"),3) then
				callpoint!.setDevObject("prev_old_bar_loc",old_bar_loc$)

				rem --- Initialize app grid, i.e. set defaults for data apps
				gosub create_app_vector
				callpoint!.setDevObject("appRowVect",appRowVect!)
				gosub fill_app_grid
				util.resizeWindow(Form!, SysGui!)
				callpoint!.setStatus("REFRESH")

				rem --- Warn if more than one app with ADDON parent, and exit.
				if aonParents>1 then
					msg_id$="AD_EXTRA_AON_PARENTS"
					gosub disp_message
					release
				endif
			endif
		endif
	endif

[[ADX_UPGRADEWIZ.OLD_BAR_LOC.AVAL]]
rem --- Validate old barista install location

	old_bar_loc$=(new File(callpoint!.getUserInput())).getCanonicalPath()
	gosub validate_old_bar_loc
	callpoint!.setUserInput(old_bar_loc$)
	if abort then break
		
	rem --- Re-initialize app grid whenever old barista location changes
	if cvs(old_bar_loc$,3)<>cvs(callpoint!.getDevObject("prev_old_bar_loc"),3) then
		callpoint!.setDevObject("prev_old_bar_loc",old_bar_loc$)

		rem --- Initialize app grid, i.e. set defaults for data apps
		gosub create_app_vector
		callpoint!.setDevObject("appRowVect",appRowVect!)
		gosub fill_app_grid
		util.resizeWindow(Form!, SysGui!)
		callpoint!.setStatus("REFRESH")

		rem --- Warn if more than one app with ADDON parent, and exit.
		if aonParents>1 then
			msg_id$="AD_EXTRA_AON_PARENTS"
			gosub disp_message
			release
		endif
	endif


	rem --- Initialize old Barista admin_backup as needed
	if cvs(callpoint!.getColumnData("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR"),3)="" then
		bar_dir$=old_bar_loc$+"/barista"
		gosub able_backup_sync_dir
	endif

[[ADX_UPGRADEWIZ.SYNC_BACKUP_DIR.AVAL]]
rem --- Validate sync backup directory

	sync_backup_dir$=(new File(callpoint!.getUserInput())).getCanonicalPath()
	gosub validate_sync_backup_dir
	callpoint!.setUserInput(sync_backup_dir$)
	if abort then break

[[ADX_UPGRADEWIZ.<CUSTOM>]]
rem --- validate_git_auth_id
rem --- verifies that the Git repository is a fork or clone of the official Addon repository
rem --- gitAuthID$: the ID of the Git Authentication record in the ADX_GIT_AUTH table.
validate_git_auth_id: 
	
	git!=new GitRepoInterface(gitAuthID$)

	REM If the repo is not official, show a message and cancel validation 
	isOfficial=git!.isDescendantOfOfficialRepo()
	if !isOfficial then
		msg_id$="ADX_INVALID_GIT_REPO"
		gosub disp_message
		callpoint!.setStatus("EXIT")
	endif 

	return

validate_release_tag:

	git!=new GitRepoInterface(gitAuthID$)

	rem --- if the version being installed/upgraded to isn't tagged (i.e., not an official release), show message and cancel
	tagVersion$=callpoint!.getDevObject("minor_ver")
	tagVersion$=tagVersion$(2)
	isTagged=git!.isTaggedRelease(tagVersion$)
	if !isTagged
		msg_id$="ADX_INVALID_GIT_REL"
		dim msg_tokens$[1]
		msg_tokens$[1]=str(num(tagVersion$)/100:"00.00")
		gosub disp_message
		callpoint!.setStatus("EXIT")
	endif
	return 

validate_new_db_name: rem --- Validate new database name

	abort=0

	rem --- Barista uses all upper case db names
	db_name$=cvs(db_name$,4)

	rem --- Also replace any spaces with underscores (ER 10496)
	db_name!=db_name$
	db_name$=db_name!.replace(" ","_")

	rem --- Don't allow database if it's already in Enterprise Manager
	call stbl("+DIR_SYP")+"bac_em_login.bbj",SysGUI!,Form!,rdAdmin!,rd_status$
	if rd_status$="ADMIN" then
		db! = rdAdmin!.getDatabase(db_name$,err=dbNotFound)

		rem --- This db already exists, so don't allow it unless this is a re-start for Git conflicts
		dictionary$=db!.getString(BBjAdminDatabase.DICTIONARY)
		if db!.getType()=BBjAdminDatabase.DatabaseType.BARISTA
			aonLoc$=dictionary$(1,pos("/barista/sys/data"=dictionary$)-1)
		else
			aonLoc$=dictionary$(1,pos("/barista/bbdict"=dictionary$)-1)
		endif
		restartFile$=aonLoc$+"/aon/logs/restartUpgradeWizard.txt"
		restart=0
		restart_dev=unt
		open(restart_dev,err=*next)restartFile$; restart=1
		if restart then
			rem --- Verify correct restart file
			read(restart_dev)text$
			close(restart_dev,err=*next)
			if pos(restartFile$=text$) then goto dbNotFound
		endif
		close(restart_dev,err=*next)

		msg_id$="AD_DB_EXISTS"
		gosub disp_message
	endif

	rem --- Abort, need to re-enter database name
	callpoint!.setColumnData("ADX_UPGRADEWIZ.DB_NAME", db_name$)
	callpoint!.setFocus("ADX_UPGRADEWIZ.DB_NAME")
	callpoint!.setStatus("ABORT")
	abort=1

dbNotFound:
	rem --- Okay to use this db name, it doesn't already exist or this is a Git conflicts re-start
	callpoint!.setDevObject("rdAdmin", rdAdmin!)

	return

validate_base_dir: rem --- Validate base directory for installation

	abort=0

	rem --- Flip directory path separators

	filePath$=new_loc$
	gosub fix_path
	new_loc$=filePath$

	rem --- Remove trailing slashes (/ and \) from aon new install location

	while len(new_loc$) and pos(new_loc$(len(new_loc$),1)="/\")
		new_loc$ = new_loc$(1, len(new_loc$)-1)
	wend

	rem --- Fix path for this OS
	current_dir$=dir("")
	current_drive$=dsk("",err=*next)
    	FileObject.makeDirs(new File(new_loc$))
	valid_path=0
	if (new_loc$(2,1)=":") then
		drive$=new_loc$(1,1)
		setdrive drive$
	endif 
	chdir(new_loc$),err=*next; valid_path=1
	if !valid_path then
		msg_id$="AD_BAD_DIR"
		dim msg_tokens$[1]
		msg_tokens$[1]=new_loc$
		gosub disp_message

		callpoint!.setColumnData("ADX_UPGRADEWIZ.BASE_DIR", new_loc$)
		callpoint!.setFocus("ADX_UPGRADEWIZ.BASE_DIR")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif
	new_loc$=dsk("")+dir("")
	while len(new_loc$) and pos(new_loc$(len(new_loc$),1)="/\")
		new_loc$ = new_loc$(1, len(new_loc$)-1)
	wend
	setdrive current_drive$
	chdir(current_dir$)

	rem --- Don’t allow current download location

	testLoc$=new_loc$
	gosub verify_not_download_loc
	if !loc_ok
		callpoint!.setColumnData("ADX_UPGRADEWIZ.BASE_DIR", new_loc$)
		callpoint!.setFocus("ADX_UPGRADEWIZ.BASE_DIR")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif

	rem --- Read-Write-Execute directory permissions are required

	if !FileObject.isDirWritable(new_loc$)
		msg_id$="AD_DIR_NOT_WRITABLE"
		dim msg_tokens$[1]
		msg_tokens$[1]=new_loc$
		gosub disp_message

		callpoint!.setColumnData("ADX_UPGRADEWIZ.BASE_DIR", new_loc$)
		callpoint!.setFocus("ADX_UPGRADEWIZ.BASE_DIR")
		callpoint!.setStatus("ABORT")
		abort=1
		return
	endif

	rem --- Cannot be currently used by Addon, unless this is a re-start for Git conflicts

	major_ver$=callpoint!.getDevObject("major_ver")
	minor_ver$=callpoint!.getDevObject("minor_ver")
	aonLoc$=new_loc$+"/"+major_ver$+"/"+minor_ver$
	aonDir_exists=0
	testChan=unt
	open(testChan,err=*next)aonLoc$+"/aon/data"; aonDir_exists=1
	close(testChan,err=*next)
	if !aonDir_exists then return

	rem --- Is this is a re-start for Git conflicts?
	restartFile$=aonLoc$+"/aon/logs/restartUpgradeWizard.txt"
	restart=0
	restart_dev=unt
	open(restart_dev,err=*next)restartFile$; restart=1
	if restart then
		rem --- Verify correct restart file
		read(restart_dev)text$
		close(restart_dev,err=*next)
		if pos(restartFile$=text$) then return
	endif
	close(restart_dev,err=*next)

	rem --- Location is used by Addon, and this is not a Git conflict re-start
	callpoint!.setColumnData("ADX_UPGRADEWIZ.NEW_AON_LOC",new_loc$+"/"+major_ver$+"/"+minor_ver$,1)
	msg_id$="AD_INSTALL_LOC_USED"
	gosub disp_message

	callpoint!.setColumnData("ADX_UPGRADEWIZ.BASE_DIR", new_loc$)
	callpoint!.setFocus("ADX_UPGRADEWIZ.BASE_DIR")
	callpoint!.setStatus("ABORT")
	abort=1

	return

verify_not_download_loc: rem --- Verify not using current download location

	loc_ok=1
	bbjHome$ = System.getProperty("basis.BBjHome")
	if ((new File(testLoc$)).getAbsolutePath()).toLowerCase().startsWith((new File(bbjHome$)).getAbsolutePath().toLowerCase()+File.separator)
		msg_id$="AD_INSTALL_LOC_BAD"
		dim msg_tokens$[1]
		msg_tokens$[1]=bbjHome$
		gosub disp_message
		loc_ok=0
	endif

	return

validate_old_aon_loc: rem --- Validate old aon install location

	abort=0

	rem --- Remove trailing slashes (/ and \) from aon new install location

	while len(old_aon_loc$) and pos(old_aon_loc$(len(old_aon_loc$),1)="/\")
		old_aon_loc$ = old_aon_loc$(1, len(old_aon_loc$)-1)
	wend

	rem --- Remove trailing “/aon”

	if len(old_aon_loc$)>=4 and pos(old_aon_loc$(1+len(old_aon_loc$)-4)="/aon\aon" ,4)
		old_aon_loc$ = old_aon_loc$(1, len(old_aon_loc$)-4)
	endif

	rem --- Confirm currently used by Addon

	testChan=unt
	open(testChan, err=not_aon_loc)old_aon_loc$ + "/aon/config/addon.syn"
	close(testChan)
	
	return

not_aon_loc:	rem --- Addon not at this location
	msg_id$="AD_NOT_AON_LOC"
	gosub disp_message

	callpoint!.setColumnData("ADX_UPGRADEWIZ.OLD_AON_LOC", old_aon_loc$)
	callpoint!.setStatus("ABORT")
	abort=1

	return

validate_old_bar_loc: rem --- Validate old bar install location

	abort=0

	rem --- Remove trailing slashes (/ and \) from aon new install location

	while len(old_bar_loc$) and pos(old_bar_loc$(len(old_bar_loc$),1)="/\")
		old_bar_loc$ = old_bar_loc$(1, len(old_bar_loc$)-1)
	wend

	rem --- Remove trailing “/barista”

	if len(old_bar_loc$)>=8 and pos(old_bar_loc$(1+len(old_bar_loc$)-8)="/barista\barista" ,8)
		old_bar_loc$ = old_bar_loc$(1, len(old_bar_loc$)-8)
	endif

	rem --- Confirm currently used by Barista

	testChan=unt
	open(testChan, err=not_bar_loc)old_bar_loc$ + "/barista/sys/config/enu/barista.cfg"
	close(testChan)
	
	return

not_bar_loc:	rem --- Barista not at this location
	msg_id$="AD_NOT_BAR_LOC"
	gosub disp_message

	callpoint!.setColumnData("ADX_UPGRADEWIZ.OLD_BAR_LOC", old_bar_loc$)
	callpoint!.setFocus("ADX_UPGRADEWIZ.OLD_BAR_LOC")
	callpoint!.setStatus("ABORT")
	abort=1

	return

validate_sync_backup_dir: rem --- Validate sync backup directory

	abort=0

	rem --- Remove trailing slashes (/ and \) from aon new install location

	while len(sync_backup_dir$) and pos(sync_backup_dir$(len(sync_backup_dir$),1)="/\")
		sync_backup_dir$ = sync_backup_dir$(1, len(sync_backup_dir$)-1)
	wend


	rem --- Directory must exist
	testChan=unt
	open(testChan, err=dir_missing)sync_backup_dir$
	close(testChan)
	
	return

dir_missing: rem --- Directory doesn't exist
	msg_id$="AD_DIR_MISSING"
	dim msg_tokens$[1]
	msg_tokens$[1]=testDir$
	gosub disp_message

	callpoint!.setColumnData("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR", old_bar_loc$)
	callpoint!.setFocus("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR")
	callpoint!.setStatus("ABORT")
	abort=1

	return

able_old_bar_loc: rem --- Enable/disable input field for old Barista location

	rem --- Check for old Barista barista.cfg file
	bar_found=0
	testChan=unt 
	open(testChan, err=*next)old_bar_loc$ + "/barista/sys/config/enu/barista.cfg"; bar_found=1
	close(testChan)

	if bar_found then
		rem --- Initialize and disable old Barista location
		callpoint!.setColumnEnabled("ADX_UPGRADEWIZ.OLD_BAR_LOC",0)
		callpoint!.setColumnData("ADX_UPGRADEWIZ.OLD_BAR_LOC",old_bar_loc$)
	else
		rem --- Enable old Barista location
		callpoint!.setColumnEnabled("ADX_UPGRADEWIZ.OLD_BAR_LOC",1)
	endif

	callpoint!.setStatus("REFRESH")

	return

able_backup_sync_dir: rem --- Enable/disable input field for sync backup directory

	rem --- Check for old Barista admin_backup
	backup_found=0
	testChan=unt 
	open(testChan, err=*next)bar_dir$ + "/admin_backup"; backup_found=1
	close(testChan)

	rem --- Check version of old Barista (will automatically do Create Sync File Backup if pre-version 18)
	rem --- Locate the database for old Barista
	dbname$ = ""
	oldBarDir$=bar_dir$
	if pos(":"=oldBarDir$)=0 then oldBarDir$=dsk("")+oldBarDir$
	sourceChan=unt
	open(sourceChan,isz=-1)oldBarDir$+"/sys/config/enu/barista.cfg"
	while 1
		read(sourceChan,end=*break)record$
		rem --- get database from SET +DBNAME line
		if pos("SET +DBNAME="=record$)=1 then
			dbname$=record$(pos("="=record$)+1)
			break
		endif
	wend
	close(sourceChan)
	callpoint!.setDevObject("old_dbname",dbname$)

	rem --- Query old ADM_MODULES for Barista Administration version
	adb_version$=""
	if dbname$<>"" then
		sql_chan=sqlunt
		sqlopen(sql_chan)dbname$
		sql_prep$="SELECT version_id FROM adm_modules where asc_comp_id='01007514' and asc_prod_id='ADB'"
		sqlprep(sql_chan)sql_prep$
		dim select_tpl$:sqltmpl(sql_chan)
		sqlexec(sql_chan)
		select_tpl$=sqlfetch(sql_chan); rem --- Something is wrong if this fails, so let it error to get helpful message. 
		adb_version$=cvs(select_tpl.version_id$,3)
		sqlclose(sql_chan)
	endif

	rem --- Automatically do Create Sync File Backup if old Barista is pre-version 18
	if num(adb_version$)<18 then
		do_sync_backup=1
	else
		do_sync_backup=0
	endif
	callpoint!.setDevObject("do_sync_backup",do_sync_backup)

	if backup_found or num(adb_version$)>=18 then
		rem --- Initialize and disable sync backup directory
		callpoint!.setColumnEnabled("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR",0)
		callpoint!.setColumnData("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR",bar_dir$ + "/admin_backup")
	else
		rem --- Enable sync backup directory
		callpoint!.setColumnEnabled("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR",1)
		callpoint!.setColumnData("ADX_UPGRADEWIZ.SYNC_BACKUP_DIR","")
	endif

	callpoint!.setStatus("REFRESH")

	return

format_app_grid: rem --- Format application grid

	app_grid_def_cols=callpoint!.getDevObject("app_grid_def_cols")
	app_rpts_rows=callpoint!.getDevObject("app_grid_min_rows")

	dim attr_def_col_str$[0,0]
	attr_def_col_str$[0,0]=callpoint!.getColumnAttributeTypes()

	dim attr_rpts_col$[app_grid_def_cols,len(attr_def_col_str$[0,0])/5]
	attr_rpts_col$[1,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="APP"
	attr_rpts_col$[1,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_application_label$
	attr_rpts_col$[1,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="55"

	attr_rpts_col$[2,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="APP_PARENT"
	attr_rpts_col$[2,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_app_parent_label$
	attr_rpts_col$[2,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="55"

	attr_rpts_col$[3,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="INSTALL"
	attr_rpts_col$[3,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_install_label$
	attr_rpts_col$[3,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="25"

	attr_rpts_col$[4,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="COPY"
	attr_rpts_col$[4,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_copy_label$
	attr_rpts_col$[4,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="25"

	attr_rpts_col$[5,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="APP_SOURCE"
	attr_rpts_col$[5,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_source_label$
	attr_rpts_col$[5,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="345"

	attr_rpts_col$[6,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="APP_TARGET"
	attr_rpts_col$[6,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_target_label$
	attr_rpts_col$[6,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="345"
	attr_rpts_col$[6,fnstr_pos("MAXL",attr_def_col_str$[0,0],5)]="256"

	for curr_attr=1 to app_grid_def_cols
		attr_rpts_col$[0,1]=attr_rpts_col$[0,1]+pad("UPGRADEWIZ."+attr_rpts_col$[curr_attr,
:			fnstr_pos("DVAR",attr_def_col_str$[0,0],5)],40)
	next curr_attr

	attr_disp_col$=attr_rpts_col$[0,1]

	call stbl("+DIR_SYP")+"bam_grid_init.bbj",gui_dev,appGrid!,"COLH-LINES-LIGHT-AUTO-MULTI-SIZEC",app_rpts_rows,
:		attr_def_col_str$[all],attr_disp_col$,attr_rpts_col$[all]

	return

rem ==========================================================================
create_app_vector: rem --- Create a vector of applications from the OLD ddm_systems table to fill the app grid
		rem      IN: old_bar_loc$
		rem     OUT: appRowVect!
rem ==========================================================================

	rem --- Application heritage must come from OLD system.
	rem --- Locate the database for the OLD system, and query the DDM_SYSTEMS table.
	dbname$ = ""
	bar_dir$=old_bar_loc$+"/barista"
	if pos(":"=bar_dir$)=0 then bar_dir$=dsk("")+bar_dir$
	sourceChan=unt
	cfg_found=0
	open(sourceChan,isz=-1,err=*next)bar_dir$+"/sys/config/"+cvs(stbl("+LANGUAGE_ORIGIN"),8)+"/barista.cfg"; cfg_found=1
	if cfg_found then
		while 1
			read(sourceChan,end=*break)record$
			rem --- get database from SET +DBNAME line
			if pos("SET +DBNAME="=record$)=1 then
				dbname$=record$(pos("="=record$)+1)
			break
			endif
		wend
		close(sourceChan)
	endif
	callpoint!.setDevObject("old_dbname",dbname$)

	rem --- Build HashMap of all parent and child applications. The HashMap is keyed by the parent,
	rem --- and holds a Vector of all the children for that parent.
	aonParents=0
	declare HashMap appMap!
	appMap! = new HashMap()
	declare Vector rootVect!
	rootVect! = new Vector()
	declare Vector childVect!
	declare HashMap propMap!
	if dbname$<>"" then
		sql_chan=sqlunt
		sqlopen(sql_chan)dbname$
		sql_prep$="SELECT mount_sys_id, mount_dir, parent_sys_id FROM ddm_systems order by mount_seq_no"
		sqlprep(sql_chan)sql_prep$
		dim select_tpl$:sqltmpl(sql_chan)
		sqlexec(sql_chan)
		while 1
			select_tpl$=sqlfetch(sql_chan,err=*break) 
			child$=cvs(select_tpl.mount_sys_id$,3)
			child_dir$=cvs(select_tpl.mount_dir$,3)
			parent$=cvs(select_tpl.parent_sys_id$,3)
			propMap! = new HashMap()
			propMap!.put("mount_sys_id",child$)
			propMap!.put("mount_dir",child_dir$)
			propMap!.put("parent_sys_id",parent$)
			if parent$="" then
				rootVect!.add(propMap!)
			else
				if appMap!.containsKey(parent$) then
					childVect! = cast(Vector, appMap!.get(parent$))
					childVect!.add(propMap!)
				else
					childVect! = new Vector()
					childVect!.add(propMap!)
					appMap!.put(parent$, childVect!)
				endif
			endif
		wend
		sqlclose(sql_chan)
	endif

	rem --- Build rows for app grid
	appRowVect!=SysGUI!.makeVector()
	rootIter!=rootVect!.iterator()
	while rootIter!.hasNext()
		rootProps!=cast(HashMap, rootIter!.next())

		rem --- Add root app row unless ADDON
		rootApp$=cast(BBjString, rootProps!.get("mount_sys_id"))
		if pos(":"+rootApp$+":"=":ADDON:")=0 then
			appRowVect!.addItem(rootApp$); rem App
			appRowVect!.addItem(""); rem Parent
			if pos(":"+rootApp$+":"=":V6HYBRID:")<>0
				appRowVect!.addItem("n"); rem Don't install V6Hybrid - done separately
			else
				appRowVect!.addItem("y"); rem Install
			endif
			appRowVect!.addItem("n"); rem Copy
			appRowVect!.addItem(cast(BBjString, rootProps!.get("mount_dir"))); rem Source
			appRowVect!.addItem(""); rem Target
		endif

		rem --- Add child app rows for this root app
		declare AppHeritage heritage!
		heritage! = new AppHeritage(appMap!)
		declare Vector descendentVect!
		descendentVect! = heritage!.getDescendents(rootApp$)
		if descendentVect!.size()>0 then
			for i=0 to descendentVect!.size()-1
				childProps! = cast(HashMap, descendentVect!.get(i))
				appRowVect!.addItem(cast(BBjString, childProps!.get("mount_sys_id"))); rem App
				appRowVect!.addItem(cast(BBjString, childProps!.get("parent_sys_id"))); rem Parent
				appRowVect!.addItem("y"); rem Install
				if pos(":"+rootApp$+":"=":ADDON:") then
					appRowVect!.addItem("y"); rem Copy
				else
					appRowVect!.addItem("n"); rem Copy
				endif
				appRowVect!.addItem(cast(BBjString, childProps!.get("mount_dir"))); rem Source
				if pos(":"+rootApp$+":"=":ADDON:") then
					sourceDir$=cast(BBjString, childProps!.get("mount_dir"))
					gosub build_target_dir
					appRowVect!.addItem(targetDir$); rem Target
				else
					appRowVect!.addItem(""); rem Target
				endif

				rem --- Count apps with ADDON parent
				if childProps!.get("parent_sys_id")="ADDON" then aonParents=aonParents+1
			next i
		endif
	wend

	rem ---Make sure grid has at least minimum number of rows
	while appRowVect!.size()<callpoint!.getDevObject("app_grid_def_cols")*callpoint!.getDevObject("app_grid_min_rows")
		appRowVect!.addItem(""); rem App
		appRowVect!.addItem(""); rem Parent
		appRowVect!.addItem(""); rem Install
		appRowVect!.addItem(""); rem Copy
		appRowVect!.addItem(""); rem Source
		appRowVect!.addItem(""); rem Target
	wend
	
	return

fill_app_grid: rem --- Fill the app grid with data in appRowVect!

	SysGUI!.setRepaintEnabled(0)
	stblRowVect!=callpoint!.getDevObject("stblRowVect")
	appGrid!=callpoint!.getDevObject("appGrid")
	appGrid!.clearMainGrid()
	if appRowVect!.size()
		numrow=appRowVect!.size()/appGrid!.getNumColumns()
		appGrid!.setNumRows(numrow)
		appGrid!.setCellText(0,0,appRowVect!)

		rem --- Set cell properties
		for i=0 to appRowVect!.size()-1 step appGrid!.getNumColumns()
			row=i/appGrid!.getNumColumns()

			rem --- Disable blank rows
			if appRowVect!.getItem(i)="" then
				appGrid!.setRowEditable(row, 0)
			endif

			rem --- Disable V6Hybrid row, if applicable (gets done separately)
			if pos("V6HYBRID"=appRowVect!.getItem(i))<>0 then
				appGrid!.setRowEditable(row, 0)
				appGrid!.setCellStyle(row,2,SysGUI!.GRID_STYLE_UNCHECKED)
				appGrid!.setCellStyle(row,3,SysGUI!.GRID_STYLE_UNCHECKED)
			endif

			rem --- Set install checkbox
			if appRowVect!.getItem(i+2) = "y" then 
				appGrid!.setCellStyle(row, 2, SysGUI!.GRID_STYLE_CHECKED)
			else
				appGrid!.setCellStyle(row, 2, SysGUI!.GRID_STYLE_UNCHECKED)
			endif
			appGrid!.setCellText(row, 2, "")

			rem --- Set copy checkbox
			if appRowVect!.getItem(i+3) = "y" then 
				appGrid!.setCellStyle(row, 3, SysGUI!.GRID_STYLE_CHECKED)
				appGrid!.setCellEditable(row,5,1); rem Target

				if !skipStblVectorBuild then
					rem --- Update stblRowVect! for copied application
					appName$=appRowVect!.getItem(i+0)
					oldDir$=appRowVect!.getItem(i+4)
					synFile$=oldDir$+"config/"+cvs(appName$,8)+".syn"
					newDir$=appRowVect!.getItem(i+5)
					gosub build_stbl_vector
				endif
			else
				appGrid!.setCellStyle(row, 3, SysGUI!.GRID_STYLE_UNCHECKED)
				appGrid!.setCellEditable(row,5,0); rem Target
			endif
			appGrid!.setCellText(row, 3, "")
		next i
	endif
	rem --- Update stbl grid with stblRowVect! updated for copied applications
	callpoint!.setDevObject("stblRowVect",stblRowVect!)
	gosub fill_stbl_grid
	SysGUI!.setRepaintEnabled(1)

	return

rem ==========================================================================
update_app_grid: rem --- Update app grid row when checkboxes are checked/unchecked
		rem      IN: e!
		rem      IN: appGrid!
		rem      IN: appRowVect!
		rem      IN: onoff
rem ==========================================================================

	SysGUI!.setRepaintEnabled(0)
	stblRowVect!=callpoint!.getDevObject("stblRowVect")
    	app_grid_def_cols=callpoint!.getDevObject("app_grid_def_cols")
	index=e!.getRow()*app_grid_def_cols

	rem --- Force Install and Copy checkboxes to be the same for apps with ADDON parent
	parent$=cvs(appRowVect!.getItem(index+1),2)

	rem --- Install checkbox
	if e!.getColumn()=2 or (parent$="ADDON" and e!.getColumn()=3) then
		if onoff then
			rem --- Checked
			appGrid!.setCellStyle(e!.getRow(),2,SysGUI!.GRID_STYLE_CHECKED); rem Install
			sourceDir$=appRowVect!.get(index+4)
			appGrid!.setCellText(e!.getRow(),4,sourceDir$); rem Source

			rem --- Update appRowVect! for checked install
			appRowVect!.removeItem(index+2)
			appRowVect!.insertItem(index+2, "y"); rem Install
			appRowVect!.removeItem(index+4)
			appRowVect!.insertItem(index+4, sourceDir$); rem Source
		else
			rem --- Unchecked
			appGrid!.setCellStyle(e!.getRow(),2,SysGUI!.GRID_STYLE_UNCHECKED); rem Install

			rem --- Update appRowVect! for unchecked install
			appRowVect!.removeItem(index+2)
			appRowVect!.insertItem(index+2, "n"); rem Install
		endif
	endif

	rem --- Copy checkbox
	if e!.getColumn()=3 or (parent$="ADDON" and e!.getColumn()=2) then
		if onoff then
			rem --- Checked
			appGrid!.setCellStyle(e!.getRow(),3,SysGUI!.GRID_STYLE_CHECKED); rem Copy
			sourceDir$=appRowVect!.get(index+4)
			gosub build_target_dir
			appGrid!.setCellText(e!.getRow(),5,targetDir$); rem Target
			appGrid!.setCellEditable(e!.getRow(),5,1); rem Target

			rem --- Update appRowVect! for checked copy
			appRowVect!.removeItem(index+3)
			appRowVect!.insertItem(index+3, "y"); rem Copy
			appRowVect!.removeItem(index+5)
			appRowVect!.insertItem(index+5, targetDir$); rem Target

			rem --- Update stblRowVect! for copied application
			appName$=appRowVect!.get(index+0)
			oldDir$=appRowVect!.get(index+4)
			synFile$=oldDir$+"config/"+cvs(appName$,8)+".syn"
			newDir$=appRowVect!.get(index+5)
			gosub build_stbl_vector
		else
			rem --- Unchecked
			appGrid!.setCellStyle(e!.getRow(),3,SysGUI!.GRID_STYLE_UNCHECKED); rem Copy
			appGrid!.setCellText(e!.getRow(),5,""); rem Target
			appGrid!.setCellEditable(e!.getRow(),5,0); rem Target

			rem --- Update appRowVect! for unchecked copy
			appRowVect!.removeItem(index+3)
			appRowVect!.insertItem(index+3, "n"); rem Copy
			appRowVect!.removeItem(index+5)
			appRowVect!.insertItem(index+5, ""); rem Target

			rem --- Update stblRowVect! for uncopied application
			appName$=appRowVect!.get(index+0)
			gosub remove_app_stbl_vector
		endif
	endif

	rem --- Update stbl grid with stblRowVect! updated for copied/uncopied applications
	callpoint!.setDevObject("stblRowVect",stblRowVect!)
	gosub fill_stbl_grid
	SysGUI!.setRepaintEnabled(1)

	return

format_stbl_grid: rem --- Format STBL grid

	stbl_grid_def_cols=callpoint!.getDevObject("stbl_grid_def_cols")
	stbl_rpts_rows=callpoint!.getDevObject("stbl_grid_min_rows")

	dim attr_def_col_str$[0,0]
	attr_def_col_str$[0,0]=callpoint!.getColumnAttributeTypes()

	dim attr_rpts_col$[stbl_grid_def_cols,len(attr_def_col_str$[0,0])/5]
	attr_rpts_col$[1,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="TYPE"
	attr_rpts_col$[1,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_application_label$
	attr_rpts_col$[1,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="55"

	attr_rpts_col$[2,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="STBL"
	attr_rpts_col$[2,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_stbl_prefix_lable$
	attr_rpts_col$[2,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="150"

	attr_rpts_col$[3,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="STBL_SOURCE"
	attr_rpts_col$[3,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_source_label$
	attr_rpts_col$[3,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="345"

	attr_rpts_col$[4,fnstr_pos("DVAR",attr_def_col_str$[0,0],5)]="STBL_TARGET"
	attr_rpts_col$[4,fnstr_pos("LABS",attr_def_col_str$[0,0],5)]=aon_target_label$
	attr_rpts_col$[4,fnstr_pos("CTLW",attr_def_col_str$[0,0],5)]="345"
	attr_rpts_col$[4,fnstr_pos("MAXL",attr_def_col_str$[0,0],5)]="256"

	for curr_attr=1 to stbl_grid_def_cols
		attr_rpts_col$[0,1]=attr_rpts_col$[0,1]+pad("UPGRADEWIZ."+attr_rpts_col$[curr_attr,
:			fnstr_pos("DVAR",attr_def_col_str$[0,0],5)],40)
	next curr_attr

	attr_disp_col$=attr_rpts_col$[0,1]

	call stbl("+DIR_SYP")+"bam_grid_init.bbj",gui_dev,stblGrid!,"COLH-LINES-LIGHT-AUTO-MULTI-SIZEC",stbl_rpts_rows,
:		attr_def_col_str$[all],attr_disp_col$,attr_rpts_col$[all]

	return

init_stbl_grid: rem --- Initialize the STBL grid with data in stblRowVect! for only ADDON

	newSynRows!=callpoint!.getDevObject("newSynRows")
	oldSynRows!=callpoint!.getDevObject("oldSynRows")
	gosub merge_vect_rows
	callpoint!.setDevObject("stblRowVect",stblRowVect!)
	gosub fill_stbl_grid

	return

fill_stbl_grid: rem --- Fill the STBL grid with data in stblRowVect!

	SysGUI!.setRepaintEnabled(0)
	stblGrid!=callpoint!.getDevObject("stblGrid")
	if stblRowVect!.size()
		numrow=stblRowVect!.size()/stblGrid!.getNumColumns()
		stblGrid!.clearMainGrid()
		stblGrid!.setNumRows(numrow)
		stblGrid!.setCellText(0,0,stblRowVect!)
	endif
	SysGUI!.setRepaintEnabled(1)

	return

rem ==========================================================================
merge_vect_rows: rem --- Merge new and old syn row vectors into a single vector of STBLs and PREFIXs
		rem      IN: newSynRows!
		rem           oldSynRows!
		rem     OUT: stblRowVect!
rem ==========================================================================

	if oldSynRows!=null() then return
	stblRowVect!=oldSynRows!
	if newSynRows!.size()>0
		numCols=num(callpoint!.getDevObject("stbl_grid_def_cols"))

		for i=0 to newSynRows!.size()-1 step numCols
			type$=newSynRows!.getItem(i+1)
			addLine=0

			rem --- replace updated target value of old STBL lines as needed
			if type$<>"<prefix>"
				stbl$=newSynRows!.getItem(i+1)
				addLine=1
				for j=0 to stblRowVect!.size()-1 step numCols
					if stblRowVect!.getItem(j+1)<>stbl$ then continue
                    stblRowVect!.setItem(j+3,newSynRows!.getItem(i+3))
					if stbl$="+MDI_TITLE" then
						stblRowVect!.setItem(j+3, callpoint!.getColumnData("ADX_UPGRADEWIZ.APP_DESC"))
					endif
					addLine=0
					break
				next j
			endif

			rem --- replace updated target value of old PREFIX lines as needed
			if type$="<prefix>"
				source$=newSynRows!.getItem(i+2)
				addLine=1
				for j=0 to stblRowVect!.size()-1 step numCols
					if stblRowVect!.getItem(j+2)<>source$ then continue
					stblRowVect!.setItem(j+3,newSynRows!.getItem(i+3))
					addLine=0
					break
				next j
			endif
				
			rem --- if new STBL or new PREFIX not found, add it
			if addLine then
				stblRowVect!.addItem(newSynRows!.getItem(i+0)); rem App
				stblRowVect!.addItem(newSynRows!.getItem(i+1)); rem STBL or PRFIX
				stblRowVect!.addItem(newSynRows!.getItem(i+2)); rem Source
				stblRowVect!.addItem(newSynRows!.getItem(i+3)); rem Target
			endif
		next i
	endif

	return

rem ==========================================================================
remove_app_stbl_vector: rem --- Remove application from stblRowVect!
		rem      IN: appName$
		rem  IN-OUT: stblRowVect!
rem ==========================================================================

	if stblRowVect!.size()>0 then
		tempVect!=SysGUI!.makeVector()
		numCols=num(callpoint!.getDevObject("stbl_grid_def_cols"))

		rem --- copy stblRowVect! to tempVect!
		for j=0 to stblRowVect!.size()-1 step numCols
			rem --- skip if application is the one being removed
			if stblRowVect!.getItem(j+0)=appName$ then continue
			tempVect!.addItem(stblRowVect!.getItem(j+0)); rem App
			tempVect!.addItem(stblRowVect!.getItem(j+1)); rem STBL or PRFIX
			tempVect!.addItem(stblRowVect!.getItem(j+2)); rem Source
			tempVect!.addItem(stblRowVect!.getItem(j+3)); rem Target
		next j

		rem --- assign tempVect! to stblRowVect!
		stblRowVect!=tempVect!
	endif

	return

rem ==========================================================================
build_stbl_vector: rem --- Create a vector of STBLs and PREFIXs from the source syn file to fill the STBL grid.
		rem      IN: newDir$
		rem      IN: synFile$
		rem  IN-OUT: stblRowVect!
rem ==========================================================================

	synDev=unt, more=0
	open(synDev,isz=-1,err=*return)synFile$; more=1

	oldDir$=""
	filePath$=callpoint!.getColumnData("ADX_UPGRADEWIZ.BASE_DIR")
	gosub fix_path
	baseDir$=filePath$
	while more
		read(synDev,end=*break)record$

		rem  --- get application name
		rem --- parse from SYS line
		if pos("SYS="=record$) = 1 then
			xpos = pos("="=record$)
			appName$= record$(xpos+1,pos(";"=record$(xpos+1))-1)
		endif
		rem --- parse from SYSID line
		if pos("SYSID="=record$) = 1 then
			xpos = pos("="=record$)
			appName$= cvs(record$(xpos+1),3)
		endif

		rem --- get old aon path from SYSDIR/DIR line
		rem --- it must be replaced everywhere with current aon path.
		if(pos("DIR="=record$) = 1 or pos("SYSDIR="=record$) = 1) then
			xpos = pos("="=record$)
			oldDir$= cvs(record$(xpos+1),3)
		endif

		rem --- process SYSSTBL/STBL lines
		if(pos("STBL="=record$) = 1 or pos("SYSSTBL="=record$) = 1) then
			xpos = pos(" "=record$)
			stbl$ = record$(xpos+1, pos("="=record$(xpos+1))-1)
			if pos(":"+stbl$+":"=":+DATAPORT_LOGS:+CODEPORT_LOGS:") then
				rem --- Standard Addon default directories that may not exist yet
				aonDefaultPath=1
			else
				aonDefaultPath=0
			endif
			source_value$=cvs(record$(pos("="=record$,1,2)+1),3)

			rem --- Use version-neutral directory for +AON_IMAGES, +CUST_IMAGES and +DOC_DIR_* target directories
			rem --- Use version-neutral major_ver directory for +DIR_DAT and +??DATA directories
			switch (BBjAPI().TRUE)
				case pos(stbl$="+AON_IMAGES")
					target_value$=baseDir$+"/images/"
					break
				case pos(stbl$="+CUST_IMAGES")
					target_value$=baseDir$+"/cust_images/"
					break
				case pos("+DOC_DIR_ARCHIVE"=stbl$)
					target_value$=baseDir$+"/documents/archive/"
					break
				case pos("+DOC_DIR_"=stbl$)
					target_value$=baseDir$+"/documents/"
					break
				case stbl$="+DIR_DAT" or (stbl$(1,1)="+" and pos("DATA"=stbl$,-1)=len(stbl$)-3)
					target_value$=baseDir$+"/"+callpoint!.getDevObject("major_ver")+"/app_data/"
					break
				case default
					gosub source_target_value
					break
			swend

			stblRowVect!.addItem(appName$)
			stblRowVect!.addItem(stbl$)
			stblRowVect!.addItem(source_value$)
			stblRowVect!.addItem(target_value$)
		endif

		rem --- process SYSPFX/PREFIX lines
		if(pos("PREFIX"=record$) = 1 or pos("SYSPFX"=record$) = 1) then
			source_value$=cvs(record$(pos("="=record$)+1),3)
			if pos("../apps/aon/classes/"=source_value$) then
				rem --- Addon classes directory for Business Components may not exist yet
				aonDefaultPath=1
			else
				aonDefaultPath=0
			endif
			gosub source_target_value
			stblRowVect!.addItem(appName$)
			stblRowVect!.addItem("<prefix>")
			stblRowVect!.addItem(source_value$)
			stblRowVect!.addItem(target_value$)
		endif
	wend
	close(synDev)
	
	return

rem ==========================================================================
source_target_value: rem -- Set default new target value based on new config location
		rem      IN: aonDefaultPath  ---  true (1)/false (0), a standard Addon default directory that may not exist yet
		rem      IN: newDir$
		rem      IN: oldDir$
		rem      IN: source_value$
		rem      OUT: target_value$
rem ==========================================================================

	target_value$=source_value$

	rem --- If source holds a path (or is a default Addon path STBL), then need to initialize default new target value
	declare File aFile!
	aFile! = new File(source_value$)
	if (aFile!.exists() and newDir$<>"" and oldDir$<>"") or (aonDefaultPath) then
		record$=target_value$
		search$=oldDir$
		replace$=newDir$
		gosub search_replace
		target_value$=record$
	endif

	filePath$=target_value$
	gosub fix_path
	target_value$=filePath$

	return

rem ==========================================================================
build_target_dir: rem --- Build target dir from source dir and new aon location
		rem      IN: sourceDir$
		rem     OUT: targetDir$
rem ==========================================================================

	filePath$=callpoint!.getDevObject("prev_new_aon_loc")
	if len(filePath$)=0 then filePath$=cvs(callpoint!.getColumnData("ADX_UPGRADEWIZ.NEW_AON_LOC"),3)
	gosub fix_path
	if filePath$(len(filePath$))<>"/" then filePath$=filePath$+"/"
	aonLoc$=filePath$

	filePath$=sourceDir$
	gosub fix_path
	if len(filePath$)=0 then
		targetDir$=aonLoc$
	else
		if filePath$(len(filePath$))<>"/" then filePath$=filePath$+"/"
		targetDir$=aonLoc$+filePath$(pos("/"=filePath$,-1,2)+1)
	endif

	return

fix_path: rem --- Flip directory path separators

	pos=pos("\"=filePath$)
	while pos
		filePath$=filePath$(1, pos-1)+"/"+filePath$(pos+1)
		pos=pos("\"=filePath$)
	 wend

	return
    
search_replace: rem --- Search record$ for search$, and replace with replace$
	rem --- Assumes only one occurrence of search$ per line so don't have 
	rem --- to deal with situation where pos(search$=replace$)>0

	pos = pos(search$=record$)
	if(pos) then
		record$ = record$(1, pos - 1) + replace$ + record$(pos + len(search$))
	endif

	return



