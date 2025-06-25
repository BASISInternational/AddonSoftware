[[OPM_POINTOFSALE.ADIS]]
rem --- Default Warehouse is required when Warehouse Entry is skipped

if callpoint!.getColumnData("OPM_POINTOFSALE.SKIP_WHSE")="Y"
	callpoint!.setTableColumnAttribute("OPM_POINTOFSALE.WAREHOUSE_ID","MINL","1")
else
	callpoint!.setTableColumnAttribute("OPM_POINTOFSALE.WAREHOUSE_ID","MINL","0")
endif

[[OPM_POINTOFSALE.BSHO]]
rem --- Inits

	use ::ado_func.src::func
	use ::ado_config.src::Config
	use java.util.HashMap

	declare Config config!
	config! = new Config()

	declare HashMap UserObj! 
	UserObj! = new HashMap()
	UserObj!.put("config", config!)
	UserObj!.put("aliases", config!.getAliasBBxNames())

rem --- Open/Lock files

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="IVC_WHSECODE",open_opts$[1]="OTA"

	gosub open_tables

[[OPM_POINTOFSALE.BWRI]]
rem --- Re-check all tests and abort if fail

	list$  = callpoint!.getColumnData("OPM_POINTOFSALE.VAL_CTR_PRT")
	alias$ = callpoint!.getColumnData("OPM_POINTOFSALE.CNTR_PRINTER")

	if alias$ <> "" then
		gosub alias_in_list

		if !valid then
			callpoint!.setFocus("OPM_POINTOFSALE.CNTR_PRINTER")
		endif
	endif

	list$  = callpoint!.getColumnData("OPM_POINTOFSALE.VAL_REC_PRT")
	alias$ = callpoint!.getColumnData("OPM_POINTOFSALE.REC_PRINTER")

	if alias$ <> "" then
		gosub alias_in_list

		if !valid then
			callpoint!.setFocus("OPM_POINTOFSALE.REC_PRINTER")
		endif
	endif

	

[[OPM_POINTOFSALE.CASH_BX_HEX.AVAL]]
rem --- Valid Hex?

	hex$ = callpoint!.getUserInput()

	if hex$ <> "" and !func.isHex(hex$) then
		callpoint!.setMessage("NOT_HEX")
		callpoint!.setStatus("ABORT")
	endif

[[OPM_POINTOFSALE.CASH_BX_PORT.AVAL]]
rem --- Check alias, is it in the config file?

	port$ = callpoint!.getUserInput()

	if port$ <> "" then

		declare Config config!
		config! = cast(Config, UserObj!.get("config"))

		if !config!.isAlias(port$) then
			callpoint!.setMessage("NOT_AN_ALIAS")
			callpoint!.setStatus("ABORT")
		endif

	endif

[[OPM_POINTOFSALE.CNTR_PRINTER.AVAL]]
rem --- Must be in the entered list of valid printer aliases

	list$  = callpoint!.getColumnData("OPM_POINTOFSALE.VAL_CTR_PRT")
	alias$ = callpoint!.getUserInput()

	if alias$ <> "" then
		gosub alias_in_list
	endif

[[OPM_POINTOFSALE.LAST_MDP_HEX.AVAL]]
rem --- Valid Hex?

	hex$ = callpoint!.getUserInput()

	if hex$ <> "" and !func.isHex(hex$) then
		callpoint!.setMessage("NOT_HEX")
		callpoint!.setStatus("ABORT")
	endif

[[OPM_POINTOFSALE.REC_PRINTER.AVAL]]
rem --- Must be in the entered list of valid printer aliases

	list$  = callpoint!.getColumnData("OPM_POINTOFSALE.VAL_REC_PRT")
	alias$ = callpoint!.getUserInput()

	if alias$ <> "" then
		gosub alias_in_list
	endif

[[OPM_POINTOFSALE.REC_PRT_PORT.AVAL]]
rem --- Check alias, is it in the config file?

	port$ = callpoint!.getUserInput()

	if port$ <> "" then

		declare Config config!
		config! = cast(Config, UserObj!.get("config"))

		if !config!.isAlias(port$) then
			callpoint!.setMessage("NOT_AN_ALIAS")
			callpoint!.setStatus("ABORT")
		endif

	endif

[[OPM_POINTOFSALE.SKIP_WHSE.AVAL]]
rem --- Default Warehouse is required when Warehouse Entry is skipped

if callpoint!.getUserInput()="Y"
	callpoint!.setTableColumnAttribute("OPM_POINTOFSALE.WAREHOUSE_ID","MINL","1")
else
	callpoint!.setTableColumnAttribute("OPM_POINTOFSALE.WAREHOUSE_ID","MINL","0")
endif

[[OPM_POINTOFSALE.TRANSPAR_OFF.AVAL]]
rem --- Valid Hex?

	hex$ = callpoint!.getUserInput()

	if hex$ <> "" and !func.isHex(hex$) then
		callpoint!.setMessage("NOT_HEX")
		callpoint!.setStatus("ABORT")
	endif

[[OPM_POINTOFSALE.TRANSPAR_ON.AVAL]]
rem --- Valid Hex?

	hex$ = callpoint!.getUserInput()

	if hex$ <> "" and !func.isHex(hex$) then
		callpoint!.setMessage("NOT_HEX")
		callpoint!.setStatus("ABORT")
	endif

[[OPM_POINTOFSALE.VAL_CTR_PRT.AVAL]]
rem --- Validate list of counter printers
rem --- Currently, aliases can only be len=2

	list$ = callpoint!.getUserInput()

	if list$ <> "" then
		gosub valid_list
	endif

[[OPM_POINTOFSALE.VAL_REC_PRT.AVAL]]
rem --- Validate list of counter printers
rem --- Currently, aliases can only be len=2

	list$ = callpoint!.getUserInput()

	if list$ <> "" then
		gosub valid_list
	endif

[[OPM_POINTOFSALE.WAREHOUSE_ID.AVAL]]
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

[[OPM_POINTOFSALE.<CUSTOM>]]
rem ==========================================================================
valid_list: rem --- Are all aliases in the config file?
            rem     Currently aliases can only be a length of 2
            rem      IN: list$ - list of aliases
rem ==========================================================================

	if mod(len(list$), 2) <> 0 then
		callpoint!.setMessage("ALIAS_LEN_OF_TWO")
		callpoint!.setStatus("ABORT")
	else

		declare BBjVector aliases!
		aliases! = cast(BBjVector, UserObj!.get("aliases"))

		for i=1 to len(list$) step 2
			missing = 1

			for j=0 to aliases!.size()-1
				if list$(i,2) = str(aliases!.get(j)) then
					missing = 0
					break
				endif
			next j

			if missing then break

		next i

		if missing then
			callpoint!.setMessage("ALIAS_NOT_FOUND")
			callpoint!.setStatus("ABORT")
		endif

	endif

return

rem ==========================================================================
alias_in_list: rem --- Is this alias in the list of valid aliases?
               rem      IN: list$ - list of valid aliases
               rem          aliase$ - the alias to check
               rem     OUT: valid - true/false
rem ==========================================================================

	valid = 1

	if list$ = "" then
		callpoint!.setMessage("ALIAS_LIST_NOT_SET")
		valid = 0
	else
		missing = 1

		for i=1 to len(list$) step 2
			if alias$ = list$(i, 2) then
				missing = 0
				break
			endif
		next i

		if missing then
			callpoint!.setMessage("ALIAS_NOT_IN_LIST")
			valid = 0
		endif

	endif

return



