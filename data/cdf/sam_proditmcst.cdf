[[SAM_PRODITMCST.ADIS]]
rem --- Create totals

	gosub calc_totals

	if cvs(callpoint!.getColumnData("SAM_PRODITMCST.YEAR"),3)<>""
		cwin!=callpoint!.getDevObject("cwin")
		SAWidget!=callpoint!.getDevObject("barWidget")
		widget!=SAWidget!.getWidget()
		filterLeft! = SAWidget!.getDashboardWidgetFilterLeft()
		if filterLeft!.getKey()="sales"
			gosub set_widget_sales_data
		else
			gosub set_widget_units_data
		endif
		cwin!.setVisible(1)
	endif

rem --- Enable/Disable Summary button

	prod_type$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_no$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	cust_no$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	gosub summ_button
 

[[SAM_PRODITMCST.AOPT-SUMM]]
rem --- Calculate and display summary info
	tcst=0
	tqty=0
	tsls=0
	year$=callpoint!.getColumnData("SAM_PRODITMCST.YEAR")
	lyear$=str(num(year$)-1:"0000")
	trip_key$=firm_id$+year$+callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	ltrip_key$=firm_id$+lyear$+callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_no$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	cust_no$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	if cvs(item_no$,2)<>"" 
		trip_key$=trip_key$+item_no$
		ltrip_key$=ltrip_key$+item_no$
	else
		callpoint!.setColumnData("SAM_PRODITMCST.ITEM_ID","")
	endif
	callpoint!.setColumnData("SAM_PRODITMCST.CUSTOMER_ID","")

rem --- Start progress meter
	task_id$=info(3,0)
	Window_Name$=Translate!.getTranslation("AON_SUMMARIZING")
	Progress! = bbjapi().getGroupNamespace()
	Progress!.setValue("+process_task",task_id$+"^C^"+Window_Name$+"^CNC-IND^"+str(n)+"^")

	sam_dev=	fnget_dev("SAM_PRODITMCST")
	dim sam_tpl$:fnget_tpl$("SAM_PRODITMCST")
	dim qty[13],cost[13],sales[13]
	hshThisYear! = new java.util.HashMap()
	hshLastYear! = new java.util.HashMap()

	for x=1 to 13
		hshLastYear!.put("cost"+str(x:"00"),0)
		hshLastYear!.put("sales"+str(x:"00"),0)
		hshLastYear!.put("units"+str(x:"00"),0)
		hshThisYear!.put("cost"+str(x:"00"),0)
		hshThisYear!.put("sales"+str(x:"00"),0)
		hshThisYear!.put("units"+str(x:"00"),0)
	next x

	hi_amount=0
	hi_count=0

rem --- Calculate Last Year

	read(sam_dev,key=ltrip_key$,knum="AO_PRD_ITM_CST",dom=*next)
	while 1
		read record(sam_dev,end=*break)sam_tpl$

		Progress!.getValue("+process_task_"+task_id$,err=*next);break
	
		if pos(ltrip_key$=sam_tpl$)<>1 break
		for x=1 to 13
			qty[x]=qty[x]+nfield(sam_tpl$,"qty_shipped_"+str(x:"00"))
			cost[x]=cost[x]+nfield(sam_tpl$,"total_cost_"+str(x:"00"))
			sales[x]=sales[x]+nfield(sam_tpl$,"total_sales_"+str(x:"00"))
			hshLastYear!.put("cost"+str(x:"00"),str(cost[x]))
			hshLastYear!.put("sales"+str(x:"00"),str(sales[x]))
			hshLastYear!.put("units"+str(x:"00"),str(qty[x]))
		next x
	wend
	For x=1 to 13
		tcst=tcst+cost[x]
		tqty=tqty+qty[x]
		tsls=tsls+sales[x]
		if cost[x]>hi_amount  then hi_amount=cost[x]
		if sales[x]>hi_amount then hi_amount=sales[x]
		if qty[x]>hi_count then hi_count=qty[x]
	next x

	for x=1 to 13
		callpoint!.setColumnData("<<DISPLAY>>.LY_SHIP_"+str(x:"00"),str(qty[x]))
		callpoint!.setColumnData("<<DISPLAY>>.LY_SALES_"+str(x:"00"),str(sales[x]))
		callpoint!.setColumnData("<<DISPLAY>>.LY_COST_"+str(x:"00"),str(cost[x]))
	next x

	callpoint!.setColumnData("<<DISPLAY>>.LY_COST_TOT",str(tcst))
	callpoint!.setColumnData("<<DISPLAY>>.LY_SALES_TOT",str(tsls))
	callpoint!.setColumnData("<<DISPLAY>>.LY_SHIP_TOT",str(tqty))

	tcst=0
	tsls=0
	tqty=0
	dim cost[13],qty[13],sales[13]

