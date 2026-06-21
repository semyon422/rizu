local View = require("gui.View")
local SpringValue = require("gui.anim.SpringValue")
local Resources = require("yi.Resources")
local Colors = require("yi.Colors")
local Painter = require("yi.Painter")
local time_util = require("time_util")

---@class yi.views.select.ScoreList : gui.View
---@operator call: yi.views.select.ScoreList
local ScoreList = View + {}

local FADE_IN_DURATION = 0.4
local FADE_IN_STAGGER = 0.02

---@param score_selector rizu.select.ScoreSelector
---@param on_score_selected fun(index: integer)
function ScoreList:new(score_selector, on_score_selected)
	View.new(self)
	self.score_selector = score_selector
	self.on_score_selected = on_score_selected
	self.items = {}
	self.gap = 5
	self.scroll_spring = SpringValue({stiffness = 480, damping = 48})
	self.selected_index = nil
	self.hover_index = nil
	self.handles_mouse_input = true
	self.handles_keyboard_input = true
	self.batch = love.graphics.newSpriteBatch(Resources.atlas)
	self.text_batch24 = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.text_batch16 = love.graphics.newTextBatch(Resources.getFont("regular", 16))
	self.last_key_press = -math.huge
	self.reload_time = 0
	self.no_records = true
	self.no_records_t = 0
end

function ScoreList:load()
	self.width, self.height = self.box:getDimensions()
	self.item_height = 76
	self.cap_left_width = Painter.getQuadWidth(Resources.quads.list_item_cap_left)
	self.cap_right_width = Painter.getQuadWidth(Resources.quads.list_item_cap_right)
	self.mid_width = self.box.width - self.cap_left_width - self.cap_right_width
end

local function getColorFromScore(score) -- TODO: Should use Chartplay:getGrade() but idk where to get it
	if score > 9800 then
		return Colors.grade_x
	elseif score > 8000 then
		return Colors.grade_s
	elseif score > 7000 then
		return Colors.grade_a
	elseif score > 6000 then
		return Colors.grade_b
	elseif score > 5000 then
		return Colors.grade_c
	end

	return Colors.grade_d
end

function ScoreList:reload()
	self.items = {}
	self.selected_index = nil
	self.reload_time = love.timer.getTime()

	for i, v in ipairs(self.score_selector.store.items) do
		local mods_sb = {}

		if v.const then
			table.insert(mods_sb, "Const")
		end

		if v.rate and v.rate ~= 1 then
			table.insert(mods_sb, ("%0.02fx"):format(v.rate))
		end

		if v.pause_count and v.pause_count > 0 then
			table.insert(mods_sb, "Pauses")
		end

		table.insert(self.items, {
			label = ("#%i Username"):format(i),
			accuracy = ("%0.02f%%"):format((v.score or 0) / 100),
			time_ago = time_util.time_ago_in_words(v.created_at or 0),
			mods = table.concat(mods_sb, " "),
			color = getColorFromScore(v.score or 0),
		})
	end

	self.scroll_spring:snap(self:clampScroll(self.scroll_spring.target))
	self.no_records = #self.items == 0
end

