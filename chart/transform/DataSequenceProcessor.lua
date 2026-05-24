local class = require("class")

---@class chart.DataSequenceProcessor
---@operator call: chart.DataSequenceProcessor
local DataSequenceProcessor = class()

---@param dataSequences table
---@return table
function DataSequenceProcessor:process(dataSequences)
	local timeData = {}

	for _, dataSequence in pairs(dataSequences) do
		for _, data in ipairs(dataSequence) do
			timeData[data.time] = true
		end
	end

	local outDataSequence = {}
	for time in pairs(timeData) do
		local datas = {}

		for _, dataSequence in pairs(dataSequences) do
			for _, data in ipairs(dataSequence) do
				if data.time <= time then
					datas[dataSequence] = datas[dataSequence] or data
					if datas[dataSequence].time < data.time then
						datas[dataSequence] = data
					end
				end
			end
		end

		local outData = {
			time = time,
			values = {},
		}

		for _, data in pairs(datas) do
			for valueIndex, value in pairs(data.values) do
				outData.values[valueIndex] = (outData.values[valueIndex] or 1) * value
			end
		end

		table.insert(outDataSequence, outData)
	end

	table.sort(outDataSequence, function(a, b)
		return a.time < b.time
	end)

	return outDataSequence
end

return DataSequenceProcessor
