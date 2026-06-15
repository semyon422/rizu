local class = require("class")
local math_util = require("math_util")
local spherefonts = require("sphere.assets.fonts")

---@class yi.views.editor.EditorOverlayControl
---@field id string
---@field kind string
---@field x number
---@field y number
---@field w number
---@field h number

---@class yi.views.editor.EditorOverlayPanel
---@operator call: yi.views.editor.EditorOverlayPanel
---@field controls {[string]: yi.views.editor.EditorOverlayControl}
---@field controlOrder string[]
---@field clicked {[string]: boolean}
---@field dragged {[string]: number}
---@field keyPressed {[string]: boolean}
---@field activeId string?
---@field focusedId string?
---@field editValues {[string]: string}
---@field cursorX number
---@field cursorY number
---@field panelWidth number
---@field lineHeight number
local EditorOverlayPanel = class()

function EditorOverlayPanel:new()
	self.controls = {}
	self.controlOrder = {}
	self.clicked = {}
	self.dragged = {}
	self.keyPressed = {}
	self.editValues = {}
	self.cursorX = 0
	self.cursorY = 55
	self.panelWidth = 400
	self.lineHeight = 55
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

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorOverlayPanel:containsPoint(screen_x, screen_y)
	return self:getControlAt(screen_x, screen_y) ~= nil
end

---@param id string
---@param kind string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorOverlayPanel:register(id, kind, x, y, w, h)
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
---@return boolean
function EditorOverlayPanel:isOver(id, x, y, w, h)
	local mx, my = love.mouse.getPosition()
	local sx, sy = love.graphics.transformPoint(x, y)
	local sx2, sy2 = love.graphics.transformPoint(x + w, y + h)
	local left, top = math.min(sx, sx2), math.min(sy, sy2)
	local width, height = math.abs(sx2 - sx), math.abs(sy2 - sy)
	return mx >= left and mx <= left + width and my >= top and my <= top + height
end

---@param control yi.views.editor.EditorOverlayControl?
---@param x number
---@param y number
---@return boolean
function EditorOverlayPanel:controlContains(control, x, y)
	return control ~= nil and x >= control.x and x <= control.x + control.w and y >= control.y and y <= control.y + control.h
end

---@param x number
---@param y number
---@return yi.views.editor.EditorOverlayControl?
function EditorOverlayPanel:getControlAt(x, y)
	for i = #self.controlOrder, 1, -1 do
		local control = self.controls[self.controlOrder[i]]
		if self:controlContains(control, x, y) then
			return control
		end
	end
end

---@param e gui.MouseDownEvent
function EditorOverlayPanel:onMouseDown(e)
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
function EditorOverlayPanel:onMouseUp(e)
	local activeId = self.activeId
	if not activeId then
		return
	end

	local control = self.controls[activeId]
	self.activeId = nil
	if self:controlContains(control, e.x, e.y) then
		self.clicked[activeId] = true
	end
	return true
end

---@param e gui.DragEvent
function EditorOverlayPanel:onDrag(e)
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
function EditorOverlayPanel:onDragEnd(e)
	return self:onDrag(e)
end

---@param e gui.KeyDownEvent
function EditorOverlayPanel:onKeyDown(e)
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
function EditorOverlayPanel:onTextInput(e)
	local id = self.focusedId
	if not id then
		return
	end
	self.editValues[id] = (self.editValues[id] or "") .. e.key
	return true
end

function EditorOverlayPanel:finishFrame()
	table.clear(self.clicked)
	table.clear(self.dragged)
	table.clear(self.keyPressed)
end

function EditorOverlayPanel:reset()
	self.cursorX = 0
	self.cursorY = 55
	self.panelWidth = 400
	self.lineHeight = 55
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))
end

---@param text string
function EditorOverlayPanel:text(text)
	self:label(text, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
end

function EditorOverlayPanel:separator()
	self.cursorY = self.cursorY + 10
	love.graphics.setColor(1, 1, 1, 0.25)
	love.graphics.line(self.cursorX, self.cursorY, self.cursorX + self.panelWidth, self.cursorY)
	self.cursorY = self.cursorY + 10
end

---@param id string
---@param text string
---@param width number?
---@return boolean clicked
function EditorOverlayPanel:button(id, text, width)
	local clicked = self:drawButton(id, text, self.cursorX, self.cursorY, width or self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return clicked
end

---@param id string
---@param text string
---@return boolean clicked
function EditorOverlayPanel:smallButton(id, text)
	local clicked = self:drawButton(id, text, self.cursorX, self.cursorY, 90, self.lineHeight)
	self.cursorX = self.cursorX + 100
	return clicked
end

function EditorOverlayPanel:endRow()
	self.cursorX = 0
	self.cursorY = self.cursorY + self.lineHeight
end

---@param id string
---@param value number
---@param minValue number
---@param maxValue number
---@param step number
---@param label string
---@return number
function EditorOverlayPanel:slider(id, value, minValue, maxValue, step, label)
	local newValue = self:drawSlider(id, value, minValue, maxValue, step, label, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

---@param id string
---@param value string|number
---@param label string
---@return string
function EditorOverlayPanel:input(id, value, label)
	local newValue = self:drawInput(id, tostring(value), label, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param align string?
function EditorOverlayPanel:label(text, x, y, w, h, align)
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
function EditorOverlayPanel:drawButton(id, text, x, y, w, h)
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
---@return boolean
function EditorOverlayPanel:checkbox(id, value, text)
	local newValue = value
	if self:drawButton(id, (value and "[x] " or "[ ] ") .. text, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight) then
		newValue = not value
	end
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

---@param id string
---@param value string
---@param values string[]
---@return string
function EditorOverlayPanel:combo(id, value, values)
	local newValue = value
	if self:drawButton(id, value, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight) then
		for i, option in ipairs(values) do
			if option == value then
				newValue = values[i % #values + 1]
				break
			end
		end
		if newValue == value then
			newValue = values[1]
		end
	end
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

---@param key string
---@return boolean
function EditorOverlayPanel:consumeKey(key)
	local pressed = self.keyPressed[key] or false
	self.keyPressed[key] = nil
	return pressed
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
function EditorOverlayPanel:drawSlider(id, value, minValue, maxValue, step, text, x, y, w, h)
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
	self:label(text, x, y, w, h, "center")
	return value
end

---@param id string
---@param value string
---@param placeholder string
---@param x number
---@param y number
---@param w number
---@param h number
---@return string
function EditorOverlayPanel:drawInput(id, value, placeholder, x, y, w, h)
	if self.focusedId ~= id then
		self.editValues[id] = value
	end

	self:register(id, "input", x, y, w, h)
	local hovered = self:isOver(id, x, y, w, h)
	setButtonColor(self.focusedId == id, hovered)
	love.graphics.rectangle("fill", x, y, w, h, 4, 4)
	self:label(self.editValues[id] or placeholder, x + 8, y, w - 16, h)
	return self.editValues[id] or value
end

---@param id string
---@param value string
---@param values string[]
---@param x number
---@param y number
---@param w number
---@param h number
---@return string
function EditorOverlayPanel:tabs(id, value, values, x, y, w, h)
	local tabWidth = w / #values
	for i, option in ipairs(values) do
		local tabId = id .. ":" .. option
		local clicked = self:drawButton(tabId, option, x + (i - 1) * tabWidth, y, tabWidth, h)
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

return EditorOverlayPanel
