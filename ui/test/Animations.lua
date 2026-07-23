local coloredRect = require("ui.test.ColoredRect")

---@type ui.test.TestCase
local case = {
	name = "animations",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg.anchor_max = {1, 1}
		root:add(bg)

		local fade = coloredRect(0.95, 0.35, 0.45)
		fade.offset_min = {120, 160}
		fade.offset_max = {240, 280}
		fade:setOpacity(0):fadeIn(1)
		root:add(fade)

		local move = coloredRect(0.25, 0.65, 0.95)
		move.offset_min = {340, 160}
		move.offset_max = {460, 280}
		move:setOffset(-100, 0):moveTo(0, 0, 1, "OutQuint")
		root:add(move)

		local scale = coloredRect(0.35, 0.85, 0.5)
		scale.offset_min = {560, 160}
		scale.offset_max = {680, 280}
		scale:setPivot(0.5, 0.5):setScale(0.1, 0.1):scaleTo(1, 1, 1, "OutBack")
		root:add(scale)

		local rotate = coloredRect(0.95, 0.7, 0.25)
		rotate.offset_min = {230, 380}
		rotate.offset_max = {350, 500}
		rotate:setPivot(0.5, 0.5):setRotation(-math.pi):rotateTo(0, 1, "OutQuint")
		root:add(rotate)

		local delayed = coloredRect(0.7, 0.45, 0.95)
		delayed.offset_min = {500, 380}
		delayed.offset_max = {620, 500}
		delayed:setOpacity(0):setOffset(0, 80)
		delayed:delay(0.5):fadeIn(0.7):moveTo(0, 0, 0.7, "OutQuint")
		root:add(delayed)
	end,
}

return case
