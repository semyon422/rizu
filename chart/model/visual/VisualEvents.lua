local class = require("class")

---@class chart.VisualEvent
---@field time number
---@field action -1|1
---@field point chart.VisualPoint

---@class chart.VisualEvents
---@operator call: chart.VisualEvents
local VisualEvents = class()

---@param vps chart.VisualPoint[]
---@param range {[1]: number, [2]: number}
---@return chart.VisualEvent[]
function VisualEvents:generate(vps, range)
	local visual_events = self:generateVisual(vps, range)
	local events = self:toAbsolute(vps, visual_events)
	self.events = events
	return events
end

---@param vps chart.VisualPoint[]
---@param range {[1]: number, [2]: number}
---@return chart.VisualEvent[]
function VisualEvents:generateVisual(vps, range)
	---@type ncdk2.VisualEvent[]
	local events = {}

	for j = 1, #vps do
		local vp = vps[j]
		table.insert(events, {
			time = vp.visualTime - range[2] / vp.localSpeed,
			action = 1,
			point = vp,
		})
		table.insert(events, {
			time = vp.visualTime - range[1] / vp.localSpeed,
			action = -1,
			point = vp,
		})
	end

	table.sort(events, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.point.point < b.point.point
	end)

	return events
end

---@param vps chart.VisualPoint[]
---@return chart.VisualEvent[]
function VisualEvents:toAbsolute(vps, events)
	local _offset = vps[1].currentSpeed >= 0 and 0 or #events

	---@type ncdk2.VisualEvent[]
	local abs_events = {}

	local first_vp = vps[1]
	if first_vp.currentSpeed == 0 then
		_offset = 0
		local startTime = first_vp.visualTime
		---@type {[ncdk2.VisualPoint]: true}
		local visiblePoints = {}
		local offset, vp, show = self:next(events, _offset, startTime)
		while offset do
			_offset = offset
			visiblePoints[vp] = show
			offset, vp, show = self:next(events, offset, startTime)
		end

		for vp in pairs(visiblePoints) do
			table.insert(abs_events, {
				time = -math.huge,
				action = 1,
				point = vp,
			})
		end
	end

	---@type {[ncdk2.VisualPoint]: true}
	local visiblePoints = {}

	for i = 1, #vps do
		local _vp = vps[i]
		local next_vp = vps[i + 1]

		local next_visualTime = next_vp and next_vp.visualTime or _vp.visualTime + 1 * _vp.currentSpeed
		local next_absoluteTime = next_vp and next_vp.point.absoluteTime or _vp.point.absoluteTime + 1

		local dvt = next_visualTime - _vp.visualTime
		local dat = next_absoluteTime - _vp.point.absoluteTime

		if dvt == 0 and dat == 0 then
			dvt, dat = 1, 1
		end

		local sctollTo = next_vp and next_visualTime or vps[#vps].currentSpeed / 0
		if not next_vp and vps[#vps].currentSpeed == 0 then
			break
		end

		local offset, vp, show, event = self:next(events, _offset, sctollTo)
		while offset do
			_offset = offset
			visiblePoints[vp] = show
			table.insert(abs_events, {
				time = (event.time - _vp.visualTime) * dat / dvt + _vp.point.absoluteTime,
				action = show and 1 or -1,
				point = vp,
			})
			offset, vp, show, event = self:next(events, offset, sctollTo)
		end
	end

	local last_vp = vps[#vps]
	if last_vp.currentSpeed == 0 then
		for vp in pairs(visiblePoints) do
			table.insert(abs_events, {
				time = math.huge,
				action = -1,
				point = vp,
			})
		end
	end

	table.sort(abs_events, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		elseif a.point.point.absoluteTime ~= b.point.point.absoluteTime then
			return a.point.point.absoluteTime < b.point.point.absoluteTime
		end
		return a.point.visualTime < b.point.visualTime
	end)

	return abs_events
end

-- nil instead of false to clear values in tables
---@param action number
---@return true?
local function get_action_value(action)
	if action > 0 then
		return true
	end
end

---@param events chart.VisualEvent[]
---@param index number
---@param time number
---@return number?
---@return chart.VisualPoint?
---@return true?
---@return chart.VisualEvent?
function VisualEvents:next(events, index, time)
	local event = events[index]
	local next_event = events[index + 1]

	if event and next_event and time >= event.time and time < next_event.time then
		return
	elseif next_event and time >= next_event.time then
		return index + 1, next_event.point, get_action_value(1 * next_event.action * next_event.point.localSpeed), next_event
	elseif event and time < event.time then
		return index - 1, event.point, get_action_value(-1 * event.action * event.point.localSpeed), event
	end
end

return VisualEvents
