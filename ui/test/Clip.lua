local View = require("gui.View")
local coloredRect = require("ui.test.ColoredRect")

local VIEWPORT_WIDTH = 500
local VIEWPORT_HEIGHT = 300

---@type {time: number, moving: gui.View?}
local state = {time = 0, moving = nil}

---@type ui.test.TestCase
local case = {
	name = "clip",
	build = function(root)
		state.time = 0
		state.moving = nil

		root:add(coloredRect(0.08, 0.08, 0.1)):anchorFill(0, 0, 0, 0)

		local viewport = coloredRect(0.12, 0.14, 0.18)
		viewport:setSize(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
		viewport:setAlignment(0.5, 0.5)
		viewport.clip = true
		root:add(viewport)

		local moving = coloredRect(0.2, 0.65, 0.95)
		moving:anchorFixed(160, 60, 180, 180)
		viewport:add(moving)

		local inner = coloredRect(0.95, 0.35, 0.45)
		inner:anchorFixed(45, 45, 180, 90)
		moving:add(inner)

		local outline = View()
		outline:setSize(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
		outline:setAlignment(0.5, 0.5)
		function outline:draw()
			love.graphics.setColor(0.8, 0.85, 0.95, self.effective_opacity)
			love.graphics.setLineWidth(4)
			love.graphics.rectangle("line", 0, 0, self.width, self.height)
		end
		root:add(outline)

		state.moving = moving
	end,
	update = function(_, dt)
		local moving = state.moving
		if not moving or not moving.parent then
			return
		end
		state.time = state.time + dt
		moving:setOffset(math.sin(state.time * 1.5) * 330, 0)
	end,
}

return case
