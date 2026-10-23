local json = require("json")

---@class rizu.skin.SkinConfigSerializer
---@field version integer
local SkinConfigSerializer = {
	version = 1,
}

---@alias rizu.skin.SkinConfigHudValue number|string|boolean|number[]
---@alias rizu.skin.SkinConfigHudLayout {[string]: {[string]: rizu.skin.SkinConfigHudValue}[]} Layer name to its elements.
---@alias rizu.skin.SkinConfigHuds {[string]: {[string]: rizu.skin.SkinConfigHudLayout}} By gamemode and input mode.

---@param value any
---@return boolean
local function is_finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

---A copy of a HUD layout with everything of the wrong shape left out. The values themselves are
---checked by the elements that read them.
---@param layout any
---@return rizu.skin.SkinConfigHudLayout?
function SkinConfigSerializer.sanitizeHud(layout)
	if type(layout) ~= "table" then return end
	local copy = {} ---@type rizu.skin.SkinConfigHudLayout
	for layer, elements in pairs(layout) do
		if type(layer) == "string" and type(elements) == "table" then
			local copied_elements = {} ---@type {[string]: rizu.skin.SkinConfigHudValue}[]
			for _, element in ipairs(elements) do
				if type(element) == "table" then
					local copied = {} ---@type {[string]: rizu.skin.SkinConfigHudValue}
					for key, value in pairs(element) do
						local value_type = type(value)
						if type(key) ~= "string" then
						elseif value_type == "string" or value_type == "boolean" or is_finite(value) then
							copied[key] = value
						elseif value_type == "table" and #value >= 3 and #value <= 4 then -- colors
							local numbers = {} ---@type number[]
							for i, number in ipairs(value) do
								numbers[i] = is_finite(number) and number or 0
							end
							copied[key] = numbers
						end
					end
					copied_elements[#copied_elements + 1] = copied
				end
			end
			copy[layer] = copied_elements
		end
	end
	return copy
end

---@param overrides rizu.skin.SkinConfigOverrides
---@param huds rizu.skin.SkinConfigHuds?
---@return string json_string
function SkinConfigSerializer.serialize(overrides, huds)
	local encoded_overrides = json.object()
	for gamemode, modes in pairs(overrides) do
		local encoded_modes = json.object()
		for input_mode, properties in pairs(modes) do
			local encoded_properties = json.object()
			for key, value in pairs(properties) do
				encoded_properties[key] = value
			end
			encoded_modes[input_mode] = encoded_properties
		end
		encoded_overrides[gamemode] = encoded_modes
	end
	local encoded_huds = json.object()
	for gamemode, modes in pairs(huds or {}) do
		local encoded_modes = json.object()
		for input_mode, layout in pairs(modes) do
			local encoded_layout = json.object()
			for layer, elements in pairs(layout) do
				local encoded_elements = json.array()
				for i, element in ipairs(elements) do
					local encoded_element = json.object()
					for key, value in pairs(element) do encoded_element[key] = value end
					encoded_elements[i] = encoded_element
				end
				encoded_layout[layer] = encoded_elements
			end
			encoded_modes[input_mode] = encoded_layout
		end
		encoded_huds[gamemode] = encoded_modes
	end
	return json.encode({
		version = SkinConfigSerializer.version,
		overrides = encoded_overrides,
		huds = next(encoded_huds) and encoded_huds or nil,
	}, {indent = "\t"}) .. "\n"
end

---HUD layouts of the wrong shape are left out instead of failing the whole config.
---@param json_string string
---@return rizu.skin.SkinConfigOverrides?
---@return string? error_message
---@return rizu.skin.SkinConfigHuds? huds
function SkinConfigSerializer.deserialize(json_string)
	local decoded, decode_error = json.decode_safe(json_string)
	if type(decoded) ~= "table" or not json.isObject(decoded) then
		return nil, decode_error or "skin config must be an object"
	end
	if decoded.version ~= SkinConfigSerializer.version then
		return nil, "unsupported skin config version"
	end
	if type(decoded.overrides) ~= "table" or not json.isObject(decoded.overrides) then
		return nil, "skin config overrides must be an object"
	end

	local overrides = {} ---@type rizu.skin.SkinConfigOverrides
	for gamemode, modes in pairs(decoded.overrides) do
		if type(gamemode) ~= "string" or gamemode == "" or type(modes) ~= "table" or not json.isObject(modes) then
			return nil, "skin config contains invalid gamemode overrides"
		end
		local copied_modes = {}
		for input_mode, properties in pairs(modes) do
			if type(input_mode) ~= "string" or input_mode == "" or type(properties) ~= "table" or not json.isObject(properties) then
				return nil, "skin config contains invalid input mode overrides"
			end
			local copied_properties = {}
			for key, value in pairs(properties) do
				local value_type = type(value)
				if type(key) ~= "string" or key == "" or
					(value_type ~= "number" and value_type ~= "string" and value_type ~= "boolean") then
					return nil, "skin config contains an invalid property override"
				end
				if value_type == "number" and
					(value ~= value or value == math.huge or value == -math.huge) then
					return nil, "skin config contains a non-finite number"
				end
				copied_properties[key] = value
			end
			copied_modes[input_mode] = copied_properties
		end
		overrides[gamemode] = copied_modes
	end

	local huds = {} ---@type rizu.skin.SkinConfigHuds
	if type(decoded.huds) == "table" then
		for gamemode, modes in pairs(decoded.huds) do
			if type(gamemode) == "string" and type(modes) == "table" then
				local copied_modes = {} ---@type {[string]: rizu.skin.SkinConfigHudLayout}
				for input_mode, layout in pairs(modes) do
					if type(input_mode) == "string" then copied_modes[input_mode] = SkinConfigSerializer.sanitizeHud(layout) end
				end
				huds[gamemode] = copied_modes
			end
		end
	end
	return overrides, nil, huds
end

return SkinConfigSerializer
