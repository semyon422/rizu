local NeedleGpuProbe = require("rizu.ai.NeedleGpuProbe")

local test = {}

---@param t testing.T
function test.reports_missing_glsl4(t)
	local graphics = {
		getSupported = function() return {glsl4 = false} end,
		getSystemLimits = function() return {shaderstoragebuffersize = 0} end,
		getRendererInfo = function() return "unknown" end,
	}
	local probe = NeedleGpuProbe(graphics, {}, function() return 0 end)
	t:eq(probe:start(), false)
	t:eq(probe.state, "unsupported")
end

---@param t testing.T
function test.reads_async_q8_result(t)
	local complete = false
	local sent = {}
	local readback = {
		isComplete = function() return complete end,
		hasError = function() return false end,
		getBufferData = function()
			return {getFloat = function() return 512 end}
		end,
	}
	local graphics = {
		getSupported = function() return {glsl4 = true} end,
		getSystemLimits = function() return {shaderstoragebuffersize = 1024 * 1024} end,
		getRendererInfo = function() return "test", "gpu", "driver" end,
		newComputeShader = function()
			return {send = function(_, name) sent[name] = true end}
		end,
		newBuffer = function() return {} end,
		dispatchThreadgroups = function(_, groups) sent.groups = groups end,
		readbackBufferAsync = function() return readback end,
	}
	local data = {newByteData = function(value) return value end}
	local now = 0
	local probe = NeedleGpuProbe(graphics, data, function() return now end)
	t:eq(probe:start(), true)
	t:eq(probe.state, "waiting")
	t:eq(sent.groups, 3688)
	t:eq(sent.ProbeInput, true)
	t:eq(sent.ProbeWeights, true)
	t:eq(sent.ProbeOutput, true)
	t:eq(sent.ProbeScales, true)
	t:eq(sent.batch_rows, true)
	probe:update()
	t:eq(probe.state, "waiting")
	complete = true
	now = 0.02
	probe:update()
	t:eq(probe.state, "waiting")
	probe:update()
	t:eq(probe.state, "waiting")
	probe:update()
	t:eq(probe.state, "ready")
end

return test
