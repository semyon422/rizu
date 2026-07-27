---@alias ui.SettingsKind "checkbox"|"choice"|"range"|"textbox"|"list"

---@class ui.SettingSchema
---@field kind ui.SettingsKind?
---@field order integer?
---@field options? any[]
---@field min_value? number
---@field max_value? number
---@field step? number
---@field format? string
---@field item_kind? ui.SettingsKind
---@field deprecated? boolean
---@field read_only? boolean

local order = 0

---@param kind ui.SettingsKind
---@param fields? table
---@return ui.SettingSchema
local function setting(kind, fields)
	order = order + 1
	fields = fields or {}
	fields.kind = kind
	fields.order = order
	return fields
end

---@return ui.SettingSchema
local function Checkbox()
	return setting("checkbox")
end

---@param options any[]
---@return ui.SettingSchema
local function Choice(options)
	return setting("choice", {options = options})
end

---@param min_value number
---@param max_value number
---@param step number
---@param format? string
---@return ui.SettingSchema
local function Range(min_value, max_value, step, format)
	return setting("range", {
		min_value = min_value,
		max_value = max_value,
		step = step,
		format = format,
	})
end

---@return ui.SettingSchema
local function Textbox()
	return setting("textbox")
end

---@param item_kind ui.SettingsKind
---@return ui.SettingSchema
local function List(item_kind)
	return setting("list", {item_kind = item_kind})
end

local audio_modes = {"bass_sample", "bass_fx_tempo"}
local chartview_modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}
local timing_names = {"sphere", "simple", "osuod", "etternaj", "quaver", "bmsrank", "arbitrary"}

