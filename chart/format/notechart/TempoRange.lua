local TempoRange = {}

---@param chart chart.Chart
function TempoRange:find(chart, minTime, maxTime)
	local lastTime = minTime

	---@type {[number]: number}
	local durations = {}

	---@type chart.AbsolutePoint[]
	local tempoPoints = {}
	local pointList = chart.layers.main:getPointList()
	for _, point in ipairs(pointList) do
		---@type chart.Tempo
		local tempo = point._tempo
		if tempo then
			table.insert(tempoPoints, point)
		end
	end
	for i = 1, #tempoPoints do
		local tempo = assert(tempoPoints[i]._tempo)
		local nextPoint = tempoPoints[i + 1]
		local nextTempo = nextPoint and nextPoint._tempo

		local startTime = lastTime
		local endTime = maxTime
		if nextTempo then
			endTime = math.min(maxTime, nextPoint.absoluteTime)
		end
		lastTime = endTime

		local _tempo = tempo.tempo
		durations[_tempo] = (durations[_tempo] or 0) + endTime - startTime
	end

	local longestDuration = 0
	local average, minimum, maximum

	for tempo, duration in pairs(durations) do
		if duration > longestDuration then
			longestDuration = duration
			average = tempo
		end
		if not minimum or tempo < minimum then
			minimum = tempo
		end
		if not maximum or tempo > maximum then
			maximum = tempo
		end
	end

	return average or 1, minimum or 1, maximum or 1
end

return TempoRange
