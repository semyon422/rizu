local FlowContainer = require("gui.layout.FlowContainer")
local ScrollView = require("gui.ScrollView")
local FormSelection = require("ui.views.form.FormSelection")
local FormControl = require("ui.views.form.FormControl")
local View = require("gui.View")

---@class ui.views.form.Form.Config : gui.layout.FlowContainer.Config

---Owns form rows and coordinates which dropdown receives input.
---@class ui.views.form.Form : gui.View
---@operator call: ui.views.form.Form
---@overload fun(config: ui.views.form.Form.Config?): ui.views.form.Form
---@field rows gui.layout.FlowContainer
---@field selection ui.views.form.FormSelection
---@field active_dropdown ui.views.form.Dropdown?
---@field overlay gui.View?
---@field overlay_base_width number?
---@field overlay_base_height number?
---@field selected_index integer? Index into rows.children
---@field selected_control ui.views.form.FormControl?
local Form = View + {}

---@param config ui.views.form.Form.Config?
function Form:new(config)
	View.new(self)
	config = config or {}
	self.selection = FormSelection()
	View.add(self, self.selection)
	self.rows = FlowContainer(config)
	View.add(self, self.rows)
	self.active_dropdown = nil
	self.overlay = nil
	self.overlay_base_width = nil
	self.overlay_base_height = nil
	self.selected_index = nil
	self.selected_control = nil
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.keyboard_input_fallback = true
end

---Adds a row to the form's flow container.
---@generic T: gui.View
---@param row T
---@return T
function Form:add(row)
	local added = self.rows:add(row)
	if self.selected_control then
		self:syncSelection()
	end
	return added
end

---@generic T: gui.View
---@param index integer
---@param row T
---@return T
function Form:insert(index, row)
	local inserted = self.rows:insert(index, row)
	if self.selected_control then
		self:syncSelection()
	end
	return inserted
end

---@param row gui.View
function Form:remove(row)
	if row.parent == self then
		View.remove(self, row)
		if row == self.overlay then
			self.overlay = nil
			self:setSize(
				assert(self.overlay_base_width, "overlay has no base width"),
				assert(self.overlay_base_height, "overlay has no base height")
			)
			self.overlay_base_width = nil
			self.overlay_base_height = nil
		end
		return
	end

	local removed_index ---@type integer?
	for index, child in ipairs(self.rows.children) do
		if child == row then
			removed_index = index
			break
		end
	end
	assert(removed_index, "cannot remove a view that is not a form row")

	local had_selection = self.selected_control ~= nil
	local was_selected = self.selected_control == row
	if self.active_dropdown == row then
		self:closeActiveDropdown()
	end
	self.rows:remove(row)
	if was_selected then
		self.selected_control = nil
		self.selected_index = removed_index
	end
	if had_selection then
		self:syncSelection()
	end
end

---Adds an overlay such as a dropdown item panel above the rows.
---@generic T: gui.View
---@param overlay T
---@return T
function Form:addOverlay(overlay)
	assert(not self.overlay, "form already has an overlay")
	self.overlay = overlay
	self.overlay_base_width = self.offset_max[1] - self.offset_min[1]
	self.overlay_base_height = self.offset_max[2] - self.offset_min[2]
	self:setSize(
		math.max(self.overlay_base_width, overlay.offset_max[1]),
		math.max(self.overlay_base_height, overlay.offset_max[2])
	)
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

---@param row gui.View
---@return boolean selectable
local function canSelect(row)
	if FormControl * row then
		---@cast row ui.views.form.FormControl
		return row:canBeSelected()
	end
	return false
end

---@param control ui.views.form.FormControl
---@return boolean selected
function Form:selectControl(control)
	for index, row in ipairs(self.rows.children) do
		if row == control then
			if not canSelect(control) then
				return false
			end
			self.selected_index = index
			self.selected_control = control
			return true
		end
	end
	return false
end

function Form:clearSelection()
	self.selected_index = nil
	self.selected_control = nil
	self.selection:hide()
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

	self:clearSelection()

	local closed = self:closeActiveDropdown()
	if closed and e.target == self then
		return true
	end
end

