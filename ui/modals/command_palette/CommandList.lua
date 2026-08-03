local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local VirtualizedList = require("gui.VirtualizedList")

---@class ui.modals.command_palette.CommandList : gui.VirtualizedList
---@operator call: ui.modals.command_palette.CommandList
---@field candidates table[]
---@field selected_index integer
---@field hover_index integer?
---@field on_select fun(index: integer)
---@field on_confirm fun(index: integer)
local CommandList = VirtualizedList + {}

local ITEM_HEIGHT = 58
local TEXT_X = 14

---@param on_select fun(index: integer)
---@param on_confirm fun(index: integer)
function CommandList:new(on_select, on_confirm)
	VirtualizedList.new(self)
	self.item_height = ITEM_HEIGHT
	self.candidates = {}
	self.selected_index = 1
	self.hover_index = nil
	self.on_select = on_select
	self.on_confirm = on_confirm
	self.title_font = Resources.getFont("medium", 18)
	self.description_font = Resources.getFont("regular", 14)
end

---@return integer count
function CommandList:getItemCount()
	return #self.candidates
end

---@param candidates table[]
function CommandList:setCandidates(candidates)
	self.candidates = candidates
	self.selected_index = math.max(1, math.min(self.selected_index, math.max(1, #candidates)))
	self:scrollTo(self.scroll_target)
end

---@param index integer
function CommandList:setSelectedIndex(index)
	if #self.candidates == 0 then
		self.selected_index = 1
		return
	end
	self.selected_index = math.max(1, math.min(index, #self.candidates))
	local top = (self.selected_index - 1) * self:getRowStep()
	local bottom = top + self.item_height
	if top < self.scroll_target or bottom > self.scroll_target + self.height then
		self:scrollTo(top + self.item_height / 2 - self.height / 2)
	end
end

---@return integer? index
function CommandList:getIndexAt(screen_x, screen_y)
	local local_y = self:getLocalY(screen_x, screen_y)
	if local_y < 0 or local_y >= self.height then
		return nil
	end
	local index = math.floor((local_y + self:getVisualScrollPosition()) / self:getRowStep()) + 1
	if index < 1 or index > #self.candidates then
		return nil
	end
	return index
end

---@param dt number
function CommandList:update(dt)
	VirtualizedList.update(self, dt)
	self.hover_index = nil
	if self.mouse_over then
		self.hover_index = self:getIndexAt(love.mouse.getPosition())
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function CommandList:onMouseClick(e)
	if e.button ~= 1 or self.drag_active then
		return
	end
	local index = self:getIndexAt(e.x, e.y)
	if not index then
		return
	end
	self.on_select(index)
	self.on_confirm(index)
	return true
end

function CommandList:draw()
	local scroll = self:getVisualScrollPosition()
	local first_index, last_index = self:getVisibleRowRange()
	for index = first_index, last_index do
		local candidate = self.candidates[index]
		local y = (index - 1) * self:getRowStep() - scroll
		if index == self.selected_index then
			Painter.setColorTable(Colors.hover)
			love.graphics.rectangle("fill", 0, y, self.width, self.item_height)
		elseif index == self.hover_index then
			Painter.setColorTable(Colors.elements)
			love.graphics.rectangle("fill", 0, y, self.width, self.item_height)
		end

		Painter.setColorTable(Colors.text)
		love.graphics.setFont(self.title_font)
		love.graphics.print(candidate.title or "", TEXT_X, y + 7)
		if candidate.description and candidate.description ~= "" then
			Painter.setColorTable(Colors.text_muted)
			love.graphics.setFont(self.description_font)
			love.graphics.print(candidate.description, TEXT_X, y + 32)
		end
	end
end

return CommandList
