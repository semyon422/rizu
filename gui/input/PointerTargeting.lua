local class = require("class")
local table_util = require("table_util")
local HoverEvent = require("gui.input.events.HoverEvent")
local HoverLostEvent = require("gui.input.events.HoverLostEvent")

---@class gui.PointerTargeting
---@operator call: gui.PointerTargeting
---@field private inputs gui.Inputs
local PointerTargeting = class()

---@type gui.ModifierKeys
local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param inputs gui.Inputs
function PointerTargeting:new(inputs)
	self.inputs = inputs
	inputs.mouse_x = -math.huge
	inputs.mouse_y = -math.huge
	inputs.mouse_target = nil
	---@type gui.View[]
	inputs.mouse_hits = {}
end

---@param mouse_x number Global mouse X position
---@param mouse_y number Global mouse Y position
function PointerTargeting:reset(mouse_x, mouse_y)
	local inputs = self.inputs
	inputs.mouse_x = mouse_x
	inputs.mouse_y = mouse_y
	inputs.mouse_target = nil
	table_util.clear(inputs.mouse_hits)
end

---@param root gui.View
function PointerTargeting:clearSubtree(root)
	local inputs = self.inputs
	if inputs:isInSubtree(inputs.mouse_target, root) then
		inputs.mouse_target.mouse_over = false
		inputs.mouse_target = nil
	end
	for i = #inputs.mouse_hits, 1, -1 do
		if inputs:isInSubtree(inputs.mouse_hits[i], root) then
			table.remove(inputs.mouse_hits, i)
		end
	end
end

---@param view gui.View
function PointerTargeting:processView(view)
	if not view.handles_mouse_input then
		return
	end
	local inputs = self.inputs
	local had_focus = view.mouse_over
	local is_mouse_over = view:isMouseOver(inputs.mouse_x, inputs.mouse_y)
	local clip_rect = view.clip_rect
	if is_mouse_over and clip_rect then
		local x, y = inputs.mouse_x, inputs.mouse_y
		is_mouse_over = clip_rect[3] > 0 and clip_rect[4] > 0
			and x >= clip_rect[1] and x <= clip_rect[1] + clip_rect[3]
			and y >= clip_rect[2] and y <= clip_rect[2] + clip_rect[4]
	end

	if is_mouse_over then
		inputs.mouse_hits[#inputs.mouse_hits + 1] = view
	end

	if not inputs.mouse_target then
		view.mouse_over = is_mouse_over
		if view.mouse_over then
			inputs.mouse_target = view
		end
		if not had_focus and view.mouse_over then
			local e = HoverEvent(default_modifiers)
			e.target = view
			inputs:dispatchEvent(e)
		elseif had_focus and not view.mouse_over then
			local e = HoverLostEvent(default_modifiers)
			e.target = view
			inputs:dispatchEvent(e)
		end
	elseif view.mouse_over then
		view.mouse_over = false
		local e = HoverLostEvent(default_modifiers)
		e.target = view
		inputs:dispatchEvent(e)
	end
end

---@private
---@param view gui.View
---@return boolean present
function PointerTargeting:hasMouseHit(view)
	local hits = self.inputs.mouse_hits
	for i = 1, #hits do
		if hits[i] == view then
			return true
		end
	end
	return false
end

---@param e gui.MouseEvent
---@return gui.View? target
---@return gui.View? current_target
---@return boolean? handled
function PointerTargeting:dispatch(e)
	local inputs = self.inputs
	local target = e.target or inputs.mouse_hits[1] or inputs.mouse_target
	if not target then
		return
	end
	e.target = target

	if #inputs.mouse_hits > 0 then
		-- Input callbacks can detach views and mutate mouse_hits. Iterate a
		-- snapshot, but skip entries removed from the live hit list.
		local hits = {unpack(inputs.mouse_hits)}
		for _, view in ipairs(hits) do
			if self:hasMouseHit(view) then
				e.current_target = view
				local handled = inputs:dispatchEvent(e)
				if handled or e.stop then
					return target, view, handled
				end
			end
		end
	else
		e.current_target = target
		local handled = inputs:dispatchEvent(e)
		if handled or e.stop then
			return target, target, handled
		end
	end
	return target
end

---@param e gui.MouseEvent
---@return boolean? handled
function PointerTargeting:dispatchToTarget(e)
	if not e.target then
		return
	end
	e.current_target = e.current_target or e.target
	return self.inputs:dispatchEvent(e)
end

return PointerTargeting
