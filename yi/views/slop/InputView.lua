local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local SpringValue = require("gui.anim.SpringValue")

local cs = {Colors.text, ""}

---@class yi.views.slop.InputView : gui.View
---@operator call: yi.views.slop.InputView
---@field inputModel sphere.InputModel
---@field modifierCoordinator rizu.select.ModifierCoordinator
---@field text_batch love.TextBatch
local InputView = View + {}

---@param game table
function InputView:new(game)
	View.new(self)
	self.game = assert(game)
	self.inputModel = assert(game.inputModel)
	self.modifierCoordinator = assert(game.modifierCoordinator)

	self.text_batch = love.graphics.newTextBatch(Resources.getScaledFont("regular", 24))
	self.handles_mouse_input = true
	self.handles_keyboard_input = true

	-- Layout constants
	self.padding = 20
	self.item_height = 40
	self.item_padding = 6
	self.col_width = 728
	self.col_height = 500

	-- Mouse hover and dragging / binding state
	self.hovered_item_idx = nil
	self.hovered_slot_idx = nil
	self.binding_slot = nil -- {virtualKey = string, bind_idx = number}

	-- Scroll springs and targets
	self.scroll_spring = SpringValue()
	self.scroll_target = 0

	self.atlas = Resources.atlas
	self.quads = Resources.quads
end

function InputView:load()
	local w = self.padding * 2 + self.col_width
	local h = self.padding * 2 + self.col_height + 40
	self:setSize(w, h)
end

function InputView:update(dt)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	-- Update scroll spring
	self.scroll_spring:update(dt)
	local scroll = self.scroll_spring:get()

	self.hovered_item_idx = nil
	self.hovered_slot_idx = nil

	local list_x = self.padding
	local list_y = self.padding + 40
	local list_w = self.col_width

	local inputMode = tostring(self.modifierCoordinator.state.inputMode)
	local inputs = self.inputModel:getInputs(inputMode)
	local binds_count = self.inputModel:getBindsCount(inputMode)

	-- Check hover on the list
	if lx >= list_x and lx <= list_x + list_w and ly >= list_y and ly <= list_y + self.col_height then
		local idx = math.floor((ly - list_y + scroll) / (self.item_height + self.item_padding)) + 1
		-- idx can go up to #inputs + 1 (the last row is the reset button)
		if idx >= 1 and idx <= #inputs + 1 then
			self.hovered_item_idx = idx
			-- If hovering a bind slot (slots are on the right side: slot width 100 with padding 10)
			local slots_start_x = list_x + 260
			if lx >= slots_start_x and idx <= #inputs then
				local slot_idx = math.floor((lx - slots_start_x) / 110) + 1
				if slot_idx >= 1 and slot_idx <= binds_count + 1 then
					self.hovered_slot_idx = slot_idx
				end
			end
		end
	end

	-- Clamp scroll target if input list changes
	local total_rows = #inputs + 1
	local max_scroll = math.max(0, total_rows * (self.item_height + self.item_padding) - self.col_height)
	if self.scroll_target > max_scroll then
		self.scroll_target = max_scroll
		self.scroll_spring:set(max_scroll)
	end

	-- Update text batch
	self.text_batch:clear()
	self.text_batch:add("TODO: DEVICE ID IS ALWAYS 1, onKeyDown event doesn't contain it", 50, self.height - 50)
	local font = self.text_batch:getFont()
	local font_h = font:getHeight()
	local text_offset_y = (self.item_height - font_h) / 2

	-- Title
	self.text_batch:addf("Input Settings (" .. inputMode .. ")", self.col_width, "center", list_x, self.padding)

	-- Draw Input Bindings
	for i = 1, #inputs do
		local item_y = list_y + (i - 1) * (self.item_height + self.item_padding) - scroll
		local virtualKey = inputs[i]

		-- Key Name
		cs[1] = Colors.text
		cs[2] = virtualKey
		self.text_batch:addf(cs, 200, "left", list_x + 10, item_y + text_offset_y)

		-- Slots text
		local slots_start_x = list_x + 260
		for j = 1, binds_count + 1 do
			local slot_x = slots_start_x + (j - 1) * 110
			local text = ""
			local color = Colors.text

			if self.binding_slot and self.binding_slot.virtualKey == virtualKey and self.binding_slot.bind_idx == j then
				text = "Press key..."
				color = Colors.accent
			else
				local key_name = self.inputModel:getKey(inputMode, virtualKey, j)
				text = key_name or "[Empty]"
				if not key_name then
					color = Colors.text_muted
				end
			end

			cs[1] = color
			cs[2] = text
			self.text_batch:addf(cs, 100, "center", slot_x, item_y + text_offset_y)
		end
	end

	-- Reset button row text
	if #inputs > 0 then
		local btn_y = list_y + #inputs * (self.item_height + self.item_padding) - scroll
		cs[1] = Colors.text
		cs[2] = "Reset Bindings"
		self.text_batch:addf(cs, self.col_width, "center", list_x, btn_y + text_offset_y)
	end
end

function InputView:onKeyDown(e)
	if self.binding_slot then
		local virtualKey = self.binding_slot.virtualKey
		local bind_idx = self.binding_slot.bind_idx
		local inputMode = tostring(self.modifierCoordinator.state.inputMode)

		-- Bind the pressed key
		self.inputModel:setKey(inputMode, virtualKey, bind_idx, "keyboard", 1, e.key)
		self.binding_slot = nil
		return true
	end
	return false
