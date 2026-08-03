local Screen = require("gui.Screen")
local Label = require("ui.views.Label")
local UiActions = require("ui.UiActions")

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

end

---@param inputs gui.Inputs
function Dlc:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.cancel) then
		self.ui:setScreen(self.ui.main_menu)
	end
end

return Dlc
