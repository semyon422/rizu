local class = require("class")

---@class chart.osu.Section
---@operator call: chart.osu.Section
local Section = class()

---@param lines string[]
function Section:decode(lines)
	for _, line in ipairs(lines) do
		self:decodeLine(line)
	end
end

---@param line string
function Section:decodeLine(line) end

---@return string[]
function Section:encode()
	return {}
end

return Section
