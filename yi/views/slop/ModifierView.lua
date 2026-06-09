local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local SpringValue = require("gui.anim.SpringValue")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")

local cs = {Colors.text, ""}

---@class yi.views.slop.ModifierView : gui.View
---@operator call: yi.views.slop.ModifierView
---@field modifierSelectModel sphere.ModifierSelectModel
---@field text_batch love.TextBatch
local ModifierView = View + {}

---@param modifierSelectModel sphere.ModifierSelectModel
function ModifierView:new(modifierSelectModel)
	View.new(self)
	self.modifierSelectModel = modifierSelectModel
	self.text_batch = love.graphics.newTextBatch(Resources.getScaledFont("regular", 20))
	self.handles_mouse_input = true

	-- Layout constants
	self.padding = 20
	self.item_height = 36
	self.item_padding = 4
	self.col_width = 450
	self.col_height = 600

	-- Mouse hover state tracking
	self.hovered_left_idx = nil
	self.hovered_right_idx = nil

	-- Scroll springs and targets
	self.left_scroll_spring = SpringValue()
	self.right_scroll_spring = SpringValue()
	self.left_scroll_target = 0
	self.right_scroll_target = 0

	-- Dragging state
	self.dragging_slider_idx = nil

	self.atlas = Resources.atlas
	self.quads = Resources.quads
end

function ModifierView:load()
	local w = self.padding * 3 + self.col_width * 2
	local h = self.padding * 2 + self.col_height + 40 -- Extra space for titles
	self:setSize(w, h)
end

