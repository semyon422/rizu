local class = require("class")
local Observable = require("Observable")

---@class sphere.InputManager
---@operator call: sphere.InputManager
local InputManager = class()

InputManager.mode = "external"

---@param timeEngine sphere.TimeEngine
---@param inputModel sphere.InputModel
function InputManager:new(timeEngine, inputModel)
	self.observable = Observable()
	self.timeEngine = timeEngine
	self.inputModel = inputModel
end

---@param mode string
function InputManager:setMode(mode)
	assert(mode == "external" or mode == "internal")
	self.mode = mode
end

---@param event table
function InputManager:send(event)
	self.observable:send(event)
end

---@param inputMode string
function InputManager:setInputMode(inputMode)
	self.inputMode = inputMode
	self.state = {}
	self.savedState = {}
end

---@param virtualKey string
---@param state boolean
function InputManager:setState(virtualKey, state)
	self.state[virtualKey] = state
end

function InputManager:loadState()
	local currentTime = self.timeEngine.currentTime
	for virtualKey, state in pairs(self.state) do
		if state ~= self.savedState[virtualKey] then
			self:apply(virtualKey, state, currentTime)
		end
	end
end

function InputManager:saveState()
	for virtualKey, state in pairs(self.state) do
		self.savedState[virtualKey] = state
	end
end

local virtualEvent = {virtual = true}

---@param virtualKey string
---@param state boolean
---@param time number
function InputManager:apply(virtualKey, state, time)
	virtualEvent.time = math.ceil(time * 1024) / 1024
	virtualEvent.name = state and "keypressed" or "keyreleased"
	virtualEvent[1] = virtualKey
	self:send(virtualEvent)
end

---@param event table
function InputManager:receive(event)
	if event.virtual and self.mode == "internal" then
		self:send(event)
		return
	end

	local virtualKey, state = self.inputModel:transformEvent(self.inputMode, event)
	if not virtualKey then return end

	self:setState(virtualKey, state)

	local timeEngine = self.timeEngine
	local isPlaying = timeEngine.timer.is_playing
	if not isPlaying then return end

	self:apply(virtualKey, state, timeEngine.timer:transform(event.time))
end

return InputManager
