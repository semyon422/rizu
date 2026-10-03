local class = require("class")

---@class rizu.skin.SkinLoadContext
---@operator call: rizu.skin.SkinLoadContext
---@field game sphere.GameController
---@field skin_path string
---@field directory_path string
---@field input_mode string
---@field screen rizu.skin.Screen
---@field config rizu.skin.SkinConfig?
---@field config_path string?
---@field module_loader (fun(name: string): any)?
local SkinLoadContext = class()

---@param options rizu.skin.SkinLoadContext
function SkinLoadContext:new(options)
	self.game = options.game
	self.skin_path = options.skin_path
	self.directory_path = options.directory_path
	self.input_mode = options.input_mode
	self.screen = options.screen
	self.config = options.config
	self.config_path = options.config_path
	self.module_loader = options.module_loader
end

---Loads a module relative to this custom skin, caching its result.
---@param name string Module path without the .lua extension.
---@return any
function SkinLoadContext:loadModule(name)
	assert(self.module_loader, "module loading is only available for custom skins")
	return self.module_loader(name)
end

return SkinLoadContext
