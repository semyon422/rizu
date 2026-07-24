local Screen = require("gui.Screen")
local View = require("gui.View")
local StackContainer = require("gui.layout.StackContainer")

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

return test
