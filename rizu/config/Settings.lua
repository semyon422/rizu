local Config = require("rizu.config.Config")
local ScrollSpeed = require("rizu.gameplay.ScrollSpeed")

---@class rizu.config.Settings.Keys
local keys = {
	user_interface = "graphics.appearance.user_interface",
	gameplay = {
		speed = "gameplay.speed",
		speed_type = "gameplay.speed_type",
		action_on_fail = "gameplay.action_on_fail",
		scale_speed = "gameplay.scale_speed",
		long_note_shortening = "gameplay.long_note_shortening",
		tempo_factor = "gameplay.tempo_factor",
		primary_tempo = "gameplay.primary_tempo",
		last_mean_values = "gameplay.last_mean_values",
		rating_hit_timing_window = "gameplay.rating_hit_timing_window",
		auto_key_sound = "gameplay.auto_key_sound",
		event_based_render = "gameplay.event_based_render",
		swap_velocity_type = "gameplay.swap_velocity_type",
		skin_resources_top_priority = "gameplay.skin_resources_top_priority",
		hp_shift = "gameplay.hp.shift",
		hp_notes = "gameplay.hp.notes",
		bga_video = "gameplay.bga.video",
		bga_image = "gameplay.bga.image",
		analog_scratch_act_w = "gameplay.analog_scratch.act_w",
		analog_scratch_deact_w = "gameplay.analog_scratch.deact_w",
		analog_scratch_act_period = "gameplay.analog_scratch.act_period",
		analog_scratch_deact_period = "gameplay.analog_scratch.deact_period",
		time_prepare = "gameplay.time.prepare",
		time_play_pause = "gameplay.time.play_pause",
		time_pause_play = "gameplay.time.pause_play",
		time_play_retry = "gameplay.time.play_retry",
		time_pause_retry = "gameplay.time.pause_retry",
		offset_input = "gameplay.offset.input",
		offset_visual = "gameplay.offset.visual",
		offset_format = {},
		offset_audio_mode = {},
	},
	input = {
		pause = "input.pause",
		skip_intro = "input.skip_intro",
		quick_restart = "input.quick_restart",
		quick_quit = "input.quick_quit",
		play_speed_decrease = "input.play_speed.decrease",
		play_speed_increase = "input.play_speed.increase",
		time_rate_decrease = "input.time_rate.decrease",
		time_rate_increase = "input.time_rate.increase",
		select_random = "input.select_random",
		screenshot_capture = "input.screenshot.capture",
		screenshot_open = "input.screenshot.open",
		offset_decrease = "input.offset.decrease",
		offset_increase = "input.offset.increase",
		offset_reset = "input.offset.reset",
	},
	select = {
		primary_mode = "select.primary_mode",
		secondary_mode = "select.secondary_mode",
		diff_column = "select.diff_column",
		locations_in_collections = "select.locations_in_collections",
		collapse = "select.collapse",
		chart_preview = "select.chart_preview",
		filter_string = "select.filter_string",
		lamp_string = "select.lamp_string",
		sort_function = "select.sort_function",
		score_source = "select.score_source",
		score_filter = "select.score_filter",
	},
	timings = {
		arbitrary = "timings.arbitrary",
		sphere = "timings.sphere",
		simple = "timings.simple",
		osuod = "timings.osuod",
		etternaj = "timings.etternaj",
		quaver = "timings.quaver",
		bmsrank = "timings.bmsrank",
		osu_score_version = "timings.osu_score_version",
	},
	replay_base = {
		auto_timings = "replay_base.auto_timings",
	},
	graphics = {
		fps = "graphics.fps",
		unlimited_fps = "graphics.unlimited_fps",
		fullscreen = "graphics.mode.fullscreen",
		fullscreen_type = "graphics.mode.fullscreen_type",
		vsync = "graphics.mode.vsync",
		vsync_on_select = "graphics.vsync_on_select",
		msaa = "graphics.mode.msaa",
		borderless = "graphics.mode.borderless",
		centered = "graphics.mode.centered",
		display = "graphics.mode.display",
		resizable = "graphics.mode.resizable",
		usedpiscale = "graphics.mode.usedpiscale",
		dwmflush = "graphics.dwmflush",
		asynckey = "graphics.asynckey",
		busy_loop_ratio = "graphics.busy_loop_ratio",
		sleep_function = "graphics.sleep_function",
		window_width = "graphics.mode.window.width",
		window_height = "graphics.mode.window.height",
		cursor = "graphics.cursor",
		fonts_dpi = "graphics.fonts_dpi",
		dim_select = "graphics.dim.select",
		dim_gameplay = "graphics.dim.gameplay",
		dim_result = "graphics.dim.result",
		blur_select = "graphics.blur.select",
		blur_gameplay = "graphics.blur.gameplay",
		blur_result = "graphics.blur.result",
		perspective_camera = "graphics.perspective.camera",
		perspective_rx = "graphics.perspective.rx",
		perspective_ry = "graphics.perspective.ry",
	},
	audio = {
		volume_type = "audio.volume_type",
		volume_master = "audio.volume.master",
		volume_music = "audio.volume.music",
		volume_keysounds = "audio.volume.keysounds",
		volume_metronome = "audio.volume.metronome",
		volume_keysounds_format = {},
		sample_gain = "audio.sample_gain",
		adjust_rate = "audio.adjust_rate",
		mode_primary = "audio.mode.primary",
		mode_secondary = "audio.mode.secondary",
		midi_constant_volume = "audio.midi.constant_volume",
		device_period = "audio.device.period",
		device_buffer = "audio.device.buffer",
	},
	misc = {
		auto_update = "misc.auto_update",
		mute_on_unfocus = "misc.mute_on_unfocus",
		show_non_mania_charts = "misc.show_non_mania_charts",
		show_fps = "misc.show_fps",
		show_tasks = "misc.show_tasks",
		show_debug_menu = "misc.show_debug_menu",
		discord_presence = "misc.discord_presence",
		generate_gif_result = "misc.generate_gif_result",
	},
}

