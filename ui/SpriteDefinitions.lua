---@type {[string]: gui.SpriteGenerator.Definition}
local SpriteDefinitions = {
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
