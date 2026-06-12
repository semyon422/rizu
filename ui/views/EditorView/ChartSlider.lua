local just = require("just")
local math_util = require("math_util")
local theme = require("imgui.theme")

---@param w number
---@param h number
---@return number
local function getPosition(w, h)
	local x, y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local value = math_util.map(x, h / 2, w - h / 2, 0, 1)
	return math.min(math.max(value, 0), 1)
end

return function(self, w, h)
	love.graphics.setColor(0, 0, 0, 0.8)
	theme.rectangle(w, h)
	love.graphics.setColor(1, 1, 1, 1)

	local editorModel = self.game.editorModel
	local editorTimePoint = editorModel.session.point

	local firstTime, lastTime = editorModel:getTimelineRange()
	local fullLength = lastTime - firstTime
	local value = (editorTimePoint.absoluteTime - firstTime) / fullLength

	local densityPoints = editorModel.graphsGenerator.densityGraph
	local vertexPoints = editorModel.graphsGenerator.vertexDatasGraph

	local over = just.is_over(w, h)
	local pos = getPosition(w, h)

	local new_value, active, hovered = just.slider("time slider", over, pos, value)

	love.graphics.setLineWidth(2)
	theme.setColor(active, hovered)
	theme.rectangle(w, h)
	local pad = h * (1 - theme.size) / 2
	local _h = h - 2 * pad

	local a, b = h / 2, w - h / 2

	love.graphics.setColor(1, 1, 0.1, 0.7)
	for i = 0, vertexPoints.n do
		if vertexPoints[i] then
			local x = math_util.map(i, 0, vertexPoints.n, a, b)
			love.graphics.line(x, pad, x, _h + pad)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
	for i = 0, #densityPoints - 1 do
		local x = math_util.map(i, 0, #densityPoints, a, b)
		local x2 = math_util.map(i + 1, 0, #densityPoints, a, b)
		love.graphics.line(x, (1 - densityPoints[i]) * _h + pad, x2, (1 - densityPoints[i + 1]) * _h + pad)
	end

	local preview_time = editorModel:getPreviewTime()
	if preview_time then
		local x = math_util.map(preview_time, firstTime, lastTime, a, b)
		love.graphics.setColor(0.1, 0.6, 1, 1)
		love.graphics.setLineWidth(4)
		love.graphics.line(x, pad, x, _h + pad)
		love.graphics.setLineWidth(1)
	end

	local x = math_util.map(math.min(math.max(value, 0), 1), 0, 1, a, b)
	love.graphics.setColor(1, 1, 1, 1)
	theme.fillrect(h, h, x - h / 2, 0)

	just.next(w, h)

	if just.active_id == "time slider" then
		if new_value then
			editorModel.scroller:scrollSeconds(new_value * fullLength + firstTime)
		end
		if editorModel.timer.is_playing then
			editorModel:pause()
			editorModel.session.dragging = true
		end
	elseif editorModel.session.dragging then
		editorModel:play()
		editorModel.session.dragging = false
	end
end
