local View = require("rizu.skin.View")

---@alias rizu.skin.hud.HudElement.Value number|string|boolean|number[]
---@alias rizu.skin.hud.HudElement.Values {[string]: rizu.skin.hud.HudElement.Value}

---"texture" is a texture name and "bitmap_font" a glyph prefix, both looked up in the skin.
---"text" is saved and validated but has no editor control yet.
---@alias rizu.skin.hud.HudElement.FieldType "slider"|"checkbox"|"dropdown"|"segmented"|"color"|"texture"|"bitmap_font"|"text"

---@class rizu.skin.hud.HudElement.Field
---@field key string
---@field label string
---@field type rizu.skin.hud.HudElement.FieldType? Defaults to "slider".
---@field default rizu.skin.hud.HudElement.Value
---@field min number?
---@field max number?
---@field step number?
---@field options any[]? Values of dropdown and segmented fields.
---@field format (fun(value: any): string)? Option labels of dropdown and segmented fields.
---@field value_format (fun(value: number): string)? Slider value text. Whole numbers by default.

---A HUD element a skin layout can place: it declares its editable fields and the textures it needs,
---reads the play through the game api and draws in local coordinates. Every element has
---`x`, `y`, `anchor`, `origin`, `scale` and `rotation` (degrees, around the origin), then the fields of its type.
---@class rizu.skin.hud.HudElement : rizu.skin.View
---@operator call: rizu.skin.hud.HudElement
---@field type string Registry name, set by `rizu.skin.hud.HudElements.register`.
---@field label string Name shown in the skin editor.
---@field fields rizu.skin.hud.HudElement.Field[] Fields of this type, after the common ones.
---@field defaults rizu.skin.hud.HudElement.Values Defaults of common fields for this type.
---@field values rizu.skin.hud.HudElement.Values Normalized, includes `type`.
---@field textures rizu.skin.SkinTextures
---@field context rizu.api.GameApi?
local HudElement = View + {}

HudElement.label = "Element"
HudElement.fields = {}
HudElement.defaults = {}
HudElement.group = "hud" -- atlas group of HUD textures

local anchors = {"top_left", "top", "top_right", "left", "center", "right", "bottom_left", "bottom", "bottom_right"}
local MAX_TEXT_LENGTH = 256

---@param value number
---@return string
function HudElement.percent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

---@type rizu.skin.hud.HudElement.Field[]
HudElement.common_fields = {
	{key = "x", label = "X", min = -640, max = 640, step = 1, default = 0},
	{key = "y", label = "Y", min = -480, max = 480, step = 1, default = 0},
	{key = "anchor", label = "Anchor", type = "dropdown", options = anchors, default = "center"},
	{key = "origin", label = "Origin", type = "dropdown", options = anchors, default = "center"},
	{key = "scale", label = "Scale", min = 0.05, max = 4, step = 0.05, default = 1, value_format = HudElement.percent},
	{key = "rotation", label = "Rotation", min = -180, max = 180, step = 1, default = 0,
		value_format = function(value) return ("%d°"):format(value) end},
}

