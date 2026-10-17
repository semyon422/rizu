local coloredRect = require("ui.test.ColoredRect")

local RADIUS = 150
local CONTAINER_SIZE = 200

---@type {angle: number, container: gui.View?}
local state = {angle = 0, container = nil}

---@type ui.test.TestCase
local case = {
	name = "orbit offset transform",
	build = function(root)
		state.angle = 0
		state.container = nil

		local bg = coloredRect(0.08, 0.08, 0.1)
		bg:anchorFill(0, 0, 0, 0)
		root:add(bg)

		local marker = coloredRect(0.4, 0.4, 0.45)
		marker:setSize(8, 8):setAlignment(0.5, 0.5)
		root:add(marker)

		local container = coloredRect(0.95, 0.7, 0.2)
		container:setSize(CONTAINER_SIZE, CONTAINER_SIZE):setAlignment(0.5, 0.5)
		root:add(container)

		local child = coloredRect(0.3, 0.4, 0.95)
		child:anchorFill(20, 20, 20, 20)
		container:add(child)

		state.container = container
	end,
	update = function(screen, dt)
		local container = state.container
		if not container or container.parent ~= screen.root then
			return
		end
		state.angle = state.angle + dt
		container.offset_x = math.cos(state.angle) * RADIUS
		container.offset_y = math.sin(state.angle) * RADIUS
		screen:relayout()
	end,
}

return case
