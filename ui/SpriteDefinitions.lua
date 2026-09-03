local Colors = require("ui.Colors")

---@type {[string]: gui.SpriteGenerator.Definition}
local SpriteDefinitions = {
	song_select_panel = {
		width = 17,
		height = 17,
		border_radius = 7,
		slice = 8,
		linear_gradient = {angle = 0, colors = {Colors.panel, Colors.panel}},
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_summary = {
		width = 15,
		height = 15,
		border_radius = 6,
		slice = 7,
		linear_gradient = {angle = 0, colors = {Colors.panel, Colors.panel}},
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_toolbar_control = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		linear_gradient = {angle = 0, colors = {{1, 1, 1, 1}, {1, 1, 1, 1}}},
	},
	song_select_search = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		linear_gradient = {angle = 0, colors = {Colors.surface, Colors.surface}},
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_session = {
		width = 11,
		height = 11,
		border_radius = 4,
		slice = 5,
		linear_gradient = {angle = 0, colors = {{1, 1, 1, 1}, {1, 1, 1, 1}}},
	},
	song_select_chevron = {
		width = 38,
		height = 66,
		border_radius = 4,
		linear_gradient = {angle = 0, colors = {{1, 1, 1, 1}, {1, 1, 1, 1}}},
	},
	chart_summary_difficulty_gradient = {
		width = 285,
		height = 66,
		linear_gradient = {
			angle = 0,
			colors = {
				{1, 1, 1, 1},
				{1, 1, 1, 0},
			},
		},
	},
	chart_grid_item = {
		width = 110,
		height = 66,
		border_radius = 8,
		rounding_power = 4,
		linear_gradient = {
			angle = 0,
			colors = {
				{1, 1, 1, 1},
				{1, 1, 1, 1},
			},
		},
	},
	chart_grid_item_selected = {
		width = 110,
		height = 66,
		border_radius = 8,
		rounding_power = 4,
		linear_gradient = {
			angle = 0,
			colors = {
				{1, 1, 1, 0},
				{1, 1, 1, 0},
			},
		},
		stroke = {
			width = {bottom = 3},
			color = {1, 1, 1, 1},
		},
	},
	chart_grid_item_gradient = {
		width = 110,
		height = 66,
		border_radius = 8,
		rounding_power = 4,
		linear_gradient = {
			angle = -90,
			colors = {
				{1, 1, 1, 1},
				{1, 1, 1, 0},
			},
		},
	},
}

return SpriteDefinitions
