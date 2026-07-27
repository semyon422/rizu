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

---@param event {name: string, [integer]: any}
---@return boolean? handled
function IScreenManager:receive(event) end

---@param dt number
function IScreenManager:update(dt) end

function IScreenManager:draw() end

function IScreenManager:unload() end

return IScreenManager
