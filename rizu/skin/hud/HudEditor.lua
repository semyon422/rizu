local HudElements = require("rizu.skin.hud.HudElements")

---Skin editor sections of a renderer's HUD: one per element, with properties built from its fields.
---Every change is stored in the renderer's layout.
local HudEditor = {}

HudEditor.layer_labels = {screen = "Screen", conveyor = "Conveyor"}
local channel_labels = {"red", "green", "blue", "opacity"}
local THUMBNAIL_SIZE = 128
local no_thumbnail = {done = true, result = {n = 0}}

---@param value number
---@return string
local function percent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

---@param options string[]
---@param value string
---@return string[]
local function with_value(options, value)
	for _, option in ipairs(options) do
		if option == value then return options end
	end
	local copy = {value}
	for i, option in ipairs(options) do copy[i + 1] = option end
	return copy
end

---@param renderer rizu.gameplay.views.PlayfieldRenderer
---@param element fun(): rizu.skin.hud.HudElement The element now at this place in the layout.
---@param field rizu.skin.hud.HudElement.Field
---@param properties rizu.api.Gameplay.SkinProperty[]
local function add_field(renderer, element, field, properties)
	local key = field.key
	local function set(value)
		local reload = element():set(key, value)
		renderer:saveHudLayout()
		if reload then renderer:reloadHud() end
	end
	local function get() return element().values[key] end
	local field_type = field.type or "slider"
	if field_type == "color" then
		for channel, name in ipairs(channel_labels) do
			properties[#properties + 1] = {
				label = field.label .. " " .. name, min = 0, max = 1, step = 0.01, value_format = percent,
				get = function() return element().values[key][channel] end,
				set = function(value)
					local color = {unpack(element().values[key] --[[@as number[] ]])}
					color[channel] = value
					set(color)
				end,
			}
		end
	elseif field_type == "texture" or field_type == "bitmap_font" then
		local textures = renderer.textures --[[@as rizu.skin.SkinTextures]]
		local font = field_type == "bitmap_font"
		local options = font and textures:getBitmapFontPrefixes() or textures:getTextureNames()
		if not font then table.insert(options, 1, "") end
		properties[#properties + 1] = {
			label = field.label, type = "texture", options = with_value(options, get() --[[@as string]]),
			format = function(value) return value == "" and "None" or value end,
			-- A font shows its zero.
			preview = function(value)
				if value == "" then return no_thumbnail end
				return textures:loadThumbnail(font and value .. "-0" or value, THUMBNAIL_SIZE)
			end,
			get = get, set = set,
			refresh = true, -- a texture change loads the HUD again, with new elements
		}
	elseif field_type ~= "text" then
		properties[#properties + 1] = {
			label = field.label, type = field_type --[[@as "slider"|"checkbox"|"dropdown"|"segmented"]], min = field.min, max = field.max, step = field.step,
			options = field.options, format = field.format, get = get, set = set,
		}
	end
end

---@param renderer rizu.gameplay.views.PlayfieldRenderer
---@return rizu.api.Gameplay.SkinSection[]
function HudEditor.getSections(renderer)
	local sections = {} ---@type rizu.api.Gameplay.SkinSection[]
	for _, layer in ipairs(renderer.hud_layers) do
		for index, element in ipairs(renderer:getHudElements(layer)) do
			-- Reloads replace the elements, so controls find theirs by place instead of keeping it.
			local function current() return renderer:getHudElements(layer)[index] end
			local properties = {} ---@type rizu.api.Gameplay.SkinProperty[]
			for _, field in ipairs(element:getFields()) do add_field(renderer, current, field, properties) end
			sections[#sections + 1] = {
				id = HudEditor.getId(layer, index),
				label = ("%s · %s"):format(element.label, HudEditor.layer_labels[layer]),
				properties = properties,
				remove = function() renderer:removeHudElement(layer, index) end,
			}
		end
	end
	return sections
end

---@param layer rizu.skin.hud.HudLayout.Layer
---@param index integer
---@return string
function HudEditor.getId(layer, index)
	return layer .. ":" .. index
end

---@return rizu.api.Gameplay.HudElementType[]
function HudEditor.getElementTypes()
	local types = {} ---@type rizu.api.Gameplay.HudElementType[]
	for i, name in ipairs(HudElements.getNames()) do
		types[i] = {name = name, label = HudElements.get(name).label}
	end
	return types
end

return HudEditor
