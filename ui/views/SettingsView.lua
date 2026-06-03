local just = require("just")
local imgui = require("imgui")
local thread = require("thread")
local ModalImView = require("ui.imviews.ModalImView")
local _transform = require("gfx_util").transform
local spherefonts = require("sphere.assets.fonts")
local version = require("version")
local audio = require("audio")
local utf8validate = require("utf8validate")
local fonts = require("sphere.assets.fonts")
local loop = require("rizu.loop.Loop")
local SettingsScheme = require("rizu.config.schemas.Settings")

local transform = {{1 / 2, -16 / 9 / 2}, 0, 0, {0, 1 / 1080}, {0, 1 / 1080}, 0, 0, 0, 0}

local sections = {
	"gameplay",
	"select",
	"graphics",
	"themes",
	"audio",
	"offsets",
	"misc",
}
local section = sections[1]

local scrollY = {}

local w, h = 1024, 1080 / 2
local _h = 55
local r = 8

local window_id = "settings window"

local drawSection = {}

---@param self table?
---@return boolean?
local function draw(self, quit)
	if quit then
		return true
	end

	imgui.setSize(w, h, w / 2, _h)

	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	love.graphics.replaceTransform(_transform(transform))
	love.graphics.translate((1920 - w) / 2, (1080 - h) / 2)

	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, r)
	love.graphics.setColor(1, 1, 1, 1)

	just.push()
	just.push()
	local tabsw
	section, tabsw = imgui.vtabs("settings tabs", section, sections)
	just.pop()
	love.graphics.translate(tabsw, 0)

	local inner_w = w - tabsw
	imgui.setSize(inner_w, h, inner_w / 2, _h)

	scrollY[section] = scrollY[section] or 0
	imgui.Container(window_id, inner_w, h, _h / 3, _h * 2, scrollY[section])

	drawSection[section](self)
	just.emptyline(8)

	scrollY[section] = imgui.Container()
	just.pop()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", 0, 0, w, h, r)
end

---@param id any
---@param v number
---@param label string
---@return number
local function intButtonsMs(id, v, label)
	return imgui.intButtons(id, v * 1000, 1, label) / 1000
end

