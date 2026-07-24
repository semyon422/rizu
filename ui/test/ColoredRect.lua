local Painter = require("gui.Painter")
local View = require("gui.View")

---@param r number
---@param g number
---@param b number
---@param a number?
---@return gui.View
local function coloredRect(r, g, b, a)
	local view = View()
	view.color = {r, g, b, a == nil and 1 or a}
	function view:draw()
		Painter.setColorTable(self.color)
		love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	end
	return view
end

return coloredRect
