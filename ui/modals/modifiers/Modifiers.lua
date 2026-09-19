local Checkbox = require("ui.views.form.Checkbox")
local Colors = require("ui.Colors")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Settings = require("rizu.config.Settings")
local Resources = require("ui.Resources")
local Slider = require("ui.views.form.Slider")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

---@class ui.modals.modifiers.Modifiers : ui.ModalView
---@operator call: ui.modals.modifiers.Modifiers
---@field game sphere.GameController
---@field form ui.views.form.Form
---@field form_selection ui.views.form.FormSelection
---@field background gui.NineSliceUsage
---@field private form_invalidated boolean
---@field private on_change fun()?
local Modifiers = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 700
local FORM_WIDTH = 600
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 112

local TIMING_SYSTEMS = {"sphere", "osuod", "etternaj", "quaver", "bmsrank", "iidx"}
local TIMING_SYSTEM_LABELS = {
	sphere = "Rizu",
	osuod = "osu!mania",
	etternaj = "Etterna",
	quaver = "Quaver",
	bmsrank = "LR2",
	iidx = "IIDX",
}
local ETTERNA_JUDGES = {1, 2, 3, 4, 5, 6, 7, 8, 9}
local BMS_RANKS = {3, 2, 1, 0, 4}
local BMS_RANK_LABELS = {
	[3] = "Easy",
	[2] = "Normal",
	[1] = "Hard",
	[0] = "Insane",
	[4] = "Invalid",
}
local OSU_SCORE_VERSIONS = {1, 2}

---@param value number
---@return string
local function formatOsuOd(value)
	return ("OD %g"):format(value)
end

---@param value number
---@return string
local function formatEtternaJudge(value)
	return "J" .. value
end

---@param value number
---@return string
local function formatBmsRank(value)
	return assert(BMS_RANK_LABELS[value], "unknown LR2 timing rank")
end

---@param value number
---@return string
local function formatOsuScoreVersion(value)
	return "V" .. value
end

---@param game sphere.GameController
---@param on_change fun()?
---@param on_close fun()
---@param localization ui.localization.Localization
function Modifiers:new(game, on_change, on_close, localization)
	ModalView.new(self)
	self.localization = localization
	self.game = game
	self.on_change = on_change
	self.form_invalidated = false

	self:setSize(MODAL_WIDTH, MODAL_HEIGHT)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
	self:setOpacity(0)
	self:setVisible(false)
	self:setClip(true)
	self.handles_mouse_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt,
		sprites.nineslice_modal_t,
		sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l,
		sprites.nineslice_modal_c,
		sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb,
		sprites.nineslice_modal_b,
		sprites.nineslice_modal_rb,
	})

	self:add(ModalHeader(self.localization:get("song_select.modifiers_title"),
		self.localization:get("song_select.modifiers_subtitle")))
	self:add(ModalFooter(on_close, self.localization:get("settings.close")))

	self.form = Form({direction = "column", gap = 12})
	self.form:setPosition(FORM_X, FORM_Y)
	self:add(self.form)
	self.form_selection = self:add(FormSelection(self.form))
	self:rebuildForm()
end

function Modifiers:changed()
	self.game.modifierSelectModel:change()
	if self.on_change then
		self.on_change()
	end
end

---@param name string
---@param data number?
---@param score_version number?
function Modifiers:setTimings(name, data, score_version)
	local game = self.game
	local timing_key = Settings.keys.timings[name]
	data = data or (timing_key and game.settings:getNumber(timing_key)) or 0
	if name == "osuod" then
		-- Slider arithmetic can leave values such as 9.7 just below the exact
		-- tenth required by Timings validation.
		data = math.floor(data * 10 + 0.5) / 10
	end
	local timings = Timings(name, data)
	local subtimings ---@type sea.Subtimings?

	if timing_key then
		game.settings:setNumber(timing_key, data)
	end
	if name == "osuod" then
		score_version = score_version or game.settings:getNumber(Settings.keys.timings.osu_score_version)
		game.settings:setNumber(Settings.keys.timings.osu_score_version, score_version)
		subtimings = Subtimings("scorev", score_version)
	end

	game.replayBase.timings = timings
	game.replayBase.subtimings = subtimings
	game.replayBase.timing_values = assert(TimingValuesFactory:get(timings, subtimings))
	self:changed()
end

---@return string
function Modifiers:getTimingSystem()
	local timings = self.game.replayBase.timings
	if timings and TIMING_SYSTEM_LABELS[timings.name] then
		return timings.name
	end
	return "sphere"
end

