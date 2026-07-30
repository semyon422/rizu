local FlowContainer = require("gui.layout.FlowContainer")
local View = require("gui.View")

---@class ui.views.form.Form.Config : gui.layout.FlowContainer.Config

---Owns form rows and coordinates which dropdown receives input.
---@class ui.views.form.Form : gui.View
---@operator call: ui.views.form.Form
---@overload fun(config: ui.views.form.Form.Config?): ui.views.form.Form
---@field rows gui.layout.FlowContainer
---@field active_dropdown ui.views.form.Dropdown?
local Form = View + {}

---@param config ui.views.form.Form.Config?
function Form:new(config)
	View.new(self)
	config = config or {}
	self.rows = FlowContainer(config)
	View.add(self, self.rows)
	self.active_dropdown = nil
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.keyboard_input_fallback = true
end

---Adds a row to the form's flow container.
---@generic T: gui.View
---@param row T
---@return T
function Form:add(row)
	return self.rows:add(row)
end

---Adds an overlay such as a dropdown item panel above the rows.
---@generic T: gui.View
---@param overlay T
---@return T
function Form:addOverlay(overlay)
	return View.add(self, overlay)
end

---@return ui.views.form.Form
function Form:fitContent()
	self.rows:fitContent()
	self:setSize(
		self.rows.offset_max[1] - self.rows.offset_min[1],
		self.rows.offset_max[2] - self.rows.offset_min[2]
	)
	return self
end

---Makes a dropdown the sole input-active dropdown. The previous dropdown
---owns and performs its own closing animation.
---@param dropdown ui.views.form.Dropdown
---@return boolean activated
function Form:activateDropdown(dropdown)
	if self.active_dropdown == dropdown then
		return false
	end
	local previous = self.active_dropdown
	if previous then
		previous:close()
	end
	self.active_dropdown = dropdown
	return true
end

---@param dropdown ui.views.form.Dropdown
function Form:deactivateDropdown(dropdown)
	if self.active_dropdown == dropdown then
		self.active_dropdown = nil
	end
end

---@return boolean closed
function Form:closeActiveDropdown()
	local dropdown = self.active_dropdown
	if not dropdown then
		return false
	end
	return dropdown:close()
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function Form:onMouseDown(e)
	if e.button ~= 1 then
		return
	end
	if self.active_dropdown and self.active_dropdown:isMouseOver(e.x, e.y) then
		return
	end
	local closed = self:closeActiveDropdown()
	if closed and e.target == self then
		return true
	end
end

---@param e gui.ScrollEvent
function Form:onScroll(e)
	self:closeActiveDropdown()
end

---@param e gui.KeyDownEvent
---@return boolean? handled
function Form:onKeyDown(e)
	if e.key == "escape" then
		return self:closeActiveDropdown()
	end
end

return Form
