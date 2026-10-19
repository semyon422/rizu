local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local Localization = require("ui.localization.Localization")
local Panel = require("ui.views.Panel")
local View = require("gui.View")

---A language to pick: its name in its own language and in English.
---@class ui.screens.welcome.LanguageTile : gui.View
---@operator call: ui.screens.welcome.LanguageTile
---@field panel ui.views.Panel
---@field on_click fun()
local LanguageTile = View + {}

local COLOR = {Colors.surface[1], Colors.surface[2], Colors.surface[3], 0.82}
local HOVER_COLOR = {Colors.surface_raised[1], Colors.surface_raised[2], Colors.surface_raised[3], 0.9}
local SELECTED_COLOR = {Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.16}

---@param locale string
---@param selected boolean
---@param on_click fun()
function LanguageTile:new(locale, selected, on_click)
	View.new(self)
	self.on_click = on_click
	self.handles_mouse_input = true
	self:setSize(272, 88)
	self.panel = self:add(Panel({
		color = selected and SELECTED_COLOR or COLOR,
		line_color = selected and Colors.accent or nil,
		line_width = 2,
	}))
	self.panel:anchorFill(0, 0, 0, 0)
	self.selected = selected

	local name = self:add(Label({font_name = "medium", font_size = 26, text = Localization.native_names[locale]}))
	name:setPosition(22, 14)
	local english = self:add(Label({
		font_name = "regular", font_size = 16, text = Localization.english_names[locale], color = Colors.muted,
	}))
	english:setPosition(22, 50)
end

---@param e gui.MouseClickEvent
function LanguageTile:onMouseClick(e)
	if e.button ~= 1 then return end
	self.on_click()
	return true
end

function LanguageTile:update()
	if not self.selected then
		self.panel.color = self.mouse_over and HOVER_COLOR or COLOR
	end
end

return LanguageTile