function Modifiers:invalidateForm()
	self.form_invalidated = true
end

function Modifiers:rebuildForm()
	self.form_invalidated = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local game = self.game
	local replay_base = game.replayBase
	local time_rate_model = game.timeRateModel
	local rate_type = replay_base.rate_type
	local range = assert(time_rate_model.range[rate_type], "unknown time rate type")

	self.form:add(SegmentedControl({
		label = self.localization:get("song_select.time_rate_type"),
		options = time_rate_model.types,
		value = rate_type,
		width = FORM_WIDTH,
		format = function(value)
			return value == "exp" and "Exp" or "Linear"
		end,
		on_change = function(value)
			time_rate_model:setType(value)
			self:changed()
			self:invalidateForm()
		end,
	}))
	self.form:add(Slider({
		label = self.localization:get("song_select.time_rate"),
		value = time_rate_model:get(),
		min = range[1],
		max = range[2],
		step = range[3],
		width = FORM_WIDTH,
		value_format = function(value)
			if rate_type == "linear" then
				return ("%0.2fx"):format(value)
			end
			return ("%+.0f"):format(value)
		end,
		on_change = function(value)
			time_rate_model:set(value)
			self:changed()
		end,
	}))
	self.form:add(Checkbox({
		text = self.localization:get("song_select.constant_scroll_speed"),
		checked = replay_base.const,
		on_change = function(value)
			replay_base.const = value
			self:changed()
		end,
	}))
	self.form:add(Checkbox({
		text = self.localization:get("song_select.no_long_notes"),
		checked = replay_base.tap_only,
		on_change = function(value)
			replay_base.tap_only = value
			self:changed()
		end,
	}))
	local auto_timings = game.settings:getBoolean(Settings.keys.replay_base.auto_timings)
	self.form:add(Checkbox({
		text = self.localization:get("song_select.auto_timings"),
		checked = auto_timings,
		on_change = function(value)
			game.settings:setBoolean(Settings.keys.replay_base.auto_timings, value)
			if not value then
				self:setTimings(self:getTimingSystem())
			else
				self:changed()
			end
			self:invalidateForm()
		end,
	}))

	if not auto_timings then
		local timing_system = self:getTimingSystem()
		self.form:add(SegmentedControl({
			label = self.localization:get("song_select.score_system"),
			options = TIMING_SYSTEMS,
			value = timing_system,
			format = function(value)
				return TIMING_SYSTEM_LABELS[value]
			end,
			on_change = function(value)
				self:setTimings(value)
				self:invalidateForm()
			end,
		}))

		local timings = replay_base.timings or Timings(timing_system,
			game.settings:getNumber(assert(Settings.keys.timings[timing_system])))
		if timing_system == "osuod" then
			self.form:add(SegmentedControl({
				label = self.localization:get("song_select.osu_score_version"),
				options = OSU_SCORE_VERSIONS,
				value = replay_base.subtimings and replay_base.subtimings.data
					or game.settings:getNumber(Settings.keys.timings.osu_score_version),
				format = formatOsuScoreVersion,
				on_change = function(value)
					self:setTimings("osuod", timings.data, value)
				end,
			}))
			self.form:add(Slider({
				label = self.localization:get("song_select.overall_difficulty"),
				value = timings.data,
				min = 0,
				max = 10,
				step = 0.1,
				width = FORM_WIDTH,
				value_format = formatOsuOd,
				on_change = function(value)
					self:setTimings("osuod", value,
						replay_base.subtimings and replay_base.subtimings.data or nil)
				end,
			}))
		elseif timing_system == "etternaj" then
			self.form:add(SegmentedControl({
				label = self.localization:get("song_select.etterna_judge"),
				options = ETTERNA_JUDGES,
				value = timings.data,
				format = formatEtternaJudge,
				on_change = function(value)
					self:setTimings("etternaj", value)
				end,
			}))
		elseif timing_system == "bmsrank" then
			self.form:add(SegmentedControl({
				label = self.localization:get("song_select.bms_rank"),
				options = BMS_RANKS,
				value = timings.data,
				format = formatBmsRank,
				on_change = function(value)
					self:setTimings("bmsrank", value)
				end,
			}))
		end
	end

	self.form:fitContent()

	if selected_index then
		self.form.selected_index = selected_index
		self.form:syncSelection()
	end
end

---@param dt number
function Modifiers:update(dt)
	if self.form_invalidated then
		self:rebuildForm()
	end
end

function Modifiers:show()
	self:rebuildForm()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Modifiers:hide()
	self.form:closeActiveDropdown()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Modifiers:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Modifiers