rem --- Calculate This Year

	read(sam_dev,key=trip_key$,knum="AO_PRD_ITM_CST",dom=*next)
	while 1
		sam_key$=key(sam_dev,end=*break)
		if pos(trip_key$=sam_key$)<>1 break
		read record(sam_dev,knum="AO_PRD_ITM_CST",key=sam_key$)sam_tpl$

		Progress!.getValue("+process_task_"+task_id$,err=*next);break

		for x=1 to 13
			qty[x]=qty[x]+nfield(sam_tpl$,"qty_shipped_"+str(x:"00"))
			cost[x]=cost[x]+nfield(sam_tpl$,"total_cost_"+str(x:"00"))
			sales[x]=sales[x]+nfield(sam_tpl$,"total_sales_"+str(x:"00"))
			hshThisYear!.put("cost"+str(x:"00"),str(cost[x]))
			hshThisYear!.put("sales"+str(x:"00"),str(sales[x]))
			hshThisYear!.put("units"+str(x:"00"),str(qty[x]))
		next x
	wend
	For x=1 to 13
		tcst=tcst+cost[x]
		tqty=tqty+qty[x]
		tsls=tsls+sales[x]
		if cost[x]>hi_amount  then hi_amount=cost[x]
		if sales[x]>hi_amount then hi_amount=sales[x]
		if qty[x]>hi_count then hi_count=qty[x]
	next x

Progress!.setValue("+process_task",task_id$+"^D^")

rem --- Now display all of these things and disable key fields
	for x=1 to 13
		callpoint!.setColumnData("SAM_PRODITMCST.TOTAL_SALES_"+str(x:"00"),str(sales[x]))
		callpoint!.setColumnData("SAM_PRODITMCST.TOTAL_COST_"+str(x:"00"),str(cost[x]))
		callpoint!.setColumnData("SAM_PRODITMCST.QTY_SHIPPED_"+str(x:"00"),str(qty[x]))
	next x
	callpoint!.setColumnData("<<DISPLAY>>.TCST",str(tcst))
	callpoint!.setColumnData("<<DISPLAY>>.TQTY",str(tqty))
	callpoint!.setColumnData("<<DISPLAY>>.TSLS",str(tsls))

	callpoint!.setColumnEnabled("SAM_PRODITMCST.YEAR",0)
	callpoint!.setColumnEnabled("SAM_PRODITMCST.PRODUCT_TYPE",0)
	callpoint!.setColumnEnabled("SAM_PRODITMCST.ITEM_ID",0)
	callpoint!.setColumnEnabled("SAM_PRODITMCST.CUSTOMER_ID",0)
	callpoint!.setOptionEnabled("SUMM",0)
	callpoint!.setStatus("REFRESH-CLEAR")

	callpoint!.setDevObject("hshThisYear",hshThisYear!)
	callpoint!.setDevObject("hshLastYear",hshLastYear!)
	callpoint!.setDevObject("hiAmount",hi_amount)
	callpoint!.setDevObject("hiCount",hi_count)

	if cvs(callpoint!.getColumnData("SAM_PRODITMCST.YEAR"),3)<>""
		cwin!=callpoint!.getDevObject("cwin")
		SAWidget!=callpoint!.getDevObject("barWidget")
		widget!=SAWidget!.getWidget()
		filterLeft! = SAWidget!.getDashboardWidgetFilterLeft()
		if filterLeft!.getKey()="sales"
			gosub set_widget_sales_data
		else
			gosub set_widget_units_data
		endif
		cwin!.setVisible(1)
	endif

