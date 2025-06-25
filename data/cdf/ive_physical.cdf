[[IVE_PHYSICAL.ADIS]]
rem --- see if this item is lot/ser

	ivm_itemmast=fnget_dev("IVM_ITEMMAST")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
	find record (ivm_itemmast, key=firm_id$+callpoint!.getColumnData("IVE_PHYSICAL.ITEM_ID")) ivm_itemmast$

	callpoint!.setDevObject("this_item_lot_ser",iff(pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y",1,0))
	callpoint!.setDevObject("lotser_flag",ivm_itemmast.lotser_flag$)

[[IVE_PHYSICAL.ARNF]]
rem --- if record not found confirm user wants to add

	msg_id$ = "IV_ADD_PHYS_REC"
	gosub disp_message

	if msg_opt$ = "N" then
	callpoint!.setStatus("NEWREC")

[[IVE_PHYSICAL.BSHO]]
rem --- Open files

	num_files=6
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVS_PARAMS",   open_opts$[1]="OTA"
	open_tables$[2]="IVM_ITEMMAST", open_opts$[2]="OTA"
	open_tables$[3]="IVM_ITEMWHSE", open_opts$[3]="OTA"
	open_tables$[4]="IVC_PHYSCODE", open_opts$[4]="OTA"
	open_tables$[5]="IVM_LSMASTER", open_opts$[5]="OTA"
	open_tables$[6]="IVC_WHSECODE", open_opts$[6]="OTA"

	gosub open_tables

rem --- Inits

	callpoint!.setDevObject("lotser_flag","N")
	callpoint!.setDevObject("this_item_lot_ser",0)

rem --- Store defined/templated length for location and lotser fields

	dim phy$:fnget_tpl$("IVE_PHYSICAL")
	tmp$=fattr(phy$,"LOCATION")
	callpoint!.setDevObject("location_length",dec(tmp$(10,2)))
	tmp$=fattr(phy$,"LOTSER_NO")
	callpoint!.setDevObject("lotser_no_length",dec(tmp$(10,2)))

[[IVE_PHYSICAL.BWRI]]
rem --- before writing, if a count has been entered for an L/S item, but there's no lotser_no, disallow the write

if callpoint!.getDevObject("this_item_lot_ser")
	if cvs(callpoint!.getColumnData("IVE_PHYSICAL.LOTSER_NO"),2)="" and num(callpoint!.getColumnData("IVE_PHYSICAL.ACT_PHYS_CNT"))<>0
		msg_id$="IV_LOT_MUST_EXIST"
		gosub disp_message
		callpoint!.setStatus("ACTIVATE-ABORT")
	endif
endif

[[IVE_PHYSICAL.COUNT_STRING.AVAL]]
rem --- Test and total count string

	count$ = callpoint!.getUserInput()
	gosub parse_count

	if failed then
		print "---Failed in parse_count"; rem debug
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

rem --- Serial number count must be one or zero

	qty$=callpoint!.getUserInput()

	if callpoint!.getDevObject("this_item_lot_ser") and callpoint!.getDevObject("lotser_flag")="S" and qty$ <> "1" and qty$<> "0"
		msg_id$="IV_SER_ONE_ZERO"
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break; rem --- exit callpoint
	endif

rem --- Flag that this record was entered

	if cvs(callpoint!.getUserInput(), 2) <> "" then 
		callpoint!.setColumnData("IVE_PHYSICAL.ENTERED_FLAG","Y")
	endif

[[IVE_PHYSICAL.COUNT_STRING.BINP]]
rem --- Serial number's count defaults to one

	if callpoint!.getDevObject("this_item_lot_ser") and callpoint!.getDevObject("lotser_flag")="S"
		callpoint!.setTableColumnAttribute("IVE_PHYSICAL.ACT_PHYS_CNT","DFLT","1")
	endif

[[IVE_PHYSICAL.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[IVE_PHYSICAL.ITEM_ID.AVAL]]
rem "Inventory Inactive Feature"
	item_id$=callpoint!.getUserInput()
	ivm01_dev=fnget_dev("IVM_ITEMMAST")
	ivm01_tpl$=fnget_tpl$("IVM_ITEMMAST")
	dim ivm01a$:ivm01_tpl$
	ivm01a_key$=firm_id$+item_id$
	find record (ivm01_dev,key=ivm01a_key$,err=*break)ivm01a$
	if ivm01a.item_inactive$="Y" then
  		msg_id$="IV_ITEM_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivm01a.item_id$,2)
		msg_tokens$[2]=cvs(ivm01a.display_desc$,2)
		gosub disp_message
		callpoint!.setStatus("ACTIVATE")
	endif

rem --- Validate Whse/Item record

	item$ = callpoint!.getUserInput()
	whse$=callpoint!.getColumnData("IVE_PHYSICAL.WAREHOUSE_ID")
	gosub check_item_whse

	if failed then
		callpoint!.setStatus("ABORT")
	else

rem --- Is this item is the selected cycle?

	gosub item_in_cycle

	if !found then
		msg_id$ = "IV_ITEM_NOT_IN_CYCLE"
		gosub disp_message
		callpoint!.setStatus("ABORT")	
	endif

[[IVE_PHYSICAL.LOCATION.AVAL]]
rem --- since location can be blank, make sure it's padded to 10 spaces
rem --- if you just <enter>, Barista treats that as a legit empty string, so won't honor the left/space justification
rem --- if you enter one space, it does, but let's not make the user remember that

	if cvs(callpoint!.getUserInput(),2)=""
		callpoint!.setUserInput(fill(callpoint!.getDevObject("location_length")))
	endif

[[IVE_PHYSICAL.LOTSER_NO.AVAL]]
rem --- since lot/serial can be blank, make sure it's padded to 20 spaces
rem --- if you just <enter>, Barista treats that as a legit empty string, so won't honor the left/space justification
rem --- if you enter one space, it does, but let's not make the user remember that

	if cvs(callpoint!.getUserInput(),2)="" or !callpoint!.getDevObject("this_item_lot_ser")
		callpoint!.setUserInput(fill(callpoint!.getDevObject("lotser_no_length")))
	endif

[[IVE_PHYSICAL.PI_CYCLECODE.AVAL]]
rem --- Is cycle in the correct stage?

	whse$  = callpoint!.getColumnData("IVE_PHYSICAL.WAREHOUSE_ID")
	cycle$ = callpoint!.getUserInput()
	gosub check_whse_cycle

	if failed then
		callpoint!.setStatus("ABORT")
	endif

[[IVE_PHYSICAL.WAREHOUSE_ID.AVAL]]
rem --- Don't allow inactive code
	ivcWhseCode_dev=fnget_dev("IVC_WHSECODE")
	dim ivcWhseCode$:fnget_tpl$("IVC_WHSECODE")
	whse_code$=callpoint!.getUserInput()
	read record (ivcWhseCode_dev,key=firm_id$+"C"+whse_code$,dom=*next)ivcWhseCode$
	if ivcWhseCode.code_inactive$ = "Y"
		msg_id$="AD_CODE_INACTIVE"
		dim msg_tokens$[2]
		msg_tokens$[1]=cvs(ivcWhseCode.warehouse_id$,3)
		msg_tokens$[2]=cvs(ivcWhseCode.short_name$,3)
		gosub disp_message
		callpoint!.setStatus("ABORT")
		break
	endif

[[IVE_PHYSICAL.<CUSTOM>]]
rem ==========================================================================
check_whse_cycle: rem --- Check the Physical Cycle code for the correct status
                  rem      IN: whse$
                  rem          cycle$
                  rem     OUT: physcode
                  rem          failed - true / false
rem ==========================================================================
if callpoint!.getUserInput()=callpoint!.getColumnData("IVE_PHYSICAL.PI_CYCLECODE") then return

	failed = 0
	ivc_physcode = fnget_dev("IVC_PHYSCODE")
	dim ivc_physcode$:fnget_tpl$("IVC_PHYSCODE")
	find record (ivc_physcode, key=firm_id$+whse$+cycle$)ivc_physcode$

	if ivc_physcode.phys_inv_sts$ <> "2" then 
		if ivc_physcode.phys_inv_sts$ = "0" then
			msg_id$ = "IV_PHYS_NOT_FROZEN"
			gosub disp_message
			failed = 1
		else
			if ivc_physcode.phys_inv_sts$ = "1" then
				msg_id$ = "IV_PHYS_NOT_PRINTED"
				gosub disp_message
				failed = 1
			else
				if ivc_physcode.phys_inv_sts$ = "3" then	
					msg_id$ = "IV_PHYS_ALREADY_REG"
					gosub disp_message
					failed = 1
				endif
			endif
		endif
	endif

	if !failed
		callpoint!.setColumnData("IVE_PHYSICAL.CUTOFF_DATE",ivc_physcode.cutoff_date$,1)
	endif
	return

rem ==========================================================================
check_item_whse: rem --- Check that a warehouse record exists for this item
                 rem      IN: whse$
                 rem          item$
                 rem     OUT: failed  (true/false)
                 rem          ivm_itemmast$ (item record)
                 rem          ivm_itemwhse$ (item/whse record)
                 rem          enable lot/serial$ field
rem ==========================================================================

	ivm_itemmast=fnget_dev("IVM_ITEMMAST")
	dim ivm_itemmast$:fnget_tpl$("IVM_ITEMMAST")
	find record (ivm_itemmast, key=firm_id$+item$) ivm_itemmast$

	callpoint!.setDevObject("this_item_lot_ser",iff(pos(ivm_itemmast.lotser_flag$="LS") and ivm_itemmast.inventoried$="Y",1,0))
	callpoint!.setDevObject("lotser_flag",ivm_itemmast.lotser_flag$)
	callpoint!.setColumnData("IVE_PHYSICAL.LOTSER_FLAG",ivm_itemmast.lotser_flag$,1)

	ivm_itemwhse = fnget_dev("IVM_ITEMWHSE")
	dim ivm_itemwhse$:fnget_tpl$("IVM_ITEMWHSE")

	found=0
	failed=0
	find record (ivm_itemwhse, knum="PRIMARY", key=firm_id$+whse$+item$, dom=*next) ivm_itemwhse$;found=1

	if found
		callpoint!.setColumnData("IVE_PHYSICAL.LOCATION", ivm_itemwhse.location$,1)
		if !callpoint!.getDevObject("this_item_lot_ser")
			callpoint!.setStatus("RECORD:["+firm_id$+whse$+callpoint!.getColumnData("IVE_PHYSICAL.PI_CYCLECODE")+ivm_itemwhse.location$+item$+fill(callpoint!.getDevObject("lotser_no_length"))+"]")
		endif
	else
		callpoint!.setMessage("IV_ITEM_WHSE_INVALID:" + whse$ )
		failed=1
	endif

	return

rem ==========================================================================
item_in_cycle: rem --- Is this item in the selected cycle?
               rem      IN: ivm_itemwhse$ - templated record   
               rem           ivm_itemwhse  - file channel
               rem     OUT: found - true / false
rem ==========================================================================

	found = 0
	k$ = ivm_itemwhse.firm_id$ +
:       callpoint!.getColumnData("IVE_PHYSICAL.WAREHOUSE_ID") +
:       callpoint!.getColumnData("IVE_PHYSICAL.PI_CYCLECODE") +
:       ivm_itemwhse.location$ +
:       ivm_itemwhse.item_id$

	find (ivm_itemwhse, knum="AO_WH_CYCLE_LOC", key=k$, dom=item_in_cycle_end)
	found = 1

item_in_cycle_end:
	return

rem ==========================================================================
parse_count: rem --- Parse count string, display total
             rem      IN: count$
             rem     OUT: total, displayed
             rem          failed - true / false
rem ==========================================================================

print "in parse_count"; rem debug

	num_mask$ = "^[0-9]+(\.[0-9]+)?"
	sep_mask$ = "([^0-9.] *|$)"
	total = 0
	failed = 0
	count$ = cvs(count$, 3)
	if count$ = "" then goto count_display
	p = mask(count$, num_mask$, err=count_error)

	repeat
		if p <> 1 then exitto count_error
		amt = num( count$(1, tcb(16)) )
		total = total + amt
		count$ = cvs(count$(tcb(16) + 1), 1)
		print "count$ = ", count$; rem debug
		q = mask(count$, sep_mask$, err=count_error)
		count$ = cvs(count$(tcb(16) + 1), 1)
		print "count$ = ", count$; rem debug
		p = mask(count$, num_mask$, err=count_error)
	until count$ = ""

count_display:
	callpoint!.setColumnData("IVE_PHYSICAL.ACT_PHYS_CNT", str(total),1)
	
	goto parse_count_end

count_error:
	msg_id$ = "IV_BAD_COUNT_STR"
	gosub disp_message
	failed = 1

parse_count_end:
	print "---failed =", failed; rem debug
	print "out"; rem debug
	return

rem ==========================================================================
#include [+ADDON_LIB]std_missing_params.aon
rem ==========================================================================



