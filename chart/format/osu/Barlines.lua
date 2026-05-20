local class = require("class")

---@class chart.osu.Barlines
---@operator call: chart.osu.Barlines
local Barlines = class()

-- NOTICE: beatLength in ms!

---@param tempo_points chart.osu.FilteredPoint[]
---@param lastTime number
---@return number[]
function Barlines:generate(tempo_points, lastTime)
	if #tempo_points == 0 then
		return {}
	end
	local start = tempo_points[1].offset
	if start > 0 then
		local measure_length = tempo_points[1].beatLength * tempo_points[1].signature
		start = start - math.floor(start / measure_length) * measure_length
	end

	---@type number[]
	local barlines = {}
	for i = 1, #tempo_points do
		local p = tempo_points[i]
		local beatTime = p.offset
		if i == 1 then
			beatTime = start
		end

		local timeEnd = lastTime + 1
		if i < #tempo_points then
			timeEnd = tempo_points[i + 1].offset - 1
		end

		local measure_length = p.beatLength * p.signature
		if p.omitFirstBarLine then
			beatTime = beatTime + measure_length
		end

		while beatTime < timeEnd do
			table.insert(barlines, beatTime)
			beatTime = beatTime + measure_length

			if
				measure_length < 0.1 or
				(timeEnd - beatTime) / measure_length > 10000
			then  -- optimization
				break
			end
		end
	end
	return barlines
end

return Barlines
