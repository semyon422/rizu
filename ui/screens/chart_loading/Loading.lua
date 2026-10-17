local View = require("gui.View")
local Resources = require("ui.Resources")

---@class ui.screens.chart_loading.Loading : gui.View
---@operator call: ui.screens.chart_loading.Loading
---@field scale number
local Loading = View + {}

local DEFAULT_SCALE = 0.5

---@param scale number?
function Loading:new(scale)
	View.new(self)
	self.sprite = Resources.sprites.loading
	self.scale = scale or DEFAULT_SCALE
	local width, height = self.sprite:getDimensions()
	self:setSize(width * self.scale, height * self.scale)
end

function Loading:draw()
	local width, height = self.sprite:getDimensions()
	self.sprite:draw(
		self.width / 2,
		self.height / 2,
		love.timer.getTime(),
		self.scale,
		self.scale,
		width / 2,
		height / 2
	)
end

return Loading
