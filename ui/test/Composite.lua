local CompositeView = require("gui.CompositeView")
local coloredRect = require("ui.test.ColoredRect")

local PANEL_WIDTH = 700
local PANEL_HEIGHT = 360
local MOVING_WIDTH = 180

---@type {time: number, composite: gui.CompositeView?, moving: gui.View?}
local state = {time = 0, composite = nil, moving = nil}

---@type ui.test.TestCase
local case = {
	name = "composite opacity",
	build = function(root)
		state.time = 0
		state.composite = nil
		state.moving = nil

		root:add(coloredRect(0.08, 0.08, 0.1)):anchorFill(0, 0, 0, 0)

		local composite = CompositeView()
		composite:setSize(PANEL_WIDTH, PANEL_HEIGHT)
		composite:setAlignment(0.5, 0.5)
		root:add(composite)

		-- This rectangle moves behind the fixed middle rectangle. Group opacity
		-- must not make it visible through the opaque rectangle in front of it.
		local moving = coloredRect(0.2, 0.65, 0.95)
		moving:anchorFixed(0, 90, MOVING_WIDTH, 180)
		composite:add(moving)

		local middle = coloredRect(0.95, 0.35, 0.45)
		middle:anchorFixed(250, 55, 200, 250)
		composite:add(middle)

		state.composite = composite
		state.moving = moving
	end,
	update = function(_, dt)
		local composite = state.composite
		local moving = state.moving
		if not composite or not composite.parent or not moving then
			return
		end

		state.time = state.time + dt
		local progress = (math.sin(state.time * 1.2) + 1) * 0.5
		moving:setOffset(progress * (PANEL_WIDTH - MOVING_WIDTH), 0)
		composite:setOpacity(0.15 + (math.sin(state.time * 0.7) + 1) * 0.425)
	end,
}

return case
