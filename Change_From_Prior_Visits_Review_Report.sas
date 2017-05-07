
/*=============================================================================================*/
/*
Programmer:		R. VALABOJU
Date:			05-03-20xx 
Purpose:	Generic program to Create view of Datasets with xxTESTCD, xxSTRESN, variables. Shows difference from prior visit values as well as change from baseline values.
Requirements:
*/
/*
Purpose: Checks the test results against range and difference values input and displays subject results meeting the input criteria
For subjects identified as having at least one outlier, displays all results and indicates outliers where applicable.
An outlier includes a baseline to endpoint check which is always displayed

sample macro call

%dvalldiff1(dsname=VS, vstestcd=DIABP, diffamt=20, highflag=140, lowflag=100, unit=mmHG)
displays all DIABP results for subjects that have at least one occurrence of
flags any difference >= 20 from the previous collection
flags low under 100
flags upper over 140
displays the baseline to endpoint result if a baseline record is flagged 'Y' in --BLFL 
displays the baseline record flag
*/
/*=============================================================================================*/


%macro v_dvalldiff1(dsname=, testcd=, diffamt=, highflag=, lowflag=, unit=);

data &dsname;
set sdtm.&dsname (keep=usubjid &dsname.seq &dsname.testcd &dsname.stresn &dsname.stresu &dsname.blfl &dsname.dtc);
count+1;
by usubjid;
where upcase(&dsname.testcd)=upcase("&testcd");
where also upcase(&dsname.stresu)=upcase("&unit");
if first.usubjid then count=1;
run;

proc sql;
create table bl as select usubjid, &dsname.stresn, &dsname.blfl from &dsname
where &dsname.blfl="Y";

create table &dsname.bl as select a.*, b.&dsname.stresn as blstresn from &dsname as a left join bl as b
on a.usubjid=b.usubjid
order by a.usubjid;
quit;

proc sort data=&dsname.bl;
by usubjid &dsname.seq count;
run;

data &dsname;
set &dsname.bl;
by usubjid;
if &dsname.blfl^="Y" and &dsname.stresn=. then delete;
run;
proc sort data=&dsname;
by usubjid &dsname.seq count;
run;

data &dsname;
set &dsname;
by usubjid;
if &dsname.stresn<input("&lowflag",8.) then result_hilow=&dsname.stresn-input("&lowflag",8.);
if &dsname.stresn>input("&highflag",8.) then result_hilow=&dsname.stresn-input("&highflag",8.);
if not first.usubjid and abs(dif(&dsname.stresn))>=input("&diffamt",8.) then difflag=1; 
result_change=dif(&dsname.stresn);
run;
proc sort data=&dsname;
by usubjid &dsname.seq count;
run;

data &dsname.out;
set &dsname;
by usubjid;
if difflag=. then result_change=.;
if last.usubjid and &dsname.stresn^=. then bl_to_endpt=&dsname.stresn-blstresn;
drop difflag blstresn;
run;

proc sql;
create table &dsname.tmp as select distinct usubjid, result_change, result_hilow, bl_to_endpt from &dsname.out
where (result_change^=. or result_hilow^=. or bl_to_endpt^=.);

delete from &dsname.tmp
where (result_change=. and result_hilow=.)
and abs(bl_to_endpt)<abs(input("&diffamt",8.));

delete from &dsname.out 
where usubjid not in (select usubjid from &dsname.tmp);
quit;
%mend v_dvalldiff1;