end

function InputView:onMouseClick(e)
	local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)

	local list_x = self.padding
	local list_y = self.padding + 40
	local list_w = self.col_width

	local inputMode = tostring(self.modifierCoordinator.state.inputMode)
	local inputs = self.inputModel:getInputs(inputMode)
	local binds_count = self.inputModel:getBindsCount(inputMode)

	if lx >= list_x and lx <= list_x + list_w and ly >= list_y and ly <= list_y + self.col_height then
		local scroll = self.scroll_spring:get()
		local idx = math.floor((ly - list_y + scroll) / (self.item_height + self.item_padding)) + 1

		if idx >= 1 and idx <= #inputs then
			local virtualKey = inputs[idx]
			local slots_start_x = list_x + 260
			if lx >= slots_start_x then
				local slot_idx = math.floor((lx - slots_start_x) / 110) + 1
				if slot_idx >= 1 and slot_idx <= binds_count + 1 then
					if e.button == 1 then
						-- Enter binding mode
						self.binding_slot = {virtualKey = virtualKey, bind_idx = slot_idx}
						return true
					elseif e.button == 2 then
						-- Remove keybind
						self.inputModel:setKey(inputMode, virtualKey, slot_idx, nil, nil, nil)
						return true
					end
				end
			end
		elseif idx == #inputs + 1 then
			if e.button == 1 then
				-- Clicked reset button
				self.inputModel:resetInputs(inputMode)
				return true
			end
		end
	end

	-- Cancel binding mode if clicked outside a slot
	if self.binding_slot then
		self.binding_slot = nil
		return true
	end

	return false
end

function InputView:onScroll(e)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	local list_x = self.padding
	local list_y = self.padding + 40

	if lx >= list_x and lx <= list_x + self.col_width and ly >= list_y and ly <= list_y + self.col_height then
		local inputMode = tostring(self.modifierCoordinator.state.inputMode)
		local inputs = self.inputModel:getInputs(inputMode)
		local total_rows = #inputs + 1
		local max_scroll = math.max(0, total_rows * (self.item_height + self.item_padding) - self.col_height)
		self.scroll_target = math.max(0, math.min(self.scroll_target - e.direction_y * 120, max_scroll))
		self.scroll_spring:set(self.scroll_target)
		return true
	end
	return false
end

function InputView:draw()
	local atlas = self.atlas
	local pixel = self.quads.pixel

	-- List column background
	love.graphics.setColor(Colors.background)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)

	-- Draw outlines with "add" blend mode
	love.graphics.setBlendMode("add")
	love.graphics.setColor(Colors.outline)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, 1) -- Top
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40 + self.col_height - 1, 0, self.col_width, 1) -- Bottom
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, 1, self.col_height) -- Left
	love.graphics.draw(atlas, pixel, self.padding + self.col_width - 1, self.padding + 40, 0, 1, self.col_height) -- Right
	love.graphics.setBlendMode("alpha")

	-- Apply stencil to clip inside content
	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)
	love.graphics.setStencilMode("test")

	local scroll = self.scroll_spring:get()
	local inputMode = tostring(self.modifierCoordinator.state.inputMode)
	local inputs = self.inputModel:getInputs(inputMode)
	local binds_count = self.inputModel:getBindsCount(inputMode)

	-- Highlight hovered item/slot
	local list_y = self.padding + 40
	for i = 1, #inputs + 1 do
		local item_y = list_y + (i - 1) * (self.item_height + self.item_padding) - scroll
		if self.hovered_item_idx == i then
			if i <= #inputs then
				-- Hovering a key row
				love.graphics.setColor(Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.1)
				love.graphics.draw(atlas, pixel, self.padding, item_y, 0, self.col_width, self.item_height)

				-- Highlight the specific hovered slot
				if self.hovered_slot_idx then
					local slots_start_x = self.padding + 260
					local slot_x = slots_start_x + (self.hovered_slot_idx - 1) * 110
					love.graphics.setColor(Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.2)
					love.graphics.draw(atlas, pixel, slot_x, item_y + 2, 0, 100, self.item_height - 4)
				end
			else
				-- Hovering reset button row
				love.graphics.setColor(Colors.accent[1], Colors.accent[2], Colors.accent[3], 0.2)
				love.graphics.draw(atlas, pixel, self.padding, item_y, 0, self.col_width, self.item_height)
			end
		end

		-- Draw slot borders for virtual key rows
		if i <= #inputs then
			local slots_start_x = self.padding + 260
			for j = 1, binds_count + 1 do
				local slot_x = slots_start_x + (j - 1) * 110
				love.graphics.setColor(Colors.outline)
				love.graphics.draw(atlas, pixel, slot_x, item_y + 2, 0, 100, 1) -- Top
				love.graphics.draw(atlas, pixel, slot_x, item_y + self.item_height - 3, 0, 100, 1) -- Bottom
				love.graphics.draw(atlas, pixel, slot_x, item_y + 2, 0, 1, self.item_height - 4) -- Left
				love.graphics.draw(atlas, pixel, slot_x + 99, item_y + 2, 0, 1, self.item_height - 4) -- Right
			end
		end
	end

	-- Reset color for text batch
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.text_batch)

	-- Disable stencil
	love.graphics.setStencilMode("off")
end

return InputView
