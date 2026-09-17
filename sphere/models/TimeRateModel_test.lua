local TimeRateModel = require("sphere.models.TimeRateModel")

local test = {}

local function newModel()
	return TimeRateModel({rate = 1, rate_type = "linear"})
end

---@param t testing.T
function test.notifies_rate_changes(t)
	local model = newModel()
	local events = {}
	local observer = model:onChanged(function(event)
		table.insert(events, event)
	end)

	model:set(1.25)
	t:eq(#events, 1)
	t:eq(events[1].type, "time_rate_changed")
	t:eq(events[1].rate, 1.25)
	t:eq(events[1].rate_type, "linear")

	model:set(1.25)
	t:eq(#events, 1)

	model:offChanged(observer)
	model:set(1.5)
	t:eq(#events, 1)
end

---@param t testing.T
function test.notifies_rate_type_changes(t)
	local model = newModel()
	local events = {}
	model:onChanged(function(event)
		table.insert(events, event)
	end)

	model:set(1.25)
	model:setType("exp")
	t:eq(#events, 2)
	t:eq(events[2].rate, 1.25)
	t:eq(events[2].rate_type, "exp")

	model:setType("exp")
	t:eq(#events, 2)
end

return test
