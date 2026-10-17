local Label = require("ui.views.Label")
local NineSlice = require("gui.NineSlice")
local Resources = require("ui.Resources")

---@class ui.views.WindowHeader : gui.NineSlice
---@operator call: ui.views.WindowHeader
---@field window ui.views.Window
---@field title ui.views.Label
local WindowHeader = NineSlice + {}

local DEFAULT_HEIGHT = 56
local PADDING_X = 20

---@param window ui.views.Window
---@param title string?
---@param height number?
function WindowHeader:new(window, title, height)
	NineSlice.new(self, Resources.nine_slices.window_header)
	self.window = window
	height = height or DEFAULT_HEIGHT
	self:anchorFixed(0, 0, 0, height):fillWidth(0, 0)
	self:setLayoutIgnore(true)
	self.handles_mouse_input = true

	self.title = self:add(Label({
		font_name = "bold",
		font_size = 24,
		text = title or "",
	}))
	self.title:setAlignmentY(0.5):addPosition(PADDING_X, 0)
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function WindowHeader:onMouseDown(e)
	if e.button == 1 then
		return true
	end
end

---@param e gui.MouseUpEvent
---@return boolean? handled
function WindowHeader:onMouseUp(e)
	if e.button == 1 then
		return true
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function WindowHeader:onMouseClick(e)
	if e.button == 1 then
		return true
	end
end

---@param e gui.DragStartEvent
---@return boolean? handled
function WindowHeader:onDragStart(e)
	if e.button ~= 1 then
		return
	end
	self.window:beginDrag(e)
	return true
end

---@param e gui.DragEvent
---@return boolean? handled
function WindowHeader:onDrag(e)
	if e.button ~= 1 then
		return
	end
	self.window:drag(e)
	return true
end

---@param e gui.DragEndEvent
---@return boolean? handled
function WindowHeader:onDragEnd(e)
	if e.button ~= 1 then
		return
	end
	self.window:endDrag()
	return true
end

return WindowHeader
