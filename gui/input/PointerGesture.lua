local class = require("class")
local MouseDownEvent = require("gui.input.events.MouseDownEvent")
local MouseUpEvent = require("gui.input.events.MouseUpEvent")
local MouseClickEvent = require("gui.input.events.MouseClickEvent")
local ScrollEvent = require("gui.input.events.ScrollEvent")
local DragEvent = require("gui.input.events.DragEvent")
local DragStartEvent = require("gui.input.events.DragStartEvent")
local DragEndEvent = require("gui.input.events.DragEndEvent")

---@class gui.PointerGestureState
---@field button number
---@field press_target gui.View
---@field capture_target gui.View
---@field x number
---@field y number
---@field time number
---@field dragging boolean
---@field released_target gui.View?

---@class gui.PointerGesture
---@operator call: gui.PointerGesture
---@field private inputs gui.Inputs
---@field private targeting gui.PointerTargeting
local PointerGesture = class()

PointerGesture.MOUSE_CLICK_MAX_DISTANCE = 6
PointerGesture.DRAG_START_THRESHOLD = 4

---@param inputs gui.Inputs
---@param targeting gui.PointerTargeting
function PointerGesture:new(inputs, targeting)
	self.inputs = inputs
	self.targeting = targeting
	inputs.pointer_gesture = nil
	inputs.last_mouse_down_event = nil
	inputs.last_drag_event = nil
	inputs.released_press_target = nil
end

---@private
function PointerGesture:syncLegacyGestureState()
	local gesture = self.inputs.pointer_gesture
	self.inputs.released_press_target = gesture and gesture.released_target or nil
	if not gesture then
		self.inputs.last_mouse_down_event = nil
		self.inputs.last_drag_event = nil
	end
end

---@param root gui.View
function PointerGesture:clearPointerGestureInSubtree(root)
	local gesture = self.inputs.pointer_gesture
	if not gesture then
		return
	end
	if self.inputs:isInSubtree(gesture.press_target, root) then
		gesture.press_target.pressed = false
	end
	-- After drag capture is committed, the original pressed view no longer
	-- owns the gesture and may be detached by its synthetic MouseUp callback.
	local owner = gesture.dragging and gesture.capture_target or gesture.press_target
	if self.inputs:isInSubtree(owner, root) then
		self.inputs.pointer_gesture = nil
		self:syncLegacyGestureState()
	elseif self.inputs:isInSubtree(gesture.released_target, root) then
		gesture.released_target = nil
		self:syncLegacyGestureState()
	end
end

---@private
---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.MouseDownEvent?
function PointerGesture:handleMouseDown(event, modifiers)
	local e = MouseDownEvent(modifiers)
	e.button = event[3]
	e.x = self.inputs.mouse_x
	e.y = self.inputs.mouse_y
	e.time = event.time
	local target, current_target = self.targeting:dispatch(e)
	if target ~= self.inputs.keyboard_focus and self.inputs.keyboard_focus then
		self.inputs:setKeyboardFocus(nil, modifiers)
	end
	if not target then
		self.inputs.pointer_gesture = nil
		self:syncLegacyGestureState()
		return
	end
	e.target = target
	e.current_target = current_target or target
	self.inputs.pointer_gesture = {
		button = e.button,
		press_target = target,
		capture_target = e.current_target,
		x = e.x,
		y = e.y,
		time = e.time,
		dragging = false,
	}
	self.inputs.last_mouse_down_event = e
	self.inputs.last_drag_event = nil
	self.inputs.released_press_target = nil
	target.pressed = true
	return e
end

---@private
---@param gesture gui.PointerGestureState
---@param dx number
---@param dy number
---@return gui.View capture
function PointerGesture:chooseDragCapture(gesture, dx, dy)
	local capture = gesture.capture_target
	local wanted_axis = math.abs(dx) > math.abs(dy) and "horizontal" or "vertical"
	if capture.drag_axis == wanted_axis then
		return capture
	end
	local fallback ---@type gui.View?
	local view = gesture.press_target
	while view do
		if view.drag_axis then
			fallback = fallback or view
			if view.drag_axis == wanted_axis then
				return view
			end
		end
		view = view.parent
	end
	if not capture.drag_axis and fallback then
		return fallback
	end
	return capture
end

