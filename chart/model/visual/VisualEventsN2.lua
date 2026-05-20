local class = require("class")

---@class chart.VisualEventsN2
---@operator call: chart.VisualEventsN2
local VisualEventsN2 = class()

---@param vps chart.VisualPoint[]
---@param j number
---@param i number
---@param dt number
---@return number|false?
local function intersect(vps, j, i, dt)
	local vp = vps[j]
	local _vp = vps[i]
	local next_vp = vps[i + 1]

	local next_visualTime = next_vp and next_vp.visualTime or _vp.visualTime + 1 * _vp.currentSpeed
	local next_absoluteTime = next_vp and next_vp.point.absoluteTime or _vp.point.absoluteTime + 1

	local dvt = next_visualTime - _vp.visualTime
	local dat = next_absoluteTime - _vp.point.absoluteTime

	if dvt == 0 and dat == 0 then
		dvt, dat = 1, 1
	end

	local targetVisualTime = vp.visualTime - dt / vp.localSpeed

	local k = (targetVisualTime - _vp.visualTime) / dvt
	local gte = k >= 0
	local lt = k < 1

	local targetTime = k * dat + _vp.point.absoluteTime

	if targetTime == -math.huge and i == 1 or targetTime == math.huge and i == #vps then
		return math.abs(vp.visualTime - vps[i].visualTime) <= math.abs(dt / vp.localSpeed) and targetTime
	end

	if #vps == 1 then
		return targetTime
	end

	if i == #vps then
		return gte and targetTime
	elseif i == 1 then
		return lt and targetTime
	end

	return gte and lt and targetTime
end

---@param vps chart.VisualPoint[]
---@param range {[1]: number, [2]: number}
---@return chart.VisualEvent[]
function VisualEventsN2:generate(vps, range)
	---@type ncdk2.VisualEvent[]
	local events = {}

	for j = 1, #vps do
		local vp = vps[j]
		for i = 1, #vps do
			local _vp = vps[i]  -- current time is from i to i+1
			local rightTime = intersect(vps, j, i, range[2])
			local leftTime = intersect(vps, j, i, range[1])
			local speed = vp.localSpeed * _vp.currentSpeed

			if rightTime then
				table.insert(events, {
					time = rightTime,
					action = speed >= 0 and 1 or -1,
					point = vp,
				})
			end
			if leftTime then
				table.insert(events, {
					time = leftTime,
					action = speed >= 0 and -1 or 1,
					point = vp,
				})
			end
		end
	end

	table.sort(events, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		elseif a.point.point.absoluteTime ~= b.point.point.absoluteTime then
			return a.point.point.absoluteTime < b.point.point.absoluteTime
		end
		return a.point.visualTime < b.point.visualTime
	end)

	return events
end

return VisualEventsN2