function ScoreList:clampScroll(value)
	local row_step = self.item_height + self.gap
	local max_scroll = math.max(0, (#self.items - 1) * row_step)
	return math.max(0, math.min(value, max_scroll))
end

function ScoreList:update(dt)
	if self.no_records then
		self.no_records_t = math.min(1, self.no_records_t + dt * 3)
		return
	else
		self.no_records_t = math.max(0, self.no_records_t - dt * 3)
	end

	self.scroll_spring:update(dt)

	if self.last_key_press - (love.timer.getTime() - 2) < 0 then
		self.selected_index = nil
	end

	self.hover_index = nil
	if self.mouse_over then
		local _, my = self.transform:inverseTransformPoint(love.mouse.getPosition())
		if my >= 0 and my < self.height then
			local row_step = self.item_height + self.gap
			local scroll = self.scroll_spring:get()
			local start_row = math.floor(scroll / row_step)
			local pixel_offset = scroll - start_row * row_step
			local idx = start_row + math.floor((my + pixel_offset) / row_step) + 1
			if idx >= 1 and idx <= #self.items then
				self.hover_index = idx
			end
		end
	end

	self.batch:clear()
	self.text_batch24:clear()
	self.text_batch16:clear()

	local row_step = self.item_height + self.gap
	local scroll = self.scroll_spring:get()
	local start_row = math.floor(scroll / row_step)
	local pixel_offset = scroll - start_row * row_step

	for i, item in ipairs(self.items) do
		local row = i - 1 - start_row
		local y = row * row_step - pixel_offset

		if y > self.height or y + self.item_height < 0 then
			goto continue
		end

		self:drawItem(item, i, y, i == self.selected_index, i == self.hover_index)
		::continue::
	end
end

local cs = {{1, 1, 1, 1}, ""}

---@param p number
---@return number
local function ease_out_cubic(p)
	return 1 - (1 - p) ^ 3
end

---@param color gui.Color
local function copy_color_to_cs(color)
	cs[1][1] = color[1]
	cs[1][2] = color[2]
	cs[1][3] = color[3]
	cs[1][4] = color[4]
end

---@param a number
local function set_cs_alpha(a)
	cs[1][4] = a
end

---@param item table
---@param index integer
---@param y number
---@param is_selected boolean
---@param is_hovered boolean
function ScoreList:drawItem(item, index, y, is_selected, is_hovered)
	local elapsed = love.timer.getTime() - self.reload_time
	local delay = index * FADE_IN_STAGGER
	local t = (elapsed - delay) / FADE_IN_DURATION
	local p = math.max(0, math.min(1, t))
	p = ease_out_cubic(p)

	self.batch:setColor(Colors.panel[1], Colors.panel[2], Colors.panel[3], p)
	self.batch:add(Resources.quads.list_item_cap_left, 0, y, 0)
	self.batch:add(Resources.quads.pixel, self.cap_left_width, y, 0, self.mid_width, self.item_height)
	self.batch:add(Resources.quads.list_item_cap_right, self.box.width - self.cap_right_width, y, 0)

	local a = ((is_selected or is_hovered) and 0.6 or 0.2) * p
	self.batch:setColor(item.color[1], item.color[2], item.color[3], a)
	self.batch:add(Resources.quads.score_grade_gradient, 0, y)

	self.batch:setColor(1, 1, 1, p)
	self.batch:add(Resources.quads.avatar, 6, y + 6)

	copy_color_to_cs(Colors.text)
	set_cs_alpha(p)
	cs[2] = item.label
	self.text_batch24:add(cs, 87, y + 23)

	copy_color_to_cs(item.color)
	set_cs_alpha(p)
	cs[2] = item.accuracy
	self.text_batch24:addf(cs, self.box.width, "right", -17, y + 12)

	copy_color_to_cs(Colors.text_muted)
	set_cs_alpha(p)
	cs[2] = item.time_ago
	self.text_batch16:addf(cs, self.box.width, "right", -17, y + 43)

	copy_color_to_cs(Colors.text)
	set_cs_alpha(p)
	cs[2] = item.mods
	self.text_batch16:addf(cs, self.box.width - 100, "right", -17, y + 43)
end

function ScoreList:onScroll(e)
	local row_step = self.item_height + self.gap
	local new_target = self.scroll_spring.target - e.direction_y * row_step
	self.scroll_spring:set(self:clampScroll(new_target))
end

function ScoreList:onKeyDown(e)
	if e.key == "down" then
		self.selected_index = math.min(#self.items, (self.selected_index or 0) + 1)
		self:scrollToIndex(self.selected_index)
		self.last_key_press = love.timer.getTime()
	elseif e.key == "up" then
		self.selected_index = math.max(1, (self.selected_index or #self.items) - 1)
		self:scrollToIndex(self.selected_index)
		self.last_key_press = love.timer.getTime()
	elseif e.key == "right" then
		if self.selected_index then
			self.on_score_selected(self.selected_index)
		end
	end
end

function ScoreList:scrollToIndex(index)
	local row_step = self.item_height + self.gap
	local target = (index - 1) * row_step
	local scroll = self.scroll_spring:get()
	if target < scroll then
		self.scroll_spring:snap(self:clampScroll(target))
	elseif target + row_step > scroll + self.height then
		self.scroll_spring:snap(self:clampScroll(target + row_step - self.height))
	end
end

function ScoreList:onMouseClick(e)
	if self.hover_index then
		self.on_score_selected(self.hover_index)
	end
end

local lg = love.graphics

function ScoreList:draw()
	if self.no_records then
		local w = Painter.getQuadWidth(Resources.quads.no_records_set)
		local h = Painter.getQuadHeight(Resources.quads.no_records_set)
		lg.setColor(1, 1, 1, ease_out_cubic(self.no_records_t))
		lg.draw(
			Resources.atlas,
			Resources.quads.no_records_set,
			self.box.width / 2,
			self.box.height / 2,
			0,
			1,
			1,
			w / 2,
			h / 2
		)
		return
	end

	lg.clear(false, true, false)
	lg.setStencilMode("draw", 1)
	lg.rectangle("fill", 0, 0, self:getDimensions())
	lg.setStencilMode("test")
	lg.draw(self.batch)
	Painter.snapToPixel()
	lg.draw(self.text_batch16)
	lg.draw(self.text_batch24)
	lg.setStencilMode("off")
end

return ScoreList
