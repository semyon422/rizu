local class = require("class")

---@class gui.IInputHandler
---@field mouse_over boolean
---@field handles_mouse_input boolean
---@field handles_keyboard_input boolean
local IInputHandler = class()

---@param e gui.MouseDownEvent
function IInputHandler:onMouseDown(e) end

---@param e gui.MouseUpEvent
function IInputHandler:onMouseUp(e) end

---@param e gui.MouseClickEvent
function IInputHandler:onMouseClick(e) end

---@param e gui.ScrollEvent
function IInputHandler:onScroll(e) end

---@param e gui.DragStartEvent
function IInputHandler:onDragStart(e) end

---@param e gui.DragEvent
function IInputHandler:onDrag(e) end

---@param e gui.DragEndEvent
function IInputHandler:onDragEnd(e) end

---@param e gui.HoverEvent
function IInputHandler:onHover(e) end

---@param e gui.HoverLostEvent
function IInputHandler:onHoverLost(e) end

---@param e gui.FocusEvent
function IInputHandler:onFocus(e) end

---@param e gui.FocusLostEvent
function IInputHandler:onFocusLost(e) end

---@param e gui.KeyDownEvent
function IInputHandler:onKeyDown(e) end

---@param e gui.KeyUpEvent
function IInputHandler:onKeyUp(e) end

---@param e gui.TextInputEvent
function IInputHandler:onTextInput(e) end

return IInputHandler
