local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")

---@class ui.screens.result_v2.ResultMutators.Item
---@field sprite gui.Sprite
---@field value string?

---One row of the mutators applied to the play: an icon, with the setting underneath when it has one.
---A long row is clipped at the right edge instead of wrapping.
---@class ui.screens.result_v2.ResultMutators : gui.View
---@operator call: ui.screens.result_v2.ResultMutators
---@field items ui.screens.result_v2.ResultMutators.Item[]
---@field value_font love.Font
local ResultMutators = View + {}

local ICON_SIZE = 76
local GAP_X = 12
local VALUE_GAP = 4

local icon_names = {
	Custom = "mod_custom",
	WindUp = "mod_windup",
	NoScratch = "mod_no_scratch",
	NoLongNote = "mod_no_ln",
	Automap = "mod_automap",
	MultiplePlay = "mod_multiple_play",
	MultiOverPlay = "mod_multiple_play",
	Taiko = "mod_taiko",
	Alternate = "mod_alternate",
	Alternate2 = "mod_alternate",
	Shift = "mod_shift",
	Mirror = "mod_mirror",
	Random = "mod_unknown",
	BracketSwap = "mod_bracket_swap",
	MaxChord = "mod_max_chord",
	LessChord = "mod_less_chord",
	FullLongNote = "mod_full_ln",
	MinLnLength = "mod_min_ln_length",
}

---@type {[integer]: string}
local modifier_names = {}
for name, id in pairs(ModifierRegistry.enum) do
	modifier_names[id] = name
end

---@param width number
function ResultMutators:new(width)
	View.new(self)
	self.items = {}
	self.value_font = Resources.getFont("medium", 26)
	self:setSize(width, 0)
	self:setClip(true)
end

---@return number
function ResultMutators:getRowHeight()
	return ICON_SIZE + VALUE_GAP + self.value_font:getHeight()
end

---@param mutators sea.Modifier[]
function ResultMutators:bind(mutators)
	self.items = {}
	for _, modifier in ipairs(mutators) do
		local name = modifier_names[modifier.id]
		local sprite = Resources.sprites[icon_names[name or ""] or "mod_unknown"] --[[@as gui.Sprite]]

		-- The second return of getString is the setting, e.g. the 3 of FLN 3. Custom has a decorative one.
		local value ---@type string?
		local mod = ModifierModel:getModifier(modifier.id)
		if mod and name ~= "Custom" then
			local _, setting = mod:getString(modifier)
			if setting and #tostring(setting) > 0 then
				value = tostring(setting)
			end
		end
		self.items[#self.items + 1] = {sprite = sprite, value = value}
	end

	self:setHeight(#self.items > 0 and self:getRowHeight() or 0)
end

function ResultMutators:draw()
	Painter.snapToPixel()
	love.graphics.setFont(self.value_font)
	for i, item in ipairs(self.items) do
		local x = (i - 1) * (ICON_SIZE + GAP_X)
		local y = 0

		Painter.setColorRgb(1, 1, 1, 1)
		item.sprite:draw(x, y, 0, ICON_SIZE / item.sprite:getWidth(), ICON_SIZE / item.sprite:getHeight())
		if item.value then
			Painter.setColorTable(Colors.text)
			love.graphics.printf(item.value, x, y + ICON_SIZE + VALUE_GAP, ICON_SIZE, "center")
		end
	end
end

return ResultMutators
