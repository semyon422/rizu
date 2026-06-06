--- Bancho server configuration.
---
--- Load with: `local config = require("bancho.config.BanchoConfig")(overrides)`
---
--- `overrides` is a table of values that deep-merge into the defaults.
--- See `bancho/config.example.lua` for all available options.

local class = require("class")

--- Deep-copy a table recursively.
---@param src table
---@param dst table
local function copyTable(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			copyTable(v, dst[k])
		else
			dst[k] = v
		end
	end
end

--- Default configuration values.
--- Modified by `bancho/config.lua` at runtime.
---@class bancho.config.BanchoConfig
---@field domain string Server domain (e.g. "rizu.su")
---@field bot_name string Bot player name
---@field bot_id integer Bot player ID
---@field db_path string SQLite database file path
---@field osu_api_key string? Official osu! API v1 key (for beatmap lookup fallback)
---@field mirror_search_endpoint string Beatmap search API endpoint
---@field mirror_download_endpoint string Beatmap download redirect endpoint
---@field beatmaps_path string Directory for .osu files
---@field replays_path string Directory for .osr replay files
---@field screenshots_path string Directory for screenshot files
---@field max_matches integer Maximum concurrent multiplayer rooms
---@field allow_registration boolean Allow in-game registration
---@field disallow_old_clients boolean Reject outdated osu! clients
---@field disallowed_names string[] Names blocked from registration
---@field disallowed_passwords string[] Passwords blocked from registration
---@field command_prefix string In-game command prefix character
---@field menu_icon_url string Main menu icon image URL
---@field menu_onclick_url string Main menu icon click URL
---@field seasonal_backgrounds table[] Seasonal background {file, start, end} tuples
---@field cached_accuracies integer[] Accuracy percentages pre-calculated for /np
---@field channels bancho.config.ChannelDef[] Default channel definitions
---@operator call: bancho.config.BanchoConfig
local BanchoConfig = class()

--- Channel definition for `channels` field.
---@class bancho.config.ChannelDef
---@field name string Channel name (e.g. "#lobby")
---@field topic string Channel topic text
---@field read_priv integer Privilege bitmask required to read
---@field write_priv integer Privilege bitmask required to write
---@field auto_join boolean Whether players auto-join on login
---@field instance boolean Whether channel is auto-deleted when empty

--- Default values applied before user overrides.
BanchoConfig.defaults = {
	domain = "rizu.su",
	bot_name = "bot",
	bot_id = 1,

	db_path = "bancho.db",

	osu_api_key = nil,

	mirror_search_endpoint = "",
	mirror_download_endpoint = "",

	beatmaps_path = "storages/charts",
	replays_path = "storages/replays",
	screenshots_path = "storages/screenshots",

	max_matches = 64,

	allow_registration = false,
	disallow_old_clients = false,
	disallowed_names = {},
	disallowed_passwords = {},

	command_prefix = "!",

	menu_icon_url = "",
	menu_onclick_url = "",

	seasonal_backgrounds = {},

	cached_accuracies = { 50, 60, 70, 80, 90, 95, 99, 100 },

	channels = {
		{ name = "#lobby", topic = "Multiplayer lobby", read_priv = 0, write_priv = 0, auto_join = false, instance = false },
		{ name = "#beginners", topic = "For osu! beginners", read_priv = 0, write_priv = 0, auto_join = true, instance = false },
		{ name = "#general", topic = "General discussion", read_priv = 0, write_priv = 0, auto_join = true, instance = false },
		{ name = "#halp", topic = "Technical support", read_priv = 0, write_priv = 0, auto_join = true, instance = false },
		{ name = "#shout", topic = "Shout channel", read_priv = 0, write_priv = 0, auto_join = false, instance = false },
		{ name = "#announce", topic = "Announcements", read_priv = 1, write_priv = 0, auto_join = true, instance = false },
	},
}

--- Create a configuration with optional overrides.
--- Overrides are deep-merged into defaults so unset fields retain default values.
---@param overrides table? Configuration values to merge into defaults
---@return bancho.config.BanchoConfig
function BanchoConfig:new(overrides)
	local config = {}
	copyTable(BanchoConfig.defaults, config)
	if overrides then
		copyTable(overrides, config)
	end
	return config
end

--- Deep-merge two configuration tables.
--- Values from `overrides` take precedence over `base`.
--- Both tables are left unmodified; a new table is returned.
---@param base table Base configuration
---@param overrides table Override values
---@return table merged
function BanchoConfig:merge(base, overrides)
	local result = {}
	copyTable(base, result)
	copyTable(overrides, result)
	return result
end

return BanchoConfig
