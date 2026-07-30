local json = require("web.json")
local utf8validate = require("utf8validate")

local M = {}

local INDENT = "  "

---@param text string
---@param prefix string
---@return string
local function indent(text, prefix)
	return prefix .. text:gsub("\n", "\n" .. prefix)
end

---@param value table
---@return string[]
local function sortedKeys(value)
	local keys = {}
	for key in pairs(value) do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	return keys
end

---@param value any
---@return string
local function formatValue(value)
	if value == json.null then
		return "null"
	end
	local value_type = type(value)
	if value_type == "string" then
		return utf8validate(value)
	elseif value_type == "boolean" or value_type == "number" then
		return tostring(value)
	elseif value_type ~= "table" then
		return utf8validate(tostring(value))
	end

	if json.isArray(value) then
		if #value == 0 then
			return "[]"
		end
		local lines = {}
		for _, item in ipairs(value) do
			local formatted = formatValue(item)
			local first, rest = formatted:match("^([^\n]*)\n?(.*)$")
			table.insert(lines, "- " .. first)
			if rest ~= "" then
				table.insert(lines, indent(rest, INDENT))
			end
		end
		return table.concat(lines, "\n")
	end

	local keys = sortedKeys(value)
	if #keys == 0 then
		return "{}"
	end
	local lines = {}
	for _, key in ipairs(keys) do
		local formatted = formatValue(value[key])
		if formatted:find("\n", 1, true) or type(value[key]) == "table" then
			table.insert(lines, key .. ":")
			table.insert(lines, indent(formatted, INDENT))
		else
			table.insert(lines, key .. ": " .. formatted)
		end
	end
	return table.concat(lines, "\n")
end

---@param text string
---@return string
local function cleanLuaDump(text)
	text = text:gsub("<table:%s*0x%x+>%s*", "")
	text = text:gsub("\\(.)", function(character)
		if character == "n" then
			return "\n"
		elseif character == "r" then
			return ""
		elseif character == "t" then
			return INDENT
		elseif character == "b" or character == "f" then
			return ""
		elseif character == '"' then
			return '"'
		elseif character == "\\" then
			return "\\"
		end
		return "\\" .. character
	end)
	return utf8validate(text)
end

---@param decoded table
---@return string
local function formatLuaEvalResult(decoded)
	local sections = {}
	if type(decoded.error) == "string" and decoded.error ~= "" then
		table.insert(sections, "error:\n" .. indent(cleanLuaDump(decoded.error), INDENT))
	end
	if type(decoded.output) == "string" and decoded.output ~= "" then
		table.insert(sections, "output:\n" .. indent(cleanLuaDump(decoded.output), INDENT))
	end
	if type(decoded.values) == "table" then
		for index, value in ipairs(decoded.values) do
			local formatted = type(value) == "string" and cleanLuaDump(value) or formatValue(value)
			if #decoded.values == 1 and #sections == 0 then
				table.insert(sections, formatted)
			else
				table.insert(sections, ("value %d:\n%s"):format(index, indent(formatted, INDENT)))
			end
		end
	end
	if #sections == 0 then
		return decoded.ok == true and "Completed" or formatValue(decoded)
	end
	return table.concat(sections, "\n")
end

---@param arguments string?
---@return string
function M.formatArguments(arguments)
	if type(arguments) ~= "string" or arguments == "" then
		return ""
	end
	local decoded = json.decode_safe(arguments)
	if decoded == nil then
		return utf8validate(arguments)
	elseif type(decoded) == "table" and next(decoded) == nil then
		return ""
	end
	return formatValue(decoded)
end

---@param tool_name string?
---@param content string
---@return string
function M.formatResult(tool_name, content)
	local decoded = json.decode_safe(content)
	if decoded == nil then
		return utf8validate(content)
	elseif tool_name == "lua_eval" and type(decoded) == "table" then
		return formatLuaEvalResult(decoded)
	end
	return formatValue(decoded)
end

return M
