local ButtonRow = require("ui.views.form.ButtonRow")
local Colors = require("ui.Colors")
local Form = require("ui.views.form.Form")
local FormSelection = require("ui.views.form.FormSelection")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.form.Textbox")

---Labels the shown play as under- or overrated by Rizu Difficulty, see rizu.api.Result:saveDifficultyLabel.
---@class ui.modals.difficulty_label.DifficultyLabel : ui.ModalView
---@operator call: ui.modals.difficulty_label.DifficultyLabel
---@field private result rizu.api.Result
---@field private notifications rizu.api.Notifications
---@field private on_close fun()
---@field private localization ui.localization.Localization
---@field private form ui.views.form.Form
---@field private background gui.NineSliceUsage
---@field private comment ui.views.form.Textbox
local DifficultyLabel = ModalView + {}

local MODAL_WIDTH = 800
local MODAL_HEIGHT = 360
local FORM_WIDTH = 660
local FORM_X = (MODAL_WIDTH - FORM_WIDTH) / 2
local FORM_Y = 112

---@param result rizu.api.Result
---@param notifications rizu.api.Notifications
---@param on_close fun()
---@param localization ui.localization.Localization
function DifficultyLabel:new(result, notifications, on_close, localization)
	ModalView.new(self)
	self.result = result
	self.notifications = notifications
	self.on_close = on_close
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

	self:add(ModalHeader(localization:get("result.difficulty_label_title"),
		localization:get("result.difficulty_label_subtitle")))
	self:add(ModalFooter(on_close, localization:get("settings.close")))

	---@type ui.views.form.ButtonRow.Button[]
	local buttons = {}
	for _, label in ipairs(result:getDifficultyLabels()) do
		table.insert(buttons, {
			text = localization:get("result.difficulty_label." .. label),
			on_click = function() self:save(label) end,
		})
	end
	self.form = Form({direction = "column", gap = 12})
	self.comment = self.form:add(Textbox({
		label = localization:get("result.difficulty_label_comment"),
		placeholder = localization:get("result.difficulty_label_comment_placeholder"),
		width = FORM_WIDTH,
	}))
	self.form:add(ButtonRow({buttons = buttons}))
	self.form:fitContent()
	self.form:setPosition(FORM_X, FORM_Y)
	self:add(self.form)
	self:add(FormSelection(self.form))
end

---@private
---@param label string
function DifficultyLabel:save(label)
	local localization = self.localization
	local ok, err = self.result:saveDifficultyLabel(label, self.comment:getText())
	if not ok then
		self.notifications:post("error", "difficulty_label_failed",
			localization:get("result.difficulty_label_failed"), err)
		return
	end
	self.notifications:post("success", "difficulty_label_saved", localization:get("result.difficulty_label_saved"),
		localization:get("result.difficulty_label." .. label))
	self.on_close()
end

function DifficultyLabel:show()
	self.comment:setText("")
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function DifficultyLabel:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function DifficultyLabel:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return DifficultyLabel
