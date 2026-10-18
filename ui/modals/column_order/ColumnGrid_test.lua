local ColumnGrid = require("ui.modals.column_order.ColumnGrid")

local test = {}

---@param on_change fun(order: integer[])?
---@return ui.modals.column_order.ColumnGrid
local function newGrid(on_change)
	return setmetatable({
		order = {1, 2, 3, 4},
		cursor = 1,
		on_change = on_change or function() end,
	}, {__index = ColumnGrid})
end

---@param t testing.T
function test.pick_then_swap(t)
	local changed
	local grid = newGrid(function(order) changed = {unpack(order)} end)
	grid:press(1)
	t:eq(grid.picked, 1)
	grid:press(3)
	t:eq(grid.picked, nil)
	t:tdeq(grid.order, {3, 2, 1, 4})
	t:tdeq(changed, {3, 2, 1, 4})
	grid:press(2)
	grid:press(2)
	t:eq(grid.picked, nil)
	t:tdeq(grid.order, {3, 2, 1, 4})
end

---@param t testing.T
function test.keyboard_carries_the_picked_column(t)
	local grid = newGrid()
	grid:activate()
	t:eq(grid:onFormKeyDown({key = "right"}), true)
	grid:onFormKeyDown({key = "right"})
	t:tdeq(grid.order, {2, 3, 1, 4})
	t:eq(grid.picked, 3)
	grid:activate()
	t:eq(grid.picked, nil)
	for _ = 1, 5 do
		grid:onFormKeyDown({key = "right"})
	end
	t:eq(grid.cursor, 4)
	t:eq(grid:onFormKeyDown({key = "up"}), false)
end

---@param t testing.T
function test.rows_have_equal_length(t)
	local grid = newGrid()
	grid.grid_width = 600
	grid.setHeight = function() end
	grid:setOrder({1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14})
	t:eq(grid.per_row, 7)
	grid:setOrder({1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
	t:eq(grid.per_row, 10)
end

return test
