local Button = require("ui.views.Button")
local Colors = require("ui.Colors")
local Label = require("ui.views.Label")
local ModalView = require("ui.ModalView")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Textbox = require("ui.views.form.Textbox")
local Loading = require("ui.screens.chart_loading.Loading")
local UiActions = require("ui.UiActions")

---@alias ui.modals.login.State "idle"|"loading"|"error"

---@class ui.modals.login.Login : ui.ModalView
---@operator call: ui.modals.login.Login
---@field state ui.modals.login.State
---@field observer util.Observer?
local Login = ModalView + {}

local WIDTH = 560
local HEIGHT = 370
local FIELD_WIDTH = 476

---@param ui ui.UserInterface
---@param on_close fun()
function Login:new(ui, on_close)
	ModalView.new(self)
	self.ui = ui
	self.on_close = on_close
	self.state = "idle"
	self.observer = nil
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

	self.title = self:add(Label({
		font_name = "bold", font_size = 36, text = ui.localization:get("login.title"),
	}))
	self.title:setPosition(42, 30)
	self.email = self:add(Textbox({
		label = ui.localization:get("login.email"),
		placeholder = ui.localization:get("login.email_placeholder"),
		width = FIELD_WIDTH,
	}))
	self.email:setPosition(42, 95)
	self.password = self:add(Textbox({
		label = ui.localization:get("login.password"),
		placeholder = ui.localization:get("login.password_placeholder"),
		width = FIELD_WIDTH,
		secret = true,
	}))
	self.password:setPosition(42, 175)
	self.status = self:add(Label({font_name = "regular", font_size = 16, color = Colors.danger}))
	self.status:setPosition(42, 250)
	self.loading = self:add(Loading(0.18))
	self.loading:setAlignment(0.5, 0):addPosition(0, 252)
	self.loading:setVisible(false)

	self.login_button = self:add(Button(ui.localization:get("main_menu.login"), function()
		self:login()
	end, {variant = "primary", shape = "capsule", font_size = 18}))
	self.login_button:setSize(180, 48):setPosition(148, 292)
	self.cancel_button = self:add(Button(ui.localization:get("login.cancel"), on_close, {
		shape = "capsule", font_size = 18,
	}))
	self.cancel_button:setSize(140, 48):setPosition(342, 292)
end

function Login:login()
	if self.state == "loading" then return end
	local email = self.email:getText()
	local password = self.password:getText()
	if email == "" or password == "" then
		self:setState("error", self.ui.localization:get("login.fields_required"))
		return
	end
	self:setState("loading")
	self.ui.game.onlineModel.authManager:login(email, password)
end

---@param state ui.modals.login.State
---@param err string?
function Login:setState(state, err)
	self.state = state
	self.loading:setVisible(state == "loading")
	self.login_button:setEnabled(state ~= "loading")
	self.email:setEnabled(state ~= "loading")
	self.password:setEnabled(state ~= "loading")
	self.status:setText(state == "error" and (err or self.ui.localization:get("login.failed")) or "")
end

---@param event rizu.online.Event
function Login:receive(event)
	if event.type == "login_started" then
		self:setState("loading")
	elseif event.type == "login_failed" then
		self:setState("error", event.error)
	elseif event.type == "login_succeeded" then
		self.password:setText("")
		self.on_close()
	end
end

function Login:load()
	ModalView.load(self)
	self.observer = self.ui.game.online_client:onChanged(self)
end

function Login:unload()
	if self.observer then
		self.ui.game.online_client:offChanged(self.observer)
		self.observer = nil
	end
	ModalView.unload(self)
end

---@param inputs gui.Inputs
function Login:onHandleInputs(inputs)
	if self.state ~= "loading" and inputs:consumeActionJustPressed(UiActions.accept) then
		self:login()
	end
end

function Login:show()
	self.password:setText("")
	self:setState("idle")
	self:setVisible(true)
	self:fadeIn(0.25, "OutCubic")
end

function Login:hide()
	self:setState("idle")
	self:transformTo("opacity", 0, 0.18, "InCubic", function()
		self:setVisible(false)
	end)
end

function Login:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return Login
