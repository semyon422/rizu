local View = require("gui.View")
local EditorWidgets = require("yi.views.editor.EditorWidgets")
local math_util = require("math_util")
local spherefonts = require("sphere.assets.fonts")
local EditorLayout = require("yi.views.editor.EditorLayout")

---@param w number
---@param h number
---@return number
local function getChartSliderMouseValue(w, h)
	local x = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local value = math_util.map(x, h / 2, w - h / 2, 0, 1)
	return math.min(math.max(value, 0), 1)
end

---@class yi.views.editor.EditorFooterView: gui.View
---@operator call: yi.views.editor.EditorFooterView
---@field screen table
---@field widgets yi.views.editor.EditorWidgets
local EditorFooterView = View + {}

---@param screen table
function EditorFooterView:new(screen)
	View.new(self)
	self.screen = screen
	self.widgets = EditorWidgets()
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
	return self.widgets:contains("playPause", screen_x, screen_y)
		or self.widgets:contains("rateSlider", screen_x, screen_y)
		or self.widgets:contains("chartSlider", screen_x, screen_y)
end

---@param e gui.MouseDownEvent
function EditorFooterView:onMouseDown(e)
	return self.widgets:onMouseDown(e)
end

---@param e gui.MouseUpEvent
function EditorFooterView:onMouseUp(e)
	return self.widgets:onMouseUp(e)
end

---@param e gui.DragEvent
function EditorFooterView:onDrag(e)
	return self.widgets:onDrag(e)
end

---@param e gui.DragEndEvent
function EditorFooterView:onDragEnd(e)
	return self.widgets:onDragEnd(e)
end

---@param e gui.KeyDownEvent
function EditorFooterView:onKeyDown(e)
	if e.key == "space" then
		self.widgets:onKeyDown(e)
		return true
	end
end

function EditorFooterView:finishFrame()
	self.widgets:finishFrame()
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

	self.widgets:register("chartSlider", "slider", 0, 0, w, h)
	local newValue = self.widgets:getDragFraction("chartSlider") or pos
	local active = self.widgets:isActive("chartSlider")
	local hovered = self.widgets:isMouseOver("chartSlider")

	love.graphics.setLineWidth(2)
	self.widgets:setButtonColor(active, hovered)
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

	local x = math_util.map(EditorWidgets.clamp01(state.value), 0, 1, a, b)
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

	self.widgets:button("playPause", state.playPauseLabel, 0, 0, 110, lineHeight)

	self.widgets:label(state.absoluteTimeLabel, 120, 0, 220, lineHeight, "center")

	local rateNormalized = EditorWidgets.clamp01((state.rate - state.rateMin) / (state.rateMax - state.rateMin))
	self.widgets:slider("rateSlider", rateNormalized, 0, 1, nil, state.rateLabel, 350, 0, w / 6, lineHeight)
	footerService:handleInput(context, state, {
		togglePlayback = self.widgets:clicked("playPause") or self.widgets:consumeKey("space"),
		rateFraction = self.widgets:getDragFraction("rateSlider"),
	})

	love.graphics.translate(0, lineHeight)
	self:drawChartSlider(w, lineHeight)
	self:finishFrame()
end

return EditorFooterView
