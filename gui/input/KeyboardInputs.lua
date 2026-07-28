local class = require("class")
local table_util = require("table_util")
local FocusEvent = require("gui.input.events.FocusEvent")
local FocusLostEvent = require("gui.input.events.FocusLostEvent")
local KeyDownEvent = require("gui.input.events.KeyDownEvent")
local KeyUpEvent = require("gui.input.events.KeyUpEvent")
local TextInputEvent = require("gui.input.events.TextInputEvent")

---@class gui.FocusScope
---@field root gui.View
---@field previous_focus gui.View?

---@class gui.KeyboardInputs
---@operator call: gui.KeyboardInputs
---@field private inputs gui.Inputs
local KeyboardInputs = class()

---@type gui.ModifierKeys
local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param inputs gui.Inputs
function KeyboardInputs:new(inputs)
	self.inputs = inputs
	---@type gui.View[]
	inputs.focus_requesters = {}
	---@type gui.FocusScope[]
	inputs.focus_scopes = {}
end

function KeyboardInputs:resetTargets()
	table_util.clear(self.inputs.focus_requesters)
end

---@param root gui.View
function KeyboardInputs:clearSubtree(root)
	local inputs = self.inputs
	for i = #inputs.focus_scopes, 1, -1 do
		if inputs:isInSubtree(inputs.focus_scopes[i].root, root) then
			table.remove(inputs.focus_scopes, i)
		end
	end
	if inputs:isInSubtree(inputs.keyboard_focus, root) then
		inputs.keyboard_focus.focused = false
		inputs.keyboard_focus = nil
	end
	for i = #inputs.focus_requesters, 1, -1 do
		if inputs:isInSubtree(inputs.focus_requesters[i], root) then
			table.remove(inputs.focus_requesters, i)
		end
	end
end

---@param view gui.View
function KeyboardInputs:processView(view)
	local inputs = self.inputs
	if not view.handles_keyboard_input or not self:isInActiveFocusScope(view) then
		return
	end
	if view.keyboard_input_fallback then
		inputs.focus_requesters[#inputs.focus_requesters + 1] = view
		return
	end
	local index = #inputs.focus_requesters + 1
	for i, requester in ipairs(inputs.focus_requesters) do
		if requester.keyboard_input_fallback then
			index = i
			break
		end
	end
	table.insert(inputs.focus_requesters, index, view)
end

---@param view gui.View
---@return boolean eligible
function KeyboardInputs:isInActiveFocusScope(view)
	local inputs = self.inputs
	local scope = inputs.focus_scopes[#inputs.focus_scopes]
	if not scope or inputs:isInSubtree(view, scope.root) then
		return true
	end
	return view.keyboard_input_fallback and inputs:isInSubtree(scope.root, view)
end

---@param root gui.View
function KeyboardInputs:pushFocusScope(root)
	local inputs = self.inputs
	assert(root.screen and root.flat_index, "focus scope root must be attached")
	inputs.focus_scopes[#inputs.focus_scopes + 1] = {root = root, previous_focus = inputs.keyboard_focus}
	if inputs.keyboard_focus and not inputs:isInSubtree(inputs.keyboard_focus, root) then
		self:setKeyboardFocus(nil, default_modifiers)
	end
end

---@param root gui.View?
function KeyboardInputs:popFocusScope(root)
	local inputs = self.inputs
	local scope = inputs.focus_scopes[#inputs.focus_scopes]
	assert(scope, "focus scope stack is empty")
	assert(not root or scope.root == root, "focus scopes must be popped in stack order")
	inputs.focus_scopes[#inputs.focus_scopes] = nil
	local previous = scope.previous_focus
	if previous and previous.screen and previous.flat_index and previous.effective_visible
		and previous.effective_enabled and previous.present and previous.cull_mask == 0
	then
		self:setKeyboardFocus(previous, default_modifiers)
	end
end

---@param node gui.View?
---@param modifiers gui.ModifierKeys
function KeyboardInputs:setKeyboardFocus(node, modifiers)
	local inputs = self.inputs
	local scope = inputs.focus_scopes[#inputs.focus_scopes]
	assert(not node or not scope or inputs:isInSubtree(node, scope.root),
		"keyboard focus must be inside the active focus scope")
	if inputs.keyboard_focus then
		inputs.keyboard_focus.focused = false
		local e = FocusLostEvent(modifiers)
		e.target = inputs.keyboard_focus
		e.next_focused = node
		inputs:dispatchEvent(e)
	end
	if node then
		node.focused = true
		local e = FocusEvent(modifiers)
		e.target = node
		e.previously_focused = inputs.keyboard_focus
		inputs:dispatchEvent(e)
	end
	inputs.keyboard_focus = node
end

---@param event {name: string, time: number, [integer]: any}
---@param modifiers gui.ModifierKeys
function KeyboardInputs:dispatch(event, modifiers)
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

	local inputs = self.inputs
	if inputs.keyboard_focus then
		e.target = inputs.keyboard_focus
		local handled = inputs:dispatchEvent(e)
		if handled or e.stop then
			return
		end
	end

	local requesters = {unpack(inputs.focus_requesters)}
	for _, view in ipairs(requesters) do
		local present = false
		for i = 1, #inputs.focus_requesters do
			if inputs.focus_requesters[i] == view then
				present = true
				break
			end
		end
		if present and view ~= inputs.keyboard_focus then
			e.target = view
			e.current_target = view
			local handled = inputs:dispatchEvent(e)
			if handled or e.stop then
				break
			end
		end
	end
end

return KeyboardInputs
