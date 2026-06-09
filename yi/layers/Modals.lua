local Screen = require("yi.Screen")
local ModifierView = require("yi.views.slop.ModifierView")
local InputView = require("yi.views.slop.InputView")
local FiltersView = require("yi.views.slop.FiltersView")

---@alias yi.Modals.Names
---| "modifiers"
---| "input"
---| "filters"

---@class yi.Modals : yi.Screen
---@operator call: yi.Modals
---@field current_modal gui.View?
local Modals = Screen + {}

---@param yi yi.UserInterface
function Modals:new(yi)
	Screen.new(self)
	self.modifiers = ModifierView(yi.game.modifierSelectModel)
	self.modifiers:setPivot(0.5, 0.5)

	self.input = InputView(yi.game)
	self.input:setPivot(0.5, 0.5)

	self.filters = FiltersView(yi.game)
	self.filters:setPivot(0.5, 0.5)

	self:hideView(self.modifiers)
	self:hideView(self.input)
	self:hideView(self.filters)
end

---@param modal_name yi.Modals.Names
function Modals:open(modal_name)
	local modal = self[modal_name] ---@type gui.View?

	if not modal then
		return
	end

	if self.current_modal == modal then
		self:hideView(modal)
		self.current_modal = nil
		return
	elseif self.current_modal then
		self:hideView(self.current_modal)
		self.current_modal = nil
	end

	self:showView(modal)
	self.current_modal = modal
end

function Modals:close()
	if self.current_modal then
		self:hideView(self.current_modal)
		self.current_modal = nil
	end
end

function Modals:handleKeyDown(key)
	if key == "escape" then
		if self.current_modal then
			self:close()
			return true
		end
	end
end

return Modals
