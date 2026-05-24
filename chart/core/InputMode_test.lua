local InputMode = require("chart.core.InputMode")

local test = {}

function test.basic(t)
	t:eq(InputMode(), InputMode())
	t:eq(InputMode("4key"), InputMode({key = 4}))
	t:eq(InputMode("7key1scratch"), InputMode({key = 7, scratch = 1}))
	t:eq(tostring(InputMode("7key1scratch")), "7key1scratch")
end

return test
