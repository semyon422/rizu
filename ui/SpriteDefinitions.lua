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

local function iconTextButton(background_color, stroke_color)
	return {
		width = 27,
		height = 27,
		border_radius = 12,
		slice = 13,
		fills = fills(background_color),
		stroke = stroke_color and {width = 1, color = stroke_color},
	}
end

local function playButton(dark, light)
	return {
		width = 380,
		height = 88,
		border_radius = 14,
		rounding_power = 3,
		slice = 14,
		fills = {{
			type = "linear_gradient",
			angle = 0,
			stops = {
				{offset = 0, color = dark},
				{offset = 1, color = light},
			},
		}},
		stroke = {width = 3, color = {1, 1, 1, 1}},
	}
end

local function pauseButton(top, bottom, stroke)
	return {
		width = 29,
		height = 29,
		border_radius = 13,
		rounding_power = 3,
		slice = 14,
		fills = {{
			type = "linear_gradient",
			angle = 90,
			stops = {
				{offset = 0, color = top},
				{offset = 1, color = bottom},
			},
		}},
		stroke = {width = 2, color = stroke},
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
	volume_overlay = {
		width = 17,
		height = 17,
		border_radius = 7,
		slice = 8,
		fills = fills(Colors.panel),
		stroke = {width = 1, color = Colors.outline},
	},
	gameplay_pause_hold = {
		width = 49,
		height = 49,
		border_radius = 23,
		rounding_power = 4,
		slice = 24,
		fills = fills({0.035, 0.075, 0.15, 0.94}),
		stroke = {width = 2, color = {0.32, 0.56, 0.86, 0.9}},
	},
	gameplay_pause_hold_track = {
		width = 13,
		height = 13,
		border_radius = 6,
		slice = 6,
		fills = fills({0.08, 0.13, 0.22, 1}),
	},
	gameplay_pause_hold_fill = {
		width = 13,
		height = 13,
		border_radius = 6,
		slice = 6,
		fills = fills(Colors.blue),
	},
	gameplay_pause_button_continue = pauseButton({0, 0, 0, 0}, {0, 0, 0, 0}, {0.49, 0.71, 0.21, 0.9}),
	gameplay_pause_button_continue_hover = pauseButton(Colors.success, Colors.success, {0.75, 0.91, 0.49, 1}),
	gameplay_pause_button_continue_pressed = pauseButton({0.31, 0.44, 0.13, 1}, {0.31, 0.44, 0.13, 1}, {0.40, 0.57, 0.18, 0.9}),
	gameplay_pause_button_restart = pauseButton({0, 0, 0, 0}, {0, 0, 0, 0}, {0.44, 0.57, 0.82, 0.8}),
	gameplay_pause_button_restart_hover = pauseButton({0.22, 0.28, 0.46, 1}, {0.22, 0.28, 0.46, 1}, {0.63, 0.76, 1, 0.95}),
	gameplay_pause_button_restart_pressed = pauseButton({0.12, 0.15, 0.27, 1}, {0.12, 0.15, 0.27, 1}, {0.35, 0.46, 0.68, 0.8}),
	gameplay_pause_button_leave = pauseButton({0, 0, 0, 0}, {0, 0, 0, 0}, {0.76, 0.36, 0.62, 0.85}),
	gameplay_pause_button_leave_hover = pauseButton({0.42, 0.15, 0.34, 1}, {0.42, 0.15, 0.34, 1}, {1, 0.53, 0.78, 1}),
	gameplay_pause_button_leave_pressed = pauseButton({0.24, 0.08, 0.20, 1}, {0.24, 0.08, 0.20, 1}, {0.62, 0.27, 0.50, 0.85}),
	icon_text_button_secondary = iconTextButton(Colors.surface, Colors.outline),
	icon_text_button_secondary_hover = iconTextButton(Colors.surface_raised, Colors.outline),
	icon_text_button_danger = iconTextButton({0.71, 0.22, 0.22, 1}),
	icon_text_button_danger_hover = iconTextButton(Colors.danger),
	icon_text_button_success = iconTextButton(Colors.success),
	icon_text_button_success_hover = iconTextButton({0.55, 0.76, 0.28, 1}),
	-- Icon coloured glow fading out upwards, shown while the badge counts something. Drawn at the button height.
	icon_text_button_active = {
		width = 40,
		height = 56,
		border_radius = 12,
		slice = 13,
		fills = {{
			type = "linear_gradient",
			angle = -90,
			stops = {
				{offset = 0, color = {1, 1, 1, 1}},
				{offset = 1, color = {1, 1, 1, 0}},
			},
		}},
	},
	icon_text_button_badge = {
		width = 13,
		height = 13,
		border_radius = 6,
		slice = 6,
		fills = fills({Colors.background[1], Colors.background[2], Colors.background[3], 0.6}),
	},
	button_play = playButton({0.29, 0.48, 0.10, 1}, {0.61, 0.82, 0.31, 1}),
	button_play_pulse = {
		width = 380,
		height = 88,
		border_radius = 14,
		rounding_power = 3,
		slice = 14,
		fills = fills({1, 1, 1, 0}),
		stroke = {width = 3, color = {1, 1, 1, 1}},
	},
	button_play_hover = playButton({0.35, 0.57, 0.13, 1}, {0.69, 0.9, 0.38, 1}),
	button_play_pressed = playButton({0.24, 0.4, 0.08, 1}, {0.48, 0.7, 0.22, 1}),
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
	window_header = {
		width = 35,
		height = 35,
		corner_radii = {top_left = 17, top_right = 17},
		slice = 17,
		fills = fills(Colors.surface_raised),
	},
	window_background = {
		width = 35,
		height = 35,
		corner_radii = {bottom_left = 17, bottom_right = 17},
		slice = 17,
		fills = fills(Colors.panel),
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
	song_select_refresh_notice = {
		width = 17,
		height = 17,
		corner_radii = {top_left = 7, bottom_right = 7},
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
	song_select_toolbar_border = {
		width = 13,
		height = 13,
		border_radius = 5,
		slice = 6,
		fills = fills({1, 1, 1, 0}),
		stroke = {width = 1, color = {1, 1, 1, 1}},
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
	dlc_panel = {
		width = 21,
		height = 21,
		border_radius = 10,
		rounding_power = 4,
		slice = 10,
		fills = fills({1, 1, 1, 1}),
		stroke = {width = 1, color = {1, 1, 1, 1}},
	},
	dlc_list_item = {
		width = 17,
		height = 17,
		border_radius = 8,
		rounding_power = 4,
		slice = 8,
		fills = fills({1, 1, 1, 1}),
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
	-- Result v2 judge line: the round ends; the middle of each segment is the plain pixel sprite.
	judge_line_cap_left = {
		width = 12,
		height = 12,
		corner_radii = {top_left = 6, bottom_left = 6},
		fills = fills({1, 1, 1, 1}),
	},
	judge_line_cap_right = {
		width = 12,
		height = 12,
		corner_radii = {top_right = 6, bottom_right = 6},
		fills = fills({1, 1, 1, 1}),
	},
	-- Result v2 score list: a round solid cap and a fade-out body make the transparent row.
	result_v2_score_cap = {
		width = 12,
		height = 64,
		corner_radii = {top_left = 6, bottom_left = 6},
		fills = fills({1, 1, 1, 1}),
	},
	result_v2_score_fade = {
		width = 64,
		height = 1,
		fills = {{
			type = "linear_gradient",
			angle = 0,
			stops = {
				{offset = 0, color = {1, 1, 1, 1}},
				{offset = 1, color = {1, 1, 1, 0}},
			},
		}},
	},
	result_v2_score_cap_right = {
		width = 12,
		height = 64,
		corner_radii = {top_right = 6, bottom_right = 6},
		fills = fills({1, 1, 1, 1}),
	},
	result_v2_score_body = {
		width = 8,
		height = 1,
		fills = fills({1, 1, 1, 1}),
	},
	-- The dot after the name of the selected score.
	result_v2_score_marker = {
		width = 10,
		height = 10,
		border_radius = 5,
		fills = fills({1, 1, 1, 1}),
	},
	-- Song select v2 chart set rows: rounded caps around a flat body, a difficulty tint fading out
	-- to the right, and an accent outline for the selected row.
	song_set_cap_left = {
		width = 16,
		height = 76,
		corner_radii = {top_left = 8, bottom_left = 8},
		fills = fills({1, 1, 1, 1}),
	},
	song_set_cap_right = {
		width = 16,
		height = 76,
		corner_radii = {top_right = 8, bottom_right = 8},
		fills = fills({1, 1, 1, 1}),
	},
	song_set_body = {
		width = 8,
		height = 76,
		fills = fills({1, 1, 1, 1}),
	},
	song_set_tint = {
		width = 64,
		height = 76,
		fills = {{
			type = "linear_gradient",
			angle = 0,
			stops = {
				{offset = 0, color = {1, 1, 1, 1}},
				{offset = 1, color = {1, 1, 1, 0}},
			},
		}},
	},
	-- Behind the difficulty in the ungrouped chart list.
	song_chart_difficulty_capsule = {
		width = 76,
		height = 36,
		border_radius = 18,
		fills = fills({1, 1, 1, 1}),
	},
	-- Chart rows under an open set in the carousel: the same shapes, shorter.
	song_chart_cap_left = {
		width = 12,
		height = 44,
		corner_radii = {top_left = 6, bottom_left = 6},
		fills = fills({1, 1, 1, 1}),
	},
	song_chart_cap_right = {
		width = 12,
		height = 44,
		corner_radii = {top_right = 6, bottom_right = 6},
		fills = fills({1, 1, 1, 1}),
	},
	song_chart_body = {
		width = 8,
		height = 44,
		fills = fills({1, 1, 1, 1}),
	},
	song_set_outline = {
		width = 21,
		height = 21,
		border_radius = 8,
		slice = 10,
		fills = fills({1, 1, 1, 0}),
		stroke = {width = 2, color = {1, 1, 1, 1}},
	},
	result_v2_score_avatar = {
		width = 52,
		height = 52,
		border_radius = 5,
		fills = fills(Colors.surface),
	},
	-- Result v2 scrims: dark left edge for the stat column, dark bottom for the footer.
	result_v2_scrim_horizontal = {
		width = 64,
		height = 1,
		fills = {{
			type = "linear_gradient",
			angle = 0,
			stops = {
				{offset = 0, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.88}},
				{offset = 0.55, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.55}},
				{offset = 1, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.25}},
			},
		}},
	},
	result_v2_scrim_vertical = {
		width = 1,
		height = 64,
		fills = {{
			type = "linear_gradient",
			angle = 90,
			stops = {
				{offset = 0, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0}},
				{offset = 0.5, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0}},
				{offset = 0.82, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.94}},
				{offset = 1, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0.94}},
			},
		}},
	},
	result_gradient_background = {
		width = 1,
		height = 176,
		fills = {{
			type = "linear_gradient",
			angle = 90,
			stops = {
				{offset = 0, color = {Colors.background[1], Colors.background[2], Colors.background[3], 0}},
				{offset = 1, color = Colors.background},
			},
		}},
	},
}

return SpriteDefinitions
