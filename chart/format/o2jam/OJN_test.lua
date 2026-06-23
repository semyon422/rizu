local ChartDecoder = require("chart.format.o2jam.ChartDecoder")
local Fixtures = require("chart.format.o2jam.TestFixtures")
local OJN = require("chart.format.o2jam.OJN")

local test = {}

---@param t testing.T
function test.parse_generated_ojn(t)
	local ojn = OJN(Fixtures.ojn())

	t:eq(ojn.songid, 1234)
	t:eq(ojn.signature, "ojn")
	t:eq(ojn.str_title, "Fixture Title")
	t:eq(ojn.str_artist, "Fixture Artist")
	t:eq(ojn.str_noter, "Fixture Noter")
	t:eq(ojn.sample_file, "fixture.ojm")
	t:eq(ojn.cover, "cover")

	local events = ojn.charts[1].event_list
	t:eq(#events, 5)
	t:eq(events[1].channel, "BPM_CHANGE")
	t:eq(events[1].value, 150)
	t:eq(events[2].channel, "TIME_SIGNATURE")
	t:eq(events[2].value, 750)
	t:eq(events[3].channel, "NOTE_1")
	t:eq(events[3].value, 4)
	t:eq(events[3].type, "HOLD")
	t:eq(events[3].volume, 1)
	t:eq(events[3].pan, 0)
	t:eq(events[4].type, "RELEASE")
	t:eq(events[4].volume, 0.5)
	t:eq(events[4].pan, 0)
	t:eq(events[5].channel, "AUTO_PLAY")
	t:eq(events[5].value, 1001)
end

---@param t testing.T
function test.parse_encrypted_ojn(t)
	local ojn = OJN(Fixtures.encryptedOjn())

	t:eq(ojn.signature, "ojn")
	t:eq(ojn.songid, 1234)
	t:eq(ojn.cover, "cover")
	t:eq(#ojn.charts[1].event_list, 5)
end

---@param t testing.T
function test.decode_generated_chart(t)
	local decoded = ChartDecoder():decode(Fixtures.ojn(), "0123456789abcdef0123456789abcdef")

	t:eq(#decoded, 3)
	t:eq(decoded[1].chartmeta.title, "Fixture Title")
	t:eq(decoded[1].chartmeta.artist, "Fixture Artist")
	t:eq(decoded[1].chartmeta.creator, "Fixture Noter")
	t:eq(decoded[1].chartmeta.level, 3)
	t:eq(decoded[1].chartmeta.tempo, 128)
	t:eq(decoded[2].chartmeta.level, 7)
	t:eq(decoded[3].chartmeta.level, 12)
end

return test
