local View = require("gui.View")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")

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
	table.clear(inputs.mouse_hits)
	inputs.mouse_target = nil
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
function test.drag_is_captured_by_mouse_down_handler(t)
	local child = create_view(100, 100)
	local scroller = create_view(100, 100)
	local inputs = Inputs()
	local events = {}
	child.onMouseDown = function() end
	scroller.onMouseDown = function() table.insert(events, "down") return true end
	scroller.onDragStart = function() table.insert(events, "start") end
	scroller.onDragEnd = function() table.insert(events, "end") end
	table.insert(inputs.mouse_hits, child)
	table.insert(inputs.mouse_hits, scroller)
	inputs.mouse_target = child
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs.mouse_x = 20
	inputs:receive({name = "mousemoved", 20, 10, 10, 0}, default_modifiers)
	inputs:receive({name = "mousereleased", 20, 10, 1}, default_modifiers)

	t:tdeq(events, {"down", "start", "end"})
end

---@param t testing.T
function test.mouse_move_below_drag_threshold_still_clicks(t)
	local btn = create_view(100, 100)
	local inputs = Inputs()
	local events = {}
	btn.onDragStart = function() table.insert(events, "drag") end
	btn.onMouseClick = function() table.insert(events, "click") end
	table.insert(inputs.mouse_hits, btn)
	inputs.mouse_target = btn
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs.mouse_x = 12
	inputs.mouse_y = 12
	inputs:receive({name = "mousemoved", 12, 12, 2, 2}, default_modifiers)
	inputs:receive({name = "mousereleased", 12, 12, 1}, default_modifiers)

	t:tdeq(events, {"click"})
end

---@param t testing.T
function test.drag_suppresses_click(t)
	local btn = create_view(100, 100)
	local inputs = Inputs()
	local events = {}
	btn.onDragStart = function() table.insert(events, "drag") end
	btn.onMouseClick = function() table.insert(events, "click") end
	table.insert(inputs.mouse_hits, btn)
	inputs.mouse_target = btn
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs.mouse_x = 20
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 20, 20, 10, 10}, default_modifiers)
	inputs:receive({name = "mousereleased", 20, 20, 1}, default_modifiers)

	t:tdeq(events, {"drag"})
end

---@param t testing.T
function test.drag_releases_pressed_view_when_drag_starts(t)
	local icon = create_view(100, 100)
	local scroller = create_view(100, 100)
	local inputs = Inputs()
	local events = {}
	icon.onMouseDown = function() table.insert(events, "down") end
	icon.onMouseUp = function() table.insert(events, "up") end
	scroller.drag_axis = "vertical"
	scroller.onDragStart = function() table.insert(events, "drag") end
	icon.parent = scroller
	table.insert(inputs.mouse_hits, icon)
	table.insert(inputs.mouse_hits, scroller)
	inputs.mouse_target = icon
	inputs.mouse_x = 10
	inputs.mouse_y = 10

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 10, 20, 0, 10}, default_modifiers)
	t:tdeq(events, {"down", "up", "drag"})

	inputs:receive({name = "mousereleased", 10, 20, 1}, default_modifiers)
	t:tdeq(events, {"down", "up", "drag"})
end

