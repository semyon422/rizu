local Chart1 = require("chart.format.iidx.Chart1")
local Fixtures = require("chart.format.iidx.TestFixtures")

local test = {}

---@param t testing.T
function test.parse_sections_and_events(t)
	local chart = Chart1.parse(Fixtures.sampleChart())
	local spn = chart.sections[1]
	local dpn = chart.sections[7]

	t:eq(spn.name, "SPN")
	t:eq(dpn.name, "DPN")
	t:eq(#spn.events, 9)
	t:eq(spn.events[1].tick, 0)
	t:eq(spn.events[1].type, 4)
	t:eq(spn.events[7].tick, 750)
	t:eq(spn.events[7].raw_lane, 7)
	t:eq(#dpn.events, 8)
end

---@param t testing.T
function test.names_dpb_section(t)
	local chart = Chart1.parse(Fixtures.chart1({
		DPB = {
			{tick = 0, type = 12, lane = 0, value = 0},
		},
	}))

	t:eq(chart.sections[5].name, "DPB")
	t:eq(#chart.sections[5].events, 1)
end

return test
