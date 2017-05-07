/*==================================================================================*/
/*
Programmer:		R. VALABOJU
Date:			03-31-20xx 
Purpose: 		Check duplicates across SDTM database according to established sort keys
Requirements:	Standards excel spreadsheet
*/
/*==================================================================================*/
**Specify study name;
%let study=xxx1234;

options nodate ps=45 ls=132 nocenter missing='.' nofmterr mautosource noserror nolabel
		NOSYMBOLGEN MPRINT MLOGIC FORMCHAR = '|----|+|---+=|-/<>*'
        sasautos=('P:\Medical\SRSProd\maclib\test',
					'P:\Medical\SRSProd\maclib\prod',
					'P:\Medical\dbadmin\macros', 
	               'P:\Medical\dbadmin\tools',
                  );
	%let   common=P:\Medical\SRSProd\utilities\standards\;
	%let      raw=P:\Medical\SRSProd\test\standards\output\;
    %let    macro=P:\Medical\SRSProd\mac_bsp\test\MACROS;
	%let     sdtm=P:\Medical\SRSProd\test\standards\testdata;
	%let sdtmwork=P:\Medical\SRSProd\poa\poa1001\core\forbsp\sdtmwork;
    
	libname sdtmwork 'P:\Medical\SRSProd\poa\poa1001\core\forbsp\sdtmwork\';
	libname sdtm 'P:\Medical\SRSProd\test\standards\testdata';
	run;
/* POA Studies*/
	libname poa1001 'P:\Medical\SRSProd\poa\poa1001\core\forbsp';
	libname poa1004 'P:\Medical\SRSProd\poa\poa1004\core\forbsp';
    run;

/*Create test data*/
	
%macro didups_v1;
option compress=yes symbolgen;

PROC IMPORT OUT=dmnsvars
			DATAFILE="P:\Medical\SRSProd\utilities\standards\SDTM_312_domains_and_varnames.xls" 
			DBMS=EXCEL2000 REPLACE;
			SHEET="domains";
			GETNAMES=YES;
RUN;

DATA dmnsvars;
set dmnsvars;
  DO I = 1 TO 99 until (length=0);
     CALL SCANQ(dup_reckey,I,POSITION,LENGTH);
  END;
  NUM_WORDS = I-1;
  DROP POSITION LENGTH I;
run;

proc sql;
create table duprecs
		( domain char(10),
		  sortkeys char(200),
		  count num(8)
		 );
quit;

proc sql noprint;
select distinct upcase(domain) into :dmn1-:dmn99 from dmnsvars
where domain in 
(select distinct memname from sashelp.vcolumn where libname='SDTM');
quit;
%let tot=&sqlobs;

%do i=1 %to &tot;
proc sql noprint;
select dup_reckey into :key from dmnsvars
where domain="&&dmn&i";

select num_words into :nkeys from dmnsvars
where domain="&&dmn&i";
quit;

%let nkeys=&nkeys;

data all&&dmn&i;
length key $200;
length domain $10;
length keynum 3;
key=' ';
domain=' ';
keynum=.;
run;

%do j=1 %to &nkeys;

%let k&j=%qscan(&key,&j,' ');

data &&k&j;
length key $200;
length domain $10;
length keynum 3;
  dsid=open("sdtm.&&dmn&i");
  check=varnum(dsid,"&&k&j");
  if check=0 then key=" ";
  if check^=0 then key="&&k&j";
  domain="&&dmn&i";
  keynum="&j";
  drop dsid check;
run;

proc append base=all&&dmn&i data=&&k&j;
run;

proc sort data=all&&dmn&i;
by keynum;
run;

proc sql noprint;
drop table &&k&j;
quit;

%end;

%let keys=;

proc sql noprint;
select distinct key into :keys separated by ' ' from all&&dmn&i
where key^='';
quit;
%put &keys;

proc sql noprint;
select distinct key into :keys2 separated by ',' from all&&dmn&i
where key^='';
quit;
%put &keys2;

%if %length(&keys)>0 %then %do;
proc sort data=SDTM.&&dmn&i out=nodup&&dmn&i nodupkey;
by &keys;
run;

proc sql noprint;
create table dup&&dmn&i as 
select distinct &keys2, count(*) as count from SDTM.&&dmn&i
group by &keys2
having count(*)>1
order by &keys2;
quit;

*drop table nodup&&dmn&i;
quit;
%end;

%if %length(&keys)>0 %then %do;
proc sql noprint;
insert into duprecs (domain, sortkeys, count)
select distinct "&&dmn&i" as domain, "&keys" as sortkeys, 
count(count) as count from dup&&dmn&i;

*drop table dup&&dmn&i, all&&dmn&i;
quit;
%end;

%end;
/*
proc datasets library=work nolist;
save duprecs;
run;quit;
*/
%mend didups_v1;

%didups_v1;