[[SAM_PRODITMCST.AREC]]
rem --- Enable key fields
	callpoint!.setColumnEnabled("SAM_PRODITMCST.YEAR",1)
	callpoint!.setColumnEnabled("SAM_PRODITMCST.CUSTOMER_ID",1)
	callpoint!.setColumnEnabled("SAM_PRODITMCST.PRODUCT_TYPE",1)
	callpoint!.setColumnEnabled("SAM_PRODITMCST.ITEM_ID",1)

	callpoint!.setColumnData("<<DISPLAY>>.TCST","0")
	callpoint!.setColumnData("<<DISPLAY>>.TQTY","0")
	callpoint!.setColumnData("<<DISPLAY>>.TSLS","0")

	for x=1 to 13
		callpoint!.setColumnData("<<DISPLAY>>.LY_SHIP_"+str(x:"00"),"0")
		callpoint!.setColumnData("<<DISPLAY>>.LY_SALES_"+str(x:"00"),"0")
		callpoint!.setColumnData("<<DISPLAY>>.LY_COST_"+str(x:"00"),"0")
	next x

	callpoint!.setColumnData("<<DISPLAY>>.LY_COST_TOT","0")
	callpoint!.setColumnData("<<DISPLAY>>.LY_SALES_TOT","0")
	callpoint!.setColumnData("<<DISPLAY>>.LY_SHIP_TOT","0")

rem --- Enable/Disable Summary button

	prod_type$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_no$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	cust_no$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	gosub summ_button

rem --- clear out the widget

	SAWidget!=callpoint!.getDevObject("barWidget")
	widget!=SAWidget!.getWidget()
	widget!.clearDataSet()
	widget!.refresh()

	cwin!=callpoint!.getDevObject("cwin")
	cwin!.setVisible(0)

	callpoint!.setStatus("REFRESH")

[[SAM_PRODITMCST.ASHO]]
rem - create stacked bar chart widget

	gosub create_widget

[[SAM_PRODITMCST.BNEK]]
rem --- Use current selections for initiating next record
	year$=callpoint!.getColumnData("SAM_PRODITMCST.YEAR")
	product_type$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_id$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	sam_dev=fnget_dev("SAM_PRODITMCST")
	customer_id$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	read(sam_dev,key=firm_id$+year$+product_type$+item_id$+customer_id$,dom=*next)

[[SAM_PRODITMCST.BOVE]]
rem --- Restrict lookup to orders
			
	alias_id$ = "SAM_CUSTOMER"
	inq_mode$ = ""
	key_pfx$  = firm_id$
	key_id$   = "AO_PRD_ITM_CST"
			
	dim filter_defs$[1,1]
			
	call stbl("+DIR_SYP")+"bam_inquiry.bbj",
:		gui_dev,
:		Form!,
:		alias_id$,
:		inq_mode$,
:		table_chans$[all],
:		key_pfx$,
:		key_id$,
:		selected_key$,
:		filter_defs$[all],
:		search_defs$[all]
			
	if selected_key$<>"" then 
		callpoint!.setStatus("RECORD:[" + selected_key$ +"]")
	else
		callpoint!.setStatus("ABORT")
	endif
	callpoint!.setStatus("ACTIVATE")

[[SAM_PRODITMCST.BPRK]]
rem --- Use current selections for initiating previous record
	year$=callpoint!.getColumnData("SAM_PRODITMCST.YEAR")
	product_type$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_id$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	sam_dev=fnget_dev("SAM_PRODITMCST")
	customer_id$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	read(sam_dev,key=firm_id$+year$+product_type$+item_id$+customer_id$,dir=0,dom=*next)

