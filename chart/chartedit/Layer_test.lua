local Layer = require("chart.chartedit.Layer")

local test = {}

function test.iter(t)
	local layer = Layer()
	layer.points:initDefault()

	local count = 0
	for p, vp, notes in layer:iter(-1, 2) do
		count = count + 1
	end
	t:eq(count, 2)
end

return test
