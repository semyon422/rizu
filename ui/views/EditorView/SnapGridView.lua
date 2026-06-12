local class = require("class")
local gfx_util = require("gfx_util")
local math_util = require("math_util")
local spherefonts = require("sphere.assets.fonts")
local just = require("just")
local Fraction = require("chart.core.Fraction")
local imgui = require("imgui")

local Layout = require("ui.views.EditorView.Layout")

local SnapGridView = class()

---@return string
local function getVelocityText()
	return ""
end

---@param field string
---@param currentTime number
---@param w number
---@param h number
---@param align string
---@param getText function
function SnapGridView:drawTimingObjects(field, currentTime, w, h, align, getText)
	do return end
	local editorModel = self.game.editorModel
	local rangeTracker = editorModel.layerData.ranges.timePoint
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor
	local timePoint = rangeTracker.head
	if not timePoint or not currentTime then
		return
	end

	local endTimePoint = rangeTracker.tail
	local t
	while timePoint and timePoint <= endTimePoint do
		local text = getText(timePoint)
		if text and not t or timePoint.absoluteTime - t >= 0.01 then
			local y = noteSkin:getTimePosition((currentTime - timePoint[field]) * editor.speed)
			gfx_util.printFrame(text, 0, y - h / 2, w, h, align, "center")
			t = timePoint.absoluteTime
		end

		timePoint = timePoint.next
	end
end

local colors = {
	gray = {0.2, 0.2, 0.2},
	white = {1, 1, 1},
	red = {1, 0, 0},
	blue = {0, 0, 1},
	green = {0, 1, 0},
	yellow = {1, 1, 0},
	violet = {1, 0, 1},
}

local snaps = {
	[1] = colors.white,
	[2] = colors.red,
	[3] = colors.violet,
	[4] = colors.blue,
	[5] = colors.yellow,
	[6] = colors.violet,
	[7] = colors.yellow,
	[8] = colors.green,
}

---@param point chart.IntervalPoint
---@param field string
---@param currentTime number
---@param width number
function SnapGridView:drawSnap(point, field, currentTime, width)
	local editorModel = self.game.editorModel
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor

	local y = noteSkin:getTimePosition((currentTime - point[field]) * editor.speed)

	love.graphics.push("all")
	love.graphics.translate(0, y)

	local size = 20
	local changed, active, hovered = just.button(
		tostring(point) .. "scroll",
		just.is_over(size, size, -size / 2, -size / 2) or just.is_over(size, size, -size / 2 + width, -size / 2)
	)
	if hovered then
		love.graphics.setLineWidth(4)
	end
	if changed then
		editorModel.scroller:scrollPoint(point)
	end

	love.graphics.line(0, 0, width, 0)
	love.graphics.pop()
end

---@param field string
---@param currentTime number
---@param width number
function SnapGridView:drawComputedGrid(field, currentTime, width)
	local editorModel = self.game.editorModel
	local editor = self.game.configModel.configs.settings.editor
	local layer = editorModel.layer
	local snap = editor.snap

	if not currentTime then
		return
	end

	love.graphics.setLineWidth(1)

	local range = 1 / editor.speed
	local point = layer.points:interpolateAbsolute(1, currentTime - range)
	local measure

	local vertex = point.vertex
	local time = point.time
	vertex, time = point:add(Fraction((time * snap):ceil() + 1, snap) - time)

	point = layer.points:interpolateAbsolute(1, currentTime + range)
	local endVertex = point.vertex
	local endTime = point.time
	endTime = Fraction((endTime * snap):floor(), snap)

	point = layer.points:interpolateFraction(vertex, time)

	while vertex and vertex < endVertex or vertex == endVertex and time <= endTime do
		point = point or layer.points:interpolateFraction(vertex, time)
		if not point or not point[field] then
			break
		end

		local drawNothing, skipVertex

		if measure ~= point.measure then
			measure = point.measure
			local delta = -(time % 1) - measure.offset
			while delta[1] < 0 do
				delta = delta + Fraction(1, snap)
			end
			vertex, time = point:add(delta)
			point = layer.points:interpolateFraction(vertex, time)
			if not point or not point[field] then
				break
			end
		end

		if not drawNothing and vertex.next then
			local dt = vertex.next.point.absoluteTime - vertex.point.absoluteTime
			if dt < 0.01 then
				drawNothing = true
				skipVertex = true
			end
		end

		if not drawNothing then
			local j = snap * point:getBeatModulo()
			love.graphics.setColor(snaps[editorModel:getSnap(j)] or colors.gray)
			self:drawSnap(point, field, currentTime, width)
		end

		if skipVertex then
			vertex, time = vertex.next, vertex:start()
			point = vertex.point
		else
			vertex, time = point:add(Fraction(1, snap))
			point = nil
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
end

