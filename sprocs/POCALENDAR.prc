rem ----------------------------------------------------------------------------
rem Program: POCALENDAR.prc -- sproc to return specified records from PO Calendar for display in Jasper
rem Description: returns specified records from PO Calendar for display in Jasper
rem
rem Author(s): C. Hawkins
rem
rem AddonSoftware
rem Copyright BASIS International Ltd.
rem ----------------------------------------------------------------------------

seterr sproc_error

use java.util.Calendar
use java.util.GregorianCalendar
use java.util.Locale

rem --- unrem these for live

rem --- Declare some variables ahead of time
declare BBjStoredProcedureData sp!
declare BBjRecordSet rs!
declare BBjRecordData data!

rem --- Get the infomation object for the Stored Procedure
sp! = BBjAPI().getFileSystem().getStoredProcedureData()

rem --- Get the IN and IN/OUT parameters used by the procedure
firm_id$ = sp!.getParameter("FIRM_ID")
beg_mo$=sp!.getParameter("BEGINNING_MONTH")
beg_yr$=sp!.getParameter("BEGINNING_YEAR")
end_mo$=sp!.getParameter("ENDING_MONTH")
end_yr$=sp!.getParameter("ENDING_YEAR")
barista_wd$=sp!.getParameter("BARISTA_WD")

sv_wd$=dir("")
chdir barista_wd$
nf$="Not found"
pgmdir$=stbl("+DIR_PGM",err=*next)

rem --- setting for testing when running directly
rem firm_id$="01"
rem beg_mo$="04"
rem beg_yr$="2008"
rem end_mo$="05"
rem end_yr$="2008"
rem goto bac_open
rem --- Open files with adc

    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],ids$[files],templates$[files],channels[files]
    files$[1]="pom-01",ids$[1]="POM_CALENDAR"

    call pgmdir$+"adc_fileopen.aon",action,begfile,endfile,files$[all],options$[all],
:                                   ids$[all],templates$[all],channels[all],batch,status
    if status then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif
    pom_calendar_dev = channels[1]

rem --- Dimension string templates

    dim pom_calendar$:templates$[1]

goto no_bac_open
rem --- Open/Lock files

    files=1,begfile=1,endfile=files
    dim files$[files],options$[files],chans$[files],templates$[files]
    files$[1]="POM_CALENDAR"
    for wkx=begfile to endfile
        options$[wkx]="OTA"
    next wkx
    call stbl("+DIR_SYP")+"bac_open_tables.bbj",begfile,endfile,files$[all],options$[all],
:       chans$[all],templates$[all],table_chans$[all],batch,status$
    if status$<>"" then
        seterr 0
        x$=stbl("+THROWN_ERR","TRUE")   
        throw "File open error.",1001
    endif

    pom_calendar_dev=num(chans$[1])
                    
rem --- Dimension string templates

    dim pom_calendar$:templates$[1]
no_bac_open:
    dim day_name$[6]
    dim day_status$[41]
    
    rsTemplate$="year:c(4),month:c(10*),"
    for x=1 to 7
    	rsTemplate$=rsTemplate$+"day_name_"+str(x)+":c(10*),"
    next x
    for x=1 to 42
    	rsTemplate$=rsTemplate$+"day_status_"+str(x:"00")+":c(15*),"
    next x
    rsTemplate$=rsTemplate$(1,len(rsTemplate$)-1)
    
    rs! = BBJAPI().createMemoryRecordSet(rsTemplate$)

rem --- init
rem --- get locale, and corresponding first day of week (not always Sunday)
rem --- also get !DATE, which contains date format, short/long month desc, and short/long day desc.

    Locale$=stbl("!LOCALE")
    Locale! = fnLocale!(Locale$)
    Calendar! = new GregorianCalendar(Locale!)
    firstDayOfWeek=Calendar!.getFirstDayOfWeek()

	dim date_text$:"default:c(32*=0),sm[12]:c(3*=0),m[12]:c(32*=0),sd[7]:c(3*=0),d[7]:c(32*=0)"
	date_text$=stbl("!DATE")
    day_str$="312831303130313130313031"
    
	no_columns=7

	dim day_name$[1:no_columns]
		for curr_elem=firstDayOfWeek to 7
			day_name$[curr_elem-firstDayOfWeek+1]=date_text.d$[curr_elem]
		next curr_elem
		if firstDayOfWeek > 1
			for curr_elem=1 to firstDayOfWeek-1
				day_name$[7-firstDayOfWeek+2]=date_text.d$[curr_elem]
			next curr_elem
		endif

	year$=beg_yr$
	month$=beg_mo$
	readrecord(pom_calendar_dev,key=firm_id$+year$+month$,dir=0,err=*next)pom_calendar$
	
