local class = require("class")
local Inputs = require("gui.input.Inputs")

---@class gui.QueuedInput
---@field event {name: string, time: number, [integer]: any}
---@field modifiers gui.ModifierKeys
---@field x number
---@field y number

---@class gui.UserInterface
---@operator call: gui.UserInterface
---@field screen_manager gui.IScreenManager
---@field inputs gui.Inputs
---@field private input_queue gui.QueuedInput[]
local UserInterface = class()

local pointer_events = {
	mousepressed = true,
	mousereleased = true,
	mousemoved = true,
	wheelmoved = true,
}

---@return gui.ModifierKeys
local function getModifiers()
	return {
		control = love.keyboard.isDown("lctrl", "rctrl"),
		shift = love.keyboard.isDown("lshift", "rshift"),
		alt = love.keyboard.isDown("lalt", "ralt"),
		super = love.keyboard.isDown("lgui", "rgui"), ---@diagnostic disable-line
	}
end

---@param event {name: string, time: number, [integer]: any}
---@return {name: string, time: number, [integer]: any} copy
local function copyEvent(event)
	local copy = {} ---@type {name: string, time: number, [integer]: any}
	for key, value in pairs(event) do
		copy[key] = value
	end
	return copy
end

---@param screen_manager gui.IScreenManager
function UserInterface:new(screen_manager)
	self.screen_manager = screen_manager
	self.inputs = Inputs()
	self.input_queue = {}
end

---keep_previous_visible keeps the outgoing screen active for a transition.
---@param screen gui.Screen
---@param keep_previous_visible boolean?
---@return boolean changed
function UserInterface:setScreen(screen, keep_previous_visible)
	return self.screen_manager:setScreen(screen, keep_previous_visible)
end

function UserInterface:load() end

function UserInterface:unload()
	self.screen_manager:unload()
end

---@private
function UserInterface:drainInputQueue()
	local queue = self.input_queue
	for i = 1, #queue do
		local queued = queue[i]
		if pointer_events[queued.event.name] then
			self.inputs.mouse_x = queued.x
			self.inputs.mouse_y = queued.y
		end
		self.inputs:updateActions(queued.event, queued.modifiers)
		if not self.screen_manager:receive(queued.event, queued.modifiers) then
			self.inputs:dispatch(queued.event, queued.modifiers)
		end
		queue[i] = nil
	end
end

---@param dt number
function UserInterface:update(dt)
	local mouse_x, mouse_y = love.mouse.getPosition()
	self.inputs:beginFrame(mouse_x, mouse_y)
	self.screen_manager:acceptInputs(self.inputs)
	self:drainInputQueue()
	self.screen_manager:handleInputs(self.inputs)
	self.screen_manager:update(dt)
end

function UserInterface:draw()
	self.screen_manager:draw()
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys?
function UserInterface:receive(event, modifiers)
	local x, y = 0, 0
	if event.name == "mousepressed" or event.name == "mousereleased" or event.name == "mousemoved" then
		x, y = event[1], event[2]
	else
		x, y = love.mouse.getPosition()
	end
	self.input_queue[#self.input_queue + 1] = {
		event = copyEvent(event),
		modifiers = modifiers or getModifiers(),
		x = x,
		y = y,
	}
end

return UserInterface
