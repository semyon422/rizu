local HudElements = require("rizu.skin.hud.HudElements")

---Skin editor properties of a renderer's HUD: one group per element built from its fields, and
---controls to add, remove and reset elements. Every change is stored in the renderer's layout.
local HudEditor = {}

local layer_labels = {screen = "Screen", conveyor = "Conveyor"}
local channel_labels = {"red", "green", "blue", "opacity"}

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
		local options = field_type == "texture" and textures:getTextureNames() or textures:getBitmapFontPrefixes()
		if field_type == "texture" then table.insert(options, 1, "") end
		properties[#properties + 1] = {
			label = field.label, type = "dropdown", options = with_value(options, get() --[[@as string]]),
			format = function(value) return value == "" and "None" or value end,
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
---@return rizu.api.Gameplay.SkinProperty[]
function HudEditor.getProperties(renderer)
	local properties = {} ---@type rizu.api.Gameplay.SkinProperty[]
	local layers = renderer.hud_layers
	for _, layer in ipairs(layers) do
		for index, element in ipairs(renderer:getHudElements(layer)) do
			-- Reloads replace the elements, so controls find theirs by place instead of keeping it.
			local function current() return renderer:getHudElements(layer)[index] end
			properties[#properties + 1] = {
				type = "buttons", label = ("%s · %s"):format(element.label, layer_labels[layer]), refresh = true,
				buttons = {{text = "Remove", on_click = function() renderer:removeHudElement(layer, index) end}},
			}
			for _, field in ipairs(element:getFields()) do add_field(renderer, current, field, properties) end
		end
	end

	local names = HudElements.getNames()
	local new_type = names[1]
	properties[#properties + 1] = {
		label = "New HUD element", type = "dropdown", options = names,
		format = function(name) return HudElements.get(name).label end,
		get = function() return new_type end,
		set = function(name) new_type = name end,
		setting = true, -- nothing to save until it is added
	}
	local buttons = {} ---@type {text: string, on_click: fun()}[]
	for _, layer in ipairs(layers) do
		buttons[#buttons + 1] = {text = "Add to " .. layer_labels[layer]:lower(), on_click = function()
			renderer:addHudElement(new_type, layer)
		end}
	end
	buttons[#buttons + 1] = {text = "Reset HUD", on_click = function() renderer:resetHudLayout() end}
	properties[#properties + 1] = {type = "buttons", label = "HUD", buttons = buttons, refresh = true}
	return properties
end

return HudEditor
