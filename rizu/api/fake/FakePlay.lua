local Events = require("rizu.api.Events")

---`rizu.api.Play` that remembers what was set and starts nothing.
---@class rizu.api.fake.FakePlay : rizu.api.Events
---@operator call: rizu.api.fake.FakePlay
local FakePlay = Events + {}

local ranges = {linear = {0.25, 4, 0.05}, exp = {-20, 20, 1}}

function FakePlay:new()
	Events.new(self)
	self.rate = 1
	self.rate_type = "linear"
	self.toggles = {constant_scroll = false, taps_only = false, nearest_input = false, auto_timings = true}
	self.timing_system = "sphere"
	self.timing_values = {osuod = 8, etternaj = 4, bmsrank = 3}
	self.osu_score_version = 1
end

function FakePlay:getRate() return self.rate end
function FakePlay:getRateType() return self.rate_type end
function FakePlay:getRateTypes() return {"linear", "exp"} end

function FakePlay:getRateValue()
	local value = self.rate
	if self.rate_type == "exp" then
		value = math.floor(math.log(self.rate) / math.log(2) * 10 + 0.5)
	end
	return value, unpack(ranges[self.rate_type])
end

function FakePlay:getRateText()
	local value = self:getRateValue()
	if self.rate_type == "exp" then
		return value > 0 and ("+%.0f"):format(value) or ("%.0f"):format(value)
	end
	return ("%.2fx"):format(value)
end

function FakePlay:setRateValue(value)
	local range = ranges[self.rate_type]
	value = math.max(range[1], math.min(value, range[2]))
	self.rate = self.rate_type == "exp" and 2 ^ (value / 10) or value
	self:emit("rate_changed")
end

function FakePlay:changeRate(steps)
	local value, _, _, step = self:getRateValue()
	self:setRateValue(value + steps * step)
end

function FakePlay:setRateType(rate_type)
	self.rate_type = rate_type
	self:emit("rate_changed")
end

function FakePlay:getToggle(toggle) return self.toggles[toggle] end

function FakePlay:setToggle(toggle, on)
	self.toggles[toggle] = on
	self:emit("mods_changed")
end

function FakePlay:getModCount()
	return (self.toggles.constant_scroll and 1 or 0) + (self.toggles.taps_only and 1 or 0)
end

function FakePlay:getMutatorCount() return 0 end

function FakePlay:getTimingSystems() return {"sphere", "osuod", "etternaj", "quaver", "bmsrank", "iidx"} end
function FakePlay:getTimingSystem() return self.timing_system end

function FakePlay:setTimingSystem(system)
	self.timing_system = system
	self:emit("mods_changed")
end

function FakePlay:getTimingValue() return self.timing_values[self.timing_system] or 0 end

function FakePlay:setTimingValue(value)
	self.timing_values[self.timing_system] = value
	self:emit("mods_changed")
end

function FakePlay:getOsuScoreVersion() return self.osu_score_version end

function FakePlay:setOsuScoreVersion(version)
	self.osu_score_version = version
	self:emit("mods_changed")
end

function FakePlay:prepare(autoplay) end

return FakePlay
