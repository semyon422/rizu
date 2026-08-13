local InputMode = require("chart.core.InputMode")
local GameplayInteractor = require("rizu.gameplay.GameplayInteractor")

local test = {}

---@param t testing.T
function test.uses_computed_chart_input_mode(t)
	local chart = {inputMode = InputMode("10key")}
	t:eq(GameplayInteractor.getInputMode(chart), "10key")
end

return test
