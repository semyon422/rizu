local Section = require("chart.format.osu.sections.Section")

---Decoded for combo colours only; the section is not written back.
---@class chart.osu.Colours: chart.osu.Section
---@operator call: chart.osu.Colours
---@field combos {[integer]: number[]} RGB in 0 to 1, by the ComboN index.
local Colours = Section + {}

function Colours:new()
	self.combos = {}
end

---@param line string
function Colours:decodeLine(line)
	---@type string?, string?, string?, string?
	local index, r, g, b = line:match("^Combo(%d+)%s*:%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
	if index then
		self.combos[assert(tonumber(index))] = {tonumber(r) / 255, tonumber(g) / 255, tonumber(b) / 255}
	end
end

return Colours
