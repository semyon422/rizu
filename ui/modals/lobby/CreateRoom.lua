local Button = require("ui.views.Button")
local ChartmetaKey = require("sea.chart.ChartmetaKey")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.form.Textbox")
local UiActions = require("ui.UiActions")

---@class ui.modals.lobby.CreateRoom : ui.ModalView
---@operator call: ui.modals.lobby.CreateRoom
---@field ui ui.UserInterface
---@field client sea.MultiplayerClient
---@field name_input ui.views.form.Textbox
---@field password_input ui.views.form.Textbox
---@field status ui.views.Label
---@field create_button ui.views.Button
---@field observer util.Observer?
---@field creating boolean
local CreateRoom = ModalView + {}

local WIDTH = 560
local HEIGHT = 390
local FIELD_WIDTH = 476

local function trim(value)
	return value:match("^%s*(.-)%s*$")
end

---@param ui ui.UserInterface
function CreateRoom:new(ui)
	ModalView.new(self)
	self.ui = ui
	self.client = ui.game.multiplayerModel.client
	self.observer = nil
	self.creating = false
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

	local title = self:add(Label({
		font_name = "bold", font_size = 36, text = ui.localization:get("create_room.title"),
	}))
	title:setPosition(42, 30)

	self.name_input = self:add(Textbox({
		label = ui.localization:get("create_room.name"),
		placeholder = ui.localization:get("create_room.name_placeholder"),
		width = FIELD_WIDTH,
	}))
	self.name_input:setPosition(42, 96)
	self.password_input = self:add(Textbox({
		label = ui.localization:get("create_room.password"),
		placeholder = ui.localization:get("create_room.password_placeholder"),
		width = FIELD_WIDTH,
		secret = true,
	}))
	self.password_input:setPosition(42, 176)

	self.status = self:add(Label({font_name = "regular", font_size = 16, color = Colors.danger}))
	self.status:setPosition(42, 254)

	self.create_button = self:add(Button(ui.localization:get("create_room.create"), function()
		self:createRoom()
	end, {variant = "primary", shape = "capsule", font_name = "medium", font_size = 18}))
	self.create_button:setSize(180, 48):setPosition(148, 312)
	local cancel = self:add(Button(ui.localization:get("create_room.cancel"), function()
		ui.modal_manager:hideModal(self)
	end, {shape = "capsule", font_name = "medium", font_size = 18}))
	cancel:setSize(140, 48):setPosition(342, 312)
end

function CreateRoom:load()
	ModalView.load(self)
	self.observer = self.client:onChanged(self)
end

function CreateRoom:unload()
	if self.observer then
		self.client:offChanged(self.observer)
		self.observer = nil
	end
	ModalView.unload(self)
end

function CreateRoom:createRoom()
	if self.creating then return end
	local name = trim(self.name_input:getText())
	if name == "" then
		self.status:setText(self.ui.localization:get("create_room.name_required"))
		return
	end

	local chartview = self.ui.game.chartSelector.chartview
	if not chartview or not chartview.hash or not chartview.index then
		self.status:setText(self.ui.localization:get("create_room.chart_required"))
		return
	end

	local chartmeta_key = ChartmetaKey()
	chartmeta_key.hash = chartview.hash
	chartmeta_key.index = chartview.index
	self.creating = true
	self.create_button:setEnabled(false)
	self.name_input:setEnabled(false)
	self.password_input:setEnabled(false)
	self.status:setText(self.ui.localization:get("create_room.creating"))
	self.client:createRoom(name, self.password_input:getText(), chartmeta_key)
end

---@param event sea.multi.MultiplayerClient.Event
function CreateRoom:receive(event)
	if not self.creating then return end
	if event.type == "create_succeeded" then
		self.creating = false
		self.ui.modal_manager:hideModal(self)
		self.ui:setScreen(self.ui.lobby, true)
	elseif event.type == "create_failed" then
		self.creating = false
		self.create_button:setEnabled(true)
		self.name_input:setEnabled(true)
		self.password_input:setEnabled(true)
		self.status:setText(self.ui.localization:get("create_room.failed", {error = event.error}))
	end
end

---@param inputs gui.Inputs
function CreateRoom:onHandleInputs(inputs)
	if not self.creating and inputs:consumeActionJustPressed(UiActions.accept) then
		self:createRoom()
	end
end

function CreateRoom:show()
	self.creating = false
	self.name_input:setText("")
	self.password_input:setText("")
	self.name_input:setEnabled(true)
	self.password_input:setEnabled(true)
	self.create_button:setEnabled(true)
	self.status:setText("")
	self:setVisible(true)
	self:fadeIn(0.25, "OutCubic")
end

function CreateRoom:hide()
	self.creating = false
	self:transformTo("opacity", 0, 0.18, "InCubic", function()
		self:setVisible(false)
	end)
end

function CreateRoom:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return CreateRoom
