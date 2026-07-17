local NeedleGpuEncoderProbe = require("rizu.ai.NeedleGpuEncoderProbe")

local test = {}

---@param t testing.T
function test.reports_missing_glsl4(t)
	local probe = NeedleGpuEncoderProbe({
		getSupported = function() return {glsl4 = false} end,
	}, {}, function() return 0 end)
	t:eq(probe:start("unused"), false)
	t:eq(probe.state, "unsupported")
end

return test
