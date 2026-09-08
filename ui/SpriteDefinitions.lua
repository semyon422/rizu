local Colors = require("ui.Colors")

local function fills(color)
	return {{type = "color", color = color}}
end

local function button(background_color, capsule)
	local size = capsule and 39 or 23
	return {
		width = size,
		height = size,
		border_radius = capsule and 19 or 6,
		rounding_power = capsule and 2 or 3,
		slice = capsule and 19 or 11,
		fills = fills(background_color),
	}
end

local function mix(a, b, amount)
	return {
		a[1] + (b[1] - a[1]) * amount,
		a[2] + (b[2] - a[2]) * amount,
		a[3] + (b[3] - a[3]) * amount,
		(a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * amount,
	}
end

local function loadoutGradient(control_color, active, hovered)
	local top_mix = hovered and 0.48 or 0.34
	local bottom_mix = hovered and 0.26 or 0.16
	local top = active and mix(control_color, Colors.text, hovered and 0.28 or 0.15)
		or mix(Colors.surface, control_color, top_mix)
	local bottom = active and mix(Colors.background, control_color, hovered and 0.72 or 0.60)
		or mix(Colors.surface, control_color, bottom_mix)
	local stops = {
		{offset = 0, color = top},
		{offset = 1, color = bottom},
	}
	if active then
		-- Preserve the webclient's distinct base-color midpoint instead of
		-- reducing the active treatment to an almost uniform color wash.
		stops = {
			{offset = 0, color = top},
			{offset = 0.42, color = control_color},
			{offset = 1, color = bottom},
		}
	end
	return {
		width = 2,
		height = 46,
		fills = {{
			type = "linear_gradient",
			angle = 90,
			stops = stops,
		}},
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
	modal_header = {
		width = 35,
		height = 35,
		corner_radii = {top_left = 17, top_right = 17},
		slice = 17,
		fills = fills(Colors.panel),
		stroke = {width = {bottom = 1}, color = Colors.border_subtle},
	},
	modal_footer = {
		width = 35,
		height = 35,
		corner_radii = {bottom_left = 17, bottom_right = 17},
		slice = 17,
		fills = fills(Colors.surface),
	},
	radio_body = {
		width = 20,
		height = 20,
		border_radius = 10,
		fills = fills(Colors.background),
	},
	radio_mark = {
		width = 10,
		height = 10,
		border_radius = 5,
		fills = fills(Colors.accent),
	},
	note_skin_item = {
		width = 17,
		height = 17,
		border_radius = 8,
		slice = 8,
		fills = fills(Colors.surface),
	},
	note_skin_item_hover = {
		width = 17,
		height = 17,
		border_radius = 8,
		slice = 8,
		fills = fills(Colors.surface_raised),
	},
	note_skin_item_selected = {
		width = 17,
		height = 17,
		border_radius = 8,
		slice = 8,
		fills = fills(mix(Colors.surface, Colors.blue, 0.2)),
		stroke = {width = 1, color = mix(Colors.outline, Colors.blue, 0.4)},
	},
	song_select_loadout_success = loadoutGradient(Colors.success),
	song_select_loadout_success_hover = loadoutGradient(Colors.success, false, true),
	song_select_loadout_success_active = loadoutGradient(Colors.success, true),
	song_select_loadout_success_active_hover = loadoutGradient(Colors.success, true, true),
	song_select_loadout_magenta = loadoutGradient(Colors.magenta),
	song_select_loadout_magenta_hover = loadoutGradient(Colors.magenta, false, true),
	song_select_loadout_magenta_active = loadoutGradient(Colors.magenta, true),
	song_select_loadout_magenta_active_hover = loadoutGradient(Colors.magenta, true, true),
	song_select_loadout_purple = loadoutGradient(Colors.purple),
	song_select_loadout_purple_hover = loadoutGradient(Colors.purple, false, true),
	song_select_loadout_blue = loadoutGradient(Colors.blue),
	song_select_loadout_blue_hover = loadoutGradient(Colors.blue, false, true),
	song_select_panel = {
		width = 17,
		height = 17,
		border_radius = 7,
		slice = 8,
		fills = fills(Colors.panel),
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_summary = {
		width = 15,
		height = 15,
		border_radius = 6,
		slice = 7,
		fills = fills(Colors.panel),
	},
	chart_summary_chip = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		fills = fills({1, 1, 1, 1}),
	},
	tooltip = {
		width = 11,
		height = 11,
		border_radius = 4,
		slice = 5,
		fills = fills(Colors.surface_raised),
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_toolbar_control = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		fills = fills({1, 1, 1, 1}),
	},
	song_select_search = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		fills = fills(Colors.surface),
		stroke = {width = 1, color = Colors.outline},
	},
	song_select_session = {
		width = 11,
		height = 11,
		border_radius = 4,
		slice = 5,
		fills = fills({1, 1, 1, 1}),
	},
	song_select_chevron = {
		width = 38,
		height = 66,
		border_radius = 4,
		fills = fills({1, 1, 1, 1}),
	},
	chart_grid_item = {
		width = 110,
		height = 66,
		border_radius = 8,
		rounding_power = 4,
		fills = fills({1, 1, 1, 1}),
	},
	chart_grid_item_selected = {
		width = 110,
		height = 66,
		border_radius = 8,
		rounding_power = 4,
		fills = fills({1, 1, 1, 0}),
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
		fills = {{
			type = "linear_gradient",
			angle = -90,
			stops = {
				{offset = 0, color = {1, 1, 1, 1}},
				{offset = 1, color = {1, 1, 1, 0}},
			},
		}},
	},
	result_judge_gradient = {
		width = 64,
		height = 1,
		fills = {{
			type = "linear_gradient",
			angle = 0,
			stops = {
				{offset = 0, color = {1, 1, 1, 0.7}},
				{offset = 1, color = {1, 1, 1, 0}},
			},
		}},
	},
}

return SpriteDefinitions
