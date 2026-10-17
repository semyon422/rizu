local class = require("class")
local string_util = require("string_util")

---@class chart.osu.TimingDataImporter
---@operator call: chart.osu.TimingDataImporter
local TinyParser = class()

---@param noteChartString string
function TinyParser:import(noteChartString)
	self.notes = {}
	local block
	for _, line in string_util.isplit(noteChartString, "\n") do
		if line:find("^%[") then
			block = line:match("^%[(.+)%]")
		else
			if line:find("^%a+:.*$") then
				local key, value = line:match("^(%a+):%s?(.*)")
				if key == "CircleSize" then
					self.columnCount = tonumber(value)
				end
			elseif block == "HitObjects" and line ~= "" then
				local note = {}
				local data = string_util.split(line, ",")
				note.column = math.min(math.max(math.ceil(tonumber(data[1]) / 512 * self.columnCount), 1), self.columnCount)

				note.startTime = tonumber(data[3])
				if bit.band(tonumber(data[4]), 128) == 128 then
					local addition = string_util.split(data[6], ":")
					note.endTime = tonumber(addition[1])
				end

				table.insert(self.notes, note)
			end
		end
	end
end

return TinyParser
