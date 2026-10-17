local class = require("class")

---@class chart.DurationAverage
---@operator call: chart.DurationAverage
local DurationAverage = class()

---@param period number
function DurationAverage:new(period)
	self.period = period
	self.points = {}
	self.avg = 0
end

---@param v number
---@param dt number
---@return number
function DurationAverage:add(v, dt)
	local period = self.period

	if period == 0 then
		self.avg = v
		return self.avg
	end

	local points = self.points
	table.insert(points, 1, {v, dt})

	local t = 0
	local v_sum = 0

	local j = #points + 1
	for i = 1, #points do
		local p = points[i]
		t = t + p[2]
		v_sum = v_sum + p[1] * math.min(p[2], p[2] - (t - period))
		if t >= self.period then
			j = i + 1
			break
		end
	end
	for k = j, #points do
		points[k] = nil
	end

	self.avg = v_sum / period
	return self.avg
end

local wa = DurationAverage(1)

wa:add(1, 0.5)
assert(wa.avg == 0.5)

wa:add(0.5, 0.25)
assert(wa.avg == 0.625)

wa:add(0.75, 0.5)
assert(wa.avg == (0.75 * 0.5 + 0.5 * 0.25 + 1 * 0.25))

wa:add(1, 1)
assert(wa.avg == 1)

return DurationAverage
