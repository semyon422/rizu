---@type sea.Wiki.LanguageMetadata
local t = {
	name = "Русский",
	code = "ru",
	categories = {
		{
			name = "Знакомство",
			pages = {
				{ name = "Установка", filename = "installation" },
				{ name = "Помощь", filename = "help_center" },
			}
		},
		{
			name = "Игровой клиент",
			pages = {
				{ name = "Добавление карт/музыки", filename = "adding_charts" },
				{ name = "Добавление скинов", filename = "adding_skins" },
				{ name = "Фильтры карт", filename = "chart_filters" },
			}
		}
	}
}

return t