---@param t testing.T
function test.drag_survives_pressed_child_removal_during_synthetic_mouse_up(t)
	local screen = Screen()
	screen:resize(100, 100)
	local scroller = screen.root:add(create_view(100, 100))
	local child = scroller:add(create_view(100, 100))
	scroller.drag_axis = "vertical"
	scroller.handles_mouse_input = true
	child.handles_mouse_input = true
	local events = {}
	child.onMouseUp = function()
		events[#events + 1] = "up"
		scroller:remove(child)
	end
	scroller.onDragStart = function() events[#events + 1] = "start" end
	scroller.onDragEnd = function() events[#events + 1] = "end" end
	screen:relayout()
	local inputs = Inputs()
	screen.inputs = inputs
	inputs:resetTraversalContext(10, 10)
	inputs.mouse_hits = {child, scroller}
	inputs.mouse_target = child

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 10, 20, 0, 10}, default_modifiers)
	inputs:receive({name = "mousereleased", 10, 20, 1}, default_modifiers)

	t:tdeq(events, {"up", "start", "end"})
end

---@param t testing.T
function test.drag_is_cancelled_when_capture_is_removed_during_synthetic_mouse_up(t)
	local screen = Screen()
	screen:resize(100, 100)
	local scroller = screen.root:add(create_view(100, 100))
	local child = scroller:add(create_view(100, 100))
	scroller.drag_axis = "vertical"
	scroller.handles_mouse_input = true
	child.handles_mouse_input = true
	local events = {}
	child.onMouseUp = function()
		events[#events + 1] = "up"
		screen.root:remove(scroller)
	end
	scroller.onDragStart = function() events[#events + 1] = "start" end
	screen:relayout()
	local inputs = Inputs()
	screen.inputs = inputs
	inputs:resetTraversalContext(10, 10)
	inputs.mouse_hits = {child, scroller}
	inputs.mouse_target = child

	inputs:receive({name = "mousepressed", 10, 10, 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 10, 20, 0, 10}, default_modifiers)

	t:tdeq(events, {"up"})
	t:eq(inputs.pointer_gesture, nil)
end

---@param t testing.T
function test.mouse_hit_dispatch_survives_current_target_removal(t)
	local screen = Screen()
	screen:resize(100, 100)
	local bottom = screen.root:add(create_view(100, 100))
	local top = screen.root:add(create_view(100, 100))
	bottom.handles_mouse_input = true
	top.handles_mouse_input = true
	local events = {}
	top.onScroll = function()
		events[#events + 1] = "top"
		screen.root:remove(top)
	end
	bottom.onScroll = function() events[#events + 1] = "bottom" end
	screen:relayout()
	local inputs = Inputs()
	screen.inputs = inputs
	inputs:resetTraversalContext(10, 10)
	inputs.mouse_hits = {top, bottom}
	inputs.mouse_target = top

	inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:tdeq(events, {"top", "bottom"})
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
function test.stop_propagation_stops_mouse_hit_dispatch(t)
	local inputs = Inputs()
	local top = create_view(100, 100)
	local bottom = create_view(100, 100)
	local events = {}
	top.onScroll = function(_, e)
		table.insert(events, "top")
		e:stopPropagation()
	end
	bottom.onScroll = function() table.insert(events, "bottom") end
	table.insert(inputs.mouse_hits, top)
	table.insert(inputs.mouse_hits, bottom)
	inputs.mouse_target = top

	inputs:receive({name = "wheelmoved", 0, 1}, default_modifiers)

	t:tdeq(events, {"top"})
end

---@param t testing.T
function test.focus_scope_filters_requesters_and_restores_focus(t)
	local screen = Screen()
	screen:resize(100, 100)
	local outside = screen.root:add(create_view(10, 10))
	local scope = screen.root:add(create_view(10, 10))
	local inside = scope:add(create_view(10, 10))
	outside.handles_keyboard_input = true
	inside.handles_keyboard_input = true
	screen:relayout()
	local inputs = Inputs()
	inputs:setKeyboardFocus(outside, default_modifiers)

	inputs:pushFocusScope(scope)
	inputs:processView(outside)
	inputs:processView(inside)

	t:eq(inputs.keyboard_focus, nil)
	t:tdeq(inputs.focus_requesters, {inside})
	inputs:popFocusScope(scope)
	t:eq(inputs.keyboard_focus, outside)
end

---@param t testing.T
function test.focus_scope_allows_ancestor_keyboard_fallback(t)
	local screen = Screen()
	screen:resize(100, 100)
	local host = screen.root:add(create_view(100, 100))
	local scope = host:add(create_view(50, 50))
	local focused = scope:add(create_view(10, 10))
	host.handles_keyboard_input = true
	host.keyboard_input_fallback = true
	focused.handles_keyboard_input = true
	local events = {}
	focused.onKeyDown = function() events[#events + 1] = "focused" end
	host.onKeyDown = function() events[#events + 1] = "host" return true end
	screen:relayout()
	local inputs = Inputs()
	inputs:pushFocusScope(scope)
	inputs:setKeyboardFocus(focused, default_modifiers)
	inputs:processView(host)
	inputs:processView(focused)

	inputs:receive({name = "keypressed", "escape"}, default_modifiers)

	t:tdeq(events, {"focused", "host"})
end

---@param t testing.T
function test.keyboard_fallback_runs_after_unhandled_focused_view(t)
	local inputs = Inputs()
	local focused = create_view(10, 10)
	local fallback = create_view(10, 10)
	focused.handles_keyboard_input = true
	fallback.handles_keyboard_input = true
	fallback.keyboard_input_fallback = true
	local events = {}
	focused.onKeyDown = function() events[#events + 1] = "focused" end
	fallback.onKeyDown = function() events[#events + 1] = "fallback" return true end
	inputs:setKeyboardFocus(focused, default_modifiers)
	inputs:processView(fallback)
	inputs:processView(focused)

	inputs:receive({name = "keypressed", "escape"}, default_modifiers)

	t:tdeq(events, {"focused", "fallback"})
end

---@param t testing.T
function test.handled_focused_view_blocks_keyboard_fallback(t)
	local inputs = Inputs()
	local focused = create_view(10, 10)
	local fallback = create_view(10, 10)
	fallback.keyboard_input_fallback = true
	local events = {}
	focused.onKeyDown = function() events[#events + 1] = "focused" return true end
	fallback.onKeyDown = function() events[#events + 1] = "fallback" end
	inputs:setKeyboardFocus(focused, default_modifiers)
	inputs:processView(fallback)

	inputs:receive({name = "keypressed", "escape"}, default_modifiers)

	t:tdeq(events, {"focused"})
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
