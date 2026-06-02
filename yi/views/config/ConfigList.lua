local View = require("ui.View")
local ConfigItem = require("yi.views.config.ConfigItem")
local Checkbox = require("yi.views.config.Checkbox")
local Slider = require("yi.views.config.Slider")
local Dropdown = require("yi.views.config.Dropdown")
local Painter = require("yi.Painter")
local math_util = require("math_util")
local SpringValue = require("ui.anim.SpringValue")


---@class yi.ConfigList : ui.View
---@operator call: yi.ConfigList
---@field items yi.ConfigItem[]
---@field focus_index integer
local ConfigList = View + {}

local GAP = 10

---@param resources yi.Resources
---@param schema {[string]: {[string]: {[string]: rizu.config.Setting}}}
---@param cfg rizu.config.Config
function ConfigList:new(resources, schema, cfg)
	View.new(self)
	self.resources = resources
	self.schema = schema
	self.cfg = cfg
	self.items = {}
	self.focus_index = 0
	self.scroll_spring = SpringValue()

	local font = resources:getFont("regular", 36)
	self.text_batch = love.graphics.newTextBatch(font)

	self:setWidth(ConfigItem.width)
	self.handles_keyboard_input = true

end

---@param items yi.ConfigItem[]
function ConfigList:setItems(items)
	self.focus_index = 0
	self.scroll_spring:snap(0)
	self.items = items
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

	local center = (self.box.height / (ConfigItem.height + GAP) / 2)
	local a = math.max(0, self.focus_index - center)
	local b = math.min(a, #self.items - center * 2)

	self.scroll_spring:set(
		b * ConfigItem.height + GAP * b
	)
	self.items[self.focus_index].is_focused = true

	return true
end

local lg = love.graphics

function ConfigList:update(dt)
	for _, v in ipairs(self.items) do
		v:update(dt)
	end

	self.scroll_spring:update(dt)
end

function ConfigList:draw()
	local atlas, quads = self.resources.atlas, self.resources.quads
	local text_batch = self.text_batch
	local global_y = 0
	local scroll_position = self.scroll_spring:get()

	text_batch:clear()

	love.graphics.setStencilMode("draw", 1)
	love.graphics.rectangle("fill", -16, 0, self.width + 32, self.box.height)
	love.graphics.setStencilMode("test")
	lg.push()
	lg.translate(0, -scroll_position)

	for _, v in ipairs(self.items) do
		lg.push("all")
		v:draw(atlas, quads, text_batch, global_y)
		lg.pop()

		local add_y = GAP + v.height
		global_y = global_y + add_y
		lg.translate(0, add_y)
	end

	lg.pop()
	lg.translate(0, -scroll_position)
	Painter.snapToPixel()
	lg.draw(text_batch)
	love.graphics.setStencilMode("off")
end

return ConfigList
