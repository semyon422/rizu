---HP helpers shared by osu!mania V1 (stable) and V2 (lazer).
local osu_hp = {}

---osu!'s DifficultyRange
---@param d number
---@param min number
---@param mid number
---@param max number
---@return number
function osu_hp.range(d, min, mid, max)
	if d > 5 then
		return mid + (max - mid) * (d - 5) / 5
	elseif d < 5 then
		return mid - (mid - min) * (5 - d) / 5
	end
	return mid
end

---The chart's HPDrainRate, 5 when it has none.
---@param healths sea.Healths?
---@return number
function osu_hp.getDrainRate(healths)
	return healths and healths.name == "simple" and healths.data / 10 or 5
end

---Taps and holds of the chart, sorted by start. Empty without a chart.
---@param chart chart.Chart?
---@return {[1]: number, [2]: number, [3]: boolean}[] objects Start and end in milliseconds, is long.
function osu_hp.getObjects(chart)
	---@type {[1]: number, [2]: number, [3]: boolean}[]
	local objects = {}
	if not chart then
		return objects
	end
	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		local t = note:getType()
		if t == "tap" or t == "hold" then
			table.insert(objects, {note:getStartTime() * 1000, note:getEndTime() * 1000, note:isLong()})
		end
	end
	table.sort(objects, function(a, b) return a[1] < b[1] end)
	return objects
end

return osu_hp
