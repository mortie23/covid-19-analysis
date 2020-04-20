*	Get the current working directory (note this is for windows);
filename pwd pipe "echo %cd%";
data _null_;
	infile pwd;
	input;
	put _infile_;
	pwd=tranwrd(_infile_,'0d'x,'');
	call symputx('pwd',pwd);
run;
%put pwd: &pwd.;
libname covid "&pwd.";

*	Get the raw CSV file to a local file;
*	Variable for raw github path;
%let tsdata=https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv;
*	Local file handles;
filename tsdata "&pwd.\tsdata.csv" lrecl=100000000;
filename tsdata_h "&pwd.\tsdata-header.csv";
*	Use HTTP get to pull to local;
proc http
	url="&tsdata."
	method="GET"
	out=tsdata
	headerout=tsdata_h;
run;
*	Generate the columns for the timeseries;
data colnames;
	*	Read the first line;
	infile tsdata lrecl=100000000 obs=1 truncover;
	length varnm $100.;
	input colnames $10000.;
	*	Total number of commas (i.e. columns-1) in the string;
	numvars=length(colnames)-length(transtrn(colnames,',',trimn('')));
	*	Total number of months;
	call symput('nummths',numvars-5);
	*	Create macro variables for all months;
	do i=1 to numvars+1;
		varnm=scan(colnames,i,',');
		*	Write to log for test;
		put varnm;
		*	Month variables after the first 5 variables and put in macros;
		if i>5 then
			call symputx('mnth'||strip(i-5),'mnth_'||tranwrd(strip(varnm),'/','_'));
	end;
run;
*	Test macros to log;
%put {"nummths": "&nummths.", "mnth1": "&mnth1.", "mnth2": "&mnth2." };

options mprint symbolgen;
*	Macro function to use macro loops;
%macro read_data;
%macro dummy(); %mend dummy;
	*	Read in the data to a dataset;
	data timeseries_raw;
		length country $50. prov_state $50. lat 8.6 lon 8.6;
		infile tsdata dsd dlm='2C'x firstobs=2;
		input prov_state $ country $ lat  lon 
		%do i=1 %to &nummths.;
			&&mnth&i.. 
		%end;
		;
	run;
	*	Sort data for transpose;
	proc sort data=timeseries_raw;
		by country prov_state;
	run;
	*	Transpose the data into rows not columns;
	proc transpose data=timeseries_raw out=timeseries_trans;
		by country prov_state lat lon;
		var 
		%do i=1 %to &nummths.;
			&&mnth&i.. 
		%end;
		;
	run;

%mend;
%read_data

*	Process the time column;
data covid.timeseries;
	set timeseries_trans (where=(not missing(country)));
	format date date9. cases 8.;
	cases=col1;
	date=input(scan(_NAME_,3,'_')||'-'||scan(_NAME_,2,'_')||'-20'||scan(_NAME_,4,'_'),ddmmyy10.);
	drop _NAME_ col1;
run;
*	output processed to CSV for record keeping;
proc export data=covid.timeseries
	outfile="&pwd.\tsdata-proc.csv"
	dbms=csv replace;
run;


