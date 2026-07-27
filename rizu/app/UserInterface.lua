local GuiUserInterface = require("gui.UserInterface")

---@class rizu.app.UserInterface : gui.UserInterface
---@overload fun(game: sphere.GameController, mount_path: string, screen_manager: gui.IScreenManager): rizu.app.UserInterface
local UserInterface = GuiUserInterface + {}

-- Name must be overriden
UserInterface.name = "user_interface"
UserInterface.display_name = "User Interface"

---@param game sphere.GameController
---@param mount_path string
---@param screen_manager gui.IScreenManager
function UserInterface:new(game, mount_path, screen_manager)
	self.game = game
	self.mount_path = mount_path
	GuiUserInterface.new(self, screen_manager)

	if self.name == "user_interface" then
		error("You must override UserInterface.name")
	end
end

return UserInterface
