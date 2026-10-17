local View = require("rizu.skin.View")
local ViewContainer = require("rizu.skin.ViewContainer")

local test = {}

---@param t testing.T
function test.anchor_factors_define_nine_viewport_anchors(t)
	local expected = {
		top_left = {0, 0}, top = {0.5, 0}, top_right = {1, 0},
		left = {0, 0.5}, center = {0.5, 0.5}, right = {1, 0.5},
		bottom_left = {0, 1}, bottom = {0.5, 1}, bottom_right = {1, 1},
	}
	for name, factors in pairs(expected) do t:tdeq(View.anchors[name], factors) end
end

---@param t testing.T
function test.view_positions_origin_at_selected_anchor_and_applies_transform(t)
	local rotation = love.math.newTransform()
	rotation:setTransformation(0, 0, math.pi / 2)
	local view = View({
		anchor = "bottom_right", origin = "center", x = -10, y = -5,
		width = 40, height = 20, transform = rotation,
	})
	local transform = view:getWorldTransform(200, 100)
	local center_x, center_y = transform:transformPoint(20, 10)
	t:eq(center_x, 190)
	t:eq(center_y, 95)
	local top_left_x, top_left_y = transform:transformPoint(0, 0)
	t:eq(top_left_x, 200)
	t:eq(top_left_y, 75)
end

---@param t testing.T
function test.view_reuses_world_transform(t)
	local view = View({width = 10, height = 10})
	local first = view:getWorldTransform(100, 100)
	t:eq(first, view:getWorldTransform(100, 100))
end

---@param t testing.T
function test.container_places_children_in_parent_local_coordinates(t)
	local root = ViewContainer({x = 10, y = 20, width = 100, height = 100})
	local child = View({anchor = "center", origin = "center", width = 20, height = 10})
	root:add(child)
	local root_transform = root:getWorldTransform(640, 480)
	local child_transform = child:getWorldTransform(root.width, root.height, root_transform)
	local x, y = child_transform:transformPoint(10, 5)
	t:eq(x, 60)
	t:eq(y, 70)
end

---@param t testing.T
function test.container_load_update_remove_and_unload_dispatch(t)
	local calls = {}
	local Probe = View + {}
	function Probe:load(game)
		View.load(self, game)
		table.insert(calls, "load")
	end
	function Probe:update(dt, game)
		table.insert(calls, ("update:%s:%s"):format(dt, game.name))
	end
	function Probe:unload(game)
		table.insert(calls, "unload")
		View.unload(self, game)
	end

	local game = {name = "game"}
	local root = ViewContainer({width = 100, height = 100})
	local child = Probe({width = 10, height = 10})
	root:add(child)
	root:load(game)
	root:update(0.25, game)
	t:tdeq(calls, {"load", "update:0.25:game"})
	t:assert(root:remove(child))
	t:tdeq(calls, {"load", "update:0.25:game", "unload"})
	t:eq(child.container, nil)
	root:unload(game)
end

---@param t testing.T
function test.container_rejects_cycles_and_multiple_parents(t)
	local ChildContainer = ViewContainer + {}
	local first = ViewContainer({width = 10, height = 10})
	local second = ChildContainer({width = 10, height = 10})
	local child = View({width = 1, height = 1})
	first:add(second)
	second:add(child)
	t:assert(not pcall(function() child:add(first) end))
	t:assert(not pcall(function() first:add(child) end))
	t:assert(not pcall(function() first:add(second) end))
end

return test
