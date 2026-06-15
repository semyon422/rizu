local View = require("gui.View")
local Fraction = require("chart.core.Fraction")
local gfx_util = require("gfx_util")
local spherefonts = require("sphere.assets.fonts")
local EditorLayout = require("yi.views.editor.EditorLayout")

---@class yi.views.editor.EditorSnapGridControlRect
---@field id string
---@field x number
---@field y number
---@field w number
---@field h number

---@class yi.views.editor.EditorSnapGridView: gui.View
---@operator call: yi.views.editor.EditorSnapGridView
---@field screen table
---@field controls {[string]: yi.views.editor.EditorSnapGridControlRect}
---@field controlOrder string[]
---@field clicked {[string]: boolean}
---@field keyPressed {[string]: boolean}
---@field activeControl string?
---@field scroll number?
---@field dragActive boolean
local EditorSnapGridView = View + {}

---@return string
local function getVelocityText()
	return ""
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

---@param screen table
function EditorSnapGridView:new(screen)
	View.new(self)
	self.screen = screen
	self.controls = {}
	self.controlOrder = {}
	self.clicked = {}
	self.keyPressed = {}
	self.dragActive = false
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setSize(love.graphics.getDimensions())
end

function EditorSnapGridView:load()
	self:setSize(love.graphics.getDimensions())
end

---@param rect yi.views.editor.EditorSnapGridControlRect?
---@param x number
---@param y number
---@return boolean
function EditorSnapGridView:controlContains(rect, x, y)
	return rect ~= nil and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorSnapGridView:registerControl(id, x, y, w, h)
	local sx, sy = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)
	if not self.controls[id] then
		table.insert(self.controlOrder, id)
	end
	self.controls[id] = {
		id = id,
		x = math.min(sx, sx2),
		y = math.min(sy, sy2),
		w = math.abs(sx2 - sx),
		h = math.abs(sy2 - sy),
	}
end

---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
function EditorSnapGridView:isLocalHovered(id, x, y, w, h)
	self:registerControl(id, x, y, w, h)
	local mx, my = love.mouse.getPosition()
	return self:controlContains(self.controls[id], mx, my)
end

---@param x number
---@param y number
---@return yi.views.editor.EditorSnapGridControlRect?
function EditorSnapGridView:getControlAt(x, y)
	for i = #self.controlOrder, 1, -1 do
		local control = self.controls[self.controlOrder[i]]
		if self:controlContains(control, x, y) then
			return control
		end
	end
end

---@param x number
---@param y number
---@return boolean
function EditorSnapGridView:containsPoint(x, y)
	return self:getControlAt(x, y) ~= nil
end

---@param key string
---@return boolean
function EditorSnapGridView:consumeKey(key)
	local pressed = self.keyPressed[key] or false
	self.keyPressed[key] = nil
	return pressed
end

function EditorSnapGridView:finishFrame()
	table.clear(self.clicked)
	table.clear(self.keyPressed)
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorSnapGridView:isMouseOver(screen_x, screen_y)
	local editorModel = self.screen.game.editorModel
	if editorModel.isFineScrollRequested() or editorModel.isSnapChangeRequested() then
		return self:containsPoint(screen_x, screen_y)
	end

	local control = self:getControlAt(screen_x, screen_y)
	return control and control.id ~= "snap grid drag" or false
end

---@param e gui.MouseDownEvent
function EditorSnapGridView:onMouseDown(e)
	local editorModel = self.screen.game.editorModel
	local control = self:getControlAt(e.x, e.y)
	if not control then
		return
	end
	if control.id == "snap grid drag" and not (editorModel.isFineScrollRequested() or editorModel.isSnapChangeRequested()) then
		return
	end
	self.activeControl = control.id
	return true
end

---@param e gui.MouseUpEvent
function EditorSnapGridView:onMouseUp(e)
	local activeControl = self.activeControl
	self.activeControl = nil
	self.dragActive = false
	if activeControl and self:controlContains(self.controls[activeControl], e.x, e.y) then
		self.clicked[activeControl] = true
	end
	return activeControl ~= nil
end

---@param e gui.DragEvent
function EditorSnapGridView:onDrag(e)
	self.dragActive = self.activeControl == "snap grid drag"
	return self.activeControl ~= nil
end

---@param e gui.DragEndEvent
function EditorSnapGridView:onDragEnd(e)
	self.dragActive = false
	return self.activeControl ~= nil
end

---@param e gui.ScrollEvent
function EditorSnapGridView:onScroll(e)
	self.scroll = e.direction_y
	return true
end

