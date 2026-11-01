local View = require("gui.View")
local FlowContainer = require("gui.layout.FlowContainer")
local Painter = require("gui.Painter")
local Colors = require("ui.Colors")
local Resources = require("ui.Resources")
local Label = require("ui.views.Label")
local AvatarShader = require("ui.views.AvatarShader")

local lg = love.graphics

local AVATAR_SIZE = 64
local RING_WIDTH = 3
local MSD_COLOR = {0xF5 / 255, 0xC8 / 255, 0x42 / 255, 1}
local DIVIDER_COLOR = {0xF2 / 255, 0xF2 / 255, 1, 0.25}

---Top left of the main menu: round avatar, name and local MSD.
---@class ui.screens.main_menu_v2.PlayerCard : gui.layout.FlowContainer
---@operator call: ui.screens.main_menu_v2.PlayerCard
---@field ui ui.UserInterface
---@field name ui.views.Label
---@field msd ui.views.Label
---@field msd_column gui.layout.FlowContainer
---@field avatar_shader love.Shader?
---@field unsubscribe fun()?
local PlayerCard = FlowContainer + {}

---@param ui ui.UserInterface
function PlayerCard:new(ui)
	FlowContainer.new(self, {direction = "row", gap = 18, align = 0.5})
	self.ui = ui

	local avatar = self:add(View():setSize(AVATAR_SIZE, AVATAR_SIZE))
	avatar:setDraw(function() self:drawAvatar() end)
	self.name = self:add(Label({font_name = "bold", font_size = 32}))

	-- With the 18px gaps on both sides, the line gets the mockup's 22px of room.
	local divider = self:add(View():setSize(9, 52))
	divider:setDraw(function(view)
		Painter.setColorTable(DIVIDER_COLOR)
		Resources.sprites.pixel:draw(math.floor(view.width / 2), 0, 0, 1, view.height)
	end)

	self.msd_column = self:add(FlowContainer({direction = "column", align = 0}))
	self.msd = self.msd_column:add(Label({font_name = "bold", font_size = 32, text = "-", color = MSD_COLOR}))
	self.msd_column:add(Label({
		font_name = "medium",
		font_size = 13,
		text = ui.localization:get("main_menu.local_msd"):upper(),
		color = Colors.muted,
	}))
	self.msd_column:fitContent()
	self:updateName()
end

function PlayerCard:load()
	self.unsubscribe = self.ui.api.online:on("account_changed", function() self:updateName() end)
	self:updateName()
	-- Coming back from a play loads the menu again, so its score is counted.
	self.ui.api.scores:getTotalRatings(function(totals)
		if not totals then return end
		self.msd:setText(("%.2f"):format(totals.msd))
		self.msd_column:fitContent()
		self:fitContent()
	end)
end

function PlayerCard:unload()
	if self.unsubscribe then
		self.unsubscribe()
		self.unsubscribe = nil
	end
end

function PlayerCard:updateName()
	local online = self.ui.api.online
	self.name:setText(online:getUsername() or self.ui.localization:get("song_select.username"))
	self:fitContent()
end

function PlayerCard:drawAvatar()
	local half = AVATAR_SIZE / 2
	Painter.setColorTable(Colors.magenta)
	lg.circle("fill", half, half, half + RING_WIDTH, 48)

	local online = self.ui.api.online
	local image = online:getAvatar(online:getAvatarUrl())
	local shader = self.avatar_shader or AvatarShader.new()
	self.avatar_shader = shader
	AvatarShader.setRect(shader, 0, 0, AVATAR_SIZE, AVATAR_SIZE, half)
	Painter.setColorRgb(1, 1, 1)
	lg.setShader(shader)
	if image then
		local w, h = image:getDimensions()
		local scale = math.max(AVATAR_SIZE / w, AVATAR_SIZE / h)
		lg.draw(image, (AVATAR_SIZE - w * scale) / 2, (AVATAR_SIZE - h * scale) / 2, 0, scale)
	else
		local sprite = Resources.sprites.avatar
		local w, h = sprite:getDimensions()
		local scale = math.max(AVATAR_SIZE / w, AVATAR_SIZE / h)
		sprite:draw((AVATAR_SIZE - w * scale) / 2, (AVATAR_SIZE - h * scale) / 2, 0, scale, scale)
	end
	lg.setShader()
end

return PlayerCard
