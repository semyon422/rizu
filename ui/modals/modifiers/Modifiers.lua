local ButtonsRow = require("ui.modals.config.rows.ButtonsRow")
local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local Form = require("ui.views.form.Form")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NavItem = require("ui.modals.config.NavItem")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local SegmentedRow = require("ui.modals.config.rows.SegmentedRow")
local SliderRow = require("ui.modals.config.rows.SliderRow")
local TimingValueControl = require("ui.views.form.TimingValueControl")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")
local ToggleRow = require("ui.modals.config.rows.ToggleRow")

---Reads and sets one system picker of rizu.api.Play: the hit windows' or the accuracy's.
---@class ui.modals.modifiers.Modifiers.SystemPicker
---@field getSystem fun(): rizu.api.Play.TimingSystem
---@field setSystem fun(name: rizu.api.Play.TimingSystem)
---@field getVersion fun(): integer
---@field setVersion fun(version: 1|2)
---@field getValue fun(): number
---@field setValue fun(value: number)

---A view placed in a rounded group of rows.
---@alias ui.modals.modifiers.Modifiers.Row gui.View|{setting_row: ui.modals.config.rows.SettingRow}

---@class ui.modals.modifiers.Modifiers : ui.ModalView
---@operator call: ui.modals.modifiers.Modifiers
---@field play rizu.api.Play
---@field form ui.views.form.Form
---@field scroll_view gui.ScrollView
---@field background gui.NineSliceUsage
---@field footer_background gui.NineSliceUsage
---@field header_height number
---@field on_edit_columns fun()
---@field scores rizu.api.Scores
---@field private judging_changed boolean
---@field private form_invalidated boolean
local Modifiers = ModalView + {}

local MODAL_WIDTH = 640
local MODAL_HEIGHT = 740
local HEADER_PADDING = {32, 24, 16} -- left, top, bottom
local FOOTER_PADDING_X = 20
local FOOTER_PADDING_Y = 12
local FOOTER_HEIGHT = NavItem.HEIGHT + FOOTER_PADDING_Y * 2
local CONTENT_PADDING = {32, 8, 32, 24}
local ROW_WIDTH = MODAL_WIDTH - CONTENT_PADDING[1] - CONTENT_PADDING[3]
local ROW_CLASSES = {slider = SliderRow, segmented = SegmentedRow}

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

	self.background = NineSliceUsage(Resources.nine_slices.config_v2_modal)
	self.footer_background = NineSliceUsage(Resources.nine_slices.config_v2_footer)

	local title = self:add(Label({font_name = "bold", font_size = 26, text = localization:get("song_select.modifiers_title")}))
	title:setPosition(HEADER_PADDING[1], HEADER_PADDING[2])
	local subtitle = self:add(Label({
		font_name = "regular",
		font_size = 14,
		text = localization:get("song_select.modifiers_subtitle"),
		color = Colors.muted,
	}))
	local subtitle_y = HEADER_PADDING[2] + title:getAuthoredHeight() + 4
	subtitle:setPosition(HEADER_PADDING[1], subtitle_y)
	self.header_height = subtitle_y + subtitle:getAuthoredHeight() + HEADER_PADDING[3]

	local close_text = localization:get("settings.close")
	local close = self:add(NavItem(Resources.sprites.icon_x, close_text, on_close))
	local close_width = Resources.getFont("medium", 14):getWidth(close_text) + 54 -- icon, gap and padding of NavItem
	close:anchorFixed(FOOTER_PADDING_X, MODAL_HEIGHT - FOOTER_HEIGHT + FOOTER_PADDING_Y, close_width, NavItem.HEIGHT)

	self.form = Form({direction = "column", padding = CONTENT_PADDING})
	self.scroll_view = self:add(ScrollView(self.form))
	self.scroll_view:anchorFixed(1, self.header_height, MODAL_WIDTH - 2, MODAL_HEIGHT - self.header_height - FOOTER_HEIGHT - 1)
	self:rebuildForm()
end

function Modifiers:invalidateForm()
	self.form_invalidated = true
end

