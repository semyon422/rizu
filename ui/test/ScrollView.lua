local FlowContainer = require("gui.layout.FlowContainer")
local Painter = require("gui.Painter")
local ScrollView = require("gui.ScrollView")
local View = require("gui.View")
local coloredRect = require("ui.test.ColoredRect")

local VIEWPORT_WIDTH = 520
local VIEWPORT_HEIGHT = 420
local ROW_HEIGHT = 84
local ROW_GAP = 12

---@type ui.test.TestCase
local case = {
	name = "scroll view",
	build = function(root)
		root:add(coloredRect(0.06, 0.07, 0.09)):anchorFill(0, 0, 0, 0)

		local content = FlowContainer({
			direction = "column",
			gap = ROW_GAP,
		})
		for i = 1, 14 do
			local hue = (i - 1) / 14
			local row = coloredRect(
				0.25 + 0.45 * math.abs(math.sin(hue * math.pi)),
				0.25 + 0.45 * math.abs(math.sin((hue + 0.33) * math.pi)),
				0.25 + 0.45 * math.abs(math.sin((hue + 0.66) * math.pi))
			)
			row:setSize(VIEWPORT_WIDTH, ROW_HEIGHT)
			content:add(row)
		end
		content:fitContent()

		local scroll_view = ScrollView(content)
		scroll_view:setSize(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
		scroll_view:setAlignment(0.5, 0.5)
		root:add(scroll_view)

		local outline = View()
		outline:setSize(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
		outline:setAlignment(0.5, 0.5)
		function outline:draw()
			Painter.setColorRgb(0.9, 0.92, 1)
			love.graphics.setLineWidth(4)
			love.graphics.rectangle("line", 0, 0, self.width, self.height)
		end
		root:add(outline)
	end,
}

return case
