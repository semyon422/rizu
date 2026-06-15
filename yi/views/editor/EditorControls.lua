local class = require("class")

---@class yi.views.editor.EditorControlRect
---@field id string
---@field kind string
---@field x number
---@field y number
---@field w number
---@field h number

---@class yi.views.editor.EditorControls
---@operator call: yi.views.editor.EditorControls
---@field controls {[string]: yi.views.editor.EditorControlRect}
---@field controlOrder string[]
---@field clicked {[string]: boolean}
---@field dragged {[string]: number}
---@field keyPressed {[string]: boolean}
---@field activeId string?
---@field focusedId string?
local EditorControls = class()

function EditorControls:new()
	self.controls = {}
	self.controlOrder = {}
	self.clicked = {}
	self.dragged = {}
	self.keyPressed = {}
end

---@param value number
---@return number
function EditorControls.clamp01(value)
	return math.min(math.max(value, 0), 1)
end

---@param x number
---@param y number
---@param w number
---@param h number
---@return number
---@return number
---@return number
---@return number
function EditorControls.toScreenRect(x, y, w, h)
	local sx, sy = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)
	return math.min(sx, sx2), math.min(sy, sy2), math.abs(sx2 - sx), math.abs(sy2 - sy)
end

---@param id string
---@param kind string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorControls:register(id, kind, x, y, w, h)
	local sx, sy, sw, sh = EditorControls.toScreenRect(x, y, w, h)
	if not self.controls[id] then
		table.insert(self.controlOrder, id)
	end
	self.controls[id] = {
		id = id,
		kind = kind,
		x = sx,
		y = sy,
		w = sw,
		h = sh,
	}
end

---@param control yi.views.editor.EditorControlRect?
---@param x number
---@param y number
---@return boolean
function EditorControls:contains(control, x, y)
	return control ~= nil and x >= control.x and x <= control.x + control.w and y >= control.y and y <= control.y + control.h
end

---@param x number
---@param y number
---@return yi.views.editor.EditorControlRect?
function EditorControls:getControlAt(x, y)
	for i = #self.controlOrder, 1, -1 do
		local control = self.controls[self.controlOrder[i]]
		if self:contains(control, x, y) then
			return control
		end
	end
end

---@param x number
---@param y number
---@return boolean
function EditorControls:containsPoint(x, y)
	return self:getControlAt(x, y) ~= nil
end

---@param id string
---@return boolean
function EditorControls:isMouseOver(id)
	local mx, my = love.mouse.getPosition()
	return self:contains(self.controls[id], mx, my)
end

---@param id string
---@param x number
---@return number
function EditorControls:getFraction(id, x)
	local control = self.controls[id]
	if not control then
		return 0
	end
	return EditorControls.clamp01((x - control.x) / control.w)
end

---@param key string
---@return boolean
function EditorControls:consumeKey(key)
	local pressed = self.keyPressed[key] or false
	self.keyPressed[key] = nil
	return pressed
end

function EditorControls:finishFrame()
	table.clear(self.clicked)
	table.clear(self.dragged)
	table.clear(self.keyPressed)
end

function EditorControls:clearTransient()
	self.activeId = nil
	self.focusedId = nil
	self:finishFrame()
end

---@param e gui.MouseDownEvent
---@return yi.views.editor.EditorControlRect?
function EditorControls:beginPress(e)
	local control = self:getControlAt(e.x, e.y)
	if not control then
		return
	end

	self.activeId = control.id
	if control.kind == "input" then
		self.focusedId = control.id
	elseif control.kind == "slider" then
		self.dragged[control.id] = self:getFraction(control.id, e.x)
	else
		self.focusedId = nil
	end
	return control
end

---@param e gui.MouseUpEvent
---@return string? clickedId
function EditorControls:endPress(e)
	local activeId = self.activeId
	if not activeId then
		return
	end

	local control = self.controls[activeId]
	self.activeId = nil
	if self:contains(control, e.x, e.y) then
		self.clicked[activeId] = true
		return activeId
	end
end

---@param e gui.DragEvent
---@return string? activeId
function EditorControls:drag(e)
	local activeId = self.activeId
	local control = activeId and self.controls[activeId]
	if not control then
		return
	end
	if control.kind == "slider" then
		self.dragged[activeId] = self:getFraction(activeId, e.x)
	end
	return activeId
end

---@param e gui.KeyDownEvent
function EditorControls:onKeyDown(e)
	self.keyPressed[e.key] = true
end

return EditorControls
