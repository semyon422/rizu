local Interpolator = require("chart.model.Interpolator")
local class = require("class")

local test = {}

local Obj = class()

function Obj:new(time)
	self.time = time
end

function Obj:compare(obj)
	return self.time < obj.time
end

function test.basic(t)
	local itp = Interpolator()

	local objs = {
		Obj(1),
		Obj(2), -- <- this should be selected for Obj(2)
		Obj(2),
		Obj(2),
		Obj(3),
	}

	---@type table
	local obj = Obj(2)
	t:eq(itp:getBaseIndex(objs, obj), 2)
end

return test