function ModifierView:update(dt)
	-- Get mouse position in local coordinates to handle hovering
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	-- Update scroll springs
	self.left_scroll_spring:update(dt)
	self.right_scroll_spring:update(dt)

	local left_scroll = self.left_scroll_spring:get()
	local right_scroll = self.right_scroll_spring:get()

	self.hovered_left_idx = nil
	self.hovered_right_idx = nil

	-- Left column bounds (Available Modifiers)
	local left_x = self.padding
	local left_y = self.padding + 40
	local left_w = self.col_width

	-- Right column bounds (Active Modifiers)
	local right_x = self.padding * 2 + self.col_width
	local right_y = self.padding + 40
	local right_w = self.col_width

	-- Check hover on left column
	if lx >= left_x and lx <= left_x + left_w and ly >= left_y and ly <= left_y + self.col_height then
		local idx = math.floor((ly - left_y + left_scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #ModifierRegistry.list then
			self.hovered_left_idx = idx
		end
	end

	-- Check hover on right column
	local modifiers = self.modifierSelectModel.replayBase.modifiers
	if lx >= right_x and lx <= right_x + right_w and ly >= right_y and ly <= right_y + self.col_height then
		local idx = math.floor((ly - right_y + right_scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #modifiers then
			self.hovered_right_idx = idx
		end
	end

	-- Clamp right scroll target if modifiers count changes
	local max_right_scroll = math.max(0, #modifiers * (self.item_height + self.item_padding) - self.col_height)
	if self.right_scroll_target > max_right_scroll then
		self.right_scroll_target = max_right_scroll
		self.right_scroll_spring:set(max_right_scroll)
	end

	-- Update text batch
	self.text_batch:clear()
	local font = self.text_batch:getFont()
	local font_h = font:getHeight()
	local text_offset_y = (self.item_height - font_h) / 2

	-- Available Modifiers Text
	for i, name in ipairs(ModifierRegistry.list) do
		local item_y = left_y + (i - 1) * (self.item_height + self.item_padding) - left_scroll
		local is_added = self.modifierSelectModel:isAdded(name)
		local is_one_use = self.modifierSelectModel:isOneUse(name)

		local color = Colors.text
		if is_added and is_one_use then
			color = Colors.text_muted
		end

		cs[1] = color
		cs[2] = name
		self.text_batch:addf(cs, self.col_width - 20, "left", left_x + 10, item_y + text_offset_y)
	end

	-- Active Modifiers Text
	for i, item in ipairs(modifiers) do
		local item_y = right_y + (i - 1) * (self.item_height + self.item_padding) - right_scroll
		local name = ModifierRegistry:getName(item.id)
		local display_str = name
		local mod = ModifierModel:getModifier(item.id)
		if item.value ~= nil then
			display_str = name .. ": " .. tostring(item.value)
		end
		-- Limit width to 240 so it doesn't overlap with sliders/steppers
		cs[1] = Colors.text
		cs[2] = display_str
		self.text_batch:addf(cs, 240, "left", right_x + 10, item_y + text_offset_y)
	end
end

function ModifierView:onMouseClick(e)
	-- Determine where the click happened
	local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)

	local left_x = self.padding
	local left_y = self.padding + 40
	local left_w = self.col_width

	local right_x = self.padding * 2 + self.col_width
	local right_y = self.padding + 40
	local right_w = self.col_width

	-- Handle click on left column (Available Modifiers)
	if lx >= left_x and lx <= left_x + left_w and ly >= left_y and ly <= left_y + self.col_height then
		local left_scroll = self.left_scroll_spring:get()
		local idx = math.floor((ly - left_y + left_scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #ModifierRegistry.list then
			local name = ModifierRegistry.list[idx]
			if name then
				local is_added = self.modifierSelectModel:isAdded(name)
				local is_one_use = self.modifierSelectModel:isOneUse(name)
				if not (is_added and is_one_use) then
					self.modifierSelectModel:add(name)
					return true
				end
			end
		end
	end

	-- Handle click on right column (Active Modifiers)
	local modifiers = self.modifierSelectModel.replayBase.modifiers
	if lx >= right_x and lx <= right_x + right_w and ly >= right_y and ly <= right_y + self.col_height then
		local right_scroll = self.right_scroll_spring:get()
		local idx = math.floor((ly - right_y + right_scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #modifiers then
			local item = modifiers[idx]
			local item_y = right_y + (idx - 1) * (self.item_height + self.item_padding) - right_scroll
			local mod = ModifierModel:getModifier(item.id)

			if mod and mod.defaultValue ~= nil then
				-- Check click on interactive controls (x range: right_x + 250 to right_x + 430)
				if lx >= right_x + 250 and lx <= right_x + 430 and ly >= item_y and ly <= item_y + self.item_height then
					if e.button == 1 then
						if type(mod.defaultValue) == "number" then
							-- Slider interaction
							local clicked_norm = (lx - (right_x + 250)) / 180
							local clamped = math.max(0, math.min(1, clicked_norm))
							ModifierModel:setModifierValue(item, mod:fromNormValue(clamped))
							self.modifierSelectModel:change()
							return true
						elseif type(mod.defaultValue) == "string" then
							-- Stepper interaction
							if lx <= right_x + 280 then
								-- Clicked left (<)
								ModifierModel:increaseModifierValue(item, -1)
								self.modifierSelectModel:change()
								return true
							elseif lx >= right_x + 400 then
								-- Clicked right (>)
								ModifierModel:increaseModifierValue(item, 1)
								self.modifierSelectModel:change()
								return true
							end
						end
					end
				end
			end

			-- Normal item selection/removal
			if e.button == 2 then
				self.modifierSelectModel:remove(idx)
				return true
			elseif e.button == 1 then
				self.modifierSelectModel.modifierIndex = idx
				return true
			end
		elseif idx > #modifiers then
			if e.button == 1 then
				self.modifierSelectModel.modifierIndex = #modifiers + 1
				return true
			end
		end
	end

	return false
end

function ModifierView:onScroll(e)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	local left_x = self.padding
	local left_y = self.padding + 40
	local right_x = self.padding * 2 + self.col_width
	local right_y = self.padding + 40

	if lx >= left_x and lx <= left_x + self.col_width and ly >= left_y and ly <= left_y + self.col_height then
		local max_scroll = math.max(0, #ModifierRegistry.list * (self.item_height + self.item_padding) - self.col_height)
		self.left_scroll_target = math.max(0, math.min(self.left_scroll_target - e.direction_y * 120, max_scroll))
		self.left_scroll_spring:set(self.left_scroll_target)
		return true
	elseif lx >= right_x and lx <= right_x + self.col_width and ly >= right_y and ly <= right_y + self.col_height then
		local modifiers = self.modifierSelectModel.replayBase.modifiers
		local max_scroll = math.max(0, #modifiers * (self.item_height + self.item_padding) - self.col_height)
		self.right_scroll_target = math.max(0, math.min(self.right_scroll_target - e.direction_y * 120, max_scroll))
		self.right_scroll_spring:set(self.right_scroll_target)
		return true
	end
	return false
end

function ModifierView:onDragStart(e)
	local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)

	local right_x = self.padding * 2 + self.col_width
	local right_y = self.padding + 40
	local modifiers = self.modifierSelectModel.replayBase.modifiers

	-- Check if dragging a slider in the active column
	if lx >= right_x + 250 and lx <= right_x + 430 and ly >= right_y and ly <= right_y + self.col_height then
		local right_scroll = self.right_scroll_spring:get()
		local idx = math.floor((ly - right_y + right_scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #modifiers then
			local item = modifiers[idx]
			local mod = ModifierModel:getModifier(item.id)
			if mod and mod.defaultValue ~= nil and type(mod.defaultValue) == "number" then
				self.dragging_slider_idx = idx
				local clicked_norm = (lx - (right_x + 250)) / 180
				local clamped = math.max(0, math.min(1, clicked_norm))
				ModifierModel:setModifierValue(item, mod:fromNormValue(clamped))
				self.modifierSelectModel:change()
				return true
			end
		end
	end
	return false
end

function ModifierView:onDrag(e)
	if self.dragging_slider_idx then
		local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)
		local right_x = self.padding * 2 + self.col_width
		local modifiers = self.modifierSelectModel.replayBase.modifiers
		local item = modifiers[self.dragging_slider_idx]
		if item then
			local mod = ModifierModel:getModifier(item.id)
			if mod and type(mod.defaultValue) == "number" then
				local clicked_norm = (lx - (right_x + 250)) / 180
				local clamped = math.max(0, math.min(1, clicked_norm))
				ModifierModel:setModifierValue(item, mod:fromNormValue(clamped))
				self.modifierSelectModel:change()
				return true
			end
		end
	end
	return false
end

function ModifierView:onDragEnd(e)
	if self.dragging_slider_idx then
		self.dragging_slider_idx = nil
		return true
	end
	return false
end

function ModifierView:draw()
	local atlas = self.atlas
	local pixel = self.quads.pixel

	-- Left column box background
	love.graphics.setColor(Colors.background)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)

	-- Right column box background
	love.graphics.setColor(Colors.background)
	love.graphics.draw(atlas, pixel, self.padding * 2 + self.col_width, self.padding + 40, 0, self.col_width, self.col_height)

	-- Draw lines/outlines with "add" blend mode
	love.graphics.setBlendMode("add")
	love.graphics.setColor(Colors.line)
	-- Left column borders
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, 1) -- Top
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40 + self.col_height - 1, 0, self.col_width, 1) -- Bottom
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, 1, self.col_height) -- Left
	love.graphics.draw(atlas, pixel, self.padding + self.col_width - 1, self.padding + 40, 0, 1, self.col_height) -- Right

	-- Right column borders
	local right_x = self.padding * 2 + self.col_width
	love.graphics.draw(atlas, pixel, right_x, self.padding + 40, 0, self.col_width, 1) -- Top
	love.graphics.draw(atlas, pixel, right_x, self.padding + 40 + self.col_height - 1, 0, self.col_width, 1) -- Bottom
	love.graphics.draw(atlas, pixel, right_x, self.padding + 40, 0, 1, self.col_height) -- Left
	love.graphics.draw(atlas, pixel, right_x + self.col_width - 1, self.padding + 40, 0, 1, self.col_height) -- Right
	love.graphics.setBlendMode("alpha")

	-- Apply stencil to clip highlights and text batch inside the columns
	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)
	love.graphics.draw(atlas, pixel, self.padding * 2 + self.col_width, self.padding + 40, 0, self.col_width, self.col_height)
	love.graphics.setStencilMode("test")

	local left_scroll = self.left_scroll_spring:get()
	local right_scroll = self.right_scroll_spring:get()

	local right_x = self.padding * 2 + self.col_width
	local right_y = self.padding + 40

	-- Draw available modifiers rectangles
	local left_y = self.padding + 40
	for i, _ in ipairs(ModifierRegistry.list) do
		local item_y = left_y + (i - 1) * (self.item_height + self.item_padding) - left_scroll
		if self.hovered_left_idx == i then
			love.graphics.setColor(Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.2)
			love.graphics.draw(atlas, pixel, self.padding, item_y, 0, self.col_width, self.item_height)
		end
	end

	-- Draw active modifiers rectangles and controls
	local modifiers = self.modifierSelectModel.replayBase.modifiers
	for i, item in ipairs(modifiers) do
		local item_y = right_y + (i - 1) * (self.item_height + self.item_padding) - right_scroll
		if self.hovered_right_idx == i then
			love.graphics.setColor(Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.2)
			love.graphics.draw(atlas, pixel, right_x, item_y, 0, self.col_width, self.item_height)
		end

		local mod = ModifierModel:getModifier(item.id)
		if mod and mod.defaultValue ~= nil then
			if type(mod.defaultValue) == "number" then
				-- Draw slider track
				love.graphics.setColor(Colors.line)
				love.graphics.draw(atlas, pixel, right_x + 250, item_y + self.item_height / 2 - 1, 0, 180, 2)

				-- Draw slider handle
				local norm = mod:toNormValue(item.value)
				local handle_x = right_x + 250 + norm * 180
				love.graphics.setColor(Colors.accent)
				love.graphics.draw(atlas, pixel, handle_x - 3, item_y + self.item_height / 2 - 6, 0, 6, 12)
			elseif type(mod.defaultValue) == "string" then
				-- Draw < button
				love.graphics.setColor(Colors.line)
				love.graphics.draw(atlas, pixel, right_x + 250, item_y + 4, 0, 30, 1) -- Top
				love.graphics.draw(atlas, pixel, right_x + 250, item_y + self.item_height - 5, 0, 30, 1) -- Bottom
				love.graphics.draw(atlas, pixel, right_x + 250, item_y + 4, 0, 1, self.item_height - 8) -- Left
				love.graphics.draw(atlas, pixel, right_x + 279, item_y + 4, 0, 1, self.item_height - 8) -- Right

				love.graphics.setColor(Colors.text)
				love.graphics.polygon("fill",
					right_x + 270, item_y + 10,
					right_x + 270, item_y + self.item_height - 10,
					right_x + 260, item_y + self.item_height / 2
				)

				-- Draw > button
				love.graphics.setColor(Colors.line)
				love.graphics.draw(atlas, pixel, right_x + 400, item_y + 4, 0, 30, 1) -- Top
				love.graphics.draw(atlas, pixel, right_x + 400, item_y + self.item_height - 5, 0, 30, 1) -- Bottom
				love.graphics.draw(atlas, pixel, right_x + 400, item_y + 4, 0, 1, self.item_height - 8) -- Left
				love.graphics.draw(atlas, pixel, right_x + 429, item_y + 4, 0, 1, self.item_height - 8) -- Right

				love.graphics.setColor(Colors.text)
				love.graphics.polygon("fill",
					right_x + 410, item_y + 10,
					right_x + 410, item_y + self.item_height - 10,
					right_x + 420, item_y + self.item_height / 2
				)
			end
		end
	end

	-- Draw cursor line as a triangle pointing to the right
	local cursor_idx = self.modifierSelectModel.modifierIndex
	if cursor_idx and cursor_idx >= 1 and cursor_idx <= #modifiers + 1 then
		local cursor_y = right_y + (cursor_idx - 1) * (self.item_height + self.item_padding) - 2 - right_scroll
		love.graphics.setColor(1, 1, 1)
		love.graphics.polygon("fill",
			right_x, cursor_y - 6,
			right_x, cursor_y + 6,
			right_x + 10, cursor_y
		)
	end

	-- Reset color for text batch
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.text_batch)

	-- Disable stencil
	love.graphics.setStencilMode("off")
end

return ModifierView
