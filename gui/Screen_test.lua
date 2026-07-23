local Screen = require("gui.Screen")
local View = require("gui.View")

local test = {}

---@param t testing.T
function test.new_screen_has_root(t)
	local s = Screen()
	t:assert(s.root ~= nil, "root should be set")
end

---@param t testing.T
function test.root_is_a_view(t)
	local s = Screen()
	t:assert(View * s.root, "root should be a View instance")
end

---@param t testing.T
function test.root_starts_unparented_with_no_children(t)
	local s = Screen()
	t:eq(s.root.parent, nil)
	t:eq(s.root.screen, s)
	t:eq(#s.root.children, 0)
end

---@param t testing.T
function test.add_injects_screen_into_subtree(t)
	local s = Screen()
	local parent = View()
	local child = View()
	parent:add(child)

	s.root:add(parent)

	t:eq(parent.screen, s)
	t:eq(child.screen, s)
end

---@param t testing.T
function test.update_does_not_error(t)
	local s = Screen()
	s:update(0.016)
end

---@param t testing.T
function test.draw_does_not_error(t)
	local s = Screen()
	s:draw()
end

---@param t testing.T
function test.acceptInputs_uses_flat_views_front_to_back(t)
	local s = Screen()
	local first = View()
	local last = View()
	local child = View()
	s.root:add(first)
	s.root:add(last)
	last:add(child)

	local seen = {}
	s:acceptInputs({
		processView = function(_, view)
			seen[#seen + 1] = view
		end,
	})

	t:tdeq(seen, {child, last, first, s.root})
end

---@param t testing.T
function test.relayout_builds_flat_preorder_and_ranges(t)
	local s = Screen()
	local a = View()
	local b = View()
	local leaf = View()
	s.root:add(a)
	s.root:add(b)
	b:add(leaf)

	s:relayout()

	t:tdeq(s.views, {s.root, a, b, leaf})
	t:eq(s.root.flat_index, 1)
	t:eq(s.root.flat_subtree_end, 4)
	t:eq(a.flat_index, 2)
	t:eq(a.flat_subtree_end, 2)
	t:eq(b.flat_index, 3)
	t:eq(b.flat_subtree_end, 4)
end

---@param t testing.T
function test.relayout_builds_specialized_update_and_draw_arrays(t)
	local s = Screen()
	local inert = View()
	local updating = View()
	local drawing = View()
	local both = View()
	updating:setUpdate(function() end)
	drawing:setDraw(function() end)
	both:setUpdate(function() end)
	both:setDraw(function() end)
	s.root:add(inert)
	s.root:add(updating)
	s.root:add(drawing)
	s.root:add(both)

	s:relayout()

	t:tdeq(s.update_views, {updating, both})
	t:tdeq(s.draw_views, {drawing, both})
end

---@param t testing.T
function test.tree_mutation_invalidates_and_flush_rebuilds_arrays(t)
	local s = Screen()
	s:relayout()
	local child = View()
	child:setDraw(function() end)

	s.root:add(child)
	t:eq(s.dirty, true)
	t:eq(#s.views, 1)

	s:flush()
	t:eq(s.dirty, false)
	t:tdeq(s.views, {s.root, child})
	t:tdeq(s.draw_views, {child})
end

---@param t testing.T
function test.update_and_draw_skip_base_noop_views(t)
	local s = Screen()
	local inert = View()
	local active = View()
	local updated = 0
	local drawn = 0
	active:setUpdate(function(_, dt)
		updated = updated + dt
	end)
	active:setDraw(function()
		drawn = drawn + 1
	end)
	s.root:add(inert)
	s.root:add(active)

	s:update(0.25)
	s:draw()

	t:eq(updated, 0.25)
	t:eq(drawn, 1)
end

---@param t testing.T
function test.resize_sets_root_size_and_screen_size(t)
	local s = Screen()
	s:resize(800, 600)
	t:eq(s.width, 800)
	t:eq(s.height, 600)
	t:eq(s.root.width, 800)
	t:eq(s.root.height, 600)
	t:eq(s.root.x, 0)
	t:eq(s.root.y, 0)
end

---@param t testing.T
function test.resize_triggers_relayout_of_children(t)
	local s = Screen()
	local child = View()
	child.anchor_max = {1, 1}
	s.root:add(child)

	s:resize(640, 480)

	t:eq(child.width, 640)
	t:eq(child.height, 480)
end

---@param t testing.T
function test.resize_again_relays_children(t)
	local s = Screen()
	local child = View()
	child.anchor_max = {1, 1}
	s.root:add(child)

	s:resize(640, 480)
	t:eq(child.width, 640)

	s:resize(1024, 768)
	t:eq(child.width, 1024)
	t:eq(child.height, 768)
end

-- ===========================================================================
-- ui_scale (§3.4, §7.4)
-- ===========================================================================

---@param t testing.T
function test.default_ui_scale_is_1(t)
	local s = Screen()
	t:eq(s.ui_scale, 1)
end

---@param t testing.T
function test.setUIScale_updates_field(t)
	local s = Screen()
	s:setUIScale(2)
	t:eq(s.ui_scale, 2)
end

---@param t testing.T
function test.setUIScale_rejects_invalid_values(t)
	local s = Screen()
	local bad = {0, -1, -0.5, math.huge, -math.huge, math.huge - math.huge, "1", nil, {}}
	for _, v in ipairs(bad) do
		t:has_error(function()
			s:setUIScale(v)
		end)
	end
end

---@param t testing.T
function test.resize_with_ui_scale_halves_root_size(t)
	local s = Screen()
	s:setUIScale(2)
	s:resize(800, 600)
	t:eq(s.root.width, 400)
	t:eq(s.root.height, 300)
end

---@param t testing.T
function test.ui_scale_bakes_scale_into_root_world_transform(t)
	local s = Screen()
	s:setUIScale(2)
	s:resize(800, 600)
	local x, y = s.root.world_transform:transformPoint(100, 50)
	t:aeq(x, 200, 1e-9)
	t:aeq(y, 100, 1e-9)
end

---@param t testing.T
function test.ui_scale_doubles_child_world_position(t)
	local s = Screen()
	s:setUIScale(2)
	s:resize(800, 600)

	local child = View()
	child.offset_min = {10, 20}
	child.offset_max = {40, 60}
	s.root:add(child)
	s:relayout()

	local wx, wy = child:getWorldPosition()
	t:aeq(wx, 20, 1e-9)
	t:aeq(wy, 40, 1e-9)
end

---@param t testing.T
function test.setUIScale_after_resize_triggers_relayout(t)
	local s = Screen()
	s:resize(800, 600)
	t:eq(s.root.width, 800)

	s:setUIScale(2)
	t:eq(s.root.width, 400)
	t:eq(s.root.height, 300)
end

---@param t testing.T
function test.screen_relayout_preserves_ui_scale(t)
	local s = Screen()
	s:setUIScale(2)
	s:resize(800, 600)

	local child = View()
	child.offset_min = {10, 10}
	child.offset_max = {20, 20}
	s.root:add(child)
	s:relayout()

	local wx, wy = child:getWorldPosition()
	t:aeq(wx, 20, 1e-9)
	t:aeq(wy, 20, 1e-9)
end

-- ===========================================================================
-- Lifecycle
-- ===========================================================================

---@param t testing.T
function test.load_and_unload_visit_tree_once(t)
	local s = Screen()
	local child = View()
	local loads, unloads = 0, 0
	function child:load() loads = loads + 1 end
	function child:unload() unloads = unloads + 1 end
	s.root:add(child)

	s:load()
	s:load()
	t:eq(loads, 1)

	s:unload()
	s:unload()
	t:eq(unloads, 1)
end

---@param t testing.T
function test.add_to_loaded_screen_loads_and_remove_unloads(t)
	local s = Screen()
	s:load()
	local child = View()
	local loads, unloads = 0, 0
	function child:load() loads = loads + 1 end
	function child:unload() unloads = unloads + 1 end

	s.root:add(child)
	t:eq(loads, 1)
	s.root:remove(child)
	t:eq(unloads, 1)
	t:eq(child.detached, true)
end

return test
