local View = require("gui.View")
local Flex = require("gui.layout.Flex")
local coloredRect = require("ui.test.ColoredRect")

---@type ui.test.TestCase
local case = {
	name = "flex list",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg.anchor_max = {1, 1}
		root:add(bg)

		local outer = View()
		outer.anchor_max = {1, 1}
		outer.offset_min = {40, 40}
		outer.offset_max = {-40, -40}
		outer.arrange_strategy = Flex({
			direction = "column",
			gap = 8,
			sizes = {80, "*", 60},
		})
		root:add(outer)

		local header = coloredRect(0.30, 0.40, 0.55)
		outer:add(header)

		local list = View()
		list.arrange_strategy = Flex({
			direction = "column",
			gap = 4,
			sizes = {"*", "*", "*", "*", "*", "*"},
		})
		outer:add(list)

		local palette = {
			{0.95, 0.40, 0.30},
			{0.95, 0.75, 0.30},
			{0.30, 0.85, 0.45},
			{0.30, 0.65, 0.95},
			{0.55, 0.40, 0.95},
			{0.95, 0.45, 0.70},
		}
		for i = 1, 6 do
			local row = View()
			row.arrange_strategy = Flex({
				direction = "row",
				gap = 6,
				sizes = {120, "*", 80},
				align_items = "center",
			})
			list:add(row)

			local label_box = coloredRect(palette[i][1] * 0.6, palette[i][2] * 0.6, palette[i][3] * 0.6)
			label_box.offset_max = {0, 40}
			row:add(label_box)

			local value_box = coloredRect(palette[i][1], palette[i][2], palette[i][3])
			value_box.offset_max = {0, 60}
			row:add(value_box)

			local chevron = coloredRect(0.7, 0.7, 0.75)
			chevron.offset_max = {0, 30}
			row:add(chevron)
		end

		local footer = coloredRect(0.20, 0.20, 0.25)
		outer:add(footer)
	end,
}

return case
