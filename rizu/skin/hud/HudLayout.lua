local HudElements = require("rizu.skin.hud.HudElements")

---A HUD layout is plain data, stored in skin configs: per layer, a list of element values with
---their `type`. "screen" covers the gameplay viewport, "conveyor" the columns of the playfield.
local HudLayout = {}

---@alias rizu.skin.hud.HudLayout.Layer "screen"|"conveyor"
---@alias rizu.skin.hud.HudLayout.Data {[rizu.skin.hud.HudLayout.Layer]: rizu.skin.hud.HudElement.Values[]}
---@alias rizu.skin.hud.HudLayout.Elements {[rizu.skin.hud.HudLayout.Layer]: rizu.skin.hud.HudElement[]}

---@type rizu.skin.hud.HudLayout.Layer[]
HudLayout.layers = {"screen", "conveyor"}

---Elements of unknown types are left out: the layout may come from a newer game or a plugin.
---@param data rizu.skin.hud.HudLayout.Data
---@param textures rizu.skin.SkinTextures
---@param layers rizu.skin.hud.HudLayout.Layer[]? Layers the renderer draws, all by default.
---@return rizu.skin.hud.HudLayout.Elements
function HudLayout.build(data, textures, layers)
	local elements = {} ---@type rizu.skin.hud.HudLayout.Elements
	for _, layer in ipairs(layers or HudLayout.layers) do
		local list = {} ---@type rizu.skin.hud.HudElement[]
		for _, values in ipairs(data[layer] or {}) do
			local Element = HudElements.get(tostring(values.type))
			if Element then
				list[#list + 1] = Element(values, textures)
			else
				print(("hud layout: unknown element type %s"):format(tostring(values.type)))
			end
		end
		elements[layer] = list
	end
	return elements
end

---@param elements rizu.skin.hud.HudLayout.Elements
---@return rizu.skin.hud.HudLayout.Data
function HudLayout.serialize(elements)
	local data = {} ---@type rizu.skin.hud.HudLayout.Data
	for layer, list in pairs(elements) do
		local values = {} ---@type rizu.skin.hud.HudElement.Values[]
		for i, element in ipairs(list) do values[i] = element:serialize() end
		data[layer] = values
	end
	return data
end

---Textures every element needs, without empty names.
---@param elements rizu.skin.hud.HudLayout.Elements
---@return rizu.skin.SkinTextures.Asset[]
function HudLayout.getAssets(elements)
	local assets = {} ---@type rizu.skin.SkinTextures.Asset[]
	for _, layer in ipairs(HudLayout.layers) do
		for _, element in ipairs(elements[layer] or {}) do
			for _, asset in ipairs(element:getAssets()) do
				if asset.name and asset.name ~= "" then assets[#assets + 1] = asset end
			end
		end
	end
	return assets
end

return HudLayout