[[SAM_PRODITMCST.BSHO]]
rem --- Check for parameter record
	num_files=3
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]="SAS_PARAMS",open_opts$[1]="OTA"
	open_tables$[2]="SAM_PRODITMCST",open_opts$[2]="OTA@"
	open_tables$[3]="GLS_CALENDAR",open_opts$[3]="OTA"
	gosub open_tables
	sas01_dev=num(open_chans$[1]),sas01a$=open_tpls$[1]

	dim sas01a$:sas01a$
	read record (sas01_dev,key=firm_id$+"SA00")sas01a$
	if sas01a.by_customer$<>"Y"
		msg_id$="INVALID_SA"
		dim msg_tokens$[1]
		msg_tokens$[1]=Translate!.getTranslation("AON_CUSTOMER")
		gosub disp_message
		bbjAPI!=bbjAPI()
		rdFuncSpace!=bbjAPI!.getGroupNamespace()
		rdFuncSpace!.setValue("+build_task","OFF")
		release
	endif

rem --- disable total elements
	callpoint!.setColumnEnabled("<<DISPLAY>>.TQTY",-1)
	callpoint!.setColumnEnabled("<<DISPLAY>>.TCST",-1)
	callpoint!.setColumnEnabled("<<DISPLAY>>.TSLS",-1)

[[SAM_PRODITMCST.CUSTOMER_ID.AVAL]]
rem --- Enable/Disable Summary button
	prod_type$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_no$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	cust_no$=callpoint!.getUserInput()
	gosub summ_button

[[SAM_PRODITMCST.ITEM_ID.AINV]]
rem --- Item synonym processing

	call stbl("+DIR_PGM")+"ivc_itemsyn.aon::option_entry"

[[SAM_PRODITMCST.ITEM_ID.AVAL]]
rem --- Enable/Disable Summary button
	prod_type$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item_no$=callpoint!.getUserInput()
	cust_no$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	gosub summ_button

[[SAM_PRODITMCST.PRODUCT_TYPE.AVAL]]
rem --- Enable/Disable Summary button
	prod_type$=callpoint!.getUserInput()
	item_no$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	cust_no$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	gosub summ_button

[[SAM_PRODITMCST.YEAR.AVAL]]
rem --- Use fiscal period and abbreviation for table row label
	year$=callpoint!.getUserInput()
	aon_period$=Translate!.getTranslation("AON_PERIOD")
	gls_calendar=fnget_dev("GLS_CALENDAR")
	dim gls_calendar$:fnget_tpl$("GLS_CALENDAR")
	findrecord(gls_calendar,key=firm_id$+year$,dom=*next)gls_calendar$
	for i=1 to 13
		period$=str(i:"00")
		mthAbbr$=field(gls_calendar$,"abbr_name_"+period$)
		if cvs(mthAbbr$,2)="" then continue
		ctlContext=num(callpoint!.getTableColumnAttribute("SAM_PRODITMCST.QTY_SHIPPED_"+period$,"CTLC"))
		ctlID=num(callpoint!.getTableColumnAttribute("SAM_PRODITMCST.QTY_SHIPPED_"+period$,"CTLI"))
		ctlLabel!=SysGUI!.getWindow(ctlContext).getControl(ctlID-1000)
		ctlLabel!.setLocation(ctlLabel!.getX()-25,ctlLabel!.getY())
		ctlLabel!.setSize(ctlLabel!.getWidth()+25,ctlLabel!.getHeight())
		ctlLabel!.setText(aon_period$+" "+period$+" - "+mthAbbr$+":")
	next i

