local Config = require("rizu.config.Config")

---@class ui.UiConfig.Keys
local keys = {
	show_fps = "show_fps",
	gameplay_viewport_x = "gameplay_viewport_x",
	gameplay_viewport_y = "gameplay_viewport_y",
	gameplay_viewport_sx = "gameplay_viewport_sx",
	gameplay_viewport_sy = "gameplay_viewport_sy",
	command_palette_bindings = "command_palette_bindings",
	open_config_bindings = "open_config_bindings",
	accept_bindings = "accept_bindings",
	cancel_bindings = "cancel_bindings",
	left_bindings = "left_bindings",
	right_bindings = "right_bindings",
	up_bindings = "up_bindings",
	down_bindings = "down_bindings",
	gameplay_skip_intro_bindings = "gameplay_skip_intro_bindings",
	editor_toggle_playback_bindings = "editor_toggle_playback_bindings",
	toggle_audio_preview_bindings = "toggle_audio_preview_bindings",
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
	self:setDefaultKeyBindings(keys.command_palette_bindings, {{key = ";", shift = true}})
	self:setDefaultKeyBindings(keys.open_config_bindings, {{key = "o", control = true}})
	self:setDefaultKeyBindings(keys.accept_bindings, {{key = "return"}, {key = "kpenter"}})
	self:setDefaultKeyBindings(keys.cancel_bindings, {{key = "escape"}})
	self:setDefaultKeyBindings(keys.left_bindings, {{key = "left", allow_repeat = true}})
	self:setDefaultKeyBindings(keys.right_bindings, {{key = "right", allow_repeat = true}})
	self:setDefaultKeyBindings(keys.up_bindings, {{key = "up", allow_repeat = true}})
	self:setDefaultKeyBindings(keys.down_bindings, {{key = "down", allow_repeat = true}})
	self:setDefaultKeyBindings(keys.gameplay_skip_intro_bindings, {{key = "space"}})
	self:setDefaultKeyBindings(keys.editor_toggle_playback_bindings, {{key = "space"}})
	self:setDefaultKeyBindings(keys.toggle_audio_preview_bindings, {{key = "p", control = true}})
end

return UiConfig
