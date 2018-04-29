/*
	this file contains the code, including local macros, to create simulated datasets with 10,000 cases under four scenarios:
			1 - single product and single event
			2 - single product and multiple events
			3 - multiple products and single event
			4 - multiple products and multiple events

	these are the datasets that get created in library sim:
		EX1.sas7bdat - independent pairs of product/event
				each row is product/event pair where rows are considered independent
		EX2_LONG.sas7bdat - cases with a single product and multiple events
				each row is a product/event pair and multiple rows for multiple events are grouped by a case
		EX2_WIDE.sas7bdat - cases with a single product and multiple events
				each row is a case with product and a column containing a delimited list of associated events
		EX3_LONG.sas7bdat - cases with multiple products and a single event
		 		each row is a product/event pair and multiple rows for multiple products are grouped by a case
		EX3_WIDE.sas7bdat - cases with multiple products and a single event
		 		each row is a case with event and a column containing a delimited list of associated products
		EX4_LONG.sas7bdat - cases with multiple products and multiple events
				each row is a product/event pair and multiple rows for multiple products and events are grouped by a case
		EX4_WIDE.sas7bdat - cases with multiple products and multiple events
				each row is a case with columns containing a delimited list of products and a delimited list of events

	This is an input file with known distributions for a set of drugs and events
		drug_event_example.sas7bdat

	The simulated cases do the following:


*/

/* include the macros for building simulated cases (%basecase) and adding drugs (%add_drugs) and events (%add_events) */
		%include './Macros/basecase.sas';
		%include './Macros/add_events.sas';
		%include './Macros/add_drugs.sas';

/* specify output location for the ouput files (sim_out) and the expected input file drug_event_example.sas7bdat (sim_in) */
		libname sim_in 'C:\PROJECTS\SAS-Mini-Projects\Disproportionality Measures\simulating cases';
		libname sim_out 'C:\PROJECTS\SAS-Mini-Projects\Disproportionality Measures\simulating cases\examples';

/* specify parameters for data creation */
		%let NCases=10000; /* how many cases to genereate */


/* create information tables: drug_event, drugs, events */
		Proc sql;
		/* add percentage to events within drugs - the DE_percent will represent the % of reports for that Drug that are the specific event */
			create table drug_event as
				select a.DrugName, a.EventName, a.Nij as DE_COUNT, b.D_COUNT, a.Nij/b.D_COUNT as DE_PERCENT, a.Nij/c.E_Count as ED_PERCENT, C.E_COUNT, a.TOTAL
				from
					(select DrugName, EventName, Nij, sum(Nij) as TOTAL from sim_in.drug_event_example) a
					left outer join
					(select DrugName, sum(Nij) as D_COUNT from sim_in.drug_event_example group by DrugName) b
					on a.DrugName=b.DrugName
					left outer join
					(select EventName, sum(Nij) as E_COUNT from sim_in.drug_event_example group by EventName) c
					on a.EventName=c.EventName
				order by a.DrugName, a.EventName
			;
		/* Drugs table with column D_PERCENT = proportion of reports that are for the specific drug */
			create table drugs as
				select distinct DrugName, D_COUNT, TOTAL, D_COUNT/TOTAL as D_PERCENT
				from drug_event
			;
		/* Evemts table with column E_PERCENT = proportion of reports that are for the specific event */
			create table events as
				select distinct EventName, E_COUNT, TOTAL, E_COUNT/TOTAL as E_PERCENT
				from drug_event
			;
		quit;

options nosource nonotes;
%basecase(core,&NCases.,1,SEED=54321);
	%add_events(core,EX1,1);
	%add_events(core,EX2_LONG,-1);
	%add_drugs(EX1,EX3_LONG,-1);
	%add_drugs(EX2_LONG,EX4_LONG,-1);
options source notes;




/* create a table with 1 row per case
	the following has also been turned into a macro: /Macros/%cases_to_caserows
*/
data EX2;
	length Events $500.;
		do until(last.Case_N);
			set EX2_LONG;
			by Case_N;
			Events=catx(' ',Events,EventName);
		end;
	drop EventName;
run;
data EX3;
	length Drugs $500.;
		do until(last.Case_N);
			set EX3_LONG;
			by Case_N;
			Drugs=catx(' ',Drugs,DrugName);
		end;
	drop DrugName;
run;
data EX4;
	length Drugs $500. Events $500.;
		do until(last.Case_N);
			set EX4_LONG;
			by Case_N;
			Drugs=catx(' ',Drugs,DrugName);
			Events=catx(' ',Events,EventName);
		end;
	drop DrugName EventName;
run;

options compress=yes;

/* move Sample_Cases to permanent library and clean up work */
proc sql noprint;
	create table sim_out.EX1 as
		select * from EX1
	;
	create table sim_out.EX2_LONG as
		select * from EX2_LONG
	;
	create table sim_out.EX3_LONG as
		select * from EX3_LONG
	;
	create table sim_out.EX2 as select Case_N, DrugName, Events from EX2;
	create table sim_out.EX3 as select Case_N, Drugs, EventName from EX3;
	create table sim_out.EX4 as select Case_N, Drugs, Events from EX4;
	drop table core;
	drop table drugs;
	drop table drug_event;
	drop table events;
	drop table EX1, EX2, EX3, EX2_LONG, EX3_LONG, EX4, EX4_LONG;
quit;
