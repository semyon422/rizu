local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.chart_loading.LoadError: gui.View
---@operator call: ui.screens.chart_loading.LoadError
local LoadError = View + {}

function LoadError:new()
	View.new(self)
	self.message = ""
	self.font = Resources.getFont("regular", 24)
end

---@param message string
function LoadError:setMessage(message)
	self.message = message:match("Aim prototype[^\n]*") or message:match("[^\n]+") or message
end

function LoadError:draw()
	love.graphics.setFont(self.font)
	Painter.setColorRgb(1, 0.8, 0.7)
	local width = math.max(1, self.width - 64)
	local _, lines = self.font:getWrap(self.message .. "\n\nEscape: back", width)
	love.graphics.printf(self.message .. "\n\nEscape: back", 32,
		math.max(32, (self.height - #lines * self.font:getHeight()) / 2), width, "center")
end

return LoadError
