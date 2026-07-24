local Screen = require("gui.Screen")
local Resources = require("ui.Resources")
local Image = require("ui.views.Image")

---@class ui.screens.result.Result : gui.Screen
---@operator call: ui.screens.result.Result
local Result = Screen + {}

---@param ui ui.UserInterface
function Result:new(ui)
	Screen.new(self)
	self.ui = ui

	local placeholder = self.root:add(Image(Resources.atlas, Resources.quads.screen_wip))
	placeholder:setAlignment(0.5, 0.5)
	placeholder:setPivot(0.5, 0.5)

	self.root.handles_keyboard_input = true
	self.root.onKeyDown = function(_, event)
		if event.key == "escape" then
			self.ui:setScreen(self.ui.song_select)
		end
	end
end

return Result
