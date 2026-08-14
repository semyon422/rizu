local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

local WIDTH = 420
local HEIGHT = 72
local PADDING = 12

---@class ui.views.CacheProgressView : gui.View
---@operator call: ui.views.CacheProgressView
---@field library rizu.library.Library
---@field font love.Font
---@field status rizu.library.TaskStatus
local CacheProgressView = View + {}

---@param library rizu.library.Library
function CacheProgressView:new(library)
	View.new(self)
	self.library = library
	self.font = Resources.getFont("regular", 20)
	self.status = library.status
	self:setSize(WIDTH, HEIGHT)
	self:setVisible(self.status.stage ~= "idle")
	library.onStatusChanged:add(self)
end

function CacheProgressView:unload()
	self.library.onStatusChanged:remove(self)
end

---@param status rizu.library.TaskStatus
function CacheProgressView:receive(status)
	self.status = status
	self:setVisible(status.stage ~= "idle")
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

	if status.itemsPerSecond then
		progress = progress .. ("  %.1f/s"):format(status.itemsPerSecond)
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
	love.graphics.print("Updating cache: " .. self.status.stage, PADDING, PADDING)
	Painter.setColorTable(Colors.text_muted)
	love.graphics.print(self:getProgressText(), PADDING, PADDING + self.font:getHeight())
end

return CacheProgressView
