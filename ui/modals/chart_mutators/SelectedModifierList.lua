local Colors = require("ui.Colors")
local FlowContainer = require("gui.layout.FlowContainer")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local ScrollView = require("gui.ScrollView")
local UiActions = require("ui.UiActions")
local View = require("gui.View")

local HEADER_HEIGHT = 62
local ROW_HEIGHT = 38
local HORIZONTAL_PADDING = 24
local VERTICAL_PADDING = 14
local TRANSITION_DURATION = 0.2

---@class ui.modals.chart_mutators.SelectedModifierRow : gui.View
---@operator call: ui.modals.chart_mutators.SelectedModifierRow
---@field list ui.modals.chart_mutators.SelectedModifierList
---@field config table
local SelectedModifierRow = View + {}

---@param list ui.modals.chart_mutators.SelectedModifierList
---@param config table
function SelectedModifierRow:new(list, config)
	View.new(self)
	self.list = list
	self.config = config
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self:setSize(0, ROW_HEIGHT)
end

---@param inputs gui.Inputs
function SelectedModifierRow:onHandleInputs(inputs)
	local index = self.list:getModifierIndex(self.config)
	if not self.list.active or index ~= self.list.model.modifierIndex then
		return
	end
	if inputs:consumeActionJustPressed(UiActions.left) then
		self.list:changeValue(-1)
	elseif inputs:consumeActionJustPressed(UiActions.right) then
		self.list:changeValue(1)
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function SelectedModifierRow:onMouseClick(e)
	if self.list.drag_active or (e.button ~= 1 and e.button ~= 2) then
		return
	end
	local index = self.list:getModifierIndex(self.config)
	if not index then
		return
	end
	self.list.model.modifierIndex = index
	if e.button == 2 then
		self.list:activate()
	else
		self.list:refreshItems()
		self.list:scrollToSelection()
	end
	return true
end

function SelectedModifierRow:draw()
	if self.mouse_over then
		Painter.setColorTable(Colors.elements)
		love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	end

	local name = ModifierRegistry:getName(self.config.id)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.list.item_font)
	love.graphics.print(name, HORIZONTAL_PADDING, 8)

	local modifier = ModifierModel:getModifier(self.config.id)
	if modifier and modifier.values then
		Painter.setColorTable(Colors.text_muted)
		love.graphics.setFont(self.list.value_font)
		love.graphics.printf(tostring(self.config.value), 0, 10, self.width - HORIZONTAL_PADDING, "right")
	end
end

---@class ui.modals.chart_mutators.ModifierInsertionCell : gui.View
---@operator call: ui.modals.chart_mutators.ModifierInsertionCell
---@field list ui.modals.chart_mutators.SelectedModifierList
local ModifierInsertionCell = View + {}

---@param list ui.modals.chart_mutators.SelectedModifierList
function ModifierInsertionCell:new(list)
	View.new(self)
	self.list = list
	self.handles_mouse_input = true
	self:setSize(0, ROW_HEIGHT)
end

---@param e gui.MouseClickEvent
---@return boolean?
function ModifierInsertionCell:onMouseClick(e)
	if e.button == 1 then
		return true
	end
end

function ModifierInsertionCell:draw()
	Painter.setColorTable(self.list.active and Colors.hover or Colors.elements)
	love.graphics.rectangle("fill", 0, 0, self.width, self.height)
	Painter.setColorTable(self.list.active and Colors.accent or Colors.text_muted)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", 0.5, 0.5, self.width - 1, self.height - 1)
	love.graphics.setFont(self.list.value_font)
	love.graphics.printf("Will be inserted here", 0, 10, self.width, "center")
end

---@class ui.modals.chart_mutators.SelectedModifierListChrome : gui.View
---@operator call: ui.modals.chart_mutators.SelectedModifierListChrome
---@field list ui.modals.chart_mutators.SelectedModifierList
---@field draw_title boolean
local SelectedModifierListChrome = View + {}

---@param list ui.modals.chart_mutators.SelectedModifierList
---@param draw_title boolean
function SelectedModifierListChrome:new(list, draw_title)
	View.new(self)
	self.list = list
	self.draw_title = draw_title
	self.handles_mouse_input = true
end

function SelectedModifierListChrome:draw()
	-- Keep scrolled rows out of the fixed chrome without covering the
	-- nine-slice frame drawn by the list itself.
	Painter.setColorTable(Colors.panel)
	local top = self.draw_title and VERTICAL_PADDING or 0
	love.graphics.rectangle("fill", HORIZONTAL_PADDING, top,
		math.max(0, self.width - HORIZONTAL_PADDING * 2), self.height - top)
	if self.draw_title then
		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.list.header_font)
		love.graphics.print("Selected modifiers", HORIZONTAL_PADDING, 17)
	end
end

---@class ui.modals.chart_mutators.SelectedModifierList : gui.ScrollView
---@operator call: ui.modals.chart_mutators.SelectedModifierList
---@field model sphere.ModifierSelectModel
---@field active boolean
---@field background gui.NineSliceUsage
---@field content gui.layout.FlowContainer
---@field insertion_cell ui.modals.chart_mutators.ModifierInsertionCell
---@field row_views ui.modals.chart_mutators.SelectedModifierRow[]
---@field on_change fun()?
local SelectedModifierList = ScrollView + {}

local function createBackground()
	local sprites = Resources.sprites
	return NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})
end

