local class = require("class")
local table_util = require("table_util")
local MouseDownEvent = require("gui.input.events.MouseDownEvent")
local MouseUpEvent = require("gui.input.events.MouseUpEvent")
local MouseClickEvent = require("gui.input.events.MouseClickEvent")
local ScrollEvent = require("gui.input.events.ScrollEvent")
local DragEvent = require("gui.input.events.DragEvent")
local DragStartEvent = require("gui.input.events.DragStartEvent")
local DragEndEvent = require("gui.input.events.DragEndEvent")
local FocusEvent = require("gui.input.events.FocusEvent")
local FocusLostEvent = require("gui.input.events.FocusLostEvent")
local KeyDownEvent = require("gui.input.events.KeyDownEvent")
local KeyUpEvent = require("gui.input.events.KeyUpEvent")
local TextInputEvent = require("gui.input.events.TextInputEvent")
local HoverEvent = require("gui.input.events.HoverEvent")
local HoverLostEvent = require("gui.input.events.HoverLostEvent")

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
---@field last_mouse_down_event gui.MouseDownEvent?
---@field released_press_target gui.View?
---@field focus_scopes gui.FocusScope[]
local Inputs = class()

---@class gui.FocusScope
---@field root gui.View
---@field previous_focus gui.View?

Inputs.MOUSE_CLICK_MAX_DISTANCE = 6
Inputs.DRAG_START_THRESHOLD = 4

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

---@type gui.ModifierKeys
local default_modifiers = {control = false, shift = false, alt = false, super = false}

function Inputs:new()
	self.mouse_x = -math.huge
	self.mouse_y = -math.huge
	self.mouse_target = nil
	self.mouse_hits = {}
	self.focus_requesters = {}
	self.focus_scopes = {}
	self.released_press_target = nil
end

---@param mouse_x number Global Mouse X position
---@param mouse_y number Global Mouse Y position
function Inputs:resetTraversalContext(mouse_x, mouse_y)
	self.mouse_x = mouse_x
	self.mouse_y = mouse_y
	self.mouse_target = nil
	table_util.clear(self.mouse_hits)
	table_util.clear(self.focus_requesters)
end

---@param mouse_x number Global Mouse X position
---@param mouse_y number Global Mouse Y position
function Inputs:beginFrame(mouse_x, mouse_y)
	self:resetTraversalContext(mouse_x, mouse_y)
end

---@param root gui.View
function Inputs:clearSubtree(root)
	local function contains(view)
		return view and view.flat_index and root.flat_index
			and view.screen == root.screen
			and view.flat_index >= root.flat_index
			and view.flat_index <= root.flat_subtree_end
	end

	for i = #self.focus_scopes, 1, -1 do
		if contains(self.focus_scopes[i].root) then
			table.remove(self.focus_scopes, i)
		end
	end
	if contains(self.keyboard_focus) then
		self.keyboard_focus.focused = false
		self.keyboard_focus = nil
	end
	if contains(self.mouse_target) then
		self.mouse_target.mouse_over = false
		self.mouse_target = nil
	end
	if self.last_mouse_down_event and contains(self.last_mouse_down_event.target) then
		self.last_mouse_down_event.target.pressed = false
		self.last_mouse_down_event = nil
	end
	if self.last_drag_event and contains(self.last_drag_event.target) then
		self.last_drag_event = nil
	end
	if contains(self.released_press_target) then
		self.released_press_target = nil
	end
	for i = #self.mouse_hits, 1, -1 do
		if contains(self.mouse_hits[i]) then
			table.remove(self.mouse_hits, i)
		end
	end
	for i = #self.focus_requesters, 1, -1 do
		if contains(self.focus_requesters[i]) then
			table.remove(self.focus_requesters, i)
		end
	end
end

