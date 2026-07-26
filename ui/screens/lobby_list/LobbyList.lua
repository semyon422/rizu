local Screen = require("gui.Screen")
local Label = require("ui.views.Label")

---@class ui.screens.lobby_list.LobbyList : gui.Screen
---@operator call: ui.screens.lobby_list.LobbyList
local LobbyList = Screen + {}

---@param ui ui.UserInterface
function LobbyList:new(ui)
	Screen.new(self)
	self.ui = ui

	local label = self.root:add(Label({
		font_name = "bold",
		font_size = 32,
		text = "Multiplayer room list: TODO",
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

return LobbyList
