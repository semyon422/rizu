local FlowContainer = require("gui.layout.FlowContainer")
local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local ScrollView = require("gui.ScrollView")
local View = require("gui.View")

---@class gui.test.HorizontalDragControl : gui.View
---@operator call: gui.test.HorizontalDragControl
---@field value number
local HorizontalDragControl = View + {}

---@param value number
---@param width number
function HorizontalDragControl:new(value, width)
	View.new(self)
	self.value = value
	self:setSize(width, 24)
	self.handles_mouse_input = true
	self.drag_axis = "horizontal"
end

---@param e gui.DragStartEvent|gui.DragEvent
---@return boolean handled
function HorizontalDragControl:updateDrag(e)
	local local_x = self.world_transform:inverseTransformPoint(e.x, e.y)
	self.value = math.max(0, math.min(1, local_x / self.width))
	return true
end

HorizontalDragControl.onDragStart = HorizontalDragControl.updateDrag
HorizontalDragControl.onDrag = HorizontalDragControl.updateDrag

local test = {}

local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@return gui.Screen
---@return gui.ScrollView
---@return gui.View[]
local function createScrollView()
	local rows = {}
	local content = FlowContainer({direction = "column"})
	for i = 1, 3 do
		local row = View()
		row:setSize(100, 50)
		row.handles_mouse_input = true
		content:add(row)
		rows[i] = row
	end
	content:fitContent()

	local scroll_view = ScrollView(content)
	scroll_view:anchorFixed(0, 0, 100, 50)
	local screen = Screen()
	screen.root:add(scroll_view)
	screen:resize(200, 200)
	return screen, scroll_view, rows
end

---@param t testing.T
function test.culls_content_outside_viewport(t)
	local _, _, rows = createScrollView()

	t:eq(rows[1].cull_mask, 0)
	t:assert(bit.band(rows[2].cull_mask, View.CULL_VIEWPORT) ~= 0)
	t:assert(bit.band(rows[3].cull_mask, View.CULL_VIEWPORT) ~= 0)
end

---@param t testing.T
function test.immediate_scroll_refreshes_culling(t)
	local _, scroll_view, rows = createScrollView()

	scroll_view:scrollTo(50, true)

	t:assert(bit.band(rows[1].cull_mask, View.CULL_VIEWPORT) ~= 0)
	t:eq(rows[2].cull_mask, 0)
	t:assert(bit.band(rows[3].cull_mask, View.CULL_VIEWPORT) ~= 0)
end

---@param t testing.T
function test.culled_views_do_not_receive_input(t)
	local screen, _, rows = createScrollView()
	local inputs = Inputs()
	inputs:beginFrame(25, 75)

	screen:acceptInputs(inputs)

	t:eq(#inputs.mouse_hits, 0)
	t:assert(bit.band(rows[2].cull_mask, View.CULL_VIEWPORT) ~= 0)
end

---@param t testing.T
function test.viewport_culling_preserves_other_cull_causes(t)
	local _, scroll_view, rows = createScrollView()
	local other_cause = 4
	rows[1].cull_mask = bit.bor(rows[1].cull_mask, other_cause)

	scroll_view:scrollTo(50, true)
	scroll_view:scrollTo(0, true)

	t:assert(bit.band(rows[1].cull_mask, other_cause) ~= 0)
	t:eq(bit.band(rows[1].cull_mask, View.CULL_VIEWPORT), 0)
end

---@param t testing.T
function test.exposes_scrollbar_model(t)
	local _, scroll_view = createScrollView()
	scroll_view:scrollTo(40, true)

	t:eq(scroll_view:getScrollPosition(), 40)
	t:eq(scroll_view:getScrollContentSize(), 150)
	t:eq(scroll_view:getScrollViewportSize(), 50)
end

---@param t testing.T
function test.relayout_reclamps_unchanged_extent(t)
	local screen, scroll_view = createScrollView()
	scroll_view:scrollTo(100, true)
	scroll_view.scroll_target = 999
	scroll_view.scroll_current = 999
	screen:invalidateLayout()
	screen:flush()

	t:eq(scroll_view.scroll_target, 100)
	t:eq(scroll_view.scroll_current, 100)
	t:eq(scroll_view.content.offset_y, -100)
end

---@param t testing.T
function test.drag_scrolls_content_and_release_ends_capture(t)
	local screen, scroll_view = createScrollView()
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1}, default_modifiers)
	inputs.mouse_y = 30
	inputs:receive({name = "mousemoved", 25, 30, 0, -10}, default_modifiers)

	t:eq(scroll_view.scroll_target, 10)
	t:eq(scroll_view.scroll_current, 10)
	t:eq(scroll_view.content.offset_y, -10)

	inputs.mouse_y = -100
	inputs:receive({name = "mousemoved", 25, -100, 0, -130}, default_modifiers)
	t:eq(scroll_view.scroll_current, scroll_view:getMaxScroll())

	inputs:receive({name = "mousereleased", 25, -100, 1}, default_modifiers)
	t:eq(inputs.last_mouse_down_event, nil)
	inputs.mouse_y = 40
	inputs:receive({name = "mousemoved", 25, 40, 0, 140}, default_modifiers)
	t:eq(scroll_view.scroll_current, scroll_view:getMaxScroll())
end

