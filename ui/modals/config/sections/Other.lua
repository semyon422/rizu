local Colors = require("ui.Colors")
local ControlFactory = require("ui.modals.config.ControlFactory")
local Label = require("ui.views.Label")
local Resources = require("ui.Resources")
local Section = require("ui.modals.config.Section")
local Settings = require("rizu.config.Settings")
local version = require("version")

---@class ui.modals.config.sections.Other : ui.modals.config.Section
---@operator call: ui.modals.config.sections.Other
local Other = Section + {}

---@return string build
local function getBuild()
	local build = version.commit ~= "" and version.commit:sub(1, 8) or "dev"
	if version.date ~= "" then
		build = build .. " (" .. version.date .. ")"
	end
	return build
end

---Cheat options only take effect while enabled, so disabling them restores the defaults.
---@param settings rizu.config.Config
local function resetCheatSettings(settings)
	for _, key in ipairs(Settings.cheat_keys) do
		settings:set(key, settings:getDefinition(key).default)
	end
end

---@param settings rizu.config.Config
---@param ui_config ui.UiConfig
---@param localization ui.localization.Localization
function Other:new(settings, ui_config, localization)
	Section.new(self, {
		name = localization:get("settings.other"),
		icon = Resources.sprites.icon_gear,
		build = function(section)
			local keys = Settings.keys.misc
			local build_label = Label({
				font_name = "medium", font_size = 14, color = Colors.muted,
				text = localization:get("settings.build", {commit = getBuild()}),
			})
			-- Not a FormControl, but the settings filter only reads these fields.
			build_label.setting_name = build_label:getText()
			build_label.setting_keywords = {"version", "build", "commit"}
			return {
				ControlFactory.boolean(settings, keys.advanced_options, {
					name = localization:get("settings.advanced_options"),
					keywords = {"advanced", "audio", "latency", "backend", "keysound", "options"},
					tip = localization:get("settings.advanced_options_tip"),
					on_change = function()
						section:invalidate()
					end,
				}),
				ControlFactory.boolean(settings, keys.enable_cheats, {
					name = localization:get("settings.enable_cheats"),
					keywords = {"cheats", "advanced", "gameplay", "tempo", "velocity"},
					tip = localization:get("settings.enable_cheats_tip"),
					on_change = function(enabled)
						if not enabled then
							resetCheatSettings(settings)
						end
						section:invalidate()
					end,
				}),
				ControlFactory.boolean(settings, keys.discord_presence, {
					name = localization:get("settings.discord_presence"),
					keywords = {"discord", "rpc", "presence", "status"},
					tip = localization:get("settings.discord_presence_tip"),
				}),
				ControlFactory.boolean(settings, keys.auto_update, {
					name = localization:get("settings.auto_update"),
					keywords = {"update", "updater", "startup"},
					tip = localization:get("settings.auto_update_tip"),
				}),
				build_label,
			}
		end,
	})
end

return Other
