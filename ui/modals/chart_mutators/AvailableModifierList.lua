local Colors = require("ui.Colors")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.modals.chart_mutators.AvailableModifierList : gui.VirtualizedList
---@operator call: ui.modals.chart_mutators.AvailableModifierList
---@field model sphere.ModifierSelectModel
---@field active boolean
---@field selection_visible boolean
---@field background gui.NineSliceUsage
---@field on_add fun()?
local AvailableModifierList = VirtualizedList + {}

local HEADER_HEIGHT = 62
local ROW_HEIGHT = 38
local HORIZONTAL_PADDING = 24
local VERTICAL_PADDING = 14

local function createBackground()
	local sprites = Resources.sprites
	return NineSliceUsage({
		sprites.nineslice_modal_lt, sprites.nineslice_modal_t, sprites.nineslice_modal_rt,
		sprites.nineslice_modal_l, sprites.nineslice_modal_c, sprites.nineslice_modal_r,
		sprites.nineslice_modal_lb, sprites.nineslice_modal_b, sprites.nineslice_modal_rb,
	})
end

---@param model sphere.ModifierSelectModel
---@param on_add fun()?
function AvailableModifierList:new(model, on_add)
	VirtualizedList.new(self)
	self.model = model
	self.on_add = on_add
	self.active = true
	self.selection_visible = true
	self.item_height = ROW_HEIGHT
	self.background = createBackground()
	self.header_font = Resources.getFont("bold", 24)
	self.item_font = Resources.getFont("medium", 18)
end

---@return integer
function AvailableModifierList:getItemCount()
	return #ModifierRegistry.list
end

---@return number
function AvailableModifierList:getScrollViewportSize()
	return math.max(0, self.height - HEADER_HEIGHT - VERTICAL_PADDING)
end

---@return integer first_index
---@return integer last_index
function AvailableModifierList:getVisibleRowRange()
	local count = self:getItemCount()
	if count == 0 then
		return 1, 0
	end
	local scroll = self:getVisualScrollPosition()
	local viewport = self:getScrollViewportSize()
	local first_index = math.max(1, math.floor(scroll / self:getRowStep()) + 1)
	local last_index = math.min(count, math.floor((scroll + viewport) / self:getRowStep()) + 1)
	return first_index, last_index
end

---@param active boolean
function AvailableModifierList:setActive(active)
	self.active = active
end

---@param visible boolean
function AvailableModifierList:setSelectionVisible(visible)
	self.selection_visible = visible
end

---@param direction integer
function AvailableModifierList:move(direction)
	self.model:scrollAvailableModifier(direction)
	self:scrollToSelection()
end

function AvailableModifierList:scrollToSelection()
	local top = (self.model.availableModifierIndex - 1) * self:getRowStep()
	local bottom = top + self.item_height
	local viewport = self:getScrollViewportSize()
	if top < self.scroll_target then
		self:scrollTo(top)
	elseif bottom > self.scroll_target + viewport then
		self:scrollTo(bottom - viewport)
	end
end

function AvailableModifierList:activate()
	local name = ModifierRegistry.list[self.model.availableModifierIndex]
	if not name then
		return
	end
	self.model:add(name)
	if self.on_add then
		self.on_add()
	end
end

---@param screen_x number
---@param screen_y number
---@return integer?
function AvailableModifierList:getIndexAt(screen_x, screen_y)
	local x, local_y = self.world_transform:inverseTransformPoint(screen_x, screen_y)
	local y = local_y - HEADER_HEIGHT
	if x < 0 or x >= self.width or y < 0 or y >= self:getScrollViewportSize() then
		return nil
	end
	local index = math.floor((y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if index > self:getItemCount() then
		return nil
	end
	return index
end

---@param e gui.MouseClickEvent
---@return boolean?
function AvailableModifierList:onMouseClick(e)
	if e.button ~= 1 or self.drag_active then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if not index then
		return
	end
	self.model.availableModifierIndex = index
	self:activate()
	return true
end

function AvailableModifierList:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)

	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local y = HEADER_HEIGHT + (index - 1) * self:getRowStep() - scroll
		if self.selection_visible and index == self.model.availableModifierIndex then
			Painter.setColorTable(self.active and Colors.surface_raised or Colors.surface)
			love.graphics.rectangle("fill", HORIZONTAL_PADDING, y, self.width - HORIZONTAL_PADDING * 2, self.item_height)
		end

		local name = ModifierRegistry.list[index]
		local unavailable = self.model:isOneUse(name) and self.model:isAdded(name)
		Painter.setColorTable(unavailable and Colors.muted or Colors.text)
		love.graphics.setFont(self.item_font)
		love.graphics.print(name, HORIZONTAL_PADDING * 2, y + 8)
	end

	-- VirtualizedList clips the panel as a whole, so cover row fragments that
	-- extend into the fixed header and bottom padding.
	Painter.setColorTable(Colors.panel)
	love.graphics.rectangle("fill", HORIZONTAL_PADDING, VERTICAL_PADDING, self.width - HORIZONTAL_PADDING * 2, HEADER_HEIGHT - VERTICAL_PADDING)
	love.graphics.rectangle("fill", HORIZONTAL_PADDING, self.height - VERTICAL_PADDING, self.width - HORIZONTAL_PADDING * 2, VERTICAL_PADDING)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.header_font)
	love.graphics.print("Available modifiers", HORIZONTAL_PADDING, 17)
end

return AvailableModifierList
