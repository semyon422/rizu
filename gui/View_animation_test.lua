local Screen = require("gui.Screen")
local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local StackContainer = require("gui.layout.StackContainer")
local TrackContainer = require("gui.layout.TrackContainer")

local test = {}

---@param t testing.T
function test.transform_progresses_and_finishes(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:transformTo("offset_x", 100, 1, "Linear")

	screen:update(0.25)
	t:aeq(view.offset_x, 25, 1e-9)
	screen:update(0.75)
	t:eq(view.offset_x, 100)
	t:eq(view:hasTransforms(), false)
end

---@param t testing.T
function test.replacement_starts_from_current_value(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:moveToX(100, 1, "Linear")
	screen:update(0.5)
	view:moveToX(0, 1, "Linear")
	screen:update(0.5)

	t:aeq(view.offset_x, 25, 1e-9)
end

---@param t testing.T
function test.multi_target_motion_recomposes_once(t)
	local screen = Screen()
	local view = screen.root:add(View())
	screen:flush()
	local compositions = 0
	local original = view.composeSubtree
	function view:composeSubtree()
		compositions = compositions + 1
		original(self)
	end
	view:moveTo(10, 20, 1, "Linear")

	screen:update(0.5)
	t:eq(compositions, 1)
	t:aeq(view.offset_x, 5, 1e-9)
	t:aeq(view.offset_y, 10, 1e-9)
end

---@param t testing.T
function test.delay_offsets_subsequent_transform(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:delay(0.5):moveToX(10, 0.5, "Linear")
	screen:update(0.25)
	t:eq(view.offset_x, 0)
	screen:update(0.5)
	t:aeq(view.offset_x, 5, 1e-9)
end

---@param t testing.T
function test.delay_does_not_leak_into_later_calls(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:delay(1):fadeOut(0.2, "Linear")
	view:moveToX(10, 0.5, "Linear")

	screen:update(0.25)
	t:aeq(view.offset_x, 5, 1e-9)
	t:eq(view.opacity, 1)
end

---@param t testing.T
function test.delayed_transform_waits_for_the_running_one_on_its_target(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:setOpacity(0)
	local completed = 0
	view:transformTo("opacity", 1, 0.2, "Linear", function() completed = completed + 1 end)
	view:delay(1):fadeOut(0.2, "Linear")

	screen:update(0.1)
	t:aeq(view.opacity, 0.5, 1e-9)
	screen:update(0.1)
	t:eq(view.opacity, 1)
	t:eq(completed, 1)
	screen:update(0.9)
	t:eq(view.opacity, 1)
	t:eq(view:hasTransforms(), true)
	-- Starts at 1.2 from the value it finds there.
	screen:update(0.2)
	t:aeq(view.opacity, 0.5, 1e-9)
	screen:update(0.15)
	t:eq(view.opacity, 0)
	t:eq(view:hasTransforms(), false)
end

---@param t testing.T
function test.delayed_chain_reads_like_a_sequence(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:setOpacity(0)
	view:fadeIn(0.2, "Linear"):delay(1):fadeOut(0.2, "Linear")

	screen:update(0.2)
	t:eq(view.opacity, 1)
	screen:update(1.25)
	t:eq(view.opacity, 0)
end

---@param t testing.T
function test.clear_and_immediate_transform_drop_delayed_ones(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:delay(1):fadeOut(0.2)
	view:clearTransforms("opacity")
	t:eq(view:hasTransforms(), false)

	view:delay(1):fadeOut(0.2)
	view:fadeTo(0.5, 0)
	screen:update(2)
	t:eq(view.opacity, 0.5)
end

---@param t testing.T
function test.only_animating_attached_views_step(t)
	local screen = Screen()
	local idle = screen.root:add(View())
	local moving = screen.root:add(View())
	local steps = {}
	for _, view in ipairs({idle, moving}) do
		local step = view.stepAnimations
		function view:stepAnimations(dt, completions)
			steps[self] = (steps[self] or 0) + 1
			return step(self, dt, completions)
		end
	end
	moving:moveToX(10, 1, "Linear")

	screen:update(0.5)
	t:eq(steps[idle], nil)
	t:eq(steps[moving], 1)
	t:eq(screen:isTransitionActive(), true)

	screen.root:remove(moving)
	screen:update(0.25)
	t:eq(steps[moving], 1)
	screen.root:add(moving)
	screen:update(0.5)
	t:eq(moving.offset_x, 10)
	t:eq(screen:isTransitionActive(), false)
	screen:update(0.5)
	t:eq(steps[moving], 2)
end

---@param t testing.T
function test.nested_animations_recompose_shared_descendants_once(t)
	local screen = Screen()
	local parent = screen.root:add(View())
	local child = parent:add(View())
	local leaf = child:add(View())
	screen:flush()
	local composes = 0
	local compose = leaf.compose
	function leaf:compose(root_scale, opacity_only)
		composes = composes + 1
		compose(self, root_scale, opacity_only)
	end
	parent:moveToX(10, 1, "Linear")
	child:moveToX(10, 1, "Linear")
	leaf:fadeOut(1, "Linear")

	screen:update(0.5)

	t:eq(composes, 1)
	t:eq(leaf:getWorldPosition(), 10)
	t:aeq(leaf.effective_opacity, 0.5, 1e-9)
end

---@param t testing.T
function test.opacity_animation_keeps_matrices_and_updates_descendants(t)
	local screen = Screen()
	local parent = screen.root:add(View())
	local child = parent:add(View())
	screen:flush()
	local geometry = 0
	local composeGeometry = child.composeGeometry
	function child:composeGeometry(root_scale)
		geometry = geometry + 1
		composeGeometry(self, root_scale)
	end
	parent:fadeOut(1, "Linear")

	screen:update(0.5)
	t:eq(geometry, 0)
	t:aeq(child.effective_opacity, 0.5, 1e-9)
	screen:update(0.5)
	t:eq(child.present, false)
end

---@param t testing.T
function test.pivot_animation_reuses_the_pivot_table(t)
	local screen = Screen()
	local view = screen.root:add(View())
	local pivot = view.pivot
	view:pivotTo(1, 1, 1, "Linear")

	screen:update(0.5)

	t:eq(view.pivot, pivot)
	t:tdeq(view.pivot, {0.5, 0.5})
end

---@param t testing.T
function test.finish_fires_completion_once(t)
	local view = View()
	local calls = 0
	view:transformTo("opacity", 0, 1, "Linear", function()
		calls = calls + 1
	end)
	view:finishTransforms("opacity")
	view:finishTransforms("opacity")

	t:eq(view.opacity, 0)
	t:eq(calls, 1)
end

---@param t testing.T
function test.clear_drops_without_applying_or_completing(t)
	local view = View()
	local calls = 0
	view:transformTo("opacity", 0, 1, nil, function() calls = calls + 1 end)
	view:clearTransforms()

	t:eq(view.opacity, 1)
	t:eq(calls, 0)
end

---@param t testing.T
function test.animation_steps_before_user_update(t)
	local screen = Screen()
	local view = screen.root:add(View())
	local observed
	view:setUpdate(function(self)
		observed = self.opacity
	end)
	view:fadeOut(1, "Linear")

	screen:update(0.5)
	t:aeq(observed, 0.5, 1e-9)
end

---@param t testing.T
function test.expire_removes_at_next_flush_after_last_transform(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:fadeOut(0.2, "Linear"):expire()

	screen:update(0.2)
	t:eq(view.parent, screen.root)
	screen:flush()
	t:eq(view.parent, nil)
end

---@param t testing.T
function test.expire_without_transforms_removes_at_next_flush(t)
	local screen = Screen()
	local view = screen.root:add(View())
	view:expire()

	t:eq(view.parent, screen.root)
	screen:flush()
	t:eq(view.parent, nil)
end

---@param t testing.T
function test.layout_transition_keeps_final_rect_and_visual_position(t)
	local screen = Screen()
	screen:resize(100, 100)
	local container = screen.root:add(StackContainer({
		padding = 0,
		layout_transition = {duration = 1, easing = "Linear"},
	}))
	container:anchorFill(0, 0, 0, 0)
	local child = container:add(View())
	screen:flush()
	local old_world_x = child:getWorldPosition()

	container.padding = {20, 0, 0, 0}
	container:invalidate()
	screen:flush()
	local visual_x = child:getWorldPosition()

	t:eq(child.x, 20)
	t:aeq(visual_x, old_world_x, 1e-9)
	screen:update(1)
	t:eq(child.offset_x, 0)
	local final_x = child:getWorldPosition()
	t:aeq(final_x, 20, 1e-9)
end

---A row of tracks filling a 1000x100 screen; `first` is a fixed 100 px track.
---@param transition gui.layout.LayoutTransition
---@return gui.Screen screen
---@return gui.layout.TrackContainer row
---@return gui.View first
local function newTrackRow(transition)
	local screen = Screen()
	screen:resize(1000, 100)
	local row = screen.root:add(TrackContainer({direction = "row", layout_transition = transition}))
	row:anchorFill(0, 0, 0, 0)
	local first = row:add(View(), 100)
	screen:flush()
	return screen, row, first
end

---@param t testing.T
function test.layout_transition_snaps_size_and_glides_position_by_default(t)
	local screen, row, first = newTrackRow({duration = 1, easing = "Linear"})
	local second = row:add(View(), 50)
	screen:flush()

	row:setTrackSize(first, 200)
	screen:flush()

	local _, _, first_width = first:getWorldBounds()
	t:eq(first_width, 200)
	t:eq(second.x, 200)
	t:eq(second:getWorldPosition(), 100)
	screen:update(0.5)
	t:aeq(second:getWorldPosition(), 150, 1e-9)
	screen:update(0.5)
	t:eq(second:getWorldPosition(), 200)
	t:eq(second:isAnimating(), false)
end

---@param t testing.T
function test.layout_transition_interrupted_size_glide_is_continuous(t)
	local screen, row, first = newTrackRow({duration = 1, easing = "Linear", scale_size = true})
	row:setTrackSize(first, 200)
	screen:update(0.5)
	local _, _, width = first:getWorldBounds()
	t:aeq(width, 150, 1e-9)

	row:setTrackSize(first, 400)
	screen:flush()

	_, _, width = first:getWorldBounds()
	t:aeq(width, 150, 1e-9)
	screen:update(1)
	_, _, width = first:getWorldBounds()
	t:eq(width, 400)
end

---@param t testing.T
function test.layout_transition_leaves_visual_channel_alone(t)
	local screen, row, first = newTrackRow({duration = 1, easing = "Linear", scale_size = true})
	local second = row:add(View(), 50)
	screen:flush()
	second:setScale(2, 2):setOffset(5, 0)

	row:setTrackSize(first, 200)
	row:setTrackSize(second, 100)
	screen:flush()
	t:tdeq({second.scale_x, second.scale_y, second.offset_x}, {2, 2, 5})
	t:eq(second:hasTransforms(), false)
	screen:update(1)

	t:tdeq({second.scale_x, second.scale_y, second.offset_x}, {2, 2, 5})
	local x, _, width = second:getWorldBounds()
	t:tdeq({x, width}, {205, 200})
end

---@param t testing.T
function test.layout_transition_nested_containers_compensate_size_once(t)
	local transition = {duration = 1, easing = "Linear", scale_size = true}
	local screen, row, inner = newTrackRow(transition)
	row:remove(inner)
	inner = row:add(TrackContainer({direction = "row", layout_transition = transition}), 100)
	local leaf = inner:add(View())
	screen:flush()

	row:setTrackSize(inner, 200)
	screen:flush()

	t:eq(leaf.width, 200)
	local _, _, width = leaf:getWorldBounds()
	t:aeq(width, 100, 1e-9)
end

---@param t testing.T
function test.layout_transition_scale_keeps_old_rect_with_pivot(t)
	local screen, row, first = newTrackRow({duration = 1, easing = "Linear", scale_size = true})
	first:setPivot(0.5, 0.5)

	row:setTrackSize(first, 300)
	screen:flush()

	local x, _, width = first:getWorldBounds()
	t:aeq(x, 0, 1e-9)
	t:aeq(width, 100, 1e-9)
end

---@param t testing.T
function test.layout_transition_ignores_window_resize(t)
	local screen = Screen()
	screen:resize(1000, 100)
	local container = screen.root:add(StackContainer({
		layout_transition = {duration = 1, easing = "Linear", scale_size = true},
	}))
	container:anchorFill(0, 0, 0, 0)
	local child = container:add(View())
	screen:flush()

	screen:resize(500, 100)

	t:eq(child.width, 500)
	t:eq(child.scale_x, 1)
	t:eq(child:isAnimating(), false)
	local _, _, width = child:getWorldBounds()
	t:eq(width, 500)
end

---@param t testing.T
function test.layout_transition_glides_when_the_container_resizes_itself(t)
	local screen = Screen()
	screen:resize(100, 100)
	local column = screen.root:add(FlowContainer({
		direction = "column",
		layout_transition = {duration = 1, easing = "Linear"},
	}))
	local row = column:add(View():setSize(10, 10))
	column:fitContent()
	screen:flush()

	column:insert(1, View():setSize(10, 30))
	column:fitContent()
	screen:flush()

	t:eq(row.y, 30)
	local _, y = row:getWorldPosition()
	t:eq(y, 0)
end

---@param t testing.T
function test.layout_transition_does_not_glide_from_another_parent(t)
	local screen = Screen()
	screen:resize(1000, 100)
	local transition = {duration = 1, easing = "Linear"}
	local left = screen.root:add(StackContainer({layout_transition = transition}):anchorFixed(0, 0, 100, 100))
	local right = screen.root:add(StackContainer({layout_transition = transition, padding = {7, 0, 0, 0}}))
	right:anchorFixed(500, 0, 100, 100)
	local child = left:add(View())
	screen:flush()

	right:add(child)
	screen:flush()

	t:eq(child:getWorldPosition(), 507)
	t:eq(child:isAnimating(), false)
end

---@param t testing.T
function test.layout_transition_does_not_glide_on_reattach(t)
	local screen = Screen()
	screen:resize(100, 100)
	local container = screen.root:add(StackContainer({
		layout_transition = {duration = 1, easing = "Linear"},
	}))
	container:anchorFill(0, 0, 0, 0)
	local child = container:add(View())
	screen:flush()

	container:remove(child)
	screen:flush()
	container:setPadding({20, 0, 0, 0})
	container:add(child)
	screen:flush()

	t:eq(child.x, 20)
	t:eq(child:getWorldPosition(), 20)
	t:eq(child:hasTransforms(), false)
end

return test
