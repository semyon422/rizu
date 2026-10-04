local json = require("json")
local FakeFilesystem = require("fs.FakeFilesystem")
local ResultExporter = require("rizu.gameplay.ResultExporter")

local test = {}

---@diagnostic disable: missing-fields

---@param t testing.T
function test.serializes_result_metadata_hits_and_non_finite_values(t)
	local data = ResultExporter.serialize(
		{id = 42},
		{title = "Title", artist = "Artist", name = "SPH"},
		{
			rate = 1.25,
			mode = "mania",
			timings = {name = "iidx", data = 0},
			modifiers = {{id = 3, version = 1, value = true}},
		},
		{
			events = {{index = 7, column = 2, delta_time = 0.01}},
			sequence = {{
				base = {currentTime = 1, isMiss = false},
				misc = {deltaTime = -math.huge},
				iidx = {last_judge = 1},
			}},
		},
		{input = 0.02}
	)

	local result = json.decode(data)
	t:eq(result.version, 1)
	t:eq(result.score_id, 42)
	t:eq(result.title, "Title")
	t:eq(result.artist, "Artist")
	t:eq(result.diff_name, "SPH")
	t:eq(result.replay_base.rate, 1.25)
	t:eq(result.replay_base.timings.name, "iidx")
	t:eq(result.hits[1].delta_time, 0.01)
	t:eq(result.sequence[1].misc.deltaTime, "-Infinity")
end

---@param t testing.T
function test.export_writes_result_file(t)
	local fs = FakeFilesystem()
	fs:createDirectory("userdata")

	local ok, err = ResultExporter.export(
		fs,
		"userdata/result.json",
		{id = 9},
		{title = "T", artist = "A", name = "N"},
		{rate = 1, mode = "mania"},
		{events = {}, sequence = {}},
		{input = 0.02}
	)

	t:eq(ok, true)
	t:eq(err, nil)
	local result = json.decode(assert(fs:read("userdata/result.json")))
	t:eq(result.score_id, 9)
	t:eq(result.offset, nil)
end

---@diagnostic enable: missing-fields
return test
