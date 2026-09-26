local View = require("gui.View")
local ScrollView = require("gui.ScrollView")
local WindowBackground = require("ui.views.WindowBackground")
local WindowHeader = require("ui.views.WindowHeader")

---@class ui.views.Window : gui.View
---@operator call: ui.views.Window
---@field header ui.views.WindowHeader
---@field background ui.views.WindowBackground
---@field drag_active boolean
---@field private drag_start_x number
---@field private drag_start_y number
---@field private drag_origin_x number
---@field private drag_origin_y number
---@field content_view gui.View
---@field scroll_view gui.ScrollView
---@field inactive_opacity number?
---@field private opacity_target number?
local Window = View + {}

local HEADER_HEIGHT = 56
local INACTIVE_FADE_DURATION = 0.15

---@param title string?
---@param width number?
---@param height number?
function Window:new(title, width, height)
	View.new(self)
	width = width or 640
	height = height or 420
	assert(width >= 0 and height >= HEADER_HEIGHT, "window height must include its header")
	self:setSize(width, height)
	self:setClip(true)
	self.handles_mouse_input = true
	self.drag_active = false
	self.inactive_opacity = nil
	self.opacity_target = nil

	self.background = self:add(WindowBackground())
	self.background:anchorFill(0, HEADER_HEIGHT, 0, 0)
	self.header = self:add(WindowHeader(self, title, HEADER_HEIGHT))

	self.content_view = self:add(View())
	self.content_view:anchorFill(20, HEADER_HEIGHT + 16, 20, 16)
	self.content_view:setClip(true)
	self.scroll_view = self.content_view:add(ScrollView())
	self.scroll_view:anchorFill(0, 0, 0, 0)
	self.scroll_view.content:anchorFixed(0, 0, width - 40, 0)
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function Window:onMouseDown(e)
	if e.button == 1 then
		return true
	end
end

---@param e gui.MouseUpEvent
---@return boolean? handled
function Window:onMouseUp(e)
	if e.button == 1 then
		return true
	end
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function Window:onMouseClick(e)
	if e.button == 1 then
		return true
	end
end

---@param e gui.ScrollEvent
---@return boolean
function Window:onScroll(e)
	return true
end

---@param screen_x number
---@param screen_y number
---@return number x
---@return number y
local function toParentSpace(self, screen_x, screen_y)
	local parent = self.parent
	if parent then
		return parent.world_transform:inverseTransformPoint(screen_x, screen_y)
	end
	return screen_x, screen_y
end

---@param e gui.DragStartEvent
function Window:beginDrag(e)
	local start_x, start_y = toParentSpace(self, e.press_x or e.x, e.press_y or e.y)
	self.drag_active = true
	self.drag_start_x = start_x
	self.drag_start_y = start_y
	self.drag_origin_x = self.offset_x
	self.drag_origin_y = self.offset_y
end

---@param e gui.DragEvent
function Window:drag(e)
	if not self.drag_active then
		return
	end
	local x, y = toParentSpace(self, e.x, e.y)
	self:setOffset(
		self.drag_origin_x + x - self.drag_start_x,
		self.drag_origin_y + y - self.drag_start_y
	)
end

function Window:endDrag()
	self.drag_active = false
end

---@param opacity number?
---@return ui.views.Window
function Window:setInactiveOpacity(opacity)
	assert(opacity == nil or (type(opacity) == "number" and opacity >= 0 and opacity <= 1),
		"inactive opacity must be between 0 and 1 or nil")
	self.inactive_opacity = opacity
	self.opacity_target = nil
	return self
end

---@param dt number
function Window:update(dt)
	local inactive_opacity = self.inactive_opacity
	local inputs = self.screen and self.screen.inputs
	if not inputs then
		return
	end

	local target = 1
	if inactive_opacity then
		local mouse_x, mouse_y = inputs.mouse_x, inputs.mouse_y
		local mouse_over = self:isMouseOver(mouse_x, mouse_y)
		local clip_rect = self.clip_rect
		if mouse_over and clip_rect then
			mouse_over = clip_rect[3] > 0 and clip_rect[4] > 0
				and mouse_x >= clip_rect[1] and mouse_x <= clip_rect[1] + clip_rect[3]
				and mouse_y >= clip_rect[2] and mouse_y <= clip_rect[2] + clip_rect[4]
		end
		target = mouse_over and 1 or inactive_opacity
	end
	if target == self.opacity_target then
		return
	end
	self.opacity_target = target
	if self.opacity ~= target then
		self:fadeTo(target, INACTIVE_FADE_DURATION, "OutQuad")
	end
end

---@generic T: gui.View
---@param child T
---@return T
function Window:addContent(child)
	return self.scroll_view.content:add(child)
end

---@param height number
---@return ui.views.Window
function Window:setContentHeight(height)
	self.scroll_view.content:setHeight(height)
	return self
end

return Window
