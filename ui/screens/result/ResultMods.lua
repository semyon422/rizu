local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")

---@class ui.screens.result.ResultMods : gui.View
---@operator call: ui.screens.result.ResultMods
---@field sprites gui.Sprite[]
local ResultMods = View + {}

local ICON_SIZE = 48
local ICON_GAP = 6

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
function ResultMods:new()
	View.new(self)
	self.sprites = {}
	self:setSize(0, ICON_SIZE)
end

---@param replay_base sea.ReplayBase?
function ResultMods:bind(replay_base)
	self.sprites = {}

	for _, modifier in ipairs(replay_base and replay_base.modifiers or {}) do
		local name = modifier_names[modifier.id]
		local sprite_name = icon_names[name or ""] or "mod_unknown"
		local sprite = Resources.sprites[sprite_name] --[[@as gui.Sprite]]
		self.sprites[#self.sprites + 1] = sprite
	end

	self:setWidth(#self.sprites * ICON_SIZE + math.max(0, #self.sprites - 1) * ICON_GAP)
end

function ResultMods:draw()
	Painter.setColorRgb(1, 1, 1, 1)
	for i, sprite in ipairs(self.sprites) do
		sprite:draw((i - 1) * (ICON_SIZE + ICON_GAP), 0, 0, ICON_SIZE / sprite:getWidth(), ICON_SIZE / sprite:getHeight())
	end
end

return ResultMods
