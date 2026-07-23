local class = require("class")
local table_util = require("table_util")

local FallbackUserInterface = require("sphere.FallbackUserInterface")
local NewUserInterface = require("ui.UserInterface")

local Settings = require("rizu.config.schemas.Settings")

---@class sphere.UserInterfaceModel.ItemEntry
---@field name string
---@field display_name string 
---@field object sphere.IUserInterface
---@field mount_path string?

---@class sphere.UserInterfaceModel
---@operator call: sphere.UserInterfaceModel
---@field items sphere.UserInterfaceModel.ItemEntry[]
---@field private game sphere.GameController
local UserInterfaceModel = class()

---@param game sphere.GameController
function UserInterfaceModel:new(game)
	self.game = game
	self.settings = game.settings
	self.items = {}

	self:add("new", "2026 UI", NewUserInterface, "")
end

---@param name string
---@param display_name string
---@param object sphere.IUserInterface
---@param mount_path string
function UserInterfaceModel:add(name, display_name, object, mount_path)
	table.insert(self.items, {
		name = name,
		display_name = display_name,
		object = object,
		mount_path = mount_path
	})
end

function UserInterfaceModel:load()
	local package_manager = self.game.packageManager
	local pkgs = self.game.packageManager:getPackagesByType("ui")

	for _, pkg in ipairs(pkgs) do
		---@type boolean, string | sphere.IUserInterface
		local ok, res = xpcall(require, debug.traceback, pkg.types.ui)

		if ok then
			---@cast res sphere.IUserInterface
			local root_dir = package_manager:getPackageDir(pkg.name) or ""
			self:add(pkg.name, pkg.display_name, res, root_dir)
		else
			print(("[UserInterfaceModel] Failed to require external UI:"):format(res))
		end
	end

	self:loadSelected()
end

---@param name string
function UserInterfaceModel:setUserInterface(name)
	self.settings:setString(Settings.graphics.appearance.user_interface, name)
end

function UserInterfaceModel:loadSelected()
	local name = self.settings:getString(Settings.graphics.appearance.user_interface)
	if name == "old" then
		name = "new"
		self:setUserInterface(name)
	end

	local item = table_util.find(self.items, function(v)
		return v.name == name
	end)

	if not item then
		self.game:setUI(FallbackUserInterface(self.game, "", ("%s not found in UserInterfaceModel.items"):format(name)))
		return
	end

	---@type boolean, sphere.IUserInterface | string
	local ok, res = pcall(function()
		return item.object(self.game, item.mount_path)
	end)

	if not ok then
		---@cast res string
		self.game:setUI(FallbackUserInterface(self.game, "", res))
		return
	end

	---@cast res -string
	self.game:setUI(res)
end

return UserInterfaceModel
