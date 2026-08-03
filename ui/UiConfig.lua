local Config = require("rizu.config.Config")

---@class ui.UiConfig.Keys
local keys = {
	show_fps = "show_fps",
	gameplay_viewport_x = "gameplay_viewport_x",
	gameplay_viewport_y = "gameplay_viewport_y",
	gameplay_viewport_sx = "gameplay_viewport_sx",
	gameplay_viewport_sy = "gameplay_viewport_sy",
}

---@class ui.UiConfig : rizu.config.Config
---@overload fun(fs: fs.IFilesystem, path: string): ui.UiConfig
---@field keys ui.UiConfig.Keys
local UiConfig = Config + {}

UiConfig.keys = keys

function UiConfig:new(fs, path)
	Config.new(self, fs, path)

	self:setDefaultNumber(keys.gameplay_viewport_x, 0)
	self:setDefaultNumber(keys.gameplay_viewport_y, 0)
	self:setDefaultNumber(keys.gameplay_viewport_sx, 1)
	self:setDefaultNumber(keys.gameplay_viewport_sy, 1)
	self:setDefaultBoolean(keys.show_fps, false)
end

return UiConfig
