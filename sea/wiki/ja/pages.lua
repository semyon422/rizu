---@type sea.Wiki.LanguageMetadata
local t = {
	name = "日本語",
	code = "ja",
	categories = {
		{
			name = "はじめに",
			pages = {
				{ name = "インストール", filename = "installation" },
				{ name = "ヘルプセンター", filename = "help_center" },
				{ name = "osu! から接続", filename = "osu_connect" }
			}
		},
		{
			name = "ゲームクライアント",
			pages = {
				{ name = "曲の追加", filename = "adding_charts" },
				{ name = "スキンの追加", filename = "adding_skins" },
			}
		}
	}
}

return t
