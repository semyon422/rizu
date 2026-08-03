local class = require("class")
local table_util = require("table_util")
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
---@field action_map gui.input.ActionMap?
---@field private action_pressed {[string]: boolean}
---@field private action_just_pressed {[string]: boolean}
---@field private action_just_released {[string]: boolean}
---@field private pointer_targeting gui.PointerTargeting
---@field private pointer_gesture_handler gui.PointerGesture
---@field private keyboard_inputs gui.KeyboardInputs
local Inputs = class()

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
	self.action_pressed = {}
	self.action_just_pressed = {}
	self.action_just_released = {}
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
	table_util.clear(self.action_just_pressed)
	table_util.clear(self.action_just_released)
end

---@param action_map gui.input.ActionMap?
function Inputs:setActionMap(action_map)
	self.action_map = action_map
	table_util.clear(self.action_pressed)
	table_util.clear(self.action_just_pressed)
	table_util.clear(self.action_just_released)
end

---@param action string
---@return boolean
function Inputs:isActionPressed(action)
	return self.action_pressed[action] == true
end

---@param action string
---@return boolean
function Inputs:isActionJustPressed(action)
	return self.action_just_pressed[action] == true
end

---@param action string
---@return boolean
function Inputs:isActionJustReleased(action)
	return self.action_just_released[action] == true
end

---Consumes this frame's pressed edge so lower-priority handlers cannot observe it.
---@param action string
---@return boolean consumed
function Inputs:consumeActionJustPressed(action)
	if not self.action_just_pressed[action] then
		return false
	end
	self.action_just_pressed[action] = nil
	return true
end

---Consumes this frame's released edge so lower-priority handlers cannot observe it.
---@param action string
---@return boolean consumed
function Inputs:consumeActionJustReleased(action)
	if not self.action_just_released[action] then
		return false
	end
	self.action_just_released[action] = nil
	return true
end

---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
function Inputs:updateActions(event, modifiers)
	local action_map = self.action_map
	if not action_map or (event.name ~= "keypressed" and event.name ~= "keyreleased") then return end
	for action, bindings in action_map:iterate() do
		for _, binding in ipairs(bindings) do
			if event[1] == binding.key then
				if event.name == "keypressed" and action_map:bindingMatchesModifiers(binding, modifiers) then
					local is_repeat = event[3] == true
					if (is_repeat and binding.allow_repeat)
						or (not is_repeat and not self.action_pressed[action])
					then
						self.action_pressed[action] = true
						self.action_just_pressed[action] = true
					end
				elseif event.name == "keyreleased" and self.action_pressed[action] then
					self.action_pressed[action] = nil
					self.action_just_released[action] = true
				end
				break
			end
		end
	end
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
	self:updateActions(event, modifiers)
	self:dispatch(event, modifiers)
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys
function Inputs:dispatch(event, modifiers)
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