---@param _w number
---@param _h number
function SnapGridView:drawTimings(_w, _h)
	local editorModel = self.game.editorModel
	local editorTimePoint = editorModel.session.point
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor

	local layer = self.game.editorModel.layer

	love.graphics.push("all")
	love.graphics.setColor(1, 0.8, 0.2)
	love.graphics.setLineWidth(4)
	for p, vp, notes in layer:iter(editorModel:getIterRange()) do
		local vertex = p._vertex
		local measure = p._measure

		if vertex then
			love.graphics.setColor(1, 0.8, 0.2)
		elseif measure then
			love.graphics.setColor(snaps[editorModel:getSnap(p:getBeatModulo())] or colors.white)
		end

		if vertex or measure then
			local y = noteSkin:getTimePosition((editorTimePoint.absoluteTime - p.absoluteTime) * editor.speed)
			love.graphics.line(0, y, _w, y)
		end
	end
	love.graphics.pop()
end

---@param _w number
---@param _h number
function SnapGridView:drawComments(_w, _h)
	local editorModel = self.game.editorModel
	local editorTimePoint = editorModel.session.point
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor

	---@type chartedit.Layer
	local layer = editorModel.layer

	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 16))
	for p in layer:iter(editorModel:getIterRange()) do
		local vp = editorModel:getVisual():getPoint(p)
		local comment = vp.comment

		if comment then
			local y = noteSkin:getTimePosition((editorTimePoint.absoluteTime - p.absoluteTime) * editor.speed)
			love.graphics.print(comment, _w + 20, y - 20, 0)
		end
	end
	love.graphics.pop()
end

---@param id any
---@param w number
---@param h number
---@return boolean
local function drag(id, w, h)
	local over = just.is_over(w, h)
	local _, active, hovered = just.button(id, over)

	if hovered then
		local alpha = active and 0.2 or 0.1
		love.graphics.setColor(1, 1, 1, alpha)
		love.graphics.rectangle("fill", 0, 0, w, h)
	end
	love.graphics.setColor(1, 1, 1, 1)

	return just.active_id == id
end

---@param self table
local function drawMouse(self)
	local editorModel = self.game.editorModel
	local dt = editorModel:getMouseTime() - editorModel.session.point.absoluteTime

	love.graphics.push()
	local w, h = Layout:move("base")

	local x, y = love.graphics.inverseTransformPoint(love.mouse.getPosition())

	local font = spherefonts.get("Noto Sans", 24)
	love.graphics.setFont(font)
	local text = ("%3.1fms"):format(dt * 1000)
	local width = font:getWidth(text)
	local height = font:getHeight() * font:getLineHeight()

	local padding = 20
	love.graphics.setColor(0, 0, 0, 0.75)
	love.graphics.rectangle("fill", x, y, width + padding * 2, height)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(("%3.1fms"):format(dt * 1000), x + padding, y, width, "left")
	love.graphics.pop()
end

local prevMouseY = 0
local speedOrig
function SnapGridView:draw()
	local editorModel = self.game.editorModel
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor

	local w, h = Layout:move("base")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	love.graphics.setLineStyle("smooth")

	local lineHeight = 55
	imgui.setSize(w, h, 200, lineHeight)

	local editorTimePoint = editorModel.session.point

	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	love.graphics.translate(noteSkin.baseOffset, 0)
	local width = noteSkin.fullWidth
	local _mx, _my = love.graphics.inverseTransformPoint(love.mouse.getPosition())

	love.graphics.push()
	self:drawComputedGrid("absoluteTime", editorTimePoint.absoluteTime, width)

	if editor.showTimings then
		self:drawTimings(width, h)
	end
	self:drawComments(width, h)

	love.graphics.translate(width + 40, 0)
	self:drawTimingObjects("absoluteTime", editorTimePoint.absoluteTime, 500, 50, "left", getVelocityText)
	love.graphics.pop()

	local lalt, lshift, lctrl = love.keyboard.isDown("lalt"), love.keyboard.isDown("lshift"), love.keyboard.isDown("lctrl")

	if lalt and not speedOrig then
		speedOrig = editor.speed
		editor.speed = 1000 / noteSkin.unit * 10
	elseif not lalt and speedOrig then
		editor.speed = speedOrig
		speedOrig = nil
	end
	if lalt or lshift or lctrl then
		drawMouse(self)
	end
	if (lalt or lshift) and drag("drag1", width, h) then
		local a = noteSkin:getInverseTimePosition(_my)
		local b = noteSkin:getInverseTimePosition(prevMouseY)
		editorModel.scroller:scrollSecondsDelta((a - b) / editor.speed)
		if editorModel.timer.is_playing then
			editorModel:pause()
			editorModel.session.dragging = true
		end
	elseif editorModel.session.dragging then
		editorModel:play()
		editorModel.session.dragging = false
	end
	prevMouseY = _my

	local scroll = just.wheel_over("scale scroll", true)
	if just.keypressed("right") then
		scroll = 1
	elseif just.keypressed("left") then
		scroll = -1
	end

	if scroll then
		if lshift then
			if scroll == 1 then
				editorModel:incSnap()
			elseif scroll == -1 then
				editorModel:decSnap()
			end
		elseif lctrl then
			editorModel:setLogSpeed(editorModel:getLogSpeed() + scroll)
		else
			if editorModel.timer.is_playing and scroll < 0 then
				editorModel.scroller:scrollSnaps(scroll)
			end
			editorModel.scroller:scrollSnaps(scroll)
		end
	end
end

return SnapGridView