---Keeps selection attached to the same control across row mutations. If the
---selected control became unavailable, selects the next control or the previous one.
---@return boolean has_selection
function Form:syncSelection()
	local rows = self.rows.children
	local selected = self.selected_control
	if selected then
		for index, row in ipairs(rows) do
			if row == selected and canSelect(row) then
				self.selected_index = index
				return true
			end
		end
	elseif not self.selected_index then
		return false
	end

	local start = math.min(self.selected_index or 1, #rows)
	for index = start, #rows do
		local view = rows[index]
		if canSelect(view) then
			---@cast view ui.views.form.FormControl
			self.selected_index = index
			self.selected_control = view
			return true
		end
	end
	for index = start - 1, 1, -1 do
		local view = rows[index]
		if canSelect(view) then
			---@cast view ui.views.form.FormControl
			self.selected_index = index
			self.selected_control = view
			return true
		end
	end
	self.selected_index = nil
	self.selected_control = nil
	return false
end

---@return gui.ScrollView? scroll_view
function Form:getScrollView()
	local parent = self.parent
	while parent and not (ScrollView * parent) do
		parent = parent.parent
	end
	---@cast parent gui.ScrollView?
	return parent
end

---@param control gui.View
---@param scroll_view gui.ScrollView
---@return boolean visible
local function isFullyVisibleInScrollView(control, scroll_view)
	local top_x, top_y = control.world_transform:transformPoint(0, 0)
	local bottom_x, bottom_y = control.world_transform:transformPoint(0, control.height)
	local _, local_top = scroll_view.world_transform:inverseTransformPoint(top_x, top_y)
	local _, local_bottom = scroll_view.world_transform:inverseTransformPoint(bottom_x, bottom_y)
	local top = math.min(local_top, local_bottom)
	local bottom = math.max(local_top, local_bottom)
	return top >= 0 and bottom <= scroll_view.height
end

---@param offset integer
---@return boolean selected
function Form:selectVisibleControl(offset)
	local scroll_view = self:getScrollView()
	if not scroll_view then
		return false
	end

	local rows = self.rows.children
	local index = offset > 0 and 1 or #rows
	local limit = offset > 0 and #rows or 1
	while offset > 0 and index <= limit or offset < 0 and index >= limit do
		local row = rows[index]
		if canSelect(row) and isFullyVisibleInScrollView(row, scroll_view) then
			---@cast row ui.views.form.FormControl
			self.selected_index = index
			self.selected_control = row
			return true
		end
		index = index + offset
	end
	return false
end

---@param view gui.View
---@param local_y number?
---@param height number?
---@return boolean scrolled
function Form:centerView(view, local_y, height)
	local scroll_view = self:getScrollView()
	if not scroll_view then
		return false
	end

	local_y = local_y or 0
	height = height or view.height
	local top_x, top_y = view.world_transform:transformPoint(0, local_y)
	local bottom_x, bottom_y = view.world_transform:transformPoint(0, local_y + height)
	local _, local_top = scroll_view.world_transform:inverseTransformPoint(top_x, top_y)
	local _, local_bottom = scroll_view.world_transform:inverseTransformPoint(bottom_x, bottom_y)
	local top = math.min(local_top, local_bottom)
	local bottom = math.max(local_top, local_bottom)
	if top >= 0 and bottom <= scroll_view.height then
		return false
	end

	local center = (top + bottom) / 2
	scroll_view:scrollTo(scroll_view:getScrollPosition() + center - scroll_view.height / 2)
	return true
end

---Centers the selected control when it falls outside an ancestor scroll viewport.
---@return boolean scrolled
function Form:centerSelectedControl()
	local selected = self.selected_control
	if not selected then
		return false
	end
	return self:centerView(selected)
end

---@param offset integer
---@return boolean moved
function Form:moveSelection(offset)
	local previous = self.selected_control
	local had_selection = self:syncSelection()
	local rows = self.rows.children
	local row_count = #rows
	if row_count == 0 then
		return false
	end
	if not had_selection and self:selectVisibleControl(offset) then
		return true
	end

	local index = had_selection and self.selected_index or (offset > 0 and 0 or row_count + 1)
	---@cast index integer
	for _ = 1, row_count do
		index = ((index - 1 + offset) % row_count) + 1
		local view = rows[index]
		if canSelect(rows[index]) then
			---@cast view ui.views.form.FormControl
			self.selected_index = index
			self.selected_control = view
			self:centerSelectedControl()
			return self.selected_control ~= previous
		end
	end
	return false
end

---@param e gui.KeyDownEvent
---@return boolean? handled
function Form:onKeyDown(e)
	if e.key == "escape" then
		return self:closeActiveDropdown()
	end

	local inputs = self.screen and self.screen.inputs
	if inputs and inputs.pointer_gesture and inputs.pointer_gesture.dragging then
		return false
	end

	local selected = self.selected_control
	if e.key == "return" or e.key == "kpenter" or e.key == "space" then
		return selected and selected:activate(e) or false
	end
	if selected and selected:onFormKeyDown(e) then
		return true
	end

	local offset = e.key == "down" and 1 or e.key == "up" and -1 or nil
	if not offset or not self:moveSelection(offset) then
		return false
	end
	if inputs and inputs.keyboard_focus then
		inputs:setKeyboardFocus(nil, {
			control = e.control_pressed,
			shift = e.shift_pressed,
			alt = e.alt_pressed,
			super = e.super_pressed,
		})
	end
	return true
end

function Form:updateSelection()
	self:syncSelection()
	local selected = self.selected_control
	if not selected then
		self.selection:hide()
		return
	end

	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = -math.huge, -math.huge
	local corners = {
		{0, 0},
		{selected.width, 0},
		{0, selected.height},
		{selected.width, selected.height},
	}
	for _, corner in ipairs(corners) do
		local world_x, world_y = selected.world_transform:transformPoint(corner[1], corner[2])
		local x, y = self.world_transform:inverseTransformPoint(world_x, world_y)
		min_x, min_y = math.min(min_x, x), math.min(min_y, y)
		max_x, max_y = math.max(max_x, x), math.max(max_y, y)
	end
	self.selection:moveToRect(min_x, min_y, max_x - min_x, max_y - min_y)
end

---@param dt number
function Form:update(dt)
	local dropdown = self.active_dropdown
	if dropdown and (dropdown.parent ~= self.rows or not dropdown:canBeSelected()) then
		self:closeActiveDropdown()
	end
	self:updateSelection()
end

return Form
