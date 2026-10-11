local VirtualizedList = require("gui.VirtualizedList")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local SpriteBatch = require("gui.SpriteBatch")
local Settings = require("rizu.config.Settings")
local ModifierModel = require("sphere.models.ModifierModel")
local ScoreSystemFormatter = require("ui.formatters.ScoreSystemFormatter")
local time_util = require("time_util")
local AvatarShader = require("ui.views.AvatarShader")

-- Transparent version of the song select score list: no panel behind it, shorter rows,
-- no hover, selection, fade animations or clicks yet.
---@class ui.screens.result_v2.ScoreList : gui.VirtualizedList
---@operator call: ui.screens.result_v2.ScoreList
local ScoreList = VirtualizedList + {}

local ITEM_HEIGHT = 64
local ROW_GAP = 5
local AVATAR_SIZE = 52
local AVATAR_PADDING = 6
local TEXT_X = AVATAR_PADDING * 2 + AVATAR_SIZE + 6
local TEXT_RIGHT = 14

ScoreList.ITEM_HEIGHT = ITEM_HEIGHT
ScoreList.ROW_GAP = ROW_GAP

---@param rows number
---@return number
function ScoreList.getHeightForRows(rows)
	return rows * ITEM_HEIGHT + (rows - 1) * ROW_GAP
end

---@param score_selector rizu.select.ScoreSelector
---@param localization ui.localization.Localization
---@param online_client rizu.OnlineClient
---@param avatar_cache rizu.online.AvatarCache?
function ScoreList:new(score_selector, localization, online_client, avatar_cache)
	VirtualizedList.new(self)
	self.score_selector = score_selector
	self.localization = localization
	self.online_client = online_client
	self.avatar_cache = avatar_cache
	self.items = {}
	self.avatar_items = {}
	self.item_height = ITEM_HEIGHT
	self.gap = ROW_GAP
	self.batch = SpriteBatch(Resources.sprites.result_v2_score_cap)
	self.avatar_shader = AvatarShader.new()
	self.text_batch24 = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.text_batch16 = love.graphics.newTextBatch(Resources.getFont("regular", 16))
end

function ScoreList:load()
	self.online_observer = self.online_client:onChanged(function(event)
		if event.type == "user_changed" or event.type == "connection_changed" or event.type == "authentication_resolved" then
			self:reload()
		end
	end)
end

function ScoreList:unload()
	if self.online_observer then
		self.online_client:offChanged(self.online_observer)
		self.online_observer = nil
	end
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

	local fallback_username = self.localization:get("song_select.username")
	local local_username = fallback_username
	local user = self.online_client:getUser()
	if self.online_client:isConnected() and user and type(user.name) == "string" and user.name ~= "" then
		local_username = user.name
	end
	local is_local = self.score_selector.settings:getChoice(Settings.keys.select.score_source) == "local"

	for i, v in ipairs(self.score_selector.store.items) do
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
			accuracy = ("%0.02f%%"):format((v.score or 0) / 100),
			time_ago = time_util.time_ago_in_words(v.created_at or 0),
			mods = table.concat(mods_sb, " "),
			color = getColorFromScore(v.score or 0),
			avatar_url = is_local and user and user.avatar or v.user_avatar,
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
local function setColor(color)
	cs[1][1] = color[1]
	cs[1][2] = color[2]
	cs[1][3] = color[3]
	cs[1][4] = color[4]
end

function ScoreList:update(dt)
	VirtualizedList.update(self, dt)

	self.batch:clear()
	self.avatar_items = {}
	self.text_batch24:clear()
	self.text_batch16:clear()

	local row_step = ITEM_HEIGHT + ROW_GAP
	local scroll = self:getVisualScrollPosition()
	local first_row, last_row = self:getVisibleRowRange()
	for i = first_row, last_row do
		self:drawItem(self.items[i], (i - 1) * row_step - scroll)
	end
end

---@param item table
---@param y number
function ScoreList:drawItem(item, y)
	local cap_width = Resources.sprites.result_v2_score_cap:getWidth()
	local fade = Resources.sprites.result_v2_score_fade
	local color = item.color

	self.batch:setColor(color[1], color[2], color[3], 0.3)
	self.batch:add(Resources.sprites.result_v2_score_cap, 0, y)
	self.batch:add(fade, cap_width, y, 0, (self.width - cap_width) / fade:getWidth(), ITEM_HEIGHT / fade:getHeight())

	local avatar_image = self.avatar_cache and self.avatar_cache:get(item.avatar_url)
	if avatar_image then
		table.insert(self.avatar_items, {image = avatar_image, y = y})
	else
		self.batch:setColor(1, 1, 1, 1)
		self.batch:add(Resources.sprites.result_v2_score_avatar, AVATAR_PADDING, y + AVATAR_PADDING)
	end

	local has_mods = item.mods ~= ""
	setColor(Colors.text)
	cs[2] = item.label
	self.text_batch24:add(cs, TEXT_X, y + (has_mods and 8 or 18))

	setColor(item.color)
	cs[2] = item.accuracy
	self.text_batch24:addf(cs, self.width, "right", -TEXT_RIGHT, y + 8)

	setColor(Colors.muted)
	cs[2] = item.time_ago
	self.text_batch16:addf(cs, self.width, "right", -TEXT_RIGHT, y + 37)

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
		lg.setShader(self.avatar_shader)
		lg.draw(
			avatar.image,
			AVATAR_PADDING + (AVATAR_SIZE - width) / 2,
			avatar.y + AVATAR_PADDING + (AVATAR_SIZE - height) / 2,
			0,
			scale
		)
		lg.setShader()
	end
	lg.draw(self.text_batch16)
	lg.draw(self.text_batch24)
end

return ScoreList
