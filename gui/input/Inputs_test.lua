local View = require("gui.View")
local Inputs = require("gui.input.Inputs")

local test = {}

local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@param width number
---@param height number
---@return gui.View
local function create_view(width, height)
	local view = View()
	view.width = width
	view.height = height
	view:relayout()
	return view
end

---@param t testing.T
function test.no_bubbling(t)
	local inputs = Inputs()
	local view = create_view(100, 100)

	local event_count = 0
	view.onMouseDown = function()
		event_count = event_count + 1
	end

	table.insert(inputs.mouse_hits, view)
	inputs.mouse_target = view
	inputs:receive({name = "mousepressed", 0, 0, 1}, default_modifiers)

	t:eq(event_count, 1)
end

---@param t testing.T
function test.mouse_click(t)
	local btn = create_view(100, 100)
	local inputs = Inputs()

	local events = {}
	btn.onMouseDown = function() table.insert(events, "down") end
	btn.onMouseUp = function() table.insert(events, "up") end
	btn.onMouseClick = function() table.insert(events, "click") end

	table.insert(inputs.mouse_hits, btn)
	inputs.mouse_target = btn
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	t:eq(btn.pressed, true)
	inputs:receive({name = "mousereleased", 10, 10, 1}, default_modifiers)
	t:eq(btn.pressed, false)

	t:tdeq(events, {"down", "click", "up"})

	events = {}
	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)

	inputs.mouse_x = 9999999999
	inputs.mouse_y = 9999999999
	inputs:receive({name = "mousemoved", 100, 100, 0, 0}, default_modifiers)
	inputs:receive({name = "mousereleased", 100, 100, 1}, default_modifiers)
	t:eq(btn.pressed, false)

	t:tdeq(events, {"down", "up"})
end

---@param t testing.T
function test.keyboard_focus(t)
	local textbox1 = create_view(100, 100)
	local textbox2 = create_view(100, 100)
	local inputs = Inputs()

	local events1 = {}
	local events2 = {}

	textbox1.onFocus = function() table.insert(events1, "focus") end
	textbox1.onFocusLost = function() table.insert(events1, "blur") end
	textbox1.onTextInput = function(_, event) table.insert(events1, "text:" .. event.text) end

	textbox2.onFocus = function() table.insert(events2, "focus") end
	textbox2.onFocusLost = function() table.insert(events2, "blur") end
	textbox2.onTextInput = function(_, event) table.insert(events2, "text:" .. event.text) end

	inputs:setKeyboardFocus(textbox1, default_modifiers)
	t:tdeq(events1, {"focus"})
	t:tdeq(events2, {})

	inputs:receive({name = "textinput", "a"}, default_modifiers)
	t:tdeq(events1, {"focus", "text:a"})
	t:tdeq(events2, {})

	inputs:setKeyboardFocus(textbox2, default_modifiers)
	t:tdeq(events1, {"focus", "text:a", "blur"})
	t:tdeq(events2, {"focus"})

	inputs:receive({name = "textinput", "b"}, default_modifiers)
	t:tdeq(events1, {"focus", "text:a", "blur"})
	t:tdeq(events2, {"focus", "text:b"})

	inputs:setKeyboardFocus(nil, default_modifiers)
	t:tdeq(events2, {"focus", "text:b", "blur"})
end

---@param t testing.T
function test.mousepressed_clears_keyboard_focus_if_outside(t)
	local inputs = Inputs()
	local view1 = create_view(100, 100)
	local view2 = create_view(100, 100)

	view1.onFocus = function() end
	view1.onFocusLost = function() end

	inputs:setKeyboardFocus(view1, default_modifiers)
	t:eq(inputs.keyboard_focus, view1)

	table.insert(inputs.mouse_hits, view1)
	inputs.mouse_target = view1
	inputs:receive({name = "mousepressed", 0, 0, 1}, default_modifiers)
	t:eq(inputs.keyboard_focus, view1)

	table.clear(inputs.mouse_hits)
	table.insert(inputs.mouse_hits, view2)
	inputs.mouse_target = view2
	inputs:receive({name = "mousepressed", 0, 0, 1}, default_modifiers)
	t:eq(inputs.keyboard_focus, nil)
end

---@param t testing.T
function test.dragging(t)
	local draggable = create_view(100, 100)
	local inputs = Inputs()

	local events = {}
	draggable.onDragStart = function() table.insert(events, "start") end
	draggable.onDrag = function() table.insert(events, "drag") end
	draggable.onDragEnd = function() table.insert(events, "end") end

	table.insert(inputs.mouse_hits, draggable)
	inputs.mouse_target = draggable
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	t:tdeq(events, {})

	inputs.mouse_x = 15
	inputs.mouse_y = 15
	inputs:receive({name = "mousemoved", 15, 15, 5, 5}, default_modifiers)
	t:tdeq(events, {"start"})

	inputs.mouse_x = 20
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 20, 20, 5, 5}, default_modifiers)
	t:tdeq(events, {"start", "drag"})

	inputs:receive({name = "mousereleased", 20, 20, 1}, default_modifiers)
	t:tdeq(events, {"start", "drag", "end"})