function drawSection:gameplay()
	local configs = self.game.configModel.configs
	local settings = configs.settings
	local g = settings.gameplay
	local i = settings.input
	local p = configs.play

	local speedModel = self.game.speedModel

	local speedRange = speedModel.range[g.speedType]
	local speedFormat = speedModel.format[g.speedType]
	local newSpeed = imgui.slider1("speed", speedModel:get(), speedFormat, speedRange[1], speedRange[2], speedRange[3], "play speed")
	speedModel:set(newSpeed)

	g.speedType = imgui.combo("speedType", g.speedType, speedModel.types, nil, "speed type")

	g.actionOnFail = imgui.combo("actionOnFail", g.actionOnFail, {"none", "pause", "quit"}, nil, "action on fail")
	g.scaleSpeed = imgui.checkbox("scaleSpeed", g.scaleSpeed, "scale scroll speed with rate")
	g.longNoteShortening = imgui.slider1(
		"shortening", g.longNoteShortening * 1000, "%dms", -300, 0, 10,
		"visual LN shortening") / 1000

	g.tempoFactor = imgui.combo("tempoFactor", g.tempoFactor, {"average", "primary", "minimum", "maximum"}, nil, "tempo factor")
	if g.tempoFactor == "primary" then
		g.primaryTempo = imgui.slider1("primaryTempo", g.primaryTempo, "%d bpm", 60, 240, 1, "primary tempo")
	end

	g.lastMeanValues = imgui.intButtons("lastMeanValues", g.lastMeanValues, 1, "last mean values")
	g.ratingHitTimingWindow = intButtonsMs("ratingHitTimingWindow", g.ratingHitTimingWindow, "rating hit timing window")

	g.autoKeySound = imgui.checkbox("autoKeySound", g.autoKeySound, "auto key sound")
	g.eventBasedRender = imgui.checkbox("eventBasedRender", g.eventBasedRender, "event based render (experimental)")
	g.swapVelocityType = imgui.checkbox("swapVelocityType", g.swapVelocityType, "swap 'current' and 'local' velocity (experimental)")

	g.skin_resources_top_priority = imgui.checkbox("skin_resources_top_priority", g.skin_resources_top_priority, "top priority for skin resources")

	imgui.separator()
	just.indent(10)
	just.text("gauge/hp")
	g.hp.shift = imgui.checkbox("hp.shift", g.hp.shift, "auto shift")
	g.hp.notes = math.min(math.max(imgui.intButtons("hp.notes", g.hp.notes, 1, "misses to fail with full hp"), 0), 100)

	imgui.separator()
	just.indent(10)
	just.text("background animation")
	g.bga.video = imgui.checkbox("bga.video", g.bga.video, "video")
	g.bga.image = imgui.checkbox("bga.image", g.bga.image, "image")

	imgui.separator()
	i.pause = imgui.hotkey("pause", i.pause, "pause")
	i.skipIntro = imgui.hotkey("skipIntro", i.skipIntro, "skip intro")
	i.quickRestart = imgui.hotkey("quickRestart", i.quickRestart, "quick restart")

	imgui.separator()
	imgui.text("Analog scratch (restart required)")
	local ansc = g.analog_scratch
	ansc.act_w = imgui.intButtons("act_w", ansc.act_w * 180, 1, "activation speed (grad per second)") / 180
	ansc.deact_w = imgui.intButtons("deact_w", ansc.deact_w * 180, 1, "deactivation speed (grad per second)") / 180
	ansc.act_period = intButtonsMs("act_period", ansc.act_period, "activation period (ms)")
	ansc.deact_period = intButtonsMs("deact_period", ansc.deact_period, "deactivation period (ms)")

	imgui.separator()
	just.indent(10)
	just.text("time to")
	g.time.prepare = imgui.slider1("time.prepare", g.time.prepare, "%0.1f", 0.5, 3, 0.1, "prepare")
	g.time.playPause = imgui.slider1("time.playPause", g.time.playPause, "%0.1f", 0, 2, 0.1, "play-pause")
	g.time.pausePlay = imgui.slider1("time.pausePlay", g.time.pausePlay, "%0.1f", 0, 2, 0.1, "pause-play")
	g.time.playRetry = imgui.slider1("time.playRetry", g.time.playRetry, "%0.1f", 0, 2, 0.1, "play-retry")
	g.time.pauseRetry = imgui.slider1("time.pauseRetry", g.time.pauseRetry, "%0.1f", 0, 2, 0.1, "pause-retry")

	imgui.separator()
	just.indent(10)
	just.text("play speed")
	i.playSpeed.decrease = imgui.hotkey("playSpeed.decrease", i.playSpeed.decrease, "decrease")
	i.playSpeed.increase = imgui.hotkey("playSpeed.increase", i.playSpeed.increase, "increase")

	imgui.separator()
	just.indent(10)
	just.text("time rate")
	i.timeRate.decrease = imgui.hotkey("timeRate.decrease", i.timeRate.decrease, "decrease")
	i.timeRate.increase = imgui.hotkey("timeRate.increase", i.timeRate.increase, "increase")
end

local diff_columns = {
	"enps_diff",
	"osu_diff",
	"msd_diff",
	"user_diff",
}
local diff_columns_names = {
	enps_diff = "enps",
	osu_diff = "osu",
	msd_diff = "msd",
	user_diff = "user",
}
---@param v number?
---@return string
local function format_diff_columns(v)
	return diff_columns_names[v] or ""
end

local selection_modes = {"chartfile_sets", "chartfiles", "chartmetas", "chartdiffs", "chartplays"}
local selection_modes_names = {
	chartfile_sets = "sets",
	chartfiles = "files",
	chartmetas = "charts",
	chartdiffs = "diffs",
	chartplays = "plays",
}
---@param v string?
---@return string
local function format_selection_mode(v)
	return selection_modes_names[v] or tostring(v)
end

function drawSection:select()
	local settings = self.game.configModel.configs.settings
	local i = settings.input
	local s = settings.select

	s.diff_column = imgui.combo("diff_column", s.diff_column, diff_columns, format_diff_columns, "difficulty")
	s.primary_mode = imgui.combo("primary_mode", s.primary_mode, selection_modes, format_selection_mode, "primary mode")
	s.secondary_mode = imgui.combo("secondary_mode", s.secondary_mode, selection_modes, format_selection_mode, "secondary mode")
	s.chart_preview = imgui.checkbox("s.chart_preview", s.chart_preview, "chart preview")

	imgui.separator()

	i.selectRandom = imgui.hotkey("selectRandom", i.selectRandom, "select random")
	i.screenshot.capture = imgui.hotkey("screenshot.capture", i.screenshot.capture, "capture screenshot")
	i.screenshot.open = imgui.hotkey("screenshot.open", i.screenshot.open, "open screenshot")
