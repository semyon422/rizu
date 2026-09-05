local Colors = require("ui.Colors")

local function button(background_color, capsule)
	local size = capsule and 39 or 23
	return {
		width = size,
		height = size,
		border_radius = capsule and 19 or 6,
		rounding_power = capsule and 2 or 3,
		slice = capsule and 19 or 11,
		background_color = background_color,
	}
end

---@type {[string]: gui.SpriteGenerator.Definition}
local SpriteDefinitions = {
	button_primary = button(Colors.blue),
	button_primary_hover = button({0.30, 0.43, 0.75, 1}),
	button_primary_pressed = button({0.24, 0.34, 0.59, 1}),
	button_secondary = button(Colors.surface_raised),
	button_secondary_hover = button({0.32, 0.28, 0.42, 1}),
	button_secondary_pressed = button(Colors.surface),
	button_danger = button({0.71, 0.22, 0.22, 1}),
	button_danger_hover = button(Colors.danger),
	button_danger_pressed = button({0.55, 0.16, 0.18, 1}),
	button_primary_capsule = button(Colors.blue, true),
	button_primary_capsule_hover = button({0.30, 0.43, 0.75, 1}, true),
	button_primary_capsule_pressed = button({0.24, 0.34, 0.59, 1}, true),
	button_secondary_capsule = button(Colors.surface_raised, true),
	button_secondary_capsule_hover = button({0.32, 0.28, 0.42, 1}, true),
	button_secondary_capsule_pressed = button(Colors.surface, true),
	button_danger_capsule = button({0.71, 0.22, 0.22, 1}, true),
	button_danger_capsule_hover = button(Colors.danger, true),
	button_danger_capsule_pressed = button({0.55, 0.16, 0.18, 1}, true),
	button_success = button(Colors.success),
	button_success_hover = button({0.55, 0.76, 0.28, 1}),
	button_success_pressed = button({0.39, 0.56, 0.16, 1}),
	button_success_capsule = button(Colors.success, true),
	button_success_capsule_hover = button({0.55, 0.76, 0.28, 1}, true),
	button_success_capsule_pressed = button({0.39, 0.56, 0.16, 1}, true),
	song_select_panel = {
		width = 17,
		height = 17,
		border_radius = 7,
		slice = 8,
		background_color = Colors.panel,
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_summary = {
		width = 15,
		height = 15,
		border_radius = 6,
		slice = 7,
		background_color = Colors.panel,
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_toolbar_control = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		background_color = {1, 1, 1, 1},
	},
	song_select_search = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		background_color = Colors.surface,
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_session = {
		width = 11,
		height = 11,
		border_radius = 4,
		slice = 5,
		background_color = {1, 1, 1, 1},
	},
	song_select_chevron = {
		width = 38,
		height = 66,
		border_radius = 4,
		background_color = {1, 1, 1, 1},
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
		background_color = {1, 1, 1, 1},
	},
	chart_grid_item_selected = {
		width = 110,
		height = 66,
		border_radius = 8,
		rounding_power = 4,
		background_color = {1, 1, 1, 0},
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
