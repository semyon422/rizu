local class = require("class")

---@class chart.sph.LinesCleaner
---@operator call: chart.sph.LinesCleaner
local LinesCleaner = class()

---@param line chart.sph.Line
---@return boolean
local function has_payload(line)
	---@cast line {[string]: any}
	for k in pairs(line) do
		if k ~= "time" then
			return true
		end
	end
	return false
end

---@param line chart.sph.Line
---@param next_line chart.sph.Line
---@return boolean
local function is_line_useful_inside(line, next_line)
	if not next_line then
		return true
	end
	local hp = has_payload(line)
	if hp then
		return true
	end
	if next_line.same then  -- time in `same` has no sense
		next_line.time = line.time
		next_line.same = nil
		return false
	end
	if not line.time then
		return true
	end
	return false
end

---@param lines chart.sph.Line[]
---@return chart.sph.Line[]
function LinesCleaner:clean(lines)
	local first, last = 1, #lines
	for i = 1, #lines do
		if has_payload(lines[i]) then
			first = i
			break
		end
	end
	for i = #lines, 1, -1 do
		if has_payload(lines[i]) then
			last = i
			break
		end
	end

	local _lines = {}
	for i = first, last do
		local line = lines[i]
		local next_line = lines[i + 1]
		if is_line_useful_inside(line, next_line) then
			table.insert(_lines, lines[i])
		end
	end

	return _lines
end

return LinesCleaner
