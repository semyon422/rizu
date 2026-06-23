local BMS = require("chart.format.bms.BMS")
local Fixtures = require("chart.format.bms.TestFixtures")

local test = {}

---@param content string
---@param pms boolean?
---@return chart.bms.BMS
local function parse(content, pms)
	local bms = BMS()
	bms.pms = pms
	bms:import(content)
	return bms
end

---@param t testing.T
function test.headers_and_resources(t)
	local bms = parse(Fixtures.basic())

	t:eq(bms.header.TITLE, "Fixture Song [Normal]")
	t:eq(bms.header.ARTIST, "Fixture Artist")
	t:eq(bms.header.PLAYLEVEL, "5")
	t:eq(bms.header.RANK, "3")
	t:eq(bms.header.STAGEFILE, "stage.png")
	t:eq(bms.wav["01"], "hit.wav")
	t:eq(bms.bmp["01"], "image.png")
	t:eq(bms.bpm["01"], 180)
	t:eq(bms.stop["01"], 48)
	t:eq(bms.baseTempo, 120)
end

---@param t testing.T
function test.timing_and_line_data(t)
	local bms = parse(Fixtures.basic({
		"#00002:1.5",
		"#00003:78",
		"#00008:01",
		"#00009:01",
		"#00101:0102",
		"#00111:0100",
		"#00151:0001",
		"#999ZZ:0101",
		"#00211:010",
	}))

	t:eq(bms.signature[0], 1.5)
	t:eq(bms.tempoAtStart, true)
	t:eq(bms.measureCount, 999)
	t:eq(#bms.timeList, 4)
	t:eq(tostring(bms.timeList[1].measureTime), "0.0/1")
	t:eq(bms.timeList[1]["03"][1], "78")
	t:eq(bms.timeList[1]["08"][1], "01")
	t:eq(bms.timeList[1]["09"][1], "01")
	t:tdeq(bms.timeList[2]["01"], {"01"})
	t:tdeq(bms.timeList[3]["01"], {"02"})
	t:eq(bms.timeList[4]["11"][1], "01")
end

---@param t testing.T
function test.mode_detection(t)
	local cases = {
		{channels = {"11"}, mode = 5},
		{channels = {"18"}, mode = 7},
		{channels = {"21"}, mode = 10},
		{channels = {"28"}, mode = 14},
		{channels = {"11", "26"}, mode = 25},
		{channels = {"18", "26"}, mode = 27},
	}

	for _, case in ipairs(cases) do
		local bms = parse(Fixtures.mode(case.channels))
		t:eq(bms.mode, case.mode)
	end

	t:eq(parse(Fixtures.mode({"23"}), true).mode, 55)
	t:eq(parse(Fixtures.mode({"24"}), true).mode, 59)
end

---@param t testing.T
function test.error_tolerant_parsing_quirks(t)
	local bms = parse(Fixtures.join({
		"#TITLE Invalids",
		"#ARTIST Tester",
		"#BPM not_a_number",
		"#BPMAA nope",
		"#STOPAA nope",
		"#001ZZ:0101",
		"#00211:010",
	}))

	t:eq(bms.baseTempo, nil)
	t:eq(bms.hasTempo, true)
	t:eq(bms.bpm.AA, nil)
	t:eq(bms.stop.AA, nil)
	t:eq(bms.measureCount, 2)
	t:eq(#bms.timeList, 1)
	t:eq(tostring(bms.timeList[1].measureTime), "2.0/1")
	t:eq(bms.timeList[1]["11"][1], "01")
end

return test
