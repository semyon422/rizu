local View = require("gui.View")
local math_util = require("math_util")
local spherefonts = require("sphere.assets.fonts")
local time_util = require("time_util")
local EditorLayout = require("yi.views.editor.EditorLayout")

---@class yi.views.editor.EditorFooterControlRect
---@field x number
---@field y number
---@field w number
---@field h number

---@param value number
---@return number
local function clamp01(value)
	return math.min(math.max(value, 0), 1)
end

---@param value number
---@param step number
---@return number
local function snap(value, step)
	return math.floor(value / step + 0.5) * step
end

---@param x number
---@param y number
---@param w number
---@param h number
---@return yi.views.editor.EditorFooterControlRect
local function getScreenRect(x, y, w, h)
	local sx, sy = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)
	return {
		x = math.min(sx, sx2),
		y = math.min(sy, sy2),
		w = math.abs(sx2 - sx),
		h = math.abs(sy2 - sy),
	}
end

---@param rect yi.views.editor.EditorFooterControlRect?
---@param x number
---@param y number
---@return boolean
local function contains(rect, x, y)
	return rect ~= nil and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

---@param rect yi.views.editor.EditorFooterControlRect
---@param x number
---@return number
local function getRectFraction(rect, x)
	return clamp01((x - rect.x) / rect.w)
end

---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
local function isLocalHovered(x, y, w, h)
	local rect = getScreenRect(x, y, w, h)
	local mx, my = love.mouse.getPosition()
	return contains(rect, mx, my)
end

---@param w number
---@param h number
---@return number
local function getChartSliderMouseValue(w, h)
	local x = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local value = math_util.map(x, h / 2, w - h / 2, 0, 1)
	return math.min(math.max(value, 0), 1)
end

---@param active boolean
---@param hovered boolean
local function setButtonColor(active, hovered)
	if active then
		love.graphics.setColor(0.5, 0.65, 1, 0.9)
	elseif hovered then
		love.graphics.setColor(0.35, 0.42, 0.55, 0.95)
	else
		love.graphics.setColor(0.18, 0.2, 0.24, 0.95)
	end
end

---@class yi.views.editor.EditorFooterView: gui.View
---@operator call: yi.views.editor.EditorFooterView
---@field screen table
---@field controls {[string]: yi.views.editor.EditorFooterControlRect}
---@field activeControl string?
---@field clickedPlayPause boolean
---@field pressedSpace boolean
---@field rateDragValue number?
---@field chartSliderDragValue number?
local EditorFooterView = View + {}

---@param screen table
function EditorFooterView:new(screen)
	View.new(self)
	self.screen = screen
	self.controls = {}
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorFooterView:load()
	self:setSize(love.graphics.getDimensions())
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorFooterView:isMouseOver(screen_x, screen_y)
	return contains(self.controls.playPause, screen_x, screen_y)
		or contains(self.controls.rateSlider, screen_x, screen_y)
		or contains(self.controls.chartSlider, screen_x, screen_y)
end

---@param e gui.MouseDownEvent
function EditorFooterView:onMouseDown(e)
	if contains(self.controls.chartSlider, e.x, e.y) then
		self.activeControl = "chartSlider"
		self.chartSliderDragValue = getRectFraction(self.controls.chartSlider, e.x)
		return true
	elseif contains(self.controls.rateSlider, e.x, e.y) then
		self.activeControl = "rateSlider"
		self.rateDragValue = getRectFraction(self.controls.rateSlider, e.x)
		return true
	elseif contains(self.controls.playPause, e.x, e.y) then
		self.activeControl = "playPause"
		return true
	end
end

---@param e gui.MouseUpEvent
function EditorFooterView:onMouseUp(e)
	local activeControl = self.activeControl
	self.activeControl = nil
	if activeControl == "playPause" and contains(self.controls.playPause, e.x, e.y) then
		self.clickedPlayPause = true
	end
	return activeControl ~= nil
end

---@param e gui.DragEvent
function EditorFooterView:onDrag(e)
	if self.activeControl == "chartSlider" and self.controls.chartSlider then
		self.chartSliderDragValue = getRectFraction(self.controls.chartSlider, e.x)
		return true
	elseif self.activeControl == "rateSlider" and self.controls.rateSlider then
		self.rateDragValue = getRectFraction(self.controls.rateSlider, e.x)
		return true
	end
end

---@param e gui.DragEndEvent
function EditorFooterView:onDragEnd(e)
	return self:onDrag(e)
end

---@param e gui.KeyDownEvent
function EditorFooterView:onKeyDown(e)
	if e.key == "space" then
		self.pressedSpace = true
		return true
	end
end

function EditorFooterView:finishFrame()
	self.clickedPlayPause = false
	self.pressedSpace = false
	self.rateDragValue = nil
	self.chartSliderDragValue = nil
