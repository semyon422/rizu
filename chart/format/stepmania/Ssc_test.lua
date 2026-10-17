local Ssc = require("chart.format.stepmania.Ssc")

local test = {}

function test.basic(t)
	local ssc = Ssc()

	ssc:decode([[
#TITLE:Title;
#BPMS:0=180
,16=240
,32=120;
#STOPS:;

//---------------dance-single - ----------------
#NOTEDATA:;
#STEPSTYPE:dance-single;
#DESCRIPTION:desc;
#DIFFICULTY:Beginner;
#METER:1;
#RADARVALUES:0;
#DISPLAYBPM:100.000;
#CHARTNAME:;
#CHARTSTYLE:;
#CREDIT:;
#NOTES:
1000
0100
0010
0001
,
1000
0100
0010
0001
;
]])

	local chart = ssc.charts[1]

	local header = chart.header
	t:eq(header.stepstype, "dance-single")
	t:eq(header.description, "desc")
	t:eq(header.difficulty, "Beginner")
	t:eq(header.meter, "1")
	t:eq(header.radarvalues, "0")

	t:eq(#chart.notes, 8)
end

return test
