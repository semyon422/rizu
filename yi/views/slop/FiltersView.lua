local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local SpringValue = require("gui.anim.SpringValue")

local cs = {Colors.text, ""}

---@class yi.views.slop.FiltersView : gui.View
---@operator call: yi.views.slop.FiltersView
---@field chartSelector rizu.select.ChartSelector
---@field filterModel sphere.FilterModel
---@field text_batch love.TextBatch
local FiltersView = View + {}

---@param game table
function FiltersView:new(game)
	View.new(self)
	self.game = assert(game)
	self.chartSelector = assert(game.chartSelector)
	self.filterModel = assert(game.chartSelector.filterModel)

	self.text_batch = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.handles_mouse_input = true

	-- Layout constants
	self.padding_x = 20
	self.padding_y = 20
	self.inner_padding_x = 12
	self.inner_padding_y = 12
	self.item_height = 40
	self.item_padding = 10
	self.col_width = 1100
	self.col_height = 600

	-- Mouse hover state tracking
	self.hovered_group_idx = nil
	self.hovered_filter_idx = nil

	-- Scroll springs and targets
	self.scroll_spring = SpringValue()
	self.scroll_target = 0

	self.atlas = Resources.atlas
	self.quads = Resources.quads
end

function FiltersView:load()
	local w = self.padding_x * 2 + self.col_width
	local h = self.padding_y * 2 + self.col_height + 40
	self:setSize(w, h)
end

