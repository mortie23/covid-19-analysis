*	Use the timeseries data to analyse;
proc summary missing data=timeseries;
	class country date;
	var cases;
	output out=timeseries_country_tmp (where=(_type_ in (1 3))) sum=;
run;
data timeseries_country;
	set timeseries_country_tmp;
	country=ifc(missing(country),'Global',country);
run;
*	Plot of some key countries;
title "COVID-19 Cases by Country";
proc sgplot data=timeseries_country (where=(country in ('Global','US','Italy','Spain','Australia')));
	where cases >= 1;
	series x=date y=cases / group=country;
	xaxis label='Date' grid ;
	yaxis label='Cases' grid type=log logstyle=logexpand logbase=10;
	keylegend;
run;
*	Fit an exponential model to the global trend;
%let datefrom=20mar2020;
data nlin_pre;
	set timeseries_country;
	where country='Global' and date > "&datefrom."d;
	x=date-"&datefrom."d;
	y=cases;
	keep x y;
run;
/*ods trace on;*/
/*ods listing close;*/
ods output ParameterEstimates=nlin_est;
proc nlin data=nlin_pre list noitprint;
   parms a 100000 b 0.1 c 100000 d 0.1; 
   model y = a*exp(b*x) - c*exp(d/x);
   output out=nlin predicted=pred lclm=l95 uclm=u95;
run;
/*ods trace off;*/
*	Put parameters into macro variables;
data _null_;
	set nlin_est;
	call symputx(parameter,estimate);
run;
%put {'a':"&a.", 'b':"&b.", 'c':"&c.", 'd':"&d."};
*	Forecast;
data fore;
	set nlin end=last;
	format date date9.;
	date="&datefrom."d+x;
	output;
	if last then
		do i=1 to 15;
			call missing(y,l95,u95);
			x=x+1;
			date="&datefrom."d+x;
			pred = &a.*exp(&b.*(x)) - &c.*exp(&d./(x));
			output;
		end;
run;
title "Model of COVID-19";
footnote "Exponential growth fit and forecast";
proc sgplot data=fore noautolegend;
	band x=date lower=l95 upper=u95;
	scatter x=date y=y;
	series x=date y=pred;
	xaxis label="Days since &datefrom." grid ; 
	yaxis label='Cases' grid 
		type=log logstyle=logexpand logbase=10
	;
run;
