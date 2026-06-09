local BmsToolsContext = require("rizu.editor.BmsToolsContext")
local Layer = require("chart.chartedit.Layer")

local test = {}

---@param t testing.T
function test.reset_offset_tempo(t)
	local layer = Layer()
	layer.points:initDefault()

	local context = BmsToolsContext()
	context.offset = 2
	context.tempo = 120

	context:resetOffsetTempo(layer)

	local firstPoint = layer.points:getFirstPoint()
	local lastPoint = layer.points:getLastPoint()

	t:eq(firstPoint.vertex.offset, 2)
	t:eq(lastPoint.vertex.offset, 2.5)
end

---@param t testing.T
function test.init_from_layer(t)
	local layer = Layer()
	layer.points:initDefault()

	local context = BmsToolsContext()
	context:initFromLayer(layer)

	t:eq(context.offset, 0)
	t:eq(context.tempo, 60)
	t:eq(context.beat_offset, 0)
end

return test
