local coloredRect = require("ui.test.ColoredRect")

---@alias ui.test.NineAnchorSpec {anchor: {[1]: number, [2]: number}, off_min: {[1]: number, [2]: number}, off_max: {[1]: number, [2]: number}, color: {[1]: number, [2]: number, [3]: number}}

---@type ui.test.NineAnchorSpec[]
local nine = {
	{anchor = {0, 0}, off_min = {0, 0}, off_max = {100, 100}, color = {0.95, 0.40, 0.30}},
	{anchor = {0.5, 0}, off_min = {-50, 0}, off_max = {50, 100}, color = {0.95, 0.75, 0.30}},
	{anchor = {1, 0}, off_min = {-100, 0}, off_max = {0, 100}, color = {0.85, 0.95, 0.30}},
	{anchor = {0, 0.5}, off_min = {0, -50}, off_max = {100, 50}, color = {0.30, 0.95, 0.45}},
	{anchor = {0.5, 0.5}, off_min = {-50, -50}, off_max = {50, 50}, color = {0.30, 0.85, 0.95}},
	{anchor = {1, 0.5}, off_min = {-100, -50}, off_max = {0, 50}, color = {0.45, 0.55, 0.95}},
	{anchor = {0, 1}, off_min = {0, -100}, off_max = {100, 0}, color = {0.55, 0.30, 0.95}},
	{anchor = {0.5, 1}, off_min = {-50, -100}, off_max = {50, 0}, color = {0.85, 0.30, 0.95}},
	{anchor = {1, 1}, off_min = {-100, -100}, off_max = {0, 0}, color = {0.95, 0.30, 0.65}},
}

---@type ui.test.TestCase
local case = {
	-- TODO(§2.2): replace this manual signed-offset math with
	-- view:setSize(100, 100) + view:setAlignment(ax, ay) once the
	-- placement sugar lands. The negative offsets for the (1,*) and
	-- (*,1) anchors are exactly what setAlignment hides.
	name = "nine anchors",
	build = function(root)
		local bg = coloredRect(0.08, 0.08, 0.1)
		bg.anchor_max = {1, 1}
		root:add(bg)

		for _, spec in ipairs(nine) do
			local rect = coloredRect(spec.color[1], spec.color[2], spec.color[3])
			rect.anchor_min = {spec.anchor[1], spec.anchor[2]}
			rect.anchor_max = {spec.anchor[1], spec.anchor[2]}
			rect.offset_min = {spec.off_min[1], spec.off_min[2]}
			rect.offset_max = {spec.off_max[1], spec.off_max[2]}
			root:add(rect)
		end
	end,
}

return case
