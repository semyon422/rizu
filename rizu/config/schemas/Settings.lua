local Checkbox = require("rizu.config.kinds.Checkbox")
local Choice = require("rizu.config.kinds.Choice")
local Range = require("rizu.config.kinds.Range")
local Textbox = require("rizu.config.kinds.Textbox")

local audio_modes = {"bass_sample", "bass_fx_tempo"}

---@class rizu.config.schemas.Settings
local schema = {
	gameplay = {
		speed = {
			type = Choice("default", {"default", "osu"}),
			default = Range(1.0, 0.05, 3.0, 0.01),
			osu = Range(1.0, 1, 40.0, 0.5),
			scale_speed_with_rate = Checkbox(false),
		},
		health = {
			auto_shift = Checkbox(false),
			misses_to_fail = Range(20, 0, 100, 1),
		},
		background_animation = {
			video = Checkbox(false),
			image = Checkbox(false),
		},
		time = {
			prepare = Range(2.0, 0.5, 3.0, 0.1),
			play_pause = Range(0.0, 0.0, 2.0, 0.1),
			pause_play = Range(0.5, 0.0, 2.0, 0.1),
			play_retry = Range(0.5, 0.0, 2.0, 0.1),
			pause_retry = Range(0.5, 0.0, 2.0, 0.1),
		},
		scratch = {
			act_w = Range(0.333, 0, 1, 0.001),
			deact_w = Range(0.111, 0, 1, 0.001),
			act_period = Range(0.1, 0, 1, 0.01),
			deact_period = Range(0.05, 0, 1, 0.01),
		},
		behavior = {
			action_on_fail = Choice("none", {"none", "pause", "quit"}),
			auto_key_sound = Checkbox(false),
			event_based_render = Checkbox(false),
			swap_velocity_type = Checkbox(false),
			last_mean_values = Range(10, 1, 100, 1),
			rating_hit_timing_window = Range(0.032, 0, 0.2, 0.001),
			tempo_factor = Choice("average", {"average", "primary", "minimum", "maximum"}),
			primary_tempo = Range(120, 60, 240, 1),
			long_note_shortening = Range(0, -0.3, 0, 0.001),
			skin_resources_top_priority = Checkbox(false),
		},
	},
	graphics = {
		display = {
			fps_limit = Range(240, 30, 1000, 1),
			unlimited_fps = Checkbox(false),
			busy_loop_ratio = Range(0, 0, 1, 0.01),
			sleep_function = Choice("love", {"love", "ffi"}),
			fullscreen = Checkbox(false),
			fullscreen_type = Choice("exclusive", {"desktop", "exclusive"}),
			vsync = Choice(0, {-1, 0, 1}),
			msaa = Choice(0, {0, 1, 2, 4, 8, 16}),
			dwm_flush = Checkbox(false),
			threaded_input = Checkbox(false),
			vsync_on_select = Checkbox(true),
		},
		dim = {
			select = Range(0, 0, 1, 0.01),
			gameplay = Range(0.8, 0, 1, 0.01),
			result = Range(0, 0, 1, 0.01),
		},
		blur = {
			select = Range(0, 0, 20, 1),
			gameplay = Range(0, 0, 20, 1),
			result = Range(0, 0, 20, 1),
		},
		camera = {
			enabled = Checkbox(false),
			rx = Checkbox(false),
			ry = Checkbox(true),
		},
		appearance = {
			cursor = Choice("circle", {"circle", "arrow", "system"}),
			fonts_dpi = Choice(1, {1, 2}),
			user_interface = Choice("new", {"old", "new"}):setDeferred(true),
		},
	},
	audio = {
		volume = {
			type = Choice("linear", {"linear", "logarithmic"}),
			master = Range(0.5, 0, 1, 0.01),
			music = Range(1.0, 0, 1, 0.01),
			keysounds = Range(1.0, 0, 1, 0.01),
			metronome = Range(1.0, 0, 1, 0.01),
		},
		volume_keysounds_format = {
			sphere = Range(1.0, 0, 1, 0.01),
			osu = Range(1.0, 0, 1, 0.01),
			o2jam = Range(1.0, 0, 1, 0.01),
			bms = Range(1.0, 0, 1, 0.01),
			stepmania = Range(1.0, 0, 1, 0.01),
			quaver = Range(1.0, 0, 1, 0.01),
			midi = Range(1.0, 0, 1, 0.01),
			ksm = Range(1.0, 0, 1, 0.01),
		},
		options = {
			sample_gain = Range(0, 0, 100, 1),
			adjust_rate = Range(0.1, 0, 1, 0.01),
			primary_mode = Choice("bass_fx_tempo", audio_modes),
			secondary_mode = Choice("bass_sample", audio_modes),
			midi_constant_volume = Checkbox(false),
		},
		device = {
			period = Range(0, 0, 50, 1),
			buffer = Range(0, 0, 50, 1),
		},
	},
	offsets = {
		global = {
			input = Range(0, -0.5, 0.5, 0.001),
			visual = Range(0, -0.5, 0.5, 0.001),
		},
		format = {
			osu = Range(0.02, -0.5, 0.5, 0.001),
			qua = Range(0.02, -0.5, 0.5, 0.001),
			sm = Range(-0.05, -0.5, 0.5, 0.001),
			ksh = Range(0, -0.5, 0.5, 0.001),
			bms = Range(0, -0.5, 0.5, 0.001),
			mid = Range(0, -0.5, 0.5, 0.001),
			ojn = Range(0, -0.5, 0.5, 0.001),
			sph = Range(0, -0.5, 0.5, 0.001),
		},
		audio_mode = {
			bass_sample = Range(0, -0.5, 0.5, 0.001),
			bass_fx_tempo = Range(-0.02, -0.5, 0.5, 0.001),
		},
	},
	select = {
		mode = {
			primary = Choice("chartfile_sets", {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}),
			secondary = Choice("chartmetas", {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}),
		},
		display = {
			diff_column = Choice("enps_diff", {"enps_diff", "osu_diff", "msd_diff", "user_diff"}),
			chart_preview = Checkbox(true),
		},
	},
	input = {
		hotkeys = {
			pause = Textbox("escape"),
			skip_intro = Textbox("space"),
			quick_restart = Textbox("`"),
			select_random = Textbox("f2"),
			offset_decrease = Textbox("-"),
			offset_increase = Textbox("="),
			offset_reset = Textbox("delete"),
			play_speed_decrease = Textbox("f3"),
			play_speed_increase = Textbox("f4"),
			time_rate_decrease = Textbox("f5"),
			time_rate_increase = Textbox("f6"),
			screenshot_capture = Textbox("f12"),
			screenshot_open = Textbox("lshift"),
		},
	},
	editor = {
		playback = {
			speed = Range(1.0, 0.1, 2.0, 0.1),
			audio_offset = Range(0, -1, 1, 0.001),
			waveform_offset = Range(0, -1, 1, 0.001),
		},
		grid = {
			snap = Range(1, 1, 192, 1),
			lock_snap = Checkbox(true),
		},
		display = {
			show_timings = Checkbox(true),
			tool = Choice("Select", {"Select", "Draw", "Erase"}),
			waveform_opacity = Range(0.5, 0, 1, 0.01),
			waveform_scale = Range(0.5, 0.1, 2.0, 0.1),
		},
	},
	misc = {
		application = {
			auto_update = Checkbox(true),
			mute_on_unfocus = Checkbox(false),
			show_non_mania_charts = Checkbox(false),
			show_fps = Checkbox(false),
			show_tasks = Checkbox(false),
			show_debug_menu = Checkbox(false),
			discord_presence = Checkbox(true),
			generate_gif_result = Checkbox(false),
		},
		idk = {
			timings_arbitrary = Range(0, 0, 100, 0.001),
			timings_sphere = Range(0, 0, 100, 0.001),
			timings_simple = Range(0.160, 0, 100, 0.001),
			timings_osuod = Range(10, 0, 10, 0.1),
			timings_etternaj = Range(4, 0, 10, 0.1),
			timings_quaver = Range(0, 0, 100, 0.001),
			timings_bmsrank = Range(3, 0, 10, 0.1),
			replay_auto_timings = Checkbox(true),
			replay_auto_healths = Checkbox(true),
			replay_auto_const = Checkbox(false),
			replay_auto_tap_only = Checkbox(false),
		}
	}
}

return schema
