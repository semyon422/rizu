local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Tempo = require("chart.model.to.Tempo")
local TempoRange = require("chart.format.notechart.TempoRange")

local test = {}

---@param t testing.T
function test.constant_tempo_range(t)
	local layer = AbsoluteLayer()
	layer:getPoint(0)._tempo = Tempo(182)
	layer:getPoint(10)
	layer:compute()

	local chart = {
		layers = {
			main = layer,
		},
	}

	local average, minimum, maximum = TempoRange:find(chart, 0, 10)

	t:eq(average, 182)
	t:eq(minimum, 182)
	t:eq(maximum, 182)
end

---@param t testing.T
function test.empty_tempo_range_fallback(t)
	local layer = AbsoluteLayer()
	layer:getPoint(0)
	layer:compute()

	local chart = {
		layers = {
			main = layer,
		},
	}

	local average, minimum, maximum = TempoRange:find(chart, 0, 10)

	t:eq(average, 1)
	t:eq(minimum, 1)
	t:eq(maximum, 1)
end

return test
