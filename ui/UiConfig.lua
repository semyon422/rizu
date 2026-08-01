local Config = require("rizu.config.Config")

---@class ui.UiConfig.Keys
local keys = {
	show_fps = "show_fps",
}

---@class ui.UiConfig : rizu.config.Config
---@overload fun(fs: fs.IFilesystem, path: string): ui.UiConfig
---@field keys ui.UiConfig.Keys
local UiConfig = Config + {}

UiConfig.keys = keys

function UiConfig:new(fs, path)
	Config.new(self, fs, path)

	self:setDefaultBoolean(keys.show_fps, false)
end

return UiConfig