end

---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorFooterView:setControlRect(id, x, y, w, h)
	self.controls[id] = getScreenRect(x, y, w, h)
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param align string?
function EditorFooterView:drawLabel(text, x, y, w, h, align)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, x, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w, align or "left")
end

---@param id string
---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorFooterView:drawButton(id, text, x, y, w, h)
	self:setControlRect(id, x, y, w, h)
	setButtonColor(self.activeControl == id, isLocalHovered(x, y, w, h))
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, x, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w, "center")
end

---@param id string
---@param value number
---@param minValue number
---@param maxValue number
---@param step number
---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@return number
function EditorFooterView:drawRateSlider(id, value, minValue, maxValue, step, text, x, y, w, h)
	self:setControlRect(id, x, y, w, h)
	local fraction = self.rateDragValue
	if fraction then
		value = snap(math_util.map(fraction, 0, 1, minValue, maxValue), step)
	end

	setButtonColor(self.activeControl == id, isLocalHovered(x, y, w, h))
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)

	local normalized = clamp01((value - minValue) / (maxValue - minValue))
	love.graphics.setColor(0.7, 0.78, 1, 0.9)
	love.graphics.rectangle("fill", x, y, w * normalized, h, 4, 4)
	self:drawLabel(text, x, y, w, h, "center")
	return value
end

---@param w number
---@param h number
function EditorFooterView:drawChartSlider(w, h)
	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, w, h, 4, 4)
	love.graphics.setColor(1, 1, 1, 1)

	local screen = self.screen
	local context = screen.game.editorModel.context:getViewContext()
	local chartSliderService = screen.editorViewServices.chartSliderService
	local state = chartSliderService:getState(context)

	local firstTime = state.firstTime
	local lastTime = state.lastTime
	local densityPoints = state.densityPoints
	local vertexPoints = state.vertexPoints

	local pos = getChartSliderMouseValue(w, h)

	self:setControlRect("chartSlider", 0, 0, w, h)
	local newValue = self.chartSliderDragValue or pos
	local active = self.activeControl == "chartSlider"
	local hovered = isLocalHovered(0, 0, w, h)

	love.graphics.setLineWidth(2)
	setButtonColor(active, hovered)
	love.graphics.rectangle("fill", 0, 0, w, h, 4, 4)
	local pad = h * 0.1
	local innerHeight = h - 2 * pad

	local a, b = h / 2, w - h / 2

	love.graphics.setColor(1, 1, 0.1, 0.7)
	for i = 0, vertexPoints.n do
		if vertexPoints[i] then
			local x = math_util.map(i, 0, vertexPoints.n, a, b)
			love.graphics.line(x, pad, x, innerHeight + pad)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
	for i = 0, #densityPoints - 1 do
		local x = math_util.map(i, 0, #densityPoints, a, b)
		local x2 = math_util.map(i + 1, 0, #densityPoints, a, b)
		love.graphics.line(x, (1 - densityPoints[i]) * innerHeight + pad, x2, (1 - densityPoints[i + 1]) * innerHeight + pad)
	end

	local previewTime = state.previewTime
	if previewTime then
		local x = math_util.map(previewTime, firstTime, lastTime, a, b)
		love.graphics.setColor(0.1, 0.6, 1, 1)
		love.graphics.setLineWidth(4)
		love.graphics.line(x, pad, x, innerHeight + pad)
		love.graphics.setLineWidth(1)
	end

	local x = math_util.map(math.min(math.max(state.value, 0), 1), 0, 1, a, b)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", x - h / 2, 0, h, h, 4, 4)

	chartSliderService:updateDrag(context, state, {
		active = active,
		newValue = newValue,
	})
end

function EditorFooterView:draw()
	local screen = self.screen
	local context = screen.game.editorModel.context:getViewContext()
	local footerService = screen.editorViewServices.footerService
	local state = footerService:getState(context)

	local w, h = EditorLayout:move("footer")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	local lineHeight = 55

	love.graphics.translate(0, h - lineHeight * 2)

	self:drawButton("playPause", state.playPauseLabel, 0, 0, 110, lineHeight)
	if self.clickedPlayPause or self.pressedSpace then
		footerService:togglePlayback(context)
	end

	self:drawLabel(time_util.format(state.absoluteTime, 3), 120, 0, 220, lineHeight, "center")

	local newRate = self:drawRateSlider("rateSlider", state.rate, 0.5, 2, 0.01, ("%0.2fx"):format(state.rate), 350, 0, w / 6, lineHeight)
	if newRate ~= state.rate then
		footerService:setRate(context, newRate)
	end

	love.graphics.translate(0, lineHeight)
	self:drawChartSlider(w, lineHeight)
	self:finishFrame()
end

return EditorFooterView
