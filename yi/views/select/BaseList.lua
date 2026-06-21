local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.views.select.BaseList : gui.View
---@operator call: yi.views.select.BaseList
local BaseList = View + {}

function BaseList:new()
	View.new(self)
	self.visible_items = 9
	self.is_centered = false
	self.gap = 0
	self.scroll_spring = SpringValue({stiffness = 480, damping = 48})
	self.handles_mouse_input = true
end

function BaseList:load()
	local total_gap_space = (self.visible_items - 1) * self.gap
	self.item_height = (self.height - total_gap_space) / self.visible_items
	self:snapToSelected()
end

function BaseList:snapToSelected()
	local selected_index = self:getSelectedIndex()
	if selected_index then
		self.scroll_spring:snap(selected_index)
	end
end

---@return integer
function BaseList:getSelectedIndex() error("Not implemented") end

---@param index integer
---@return table
function BaseList:getItem(index) error("Not implemented") end

function BaseList:update(dt)
	local selected_index = self:getSelectedIndex()

	self.scroll_spring:set(selected_index)
	self.scroll_spring:update(dt)

	local item_height = self.item_height
	local gap = self.gap
	local row_step = item_height + gap

	local scroll_index = self.scroll_spring:get()
	local reference_index = scroll_index

	if self.is_centered then
		reference_index = scroll_index - (self.visible_items / 2)
	end

	local first_index = math.floor(reference_index)
	local pixel_offset = (reference_index - first_index) * row_step

	self:resetBatches()

	for i = -1, self.visible_items + 1 do
		local item_index = first_index + i
		local item = self:getItem(item_index)
		if item then
			local item_y = 0
			if self.is_centered then
				item_y = i * row_step - pixel_offset - (item_height / 2)
			else
				item_y = i * row_step - pixel_offset
			end
			self:addToBatch(item, i, item_y, item_index == selected_index)
		end
	end
end

function BaseList:resetBatches() end

---@param item table
---@param index integer
---@param y number
---@param is_selected boolean
function BaseList:addToBatch(item, index, y, is_selected) end

function BaseList:draw() end

return BaseList
