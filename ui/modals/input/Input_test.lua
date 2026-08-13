local Input = require("ui.modals.input.Input")

local test = {}

---@param t testing.T
function test.prefers_chartdiff_input_mode(t)
	t:eq(Input.getInputMode({
		inputmode = "4key",
		chartdiff_inputmode = "10key",
	}), "10key")
end

---@param t testing.T
function test.falls_back_to_chartmeta_input_mode(t)
	t:eq(Input.getInputMode({inputmode = "4key"}), "4key")
	t:eq(Input.getInputMode(nil), nil)
end

return test
