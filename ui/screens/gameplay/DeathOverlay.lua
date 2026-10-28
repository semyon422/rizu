local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.DeathOverlay : gui.View
---@operator call: ui.screens.gameplay.DeathOverlay
---@field time number? Seconds since the death, nil while alive
local DeathOverlay = View + {}

local RAMP_DURATION = 0.08
local FLASH_DURATION = 0.7
local REVEAL_DELAY = 0.2
local REVEAL_DURATION = 0.5
local FADE_DURATION = 2
local FLASH_ALPHA = 0.7
local AFTER_FLASH_ALPHA = 0.3
local LINGER_ALPHA = 0.18

function DeathOverlay:new()
	View.new(self)
	self:anchorFill(0, 0, 0, 0)
	self:setVisible(false)
end

---Starts the animation unless it already runs.
function DeathOverlay:start()
	if self.time then return end
	self.time = 0
	self:setVisible(true)
end

function DeathOverlay:reset()
	self.time = nil
	self:setVisible(false)
end

---How far the fail overlay has faded in. It starts shortly after the death.
---@return number
function DeathOverlay:getRevealProgress()
	return self.time and math.max(0, math.min((self.time - REVEAL_DELAY) / REVEAL_DURATION, 1)) or 0
end

---@param dt number
function DeathOverlay:update(dt)
	if self.time then
		self.time = self.time + dt
	end
end

function DeathOverlay:draw()
	local time = self.time
	if not time then return end
	local alpha = 0
	if time < RAMP_DURATION then
		alpha = FLASH_ALPHA * time / RAMP_DURATION
	elseif time < FLASH_DURATION then
		local decay = (time - RAMP_DURATION) / (FLASH_DURATION - RAMP_DURATION)
		alpha = FLASH_ALPHA + (AFTER_FLASH_ALPHA - FLASH_ALPHA) * decay
	else
		local fade = math.min((time - FLASH_DURATION) / FADE_DURATION, 1)
		alpha = LINGER_ALPHA + (AFTER_FLASH_ALPHA - LINGER_ALPHA) * (1 - fade)
	end
	Painter.setColorRgb(1, 0, 0, alpha)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
end

return DeathOverlay
