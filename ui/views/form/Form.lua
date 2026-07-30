local FlowContainer = require("gui.layout.FlowContainer")
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
---@field selected_index integer? Index into rows.children
---@field selected_control gui.View?
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
	return FormControl * row and row:canBeSelected()
end

---@param control gui.View
---@return boolean selected
function Form:selectControl(control)
	for index, row in ipairs(self.rows.children) do
		if row == control then
			if not canSelect(row) then
				return false
			end
			self.selected_index = index
			self.selected_control = row
			return true
		end
	end
	return false
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

	local row = e.target
	while row and row.parent ~= self.rows do
		row = row.parent
	end
	if row then
		self:selectControl(row)
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
		if canSelect(rows[index]) then
			self.selected_index = index
			self.selected_control = rows[index]
			return true
		end
	end
	for index = start - 1, 1, -1 do
		if canSelect(rows[index]) then
			self.selected_index = index
			self.selected_control = rows[index]
			return true
		end
	end
	self.selected_index = nil
	self.selected_control = nil
	return false
end

---Centers the selected control when it falls outside an ancestor scroll viewport.
---@return boolean scrolled
function Form:centerSelectedControl()
	local selected = self.selected_control
	if not selected then
		return false
	end

	local parent = self.parent
	while parent and not parent.is_scroll_view do
		parent = parent.parent
	end
	if not parent then
		return false
	end
	---@cast parent gui.ScrollView

	local top_x, top_y = selected.world_transform:transformPoint(0, 0)
	local bottom_x, bottom_y = selected.world_transform:transformPoint(0, selected.height)
	local _, local_top = parent.world_transform:inverseTransformPoint(top_x, top_y)
	local _, local_bottom = parent.world_transform:inverseTransformPoint(bottom_x, bottom_y)
	local top = math.min(local_top, local_bottom)
	local bottom = math.max(local_top, local_bottom)
	if top >= 0 and bottom <= parent.height then
		return false
	end

	local center = (top + bottom) / 2
	parent:scrollTo(parent:getScrollPosition() + center - parent.height / 2)
	return true
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

	local index = had_selection and self.selected_index or (offset > 0 and 0 or row_count + 1)
	---@cast index integer
	for _ = 1, row_count do
		index = ((index - 1 + offset) % row_count) + 1
		if canSelect(rows[index]) then
			self.selected_index = index
			self.selected_control = rows[index]
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

	local offset = e.key == "down" and 1 or e.key == "up" and -1 or nil
	if not offset or not self:moveSelection(offset) then
		return false
	end
	if self.screen and self.screen.inputs and self.screen.inputs.keyboard_focus then
		self.screen.inputs:setKeyboardFocus(nil, {
			control = e.control_pressed,
			shift = e.shift_pressed,
			alt = e.alt_pressed,
			super = e.super_pressed,
		})
	end
	return true
end

function Form:updateSelection()
	local selected = self.selected_control
	if not selected or not canSelect(selected) then
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

function Form:draw()
	self:updateSelection()
end

return Form
