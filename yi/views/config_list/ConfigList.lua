local View = require("ui.View")
local ConfigItem = require("yi.views.config_list.ConfigItem")
local Checkbox = require("yi.views.config_list.Checkbox")
local Slider = require("yi.views.config_list.Slider")
local Dropdown = require("yi.views.config_list.Dropdown")
local Painter = require("yi.Painter")
local math_util = require("math_util")

---@class yi.ConfigList : ui.View
---@operator call: yi.ConfigList
---@field items yi.ConfigItem[]
---@field focus_index integer
local ConfigList = View + {}

local GAP = 10

---@param resources yi.Resources
function ConfigList:new(resources)
	View.new(self)
	self.resources = resources
	self.items = {}
	self.focus_index = 0
	self.scroll_position = 0

	local font = resources:getFont("regular", 36)
	self.text_batch = love.graphics.newTextBatch(font)

	local chk = true
	local slider_v = 50
	local dropdown_v = 1
	local dropdown_items = {"Option A", "Option B", "Option C"}

	for i = 1, 3 do
		table.insert(self.items, Checkbox("Checkbox", function() return chk end, function(v) chk = v end))
		table.insert(self.items, Slider("Slider", 0, 100, 5, "%i", function() return slider_v end, function(v) slider_v = v end))
		table.insert(self.items, Dropdown("Dropdown", dropdown_items, nil, function() return dropdown_v end, function(v) dropdown_v = v end))
	end

	self:setSize(ConfigItem.width, 800)
	self.handles_keyboard_input = true
end

function ConfigList:onKeyDown(e)
	local index_delta = 0
	local f_item = self.items[self.focus_index]

	if e.key == "j" then
		index_delta = 1
	elseif e.key == "k" then
		index_delta = -1
	elseif e.key == "h" then
		if f_item then
			f_item:onDirectionalKeyPressed("left")
		end
	elseif e.key == "l" then
		if f_item then
			f_item:onDirectionalKeyPressed("right")
		end
	elseif e.key == "return" and not e.is_repeated then
		if f_item then
			f_item:onClick()
		end
	else
		return false
	end

	if self.items[self.focus_index] then
		self.items[self.focus_index].is_focused = false
	end

	self.focus_index = math_util.clamp(self.focus_index + index_delta, 1, #self.items)
	self.items[self.focus_index].is_focused = true

	return true
end

local lg = love.graphics

function ConfigList:update(dt)
	for _, v in ipairs(self.items) do
		v:update(dt)
	end
end

function ConfigList:draw()
	local atlas, quads = self.resources.atlas, self.resources.quads
	local text_batch = self.text_batch
	local global_y = self.scroll_position

	text_batch:clear()
	lg.push()

	for _, v in ipairs(self.items) do
		lg.push("all")
		v:draw(atlas, quads, text_batch, global_y)
		lg.pop()

		local add_y = GAP + v.height
		global_y = global_y + add_y
		lg.translate(0, add_y)
	end

	lg.pop()
	Painter.snapToPixel()
	lg.draw(text_batch)
end

return ConfigList
