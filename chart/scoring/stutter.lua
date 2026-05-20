local stutter = {}

-- average * deltaTime = deltaTime * ratio * firstMultiplier + deltaTime * (1 - ratio) * secondMultiplier
-- ratio = (average - secondMultiplier) / (firstMultiplier - secondMultiplier)
-- z = (1 - y) / (x - y)

---@param ratio number
function stutter.checkRatio(ratio)
	if ratio <= 0 or ratio >= 1 then
		error("wrong ratio " .. ratio)
	end
end

---@param startTime number
---@param endTime number
---@param average number
---@param firstMultiplier number
---@param secondMultiplier number
---@param ratio number
---@return table
function stutter.fsr(startTime, endTime, average, firstMultiplier, secondMultiplier, ratio)
	stutter.checkRatio(ratio)
	local deltaTime = endTime - startTime
	return {
		{
			time = startTime,
			values = {
				firstMultiplier,
			},
		},
		{
			time = startTime + ratio * deltaTime,
			values = {
				secondMultiplier,
			},
		},
		{
			time = endTime,
			values = {
				1,
			},
		},
	}
end

---@param startTime number
---@param endTime number
---@param firstMultiplier number
---@return table
function stutter.eq(startTime, endTime, firstMultiplier)
	return {
		{
			time = startTime,
			values = {
				firstMultiplier,
			},
		},
		{
			time = endTime,
			values = {
				1,
			},
		},
	}
end

---@param startTime number
---@param endTime number
---@param average number
---@param firstMultiplier number
---@param secondMultiplier number
---@return table
function stutter.fs(startTime, endTime, average, firstMultiplier, secondMultiplier)
	local ratio = (average - secondMultiplier) / (firstMultiplier - secondMultiplier)
	if firstMultiplier - secondMultiplier == 0 then
		ratio = 1 / 2
	end
	return stutter.fsr(startTime, endTime, average, firstMultiplier, secondMultiplier, ratio)
end

---@param startTime number
---@param endTime number
---@param average number
---@param firstMultiplier number
---@param ratio number
---@return table
function stutter.fr(startTime, endTime, average, firstMultiplier, ratio)
	local firstMultiplier = firstMultiplier * average
	local secondMultiplier = (average - ratio * firstMultiplier) / (1 - ratio)
	return stutter.fsr(startTime, endTime, average, firstMultiplier, secondMultiplier, ratio)
end

---@param startTime number
---@param endTime number
---@param average number
---@param secondMultiplier number
---@param ratio number
---@return table
function stutter.sr(startTime, endTime, average, secondMultiplier, ratio)
	local secondMultiplier = secondMultiplier * average
	local firstMultiplier = (average - (1 - ratio) * secondMultiplier) / ratio
	return stutter.fsr(startTime, endTime, average, firstMultiplier, secondMultiplier, ratio)
end

---@param sequence table
---@return number
function stutter.average(sequence)
	local startTime = sequence[1].time
	local endTime = sequence[#sequence].time
	local deltaTime = endTime - startTime
	local visualDeltaTime = 0

	for i = 1, #sequence - 1 do
		visualDeltaTime = visualDeltaTime + (sequence[i + 1].time - sequence[i].time) * sequence[i].values[1]
	end

	return visualDeltaTime / deltaTime
end

---@param sequence table
---@param average number
function stutter.normalize(sequence, average)
	local multiplier = stutter.average(sequence)
	for i = 1, #sequence do
		sequence[i].values[1] = sequence[i].values[1] / multiplier * average
	end
end

return stutter
