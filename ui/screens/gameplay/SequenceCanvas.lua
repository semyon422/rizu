local View = require("gui.View")
local Painter = require("gui.Painter")

local lg = love.graphics

---@class ui.screens.gameplay.SequenceCanvas : gui.View
---@operator call: ui.screens.gameplay.SequenceCanvas
---@field sequence_view sphere.SequenceView
---@field canvas love.Canvas?
---@field playing boolean
local SequenceCanvas = View + {}

-- SequenceView is a legacy renderer that treats the window dimensions as its
-- viewport. Keep that behavior local while rendering it into this view's canvas.
local viewport_width = 0
local viewport_height = 0
local base_get_width = lg.getWidth
local base_get_height = lg.getHeight
local base_get_dimensions = lg.getDimensions

---@return number
local function getViewportWidth()
	return viewport_width
end

---@return number
local function getViewportHeight()
	return viewport_height
end

---@return number width
---@return number height
local function getViewportDimensions()
	return viewport_width, viewport_height
end

local function pushViewport()
	lg.getWidth = getViewportWidth
	lg.getHeight = getViewportHeight
	lg.getDimensions = getViewportDimensions
end

local function popViewport()
	lg.getWidth = base_get_width
	lg.getHeight = base_get_height
	lg.getDimensions = base_get_dimensions
end

---@param sequence_view sphere.SequenceView
function SequenceCanvas:new(sequence_view)
	View.new(self)
	self.sequence_view = sequence_view
	self.playing = false
end

function SequenceCanvas:unload()
	if self.canvas then
		self.canvas:release()
		self.canvas = nil
	end
end

---@param _old_x number
---@param _old_y number
---@param _old_width number
---@param _old_height number
function SequenceCanvas:onLayoutChanged(_old_x, _old_y, _old_width, _old_height)
	local width = math.max(1, math.floor(self.width))
	local height = math.max(1, math.floor(self.height))
	if self.canvas then
		local old_width, old_height = self.canvas:getDimensions()
		if old_width == width and old_height == height then
			return
		end
		self.canvas:release()
	end
	self.canvas = lg.newCanvas(width, height)
end

---@param dt number
function SequenceCanvas:update(dt)
	if not self.playing or not self.canvas then
		return
	end
	viewport_width, viewport_height = self.canvas:getDimensions()
	pushViewport()
	self.sequence_view:update(dt)
	popViewport()
end

function SequenceCanvas:draw()
	local canvas = self.canvas
	if not canvas then
		return
	end

	viewport_width, viewport_height = canvas:getDimensions()
	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear()
	lg.origin()
	Painter.begin(1)
	pushViewport()
	self.sequence_view:draw()
	popViewport()
	lg.pop()

	lg.setColor(1, 1, 1, self.render_opacity)
	lg.draw(canvas)
end

---@param event table
function SequenceCanvas:receive(event)
	self.sequence_view:receive(event)
end

return SequenceCanvas
