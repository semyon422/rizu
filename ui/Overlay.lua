local Screen = require("gui.Screen")
local GlobalCommands = require("ui.command_palette.GlobalCommands")
local PaletteState = require("ui.command_palette.PaletteState")
local CommandPalette = require("ui.views.CommandPalette")
local NeedleToolRegistry = require("rizu.ai.NeedleToolRegistry")
local View = require("ui.views.Rectangle")
local OverlayBackground = require("ui.views.OverlayBackground")

---@class ui.Overlay : gui.Screen
---@operator call: ui.Overlay
---@field ui ui.UserInterface
---@field palette ui.views.CommandPalette
---@field palette_attached boolean
---@field private suppress_palette_text_input boolean
local Overlay = Screen + {}

---@param ui ui.UserInterface
function Overlay:new(ui)
	Screen.new(self)
	self.ui = ui

	for _, command in ipairs(GlobalCommands.get(ui.game, ui)) do
		ui.command_registry:registerGlobal(command)
	end

	local needle_tools = NeedleToolRegistry(ui.command_registry)
	self.palette = CommandPalette(PaletteState(ui.command_registry), function()
		self:paletteClosed()
	end, ui.game.needleModel, needle_tools)
	self.palette_attached = false
	self.suppress_palette_text_input = false

	self.bg = self.root:add(OverlayBackground())

	self.root:add(self.palette)
end

---@private
function Overlay:paletteClosed()
	self.palette_attached = false
	local inputs = self.inputs
	if inputs and inputs.keyboard_focus == self.palette then
		inputs:setKeyboardFocus(nil, {control = false, shift = false, alt = false, super = false})
	end

	self.bg:hide()
end

---@return boolean attached
function Overlay:attachPalette()
	if self.palette_attached then
		return false
	end
	self.palette:reset()
	self.palette:show()
	self.palette_attached = true
	self.bg:show()

	if self.inputs then
		self.inputs:setKeyboardFocus(self.palette, {control = false, shift = false, alt = false, super = false})
	end
	return true
end

---@return boolean detached
function Overlay:detachPalette()
	if not self.palette_attached then
		return false
	end
	if self.palette.needle_model then
		self.palette.needle_model:cancel()
	end
	self.palette:hide()
	self:paletteClosed()

	return true
end

---@param event {name: string, [integer]: any}
---@return boolean handled
function Overlay:receive(event)
	-- LÖVE emits textinput(":") after the keypressed event that opens the
	-- palette. Consume that paired text event so it does not become the query.
	if self.suppress_palette_text_input and event.name == "textinput" then
		self.suppress_palette_text_input = false
		if event[1] == ":" then
			return true
		end
	end

	if event.name == "keypressed" and event[1] == ";" and love.keyboard.isDown("lshift", "rshift") then
		self:attachPalette()
		self.suppress_palette_text_input = true
		return true
	end
	return false
end

return Overlay