[[SAM_PRODITMCST.<CUSTOM>]]
rem ========================================================
calc_totals:
rem ========================================================

	rem --- Calculate Last Year

	year$=callpoint!.getColumnData("SAM_PRODITMCST.YEAR")
	lyear$=str(num(year$)-1:"0000")
	cust_no$=callpoint!.getColumnData("SAM_PRODITMCST.CUSTOMER_ID")
	prod$=callpoint!.getColumnData("SAM_PRODITMCST.PRODUCT_TYPE")
	item$=callpoint!.getColumnData("SAM_PRODITMCST.ITEM_ID")
	ltrip_key$=firm_id$+lyear$+prod$+item$+cust_no$
	sam_dev=fnget_dev("@SAM_PRODITMCST")
	dim sam_tpl$:fnget_tpl$("@SAM_PRODITMCST")
	dim qty[13],cost[13],sales[13]
	hshThisYear! = new java.util.HashMap()
	hshLastYear! = new java.util.HashMap()

	for x=1 to 13
		hshLastYear!.put("cost"+str(x:"00"),0)
		hshLastYear!.put("sales"+str(x:"00"),0)
		hshLastYear!.put("units"+str(x:"00"),0)
		hshThisYear!.put("cost"+str(x:"00"),0)
		hshThisYear!.put("sales"+str(x:"00"),0)
		hshThisYear!.put("units"+str(x:"00"),0)
	next x

	hi_amount=0
	hi_count=0

	while 1
		read record(sam_dev,key=ltrip_key$,knum="AO_PRD_ITM_CST",dom=*break)sam_tpl$

		Progress!.getValue("+process_task_"+task_id$,err=*next);break
	
		if pos(ltrip_key$=sam_tpl.firm_id$+sam_tpl.year$+sam_tpl.product_type$+sam_tpl.item_id$+sam_tpl.customer_id$)<>1 break
		for x=1 to 13
			qty[x]=qty[x]+nfield(sam_tpl$,"qty_shipped_"+str(x:"00"))
			cost[x]=cost[x]+nfield(sam_tpl$,"total_cost_"+str(x:"00"))
			sales[x]=sales[x]+nfield(sam_tpl$,"total_sales_"+str(x:"00"))
			hshLastYear!.put("cost"+str(x:"00"),str(cost[x]))
			hshLastYear!.put("sales"+str(x:"00"),str(sales[x]))
			hshLastYear!.put("units"+str(x:"00"),str(qty[x]))
		next x
		break
	wend
	For x=1 to 13
		tcst=tcst+cost[x]
		tqty=tqty+qty[x]
		tsls=tsls+sales[x]
		if cost[x]>hi_amount  then hi_amount=cost[x]
		if sales[x]>hi_amount then hi_amount=sales[x]
		if qty[x]>hi_count then hi_count=qty[x]
	next x

	for x=1 to 13
		callpoint!.setColumnData("<<DISPLAY>>.LY_SHIP_"+str(x:"00"),str(qty[x]))
		callpoint!.setColumnData("<<DISPLAY>>.LY_SALES_"+str(x:"00"),str(sales[x]))
		callpoint!.setColumnData("<<DISPLAY>>.LY_COST_"+str(x:"00"),str(cost[x]))
	next x

	callpoint!.setColumnData("<<DISPLAY>>.LY_COST_TOT",str(tcst))
	callpoint!.setColumnData("<<DISPLAY>>.LY_SALES_TOT",str(tsls))
	callpoint!.setColumnData("<<DISPLAY>>.LY_SHIP_TOT",str(tqty))

	rem --- Calculate This Year
	tcst=0
	tqty=0
	tsls=0
	For x=1 to 13
		cst=num(callpoint!.getColumnData("SAM_PRODITMCST.TOTAL_COST_"+str(x:"00")))
		qty=num(callpoint!.getColumnData("SAM_PRODITMCST.QTY_SHIPPED_"+str(x:"00")))
		sls=num(callpoint!.getColumnData("SAM_PRODITMCST.TOTAL_SALES_"+str(x:"00")))
		tcst=tcst+cst
		tqty=tqty+qty
		tsls=tsls+sls
		hshThisYear!.put("cost"+str(x:"00"),cst)
		hshThisYear!.put("sales"+str(x:"00"),sls)
		hshThisYear!.put("units"+str(x:"00"),qty)
		if cst>hi_amount  then hi_amount=cst
		if sls>hi_amount then hi_amount=sls
		if qty>hi_count then hi_count=qty
	next x

	callpoint!.setColumnData("<<DISPLAY>>.TCST",str(tcst))
	callpoint!.setColumnData("<<DISPLAY>>.TQTY",str(tqty))
	callpoint!.setColumnData("<<DISPLAY>>.TSLS",str(tsls))

	callpoint!.setDevObject("hshThisYear",hshThisYear!)
	callpoint!.setDevObject("hshLastYear",hshLastYear!)
	callpoint!.setDevObject("hiAmount",hi_amount)
	callpoint!.setDevObject("hiCount",hi_count)
	callpoint!.setStatus("REFRESH")

	return

