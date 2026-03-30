local Layer = require("ui.Layer")
local Colors = require("yi.Colors")
local UIFactory = require("yi.UIFactory")

---@class yi.Welcome : ui.Layer
---@operator call: yi.Welcome
local Welcome = Layer + {}

---@param ctx yi.Context
function Welcome:new(ctx)
	Layer.new(self)
	local ui = UIFactory(ctx.resources)

	self:addArray({
		ui:Rectangle({
			width_percent = 1,
			height_percent = 1
		}),
		ui:Image({
			image = "rizu",
			anchor = {0.5, 0.5},
			origin = {0.5, 0.5},
			scale_x = 0.8,
			scale_y = 0.8
		}),
		ui:Label({
			anchor = {0.5, 1},
			origin = {0.5, 1},
			color = Colors.black,
			font = "regular",
			font_size = 24,
			text = "Press any key to continue",
			y = -20
		}),
	})
end

return Welcome
