local Inputs = require("gui.input.Inputs")
local Screen = require("gui.Screen")
local VirtualizedList = require("gui.VirtualizedList")

---@class gui.test.VirtualizedList : gui.VirtualizedList
local TestList = VirtualizedList + {}

function TestList:new()
	VirtualizedList.new(self)
	self.item_height = 20
	self.gap = 5
	self.item_count = 10
	self:anchorFixed(0, 0, 100, 50)
end

---@return integer count
function TestList:getItemCount()
	return self.item_count
end

local test = {}
local default_modifiers = {control = false, shift = false, alt = false, super = false}

---@return gui.Screen
---@return gui.test.VirtualizedList
local function createList()
	local list = TestList()
	local screen = Screen()
	screen.root:add(list)
	screen:resize(200, 200)
	return screen, list
end

---@param t testing.T
function test.exposes_scroll_model(t)
	local _, list = createList()
	list:scrollTo(40, true)

	t:eq(list:getScrollPosition(), 40)
	t:eq(list:getScrollContentSize(), 245)
	t:eq(list:getScrollViewportSize(), 50)
	t:eq(list:getMaxScroll(), 195)
end

---@param t testing.T
function test.reports_visible_rows(t)
	local _, list = createList()
	list:scrollTo(30, true)

	local first_row, last_row = list:getVisibleRowRange()
	t:eq(first_row, 2)
	t:eq(last_row, 4)
end

---@param t testing.T
function test.wheel_scrolls_one_row(t)
	local _, list = createList()
	list:onScroll({direction_y = -1})
	list:update(1)

	t:assert(math.abs(list:getScrollPosition() - 25) < list.SCROLL_EPSILON)
end

---@param t testing.T
function test.drag_overscrolls_and_recovers(t)
	local screen, list = createList()
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_y = 80
	inputs:receive({name = "mousemoved", 25, 80, 0, 40, time = 1.1}, default_modifiers)

	t:eq(list:getScrollPosition(), 0)
	t:assert(list:getVisualScrollPosition() < 0)
	t:assert(list.overscroll > -list.height * list.OVERSCROLL_LIMIT_RATIO)

	inputs:receive({name = "mousereleased", 25, 80, 1, time = 1.1}, default_modifiers)
	local released_overscroll = math.abs(list.overscroll)
	list:update(0.1)
	t:assert(math.abs(list.overscroll) < released_overscroll)
	for _ = 1, 20 do
		list:update(0.1)
	end
	t:eq(list.overscroll, 0)
end

---@param t testing.T
function test.direct_control_stops_motion(t)
	local _, list = createList()
	list.scroll_velocity = 100
	list.overscroll = -10

	list:stopScrollMotion()
	list:scrollTo(80, true)
	list:update(0.1)

	t:eq(list.scroll_velocity, 0)
	t:eq(list.overscroll, 0)
	t:eq(list:getScrollPosition(), 80)
end

---@param t testing.T
function test.drag_release_flings(t)
	local screen, list = createList()
	local inputs = Inputs()
	inputs:beginFrame(25, 40)
	screen:acceptInputs(inputs)
	list:scrollTo(50, true)

	inputs:receive({name = "mousepressed", 25, 40, 1, time = 1}, default_modifiers)
	inputs.mouse_y = 20
	inputs:receive({name = "mousemoved", 25, 20, 0, -20, time = 1.1}, default_modifiers)
	inputs:receive({name = "mousereleased", 25, 20, 1, time = 1.1}, default_modifiers)
	local release_position = list:getScrollPosition()
	list:update(0.1)

	t:assert(list:getScrollPosition() > release_position)
end

return test
