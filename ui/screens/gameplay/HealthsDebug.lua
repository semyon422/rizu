local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")

local WIDTH = 320
local HEIGHT = 140
local PADDING = 10
local HISTORY = 200
local GRAPH_Y = 34

---Debug: the value of the selected healths source and how it went over the last events.
---@class ui.screens.gameplay.HealthsDebug : gui.View
---@operator call: ui.screens.gameplay.HealthsDebug
---@field gameplay rizu.api.Gameplay
---@field font love.Font
---@field history number[]
local HealthsDebug = View + {}

---@param gameplay rizu.api.Gameplay
function HealthsDebug:new(gameplay)
	View.new(self)
	self.gameplay = gameplay
	self.font = Resources.getFont("regular", 16)
	self.history = {}
	self:setSize(WIDTH, HEIGHT)
	self:setAlignment(1, 0)
	self:setPosition(-16, 16)
end

function HealthsDebug:update()
	if self.visible then
		self.history = self.gameplay:getHealthsHistory(HISTORY)
	end
end

function HealthsDebug:draw()
	Painter.setColorRgb(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

	local healths, max_healths, failed, key = self.gameplay:getHealths()
	---@cast max_healths number
	love.graphics.setFont(self.font)
	if not healths then
		Painter.setColorTable(Colors.muted)
		love.graphics.print("no healths source", PADDING, PADDING - 2)
		return
	end

	Painter.setColorTable(failed and Colors.accent or Colors.text)
	love.graphics.print(("%s  %.3f / %g  %s"):format(key, healths, max_healths, failed and "FAILED" or "alive"),
		PADDING, PADDING - 2)

	local left, right = PADDING, WIDTH - PADDING
	local top, bottom = GRAPH_Y, HEIGHT - PADDING
	Painter.setColorRgb(1, 1, 1, 0.16)
	love.graphics.rectangle("line", left, top, right - left, bottom - top)

	local history = self.history
	if #history > 1 then
		---@type number[]
		local points = {}
		for i, value in ipairs(history) do
			points[#points + 1] = left + (i - 1) / (HISTORY - 1) * (right - left)
			points[#points + 1] = bottom - math.min(math.max(value / max_healths, 0), 1) * (bottom - top)
		end
		Painter.setColorTable(Colors.accent)
		love.graphics.line(points)
	end
end

return HealthsDebug
