local Section = require("chart.format.osu.sections.Section")

---@class chart.osu.KeyValue: chart.osu.Section
---@operator call: chart.osu.KeyValue
---@field keys string[]
---@field [string] string
local KeyValue = Section + {}

KeyValue.space = false

KeyValue.keys = {}

---@param line string
function KeyValue:decodeLine(line)
	local key, value = line:match("^(%a+):%s?(.*)")
	if key then
		self[key] = value
	end
end

---@return string[]
function KeyValue:encode()
	local out = {}

	local space = self.space and " " or ""

	for _, k in ipairs(self.keys) do
		local entry = self[k]
		if entry then
			table.insert(out, ("%s:%s%s"):format(k, space, entry))
		end
	end

	return out
end

return KeyValue
