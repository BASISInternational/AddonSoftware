[[GLM_FINASSIGN.GL_ACCOUNT.AVAL]]
rem "GL INACTIVE FEATURE"
   glm01_dev=fnget_dev("GLM_ACCT")
   glm01_tpl$=fnget_tpl$("GLM_ACCT")
   dim glm01a$:glm01_tpl$
   glacctinput$=callpoint!.getUserInput()
   glm01a_key$=firm_id$+glacctinput$
   find record (glm01_dev,key=glm01a_key$,err=*break) glm01a$
   if glm01a.acct_inactive$="Y" then
      call stbl("+DIR_PGM")+"adc_getmask.aon","GL_ACCOUNT","","","",m0$,0,gl_size
      msg_id$="GL_ACCT_INACTIVE"
      dim msg_tokens$[2]
      msg_tokens$[1]=fnmask$(glm01a.gl_account$(1,gl_size),m0$)
      msg_tokens$[2]=cvs(glm01a.gl_acct_desc$,2)
      gosub disp_message
      callpoint!.setStatus("ACTIVATE")
   endif
[[GLM_FINASSIGN.AOPT-ASGN]]
rem --- Launch the Assign Account Range utility in Standard mode

user_id$=stbl("+USER_ID")
dim dflt_data$[4,1]
dflt_data$[1,0]="ASSIGN_MODE"
dflt_data$[1,1]="S"
dflt_data$[2,0]="GL_RPT_NO"
dflt_data$[2,1]=callpoint!.getColumnData("GLM_FINASSIGN.GL_RPT_NO")
dflt_data$[3,0]="GL_RPT_LINE"
dflt_data$[3,1]=callpoint!.getColumnData("GLM_FINASSIGN.GL_RPT_LINE")
dflt_data$[4,0]="ASSIGN_NO"
dflt_data$[4,1]=callpoint!.getColumnData("GLM_FINASSIGN.ASSIGN_NO")
call stbl("+DIR_SYP")+"bam_run_prog.bbj",
:                       "GLX_ASSIGNACCT",
:                       user_id$,
:                       "",
:                       "",
:                       table_chans$[all],
:                       "",
:                       dflt_data$[all]

[[GLM_FINASSIGN.<CUSTOM>]]
#include [+ADDON_LIB]std_functions.aon

