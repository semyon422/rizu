local class = require("class")

---@class chart.osu.PrimaryTempo
---@operator call: chart.osu.PrimaryTempo
local PrimaryTempo = class()

---@param tempo_points chart.osu.FilteredPoint[]
---@param lastTime number ms
---@return number primary primary tempo
---@return number min min tempo
---@return number max max tempo
function PrimaryTempo:compute(tempo_points, lastTime)
	local current_bl = 0

	---@type {[number]: number}
	local durations = {}

	local min_bl = math.huge
	local max_bl = -math.huge

	for i = #tempo_points, 1, -1 do
		local p = tempo_points[i]

		local beatLength = p.beatLength
		current_bl = beatLength
		min_bl = math.min(min_bl, current_bl)
		max_bl = math.max(max_bl, current_bl)

		if p.offset < lastTime then
			durations[current_bl] = (durations[current_bl] or 0) + (lastTime - (i == 1 and 0 or p.offset))
			lastTime = p.offset
		end
	end

	local longestDuration = 0
	local average = 0

	for beatLength, duration in pairs(durations) do
		if duration > longestDuration then
			longestDuration = duration
			average = beatLength
		end
	end

	if longestDuration == 0 then
		return 0, 0, 0
	end

	return 60000 / average, 60000 / min_bl, 60000 / max_bl
end

return PrimaryTempo