---Common fields with this type's defaults, then the type's own fields.
---@return rizu.skin.hud.HudElement.Field[]
function HudElement:getFields()
	local fields = {} ---@type rizu.skin.hud.HudElement.Field[]
	for i, field in ipairs(HudElement.common_fields) do
		local default = self.defaults[field.key]
		if default ~= nil then
			local copy = {} ---@type {[string]: any}
			for k, v in pairs(field) do copy[k] = v end
			copy.default = default
			field = copy
		end
		fields[i] = field
	end
	for _, field in ipairs(self.fields) do fields[#fields + 1] = field end
	return fields
end

---@param value any
---@return boolean
local function is_finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

---The value if the field accepts it, clamped into range, otherwise nil.
---@param field rizu.skin.hud.HudElement.Field
---@param value any
---@return rizu.skin.hud.HudElement.Value?
function HudElement.check(field, value)
	local field_type = field.type or "slider"
	if field_type == "slider" then
		if not is_finite(value) then return end
		if field.step == 1 then value = math.floor(value + 0.5) end -- counts, like digits
		return math.max(field.min or -math.huge, math.min(field.max or math.huge, value))
	elseif field_type == "checkbox" then
		if type(value) == "boolean" then return value end
	elseif field_type == "dropdown" or field_type == "segmented" then
		for _, option in ipairs(field.options) do
			if option == value then return value end
		end
	elseif field_type == "color" then
		if type(value) ~= "table" or #value < 3 or #value > 4 then return end
		local color = {} ---@type number[]
		for i = 1, 4 do
			local channel = value[i] == nil and i == 4 and 1 or value[i]
			if not is_finite(channel) then return end
			color[i] = math.max(0, math.min(1, channel))
		end
		return color
	elseif type(value) == "string" and #value <= MAX_TEXT_LENGTH then
		return value
	end
end

---Layout values are player data: anything missing or invalid takes the field default.
---@param values {[string]: any}?
---@return rizu.skin.hud.HudElement.Values
function HudElement:normalize(values)
	values = values or {}
	local normalized = {type = self.type} ---@type rizu.skin.hud.HudElement.Values
	for _, field in ipairs(self:getFields()) do
		local value = HudElement.check(field, values[field.key])
		if value == nil then value = HudElement.check(field, field.default) end
		normalized[field.key] = value
	end
	return normalized
end

---@param values {[string]: any}?
---@param textures rizu.skin.SkinTextures
function HudElement:new(values, textures)
	View.new(self, {width = 0, height = 0})
	self.textures = textures
	self.values = self:normalize(values)
	self:applyValues()
end

---Copies the common values onto the view. Types with derived state extend it.
function HudElement:applyValues()
	local values = self.values
	self.x, self.y = values.x --[[@as number]], values.y --[[@as number]]
	self.anchor, self.origin = values.anchor --[[@as rizu.skin.ViewAnchor]], values.origin --[[@as rizu.skin.ViewAnchor]]
	local scale = values.scale --[[@as number]]
	self.transform:setTransformation(0, 0, math.rad(values.rotation --[[@as number]]), scale, scale)
end

---@param key string
---@return rizu.skin.hud.HudElement.Field?
function HudElement:getField(key)
	for _, field in ipairs(self:getFields()) do
		if field.key == key then return field end
	end
end

---@param key string
---@param value any
---@return boolean reload True when the element now needs other textures.
function HudElement:set(key, value)
	local field = assert(self:getField(key), "unknown field " .. tostring(key))
	value = HudElement.check(field, value)
	assert(value ~= nil, "invalid value for " .. key)
	self.values[key] = value
	self:applyValues()
	return field.type == "texture" or field.type == "bitmap_font"
end

---Textures to request before loading, in the `hud` atlas group.
---@return rizu.skin.SkinTextures.Asset[]
function HudElement:getAssets()
	return {}
end

---@return rizu.skin.hud.HudElement.Values
function HudElement:serialize()
	local copy = {} ---@type rizu.skin.hud.HudElement.Values
	for key, value in pairs(self.values) do
		if type(value) == "table" then
			local color = {} ---@type number[]
			for i, channel in ipairs(value) do color[i] = channel end
			value = color
		end
		copy[key] = value
	end
	return copy
end

---@param context rizu.api.GameApi
function HudElement:load(context)
	View.load(self, context)
end

---@param dt number
---@param context rizu.api.GameApi
function HudElement:update(dt, context) end

---@param name string
---@return rizu.skin.SkinTextures.Image?
function HudElement:getTexture(name)
	if name == "" then return end
	return self.textures:getFrames(name, nil, HudElement.group)[1]
end

---@param name string
---@return rizu.skin.SkinTextures.Image[]
function HudElement:getAnimation(name)
	if name == "" then return {} end
	return self.textures:getAnimationFrames(name, nil, HudElement.group)
end

---@param color number[]
---@param alpha number?
function HudElement.setColor(color, alpha)
	love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
end

return HudElement
