[[ARM_CUSTITEMS.ARNF]]
rem --- Initialize Description for this Customer Item Number
	ivmItemMast_dev=fnget_dev("IVM_ITEMMAST")
	dim ivmItemMast$:fnget_tpl$("IVM_ITEMMAST")
	item_id$=callpoint!.getColumnData("ARM_CUSTITEMS.ITEM_ID")
	findrecord(ivmItemMast_dev,key=firm_id$+item_id$,dom=*next)ivmItemMast$
	callpoint!.setColumnData("ARM_CUSTITEMS.DESCRIPTION",ivmItemMast.item_desc$,1)

[[ARM_CUSTITEMS.BSHO]]
rem --- Open needed files
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	
	open_tables$[1]="IVM_ITEMMAST",  open_opts$[1]="OTA"

	gosub open_tables



