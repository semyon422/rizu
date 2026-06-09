local Screen = require("yi.Screen")
local ModifierView = require("yi.views.slop.ModifierView")
local InputView = require("yi.views.slop.InputView")

---@alias yi.Modals.Names
---| "modifiers"
---| "inputs"

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

	self:hideView(self.modifiers)
	self:hideView(self.input)
end

---@param modal_name yi.Modals.Names
function Modals:open(modal_name)
	local modal ---@type gui.View?

	if modal_name == "modifiers" then
		modal = self.modifiers
	elseif modal_name == "inputs" then
		modal = self.input
	end

	---@cast modal gui.View?

	if not modal then
		return
	end

	if self.current_modal == modal then
		self:hideView(modal)
		self.current_modal = nil
		return
	else
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
