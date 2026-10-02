local SkinResourceContext = require("rizu.skin.SkinResourceContext")

---@class rizu.skin.SkinLoadContext.Options : rizu.skin.SkinResourceContext.Options
---@field game sphere.GameController?
---@field fs fs.IFilesystem?
---@field input_mode string?
---@field screen rizu.skin.Screen?
---@field config rizu.skin.SkinConfig?
---@field config_path string?
---@field module_loader (fun(name: string): any)?

---@class rizu.skin.SkinLoadContext : rizu.skin.SkinResourceContext
---@operator call: rizu.skin.SkinLoadContext
---@field game sphere.GameController
---@field skin_path string
---@field directory_path string
---@field input_mode string
---@field screen rizu.skin.Screen
---@field config rizu.skin.SkinConfig?
---@field config_path string?
---@field fs fs.IFilesystem?
---@field module_loader (fun(name: string): any)?
local SkinLoadContext = SkinResourceContext + {}

---@param options rizu.skin.SkinLoadContext.Options
function SkinLoadContext:new(options)
	SkinResourceContext.new(self, options.fs, options)
	self.game = options.game
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
