local LoadError = require("ui.screens.chart_loading.LoadError")
local test = {}

---@param t testing.T
function test.aim_diagnostic_hides_source_prefix(t)
	local view = setmetatable({}, {__index = LoadError})
	view:setMessage("loader.lua:20: rules.lua:3: Aim prototype supports circles only; this chart contains slider objects.\ntrace")
	t:eq(view.message, "Aim prototype supports circles only; this chart contains slider objects.")
end

return test