---@param view gui.View
function Inputs:processView(view)
	if view.handles_mouse_input or view.handles_keyboard_input then
		if view.handles_keyboard_input and self:isInActiveFocusScope(view) then
			if view.keyboard_input_fallback then
				self.focus_requesters[#self.focus_requesters + 1] = view
			else
				local index = #self.focus_requesters + 1
				for i, requester in ipairs(self.focus_requesters) do
					if requester.keyboard_input_fallback then
						index = i
						break
					end
				end
				table.insert(self.focus_requesters, index, view)
			end
		end

		if view.handles_mouse_input then
			local had_focus = view.mouse_over
			local is_mouse_over = view:isMouseOver(self.mouse_x, self.mouse_y)
			local clip_rect = view.clip_rect
			if is_mouse_over and clip_rect then
				local x, y = self.mouse_x, self.mouse_y
				is_mouse_over = clip_rect[3] > 0 and clip_rect[4] > 0
					and x >= clip_rect[1] and x <= clip_rect[1] + clip_rect[3]
					and y >= clip_rect[2] and y <= clip_rect[2] + clip_rect[4]
			end

			if is_mouse_over then
				table.insert(self.mouse_hits, view)
			end

			if not self.mouse_target then
				view.mouse_over = is_mouse_over

				if view.mouse_over then
					self.mouse_target = view
				end

				if not had_focus and view.mouse_over then
					local e = HoverEvent(default_modifiers)
					e.target = view
					self:dispatchEvent(e)
				elseif had_focus and not view.mouse_over then
					local e = HoverLostEvent(default_modifiers)
					e.target = view
					self:dispatchEvent(e)
				end
			else
				if view.mouse_over then
					view.mouse_over = false

					local e = HoverLostEvent(default_modifiers)
					e.target = view
					self:dispatchEvent(e)
				end
			end
		end
	end
end

---@private
---@param e gui.MouseEvent
---@return gui.View? target
---@return gui.View? current_target
---@return boolean? handled
function Inputs:dispatchMouseTargets(e)
	local target = e.target or self.mouse_hits[1] or self.mouse_target
	if not target then
		return
	end

	e.target = target

	if #self.mouse_hits > 0 then
		for _, view in ipairs(self.mouse_hits) do
			e.current_target = view
			local handled = self:dispatchEvent(e)
			if handled or e.stop then
				return target, view, handled
			end
		end
	else
		e.current_target = target
		local handled = self:dispatchEvent(e)
		if handled or e.stop then
			return target, target, handled
		end
	end

	return target
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.View? target
---@return gui.View? current_target
---@return gui.MouseDownEvent
---@return boolean? handled
function Inputs:handleMouseDown(event, modifiers)
	local e = MouseDownEvent(modifiers)
	e.button = event[3]
	e.x = self.mouse_x
	e.y = self.mouse_y
	e.time = event.time or love.timer.getTime()

	local target, current_target, handled = self:dispatchMouseTargets(e)
	self.released_press_target = nil
	e.target = target
	-- The view that handled MouseDown captures a future drag. Keep the
	-- original hit as target until the drag threshold is crossed so clicks
	-- still dispatch to the pressed child.
	e.current_target = current_target or target
	self.last_mouse_down_event = e
	if target then
		target.pressed = true
	end
	if target ~= self.keyboard_focus and self.keyboard_focus then
		self:setKeyboardFocus(nil, modifiers)
	end

	return target, current_target, e, handled
end

---@private
---@param e gui.MouseEvent
---@return boolean? handled
function Inputs:dispatchMouseEventToTarget(e)
	if not e.target then
		return
	end
	e.current_target = e.current_target or e.target
	return self:dispatchEvent(e)
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.View? target
---@return gui.View? current_target
---@return gui.MouseUpEvent?
---@return boolean? handled
function Inputs:handleMouseUp(event, modifiers)
	if not self.last_mouse_down_event then
		return
	end

	if event[3] ~= self.last_mouse_down_event.button then
		return
	end

	local pressed_target = self.last_mouse_down_event.target
	if pressed_target then
		pressed_target.pressed = false
	end

	local dx = (self.last_mouse_down_event.x - self.mouse_x)
	local dy = (self.last_mouse_down_event.y - self.mouse_y)
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance < self.MOUSE_CLICK_MAX_DISTANCE and not self.last_drag_event then
		local ce = MouseClickEvent(modifiers)
		ce.target = self.last_mouse_down_event.target
		ce.current_target = ce.target
		ce.x = self.mouse_x
		ce.y = self.mouse_y
		ce.button = event[3]
		if ce.target then
			self:dispatchEvent(ce)
		end
	end

	if self.last_drag_event then
		local de = DragEndEvent(modifiers)
		de.target = self.last_drag_event.target
		de.current_target = self.last_drag_event.current_target or de.target
		de.x = self.mouse_x
		de.y = self.mouse_y
		de.time = event.time or love.timer.getTime()
		de.press_x = self.last_mouse_down_event.x
		de.press_y = self.last_mouse_down_event.y
		de.press_time = self.last_mouse_down_event.time
		if de.target then
			self:dispatchEvent(de)
		end
		self.last_drag_event = nil
	end

	local e = MouseUpEvent(modifiers)
	e.button = event[3]
	e.x = self.mouse_x
	e.y = self.mouse_y
	e.time = event.time or love.timer.getTime()
	e.target = pressed_target
	e.current_target = pressed_target
	self.last_mouse_down_event = nil
	local handled
	if pressed_target ~= self.released_press_target then
		handled = self:dispatchMouseEventToTarget(e)
	end
	self.released_press_target = nil
	return pressed_target, pressed_target, e, handled
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.ScrollEvent
function Inputs:handleWheel(event, modifiers)
	local e = ScrollEvent(modifiers)
	e.direction_x = event[1]
	e.direction_y = event[2]
	return e
end

---@private
---@param modifiers gui.ModifierKeys
---@param event_time number
---@return gui.MouseEvent?
function Inputs:handleMouseMove(modifiers, event_time)
	if not self.last_mouse_down_event then
		return
	end

	---@type gui.MouseEvent
	local e
	if not self.last_drag_event then
		local dx = self.mouse_x - self.last_mouse_down_event.x
		local dy = self.mouse_y - self.last_mouse_down_event.y
		if dx * dx + dy * dy < self.DRAG_START_THRESHOLD * self.DRAG_START_THRESHOLD then
			return
		end
		local capture = self.last_mouse_down_event.current_target or self.last_mouse_down_event.target
		local wanted_axis = math.abs(dx) > math.abs(dy) and "horizontal" or "vertical"
		if not capture.drag_axis or capture.drag_axis ~= wanted_axis then
			local fallback ---@type gui.View?
			local view = self.last_mouse_down_event.target
			while view do
				if view.drag_axis then
					fallback = fallback or view
					if view.drag_axis == wanted_axis then
						capture = view
						break
					end
				end
				view = view.parent
			end
			-- An axis-neutral pressed child does not own drag direction. If no
			-- ancestor matches the initial movement, let the nearest axis owner
			-- capture so a later change in direction continues the same drag.
			if not capture.drag_axis and fallback then
				capture = fallback
			end
		end
		local pressed_target = self.last_mouse_down_event.target
		if pressed_target then
			pressed_target.pressed = false
		end
		-- Release a pressed child when drag arbitration transfers capture to an
		-- ancestor. The capture owner must keep its normal release lifecycle.
		if pressed_target and pressed_target ~= capture then
			local mouse_up = MouseUpEvent(modifiers)
			mouse_up.target = pressed_target
			mouse_up.current_target = pressed_target
			mouse_up.button = self.last_mouse_down_event.button
			mouse_up.x = self.mouse_x
			mouse_up.y = self.mouse_y
			mouse_up.time = event_time
			self:dispatchMouseEventToTarget(mouse_up)
			self.released_press_target = pressed_target
		end
		-- Once this is a drag, only the capture owner matters. Retargeting the
		-- stored press also prevents culling the original child during the drag
		-- from cancelling its ancestor's capture.
		self.last_mouse_down_event.target = capture
		self.last_mouse_down_event.current_target = capture
		e = DragStartEvent(modifiers)
		e.target = capture
		e.current_target = capture
		e.button = self.last_mouse_down_event.button
	else
		e = DragEvent(modifiers)
		e.target = self.last_drag_event.target
		e.current_target = self.last_drag_event.current_target or e.target
		e.button = self.last_mouse_down_event.button
	end
	return e
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
	local scope = self.focus_scopes[#self.focus_scopes]
	if not scope or self:isInSubtree(view, scope.root) then
		return true
	end
	-- A scope may delegate its final unhandled-key policy to an ancestor host,
	-- such as ModalManager. Ordinary ancestor requesters remain excluded.
	return view.keyboard_input_fallback and self:isInSubtree(scope.root, view)
end

---@param root gui.View
function Inputs:pushFocusScope(root)
	assert(root.screen and root.flat_index, "focus scope root must be attached")
	self.focus_scopes[#self.focus_scopes + 1] = {root = root, previous_focus = self.keyboard_focus}
	if self.keyboard_focus and not self:isInSubtree(self.keyboard_focus, root) then
		self:setKeyboardFocus(nil, default_modifiers)
	end
end

---@param root gui.View?
function Inputs:popFocusScope(root)
	local scope = self.focus_scopes[#self.focus_scopes]
	assert(scope, "focus scope stack is empty")
	assert(not root or scope.root == root, "focus scopes must be popped in stack order")
	self.focus_scopes[#self.focus_scopes] = nil
	local previous = scope.previous_focus
	if previous and previous.screen and previous.flat_index and previous.effective_visible
		and previous.effective_enabled and previous.present and previous.cull_mask == 0
	then
		self:setKeyboardFocus(previous, default_modifiers)
	end
end

---@param node gui.View?
---@param modifiers gui.ModifierKeys
function Inputs:setKeyboardFocus(node, modifiers)
	local scope = self.focus_scopes[#self.focus_scopes]
	assert(not node or not scope or self:isInSubtree(node, scope.root),
		"keyboard focus must be inside the active focus scope")
	if self.keyboard_focus then
		self.keyboard_focus.focused = false
		local e = FocusLostEvent(modifiers)
		e.target = self.keyboard_focus
		e.next_focused = node
		self:dispatchEvent(e)
	end

	if node then
		node.focused = true
		local e = FocusEvent(modifiers)
		e.target = node
		e.previously_focused = self.keyboard_focus
		self:dispatchEvent(e)
	end

	self.keyboard_focus = node
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
---@return gui.MouseEvent?
function Inputs:dispatchMouseEvent(event, modifiers)
	local e = nil ---@type gui.MouseEvent?
	local target = nil ---@type gui.View?
	local current_target = nil ---@type gui.View?
	local handled = nil ---@type boolean?

	if event.name == "mousepressed" then
		target, current_target, e, handled = self:handleMouseDown(event, modifiers)
		if not target then
			self.last_mouse_down_event = nil
			return
		end
		if not handled then
			return e
		end
		return e
	elseif event.name == "mousereleased" then
		target, current_target, e, handled = self:handleMouseUp(event, modifiers)
		if not e then
			return
		end
		if not target then
			return
		end
		return e
	elseif event.name == "wheelmoved" then
		e = self:handleWheel(event, modifiers)
	elseif event.name == "mousemoved" then
		e = self:handleMouseMove(modifiers, event.time or love.timer.getTime())
	end

	if not e then
		return
	end

	e.x = self.mouse_x
	e.y = self.mouse_y
	e.time = event.time or love.timer.getTime()
	if self.last_mouse_down_event then
		e.press_x = self.last_mouse_down_event.x
		e.press_y = self.last_mouse_down_event.y
		e.press_time = self.last_mouse_down_event.time
	end

	if e.target then
		self:dispatchMouseEventToTarget(e)
		if event.name == "mousemoved" and not self.last_drag_event then
			self.last_drag_event = e
		end
		return e
	end

	target, current_target, handled = self:dispatchMouseTargets(e)
	e.target = target
	e.current_target = current_target
	if not target then
		return
	end

	if event.name == "mousemoved" and not self.last_drag_event then
		self.last_drag_event = e
	end

	return e
end

---@private
---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
function Inputs:dispatchKeyboardEvent(event, modifiers)
	local e = nil ---@type gui.KeyboardEvent?

	if event.name == "keypressed" then
		e = KeyDownEvent(modifiers)
	elseif event.name == "keyreleased" then
		e = KeyUpEvent(modifiers)
	elseif event.name == "textinput" then
		e = TextInputEvent(modifiers)
	else
		return
	end

	---@cast e -?
	if event.name == "textinput" then
		e.text = event[1]
	else
		e.key = event[1]
		e.is_repeated = event[3] or false
	end

	if self.keyboard_focus then
		e.target = self.keyboard_focus
		local handled = self:dispatchEvent(e)
		if handled or e.stop then
			return
		end
	end

	for _, view in ipairs(self.focus_requesters) do
		if view ~= self.keyboard_focus then
			e.target = view
			e.current_target = view
			local handled = self:dispatchEvent(e)
			if handled or e.stop then
				break
			end
		end
	end
end

---@param event {name: string, [integer]: any}
---@param modifiers gui.ModifierKeys
function Inputs:receive(event, modifiers)
	if mouse_events[event.name] then
		self:dispatchMouseEvent(event, modifiers)
	elseif keyboard_events[event.name] then
		self:dispatchKeyboardEvent(event, modifiers)
	else
		return
	end
end

---@param e gui.UIEvent
---@return boolean? handled
function Inputs:dispatchEvent(e)
	return e:trigger()
end

return Inputs
