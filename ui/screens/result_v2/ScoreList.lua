local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Sounds = require("ui.Sounds")
local SpriteBatch = require("gui.SpriteBatch")
local ModifierModel = require("sphere.models.ModifierModel")
local ScoreSystemFormatter = require("ui.formatters.ScoreSystemFormatter")
local time_util = require("time_util")
local AvatarShader = require("ui.views.AvatarShader")

-- Transparent score list of song select and the result screen: no panel behind it, short rows.
-- Fade animations, clicks and the selected score marker are opt-in.
---@class ui.screens.result_v2.ScoreList : gui.VirtualizedList
---@operator call: ui.screens.result_v2.ScoreList
local ScoreList = VirtualizedList + {}

local ITEM_HEIGHT = 64
local ROW_GAP = 5
local AVATAR_SIZE = 52
local AVATAR_PADDING = 6
local TEXT_X = AVATAR_PADDING * 2 + AVATAR_SIZE + 6
local TEXT_RIGHT = 14
local PLACEHOLDER_COLOR = {0, 0, 0}
local PLACEHOLDER_ALPHA = 0.25
local FADE_DURATION = 0.4
local FADE_STAGGER = 0.02
local HOVER_GRADIENT_ALPHA = 0.6
local GRADIENT_ALPHA = 0.3
local MARKER_GAP = 12

ScoreList.ITEM_HEIGHT = ITEM_HEIGHT
ScoreList.ROW_GAP = ROW_GAP

---@param rows number
---@return number
function ScoreList.getHeightForRows(rows)
	return rows * ITEM_HEIGHT + (rows - 1) * ROW_GAP
end

---@param scores rizu.api.Scores
---@param localization ui.localization.Localization
---@param online rizu.api.Online
function ScoreList:new(scores, localization, online)
	VirtualizedList.new(self)
	self.scores = scores
	self.localization = localization
	self.online = online
	self.items = {}
	self.avatar_items = {}
	self.show_empty_sprite = false
	self.animated = false
	self.handles_mouse_input = true
	self.reload_time = 0
	self.fade_out_time = nil
	self.hover_index = nil
	self.loading = false
	self.empty_t = 0
	self.item_height = ITEM_HEIGHT
	self.gap = ROW_GAP
	self.batch = SpriteBatch(Resources.sprites.result_v2_score_cap)
	self.avatar_shader = AvatarShader.new()
	self.font24 = Resources.getFont("regular", 24)
	self.text_batch24 = love.graphics.newTextBatch(self.font24)
	self.text_batch16 = love.graphics.newTextBatch(Resources.getFont("regular", 16))
end

function ScoreList:load()
	self.unsubscribe = self.online:on("account_changed", function() self:reload() end)
end

function ScoreList:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end

---@param score number 0..10000
---@return gui.Color
function ScoreList.getColorFromScore(score) -- TODO: Should use Chartplay:getGrade() but idk where to get it
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
	self.fade_out_time = nil
	self.reload_time = love.timer.getTime()

	local fallback_username = self.localization:get("song_select.username")
	local local_username = self.online:getUsername() or fallback_username
	local local_avatar = self.online:getAvatarUrl()
	local is_local = self.scores:getSource() == "local"

	for i = 1, self.scores:getCount() do
		local v = assert(self.scores:get(i))
		local mods_sb = {}

		if v.const then
			table.insert(mods_sb, self.localization:get("song_select.const"))
		end

		if v.rate and v.rate ~= 1 then
			table.insert(mods_sb, ("%0.02fx"):format(v.rate))
		end

		if v.pause_count and v.pause_count > 0 then
			table.insert(mods_sb, self.localization:get("song_select.pauses"))
		end

		local mutators = ModifierModel:getString(v.modifiers or {})
		if mutators ~= "" then
			table.insert(mods_sb, mutators)
		end

		if v.timings then
			table.insert(mods_sb, ScoreSystemFormatter(v):getName())
		end

		local username = type(v.user_name) == "string" and v.user_name ~= "" and v.user_name
			or (is_local and local_username or fallback_username)
		table.insert(self.items, {
			label = self.localization:get("song_select.score_username", {index = i, username = username}),
			accuracy = self.scores:getAccuracy(v) or "-",
			time_ago = time_util.time_ago_in_words(v.created_at or 0),
			mods = table.concat(mods_sb, " "),
			color = ScoreList.getColorFromScore(v.score or 0),
			avatar_url = is_local and local_avatar or v.user_avatar,
			score = v,
		})
	end

	self:scrollTo(self.scroll_target, true)
