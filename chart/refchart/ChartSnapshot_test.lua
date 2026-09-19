local ChartSnapshot = require("chart.refchart.ChartSnapshot")
local SnapshotRestorer = require("chart.refchart.SnapshotRestorer")
local RefChart = require("chart.refchart.RefChart")
local Fraction = require("chart.core.Fraction")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Note = require("chart.model.notes.Note")
local Tempo = require("chart.model.to.Tempo")
local Measure = require("chart.model.to.Measure")
local Visual = require("chart.model.visual.Visual")
local Expand = require("chart.model.visual.Expand")
local Velocity = require("chart.model.visual.Velocity")

local test = {}

---@return chart.Chart
local function createChart()
	local chart = Chart()
	chart.inputMode:set("4key")
	chart.data.mode = "test"

	local layer = AbsoluteLayer()
	chart.layers.main = layer
	local visual = Visual()
	visual.bga = true
	layer.visuals.main = visual

	local point = layer:getPoint(1)
	point._tempo = Tempo(120)
	point._measure = Measure(Fraction(1, 2))
	local visual_point = visual:getPoint(point)
	visual_point._velocity = Velocity(2, 3, 4)
	visual_point._expand = Expand(1)

	chart.notes:insert(Note(visual_point, "key1", "tap", 0, {
		sounds = {{"hit.ogg", 0.5}},
	}))
	chart.notes:insert(Note(visual:newPoint(point), "key2", "tap", 0))
	chart.resources:add("sound", "audio.ogg", "fallback.ogg")
	chart:compute()
	return chart
end

---@param t testing.T
function test.round_trip(t)
	local chart = createChart()
	local restored = assert(SnapshotRestorer():restore(ChartSnapshot(chart)))
	t:tdeq(RefChart(restored), RefChart(chart))
	local source_visual_point = chart.layers.main.visuals.main.points[1]
	local restored_visual_point = restored.layers.main.visuals.main.points[1]
	t:eq(restored_visual_point.visualTime, source_visual_point.visualTime)
	t:eq(restored_visual_point.monotonicVisualTime, source_visual_point.monotonicVisualTime)
	t:eq(restored_visual_point.currentSpeed, source_visual_point.currentSpeed)
	t:eq(restored_visual_point.localSpeed, source_visual_point.localSpeed)
	t:eq(restored_visual_point.globalSpeed, source_visual_point.globalSpeed)
	t:eq(#restored.notes.linked_notes, #chart.notes.linked_notes)
end

---@param t testing.T
function test.snapshot_is_isolated(t)
	local chart = createChart()
	local snapshot = ChartSnapshot(chart)
	chart.data.mode = "changed"
	---@type {sounds: {[1]: {[1]: string, [2]: number}}}
	local chart_note_data = chart.notes.notes[1].data
	chart_note_data.sounds[1][1] = "changed.ogg"

	t:eq(snapshot.data.mode, "test")
	---@type {sounds: {[1]: {[1]: string, [2]: number}}}
	local snapshot_note_data = snapshot.notes.data[1]
	t:eq(snapshot_note_data.sounds[1][1], "hit.ogg")
	t:eq(snapshot.notes.data[2], nil)
end

---@param t testing.T
function test.restored_data_is_isolated(t)
	local snapshot = ChartSnapshot(createChart())
	local restored = assert(SnapshotRestorer():restore(snapshot))
	snapshot.data.mode = "changed"
	---@type {sounds: {[1]: {[1]: string, [2]: number}}}
	local snapshot_note_data = snapshot.notes.data[1]
	snapshot_note_data.sounds[1][1] = "changed.ogg"

	t:eq(restored.data.mode, "test")
	---@type {sounds: {[1]: {[1]: string, [2]: number}}}
	local restored_note_data = restored.notes.notes[1].data
	t:eq(restored_note_data.sounds[1][1], "hit.ogg")
end

---@param t testing.T
function test.restore_can_be_cancelled(t)
	local snapshot = ChartSnapshot(createChart())
	local checkpoints = 0
	local restored = SnapshotRestorer():restore(snapshot, function()
		checkpoints = checkpoints + 1
		return false
	end)
	t:eq(restored, nil)
	t:eq(checkpoints, 1)
end

return test
