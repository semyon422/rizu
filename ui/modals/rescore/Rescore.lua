local Colors = require("ui.Colors")
local SegmentedControl = require("ui.views.form.SegmentedControl")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")
local TimingValueControl = require("ui.views.form.TimingValueControl")
local delay = require("delay")

---@class ui.modals.rescore.Rescore : ui.ModalView
---@operator call: ui.modals.rescore.Rescore
---@field result rizu.api.Result
---@field form ui.views.form.Form
---@field form_selection ui.views.form.FormSelection
---@field background gui.NineSliceUsage
---@field system string
---@field values {[string]: number}
---@field osu_score_version 1|2
---@field private on_rescored fun()
---@field private form_invalidated boolean
local Rescore = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 480
local FORM_WIDTH = 600
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 112

-- Every value change scores the whole play again, so it waits until the slider rests.
local SLIDER_DEBOUNCE = 0.2

---@param result rizu.api.Result
---@param on_rescored fun() Called after the score was counted again, to show the new numbers.
---@param on_close fun()
---@param localization ui.localization.Localization
function Rescore:new(result, on_rescored, on_close, localization)
	ModalView.new(self)
	self.localization = localization
	self.result = result
	self.on_rescored = on_rescored
	self.form_invalidated = false
	self.system = "sphere"
	self.values = {}
	self.osu_score_version = 1

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

	self:add(ModalHeader(self.localization:get("result.rescore_title"),
		self.localization:get("result.rescore_subtitle")))
	self:add(ModalFooter(on_close, self.localization:get("settings.close")))

	self.form = Form({direction = "column", gap = 12})
	self.form:setPosition(FORM_X, FORM_Y)
	self:add(self.form)
	self.form_selection = self:add(FormSelection(self.form))
	self:rebuildForm()
end

---Takes the system the shown result was judged with as the starting point.
function Rescore:readCurrent()
	if not self.result:hasScore() then
		return
	end
	local judging = self.result:getJudging()
	local timings, subtimings = judging.timings, judging.subtimings
	if not timings or not TimingSystems.isSelectable(timings.name) then
		return
	end
	self.system = timings.name
	self.values[timings.name] = timings.data
	self.osu_score_version = subtimings and subtimings.data or 1
end

function Rescore:apply()
	local value = self.values[self.system] or TimingSystems.get(self.system).default_value
	local ok, err = self.result:rescore(self.system, value, self.osu_score_version)
	if not ok then
		print("rescore failed:", err)
		return
	end
	self.on_rescored()
end

function Rescore:invalidateForm()
	self.form_invalidated = true
end

function Rescore:rebuildForm()
	self.form_invalidated = false
	local selected_index = self.form.selected_index
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	local localization = self.localization
	local system = TimingSystems.get(self.system)

	self.form:add(SegmentedControl({
		label = localization:get("song_select.score_system"),
		options = self.result:getRescoreSystems(),
		value = self.system,
		format = function(v)
			return TimingSystems.get(v).label
		end,
		on_change = function(v)
			self.system = v
			self:apply()
			self:invalidateForm()
		end,
	}))

	if system.score_versions then
		self.form:add(SegmentedControl({
			label = localization:get("song_select.osu_score_version"),
			options = system.score_versions,
			value = self.osu_score_version,
			format = function(v)
				return "V" .. v
			end,
			on_change = function(v)
				self.osu_score_version = v
				self:apply()
			end,
		}))
	end

	local value_control = TimingValueControl(system, self.values[self.system] or system.default_value, FORM_WIDTH,
		localization, function(v)
			self.values[self.system] = v
			delay.debounce(self, "apply_debounce", SLIDER_DEBOUNCE, self.apply, self)
		end)
	if value_control then
		self.form:add(value_control)
	end

	self.form:fitContent()

	if selected_index then
		self.form.selected_index = selected_index
		self.form:syncSelection()
	end
end

---@param dt number
function Rescore:update(dt)
	if self.form_invalidated then
		self:rebuildForm()
	end
end

function Rescore:show()
	self:readCurrent()
	self:rebuildForm()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function Rescore:hide()
	self.form:closeActiveDropdown()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function Rescore:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Rescore
