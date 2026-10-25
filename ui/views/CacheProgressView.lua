local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

local WIDTH = 420
local HEIGHT = 72
local PADDING = 12

---@class ui.views.CacheProgressView : gui.View
---@operator call: ui.views.CacheProgressView
---@field library rizu.api.Library
---@field font love.Font
---@field status rizu.api.CacheStatus
---@field private unsubscribe fun()
local CacheProgressView = View + {}

---@param library rizu.api.Library
function CacheProgressView:new(library)
	View.new(self)
	self.library = library
	self.font = Resources.getFont("regular", 20)
	self.status = library:getCacheStatus()
	self:setSize(WIDTH, HEIGHT)
	self:setVisible(self.status.stage ~= "idle")
	self.unsubscribe = library:on("cache_status_changed", function(status)
		self.status = status
		self:setVisible(status.stage ~= "idle")
	end)
end

function CacheProgressView:unload()
	self.unsubscribe()
end

---@param seconds number
---@return string
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds >= 60 then
		return ("%dm %02ds"):format(math.floor(seconds / 60), seconds % 60)
	end
	return ("%ds"):format(seconds)
end

---@return string
function CacheProgressView:getProgressText()
	local status = self.status
	local progress
	if status.total > 0 then
		local percent = math.min(status.current / status.total * 100, 100)
		progress = ("%d / %d (%.1f%%)"):format(status.current, status.total, percent)
	else
		progress = ("%d items"):format(status.current)
	end

	if status.items_per_second then
		progress = progress .. ("  %.1f/s"):format(status.items_per_second)
	end
	if status.eta then
		progress = progress .. "  ETA " .. formatTime(status.eta)
	end
	return progress
end

function CacheProgressView:draw()
	Painter.setColorRgb(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	local stage = self.status.stage
	love.graphics.print(stage == "accuracies" and "Updating score accuracies" or "Updating cache: " .. stage, PADDING, PADDING)
	Painter.setColorTable(Colors.muted)
	love.graphics.print(self:getProgressText(), PADDING, PADDING + self.font:getHeight())
end

return CacheProgressView
