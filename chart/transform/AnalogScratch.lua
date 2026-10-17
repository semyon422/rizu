local class = require("class")
local DurationAverage = require("chart.transform.DurationAverage")

---@class chart.AnalogScratch
---@operator call: chart.AnalogScratch
local AnalogScratch = class()

AnalogScratch.active = false
AnalogScratch.scratch_right = false

---@param act_period number
---@param deact_period number
---@param act_w number
---@param deact_w number
function AnalogScratch:new(act_period, deact_period, act_w, deact_w)
	self.act_w = act_w
	self.deact_w = deact_w
	self.act_da = DurationAverage(act_period)
	self.deact_da = DurationAverage(deact_period)
end

local function analog_diff(old, new)
	local d = new - old
	if d > 1 then
		d = d - 2
	elseif d < -1 then
		d = d + 2
	end
	return d
end

---@param pos number
---@param dt number
function AnalogScratch:update(pos, dt)
	local diff = analog_diff(self.old_pos or pos, pos)
	self.old_pos = pos

	local act_w = self.act_da:add(diff / dt, dt)
	local deact_w = self.deact_da:add(diff / dt, dt)

	if math.abs(deact_w) < self.deact_w then
		self.active = false
	elseif math.abs(act_w) >= self.act_w then
		self.active = true
	end

	if self.active then
		self.scratch_right = act_w > 0
	end
end

return AnalogScratch
