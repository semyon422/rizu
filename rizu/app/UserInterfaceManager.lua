local class = require("class")
local table_util = require("table_util")

local UserInterface = require("rizu.app.UserInterface")

local Settings = require("rizu.config.Settings")

---Discovers UI packages and activates the UI selected in settings.
---@class rizu.app.UserInterfaceManager
---@operator call: rizu.app.UserInterfaceManager
---@field items rizu.app.UserInterface[]
---@field private game sphere.GameController
---@field private settings rizu.config.Config
---@field private default_user_interface rizu.app.UserInterface
---@field mount_paths {[rizu.app.UserInterface]: string}
local UserInterfaceManager = class()

---@param game sphere.GameController
---@param default_user_interface rizu.app.UserInterface?
function UserInterfaceManager:new(game, default_user_interface)
	self.game = game
	self.settings = game.settings
	self.items = {}
	self.mount_paths = {}
	self.default_user_interface = default_user_interface or require("ui.UserInterface")

	self:register(self.default_user_interface, "")
end

---@param ui_class rizu.app.UserInterface
---@param mount_path string?
--- Registers a class object, not an instance!
--- mount_path is required for UI's that are added to the game using a plugin system
function UserInterfaceManager:register(ui_class, mount_path)
	assert(class.is_class(ui_class), "UserInterface registration requires a class, not an instance")
	assert(UserInterface / ui_class, "registered class must inherit rizu.app.UserInterface")
	assert(type(ui_class.name) == "string" and ui_class.name ~= "user_interface",
		"registered UserInterface class must override name")
	assert(type(ui_class.display_name) == "string", "registered UserInterface class must define display_name")
	self.items[#self.items + 1] = ui_class
	self.mount_paths[ui_class] = mount_path or ""
end

function UserInterfaceManager:load()
	local package_manager = self.game.packageManager
	local pkgs = self.game.packageManager:getPackagesByType("ui")

	for _, pkg in ipairs(pkgs) do
		local ok, err = xpcall(function()
			local ui_class = require(pkg.types.ui) ---@type rizu.app.UserInterface
			local root_dir = package_manager:getPackageDir(pkg.name) or ""
			self:register(ui_class, root_dir)
		end, debug.traceback)

		if not ok then
			print(("[UserInterfaceManager] Failed to load UI package %q:\n%s"):format(pkg.name, err))
		end
	end

	self:loadSelected()
end

---@param name string
function UserInterfaceManager:setUserInterface(name)
	self.settings:setString(Settings.user_interface, name)
end

function UserInterfaceManager:loadSelected()
	local name = self.settings:getString(Settings.user_interface)
	local ui_class = table_util.find(self.items, function(item)
		return item.name == name
	end) or self.default_user_interface

	local ok, instance_or_error = xpcall(function()
		return ui_class(self.game, self.mount_paths[ui_class])
	end, debug.traceback)

	if not ok then
		if ui_class == self.default_user_interface then
			error(instance_or_error, 0)
		end
		print(("[UserInterfaceManager] Failed to create UI %q; falling back to %q:\n%s")
			:format(ui_class.name, self.default_user_interface.name, instance_or_error))
		ui_class = self.default_user_interface
		instance_or_error = ui_class(self.game, self.mount_paths[ui_class])
	end

	if name ~= ui_class.name then
		self:setUserInterface(ui_class.name)
	end
	self.game:setUI(instance_or_error)
end

return UserInterfaceManager
