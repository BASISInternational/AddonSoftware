[[APR_RECURRING.ARAR]]
rem --- Default next_issued_date
	today_date$=sysinfo.system_date$
	today_jul=jul(num(today_date$(1,4)),num(today_date$(5,2)),num(today_date$(7,2)))
	recurring_window=num(callpoint!.getDevObject("recurring_window"))
	next_date$=date(today_jul+recurring_window:"%Yl%Mz%Dz")
          
	call stbl("+DIR_PGM")+"glc_datecheck.aon",next_date$,"N",period$,year$,status
	if status<100
		callpoint!.setColumnData("APR_RECURRING.NEXT_ISSUED_DATE",next_date$,1)
	endif

[[APR_RECURRING.ASVA]]
rem --- Validate Date
	end_date$=callpoint!.getColumnData("APR_RECURRING.NEXT_ISSUED_DATE")
	call stbl("+DIR_PGM")+"glc_datecheck.aon",end_date$,"Y",period$,year$,status
	if status>99 
		callpoint!.setStatus("ABORT")
	endif

[[APR_RECURRING.BEND]]
release

[[APR_RECURRING.BSHO]]
rem --- Open Parameter file
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="APS_PARAMS",open_opts$[1]="OTA"
	gosub open_tables

	aps01_dev=num(open_chans$[1])
	dim aps01a$:open_tpls$[1]

	 read record (aps01_dev,key=firm_id$+"AP00",dom=std_missing_params)aps01a$
	 if aps01a.recurring_window=0 then
		aps01a.recurring_window=30
	endif
	callpoint!.setDevObject("recurring_window",aps01a.recurring_window)

[[APR_RECURRING.<CUSTOM>]]
#include [+ADDON_LIB]std_missing_params.aon



