---Element types a HUD layout can use, by name. Skins and plugins add their own with `register`.
local HudElements = {}

---@type {[string]: rizu.skin.hud.HudElement}
local types = {}
---@type string[]
local names = {}

---@param name string Stored in layouts, so keep it once a layout may use it.
---@param Element rizu.skin.hud.HudElement
function HudElements.register(name, Element)
	assert(type(name) == "string" and name ~= "", "element name must be a non-empty string")
	if not types[name] then names[#names + 1] = name end
	types[name] = Element
	Element.type = name
end

---@param name string
---@return rizu.skin.hud.HudElement?
function HudElements.get(name)
	return types[name]
end

---@return string[] names In registration order.
function HudElements.getNames()
	return names
end

HudElements.register("score", require("rizu.skin.hud.elements.Score"))
HudElements.register("accuracy", require("rizu.skin.hud.elements.Accuracy"))
HudElements.register("combo", require("rizu.skin.hud.elements.Combo"))
HudElements.register("judgement", require("rizu.skin.hud.elements.Judgement"))
HudElements.register("osu_hit_error", require("rizu.skin.hud.elements.OsuHitError"))
HudElements.register("osu_radial_progress", require("rizu.skin.hud.elements.OsuRadialProgress"))
HudElements.register("iidx_gauge", require("rizu.skin.hud.elements.IidxGauge"))
HudElements.register("osu_hp_bar", require("rizu.skin.hud.elements.OsuHpBar"))
HudElements.register("sprite", require("rizu.skin.hud.elements.Sprite"))
HudElements.register("box", require("rizu.skin.hud.elements.Box"))

return HudElements
