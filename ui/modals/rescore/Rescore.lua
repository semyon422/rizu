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
local Slider = require("ui.views.form.Slider")
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

-- Every slider step scores the whole play again, so it waits until the slider rests.
local SLIDER_DEBOUNCE = 0.2

local SYSTEM_LABELS = {
	sphere = "Rizu",
	osuod = "osu!mania",
	etternaj = "Etterna",
	quaver = "Quaver",
	bmsrank = "LR2",
	iidx = "IIDX",
}
local DEFAULT_VALUES = {osuod = 8, etternaj = 4, bmsrank = 3}
local ETTERNA_JUDGES = {4, 5, 6, 7, 8, 9}
local BMS_RANKS = {3, 2, 1, 0, 4}
local BMS_RANK_LABELS = {
	[3] = "Easy",
	[2] = "Normal",
	[1] = "Hard",
	[0] = "Insane",
	[4] = "Invalid",
}
local OSU_SCORE_VERSIONS = {1, 2}

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
	if not timings or not SYSTEM_LABELS[timings.name] then
		return
	end
	self.system = timings.name
	self.values[timings.name] = timings.data
	self.osu_score_version = subtimings and subtimings.data or 1
end

function Rescore:apply()
	local value = self.values[self.system] or DEFAULT_VALUES[self.system]
	local ok, err = self.result:rescore(self.system, value, self.osu_score_version)
	if not ok then
		print("rescore failed:", err)
		return
	end
	self.on_rescored()
end

---@param system string
---@param value number
function Rescore:setValue(system, value)
	self.values[system] = value
	self:apply()
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
	local system = self.system
	local value = self.values[system] or DEFAULT_VALUES[system]

	self.form:add(SegmentedControl({
		label = localization:get("song_select.score_system"),
		options = self.result:getRescoreSystems(),
		value = system,
		format = function(v)
			return SYSTEM_LABELS[v]
		end,
		on_change = function(v)
			self.system = v
			self:apply()
			self:invalidateForm()
		end,
	}))

	if system == "osuod" then
		self.form:add(SegmentedControl({
			label = localization:get("song_select.osu_score_version"),
			options = OSU_SCORE_VERSIONS,
			value = self.osu_score_version,
			format = function(v)
				return "V" .. v
			end,
			on_change = function(v)
				self.osu_score_version = v
				self:apply()
			end,
		}))
		self.form:add(Slider({
			label = localization:get("song_select.overall_difficulty"),
			value = value,
			min = 0,
			max = 10,
			step = 0.1,
			width = FORM_WIDTH,
			value_format = function(v)
				return ("OD %g"):format(v)
			end,
			on_change = function(v)
				self.values[system] = v
				delay.debounce(self, "apply_debounce", SLIDER_DEBOUNCE, self.apply, self)
			end,
		}))
	elseif system == "etternaj" then
		self.form:add(SegmentedControl({
			label = localization:get("song_select.etterna_judge"),
			options = ETTERNA_JUDGES,
			value = value,
			format = function(v)
				return "J" .. v
			end,
			on_change = function(v)
				self:setValue(system, v)
			end,
		}))
	elseif system == "bmsrank" then
		self.form:add(SegmentedControl({
			label = localization:get("song_select.bms_rank"),
			options = BMS_RANKS,
			value = value,
			format = function(v)
				return assert(BMS_RANK_LABELS[v], "unknown LR2 timing rank")
			end,
			on_change = function(v)
				self:setValue(system, v)
			end,
		}))
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
