local class = require("class")
local EditorControlRenderer = require("yi.views.editor.EditorControlRenderer")
local EditorControls = require("yi.views.editor.EditorControls")
local math_util = require("math_util")

---@class yi.views.editor.EditorWidgets
---@operator call: yi.views.editor.EditorWidgets
---@field controls yi.views.editor.EditorControls
---@field renderer yi.views.editor.EditorControlRenderer
---@field editValues {[string]: string}
local EditorWidgets = class()

function EditorWidgets:new()
	self.controls = EditorControls()
	self.renderer = EditorControlRenderer()
	self.editValues = {}
end

---@param value number
---@return number
function EditorWidgets.clamp01(value)
	return EditorControls.clamp01(value)
end

---@param screen_x number
---@param screen_y number
---@return boolean
function EditorWidgets:containsPoint(screen_x, screen_y)
	return self.controls:containsPoint(screen_x, screen_y)
end

---@param id string
---@param x number
---@param y number
---@return boolean
function EditorWidgets:contains(id, x, y)
	return self.controls:contains(self.controls.controls[id], x, y)
end

---@param x number
---@param y number
---@return yi.views.editor.EditorControlRect?
function EditorWidgets:getControlAt(x, y)
	return self.controls:getControlAt(x, y)
end

---@param id string
---@param kind string
---@param x number
---@param y number
---@param w number
---@param h number
function EditorWidgets:register(id, kind, x, y, w, h)
	self.controls:register(id, kind, x, y, w, h)
end

---@param id string
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean
function EditorWidgets:isOver(id, x, y, w, h)
	self:register(id, self.controls.controls[id] and self.controls.controls[id].kind or "button", x, y, w, h)
	return self.controls:isMouseOver(id)
end

---@param id string
---@return boolean
function EditorWidgets:isMouseOver(id)
	return self.controls:isMouseOver(id)
end

---@param id string
---@return boolean
function EditorWidgets:isActive(id)
	return self.controls.activeId == id
end

---@return boolean
function EditorWidgets:hasActive()
	return self.controls.activeId ~= nil
end

---@param id string?
function EditorWidgets:setActive(id)
	self.controls.activeId = id
end

---@param active boolean
---@param hovered boolean
function EditorWidgets:setButtonColor(active, hovered)
	self.renderer:setButtonColor(active, hovered)
end

---@param e gui.MouseDownEvent
function EditorWidgets:onMouseDown(e)
	return self.controls:beginPress(e) ~= nil
end

---@param e gui.MouseUpEvent
function EditorWidgets:onMouseUp(e)
	return self.controls:endPress(e) ~= nil
end

---@param e gui.MouseUpEvent
---@return string? clickedId
function EditorWidgets:endPress(e)
	return self.controls:endPress(e)
end

---@param e gui.DragEvent
function EditorWidgets:onDrag(e)
	return self.controls:drag(e) ~= nil
end

---@param e gui.DragEndEvent
function EditorWidgets:onDragEnd(e)
	return self:onDrag(e)
end

---@param e gui.KeyDownEvent
function EditorWidgets:onKeyDown(e)
	self.controls:onKeyDown(e)

	local id = self.controls.focusedId
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
		self.controls.focusedId = nil
		return true
	end
end

---@param e gui.TextInputEvent
function EditorWidgets:onTextInput(e)
	local id = self.controls.focusedId
	if not id then
		return
	end
	self.editValues[id] = (self.editValues[id] or "") .. e.key
	return true
end

function EditorWidgets:finishFrame()
	self.controls:finishFrame()
end

---@param key string
---@return boolean
function EditorWidgets:consumeKey(key)
	return self.controls:consumeKey(key)
end

---@param id string
---@return boolean
function EditorWidgets:clicked(id)
	return self.controls.clicked[id] or false
end

---@param id string
---@return number?
function EditorWidgets:getDragFraction(id)
	return self.controls.dragged[id]
end

---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@param align string?
function EditorWidgets:label(text, x, y, w, h, align)
	self.renderer:label(text, x, y, w, h, align)
end

---@param id string
---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@return boolean clicked
function EditorWidgets:button(id, text, x, y, w, h)
	self:register(id, "button", x, y, w, h)
	self.renderer:button(text, x, y, w, h, self.controls.activeId == id, self.controls:isMouseOver(id))
	return self:clicked(id)
end

---@param id string
---@param value number
---@param minValue number
---@param maxValue number
---@param step number?
---@param text string
---@param x number
---@param y number
---@param w number
---@param h number
---@return number
function EditorWidgets:slider(id, value, minValue, maxValue, step, text, x, y, w, h)
	self:register(id, "slider", x, y, w, h)
	local fraction = self:getDragFraction(id)
	if fraction then
		value = math_util.map(fraction, 0, 1, minValue, maxValue)
		if step then
			value = math.floor(value / step + 0.5) * step
		end
	end

	local normalized = (value - minValue) / (maxValue - minValue)
	self.renderer:slider(text, x, y, w, h, self.controls.activeId == id, self.controls:isMouseOver(id), normalized)
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
function EditorWidgets:input(id, value, placeholder, x, y, w, h)
	if self.controls.focusedId ~= id then
		self.editValues[id] = value
	end

	self:register(id, "input", x, y, w, h)
	self.renderer:input(
		self.editValues[id] or placeholder,
		x,
		y,
		w,
		h,
		self.controls.focusedId == id,
		self.controls:isMouseOver(id)
	)
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
function EditorWidgets:tabs(id, value, values, x, y, w, h)
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

---@param x number
---@param y number
---@param w number
function EditorWidgets:separator(x, y, w)
	self.renderer:separator(x, y, w)
end

---@param x number
---@param y number
---@param w number
---@param h number
function EditorWidgets:panelBackground(x, y, w, h)
	self.renderer:panelBackground(x, y, w, h)
end

return EditorWidgets