function FiltersView:update(dt)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	-- Update scroll spring
	self.scroll_spring:update(dt)
	local scroll = self.scroll_spring:get()

	self.hovered_group_idx = nil
	self.hovered_filter_idx = nil

	local list_x = self.padding_x
	local list_y = self.padding_y + 40
	local list_w = self.col_width

	local filters = self.game.configModel.configs.filters.notechart
	local btn_gap = 10
	local btn_w = (self.col_width - 2 * self.inner_padding_x - 5 * btn_gap) / 6

	-- Determine mouse hover by running layout loop
	if lx >= list_x and lx <= list_x + list_w and ly >= list_y and ly <= list_y + self.col_height then
		local current_y = list_y + self.inner_padding_y - scroll
		for i, group in ipairs(filters) do
			-- Header height is 30
			current_y = current_y + 30

			-- Buttons layout
			for j, filter in ipairs(group) do
				local c = (j - 1) % 6
				local r = math.floor((j - 1) / 6)
				local btn_x = list_x + self.inner_padding_x + c * (btn_w + btn_gap)
				local btn_y = current_y + r * (self.item_height + self.item_padding)

				if lx >= btn_x and lx <= btn_x + btn_w and ly >= btn_y and ly <= btn_y + self.item_height then
					self.hovered_group_idx = i
					self.hovered_filter_idx = j
				end
			end

			local total_rows = math.ceil(#group / 6)
			current_y = current_y + total_rows * (self.item_height + self.item_padding) + 20 -- Group gap
		end
	end

	-- Compute max scroll dynamically
	local content_height = self.inner_padding_y * 2
	for i, group in ipairs(filters) do
		content_height = content_height + 30 -- Header height
		local total_rows = math.ceil(#group / 6)
		content_height = content_height + total_rows * (self.item_height + self.item_padding) + 20 -- Group gap
	end
	local max_scroll = math.max(0, content_height - self.col_height)

	if self.scroll_target > max_scroll then
		self.scroll_target = max_scroll
		self.scroll_spring:set(max_scroll)
	end

	-- Update text batch
	self.text_batch:clear()
	local font = self.text_batch:getFont()
	local font_h = font:getHeight()
	local text_offset_y = (self.item_height - font_h) / 2

	-- Populate text batch using the layout loop
	local current_y = list_y + self.inner_padding_y - scroll
	for i, group in ipairs(filters) do
		-- Draw Group Header
		cs[1] = Colors.text_muted
		cs[2] = group.name
		self.text_batch:addf(cs, self.col_width - 2 * self.inner_padding_x, "left", list_x + self.inner_padding_x, current_y + 4)
		current_y = current_y + 30

		-- Draw buttons labels
		for j, filter in ipairs(group) do
			local c = (j - 1) % 6
			local r = math.floor((j - 1) / 6)
			local btn_x = list_x + self.inner_padding_x + c * (btn_w + btn_gap)
			local btn_y = current_y + r * (self.item_height + self.item_padding)

			local is_active = self.filterModel:isActive(group.name, filter.name)
			cs[1] = is_active and Colors.background or Colors.text
			cs[2] = filter.name
			self.text_batch:addf(cs, btn_w, "center", btn_x, btn_y + text_offset_y)
		end

		local total_rows = math.ceil(#group / 6)
		current_y = current_y + total_rows * (self.item_height + self.item_padding) + 20
	end
end

function FiltersView:onMouseClick(e)
	local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)

	local list_x = self.padding_x
	local list_y = self.padding_y + 40
	local list_w = self.col_width

	local filters = self.game.configModel.configs.filters.notechart
	local btn_gap = 10
	local btn_w = (self.col_width - 2 * self.inner_padding_x - 5 * btn_gap) / 6

	if lx >= list_x and lx <= list_x + list_w and ly >= list_y and ly <= list_y + self.col_height then
		local scroll = self.scroll_spring:get()
		local current_y = list_y + self.inner_padding_y - scroll

		for i, group in ipairs(filters) do
			current_y = current_y + 30 -- Skip header

			for j, filter in ipairs(group) do
				local c = (j - 1) % 6
				local r = math.floor((j - 1) / 6)
				local btn_x = list_x + self.inner_padding_x + c * (btn_w + btn_gap)
				local btn_y = current_y + r * (self.item_height + self.item_padding)

				if lx >= btn_x and lx <= btn_x + btn_w and ly >= btn_y and ly <= btn_y + self.item_height then
					if e.button == 1 then
						local is_active = self.filterModel:isActive(group.name, filter.name)
						self.filterModel:setFilter(group.name, filter.name, not is_active)
						self.filterModel:apply()
						self.chartSelector:noDebounceRefresh()
						return true
					end
				end
			end

			local total_rows = math.ceil(#group / 6)
			current_y = current_y + total_rows * (self.item_height + self.item_padding) + 20
		end
	end

	return false
end

function FiltersView:onScroll(e)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	local list_x = self.padding_x
	local list_y = self.padding_y + 40

	if lx >= list_x and lx <= list_x + self.col_width and ly >= list_y and ly <= list_y + self.col_height then
		local filters = self.game.configModel.configs.filters.notechart
		local content_height = self.inner_padding_y * 2
		for i, group in ipairs(filters) do
			content_height = content_height + 30
			local total_rows = math.ceil(#group / 6)
			content_height = content_height + total_rows * (self.item_height + self.item_padding) + 20
		end
		local max_scroll = math.max(0, content_height - self.col_height)
		self.scroll_target = math.max(0, math.min(self.scroll_target - e.direction_y * 120, max_scroll))
		self.scroll_spring:set(self.scroll_target)
		return true
	end
	return false
end

function FiltersView:draw()
	local atlas = self.atlas
	local pixel = self.quads.pixel

	-- Draw Title
	love.graphics.setFont(Resources.getScaledFont("regular", 20))
	love.graphics.setColor(Colors.text)
	love.graphics.printf("Filter Chart List", self.padding_x, self.padding_y, self.col_width, "center")

	-- List column background
	love.graphics.setColor(Colors.background)
	love.graphics.draw(atlas, pixel, self.padding_x, self.padding_y + 40, 0, self.col_width, self.col_height)

	-- Draw outlines with "add" blend mode
	love.graphics.setBlendMode("add")
	love.graphics.setColor(Colors.outline)
	love.graphics.draw(atlas, pixel, self.padding_x, self.padding_y + 40, 0, self.col_width, 1) -- Top
	love.graphics.draw(atlas, pixel, self.padding_x, self.padding_y + 40 + self.col_height - 1, 0, self.col_width, 1) -- Bottom
	love.graphics.draw(atlas, pixel, self.padding_x, self.padding_y + 40, 0, 1, self.col_height) -- Left
	love.graphics.draw(atlas, pixel, self.padding_x + self.col_width - 1, self.padding_y + 40, 0, 1, self.col_height) -- Right
	love.graphics.setBlendMode("alpha")

	-- Apply stencil to clip inside content
	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.draw(atlas, pixel, self.padding_x, self.padding_y + 40, 0, self.col_width, self.col_height)
	love.graphics.setStencilMode("test")

	local scroll = self.scroll_spring:get()
	local filters = self.game.configModel.configs.filters.notechart
	local btn_gap = 10
	local btn_w = (self.col_width - 2 * self.inner_padding_x - 5 * btn_gap) / 6

	-- Draw buttons background and outlines using layout loop
	local list_y = self.padding_y + 40
	local current_y = list_y + self.inner_padding_y - scroll

	for i, group in ipairs(filters) do
		current_y = current_y + 30 -- Skip header space

		for j, filter in ipairs(group) do
			local c = (j - 1) % 6
			local r = math.floor((j - 1) / 6)
			local btn_x = self.padding_x + self.inner_padding_x + c * (btn_w + btn_gap)
			local btn_y = current_y + r * (self.item_height + self.item_padding)

			local is_active = self.filterModel:isActive(group.name, filter.name)
			local is_hovered = (self.hovered_group_idx == i and self.hovered_filter_idx == j)

			if is_active then
				-- Active state: filled accent button
				love.graphics.setColor(Colors.accent)
				love.graphics.draw(atlas, pixel, btn_x, btn_y, 0, btn_w, self.item_height)
			else
				-- Inactive state: outlined button
				love.graphics.setColor(Colors.outline)
				love.graphics.draw(atlas, pixel, btn_x, btn_y, 0, btn_w, 1) -- Top
				love.graphics.draw(atlas, pixel, btn_x, btn_y + self.item_height - 1, 0, btn_w, 1) -- Bottom
				love.graphics.draw(atlas, pixel, btn_x, btn_y, 0, 1, self.item_height) -- Left
				love.graphics.draw(atlas, pixel, btn_x + btn_w - 1, btn_y, 0, 1, self.item_height) -- Right
			end

			-- Hover highlight overlay
			if is_hovered then
				love.graphics.setColor(1, 1, 1, 0.15)
				love.graphics.draw(atlas, pixel, btn_x, btn_y, 0, btn_w, self.item_height)
			end
		end

		local total_rows = math.ceil(#group / 6)
		current_y = current_y + total_rows * (self.item_height + self.item_padding) + 20
	end

	-- Reset color for text batch
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.text_batch)

	-- Disable stencil
	love.graphics.setStencilMode("off")
end

function FiltersView:unload()
	self.filterModel:apply()
	self.chartSelector:noDebounceRefresh()
end

return FiltersView
