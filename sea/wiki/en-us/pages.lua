---@type sea.Wiki.LanguageMetadata
local t = {
	name = "English",
	code = "en-us",
	categories = {
		{
			name = "Getting started",
			pages = {
				{ name = "Installation", filename = "installation" },
				{ name = "Help center", filename = "help_center" },
				{ name = "Connecting from osu!", filename = "osu_connect" }
			}
		},
		{
			name = "Game client",
			pages = {
				{ name = "Adding songs/charts", filename = "adding_charts" },
				{ name = "Adding skins", filename = "adding_skins" },
				{ name = "Chart filters", filename = "chart_filters" }
			}
		},
		{
			name = "Community",
			pages = {
				{ name = "The Snicker Boost Method", filename = "community_snicker_boost" }
			}
		}
	}
}

return t
