local ChartDecoder = require("chart.format.bms.ChartDecoder")
local PmsChartDecoder = require("chart.format.bms.PmsChartDecoder")
local Fixtures = require("chart.format.bms.TestFixtures")

local test = {}

local hash = "0123456789abcdef0123456789abcdef"

---@param chart chart.Chart
---@param predicate fun(note: notechart.Note): boolean
---@return notechart.Note?
local function find_note(chart, predicate)
	for _, note in ipairs(chart.notes.notes) do
		if predicate(note) then
			return note
		end
	end
end

---@param t testing.T
function test.decode_chartmeta_and_resources(t)
	local decoded = ChartDecoder():decode(Fixtures.basic({
		"#00101:0102",
		"#00104:01",
		"#00111:0100",
	}), hash)
	local chart = decoded[1].chart
	local chartmeta = decoded[1].chartmeta

	t:eq(chartmeta.title, "Fixture Song ")
	t:eq(chartmeta.name, "Normal")
	t:eq(chartmeta.artist, "Fixture Artist")
	t:eq(chartmeta.level, 5)
	t:eq(chartmeta.inputmode, "5key1scratch")
	t:eq(chartmeta.tempo, 120)
	t:tdeq(chart.resources.sound["hit.wav"], {"hit.wav"})
	t:tdeq(chart.resources.sound["bgm.wav"], {"bgm.wav"})
	t:tdeq(chart.resources.image["image.png"], {"image.png"})

	local tap = assert(find_note(chart, function(note)
		return note.column == "key1" and note.type == "tap"
	end))
	t:eq(tap.data.sounds[1][1], "hit.wav")

	local sample = assert(find_note(chart, function(note)
		return note.column == "auto0" and note.type == "sample"
	end))
	t:eq(sample.data.sounds[1][1], "hit.wav")

	local sprite = assert(find_note(chart, function(note)
		return note.column == "bmsbga4" and note.type == "sprite"
	end))
	t:eq(sprite.data.images[1][1], "image.png")
end

---@param t testing.T
function test.decode_lnobj_hold(t)
	local decoded = ChartDecoder():decode(Fixtures.basic({
		"#LNOBJ 02",
		"#00111:0102",
	}), hash)
	local chart = decoded[1].chart

	local head = assert(find_note(chart, function(note)
		return note.column == "key1" and note.type == "hold" and note.weight == 1
	end))
	local tail = assert(find_note(chart, function(note)
		return note.column == "key1" and note.type == "hold" and note.weight == -1
	end))

	t:aeq(head:getTime(), 2, 0.0001)
	t:aeq(tail:getTime(), 3, 0.0001)
	t:eq(head.data.sounds[1][1], "hit.wav")
	t:eq(#tail.data.sounds, 0)
end

---@param t testing.T
function test.decode_mine_and_invisible_lane_conflict(t)
	local decoded = ChartDecoder():decode(Fixtures.basic({
		"#001D1:01",
		"#00131:01",
		"#00111:01",
	}), hash)
	local chart = decoded[1].chart

	local mine = assert(find_note(chart, function(note)
		return note.column == "key1" and note.type == "mine"
	end))

	t:aeq(mine:getTime(), 2, 0.0001)
	t:eq(find_note(chart, function(note)
		return note.column == "key1" and note.type == "tap"
	end), nil)
end

---@param t testing.T
function test.decode_pms_uses_pms_mode(t)
	local decoded = PmsChartDecoder():decode(Fixtures.basic({
		"#00124:01",
	}), hash)

	t:eq(decoded[1].chartmeta.inputmode, "9key")
end

return test
