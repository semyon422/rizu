local Flex = require("gui.layout.Flex")
local coloredRect = require("ui.test.ColoredRect")

---@type {elapsed: number, shifted: boolean, container: gui.View?, strategy: gui.layout.Flex?}
local state = {elapsed = 0, shifted = false, container = nil, strategy = nil}

---@type ui.test.TestCase
local case = {
	name = "layout transitions",
	build = function(root)
		state.elapsed = 0
		state.shifted = false

		local bg = coloredRect(0.08, 0.08, 0.1)
		bg.anchor_max = {1, 1}
		root:add(bg)

		local strategy = Flex({
			direction = "row",
			gap = 20,
			padding = 80,
			sizes = {"*", "*", "*"},
			align_items = "center",
			layout_transition = {duration = 0.6, easing = "OutQuint"},
		})
		local container = root:add(coloredRect(0.13, 0.13, 0.17))
		container.anchor_max = {1, 1}
		container.offset_min = {80, 100}
		container.offset_max = {-80, -100}
		container.arrange_strategy = strategy

		local colors = {
			{0.95, 0.35, 0.45},
			{0.25, 0.65, 0.95},
			{0.35, 0.85, 0.5},
		}
		for i = 1, 3 do
			local child = coloredRect(colors[i][1], colors[i][2], colors[i][3])
			child.offset_max = {0, 140}
			container:add(child)
		end

		state.container = container
		state.strategy = strategy
	end,
	update = function(_, dt)
		local container = state.container
		local strategy = state.strategy
		if not container or not strategy or not container.parent then return end

		state.elapsed = state.elapsed + dt
		if state.elapsed >= 1.5 then
			state.elapsed = state.elapsed - 1.5
			state.shifted = not state.shifted
			strategy.padding = state.shifted and {220, 40, 40, 160} or {40, 160, 220, 40}
			container:invalidate()
		end
	end,
}

return case
