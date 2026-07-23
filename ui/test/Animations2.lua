local Button = require("ui.views.Button")
local coloredRect = require("ui.test.ColoredRect")
local Flex = require("gui.layout.Flex")

local n1
local next_t = 0

local case = {
	name = "animations2",
	build = function(root)
		local b = Button()
		root:add(b)

		n1 = coloredRect(1, 1, 1, 1)
		n1.anchor_max = {1, 0}
		n1.offset_max = {0, 200}
		n1.arrange_strategy = Flex({
			padding = 24,
			gap = 24,
			layout_transition = {
				duration = 0.5,
				easing = "OutElastic"
			}
		})

		root:add(n1)
	end,

	update = function()
		local t = love.timer.getTime()

		if t > next_t then
			next_t = t + 2
			local c = coloredRect(0, 0, 0, 1)
			c:setOpacity(0)
			c:fadeTo(1, 0.3, "OutSine")
			n1:add(c)
		end
	end
}

return case
