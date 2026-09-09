local AimPlayfield = require("ui.screens.gameplay.AimPlayfield")
local test = {}

---@param t testing.T
function test.pointer_mapping_round_trips_across_sizes_and_ui_scales(t)
	for _, size in ipairs({{640, 480}, {1280, 720}, {900, 1200}}) do
		for _, ui_scale in ipairs({1, 1.5, 2}) do
			local view = setmetatable({
				width = size[1] / ui_scale, height = size[2] / ui_scale,
				world_transform = {inverseTransformPoint = function(_, x, y)
					return (x - 15) / ui_scale, (y - 20) / ui_scale
				end},
			}, {__index = AimPlayfield})
			local scale, ox, oy = view:getField()
			local x, y = view:toChart((ox + 123 * scale) * ui_scale + 15, (oy + 321 * scale) * ui_scale + 20)
			t:aeq(x, 123, 1e-9)
			t:aeq(y, 321, 1e-9)
		end
	end
end

return test
