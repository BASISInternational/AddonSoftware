[[ADM_RPTDIRHDR.AREC]]
rem --- Initialize company_id to the current firm_id
callpoint!.setColumnData("ADM_RPTDIRHDR.COMPANY_ID",firm_id$,1)

[[ADM_RPTDIRHDR.BSHO]]
rem --- Open and lock files
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="ADM_MODULES",open_opts$[1]="OTA"

	gosub open_tables



