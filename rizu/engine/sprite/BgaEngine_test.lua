local BgaEngine = require("rizu.engine.sprite.BgaEngine")
local VisualInfo = require("rizu.engine.visual.VisualInfo")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Visual = require("chart.model.visual.Visual")
local InputMode = require("chart.core.InputMode")
local Note = require("chart.format.notechart.Note")

local test = {}

---@param t testing.T
function test.bga_basic(t)
	local visual_info = VisualInfo()
	local bga_engine = BgaEngine(visual_info)

	local chart = Chart()
	chart.inputMode = InputMode("4key")
	local inputMap = chart.inputMode:getInputs()

	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual_gameplay = Visual()
	visual_gameplay.primaryTempo = 120
	layer.visuals["gameplay"] = visual_gameplay

	local visual_bga = Visual()
	visual_bga.bga = true
	visual_bga.primaryTempo = 120
	layer.visuals["bga"] = visual_bga

	-- Gameplay notes (should be ignored by BgaEngine)
	local p1 = layer:getPoint(1)
	local vp1 = visual_gameplay:getPoint(p1)
	chart.notes:insert(Note(vp1, inputMap[1], "tap", 0))

	-- BGA notes
	local p0 = layer:getPoint(0)
	local p2 = layer:getPoint(2)
	local vb0 = visual_bga:getPoint(p0)
	local vb2 = visual_bga:getPoint(p2)

	chart.notes:insert(Note(vb0, 100, "sprite", 0))
	chart.notes:insert(Note(vb2, 100, "sprite", 0))

	chart:compute()
	bga_engine:load(chart, {})

	-- Test
	visual_info.time = -1
	bga_engine:update()
	-- Sprite 1 (at 0) should be active even before its time
	t:eq(#bga_engine.active_notes, 1)
	t:eq(bga_engine.active_notes[1].time, 0)

	visual_info.time = 1
	bga_engine:update()
	-- Sprite 1 still active
	t:eq(#bga_engine.active_notes, 1)

	visual_info.time = 2.5
	bga_engine:update()
	-- Sprite 2 (at 2) is active.
	t:eq(#bga_engine.active_notes, 1)
	t:eq(bga_engine.active_notes[1].time, 2)

	visual_info.time = 10
	bga_engine:update()
	-- Sprite 2 still active
	t:eq(#bga_engine.active_notes, 1)
	t:eq(bga_engine.active_notes[1].time, 2)
end

---@param t testing.T
function test.bga_multiple_columns(t)
	local visual_info = VisualInfo()
	local bga_engine = BgaEngine(visual_info)

	local chart = Chart()
	local layer = AbsoluteLayer()
	chart.layers.main = layer

	local visual_bga1 = Visual()
	visual_bga1.bga = true
	layer.visuals["bga1"] = visual_bga1

	local visual_bga2 = Visual()
	visual_bga2.bga = true
	layer.visuals["bga2"] = visual_bga2

	-- BGA 1 notes
	local p0 = layer:getPoint(0)
	local vb0_1 = visual_bga1:getPoint(p0)
	chart.notes:insert(Note(vb0_1, 100, "sprite", 0))

	-- BGA 2 notes
	local vb0_2 = visual_bga2:getPoint(p0)
	chart.notes:insert(Note(vb0_2, 101, "sprite", 0))

	chart:compute()
	bga_engine:load(chart, {})

	-- Both should be active
	visual_info.time = 0
	bga_engine:update()
	t:eq(#bga_engine.active_notes, 2)
end

return test
