local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.result_v2.ResultMutators.Item
---@field sprite gui.Sprite
---@field value string?

---One row of the mutators applied to the play: an icon, with the setting underneath when it has one.
---A long row is clipped at the right edge instead of wrapping.
---@class ui.screens.result_v2.ResultMutators : gui.View
---@operator call: ui.screens.result_v2.ResultMutators
---@field items ui.screens.result_v2.ResultMutators.Item[]
---@field value_font love.Font
---@field icon_size number
---@field show_values boolean
---@field align_right boolean
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

---@class ui.screens.result_v2.ResultMutators.Params
---@field icon_size number?
---@field show_values boolean? Draw the setting under the icon; default true.
---@field align_right boolean? Stick the row to the right edge instead of the left.

---@param width number
---@param params ui.screens.result_v2.ResultMutators.Params?
function ResultMutators:new(width, params)
	View.new(self)
	params = params or {}
	self.icon_size = params.icon_size or ICON_SIZE
	self.show_values = params.show_values ~= false
	self.align_right = params.align_right == true
	self.items = {}
	self.value_font = Resources.getFont("medium", 26)
	self:setSize(width, 0)
	self:setClip(true)
end

---@return number
function ResultMutators:getRowHeight()
	if not self.show_values then
		return self.icon_size
	end
	return self.icon_size + VALUE_GAP + self.value_font:getHeight()
end

---@param mutators rizu.api.Mutator[] From `ui.api.result:getMutators()`.
---@param play rizu.api.Play Names the mutators.
function ResultMutators:bind(mutators, play)
	self.items = {}
	for _, mutator in ipairs(mutators) do
		local name = play:getMutatorName(mutator)
		local sprite = Resources.sprites[icon_names[name] or "mod_unknown"] --[[@as gui.Sprite]]
		self.items[#self.items + 1] = {sprite = sprite, value = play:getMutatorValueText(mutator)}
	end

	self:setHeight(#self.items > 0 and self:getRowHeight() or 0)
end

function ResultMutators:draw()
	Painter.snapToPixel()
	love.graphics.setFont(self.value_font)
	local icon_size = self.icon_size
	local x0 = 0
	if self.align_right then
		x0 = self.width - (#self.items * (icon_size + GAP_X) - GAP_X)
	end
	for i, item in ipairs(self.items) do
		local x = x0 + (i - 1) * (icon_size + GAP_X)
		local y = 0

		Painter.setColorRgb(1, 1, 1, 1)
		item.sprite:draw(x, y, 0, icon_size / item.sprite:getWidth(), icon_size / item.sprite:getHeight())
		if item.value and self.show_values then
			Painter.setColorTable(Colors.text)
			love.graphics.printf(item.value, x, y + icon_size + VALUE_GAP, icon_size, "center")
		end
	end
end

return ResultMutators
