local Sm = require("chart.format.stepmania.Sm")

local test = {}

function test.basic(t)
	local sm = Sm()

	sm:import([[
#TITLE:Title;
#BPMS:0=180
,16=240
,32=120;
#STOPS:;

//---------------dance-single - ----------------
#NOTES:
     dance-single:
     :
     Challenge:
     1:

     0.000,0.000,0.000,0.000,0.000:
  //  Measure 0
1000
0100
0010
0001
,  //  Measure 1
1000
0100
0010
0001
;
]])

	local chart = sm.charts[1]

	local header = chart.header
	t:eq(header.stepstype, "dance-single")
	t:eq(header.description, "")
	t:eq(header.difficulty, "Challenge")
	t:eq(header.meter, "1")
	t:eq(header.radarvalues, "0.000,0.000,0.000,0.000,0.000")

	t:eq(#chart.notes, 8)
end

return test
