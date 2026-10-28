local class = require("class")

---@alias sea.HealthsName
---| "unknown"
---| "simple"
---| "etterna"
---| "lr2"
---| "bmstotal"
---| "iidx"

---@class sea.Healths
---@operator call: sea.Healths
---@field name sea.HealthsName
---@field data number
local Healths = class()

---@param name sea.HealthsName
---@param data any?
function Healths:new(name, data)
	self.name = name
	self.data = data
	local v = self:encode()
	assert(v == math.floor(v), "invalid")
	assert(self:validate(), "invalid")
end

---@return boolean
function Healths:validate()
	local v = self.data
	local n = self.name

	if n == "simple" then
		return v >= 0 and v <= 100 and v == math.floor(v)
	elseif n == "etterna" then
		return v >= 1 and v <= 7 and v == math.floor(v) -- LifeDifficulty level
	elseif n == "lr2" then
		return v >= 0 and v <= 3 and v == math.floor(v) -- gauge
	elseif n == "bmstotal" then
		return v >= 0 and v <= 90000 and v == math.floor(v) -- #TOTAL of the chart
	elseif n == "iidx" then
		return v >= 0 and v <= 4 and v == math.floor(v) -- gauge
	end

	return false
end

---@param v integer
---@return sea.Healths
function Healths.decode(v)
	assert(v, "missing healths value")

	if v >= 0 and v <= 100 then
		return Healths("simple", v)
	elseif v >= 201 and v <= 207 then
		return Healths("etterna", v - 200)
	elseif v >= 300 and v <= 303 then
		return Healths("lr2", v - 300)
	elseif v >= 400 and v <= 404 then
		return Healths("iidx", v - 400)
	elseif v >= 10000 and v <= 100000 then
		return Healths("bmstotal", v - 10000)
	end

	return Healths("unknown", v)
end

---@param t sea.Healths
---@return integer
function Healths.encode(t)
	local v = t.data

	if t.name == "simple" then
		return v
	elseif t.name == "etterna" then
		return 200 + v
	elseif t.name == "lr2" then
		return 300 + v
	elseif t.name == "iidx" then
		return 400 + v
	elseif t.name == "bmstotal" then
		return 10000 + v
	end

	return v
end

---@param t sea.Timings
function Healths:__eq(t)
	return self.name == t.name and self.data == t.data
end

function Healths:__tostring(t)
	return ("Healths(%s, %s)"):format(self.name, self.data)
end

return Healths