rem --- read loop

    while 1
		read record(pom_calendar_dev,end=*break)pom_calendar$
		if pom_calendar.firm_id$<>firm_id$ then break
		if pom_calendar.year$+pom_calendar.month$>end_yr$+end_mo$ then break		
		month_name$=date_text.m$[num(pom_calendar.month$)]
		curr_yr=num(pom_calendar.year$)
		curr_mo=num(pom_calendar.month$)
		rem --- get day of week of first day of month			
		start_day=num(date(jul(curr_yr,curr_mo,1):"%W"))
		rem --- above returns day of week relative to Sunday
		rem --- adjust for firstDayOfWeek as indicated by locale
		start_day=start_day-(firstDayOfWeek-1)
		if start_day<=0 start_day=start_day+7			
		no_days=num(day_str$(curr_mo*2-1,2))
		if mod(curr_yr,4)=0 and curr_mo=2 then no_days=29
		
		dim day_text$[42]
		for x=1 to no_days
			switch pos(field(pom_calendar$,"DAY_STATUS_"+str(x:"00"))="CHW")
				case 1
					day_text$[start_day+x-1]=str(x)+" - Closed"
				break
				case 2
					day_text$[start_day+x-1]=str(x)+" - Holiday"
				break
				case 3
					day_text$[start_day+x-1]=str(x)+" - Workday"
				break
				case default
					day_text$[start_day+x-1]=str(x)
				break
			swend		
		next x

		data! = rs!.getEmptyRecordData()
		data!.setFieldValue("month",month_name$)
		data!.setFieldValue("year",pom_calendar.year$)
		for x=1 to 7
			data!.setFieldValue("DAY_NAME_"+str(x),day_name$[x])
		next x
		for x=1 to 42
			data!.setFieldValue("DAY_STATUS_"+str(x:"00"),day_text$[x])
		next x
		rs!.insert(data!)

	wend	

done:
sp!.setRecordSet(rs!)
end

do_output_test:
        data! = rs!.getEmptyRecordData()
        data!.setFieldValue("month", test$)
        rs!.insert(data!)
return


rem --- locale function

def fnLocale!(Locale$)
  Locale$ = cvs(Locale$,3)
   switch pos("_"=Locale$,1,0)
     case 0
       return new Locale(Locale$)
     case 1; rem ' language_country
       p = pos("_"=Locale$)
       language$ = cvs(Locale$(1,p-1),8)
       country$ = cvs(Locale$(p+1),4)
       return new Locale(language$,country$)
     case 2; rem ' language_country_modifier
       p1 = pos("_"=Locale$)
       p2 = pos("_"=Locale$(p1+1))
       language$ = cvs(Locale$(1,p1-1),8)
       country$ = cvs(Locale$(p1+1,p2-1),4)
       modifier$ = Locale$(p1+p2)
       return new Locale(language$,country$,modifier$)
     case default; rem ' invalid format
       return new Locale(Locale$)
   swend
 fnend


rem --- Date/time handling functions

    def fndate$(q$)
        q1$=""
        q1$=date(jul(num(q$(1,4)),num(q$(5,2)),num(q$(7,2)),err=*next),err=*next)
        if q1$="" q1$=q$
        return q1$
    fnend

sproc_error:rem --- SPROC error trap/handler
    rd_err_text$="", err_num=err
    if tcb(2)=0 and tcb(5) then rd_err_text$=pgm(tcb(5),tcb(13),err=*next)
    x$=stbl("+THROWN_ERR","TRUE")   
    throw "["+pgm(-2)+"] "+str(tcb(5))+": "+rd_err_text$,err_num
