local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local ProgressBar = require("ui.screens.music_player.ProgressBar")

local lg = love.graphics

local THIN, THICK = 3, 8
local GROW_SPEED = 14

---The music strip's progress line along its bottom edge: thin, it grows while the mouse is anywhere on the strip and seeks on click and drag.
---@class ui.screens.main_menu_v2.StripProgress : ui.screens.music_player.ProgressBar
---@operator call: ui.screens.main_menu_v2.StripProgress
---@field grow number 0 thin, 1 thick
---@field expanded boolean? set while the mouse is over the whole strip
local StripProgress = ProgressBar + {}

StripProgress.HEIGHT = 14 -- the mouse target, taller than the thin line

---@param media rizu.api.Media
function StripProgress:new(media)
	ProgressBar.new(self, media)
	self.grow = 0
end

---@param dt number
function StripProgress:update(dt)
	local target = (self.expanded or self.mouse_over) and 1 or 0
	self.grow = self.grow + (target - self.grow) * (1 - math.exp(-GROW_SPEED * dt))
end

-- A click on the line seeks, it must not also open the music player under it.
---@param e gui.MouseClickEvent
function StripProgress:onMouseClick(e) return true end

function StripProgress:draw()
	local time, start, finish = self.media:getPreviewTime()
	local duration = math.max(finish - start, 0)
	local progress = duration > 0 and math.min(math.max(time - start, 0) / duration, 1) or 0
	local height = THIN + (THICK - THIN) * self.grow
	local y = self.height - height
	Painter.setColorTable(Colors.surface)
	lg.rectangle("fill", 0, y, self.width, height)
	Painter.setColorTable(Colors.success)
	lg.rectangle("fill", 0, y, math.floor(self.width * progress), height)
end

return StripProgress