end

---@param mode table
---@return string
local function formatMode(mode)
	return mode.width .. "x" .. mode.height
end
local vsyncNames = {
	[1] = "enabled",
	[0] = "disabled",
	[-1] = "adaptive",
}

---@param v number?
---@return string
local function formatVsync(v)
	return vsyncNames[v] or ""
end
function drawSection:graphics()
	local settings = self.game.configModel.configs.settings
	local g = settings.graphics

	g.fps = imgui.intButtons("fps", g.fps, 2, "FPS limit")
	g.unlimited_fps = imgui.checkbox("unlimited_fps", g.unlimited_fps, "unlimited FPS")
	g.busy_loop_ratio = imgui.slider1("busy_loop_ratio", g.busy_loop_ratio, "%0.2f", 0, 1, 0.01, "FPS limiter busy loop ratio")
	g.sleep_function = imgui.combo("g.sleep_function", g.sleep_function, loop.sleep_function_factory:getAvailableTypes(), nil, "sleep function")

	local flags = g.mode.flags
	flags.fullscreen = imgui.checkbox("flags.fullscreen", flags.fullscreen, "fullscreen")
	flags.fullscreentype = imgui.combo("flags.fst", flags.fullscreentype, {"desktop", "exclusive"}, nil, "fullscreen type")
	flags.vsync = imgui.combo("flags.vsync", flags.vsync, {1, 0, -1}, formatVsync, "vsync")
	g.vsyncOnSelect = imgui.checkbox("vsyncOnSelect", g.vsyncOnSelect, "vsync on select")
	flags.msaa = imgui.combo("flags.msaa", flags.msaa, {0, 1, 2, 4, 8, 16}, nil, "MSAA")
	g.dwmflush = imgui.checkbox("dwmflush", g.dwmflush, "DWM flush")
	g.asynckey = imgui.checkbox("asynckey", g.asynckey, "threaded input")

	self.modes = self.modes or love.window.getFullscreenModes()
	g.mode.window = imgui.combo("mode.window", g.mode.window, self.modes, formatMode, "start window resolution")

	g.cursor = imgui.combo("g.cursor", g.cursor, {"circle", "arrow", "system"}, nil, "cursor")

	g.fonts_dpi = imgui.combo("g.fonts_dpi", g.fonts_dpi, {1, 2}, nil, "fonts DPI scale")
	if g.fonts_dpi ~= fonts.dpi then
		fonts.dpi = g.fonts_dpi
		fonts.reset()
	end

	imgui.separator()
	just.indent(10)
	just.text("dim")
	local dim = g.dim
	dim.select = imgui.slider1("dim.select", dim.select, "%0.2f", 0, 1, 0.01, "select")
	dim.gameplay = imgui.slider1("dim.gameplay", dim.gameplay, "%0.2f", 0, 1, 0.01, "gameplay")
	dim.result = imgui.slider1("dim.result", dim.result, "%0.2f", 0, 1, 0.01, "result")

	imgui.separator()
	just.indent(10)
	just.text("blur")
	local blur = g.blur
	blur.select = imgui.slider1("blur.select", blur.select, "%d", 0, 20, 1, "select")
	blur.gameplay = imgui.slider1("blur.gameplay", blur.gameplay, "%d", 0, 20, 1, "gameplay")
	blur.result = imgui.slider1("blur.result", blur.result, "%d", 0, 20, 1, "result")

	imgui.separator()
	just.indent(10)
	just.text("camera")
	local p = g.perspective
	p.camera = imgui.checkbox("p.camera", p.camera, "enable camera")
	p.rx = imgui.checkbox("p.rx", p.rx, "allow rotate x")
	p.ry = imgui.checkbox("p.ry", p.ry, "allow rotate y")

	imgui.separator()
	imgui.text("Renderer")

	local name, version, vendor, device = love.graphics.getRendererInfo()
	imgui.text("name:")
	just.sameline()
	just.offset(120)
	just.text(name)
	imgui.text("version:")
	just.sameline()
	just.offset(120)
	just.text(version)
	imgui.text("vendor:")
	just.sameline()
	just.offset(120)
	just.text(vendor)
	imgui.text("device:")
	just.sameline()
	just.offset(120)
	just.text(device)
