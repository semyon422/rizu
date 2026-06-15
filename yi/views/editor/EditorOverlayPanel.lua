local class = require("class")
local EditorWidgets = require("yi.views.editor.EditorWidgets")
local spherefonts = require("sphere.assets.fonts")

---@class yi.views.editor.EditorOverlayPanel
---@operator call: yi.views.editor.EditorOverlayPanel
---@field widgets yi.views.editor.EditorWidgets
---@field cursorX number
---@field cursorY number
---@field panelWidth number
---@field lineHeight number
local EditorOverlayPanel = class()

function EditorOverlayPanel:new()
	self.widgets = EditorWidgets()
	self.cursorX = 0
	self.cursorY = 55
	self.panelWidth = 400
	self.lineHeight = 55
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorOverlayPanel:containsPoint(screen_x, screen_y)
	return self.widgets:containsPoint(screen_x, screen_y)
end

---@param id string
---@param kind string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorOverlayPanel:register(id, kind, x, y, w, h)
	self.widgets:register(id, kind, x, y, w, h)
end

---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
function EditorOverlayPanel:isOver(id, x, y, w, h)
	return self.widgets:isOver(id, x, y, w, h)
end

---@param e gui.MouseDownEvent
function EditorOverlayPanel:onMouseDown(e)
	return self.widgets:onMouseDown(e)
end

---@param e gui.MouseUpEvent
function EditorOverlayPanel:onMouseUp(e)
	return self.widgets:onMouseUp(e)
end

---@param e gui.DragEvent
function EditorOverlayPanel:onDrag(e)
	return self.widgets:onDrag(e)
end

---@param e gui.DragEndEvent
function EditorOverlayPanel:onDragEnd(e)
	return self.widgets:onDragEnd(e)
end

---@param e gui.KeyDownEvent
function EditorOverlayPanel:onKeyDown(e)
	return self.widgets:onKeyDown(e)
end

---@param e gui.TextInputEvent
function EditorOverlayPanel:onTextInput(e)
	return self.widgets:onTextInput(e)
end

function EditorOverlayPanel:finishFrame()
	self.widgets:finishFrame()
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
	self.widgets:label(text, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
end

function EditorOverlayPanel:separator()
	self.cursorY = self.cursorY + 10
	self.widgets:separator(self.cursorX, self.cursorY, self.panelWidth)
	self.cursorY = self.cursorY + 10
end

---@param id string
---@param text string
---@param width number?
---@return boolean clicked
function EditorOverlayPanel:button(id, text, width)
	local clicked = self.widgets:button(id, text, self.cursorX, self.cursorY, width or self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return clicked
end

---@param id string
---@param text string
---@return boolean clicked
function EditorOverlayPanel:smallButton(id, text)
	local clicked = self.widgets:button(id, text, self.cursorX, self.cursorY, 90, self.lineHeight)
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
	local newValue = self.widgets:slider(id, value, minValue, maxValue, step, label, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
	self.cursorY = self.cursorY + self.lineHeight
	return newValue
end

---@param id string
---@param value string|number
---@param label string
---@return string
function EditorOverlayPanel:input(id, value, label)
	local newValue = self.widgets:input(id, tostring(value), label, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight)
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
	self.widgets:label(text, x, y, w, h, align)
end

---@param id string
---@param value boolean
---@param text string
---@return boolean
function EditorOverlayPanel:checkbox(id, value, text)
	local newValue = value
	if self.widgets:button(id, (value and "[x] " or "[ ] ") .. text, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight) then
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
	if self.widgets:button(id, value, self.cursorX, self.cursorY, self.panelWidth, self.lineHeight) then
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
	return self.widgets:consumeKey(key)
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
	return self.widgets:tabs(id, value, values, x, y, w, h)
end

return EditorOverlayPanel