for _, format in ipairs({"sphere", "osu", "o2jam", "bms", "stepmania", "quaver", "midi", "ksm"}) do
	keys.audio.volume_keysounds_format[format] = "audio.volume.keysounds_format." .. format
end
for _, format in ipairs({"osu", "qua", "sm", "ksh"}) do
	keys.gameplay.offset_format[format] = "gameplay.offset.format." .. format
end
for _, mode in ipairs({"bass_sample", "bass_fx_tempo"}) do
	keys.gameplay.offset_audio_mode[mode] = "gameplay.offset.audio_mode." .. mode
end

---@class rizu.config.Settings
local Settings = {
	keys = keys,
	-- Compatibility alias for callers being migrated to Settings.keys.
	user_interface = keys.user_interface,
}

---@param filesystem fs.IFilesystem
---@return rizu.config.Config
function Settings.createConfig(filesystem)
	local config = Config(filesystem, "userdata/settings.json")
	local g, i, s, gr, a, m = keys.gameplay, keys.input, keys.select, keys.graphics, keys.audio, keys.misc

	config:setDefaultString(keys.user_interface, "new")

	config:setDefaultNumber(
		g.speed,
		1,
		ScrollSpeed.canonical_min,
		ScrollSpeed.canonical_max,
		ScrollSpeed.ranges.default[3]
	)
	config:setDefaultChoice(g.speed_type, "default", ScrollSpeed.types)
	config:setDefaultChoice(g.action_on_fail, "none", {"none", "pause", "quit"}) -- Should go to UI
	config:setDefaultBoolean(g.scale_speed, false) -- Nobody uses it
	config:setDefaultNumber(g.long_note_shortening, 0, -0.3, 0, 0.01)
	config:setDefaultChoice(g.tempo_factor, "average", {"average", "primary", "minimum", "maximum"})
	config:setDefaultNumber(g.primary_tempo, 120, 60, 240, 1)
	config:setDefaultNumber(g.last_mean_values, 10, 1, 100, 1) -- Should go to UI, also should be removed from score system
	config:setDefaultNumber(g.rating_hit_timing_window, 0.032, 0, 0.2, 0.001) -- Not used anymore
	config:setDefaultBoolean(g.auto_key_sound, false)
	config:setDefaultBoolean(g.event_based_render, false) -- Don't we already use it by default?
	config:setDefaultBoolean(g.swap_velocity_type, false)
	config:setDefaultBoolean(g.skin_resources_top_priority, false)
	config:setDefaultBoolean(g.hp_shift, false) -- Not sure if it works
	config:setDefaultNumber(g.hp_notes, 20, 0, 100, 1) -- Not sure if it works
	config:setDefaultBoolean(g.bga_video, false)
	config:setDefaultBoolean(g.bga_image, false)
	config:setDefaultNumber(g.analog_scratch_act_w, 1 / 3, 0, 2, 1 / 180)
	config:setDefaultNumber(g.analog_scratch_deact_w, 1 / 9, 0, 2, 1 / 180)
	config:setDefaultNumber(g.analog_scratch_act_period, 0.1, 0, 1, 0.001)
	config:setDefaultNumber(g.analog_scratch_deact_period, 0.05, 0, 1, 0.001)

	-- Should to UI
	config:setDefaultNumber(g.time_prepare, 2, 0.5, 3, 0.1)
	config:setDefaultNumber(g.time_play_pause, 0, 0, 2, 0.1)
	config:setDefaultNumber(g.time_pause_play, 0.5, 0, 2, 0.1)
	config:setDefaultNumber(g.time_play_retry, 0.5, 0, 2, 0.1)
	config:setDefaultNumber(g.time_pause_retry, 0.5, 0, 2, 0.1)

	config:setDefaultNumber(g.offset_input, 0, -0.5, 0.5, 0.001)
	config:setDefaultNumber(g.offset_visual, 0, -0.5, 0.5, 0.001)
	local format_defaults = {osu = 0.02, qua = 0.02, sm = -0.05, ksh = 0}
	for format, key in pairs(g.offset_format) do
		config:setDefaultNumber(key, format_defaults[format], -0.5, 0.5, 0.001)
	end
	config:setDefaultNumber(g.offset_audio_mode.bass_sample, 0, -0.5, 0.5, 0.001)
	config:setDefaultNumber(g.offset_audio_mode.bass_fx_tempo, -0.02, -0.5, 0.5, 0.001)

	local chartview_modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}
	config:setDefaultChoice(s.primary_mode, "chartfile_sets", chartview_modes)
	config:setDefaultChoice(s.secondary_mode, "chartmetas", chartview_modes)
	config:setDefaultChoice(s.diff_column, "enps_diff", {"enps_diff", "osu_diff", "msd_diff", "user_diff"})
	config:setDefaultBoolean(s.locations_in_collections, false)
	config:setDefaultBoolean(s.collapse, true) -- Deprecated?
	config:setDefaultBoolean(s.chart_preview, true)
	config:setDefaultString(s.filter_string, "")
	config:setDefaultString(s.lamp_string, "")
	config:setDefaultString(s.sort_function, "title")
	config:setDefaultChoice(s.score_source, "local", {"local", "online"})
	config:setDefaultString(s.score_filter, "No filter")

	local timing_defaults = {
		arbitrary = 0,
		sphere = 0,
		simple = 0.160,
		osuod = 10,
		etternaj = 4,
		quaver = 0,
		bmsrank = 3,
	}
	for name, default in pairs(timing_defaults) do
		config:setDefaultNumber(keys.timings[name], default, 0, 10, 0.01)
	end
	config:setDefaultNumber(keys.timings.osu_score_version, 1, 1, 2, 1)
	config:setDefaultBoolean(keys.replay_base.auto_timings, true)

	config:setDefaultNumber(gr.fps, 240, 30, 1024, 2)
	config:setDefaultBoolean(gr.unlimited_fps, false)
	config:setDefaultBoolean(gr.fullscreen, false)
	config:setDefaultChoice(gr.fullscreen_type, "exclusive", {"desktop", "exclusive"})
	config:setDefaultNumber(gr.vsync, 0, -1, 1, 1)
	config:setDefaultBoolean(gr.vsync_on_select, true)
	config:setDefaultNumber(gr.msaa, 0, 0, 16, 1) -- We don't need it
	config:setDefaultBoolean(gr.borderless, false)
	config:setDefaultBoolean(gr.centered, true)
	config:setDefaultNumber(gr.display, 1, 1, 16, 1)
	config:setDefaultBoolean(gr.resizable, true)
	config:setDefaultBoolean(gr.usedpiscale, true)
	config:setDefaultBoolean(gr.dwmflush, false) -- Windows only
	config:setDefaultBoolean(gr.asynckey, false) -- Windows only
	config:setDefaultNumber(gr.busy_loop_ratio, 0, 0, 1, 0.01)
	config:setDefaultChoice(gr.sleep_function, "love", {"love", "ffi"})
	config:setDefaultNumber(gr.window_width, 1280, 320, 7680, 1)
	config:setDefaultNumber(gr.window_height, 720, 240, 4320, 1)
	config:setDefaultChoice(gr.cursor, "circle", {"circle", "arrow", "system"}) -- Should go to UI

	-- Deprecated
	config:setDefaultNumber(gr.fonts_dpi, 1, 1, 2, 1)
	config:setDefaultNumber(gr.dim_select, 0, 0, 1, 0.01)
	config:setDefaultNumber(gr.dim_gameplay, 0.8, 0, 1, 0.01) -- Should go to UI
	config:setDefaultNumber(gr.dim_result, 0, 0, 1, 0.01)
	config:setDefaultNumber(gr.blur_select, 0, 0, 20, 1)
	config:setDefaultNumber(gr.blur_gameplay, 0, 0, 20, 1)
	config:setDefaultNumber(gr.blur_result, 0, 0, 20, 1)

	config:setDefaultBoolean(gr.perspective_camera, false)
	config:setDefaultBoolean(gr.perspective_rx, false)
	config:setDefaultBoolean(gr.perspective_ry, true)

	config:setDefaultChoice(a.volume_type, "linear", {"linear", "logarithmic"})
	config:setDefaultNumber(a.volume_master, 1, 0, 1, 0.01)
	config:setDefaultNumber(a.volume_music, 1, 0, 1, 0.01)
	config:setDefaultNumber(a.volume_keysounds, 1, 0, 1, 0.01)
	config:setDefaultNumber(a.volume_metronome, 1, 0, 1, 0.01)
	for _, key in pairs(a.volume_keysounds_format) do
		config:setDefaultNumber(key, 1, 0, 1, 0.01)
	end
	config:setDefaultNumber(a.sample_gain, 0, 0, 100, 1) -- Not needed
	config:setDefaultNumber(a.adjust_rate, 0.1, 0, 1, 0.01)
	config:setDefaultChoice(a.mode_primary, "bass_fx_tempo", {"bass_sample", "bass_fx_tempo"})
	config:setDefaultChoice(a.mode_secondary, "bass_sample", {"bass_sample", "bass_fx_tempo"})
	config:setDefaultBoolean(a.midi_constant_volume, false)
	config:setDefaultNumber(a.device_period, 0, 0, 50, 1)
	config:setDefaultNumber(a.device_buffer, 0, 0, 500, 1)

	config:setDefaultBoolean(m.auto_update, true)
	config:setDefaultBoolean(m.mute_on_unfocus, false)
	config:setDefaultBoolean(m.show_non_mania_charts, false)
	config:setDefaultBoolean(m.show_fps, false)
	config:setDefaultBoolean(m.show_tasks, false)
	config:setDefaultBoolean(m.show_debug_menu, false)
	config:setDefaultBoolean(m.discord_presence, true)
	config:setDefaultBoolean(m.generate_gif_result, false)

	return config
end

return Settings
