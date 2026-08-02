local RizuUserInterface = require("rizu.app.UserInterface")
local UserInterfaceManager = require("rizu.app.UserInterfaceManager")

local test = {}

local screen_manager = {
	setScreen = function() return false end,
	acceptInputs = function() end,
	receive = function() end,
	update = function() end,
	draw = function() end,
	unload = function() end,
}

local DefaultUserInterface = RizuUserInterface + {}
DefaultUserInterface.name = "default"
DefaultUserInterface.display_name = "Default"
function DefaultUserInterface:new(game, mount_path)
	RizuUserInterface.new(self, game, mount_path, screen_manager)
end

local PluginUserInterface = RizuUserInterface + {}
PluginUserInterface.name = "plugin"
PluginUserInterface.display_name = "Plugin"
function PluginUserInterface:new(game, mount_path)
	RizuUserInterface.new(self, game, mount_path, screen_manager)
end

local CrashingUserInterface = RizuUserInterface + {}
CrashingUserInterface.name = "crashing"
CrashingUserInterface.display_name = "Crashing"
function CrashingUserInterface:new()
	error("plugin constructor failed")
end

local CrashingDefaultUserInterface = RizuUserInterface + {}
CrashingDefaultUserInterface.name = "crashing_default"
CrashingDefaultUserInterface.display_name = "Crashing Default"
function CrashingDefaultUserInterface:new()
	error("default constructor failed")
end

---@param selected string
---@return sphere.GameController
local function createGame(selected)
	---@type sphere.GameController
	local game = {
		settings = {
			getString = function() return selected end,
			setString = function(_, _, value) selected = value end,
		},
		packageManager = {
			getPackagesByType = function() return {} end,
			getPackageDir = function() return nil end,
		},
		setUI = function(self, user_interface) self.ui = user_interface end,
	}
	return game
end

---@param game sphere.GameController
---@param default_ui rizu.app.UserInterface
---@return rizu.app.UserInterfaceManager
local function createManager(game, default_ui)
	local manager = UserInterfaceManager(game, default_ui)
	manager:register(default_ui, "")
	return manager
end

---@param t testing.T
function test.activates_selected_class_with_mount_path(t)
	local game = createGame("plugin")
	local manager = createManager(game, DefaultUserInterface)
	manager:register(PluginUserInterface, "/plugin")

	manager:loadSelected()

	t:assert(PluginUserInterface * game.ui)
	t:eq(game.ui.mount_path, "/plugin")
end

---@param t testing.T
function test.plugin_constructor_failure_falls_back_to_default(t)
	local game = createGame("crashing")
	local manager = createManager(game, DefaultUserInterface)
	manager:register(CrashingUserInterface, "/crashing")

	manager:loadSelected()

	t:assert(DefaultUserInterface * game.ui)
	t:eq(game.settings:getString(), "default")
end

---@param t testing.T
function test.default_constructor_failure_propagates(t)
	local game = createGame("missing")
	local manager = createManager(game, CrashingDefaultUserInterface)

	t:has_error(function()
		manager:loadSelected()
	end)
end

---@param t testing.T
function test.discovers_ui_package_class(t)
	local game = createGame("plugin")
	local manager = createManager(game, DefaultUserInterface)
	package.loaded["test.user_interface"] = PluginUserInterface
	game.packageManager.getPackagesByType = function()
		return {{name = "plugin", types = {ui = "test.user_interface"}}}
	end
	game.packageManager.getPackageDir = function(_, name)
		t:eq(name, "plugin")
		return "/packages/plugin"
	end

	manager:load()
	package.loaded["test.user_interface"] = nil

	t:assert(PluginUserInterface * game.ui)
	t:eq(game.ui.mount_path, "/packages/plugin")
end

return test
