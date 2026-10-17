local class = require("class")

---Screen lifecycle and input contract consumed by `gui.UserInterface`.
---Concrete applications may add navigation, overlays, and viewport policy.
---@class gui.IScreenManager
---@operator call: gui.IScreenManager
local IScreenManager = class()

---@param screen gui.Screen
---@param keep_previous_visible boolean?
---@return boolean changed
function IScreenManager:setScreen(screen, keep_previous_visible)
	return false
end

---@param inputs gui.Inputs
function IScreenManager:acceptInputs(inputs) end

---Dispatches semantic actions after queued raw events have updated action state.
---@param inputs gui.Inputs
function IScreenManager:handleInputs(inputs) end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys?
---@return boolean? handled
function IScreenManager:receive(event, modifiers) end

---@param dt number
function IScreenManager:update(dt) end

function IScreenManager:draw() end

function IScreenManager:unload() end

return IScreenManager