end

---@param v sphere.UserInterfaceModel.ItemEntry
---@return string
local function formatThemeName(v)
	return v.display_name
end

function drawSection:themes()
	local settings = self.game.configModel.configs.settings
	local g = settings.graphics

	local ui_model = self.game.uiModel

	imgui.text("Click on any button to switch to a new UI theme")
	imgui.text("Available themes:")
	for i, v in ipairs(ui_model.items) do
		local pressed = imgui.button(v.display_name, v.display_name)

		if pressed then
			self.game.settings_config:setString(
				SettingsScheme.graphics.appearance.user_interface,
				v.name
			)
			self.game.settings_config:commit()
			ui_model:loadSelected()
		end
	end

	imgui.separator()

	imgui.text("Get more themes here:")
	local gameView = self.game.ui.gameView
	if imgui.button("download themes", "download themes") then
		local PackagesView = require("ui.views.PackagesView")
		PackagesView("set_section", "remote")
		gameView:setModal(PackagesView)
	end
end

local _formatModes = {
	bass_sample = "bass sample",
	bass_fx_tempo = "bass fx tempo",
}
local audio_modes = {"bass_sample", "bass_fx_tempo"}

---@param mode string
---@return string
local function formatModes(mode)
	return _formatModes[mode] or mode
end

local function deviceToString(d)
	return d.driver or d.name
	-- return ("%s - %s - %s - %s"):format(d.id, d.name, d.driver, d.flags)
end
function drawSection:audio()
	local settings = self.game.configModel.configs.settings
	local a = settings.audio

	a.volumeType = imgui.combo("a.volumeType", a.volumeType, {"linear", "logarithmic"}, nil, "volume type")

	local v = a.volume
	if a.volumeType == "linear" then
		v.master = imgui.slider1("v.master", v.master, "%0.2f", 0, 1, 0.01, "master")
		v.music = imgui.slider1("v.music", v.music, "%0.2f", 0, 1, 0.01, "music")
		v.keysounds = imgui.slider1("v.keysounds", v.keysounds, "%0.2f", 0, 1, 0.01, "keysounds")
		v.metronome = imgui.slider1("v.metronome", v.metronome, "%0.2f", 0, 1, 0.01, "metronome")
	elseif a.volumeType == "logarithmic" then
		v.master = imgui.lfslider("v.master", v.master, "%ddB", -60, 0, 1, "master")
		v.music = imgui.lfslider("v.music", v.music, "%ddB", -60, 0, 1, "music")
		v.keysounds = imgui.lfslider("v.keysounds", v.keysounds, "%ddB", -60, 0, 1, "keysounds")
		v.metronome = imgui.lfslider("v.metronome", v.metronome, "%ddB", -60, 0, 1, "metronome")
	end

	imgui.separator()
	imgui.text("keysounds per format")
	local kf = v.keysounds_format
	for _, format in ipairs({"sphere", "osu", "o2jam", "bms", "stepmania", "quaver", "midi", "ksm"}) do
		kf[format] = imgui.lfslider("kf." .. format, kf[format], "%ddB", -60, 0, 1, format)
	end

	a.sampleGain = imgui.slider1("sampleGain", a.sampleGain, "+%0.0fdB", 0, 100, 1, "gain with clipping")

	imgui.separator()

	a.adjustRate = imgui.slider1("a.adjustRate", a.adjustRate, "%0.2f", 0, 1, 0.01, "timer adjust rate")

	local mode = a.mode
	mode.primary = imgui.combo(
		"mode.primary", mode.primary, audio_modes, formatModes, "primary audio mode")
	mode.secondary = imgui.combo(
		"mode.secondary", mode.secondary, audio_modes, formatModes, "secondary audio mode")

	a.midi.constantVolume = imgui.checkbox("midi.constantVolume", a.midi.constantVolume, "midi constant volume")

	imgui.separator()

	local audioInfo = audio.getInfo()
	imgui.text("Latency: " .. audioInfo.latency .. "ms")
	local buffer_over_period = math.ceil(a.device.buffer / a.device.period)

	a.device.period = imgui.slider1("d.period", a.device.period, "%dms", 1, 50, 1, "update period")
	just.sameline()
	imgui.indent()
	imgui.url("update period", "link", "https://www.un4seen.com/doc/#bass/BASS_CONFIG_DEV_PERIOD.html", true)

	a.device.buffer = imgui.slider1("d.buffer", buffer_over_period, "%dx" .. a.device.period .. "ms", 2, 10, 1, "buffer length") * a.device.period
	just.sameline()
	imgui.indent()
	imgui.url("dev buffer link", "link", "https://www.un4seen.com/doc/#bass/BASS_CONFIG_DEV_BUFFER.html", true)

	if imgui.button("apply device", "apply") then
		audio.setDevicePeriod(a.device.period)
		audio.setDeviceBuffer(a.device.buffer)
		audio.reinit()
	end
	just.sameline()
	if imgui.button("reset device", "reset") then
		a.device.period = audio.default_dev_period
		a.device.buffer = audio.default_dev_buffer
		audio.setDevicePeriod(a.device.period)
		audio.setDeviceBuffer(a.device.buffer)
		audio.reinit()
	end

	imgui.separator()
	imgui.text("Audio devices:")

	local bass = require("bass")
	local devices = bass.getDevices()
	for _, d in ipairs(devices) do
		local offset = imgui.text(("%s -"):format(d.id), 40, true)
		just.sameline()
		just.indent(10)
		just.text(utf8validate(("%s - %s"):format(d.driver, d.name)))
		just.indent(offset + 10)
		local s = ""
		if d.enabled then s = s .. "enabled " end
		if d.default then s = s .. "default " end
		if d.init then s = s .. "init " end
		imgui.text(s)
	end