end

---@return integer count
function ScoreList:getItemCount()
	return #self.items
end

local cs = {{1, 1, 1, 1}, ""}

---@param color gui.Color
---@param alpha number?
local function setColor(color, alpha)
	cs[1][1] = color[1]
	cs[1][2] = color[2]
	cs[1][3] = color[3]
	cs[1][4] = alpha or color[4]
end

---@param p number
---@return number
local function easeOutCubic(p)
	return 1 - (1 - p) ^ 3
end

---Shows the "no records" sprite while there are no scores and none are loading.
---@param enabled boolean
function ScoreList:setEmptySpriteEnabled(enabled)
	self.show_empty_sprite = enabled
end

---Rows fade in one after another on reload and fade out while scores load.
---@param animated boolean
function ScoreList:setAnimated(animated)
	self.animated = animated
end

function ScoreList:fadeOutItems()
	if #self.items > 0 and not self.fade_out_time then
		self.fade_out_time = love.timer.getTime()
	end
end

---Draws a small circle after the name of the selected score.
---@param marked boolean
function ScoreList:setSelectionMarked(marked)
	self.selection_marked = marked
end

---Makes rows clickable; they brighten under the mouse.
---@param on_select fun(index: integer)?
function ScoreList:setOnSelect(on_select)
	self.on_select = on_select
end

---@param e gui.MouseClickEvent
function ScoreList:onMouseClick(e)
	if e.button == 1 and self.on_select and self.hover_index then
		self.on_select(self.hover_index)
		return true
	end
end

---@param loading boolean
function ScoreList:setLoading(loading)
	self.loading = loading
end

function ScoreList:update(dt)
	VirtualizedList.update(self, dt)

	if self.show_empty_sprite and not self.loading and #self.items == 0 then
		self.empty_t = math.min(1, self.empty_t + dt * 6)
	else
		self.empty_t = math.max(0, self.empty_t - dt * 15)
	end

	local last_hover = self.hover_index
	self.hover_index = nil
	if (self.animated or self.on_select) and self.mouse_over then
		local _, my = self.world_transform:inverseTransformPoint(love.mouse.getPosition())
		local row_step = ITEM_HEIGHT + ROW_GAP
		local index = math.floor((my + self:getVisualScrollPosition()) / row_step) + 1
		if my >= 0 and my < self.height and index >= 1 and index <= #self.items then
			self.hover_index = index
		end
	end
	if last_hover ~= self.hover_index and self.hover_index then
		Sounds.play("hover")
	end

	self.batch:clear()
	self.avatar_items = {}
	self.selected_score = self.selection_marked and self.scores:getSelected() or nil
	self.text_batch24:clear()
	self.text_batch16:clear()

	local row_step = ITEM_HEIGHT + ROW_GAP
	local scroll = self:getVisualScrollPosition()
	local first_row, last_row = self:getVisibleRowRange()
	for i = first_row, last_row do
		self:drawItem(self.items[i], i, (i - 1) * row_step - scroll)
	end

	-- Empty placeholder rows below the last score so a short list doesn't leave the bottom bare.
	local y = #self.items * row_step - scroll
	while y < self.height do
		self:drawBackground(PLACEHOLDER_COLOR, PLACEHOLDER_ALPHA, y, true)
		y = y + row_step
	end
end

---@param color gui.Color
---@param alpha number
---@param y number
---@param solid boolean? Flat body instead of the fade-out.
function ScoreList:drawBackground(color, alpha, y, solid)
	local cap = Resources.sprites.result_v2_score_cap
	local fade = solid and Resources.sprites.result_v2_score_body or Resources.sprites.result_v2_score_fade
	local cap_width = cap:getWidth()
	self.batch:setColor(color[1], color[2], color[3], alpha)
	self.batch:add(cap, 0, y)
	if solid then
		local right_cap = Resources.sprites.result_v2_score_cap_right
		local body_width = self.width - cap_width - right_cap:getWidth()
		self.batch:add(fade, cap_width, y, 0, body_width / fade:getWidth(), ITEM_HEIGHT / fade:getHeight())
		self.batch:add(right_cap, self.width - right_cap:getWidth(), y)
		return
	end
	self.batch:add(fade, cap_width, y, 0, (self.width - cap_width) / fade:getWidth(), ITEM_HEIGHT / fade:getHeight())
