---@class sphere.SettingsSelectConfig
---@field primary_mode rizu.library.ChartviewsRepo.Mode
---@field secondary_mode rizu.library.ChartviewsRepo.Mode
---@field collapse boolean Deprecated.
---@field chartviews_table string Deprecated.
---@field diff_column "enps_diff"|"osu_diff"|"msd_diff"|"user_diff"
---@field locations_in_collections boolean
---@field chart_preview boolean

---@class sphere.SettingsConfig
---@field select sphere.SettingsSelectConfig
local settings = {
	audio = {
		adjustRate = 0.1,
		device = {  -- use default
			period = 0,
			buffer = 0,
		},
		midi = {
			constantVolume = false
		},
		mode = {
			primary = "bass_fx_tempo",
			secondary = "bass_sample"
		},
		sampleGain = 0,
		volumeType = "linear",
		volume = {
			keysounds = 1,
			keysounds_format = {
				sphere = 1,
				osu = 1,
				o2jam = 1,
				bms = 1,
				stepmania = 1,
				quaver = 1,
				midi = 1,
				ksm = 1,
			},
			master = 1,
			music = 1,
			metronome = 1,
		}
	},
	editor = {
		audioOffset = 0,
		waveformOffset = 0,
		speed = 1,
		snap = 1,
		lockSnap = true,
		showTimings = true,
		time = 0,
		tool = "Select",
		waveform = {
			opacity = 0.5,
			scale = 0.5
		},
	},
	gameplay = {
		bga = {
			image = false,
			video = false
		},
		hp = {
			shift = false,
			notes = 20,
		},
		autoKeySound = false,
		eventBasedRender = false,
		swapVelocityType = false,
		lastMeanValues = 10,
		longNoteShortening = 0,
		offset = {
			input = 0,
			visual = 0
		},
		offsetScale = {
			input = false,
			visual = false
		},
		offset_format = {
			bms = 0,
			ksh = 0,
			mid = 0,
			ojn = 0,
			osu = 0.02,
			qua = 0.02,
			sph = 0,
			sm = -0.05,
		},
		offset_audio_mode = {
			bass_sample = 0,
			bass_fx_tempo = -0.02,
		},
		actionOnFail = "none",
		ratingHitTimingWindow = 0.032,
		scaleSpeed = false,
		speedType = "default",
		speed = 1,
		tempoFactor = "average",  -- "average", "primary", "minimum", "maximum"
		primaryTempo = 120,
		time = {
			pausePlay = 0.5,
			pauseRetry = 0.5,
			playPause = 0,
			playRetry = 0.5,
			prepare = 2
		},
		analog_scratch = {
			act_period = 0.1,
			act_w = 0.3333333333333333,
			deact_period = 0.05,
			deact_w = 0.1111111111111111
		},
		skin_resources_top_priority = false,
		selected_filters = {},
	},
	graphics = {
		asynckey = false,
		blur = {
			gameplay = 0,
			result = 0,
			select = 0
		},
		cursor = "circle",
		dim = {
			gameplay = 0.8,
			result = 0,
			select = 0
		},
		dwmflush = false,
		fps = 240,
		unlimited_fps = false,
		busy_loop_ratio = 0,
		sleep_function = "love",
		mode = {
			flags = {
				borderless = false,
				centered = true,
				display = 1,
				fullscreen = false,
				fullscreentype = "exclusive",
				highdpi = false,
				msaa = 0,
				resizable = true,
				usedpiscale = true,
				vsync = 0
			},
			fullscreen = {
				height = 720,
				width = 1280
			},
			window = {
				height = 720,
				width = 1280
			}
		},
		perspective = {
			camera = false,
			pitch = 0,
			rx = false,
			ry = true,
			x = 0.5,
			y = 0.5,
			yaw = 0,
			z = -0.71407400337105997
		},
		vsyncOnSelect = true,
		userInterface = "new",
		fonts_dpi = 1,
	},
	input = {
		pause = "escape",
		offset = {
			decrease = "-",
			increase = "=",
			reset = "delete",
		},
		playSpeed = {
			decrease = "f3",
			increase = "f4"
		},
		quickRestart = "`",
		screenshot = {
			capture = "f12",
			open = "lshift"
		},
		selectRandom = "f2",
		skipIntro = "space",
		timeRate = {
			decrease = "f5",
			increase = "f6"
		}
	},
	miscellaneous = {
		autoUpdate = true,
		muteOnUnfocus = false,
		showNonManiaCharts = false,
		showFPS = false,
		showTasks = false,
		showDebugMenu = false,
		discordPresence = true,
		generateGifResult = false,
	},
	select = {
		primary_mode = "chartfile_sets",
		secondary_mode = "chartmetas",
		collapse = true, -- Deprecated
		chartviews_table = "chartviews",  -- Deprecated
		diff_column = "enps_diff",
		locations_in_collections = false,
		chart_preview = true,
	},
	format_timings = {
		sphere = {"sphere"},
		osu = {"osuod", 10},
		o2jam = {"sphere"},
		bms = {"bmsrank", 3},
		stepmania = {"etternaj", 4},
		quaver = {"quaver"},
		midi = {"sphere"},
		ksm = {"sphere"},
		iidx = {"sphere"},
	},
	timings = {
		arbitrary = 0,
		sphere = 0,
		simple = 0.160,
		osuod = 10,
		etternaj = 4,
		quaver = 0,
		bmsrank = 3,
	},
	subtimings = {
		osuod = {"scorev", scorev = 1},
	},
	replay_base = {
		auto_timings = true,
		auto_healths = true,
		auto_const = false,
		auto_tap_only = false,
	}
}

return settings
