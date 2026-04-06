local Box = require("ui.Box")
local List = require("yi.components.List")
local View = require("ui.View")

local test = {}

local Item = View + {}

function Item:new(height)
	View.new(self)
	self.height = height or 20
	self.width = 100
	self.is_focusable = true
	self.handles_keyboard_input = true
	self.layout_update_count = 0
end

function Item:onLayoutUpdate()
	self.layout_update_count = self.layout_update_count + 1
end

---@param t testing.T
function test.wheel_updates_target_scroll_position(t)
	local list = List({
		wheel_step = 50,
		items = {Item(40), Item(40), Item(40), Item(40)},
	})

	list:setSize(100, 100)
	list.box = Box()
	list.box:update(0, 0, 100, 100, 1)
	list:applyLayout()

	t:eq(list.target_scroll_position, 0)
	t:eq(list:onScroll({direction_y = -1}), true)
	t:eq(list.target_scroll_position, 50)
	t:eq(list.scroll_position, 0)
end

---@param t testing.T
function test.update_animates_scroll_position(t)
	local list = List({
		scroll_animation_speed = 10,
		items = {Item(40), Item(40), Item(40), Item(40)},
	})

	list:setSize(100, 100)
	list.box = Box()
	list.box:update(0, 0, 100, 100, 1)
	list:applyLayout()
	list:setTargetScrollPosition(60)

	list:update(0.05)
	t:eq(list.scroll_position > 0, true)
	t:eq(list.scroll_position < 60, true)

	list:update(1)
	t:eq(list.scroll_position, 60)
end

---@param t testing.T
function test.padding_offsets_items_and_content_height(t)
	local list = List({
		padding = 10,
		padding_left = 12,
		padding_bottom = 14,
		gap = 5,
		items = {Item(40), Item(50)},
	})

	list:setSize(100, 120)
	list.box = Box()
	list.box:update(0, 0, 100, 120, 1)
	list:applyLayout()

	t:eq(list.views[1].x, 12)
	t:eq(list.views[1].y, 10)
	t:eq(list.views[2].y, 55)
	t:eq(list.content_height, 119)
	t:eq(list.content_box.x, 12)
	t:eq(list.content_box.y, 10)
	t:eq(list.content_box.width, 78)
	t:eq(list.content_box.height, 96)
end

---@param t testing.T
function test.focus_visibility_accounts_for_padding(t)
	local list = List({
		padding_top = 10,
		padding_bottom = 20,
		items = {Item(40), Item(40), Item(40), Item(40)},
	})

	list:setSize(100, 100)
	list.box = Box()
	list.box:update(0, 0, 100, 100, 1)
	list:applyLayout()
	list:focusChild(4)

	t:eq(list.target_scroll_position, 90)
end

---@param t testing.T
function test.table_padding_is_supported(t)
	local list = List({
		padding = {12, 8, 20, 10},
		gap = 5,
		items = {Item(40), Item(50)},
	})

	list:setSize(120, 130)
	list.box = Box()
	list.box:update(0, 0, 120, 130, 1)
	list:applyLayout()

	t:eq(list.padding_left, 12)
	t:eq(list.padding_top, 8)
	t:eq(list.padding_right, 20)
	t:eq(list.padding_bottom, 10)
	t:eq(list.views[1].x, 12)
	t:eq(list.views[1].y, 8)
	t:eq(list.content_box.width, 88)
	t:eq(list.content_box.height, 112)
end

---@param t testing.T
function test.vertical_padding_does_not_hide_partially_visible_items_early(t)
	local list = List({
		padding_top = 20,
		padding_bottom = 20,
		items = {Item(40), Item(40), Item(40)},
	})

	list:setSize(100, 100)
	list.box = Box()
	list.box:update(0, 0, 100, 100, 1)
	list:applyLayout()
	list:setScrollPosition(30)
	list:applyLayout()

	t:eq(list.first_visible, 1)
	t:eq(list.last_visible, 3)
end

---@param t testing.T
function test.resolution_change_keeps_logical_spacing_values(t)
	local list = List({
		gap = 10,
		padding = {12, 8, 20, 10},
		wheel_step = 24,
	})

	list.ui_scale = 1.5
	list.box = Box()
	list.box:update(0, 0, 100, 100, 1.5)
	list:applyLayout()

	t:eq(list.gap, 10)
	t:eq(list.padding_left, 12)
	t:eq(list.padding_top, 8)
	t:eq(list.padding_right, 20)
	t:eq(list.padding_bottom, 10)
	t:eq(list.wheel_step, 24)
end

---@param t testing.T
function test.new_children_adopt_current_ui_scale_immediately(t)
	local list = List({
		padding = 10,
	})

	list.ui_scale = 1.5
	list:setSize(120, 100)
	list.box = Box()
	list.box:update(0, 0, 120, 100, 1.5)
	list:applyLayout()

	local item = Item(40)
	item:setWidthPercent(1)
	list:setItems({item})

	t:eq(item.ui_scale, 1.5)
	t:eq(item.layout_update_count > 0, true)
	t:eq(item.width, 100)
end

---@param t testing.T
function test.animated_scroll_does_not_relayout_children(t)
	local list = List({
		scroll_animation_speed = 20,
	})
	list.box = Box()
	list.box:update(0, 0, 100, 60)
	list:setSize(100, 60)

	local first = list:addItem(Item(20))
	local second = list:addItem(Item(20))
	local third = list:addItem(Item(20))
	local fourth = list:addItem(Item(20))

	list:applyLayout()
	local first_updates = first.layout_update_count
	local second_updates = second.layout_update_count
	local third_updates = third.layout_update_count
	local fourth_updates = fourth.layout_update_count

	list:scrollBy(30)
	list:update(1 / 60)
	list:update(1 / 60)

	t:eq(first.layout_update_count, first_updates)
	t:eq(second.layout_update_count, second_updates)
	t:eq(third.layout_update_count, third_updates)
	t:eq(fourth.layout_update_count, fourth_updates)
end

return test
