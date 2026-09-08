local Colors = require("ui.Colors")
local ModalFooter = require("ui.views.ModalFooter")
local ModalHeader = require("ui.views.ModalHeader")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local NoteSkinList = require("ui.modals.note_skins.NoteSkinList")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local UiActions = require("ui.UiActions")

---@class ui.modals.note_skins.NoteSkins : ui.ModalView
---@operator call: ui.modals.note_skins.NoteSkins
local NoteSkins = ModalView + {}

local WIDTH = 760
local HEIGHT = 720
local CONTENT_X = 28
local HEADER_HEIGHT = 112
local FOOTER_HEIGHT = 92
local LIST_PADDING_Y = 20

---@param game sphere.GameController
---@param on_close fun()
function NoteSkins:new(game, on_close)
	ModalView.new(self)
	self.game = game
	self.input_mode = ""
	self.items = {}
	self.selected_index = 1

	self:setSize(WIDTH, HEIGHT):setAlignment(0.5, 0.5):setPivot(0.5, 0.5)
	self:setOpacity(0):setVisible(false):setClip(true)
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	local sprites = Resources.sprites
	self.background = NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})

	self.header = self:add(ModalHeader("Note Skins", "Choose a skin for the selected Chart."))
	self.list = self:add(NoteSkinList(function(index) self:select(index) end))
	self.list:anchorFixed(CONTENT_X, HEADER_HEIGHT + LIST_PADDING_Y,
		WIDTH - CONTENT_X * 2, HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT - LIST_PADDING_Y * 2)
	self:add(ModalFooter(on_close))
end

function NoteSkins:refresh()
	local input_mode = tostring(self.game.modifierCoordinator.state.inputMode or "")
	self.input_mode = input_mode
	if input_mode == "" then
		self.items = {}
		self.selected_index = 1
		self.header.subtitle:setText("Select a Chart to choose a compatible skin.")
		self.list:setItems({}, nil)
		return
	end

	local model = self.game.noteSkinModel
	self.items = model:getSkinInfos(input_mode)
	local selected = model:getSkinInfo(input_mode)
	local selected_path = selected and selected:getPath() or nil
	self.header.subtitle:setText("Choose a skin for " .. input_mode .. ".")
	for index, item in ipairs(self.items) do
		if item:getPath() == selected_path then
			self.selected_index = index
			break
		end
	end
	self.list:setItems(self.items, selected_path)
end

---@param index integer
function NoteSkins:select(index)
	local item = self.items[index]
	if not item or self.input_mode == "" then return end
	self.selected_index = index
	local model = self.game.noteSkinModel
	local path = item:getPath()
	model:setDefaultNoteSkin(self.input_mode, path)
	model:loadNoteSkin(self.input_mode)
	self.game.persistence.configModel:write("settings")
	self.list.selected_path = path
end

---@param offset integer
function NoteSkins:move(offset)
	if #self.items == 0 then return end
	self.selected_index = ((self.selected_index - 1 + offset) % #self.items) + 1
	self:select(self.selected_index)
	local top = (self.selected_index - 1) * self.list:getRowStep()
	self.list:scrollTo(top + self.list.item_height / 2 - self.list.height / 2)
end

---@param inputs gui.Inputs
function NoteSkins:onHandleInputs(inputs)
	if inputs:consumeActionJustPressed(UiActions.down) then
		self:move(1)
	elseif inputs:consumeActionJustPressed(UiActions.up) then
		self:move(-1)
	end
end

function NoteSkins:show()
	self:refresh()
	self:setVisible(true)
	self:fadeIn(0.3, "OutCubic")
end

function NoteSkins:hide()
	self:transformTo("opacity", 0, 0.2, "InCubic", function()
		self:setVisible(false)
	end)
end

function NoteSkins:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return NoteSkins
