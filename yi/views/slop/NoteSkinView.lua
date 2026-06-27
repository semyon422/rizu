local View = require("gui.View")
local Colors = require("yi.Colors")
local Resources = require("yi.Resources")
local SpringValue = require("gui.anim.SpringValue")
local just = require("just")
local imgui = require("imgui")

local cs = {Colors.text, ""}
local window_id = "NoteSkinView"

---@class yi.views.slop.NoteSkinView : gui.View
---@operator call: yi.views.slop.NoteSkinView
---@field noteSkinModel sphere.NoteSkinModel
---@field text_batch love.TextBatch
local NoteSkinView = View + {}

---@param game table
function NoteSkinView:new(game)
	View.new(self)
	self.game = assert(game)
	self.noteSkinModel = assert(game.noteSkinModel)

	self.text_batch = love.graphics.newTextBatch(Resources.getScaledFont("regular", 24))
	self.handles_mouse_input = true

	-- Layout constants
	self.padding = 20
	self.item_height = 40
	self.item_padding = 4
	self.col_width = 450
	self.col_height = 500

	-- Mouse hover state tracking
	self.hovered_idx = nil

	-- Scroll springs and targets
	self.scroll_spring = SpringValue()
	self.scroll_target = 0
	
	self.scrollYconfig = 0

	self.atlas = Resources.atlas
	self.quads = Resources.quads
end

function NoteSkinView:load()
	local w = self.padding * 3 + self.col_width * 2
	local h = self.padding * 2 + self.col_height + 40
	self:setSize(w, h)
end

