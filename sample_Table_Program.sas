
/***********************************************************************************************/
Sample table program –
/***********************************************************************************************/

libname r "P:\Medical\SRSProd\otr\xxx1234\core\forbsp";
run;

/* Copy EX dataset to work folder and assign single letter treatment codes */
data ex;
length treatc $1;
set r.ex(keep=studyid usubjid exseq exdostxt exstdtc exendtc epoch visitnum);
if EXDOSTXT="FINELY CRUSHED 10 MG OTR" then treatc="A";
if EXDOSTXT="COARSELY CRUSHED 10 MG OTR" then treatc="B";
if EXDOSTXT="FINELY CRUSHED 10 MG OC" then treatc="C";
drop exdostxt;
run;

/* Population counts by treatment assigned to macro variables */
proc sql noprint;
select count(distinct usubjid) into :trta from ex where treatc="A";
select count(distinct usubjid) into :trtb from ex where treatc="B";
select count(distinct usubjid) into :trtc from ex where treatc="C";
select count(distinct usubjid) into :overall from ex where treatc in ("A","B","C");
quit;

/* Re-assign Population count macro variables to remove blanks */
%let trta=&trta;
%let trtb=&trtb;
%let trtc=&trtc;
%let overall=&overall;

/* Transpose ex dataset to get start and end dates of exposure by treatment */
proc transpose data=ex out=trex(drop=_name_);
by usubjid;
id treatc ;
var exstdtc;
run;

/* Transpose ex dataset to get start and end dates of exposure by treatment */
proc transpose data=ex out=trex2(drop=_name_ rename=(a=paendt b=pbendt c=pcendt));
by usubjid;
id treatc ;
var exendtc;
run;

/* Add :00 to the ae start and end dates to make use of the is8601 function later on the variables */
data ae;
set r.ae;
aestdtc2=trim(trim(aestdtc)||trim(":00"));
aeendtc2=trim(trim(aeendtc)||trim(":00"));
drop aestdtc aeendtc;
rename aestdtc2=aestdtc aeendtc2=aeendtc;
run;

/* Merge ae and transposed ex datasets to get start and stop dates of exposure for all treatments for every subject ae record */
data aeexst;
merge ae trex trex2;
by usubjid;
run;

/* Create numeric dates using is8601 function and datetime20 format for later use */
data aeexst;
set aeexst;
array dates(8) aestdtc aeendtc a b c paendt pbendt pcendt;
array numdates(8) _aestdtc _aeendtc _a _b _c a_ b_ c_;
do i = 1 to 8;
if dates(i)^='' then
numdates(i) = input(dates(i),IS8601DT.);
end;
drop i;
format _aestdtc _aeendtc _a _b _c a_ b_ c_ datetime20.;
run;

/* Create numeric dates using is8601 function and datetime20 format for later use */
data dm;
set r.dm;
if rfstdtc ^='' then do;
rfstdt=input(rfstdtc,IS8601DT.);
rfendt=input(rfendtc,IS8601DT.);
end;
format rfstdt rfendt datetime20.;
run;

/* Merge dm data with rfstdt and rfendt variables with merged ae and ex dataset from above */
data aed;
merge aeexst dm(keep=usubjid rfstdt rfendt);
by usubjid;
run;

/* Delete non ae records from the merged dataset */
proc sql;
delete from aed
where usubjid not in (select usubjid from r.ae);
quit;

/* Assign treatment groups to each AE record depending on when AE occured - used ae start dates in calculation */
proc sql;
create table aed2 as select *,
case when _aestdtc<=rfstdt then "Z"
 when (_aestdtc between _a and _a+48*60*60)or(_aestdtc between _a and _a+48*60*60) then "A"
 when (_aestdtc between _b and _b+48*60*60)or(_aestdtc between _b and _b+48*60*60) then "B"
 when (_aestdtc between _c and _c+48*60*60)or(_aestdtc between _c and _c+48*60*60) then "C"
	 else "" end as treatc
from aed;
quit;


options mprint mlogic symbolgen;


/* Macro to prepare final report dataset by creating horizontal and vertical datasets and merging */
%macro aeprep;

%let trt1=%upcase(a);
%let trt2=%upcase(b);
%let trt3=%upcase(c);
%let trt4=%upcase(z);
%let trt5=overall;

%let str=%nrstr(put(count(*),3.0) ||compbl(" (N="||put(count(distinct usubjid),3.0)||")"));
/* Vertical dataset "overall" to get overall numbers - no grouping */
proc sql ;
	create table &trt5 as 
	(select "Any Adverse Event" as AE_GRP, %unquote(&str) as Overall, "1" as _order from aed2)
union all
	(select distinct(propcase(aesev)) as AE_GRP, %unquote(&str) as Overall, "2" as _order from aed2
	group by 1)
union all
	(select "Possible, Probably, or Definitely Related Adverse Event" as AE_GRP, 
	%unquote(&str) as Overall, "3" as _order from aed2
	where aerel in ("POSSIBLY","PROBABLY","DEFINITELY"))
union all
	(select "Adverse Event Leading to Study Discontinuation" as AE_GRP, 
	%unquote(&str) as Overall, "4" as _order from aed2
	where aeacnoth in ("WITHDRAWN FROM STUDY","TREATMENT GIVEN AND WITHDRAWN FROM STUDY"))
union all
	(select "Serious Adverse Event" as AE_GRP, %unquote(&str) as Overall, "5" as _order from aed2
	where aeser="Y");
