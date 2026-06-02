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
---@param schema {[string]: {[string]: {[string]: rizu.config.Setting}}}
---@param cfg rizu.config.Config
function ConfigList:new(resources, schema, cfg)
	View.new(self)
	self.resources = resources
	self.schema = schema
	self.cfg = cfg
	self.items = {}
	self.focus_index = 0
	self.scroll_position = 0

	local font = resources:getFont("regular", 36)
	self.text_batch = love.graphics.newTextBatch(font)

	self:setSize(ConfigItem.width, 800)
	self.handles_keyboard_input = true

	for group_name, group in pairs(schema) do
		for section_name, section in pairs(group) do
			for setting_name, setting in pairs(section) do
				local key = ("%s.%s.%s"):format(group_name, section_name, setting_name)
				local kind = setting.kind
				local item ---@type yi.ConfigItem?
				if kind == "checkbox" then
					item = Checkbox(key, setting, cfg)
				elseif kind == "range" then
					item = Slider(key, setting, cfg)
				elseif kind == "choice" then
					item = Dropdown(key, setting, cfg)
				end
				table.insert(self.items, item)
			end
		end
	end
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
