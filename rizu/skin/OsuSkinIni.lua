---@class rizu.skin.OsuSkinIni.ManiaSection
---@field [string] string

---@class rizu.skin.OsuSkinIni.Data
---@field General {[string]: string}
---@field Colours {[string]: string}
---@field Fonts {[string]: string}
---@field CatchTheBeat {[string]: string}
---@field Mania rizu.skin.OsuSkinIni.ManiaSection[]
---@field [string] table

local OsuSkinIni = {}

---@param value string
---@return string
local function trim(value)
	return (value:gsub("^%s*(.-)%s*$", "%1"))
end

---Parses an osu! skin.ini into case-preserving sections of raw string values.
---Repeated [Mania] sections are kept separately; other repeated sections merge.
---@param content string
---@return rizu.skin.OsuSkinIni.Data
function OsuSkinIni.parse(content)
	assert(type(content) == "string", "skin.ini content must be a string")
	content = content:gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("\r", "\n")

	---@type rizu.skin.OsuSkinIni.Data
	local sections = {
		General = {},
		Colours = {},
		Fonts = {},
		CatchTheBeat = {},
		Mania = {},
	}
	local current_section = sections.General

	for line in (content .. "\n"):gmatch("(.-)\n") do
		line = trim(line)
		if line ~= "" and not line:match("^//") then
			if line:sub(1, 1) == "[" then
				local closing_bracket = line:find("]", 2, true)
				if closing_bracket then
					local section_name = trim(line:sub(2, closing_bracket - 1))
					if section_name == "Mania" then
						current_section = {}
						table.insert(sections.Mania, current_section)
					elseif section_name ~= "" then
						local section = sections[section_name]
						if type(section) ~= "table" then
							section = {}
							sections[section_name] = section
						end
						current_section = section
					else
						current_section = nil
					end
				else
					current_section = nil
				end
			elseif current_section then
				local comment_start = line:find("//", 1, true)
				if comment_start then
					line = trim(line:sub(1, comment_start - 1))
				end
				local delimiter = line:find(":", 1, true)
				if delimiter then
					local key = trim(line:sub(1, delimiter - 1))
					local value = trim(line:sub(delimiter + 1))
					-- osu! preserves the first occurrence of a key in a section.
					if key ~= "" and current_section[key] == nil then
						current_section[key] = value
					end
				end
			end
		end
	end

	return sections
end

return OsuSkinIni
