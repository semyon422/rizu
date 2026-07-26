local Inputs = require("gui.input.Inputs")
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
function test.printDebugLayout_does_not_error(t)
	local s = Screen()
	local arranged = View()
	arranged.debug_name = "arranged"
	local anchored = arranged:add(View())
	anchored.debug_name = "anchored"
	s.root:add(arranged)
	arranged.arrange_strategy = {
		arrange = function(_, container)
			container.children[1].arranged = {1, 2, 3, 4}
		end,
	}

	s:printDebugLayout()
	t:eq(arranged.width, 0)
	t:eq(anchored.x, 1)
	t:eq(anchored.y, 2)
	t:eq(anchored.width, 3)
	t:eq(anchored.height, 4)
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
function test.move_changes_draw_and_input_order_after_flush(t)
	local s = Screen()
	local first = View()
	local second = View()
	first:setDraw(function() end)
	second:setDraw(function() end)
	first.handles_mouse_input = true
	second.handles_mouse_input = true
	first:anchorFixed(0, 0, 10, 10)
	second:anchorFixed(0, 0, 10, 10)
	s.root:add(first)
	s.root:add(second)
	s:flush()

	s.root:move(first, 2)
	s:flush()
	t:tdeq(s.draw_views, {second, first})

	local inputs = Inputs()
	inputs:beginFrame(5, 5)
	s:acceptInputs(inputs)
	t:tdeq(inputs.mouse_hits, {first, second})
end

---@param t testing.T
function test.insert_reparents_across_loaded_screens(t)
	local old_screen = Screen()
	local new_screen = Screen()
	local child = View()
	local loads, unloads = 0, 0
	function child:load() loads = loads + 1 end
	function child:unload() unloads = unloads + 1 end
	old_screen.root:add(child)
	old_screen:load()
	new_screen:load()

	new_screen.root:insert(1, child)

	t:eq(child.screen, new_screen)
	t:eq(child.parent, new_screen.root)
	t:eq(child.loaded, true)
	t:eq(unloads, 1)
	t:eq(loads, 2)
	t:eq(old_screen.dirty, true)
	t:eq(new_screen.dirty, true)
end

---@param t testing.T
function test.acceptInputs_respects_ancestor_clip(t)
	local s = Screen()
	s:resize(200, 200)
	local clip = s.root:add(View():anchorFixed(10, 10, 50, 50))
	clip:setClip(true)
	local child = clip:add(View():anchorFixed(40, 40, 50, 50))
	child.handles_mouse_input = true

	local inputs = Inputs()
	inputs:beginFrame(75, 75)
	s:acceptInputs(inputs)

	t:eq(child.clip_rect[1], 10)
	t:eq(child.clip_rect[3], 50)
	t:eq(#inputs.mouse_hits, 0)

	inputs:beginFrame(55, 55)
	s:acceptInputs(inputs)
	t:tdeq(inputs.mouse_hits, {child})
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
	local commands = s.renderer.commands
	t:eq(type(commands[1]), "number")
	t:eq(commands[2], drawing)
	t:eq(commands[3], commands[1])
	t:eq(commands[4], both)
	t:eq(s.renderer.command_count, 4)
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
	t:eq(type(s.renderer.commands[1]), "number")
	t:eq(s.renderer.commands[2], child)
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
function test.ui_scale_preserves_root_center_pivot(t)
	local s = Screen()
	s:setUIScale(2)
	s:resize(800, 600)
	s.root:setPivot(0.5, 0.5)

	local x, y = s.root:getWorldPosition()
	t:aeq(x, 0, 1e-9)
	t:aeq(y, 0, 1e-9)

	s.root:setScale(0.5, 0.5)
	x, y = s.root.world_transform:transformPoint(s.root.width / 2, s.root.height / 2)
	t:aeq(x, 400, 1e-9)
	t:aeq(y, 300, 1e-9)
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
function test.default_enter_and_exit(t)
	local s = Screen()
	s:enter()
	t:eq(s:exit(), true)
end

---@param t testing.T
function test.exit_clears_input_state(t)
	local s = Screen()
	local cleared
	s.inputs = {
		clearSubtree = function(_, root)
			cleared = root
		end,
	}

	t:eq(s:exit(), true)
	t:eq(cleared, s.root)
	t:eq(s.inputs, nil)
end

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
	t:eq(s.renderer.command_count, 0)
	t:eq(#s.renderer.commands, 0)
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
