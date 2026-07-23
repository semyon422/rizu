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
		bg.anchor_max = {1, 1}
		root:add(bg)

		local marker = coloredRect(0.4, 0.4, 0.45)
		marker.anchor_min = {0.5, 0.5}
		marker.anchor_max = {0.5, 0.5}
		marker.offset_min = {-4, -4}
		marker.offset_max = {4, 4}
		root:add(marker)

		local container = coloredRect(0.95, 0.7, 0.2)
		container.anchor_min = {0.5, 0.5}
		container.anchor_max = {0.5, 0.5}
		container.offset_min = {-CONTAINER_SIZE / 2, -CONTAINER_SIZE / 2}
		container.offset_max = {CONTAINER_SIZE / 2, CONTAINER_SIZE / 2}
		root:add(container)

		local child = coloredRect(0.3, 0.4, 0.95)
		child.anchor_max = {1, 1}
		child.offset_min = {20, 20}
		child.offset_max = {-20, -20}
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