-- This schema deliberately mirrors sphere/persistence/ConfigModel/settings.lua.
-- A renderer can recursively walk it and use the same path in the legacy settings table.
---@type {[string|integer]: ui.SettingSchema|table}
local schema = {
	audio = {
		adjustRate = Range(0, 1, 0.01),
		device = {
			period = Range(0, 50, 1, "%d ms"),
			buffer = Range(0, 500, 1, "%d ms"),
		},
		midi = {
			constantVolume = Checkbox(),
		},
		mode = {
			primary = Choice(audio_modes),
			secondary = Choice(audio_modes),
		},
		sampleGain = Range(0, 100, 1, "+%d dB"),
		volumeType = Choice({"linear", "logarithmic"}),
		volume = {
			keysounds = Range(0, 1, 0.01),
			keysounds_format = {
				sphere = Range(0, 1, 0.01),
				osu = Range(0, 1, 0.01),
				o2jam = Range(0, 1, 0.01),
				bms = Range(0, 1, 0.01),
				stepmania = Range(0, 1, 0.01),
				quaver = Range(0, 1, 0.01),
				midi = Range(0, 1, 0.01),
				ksm = Range(0, 1, 0.01),
			},
			master = Range(0, 1, 0.01),
			music = Range(0, 1, 0.01),
			metronome = Range(0, 1, 0.01),
		},
	},
	editor = {
		audioOffset = Range(-1, 1, 0.001, "%.3f s"),
		waveformOffset = Range(-1, 1, 0.001, "%.3f s"),
		speed = Range(0.05, 10, 0.05),
		snap = Range(1, 192, 1),
		lockSnap = Checkbox(),
		showTimings = Checkbox(),
		time = Range(0, 86400, 0.001, "%.3f s"),
		tool = Choice({"Select"}),
		waveform = {
			opacity = Range(0, 1, 0.01),
			scale = Range(0, 2, 0.01),
		},
	},
	gameplay = {
		bga = {
			image = Checkbox(),
			video = Checkbox(),
		},
		hp = {
			shift = Checkbox(),
			notes = Range(0, 100, 1),
		},
		autoKeySound = Checkbox(),
		eventBasedRender = Checkbox(),
		swapVelocityType = Checkbox(),
		lastMeanValues = Range(1, 100, 1),
		longNoteShortening = Range(-0.3, 0, 0.001, "%.3f s"),
		offset = {
			input = Range(-0.5, 0.5, 0.001, "%.3f s"),
			visual = Range(-0.5, 0.5, 0.001, "%.3f s"),
		},
		offsetScale = {
			input = Checkbox(),
			visual = Checkbox(),
		},
		offset_format = {
			bms = Range(-0.5, 0.5, 0.001, "%.3f s"),
			ksh = Range(-0.5, 0.5, 0.001, "%.3f s"),
			mid = Range(-0.5, 0.5, 0.001, "%.3f s"),
			ojn = Range(-0.5, 0.5, 0.001, "%.3f s"),
			osu = Range(-0.5, 0.5, 0.001, "%.3f s"),
			qua = Range(-0.5, 0.5, 0.001, "%.3f s"),
			sph = Range(-0.5, 0.5, 0.001, "%.3f s"),
			sm = Range(-0.5, 0.5, 0.001, "%.3f s"),
		},
		offset_audio_mode = {
			bass_sample = Range(-0.5, 0.5, 0.001, "%.3f s"),
			bass_fx_tempo = Range(-0.5, 0.5, 0.001, "%.3f s"),
		},
		actionOnFail = Choice({"none", "pause", "quit"}),
		ratingHitTimingWindow = Range(0, 0.2, 0.001, "%.3f s"),
		scaleSpeed = Checkbox(),
		speedType = Choice({"default", "osu"}),
		speed = Range(0.05, 40, 0.05),
		tempoFactor = Choice({"average", "primary", "minimum", "maximum"}),
		primaryTempo = Range(60, 240, 1, "%d bpm"),
		time = {
			pausePlay = Range(0, 3, 0.1, "%.1f s"),
			pauseRetry = Range(0, 3, 0.1, "%.1f s"),
			playPause = Range(0, 3, 0.1, "%.1f s"),
			playRetry = Range(0, 3, 0.1, "%.1f s"),
			prepare = Range(0, 3, 0.1, "%.1f s"),
		},
		analog_scratch = {
			act_period = Range(0, 1, 0.001, "%.3f s"),
			act_w = Range(0, 2, 0.001),
			deact_period = Range(0, 1, 0.001, "%.3f s"),
			deact_w = Range(0, 2, 0.001),
		},
		skin_resources_top_priority = Checkbox(),
		selected_filters = List("textbox"),
	},
	graphics = {
		asynckey = Checkbox(),
		blur = {
			gameplay = Range(0, 20, 1),
			result = Range(0, 20, 1),
			select = Range(0, 20, 1),
		},
		cursor = Choice({"circle", "arrow", "system"}),
		dim = {
			gameplay = Range(0, 1, 0.01),
			result = Range(0, 1, 0.01),
			select = Range(0, 1, 0.01),
		},
		dwmflush = Checkbox(),
		fps = Range(30, 1024, 1),
		unlimited_fps = Checkbox(),
		busy_loop_ratio = Range(0, 1, 0.01),
		sleep_function = Choice({"love", "ffi"}),
		mode = {
			flags = {
				borderless = Checkbox(),
				centered = Checkbox(),
				fullscreen = Checkbox(),
				fullscreentype = Choice({"desktop", "exclusive"}),
				highdpi = Checkbox(),
				msaa = Choice({0, 1, 2, 4, 8, 16}),
				resizable = Checkbox(),
				usedpiscale = Checkbox(),
				vsync = Choice({-1, 0, 1}),
			},
			fullscreen = {
				height = Range(240, 4320, 1),
				width = Range(320, 7680, 1),
			},
			window = {
				height = Range(240, 4320, 1),
				width = Range(320, 7680, 1),
			},
		},
		perspective = {
			camera = Checkbox(),
			pitch = Range(-math.pi, math.pi, 0.001),
			rx = Checkbox(),
			ry = Checkbox(),
			x = Range(0, 1, 0.001),
			y = Range(0, 1, 0.001),
			yaw = Range(-math.pi, math.pi, 0.001),
			z = Range(-10, 10, 0.001),
		},
		vsyncOnSelect = Checkbox(),
		userInterface = Choice({"old", "new"}),
		fonts_dpi = Choice({1, 2}),
	},
	input = {
		pause = Textbox(),
		offset = {
			decrease = Textbox(),
			increase = Textbox(),
			reset = Textbox(),
		},
		playSpeed = {
			decrease = Textbox(),
			increase = Textbox(),
		},
		quickRestart = Textbox(),
		screenshot = {
			capture = Textbox(),
			open = Textbox(),
		},
		selectRandom = Textbox(),
		skipIntro = Textbox(),
		timeRate = {
			decrease = Textbox(),
			increase = Textbox(),
		},
	},
	miscellaneous = {
		autoUpdate = Checkbox(),
		muteOnUnfocus = Checkbox(),
		showNonManiaCharts = Checkbox(),
		showFPS = Checkbox(),
		showTasks = Checkbox(),
		showDebugMenu = Checkbox(),
		discordPresence = Checkbox(),
		generateGifResult = Checkbox(),
	},
	select = {
		primary_mode = Choice(chartview_modes),
		secondary_mode = Choice(chartview_modes),
		collapse = setting("checkbox", {deprecated = true}),
		chartviews_table = setting("textbox", {deprecated = true}),
		diff_column = Choice({"enps_diff", "osu_diff", "msd_diff", "user_diff"}),
		locations_in_collections = Checkbox(),
		chart_preview = Checkbox(),
	},
	format_timings = {
		sphere = {[1] = Choice(timing_names)},
		osu = {[1] = Choice(timing_names), [2] = Range(0, 10, 0.01)},
		o2jam = {[1] = Choice(timing_names)},
		bms = {[1] = Choice(timing_names), [2] = Range(0, 10, 0.01)},
		stepmania = {[1] = Choice(timing_names), [2] = Range(0, 10, 0.01)},
		quaver = {[1] = Choice(timing_names)},
		midi = {[1] = Choice(timing_names)},
		ksm = {[1] = Choice(timing_names)},
		iidx = {[1] = Choice(timing_names)},
	},
	timings = {
		arbitrary = Range(0, 1, 0.001),
		sphere = Range(0, 1, 0.001),
		simple = Range(0, 1, 0.001),
		osuod = Range(0, 10, 0.01),
		etternaj = Range(0, 10, 0.01),
		quaver = Range(0, 10, 0.01),
		bmsrank = Range(0, 4, 1),
	},
	subtimings = {
		osuod = {
			[1] = Textbox(),
			scorev = Range(1, 2, 1),
		},
	},
	replay_base = {
		auto_timings = Checkbox(),
		auto_healths = Checkbox(),
		auto_const = Checkbox(),
		auto_tap_only = Checkbox(),
	},
}

return schema
