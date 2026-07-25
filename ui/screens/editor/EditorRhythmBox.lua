local View = require("gui.View")
local gfx_util = require("gfx_util")

local lg = love.graphics

---@class ui.screens.editor.EditorRhythmBox : gui.View
---@operator call: ui.screens.editor.EditorRhythmBox
---@field game sphere.GameController
---@field rhythm_view ui.screens.editor.EditorRhythmView?
---@field canvas love.Canvas?
local EditorRhythmBox = View + {}

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

---@param game sphere.GameController
function EditorRhythmBox:new(game)
	View.new(self)
	self.game = game
	self:setSize(640, 900)
	self:setAlignment(0.5, 0.5)
	self:setPivot(0.5, 0.5)
end

---@param rhythm_view ui.screens.editor.EditorRhythmView
function EditorRhythmBox:bind(rhythm_view)
	self.rhythm_view = rhythm_view
	if rhythm_view.load then
		rhythm_view:load()
	end
end

function EditorRhythmBox:unbind()
	local rhythmView = self.rhythm_view
	if rhythmView and rhythmView.unload then
		rhythmView:unload()
	end
	self.rhythm_view = nil
end

function EditorRhythmBox:unload()
	self:unbind()
	if self.canvas then
		self.canvas:release()
		self.canvas = nil
	end
end

---@param _old_x number
---@param _old_y number
---@param _old_width number
---@param _old_height number
function EditorRhythmBox:onLayoutChanged(_old_x, _old_y, _old_width, _old_height)
	local width = math.max(1, math.floor(self.width))
	local height = math.max(1, math.floor(self.height))
	if self.canvas then
		local oldWidth, oldHeight = self.canvas:getDimensions()
		if oldWidth == width and oldHeight == height then
			return
		end
		self.canvas:release()
	end
	self.canvas = lg.newCanvas(width, height)
end

---@param dt number
function EditorRhythmBox:update(dt)
	local rhythmView = self.rhythm_view
	if not rhythmView then
		return
	end

	viewport_width, viewport_height = self.canvas:getDimensions()
	lg.push("all")
	pushViewport()
	lg.replaceTransform(gfx_util.transform(rhythmView.transform))
	self.game.editorModel:update()
	popViewport()
	lg.pop()
end

function EditorRhythmBox:draw()
	local rhythmView = self.rhythm_view
	local canvas = self.canvas
	if not rhythmView or not canvas then
		return
	end

	viewport_width, viewport_height = canvas:getDimensions()
	lg.push("all")
	lg.setCanvas(canvas)
	lg.clear(0.035, 0.04, 0.055, 1)
	lg.origin()
	pushViewport()
	rhythmView:draw()
	popViewport()
	lg.pop()

	lg.setColor(1, 1, 1, 1)
	lg.draw(canvas)
end

return EditorRhythmBox
