local class = require("class")
local math_util = require("math_util")
local spherefonts = require("sphere.assets.fonts")

---@class yi.views.editor.EditorGuiControl
---@field id string
---@field kind string
---@field x number
---@field y number
---@field w number
---@field h number

---@class yi.views.editor.EditorGui
---@operator call: yi.views.editor.EditorGui
---@field controls {[string]: yi.views.editor.EditorGuiControl}
---@field controlOrder string[]
---@field clicked {[string]: boolean}
---@field dragged {[string]: number}
---@field keyPressed {[string]: boolean}
---@field activeId string?
---@field focusedId string?
---@field editValues {[string]: string}
local EditorGui = class()

function EditorGui:new()
	self.controls = {}
	self.controlOrder = {}
	self.clicked = {}
	self.dragged = {}
	self.keyPressed = {}
	self.editValues = {}
end

function EditorGui:finishFrame()
	table.clear(self.clicked)
	table.clear(self.dragged)
	table.clear(self.keyPressed)
end

---@param key string
function EditorGui:consumeKey(key)
	local pressed = self.keyPressed[key] or false
	self.keyPressed[key] = nil
	return pressed
end

---@param id string
---@param kind string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorGui:register(id, kind, x, y, w, h)
	local sx, sy = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)
	if not self.controls[id] then
		table.insert(self.controlOrder, id)
	end
	self.controls[id] = {
		id = id,
		kind = kind,
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
---@return boolean hovered
function EditorGui:isOver(id, x, y, w, h)
	local mx, my = love.mouse.getPosition()
	local sx, sy = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)
	local left, top = math.min(sx, sx2), math.min(sy, sy2)
	local width, height = math.abs(sx2 - sx), math.abs(sy2 - sy)
	return mx >= left and mx <= left + width and my >= top and my <= top + height
end

---@param control yi.views.editor.EditorGuiControl
---@param x number
---@param y number
---@return boolean
function EditorGui:controlContains(control, x, y)
	return x >= control.x and x <= control.x + control.w and y >= control.y and y <= control.y + control.h
end

---@param x number
---@param y number
---@return yi.views.editor.EditorGuiControl?
function EditorGui:getControlAt(x, y)
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
function EditorGui:containsPoint(x, y)
	return self:getControlAt(x, y) ~= nil
end

---@param e gui.MouseDownEvent
function EditorGui:onMouseDown(e)
	local control = self:getControlAt(e.x, e.y)
	if not control then
		return
	end

	self.activeId = control.id
	if control.kind == "input" then
		self.focusedId = control.id
	elseif control.kind == "slider" then
		self.dragged[control.id] = math.min(math.max((e.x - control.x) / control.w, 0), 1)
	elseif control.kind ~= "slider" then
		self.focusedId = nil
	end
	return true
end

---@param e gui.MouseUpEvent
function EditorGui:onMouseUp(e)
	local activeId = self.activeId
	if not activeId then
		return
	end

	local control = self.controls[activeId]
	self.activeId = nil
	if control and self:controlContains(control, e.x, e.y) then
		self.clicked[activeId] = true
	end
	return true
end

---@param e gui.DragEvent
function EditorGui:onDrag(e)
	local activeId = self.activeId
	local control = activeId and self.controls[activeId]
	if not control then
		return
	end
	if control.kind == "slider" then
		self.dragged[activeId] = math.min(math.max((e.x - control.x) / control.w, 0), 1)
	end
	return true
end

---@param e gui.DragEndEvent
function EditorGui:onDragEnd(e)
	return self:onDrag(e)
end

