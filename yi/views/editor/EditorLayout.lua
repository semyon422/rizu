local gfx_util = require("gfx_util")

---@class yi.views.editor.EditorLayout
---@field transform table
---@field rects {[string]: number[]}
local EditorLayout = {
	transform = {{1 / 2, -16 / 9 / 2}, 0, 0, {0, 1 / 1080}, {0, 1 / 1080}, 0, 0, 0, 0},
	rects = {},
}

---@param key string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorLayout:setRect(key, x, y, w, h)
	self.rects[key] = {x, y, w, h}
end

---@param graphics love.Graphics?
function EditorLayout:update(graphics)
	graphics = graphics or love.graphics
	local width, height = graphics.getDimensions()

	graphics.replaceTransform(gfx_util.transform(self.transform))

	local x, y = graphics.inverseTransformPoint(0, 0)
	local xw, yh = graphics.inverseTransformPoint(width, height)
	local w, h = xw - x, yh - y

	self:setRect("base", x, y, w, h)

	local x_int = 24
	local y_int = 55

	local x0, w0 = gfx_util.layout(x, w, {-1})
	local x1, w1 = gfx_util.layout(x, w, {y_int, -1 / 2, x_int, -1 / 3, x_int, -(1 - 1 / 2 - 1 / 3), y_int})

	local y0, h0 = gfx_util.layout(0, 1080, {89, y_int, -1, y_int, 89})

	self:setRect("header", x0[1], y0[1], w0[1], h0[1])
	self:setRect("footer", x0[1], y0[5], w0[1], h0[5])
	self:setRect("subheader", x1[4], y0[2], w1[4], h0[2])

	self:setRect("column1", x1[2], y0[3], w1[2], h0[3])
	self:setRect("column2", x1[4], y0[3], w1[4], h0[3])
	self:setRect("column3", x1[6], y0[3], w1[6], h0[3])

	local column2 = self.rects.column2
	local y1, h1 = gfx_util.layout(column2[2], column2[4], {336, -1, 72})

	self:setRect("column2row1", x1[4], y1[1], w1[4], h1[1])
	self:setRect("column2row2", x1[4], y1[2], w1[4], h1[2])
	self:setRect("column2row3", x1[4], y1[3], w1[4], h1[3])

	local column2row2 = self.rects.column2row2
	local y2, h2 = gfx_util.layout(column2row2[2], column2row2[4], {72, 72 * 5})

	self:setRect("column2row2row1", x1[4], y2[1], w1[4], h2[1])
	self:setRect("column2row2row2", x1[4], y2[2], w1[4], h2[2])

	local column1 = self.rects.column1
	local y3, h3 = gfx_util.layout(column1[2], column1[4], {72 * 6, x_int, -1, x_int, 72 * 2})

	self:setRect("column1row1", x1[2], y3[1], w1[2], h3[1])
	self:setRect("column1row2", x1[2], y3[3], w1[2], h3[3])
	self:setRect("column1row3", x1[2], y3[5], w1[2], h3[5])

	local column1row1 = self.rects.column1row1
	local y4, h4 = gfx_util.layout(column1row1[2], column1row1[4], {72, -1})

	self:setRect("column1row1row1", x1[2], y4[1], w1[2], h4[1])
	self:setRect("column1row1row2", x1[2], y4[2], w1[2], h4[2])
end

---@param key string
---@return number w
---@return number h
function EditorLayout:move(key)
	local rect = self.rects[key]
	love.graphics.translate(rect[1], rect[2])
	return rect[3], rect[4]
end

return EditorLayout
