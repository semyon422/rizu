local Screen = require("gui.Screen")
local Label = require("ui.views.Label")

---@class ui.screens.dlc.Dlc : gui.Screen
---@operator call: ui.screens.dlc.Dlc
local Dlc = Screen + {}

---@param ui ui.UserInterface
function Dlc:new(ui)
	Screen.new(self)
	self.ui = ui

	local label = self.root:add(Label({
		font_name = "bold",
		font_size = 32,
		text = "Downloadable content: TODO",
	}))
	label:setAlignment(0.5, 0.5)
	label:setPivot(0.5, 0.5)

	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "escape" then
			self.ui:setScreen(self.ui.main_menu)
			return true
		end
	end
end

return Dlc
