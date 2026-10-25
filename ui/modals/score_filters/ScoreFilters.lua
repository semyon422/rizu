local ButtonRow = require("ui.views.form.ButtonRow")
local Colors = require("ui.Colors")
local Dropdown = require("ui.views.form.Dropdown")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---Options of the song select leaderboard.
---@class ui.modals.score_filters.ScoreFilters : ui.ModalView
---@operator call: ui.modals.score_filters.ScoreFilters
---@field form ui.views.form.Form
---@field form_selection ui.views.form.FormSelection
---@field background gui.NineSliceUsage
---@field library rizu.api.Library
---@field scores rizu.api.Scores
---@field popup_container ui.views.PopupContainer
---@field localization ui.localization.Localization
local ScoreFilters = ModalView + {}

local MODAL_WIDTH = 700
local MODAL_HEIGHT = 400
local FORM_X = 48
local FORM_WIDTH = MODAL_WIDTH - FORM_X * 2
local FORM_Y = 136

---@param library rizu.api.Library
---@param scores rizu.api.Scores
---@param popup_container ui.views.PopupContainer
---@param on_close fun()
---@param localization ui.localization.Localization
function ScoreFilters:new(library, scores, popup_container, on_close, localization)
	ModalView.new(self)
	self.library = library
	self.scores = scores
	self.popup_container = popup_container
	self.localization = localization

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

	self:add(ModalHeader(localization:get("song_select.score_filters_title"),
		localization:get("song_select.recalculate_accuracies_tip")))
	self:add(ModalFooter(on_close, localization:get("settings.close")))

	self.form = Form({direction = "column", gap = 12})
	self.form:setPosition(FORM_X, FORM_Y)
	self:add(self.form)
	self.form_selection = self:add(FormSelection(self.form))
	self:rebuildForm()

	-- The list shows the old accuracies until it is read again.
	local stage = library:getCacheStatus().stage
	---@param status rizu.api.CacheStatus
	library:on("cache_status_changed", function(status)
		if stage == "accuracies" and status.stage ~= "accuracies" then
			scores:refresh()
		end
		stage = status.stage
	end)
end

---The stored systems can change between openings, so the dropdown is made anew.
function ScoreFilters:rebuildForm()
	local scores = self.scores
	local localization = self.localization
	self.form:closeActiveDropdown()
	self.form:clearSelection()
	self.form:clearRows()

	self.form:add(Dropdown({
		label = localization:get("song_select.accuracy_system"),
		options = scores:getAccuracySystems(),
		value = scores:getSelectedAccuracySystem(),
		width = FORM_WIDTH,
		format = function(token)
			---@cast token string
			local scoring = token ~= "auto" and scores:getAccuracySystem(nil, token)
			return scoring and scoring:getName() or localization:get("song_select.accuracy_system_auto")
		end,
		on_change = function(token) scores:setSelectedAccuracySystem(token) end,
		form = self.form,
		popup_container = self.popup_container,
	}))
	self.form:add(ButtonRow({
		buttons = {{
			text = localization:get("song_select.recalculate_accuracies"),
			on_click = function() self.library:recalculateAccuracies() end,
		}},
	}))
	self.form:fitContent()
end

function ScoreFilters:show()
	self:rebuildForm()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function ScoreFilters:hide()
	self.form:closeActiveDropdown()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function ScoreFilters:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return ScoreFilters
