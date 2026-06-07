local IInputHandler = require("gui.input.IInputHandler")

---@class yi.Layer : gui.IInputHandler
---@operator call: yi.Layer
local Layer = IInputHandler + {}

Layer.handles_keyboard_input = true

function Layer:load() end

function Layer:unload() end

---@param dt number
function Layer:update(dt) end

function Layer:draw() end

---@param inputs gui.Inputs
function Layer:acceptInputs(inputs) end

---@param event {name: string, [integer]: any}
function Layer:receive(event) end

return Layer
