[[ADM_PROCBATCHMNT.ADIS]]
rem ---  don't allow delete if this batch is referenced in entry files

adm_proctables_dev=fnget_dev("ADM_PROCTABLES")
dim adm_proctables$:fnget_tpl$("ADM_PROCTABLES")
ddmKeySegs_dev=fnget_dev("DDM_KEY_SEGS")
dim ddmKeySegs$:fnget_tpl$("DDM_KEY_SEGS")

callpoint!.setDevObject("can_delete","")
batch_no$=callpoint!.getColumnData("ADM_PROCBATCHMNT.BATCH_NO")
process_id$=callpoint!.getColumnData("ADM_PROCBATCHMNT.PROCESS_ID")

read (adm_proctables_dev,key=firm_id$+process_id$,dom=*next)
while 1
	read record (adm_proctables_dev,end=*break)adm_proctables$
	if pos(firm_id$+process_id$=adm_proctables$)<>1 then break

	rem --- Find batch key for this table
	dd_key_number$=""
	dd_segment_seq$="02"
	dd_table_alias$=adm_proctables.dd_table_alias$
	read(ddmKeySegs_dev,key=dd_table_alias$,dom=*next)
	while 1
		readrecord(ddmKeySegs_dev,end=*break)ddmKeySegs$
		if ddmKeySegs.dd_table_alias$<>dd_table_alias$ then continue
		if ddmKeySegs.dd_segment_seq$<>dd_segment_seq$ then continue
		if ddmKeySegs.dd_segment_col$<>"BATCH_NO" then continue
		dd_key_number$=ddmKeySegs.dd_key_number$
		break
	wend
	if dd_key_number$="" then continue

	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]=dd_table_alias$,open_opts$[1]="OTA"
	gosub open_tables
	file_dev=num(open_chans$[1])
	file_tpl$=open_tpls$[1]

	if file_dev
		rem --- If a table with a trans_status column, like opt_invhdr, is added to a adm_proctables process, then
		rem --- need to use a knum for a firm_id+batch_no+trans_status key, like opt_invhdr's AO_BATCH_STAT key,
		rem --- and set tripKey$irm_id$+batch_no$+"E". (Check file_tpl$ for trans_status column.)
		tripKey$=firm_id$+batch_no$
		read (file_dev,key=tripKey$,knum=num(dd_key_number$),dom=*next,err=*endif)
		k$=key(file_dev,end=*endif)
		if pos(tripKey$=k$)=1 then 	
			if pos("trans_status:c(1)"=open_tpls$[1]) then
				rem --- Check if real-time processing type file with trans_status<>U
				if pos(tripKey$+"E"=k$)=1 or pos(tripKey$+"R"=k$)=1  then
					callpoint!.setDevObject("can_delete","NO")
				endif
			else
				callpoint!.setDevObject("can_delete","NO")
			endif
		endif		
	endif
	num_files=1
	dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
	open_tables$[1]=dd_table_alias$,open_opts$[1]="C"
	gosub open_tables

	if callpoint!.getDevObject("can_delete")="NO" then break
wend

if callpoint!.getDevObject("can_delete")="NO"
	callpoint!.setColumnData("<<DISPLAY>>.DSP_DATA","Y")
else
	callpoint!.setColumnData("<<DISPLAY>>.DSP_DATA","N")
endif

callpoint!.setOptionEnabled("ORPH",1)
callpoint!.setStatus("REFRESH")

[[ADM_PROCBATCHMNT.AOPT-ORPH]]
rem --- read thru entry files for this process and see if there are any batches not in the batch file

