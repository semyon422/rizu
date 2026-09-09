local NotesPreview = require("rizu.preview.NotesPreview")
local SphPreview = require("chart.format.sph.SphPreview")
local Fraction = require("chart.core.Fraction")
local ChartDecoder = require("chart.format.sph.ChartDecoder")
local Sph = require("chart.format.sph.Sph")

local test = {}

---@param t testing.T
function test.timing_and_holds(t)
	local lines = {
		{notes = {true}},
		{offset = 0},
		{time = Fraction(1, 2), notes = {false, true}},
		{offset = 2},
		{time = Fraction(1, 2), notes = {true}},
		{offset = 3},
		{notes = {nil, true}},
	}
	for version = 0, 1 do
		local data = SphPreview:encode(lines, version)
		local preview = NotesPreview(data, 2)
		t:tdeq(preview.columns, {
			{{time = -2, end_time = 1}, {time = 2.5, end_time = 2.5}},
			{{time = 1, end_time = 1}, {time = 4, end_time = 4}},
		})
		local sph = Sph()
		sph.metadata:set("input", "2key")
		sph.metadata:set("title", "")
		sph.metadata:set("artist", "")
		sph.sphLines:decode(SphPreview:decodeLines(data))
		local chart = ChartDecoder():decodeSph(sph)
		local times = {}
		for _, note in ipairs(chart.notes:getLinkedNotes()) do
			times[#times + 1] = note.startNote.visualPoint.point.absoluteTime
		end
		table.sort(times)
		t:tdeq(times, {-2, 1, 2.5, 4})
	end
end

---@param t testing.T
function test.visible_range_and_seek(t)
	local preview = NotesPreview(SphPreview:encode({
		{offset = 0, notes = {true}},
		{offset = 1, notes = {false, true}},
		{offset = 2, notes = {true}},
	}), 2)
	local a, b = preview:getVisibleRange(1, 0.5, 0.75)
	t:eq(a, 1)
	t:eq(b, 1)
	a, b = preview:getVisibleRange(1, 3, 4)
	t:eq(a, 3)
	t:eq(b, 2)
	a, b = preview:getVisibleRange(1, 0, 0)
	t:eq(a, 1)
	t:eq(b, 1)
end

---@param t testing.T
function test.invalid_and_empty(t)
	t:eq(#NotesPreview("", 4).columns, 4)
	t:has_error(function() NotesPreview("x", 4) end)
	t:has_error(function() NotesPreview(SphPreview:encode({{notes = {true}}}), 4) end)
	t:has_error(function() NotesPreview(SphPreview:encode({{offset = 0, notes = {false}}, {offset = 1}}), 4) end)
end

return test