rem ========================================================
rem --- Enable/Disable Summary Button
summ_button:
rem ========================================================

	callpoint!.setOptionEnabled("SUMM",1)
	if cvs(prod_type$,2)=""
		callpoint!.setOptionEnabled("SUMM",0)
	else
		if cvs(item_no$,2)=""
			if cvs(cust_no$,2)<>""
				callpoint!.setOptionEnabled("SUMM",0)
			endif
		else
			if cvs(cust_no$,2)<>""
				callpoint!.setOptionEnabled("SUMM",0)
			endif
		endif
	endif
	return

rem ========================================================
create_widget:rem --- create line chart widget to show sales and cost for selected and prior years
rem ========================================================

	use ::ado_util.src::util
	use ::dashboard/dashboard.bbj::DashboardWidget
	use ::dashboard/dashboard.bbj::DashboardWidgetFilter
	use ::dashboard/widget.bbj::EmbeddedWidgetFactory
	use ::dashboard/widget.bbj::EmbeddedWidget
	use ::dashboard/widget.bbj::EmbeddedWidgetControl
	use ::dashboard/widget.bbj::LineChartWidget
	use ::dashboard/widget.bbj::BarChartWidget
	use ::dashboard/widget.bbj::StackedBarChartWidget
	use ::dashboard/widget.bbj::ChartWidget
	use java.util.LinkedHashMap

	ctl1!=callpoint!.getControl("SAM_PRODITMCST.YEAR")
	ctl2!=callpoint!.getControl("<<DISPLAY>>.LY_SALES_01")

	widgetY=ctl1!.getY()
	widgetHeight=ctl2!.getY()-ctl2!.getHeight()-ctl1!.getY()-5
	widgetWidth=widgetHeight+widgetHeight*.75
	widgetX=ctl2!.getX()+ctl2!.getWidth()-widgetWidth

	ctxt=SysGUI!.getAvailableContext()
	custom_ctl=num(stbl("+CUSTOM_CTL"))
	cwin!=form!.addChildWindow(custom_ctl,widgetX,widgetY,widgetWidth,widgetHeight, "", $00000810$, ctxt)

rem --- create StackedBarChartEmbeddedWidget to show sales and cost for selected and prior years

	widgetName$ = "SACust"
	title$ = "Analysis by Prod/Item/Cust"
	chartTitle$ = ""
	domainTitle$ = ""
	rangeTitle$ = "in 1000's"
	flat=0
	orientation=StackedBarChartWidget.getORIENTATION_HORIZONTAL() 
	legend=1

	SAWidget! = EmbeddedWidgetFactory.createStackedBarChartEmbeddedWidget(widgetName$,title$,chartTitle$,domainTitle$,rangeTitle$,flat,orientation,legend)
	widget! = SAWidget!.getWidget()

	widget!.setChartRangeAxisToCurrency()
	widget!.setFontScalingFactor(0.5)
	rem widget!.setLabelsInBarChartColor("#000000")
	widget!.clearDataSet()

	rem --- Create a filter to allow switching between sales/cost and units views
	filterName$ = "AnalysisType"
	filterHashMap! = new LinkedHashMap()
	filterHashMap!.put("sales","Sales and Cost")
	filterHashMap!.put("units","Units")
	toolTip$ = "Select an analysis type for the chart"
	filterListButton! = SAWidget!.addFilter(filterName$, filterHashMap!, toolTip$, DashboardWidget.getDOCK_LEFT(), DashboardWidget.getFILTER_TYPE_LISTBUTTON())
	filterListButton!.setCallback(DashboardWidgetFilter.getON_FILTER_SELECT(),pgm(-2) + "::OnFilterSelectAnalysisType")
	filterListButton!.selectFilter("sales")

	SAWidgetControl! = new EmbeddedWidgetControl(SAWidget!,cwin!,0,0,widgetWidth,widgetHeight,$$)

	callpoint!.setDevObject("cwin",cwin!)
	callpoint!.setDevObject("barWidget",SAWidget!)

