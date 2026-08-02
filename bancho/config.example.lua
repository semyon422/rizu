--- Example bancho server configuration.
---
--- Copy this file to `bancho/config.lua` and edit for your server.
--- `bancho/config.lua` is gitignored; this file is not.
---
--- Only the fields you want to change need to be present.
--- Missing fields fall back to defaults in `bancho/config/BanchoConfig.lua`.

local BanchoConfig = require("bancho.config.BanchoConfig")

return BanchoConfig:new({
	--- Server identity
	--- Domain used for all osu! client endpoints (osu.{domain})
	domain = "rizu.su",

	--- Bot player that appears online and responds to commands
	bot_name = "bot",
	bot_id = 1,

	--- Official osu! API v1 key
	--- Required for beatmap lookup when local .osu file is missing.
	--- Obtain from https://osu.ppy.sh/p/api
	osu_api_key = "your_api_key_here",

	--- Beatmap mirrors
	--- Used by osu-search.php to proxy beatmap search results
	mirror_search_endpoint = "",  -- e.g. "https://quasibit.nebelwelt.net/api/get_beatmaps"
	mirror_download_endpoint = "",  -- e.g. "https://quasibit.nebelwelt.net/d"

	--- File storage directories
	beatmaps_path = "server-state/storages/charts",
	replays_path = "server-state/storages/replays",
	screenshots_path = "server-state/storages/screenshots",

	--- Maximum number of concurrent multiplayer rooms
	max_matches = 64,

	--- In-game registration is disabled while account ownership lives in Sea.
	allow_registration = false,

	--- Reject clients older than the latest major osu! release
	disallow_old_clients = false,

	--- Names that cannot be used during registration
	disallowed_names = { "Admin", "Moderator", "Banned" },

	--- Passwords that cannot be used during registration
	disallowed_passwords = { "password", "123456", "password123" },

	--- Prefix character for in-game commands (e.g. "!help")
	command_prefix = "!",

	--- Main menu icon shown on the osu! client's main menu
	menu_icon_url = "",
	menu_onclick_url = "",

	--- Seasonal backgrounds: list of { file, start_epoch, end_epoch } tuples
	seasonal_backgrounds = {},

	--- Accuracy percentages pre-calculated for /np PP responses
	cached_accuracies = { 50, 60, 70, 80, 90, 95, 99, 100 },

	--- Default channels
	channels = {
		{ name = "#lobby", topic = "Multiplayer lobby", read_priv = 0, write_priv = 0, auto_join = false, instance = false },
		{ name = "#beginners", topic = "For osu! beginners", read_priv = 0, write_priv = 0, auto_join = true, instance = false },
		{ name = "#general", topic = "General discussion", read_priv = 0, write_priv = 0, auto_join = true, instance = false },
		{ name = "#halp", topic = "Technical support", read_priv = 0, write_priv = 0, auto_join = true, instance = false },
		{ name = "#shout", topic = "Shout channel", read_priv = 0, write_priv = 0, auto_join = false, instance = false },
		{ name = "#announce", topic = "Announcements", read_priv = 1, write_priv = 0, auto_join = true, instance = false },
	},
})
