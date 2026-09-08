local class = require("class")

---@alias ui.localization.Locale string
---@alias ui.localization.Parameters {[string]: string|number|boolean}
---@alias ui.localization.Catalog {[string]: string}

---@class ui.localization.Localization
---@operator call: ui.localization.Localization
---@field locale ui.localization.Locale Locale selected for this instance.
---@field private catalogs {[ui.localization.Locale]: ui.localization.Catalog}
local Localization = class()

local interpolation_pattern = "{([%w_]+)}"

---@param locale ui.localization.Locale
---@return ui.localization.Catalog
local function load_catalog(locale)
	local module_name = "ui.localization.locales." .. locale
	local ok, catalog = pcall(require, module_name)
	if not ok then
		assert(tostring(catalog):find("module .* not found", 1, false), catalog)
		return {}
	end
	assert(type(catalog) == "table", ("localization catalog %q must return a table"):format(locale))
	for key, value in pairs(catalog) do
		assert(type(key) == "string" and type(value) == "string",
			("localization catalog %q must contain only string entries"):format(locale))
	end
	return catalog
end

---@param locale ui.localization.Locale?
function Localization:new(locale)
	assert(locale == nil or (type(locale) == "string" and locale ~= ""),
		"localization locale must be a non-empty string")
	self.locale = locale or "en"
	self.catalogs = {
		en = load_catalog("en"),
	}
	if self.locale ~= "en" then
		self.catalogs[self.locale] = load_catalog(self.locale)
	end
end

---@param key string Semantic localization key.
---@param parameters ui.localization.Parameters?
---@return string translated
function Localization:get(key, parameters)
	assert(type(key) == "string" and key ~= "", "localization key must be a non-empty string")
	if parameters ~= nil then
		assert(type(parameters) == "table", "localization parameters must be a table")
	end

	local catalog = self.catalogs[self.locale] or {}
	local translated = assert(catalog[key] or self.catalogs.en[key],
		("missing localization key %q"):format(key))
	local values = parameters or {}
	return (translated:gsub(interpolation_pattern, function(name)
		local value = values[name]
		assert(value ~= nil, ("missing localization parameter %q for key %q"):format(name, key))
		local value_type = type(value)
		assert(value_type == "string" or value_type == "number" or value_type == "boolean",
			("localization parameter %q for key %q must be a string, number, or boolean"):format(name, key))
		return tostring(value)
	end))
end

---@param key string Semantic localization key.
---@param parameters ui.localization.Parameters?
---@return string translated
function Localization:translate(key, parameters)
	return self:get(key, parameters)
end

return Localization
