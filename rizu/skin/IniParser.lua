---@class rizu.skin.IniParser
local IniParser = {}

---@param value string
---@return string
local function trim(value)
	return value:match("^%s*(.-)%s*$")
end

---@param data string
---@return {[string]: {[string]: string}}
function IniParser.parse(data)
	data = data:gsub("^\239\187\191", "")
	---@type {[string]: {[string]: string}}
	local sections = {}
	local section
	local line = ""

	for source_line in (data .. "\n"):gmatch("(.-)\r?\n") do
		line = line .. source_line
		if line:sub(-1) == "\\" then
			line = line:sub(1, -2)
		else
			if line:sub(1, 1) ~= ";" and line:sub(1, 1) ~= "#" and not line:match("^//") and not line:match("^%-%-") then
				local name = line:match("^%[(.*)%]$")
				if name then
					section = sections[name] or {}
					sections[name] = section
				elseif section then
					local key, value = line:match("^(.-)=(.*)$")
					if key then
						key = trim(key)
						if key ~= "" then section[key] = trim(value) end
					end
				end
			end
			line = ""
		end
	end

	return sections
end

return IniParser