---Adds a section title and its rows as one rounded group.
---@param title_key string
---@param rows ui.modals.modifiers.Modifiers.Row[]
function Modifiers:addSection(title_key, rows)
	local header = FlowContainer({direction = "row", padding = {0, 24, 0, 8}})
	header:add(Label({font_name = "medium", font_size = 12, text = self.localization:get(title_key), color = Colors.muted}))
	header:fitContent()
	self.form:add(header)
	for index, row in ipairs(rows) do
		---@cast row gui.View|{setting_row: ui.modals.config.rows.SettingRow}
		row:setWidth(ROW_WIDTH)
		row.setting_row:place(self.form, index == 1, index == #rows)
		self.form:add(row)
	end
end

function Modifiers:rebuildForm()
	self.form_invalidated = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local play = self.play
	local localization = self.localization
	local rate_type = play:getRateType()
	local rate, rate_min, rate_max, rate_step = play:getRateValue()

	---@param toggle rizu.api.Play.Toggle
	---@param on_change fun(value: boolean)?
	local function toggleRow(toggle, on_change)
		return ToggleRow({
			text = localization:get("song_select." .. toggle),
			checked = play:getToggle(toggle),
			on_change = on_change or function(value)
				play:setToggle(toggle, value)
			end,
		})
	end

	self:addSection("song_select.modifiers_section_speed", {
		SliderRow({
			label = localization:get("song_select.time_rate"),
			value = rate,
			min = rate_min,
			max = rate_max,
			step = rate_step,
			width = ROW_WIDTH,
			value_format = function(value)
				if rate_type == "linear" then
					return ("%0.2fx"):format(value)
				end
				return ("%+.0f"):format(value)
			end,
			on_change = function(value)
				play:setRateValue(value)
			end,
		}),
		SegmentedRow({
			label = localization:get("song_select.time_rate_type"),
			options = play:getRateTypes(),
			value = rate_type,
			format = function(value)
				return localization:get("song_select.time_rate_type_" .. value)
			end,
			on_change = function(value)
				play:setRateType(value)
				self:invalidateForm()
			end,
		}),
		ToggleRow({
			text = localization:get("song_select.constant_scroll_speed"),
			checked = play:getToggle("constant_scroll"),
			on_change = function(value)
				play:setToggle("constant_scroll", value)
			end,
		}),
	})

	self:addSection("song_select.modifiers_section_notes", {
		ToggleRow({
			text = localization:get("song_select.no_long_notes"),
			checked = play:getToggle("taps_only"),
			on_change = function(value)
				play:setToggle("taps_only", value)
			end,
		}),
	})

	local column_rows = {} ---@type ui.modals.modifiers.Modifiers.Row[]
	for _, toggle in ipairs({"random_columns", "random_sides", "mirror_all", "mirror_left", "mirror_right"}) do
		column_rows[#column_rows + 1] = toggleRow(toggle)
	end
	if #play:getColumnOrder() > 0 then
		column_rows[#column_rows + 1] = ButtonsRow({
			buttons = {
				{text = localization:get("song_select.column_order_mirror"), on_click = function()
					play:mirrorColumns()
				end},
				{text = localization:get("song_select.column_order_random"), on_click = function()
					play:randomizeColumns()
				end},
				{text = localization:get("song_select.column_order_reset"), on_click = function()
					play:setColumnOrder(nil)
				end},
				{text = localization:get("song_select.column_order_edit"), on_click = self.on_edit_columns},
			},
		})
	end
	self:addSection("song_select.modifiers_section_columns", column_rows)

	local judgement_rows = {} ---@type ui.modals.modifiers.Modifiers.Row[]
	---@param row ui.modals.modifiers.Modifiers.Row
	local function add(row)
		judgement_rows[#judgement_rows + 1] = row
	end
	---@param f fun(value: any)
	local function judging(f)
		return function(value)
			f(value)
			self.judging_changed = true
			self:invalidateForm()
		end
	end
	---A system picker for the hit windows or for the accuracy, shown while its auto toggle is off.
	---@param toggle rizu.api.Play.Toggle
	---@param label string
	---@param picker ui.modals.modifiers.Modifiers.SystemPicker
	local function addSystemPicker(toggle, label, picker)
		local auto = play:getToggle(toggle)
		add(toggleRow(toggle, judging(function(value)
			play:setToggle(toggle, value)
		end)))
		if auto then
			return
		end
		local system = TimingSystems.get(picker.getSystem())
		add(SegmentedRow({
			label = label,
			options = play:getTimingSystems(),
			value = system.name,
			format = function(name)
				return TimingSystems.get(name).label
			end,
			on_change = judging(picker.setSystem),
		}))
		if system.score_versions then
			add(SegmentedRow({
				label = localization:get("song_select.osu_score_version"),
				options = system.score_versions,
				value = picker.getVersion(),
				format = function(version)
					return "V" .. version
				end,
				on_change = judging(picker.setVersion),
			}))
		end
		local value_control = TimingValueControl(system, picker.getValue(), ROW_WIDTH, localization,
			function(value)
				-- Not judging(): rebuilding the form would drop the slider while it is dragged.
				picker.setValue(value)
				self.judging_changed = true
			end, ROW_CLASSES)
		if value_control then
			add(value_control --[[@as ui.modals.modifiers.Modifiers.Row]])
		end
	end

	addSystemPicker("auto_timings", localization:get("song_select.hit_windows"), {
		getSystem = function() return play:getTimingSystem() end,
		setSystem = function(name) play:setTimingSystem(name) end,
		getVersion = function() return play:getOsuScoreVersion() end,
		setVersion = function(version) play:setOsuScoreVersion(version) end,
		getValue = function() return play:getTimingValue() end,
		setValue = function(value) play:setTimingValue(value) end,
	})
	addSystemPicker("auto_accuracy", localization:get("song_select.accuracy_system"), {
		getSystem = function() return play:getAccuracySystem() end,
		setSystem = function(name) play:setAccuracySystem(name) end,
		getVersion = function() return play:getAccuracyOsuScoreVersion() end,
		setVersion = function(version) play:setAccuracyOsuScoreVersion(version) end,
		getValue = function() return play:getAccuracyValue() end,
		setValue = function(value) play:setAccuracyValue(value) end,
	})

	local auto_healths = play:getToggle("auto_healths")
	add(toggleRow("auto_healths", function(value)
		play:setToggle("auto_healths", value)
		self:invalidateForm()
	end))

	local gauge = not auto_healths and play:getGauge()
	if gauge then
		local gauge_labels = {
			simple = "osu!mania",
			etterna = "Etterna",
			lr2 = "LR2",
			iidx = "IIDX",
		}
		add(SegmentedRow({
			label = localization:get("song_select.gauge"),
			options = play:getGauges(),
			value = gauge,
			format = function(name)
				return gauge_labels[name]
			end,
			on_change = function(name)
				play:setGauge(name)
				self:invalidateForm()
			end,
		}))
	end
	if gauge == "simple" then
		add(SliderRow({
			label = localization:get("song_select.osu_hp"),
			value = play:getOsuHp(),
			min = 0,
			max = 10,
			step = 0.1,
			width = ROW_WIDTH,
			value_format = function(value)
				return ("HP %.1f"):format(value)
			end,
			on_change = function(value)
				play:setOsuHp(value)
			end,
		}))
	elseif gauge == "etterna" then
		add(SegmentedRow({
			label = localization:get("song_select.etterna_life"),
			options = {1, 2, 3, 4, 5, 6, 7},
			value = play:getEtternaLife(),
			format = function(level)
				return "L" .. level
			end,
			on_change = function(level)
				play:setEtternaLife(level)
			end,
		}))
	elseif gauge == "lr2" then
		local gauge_names = {[0] = "Groove", "Easy", "Hard", "Hazard"}
		add(SegmentedRow({
			label = localization:get("song_select.lr2_gauge"),
			options = {0, 1, 2, 3},
			value = play:getLr2Gauge(),
			format = function(value)
				return gauge_names[value]
			end,
			on_change = function(value)
				play:setLr2Gauge(value)
			end,
		}))
	elseif gauge == "iidx" then
		local gauge_names = {[0] = "Assist Easy", "Easy", "Normal", "Hard", "EX-Hard"}
		add(SegmentedRow({
			label = localization:get("song_select.iidx_gauge"),
			options = {0, 1, 2, 3, 4},
			value = play:getIidxGauge(),
			format = function(value)
				return gauge_names[value]
			end,
			on_change = function(value)
				play:setIidxGauge(value)
			end,
		}))
	end
	self:addSection("song_select.modifiers_section_judgement", judgement_rows)

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
	Painter.setColorRgb(1, 1, 1, 1)
	self.background:draw(self.width, self.height)

	love.graphics.push()
	love.graphics.translate(1, self.height - FOOTER_HEIGHT - 1)
	self.footer_background:draw(self.width - 2, FOOTER_HEIGHT)
	love.graphics.pop()

	Painter.setColorTable(Colors.divider)
	Resources.sprites.pixel:draw(1, self.header_height - 1, 0, self.width - 2, 1)
end

return Modifiers