---@private
---@param modifiers gui.ModifierKeys
---@param event_time number
---@return gui.MouseEvent?
function PointerGesture:handleMouseMove(modifiers, event_time)
	local gesture = self.inputs.pointer_gesture
	if not gesture then
		return
	end
	if gesture.dragging then
		local e = DragEvent(modifiers)
		e.target = gesture.capture_target
		e.current_target = gesture.capture_target
		e.button = gesture.button
		return e
	end

	local dx = self.inputs.mouse_x - gesture.x
	local dy = self.inputs.mouse_y - gesture.y
	if dx * dx + dy * dy < self.DRAG_START_THRESHOLD * self.DRAG_START_THRESHOLD then
		return
	end
	local capture = self:chooseDragCapture(gesture, dx, dy)
	local pressed_target = gesture.press_target
	pressed_target.pressed = false
	gesture.capture_target = capture
	gesture.dragging = true
	self.inputs.last_mouse_down_event.target = capture
	self.inputs.last_mouse_down_event.current_target = capture

	-- Commit the transition before invoking MouseUp. The callback may detach
	-- either target and clear this gesture.
	if pressed_target ~= capture then
		gesture.released_target = pressed_target
		self.inputs.released_press_target = pressed_target
		local mouse_up = MouseUpEvent(modifiers)
		mouse_up.target = pressed_target
		mouse_up.current_target = pressed_target
		mouse_up.button = gesture.button
		mouse_up.x = self.inputs.mouse_x
		mouse_up.y = self.inputs.mouse_y
		mouse_up.time = event_time
		self.targeting:dispatchToTarget(mouse_up)
		if self.inputs.pointer_gesture ~= gesture then
			return
		end
	end

	local e = DragStartEvent(modifiers)
	e.target = capture
	e.current_target = capture
	e.button = gesture.button
	return e
end

---@private
---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.MouseUpEvent?
function PointerGesture:handleMouseUp(event, modifiers)
	local gesture = self.inputs.pointer_gesture
	if not gesture or event[3] ~= gesture.button then
		return
	end
	gesture.press_target.pressed = false
	if not gesture.dragging then
		local dx = gesture.x - self.inputs.mouse_x
		local dy = gesture.y - self.inputs.mouse_y
		if math.sqrt(dx * dx + dy * dy) < self.MOUSE_CLICK_MAX_DISTANCE then
			local click = MouseClickEvent(modifiers)
			click.target = gesture.press_target
			click.current_target = gesture.press_target
			click.x = self.inputs.mouse_x
			click.y = self.inputs.mouse_y
			click.button = gesture.button
			self.inputs:dispatchEvent(click)
			if self.inputs.pointer_gesture ~= gesture then
				return
			end
		end
	else
		local drag_end = DragEndEvent(modifiers)
		drag_end.target = gesture.capture_target
		drag_end.current_target = gesture.capture_target
		drag_end.button = gesture.button
		drag_end.x = self.inputs.mouse_x
		drag_end.y = self.inputs.mouse_y
		drag_end.time = event.time
		drag_end.press_x = gesture.x
		drag_end.press_y = gesture.y
		drag_end.press_time = gesture.time
		self.inputs:dispatchEvent(drag_end)
		if self.inputs.pointer_gesture ~= gesture then
			return
		end
	end

	local e = MouseUpEvent(modifiers)
	e.button = gesture.button
	e.x = self.inputs.mouse_x
	e.y = self.inputs.mouse_y
	e.time = event.time
	e.target = gesture.capture_target
	e.current_target = gesture.capture_target
	self.inputs.pointer_gesture = nil
	self:syncLegacyGestureState()
	if e.target ~= gesture.released_target then
		self.targeting:dispatchToTarget(e)
	end
	return e
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.MouseEvent?
function PointerGesture:dispatchMouseEvent(event, modifiers)
	if event.name == "mousepressed" then
		return self:handleMouseDown(event, modifiers)
	elseif event.name == "mousereleased" then
		return self:handleMouseUp(event, modifiers)
	end

	local e ---@type gui.MouseEvent?
	if event.name == "wheelmoved" then
		local scroll = ScrollEvent(modifiers)
		scroll.direction_x = event[1]
		scroll.direction_y = event[2]
		e = scroll
	elseif event.name == "mousemoved" then
		e = self:handleMouseMove(modifiers, event.time)
	end
	if not e then
		return
	end

	e.x = self.inputs.mouse_x
	e.y = self.inputs.mouse_y
	e.time = event.time
	local gesture = self.inputs.pointer_gesture
	if gesture then
		e.press_x = gesture.x
		e.press_y = gesture.y
		e.press_time = gesture.time
	end
	if e.target then
		self.targeting:dispatchToTarget(e)
		if self.inputs.pointer_gesture == gesture and event.name == "mousemoved" and gesture then
			self.inputs.last_drag_event = e
		end
		return e
	end
	local target, current_target = self.targeting:dispatch(e)
	e.target = target
	e.current_target = current_target
	return target and e or nil
end

return PointerGesture
