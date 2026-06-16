local FakeFilesystem = require("fs.FakeFilesystem")
local Wave = require("audio.Wave")
local AudioPreviewGenerator = require("rizu.preview.AudioPreviewGenerator")
local AudioPreview = require("rizu.preview.AudioPreview")
local TestChartFactory = require("sea.chart.TestChartFactory")
local WaveDecoder = require("rizu.engine.audio.WaveDecoder")
local Fixtures = require("chart.format.iidx.TestFixtures")

local test = {}

---@param t testing.T
function test.generate(t)
	local fs = FakeFilesystem()
	local generator = AudioPreviewGenerator(fs, function(data)
		return WaveDecoder(data)
	end)

	-- Create a fake wav file (1 second)
	local wave = Wave()
	wave.sample_rate = 44100
	wave:initBuffer(1, 44100)
	local wav_data = wave:encode()

	fs:createDirectory("chart")
	fs:write("chart/hit.wav", wav_data)

	-- Create a chart
	local tcf = TestChartFactory()
	local res = tcf:create("4key", {
		{time = 1.0, column = 1},
		{time = 2.0, column = 2},
	})

	-- Manually add sounds to notes
	local notes = res.chart.notes.notes
	notes[1].data.sounds = {{"hit.wav", 1.0}} ---@diagnostic disable-line: no-unknown
	notes[2].data.sounds = {{"hit.wav", 0.5}} ---@diagnostic disable-line: no-unknown

	generator:generate(res.chart, "chart", "test_hash")

	local preview_path = "userdata/audio_previews/test_hash.audio_preview"
	local preview_data = fs:read(preview_path)
	t:assert(preview_data, "preview file should exist")
	---@cast preview_data -?

	local preview = AudioPreview()
	preview:decode(preview_data)

	t:eq(#preview.samples, 1)
	t:eq(preview.samples[1], "hit.wav")
	t:eq(#preview.events, 2)

	t:eq(preview.events[1].time, 1.0)
	t:eq(preview.events[1].sample_index, 1)
	t:eq(preview.events[1].duration, 1.0)
	t:eq(preview.events[1].volume, 1.0)

	t:eq(preview.events[2].time, 2.0)
	t:eq(preview.events[2].sample_index, 1)
	t:eq(preview.events[2].duration, 1.0)
	t:aeq(preview.events[2].volume, 0.5, 0.01)
end

---@param t testing.T
function test.generate_main_audio(t)
	local fs = FakeFilesystem()
	local generator = AudioPreviewGenerator(fs, function(data)
		return WaveDecoder(data)
	end)

	-- Create a fake wav file (1 second)
	local wave = Wave()
	wave.sample_rate = 44100
	wave:initBuffer(1, 44100)
	local wav_data = wave:encode()

	fs:createDirectory("chart")
	fs:write("chart/bgm.wav", wav_data)
	fs:write("chart/hit.wav", wav_data)

	-- Create a chart
	local tcf = TestChartFactory()
	local res = tcf:create("4key", {
		{time = 1.0, column = 1},
		{time = 2.0, column = 2},
		{time = 0.0, column = "audio"},
	})

	-- Manually add sounds to notes
	local notes = res.chart.notes.notes
	-- After compute(), notes are sorted by time:
	-- index 1: time 0.0, column "audio"
	-- index 2: time 1.0, column "key1"
	-- index 3: time 2.0, column "key2"
	notes[1].data.sounds = {{"bgm.wav", 1.0}} ---@diagnostic disable-line: no-unknown
	notes[2].data.sounds = {{"hit.wav", 1.0}} ---@diagnostic disable-line: no-unknown
	notes[3].data.sounds = {{"hit.wav", 0.5}} ---@diagnostic disable-line: no-unknown

	generator:generate(res.chart, "chart", "test_hash_main")

	local preview_path = "userdata/audio_previews/test_hash_main.audio_preview"
	local preview_data = fs:read(preview_path)
	t:assert(preview_data, "preview file should exist")
	---@cast preview_data -?

	local preview = AudioPreview()
	preview:decode(preview_data)

	-- Should only contain bgm.wav
	t:eq(#preview.samples, 1)
	t:eq(preview.samples[1], "bgm.wav")
	t:eq(#preview.events, 1)

	t:eq(preview.events[1].time, 0.0)
	t:eq(preview.events[1].sample_index, 1)
	t:eq(preview.events[1].duration, 1.0)
	t:eq(preview.events[1].volume, 1.0)
end

---@param t testing.T
function test.generate_iidx_s3p(t)
	local fs = FakeFilesystem()
	local generator = AudioPreviewGenerator(fs, function(data)
		return WaveDecoder(data)
	end)

	local wave = Wave()
	wave.sample_rate = 44100
	wave:initBuffer(1, 44100)
	local wav_data = wave:encode()

	fs:createDirectory("chart")
	fs:write("chart/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), Fixtures.s3p({wav_data, wav_data})))

	local tcf = TestChartFactory()
	local res = tcf:create("4key", {
		{time = 1.0, column = "auto"},
		{time = 2.0, column = "auto"},
	})
	res.chart.resources:add("s3p", "01234/01234.s3p")
	res.chart.notes.notes[1].type = "sample"
	res.chart.notes.notes[1].data.sounds = {{"1", 1.0}} ---@diagnostic disable-line: no-unknown
	res.chart.notes.notes[2].type = "sample"
	res.chart.notes.notes[2].data.sounds = {{"2", 0.5}} ---@diagnostic disable-line: no-unknown

	generator:generate(res.chart, "chart/01234.ifs", "test_hash_iidx")

	local preview_path = "userdata/audio_previews/test_hash_iidx.audio_preview"
	local preview_data = fs:read(preview_path)
	t:assert(preview_data, "preview file should exist")
	---@cast preview_data -?

	local preview = AudioPreview()
	preview:decode(preview_data)

	t:eq(preview.samples[1], "01234/01234.s3p")
	t:eq(#preview.events, 2)
	t:eq(preview.events[1].sample_index, 1)
	t:eq(preview.events[2].sample_index, 2)
end

---@param t testing.T
function test.generate_iidx_2dx_fallback(t)
	local fs = FakeFilesystem()
	local generator = AudioPreviewGenerator(fs, function(data)
		return WaveDecoder(data)
	end)

	local wave = Wave()
	wave.sample_rate = 44100
	wave:initBuffer(1, 44100)
	local wav_data = wave:encode()

	fs:createDirectory("chart")
	fs:write("chart/01234.ifs", Fixtures.ifs(1234, Fixtures.sampleChart(), nil, {
		{path = "01234/012341.2dx", data = Fixtures.twoDx("012341", {wav_data, wav_data}), time = 1234},
	}))

	local tcf = TestChartFactory()
	local res = tcf:create("4key", {
		{time = 1.0, column = "auto"},
		{time = 2.0, column = "auto"},
	})
	res.chart.resources:add("s3p", "01234/01234.s3p")
	res.chart.resources:add("2dx", "01234/01234.2dx", "01234/012341.2dx")
	res.chart.notes.notes[1].type = "sample"
	res.chart.notes.notes[1].data.sounds = {{"1", 1.0}} ---@diagnostic disable-line: no-unknown
	res.chart.notes.notes[2].type = "sample"
	res.chart.notes.notes[2].data.sounds = {{"2", 0.5}} ---@diagnostic disable-line: no-unknown

	generator:generate(res.chart, "chart/01234.ifs", "test_hash_iidx_2dx")

	local preview_path = "userdata/audio_previews/test_hash_iidx_2dx.audio_preview"
	local preview_data = fs:read(preview_path)
	t:assert(preview_data, "preview file should exist")
	---@cast preview_data -?

	local preview = AudioPreview()
	preview:decode(preview_data)

	t:eq(preview.samples[1], "01234/012341.2dx")
	t:eq(#preview.events, 2)
	t:eq(preview.events[1].sample_index, 1)
	t:eq(preview.events[2].sample_index, 2)
end

return test
