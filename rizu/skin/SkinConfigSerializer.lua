local json = require("json")

---@class rizu.skin.SkinConfigSerializer
---@field version integer
local SkinConfigSerializer = {
	version = 1,
}

---@param overrides rizu.skin.SkinConfigOverrides
---@return string json_string
function SkinConfigSerializer.serialize(overrides)
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
	return json.encode({
		version = SkinConfigSerializer.version,
		overrides = encoded_overrides,
	}, {indent = "\t"}) .. "\n"
end

---@param json_string string
---@return rizu.skin.SkinConfigOverrides?
---@return string? error_message
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
	return overrides
end

return SkinConfigSerializer
