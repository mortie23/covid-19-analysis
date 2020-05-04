*	Use the timeseries data to analyse;
proc summary missing data=covid.timeseries;
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
*	Use parameters to define the period of fit;
%let datefrom=20mar2020;
%let dateto=18apr2020;
data nlin_pre;
	set timeseries_country;
	where country='Global' and date > "&datefrom."d and date <= "&dateto."d;
	x=date-"&datefrom."d;
	y=cases;
	keep date x y;
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
proc json out="&pwd.\param-est.json" pretty;
	export nlin_est;
run;
*	Forecast out a number of days from the latest data point;
%let forecasthorizon = 15;
data covid.fore;
	set timeseries_country (where=(country='Global')) end=last;
	x=date-"&datefrom."d;
	y=cases;
	if date > "&datefrom."d then do;
		pred = &a.*exp(&b.*(x)) - &c.*exp(&d./(x));
		end;
	format date date9.;
	if date > "&dateto."d then do;
		y_new=cases;
		end;
	output;
	if last then
		do i=1 to &forecasthorizon.;
			call missing(cases,y_new,y,l95,u95);
			x=x+1;
			date="&datefrom."d+x;
			pred = &a.*exp(&b.*(x)) - &c.*exp(&d./(x));
			output;
		end;
	label	y="Cases"
			y_new="Cases not in period of fit"
			pred="Model Fit and Forecast"
	;
run;
*	Add back the confidence limits;
data covid.fore;
	merge	covid.fore
			nlin (keep=date u95 l95);
	by date;
run;
*	Plot the results using log scale to see how well the basic model fit;
title "Model of COVID-19";
footnote "Exponential growth fit and forecast";
proc sgplot data=covid.fore ;
	where date > "&datefrom"d - 7;
	/*band x=date lower=l95 upper=u95;*/
	scatter x=date y=y;
	scatter x=date y=y_new / markerattrs=(size=6 symbol=circlefilled color=red);
	series x=date y=pred ;
	xaxis label="Period of fit &datefrom. to &dateto." grid ; 
	yaxis label='Cases' grid type=log logstyle=logexpand logbase=10;
	keylegend / location=inside position=bottomright across=1;
run;
*	Output processed to CSV for record keeping;
proc export data=covid.fore
	outfile="&pwd.\tsdata-fore.csv"
	dbms=csv replace;
run;