end

---@param item table
---@param index integer
---@param y number
function ScoreList:drawItem(item, index, y)
	-- Visibility of the row's content, 0 to 1.
	local p = 1
	if self.animated then
		local now = love.timer.getTime()
		p = easeOutCubic(math.max(0, math.min(1, (now - self.reload_time - index * FADE_STAGGER) / FADE_DURATION)))
		if self.fade_out_time then
			p = p * (1 - easeOutCubic(math.max(0, math.min(1, (now - self.fade_out_time) / FADE_DURATION))))
		end
	end

	-- The same solid base as the empty rows, so the fade-out has something to blend with.
	self:drawBackground(PLACEHOLDER_COLOR, PLACEHOLDER_ALPHA, y, true)
	self:drawBackground(item.color, (index == self.hover_index and HOVER_GRADIENT_ALPHA or GRADIENT_ALPHA) * p, y)

	local avatar_image = self.online:getAvatar(item.avatar_url)
	if avatar_image then
		table.insert(self.avatar_items, {image = avatar_image, y = y, opacity = p})
	else
		self.batch:setColor(1, 1, 1, p)
		self.batch:add(Resources.sprites.result_v2_score_avatar, AVATAR_PADDING, y + AVATAR_PADDING)
	end

	local has_mods = item.mods ~= ""
	setColor(Colors.text, p)
	cs[2] = item.label
	local label_y = y + (has_mods and 8 or 18)
	self.text_batch24:add(cs, TEXT_X, label_y)
	if item.score == self.selected_score then
		local marker = Resources.sprites.result_v2_score_marker
		self.batch:setColor(Colors.text[1], Colors.text[2], Colors.text[3], p)
		self.batch:add(
			marker,
			TEXT_X + self.font24:getWidth(item.label) + MARKER_GAP,
			label_y + (self.font24:getHeight() - marker:getHeight()) / 2
		)
	end

	setColor(item.color, p)
	cs[2] = item.accuracy
	self.text_batch24:addf(cs, self.width, "right", -TEXT_RIGHT, y + 8)

	setColor(Colors.muted, p)
	cs[2] = item.time_ago
	self.text_batch16:addf(cs, self.width, "right", -TEXT_RIGHT, y + 37)

	setColor(Colors.muted, p)
	cs[2] = item.mods
	self.text_batch16:add(cs, TEXT_X, y + 37)
end

local lg = love.graphics

function ScoreList:draw()
	Painter.setColorRgb(1, 1, 1)
	Painter.setOpacity(1)
	Painter.snapToPixel()

	self.batch:draw()
	for _, avatar in ipairs(self.avatar_items) do
		local image_width, image_height = avatar.image:getDimensions()
		local scale = math.max(AVATAR_SIZE / image_width, AVATAR_SIZE / image_height)
		local width, height = image_width * scale, image_height * scale
		local x, y = self.world_transform:transformPoint(AVATAR_PADDING, avatar.y + AVATAR_PADDING)
		self.avatar_shader:send("u_position", {x, y})
		-- The shader works in drawable pixels; the position above already is, the size must be too.
		local ui_scale = assert(self.screen).ui_scale
		self.avatar_shader:send("u_size", {AVATAR_SIZE * ui_scale, AVATAR_SIZE * ui_scale})
		self.avatar_shader:send("u_radius", 5 * ui_scale)
		Painter.setColorRgb(1, 1, 1)
		Painter.setOpacity(avatar.opacity or 1)
		lg.setShader(self.avatar_shader)
		lg.draw(
			avatar.image,
			AVATAR_PADDING + (AVATAR_SIZE - width) / 2,
			avatar.y + AVATAR_PADDING + (AVATAR_SIZE - height) / 2,
			0,
			scale
		)
		lg.setShader()
		Painter.setOpacity(1)
	end
	lg.draw(self.text_batch16)
	lg.draw(self.text_batch24)

	if self.empty_t > 0 then
		local sprite = Resources.sprites.no_records_set
		local t = 1 - self.empty_t
		Painter.setColorRgb(1, 1, 1)
		Painter.setOpacity(1 - t * t * t)
		sprite:draw(self.width / 2, self.height / 2, 0, 1, 1, sprite:getWidth() / 2, sprite:getHeight() / 2)
		Painter.setOpacity(1)
	end
end

return ScoreList