---@param e gui.KeyDownEvent
function EditorSnapGridView:onKeyDown(e)
	self.keyPressed[e.key] = true
	return true
end

---@param field string
---@param currentTime number
---@param w number
---@param h number
---@param align string
---@param getText function
function EditorSnapGridView:drawTimingObjects(field, currentTime, w, h, align, getText)
	do return end
	local editorModel = self.screen.game.editorModel
	local rangeTracker = editorModel.layerData.ranges.timePoint
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local editor = self.screen.game.configModel.configs.settings.editor
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

---@param point chart.IntervalPoint
---@param field string
---@param currentTime number
---@param width number
function EditorSnapGridView:drawSnap(point, field, currentTime, width)
	local editorModel = self.screen.game.editorModel
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local editor = self.screen.game.configModel.configs.settings.editor

	local y = noteSkin:getTimePosition((currentTime - point[field]) * editor.speed)

	love.graphics.push("all")
	love.graphics.translate(0, y)

	local size = 20
	local id = tostring(point) .. "scroll"
	local hovered = self:isLocalHovered(id, -size / 2, -size / 2, size, size)
		or self:isLocalHovered(id .. "right", -size / 2 + width, -size / 2, size, size)
	if hovered then
		love.graphics.setLineWidth(4)
	end
	if self.clicked[id] or self.clicked[id .. "right"] then
		editorModel:scrollPoint(point)
	end

	love.graphics.line(0, 0, width, 0)
	love.graphics.pop()
end

---@param field string
---@param currentTime number
---@param width number
function EditorSnapGridView:drawComputedGrid(field, currentTime, width)
	local editorModel = self.screen.game.editorModel
	local editor = self.screen.game.configModel.configs.settings.editor
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
function EditorSnapGridView:drawTimings(_w, _h)
	local editorModel = self.screen.game.editorModel
	local editorTimePoint = editorModel:getPoint()
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local editor = self.screen.game.configModel.configs.settings.editor

	local layer = self.screen.game.editorModel.layer

	love.graphics.push("all")
	love.graphics.setColor(1, 0.8, 0.2)
	love.graphics.setLineWidth(4)
	for p in layer:iter(editorModel:getIterRange()) do
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
function EditorSnapGridView:drawComments(_w, _h)
	local editorModel = self.screen.game.editorModel
	local editorTimePoint = editorModel:getPoint()
	local noteSkin = self.screen.game.noteSkinModel.noteSkin
	local editor = self.screen.game.configModel.configs.settings.editor

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

function EditorSnapGridView:drawMouse()
	local editorModel = self.screen.game.editorModel
	local dt = editorModel:getMouseTime() - editorModel:getSessionTime()

	love.graphics.push()
	EditorLayout:move("base")

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
	love.graphics.printf(text, x + padding, y, width, "left")
	love.graphics.pop()
end

function EditorSnapGridView:draw()
	local screen = self.screen
	local editorModel = screen.game.editorModel
	local noteSkin = screen.game.noteSkinModel.noteSkin
	local editor = screen.game.configModel.configs.settings.editor

	local w, h = EditorLayout:move("base")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
	love.graphics.setLineStyle("smooth")

	local editorTimePoint = editorModel:getPoint()

	love.graphics.replaceTransform(gfx_util.transform(screen.snap_grid_transform))
	love.graphics.translate(noteSkin.baseOffset, 0)
	local width = noteSkin.fullWidth
	local _, mouseY = love.graphics.inverseTransformPoint(love.mouse.getPosition())

	self:registerControl("snap grid drag", 0, 0, width, h)

	love.graphics.push()
	self:drawComputedGrid("absoluteTime", editorTimePoint.absoluteTime, width)

	if editor.showTimings then
		self:drawTimings(width, h)
	end
	self:drawComments(width, h)

	love.graphics.translate(width + 40, 0)
	self:drawTimingObjects("absoluteTime", editorTimePoint.absoluteTime, 500, 50, "left", getVelocityText)
	love.graphics.pop()

	local scroll = self.scroll
	self.scroll = nil
	if self:consumeKey("right") then
		scroll = 1
	elseif self:consumeKey("left") then
		scroll = -1
	end

	local canDrag = editorModel.isFineScrollRequested() or editorModel.isSnapChangeRequested()
	local scrollState = screen.editorViewServices.scrollInputService:update(editorModel.context:getViewContext(), noteSkin, editor, {
		mouseY = mouseY,
		dragActive = canDrag and self.dragActive,
		scroll = scroll,
	})
	if scrollState.showMouseDelta then
		self:drawMouse()
	end
	self:finishFrame()
end

return EditorSnapGridView
