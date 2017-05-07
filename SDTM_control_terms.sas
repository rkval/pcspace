/*==================================================================================*/

/* TEST #2-1
1. source=CDISC
2. crtfile
3. codevalue 
4. ctlist	single control term - use lower or uppercase
5. ctexclude	single control term - use lower or uppercase
*/

%chk_control_terms(
source=CDISC,
ctfile=SDTM_controlled_terms_20xx, 
codevalue=CDISC_Submission_Value,
ctlist=lbtest,                       /* Macro parameters without single quotes */
ctexclude=vstestcd);		    /* Macro parameters without single quotes */

/*==================================================================================*/

%macro chkcts;
option compress=yes;

PROC IMPORT OUT=sdtmtrms 
			DATAFILE="P:\Medical\SRSProd\utilities\standards\SDTM_controlled_terms_20xx.xls" 
			DBMS=EXCEL2000 REPLACE;
			SHEET="CDISC_controlled_terminology";
			GETNAMES=YES;
RUN;
options symbolgen;
proc sql noprint;
  select distinct memname into :mem1-:mem999 from sashelp.vcolumn
  where libname='SDTM';
%LET TOTMEM=&SQLOBS;				/* total # of datasets in SDTM folder */

%DO J=1 %TO &TOTMEM;				/* outer loop - Process datasets */

  select name into :var1-:var999 from sashelp.vcolumn
  where libname='SDTM'
  and memname="&&MEM&J"
  and name in (select distinct varname from sdtmtrms);
%LET TOTVAR=&SQLOBS;

%DO i=1 %TO &totvar;				/* inner loop - Process variables */
									/* create datasets for each variable with controlled term values */
 create table &&mem&j&&var&i (COMPRESS=YES) as 
 	select "&&var&i" as varname length=15, 
 	&&var&i as value label="value" length=200,
  	case 							/* assign flag value for each variable */ 
  	when "&&var&i" in 
	(select CDISC_Submission_Value from sdtmtrms 
	where varname in ('DOMAIN','RDOMAIN') 
	and Codelist_Extensible='Yes') then 'Exact' 
  	when &&var&i in 
	(select CDISC_Submission_Value from sdtmtrms 
	where varname="&&var&i") then 'Exact'
  	when upcase(&&var&i) in 
	(select upcase(CDISC_Submission_Value) from sdtmtrms 
	where varname="&&var&i") then 'Case' 
  	when "&&var&i" in 
	(select varname from sdtmtrms 
	where varname="&&var&i" and Codelist_Extensible='Yes') then 'Extensible'
  	when &&var&i not in
  	(select CDISC_Submission_Value from sdtmtrms 
	where varname="&&var&i" and Codelist_Extensible='No') then 'None'
 	else '' end as checkct length=10, count(*) as frequency
  from SDTM.&&MEM&J;

%END;								/* end of inner loop */
%END;								/* end of outer loop */

  create table allcts 				/* create table to append all datasets */
	(varname char(8) format $8.,
	 value char(200) format $200.,
	 checkct char(10),
	 frequency num(8)
	);

  select distinct memname into :mem1-:mem999 from sashelp.vcolumn
  where libname='WORK'
  and memname not in ('ALLCTS','SDTMTRMS','CT_EXTENSIBLE','CT_NOMATCH');

%LET TOTWRK=&SQLOBS;				

%DO K=1 %TO &TOTWRK;	

  alter table &&mem&k
  modify value char(200) format $200.;
									/* append all datasets */
  insert into allcts (varname, value, checkct, frequency)
  select varname, value, checkct, frequency from &&mem&k;
 drop table &&mem&k;

%END;
									/* create summary report of all variables and controlled terms */
  create table summary_report_&study as select distinct varname, value, checkct, count(*) as frequency from allcts
  group by 1,2,3
  order by 1,2,3,4;

  drop table allcts;
									/* additional reports */ 
  create table ct_extensible_&study as select * from summary_report_&study
  where checkct='Extensible'
  order by 1;

  create table ct_nomatch_&study as select * from summary_report_&study
  where checkct='None'
  order by 1;
quit;

%mend chkcts;

%chkcts;							/* macro execution */