function NoteSkinView:update(dt)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	-- Update scroll spring
	self.scroll_spring:update(dt)
	local scroll = self.scroll_spring:get()

	self.hovered_idx = nil

	local list_x = self.padding
	local list_y = self.padding + 40
	local list_w = self.col_width

	local inputMode = tostring(self.game.modifierCoordinator.state.inputMode)
	if inputMode == "" then return end

	local skinInfos = self.noteSkinModel:getSkinInfos(inputMode) or {}

	-- Check hover on list
	if lx >= list_x and lx <= list_x + list_w and ly >= list_y and ly <= list_y + self.col_height then
		local idx = math.floor((ly - list_y + scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #skinInfos then
			self.hovered_idx = idx
		end
	end

	-- Clamp scroll target
	local max_scroll = math.max(0, #skinInfos * (self.item_height + self.item_padding) - self.col_height)
	if self.scroll_target > max_scroll then
		self.scroll_target = max_scroll
		self.scroll_spring:set(max_scroll)
	end

	-- Update text batch
	self.text_batch:clear()
	local font = self.text_batch:getFont()
	local font_h = font:getHeight()
	local text_offset_y = (self.item_height - font_h) / 2

	local selectedNoteSkin = self.noteSkinModel:getNoteSkin(inputMode)

	for i, skinInfo in ipairs(skinInfos) do
		local item_y = list_y + (i - 1) * (self.item_height + self.item_padding) - scroll
		cs[1] = Colors.text
		cs[2] = skinInfo.name
		self.text_batch:addf(cs, self.col_width - 20, "left", list_x + 15, item_y + text_offset_y)
	end
end

function NoteSkinView:onMouseClick(e)
	local lx, ly = self.transform:inverseTransformPoint(e.x, e.y)

	local list_x = self.padding
	local list_y = self.padding + 40
	local list_w = self.col_width

	local inputMode = tostring(self.game.modifierCoordinator.state.inputMode)
	if inputMode == "" then return false end

	local skinInfos = self.noteSkinModel:getSkinInfos(inputMode) or {}

	if lx >= list_x and lx <= list_x + list_w and ly >= list_y and ly <= list_y + self.col_height then
		local scroll = self.scroll_spring:get()
		local idx = math.floor((ly - list_y + scroll) / (self.item_height + self.item_padding)) + 1
		if idx >= 1 and idx <= #skinInfos then
			local skinInfo = skinInfos[idx]
			if skinInfo then
				if e.button == 1 then
					self.noteSkinModel:setDefaultNoteSkin(inputMode, skinInfo:getPath())
					return true
				end
			end
		end
	end

	return false
end

function NoteSkinView:onScroll(e)
	local mx, my = love.mouse.getPosition()
	local lx, ly = self.transform:inverseTransformPoint(mx, my)

	local list_x = self.padding
	local list_y = self.padding + 40

	if lx >= list_x and lx <= list_x + self.col_width and ly >= list_y and ly <= list_y + self.col_height then
		local inputMode = tostring(self.game.modifierCoordinator.state.inputMode)
		if inputMode == "" then return false end
		local skinInfos = self.noteSkinModel:getSkinInfos(inputMode) or {}
		local max_scroll = math.max(0, #skinInfos * (self.item_height + self.item_padding) - self.col_height)
		self.scroll_target = math.max(0, math.min(self.scroll_target - e.direction_y * 120, max_scroll))
		self.scroll_spring:set(self.scroll_target)
		return true
	end
	return false
end

function NoteSkinView:draw()
	local atlas = self.atlas
	local pixel = self.quads.pixel

	-- Draw Title
	love.graphics.setFont(Resources.getScaledFont("regular", 20))
	love.graphics.setColor(Colors.text)
	love.graphics.printf("Note Skins", self.padding, self.padding, self.col_width, "center")

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

	-- Apply stencil to clip inside list
	love.graphics.clear(false, true, false)
	love.graphics.setStencilMode("draw", 1)
	love.graphics.draw(atlas, pixel, self.padding, self.padding + 40, 0, self.col_width, self.col_height)
	love.graphics.setStencilMode("test")

	local scroll = self.scroll_spring:get()
	local inputMode = tostring(self.game.modifierCoordinator.state.inputMode)
	if inputMode ~= "" then
		local skinInfos = self.noteSkinModel:getSkinInfos(inputMode) or {}
		local selectedNoteSkin = self.noteSkinModel:getNoteSkin(inputMode)
		local list_y = self.padding + 40

		for i, skinInfo in ipairs(skinInfos) do
			local item_y = list_y + (i - 1) * (self.item_height + self.item_padding) - scroll
			local is_selected = selectedNoteSkin and (selectedNoteSkin.path == skinInfo:getPath())
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
	end

	-- Draw text batch inside stencil
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.text_batch)

	-- Disable stencil
	love.graphics.setStencilMode("off")

	-- Draw Settings Config Panel on the right
	if inputMode ~= "" then
		local selectedNoteSkin = self.noteSkinModel:getNoteSkin(inputMode)
		local config = selectedNoteSkin and selectedNoteSkin.config

		love.graphics.push()
		local right_x = self.padding * 2 + self.col_width
		local right_y = self.padding + 40
		love.graphics.translate(right_x, right_y)

		local cw, ch = self.col_width, self.col_height
		if config and config.w then cw = config.w end
		if config and config.h then ch = config.h end

		-- Draw Title for Settings above the box
		love.graphics.pop()
		love.graphics.setColor(Colors.text)
		love.graphics.printf("Skin Settings", right_x, self.padding, cw, "center")
		love.graphics.push()
		love.graphics.translate(right_x, right_y)

		-- Draw background
		love.graphics.setColor(Colors.background)
		love.graphics.draw(atlas, pixel, 0, 0, 0, cw, ch)

		-- Draw borders
		love.graphics.setBlendMode("add")
		love.graphics.setColor(Colors.outline)
		love.graphics.draw(atlas, pixel, 0, 0, 0, cw, 1) -- Top
		love.graphics.draw(atlas, pixel, 0, ch - 1, 0, cw, 1) -- Bottom
		love.graphics.draw(atlas, pixel, 0, 0, 0, 1, ch) -- Left
		love.graphics.draw(atlas, pixel, cw - 1, 0, 0, 1, ch) -- Right
		love.graphics.setBlendMode("alpha")

		if config and config.draw then
			-- Push/pop just container for the skin config imgui UI
			love.graphics.setColor(1, 1, 1, 1)
			just.push()
			imgui.Container(window_id .. "skin", cw, ch, 18, cw / 4, self.scrollYconfig)
			config:draw(cw, ch)
			self.scrollYconfig = imgui.Container()
			just.pop()
		else
			-- Placeholder when no config settings are available
			love.graphics.setColor(Colors.text_muted)
			love.graphics.printf("No settings available for this skin", 0, ch / 2 - 10, cw, "center")
		end

		love.graphics.pop()
	end
end

function NoteSkinView:unload()
	local inputMode = tostring(self.game.modifierCoordinator.state.inputMode)
	if inputMode ~= "" then
		local selectedNoteSkin = self.noteSkinModel:getNoteSkin(inputMode)
		if selectedNoteSkin and selectedNoteSkin.config then
			selectedNoteSkin.config:close()
		end
	end
end

return NoteSkinView
