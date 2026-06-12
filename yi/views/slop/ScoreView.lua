local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local SpringValue = require("gui.anim.SpringValue")
local time_util = require("time_util")
local Format = require("sphere.views.Format")

local cs = {Colors.text, ""}
local cs_muted = {Colors.text_muted, ""}

---@class yi.views.slop.ScoreView : gui.View
---@operator call: yi.views.slop.ScoreView
---@field text_batch love.TextBatch
local ScoreView = View + {}

---@param yi yi.UserInterface
function ScoreView:new(yi)
	View.new(self)
	self.yi = assert(yi)
	self.game = assert(yi.game)
	self.scoreSelector = assert(yi.game.scoreSelector)

	self.text_batch = love.graphics.newTextBatch(Resources.getScaledFont("regular", 20))
	self.handles_mouse_input = true

	-- Layout constants
	self.padding = 20
	self.item_height = 50
	self.item_padding = 4
	self.col_width = 800
	self.col_height = 500

	-- Mouse hover state tracking
	self.hovered_idx = nil

	-- Scroll springs and targets
	self.scroll_spring = SpringValue()
	self.scroll_target = 0

	self.atlas = Resources.atlas
	self.quads = Resources.quads
end

function ScoreView:load()
	local w = self.padding * 2 + self.col_width
	local h = self.padding * 2 + self.col_height + 40
	self:setSize(w, h)
end

function ScoreView:update(dt)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	-- Update scroll spring
	self.scroll_spring:update(dt)
	local scroll = self.scroll_spring:get()

	self.hovered_idx = nil

	local list_x = self.padding
	local list_y = self.padding + 40
	local items = self.scoreSelector.store.items

	-- Check hover on list
	if lx >= list_x and lx <= list_x + self.col_width and ly >= list_y and ly <= list_y + self.col_height then
		local idx = math.floor((ly - list_y + scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #items then
			self.hovered_idx = idx
		end
	end

	-- Clamp scroll target
	local max_scroll = math.max(0, #items * (self.item_height + self.item_padding) - self.col_height)
	if self.scroll_target > max_scroll then
		self.scroll_target = max_scroll
		self.scroll_spring:set(max_scroll)
	end

	-- Update text batch
	self.text_batch:clear()
	local font = self.text_batch:getFont()
	local font_h = font:getHeight()
	local text_offset_y = (self.item_height - font_h) / 2

	local sea_client = self.game.seaClient
	local user = sea_client.client:getUser()
	local username = user and user.name or "username"

	for i, item in ipairs(items) do
		local item_y = list_y + (i - 1) * (self.item_height + self.item_padding) - scroll
		local time = item.created_at or 0
		local time_str = time ~= 0 and time_util.time_ago_in_words(time) or "never"
		local user_name = item.user_name or username
		local score_val = item.score or 0

		cs[1] = Colors.text
		cs[2] = string.format("#%d  %s", i, user_name)
		self.text_batch:addf(cs, 250, "left", list_x + 15, item_y + text_offset_y)

		cs[1] = Colors.text
		cs[2] = tostring(math.floor(score_val))
		self.text_batch:addf(cs, 150, "left", list_x + 280, item_y + text_offset_y)

		cs_muted[1] = Colors.text_muted
		cs_muted[2] = string.format("%s - %s", Format.timeRate(item.rate), Format.inputMode(item.inputmode))
		self.text_batch:addf(cs_muted, 150, "left", list_x + 450, item_y + text_offset_y)

		cs_muted[1] = Colors.text_muted
		cs_muted[2] = time_str
		self.text_batch:addf(cs_muted, 150, "right", list_x + self.col_width - 165, item_y + text_offset_y)
	end
end

function ScoreView:onMouseClick(e)
	local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)

	local list_x = self.padding
	local list_y = self.padding + 40

	local items = self.scoreSelector.store.items

	if lx >= list_x and lx <= list_x + self.col_width and ly >= list_y and ly <= list_y + self.col_height then
		local scroll = self.scroll_spring:get()
		local idx = math.floor((ly - list_y + scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #items then
			if e.button == 1 then
				if self.scoreSelector.state.chartplayIndex == idx then
					self.yi.game.resultController:replayNoteChartAsync("result", self.yi.game.scoreSelector.chartplay)
					self.yi:setScreen("result")
				else
					self.scoreSelector:scrollScore(nil, idx)
				end
				return true
			end
		end
	end

	return false
end

function ScoreView:onScroll(e)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	local list_x = self.padding
	local list_y = self.padding + 40

	if lx >= list_x and lx <= list_x + self.col_width and ly >= list_y and ly <= list_y + self.col_height then
		local items = self.scoreSelector.store.items
		local max_scroll = math.max(0, #items * (self.item_height + self.item_padding) - self.col_height)
		self.scroll_target = math.max(0, math.min(self.scroll_target - e.direction_y * 120, max_scroll))
		self.scroll_spring:set(self.scroll_target)
		return true
	end
	return false
end

function ScoreView:draw()
	local atlas = self.atlas
	local pixel = self.quads.pixel

	-- Draw Title
	love.graphics.setFont(Resources.getScaledFont("regular", 20))
	love.graphics.setColor(Colors.text)
	love.graphics.printf("Scores", self.padding, self.padding, self.col_width, "center")

	-- List column background
	love.graphics.setColor(Colors.background)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)

	-- Draw outlines with "add" blend mode
	love.graphics.setBlendMode("add")
	love.graphics.setColor(Colors.line)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, 1) -- Top
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40 + self.col_height - 1, 0, self.col_width, 1) -- Bottom
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, 1, self.col_height) -- Left
	love.graphics.draw(atlas, pixel, self.padding + self.col_width - 1, self.padding + 40, 0, 1, self.col_height) -- Right
	love.graphics.setBlendMode("alpha")

	-- Apply stencil to clip inside list
	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)
	love.graphics.setStencilMode("test")

	local scroll = self.scroll_spring:get()
	local items = self.scoreSelector.store.items
	local selected_idx = self.scoreSelector.state.chartplayIndex
	local list_y = self.padding + 40

	if #items == 0 then
		love.graphics.setColor(Colors.text_muted)
		love.graphics.printf("No scores available.", self.padding, self.padding + 40 + self.col_height / 2 - 10, self.col_width, "center")
	end

	for i, item in ipairs(items) do
		local item_y = list_y + (i - 1) * (self.item_height + self.item_padding) - scroll
		local is_selected = (selected_idx == i)
		local is_hovered = (self.hovered_idx == i)

		if is_selected then
			-- Selected state: accent bar on the left + filled background
			love.graphics.setColor(Colors.accent)
			love.graphics.draw(atlas, pixel, self.padding, item_y, 0, 4, self.item_height)
			love.graphics.setColor(Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.15)
			love.graphics.draw(atlas, pixel, self.padding + 4, item_y, 0, self.col_width - 4, self.item_height)
		elseif is_hovered then
			love.graphics.setColor(1, 1, 1, 0.08)
			love.graphics.draw(atlas, pixel, self.padding, item_y, 0, self.col_width, self.item_height)
		end
	end

	-- Draw text batch inside stencil
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.text_batch)

	-- Disable stencil
	love.graphics.setStencilMode("off")
end

return ScoreView
