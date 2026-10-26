local class = require("class")

---@alias sea.HealthsName
---| "unknown"
---| "simple"
---| "etterna"

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