---@param model sphere.ModifierSelectModel
---@param on_change fun()?
function SelectedModifierList:new(model, on_change)
	local content = FlowContainer({
		direction = "column",
		padding = {HORIZONTAL_PADDING, HEADER_HEIGHT, HORIZONTAL_PADDING, VERTICAL_PADDING},
		layout_transition = {duration = TRANSITION_DURATION, easing = "OutQuint"},
	})
	ScrollView.new(self, content)
	self.model = model
	self.on_change = on_change
	self.active = false
	self.background = createBackground()
	self.header_font = Resources.getFont("bold", 24)
	self.item_font = Resources.getFont("medium", 18)
	self.value_font = Resources.getFont("regular", 16)
	self.row_views = {}
	self.insertion_cell = ModifierInsertionCell(self)
	self:refreshItems()

	local header = self:add(SelectedModifierListChrome(self, true))
	header:anchorPercent(0, 0, 1, 0):setHeight(HEADER_HEIGHT)
	local footer = self:add(SelectedModifierListChrome(self, false))
	footer:anchorPercent(0, 1, 1, 1):setHeight(VERTICAL_PADDING):setAlignmentY(1)
end

---@param config table
---@return integer?
function SelectedModifierList:getModifierIndex(config)
	for index, modifier in ipairs(self.model.replayBase.modifiers) do
		if modifier == config then
			return index
		end
	end
end

function SelectedModifierList:updateItemWidths()
	local width = math.max(0, self.width - HORIZONTAL_PADDING * 2)
	self.insertion_cell:setSize(width, ROW_HEIGHT)
	for _, row in ipairs(self.row_views) do
		row:setSize(width, ROW_HEIGHT)
	end
	self.content:fitContent()
end

---Synchronizes ordinary row views with the modifier table and moves the
---insertion cell without recreating unaffected rows.
function SelectedModifierList:refreshItems()
	local modifiers = self.model.replayBase.modifiers
	self.model.modifierIndex = math.max(1, math.min(self.model.modifierIndex, #modifiers + 1))

	---@type {[table]: ui.modals.chart_mutators.SelectedModifierRow}
	local existing = {}
	for _, row in ipairs(self.row_views) do
		existing[row.config] = row
	end

	---@type ui.modals.chart_mutators.SelectedModifierRow[]
	local rows = {}
	---@type gui.View[]
	local desired = {}
	for index, config in ipairs(modifiers) do
		if index == self.model.modifierIndex then
			desired[#desired + 1] = self.insertion_cell
		end
		local row = existing[config] or SelectedModifierRow(self, config)
		existing[config] = nil
		rows[#rows + 1] = row
		desired[#desired + 1] = row
	end
	if self.model.modifierIndex == #modifiers + 1 then
		desired[#desired + 1] = self.insertion_cell
	end

	for _, row in pairs(existing) do
		self.content:remove(row)
	end
	for index, view in ipairs(desired) do
		if view.parent == self.content then
			self.content:move(view, index)
		else
			self.content:insert(index, view)
		end
	end
	self.row_views = rows
	self:updateItemWidths()
end

---@param old_x number
---@param old_y number
---@param old_width number
---@param old_height number
function SelectedModifierList:onLayoutChanged(old_x, old_y, old_width, old_height)
	self:updateItemWidths()
end

---@param active boolean
function SelectedModifierList:setActive(active)
	self.active = active
end

---@param direction integer
function SelectedModifierList:move(direction)
	self.model:scrollModifier(direction)
	self:refreshItems()
	self:scrollToSelection()
end

function SelectedModifierList:scrollToSelection()
	local top = (self.model.modifierIndex - 1) * ROW_HEIGHT
	local bottom = top + ROW_HEIGHT
	local viewport = math.max(0, self.height - HEADER_HEIGHT - VERTICAL_PADDING)
	if top < self.scroll_target then
		self:scrollTo(top)
	elseif bottom > self.scroll_target + viewport then
		self:scrollTo(bottom - viewport)
	end
end

function SelectedModifierList:activate()
	if not self.model.replayBase.modifiers[self.model.modifierIndex] then
		return
	end
	self.model:remove(self.model.modifierIndex)
	self:refreshItems()
	self:scrollTo(self.scroll_target)
	if self.on_change then
		self.on_change()
	end
end

---@param direction integer
---@return boolean changed
function SelectedModifierList:changeValue(direction)
	local config = self.model.replayBase.modifiers[self.model.modifierIndex]
	if not config then
		return false
	end
	local modifier = ModifierModel:getModifier(config.id)
	if not modifier or not modifier.values or #modifier.values == 0 then
		return false
	end

	local previous_value = config.value
	ModifierModel:increaseModifierValue(config, direction)
	if config.value == previous_value then
		return false
	end
	self.model:change()
	if self.on_change then
		self.on_change()
	end
	return true
end

---@param screen_x number
---@param screen_y number
---@return integer?
function SelectedModifierList:getIndexAt(screen_x, screen_y)
	local x, y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	if x < 0 or x >= self.width or y < HEADER_HEIGHT or y >= self.height - VERTICAL_PADDING then
		return nil
	end
	for index, row in ipairs(self.row_views) do
		if row:isMouseOver(screen_x, screen_y) then
			return index
		end
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function SelectedModifierList:onMouseClick(e)
	if self.drag_active or e.button ~= 1 then
		return
	end
	local x, y = self.world_transform:inverseTransformPoint(e.x, e.y)
	if x < 0 or x >= self.width or y < HEADER_HEIGHT or y >= self.height - VERTICAL_PADDING then
		return
	end
	self.model.modifierIndex = #self.model.replayBase.modifiers + 1
	self:refreshItems()
	self:scrollToSelection()
	return true
end

---@param dt number
function SelectedModifierList:update(dt)
	ScrollView.update(self, dt)
end

function SelectedModifierList:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)
end

return SelectedModifierList