end

local formats = {"osu", "qua", "sm", "ksh"}
-- local formats = {"osu", "qua", "sm", "ksh", "bms", "mid", "ojn", "sph"}
function drawSection:offsets()
	local settings = self.game.configModel.configs.settings
	local g = settings.gameplay
	local i = settings.input
	local of = g.offset_format
	local oam = g.offset_audio_mode

	imgui.text("global offsets")
	g.offset.input = intButtonsMs("input offset", g.offset.input, "input offset")
	g.offset.visual = intButtonsMs("visual offset", g.offset.visual, "visual offset")
	-- g.offsetScale.input = imgui.checkbox("offsetScale.input", g.offsetScale.input, "input offset * time rate")
	-- g.offsetScale.visual = imgui.checkbox("offsetScale.visual", g.offsetScale.visual, "visual offset * time rate")

	imgui.separator()
	imgui.text("format offsets")

	for _, format in ipairs(formats) do
		of[format] = intButtonsMs("offset " .. format, of[format], format)
	end

	imgui.separator()
	imgui.text("primary audio mode offsets")

	for _, audio_mode in ipairs(audio_modes) do
		oam[audio_mode] = intButtonsMs("offset " .. audio_mode, oam[audio_mode], formatModes(audio_mode))
	end

	imgui.separator()
	imgui.text("local offset controls")
	i.offset.decrease = imgui.hotkey("offset.decrease", i.offset.decrease, "decrease")
	i.offset.increase = imgui.hotkey("offset.increase", i.offset.increase, "increase")
	i.offset.reset = imgui.hotkey("offset.reset", i.offset.reset, "reset")
end

function drawSection:misc()
	local settings = self.game.configModel.configs.settings
	local m = settings.miscellaneous

	m.autoUpdate = imgui.checkbox("autoUpdate", m.autoUpdate, "auto update")
	m.muteOnUnfocus = imgui.checkbox("muteOnUnfocus", m.muteOnUnfocus, "mute on unfocus")
	m.showNonManiaCharts = imgui.checkbox("showNonManiaCharts", m.showNonManiaCharts, "show non-mania charts")
	m.showFPS = imgui.checkbox("showFPS", m.showFPS, "show FPS")
	m.showTasks = imgui.checkbox("showTasks", m.showTasks, "show tasks")
	m.showDebugMenu = imgui.checkbox("showDebugMenu", m.showDebugMenu, "show debug menu")
	m.discordPresence = imgui.checkbox("discordPresence", m.discordPresence, "discord presence")
	m.generateGifResult = imgui.checkbox("generateGifResult", m.generateGifResult, "generate gif result")

	if imgui.button("error button", "error") then
		error("error")
	end
	if imgui.button("test imgui", "test imgui") then
		self.game.ui.gameView:setModal(require("ui.views.ImguiTestModalView"))
	end

	just.indent(8)
	just.text("Commit: " .. version.commit)
	just.indent(8)
	just.text("Date: " .. version.date)
end

return ModalImView(draw)
