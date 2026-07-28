local class = require("class")
local PointerTargeting = require("gui.input.PointerTargeting")
local PointerGesture = require("gui.input.PointerGesture")
local KeyboardInputs = require("gui.input.KeyboardInputs")

---@class gui.ModifierKeys
---@field control boolean
---@field shift boolean
---@field alt boolean
---@field super boolean

---@class gui.Inputs
---@operator call: gui.Inputs
---@field mouse_x number
---@field mouse_y number
---@field mouse_target gui.View?
---@field mouse_hits gui.View[]
---@field focus_requesters gui.View[]
---@field focus_scopes gui.FocusScope[]
---@field keyboard_focus gui.View?
---@field pointer_gesture gui.PointerGestureState?
---@field last_mouse_down_event gui.MouseDownEvent? Compatibility view of pointer gesture state
---@field last_drag_event gui.MouseEvent? Compatibility view of pointer gesture state
---@field released_press_target gui.View? Compatibility view of pointer gesture state
---@field private pointer_targeting gui.PointerTargeting
---@field private pointer_gesture_handler gui.PointerGesture
---@field private keyboard_inputs gui.KeyboardInputs
local Inputs = class()

Inputs.MOUSE_CLICK_MAX_DISTANCE = PointerGesture.MOUSE_CLICK_MAX_DISTANCE
Inputs.DRAG_START_THRESHOLD = PointerGesture.DRAG_START_THRESHOLD

local mouse_events = {
	mousepressed = true,
	mousereleased = true,
	mousemoved = true,
	wheelmoved = true,
}

local keyboard_events = {
	keypressed = true,
	keyreleased = true,
	textinput = true,
}

function Inputs:new()
	self.pointer_targeting = PointerTargeting(self)
	self.pointer_gesture_handler = PointerGesture(self, self.pointer_targeting)
	self.keyboard_inputs = KeyboardInputs(self)
end

---@param mouse_x number Global mouse X position
---@param mouse_y number Global mouse Y position
function Inputs:resetTraversalContext(mouse_x, mouse_y)
	self.pointer_targeting:reset(mouse_x, mouse_y)
	self.keyboard_inputs:resetTargets()
end

---@param mouse_x number Global mouse X position
---@param mouse_y number Global mouse Y position
function Inputs:beginFrame(mouse_x, mouse_y)
	self:resetTraversalContext(mouse_x, mouse_y)
end

---@param root gui.View
function Inputs:clearSubtree(root)
	self.keyboard_inputs:clearSubtree(root)
	self.pointer_targeting:clearSubtree(root)
	self.pointer_gesture_handler:clearPointerGestureInSubtree(root)
end

---@param view gui.View
function Inputs:processView(view)
	self.keyboard_inputs:processView(view)
	self.pointer_targeting:processView(view)
end

---@param view gui.View?
---@param root gui.View
---@return boolean contained
function Inputs:isInSubtree(view, root)
	return not not (view and view.flat_index and root.flat_index
		and view.screen == root.screen
		and view.flat_index >= root.flat_index
		and view.flat_index <= root.flat_subtree_end)
end

---@param view gui.View
---@return boolean eligible
function Inputs:isInActiveFocusScope(view)
	return self.keyboard_inputs:isInActiveFocusScope(view)
end

---@param root gui.View
function Inputs:pushFocusScope(root)
	self.keyboard_inputs:pushFocusScope(root)
end

---@param root gui.View?
function Inputs:popFocusScope(root)
	self.keyboard_inputs:popFocusScope(root)
end

---@param node gui.View?
---@param modifiers gui.ModifierKeys
function Inputs:setKeyboardFocus(node, modifiers)
	self.keyboard_inputs:setKeyboardFocus(node, modifiers)
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys
function Inputs:receive(event, modifiers)
	event.time = event.time or love.timer.getTime()
	if mouse_events[event.name] then
		self.pointer_gesture_handler:dispatchMouseEvent(event, modifiers)
	elseif keyboard_events[event.name] then
		self.keyboard_inputs:dispatch(event, modifiers)
	end
end

---@param e gui.UIEvent
---@return boolean? handled
function Inputs:dispatchEvent(e)
	return e:trigger()
end

return Inputs
