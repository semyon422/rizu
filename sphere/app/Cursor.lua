local class = require("class")

---@class sphere.Cursor
local Cursor = class()

function Cursor:createCursors()
	self:createCircle()
	self:createArrow()
end

---@param name string
function Cursor:setCursor(name)
	if name == "circle" then
		love.mouse.setCursor(self.circleCursor)
	elseif name == "arrow" then
		love.mouse.setCursor(self.arrowCursor)
	else
		love.mouse.setCursor()
	end
end

function Cursor:createCircle()
	local oldCanvas = love.graphics.getCanvas()
	local canvas = love.graphics.newCanvas(32, 32)
	love.graphics.setCanvas(canvas)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.circle("line", 16, 16, 8, 64)
	love.graphics.circle("fill", 16, 16, 8, 64)
	love.graphics.setCanvas(oldCanvas)
	self.circleCursor = love.mouse.newCursor(love.graphics.readbackTexture(canvas), 16, 16)
end

function Cursor:createArrow()
	local oldCanvas = love.graphics.getCanvas()
	local canvas = love.graphics.newCanvas(32, 32)
	love.graphics.setCanvas(canvas)
	love.graphics.setColor(1, 1, 1, 1)
	local vertices = {0, 0, 16, 16, 0, 16 * math.sqrt(2)}
	love.graphics.polygon("line", vertices)
	love.graphics.polygon("fill", vertices)
	love.graphics.setCanvas(oldCanvas)
	self.arrowCursor = love.mouse.newCursor(love.graphics.readbackTexture(canvas), 0, 0)
end

return Cursor
