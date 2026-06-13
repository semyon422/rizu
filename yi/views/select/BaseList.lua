local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")

---@class yi.views.select.BaseList : gui.View
---@operator call: yi.views.select.BaseList
local BaseList = View + {}

function BaseList:new()
	View.new(self)
	self.scroll_spring = SpringValue({stiffness = 480, damping = 48})
	self.handles_mouse_input = true
	self.visible_items = 9
end

function BaseList:load()
	self.item_height = self.height / self.visible_items
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

	local scroll_index = self.scroll_spring:get()
	local centered = scroll_index - self.visible_items / 2
	local first_index = math.floor(centered)
	local pixel_offset = (centered - math.floor(centered)) * item_height

	self:resetBatches()

	for i = -1, self.visible_items + 1 do
		local item_index = first_index + i
		local item = self:getItem(item_index)
		if item then
			local item_y = i * item_height - pixel_offset - item_height / 2
			self:addToBatch(item, item_y, item_index == selected_index)
		end
	end
end

function BaseList:resetBatches() end

---@param item table
---@param y number
---@param is_selected boolean
function BaseList:addToBatch(item, y, is_selected) end

function BaseList:draw() end

return BaseList
