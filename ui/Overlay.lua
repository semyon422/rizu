local Screen = require("gui.Screen")
local ModalManager = require("ui.ModalManager")
local FpsView = require("ui.views.FpsView")

---@class ui.Overlay : gui.Screen
---@operator call: ui.Overlay
---@field modal_manager ui.ModalManager
---@field fps_view ui.views.FpsView
---@field private suppress_palette_text_input boolean
local Overlay = Screen + {}

---@param ui ui.UserInterface
function Overlay:new(ui)
	Screen.new(self)
	self.fps_view = self.root:add(FpsView(ui.config))
	self.fps_view:setAlignment(1, 1)
	self.fps_view:setOffset(-16, -16)
	self.modal_manager = self.root:add(ModalManager(ui))
	self.suppress_next_text_input = false
end

---@param event {name: string, time: number, [integer]: any}
---@return boolean handled
function Overlay:receive(event)
	if self.suppress_next_text_input and event.name == "textinput" then
		self.suppress_next_text_input = false
		return true
	end

	if event.name == "keypressed" then
		local key = event[1]

		if love.keyboard.isDown("lshift", "rshift") then
			if key == ";" then
				self.modal_manager:attachPalette()
				self.suppress_next_text_input = true
				return true
			end
		end

		if love.keyboard.isDown("lctrl", "rctrl") then
			if key == "o" then
				self.modal_manager:attachConfig()
				self.suppress_next_text_input = true
				return true
			end
		end
	end

	return false
end

return Overlay
