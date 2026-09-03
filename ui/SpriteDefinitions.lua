---@type {[string]: gui.SpriteGenerator.Definition}
local SpriteDefinitions = {
	chart_grid_item_gradient = {
		width = 110,
		height = 66,
		border_radius = 5,
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
