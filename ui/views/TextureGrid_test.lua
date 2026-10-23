local TextureGrid = require("ui.views.TextureGrid")

local test = {}

---@param limit integer
---@return table grid
---@return table state
local function new_grid(limit)
	local state = {loads = {}, released = {}, requests = {}}
	local grid = setmetatable({
		limit = limit, images = {}, loaded_count = 0, frame = 0, items = {},
		load = function(item)
			state.loads[#state.loads + 1] = item
			local data = item ~= "missing" and {release = function() state.released[#state.released + 1] = "data " .. item end}
			local request = {done = not state.slow, result = {n = 1, data}}
			state.requests[item] = request
			return request
		end,
	}, {__index = TextureGrid})
	return grid, state
end

---@param state table
---@param callback fun()
local function with_upload(state, callback)
	local new_image = love.graphics.newImage
	love.graphics.newImage = function(data)
		local name = state.loads[#state.loads]
		return {data = data, release = function() state.released[#state.released + 1] = name end}
	end
	local ok, err = xpcall(callback, debug.traceback)
	love.graphics.newImage = new_image
	if not ok then error(err) end
end

---@param t testing.T
function test.keeps_at_most_the_limit_and_releases_the_images_drawn_longest_ago(t)
	local grid, state = new_grid(2)
	with_upload(state, function()
		grid.frame = 1
		t:assert(grid:getImage("a"))
		grid:getImage("b")
		t:tdeq(state.released, {"data a", "data b"}) -- the decoded data goes once it is uploaded
		state.released = {}
		grid.frame = 3
		grid:getImage("b")
		grid:getImage("c") -- "a" was drawn longest ago
		t:tdeq(state.released, {"data c", "a"})
		t:eq(grid.loaded_count, 2)
		grid:getImage("b")
		t:eq(#state.loads, 3) -- loaded images are reused

		grid.frame = 4
		grid:getImage("a") -- "b" and "c" were on screen last frame: kept, over the limit
		grid:getImage("b")
		grid:getImage("c")
		t:eq(grid.loaded_count, 3)

		grid:getImage("missing")
		grid:getImage("missing")
		t:tdeq(state.loads, {"a", "b", "c", "a", "missing"}) -- a missing texture is not requested again

		grid:clear()
		t:eq(grid.loaded_count, 0)
		t:eq(next(grid.images), nil)
	end)
end

---@param t testing.T
function test.requests_one_thumbnail_at_a_time(t)
	local grid, state = new_grid(8)
	state.slow = true
	with_upload(state, function()
		t:eq(grid:getImage("a"), nil)
		t:eq(grid:getImage("b"), nil)
		t:tdeq(state.loads, {"a"}) -- "b" waits for "a"
		t:eq(grid.pending.item, "a")
		state.requests.a.done = true
		grid.poll(grid)
		t:assert(grid:getImage("a"))
		t:eq(grid:getImage("b"), nil)
		t:tdeq(state.loads, {"a", "b"})
	end)
end

---@param t testing.T
function test.drops_a_thumbnail_that_finishes_after_the_picker_closed(t)
	local grid, state = new_grid(8)
	state.slow = true
	with_upload(state, function()
		grid:getImage("a")
		grid:clear()
		state.requests.a.done = true
		grid:poll()
		t:tdeq(state.released, {"data a"})
		t:eq(grid.images.a, nil)
		t:eq(grid.pending, nil)
	end)
end

---@param t testing.T
function test.a_failing_loader_leaves_the_cell_empty(t)
	local grid = new_grid(4)
	grid.load = function() error("broken file") end
	t:eq(grid:getImage("a"), nil)
	t:eq(grid.loaded_count, 0)
	t:eq(grid.pending, nil)
end

---@param t testing.T
function test.finds_the_cell_under_the_pointer(t)
	local grid = new_grid(4)
	grid.items = {"a", "b", "c", "d", "e"}
	grid.width, grid.height, grid.item_height, grid.gap = 300, 400, 140, 12
	grid.scroll_current, grid.overscroll = 0, 0
	grid.world_transform = love.math.newTransform()
	t:eq(grid:getColumnCount(), 2)
	t:eq(grid:getIndexAt(10, 10), 1)
	t:eq(grid:getIndexAt(150, 10), 2)
	t:eq(grid:getIndexAt(138, 10), nil) -- the gap
	t:eq(grid:getIndexAt(10, 160), 3)
	t:eq(grid:getIndexAt(150, 310), nil) -- past the last item
	t:eq(grid:getIndexAt(10, 310), 5)
end

return test
