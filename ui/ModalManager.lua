local View = require("gui.View")
local PaletteState = require("rizu.command.PaletteState")
local AiChat = require("ui.modals.ai_chat.AiChat")
local CommandPalette = require("ui.modals.command_palette.CommandPalette")
local ChartMutators = require("ui.modals.chart_mutators.ChartMutators")
local NeedleToolRegistry = require("rizu.ai.NeedleToolRegistry")
local OverlayBackground = require("ui.views.OverlayBackground")
local Config = require("ui.modals.config.Config")
local Input = require("ui.modals.input.Input")
local Modifiers = require("ui.modals.modifiers.Modifiers")
local UiActions = require("ui.UiActions")

---@class ui.ModalManager : gui.View
---@operator call: ui.ModalManager
---@field ui ui.UserInterface
---@field palette ui.modals.command_palette.CommandPalette
---@field ai_chat ui.modals.ai_chat.AiChat?
---@field config ui.modals.config.Config
---@field input ui.modals.input.Input
---@field modifiers ui.modals.modifiers.Modifiers
---@field chart_mutators ui.modals.chart_mutators.ChartMutators
---@field active_view ui.ModalView?
local ModalManager = View + {}

---@param ui ui.UserInterface
function ModalManager:new(ui)
	View.new(self)
	self:anchorFill(0, 0, 0, 0)
	self.handles_keyboard_input = true
	self.keyboard_input_fallback = true
	self.ui = ui

	local needle_tools = NeedleToolRegistry(ui.command_registry)
	self.palette = CommandPalette(PaletteState(ui.command_registry), function()
		self:modalClosed(self.palette)
	end, ui.game.needleModel, needle_tools)
	self.active_view = nil

	self.bg = self:add(OverlayBackground(function()
		self:hideModal()
	end))
	self.config = self:addModal(Config(ui.config, ui.game.settings))
	self.input = self:addModal(Input(ui.game))
	ui.game.chartSelector:onChanged(self.input)
	local function modifiers_changed()
		-- TODO: The game should emit events like this.
		ui.song_select:updateModifiers()
	end
	self.modifiers = self:addModal(Modifiers(ui.game, modifiers_changed))
	self.chart_mutators = self:addModal(ChartMutators(ui.game, modifiers_changed))
	if ui.game.aiChatModel then
		self.ai_chat = self:addModal(AiChat(ui.game.aiChatModel, function()
			self:hideModal(self.ai_chat)
		end))
	end
	self:addModal(self.palette)
end

---@generic T: ui.ModalView
---@param view T
---@return T
function ModalManager:addModal(view)
	return self:add(view)
end

---@param view ui.ModalView
---@return boolean shown
function ModalManager:showModal(view)
	if self.active_view == view then
		return false
	end
	if self.active_view then
		self:hideModal(self.active_view)
	end

	self.active_view = view
	view:show()
	self.bg:show()
	local inputs = self.screen and self.screen.inputs
	if inputs then
		inputs:pushFocusScope(view)
		if view.handles_keyboard_input then
			inputs:setKeyboardFocus(view, {control = false, shift = false, alt = false, super = false})
		end
	end
	return true
end

---@param view ui.ModalView?
---@return boolean hidden
function ModalManager:hideModal(view)
	view = view or self.active_view
	if not view or self.active_view ~= view then
		return false
	end
	if view == self.palette and self.palette.needle_model then
		self.palette.needle_model:cancel()
	end
	view:hide()
	self:modalClosed(view)
	return true
end

---@private
---@param view ui.ModalView
function ModalManager:modalClosed(view)
	if self.active_view ~= view then
		return
	end
	self.active_view = nil
	local inputs = self.screen and self.screen.inputs
	if inputs then
		-- The focused modal may have closed itself while raw key events were
		-- dispatched. Consume cancel here so the later action phase cannot also
		-- close the navigation screen.
		inputs:consumeActionJustPressed(UiActions.cancel)
		inputs:setKeyboardFocus(nil, {control = false, shift = false, alt = false, super = false})
		inputs:popFocusScope(view)
	end
	self.bg:hide()
end

---@param inputs gui.Inputs
function ModalManager:onHandleInputs(inputs)
	if self.active_view and inputs:consumeActionJustPressed(UiActions.cancel) then
		self:hideModal()
	end
end

---@return boolean attached
function ModalManager:attachPalette()
	if self.active_view == self.palette then
		return false
	end
	self.palette:reset()
	return self:showModal(self.palette)
end

---@return boolean detached
function ModalManager:detachPalette()
	return self:hideModal(self.palette)
end

---@return boolean attached
function ModalManager:attachChat()
	return self.ai_chat ~= nil and self:showModal(self.ai_chat)
end

---@return boolean detached
function ModalManager:detachChat()
	return self.ai_chat ~= nil and self:hideModal(self.ai_chat)
end

---@return boolean attached
function ModalManager:attachConfig()
	return self:showModal(self.config)
end

---@return boolean detached
function ModalManager:detachConfig()
	return self:hideModal(self.config)
end

---@return boolean attached
function ModalManager:attachInput()
	return self:showModal(self.input)
end

---@return boolean detached
function ModalManager:detachInput()
	return self:hideModal(self.input)
end

---@return boolean attached
function ModalManager:attachModifiers()
	return self:showModal(self.modifiers)
end

---@return boolean detached
function ModalManager:detachModifiers()
	return self:hideModal(self.modifiers)
end

---@return boolean attached
function ModalManager:attachChartMutators()
	return self:showModal(self.chart_mutators)
end

---@return boolean detached
function ModalManager:detachChartMutators()
	return self:hideModal(self.chart_mutators)
end

return ModalManager
