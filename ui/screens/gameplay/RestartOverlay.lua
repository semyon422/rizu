local View = require("gui.View")
local Easing = require("gui.anim.Easing")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.RestartOverlay : gui.View
---@operator call: ui.screens.gameplay.RestartOverlay
---@field progress number
local RestartOverlay = View + {}

local ease = Easing.resolve("InOutQuad")
local BRIGHTNESS_ALPHA = 0.35

function RestartOverlay:new()
	View.new(self)
	self:anchorFill(0, 0, 0, 0)
	self:setVisible(false)
	self:setOpacity(0)
	self.progress = 0
	self.retracting = false
end

---@param progress number
function RestartOverlay:setProgress(progress)
	self.retracting = false
	local was_active = self.progress > 0
	self.progress = math.max(0, math.min(1, progress))
	local is_active = self.progress > 0
	if is_active and not was_active then
		self:clearTransforms("opacity")
		self:setOpacity(1)
		self:setVisible(true)
	elseif not is_active and was_active then
		self:setVisible(false)
	end
end

function RestartOverlay:cover()
	self.retracting = false
	self.progress = 1
	self:clearTransforms("opacity")
	self:setOpacity(1)
	self:setVisible(true)
end

---@param duration number
---@param on_complete fun()?
function RestartOverlay:retract()
	self.retracting = self.progress > 0
end

---@param dt number
function RestartOverlay:update(dt)
	if not self.retracting then
		return
	end
	self.progress = math.max(0, self.progress - 4 * dt)
	if self.progress == 0 then
		self.retracting = false
		self:setVisible(false)
	end
end

function RestartOverlay:reset()
	self:clearTransforms("opacity")
	self.retracting = false
	self.progress = 0
	self:setOpacity(0)
	self:setVisible(false)
end

function RestartOverlay:draw()
	local progress = ease(self.progress)
	local bar_height = self.height * 0.5 * progress

	Painter.setColorRgb(0, 0, 0)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, bar_height)
	Resources.sprites.pixel:draw(0, self.height - bar_height, 0, self.width, bar_height)

	local visible_height = self.height - bar_height * 2
	if visible_height > 0 then
		love.graphics.setBlendMode("add")

		Painter.setColorRgb(1, 1, 1, BRIGHTNESS_ALPHA * progress)
		Resources.sprites.pixel:draw(0, bar_height, 0, self.width, visible_height)

		love.graphics.setBlendMode("alpha")
	end
end

return RestartOverlay