---@param t testing.T
function test.drag_rubber_bands_past_boundary_and_recovers(t)
	local screen, scroll_view = createScrollView()
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_y = 80
	inputs:receive({name = "mousemoved", 25, 80, 0, 40, time = 1.1}, default_modifiers)

	t:eq(scroll_view.scroll_current, 0)
	t:assert(scroll_view.overscroll < 0)
	t:assert(scroll_view.overscroll > -scroll_view.height * scroll_view.OVERSCROLL_LIMIT_RATIO)
	t:assert(scroll_view.content.offset_y > 0)
	t:eq(scroll_view:getScrollPosition(), 0)

	inputs:receive({name = "mousereleased", 25, 80, 1, time = 1.1}, default_modifiers)
	local released_overscroll = math.abs(scroll_view.overscroll)
	scroll_view:update(0.1)
	t:assert(math.abs(scroll_view.overscroll) < released_overscroll)
	for _ = 1, 20 do
		scroll_view:update(0.1)
	end
	t:eq(scroll_view.overscroll, 0)
	t:eq(scroll_view.content.offset_y, 0)
end

---@param t testing.T
function test.interactive_child_keeps_horizontal_drag_capture(t)
	local content = View()
	content:setSize(100, 150)
	local slider = HorizontalDragControl(0, 100)
	content:add(slider)
	local scroll_view = ScrollView(content)
	scroll_view:anchorFixed(0, 0, 100, 50)
	local screen = Screen()
	screen.root:add(scroll_view)
	screen:resize(200, 200)
	local inputs = Inputs()
	inputs:beginFrame(10, 12)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 10, 12, 1}, default_modifiers)
	inputs.mouse_x = 90
	inputs:receive({name = "mousemoved", 90, 12, 80, 0}, default_modifiers)

	t:eq(slider.value, 0.9)
	t:eq(scroll_view.scroll_current, 0)
end

---@param t testing.T
function test.scroll_view_captures_vertical_drag_from_slider(t)
	local content = View()
	content:setSize(100, 150)
	local slider = HorizontalDragControl(0.5, 100)
	content:add(slider)
	local scroll_view = ScrollView(content)
	scroll_view:anchorFixed(0, 0, 100, 50)
	local screen = Screen()
	screen.root:add(scroll_view)
	screen:resize(200, 200)
	local inputs = Inputs()
	inputs:beginFrame(50, 12)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 50, 12, 1}, default_modifiers)
	inputs.mouse_y = 2
	inputs:receive({name = "mousemoved", 50, 2, 0, -10}, default_modifiers)

	t:eq(slider.value, 0.5)
	t:eq(scroll_view.scroll_current, 10)
end

---@param t testing.T
function test.scroll_view_captures_vertical_drag_from_interactive_child(t)
	local screen, scroll_view, rows = createScrollView()
	local mouse_up_count = 0
	rows[1].onMouseDown = function()
		return true
	end
	rows[1].onMouseUp = function()
		mouse_up_count = mouse_up_count + 1
		return true
	end
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 25, 20, 0, -20, time = 1.1}, default_modifiers)

	t:eq(mouse_up_count, 1)
	t:eq(scroll_view.scroll_current, 20)
	t:assert(scroll_view.drag_active)

	inputs:receive({name = "mousereleased", 25, 20, 1, time = 1.1}, default_modifiers)
	local release_position = scroll_view.scroll_current
	scroll_view:update(0.1)
	t:assert(scroll_view.scroll_current > release_position)
end

---@param t testing.T
function test.axis_neutral_child_does_not_block_scroll_after_horizontal_start(t)
	local screen, scroll_view, rows = createScrollView()
	rows[1].onMouseDown = function()
		return true
	end
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_x = 35
	inputs:receive({name = "mousemoved", 35, 40, 10, 0, time = 1.05}, default_modifiers)
	t:assert(scroll_view.drag_active)

	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 35, 20, 0, -20, time = 1.1}, default_modifiers)
	t:eq(scroll_view.scroll_current, 20)
end

---@param t testing.T
function test.drag_release_flings(t)
	local screen, scroll_view = createScrollView()
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 25, 20, 0, -20, time = 1.1}, default_modifiers)
	t:assert(scroll_view.drag_active)
	inputs:receive({name = "mousereleased", 25, 20, 1, time = 1.1}, default_modifiers)
	local release_position = scroll_view.scroll_current
	scroll_view:update(0.1)

	t:assert(scroll_view.scroll_current > release_position)
	t:assert(scroll_view.scroll_velocity > 0)
end

---@param t testing.T
function test.drag_release_after_stopping_does_not_fling(t)
	local screen, scroll_view = createScrollView()
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 25, 20, 0, -20, time = 1.01}, default_modifiers)
	inputs:receive({name = "mousereleased", 25, 20, 1, time = 1.2}, default_modifiers)
	local release_position = scroll_view.scroll_current
	scroll_view:update(0.1)

	t:eq(scroll_view.scroll_current, release_position)
	t:eq(scroll_view.scroll_velocity, 0)
end

---@param t testing.T
function test.drag_distance_uses_scroll_view_local_coordinates(t)
	local screen, scroll_view = createScrollView()
	scroll_view:setScale(1, 2)
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 25, 20, 0, -20}, default_modifiers)

	t:eq(scroll_view.scroll_current, 10)
end

return test
