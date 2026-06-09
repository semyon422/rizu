local Screen = require("yi.Screen")
local ModifierView = require("yi.views.slop.ModifierView")

---@class yi.Modals : yi.Screen
---@operator call: yi.Modals
---@field current_modal gui.View?
local Modals = Screen + {}

---@param yi yi.UserInterface
function Modals:new(yi)
	Screen.new(self)
	self.modifiers = ModifierView(yi.game.modifierSelectModel)
	self.modifiers.pivot = {0.5, 0.5}
	self:hideView(self.modifiers)
end

function Modals:openModifiers()
	if self.current_modal == self.modifiers then
		self:hideView(self.modifiers)
		self.current_modal = nil
		return
	end

	self:showView(self.modifiers)
	self.current_modal = self.modifiers
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
