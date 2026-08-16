local Colors = require("ui.Colors")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.modals.chart_mutators.SelectedModifierList : gui.VirtualizedList
---@operator call: ui.modals.chart_mutators.SelectedModifierList
---@field model sphere.ModifierSelectModel
---@field active boolean
---@field background gui.NineSliceUsage
---@field on_change fun()?
local SelectedModifierList = VirtualizedList + {}

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
---@param on_change fun()?
function SelectedModifierList:new(model, on_change)
	VirtualizedList.new(self)
	self.model = model
	self.on_change = on_change
	self.active = false
	self.item_height = ROW_HEIGHT
	self.background = createBackground()
	self.header_font = Resources.getFont("bold", 24)
	self.item_font = Resources.getFont("medium", 18)
	self.value_font = Resources.getFont("regular", 16)
end

---@return integer
function SelectedModifierList:getItemCount()
	return #self.model.replayBase.modifiers
end

---@return number
function SelectedModifierList:getScrollViewportSize()
	return math.max(0, self.height - HEADER_HEIGHT - VERTICAL_PADDING)
end

---@return integer first_index
---@return integer last_index
function SelectedModifierList:getVisibleRowRange()
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
function SelectedModifierList:setActive(active)
	self.active = active
end

---@param direction integer
function SelectedModifierList:move(direction)
	self.model:scrollModifier(direction)
	self:scrollToSelection()
end

function SelectedModifierList:scrollToSelection()
	local top = (self.model.modifierIndex - 1) * self:getRowStep()
	local bottom = top + self.item_height
	local viewport = self:getScrollViewportSize()
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
function SelectedModifierList:onMouseClick(e)
	if self.drag_active or (e.button ~= 1 and e.button ~= 2) then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if not index then
		return
	end
	self.model.modifierIndex = index
	if e.button == 2 then
		self:activate()
	end
	return true
end

function SelectedModifierList:draw()
	Painter.setColorTable(Colors.panel)
	self.background:draw(self.width, self.height)

	local modifiers = self.model.replayBase.modifiers
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local y = HEADER_HEIGHT + (index - 1) * self:getRowStep() - scroll
		if index == self.model.modifierIndex then
			Painter.setColorTable(self.active and Colors.hover or Colors.elements)
			love.graphics.rectangle("fill", HORIZONTAL_PADDING, y, self.width - HORIZONTAL_PADDING * 2, self.item_height)
		end

		local config = modifiers[index]
		local name = ModifierRegistry:getName(config.id)
		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.item_font)
		love.graphics.print(name, HORIZONTAL_PADDING * 2, y + 8)

		local modifier = ModifierModel:getModifier(config.id)
		if modifier and modifier.values then
			Painter.setColorTable(Colors.text_muted)
			love.graphics.setFont(self.value_font)
			love.graphics.printf(tostring(config.value), HORIZONTAL_PADDING, y + 10, self.width - HORIZONTAL_PADDING * 3, "right")
		end
	end

	-- VirtualizedList clips the panel as a whole, so cover row fragments that
	-- extend into the fixed header and bottom padding.
	Painter.setColorTable(Colors.panel)
	love.graphics.rectangle("fill", HORIZONTAL_PADDING, VERTICAL_PADDING, self.width - HORIZONTAL_PADDING * 2, HEADER_HEIGHT - VERTICAL_PADDING)
	love.graphics.rectangle("fill", HORIZONTAL_PADDING, self.height - VERTICAL_PADDING, self.width - HORIZONTAL_PADDING * 2, VERTICAL_PADDING)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.header_font)
	love.graphics.print("Selected modifiers", HORIZONTAL_PADDING, 17)
	if #modifiers == 0 then
		Painter.setColorTable(Colors.text_muted)
		love.graphics.setFont(self.item_font)
		love.graphics.print("No modifiers selected", HORIZONTAL_PADDING * 2, HEADER_HEIGHT + 8)
	end
end

return SelectedModifierList
