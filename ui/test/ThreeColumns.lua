local coloredRect = require("ui.test.ColoredRect")

---@type ui.test.TestCase
local case = {
	name = "three columns",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg:anchorFill(0, 0, 0, 0)
		root:add(bg)

		local palette = {
			{0.95, 0.4, 0.3},
			{0.3, 0.8, 0.4},
			{0.3, 0.5, 0.95},
		}
		for i = 1, 3 do
			local r, g, b = palette[i][1], palette[i][2], palette[i][3]
			local col = coloredRect(r, g, b)
			col:anchorPercent((i - 1) / 3, 0, i / 3, 1)
			root:add(col)

			local inner = coloredRect(0.95, 0.92, 0.95)
			inner:anchorFill(20, 20, 20, 20)
			col:add(inner)
		end
	end,
}

return case
