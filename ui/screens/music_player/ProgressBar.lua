local View = require("gui.View")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")

local lg = love.graphics

---@param seconds number
---@return string
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

---@class ui.screens.music_player.ProgressBar : gui.View
---@operator call: ui.screens.music_player.ProgressBar
---@field preview_model rizu.preview.PreviewModel
---@field font love.Font
local ProgressBar = View + {}

---@param preview_model rizu.preview.PreviewModel
function ProgressBar:new(preview_model)
	View.new(self)
	self.preview_model = preview_model
	self.handles_mouse_input = true
end

function ProgressBar:load()
	self.font = Resources.getFont("regular", 20)
end

---@param screen_x number
---@param screen_y number
function ProgressBar:seekAt(screen_x, screen_y)
	local x = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	self.preview_model:setRelativePosition(math.max(0, math.min(x / self.width, 1)))
end

---@param event gui.MouseDownEvent
function ProgressBar:onMouseDown(event)
	if event.button ~= 1 then
		return
	end
	self:seekAt(event.x, event.y)
	return true
end

---@param event gui.DragStartEvent
function ProgressBar:onDragStart(event)
	self:seekAt(event.x, event.y)
	return true
end

---@param event gui.DragEvent
function ProgressBar:onDrag(event)
	self:seekAt(event.x, event.y)
	return true
end

function ProgressBar:draw()
	local progress = self.preview_model:getRelativePosition()
	local min_time, max_time = self.preview_model:getRange()
	local position = math.max(self.preview_model:getTime() - min_time, 0)
	local duration = math.max(max_time - min_time, 0)
	local track_y = 10

	Painter.setColorTable(Colors.elements)
	lg.rectangle("fill", 0, track_y, self.width, 12, 6, 6)
	Painter.setColorTable(Colors.accent2)
	lg.rectangle("fill", 0, track_y, self.width * progress, 12, 6, 6)

	Painter.setColorTable(Colors.text)
	lg.setFont(self.font)
	lg.print(formatTime(position), 0, 34)
	local duration_text = formatTime(duration)
	lg.print(duration_text, self.width - self.font:getWidth(duration_text), 34)
end

return ProgressBar
