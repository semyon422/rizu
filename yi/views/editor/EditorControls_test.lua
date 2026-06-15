local EditorControls = require("yi.views.editor.EditorControls")

local test = {}

local function withLove(f)
	local oldLove = love
	love = {
		graphics = {
			transformPoint = function(x, y)
				return x, y
			end,
		},
		mouse = {
			getPosition = function()
				return 15, 15
			end,
		},
	}
	local ok, err = xpcall(f, debug.traceback)
	love = oldLove
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.hit_testing_uses_last_registered_control_on_top(t)
	withLove(function()
		local controls = EditorControls()
		controls:register("back", "button", 0, 0, 50, 50)
		controls:register("front", "button", 10, 10, 50, 50)

		t:eq(controls:getControlAt(20, 20).id, "front")
		t:eq(controls:containsPoint(80, 80), false)
		t:eq(controls:isMouseOver("front"), true)
	end)
end

---@param t testing.T
function test.click_and_slider_drag_are_frame_latched(t)
	withLove(function()
		local controls = EditorControls()
		controls:register("slider", "slider", 0, 0, 100, 20)

		t:eq(controls:beginPress({x = 25, y = 10}).id, "slider")
		t:eq(controls.activeId, "slider")
		t:eq(controls.dragged.slider, 0.25)

		t:eq(controls:drag({x = 150, y = 10}), "slider")
		t:eq(controls.dragged.slider, 1)

		t:eq(controls:endPress({x = 50, y = 10}), "slider")
		t:eq(controls.clicked.slider, true)

		controls:finishFrame()
		t:eq(controls.clicked.slider, nil)
		t:eq(controls.dragged.slider, nil)
	end)
end

---@param t testing.T
function test.key_latch_and_input_focus(t)
	withLove(function()
		local controls = EditorControls()
		controls:register("name", "input", 0, 0, 100, 20)
		controls:beginPress({x = 10, y = 10})

		t:eq(controls.focusedId, "name")
		controls:onKeyDown({key = "space"})
		t:eq(controls:consumeKey("space"), true)
		t:eq(controls:consumeKey("space"), false)
	end)
end

return test
