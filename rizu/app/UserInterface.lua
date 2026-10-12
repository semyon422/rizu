local GuiUserInterface = require("gui.UserInterface")

---@class rizu.app.UserInterface : gui.UserInterface
---@overload fun(game: sphere.GameController, mount_path: string, screen_manager: gui.IScreenManager): rizu.app.UserInterface
---@field api rizu.api.GameApi The documented way to talk to the game, see `rizu/api/`.
---@field game sphere.GameController For what the API does not cover. Holds nothing but `api` when the UI runs without the game.
local UserInterface = GuiUserInterface + {}

-- Name must be overriden
UserInterface.name = "user_interface"
UserInterface.display_name = "User Interface"

---@param game sphere.GameController
---@param mount_path string
---@param screen_manager gui.IScreenManager
function UserInterface:new(game, mount_path, screen_manager)
	self.game = game
	self.api = game.api
	self.mount_path = mount_path
	GuiUserInterface.new(self, screen_manager)

	if self.name == "user_interface" then
		error("You must override UserInterface.name")
	end
end

return UserInterface