return

rem ========================================================
OnFilterSelectAnalysisType:rem --- handle filter selection
rem --- uses exit because BBj is getting/reacting to filter selection
rem ========================================================

	rem --- Start by getting the filter selection event, and from that event we can get
	rem --- the embedded widget, the BarChartWidget, the filter, and the selected filter key and value
	customEvent! = BBjAPI().getLastEvent()
	filterSelectEvent! = customEvent!.getObject()
	SAWidget! = filterSelectEvent!.getDashboardWidget()
	widget! = SAWidget!.getWidget()
	filterLeft! = SAWidget!.getDashboardWidgetFilterLeft()
	    
	REM Get the information from the filter so we can figure out what the user selected
	selectedFilterKey$ = filterLeft!.getKey()
	selectedFilterValue$ = filterLeft!.getValue()

	if (selectedFilterKey$ = "sales") then gosub set_widget_sales_data
	if (selectedFilterKey$ = "units") then gosub set_widget_units_data

	exit

rem ========================================================
set_widget_sales_data:rem --- Refresh the stacked bar chart widget with sales/cost info
rem ========================================================

	if num(BBjAPI().getObjectTable().get("hiAmount")) >= 10000
		rangeAxisTitle$="in 1000's"
		rangeDivisor=1000
	else
		rangeAxisTitle$=""
		rangeDivisor=1
	endif

	widget!.setChartRangeAxisFormat("")
	widget!.setChartRangeAxisToCurrency()
	widget!.setChartRangeAxisTitle(rangeAxisTitle$)
	widget!.clearDataSet()

	hshThisYear!=BBjAPI().getObjectTable().get("hshThisYear")
	hshLastYear!=BBjAPI().getObjectTable().get("hshLastYear")

	for x=1 to 13
	    widget!.setDataSetValue(str(x:"00"),"Sales",round(num(hshThisYear!.get("sales"+str(x:"00")))/rangeDivisor,2))
	    widget!.setDataSetValue(str(x:"00"),"Cost",round(num(hshThisYear!.get("cost"+str(x:"00")))/rangeDivisor,2))
	    widget!.setDataSetValue(str(x:"00"),"Prior Sales",round(num(hshLastYear!.get("sales"+str(x:"00")))/rangeDivisor,2))
	    widget!.setDataSetValue(str(x:"00"),"Prior Cost",round(num(hshLastYear!.get("cost"+str(x:"00")))/rangeDivisor,2))
	next x

	filterLeft!.selectFilter("sales")
	SAWidget!.refresh()

return

rem ========================================================
set_widget_units_data:rem --- Refresh the stacked bar chart widget with units info
rem ========================================================

	if num(BBjAPI().getObjectTable().get("hiCount")) >= 10000
		rangeAxisFormat$="#0K"
		rangeAxisTitle$="in 1000's"
		rangeDivisor=1000
	else
		rangeAxisFormat$="####0"
		rangeAxisTitle$=""
		rangeDivisor=1
	endif

	widget!.setChartRangeAxisFormat(rangeAxisFormat$)
	widget!.setChartRangeAxisTitle(rangeAxisTitle$)
	widget!.clearDataSet()

	hshThisYear!=BBjAPI().getObjectTable().get("hshThisYear")
	hshLastYear!=BBjAPI().getObjectTable().get("hshLastYear")

	for x=1 to 13
	    widget!.setDataSetValue(str(x:"00"),"Units",num(hshThisYear!.get("units"+str(x:"00")))/rangeDivisor)
	    widget!.setDataSetValue(str(x:"00"),"Prior Units",num(hshLastYear!.get("units"+str(x:"00")))/rangeDivisor)
	next x

	filterLeft!.selectFilter("units")
	SAWidget!.refresh()

return