end

---@param t testing.T
function test.scrolling(t)
	local scrollable = create_view(100, 100)
	local inputs = Inputs()

	local events = {}
	scrollable.onScroll = function(self, e) table.insert(events, {e.direction_x, e.direction_y}) end

	table.insert(inputs.mouse_hits, scrollable)
	inputs.mouse_target = scrollable
	inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:tdeq(events, {{0, 1}})
end

---@param t testing.T
function test.mouse_events_without_target_are_ignored(t)
	local inputs = Inputs()
	local event_count = 0

	inputs.dispatchEvent = function()
		event_count = event_count + 1
	end

	inputs.mouse_x = 10
	inputs.mouse_y = 20

	local mouse_down = inputs:receive({name = "mousepressed", 10, 20, 1}, default_modifiers)
	local mouse_up = inputs:receive({name = "mousereleased", 10, 20, 1}, default_modifiers)
	local scroll = inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:eq(mouse_down, nil)
	t:eq(mouse_up, nil)
	t:eq(scroll, nil)
	t:eq(event_count, 0)
	t:eq(inputs.last_mouse_down_event, nil)
end

---@param t testing.T
function test.processView_sets_mouse_target_and_mouse_hits(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view = create_view(100, 100)
	view.handles_mouse_input = true

	inputs:processView(view)

	t:eq(inputs.mouse_target, view)
	t:eq(#inputs.mouse_hits, 1)
	t:eq(inputs.mouse_hits[1], view)
end

---@param t testing.T
function test.processView_does_not_set_mouse_target_if_not_handling(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view = create_view(100, 100)

	inputs:processView(view)

	t:eq(inputs.mouse_target, nil)
	t:eq(#inputs.mouse_hits, 0)
end

---@param t testing.T
function test.processView_keeps_first_mouse_target_but_collects_mouse_hits(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view1 = create_view(100, 100)
	view1.handles_mouse_input = true

	local view2 = create_view(100, 100)
	view2.handles_mouse_input = true

	inputs:processView(view1)
	inputs:processView(view2)

	t:eq(inputs.mouse_target, view1)
	t:eq(#inputs.mouse_hits, 2)
	t:eq(inputs.mouse_hits[1], view1)
	t:eq(inputs.mouse_hits[2], view2)
end

---@param t testing.T
function test.processView_detects_mouse_outside(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(150, 150)

	local view = create_view(100, 100)
	view.handles_mouse_input = true

	inputs:processView(view)

	t:eq(inputs.mouse_target, nil)
	t:eq(#inputs.mouse_hits, 0)
	t:eq(view.mouse_over, false)
end

---@param t testing.T
function test.processView_dispatches_hover_event(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view = create_view(100, 100)
	view.handles_mouse_input = true

	local hover_called = false
	view.onHover = function(self, e)
		hover_called = true
		t:eq(e.target, view)
	end

	inputs:processView(view)

	t:assert(hover_called, "onHover should be called")
	t:eq(view.mouse_over, true)
end

---@param t testing.T
function test.processView_dispatches_hover_lost_event(t)
	local inputs = Inputs()
	local view = create_view(100, 100)
	view.handles_mouse_input = true
	view.mouse_over = true

	local hover_lost_called = false
	view.onHoverLost = function(self, e)
		hover_lost_called = true
		t:eq(e.target, view)
	end

	inputs:resetTraversalContext(150, 150)
	inputs:processView(view)

	t:assert(hover_lost_called, "onHoverLost should be called")
	t:eq(view.mouse_over, false)
end

---@param t testing.T
function test.processView_no_hover_event_when_staying_hovered(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view = create_view(100, 100)
	view.handles_mouse_input = true
	view.mouse_over = true

	local hover_called = false
	view.onHover = function()
		hover_called = true
	end

	inputs:processView(view)

	t:assert(not hover_called, "onHover should not be called when already hovered")
	t:eq(view.mouse_over, true)
end

---@param t testing.T
function test.processView_no_hover_lost_event_when_staying_outside(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(150, 150)

	local view = create_view(100, 100)
	view.handles_mouse_input = true
	view.mouse_over = false

	local hover_lost_called = false
	view.onHoverLost = function()
		hover_lost_called = true
	end

	inputs:processView(view)

	t:assert(not hover_lost_called, "onHoverLost should not be called when already not hovered")
	t:eq(view.mouse_over, false)
end

---@param t testing.T
function test.processView_adds_focus_requester(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view = create_view(100, 100)
	view.handles_keyboard_input = true

	inputs:processView(view)

	t:eq(#inputs.focus_requesters, 1)
	t:eq(inputs.focus_requesters[1], view)
end

---@param t testing.T
function test.processView_adds_multiple_focus_requesters(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view1 = create_view(100, 100)
	view1.handles_keyboard_input = true

	local view2 = create_view(100, 100)
	view2.handles_keyboard_input = true

	local view3 = create_view(100, 100)
	view3.handles_keyboard_input = true

	inputs:processView(view1)
	inputs:processView(view2)
	inputs:processView(view3)

	t:eq(#inputs.focus_requesters, 3)
	t:eq(inputs.focus_requesters[1], view1)
	t:eq(inputs.focus_requesters[2], view2)
	t:eq(inputs.focus_requesters[3], view3)
end

---@param t testing.T
function test.processView_view_with_both_input_types(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view = create_view(100, 100)
	view.handles_mouse_input = true
	view.handles_keyboard_input = true

	inputs:processView(view)

	t:eq(inputs.mouse_target, view)
	t:eq(#inputs.mouse_hits, 1)
	t:eq(#inputs.focus_requesters, 1)
	t:eq(inputs.focus_requesters[1], view)
end

---@param t testing.T
function test.processView_clears_mouse_over_when_mouse_target_already_set(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local view1 = create_view(100, 100)
	view1.handles_mouse_input = true

	local view2 = create_view(100, 100)
	view2.handles_mouse_input = true
	view2.mouse_over = true

	local hover_lost_called = false
	view2.onHoverLost = function()
		hover_lost_called = true
	end

	inputs:processView(view1)
	inputs:processView(view2)

	t:assert(hover_lost_called, "onHoverLost should be called when view loses mouse_target to another")
	t:eq(view2.mouse_over, false)
	t:eq(#inputs.mouse_hits, 2)
end

---@param t testing.T
function test.processView_traversal_order(t)
	local inputs = Inputs()
	inputs:resetTraversalContext(50, 50)

	local container = create_view(100, 100)
	container.handles_mouse_input = true

	local button = create_view(50, 50)
	button.handles_mouse_input = true

	local textbox = create_view(100, 100)
	textbox.handles_keyboard_input = true

	local other = create_view(100, 100)
	other.handles_mouse_input = true
	other.x = 200
	other:relayout()

	inputs:processView(container)
	inputs:processView(button)
	inputs:processView(textbox)
	inputs:processView(other)

	t:eq(inputs.mouse_target, container)
	t:eq(#inputs.mouse_hits, 2)
	t:eq(inputs.mouse_hits[1], container)
	t:eq(inputs.mouse_hits[2], button)
	t:eq(#inputs.focus_requesters, 1)
	t:eq(inputs.focus_requesters[1], textbox)
end

---@param t testing.T
function test.resetTraversalContext_resets_context(t)
	local inputs = Inputs()

	inputs.mouse_x = 100
	inputs.mouse_y = 100
	inputs.mouse_target = create_view(10, 10)
	table.insert(inputs.mouse_hits, create_view(10, 10))
	table.insert(inputs.focus_requesters, create_view(10, 10))

	inputs:resetTraversalContext(50, 75)

	t:eq(inputs.mouse_x, 50)
	t:eq(inputs.mouse_y, 75)
	t:eq(inputs.mouse_target, nil)
	t:eq(#inputs.mouse_hits, 0)
	t:eq(#inputs.focus_requesters, 0)
end

---@param t testing.T
function test.beginFrame_aliases_resetTraversalContext(t)
	local inputs = Inputs()
	inputs.mouse_target = create_view(10, 10)
	table.insert(inputs.mouse_hits, create_view(10, 10))
	table.insert(inputs.focus_requesters, create_view(10, 10))

	inputs:beginFrame(25, 30)

	t:eq(inputs.mouse_x, 25)
	t:eq(inputs.mouse_y, 30)
	t:eq(inputs.mouse_target, nil)
	t:eq(#inputs.mouse_hits, 0)
	t:eq(#inputs.focus_requesters, 0)
end

---@param t testing.T
function test.mouse_events_bubble_through_mouse_hits_until_handled(t)
	local inputs = Inputs()
	local top = create_view(100, 100)
	local bottom = create_view(100, 100)

	local events = {}
	top.onScroll = function()
		table.insert(events, "top")
	end
	bottom.onScroll = function()
		table.insert(events, "bottom")
		return true
	end

	table.insert(inputs.mouse_hits, top)
	table.insert(inputs.mouse_hits, bottom)
	inputs.mouse_target = top
	inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:tdeq(events, {"top", "bottom"})
end

---@param t testing.T
function test.mouse_bubbling_preserves_target_and_sets_current_target(t)
	local inputs = Inputs()
	local top = create_view(100, 100)
	local bottom = create_view(100, 100)

	local seen = {}
	top.onScroll = function(self, e)
		table.insert(seen, {target = e.target, current_target = e.current_target})
	end
	bottom.onScroll = function(self, e)
		table.insert(seen, {target = e.target, current_target = e.current_target})
	end

	table.insert(inputs.mouse_hits, top)
	table.insert(inputs.mouse_hits, bottom)
	inputs.mouse_target = top
	inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:eq(#seen, 2)
	t:eq(seen[1].target, top)
	t:eq(seen[1].current_target, top)
	t:eq(seen[2].target, top)
	t:eq(seen[2].current_target, bottom)
end

return test