quit;

/* Vertical datasets "Pre-Study Drug", "A", "B", "C" - grouping by treatment and pre-study */
%do i=1 %to 4;
proc sql ;
	create table &&trt&i as 
	(select "Any Adverse Event" as AE_GRP, %unquote(&str) as &&trt&i, "1" as _order from aed2
	where treatc="&&trt&i")
union all
	(select distinct(propcase(aesev)) as AE_GRP, %unquote(&str) as &&trt&i, "2" as _order from aed2
	where treatc="&&trt&i"
	group by 1)
union all
	(select "Possible, Probably, or Definitely Related Adverse Event" as AE_GRP, 
	%unquote(&str) as &&trt&i, "3" as _order from aed2
	where treatc="&&trt&i"
	and aerel in ("POSSIBLY","PROBABLY","DEFINITELY"))
union all
	(select "Adverse Event Leading to Study Discontinuation" as AE_GRP, 
	%unquote(&str) as &&trt&i, "4" as _order from aed2
	where treatc="&&trt&i"
	and aeacnoth in ("WITHDRAWN FROM STUDY","TREATMENT GIVEN AND WITHDRAWN FROM STUDY"))
union all
	(select "Serious Adverse Event" as AE_GRP, %unquote(&str) as &&trt&i, "5" as _order from aed2
	where treatc="&&trt&i"
	and aeser="Y");
quit;
%end;

/* Create row for dataset Z where proc sql did not create a row for SEVERE ae category */
data z;
set z;
if _n_=3 then do;
output;
ae_grp="SEVERE";
_order="2";
z="---";
end;
output;
run;

/* include ae group labels and order variable values */
%do i=1 %to 5;
data &&trt&i;
set &&trt&i;
if _n_=6 and ae_grp='' then do;
ae_grp="Adverse Event Leading to Study Discontinuation";
_order="4";
end;
if _n_=7 and ae_grp='' then do;
ae_grp="Serious Adverse Event";
_order="5";
end;
if _order="2" then do;
ae_grp=" "||ae_grp;
end;
run;
proc sort data = &&trt&i;
by _order;
run;
%end;

/* Create final report dataset by merging all vertical datasets created above */
data final;
merge z a b c overall;
by _order;
run;

proc datasets library=work;
save final;
run; quit;

%mend aeprep;

%aeprep; /* Macro execution step to create vertical datasets */

/* Create blank rows after each ae group category */
data final;
set final;
output;
by _order;
if _order^=1 and last._order;
array allchar [*] _character_ ;
drop i;
do i=1 to dim(allchar); allchar{i}=' '; end;
output;  /* Output blank observation */
run;

/* Format values per SAP specifications */
proc format;
	value $col 30.  ' 0(N=0)'='    ---    '
        		'  0 (N= 0)'='    ---    '
;
run;


/*Create macro variable for sysdate system macro variable in format specified in shells */
data _null_;
today = put(date(),date9.);
call symput('dtnull',today);
run;
%let dtnull2=%substr(&dtnull,1,2)-%substr(&dtnull,3,3)-%substr(&dtnull,6,4);

/* Report procedure to export rtf file */
dm "odsresults; clear;";
options nonumber nodate orientation=landscape;
ods listing close;
ods rtf file="\\nacl03\users_ab\valabojr\Documents\xxx1234\reports\14-3-1-1a_new.rtf" bodytitle style=Styles.custom;
proc report
   	data = final
	nowd
	ls=122
	ps=30
	headline 
	headskip
	split='*'
	style(report)={font_face=arial font_size=2.5 bordercolor=black}
	style(column)={just=center font_face=arial font_size=2.5 bordercolor=black}
	style(header)={font_face=arial font_size=2.5 foreground=black bordercolor=black}
	;

	columns (ae_grp('Incidences (Number of Distinct Subjects)*                    _________________________________
_______________________________________________'
			    z a b c overall _order));

 	define ae_grp  /display " " style={protectspecialchars=off cellwidth=30% just=l asis=on} flow;
   	define z /display center "Pre-Study*Drug" format=$col. style={protectspecialchars=off cellwidth=13% just=c};
   	define a /display center "A*(N=&trta)" format=$col. style={protectspecialchars=off cellwidth=13% just=c};
   	define b /display center "B*(N=&trtb)" format=$col. style={protectspecialchars=off cellwidth=13% just=c};
	define c /display center "C*(N=&trtc)" format=$col. style={protectspecialchars=off cellwidth=13% just=c};
	define overall /display center "Overall*(N=&overall)" format=$col. style={protectspecialchars=off cellwidth=17% just=c};
	define _order /order=internal noprint;

	compute before;
	line @1 ' ';
	endcomp;

	title1 j=l "xxx1234			                        		        			Table 14.3.1-1a								      DATE:&dtnull2 TIME:&systime";
   	title2 j=c "Summary of All Adverse Events";
   	title3 j=c "(Page 1 of 1)";
   	*title3 j=c "Page ^{thispage} of ^{lastpage}";
   	title4;
	title5 j=l "Population: Enrolled                                               ";
	footnote j=l "NOTE:	Treatment A = Finely crushed 10 mg OTR; Treatment B = Coarsely crushed 10 mg OTR; Treatment C = Finely crushed 10 mg OC.";
	footnote2 j=l "Source: Listing 16.2.7-1a";
 run;quit;
 ods listing;
 ods rtf close;
