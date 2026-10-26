local Checkbox = require("ui.views.form.Checkbox")
local Colors = require("ui.Colors")
local ButtonRow = require("ui.views.form.ButtonRow")
local ColumnOrder = require("ui.modals.column_order.ColumnOrder")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local Slider = require("ui.views.form.Slider")
local TimingValueControl = require("ui.views.form.TimingValueControl")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---@class ui.modals.modifiers.Modifiers : ui.ModalView
---@operator call: ui.modals.modifiers.Modifiers
---@field play rizu.api.Play
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field form_selection ui.views.form.FormSelection
---@field background gui.NineSliceUsage
---@field on_edit_columns fun()
---@field scores rizu.api.Scores
---@field private judging_changed boolean
---@field private form_invalidated boolean
local Modifiers = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 800
local FORM_WIDTH = 600
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 112
local FORM_HEIGHT = MODAL_HEIGHT - FORM_Y - 92

---@param play rizu.api.Play
---@param on_close fun()
---@param localization ui.localization.Localization
---@param on_edit_columns fun() Opens the column order modal.
---@param scores rizu.api.Scores Reloaded when the judging changed, to show the accuracies of the new system.
function Modifiers:new(play, on_close, localization, on_edit_columns, scores)
	ModalView.new(self)
	self.localization = localization
	self.play = play
	self.on_edit_columns = on_edit_columns
	self.scores = scores
	self.judging_changed = false
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

	-- The list spans the modal so the selection marker left of the rows is not clipped.
	self.form = Form({direction = "column", gap = 12, padding = {FORM_X, 8, 0, 0}})
	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(0, FORM_Y, MODAL_WIDTH, FORM_HEIGHT)
	self.form_selection = self.scroll_view:add(FormSelection(self.form))
	self:rebuildForm()
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

	local play = self.play
	local rate_type = play:getRateType()
	local rate, rate_min, rate_max, rate_step = play:getRateValue()

	self.form:add(SegmentedControl({
		label = self.localization:get("song_select.time_rate_type"),
		options = play:getRateTypes(),
		value = rate_type,
		width = FORM_WIDTH,
		format = function(value)
			return self.localization:get("song_select.time_rate_type_" .. value)
		end,
		on_change = function(value)
			play:setRateType(value)
			self:invalidateForm()
		end,
	}))
	self.form:add(Slider({
		label = self.localization:get("song_select.time_rate"),
		value = rate,
		min = rate_min,
		max = rate_max,
		step = rate_step,
		width = FORM_WIDTH,
		value_format = function(value)
			if rate_type == "linear" then
				return ("%0.2fx"):format(value)
			end
			return ("%+.0f"):format(value)
		end,
		on_change = function(value)
			play:setRateValue(value)
		end,
	}))
	self.form:add(Checkbox({
		text = self.localization:get("song_select.constant_scroll_speed"),
		checked = play:getToggle("constant_scroll"),
		on_change = function(value)
			play:setToggle("constant_scroll", value)
		end,
	}))
	self.form:add(Checkbox({
		text = self.localization:get("song_select.no_long_notes"),
		checked = play:getToggle("taps_only"),
		on_change = function(value)
			play:setToggle("taps_only", value)
		end,
	}))
	if #play:getColumnOrder() > 0 then
		local row ---@type ui.views.form.ButtonRow
		local function summary()
			return self.localization:get("song_select.column_order_summary",
				{state = ColumnOrder.getStateText(play, self.localization)})
		end
		---@param f fun()
		local function change(f)
			return function()
				f()
				row:setLabel(summary())
			end
		end
		row = self.form:add(ButtonRow({
			label = summary(),
			buttons = {
				{text = self.localization:get("song_select.column_order_mirror"), on_click = change(function()
					play:mirrorColumns()
				end)},
				{text = self.localization:get("song_select.column_order_random"), on_click = change(function()
					play:randomizeColumns()
				end)},
				{text = self.localization:get("song_select.column_order_reset"), on_click = change(function()
					play:setColumnOrder(nil)
				end)},
				{text = self.localization:get("song_select.column_order_edit"), on_click = self.on_edit_columns},
			},
		}))
	end
	---@param f fun(value: any)
	local function judging(f)
		return function(value)
			f(value)
			self.judging_changed = true
			self:invalidateForm()
		end
	end
	local auto_timings = play:getToggle("auto_timings")
	self.form:add(Checkbox({
		text = self.localization:get("song_select.auto_timings"),
		checked = auto_timings,
		on_change = judging(function(value)
			play:setToggle("auto_timings", value)
		end),
	}))

	if not auto_timings then
		local system = TimingSystems.get(play:getTimingSystem())
		self.form:add(SegmentedControl({
			label = self.localization:get("song_select.score_system"),
			options = play:getTimingSystems(),
			value = system.name,
			format = function(name)
				return TimingSystems.get(name).label
			end,
			on_change = judging(function(name)
				play:setTimingSystem(name)
			end),
		}))
		if system.score_versions then
			self.form:add(SegmentedControl({
				label = self.localization:get("song_select.osu_score_version"),
				options = system.score_versions,
				value = play:getOsuScoreVersion(),
				format = function(version)
					return "V" .. version
				end,
				on_change = judging(function(version)
					play:setOsuScoreVersion(version)
				end),
			}))
		end
		if system.name == "etternaj" then
			self.form:add(SegmentedControl({
				label = self.localization:get("song_select.etterna_life"),
				options = {1, 2, 3, 4, 5, 6, 7},
				value = play:getEtternaLife(),
				format = function(level)
					return "L" .. level
				end,
				on_change = function(level)
					play:setEtternaLife(level)
				end,
			}))
		end
		if system.name == "bmsrank" then
			local gauge_names = {[0] = "Groove", "Easy", "Hard", "Hazard"}
			self.form:add(SegmentedControl({
				label = self.localization:get("song_select.lr2_gauge"),
				options = {0, 1, 2, 3},
				value = play:getLr2Gauge(),
				format = function(gauge)
					return gauge_names[gauge]
				end,
				on_change = function(gauge)
					play:setLr2Gauge(gauge)
				end,
			}))
		end
		local value_control = TimingValueControl(system, play:getTimingValue(), FORM_WIDTH, self.localization,
			function(value)
				-- Not judging(): rebuilding the form would drop the slider while it is dragged.
				play:setTimingValue(value)
				self.judging_changed = true
			end)
		if value_control then
			self.form:add(value_control)
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
	if self.judging_changed then
		self.judging_changed = false
		self.scores:refresh()
	end
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