---@param e gui.KeyDownEvent
function EditorGui:onKeyDown(e)
	self.keyPressed[e.key] = true

	local id = self.focusedId
	if not id then
		return
	end

	local value = self.editValues[id] or ""
	if e.key == "backspace" then
		self.editValues[id] = value:sub(1, math.max(#value - 1, 0))
		return true
	elseif e.key == "delete" then
		self.editValues[id] = ""
		return true
	elseif e.key == "return" or e.key == "kpenter" or e.key == "escape" then
		self.focusedId = nil
		return true
	end
end

---@param e gui.TextInputEvent
function EditorGui:onTextInput(e)
	local id = self.focusedId
	if not id then
		return
	end
	self.editValues[id] = (self.editValues[id] or "") .. e.key
	return true
end

local function setButtonColor(active, hovered)
	if active then
		love.graphics.setColor(0.5, 0.65, 1, 0.9)
	elseif hovered then
		love.graphics.setColor(0.35, 0.42, 0.55, 0.95)
	else
		love.graphics.setColor(0.18, 0.2, 0.24, 0.95)
	end
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param align string?
function EditorGui:label(text, x, y, w, h, align)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, x, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w, align or "left")
end

---@param id string
---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean clicked
function EditorGui:button(id, text, x, y, w, h)
	self:register(id, "button", x, y, w, h)
	local hovered = self:isOver(id, x, y, w, h)
	setButtonColor(self.activeId == id, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, x, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w, "center")
	return self.clicked[id] or false
end

---@param id string
---@param value boolean
---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean value
function EditorGui:checkbox(id, value, text, x, y, w, h)
	local clicked = self:button(id, (value and "[x] " or "[ ] ") .. text, x, y, w, h)
	if clicked then
		return not value
	end
	return value
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
---@return number value
function EditorGui:slider(id, value, minValue, maxValue, step, text, x, y, w, h)
	self:register(id, "slider", x, y, w, h)
	local fraction = self.dragged[id]
	if fraction then
		value = math_util.map(fraction, 0, 1, minValue, maxValue)
		value = math.floor(value / step + 0.5) * step
	end

	local hovered = self:isOver(id, x, y, w, h)
	setButtonColor(self.activeId == id, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)

	local normalized = (value - minValue) / (maxValue - minValue)
	love.graphics.setColor(0.7, 0.78, 1, 0.9)
	love.graphics.rectangle("fill", x, y, w * math.min(math.max(normalized, 0), 1), h, 4, 4)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(text, x, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w, "center")
	return value
end

---@param id string
---@param value string
---@param placeholder string
---@param x number
---@param y number
---@param w number
---@param h number
---@return string value
function EditorGui:input(id, value, placeholder, x, y, w, h)
	if self.focusedId ~= id then
		self.editValues[id] = value
	end

	self:register(id, "input", x, y, w, h)
	local hovered = self:isOver(id, x, y, w, h)
	setButtonColor(self.focusedId == id, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(self.editValues[id] or placeholder, x + 8, y + math.max((h - love.graphics.getFont():getHeight()) / 2, 0), w - 16, "left")
	return self.editValues[id] or value
end

---@param id string
---@param value string
---@param values string[]
---@param x number
---@param y number
---@param w number
---@param h number
---@return string value
function EditorGui:combo(id, value, values, x, y, w, h)
	if self:button(id, value, x, y, w, h) then
		for i, option in ipairs(values) do
			if option == value then
				return values[i % #values + 1]
			end
		end
		return values[1]
	end
	return value
end

---@param id string
---@param value string
---@param values string[]
---@param x number
---@param y number
---@param w number
---@param h number
---@return string value
function EditorGui:tabs(id, value, values, x, y, w, h)
	local tabWidth = w / #values
	for i, option in ipairs(values) do
		local tabId = id .. ":" .. option
		local clicked = self:button(tabId, option, x + (i - 1) * tabWidth, y, tabWidth, h)
		if option == value then
			love.graphics.setColor(0.7, 0.78, 1, 0.35)
			love.graphics.rectangle("fill", x + (i - 1) * tabWidth, y, tabWidth, h, 4, 4)
		end
		if clicked then
			value = option
		end
	end
	return value
end

function EditorGui:setFont()
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
end

return EditorGui