process_id$=callpoint!.getColumnData("ADM_PROCBATCHMNT.PROCESS_ID")
if process_id$<>""
	adm_proctables_dev=fnget_dev("ADM_PROCTABLES")
	dim adm_proctables$:fnget_tpl$("ADM_PROCTABLES")
	adm_procbatches_dev=fnget_dev("ADM_PROCBATCHMNT")
	dim adm_procbatches$:fnget_tpl$("ADM_PROCBATCHMNT")
	ddmKeySegs_dev=fnget_dev("DDM_KEY_SEGS")
	dim ddmKeySegs$:fnget_tpl$("DDM_KEY_SEGS")

	batch_no$=callpoint!.getColumnData("ADM_PROCBATCHMNT.BATCH_NO")
	msg_id$=""

	read (adm_proctables_dev,key=firm_id$+process_id$,dom=*next)
	while 1
		read record (adm_proctables_dev,end=*break)adm_proctables$
		if pos(firm_id$+process_id$=adm_proctables$)<>1 then break

		rem --- Find batch key for this table
		dd_key_number$=""
		dd_segment_seq$="02"
		dd_table_alias$=adm_proctables.dd_table_alias$
		read(ddmKeySegs_dev,key=dd_table_alias$,dom=*next)
		while 1
			readrecord(ddmKeySegs_dev,end=*break)ddmKeySegs$
			if ddmKeySegs.dd_table_alias$<>dd_table_alias$ then continue
			if ddmKeySegs.dd_segment_seq$<>dd_segment_seq$ then continue
			if ddmKeySegs.dd_segment_col$<>"BATCH_NO" then continue
			dd_key_number$=ddmKeySegs.dd_key_number$
			break
		wend
		if dd_key_number$="" then continue

		rem --- For tables with a trans_status column, skip records where trans_status$<>"E".
		sqlprep$="SELECT COUNT(*) FROM DDM_TABLE_COLS WHERE DD_TABLE_ALIAS='"+dd_table_alias$+"' AND DD_DATA_NAME='TRANS_STATUS'"
		sql_chan=sqlunt
		sqlopen(sql_chan,err=*next)stbl("+DBNAME")
		sqlprep(sql_chan)sqlprep$
		dim read_tpl$:sqltmpl(sql_chan)
		sqlexec(sql_chan)

		read_tpl$=sqlfetch(sql_chan,err=*break)
		if num(read_tpl$)=0 then
			where_transStatus$=""
		else
			where_transStatus$=" AND TRANS_STATUS='E'"
		endif

		sqlprep$="SELECT DISTINCT BATCH_NO FROM "+dd_table_alias$+" WHERE FIRM_ID='"+firm_id$+"'"+where_transStatus$
		sql_chan=sqlunt
		sqlopen(sql_chan,err=*next)stbl("+DBNAME")
		sqlprep(sql_chan)sqlprep$
		dim read_tpl$:sqltmpl(sql_chan)
		sqlexec(sql_chan)

		orph_batches! = BBjAPI().makeVector()
		orph_grid_batches!=BBjAPI().makeVector()
		while 1
			read_tpl$=sqlfetch(sql_chan,err=*break) 
			batch_no$=read_tpl.batch_no$

		rem --- Is this an orphan batch?
			found=0
			read(adm_procbatches_dev,key=firm_id$+process_id$+batch_no$,dom=*next); found=1
			if !found then orph_batches!.addItem(batch_no$)
		wend

		if orph_batches!.size() then
			msg_id$="AD_BATCH_ORPH"
			dim msg_tokens$[2]
			batches$=""
			msg_tokens$[1]=cvs(adm_proctables.dd_table_alias$,3)
			for y=0 to orph_batches!.size()-1
				batches$=batches$+orph_batches!.getItem(y)+$0A$
			next y
			msg_tokens$[2]=batches$
			gosub disp_message
		endif				
	wend

	if msg_id$=""
		msg_id$="AD_BATCH_NO_ORPH"
		gosub disp_message
	endif
endif

[[ADM_PROCBATCHMNT.AREC]]
callpoint!.setOptionEnabled("ORPH",0)

[[ADM_PROCBATCHMNT.BDEQ]]
rem --- don't allow delete if batch contains data

if callpoint!.getDevObject("can_delete")="NO"
	msg_id$="AD_BATCH_DTL"
	gosub disp_message
	callpoint!.setStatus("ABORT")
endif

[[ADM_PROCBATCHMNT.BSHO]]
rem --- open files

num_files=2
dim open_tables$[1:num_files],open_opts$[1:num_files],open_chans$[1:num_files],open_tpls$[1:num_files]
open_tables$[1]="ADM_PROCTABLES",open_opts$[1]="OTA"
open_tables$[2]="DDM_KEY_SEGS",open_opts$[2]="OTA"

gosub open_tables

callpoint!.setOptionEnabled("ORPH",0)

[[ADM_PROCBATCHMNT.PROCESS_ID.AVAL]]
rem --- enable orph scan button

callpoint!.setOptionEnabled("ORPH",1)



