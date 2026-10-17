local class = require("class")

---@alias sea.TimingsName
---| "unknown"
---| "arbitrary"
---| "sphere"
---| "simple"
---| "osuod"
---| "etternaj"
---| "quaver"
---| "bmsrank"
---| "iidx"

---@class sea.Timings
---@operator call: sea.Timings
---@field name sea.TimingsName
---@field data number
local Timings = class()

Timings.names = {
	"arbitrary",
	"sphere",
	"simple",
	"osuod",
	"etternaj",
	"quaver",
	"bmsrank",
	"iidx",
}

---@param name sea.TimingsName
---@param data number?
function Timings:new(name, data)
	self.name = name
	self.data = data or 0
	local v = self:encode()
	assert(v == math.floor(v), "invalid")
	assert(self:validate(), "invalid")
end

---@return boolean
function Timings:validate()
	local v = self.data
	local n = self.name

	if n == "arbitrary" then
		return v == 0
	elseif n == "sphere" then
		return v == 0
	elseif n == "simple" then
		v = v * 1000
		return v >= 0 and v <= 1000 and v == math.floor(v)
	elseif n == "osuod" then
		v = v * 10
		return v == math.floor(v)
	elseif n == "etternaj" then
		return v >= 1 and v <= 9
	elseif n == "quaver" then
		return v == 0
	elseif n == "bmsrank" then
		return v >= 0 and v <= 4 and v == math.floor(v)
	elseif n == "iidx" then
		return v == 0
	elseif n == "unknown" then
		return v == math.floor(v)
	end

	return false
end

---@param v integer
---@return sea.Timings
function Timings.decode(v)
	assert(v, "missing timings value")

	if v == 0 then
		return Timings("arbitrary")
	elseif v == 100 then
		return Timings("sphere")
	elseif v >= 1000 and v <= 2000 then
		return Timings("simple", (v - 1000) / 1000)
	elseif v >= 2100 and v <= 2200 then
		return Timings("osuod", (v - 2100) / 10) -- OverallDifficulty
	elseif v >= 2301 and v <= 2309 then
		return Timings("etternaj", v - 2300)
	elseif v == 2400 then
		return Timings("quaver")
	elseif v >= 2500 and v <= 2504 then
		return Timings("bmsrank", v - 2500) -- #RANK
	elseif v == 2600 then
		return Timings("iidx")
	end

	return Timings("unknown", v)
end

---@param t sea.Timings
---@return integer
function Timings.encode(t)
	local v = t.data
	local n = t.name

	if n == "arbitrary" then
		return 0
	elseif n == "sphere" then
		return 100
	elseif n == "simple" then
		return 1000 + v * 1000
	elseif n == "osuod" then
		return 2100 + v * 10
	elseif n == "etternaj" then
		return 2300 + v
	elseif n == "quaver" then
		return 2400
	elseif n == "bmsrank" then
		return 2500 + v
	elseif n == "iidx" then
		return 2600
	end

	return v
end

---@param t sea.Timings
function Timings:__eq(t)
	return self.name == t.name and self.data == t.data
end

function Timings:__tostring(t)
	return ("Timings(%s, %s)"):format(self.name, self.data)
end

return Timings
