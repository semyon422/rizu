local ChartFactory = require("chart.format.notechart.ChartFactory")
local ChartfileReader = require("rizu.library.ChartfileReader")
local FakeFilesystem = require("fs.FakeFilesystem")
local Fixtures = require("chart.format.iidx.TestFixtures")
local md5 = require("md5")

local test = {}

---@param chart chart.Chart
---@param sample_id string
---@return notechart.Note?
local function find_sound_note(chart, sample_id)
	for _, note in chart.notes:iter() do
		local sounds = note.data.sounds
		if sounds and sounds[1] and sounds[1][1] == sample_id then
			return note
		end
	end
end

---@param t testing.T
function test.decode_chart_extracted_from_ifs_fixture(t)
	local chart_data = Fixtures.sampleChart()
	local fs = FakeFilesystem()
	fs:createDirectory("data")
	fs:createDirectory("data/sound")
	fs:write("data/sound/01234.ifs", Fixtures.ifs(1234, chart_data))
	local extracted_data = assert(ChartfileReader.read(fs, "data/sound/01234.ifs/01234/01234.1"))
	local song = {
		song_id = 1234,
		title = "Fixture Song",
		artist = "Fixture Artist",
		genre = "Fixture Genre",
		levels = {
			SPN = 3,
			SPH = 5,
			DPN = 4,
			DPH = 6,
		},
	}

	local charts = assert(ChartFactory:getCharts("01234/01234.1", extracted_data, nil, {
		song_id = 1234,
		iidx_song = song,
	}))

	t:eq(#charts, 2)
	t:eq(charts[1].chartmeta.hash, md5.sumhexa(chart_data))
	t:eq(charts[1].chartmeta.name, "SPN")
	t:eq(charts[1].chartmeta.title, "Fixture Song")
	t:eq(charts[1].chartmeta.artist, "Fixture Artist")
	t:eq(charts[1].chartmeta.source, "Fixture Genre")
	t:eq(charts[1].chartmeta.level, 3)
	t:eq(charts[1].chartmeta.inputmode, "7key1scratch")
	t:tdeq(charts[1].chart.resources.s3p["01234/01234.s3p"], {"01234/01234.s3p", "01234.s3p"})
	t:eq(charts[1].chart.resources["2dx"], nil)
	t:eq(assert(find_sound_note(charts[1].chart, "1")).type, "tap")
	t:eq(assert(find_sound_note(charts[1].chart, "3")).type, "sample")
	t:eq(charts[2].chartmeta.name, "DPN")
	t:eq(charts[2].chartmeta.inputmode, "14key2scratch")
end

---@param t testing.T
function test.uses_metadata_ident_for_2dx_bank(t)
	local charts = assert(ChartFactory:getCharts("01234/01234.1", Fixtures.sampleChart(), nil, {
		song_id = 1234,
		iidx_song = {
			song_id = 1234,
			title = "Fixture",
			idents = {
				SPN = string.byte("a"),
				DPN = string.byte("2"),
			},
		},
	}))

	t:tdeq(charts[1].chart.resources["2dx"]["01234/01234a.2dx"], {"01234/01234a.2dx"})
	t:tdeq(charts[2].chart.resources["2dx"]["01234/012342.2dx"], {"01234/012342.2dx"})
end

---@param t testing.T
function test.uses_base_2dx_bank_for_zero_ident(t)
	local charts = assert(ChartFactory:getCharts("01234/01234.1", Fixtures.sampleChart(), nil, {
		song_id = 1234,
		iidx_song = {
			song_id = 1234,
			title = "Fixture",
			idents = {
				SPN = string.byte("0"),
			},
		},
	}))

	t:tdeq(charts[1].chart.resources["2dx"]["01234/01234.2dx"], {"01234/01234.2dx"})
end

---@param t testing.T
function test.decode_extracted_chart_fixture(t)
	local charts = assert(ChartFactory:getCharts("01234.1", Fixtures.sampleChart(), nil, {
		song_id = 1234,
		iidx_song = {
			song_id = 1234,
			title = "Extracted",
			artist = "Artist",
			genre = "Genre",
			levels = {
				SPN = 3,
				DPN = 4,
			},
		},
	}))

	t:eq(#charts, 2)
	t:eq(charts[1].chartmeta.title, "Extracted")
	t:eq(charts[1].chartmeta.inputmode, "7key1scratch")
	t:eq(charts[2].chartmeta.inputmode, "14key2scratch")
end

---@param t testing.T
function test.tap_note_counts(t)
	local charts = assert(ChartFactory:getCharts("01234/01234.1", Fixtures.sampleChart(), nil, {
		song_id = 1234,
		iidx_song = {
			song_id = 1234,
			title = "Fixture",
			levels = {
				SPN = 3,
				DPN = 4,
			},
		},
	}))

	local counts = {}
	for _, chart_chartmeta in ipairs(charts) do
		local count = 0
		for _, note in ipairs(chart_chartmeta.chart.notes.notes) do
			if note.type == "tap" then
				count = count + 1
			end
		end
		counts[chart_chartmeta.chartmeta.name] = count
	end

	t:eq(counts.SPN, 2)
	t:eq(counts.DPN, 2)
end

---@param t testing.T
function test.off_grid_ticks_stay_inside_measure(t)
	local charts = assert(ChartFactory:getCharts("01234/01234.1", Fixtures.chart1({
		SPN = {
			{tick = 0, type = 4, lane = 0, value = 150},
			{tick = 0, type = 12, lane = 0, value = 0},
			{tick = 1500, type = 12, lane = 0, value = 0},
			{tick = 1499, type = 0, lane = 0, value = 1},
		},
	}), nil, {song_id = 1234}))

	local chart = charts[1].chart
	local note = assert(find_sound_note(chart, "1"))

	t:aeq(note:getTime(), 1.5989, 0.0001)
end

---@param t testing.T
function test.keysound_events_attach_to_notes(t)
	local charts = assert(ChartFactory:getCharts("01234/01234.1", Fixtures.chart1({
		SPN = {
			{tick = 0, type = 4, lane = 0, value = 150},
			{tick = 0, type = 12, lane = 0, value = 0},
			{tick = 1500, type = 12, lane = 0, value = 0},
			{tick = 600, type = 2, lane = 3, value = 42},
			{tick = 750, type = 0, lane = 3, value = 0},
		},
	}), nil, {song_id = 1234}))

	local chart = charts[1].chart
	local tap_count = 0
	for _, note in ipairs(chart.notes.notes) do
		if note.type == "tap" then
			tap_count = tap_count + 1
		end
	end

	t:eq(tap_count, 1)
	t:eq(assert(find_sound_note(chart, "42")).column, "key4")
end

---@param t testing.T
function test.zero_value_notes_inherit_lane_keysound(t)
	local charts = assert(ChartFactory:getCharts("01234/01234.1", Fixtures.chart1({
		SPN = {
			{tick = 0, type = 4, lane = 0, value = 150},
			{tick = 0, type = 12, lane = 0, value = 0},
			{tick = 1500, type = 12, lane = 0, value = 0},
			{tick = 600, type = 2, lane = 3, value = 42},
			{tick = 750, type = 0, lane = 3, value = 0},
			{tick = 900, type = 0, lane = 3, value = 0},
		},
	}), nil, {song_id = 1234}))

	local chart = charts[1].chart
	local sounds = {}
	for _, note in ipairs(chart.notes.notes) do
		if note.type == "tap" then
			sounds[#sounds + 1] = assert(note.data.sounds)[1][1]
		end
	end

	t:tdeq(sounds, {"42", "42"})
end

return test
