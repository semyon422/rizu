local FlowContainer = require("gui.layout.FlowContainer")
local ScrollView = require("gui.ScrollView")
local FormControl = require("ui.views.form.FormControl")
local FormNavigation = require("ui.views.form.FormNavigation")
local UiActions = require("ui.UiActions")
local View = require("gui.View")

---@class ui.views.form.Form.Config : gui.layout.FlowContainer.Config

---Owns form rows and coordinates which dropdown receives input.
---@class ui.views.form.Form : gui.View
---@operator call: ui.views.form.Form
---@overload fun(config: ui.views.form.Form.Config?): ui.views.form.Form
---@field rows gui.layout.FlowContainer
---@field selection_visible boolean
---@field selection_target_x number?
---@field selection_target_y number?
---@field selection_target_width number?
---@field selection_target_height number?
---@field active_dropdown ui.views.form.Dropdown?
---@field selected_index integer? Index into rows.children
---@field selected_control ui.views.form.FormControl?
---@field navigation ui.views.form.FormNavigation
---@field items_revision integer Incremented whenever form rows change.
---@field private navigation_mouse_x number?
---@field private navigation_mouse_y number?
local Form = View + {}

---@param config ui.views.form.Form.Config?
function Form:new(config)
	View.new(self)
	config = config or {}
	self.selection_visible = false
	self.selection_target_x = nil
	self.selection_target_y = nil
	self.selection_target_width = nil
	self.selection_target_height = nil
	self.rows = FlowContainer(config)
	View.add(self, self.rows)
	self.active_dropdown = nil
	self.selected_index = nil
	self.selected_control = nil
	self.navigation = FormNavigation.Mouse
	self.items_revision = 0
	self.navigation_mouse_x = nil
	self.navigation_mouse_y = nil
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
	self.items_revision = self.items_revision + 1
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
	self.items_revision = self.items_revision + 1
	if self.selected_control then
		self:syncSelection()
	end
	return inserted
end

---@param row gui.View
function Form:remove(row)
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
	self.items_revision = self.items_revision + 1
	if was_selected then
		self.selected_control = nil
		self.selected_index = removed_index
	end
	if had_selection then
		self:syncSelection()
	end
end

---Removes all form rows and invalidates selection geometry.
function Form:clearRows()
	if #self.rows.children == 0 then
		return
	end
	self.rows:clear()
	self.items_revision = self.items_revision + 1
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
	self:selectControl(dropdown)
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
	self.selection_visible = false
end

---@param navigation ui.views.form.FormNavigation
function Form:setNavigation(navigation)
	self.navigation = navigation
	local inputs = self.screen and self.screen.inputs
	if inputs then
		self.navigation_mouse_x = inputs.mouse_x
		self.navigation_mouse_y = inputs.mouse_y
	end
end

---@param e gui.MouseDownEvent
---@return boolean? handled
function Form:onMouseDown(e)
	self:setNavigation(FormNavigation.Mouse)
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

---@return boolean selected
function Form:selectMiddleControl()
	local scroll_view = self:getScrollView()
	local center_y = self.screen and self.screen.height / 2 or self.height / 2
	if scroll_view then
		local _, top = scroll_view.world_transform:transformPoint(0, 0)
		local _, bottom = scroll_view.world_transform:transformPoint(0, scroll_view.height)
		center_y = (top + bottom) / 2
	end

	local best_index ---@type integer?
	local best_distance = math.huge
	for index, row in ipairs(self.rows.children) do
		if canSelect(row) and (not scroll_view or isFullyVisibleInScrollView(row, scroll_view)) then
			local _, top = row.world_transform:transformPoint(0, 0)
			local _, bottom = row.world_transform:transformPoint(0, row.height)
			local distance = math.abs((top + bottom) / 2 - center_y)
			if distance < best_distance then
				best_index = index
				best_distance = distance
			end
		end
	end
	if not best_index then
		return false
	end
	local selected = self.rows.children[best_index]
	---@cast selected ui.views.form.FormControl
	self.selected_index = best_index
	self.selected_control = selected
	return true
end

---@param mouse_x number
---@param mouse_y number
---@return boolean selected
function Form:selectHoveredControl(mouse_x, mouse_y)
	local dropdown = self.active_dropdown
	if dropdown then
		if dropdown.items then
			dropdown.items:focusMousePosition(mouse_x, mouse_y)
		end
		return self:selectControl(dropdown)
	end
	for index, row in ipairs(self.rows.children) do
		if canSelect(row) and row:isMouseOver(mouse_x, mouse_y) then
			local clip = row.clip_rect
			if not clip or clip[3] > 0 and clip[4] > 0
				and mouse_x >= clip[1] and mouse_x <= clip[1] + clip[3]
				and mouse_y >= clip[2] and mouse_y <= clip[2] + clip[4]
			then
				---@cast row ui.views.form.FormControl
				self.selected_index = index
				self.selected_control = row
				return true
			end
		end
	end
	return false
end

---@return boolean entered
function Form:startKeyboardNavigation()
	if self.navigation == FormNavigation.Keyboard then
		return false
	end
	self:setNavigation(FormNavigation.Keyboard)
	local inputs = self.screen and self.screen.inputs
	if not inputs or not self:selectHoveredControl(inputs.mouse_x, inputs.mouse_y) then
		self:selectMiddleControl()
	end
	return true
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
	local inputs = self.screen and self.screen.inputs
	if inputs and inputs.pointer_gesture and inputs.pointer_gesture.dragging then
		return false
	end
	local entered_keyboard_navigation = self:startKeyboardNavigation()

	if e.key == "escape" then
		return self:closeActiveDropdown()
	end

	local selected = self.selected_control
	if selected and selected:onFormKeyDown(e) then
		return true
	end

	local offset = e.key == "down" and 1 or e.key == "up" and -1 or nil
	if not offset then
		return false
	end
	if entered_keyboard_navigation then
		if not self.selected_control then
			return false
		end
	elseif not self:moveSelection(offset) then
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

---@param inputs gui.Inputs
function Form:onHandleInputs(inputs)
	local selected = self.selected_control
	if not selected or not inputs:consumeActionJustPressed(UiActions.accept) then
		return
	end
	selected:activate({
		control_pressed = false,
		shift_pressed = false,
		alt_pressed = false,
		super_pressed = false,
	})
end

function Form:updateSelection()
	self:syncSelection()
	local inputs = self.screen and self.screen.inputs
	if self.navigation == FormNavigation.Mouse and inputs then
		self:selectHoveredControl(inputs.mouse_x, inputs.mouse_y)
	end
	if not self.selected_control then
		self:selectMiddleControl()
	end
	local selected = self.selected_control
	if not selected then
		self.selection_visible = false
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

	self.selection_target_x = min_x
	self.selection_target_y = min_y
	self.selection_target_width = max_x - min_x
	self.selection_target_height = max_y - min_y
	self.selection_visible = true
end

---@param dt number
function Form:update(dt)
	local inputs = self.screen and self.screen.inputs
	if inputs then
		local mouse_x, mouse_y = inputs.mouse_x, inputs.mouse_y
		if self.navigation_mouse_x ~= nil
			and (mouse_x ~= self.navigation_mouse_x or mouse_y ~= self.navigation_mouse_y)
		then
			self:setNavigation(FormNavigation.Mouse)
		end
		self.navigation_mouse_x = mouse_x
		self.navigation_mouse_y = mouse_y
	end

	local dropdown = self.active_dropdown
	if dropdown and (dropdown.parent ~= self.rows or not dropdown:canBeSelected()) then
		self:closeActiveDropdown()
	end
	self:updateSelection()
end

return Form
