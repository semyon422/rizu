local coloredRect = require("ui.test.ColoredRect")

---@alias ui.test.NineAnchorSpec {anchor: {[1]: number, [2]: number}, color: {[1]: number, [2]: number, [3]: number}}

---@type ui.test.NineAnchorSpec[]
local nine = {
	{anchor = {0, 0}, color = {0.95, 0.40, 0.30}},
	{anchor = {0.5, 0}, color = {0.95, 0.75, 0.30}},
	{anchor = {1, 0}, color = {0.85, 0.95, 0.30}},
	{anchor = {0, 0.5}, color = {0.30, 0.95, 0.45}},
	{anchor = {0.5, 0.5}, color = {0.30, 0.85, 0.95}},
	{anchor = {1, 0.5}, color = {0.45, 0.55, 0.95}},
	{anchor = {0, 1}, color = {0.55, 0.30, 0.95}},
	{anchor = {0.5, 1}, color = {0.85, 0.30, 0.95}},
	{anchor = {1, 1}, color = {0.95, 0.30, 0.65}},
}

---@type ui.test.TestCase
local case = {
	name = "nine anchors",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg:anchorFill(0, 0, 0, 0)
		root:add(bg)

		for _, spec in ipairs(nine) do
			local rect = coloredRect(spec.color[1], spec.color[2], spec.color[3])
			rect:setSize(100, 100):setAlignment(spec.anchor[1], spec.anchor[2])
			root:add(rect)
		end
	end,
}

return case
