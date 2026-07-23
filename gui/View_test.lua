local View = require("gui.View")

local test = {}

---@param t testing.T
function test.new_view_has_no_parent(t)
	local v = View()
	t:eq(v.parent, nil)
end

---@param t testing.T
function test.new_view_has_empty_children(t)
	local v = View()
	t:eq(#v.children, 0)
end

---@param t testing.T
function test.add_sets_parent_and_appends(t)
	local parent = View()
	local child = View()

	local ret = parent:add(child)

	t:eq(child.parent, parent)
	t:eq(#parent.children, 1)
	t:eq(parent.children[1], child)
	t:eq(ret, child)
end

---@param t testing.T
function test.add_preserves_sibling_order(t)
	local parent = View()
	local a = View()
	local b = View()
	local c = View()

	parent:add(a)
	parent:add(b)
	parent:add(c)

	t:eq(#parent.children, 3)
	t:eq(parent.children[1], a)
	t:eq(parent.children[2], b)
	t:eq(parent.children[3], c)
end

---@param t testing.T
function test.add_self_is_error(t)
	local v = View()
	t:has_error(function()
		v:add(v)
	end)
end

---@param t testing.T
function test.add_direct_ancestor_is_cycle(t)
	local a = View()
	local b = View()
	a:add(b)

	t:has_error(function()
		b:add(a)
	end)
end

---@param t testing.T
function test.add_deep_ancestor_is_cycle(t)
	local a = View()
	local b = View()
	local c = View()
	a:add(b)
	b:add(c)

	t:has_error(function()
		c:add(a)
	end)
end

---@param t testing.T
function test.add_reparents_from_old_parent(t)
	local a = View()
	local b = View()
	local child = View()
	a:add(child)

	b:add(child)

	t:eq(child.parent, b)
	t:eq(#a.children, 0)
	t:eq(#b.children, 1)
	t:eq(b.children[1], child)
end

---@param t testing.T
function test.add_to_same_parent_moves_to_end(t)
	local parent = View()
	local a = View()
	local b = View()
	local c = View()
	parent:add(a)
	parent:add(b)
	parent:add(c)

	parent:add(a)

	t:eq(#parent.children, 3)
	t:eq(parent.children[1], b)
	t:eq(parent.children[2], c)
	t:eq(parent.children[3], a)
	t:eq(a.parent, parent)
end

---@param t testing.T
function test.remove_clears_parent_and_removes(t)
	local parent = View()
	local child = View()
	parent:add(child)

	parent:remove(child)

	t:eq(child.parent, nil)
	t:eq(child.screen, nil)
	t:eq(#parent.children, 0)
end

---@param t testing.T
function test.remove_preserves_sibling_order(t)
	local parent = View()
	local a = View()
	local b = View()
	local c = View()
	parent:add(a)
	parent:add(b)
	parent:add(c)

	parent:remove(b)

	t:eq(#parent.children, 2)
	t:eq(parent.children[1], a)
	t:eq(parent.children[2], c)
end

---@param t testing.T
function test.remove_non_child_is_error(t)
	local parent = View()
	local orphan = View()

	t:has_error(function()
		parent:remove(orphan)
	end)
end

---@param t testing.T
function test.remove_unparented_is_error(t)
	local parent = View()
	local loose = View()

	t:has_error(function()
		parent:remove(loose)
	end)
end

---@param t testing.T
function test.remove_from_wrong_parent_is_error(t)
	local a = View()
	local b = View()
	local child = View()
	a:add(child)

	t:has_error(function()
		b:remove(child)
	end)

	t:eq(child.parent, a)
	t:eq(#a.children, 1)
end

-- ===========================================================================
-- Layout: resolution (§3.1)
-- ===========================================================================

local function newSizedRoot(w, h)
	local root = View()
	root.width = w
	root.height = h
	return root
end

---@param t testing.T
function test.relayout_does_not_error_on_root_only(t)
	local root = newSizedRoot(100, 100)
	root:relayout()
	t:eq(root.width, 100)
	t:eq(root.height, 100)
end

---@param t testing.T
function test.default_anchors_and_offsets_resolve_to_zero_rect(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	root:add(child)

	root:relayout()

	t:eq(child.x, 0)
	t:eq(child.y, 0)
	t:eq(child.width, 0)
	t:eq(child.height, 0)
end

---@param t testing.T
function test.point_anchor_with_offsets_gives_fixed_rect(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {10, 20}
	child.offset_max = {110, 70}
	root:add(child)

	root:relayout()

	t:eq(child.x, 10)
	t:eq(child.y, 20)
	t:eq(child.width, 100)
	t:eq(child.height, 50)
end

---@param t testing.T
function test.centered_via_point_anchor_and_signed_offsets(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.anchor_min = {0.5, 0.5}
	child.anchor_max = {0.5, 0.5}
	child.offset_min = {-25, -25}
	child.offset_max = {25, 25}
	root:add(child)

	root:relayout()

	t:eq(child.x, 25)
	t:eq(child.y, 25)
	t:eq(child.width, 50)
	t:eq(child.height, 50)
end

---@param t testing.T
function test.fill_anchors_match_parent(t)
	local root = newSizedRoot(100, 80)
	local child = View()
	child.anchor_max = {1, 1}
	root:add(child)

	root:relayout()

	t:eq(child.x, 0)
	t:eq(child.y, 0)
	t:eq(child.width, 100)
	t:eq(child.height, 80)
end

---@param t testing.T
function test.fill_with_signed_margin_offsets(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.anchor_max = {1, 1}
	child.offset_min = {10, 10}
	child.offset_max = {-10, -10}
	root:add(child)

	root:relayout()

	t:eq(child.x, 10)
	t:eq(child.y, 10)
	t:eq(child.width, 80)
	t:eq(child.height, 80)
end

---@param t testing.T
function test.percent_width_via_anchor_spread(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.anchor_max = {0.5, 1}
	child.offset_min = {20, 0}
	root:add(child)

	root:relayout()

	t:eq(child.x, 20)
	t:eq(child.y, 0)
	t:eq(child.width, 30)
	t:eq(child.height, 100)
end

---@param t testing.T
function test.negative_size_clamps_to_zero(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {80, 80}
	child.offset_max = {20, 20}
	root:add(child)

	root:relayout()

	t:eq(child.width, 0)
	t:eq(child.height, 0)
end

---@param t testing.T
function test.resolution_inherits_parent_resolved_size_not_root(t)
	local root = newSizedRoot(100, 100)
	local middle = View()
	middle.anchor_max = {1, 1}
	root:add(middle)

	local leaf = View()
	leaf.anchor_max = {1, 1}
	leaf.offset_min = {0, 0}
	leaf.offset_max = {-50, -50}
	middle:add(leaf)

	root:relayout()

	t:eq(middle.width, 100)
	t:eq(leaf.width, 50)
	t:eq(leaf.height, 50)
end

-- ===========================================================================
-- Layout: world transform composition (§4)
-- ===========================================================================

---@param t testing.T
function test.root_world_transform_is_identity_at_origin(t)
	local root = newSizedRoot(100, 100)
	root:relayout()

	local x0, y0 = root.world_transform:transformPoint(0, 0)
	local x1, y1 = root.world_transform:transformPoint(100, 100)
	t:aeq(x0, 0, 1e-9)
	t:aeq(y0, 0, 1e-9)
	t:aeq(x1, 100, 1e-9)
	t:aeq(y1, 100, 1e-9)
end

---@param t testing.T
function test.child_world_origin_matches_resolved_xy(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {10, 20}
	child.offset_max = {40, 60}
	root:add(child)

	root:relayout()

	local wx, wy = child:getWorldPosition()
	t:aeq(wx, 10, 1e-9)
	t:aeq(wy, 20, 1e-9)
end

---@param t testing.T
function test.visual_offset_shifts_world_origin_only(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {10, 20}
	child.offset_max = {40, 60}
	child.offset_x = 5
	child.offset_y = 7
	root:add(child)

	root:relayout()

	local wx, wy = child:getWorldPosition()
	t:aeq(wx, 15, 1e-9)
	t:aeq(wy, 27, 1e-9)
	t:eq(child.x, 10)
	t:eq(child.y, 20)
end

---@param t testing.T
function test.nested_world_transforms_compose(t)
	local root = newSizedRoot(100, 100)
	local a = View()
	a.offset_min = {10, 10}
	a.offset_max = {20, 20}
	root:add(a)

	local b = View()
	b.offset_min = {10, 10}
	b.offset_max = {20, 20}
	a:add(b)

	root:relayout()

	local wx, wy = b:getWorldPosition()
	t:aeq(wx, 20, 1e-9)
	t:aeq(wy, 20, 1e-9)
end

---@param t testing.T
function test.scale_2x_doubles_world_corner_distance(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {10, 10}
	child.offset_max = {60, 60}
	child.scale_x = 2
	child.scale_y = 2
	root:add(child)

	root:relayout()

	local cx, cy = child.world_transform:transformPoint(child.width, child.height)
	t:aeq(cx, 110, 1e-9)
	t:aeq(cy, 110, 1e-9)
end

---@param t testing.T
function test.pivot_does_not_shift_origin_without_rotation_or_scale(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {10, 20}
	child.offset_max = {40, 60}
	child.pivot = {0.5, 0.5}
	root:add(child)

	root:relayout()

	local wx, wy = child:getWorldPosition()
	t:aeq(wx, 10, 1e-9)
	t:aeq(wy, 20, 1e-9)
end

---@param t testing.T
function test.rotation_pi_around_center_swaps_corners(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {0, 0}
	child.offset_max = {50, 50}
	child.pivot = {0.5, 0.5}
	child.rotation = math.pi
	root:add(child)

	root:relayout()

	local wx, wy = child.world_transform:transformPoint(0, 0)
	t:aeq(wx, 50, 1e-3)
	t:aeq(wy, 50, 1e-3)
end

---@param t testing.T
function test.getWorldPosition_matches_transformPoint_zero_zero(t)
	local root = newSizedRoot(100, 100)
	local child = View()
	child.offset_min = {7, 13}
	child.offset_max = {30, 40}
	root:add(child)

	root:relayout()

	local px, py = child.world_transform:transformPoint(0, 0)
	local gx, gy = child:getWorldPosition()
	t:aeq(px, gx, 1e-9)
	t:aeq(py, gy, 1e-9)
end

-- ===========================================================================
-- Visual setters and subtree composition (§4.4)
-- ===========================================================================

---@param t testing.T
function test.visual_offset_setter_recomposes_descendants_without_layout(t)
	local root = newSizedRoot(100, 100)
	local parent = View()
	parent.offset_max = {20, 20}
	local child = View()
	child.offset_min = {5, 7}
	child.offset_max = {10, 12}
	root:add(parent)
	parent:add(child)
	root:relayout()
	local resolved_x = parent.x

	local returned = parent:setOffset(10, 20)

	local x, y = child:getWorldPosition()
	t:eq(returned, parent)
	t:eq(parent.x, resolved_x)
	t:aeq(x, 15, 1e-9)
	t:aeq(y, 27, 1e-9)
end

---@param t testing.T
function test.opacity_setter_composes_effective_opacity_and_presence(t)
	local root = newSizedRoot(100, 100)
	local parent = View()
	local child = View()
	root:add(parent)
	parent:add(child)
	root:relayout()

	parent:setOpacity(0.5)
	t:aeq(parent.effective_opacity, 0.5, 1e-9)
	t:aeq(child.effective_opacity, 0.5, 1e-9)
	t:eq(child.present, true)

	parent:setOpacity(0)
	t:eq(parent.present, false)
	t:eq(child.present, false)
end

---@param t testing.T
function test.zero_scale_makes_subtree_root_not_present(t)
	local view = newSizedRoot(100, 100)
	view:relayout()

	view:setScale(0, 1)

	t:eq(view.present, false)
end

-- ===========================================================================
-- Input traversal (§8)
-- ===========================================================================

---@param t testing.T
function test.acceptInputs_traverses_descendants_front_to_back(t)
	local root = View()
	local first = View()
	local last = View()
	local child = View()
	root:add(first)
	root:add(last)
	last:add(child)

	local seen = {}
	root:acceptInputs({
		processView = function(_, view)
			table.insert(seen, view)
		end,
	})

	t:tdeq(seen, {child, last, first, root})
end

-- ===========================================================================
-- Instance callbacks and flat-cache invalidation
-- ===========================================================================

---@param t testing.T
function test.setUpdate_and_setDraw_invalidate_attached_screen(t)
	local screen = {dirty = false}
	function screen:invalidateLayout()
		self.dirty = true
	end
	local view = View()
	view:setScreen(screen)
	local update = function() end
	local draw = function() end

	view:setUpdate(update)
	t:eq(view.update, update)
	t:eq(screen.dirty, true)

	screen.dirty = false
	view:setDraw(draw)
	t:eq(view.draw, draw)
	t:eq(screen.dirty, true)
end

---@param t testing.T
function test.setUpdate_and_setDraw_nil_restore_class_methods(t)
	local view = View()
	view:setUpdate(function() end)
	view:setDraw(function() end)

	view:setUpdate(nil)
	view:setDraw(nil)

	t:eq(view.update, View.update)
	t:eq(view.draw, View.draw)
end

---@param t testing.T
function test.setUpdate_and_setDraw_reject_non_functions(t)
	local view = View()
	t:has_error(function() view:setUpdate(1) end)
	t:has_error(function() view:setDraw({}) end)
end

-- ===========================================================================
-- clear()
-- ===========================================================================

---@param t testing.T
function test.clear_empties_children(t)
	local parent = View()
	parent:add(View())
	parent:add(View())

	parent:clear()

	t:eq(#parent.children, 0)
end

---@param t testing.T
function test.clear_detaches_each_direct_child(t)
	local parent = View()
	local a, b = View(), View()
	parent:add(a)
	parent:add(b)

	parent:clear()

	t:eq(a.parent, nil)
	t:eq(b.parent, nil)
end

---@param t testing.T
function test.clear_recurses_into_descendants(t)
	local root = View()
	local a = View()
	local b = View()
	local inner = View()
	root:add(a)
	a:add(b)
	b:add(inner)

	root:clear()

	t:eq(#root.children, 0)
	t:eq(#a.children, 0)
	t:eq(#b.children, 0)
	t:eq(a.parent, nil)
	t:eq(b.parent, nil)
	t:eq(inner.parent, nil)
end

---@param t testing.T
function test.clear_keeps_self_attached_to_its_parent(t)
	local root = View()
	local child = View()
	local inner = View()
	root:add(child)
	child:add(inner)

	child:clear()

	t:eq(child.parent, root)
	t:eq(#child.children, 0)
	t:eq(inner.parent, nil)
end

---@param t testing.T
function test.clear_on_leaf_is_noop(t)
	local leaf = View()
	leaf:clear()
	t:eq(#leaf.children, 0)
end

---@param t testing.T
function test.clear_then_add_again_works(t)
	local parent = View()
	local first = View()
	parent:add(first)
	parent:clear()

	local second = View()
	parent:add(second)

	t:eq(#parent.children, 1)
	t:eq(parent.children[1], second)
	t:eq(second.parent, parent)
	t:eq(first.parent, nil)
end

-- ===========================================================================
-- Placement and invalidating setters
-- ===========================================================================

---@param t testing.T
function test.anchorFixed_sets_absolute_authored_rect(t)
	local view = View():anchorFixed(10, 20, 30, 40)
	t:tdeq(view.anchor_min, {0, 0})
	t:tdeq(view.anchor_max, {0, 0})
	t:tdeq(view.offset_min, {10, 20})
	t:tdeq(view.offset_max, {40, 60})
	t:eq(view.size_mode_x, "fixed")
	t:eq(view.size_mode_y, "fixed")
end

---@param t testing.T
function test.anchorFill_uses_signed_edge_margins(t)
	local view = View():anchorFill(10, 20, 30, 40)
	t:tdeq(view.anchor_min, {0, 0})
	t:tdeq(view.anchor_max, {1, 1})
	t:tdeq(view.offset_min, {10, 20})
	t:tdeq(view.offset_max, {-30, -40})
	t:eq(view.size_mode_x, "fill")
	t:eq(view.size_mode_y, "fill")
end

---@param t testing.T
function test.anchorPercent_resolves_percent_rect(t)
	local root = newSizedRoot(200, 100)
	local view = View():anchorPercent(0.25, 0.2, 0.75, 0.8)
	root:add(view)
	root:relayout()
	t:eq(view.x, 50)
	t:eq(view.y, 20)
	t:eq(view.width, 100)
	t:aeq(view.height, 60, 1e-9)
end

---@param t testing.T
function test.setPosition_preserves_authored_size(t)
	local view = View():setSize(30, 40):setPosition(10, 20)
	t:tdeq(view.offset_min, {10, 20})
	t:tdeq(view.offset_max, {40, 60})
end

---@param t testing.T
function test.setAlignment_survives_setSize(t)
	local root = newSizedRoot(200, 100)
	local view = View():setSize(20, 10):setAlignment(0.5, 0.5):setSize(40, 20)
	root:add(view)
	root:relayout()
	t:eq(view.x, 80)
	t:eq(view.y, 40)
	t:eq(view.width, 40)
	t:eq(view.height, 20)
end

---@param t testing.T
function test.fixed_operations_reject_fill_axes(t)
	local view = View():anchorFill(0, 0, 0, 0)
	t:has_error(function() view:setPosition(1, 2) end)
	t:has_error(function() view:setSize(1, 2) end)
end

---@param t testing.T
function test.layout_setters_invalidate_attached_screen(t)
	local screen = {dirty = false}
	function screen:invalidateLayout() self.dirty = true end
	local view = View()
	view:setScreen(screen)
	view:setLayoutIgnore(true)
	t:eq(screen.dirty, true)
	screen.dirty = false
	view:setClip(true)
	t:eq(screen.dirty, true)
end

---@param t testing.T
function test.onLayoutChanged_fires_initially_and_after_geometry_change(t)
	local root = newSizedRoot(100, 100)
	local view = View():setSize(10, 20)
	local changes = {}
	function view:onLayoutChanged(old_x, old_y, old_width, old_height)
		changes[#changes + 1] = {old_x, old_y, old_width, old_height}
	end
	root:add(view)
	root:relayout()
	view:setSize(20, 30)
	root:relayout()
	t:eq(#changes, 2)
	t:tdeq(changes[1], {0, 0, 0, 0})
	t:tdeq(changes[2], {0, 0, 10, 20})
end

return test
